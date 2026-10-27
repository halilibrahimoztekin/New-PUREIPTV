import ComposableArchitecture
import Foundation

public nonisolated struct DownloadBulkDeleteResult: Equatable, Sendable {
    public let removedCount: Int
    public let bytesFreed: Int64
    public let failureCount: Int

    public init(removedCount: Int, bytesFreed: Int64, failureCount: Int) {
        self.removedCount = removedCount
        self.bytesFreed = bytesFreed
        self.failureCount = failureCount
    }
}

public nonisolated struct OfflineMediaSnapshot: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let localFilePath: String
    public let coverURL: String?
    public let userAgentOverride: String?
    public let downloadedAt: Date
    public let fileSize: Int64
    public let isAvailable: Bool

    public init(id: String, title: String, localFilePath: String, coverURL: String?, userAgentOverride: String?, downloadedAt: Date, fileSize: Int64, isAvailable: Bool) {
        self.id = id
        self.title = title
        self.localFilePath = localFilePath
        self.coverURL = coverURL
        self.userAgentOverride = userAgentOverride
        self.downloadedAt = downloadedAt
        self.fileSize = fileSize
        self.isAvailable = isAvailable
    }
}

public nonisolated struct DownloadStorageSummary: Equatable, Sendable {
    public let downloadedBytes: Int64
    public let availableBytes: Int64?

    public init(downloadedBytes: Int64 = 0, availableBytes: Int64? = nil) {
        self.downloadedBytes = downloadedBytes
        self.availableBytes = availableBytes
    }
}

public nonisolated struct DownloadLibrarySnapshot: Equatable, Sendable {
    public let downloadedItems: [OfflineMediaSnapshot]
    public let activeDownloads: [DownloadProgressItem]
    public let failedDownloads: [DownloadProgressItem]
    public let storageSummary: DownloadStorageSummary

    public init(downloadedItems: [OfflineMediaSnapshot] = [], activeDownloads: [DownloadProgressItem] = [], failedDownloads: [DownloadProgressItem] = [], storageSummary: DownloadStorageSummary = .init()) {
        self.downloadedItems = downloadedItems
        self.activeDownloads = activeDownloads
        self.failedDownloads = failedDownloads
        self.storageSummary = storageSummary
    }
}

@DependencyClient
public struct DownloadClient {
    public var startDownload: @Sendable (_ id: String, _ title: String, _ url: URL, _ coverURL: URL?, _ userAgentOverride: String?) async throws -> Void
    public var cancelDownload: @Sendable (_ id: String) async throws -> Void
    public var pauseDownload: @Sendable (_ id: String) async -> Void = { _ in }
    public var resumeDownload: @Sendable (_ id: String) async -> Void = { _ in }
    public var getDownloadProgress: @Sendable (_ id: String) -> AsyncStream<Double> = { _ in .finished }
    public var getDownloadedMedia: @Sendable () async throws -> [OfflineMediaSnapshot]
    public var deleteDownloadedMedia: @Sendable (_ id: String) async throws -> Void
    public var deleteAllCompletedDownloads: @Sendable () async throws -> DownloadBulkDeleteResult
    public var isDownloaded: @Sendable (_ id: String) async throws -> Bool
    public var getActiveDownloads: @Sendable () async -> [DownloadProgressItem] = { [] }
    public var getDownloadsSnapshot: @Sendable () async throws -> DownloadLibrarySnapshot = { .init() }
    public var dismissFailedDownload: @Sendable (_ id: String) async throws -> Void = { _ in }
    public var observeDownloads: @Sendable () async -> AsyncStream<DownloadProgressItem> = { .finished }
    public var setConcurrencyLimit: @Sendable (_ value: Int) async -> Void = { _ in }
}

extension DownloadClient: DependencyKey {
    public static let liveValue: DownloadClient = .init(
        startDownload: { id, title, url, coverURL, userAgentOverride in
            try await DownloadManager.shared.startDownload(
                id: id, title: title, url: url, coverURL: coverURL,
                userAgentOverride: userAgentOverride
            )
        },
        cancelDownload: { id in
            await DownloadManager.shared.cancelDownload(id: id)
        },
        pauseDownload: { id in
            await DownloadManager.shared.pauseDownload(id: id)
        },
        resumeDownload: { id in
            await DownloadManager.shared.resumeDownload(id: id)
        },
        getDownloadProgress: { id in
            AsyncStream { continuation in
                let task = Task {
                    let stream = await DownloadManager.shared.getProgressStream(id: id)
                    for await value in stream {
                        guard !Task.isCancelled else { break }
                        continuation.yield(value)
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        },
        getDownloadedMedia: {
            try await DownloadManager.shared.getDownloadedMedia()
        },
        deleteDownloadedMedia: { id in
            try await DownloadManager.shared.deleteDownloadedMedia(id: id)
        },
        deleteAllCompletedDownloads: {
            try await DownloadManager.shared.deleteAllCompletedDownloads()
        },
        isDownloaded: { id in
            let downloaded = try await DownloadManager.shared.getDownloadedMedia()
            return downloaded.contains(where: { $0.id == id && $0.isAvailable })
        },
        getActiveDownloads: {
            await DownloadManager.shared.getActiveDownloads()
        },
        getDownloadsSnapshot: {
            try await DownloadManager.shared.getLibrarySnapshot()
        },
        dismissFailedDownload: { id in
            try await DownloadManager.shared.dismissFailedDownload(id: id)
        },
        observeDownloads: {
            await DownloadManager.shared.observeDownloads()
        },
        setConcurrencyLimit: { value in
            await DownloadManager.shared.setConcurrencyLimit(value)
        }
    )
}

public extension DependencyValues {
    var downloadClient: DownloadClient {
        get { self[DownloadClient.self] }
        set { self[DownloadClient.self] = newValue }
    }
}
