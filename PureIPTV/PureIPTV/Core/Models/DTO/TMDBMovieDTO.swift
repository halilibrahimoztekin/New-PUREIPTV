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

public struct TMDBMovieDiscoveryResponseDTO: Codable, Equatable, Sendable {
    public let results: [TMDBMovieDiscoveryDTO]?

    public init(results: [TMDBMovieDiscoveryDTO]?) {
        self.results = results
    }
}

public struct TMDBMovieDiscoveryDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let title: String?
    public let originalTitle: String?
    public let releaseDate: String?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let adult: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, title, adult
        case originalTitle = "original_title"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
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
    public let videos: TMDBVideosResponseDTO?

    private enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres, credits, status, similar, videos
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case imdbId = "imdb_id"
        case productionCompanies = "production_companies"
        case productionCountries = "production_countries"
    }
}

public struct TMDBVideosResponseDTO: Codable, Equatable, Sendable {
    public let results: [TMDBVideoDTO]?
}

public struct TMDBVideoDTO: Codable, Equatable, Sendable {
    public let id: String
    public let key: String
    public let name: String?
    public let site: String?
    public let type: String?
    public let size: Int?

    public init(id: String, key: String, name: String? = nil, site: String? = nil, type: String? = nil, size: Int? = nil) {
        self.id = id
        self.key = key
        self.name = name
        self.site = site
        self.type = type
        self.size = size
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

public struct TMDBPopularPeopleResponseDTO: Codable, Equatable, Sendable {
    public let results: [TMDBPopularPersonDTO]?
}

public struct TMDBPopularPersonDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let profilePath: String?
    public let knownForDepartment: String?

    private enum CodingKeys: String, CodingKey {
        case id, name
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
    }
}

public struct TMDBCrewMemberDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let job: String?
    public let department: String?
}

public struct TMDBPersonDetailsDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let biography: String?
    public let birthday: String?
    public let deathday: String?
    public let placeOfBirth: String?
    public let profilePath: String?
    public let knownForDepartment: String?

    public init(
        id: Int,
        name: String? = nil,
        biography: String? = nil,
        birthday: String? = nil,
        deathday: String? = nil,
        placeOfBirth: String? = nil,
        profilePath: String? = nil,
        knownForDepartment: String? = nil
    ) {
        self.id = id
        self.name = name
        self.biography = biography
        self.birthday = birthday
        self.deathday = deathday
        self.placeOfBirth = placeOfBirth
        self.profilePath = profilePath
        self.knownForDepartment = knownForDepartment
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, biography, birthday, deathday
        case placeOfBirth = "place_of_birth"
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
    }
}

/// Combined film and television credits for an actor, used only to intersect
/// known credits with the active provider catalogue.
public struct TMDBPersonCreditsDTO: Codable, Equatable, Sendable {
    public let cast: [TMDBPersonCreditDTO]?
}

public struct TMDBPersonCreditDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let mediaType: String?
    public let title: String?
    public let name: String?
    public let originalTitle: String?
    public let originalName: String?
    public let releaseDate: String?
    public let firstAirDate: String?

    private enum CodingKeys: String, CodingKey {
        case id, title, name
        case mediaType = "media_type"
        case originalTitle = "original_title"
        case originalName = "original_name"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
    }
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
    public let videos: TMDBVideosResponseDTO?

    private enum CodingKeys: String, CodingKey {
        case id, name, overview, genres, credits, status, similar, videos
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
    public let originalTitle: String?
    public let originalName: String?
    public let overview: String?
    public let posterPath: String?
    public let backdropPath: String?
    public let releaseDate: String?
    public let firstAirDate: String?
    public let voteAverage: Double?

    public init(
        id: Int,
        title: String? = nil,
        name: String? = nil,
        originalTitle: String? = nil,
        originalName: String? = nil,
        overview: String? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        releaseDate: String? = nil,
        firstAirDate: String? = nil,
        voteAverage: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.name = name
        self.originalTitle = originalTitle
        self.originalName = originalName
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.releaseDate = releaseDate
        self.firstAirDate = firstAirDate
        self.voteAverage = voteAverage
    }

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
