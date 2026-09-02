import Foundation

public struct XtreamVODInfoDTO: Codable, Equatable, Sendable {
    public let info: XtreamVODInfoDataDTO?
    public let movieData: XtreamVODMovieDataDTO?

    private enum CodingKeys: String, CodingKey {
        case info
        case movieData = "movie_data"
    }
}

public struct XtreamVODInfoDataDTO: Codable, Equatable, Sendable {
    public let tmdbId: String?
    public let name: String?
    public let movieImage: String?
    public let description: String?
    public let plot: String?
    public let cast: String?
    public let director: String?
    public let genre: String?
    public let releaseDate: String?
    public let rating: String?
    public let rating5based: Double?
    public let youtubeTrailer: String?
    public let duration: String?

    private enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case name
        case movieImage = "movie_image"
        case description
        case plot
        case cast
        case director
        case genre
        case releaseDate = "release_date"
        case rating
        case rating5based = "rating_5based"
        case youtubeTrailer = "youtube_trailer"
        case duration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try? container.decodeIfPresent(String.self, forKey: .name)
        movieImage = try? container.decodeIfPresent(String.self, forKey: .movieImage)
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        plot = try? container.decodeIfPresent(String.self, forKey: .plot)
        cast = try? container.decodeIfPresent(String.self, forKey: .cast)
        director = try? container.decodeIfPresent(String.self, forKey: .director)
        genre = try? container.decodeIfPresent(String.self, forKey: .genre)
        releaseDate = try? container.decodeIfPresent(String.self, forKey: .releaseDate)
        youtubeTrailer = try? container.decodeIfPresent(String.self, forKey: .youtubeTrailer)
        duration = try? container.decodeIfPresent(String.self, forKey: .duration)

        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .tmdbId) {
            tmdbId = String(intVal)
        } else {
            tmdbId = try? container.decodeIfPresent(String.self, forKey: .tmdbId)
        }

        if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .rating) {
            rating = String(doubleVal)
        } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .rating) {
            rating = String(intVal)
        } else {
            rating = try? container.decodeIfPresent(String.self, forKey: .rating)
        }

        if let strVal = try? container.decodeIfPresent(String.self, forKey: .rating5based), let doubleVal = Double(strVal) {
            rating5based = doubleVal
        } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .rating5based) {
            rating5based = Double(intVal)
        } else {
            rating5based = try? container.decodeIfPresent(Double.self, forKey: .rating5based)
        }
    }
}

public struct XtreamVODMovieDataDTO: Codable, Equatable, Sendable {
    public let streamId: Int
    public let name: String?
    public let containerExtension: String?

    private enum CodingKeys: String, CodingKey {
        case streamId = "stream_id"
        case name
        case containerExtension = "container_extension"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .streamId) {
            streamId = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .streamId), let intVal = Int(strVal) {
            streamId = intVal
        } else {
            streamId = 0
        }
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        containerExtension = try? container.decodeIfPresent(String.self, forKey: .containerExtension)
    }
}
