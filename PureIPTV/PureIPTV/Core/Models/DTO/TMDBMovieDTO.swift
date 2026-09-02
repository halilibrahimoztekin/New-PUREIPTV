@preconcurrency import Foundation

public struct TMDBSearchResponseDTO: Codable, Equatable, Sendable {
    public let page: Int?
    public let results: [TMDBMovieSearchResultDTO]?
    public let totalPages: Int?
    public let totalResults: Int?

    private enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

public struct TMDBMovieSearchResultDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let title: String? // For movies
    public let name: String? // For TV
    public let originalTitle: String?
    public let originalName: String? // For TV
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: String? // For movies
    public let firstAirDate: String? // For TV
    public let voteAverage: Double?

    private enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case originalTitle = "original_title"
        case originalName = "original_name"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
    }
}

public struct TMDBMovieDetailsDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let title: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: String?
    public let voteAverage: Double?
    public let runtime: Int?
    public let genres: [TMDBGenreDTO]?
    public let credits: TMDBCreditsDTO?
    public let imdbId: String?
    public let status: String?
    public let productionCompanies: [TMDBProductionCompanyDTO]?
    public let productionCountries: [TMDBProductionCountryDTO]?
    public let similar: TMDBSimilarResponseDTO?

    private enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres, credits, status, similar
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case imdbId = "imdb_id"
        case productionCompanies = "production_companies"
        case productionCountries = "production_countries"
    }
}

public struct TMDBGenreDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
}

public struct TMDBCreditsDTO: Codable, Equatable, Sendable {
    public let cast: [TMDBCastMemberDTO]?
    public let crew: [TMDBCrewMemberDTO]?
}

public struct TMDBCastMemberDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let character: String?
    public let profilePath: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }
}

public struct TMDBCrewMemberDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let job: String?
    public let department: String?
}

public struct TMDBTVDetailsDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let firstAirDate: String?
    public let voteAverage: Double?
    public let genres: [TMDBGenreDTO]?
    public let credits: TMDBCreditsDTO?
    public let numberOfEpisodes: Int?
    public let numberOfSeasons: Int?
    public let status: String?
    public let productionCompanies: [TMDBProductionCompanyDTO]?
    public let productionCountries: [TMDBProductionCountryDTO]?
    public let similar: TMDBSimilarResponseDTO?

    private enum CodingKeys: String, CodingKey {
        case id, name, overview, genres, credits, status, similar
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case numberOfEpisodes = "number_of_episodes"
        case numberOfSeasons = "number_of_seasons"
        case productionCompanies = "production_companies"
        case productionCountries = "production_countries"
    }
}

public struct TMDBProductionCompanyDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let logoPath: String?
    public let originCountry: String?

    private enum CodingKeys: String, CodingKey {
        case id, name
        case logoPath = "logo_path"
        case originCountry = "origin_country"
    }
}

public struct TMDBProductionCountryDTO: Codable, Equatable, Sendable {
    public let iso3166_1: String
    public let name: String

    private enum CodingKeys: String, CodingKey {
        case iso3166_1 = "iso_3166_1"
        case name
    }
}

public struct TMDBSimilarResponseDTO: Codable, Equatable, Sendable {
    public let results: [TMDBSimilarItemDTO]?
}

public struct TMDBSimilarItemDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let title: String? // Movie
    public let name: String? // TV
    public let posterPath: String?

    private enum CodingKeys: String, CodingKey {
        case id, title, name
        case posterPath = "poster_path"
    }
}
