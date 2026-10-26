import Foundation
@preconcurrency import Network

/// A loopback-only HTTP relay for media servers whose playback APIs require request headers.
/// The local URL contains random route IDs only; provider credentials remain in memory and are
/// attached only to requests within the configured server origin.
actor MediaServerStreamProxy {
    nonisolated static let shared = MediaServerStreamProxy()

    private struct Route: Sendable {
        let upstreamURL: URL
        let serverBaseURL: URL
        let context: MediaServerRequestContext
        let userAgentOverride: String?
        let additionalHeaders: [String: String]
    }

    private struct Session {
        var routes: [String: Route]
        var routeIDsByURL: [String: String]
        var routeOrder: [String]
        let rootRouteID: String
        var lastActivity: Date
    }

    private var listener: NWListener?
    private var listenerPort: NWEndpoint.Port?
    private var listenerStartTask: Task<NWEndpoint.Port, Error>?
    private var listenerStartID: UUID?
    private var sessions: [String: Session] = [:]

    private let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpShouldSetCookies = false
        return URLSession(
            configuration: configuration,
            delegate: MediaServerRedirectDelegate(),
            delegateQueue: nil
        )
    }()

    func makePlaybackURL(
        for upstreamURL: URL,
        config: PlaylistConfig,
        additionalHeaders: [String: String]? = nil
    ) async throws -> URL {
        try Task.checkCancellation()
        guard config.type == .plex || config.type == .emby,
              let serverBaseURL = MediaServerRequestContextFactory.baseURL(for: config),
              let context = MediaServerRequestContextFactory.context(for: config),
              isHTTPURL(upstreamURL),
              isWithinServerOrigin(upstreamURL, baseURL: serverBaseURL)
        else { throw NetworkError.invalidURL }

        let sessionID = UUID().uuidString.lowercased()
        let routeID = UUID().uuidString.lowercased()
        let route = Route(
            upstreamURL: sanitizedProviderURL(upstreamURL, baseURL: serverBaseURL),
            serverBaseURL: serverBaseURL,
            context: context,
            userAgentOverride: config.userAgentOverride,
            additionalHeaders: validatedAdditionalHeaders(additionalHeaders ?? [:])
        )
        sessions[sessionID] = Session(
            routes: [routeID: route],
            routeIDsByURL: [route.upstreamURL.absoluteString: routeID],
            routeOrder: [routeID],
            rootRouteID: routeID,
            lastActivity: Date()
        )
        pruneExpiredSessions()

        let port: NWEndpoint.Port
        do {
            port = try await ensureListener()
            try Task.checkCancellation()

            var components = URLComponents()
            components.scheme = "http"
            components.host = "127.0.0.1"
            components.port = Int(port.rawValue)
            components.path = "/\(sessionID)/\(routeID)"
            guard let localURL = components.url else { throw NetworkError.invalidURL }
            return localURL
        } catch {
            sessions.removeValue(forKey: sessionID)
            stopListenerIfIdle()
            throw error
        }
    }

    func closeSession(for localURL: URL?) {
        guard let localURL,
              let components = URLComponents(url: localURL, resolvingAgainstBaseURL: false),
              components.host == "127.0.0.1"
        else { return }
        let parts = components.path.split(separator: "/").map(String.init)
        guard let sessionID = parts.first else { return }
        sessions.removeValue(forKey: sessionID)
        stopListenerIfIdle()
    }

    private func stopListenerIfIdle() {
        guard sessions.isEmpty else { return }
        listener?.cancel()
        listenerStartTask?.cancel()
        listener = nil
        listenerPort = nil
        listenerStartTask = nil
        listenerStartID = nil
    }

    private func ensureListener() async throws -> NWEndpoint.Port {
        if let listenerPort {
            return listenerPort
        }
        let listener: NWListener
        let startTask: Task<NWEndpoint.Port, Error>
        let startID: UUID
        if let existingTask = listenerStartTask,
           let existingListener = self.listener,
           let existingStartID = listenerStartID
        {
            listener = existingListener
            startTask = existingTask
            startID = existingStartID
        } else {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
            let newListener = try NWListener(using: parameters)
            let newStartID = UUID()
            listener = newListener
            startID = newStartID
            self.listener = newListener
            listenerStartID = newStartID

            startTask = Task<NWEndpoint.Port, Error> {
                try await withCheckedThrowingContinuation { continuation in
                    let completion = ListenerStartCompletion(continuation)
                    newListener.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            guard let port = newListener.port else {
                                completion.fail(NetworkError.invalidResponse)
                                return
                            }
                            completion.succeed(port)
                        case let .failed(error):
                            completion.fail(error)
                        case .cancelled:
                            completion.fail(CancellationError())
                        default:
                            break
                        }
                    }
                    newListener.newConnectionHandler = { [proxy = self] connection in
                        connection.start(queue: MediaServerStreamProxySupport.queue)
                        Task {
                            await proxy.handle(connection)
                        }
                    }
                    newListener.start(queue: MediaServerStreamProxySupport.queue)
                }
            }
            listenerStartTask = startTask
        }

        do {
            let port = try await startTask.value
            guard self.listener === listener else {
                listener.cancel()
                throw CancellationError()
            }
            if listenerStartID == nil, listenerPort == port {
                return port
            }
            guard listenerStartID == startID else {
                listener.cancel()
                throw CancellationError()
            }
            listenerPort = port
            listenerStartTask = nil
            listenerStartID = nil
            return port
        } catch {
            listener.cancel()
            if self.listener === listener, listenerStartID == startID {
                self.listener = nil
                listenerPort = nil
                listenerStartTask = nil
                listenerStartID = nil
            }
            throw error
        }
    }

    private func handle(_ connection: NWConnection) async {
        do {
            let request = try await receiveRequest(from: connection)
            guard let (sessionID, routeID) = routeIDs(from: request.path),
                  var session = sessions[sessionID],
                  let route = session.routes[routeID],
                  session.lastActivity.addingTimeInterval(14400) > Date()
            else {
                try await sendError(410, over: connection)
                connection.cancel()
                return
            }
            session.lastActivity = Date()
            sessions[sessionID] = session
            try await relay(request, route: route, sessionID: sessionID, over: connection)
        } catch {
            try? await sendError(502, over: connection)
        }
        connection.cancel()
    }

    private func relay(
        _ localRequest: LocalRequest,
        route: Route,
        sessionID: String,
        over connection: NWConnection
    ) async throws {
        let upstream = try await openUpstream(localRequest, route: route)
        let response = upstream.response
        let status = response.statusCode
        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream"
        let isManifest = upstream.finalURL.pathExtension.lowercased() == "m3u8"
            || contentType.lowercased().contains("mpegurl")

        if isManifest, localRequest.method != "HEAD", (200 ... 299).contains(status) {
            let manifest = try await readManifest(upstream.bytes)
            let rewritten = try rewriteManifest(
                manifest,
                baseURL: upstream.finalURL,
                route: route,
                sessionID: sessionID
            )
            var headers = safeResponseHeaders(response)
            headers["content-type"] = contentType
            headers["content-length"] = String(rewritten.count)
            headers["accept-ranges"] = "none"
            try await sendHeaders(status: status, headers: headers, over: connection)
            try await sendData(rewritten, over: connection)
            return
        }

        var headers = safeResponseHeaders(response)
        let contentLength = response.expectedContentLength >= 0
            ? response.expectedContentLength
            : response.value(forHTTPHeaderField: "Content-Length").flatMap(Int64.init) ?? -1
        let shouldChunk = contentLength < 0 && localRequest.method != "HEAD" && status != 304
        if contentLength >= 0 {
            headers["content-length"] = String(contentLength)
        }
        if shouldChunk {
            headers.removeValue(forKey: "content-length")
            headers["transfer-encoding"] = "chunked"
        }
        try await sendHeaders(status: status, headers: headers, over: connection)
        guard localRequest.method != "HEAD", status != 304 else { return }
        try await streamBody(upstream.bytes, chunked: shouldChunk, over: connection)
    }

    private func openUpstream(
        _ localRequest: LocalRequest,
        route: Route
    ) async throws -> UpstreamResponse {
        var url = route.upstreamURL

        for redirectCount in 0 ... 5 {
            guard isHTTPURL(url), isWithinServerOrigin(url, baseURL: route.serverBaseURL) else {
                throw NetworkError.invalidURL
            }
            var request = URLRequest(url: sanitizedProviderURL(url, baseURL: route.serverBaseURL))
            request.httpMethod = localRequest.method
            request.timeoutInterval = 90
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            for field in ["Range", "If-Range", "If-None-Match", "If-Modified-Since", "Accept"] {
                if let value = localRequest.headers[field.lowercased()] {
                    request.setValue(value, forHTTPHeaderField: field)
                }
            }
            if let override = route.userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines),
               !override.isEmpty
            {
                request.setValue(override, forHTTPHeaderField: "User-Agent")
            } else if let localAgent = localRequest.headers["user-agent"] {
                request.setValue(localAgent, forHTTPHeaderField: "User-Agent")
            }
            if isWithinServerOrigin(url, baseURL: route.serverBaseURL) {
                route.context.apply(to: &request)
                for (field, value) in route.additionalHeaders {
                    request.setValue(value, forHTTPHeaderField: field)
                }
            }

            let (bytes, response) = try await urlSession.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            if (300 ... 399).contains(httpResponse.statusCode),
               let location = httpResponse.value(forHTTPHeaderField: "Location")
            {
                guard redirectCount < 5,
                      let redirectedURL = URL(string: location, relativeTo: url)?.absoluteURL,
                      isHTTPURL(redirectedURL),
                      isWithinServerOrigin(redirectedURL, baseURL: route.serverBaseURL)
                else { throw NetworkError.invalidURL }
                url = redirectedURL
                continue
            }
            return UpstreamResponse(bytes: bytes, response: httpResponse, finalURL: url)
        }
        throw NetworkError.invalidResponse
    }

    private func readManifest(_ bytes: URLSession.AsyncBytes) async throws -> Data {
        var manifest = Data()
        manifest.reserveCapacity(64 * 1024)
        for try await byte in bytes {
            manifest.append(byte)
            guard manifest.count <= 4 * 1024 * 1024 else {
                throw NetworkError.invalidResponse
            }
        }
        return manifest
    }

    private func rewriteManifest(
        _ data: Data,
        baseURL: URL,
        route: Route,
        sessionID: String
    ) throws -> Data {
        guard let contents = String(data: data, encoding: .utf8) else {
            throw NetworkError.invalidResponse
        }
        let uriExpression = try NSRegularExpression(pattern: #"URI="([^"]+)""#)
        let rewrittenLines = try contents.components(separatedBy: .newlines).map { line -> String in
            if line.isEmpty {
                return line
            }
            if line.first == "#" {
                let source = line as NSString
                let matches = uriExpression.matches(in: line, range: NSRange(location: 0, length: source.length))
                var rewritten = line
                for match in matches.reversed() where match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    let uri = source.substring(with: range)
                    let localURL = try registerManifestURI(uri, baseURL: baseURL, route: route, sessionID: sessionID)
                    rewritten = (rewritten as NSString).replacingCharacters(in: range, with: localURL.absoluteString)
                }
                return rewritten
            }
            let uri = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !uri.isEmpty else { return line }
            let localURL = try registerManifestURI(
                uri,
                baseURL: baseURL,
                route: route,
                sessionID: sessionID
            )
            return localURL.absoluteString
        }
        return Data(rewrittenLines.joined(separator: "\n").utf8)
    }

    private func registerManifestURI(
        _ string: String,
        baseURL: URL,
        route: Route,
        sessionID: String
    ) throws -> URL {
        guard let url = URL(string: string, relativeTo: baseURL)?.absoluteURL,
              isHTTPURL(url),
              isWithinServerOrigin(url, baseURL: route.serverBaseURL),
              var session = sessions[sessionID]
        else { throw NetworkError.invalidURL }
        let safeURL = sanitizedProviderURL(url, baseURL: route.serverBaseURL)
        if let existingRouteID = session.routeIDsByURL[safeURL.absoluteString] {
            session.lastActivity = Date()
            sessions[sessionID] = session
            guard let localURL = localRouteURL(sessionID: sessionID, routeID: existingRouteID) else {
                throw NetworkError.invalidResponse
            }
            return localURL
        }

        let routeID = UUID().uuidString.lowercased()
        session.routes[routeID] = Route(
            upstreamURL: safeURL,
            serverBaseURL: route.serverBaseURL,
            context: route.context,
            userAgentOverride: route.userAgentOverride,
            additionalHeaders: route.additionalHeaders
        )
        session.routeIDsByURL[safeURL.absoluteString] = routeID
        session.routeOrder.append(routeID)
        while session.routeOrder.count > 1024 {
            let expiredID = session.routeOrder.removeFirst()
            guard expiredID != session.rootRouteID,
                  let expiredRoute = session.routes.removeValue(forKey: expiredID)
            else { continue }
            session.routeIDsByURL.removeValue(forKey: expiredRoute.upstreamURL.absoluteString)
        }
        session.lastActivity = Date()
        sessions[sessionID] = session
        guard let localURL = localRouteURL(sessionID: sessionID, routeID: routeID) else {
            throw NetworkError.invalidResponse
        }
        return localURL
    }

    private func localRouteURL(sessionID: String, routeID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = listenerPort.map { Int($0.rawValue) }
        components.path = "/\(sessionID)/\(routeID)"
        return components.url
    }

    private func receiveRequest(from connection: NWConnection) async throws -> LocalRequest {
        let delimiter = Data([13, 10, 13, 10])
        var data = Data()
        while data.range(of: delimiter) == nil {
            let (chunk, isComplete) = try await receiveChunk(from: connection)
            if let chunk {
                data.append(chunk)
            }
            guard data.count <= 64 * 1024 else { throw NetworkError.invalidResponse }
            if isComplete, data.range(of: delimiter) == nil {
                throw NetworkError.invalidResponse
            }
        }

        guard let text = String(data: data, encoding: .utf8),
              let headerEnd = text.range(of: "\r\n\r\n"),
              let firstLine = text[..<headerEnd.lowerBound].components(separatedBy: "\r\n").first
        else { throw NetworkError.invalidResponse }
        let requestParts = firstLine.split(separator: " ", omittingEmptySubsequences: true)
        guard requestParts.count >= 2,
              let method = requestParts.first?.uppercased(),
              method == "GET" || method == "HEAD",
              let path = requestParts.dropFirst().first.map(String.init),
              path.hasPrefix("/")
        else { throw NetworkError.invalidResponse }

        var headers: [String: String] = [:]
        for line in text[..<headerEnd.lowerBound].components(separatedBy: "\r\n").dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, !value.contains("\r"), !value.contains("\n") {
                headers[name] = value
            }
        }
        return LocalRequest(method: method, path: path, headers: headers)
    }

    private func receiveChunk(from connection: NWConnection) async throws -> (Data?, Bool) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data?, Bool), Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (data, isComplete))
                }
            }
        }
    }

    private func sendHeaders(status: Int, headers: [String: String], over connection: NWConnection) async throws {
        var lines = ["HTTP/1.1 \(status) \(HTTPURLResponse.localizedString(forStatusCode: status))"]
        for (name, value) in headers.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }) {
            guard !name.contains("\r"), !name.contains("\n"), !value.contains("\r"), !value.contains("\n") else { continue }
            lines.append("\(name): \(value)")
        }
        lines.append("Connection: close")
        lines.append("")
        lines.append("")
        try await sendData(Data(lines.joined(separator: "\r\n").utf8), over: connection)
    }

    private func streamBody(
        _ bytes: URLSession.AsyncBytes,
        chunked: Bool,
        over connection: NWConnection
    ) async throws {
        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)
        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= 64 * 1024 {
                try await sendBodyChunk(buffer, chunked: chunked, over: connection)
                buffer.removeAll(keepingCapacity: true)
            }
        }
        if !buffer.isEmpty {
            try await sendBodyChunk(buffer, chunked: chunked, over: connection)
        }
        if chunked {
            try await sendData(Data("0\r\n\r\n".utf8), over: connection)
        }
    }

    private func sendBodyChunk(_ data: Data, chunked: Bool, over connection: NWConnection) async throws {
        if chunked {
            var framed = Data("\(String(data.count, radix: 16))\r\n".utf8)
            framed.append(data)
            framed.append(Data("\r\n".utf8))
            try await sendData(framed, over: connection)
        } else {
            try await sendData(data, over: connection)
        }
    }

    private func sendData(_ data: Data, over connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func sendError(_ status: Int, over connection: NWConnection) async throws {
        let body = Data(HTTPURLResponse.localizedString(forStatusCode: status).utf8)
        try await sendHeaders(
            status: status,
            headers: [
                "content-type": "text/plain; charset=utf-8",
                "content-length": String(body.count),
            ],
            over: connection
        )
        try await sendData(body, over: connection)
    }

    private func routeIDs(from path: String) -> (String, String)? {
        let parts = path.split(separator: "/").map(String.init)
        guard parts.count == 2,
              UUID(uuidString: parts[0]) != nil,
              UUID(uuidString: parts[1]) != nil
        else { return nil }
        return (parts[0], parts[1])
    }

    private func pruneExpiredSessions() {
        let expiry = Date().addingTimeInterval(-14400)
        sessions = sessions.filter { $0.value.lastActivity >= expiry }
    }

    private func isHTTPURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https")
            && url.host != nil
            && url.user == nil
            && url.password == nil
    }

    private func isWithinServerOrigin(_ url: URL, baseURL: URL) -> Bool {
        guard url.scheme?.lowercased() == baseURL.scheme?.lowercased(),
              url.host?.caseInsensitiveCompare(baseURL.host ?? "") == .orderedSame,
              url.port == baseURL.port,
              url.user == nil,
              url.password == nil
        else { return false }
        let basePath = baseURL.path.hasSuffix("/") ? baseURL.path : baseURL.path + "/"
        return url.path == String(basePath.dropLast()) || url.path.hasPrefix(basePath)
    }

    private func sanitizedProviderURL(_ url: URL, baseURL: URL) -> URL {
        guard isWithinServerOrigin(url, baseURL: baseURL),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }
        let credentialNames: Set = [
            "access_token", "api_key", "apikey", "auth_token", "token", "x-emby-token", "x-plex-token",
        ]
        components.queryItems = components.queryItems?.filter {
            !credentialNames.contains($0.name.lowercased())
        }
        return components.url ?? url
    }

    private func safeResponseHeaders(_ response: HTTPURLResponse) -> [String: String] {
        let allowed: Set = [
            "accept-ranges", "cache-control", "content-disposition", "content-length", "content-range",
            "content-type", "etag", "last-modified", "expires",
        ]
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let name = key as? String,
                  let value = value as? String,
                  allowed.contains(name.lowercased()),
                  !value.contains("\r"),
                  !value.contains("\n")
            else { continue }
            headers[name.lowercased()] = value
        }
        return headers
    }

    private func validatedAdditionalHeaders(_ headers: [String: String]) -> [String: String] {
        let blockedNames: Set = [
            "accept-encoding", "authorization", "connection", "content-length", "host", "if-modified-since",
            "if-none-match", "if-range", "proxy-authorization", "range", "transfer-encoding", "user-agent",
            "x-emby-authorization", "x-emby-token", "x-plex-token",
        ]
        var result: [String: String] = [:]
        for (name, value) in headers.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }) {
            let normalizedName = name.lowercased()
            let validName = !name.isEmpty && name.count <= 128 && name.utf8.allSatisfy { byte in
                (48 ... 57).contains(byte) || (65 ... 90).contains(byte) || (97 ... 122).contains(byte) || byte == 45
            }
            guard validName,
                  !blockedNames.contains(normalizedName),
                  value.utf8.count <= 4096,
                  !value.contains("\r"),
                  !value.contains("\n")
            else { continue }
            result[name] = value
            if result.count == 32 {
                break
            }
        }
        return result
    }
}

private nonisolated struct LocalRequest {
    let method: String
    let path: String
    let headers: [String: String]
}

private nonisolated struct UpstreamResponse {
    let bytes: URLSession.AsyncBytes
    let response: HTTPURLResponse
    let finalURL: URL
}

private final nonisolated class ListenerStartCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<NWEndpoint.Port, Error>?

    init(_ continuation: CheckedContinuation<NWEndpoint.Port, Error>) {
        self.continuation = continuation
    }

    func succeed(_ port: NWEndpoint.Port) {
        finish(.success(port))
    }

    func fail(_ error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<NWEndpoint.Port, Error>) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        guard let continuation else { return }
        continuation.resume(with: result)
    }
}

private final nonisolated class MediaServerRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private nonisolated enum MediaServerStreamProxySupport {
    static let queue = DispatchQueue(label: "com.pureiptv.media-server-stream-proxy")
}
