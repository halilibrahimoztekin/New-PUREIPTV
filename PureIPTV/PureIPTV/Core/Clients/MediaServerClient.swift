import ComposableArchitecture
import Foundation

public struct PlexSignInPIN: Equatable, Sendable {
    public let id: Int
    public let code: String
    public let signInURL: URL
}

public struct PlexDiscoveredServer: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let baseURL: URL
    public let accessToken: String
}

public struct EmbyAuthenticatedSession: Equatable, Sendable {
    public let serverID: String
    public let userID: String
    public let userName: String
    public let accessToken: String
}

@DependencyClient
public struct MediaServerClient {
    public var fetchPlaybackStatus: @Sendable (
        _ config: PlaylistConfig,
        _ itemID: String
    ) async throws -> MediaModels.ServerPlaybackStatus?
    public var createPlexPIN: @Sendable () async throws -> PlexSignInPIN
    public var pollPlexPIN: @Sendable (_ pinID: Int, _ code: String) async throws -> String?
    public var discoverPlexServers: @Sendable (_ accountToken: String) async throws -> [PlexDiscoveredServer]
    public var authenticateEmby: @Sendable (
        _ serverURL: URL,
        _ username: String,
        _ password: String
    ) async throws -> EmbyAuthenticatedSession
}

extension MediaServerClient: DependencyKey {
    public static let liveValue: Self = {
        let networkClient = NetworkClient()
        let clientIdentifier = MediaServerIdentity.clientIdentifier

        return MediaServerClient(
            fetchPlaybackStatus: { config, itemID in
                guard let credentials = config.mediaServerCredentials,
                      let baseURL = MediaServerRequestContextFactory.baseURL(for: config),
                      let context = MediaServerRequestContextFactory.context(for: config),
                      let rawItemID = rawMediaServerItemID(itemID, provider: config.type, serverID: credentials.serverID)
                else { return nil }

                switch config.type {
                case .plex:
                    guard let url = URL(string: "status/sessions", relativeTo: baseURL)?.absoluteURL else { return nil }
                    var request = context.makeRequest(for: url)
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    let response: PlexPlaybackSessionsResponse = try await networkClient.fetch(request: request)
                    guard let session = response.mediaContainer.metadata.first(where: {
                        $0.ratingKey == rawItemID && $0.player?.machineIdentifier == clientIdentifier
                    }),
                        let selectedMedia = session.media?.first(where: { $0.selected == true }) ?? session.media?.first,
                        let part = selectedMedia.parts.first(where: { $0.selected == true }) ?? selectedMedia.parts.first,
                        let decision = part.decision?.lowercased()
                    else { return nil }
                    let mode: MediaModels.ServerPlaybackStatus.Mode
                    switch decision {
                    case "directplay": mode = .directPlay
                    case "directstream": mode = .directStream
                    case "transcode": mode = .transcoding
                    default: return nil
                    }
                    return MediaModels.ServerPlaybackStatus(
                        mode: mode,
                        evidence: .serverSession,
                        resolution: selectedMedia.videoResolution,
                        bitrateKbps: selectedMedia.bitrate
                    )

                case .emby:
                    guard let userID = credentials.userID,
                          let sessionsURL = URL(string: "Sessions", relativeTo: baseURL)?.absoluteURL,
                          var components = URLComponents(url: sessionsURL, resolvingAgainstBaseURL: false)
                    else { return nil }
                    let deviceID = MediaServerIdentity.deviceIdentifier
                    components.queryItems = [URLQueryItem(name: "DeviceId", value: deviceID)]
                    guard let url = components.url else { return nil }
                    var request = context.makeRequest(for: url)
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    let sessions: [EmbyPlaybackSession] = try await networkClient.fetch(request: request)
                    guard let session = sessions.first(where: {
                        $0.deviceID == deviceID
                            && $0.userID == userID
                            && $0.nowPlayingItem?.id == rawItemID
                    }),
                        let playMethod = session.playState?.playMethod?.lowercased()
                    else { return nil }
                    let mode: MediaModels.ServerPlaybackStatus.Mode
                    switch playMethod {
                    case "directplay": mode = .directPlay
                    case "directstream": mode = .directStream
                    case "transcode": mode = .transcoding
                    default: return nil
                    }
                    let transcodingInfo = session.transcodingInfo
                    let videoStream = session.playState?.mediaSource?.mediaStreams?.first {
                        $0.type?.caseInsensitiveCompare("Video") == .orderedSame
                    }
                    let width = transcodingInfo?.width ?? videoStream?.width
                    let height = transcodingInfo?.height ?? videoStream?.height
                    let resolution: String? = if let width, let height, width > 0, height > 0 {
                        "\(width)×\(height)"
                    } else {
                        nil
                    }
                    let bitrate = transcodingInfo?.bitrate ?? session.playState?.mediaSource?.bitrate
                    return MediaModels.ServerPlaybackStatus(
                        mode: mode,
                        evidence: .serverSession,
                        resolution: resolution,
                        bitrateKbps: bitrate.flatMap { $0 > 0 ? Int((Double($0) / 1000).rounded()) : nil }
                    )

                case .xtream, .m3u:
                    return nil
                }
            },
            createPlexPIN: {
                var components = URLComponents(string: "https://plex.tv/api/v2/pins")!
                components.queryItems = [URLQueryItem(name: "strong", value: "true")]
                guard let url = components.url else { throw NetworkError.invalidURL }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
                request.setValue("PureIPTV", forHTTPHeaderField: "X-Plex-Product")
                let pin: PlexPINResponse = try await networkClient.fetch(request: request)
                guard !pin.code.isEmpty else { throw NetworkError.invalidResponse }
                var signInComponents = URLComponents(string: "https://plex.tv/link/")!
                signInComponents.queryItems = [URLQueryItem(name: "pin", value: pin.code)]
                guard let signInURL = signInComponents.url else { throw NetworkError.invalidURL }
                return PlexSignInPIN(id: pin.id, code: pin.code, signInURL: signInURL)
            },
            pollPlexPIN: { pinID, code in
                guard pinID > 0,
                      !code.isEmpty,
                      var components = URLComponents(string: "https://plex.tv/api/v2/pins/\(pinID)")
                else { throw NetworkError.invalidURL }
                components.queryItems = [URLQueryItem(name: "code", value: code)]
                guard let url = components.url else { throw NetworkError.invalidURL }
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
                let pin: PlexPINResponse = try await networkClient.fetch(request: request)
                return pin.authToken?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            },
            discoverPlexServers: { accountToken in
                let token = accountToken.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !token.isEmpty,
                      var components = URLComponents(string: "https://clients.plex.tv/api/v2/resources")
                else { throw NetworkError.invalidURL }
                components.queryItems = [
                    URLQueryItem(name: "includeHttps", value: "1"),
                    URLQueryItem(name: "includeRelay", value: "1"),
                    URLQueryItem(name: "includeIPv6", value: "1"),
                ]
                guard let url = components.url else { throw NetworkError.invalidURL }
                let context = MediaServerRequestContext.plex(accessToken: token, clientIdentifier: clientIdentifier)
                var request = context.makeRequest(for: url)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                let devices: [PlexResourceDevice] = try await networkClient.fetch(request: request)
                return devices.compactMap { device in
                    let connections = device.connections
                        .filter { URL(string: $0.uri)?.scheme?.lowercased() == "https" }
                        .sorted { left, right in
                            let leftIsRelay = left.relay == true
                            let rightIsRelay = right.relay == true
                            if leftIsRelay != rightIsRelay {
                                return !leftIsRelay
                            }
                            let leftIsLocal = left.local == true
                            let rightIsLocal = right.local == true
                            if leftIsLocal != rightIsLocal {
                                return leftIsLocal
                            }
                            return left.uri.localizedStandardCompare(right.uri) == .orderedAscending
                        }
                    guard let connection = connections.first,
                          let baseURL = URL(string: connection.uri),
                          MediaServerIdentity.validatedPlexBaseURL(baseURL) != nil,
                          let accessToken = device.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !accessToken.isEmpty
                    else { return nil }
                    let identifier = device.clientIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let identifier, !identifier.isEmpty else { return nil }
                    return PlexDiscoveredServer(
                        id: identifier,
                        name: device.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Plex Server",
                        baseURL: baseURL,
                        accessToken: accessToken
                    )
                }
            },
            authenticateEmby: { serverURL, username, password in
                guard let baseURL = MediaServerIdentity.validatedBaseURL(serverURL),
                      !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !password.isEmpty,
                      let url = URL(string: "Users/AuthenticateByName", relativeTo: baseURL)?.absoluteURL
                else { throw NetworkError.invalidURL }

                let descriptor = MediaServerIdentity.embyAuthorizationHeader
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(descriptor, forHTTPHeaderField: "X-Emby-Authorization")
                request.httpBody = try JSONEncoder().encode(EmbyAuthenticationRequest(
                    username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                ))
                let response: EmbyAuthenticationResponse = try await networkClient.fetch(request: request)
                guard let accessToken = response.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !accessToken.isEmpty,
                      let serverID = response.serverID?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !serverID.isEmpty,
                      let userID = response.user?.id?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !userID.isEmpty
                else { throw NetworkError.invalidResponse }
                return EmbyAuthenticatedSession(
                    serverID: serverID,
                    userID: userID,
                    userName: response.user?.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? username,
                    accessToken: accessToken
                )
            }
        )
    }()

    public static let testValue = Self(
        fetchPlaybackStatus: { _, _ in nil },
        createPlexPIN: { PlexSignInPIN(id: 1, code: "test", signInURL: URL(string: "https://plex.tv/link/?pin=test")!) },
        pollPlexPIN: { _, _ in nil },
        discoverPlexServers: { _ in [] },
        authenticateEmby: { _, _, _ in
            EmbyAuthenticatedSession(serverID: "test", userID: "test", userName: "Test", accessToken: "test")
        }
    )
}

private nonisolated func rawMediaServerItemID(
    _ stableID: String,
    provider: PlaylistType,
    serverID: String
) -> String? {
    let prefix = "\(provider.rawValue)|\(serverID)|"
    guard stableID.hasPrefix(prefix) else { return nil }
    let value = String(stableID.dropFirst(prefix.count))
    guard !value.isEmpty, value.count <= 256,
          value.utf8.allSatisfy({ byte in
              (48 ... 57).contains(byte) || (65 ... 90).contains(byte) || (97 ... 122).contains(byte)
                  || byte == 45 || byte == 46 || byte == 95
          }) else { return nil }
    return value
}

private struct PlexPlaybackSessionsResponse: Decodable {
    let mediaContainer: PlexPlaybackSessionsContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

private struct PlexPlaybackSessionsContainer: Decodable {
    let metadata: [PlexPlaybackSession]

    enum CodingKeys: String, CodingKey {
        case metadata = "Metadata"
    }
}

private struct PlexPlaybackSession: Decodable {
    let ratingKey: String?
    let media: [PlexPlaybackSessionMedia]?
    let player: PlexPlaybackSessionPlayer?

    enum CodingKeys: String, CodingKey {
        case ratingKey
        case media = "Media"
        case player = "Player"
    }
}

private struct PlexPlaybackSessionPlayer: Decodable {
    let machineIdentifier: String?

    enum CodingKeys: String, CodingKey {
        case machineIdentifier
    }
}

private struct PlexPlaybackSessionMedia: Decodable {
    let selected: Bool?
    let videoResolution: String?
    let bitrate: Int?
    let parts: [PlexPlaybackSessionPart]

    enum CodingKeys: String, CodingKey {
        case selected
        case videoResolution
        case bitrate
        case parts = "Part"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selected = try container.decodeIfPresent(Bool.self, forKey: .selected)
        videoResolution = try container.decodeIfPresent(String.self, forKey: .videoResolution)
        bitrate = try container.decodeIfPresent(Int.self, forKey: .bitrate)
        parts = try container.decodeIfPresent([PlexPlaybackSessionPart].self, forKey: .parts) ?? []
    }
}

private struct PlexPlaybackSessionPart: Decodable {
    let selected: Bool?
    let decision: String?

    enum CodingKeys: String, CodingKey {
        case selected
        case decision
    }
}

private struct EmbyPlaybackSession: Decodable {
    let deviceID: String?
    let userID: String?
    let nowPlayingItem: EmbyPlaybackSessionItem?
    let playState: EmbyPlaybackSessionPlayState?
    let transcodingInfo: EmbyPlaybackSessionTranscodingInfo?

    enum CodingKeys: String, CodingKey {
        case deviceID = "DeviceId"
        case userID = "UserId"
        case nowPlayingItem = "NowPlayingItem"
        case playState = "PlayState"
        case transcodingInfo = "TranscodingInfo"
    }
}

private struct EmbyPlaybackSessionItem: Decodable {
    let id: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
    }
}

private struct EmbyPlaybackSessionPlayState: Decodable {
    let playMethod: String?
    let mediaSource: EmbyPlaybackSessionMediaSource?

    enum CodingKeys: String, CodingKey {
        case playMethod = "PlayMethod"
        case mediaSource = "MediaSource"
    }
}

private struct EmbyPlaybackSessionMediaSource: Decodable {
    let bitrate: Int?
    let mediaStreams: [EmbyPlaybackSessionMediaStream]?

    enum CodingKeys: String, CodingKey {
        case bitrate = "Bitrate"
        case mediaStreams = "MediaStreams"
    }
}

private struct EmbyPlaybackSessionMediaStream: Decodable {
    let type: String?
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case width = "Width"
        case height = "Height"
    }
}

private struct EmbyPlaybackSessionTranscodingInfo: Decodable {
    let bitrate: Int?
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case bitrate = "Bitrate"
        case width = "Width"
        case height = "Height"
    }
}

public extension DependencyValues {
    var mediaServerClient: MediaServerClient {
        get { self[MediaServerClient.self] }
        set { self[MediaServerClient.self] = newValue }
    }
}

nonisolated enum MediaServerIdentity {
    private static let clientIdentifierKey = "com.pureiptv.mediaServer.clientIdentifier"
    private static let deviceIdentifierKey = "com.pureiptv.mediaServer.deviceIdentifier"

    static var clientIdentifier: String {
        persistentIdentifier(for: clientIdentifierKey)
    }

    static var embyAuthorizationHeader: String {
        "Emby Client=PureIPTV, Device=\(deviceName), DeviceId=\(deviceIdentifier), Version=1"
    }

    static var deviceName: String {
        #if os(tvOS)
            "Apple TV"
        #elseif os(iOS)
            "iPhone or iPad"
        #else
            "Apple Device"
        #endif
    }

    static var deviceIdentifier: String {
        persistentIdentifier(for: deviceIdentifierKey)
    }

    static func validatedBaseURL(_ input: URL) -> URL? {
        guard var components = URLComponents(url: input, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil
        else { return nil }
        components.query = nil
        components.fragment = nil
        if !components.path.hasSuffix("/") {
            components.path += "/"
        }
        return components.url
    }

    static func validatedPlexBaseURL(_ input: URL) -> URL? {
        guard var components = URLComponents(url: input, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil
        else { return nil }
        components.query = nil
        components.fragment = nil
        if !components.path.hasSuffix("/") {
            components.path += "/"
        }
        return components.url
    }

    private static func persistentIdentifier(for key: String) -> String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

/// Keeps provider credentials in memory for request construction and image loading.
/// Cache keys use only the playlist UUID; request headers never become part of a URL or media ID.
enum MediaServerRequestContextFactory {
    private final nonisolated class ContextBox: NSObject, @unchecked Sendable {
        let context: MediaServerRequestContext
        let serverBaseURL: URL

        init(_ context: MediaServerRequestContext, serverBaseURL: URL) {
            self.context = context
            self.serverBaseURL = serverBaseURL
        }
    }

    private nonisolated(unsafe) static let contextsByPlaylistID = NSCache<NSString, ContextBox>()

    nonisolated static func context(for config: PlaylistConfig) -> MediaServerRequestContext? {
        guard let credentials = config.mediaServerCredentials else { return nil }
        switch config.type {
        case .plex:
            guard opaqueIdentifier(credentials.serverID) != nil,
                  !credentials.accessToken.isEmpty else { return nil }
            return .plex(
                accessToken: credentials.accessToken,
                clientIdentifier: MediaServerIdentity.clientIdentifier
            )
        case .emby:
            guard let userID = credentials.userID.flatMap(opaqueIdentifier),
                  !credentials.accessToken.isEmpty else { return nil }
            return .emby(
                accessToken: credentials.accessToken,
                userID: userID,
                clientIdentifier: "PureIPTV",
                deviceName: MediaServerIdentity.deviceName,
                deviceID: MediaServerIdentity.deviceIdentifier
            )
        case .xtream, .m3u:
            return nil
        }
    }

    nonisolated static func baseURL(for config: PlaylistConfig) -> URL? {
        guard let serverURL = config.serverURL else { return nil }
        switch config.type {
        case .plex:
            return MediaServerIdentity.validatedPlexBaseURL(serverURL)
        case .emby:
            return MediaServerIdentity.validatedBaseURL(serverURL)
        case .xtream, .m3u:
            return nil
        }
    }

    nonisolated static func register(_ config: PlaylistConfig) {
        guard let playlistID = config.playlistID,
              let context = context(for: config),
              let serverBaseURL = baseURL(for: config)
        else { return }
        contextsByPlaylistID.setObject(ContextBox(context, serverBaseURL: serverBaseURL), forKey: playlistID.uuidString as NSString)
    }

    nonisolated static func cachedContext(for playlistID: UUID?, requestURL: URL?) -> MediaServerRequestContext? {
        guard let playlistID, let requestURL,
              let box = contextsByPlaylistID.object(forKey: playlistID.uuidString as NSString),
              isWithinServerOrigin(requestURL, baseURL: box.serverBaseURL)
        else { return nil }
        return box.context
    }

    nonisolated static func removeCachedContext(for playlistID: UUID) {
        contextsByPlaylistID.removeObject(forKey: playlistID.uuidString as NSString)
    }

    private nonisolated static func opaqueIdentifier(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 256,
              trimmed.utf8.allSatisfy({ byte in
                  (48 ... 57).contains(byte) || (65 ... 90).contains(byte) || (97 ... 122).contains(byte)
                      || byte == 45 || byte == 46 || byte == 95
              }) else { return nil }
        return trimmed
    }

    private nonisolated static func isWithinServerOrigin(_ url: URL, baseURL: URL) -> Bool {
        guard url.scheme?.lowercased() == baseURL.scheme?.lowercased(),
              url.host?.caseInsensitiveCompare(baseURL.host ?? "") == .orderedSame,
              url.port == baseURL.port,
              url.user == nil,
              url.password == nil else { return false }
        let basePath = baseURL.path.hasSuffix("/") ? baseURL.path : baseURL.path + "/"
        return url.path == String(basePath.dropLast()) || url.path.hasPrefix(basePath)
    }
}

private struct PlexPINResponse: Decodable {
    let id: Int
    let code: String
    let authToken: String?

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case authToken
    }
}

private struct PlexResourceDevice: Decodable {
    let name: String?
    let clientIdentifier: String?
    let accessToken: String?
    let connections: [PlexResourceConnection]

    enum CodingKeys: String, CodingKey {
        case name
        case clientIdentifier
        case accessToken
        case connections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        clientIdentifier = try container.decodeIfPresent(String.self, forKey: .clientIdentifier)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
        connections = try container.decodeIfPresent([PlexResourceConnection].self, forKey: .connections) ?? []
    }
}

private struct PlexResourceConnection: Decodable {
    let uri: String
    let local: Bool?
    let relay: Bool?

    private enum CodingKeys: String, CodingKey {
        case uri
        case local
        case relay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uri = try container.decode(String.self, forKey: .uri)
        local = try container.decodeFlexibleBooleanIfPresent(forKey: .local)
        relay = try container.decodeFlexibleBooleanIfPresent(forKey: .relay)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleBooleanIfPresent(forKey key: Key) throws -> Bool? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) {
            return nil
        }
        if let value = try? decode(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return value != 0
        }
        return nil
    }
}

private struct EmbyAuthenticationRequest: Encodable {
    let username: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case username = "Username"
        case password = "Pw"
    }
}

private struct EmbyAuthenticationResponse: Decodable {
    let accessToken: String?
    let serverID: String?
    let user: EmbyUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "AccessToken"
        case serverID = "ServerId"
        case user = "User"
    }
}

private struct EmbyUser: Decodable {
    let id: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
