import Foundation

public enum MediaServerPlaybackPreference: String, Codable, CaseIterable, Equatable, Sendable, Identifiable {
    case automatic
    case directStreamOnly

    public var id: String {
        rawValue
    }
}

public struct PlaylistConfig: Equatable, Sendable {
    public let playlistID: UUID?
    public let type: PlaylistType

    // Xtream
    public let serverURL: URL?
    public let username: String?
    public let password: String?

    /// M3U
    public let m3uURL: URL?
    public let mediaServerCredentials: MediaServerCredentials?
    public let mediaServerPlaybackPreference: MediaServerPlaybackPreference
    /// Optional provider-specific HTTP User-Agent. `nil` keeps the app default.
    public let userAgentOverride: String?
    /// Wait after stopping the previous live stream before opening the next one.
    public let channelZappingDelayMilliseconds: Int

    public nonisolated init(
        playlistID: UUID? = nil,
        type: PlaylistType,
        serverURL: URL? = nil,
        username: String? = nil,
        password: String? = nil,
        m3uURL: URL? = nil,
        mediaServerCredentials: MediaServerCredentials? = nil,
        mediaServerPlaybackPreference: MediaServerPlaybackPreference = .automatic,
        userAgentOverride: String? = nil,
        channelZappingDelayMilliseconds: Int = 0
    ) {
        self.playlistID = playlistID
        self.type = type
        self.serverURL = serverURL
        self.username = username
        self.password = password
        self.m3uURL = m3uURL
        self.mediaServerCredentials = mediaServerCredentials
        self.mediaServerPlaybackPreference = mediaServerPlaybackPreference
        self.userAgentOverride = userAgentOverride
        self.channelZappingDelayMilliseconds = min(max(channelZappingDelayMilliseconds, 0), 3000)
    }

    public func replacingUserAgentOverride(_ value: String?) -> Self {
        Self(
            playlistID: playlistID,
            type: type,
            serverURL: serverURL,
            username: username,
            password: password,
            m3uURL: m3uURL,
            mediaServerCredentials: mediaServerCredentials,
            mediaServerPlaybackPreference: mediaServerPlaybackPreference,
            userAgentOverride: value,
            channelZappingDelayMilliseconds: channelZappingDelayMilliseconds
        )
    }

    public func replacingChannelZappingDelayMilliseconds(_ value: Int) -> Self {
        Self(
            playlistID: playlistID,
            type: type,
            serverURL: serverURL,
            username: username,
            password: password,
            m3uURL: m3uURL,
            mediaServerCredentials: mediaServerCredentials,
            mediaServerPlaybackPreference: mediaServerPlaybackPreference,
            userAgentOverride: userAgentOverride,
            channelZappingDelayMilliseconds: value
        )
    }
}
