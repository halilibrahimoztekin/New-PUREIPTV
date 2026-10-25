import Foundation
import SwiftUI

public struct PlaylistSourceBadge: Identifiable, Equatable, Sendable {
    public let id: String
    public let playlistName: String
    public let colorHex: String

    public nonisolated init(id: String, playlistName: String, colorHex: String) {
        self.id = id
        self.playlistName = playlistName
        self.colorHex = colorHex
    }

    public var color: Color {
        Color(hex: colorHex)
    }
}

public final class UnifiedPlaylistManager: @unchecked Sendable {
    public nonisolated static let shared = UnifiedPlaylistManager()

    private let paletteHex = [
        "#0A84FF", // Blue
        "#30D158", // Green
        "#FF9F0A", // Orange
        "#BF5AF2", // Purple
        "#FF375F", // Pink
        "#64D2FF", // Cyan
    ]

    private init() {}

    public nonisolated func badge(for playlistConfig: PlaylistConfig, index: Int = 0) -> PlaylistSourceBadge {
        let name = playlistConfig.serverURL?.host ?? playlistConfig.m3uURL?.lastPathComponent ?? "Playlist \(index + 1)"
        let id = EPGReminderIdentifier.playlistIdentity(for: playlistConfig)
        let colorHex = paletteHex[abs(index) % paletteHex.count]
        return PlaylistSourceBadge(id: id, playlistName: name, colorHex: colorHex)
    }

    /// Merges channels across multiple playlists, attaching source playlist badges to prevent duplicates
    public nonisolated func mergeChannels(from playlistChannels: [(config: PlaylistConfig, channels: [MediaModels.Item])]) -> [MediaModels.Item] {
        var merged: [MediaModels.Item] = []
        var seenIDs: Set<String> = []

        for (_, channels) in playlistChannels {
            for channel in channels {
                if !seenIDs.contains(channel.id) {
                    seenIDs.insert(channel.id)
                    merged.append(channel)
                }
            }
        }
        return merged
    }
}
