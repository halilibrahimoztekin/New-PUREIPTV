import ComposableArchitecture
import Foundation

@DependencyClient
public struct DownloadClient {
    public var startDownload: @Sendable (_ id: String, _ title: String, _ url: URL, _ coverURL: URL?) async throws -> Void
    public var cancelDownload: @Sendable (_ id: String) async throws -> Void
    public var getDownloadProgress: @Sendable (_ id: String) -> AsyncStream<Double> = { _ in .finished }
    public var getDownloadedMedia: @Sendable () async throws -> [OfflineMedia]
    public var deleteDownloadedMedia: @Sendable (_ id: String) async throws -> Void
    public var isDownloaded: @Sendable (_ id: String) async throws -> Bool
}

extension DownloadClient: DependencyKey {
    public static let liveValue: DownloadClient = .init(
        startDownload: { id, title, url, coverURL in
            try await DownloadManager.shared.startDownload(id: id, title: title, url: url, coverURL: coverURL)
        },
        cancelDownload: { id in
            await DownloadManager.shared.cancelDownload(id: id)
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
        isDownloaded: { id in
            let downloaded = try await DownloadManager.shared.getDownloadedMedia()
            return downloaded.contains(where: { $0.id == id })
        }
    )
}

public extension DependencyValues {
    var downloadClient: DownloadClient {
        get { self[DownloadClient.self] }
        set { self[DownloadClient.self] = newValue }
    }
}
