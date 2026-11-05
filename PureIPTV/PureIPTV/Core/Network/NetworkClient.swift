import Foundation

public struct M3UHTTPResponseMetadata: Sendable {
    public let statusCode: Int
    public let etag: String?
    public let lastModified: String?
    public let cacheControl: String?
    public let vary: String?
}

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
    private let m3uSession: URLSession

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

        let m3uConfiguration = URLSessionConfiguration.ephemeral
        m3uConfiguration.urlCache = nil
        m3uConfiguration.httpCookieStorage = nil
        m3uConfiguration.httpShouldSetCookies = false
        m3uSession = URLSession(configuration: m3uConfiguration)
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

    /// Streams a bounded playlist response to a consumer in fixed-size chunks.
    public func fetchDataInChunks(
        url: URL,
        userAgentOverride: String? = nil,
        ifNoneMatch: String? = nil,
        ifModifiedSince: String? = nil,
        maximumBytes: Int,
        receiveChunk: @escaping @Sendable (Data, Int64?) async throws -> Void
    ) async throws -> M3UHTTPResponseMetadata {
        guard maximumBytes > 0 else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        UserAgentManager.shared.applyHeaders(to: &request, override: userAgentOverride)
        request.httpShouldHandleCookies = false
        if let ifNoneMatch, Self.isSafeHTTPValidator(ifNoneMatch) {
            request.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match")
        }
        if let ifModifiedSince, Self.isSafeHTTPValidator(ifModifiedSince) {
            request.setValue(ifModifiedSince, forHTTPHeaderField: "If-Modified-Since")
        }

        let (bytes, response) = try await m3uSession.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        if httpResponse.statusCode == 429 {
            throw NetworkError.rateLimited(retryAfter: Self.retryAfterDate(from: httpResponse))
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw NetworkError.unauthorized
        }
        let metadata = M3UHTTPResponseMetadata(
            statusCode: httpResponse.statusCode,
            etag: httpResponse.value(forHTTPHeaderField: "ETag"),
            lastModified: httpResponse.value(forHTTPHeaderField: "Last-Modified"),
            cacheControl: httpResponse.value(forHTTPHeaderField: "Cache-Control"),
            vary: httpResponse.value(forHTTPHeaderField: "Vary")
        )
        if httpResponse.statusCode == 304 {
            return metadata
        }
        // Playlist catalog updates must never accept a partial response as a
        // complete replacement. This request does not use Range semantics.
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode >= 500 {
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }
            throw NetworkError.invalidResponse
        }

        let expectedByteCount = httpResponse.expectedContentLength > 0
            ? httpResponse.expectedContentLength
            : nil
        if let expectedByteCount, expectedByteCount > Int64(maximumBytes) {
            throw URLError(.dataLengthExceedsMaximum)
        }

        let chunkSize = 32 * 1024
        var chunk = Data()
        chunk.reserveCapacity(chunkSize)
        var receivedByteCount = 0
        var iterator = bytes.makeAsyncIterator()
        while let byte = try await iterator.next() {
            guard receivedByteCount < maximumBytes else {
                throw URLError(.dataLengthExceedsMaximum)
            }
            chunk.append(byte)
            receivedByteCount += 1

            guard chunk.count == chunkSize else { continue }
            try Task.checkCancellation()
            try await receiveChunk(chunk, expectedByteCount)
            chunk.removeAll(keepingCapacity: true)
        }

        if !chunk.isEmpty {
            try await receiveChunk(chunk, expectedByteCount)
        }
        try Task.checkCancellation()
        return metadata
    }

    private static func isSafeHTTPValidator(_ value: String) -> Bool {
        value.utf8.count <= 4096 && !value.contains("\r") && !value.contains("\n")
    }

    /// Fetches an XMLTV source without buffering more than its supported compressed-input limit.
    public func fetchXMLTVData(url: URL, userAgentOverride: String? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        UserAgentManager.shared.applyHeaders(to: &request, override: userAgentOverride)
        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        if httpResponse.statusCode == 429 {
            throw NetworkError.rateLimited(retryAfter: Self.retryAfterDate(from: httpResponse))
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        let maximumBytes = XMLTVArchiveDecoder.maximumDownloadBytes
        if httpResponse.expectedContentLength > Int64(maximumBytes) {
            throw XMLTVArchiveError.invalidOrUnsupported
        }

        var data = Data()
        data.reserveCapacity(min(maximumBytes, 1 * 1024 * 1024))
        var iterator = bytes.makeAsyncIterator()
        while let byte = try await iterator.next() {
            guard data.count < maximumBytes else {
                throw XMLTVArchiveError.invalidOrUnsupported
            }
            data.append(byte)
            if data.count.isMultiple(of: 64 * 1024) {
                try Task.checkCancellation()
            }
        }
        try Task.checkCancellation()
        return data
    }

    /// Reads only a bounded response prefix for diagnostics that must not download a full playlist or EPG file.
    public func fetchPrefix(
        url: URL,
        userAgentOverride: String? = nil,
        maximumBytes: Int
    ) async throws -> NetworkResponsePrefix {
        guard (1 ... 1_048_576).contains(maximumBytes) else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url, timeoutInterval: 8)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("bytes=0-\(maximumBytes - 1)", forHTTPHeaderField: "Range")
        UserAgentManager.shared.applyHeaders(to: &request, override: userAgentOverride)

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        if httpResponse.statusCode == 429 {
            throw NetworkError.rateLimited(retryAfter: Self.retryAfterDate(from: httpResponse))
        }
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw NetworkError.unauthorized
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }

        var data = Data()
        data.reserveCapacity(min(maximumBytes, 64 * 1024))
        var iterator = bytes.makeAsyncIterator()
        var wasTruncated = false
        while let byte = try await iterator.next() {
            if data.count == maximumBytes {
                wasTruncated = true
                break
            }
            data.append(byte)
            if data.count.isMultiple(of: 4096) {
                try Task.checkCancellation()
            }
        }
        try Task.checkCancellation()

        let contentRangeTotal = httpResponse.value(forHTTPHeaderField: "Content-Range")?
            .split(separator: "/").last
            .flatMap { Int64($0) }
        let serverTruncated = httpResponse.statusCode == 206
            && (contentRangeTotal.map { $0 > Int64(data.count) } ?? (data.count == maximumBytes))

        return NetworkResponsePrefix(
            data: data,
            statusCode: httpResponse.statusCode,
            contentType: httpResponse.mimeType,
            wasTruncated: wasTruncated || serverTruncated
        )
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
    public func fetch<T: Decodable & Sendable>(url: URL, userAgentOverride: String? = nil) async throws -> T {
        var request = URLRequest(url: url)
        UserAgentManager.shared.applyHeaders(to: &request, override: userAgentOverride)
        return try await Self.performFetch(request: request, session: session)
    }

    /// Executes an authenticated request whose credentials are carried in headers, never in its URL.
    @MainActor
    public func fetch<T: Decodable & Sendable>(request originalRequest: URLRequest) async throws -> T {
        var request = originalRequest
        if let url = request.url {
            request.url = mediaServerCredentialSafeURL(url)
        }
        return try await Self.performFetch(request: request, session: credentialedSession)
    }

    @concurrent
    private nonisolated static func performFetch<T: Decodable & Sendable>(request: URLRequest, session: URLSession) async throws -> T {
        #if DEBUG
            print("🌐 [NETWORK REQUEST] -> \(redactedURL(request.url))")
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
            // NetworkClient is MainActor-isolated by the target's default isolation.
            // Keep the synchronous JSON decode on this explicitly nonisolated path,
            // and avoid sharing JSONDecoder across concurrent requests.
            return try JSONDecoder().decode(T.self, from: data)
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

        return AppFormatters.parseHTTPDate(value)
    }
}

public struct NetworkResponsePrefix: Sendable {
    public let data: Data
    public let statusCode: Int
    public let contentType: String?
    public let wasTruncated: Bool

    public init(data: Data, statusCode: Int, contentType: String?, wasTruncated: Bool) {
        self.data = data
        self.statusCode = statusCode
        self.contentType = contentType
        self.wasTruncated = wasTruncated
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
