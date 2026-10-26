import Foundation

public struct SavedPlaylist: Equatable, Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let type: PlaylistType

    // Xtream fields
    public let serverURL: String?
    public let username: String?
    public let password: String?

    /// M3U fields
    public let m3uURL: String?
    /// Provider session secret, persisted only inside the encrypted Keychain playlist record.
    public let mediaServerCredentials: MediaServerCredentials?
    public let userAgentOverride: String?
    /// Optional to decode playlists saved before this setting existed.
    public let channelZappingDelayMilliseconds: Int?

    public init(
        id: UUID = UUID(),
        name: String,
        type: PlaylistType,
        serverURL: String? = nil,
        username: String? = nil,
        password: String? = nil,
        m3uURL: String? = nil,
        mediaServerCredentials: MediaServerCredentials? = nil,
        userAgentOverride: String? = nil,
        channelZappingDelayMilliseconds: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.serverURL = serverURL
        self.username = username
        self.password = password
        self.m3uURL = m3uURL
        self.mediaServerCredentials = mediaServerCredentials
        self.userAgentOverride = userAgentOverride
        self.channelZappingDelayMilliseconds = channelZappingDelayMilliseconds.map { min(max($0, 0), 3000) }
    }

    /// Converts SavedPlaylist to an active PlaylistConfig instance if valid credentials exist.
    public nonisolated func toPlaylistConfig() -> PlaylistConfig? {
        if type == .xtream {
            guard let serverURLStr = serverURL,
                  let url = URL(string: serverURLStr),
                  let username,
                  let password
            else {
                return nil
            }
            return PlaylistConfig(
                playlistID: id,
                type: .xtream,
                serverURL: url,
                username: username,
                password: password,
                userAgentOverride: userAgentOverride,
                channelZappingDelayMilliseconds: channelZappingDelayMilliseconds ?? 0
            )
        } else if type == .m3u {
            guard let m3uURLStr = m3uURL,
                  let url = URL(string: m3uURLStr)
            else {
                return nil
            }
            return PlaylistConfig(
                playlistID: id,
                type: .m3u,
                m3uURL: url,
                userAgentOverride: userAgentOverride,
                channelZappingDelayMilliseconds: channelZappingDelayMilliseconds ?? 0
            )
        } else if type == .plex || type == .emby {
            guard let serverURLString = serverURL,
                  let url = URL(string: serverURLString),
                  let mediaServerCredentials
            else { return nil }
            let config = PlaylistConfig(
                playlistID: id,
                type: type,
                serverURL: url,
                mediaServerCredentials: mediaServerCredentials,
                userAgentOverride: userAgentOverride,
                channelZappingDelayMilliseconds: channelZappingDelayMilliseconds ?? 0
            )
            MediaServerRequestContextFactory.register(config)
            return config
        }
        return nil
    }

    public func replacingUserAgentOverride(_ value: String?) -> SavedPlaylist {
        SavedPlaylist(
            id: id,
            name: name,
            type: type,
            serverURL: serverURL,
            username: username,
            password: password,
            m3uURL: m3uURL,
            mediaServerCredentials: mediaServerCredentials,
            userAgentOverride: value,
            channelZappingDelayMilliseconds: channelZappingDelayMilliseconds
        )
    }

    public func replacingChannelZappingDelayMilliseconds(_ value: Int) -> SavedPlaylist {
        SavedPlaylist(
            id: id,
            name: name,
            type: type,
            serverURL: serverURL,
            username: username,
            password: password,
            m3uURL: m3uURL,
            mediaServerCredentials: mediaServerCredentials,
            userAgentOverride: userAgentOverride,
            channelZappingDelayMilliseconds: value
        )
    }

    public func replacingConnection(
        serverURL: String?,
        username: String?,
        password: String?,
        m3uURL: String?
    ) -> SavedPlaylist {
        SavedPlaylist(
            id: id,
            name: name,
            type: type,
            serverURL: serverURL,
            username: username,
            password: password,
            m3uURL: m3uURL,
            mediaServerCredentials: mediaServerCredentials,
            userAgentOverride: userAgentOverride,
            channelZappingDelayMilliseconds: channelZappingDelayMilliseconds
        )
    }
}

public struct MediaServerCredentials: Codable, Equatable, Sendable {
    public let serverID: String
    public let userID: String?
    public let accessToken: String
    public let accountToken: String?

    public init(serverID: String, userID: String? = nil, accessToken: String, accountToken: String? = nil) {
        self.serverID = serverID
        self.userID = userID
        self.accessToken = accessToken
        self.accountToken = accountToken
    }
}
