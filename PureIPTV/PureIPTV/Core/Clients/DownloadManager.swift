import Foundation
import SwiftData

struct DownloadMetadata: Codable, Sendable {
    let id: String
    let title: String
    let coverURL: String?
    let userAgentOverride: String?
}

actor DownloadManager {
    static let shared = DownloadManager()

    init() {
        let key = "com.pureiptv.downloadConcurrencyLimit"
        let storedValue = UserDefaults.standard.object(forKey: key) as? Int ?? 1
        concurrencyLimit = min(4, max(1, storedValue))
    }

    private var tasks: [String: URLSessionDownloadTask] = [:]
    private var activeDownloads: [String: DownloadProgressItem] = [:]
    private var progressContinuations: [String: AsyncStream<Double>.Continuation] = [:]
    private var progressBroadcasters: [UUID: AsyncStream<DownloadProgressItem>.Continuation] = [:]
    private var lastSpeedCalculationTimes: [String: Date] = [:]
    private var lastBytesWritten: [String: Int64] = [:]
    private var hasRestoredBackgroundTasks = false
    private var backgroundTaskRestorationsInProgress = 0
    private var invalidatedDownloadIDs: Set<String> = []
    private var queuedDownloadIDs: [String] = []
    private var concurrencyLimit = 1

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.pureiptv.downloads")
        return URLSession(configuration: config, delegate: DownloadDelegate.shared, delegateQueue: nil)
    }()

    func startDownload(id: String, title: String, url: URL, coverURL: URL?, userAgentOverride: String?) async throws {
        if tasks[id] != nil {
            return
        }
        if !hasRestoredBackgroundTasks {
            _ = await getActiveDownloads()
        }
        guard tasks[id] == nil else { return }
        invalidatedDownloadIDs.remove(id)
        var request = URLRequest(url: url)
        UserAgentManager.applyHeaders(to: &request, override: userAgentOverride)
        let task = session.downloadTask(with: request)

        let metadata = DownloadMetadata(
            id: id,
            title: title,
            coverURL: coverURL?.absoluteString,
            userAgentOverride: userAgentOverride
        )
        if let data = try? JSONEncoder().encode(metadata),
           let jsonString = String(data: data, encoding: .utf8)
        {
            task.taskDescription = jsonString
        }

        tasks[id] = task
        let item = DownloadProgressItem(
            id: id,
            title: title,
            coverURL: coverURL?.absoluteString,
            userAgentOverride: userAgentOverride,
            progress: 0.0,
            isCompleted: false
        )
        activeDownloads[id] = item
        lastSpeedCalculationTimes[id] = Date()
        lastBytesWritten[id] = 0
        queuedDownloadIDs.append(id)
        var queuedItem = item
        queuedItem.isQueued = true
        activeDownloads[id] = queuedItem
        broadcast(queuedItem)
        resumeQueuedDownloads()
    }

    func cancelDownload(id: String) {
        if backgroundTaskRestorationsInProgress > 0 {
            invalidatedDownloadIDs.insert(id)
        }
        if let task = tasks[id] {
            if task.state != .completed {
                DownloadDelegate.shared.ignore(taskIdentifier: task.taskIdentifier)
            }
            task.taskDescription = nil
            task.cancel()
        }
        tasks.removeValue(forKey: id)
        queuedDownloadIDs.removeAll { $0 == id }
        activeDownloads.removeValue(forKey: id)
        lastSpeedCalculationTimes.removeValue(forKey: id)
        lastBytesWritten.removeValue(forKey: id)
        progressContinuations[id]?.finish()
        progressContinuations.removeValue(forKey: id)
        resumeQueuedDownloads()
    }

    func getActiveDownloads() async -> [DownloadProgressItem] {
        guard !hasRestoredBackgroundTasks else {
            return Array(activeDownloads.values)
        }
        backgroundTaskRestorationsInProgress += 1
        let restoredTasks: [URLSessionDownloadTask] = await withCheckedContinuation { continuation in
            session.getAllTasks { tasks in
                continuation.resume(returning: tasks.compactMap { $0 as? URLSessionDownloadTask })
            }
        }

        for task in restoredTasks.sorted(by: { $0.taskIdentifier < $1.taskIdentifier }) where task.state != .completed {
            guard
                let description = task.taskDescription,
                let data = description.data(using: .utf8),
                let metadata = try? JSONDecoder().decode(DownloadMetadata.self, from: data)
            else { continue }

            // Actor reentrancy allows cancellation, completion, or a new task
            // with the same ID while getAllTasks is suspended. Never let this
            // stale session snapshot recreate or replace newer actor state.
            guard !invalidatedDownloadIDs.contains(metadata.id), tasks[metadata.id] == nil else {
                continue
            }

            tasks[metadata.id] = task
            let expectedBytes = task.countOfBytesExpectedToReceive
            let receivedBytes = task.countOfBytesReceived
            let progress = expectedBytes > 0
                ? min(1, max(0, Double(receivedBytes) / Double(expectedBytes)))
                : 0
            let item = DownloadProgressItem(
                id: metadata.id,
                title: metadata.title,
                coverURL: metadata.coverURL,
                userAgentOverride: metadata.userAgentOverride,
                progress: progress,
                bytesWritten: receivedBytes,
                totalBytesExpected: expectedBytes
            )
            activeDownloads[metadata.id] = item
            if task.state == .suspended {
                queuedDownloadIDs.append(metadata.id)
                var queuedItem = item
                queuedItem.isQueued = true
                activeDownloads[metadata.id] = queuedItem
            }
            lastSpeedCalculationTimes[metadata.id] = Date()
            lastBytesWritten[metadata.id] = receivedBytes
            broadcast(activeDownloads[metadata.id] ?? item)
        }

        hasRestoredBackgroundTasks = true
        backgroundTaskRestorationsInProgress -= 1
        if backgroundTaskRestorationsInProgress == 0 {
            invalidatedDownloadIDs.removeAll()
        }
        suspendExcessRunningTasks()
        resumeQueuedDownloads()
        return Array(activeDownloads.values)
    }

    func observeDownloads() -> AsyncStream<DownloadProgressItem> {
        let observerID = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeBroadcaster(observerID)
                }
            }
            self.progressBroadcasters[observerID] = continuation
        }
    }

    private func removeBroadcaster(_ id: UUID) {
        progressBroadcasters.removeValue(forKey: id)
    }

    private func broadcast(_ item: DownloadProgressItem) {
        for continuation in progressBroadcasters.values {
            continuation.yield(item)
        }
    }

    func setConcurrencyLimit(_ value: Int) {
        concurrencyLimit = min(4, max(1, value))
        suspendExcessRunningTasks()
        resumeQueuedDownloads()
    }

    private func suspendExcessRunningTasks() {
        let runningTasks = tasks
            .filter { $0.value.state == .running }
            .sorted { $0.value.taskIdentifier > $1.value.taskIdentifier }
        let excessCount = max(0, runningTasks.count - concurrencyLimit)
        for (id, task) in runningTasks.prefix(excessCount) {
            task.suspend()
            queuedDownloadIDs.removeAll { $0 == id }
            queuedDownloadIDs.insert(id, at: 0)
            if var item = activeDownloads[id] {
                item.isQueued = true
                activeDownloads[id] = item
                broadcast(item)
            }
        }
    }

    private func resumeQueuedDownloads() {
        guard hasRestoredBackgroundTasks, backgroundTaskRestorationsInProgress == 0 else { return }
        let runningCount = tasks.values.filter { $0.state == .running }.count
        var availableSlots = max(0, concurrencyLimit - runningCount)
        while availableSlots > 0, !queuedDownloadIDs.isEmpty {
            let id = queuedDownloadIDs.removeFirst()
            guard let task = tasks[id], task.state == .suspended else { continue }
            task.resume()
            if var item = activeDownloads[id] {
                item.isQueued = false
                activeDownloads[id] = item
                broadcast(item)
            }
            availableSlots -= 1
        }
    }

    func updateProgress(id: String, taskIdentifier: Int, progress: Double, bytesWritten: Int64 = 0, totalBytesExpected: Int64 = 0) {
        guard tasks[id]?.taskIdentifier == taskIdentifier else { return }
        let now = Date()
        var speed = 0.0
        if let lastTime = lastSpeedCalculationTimes[id], let lastBytes = lastBytesWritten[id] {
            let timeDiff = now.timeIntervalSince(lastTime)
            if timeDiff >= 0.4 {
                let bytesDiff = bytesWritten - lastBytes
                speed = max(0, Double(bytesDiff) / timeDiff)
                lastSpeedCalculationTimes[id] = now
                lastBytesWritten[id] = bytesWritten
            } else if let existingItem = activeDownloads[id] {
                speed = existingItem.speedBytesPerSecond
            }
        } else {
            lastSpeedCalculationTimes[id] = now
            lastBytesWritten[id] = bytesWritten
        }

        if var item = activeDownloads[id] {
            item.progress = progress
            item.bytesWritten = bytesWritten
            item.totalBytesExpected = totalBytesExpected
            item.speedBytesPerSecond = speed
            activeDownloads[id] = item
            broadcast(item)
        }
        progressContinuations[id]?.yield(progress)
    }

    func completeDownload(id: String, taskIdentifier: Int) {
        guard tasks[id]?.taskIdentifier == taskIdentifier else { return }
        if backgroundTaskRestorationsInProgress > 0 {
            invalidatedDownloadIDs.insert(id)
        }
        if var item = activeDownloads[id] {
            item.progress = 1.0
            item.isCompleted = true
            broadcast(item)
        }
        activeDownloads.removeValue(forKey: id)
        tasks.removeValue(forKey: id)
        lastSpeedCalculationTimes.removeValue(forKey: id)
        lastBytesWritten.removeValue(forKey: id)
        progressContinuations[id]?.finish()
        progressContinuations.removeValue(forKey: id)
        queuedDownloadIDs.removeAll { $0 == id }
        resumeQueuedDownloads()
    }

    func storeDownloadedFile(
        id: String,
        taskIdentifier: Int,
        title: String,
        coverURL: String?,
        userAgentOverride: String?,
        stagedFileURL: URL
    ) {
        guard tasks[id]?.taskIdentifier == taskIdentifier else {
            try? FileManager.default.removeItem(at: stagedFileURL)
            return
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent("\(id).mp4")
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: stagedFileURL, to: destinationURL)
            let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let context = ModelContext(SharedDatabaseConfig.shared)
            context.insert(OfflineMedia(
                id: id,
                title: title,
                localFilePath: destinationURL.path,
                coverURL: coverURL,
                fileSize: fileSize,
                userAgentOverride: userAgentOverride
            ))
            try context.save()
            completeDownload(id: id, taskIdentifier: taskIdentifier)
        } catch {
            print("File error: \(error)")
            try? FileManager.default.removeItem(at: stagedFileURL)
            failDownload(id: id, taskIdentifier: taskIdentifier)
        }
    }

    func failDownload(id: String, taskIdentifier: Int) {
        guard tasks[id]?.taskIdentifier == taskIdentifier else { return }
        if backgroundTaskRestorationsInProgress > 0 {
            invalidatedDownloadIDs.insert(id)
        }
        tasks.removeValue(forKey: id)
        queuedDownloadIDs.removeAll { $0 == id }
        if var item = activeDownloads.removeValue(forKey: id) {
            item.isFailed = true
            broadcast(item)
        }
        lastSpeedCalculationTimes.removeValue(forKey: id)
        lastBytesWritten.removeValue(forKey: id)
        progressContinuations[id]?.finish()
        progressContinuations.removeValue(forKey: id)
        resumeQueuedDownloads()
    }

    func getProgressStream(id: String) -> AsyncStream<Double> {
        AsyncStream { continuation in
            progressContinuations[id] = continuation
            guard let taskIdentifier = tasks[id]?.taskIdentifier else { return }
            DownloadDelegate.shared.registerProgressCallback(for: id, taskIdentifier: taskIdentifier) { progress in
                continuation.yield(progress)
            }
        }
    }

    func getDownloadedMedia() throws -> [OfflineMedia] {
        let context = ModelContext(SharedDatabaseConfig.shared)
        let descriptor = FetchDescriptor<OfflineMedia>(sortBy: [SortDescriptor(\.downloadedAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func deleteDownloadedMedia(id: String) throws {
        let context = ModelContext(SharedDatabaseConfig.shared)
        let descriptor = FetchDescriptor<OfflineMedia>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            // Delete file
            let fileURL = URL(fileURLWithPath: existing.localFilePath)
            try? FileManager.default.removeItem(at: fileURL)
            // Delete from DB
            context.delete(existing)
            try context.save()
        }
    }
}

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    static let shared = DownloadDelegate()

    var backgroundCompletionHandler: (() -> Void)?
    private var progressCallbacks: [String: (taskIdentifier: Int, callback: (Double) -> Void)] = [:]
    private let progressCallbacksLock = NSLock()
    private let ignoredTaskLock = NSLock()
    private var ignoredTaskIdentifiers: Set<Int> = []

    func registerProgressCallback(for id: String, taskIdentifier: Int, callback: @escaping (Double) -> Void) {
        progressCallbacksLock.lock()
        defer { progressCallbacksLock.unlock() }
        progressCallbacks[id] = (taskIdentifier, callback)
    }

    private func removeProgressCallback(for id: String, taskIdentifier: Int) {
        progressCallbacksLock.lock()
        defer { progressCallbacksLock.unlock() }
        guard progressCallbacks[id]?.taskIdentifier == taskIdentifier else { return }
        progressCallbacks.removeValue(forKey: id)
    }

    private func progressCallback(for id: String, taskIdentifier: Int) -> ((Double) -> Void)? {
        progressCallbacksLock.lock()
        defer { progressCallbacksLock.unlock() }
        guard let entry = progressCallbacks[id], entry.taskIdentifier == taskIdentifier else { return nil }
        return entry.callback
    }

    func ignore(taskIdentifier: Int) {
        ignoredTaskLock.lock()
        ignoredTaskIdentifiers.insert(taskIdentifier)
        ignoredTaskLock.unlock()
    }

    private func shouldIgnore(taskIdentifier: Int) -> Bool {
        ignoredTaskLock.lock()
        defer { ignoredTaskLock.unlock() }
        return ignoredTaskIdentifiers.contains(taskIdentifier)
    }

    private func clearIgnored(taskIdentifier: Int) {
        ignoredTaskLock.lock()
        ignoredTaskIdentifiers.remove(taskIdentifier)
        ignoredTaskLock.unlock()
    }

    private func decodeMetadata(from task: URLSessionTask) -> DownloadMetadata? {
        guard let description = task.taskDescription,
              let data = description.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DownloadMetadata.self, from: data)
    }

    func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard !shouldIgnore(taskIdentifier: downloadTask.taskIdentifier) else { return }
        guard let metadata = decodeMetadata(from: downloadTask) else { return }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let stagedFileURL = documentsPath.appendingPathComponent(".download-\(UUID().uuidString).tmp")
        do {
            try FileManager.default.copyItem(at: location, to: stagedFileURL)
        } catch {
            Task {
                await DownloadManager.shared.failDownload(id: metadata.id, taskIdentifier: downloadTask.taskIdentifier)
            }
            return
        }
        progressCallback(for: metadata.id, taskIdentifier: downloadTask.taskIdentifier)?(1.0)
        Task {
            await DownloadManager.shared.storeDownloadedFile(
                id: metadata.id,
                taskIdentifier: downloadTask.taskIdentifier,
                title: metadata.title,
                coverURL: metadata.coverURL,
                userAgentOverride: metadata.userAgentOverride,
                stagedFileURL: stagedFileURL
            )
        }
        removeProgressCallback(for: metadata.id, taskIdentifier: downloadTask.taskIdentifier)
    }

    func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard !shouldIgnore(taskIdentifier: downloadTask.taskIdentifier) else { return }
        guard let metadata = decodeMetadata(from: downloadTask) else { return }
        let progress = totalBytesExpectedToWrite > 0 ? (Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) : 0.0
        progressCallback(for: metadata.id, taskIdentifier: downloadTask.taskIdentifier)?(progress)
        Task {
            await DownloadManager.shared.updateProgress(
                id: metadata.id,
                taskIdentifier: downloadTask.taskIdentifier,
                progress: progress,
                bytesWritten: totalBytesWritten,
                totalBytesExpected: totalBytesExpectedToWrite
            )
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if shouldIgnore(taskIdentifier: task.taskIdentifier) {
            clearIgnored(taskIdentifier: task.taskIdentifier)
            return
        }
        clearIgnored(taskIdentifier: task.taskIdentifier)
        guard error != nil, let metadata = decodeMetadata(from: task) else { return }
        removeProgressCallback(for: metadata.id, taskIdentifier: task.taskIdentifier)
        Task {
            await DownloadManager.shared.failDownload(id: metadata.id, taskIdentifier: task.taskIdentifier)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession _: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
