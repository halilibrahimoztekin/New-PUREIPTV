import ComposableArchitecture
import Foundation

public enum PlaylistHealthCheckKind: String, CaseIterable, Equatable, Sendable, Identifiable {
    case connection
    case authentication
    case format
    case parsing
    case epg

    public var id: Self {
        self
    }
}

public enum PlaylistHealthIssue: String, Equatable, Sendable {
    case invalidConfiguration
    case connectionFailed
    case credentialsRejected
    case rateLimited
    case serverUnavailable
    case invalidResponse
    case formatMismatch
    case noPlayableEntries
    case sampleIncomplete
    case configuredFormatUnsupported
    case providerDidNotReportFormats
    case noEPGSource
    case epgConnectionFailed
    case epgFormatMismatch
    case requiresSampleStream
}

public enum PlaylistHealthStatus: Equatable, Sendable {
    case passed
    case failed(PlaylistHealthIssue)
    case notChecked(PlaylistHealthIssue)
    case notConfigured
    case notApplicable
}

public struct PlaylistHealthCheckResult: Equatable, Sendable, Identifiable {
    public let kind: PlaylistHealthCheckKind
    public let status: PlaylistHealthStatus

    public var id: PlaylistHealthCheckKind {
        kind
    }

    public init(kind: PlaylistHealthCheckKind, status: PlaylistHealthStatus) {
        self.kind = kind
        self.status = status
    }
}

/// Contains only fixed provider/check codes. It deliberately has no playlist identity, URL, or provider response text.
public struct PlaylistHealthReport: Equatable, Sendable {
    public let playlistType: PlaylistType
    public let checkedAt: Date
    public let checks: [PlaylistHealthCheckResult]

    public init(playlistType: PlaylistType, checkedAt: Date = .now, checks: [PlaylistHealthCheckResult]) {
        self.playlistType = playlistType
        self.checkedAt = checkedAt
        self.checks = checks
    }

    public func status(for kind: PlaylistHealthCheckKind) -> PlaylistHealthStatus {
        checks.first(where: { $0.kind == kind })?.status ?? .notChecked(.invalidResponse)
    }
}

public struct PlaylistHealthClient: Sendable {
    public var inspect: @Sendable (_ config: PlaylistConfig) async throws -> PlaylistHealthReport

    public init(inspect: @escaping @Sendable (PlaylistConfig) async throws -> PlaylistHealthReport) {
        self.inspect = inspect
    }
}

extension PlaylistHealthClient: DependencyKey {
    public static let liveValue: PlaylistHealthClient = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        configuration.waitsForConnectivity = false
        let session = URLSession(
            configuration: configuration,
            delegate: PlaylistHealthRedirectDelegate(),
            delegateQueue: nil
        )
        let networkClient = NetworkClient(session: session)
        let mediaServerClient = MediaServerCatalogClient.liveValue

        return PlaylistHealthClient(inspect: { config in
            try Task.checkCancellation()
            switch config.type {
            case .m3u:
                return try await inspectM3U(config, networkClient: networkClient)
            case .xtream:
                return try await inspectXtream(config, networkClient: networkClient)
            case .plex, .emby:
                return try await inspectMediaServer(config, client: mediaServerClient)
            }
        })
    }()

    public static let testValue = PlaylistHealthClient(inspect: { config in
        PlaylistHealthReport(
            playlistType: config.type,
            checks: PlaylistHealthCheckKind.allCases.map {
                PlaylistHealthCheckResult(kind: $0, status: .notChecked(.invalidConfiguration))
            }
        )
    })
}

public extension DependencyValues {
    var playlistHealthClient: PlaylistHealthClient {
        get { self[PlaylistHealthClient.self] }
        set { self[PlaylistHealthClient.self] = newValue }
    }
}

private func inspectM3U(_ config: PlaylistConfig, networkClient: NetworkClient) async throws -> PlaylistHealthReport {
    guard let url = config.m3uURL,
          let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
          url.host != nil
    else {
        return failedReport(for: .m3u, issue: .invalidConfiguration)
    }

    let prefix: NetworkResponsePrefix
    do {
        prefix = try await networkClient.fetchPrefix(
            url: url,
            userAgentOverride: config.userAgentOverride,
            maximumBytes: 256 * 1024
        )
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        return failedReport(for: .m3u, issue: issue(for: error))
    }

    let decodedContents = String(decoding: prefix.data, as: UTF8.self)
    let contents = decodedContents.first == "\u{FEFF}" ? String(decodedContents.dropFirst()) : decodedContents
    guard contents.range(of: #"(?m)^\s*#EXTM3U(?:\s|$)"#, options: .regularExpression) != nil else {
        let incompleteSample = prefix.wasTruncated
        let sampleStatus: PlaylistHealthStatus = incompleteSample ? .notChecked(.sampleIncomplete) : .failed(.formatMismatch)
        return PlaylistHealthReport(
            playlistType: .m3u,
            checks: [
                .init(kind: .connection, status: .passed),
                .init(kind: .authentication, status: .notChecked(.invalidResponse)),
                .init(kind: .format, status: sampleStatus),
                .init(kind: .parsing, status: .notChecked(incompleteSample ? .sampleIncomplete : .invalidResponse)),
                .init(kind: .epg, status: .notChecked(incompleteSample ? .sampleIncomplete : .invalidResponse)),
            ]
        )
    }

    try Task.checkCancellation()
    let parsed = M3UParser().parse(m3uString: contents)
    let playableEntryCount = parsed.items.reduce(into: 0) { count, item in
        if let scheme = item.streamURL.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            count += 1
        }
    }
    let parsingStatus: PlaylistHealthStatus = if playableEntryCount > 0 {
        .passed
    } else if prefix.wasTruncated {
        .notChecked(.sampleIncomplete)
    } else {
        .failed(.noPlayableEntries)
    }

    let epgStatus = try await inspectM3UEPG(
        parsed.epgURL,
        relativeTo: url,
        userAgentOverride: config.userAgentOverride,
        networkClient: networkClient
    )

    return PlaylistHealthReport(
        playlistType: .m3u,
        checks: [
            .init(kind: .connection, status: .passed),
            .init(kind: .authentication, status: .passed),
            .init(kind: .format, status: .passed),
            .init(kind: .parsing, status: parsingStatus),
            .init(kind: .epg, status: epgStatus),
        ]
    )
}

private func inspectM3UEPG(
    _ epgURL: URL?,
    relativeTo playlistURL: URL,
    userAgentOverride: String?,
    networkClient: NetworkClient
) async throws -> PlaylistHealthStatus {
    guard let epgURL else { return .notConfigured }
    guard let resolvedURL = URL(string: epgURL.absoluteString, relativeTo: playlistURL)?.absoluteURL,
          let scheme = resolvedURL.scheme?.lowercased(), ["http", "https"].contains(scheme),
          resolvedURL.host != nil
    else {
        return .failed(.invalidConfiguration)
    }

    do {
        let prefix = try await networkClient.fetchPrefix(
            url: resolvedURL,
            userAgentOverride: userAgentOverride,
            maximumBytes: 64 * 1024
        )
        try Task.checkCancellation()
        let text = String(decoding: prefix.data, as: UTF8.self)
        guard text.range(of: #"<tv(?:\s|>)"#, options: [.regularExpression, .caseInsensitive]) != nil else {
            return prefix.wasTruncated ? .notChecked(.sampleIncomplete) : .failed(.epgFormatMismatch)
        }
        return .passed
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        return .failed(issue(for: error, isEPG: true))
    }
}

private func inspectXtream(_ config: PlaylistConfig, networkClient: NetworkClient) async throws -> PlaylistHealthReport {
    guard let serverURL = config.serverURL,
          let username = config.username, !username.isEmpty,
          let password = config.password, !password.isEmpty
    else {
        return failedReport(for: .xtream, issue: .invalidConfiguration)
    }

    do {
        let authURL = try XtreamEndpoint.authenticate.url(
            with: ServerConfig(baseURL: serverURL, username: username, password: password)
        )
        let prefix = try await networkClient.fetchPrefix(
            url: authURL,
            userAgentOverride: config.userAgentOverride,
            maximumBytes: 64 * 1024
        )
        try Task.checkCancellation()

        guard let auth = try? JSONDecoder().decode(XtreamAuthResponseDTO.self, from: prefix.data) else {
            return PlaylistHealthReport(
                playlistType: .xtream,
                checks: [
                    .init(kind: .connection, status: .passed),
                    .init(kind: .authentication, status: .notChecked(.invalidResponse)),
                    .init(kind: .format, status: .failed(.formatMismatch)),
                    .init(kind: .parsing, status: .failed(.invalidResponse)),
                    .init(kind: .epg, status: .notChecked(.requiresSampleStream)),
                ]
            )
        }

        let authenticationStatus: PlaylistHealthStatus = switch auth.userInfo.auth {
        case 1: .passed
        case 0: .failed(.credentialsRejected)
        default: .notChecked(.invalidResponse)
        }

        let formatStatus: PlaylistHealthStatus
        if let supportedFormats = auth.userInfo.allowedOutputFormats, !supportedFormats.isEmpty {
            let normalizedFormats = Set(supportedFormats.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            formatStatus = normalizedFormats.contains(config.xtreamLiveOutputFormat.rawValue)
                ? .passed
                : .failed(.configuredFormatUnsupported)
        } else {
            formatStatus = .notChecked(.providerDidNotReportFormats)
        }

        return PlaylistHealthReport(
            playlistType: .xtream,
            checks: [
                .init(kind: .connection, status: .passed),
                .init(kind: .authentication, status: authenticationStatus),
                .init(kind: .format, status: formatStatus),
                .init(kind: .parsing, status: auth.userInfo.auth == nil ? .failed(.invalidResponse) : .passed),
                .init(kind: .epg, status: .notChecked(.requiresSampleStream)),
            ]
        )
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        return failedReport(for: .xtream, issue: issue(for: error))
    }
}

private func inspectMediaServer(
    _ config: PlaylistConfig,
    client: MediaServerCatalogClient
) async throws -> PlaylistHealthReport {
    do {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await client.validate(config)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 8_000_000_000)
                throw PlaylistHealthProbeTimeout()
            }
            _ = try await group.next()
            group.cancelAll()
        }
        try Task.checkCancellation()
        return PlaylistHealthReport(
            playlistType: config.type,
            checks: [
                .init(kind: .connection, status: .passed),
                .init(kind: .authentication, status: .passed),
                .init(kind: .format, status: .passed),
                .init(kind: .parsing, status: .passed),
                .init(kind: .epg, status: .notApplicable),
            ]
        )
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        let issue = issue(for: error)
        return PlaylistHealthReport(
            playlistType: config.type,
            checks: [
                .init(kind: .connection, status: connectionStatus(for: issue)),
                .init(kind: .authentication, status: authenticationStatus(for: issue)),
                .init(kind: .format, status: .notChecked(.invalidResponse)),
                .init(kind: .parsing, status: .notChecked(.invalidResponse)),
                .init(kind: .epg, status: .notApplicable),
            ]
        )
    }
}

private func failedReport(for type: PlaylistType, issue: PlaylistHealthIssue) -> PlaylistHealthReport {
    PlaylistHealthReport(
        playlistType: type,
        checks: [
            .init(kind: .connection, status: connectionStatus(for: issue)),
            .init(kind: .authentication, status: authenticationStatus(for: issue)),
            .init(kind: .format, status: .notChecked(issue)),
            .init(kind: .parsing, status: .notChecked(issue)),
            .init(kind: .epg, status: type == .m3u ? .notChecked(issue) : .notApplicable),
        ]
    )
}

private func connectionStatus(for issue: PlaylistHealthIssue) -> PlaylistHealthStatus {
    switch issue {
    case .credentialsRejected, .rateLimited, .serverUnavailable:
        .passed
    default:
        .failed(issue)
    }
}

private func authenticationStatus(for issue: PlaylistHealthIssue) -> PlaylistHealthStatus {
    issue == .credentialsRejected ? .failed(issue) : .notChecked(issue)
}

private func issue(for error: Error, isEPG: Bool = false) -> PlaylistHealthIssue {
    if let networkError = error as? NetworkError {
        switch networkError {
        case .invalidURL: return .invalidConfiguration
        case .unauthorized: return .credentialsRejected
        case .rateLimited: return .rateLimited
        case .serverError: return .serverUnavailable
        case .invalidResponse, .decodingFailed, .underlying: return isEPG ? .epgFormatMismatch : .invalidResponse
        }
    }
    if let urlError = error as? URLError {
        switch urlError.code {
        case .timedOut, .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return isEPG ? .epgConnectionFailed : .connectionFailed
        default:
            break
        }
    }
    return isEPG ? .epgConnectionFailed : .connectionFailed
}

private struct PlaylistHealthProbeTimeout: Error {}

private final nonisolated class PlaylistHealthRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
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

    private static func hasSameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        guard let left = URLComponents(url: lhs, resolvingAgainstBaseURL: false),
              let right = URLComponents(url: rhs, resolvingAgainstBaseURL: false),
              left.scheme?.lowercased() == right.scheme?.lowercased(),
              left.host?.lowercased() == right.host?.lowercased() else { return false }
        return effectivePort(left) == effectivePort(right)
    }

    private static func effectivePort(_ components: URLComponents) -> Int? {
        if let port = components.port {
            return port
        }
        switch components.scheme?.lowercased() {
        case "https": return 443
        case "http": return 80
        default: return nil
        }
    }
}
