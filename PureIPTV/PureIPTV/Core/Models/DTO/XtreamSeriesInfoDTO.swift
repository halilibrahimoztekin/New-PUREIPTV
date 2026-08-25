import Foundation

public struct XtreamSeriesInfoDTO: Codable, Equatable {
    public let seasons: [XtreamSeasonDTO]?
    public let info: XtreamSeriesInfoDataDTO?
    public let episodes: [String: [XtreamEpisodeDTO]]?
}

public struct XtreamSeasonDTO: Codable, Equatable {
    public let airDate: String?
    public let episodeCount: Int?
    public let id: Int?
    public let name: String?
    public let overview: String?
    public let seasonNumber: Int?
    public let cover: String?
    public let coverBig: String?

    private enum CodingKeys: String, CodingKey {
        case airDate = "air_date"
        case episodeCount = "episode_count"
        case id
        case name
        case overview
        case seasonNumber = "season_number"
        case cover
        case coverBig = "cover_big"
    }
}

public struct XtreamEpisodeDTO: Codable, Equatable {
    public let id: String
    public let episodeNum: Int?
    public let title: String
    public let containerExtension: String
    public let info: XtreamEpisodeInfoDTO?
    public let customSid: String?
    public let added: String?
    public let season: Int?
    public let directSource: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case episodeNum = "episode_num"
        case title
        case containerExtension = "container_extension"
        case info
        case customSid = "custom_sid"
        case added
        case season
        case directSource = "direct_source"
    }
}

public struct XtreamEpisodeInfoDTO: Codable, Equatable {
    public let plot: String?
    public let duration: String?
    public let movieImage: String?
    public let bitrate: Int?
    public let rating: Double?
    public let releasedate: String?

    private enum CodingKeys: String, CodingKey {
        case plot
        case duration
        case movieImage = "movie_image"
        case bitrate
        case rating
        case releasedate
    }
}

public struct XtreamSeriesInfoDataDTO: Codable, Equatable {
    public let name: String?
    public let cover: String?
    public let plot: String?
    public let cast: String?
    public let director: String?
    public let genre: String?
    public let releaseDate: String?
    public let rating: String?
    public let rating5based: Double?

    private enum CodingKeys: String, CodingKey {
        case name
        case cover
        case plot
        case cast
        case director
        case genre
        case releaseDate
        case rating
        case rating5based = "rating_5based"
    }
}
