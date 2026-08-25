import ComposableArchitecture
import Foundation

@DependencyClient
public struct TMDBClient {
    public var searchMovie: @Sendable (_ query: String) async throws -> TMDBSearchResponseDTO
    public var fetchMovieDetails: @Sendable (_ movieID: Int) async throws -> TMDBMovieDetailsDTO
    public var searchTV: @Sendable (_ query: String) async throws -> TMDBSearchResponseDTO // Reusing search response DTO, we can add a new one if fields differ significantly, but TMDB search tv returns similar structure
    public var fetchTVDetails: @Sendable (_ tvID: Int) async throws -> TMDBTVDetailsDTO
}

extension TMDBClient: DependencyKey {
    public static let liveValue: TMDBClient = {
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
                return try await networkClient.fetch(url: url)
            },
            fetchMovieDetails: { movieID in
                guard var components = URLComponents(string: "\(baseURLString)/movie/\(movieID)") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "append_to_response", value: "credits,similar"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                return try await networkClient.fetch(url: url)
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
                return try await networkClient.fetch(url: url)
            },
            fetchTVDetails: { tvID in
                guard var components = URLComponents(string: "\(baseURLString)/tv/\(tvID)") else {
                    throw NetworkError.invalidURL
                }
                components.queryItems = [
                    URLQueryItem(name: "api_key", value: apiKey),
                    URLQueryItem(name: "language", value: "tr-TR"),
                    URLQueryItem(name: "append_to_response", value: "credits,similar"),
                ]

                guard let url = components.url else { throw NetworkError.invalidURL }
                return try await networkClient.fetch(url: url)
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
