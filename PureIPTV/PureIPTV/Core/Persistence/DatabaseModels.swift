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
    public var id: String = "" // Legacy type/category ID or a scoped v2 ID.
    public var type: String = "" // "live", "vod", "series"
    public var categoryID: String = ""
    public var profileID: UUID?
    public var playlistID: UUID?
    public var isHidden: Bool = false
    public var isLocked: Bool = false
    public var orderIndex: Int = 0

    public init(
        id: String,
        type: String,
        categoryID: String,
        profileID: UUID? = nil,
        playlistID: UUID? = nil,
        isHidden: Bool,
        isLocked: Bool = false,
        orderIndex: Int
    ) {
        self.id = id
        self.type = type
        self.categoryID = categoryID
        self.profileID = profileID
        self.playlistID = playlistID
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

    public var scopedIdentity: FavoriteIdentity {
        FavoriteIdentity(type: type, playlistID: playlistID, id: id)
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

    public var compositeID: String {
        "\(type)|\(playlistID?.uuidString ?? "")|\(id)"
    }
}

/// Stable identity for a user-hidden VOD or series across playlists.
public nonisolated struct HiddenMediaIdentity: Hashable, Sendable {
    public let type: String
    public let playlistID: UUID?
    public let mediaID: String

    public init(type: String, playlistID: UUID?, mediaID: String) {
        self.type = type.lowercased()
        self.playlistID = playlistID
        self.mediaID = mediaID
    }

    public init(item: MediaModels.Item, fallbackPlaylistID: UUID? = nil) {
        self.init(
            type: item.type.rawValue,
            playlistID: item.playlistID ?? fallbackPlaylistID,
            mediaID: item.id
        )
    }

    public var storageKey: String {
        [type, playlistID?.uuidString ?? "", mediaID]
            .map { "\($0.utf8.count):\($0)" }
            .joined()
    }
}

/// Value passed between features and the persistence client.
public struct HiddenMediaEntry: Identifiable, Equatable, Hashable, Sendable {
    public let identity: HiddenMediaIdentity
    public let title: String
    public let hiddenAt: Date

    public var id: String {
        identity.storageKey
    }

    public init(identity: HiddenMediaIdentity, title: String, hiddenAt: Date = Date()) {
        self.identity = identity
        self.title = title
        self.hiddenAt = hiddenAt
    }

    public init(item: MediaModels.Item, fallbackPlaylistID: UUID? = nil, hiddenAt: Date = Date()) {
        self.init(
            identity: HiddenMediaIdentity(item: item, fallbackPlaylistID: fallbackPlaylistID),
            title: item.title,
            hiddenAt: hiddenAt
        )
    }
}

/// Soft-deleted rows preserve the user's hide/restore choice across CloudKit sync.
@Model
public final class HiddenMediaRecord {
    public var identityKey: String = ""
    public var mediaID: String = ""
    public var type: String = "" // "vod" or "series"
    public var title: String = ""
    public var playlistID: UUID?
    public var profileID: UUID?
    public var hiddenAt: Date = Date()
    public var removedAt: Date?

    public init(entry: HiddenMediaEntry, profileID: UUID?, removedAt: Date? = nil) {
        identityKey = entry.identity.storageKey
        mediaID = entry.identity.mediaID
        type = entry.identity.type
        title = entry.title
        playlistID = entry.identity.playlistID
        self.profileID = profileID
        hiddenAt = entry.hiddenAt
        self.removedAt = removedAt
    }
}

extension Notification.Name {
    static let hiddenMediaDidChange = Notification.Name("com.pureiptv.notification.hiddenMediaDidChange")
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
