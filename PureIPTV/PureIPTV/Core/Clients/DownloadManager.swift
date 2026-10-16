import Foundation
import SwiftData

struct DownloadMetadata: Codable {
    let id: String
    let title: String
    let coverURL: String?
}

actor DownloadManager {
    static let shared = DownloadManager()

    private var tasks: [String: URLSessionDownloadTask] = [:]
    private var activeDownloads: [String: DownloadProgressItem] = [:]
    private var progressContinuations: [String: AsyncStream<Double>.Continuation] = [:]
    private var progressBroadcasters: [UUID: AsyncStream<DownloadProgressItem>.Continuation] = [:]
    private var lastSpeedCalculationTimes: [String: Date] = [:]
    private var lastBytesWritten: [String: Int64] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.pureiptv.downloads")
        return URLSession(configuration: config, delegate: DownloadDelegate.shared, delegateQueue: nil)
    }()

    func startDownload(id: String, title: String, url: URL, coverURL: URL?) throws {
        let task = session.downloadTask(with: url)

        let metadata = DownloadMetadata(id: id, title: title, coverURL: coverURL?.absoluteString)
        if let data = try? JSONEncoder().encode(metadata),
           let jsonString = String(data: data, encoding: .utf8)
        {
            task.taskDescription = jsonString
        }

        tasks[id] = task
        let item = DownloadProgressItem(id: id, title: title, coverURL: coverURL?.absoluteString, progress: 0.0, isCompleted: false)
        activeDownloads[id] = item
        lastSpeedCalculationTimes[id] = Date()
        lastBytesWritten[id] = 0
        broadcast(item)
        task.resume()
    }

    func cancelDownload(id: String) {
        tasks[id]?.cancel()
        tasks.removeValue(forKey: id)
        activeDownloads.removeValue(forKey: id)
        lastSpeedCalculationTimes.removeValue(forKey: id)
        lastBytesWritten.removeValue(forKey: id)
        progressContinuations[id]?.finish()
        progressContinuations.removeValue(forKey: id)
    }

    func getActiveDownloads() -> [DownloadProgressItem] {
        Array(activeDownloads.values)
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

    func updateProgress(id: String, progress: Double, bytesWritten: Int64 = 0, totalBytesExpected: Int64 = 0) {
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

    func completeDownload(id: String) {
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
    }

    func getProgressStream(id: String) -> AsyncStream<Double> {
        AsyncStream { continuation in
            progressContinuations[id] = continuation
            DownloadDelegate.shared.registerProgressCallback(for: id) { progress in
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
    private var progressCallbacks: [String: (Double) -> Void] = [:]

    func registerProgressCallback(for id: String, callback: @escaping (Double) -> Void) {
        progressCallbacks[id] = callback
    }

    private func decodeMetadata(from task: URLSessionTask) -> DownloadMetadata? {
        guard let description = task.taskDescription,
              let data = description.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DownloadMetadata.self, from: data)
    }

    func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let metadata = decodeMetadata(from: downloadTask) else { return }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent("\(metadata.id).mp4")

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)

            let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            let context = ModelContext(SharedDatabaseConfig.shared)
            let offlineMedia = OfflineMedia(id: metadata.id, title: metadata.title, localFilePath: destinationURL.path, coverURL: metadata.coverURL, fileSize: fileSize)
            context.insert(offlineMedia)
            try context.save()

            progressCallbacks[metadata.id]?(1.0)
            Task {
                await DownloadManager.shared.completeDownload(id: metadata.id)
            }

        } catch {
            print("File error: \(error)")
        }

        progressCallbacks.removeValue(forKey: metadata.id)
    }

    func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let metadata = decodeMetadata(from: downloadTask) else { return }
        let progress = totalBytesExpectedToWrite > 0 ? (Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) : 0.0
        progressCallbacks[metadata.id]?(progress)
        Task {
            await DownloadManager.shared.updateProgress(
                id: metadata.id,
                progress: progress,
                bytesWritten: totalBytesWritten,
                totalBytesExpected: totalBytesExpectedToWrite
            )
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession _: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
