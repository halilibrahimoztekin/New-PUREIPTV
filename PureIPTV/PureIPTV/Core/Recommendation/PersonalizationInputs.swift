import Foundation

/// Immutable snapshot of the watch-history fields used by dashboard discovery.
/// SwiftData models stay on their owning actor; only these values cross into
/// concurrent recommendation work.
public nonisolated struct PersonalizationHistoryEntry: Sendable {
    public let id: String
    public let type: String
    public let title: String
    public let seriesTitle: String?
    public let progress: Double
    public let duration: Double
    public let lastWatchedAt: Date
    public let playlistID: UUID?
    public let seriesID: String?

    public init(_ item: WatchHistoryItem) {
        id = item.id
        type = item.type
        title = item.title
        seriesTitle = item.seriesTitle
        progress = item.progress
        duration = item.duration
        lastWatchedAt = item.lastWatchedAt
        playlistID = item.playlistID
        seriesID = item.seriesID
    }
}

/// Immutable snapshot of the favorite fields used by dashboard discovery.
public nonisolated struct PersonalizationFavoriteEntry: Sendable {
    public let id: String
    public let type: String
    public let playlistID: UUID?

    public init(_ item: FavoriteItem) {
        id = item.id
        type = item.type
        playlistID = item.playlistID
    }
}
