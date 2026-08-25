import Foundation

public struct XtreamEpisodeModel: Identifiable, Equatable {
    public let id: String
    public let episodeNum: Int
    public let title: String
    public let containerExtension: String
    public let plot: String?
    public let duration: String?
    public let coverURL: URL?
    public let season: Int

    public var streamURL: URL?

    public init(
        id: String,
        episodeNum: Int,
        title: String,
        containerExtension: String,
        plot: String? = nil,
        duration: String? = nil,
        coverURL: URL? = nil,
        season: Int,
        streamURL: URL? = nil
    ) {
        self.id = id
        self.episodeNum = episodeNum
        self.title = title
        self.containerExtension = containerExtension
        self.plot = plot
        self.duration = duration
        self.coverURL = coverURL
        self.season = season
        self.streamURL = streamURL
    }
}
