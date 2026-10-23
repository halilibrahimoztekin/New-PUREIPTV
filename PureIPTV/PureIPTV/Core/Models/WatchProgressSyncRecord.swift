import Foundation
import SwiftData

/// Represents a cross-device synchronized watch progress record (Madde #43).
public nonisolated struct WatchProgressSyncRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let type: String
    public let title: String
    public let seriesTitle: String?
    public let coverURL: String?
    public let streamURL: String?
    public let progress: Double
    public let duration: Double
    public let lastWatchedAt: Date
    public let playlistID: UUID?
    public let seriesID: String?
    public let deviceId: String?
    public let isDeleted: Bool?

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
        deviceId: String? = nil,
        isDeleted: Bool? = false
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
        self.deviceId = deviceId
        self.isDeleted = isDeleted
    }

    public init(from item: WatchHistoryItem, deviceId: String? = nil) {
        id = item.id
        type = item.type
        title = item.title
        seriesTitle = item.seriesTitle
        coverURL = item.coverURL
        streamURL = item.streamURL
        progress = item.progress
        duration = item.duration
        lastWatchedAt = item.lastWatchedAt
        playlistID = item.playlistID
        seriesID = item.seriesID
        self.deviceId = deviceId
        isDeleted = false
    }

    public func toWatchHistoryItem() -> WatchHistoryItem {
        WatchHistoryItem(
            id: id,
            type: type,
            title: title,
            seriesTitle: seriesTitle,
            coverURL: coverURL,
            streamURL: streamURL,
            progress: progress,
            duration: duration,
            lastWatchedAt: lastWatchedAt,
            playlistID: playlistID,
            seriesID: seriesID
        )
    }

    public func apply(to item: WatchHistoryItem) {
        item.type = type
        item.title = title
        if let seriesTitle {
            item.seriesTitle = seriesTitle
        }
        if let coverURL {
            item.coverURL = coverURL
        }
        if let streamURL {
            item.streamURL = streamURL
        }
        item.progress = progress
        item.duration = duration
        item.lastWatchedAt = lastWatchedAt
        if let playlistID {
            item.playlistID = playlistID
        }
        if let seriesID {
            item.seriesID = seriesID
        }
    }
}

public extension Notification.Name {
    /// Broadcast when watch progress history is updated remotely via iCloud sync or locally.
    static let watchHistoryDidChange = Notification.Name("com.pureiptv.notification.watchHistoryDidChange")
}
