import Foundation
import SwiftData

/// Stable in-memory identity for a favorite across playlists and media kinds.
public struct FavoriteIdentity: Hashable, Sendable {
    public let type: String
    public let playlistID: UUID?
    public let id: String

    public init(type: String, playlistID: UUID?, id: String) {
        self.type = type
        self.playlistID = playlistID
        self.id = id
    }

    public init(_ favorite: FavoriteItem) {
        self.init(type: favorite.type, playlistID: favorite.playlistID, id: favorite.id)
    }
}

/// Represents user preferences for a specific category (hidden status, custom sort order).
@Model
public final class CategoryPreference {
    public var id: String = "" // e.g. "live_123" (type_categoryID)
    public var type: String = "" // "live", "vod", "series"
    public var categoryID: String = ""
    public var isHidden: Bool = false
    public var isLocked: Bool = false
    public var orderIndex: Int = 0

    public init(id: String, type: String, categoryID: String, isHidden: Bool, isLocked: Bool = false, orderIndex: Int) {
        self.id = id
        self.type = type
        self.categoryID = categoryID
        self.isHidden = isHidden
        self.isLocked = isLocked
        self.orderIndex = orderIndex
    }
}

/// Represents a media item (Live TV, VOD, Series) that the user has favorited.
@Model
public final class FavoriteItem {
    public var id: String = ""
    public var type: String = "" // "live", "vod", "series"
    public var title: String = ""
    public var coverURL: String?
    public var streamURL: String?
    public var addedAt: Date = Date()
    public var playlistID: UUID?
    public var profileID: UUID?
    /// Soft deletion keeps CloudKit and legacy profile-less rows recoverable.
    public var removedAt: Date?

    public init(
        id: String,
        type: String,
        title: String,
        coverURL: String? = nil,
        streamURL: String? = nil,
        addedAt: Date = Date(),
        playlistID: UUID? = nil,
        profileID: UUID? = nil,
        removedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.coverURL = coverURL
        self.streamURL = streamURL
        self.addedAt = addedAt
        self.playlistID = playlistID
        self.profileID = profileID
        self.removedAt = removedAt
    }
}

/// Represents the watch progress of a VOD or Episode.
@Model
public final class WatchHistoryItem {
    public var id: String = "" // The unique identifier of the playable item (stream ID or episode ID)
    public var type: String = "" // "vod", "episode"
    public var title: String = ""
    public var seriesTitle: String?
    public var coverURL: String?
    public var streamURL: String?
    public var progress: Double = 0.0 // in seconds
    public var duration: Double = 0.0 // in seconds
    public var lastWatchedAt: Date = Date()
    public var playlistID: UUID?
    public var seriesID: String?
    public var profileID: UUID?
    /// Soft deletion preserves prior history and sync tombstone identity.
    public var removedAt: Date?

    public init(
        id: String,
        type: String,
        title: String,
        seriesTitle: String? = nil,
        coverURL: String? = nil,
        streamURL: String? = nil,
        progress: Double,
        duration: Double,
        lastWatchedAt: Date = Date(),
        playlistID: UUID? = nil,
        seriesID: String? = nil,
        profileID: UUID? = nil,
        removedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.seriesTitle = seriesTitle
        self.coverURL = coverURL
        self.streamURL = streamURL
        self.progress = progress
        self.duration = duration
        self.lastWatchedAt = lastWatchedAt
        self.playlistID = playlistID
        self.seriesID = seriesID
        self.profileID = profileID
        self.removedAt = removedAt
    }
}

/// Represents a search query in history
@Model
public final class SearchHistoryItem {
    @Attribute(.unique) public var query: String
    public var timestamp: Date = Date()

    public init(query: String, timestamp: Date = Date()) {
        self.query = query
        self.timestamp = timestamp
    }
}
