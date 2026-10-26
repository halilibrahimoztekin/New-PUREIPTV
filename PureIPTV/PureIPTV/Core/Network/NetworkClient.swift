import Foundation

private let mediaServerCredentialQueryKeys: Set<String> = [
    "token", "access_token", "authtoken", "auth", "authorization", "password", "username",
    "api_key", "api-key", "apikey", "secret", "x-plex-token", "x-emby-token",
]

private func mediaServerCredentialSafeURL(_ url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
    components.user = nil
    components.password = nil
    components.queryItems = components.queryItems?.filter {
        !mediaServerCredentialQueryKeys.contains($0.name.lowercased())
    }
    return components.url ?? url
}

public struct NetworkClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
        // Some APIs return empty arrays instead of objects on failure or empty results
        // Also might need date decoding strategies depending on API format.
    }

    public func fetchData(url: URL, userAgentOverride: String? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        UserAgentManager.shared.applyHeaders(to: &request, override: userAgentOverride)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        return data
    }

    /// Fetches bytes using a request whose credentials are carried in headers, never in its URL.
    public func fetchData(request originalRequest: URLRequest) async throws -> Data {
        var request = originalRequest
        if let url = request.url {
            request.url = mediaServerCredentialSafeURL(url)
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        return data
    }

    @MainActor
    public func fetch<T: Decodable>(url: URL, userAgentOverride: String? = nil) async throws -> T {
        var request = URLRequest(url: url)
        UserAgentManager.shared.applyHeaders(to: &request, override: userAgentOverride)
        return try await performFetch(request: request)
    }

    /// Executes an authenticated request whose credentials are carried in headers, never in its URL.
    @MainActor
    public func fetch<T: Decodable>(request originalRequest: URLRequest) async throws -> T {
        var request = originalRequest
        if let url = request.url {
            request.url = mediaServerCredentialSafeURL(url)
        }
        return try await performFetch(request: request)
    }

    @MainActor
    private func performFetch<T: Decodable>(request: URLRequest) async throws -> T {
        #if DEBUG
            print("🌐 [NETWORK REQUEST] -> \(Self.redactedURL(request.url))")
            let startTime = CFAbsoluteTimeGetCurrent()
        #endif

        let (data, response) = try await session.data(for: request)

        #if DEBUG
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        #endif

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        #if DEBUG
            let statusCode = httpResponse.statusCode
            let icon = (200 ... 299).contains(statusCode) ? "✅" : "❌"
            print("\(icon) [NETWORK RESPONSE] <- [\(statusCode)] \(Self.redactedURL(request.url)) (⏱ \(String(format: "%.2f", timeElapsed))s)")
        #endif

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            // Xtream usually returns 200 even for auth errors, but just in case
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw NetworkError.unauthorized
            }
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            throw NetworkError.decodingFailed(description: "Data corrupted: \(context.debugDescription)")
        } catch let DecodingError.keyNotFound(key, context) {
            throw NetworkError.decodingFailed(description: "Key '\(key.stringValue)' not found: \(context.debugDescription)")
        } catch let DecodingError.valueNotFound(value, context) {
            throw NetworkError.decodingFailed(description: "Value '\(value)' not found: \(context.debugDescription)")
        } catch let DecodingError.typeMismatch(type, context) {
            throw NetworkError.decodingFailed(description: "Type '\(type)' mismatch: \(context.debugDescription)")
        } catch {
            throw NetworkError.decodingFailed(description: error.localizedDescription)
        }
    }

    private nonisolated static func redactedURL(_ url: URL?) -> String {
        guard let url else {
            return "<invalid-url>"
        }
        return mediaServerCredentialSafeURL(url).absoluteString
    }
}

/// Provider authentication that travels only as HTTP headers.
public enum MediaServerRequestContext: Sendable {
    case plex(accessToken: String, clientIdentifier: String)
    case emby(accessToken: String, userID: String, clientIdentifier: String, deviceName: String, deviceID: String)

    /// Builds requests for provider-returned media keys while moving common credential query items
    /// into the authentication header supplied by this context.
    public func makeRequest(for url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: mediaServerCredentialSafeURL(url))
        request.httpMethod = method
        apply(to: &request)
        return request
    }

    public func apply(to request: inout URLRequest) {
        if let url = request.url {
            request.url = mediaServerCredentialSafeURL(url)
        }
        switch self {
        case let .plex(accessToken, clientIdentifier):
            request.setValue(accessToken, forHTTPHeaderField: "X-Plex-Token")
            request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
            request.setValue("PureIPTV", forHTTPHeaderField: "X-Plex-Product")
        case let .emby(accessToken, userID, clientIdentifier, deviceName, deviceID):
            request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")
            request.setValue(
                "Emby UserId=\(userID), Client=\(clientIdentifier), Device=\(deviceName), DeviceId=\(deviceID), Version=1",
                forHTTPHeaderField: "X-Emby-Authorization"
            )
        }
    }
}
