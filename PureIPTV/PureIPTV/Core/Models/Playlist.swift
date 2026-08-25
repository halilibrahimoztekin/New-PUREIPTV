import Foundation
import SwiftData

public enum PlaylistType: String, Codable, CaseIterable, Equatable {
    case xtream
    case m3u

    /// Human-readable display name used in the UI picker
    public var displayName: String {
        switch self {
        case .xtream: return "Xtream Codes"
        case .m3u: return "M3U URL"
        }
    }
}

@Model
public final class Playlist {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var type: String // Stored as string for SwiftData compatibility

    public var playlistType: PlaylistType {
        get { PlaylistType(rawValue: type) ?? .m3u }
        set { type = newValue.rawValue }
    }

    /// M3U specific
    public var m3uURL: String?

    // Xtream specific
    public var xtreamURL: String?
    public var xtreamUsername: String?
    public var xtreamPassword: String?

    public init(id: UUID = UUID(), name: String, type: PlaylistType) {
        self.id = id
        self.name = name
        self.type = type.rawValue
    }
}
