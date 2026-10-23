import Foundation

public struct PlaylistConfig: Equatable, Sendable {
    public let type: PlaylistType

    // Xtream
    public let serverURL: URL?
    public let username: String?
    public let password: String?

    /// M3U
    public let m3uURL: URL?

    public nonisolated init(
        type: PlaylistType,
        serverURL: URL? = nil,
        username: String? = nil,
        password: String? = nil,
        m3uURL: URL? = nil
    ) {
        self.type = type
        self.serverURL = serverURL
        self.username = username
        self.password = password
        self.m3uURL = m3uURL
    }
}
