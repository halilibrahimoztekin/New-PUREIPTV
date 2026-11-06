import ComposableArchitecture
@preconcurrency import Foundation

@DependencyClient
public struct TMDBClient {
    public var searchMovie: @Sendable (_ query: String) async throws -> TMDBSearchResponseDTO
    public var discoverMovies: @Sendable (_ sortBy: String, _ minimumVoteCount: Int, _ page: Int) async throws -> TMDBMovieDiscoveryResponseDTO
    public var fetchMovieImages: @Sendable (_ movieID: Int) async throws -> TMDBImagesDTO
    public var fetchMovieDetails: @Sendable (_ movieID: Int) async throws -> TMDBMovieDetailsDTO
    public var fetchMovieWatchProviders: @Sendable (_ movieID: Int) async throws -> TMDBWatchProvidersResponseDTO
    public var searchTV: @Sendable (_ query: String) async throws -> TMDBSearchResponseDTO // Reusing search response DTO, we can add a new one if fields differ significantly, but TMDB search tv returns similar structure
    public var fetchTVImages: @Sendable (_ tvID: Int) async throws -> TMDBImagesDTO
    public var fetchTVDetails: @Sendable (_ tvID: Int) async throws -> TMDBTVDetailsDTO
    public var fetchTVWatchProviders: @Sendable (_ tvID: Int) async throws -> TMDBWatchProvidersResponseDTO
    public var fetchPersonDetails: @Sendable (_ personID: Int) async throws -> TMDBPersonDetailsDTO
    public var fetchPersonCombinedCredits: @Sendable (_ personID: Int) async throws -> TMDBPersonCreditsDTO
    public var fetchPopularPeople: @Sendable () async throws -> TMDBPopularPeopleResponseDTO
    public var searchPeople: @Sendable (_ query: String) async throws -> TMDBPersonSearchResponseDTO
    public var validateAPIKey: @Sendable (_ apiKey: String) async throws -> Void
}

extension TMDBClient: DependencyKey {
    public nonisolated static let liveValue: TMDBClient = {
        let networkClient = NetworkClient()
        let baseURLString = "https://api.themoviedb.org/3"
        let apiKeyProvider: @Sendable () async throws -> String = {
            try await TMDBAPIKeyStore.shared.effectiveAPIKey()
        }

        return TMDBClient(
            searchMovie: { query in
                let apiKey = try await apiKeyProvider()
                guard var components = URLComponents(string: "\(baseURLString)/search/movie") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "query", value: query),
                    URLQueryItem(name: "include_adult", value: "false"),
                    URLQueryItem(name: "page", value: "1"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBSearchResponseDTO.self, from: data)
            },
            discoverMovies: { sortBy, minimumVoteCount, page in
                let apiKey = try await apiKeyProvider()
                guard var components = URLComponents(string: "\(baseURLString)/discover/movie") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "sort_by", value: sortBy),
                    URLQueryItem(name: "vote_count.gte", value: String(max(0, minimumVoteCount))),
                    URLQueryItem(name: "include_adult", value: "false"),
                    URLQueryItem(name: "page", value: String(max(1, page))),
                ]
                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBMovieDiscoveryResponseDTO.self, from: data)
            },
            fetchMovieImages: { movieID in
                let apiKey = try await apiKeyProvider()
                guard var components = URLComponents(string: "\(baseURLString)/movie/\(movieID)/images") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "include_image_language", value: "tr,en,null"),
                ]
                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBImagesDTO.self, from: data)
            },
            fetchMovieDetails: { movieID in
                let apiKey = try await apiKeyProvider()
                guard var components = URLComponents(string: "\(baseURLString)/movie/\(movieID)") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "append_to_response", value: "credits,similar,videos,images"),
                    URLQueryItem(name: "include_image_language", value: "tr,en,null"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBMovieDetailsDTO.self, from: data)
            },
            fetchMovieWatchProviders: { movieID in
                let apiKey = try await apiKeyProvider()
                guard movieID > 0,
                      var components = URLComponents(string: "\(baseURLString)/movie/\(movieID)/watch/providers")
                else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBWatchProvidersResponseDTO.self, from: data)
            },
            searchTV: { query in
                let apiKey = try await apiKeyProvider()
                guard var components = URLComponents(string: "\(baseURLString)/search/tv") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "query", value: query),
                    URLQueryItem(name: "include_adult", value: "false"),
                    URLQueryItem(name: "page", value: "1"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBSearchResponseDTO.self, from: data)
            },
            fetchTVImages: { tvID in
                let apiKey = try await apiKeyProvider()
                guard var components = URLComponents(string: "\(baseURLString)/tv/\(tvID)/images") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "include_image_language", value: "tr,en,null"),
                ]
                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBImagesDTO.self, from: data)
            },
            fetchTVDetails: { tvID in
                let apiKey = try await apiKeyProvider()
                guard var components = URLComponents(string: "\(baseURLString)/tv/\(tvID)") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "append_to_response", value: "credits,similar,videos,images"),
                    URLQueryItem(name: "include_image_language", value: "tr,en,null"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBTVDetailsDTO.self, from: data)
            },
            fetchTVWatchProviders: { tvID in
                let apiKey = try await apiKeyProvider()
                guard tvID > 0,
                      var components = URLComponents(string: "\(baseURLString)/tv/\(tvID)/watch/providers")
                else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBWatchProvidersResponseDTO.self, from: data)
            },
            fetchPersonDetails: { personID in
                let apiKey = try await apiKeyProvider()
                guard var components = URLComponents(string: "\(baseURLString)/person/\(personID)") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBPersonDetailsDTO.self, from: data)
            },
            fetchPersonCombinedCredits: { personID in
                let apiKey = try await apiKeyProvider()
                guard var components = URLComponents(string: "\(baseURLString)/person/\(personID)/combined_credits") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBPersonCreditsDTO.self, from: data)
            },
            fetchPopularPeople: {
                let apiKey = try await apiKeyProvider()
                guard var components = URLComponents(string: "\(baseURLString)/person/popular") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "page", value: "1"),
                ]
                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBPopularPeopleResponseDTO.self, from: data)
            },
            searchPeople: { query in
                let apiKey = try await apiKeyProvider()
                guard var components = URLComponents(string: "\(baseURLString)/search/person") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "query", value: query),
                    URLQueryItem(name: "include_adult", value: "false"),
                    URLQueryItem(name: "page", value: "1"),
                ]
                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try JSONDecoder().decode(TMDBPersonSearchResponseDTO.self, from: data)
            },
            validateAPIKey: { candidate in
                let trimmedKey = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedKey.isEmpty,
                      var components = URLComponents(string: "\(baseURLString)/configuration")
                else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [URLQueryItem(name: "api_key", value: trimmedKey)]
                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      payload["images"] is [String: Any]
                else {
                    throw NetworkError.invalidResponse
                }
            }
        )
    }()

    public static let testValue: TMDBClient = {
        var client = TMDBClient()
        client.searchMovie = { _ in TMDBSearchResponseDTO(results: []) }
        client.searchTV = { _ in TMDBSearchResponseDTO(results: []) }
        client.fetchMovieImages = { _ in TMDBImagesDTO(id: nil, backdrops: [], logos: [], posters: []) }
        client.fetchTVImages = { _ in TMDBImagesDTO(id: nil, backdrops: [], logos: [], posters: []) }
        client.discoverMovies = { _, _, _ in TMDBMovieDiscoveryResponseDTO(results: []) }
        client.searchPeople = { _ in TMDBPersonSearchResponseDTO(results: []) }
        client.validateAPIKey = { _ in }
        client.fetchMovieWatchProviders = { movieID in TMDBWatchProvidersResponseDTO(id: movieID) }
        client.fetchTVWatchProviders = { tvID in TMDBWatchProvidersResponseDTO(id: tvID) }
        return client
    }()
}

public extension DependencyValues {
    var tmdbClient: TMDBClient {
        get { self[TMDBClient.self] }
        set { self[TMDBClient.self] = newValue }
    }
}
