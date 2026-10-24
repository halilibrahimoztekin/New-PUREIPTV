import ComposableArchitecture
@preconcurrency import Foundation

@DependencyClient
public struct TMDBClient {
    public var searchMovie: @Sendable (_ query: String) async throws -> TMDBSearchResponseDTO
    public var discoverMovies: @Sendable (_ sortBy: String, _ minimumVoteCount: Int, _ page: Int) async throws -> TMDBMovieDiscoveryResponseDTO
    public var fetchMovieDetails: @Sendable (_ movieID: Int) async throws -> TMDBMovieDetailsDTO
    public var searchTV: @Sendable (_ query: String) async throws -> TMDBSearchResponseDTO // Reusing search response DTO, we can add a new one if fields differ significantly, but TMDB search tv returns similar structure
    public var fetchTVDetails: @Sendable (_ tvID: Int) async throws -> TMDBTVDetailsDTO
    public var fetchPersonDetails: @Sendable (_ personID: Int) async throws -> TMDBPersonDetailsDTO
    public var fetchPersonCombinedCredits: @Sendable (_ personID: Int) async throws -> TMDBPersonCreditsDTO
    public var fetchPopularPeople: @Sendable () async throws -> TMDBPopularPeopleResponseDTO
}

extension TMDBClient: DependencyKey {
    public nonisolated static let liveValue: TMDBClient = {
        let networkClient = NetworkClient()
        let apiKey = "8265bd1679663a7ea12ac168da84d2e8"
        let baseURLString = "https://api.themoviedb.org/3"

        return TMDBClient(
            searchMovie: { query in
                guard var components = URLComponents(string: "\(baseURLString)/search/movie") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "query", value: query),
                    URLQueryItem(name: "page", value: "1"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try await MainActor.run { try JSONDecoder().decode(TMDBSearchResponseDTO.self, from: data) }
            },
            discoverMovies: { sortBy, minimumVoteCount, page in
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
                return try await MainActor.run { try JSONDecoder().decode(TMDBMovieDiscoveryResponseDTO.self, from: data) }
            },
            fetchMovieDetails: { movieID in
                guard var components = URLComponents(string: "\(baseURLString)/movie/\(movieID)") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "append_to_response", value: "credits,similar,videos"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try await MainActor.run { try JSONDecoder().decode(TMDBMovieDetailsDTO.self, from: data) }
            },
            searchTV: { query in
                guard var components = URLComponents(string: "\(baseURLString)/search/tv") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "query", value: query),
                    URLQueryItem(name: "page", value: "1"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try await MainActor.run { try JSONDecoder().decode(TMDBSearchResponseDTO.self, from: data) }
            },
            fetchTVDetails: { tvID in
                guard var components = URLComponents(string: "\(baseURLString)/tv/\(tvID)") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "append_to_response", value: "credits,similar,videos"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try await MainActor.run { try JSONDecoder().decode(TMDBTVDetailsDTO.self, from: data) }
            },
            fetchPersonDetails: { personID in
                guard var components = URLComponents(string: "\(baseURLString)/person/\(personID)") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                let data = try await networkClient.fetchData(url: url)
                return try await MainActor.run { try JSONDecoder().decode(TMDBPersonDetailsDTO.self, from: data) }
            },
            fetchPersonCombinedCredits: { personID in
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
            }
        )
    }()

    public static let testValue = TMDBClient()
}

public extension DependencyValues {
    var tmdbClient: TMDBClient {
        get { self[TMDBClient.self] }
        set { self[TMDBClient.self] = newValue }
    }
}
