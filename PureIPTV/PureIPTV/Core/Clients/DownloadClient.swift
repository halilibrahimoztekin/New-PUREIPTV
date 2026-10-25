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

@DependencyClient
public struct DownloadClient {
    public var startDownload: @Sendable (_ id: String, _ title: String, _ url: URL, _ coverURL: URL?, _ userAgentOverride: String?) async throws -> Void
    public var cancelDownload: @Sendable (_ id: String) async throws -> Void
    public var pauseDownload: @Sendable (_ id: String) async -> Void = { _ in }
    public var resumeDownload: @Sendable (_ id: String) async -> Void = { _ in }
    public var getDownloadProgress: @Sendable (_ id: String) -> AsyncStream<Double> = { _ in .finished }
    public var getDownloadedMedia: @Sendable () async throws -> [OfflineMedia]
    public var deleteDownloadedMedia: @Sendable (_ id: String) async throws -> Void
    public var deleteAllCompletedDownloads: @Sendable () async throws -> DownloadBulkDeleteResult
    public var isDownloaded: @Sendable (_ id: String) async throws -> Bool
    public var getActiveDownloads: @Sendable () async -> [DownloadProgressItem] = { [] }
    public var observeDownloads: @Sendable () -> AsyncStream<DownloadProgressItem> = { .finished }
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
                Task {
                    let stream = await DownloadManager.shared.getProgressStream(id: id)
                    for await value in stream {
                        continuation.yield(value)
                    }
                }
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
            return downloaded.contains(where: { $0.id == id })
        },
        getActiveDownloads: {
            await DownloadManager.shared.getActiveDownloads()
        },
        observeDownloads: {
            AsyncStream { continuation in
                Task {
                    let stream = await DownloadManager.shared.observeDownloads()
                    for await item in stream {
                        continuation.yield(item)
                    }
                }
            }
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
