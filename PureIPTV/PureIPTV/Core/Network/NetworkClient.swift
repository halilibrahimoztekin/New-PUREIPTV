import Foundation

private nonisolated let mediaServerCredentialQueryKeys: Set<String> = [
    "token", "access_token", "authtoken", "auth", "authorization", "password", "username",
    "api_key", "api-key", "apikey", "secret", "x-plex-token", "x-emby-token",
]

private nonisolated func mediaServerCredentialSafeURL(
    _ url: URL,
    redactingAdditionalQueryKeys: Set<String> = []
) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
    components.user = nil
    components.password = nil
    components.queryItems = components.queryItems?.filter {
        let key = $0.name.lowercased()
        return !mediaServerCredentialQueryKeys.contains(key) && !redactingAdditionalQueryKeys.contains(key)
    }
    return components.url ?? url
}

public struct NetworkClient {
    private let session: URLSession
    private let credentialedSession: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        credentialedSession = URLSession(
            configuration: configuration,
            delegate: CredentialedRedirectDelegate(),
            delegateQueue: nil
        )
        decoder = JSONDecoder()
        // Some APIs return empty arrays instead of objects on failure or empty results
        // Also might need date decoding strategies depending on API format.
    }

    public func fetchData(url: URL, userAgentOverride: String? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        UserAgentManager.shared.applyHeaders(to: &request, override: userAgentOverride)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        if httpResponse.statusCode == 429 {
            throw NetworkError.rateLimited(retryAfter: Self.retryAfterDate(from: httpResponse))
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else { throw NetworkError.invalidResponse }
        return data
    }

    /// Fetches bytes using a request whose credentials are carried in headers, never in its URL.
    public func fetchData(request originalRequest: URLRequest) async throws -> Data {
        var request = originalRequest
        if let url = request.url {
            request.url = mediaServerCredentialSafeURL(url)
        }
        let (data, response) = try await credentialedSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        if httpResponse.statusCode == 429 {
            throw NetworkError.rateLimited(retryAfter: Self.retryAfterDate(from: httpResponse))
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else { throw NetworkError.invalidResponse }
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
        return try await performFetch(request: request, session: credentialedSession)
    }

    @MainActor
    private func performFetch<T: Decodable>(request: URLRequest, session: URLSession? = nil) async throws -> T {
        #if DEBUG
            print("🌐 [NETWORK REQUEST] -> \(Self.redactedURL(request.url))")
            let startTime = CFAbsoluteTimeGetCurrent()
        #endif

        let (data, response) = try await (session ?? self.session).data(for: request)

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
            if httpResponse.statusCode == 429 {
                throw NetworkError.rateLimited(retryAfter: Self.retryAfterDate(from: httpResponse))
            }
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
        return mediaServerCredentialSafeURL(url, redactingAdditionalQueryKeys: ["code"]).absoluteString
    }

    private nonisolated static func retryAfterDate(from response: HTTPURLResponse, now: Date = .now) -> Date? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }

        if let seconds = TimeInterval(value), seconds.isFinite, seconds >= 0 {
            return now.addingTimeInterval(seconds)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.date(from: value)
    }
}

private final nonisolated class CredentialedRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let originalURL = task.originalRequest?.url,
              let redirectedURL = request.url,
              Self.hasSameOrigin(originalURL, redirectedURL),
              redirectedURL.user == nil,
              redirectedURL.password == nil
        else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }

    private nonisolated static func hasSameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        guard let left = URLComponents(url: lhs, resolvingAgainstBaseURL: false),
              let right = URLComponents(url: rhs, resolvingAgainstBaseURL: false),
              let leftScheme = left.scheme?.lowercased(),
              let rightScheme = right.scheme?.lowercased(),
              let leftHost = left.host?.lowercased(),
              let rightHost = right.host?.lowercased(),
              left.user == nil, left.password == nil,
              right.user == nil, right.password == nil
        else { return false }

        func effectivePort(_ components: URLComponents) -> Int? {
            if let port = components.port {
                return port
            }
            return switch components.scheme?.lowercased() {
            case "https": 443
            case "http": 80
            default: nil
            }
        }

        return leftScheme == rightScheme
            && leftHost == rightHost
            && effectivePort(left) == effectivePort(right)
    }
}

/// Provider authentication that travels only as HTTP headers.
public nonisolated enum MediaServerRequestContext: Sendable {
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

    public var authorizationHeaders: [String: String] {
        var request = URLRequest(url: URL(string: "https://localhost.invalid")!)
        apply(to: &request)
        return request.allHTTPHeaderFields ?? [:]
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
