@preconcurrency import Foundation

public nonisolated struct TMDBSearchResponseDTO: Codable, Equatable, Sendable {
    public let page: Int?
    public let results: [TMDBMovieSearchResultDTO]?
    public let totalPages: Int?
    public let totalResults: Int?

    public init(
        page: Int? = 1,
        results: [TMDBMovieSearchResultDTO]? = [],
        totalPages: Int? = 1,
        totalResults: Int? = 0
    ) {
        self.page = page
        self.results = results
        self.totalPages = totalPages
        self.totalResults = totalResults
    }

    private enum CodingKeys: String, CodingKey {
        case page, results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

public nonisolated struct TMDBMovieDiscoveryResponseDTO: Codable, Equatable, Sendable {
    public let results: [TMDBMovieDiscoveryDTO]?

    public init(results: [TMDBMovieDiscoveryDTO]?) {
        self.results = results
    }
}

public nonisolated struct TMDBMovieDiscoveryDTO: Codable, Equatable, Sendable {
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

public nonisolated struct TMDBMovieSearchResultDTO: Codable, Equatable, Sendable {
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

public nonisolated struct TMDBImagesDTO: Codable, Equatable, Sendable {
    public let id: Int?
    public let backdrops: [TMDBImageAssetDTO]?
    public let logos: [TMDBImageAssetDTO]?
    public let posters: [TMDBImageAssetDTO]?

    public var preferredTitleLogoPath: String? {
        logos?
            .filter(\.isSupportedTitleLogo)
            .sorted { lhs, rhs in
                let leftLanguage = lhs.titleLogoLanguagePriority
                let rightLanguage = rhs.titleLogoLanguagePriority
                if leftLanguage != rightLanguage {
                    return leftLanguage < rightLanguage
                }
                if lhs.voteAverage != rhs.voteAverage {
                    return (lhs.voteAverage ?? 0) > (rhs.voteAverage ?? 0)
                }
                if lhs.voteCount != rhs.voteCount {
                    return (lhs.voteCount ?? 0) > (rhs.voteCount ?? 0)
                }
                return lhs.filePath < rhs.filePath
            }
            .first?
            .filePath
    }
}

public nonisolated struct TMDBImageAssetDTO: Codable, Equatable, Sendable {
    public let filePath: String
    public let fileType: String?
    public let iso6391: String?
    public let aspectRatio: Double?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let width: Int?
    public let height: Int?

    public var isSupportedTitleLogo: Bool {
        let path = filePath.lowercased()
        return path.hasSuffix(".png") || fileType?.lowercased() == "image/png"
    }

    fileprivate var titleLogoLanguagePriority: Int {
        switch iso6391?.lowercased() {
        case "tr": 0
        case "en": 1
        case nil: 2
        default: 3
        }
    }

    private enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case fileType = "file_type"
        case iso6391 = "iso_639_1"
        case aspectRatio = "aspect_ratio"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case width, height
    }
}

public nonisolated struct TMDBMovieDetailsDTO: Codable, Equatable, Sendable {
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
    public let images: TMDBImagesDTO?

    public var preferredTitleLogoPath: String? {
        images?.preferredTitleLogoPath
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, genres, credits, status, similar, videos, images
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case imdbId = "imdb_id"
        case productionCompanies = "production_companies"
        case productionCountries = "production_countries"
    }
}

public nonisolated struct TMDBWatchProvidersResponseDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let results: [String: TMDBWatchProviderRegionDTO]?

    public init(id: Int = 0, results: [String: TMDBWatchProviderRegionDTO]? = [:]) {
        self.id = id
        self.results = results
    }
}

public enum TMDBWatchAvailabilityRegionCode {
    public static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let code = value.uppercased()
        guard code.count == 2,
              code.unicodeScalars.allSatisfy({ (65 ... 90).contains($0.value) }) else { return nil }
        return code
    }
}

public nonisolated struct TMDBWatchProviderRegionDTO: Codable, Equatable, Sendable {
    public let link: String?
    public let flatrate: [TMDBWatchProviderDTO]?
    public let free: [TMDBWatchProviderDTO]?
    public let ads: [TMDBWatchProviderDTO]?
    public let rent: [TMDBWatchProviderDTO]?
    public let buy: [TMDBWatchProviderDTO]?

    public init(
        link: String? = nil,
        flatrate: [TMDBWatchProviderDTO]? = nil,
        free: [TMDBWatchProviderDTO]? = nil,
        ads: [TMDBWatchProviderDTO]? = nil,
        rent: [TMDBWatchProviderDTO]? = nil,
        buy: [TMDBWatchProviderDTO]? = nil
    ) {
        self.link = link
        self.flatrate = flatrate
        self.free = free
        self.ads = ads
        self.rent = rent
        self.buy = buy
    }
}

public nonisolated struct TMDBWatchProviderDTO: Codable, Equatable, Sendable, Identifiable {
    public let logoPath: String?
    public let providerID: Int
    public let providerName: String
    public let displayPriority: Int

    public var id: Int {
        providerID
    }

    private enum CodingKeys: String, CodingKey {
        case logoPath = "logo_path"
        case providerID = "provider_id"
        case providerName = "provider_name"
        case displayPriority = "display_priority"
    }

    public init(logoPath: String? = nil, providerID: Int, providerName: String, displayPriority: Int = 0) {
        self.logoPath = logoPath
        self.providerID = providerID
        self.providerName = providerName
        self.displayPriority = displayPriority
    }
}

public nonisolated struct TMDBVideosResponseDTO: Codable, Equatable, Sendable {
    public let results: [TMDBVideoDTO]?
}

public nonisolated struct TMDBVideoDTO: Codable, Equatable, Sendable {
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

public nonisolated struct TMDBGenreDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
}

public nonisolated struct TMDBCreditsDTO: Codable, Equatable, Sendable {
    public let cast: [TMDBCastMemberDTO]?
    public let crew: [TMDBCrewMemberDTO]?
}

public nonisolated struct TMDBCastMemberDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let character: String?
    public let profilePath: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }
}

public nonisolated struct TMDBPopularPeopleResponseDTO: Codable, Equatable, Sendable {
    public let results: [TMDBPopularPersonDTO]?
}

public nonisolated struct TMDBPersonSearchResponseDTO: Codable, Equatable, Sendable {
    public let results: [TMDBPersonSearchResultDTO]?
}

public nonisolated struct TMDBPersonSearchResultDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let profilePath: String?
    public let knownFor: [TMDBPersonKnownForDTO]?

    private enum CodingKeys: String, CodingKey {
        case id, name
        case profilePath = "profile_path"
        case knownFor = "known_for"
    }
}

public nonisolated struct TMDBPersonKnownForDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let mediaType: String?
    public let title: String?
    public let originalTitle: String?
    public let name: String?
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

public nonisolated struct TMDBPopularPersonDTO: Codable, Equatable, Sendable {
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

public nonisolated struct TMDBCrewMemberDTO: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let job: String?
    public let department: String?
}

public nonisolated struct TMDBPersonDetailsDTO: Codable, Equatable, Sendable {
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
public nonisolated struct TMDBPersonCreditsDTO: Codable, Equatable, Sendable {
    public let cast: [TMDBPersonCreditDTO]?
}

public nonisolated struct TMDBPersonCreditDTO: Codable, Equatable, Sendable {
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

public nonisolated struct TMDBTVDetailsDTO: Codable, Equatable, Sendable {
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
    public let images: TMDBImagesDTO?

    public var preferredTitleLogoPath: String? {
        images?.preferredTitleLogoPath
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, overview, genres, credits, status, similar, videos, images
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

public nonisolated struct TMDBProductionCompanyDTO: Codable, Equatable, Sendable {
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

public nonisolated struct TMDBProductionCountryDTO: Codable, Equatable, Sendable {
    public let iso3166_1: String
    public let name: String

    private enum CodingKeys: String, CodingKey {
        case iso3166_1 = "iso_3166_1"
        case name
    }
}

public nonisolated struct TMDBSimilarResponseDTO: Codable, Equatable, Sendable {
    public let results: [TMDBSimilarItemDTO]?
}

public nonisolated struct TMDBSimilarItemDTO: Codable, Equatable, Sendable {
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
