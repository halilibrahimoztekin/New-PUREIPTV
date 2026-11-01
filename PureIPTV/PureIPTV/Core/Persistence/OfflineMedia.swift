import Foundation
import SwiftData

@Model
public final class OfflineMedia {
    public var id: String = "" // VOD ID or Episode ID
    public var title: String = ""
    public var localFilePath: String = ""
    public var coverURL: String?
    public var userAgentOverride: String?
    public var episodeSeriesID: String?
    public var episodeSeriesTitle: String?
    public var episodeSeasonNumber: Int?
    public var episodeNumber: Int?
    public var episodeOrdinal: Int?
    public var episodePlaylistID: UUID?
    public var downloadedAt: Date = Date()
    public var fileSize: Int64 = 0

    public init(
        id: String,
        title: String,
        localFilePath: String,
        coverURL: String?,
        fileSize: Int64,
        userAgentOverride: String? = nil,
        episodeMetadata: OfflineEpisodeMetadata? = nil
    ) {
        self.id = id
        self.title = title
        self.localFilePath = localFilePath
        self.coverURL = coverURL
        self.userAgentOverride = userAgentOverride
        episodeSeriesID = episodeMetadata?.seriesID
        episodeSeriesTitle = episodeMetadata?.seriesTitle
        episodeSeasonNumber = episodeMetadata?.seasonNumber
        episodeNumber = episodeMetadata?.episodeNumber
        episodeOrdinal = episodeMetadata?.episodeOrdinal
        episodePlaylistID = episodeMetadata?.playlistID
        self.fileSize = fileSize
        downloadedAt = Date()
    }
}
