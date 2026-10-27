import CryptoKit
import Foundation
import SwiftUI

private func stablePlaylistSourceID(for config: PlaylistConfig) -> String {
    if let playlistID = config.playlistID {
        return PlaylistSourceBadge.sourceID(for: playlistID)
    }

    // Unsaved sources still need distinct identities. Hash the full source
    // descriptor so playlist credentials and URL tokens never appear in IDs.
    let components = [
        config.type.rawValue,
        config.serverURL?.absoluteString ?? "",
        config.username ?? "",
        config.password ?? "",
        config.m3uURL?.absoluteString ?? "",
        config.userAgentOverride ?? "",
    ]
    let descriptor = components.map { "\($0.utf8.count):\($0)" }.joined()
    let digest = SHA256.hash(data: Data(descriptor.utf8))
    let hexadecimal = digest.map { String(format: "%02x", $0) }.joined()
    return "source:sha256:\(hexadecimal)"
}

public struct PlaylistSourceBadge: Identifiable, Equatable, Sendable {
    public nonisolated static func sourceID(for playlistID: UUID) -> String {
        "playlist:\(playlistID.uuidString.lowercased())"
    }

    public let id: String
    public let reminderIdentity: String
    public let playlistName: String
    public let colorHex: String

    public nonisolated init(id: String, playlistName: String, colorHex: String, reminderIdentity: String? = nil) {
        self.id = id
        self.reminderIdentity = reminderIdentity ?? id
        self.playlistName = playlistName
        self.colorHex = colorHex
    }

    public var color: Color {
        Color(hex: colorHex)
    }
}

/// A provider channel that retains the source needed for playback and EPG routing.
/// Provider item IDs are only unique inside their playlist, so `id` is source-scoped.
public struct UnifiedPlaylistChannel: Identifiable, Equatable, Sendable {
    public let item: MediaModels.Item
    public let config: PlaylistConfig
    public let sourceBadge: PlaylistSourceBadge

    public var id: String {
        let components = [sourceBadge.id, item.id]
        return "unified-channel-v1|" + components.map { "\($0.utf8.count):\($0)" }.joined()
    }

    public nonisolated init(item: MediaModels.Item, config: PlaylistConfig, sourceBadge: PlaylistSourceBadge) {
        self.item = item
        self.config = config
        self.sourceBadge = sourceBadge
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
        let id = stablePlaylistSourceID(for: playlistConfig)
        let colorHex = paletteHex[abs(index) % paletteHex.count]
        return PlaylistSourceBadge(
            id: id,
            playlistName: name,
            colorHex: colorHex,
            reminderIdentity: EPGReminderIdentifier.playlistIdentity(for: playlistConfig)
        )
    }

    /// Combines channels without collapsing provider-local ID collisions and keeps
    /// each channel's source config available to callers that route playback or EPG.
    public nonisolated func mergeChannels(
        from playlistChannels: [(config: PlaylistConfig, channels: [MediaModels.Item])]
    ) -> [UnifiedPlaylistChannel] {
        var seenIDs: Set<String> = []
        return playlistChannels.enumerated().flatMap { index, source in
            let sourceBadge = badge(for: source.config, index: index)
            return source.channels.compactMap { item in
                let channel = UnifiedPlaylistChannel(item: item, config: source.config, sourceBadge: sourceBadge)
                return seenIDs.insert(channel.id).inserted ? channel : nil
            }
        }
    }
}
