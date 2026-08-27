import Foundation
import SwiftData

/// Represents user preferences for a specific category (hidden status, custom sort order).
@Model
public final class CategoryPreference {
    public var id: String // e.g. "live_123" (type_categoryID)
    public var type: String // "live", "vod", "series"
    public var categoryID: String
    public var isHidden: Bool
    public var orderIndex: Int

    public init(id: String, type: String, categoryID: String, isHidden: Bool, orderIndex: Int) {
        self.id = id
        self.type = type
        self.categoryID = categoryID
        self.isHidden = isHidden
        self.orderIndex = orderIndex
    }
}

/// Represents a media item (Live TV, VOD, Series) that the user has favorited.
@Model
public final class FavoriteItem {
    public var id: String
    public var type: String // "live", "vod", "series"
    public var title: String
    public var coverURL: String?
    public var streamURL: String?
    public var addedAt: Date
    public var playlistID: UUID?

    public init(
        id: String,
        type: String,
        title: String,
        coverURL: String? = nil,
        streamURL: String? = nil,
        addedAt: Date = Date(),
        playlistID: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.coverURL = coverURL
        self.streamURL = streamURL
        self.addedAt = addedAt
        self.playlistID = playlistID
    }
}

/// Represents the watch progress of a VOD or Episode.
@Model
public final class WatchHistoryItem {
    public var id: String // The unique identifier of the playable item (stream ID or episode ID)
    public var type: String // "vod", "episode"
    public var title: String
    public var seriesTitle: String?
    public var coverURL: String?
    public var streamURL: String?
    public var progress: Double // in seconds
    public var duration: Double // in seconds
    public var lastWatchedAt: Date
    public var playlistID: UUID?
    public var seriesID: String?

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
        seriesID: String? = nil
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
    }
}
