import Foundation

/// Represents a persistent record of a recently watched Live TV channel
public struct RecentChannelDTO: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let seriesTitle: String?
    public let streamURL: URL
    public let coverURL: URL?
    public let epgChannelID: String?
    public let categoryID: String?
    public let tvArchive: Int?
    public let lastWatchedAt: Date

    public nonisolated init(
        id: String,
        title: String,
        seriesTitle: String? = nil,
        streamURL: URL,
        coverURL: URL? = nil,
        epgChannelID: String? = nil,
        categoryID: String? = nil,
        tvArchive: Int? = nil,
        lastWatchedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.seriesTitle = seriesTitle
        self.streamURL = streamURL
        self.coverURL = coverURL
        self.epgChannelID = epgChannelID
        self.categoryID = categoryID
        self.tvArchive = tvArchive
        self.lastWatchedAt = lastWatchedAt
    }
}
