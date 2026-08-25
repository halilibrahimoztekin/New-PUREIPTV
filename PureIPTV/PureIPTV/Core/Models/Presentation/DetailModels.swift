import Foundation

public enum DetailModels {
    public struct Info: Equatable {
        public let plot: String?
        public let cast: String?
        public let director: String?
        public let genre: String? // Will hold Xtream genres
        public let duration: String?
        public let tmdbId: Int?
        public let rating: Double?
        public let releaseDate: String?

        // New Rich UI fields
        public let genresList: [String]? // TMDB genres
        public let status: String?
        public let imdbId: String? // For movies
        public let productionCountries: [String]?
        public let productionCompanies: [String]?
        public let similarItems: [SimilarItem]?

        public init(
            plot: String? = nil,
            cast: String? = nil,
            director: String? = nil,
            genre: String? = nil,
            duration: String? = nil,
            tmdbId: Int? = nil,
            rating: Double? = nil,
            releaseDate: String? = nil,
            genresList: [String]? = nil,
            status: String? = nil,
            imdbId: String? = nil,
            productionCountries: [String]? = nil,
            productionCompanies: [String]? = nil,
            similarItems: [SimilarItem]? = nil
        ) {
            self.plot = plot
            self.cast = cast
            self.director = director
            self.genre = genre
            self.duration = duration
            self.tmdbId = tmdbId
            self.rating = rating
            self.releaseDate = releaseDate
            self.genresList = genresList
            self.status = status
            self.imdbId = imdbId
            self.productionCountries = productionCountries
            self.productionCompanies = productionCompanies
            self.similarItems = similarItems
        }
    }

    public struct SimilarItem: Equatable, Identifiable {
        public let id: String
        public let title: String
        public let coverURL: URL?

        public init(id: String, title: String, coverURL: URL? = nil) {
            self.id = id
            self.title = title
            self.coverURL = coverURL
        }
    }

    public struct Season: Equatable, Identifiable {
        public let id: String
        public let seasonNumber: Int
        public let name: String
        public let episodeCount: Int?

        public init(id: String, seasonNumber: Int, name: String, episodeCount: Int? = nil) {
            self.id = id
            self.seasonNumber = seasonNumber
            self.name = name
            self.episodeCount = episodeCount
        }
    }

    public struct Episode: Equatable, Identifiable {
        public let id: String
        public let episodeNum: Int
        public let title: String
        public let streamURL: URL
        public let coverURL: URL?
        public let season: Int
        public let duration: String?
        public let plot: String?
        public let rating: Double?

        public init(
            id: String,
            episodeNum: Int,
            title: String,
            streamURL: URL,
            coverURL: URL? = nil,
            season: Int,
            duration: String? = nil,
            plot: String? = nil,
            rating: Double? = nil
        ) {
            self.id = id
            self.episodeNum = episodeNum
            self.title = title
            self.streamURL = streamURL
            self.coverURL = coverURL
            self.season = season
            self.duration = duration
            self.plot = plot
            self.rating = rating
        }
    }
}
