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

    public init(
        id: UUID = UUID(),
        name: String,
        type: PlaylistType,
        serverURL: String? = nil,
        username: String? = nil,
        password: String? = nil,
        m3uURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.serverURL = serverURL
        self.username = username
        self.password = password
        self.m3uURL = m3uURL
    }
}
