import Foundation
import SwiftData

nonisolated struct DownloadMetadata: Codable, Sendable {
    let id: String
    let title: String
    let coverURL: String?
    let userAgentOverride: String?
}

private nonisolated enum DownloadStorageError: LocalizedError {
    case invalidPath
    case activeDownload
    case destinationExists

    var errorDescription: String? {
        switch self {
        case .invalidPath: NSLocalizedString("İndirme dosyası bu cihazda kullanılamıyor.", comment: "")
        case .activeDownload: NSLocalizedString("Bu dosya için aktif bir indirme var.", comment: "")
        case .destinationExists: NSLocalizedString("Aynı adlı bir dosya zaten var. Mevcut dosya korundu.", comment: "")
        }
    }
}

private nonisolated func removeRegularFileIfPresent(_ url: URL) throws -> Bool {
    let attributes: [FileAttributeKey: Any]
    do {
        attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    } catch {
        let cocoaError = error as NSError
        if cocoaError.domain == NSCocoaErrorDomain,
           cocoaError.code == NSFileNoSuchFileError || cocoaError.code == NSFileReadNoSuchFileError {
            return false
        }
        throw error
    }
    guard attributes[.type] as? FileAttributeType == .typeRegular else { throw DownloadStorageError.invalidPath }
    try FileManager.default.removeItem(at: url)
    return true
}

actor DownloadManager {
    static let shared = DownloadManager()

    init() {
        let key = "com.pureiptv.downloadConcurrencyLimit"
        let storedValue = UserDefaults.standard.object(forKey: key) as? Int ?? 1
        concurrencyLimit = min(4, max(1, storedValue))
        manuallyPausedDownloadIDs = Set(UserDefaults.standard.stringArray(forKey: "com.pureiptv.downloads.manuallyPausedIDs") ?? [])
    }

    private var tasks: [String: URLSessionDownloadTask] = [:]
    private var activeDownloads: [String: DownloadProgressItem] = [:]
    private var failedDownloads: [DownloadProgressItem] = []
    private var failedArtifacts: [String: Set<URL>] = [:]
    private var progressContinuations: [String: AsyncStream<Double>.Continuation] = [:]
    private var progressObserverIDs: [String: UUID] = [:]
    private var progressBroadcasters: [UUID: AsyncStream<DownloadProgressItem>.Continuation] = [:]
    private var lastSpeedCalculationTimes: [String: Date] = [:]
    private var lastBytesWritten: [String: Int64] = [:]
    private var lastProgressEmissionTimes: [String: ContinuousClock.Instant] = [:]
    private var hasRestoredBackgroundTasks = false
    private var backgroundTaskRestorationsInProgress = 0
    private var invalidatedDownloadIDs: Set<String> = []
    private var queuedDownloadIDs: [String] = []
    private var concurrencyLimit = 1
    private var manuallyPausedDownloadIDs: Set<String> = []

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
        guard canonicalDownloadDestinationURL(id: id) != nil else { throw DownloadStorageError.invalidPath }
        try removeFailedArtifact(id: id)
        if let existing = try getDownloadedMedia().first(where: { $0.id == id && $0.isAvailable }) {
            failedDownloads.removeAll { $0.id == id }
            broadcast(DownloadProgressItem(id: id, title: existing.title, coverURL: existing.coverURL, userAgentOverride: existing.userAgentOverride, progress: 1, isCompleted: true, bytesWritten: existing.fileSize, totalBytesExpected: existing.fileSize))
            return
        }
        invalidatedDownloadIDs.remove(id)
        manuallyPausedDownloadIDs.remove(id)
        persistManuallyPausedDownloadIDs()
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
        failedDownloads.removeAll { $0.id == id }
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
        let removedItem = activeDownloads[id]
        manuallyPausedDownloadIDs.remove(id)
        persistManuallyPausedDownloadIDs()
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
        lastProgressEmissionTimes.removeValue(forKey: id)
        progressContinuations[id]?.finish()
        progressContinuations.removeValue(forKey: id)
        progressObserverIDs.removeValue(forKey: id)
        if var removedItem {
            removedItem.isCancelled = true
            broadcast(removedItem)
        }
        resumeQueuedDownloads()
    }

    func pauseDownload(id: String) {
        guard let task = tasks[id], task.state == .running || task.state == .suspended else { return }
        if task.state == .running {
            task.suspend()
        }
        manuallyPausedDownloadIDs.insert(id)
        persistManuallyPausedDownloadIDs()
        queuedDownloadIDs.removeAll { $0 == id }
        if var item = activeDownloads[id] {
            item.isPaused = true
            item.isQueued = false
            item.speedBytesPerSecond = 0
            activeDownloads[id] = item
            broadcast(item)
        }
        resumeQueuedDownloads()
    }

    func resumeDownload(id: String) {
        guard manuallyPausedDownloadIDs.contains(id), let task = tasks[id] else { return }
        manuallyPausedDownloadIDs.remove(id)
        persistManuallyPausedDownloadIDs()
        if var item = activeDownloads[id] {
            item.isPaused = false
            item.isQueued = task.state == .suspended
            activeDownloads[id] = item
            broadcast(item)
        }
        guard task.state == .suspended else { return }
        queuedDownloadIDs.removeAll { $0 == id }
        queuedDownloadIDs.insert(id, at: 0)
        resumeQueuedDownloads()
    }

    private func persistManuallyPausedDownloadIDs() {
        UserDefaults.standard.set(manuallyPausedDownloadIDs.sorted(), forKey: "com.pureiptv.downloads.manuallyPausedIDs")
    }

    func getActiveDownloads(scheduleQueuedTasks: Bool = true) async -> [DownloadProgressItem] {
        guard !hasRestoredBackgroundTasks else {
            return orderedActiveDownloads()
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
            let isManuallyPaused = manuallyPausedDownloadIDs.contains(metadata.id)
            if isManuallyPaused, task.state == .running {
                task.suspend()
            }
            let item = DownloadProgressItem(
                id: metadata.id,
                title: metadata.title,
                coverURL: metadata.coverURL,
                userAgentOverride: metadata.userAgentOverride,
                progress: progress,
                bytesWritten: receivedBytes,
                totalBytesExpected: expectedBytes,
                isPaused: isManuallyPaused
            )
            activeDownloads[metadata.id] = item
            if task.state == .suspended, !isManuallyPaused {
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
        if scheduleQueuedTasks {
            suspendExcessRunningTasks()
            resumeQueuedDownloads()
        }
        return orderedActiveDownloads()
    }

    private func orderedActiveDownloads() -> [DownloadProgressItem] {
        activeDownloads.values.sorted {
            let lhs = tasks[$0.id]?.taskIdentifier ?? Int.max
            let rhs = tasks[$1.id]?.taskIdentifier ?? Int.max
            return lhs == rhs ? $0.id < $1.id : lhs < rhs
        }
    }

    func getLibrarySnapshot() async throws -> DownloadLibrarySnapshot {
        _ = await getActiveDownloads()
        let items = try getDownloadedMedia()
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: documentsURL.path)
        let availableBytes = (attributes?[.systemFreeSize] as? NSNumber)?.int64Value
        return DownloadLibrarySnapshot(
            downloadedItems: items,
            activeDownloads: orderedActiveDownloads(),
            failedDownloads: failedDownloads,
            storageSummary: DownloadStorageSummary(
                downloadedBytes: items.reduce(0) { $0 + $1.fileSize },
                availableBytes: availableBytes.map { max(0, $0) }
            )
        )
    }

    func dismissFailedDownload(id: String) throws {
        try removeFailedArtifact(id: id)
        guard let index = failedDownloads.firstIndex(where: { $0.id == id }) else { return }
        var item = failedDownloads.remove(at: index)
        item.isCancelled = true
        broadcast(item)
    }

    private func removeFailedArtifact(id: String) throws {
        guard let artifacts = failedArtifacts[id] else { return }
        guard tasks[id] == nil else { throw DownloadStorageError.activeDownload }
        let hasIndexedFile = try getDownloadedMedia().contains(where: { $0.id == id && $0.isAvailable })
        for artifact in artifacts {
            if hasIndexedFile, artifact == canonicalDownloadDestinationURL(id: id) {
                failedArtifacts[id]?.remove(artifact)
                continue
            }
            guard artifact == canonicalDownloadDestinationURL(id: id) || validatedStagingURL(artifact) != nil else {
                throw DownloadStorageError.invalidPath
            }
            _ = try removeRegularFileIfPresent(artifact)
            failedArtifacts[id]?.remove(artifact)
        }
        if failedArtifacts[id]?.isEmpty == true { failedArtifacts.removeValue(forKey: id) }
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
            guard !manuallyPausedDownloadIDs.contains(id) else { continue }
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
            item.progress = progress.isFinite ? min(1, max(0, progress)) : 0
            item.bytesWritten = bytesWritten
            item.totalBytesExpected = totalBytesExpected
            item.speedBytesPerSecond = speed
            activeDownloads[id] = item
            let instant = ContinuousClock().now
            if lastProgressEmissionTimes[id].map({ $0.duration(to: instant) >= .milliseconds(250) }) ?? true {
                lastProgressEmissionTimes[id] = instant
                broadcast(item)
            }
        }
        progressContinuations[id]?.yield(progress.isFinite ? min(0.999, max(0, progress)) : 0)
    }

    func completeDownload(id: String, taskIdentifier: Int) {
        guard tasks[id]?.taskIdentifier == taskIdentifier else { return }
        manuallyPausedDownloadIDs.remove(id)
        persistManuallyPausedDownloadIDs()
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
        lastProgressEmissionTimes.removeValue(forKey: id)
        progressContinuations[id]?.yield(1)
        progressContinuations[id]?.finish()
        progressContinuations.removeValue(forKey: id)
        progressObserverIDs.removeValue(forKey: id)
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
        guard let stagedFileURL = validatedStagingURL(stagedFileURL) else {
            failDownload(id: id, taskIdentifier: taskIdentifier)
            return
        }
        let stagingAttributes = try? FileManager.default.attributesOfItem(atPath: stagedFileURL.path)
        guard stagingAttributes?[.type] as? FileAttributeType == .typeRegular else {
            failDownload(id: id, taskIdentifier: taskIdentifier)
            return
        }
        guard tasks[id]?.taskIdentifier == taskIdentifier else {
            try? FileManager.default.removeItem(at: stagedFileURL)
            return
        }

        let fileManager = FileManager.default
        var createdDestinationURL: URL?
        do {
            guard let destinationURL = canonicalDownloadDestinationURL(id: id) else {
                throw DownloadStorageError.invalidPath
            }
            let context = ModelContext(SharedDatabaseConfig.shared)
            let descriptor = FetchDescriptor<OfflineMedia>(predicate: #Predicate { $0.id == id })
            let existingRecords = try context.fetch(descriptor)
            if fileManager.fileExists(atPath: destinationURL.path) {
                // An already indexed file wins over a duplicate/restored task.
                // Never destroy a last-good file to install a second copy.
                let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
                guard attributes[.type] as? FileAttributeType == .typeRegular,
                      existingRecords.contains(where: { canonicalCompletedDownloadURL(for: $0) == destinationURL }) else {
                    throw DownloadStorageError.destinationExists
                }
                try fileManager.removeItem(at: stagedFileURL)
                completeDownload(id: id, taskIdentifier: taskIdentifier)
                return
            }
            try fileManager.moveItem(at: stagedFileURL, to: destinationURL)
            createdDestinationURL = destinationURL
            let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let media = existingRecords.first ?? OfflineMedia(id: id, title: title, localFilePath: destinationURL.path, coverURL: coverURL, fileSize: fileSize, userAgentOverride: userAgentOverride)
            if existingRecords.isEmpty { context.insert(media) }
            media.title = title
            media.localFilePath = destinationURL.path
            media.coverURL = coverURL
            media.userAgentOverride = userAgentOverride
            media.fileSize = fileSize
            media.downloadedAt = Date()
            for duplicate in existingRecords.dropFirst() { context.delete(duplicate) }
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
            completeDownload(id: id, taskIdentifier: taskIdentifier)
        } catch {
            var retainedArtifacts = Set<URL>()
            for ownedURL in [createdDestinationURL, stagedFileURL].compactMap({ $0 }) {
                do {
                    _ = try removeRegularFileIfPresent(ownedURL)
                } catch {
                    retainedArtifacts.insert(ownedURL)
                }
            }
            failDownload(id: id, taskIdentifier: taskIdentifier, artifactURLs: retainedArtifacts)
        }
    }

    func failDownload(id: String, taskIdentifier: Int, artifactURLs: Set<URL> = []) {
        guard tasks[id]?.taskIdentifier == taskIdentifier else { return }
        manuallyPausedDownloadIDs.remove(id)
        persistManuallyPausedDownloadIDs()
        if backgroundTaskRestorationsInProgress > 0 {
            invalidatedDownloadIDs.insert(id)
        }
        tasks.removeValue(forKey: id)
        queuedDownloadIDs.removeAll { $0 == id }
        if var item = activeDownloads.removeValue(forKey: id) {
            item.isFailed = true
            item.isQueued = false
            item.isPaused = false
            item.speedBytesPerSecond = 0
            failedDownloads.removeAll { $0.id == id }
            failedDownloads.insert(item, at: 0)
            if !artifactURLs.isEmpty { failedArtifacts[id, default: []].formUnion(artifactURLs) }
            let discardableIDs = failedDownloads.filter { failedArtifacts[$0.id] == nil }.dropFirst(50).map(\.id)
            failedDownloads.removeAll { discardableIDs.contains($0.id) }
            broadcast(item)
        }
        lastSpeedCalculationTimes.removeValue(forKey: id)
        lastBytesWritten.removeValue(forKey: id)
        lastProgressEmissionTimes.removeValue(forKey: id)
        progressContinuations[id]?.finish()
        progressContinuations.removeValue(forKey: id)
        progressObserverIDs.removeValue(forKey: id)
        resumeQueuedDownloads()
    }

    func getProgressStream(id: String) -> AsyncStream<Double> {
        let observerID = UUID()
        return AsyncStream { continuation in
            progressContinuations[id]?.finish()
            progressObserverIDs[id] = observerID
            progressContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeProgressObserver(id: id, observerID: observerID) }
            }
            guard tasks[id] != nil else {
                if (try? getDownloadedMedia().contains(where: { $0.id == id && $0.isAvailable })) == true {
                    continuation.yield(1)
                }
                continuation.finish()
                return
            }
            continuation.yield(min(0.999, activeDownloads[id]?.progress ?? 0))
        }
    }

    private func removeProgressObserver(id: String, observerID: UUID) {
        guard progressObserverIDs[id] == observerID else { return }
        progressContinuations.removeValue(forKey: id)
        progressObserverIDs.removeValue(forKey: id)
    }

    func getDownloadedMedia() throws -> [OfflineMediaSnapshot] {
        let context = ModelContext(SharedDatabaseConfig.shared)
        let descriptor = FetchDescriptor<OfflineMedia>(sortBy: [SortDescriptor(\.downloadedAt, order: .reverse)])
        let records = try context.fetch(descriptor)
        var items: [String: OfflineMediaSnapshot] = [:]
        for media in records {
            let attributes = canonicalCompletedDownloadURL(for: media).flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path) }
            let isAvailable = attributes?[.type] as? FileAttributeType == .typeRegular
            let fileSize = isAvailable ? max(0, (attributes?[.size] as? NSNumber)?.int64Value ?? 0) : 0
            let item = OfflineMediaSnapshot(id: media.id, title: media.title, localFilePath: media.localFilePath, coverURL: media.coverURL, userAgentOverride: media.userAgentOverride, downloadedAt: media.downloadedAt, fileSize: fileSize, isAvailable: isAvailable)
            if items[media.id] == nil || (items[media.id]?.isAvailable == false && isAvailable) {
                items[media.id] = item
            }
        }
        return items.values.sorted { $0.downloadedAt == $1.downloadedAt ? $0.id < $1.id : $0.downloadedAt > $1.downloadedAt }
    }

    func deleteDownloadedMedia(id: String) async throws {
        _ = await getActiveDownloads(scheduleQueuedTasks: false)
        guard tasks[id] == nil, activeDownloads[id] == nil, !queuedDownloadIDs.contains(id) else {
            throw DownloadStorageError.activeDownload
        }
        let context = ModelContext(SharedDatabaseConfig.shared)
        let descriptor = FetchDescriptor<OfflineMedia>(predicate: #Predicate { $0.id == id })
        let records = try context.fetch(descriptor)
        guard !records.isEmpty else { return }
        guard let fileURL = canonicalCompletedDownloadURL(for: records[0]),
              records.allSatisfy({ canonicalCompletedDownloadURL(for: $0) == fileURL }) else {
            throw DownloadStorageError.invalidPath
        }
        _ = try removeRegularFileIfPresent(fileURL)
        for media in records { context.delete(media) }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteAllCompletedDownloads() async throws -> DownloadBulkDeleteResult {
        // Restore URLSession state before taking the protected-ID snapshot.
        // There are no suspension points after this await, so actor state and
        // SwiftData mutation remain serialized throughout the deletion pass.
        let restoredActiveDownloads = await getActiveDownloads(scheduleQueuedTasks: false)
        let protectedIDs = Set(tasks.keys)
            .union(queuedDownloadIDs)
            .union(activeDownloads.keys)
            .union(restoredActiveDownloads.map(\.id))
        let context = ModelContext(SharedDatabaseConfig.shared)
        let records = try context.fetch(FetchDescriptor<OfflineMedia>())
        var removedCount = 0
        var bytesFreed: Int64 = 0
        var failureCount = 0

        for media in records where !protectedIDs.contains(media.id) {
            guard let fileURL = canonicalCompletedDownloadURL(for: media) else {
                failureCount += 1
                continue
            }

            let fileExists: Bool
            do {
                fileExists = try removeRegularFileIfPresent(fileURL)
            } catch {
                failureCount += 1
                continue
            }

            context.delete(media)
            do {
                try context.save()
                removedCount += 1
                if fileExists {
                    bytesFreed += max(0, media.fileSize)
                }
            } catch {
                // The file may already be gone, but do not count this row as
                // removed. A later pass can safely reconcile the missing file.
                context.rollback()
                failureCount += 1
            }
        }

        return DownloadBulkDeleteResult(
            removedCount: removedCount,
            bytesFreed: bytesFreed,
            failureCount: failureCount
        )
    }

    private func canonicalCompletedDownloadURL(for media: OfflineMedia) -> URL? {
        guard let expectedURL = canonicalDownloadDestinationURL(id: media.id) else { return nil }
        let recordedURL = URL(fileURLWithPath: media.localFilePath).standardizedFileURL.resolvingSymlinksInPath()
        guard recordedURL == expectedURL else { return nil }
        return expectedURL
    }

    private func canonicalDownloadDestinationURL(id: String) -> URL? {
        guard
            !id.isEmpty,
            id != ".",
            id != "..",
            !id.contains("/"),
            !id.contains("\\"),
            !id.utf8.contains(0),
            !id.hasPrefix(".download-")
        else { return nil }

        let documentsURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let expectedURL = documentsURL
            .appendingPathComponent("\(id).mp4", isDirectory: false)
            .standardizedFileURL
        let resolvedExpectedURL = expectedURL.resolvingSymlinksInPath().standardizedFileURL

        // The download manager writes only <id>.mp4 directly in Documents.
        // Exact path equality also excludes temporary staging files and
        // symlinks that resolve outside the app's Documents directory.
        guard
            expectedURL.deletingLastPathComponent() == documentsURL,
            resolvedExpectedURL == expectedURL
        else { return nil }
        return expectedURL
    }

    private func validatedStagingURL(_ url: URL) -> URL? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].standardizedFileURL.resolvingSymlinksInPath()
        let candidate = documentsURL.appendingPathComponent(url.lastPathComponent).standardizedFileURL
        guard url.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath() == documentsURL,
              candidate.lastPathComponent.hasPrefix(".download-"), candidate.pathExtension == "tmp",
              candidate.resolvingSymlinksInPath() == candidate else { return nil }
        return candidate
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

    func removeProgressCallback(for id: String, taskIdentifier: Int) {
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
            var retainedArtifact: URL?
            do { _ = try removeRegularFileIfPresent(stagedFileURL) }
            catch { retainedArtifact = stagedFileURL }
            let artifactURLs = Set(retainedArtifact.map { [$0] } ?? [])
            Task {
                await DownloadManager.shared.failDownload(id: metadata.id, taskIdentifier: downloadTask.taskIdentifier, artifactURLs: artifactURLs)
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
