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
    public let userAgentOverride: String?

    public init(
        id: UUID = UUID(),
        name: String,
        type: PlaylistType,
        serverURL: String? = nil,
        username: String? = nil,
        password: String? = nil,
        m3uURL: String? = nil,
        userAgentOverride: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.serverURL = serverURL
        self.username = username
        self.password = password
        self.m3uURL = m3uURL
        self.userAgentOverride = userAgentOverride
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
                userAgentOverride: userAgentOverride
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
                userAgentOverride: userAgentOverride
            )
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
            userAgentOverride: value
        )
    }
}
