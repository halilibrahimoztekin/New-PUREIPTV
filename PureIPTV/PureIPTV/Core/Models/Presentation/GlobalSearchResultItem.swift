import Foundation
import SwiftUI

// MARK: - Global Search Result Item

public struct GlobalSearchResultItem: Identifiable, Equatable, Sendable {
    public var id: String {
        "\(playlistBadge.id)_\(item.id)"
    }

    public let item: MediaModels.Item
    public let playlistBadge: PlaylistSourceBadge
    public let is4K: Bool
    public let matchedEPGTitle: String?
    public let score: Int

    public nonisolated init(
        item: MediaModels.Item,
        playlistBadge: PlaylistSourceBadge,
        is4K: Bool? = nil,
        matchedEPGTitle: String? = nil,
        score: Int = 0
    ) {
        self.item = item
        self.playlistBadge = playlistBadge
        let lower = item.title.lowercased()
        self.is4K = is4K ?? (
            lower.contains("4k") ||
                lower.contains("uhd") ||
                lower.contains("ultra hd") ||
                lower.contains("2160p")
        )
        self.matchedEPGTitle = matchedEPGTitle
        self.score = score
    }

    @MainActor
    public var contentTypeTitle: String {
        switch item.type {
        case .live: AppStrings.Search.liveTV
        case .vod: AppStrings.Search.movies
        case .series: AppStrings.Search.series
        }
    }

    public nonisolated var contentTypeIcon: String {
        switch item.type {
        case .live: "tv.fill"
        case .vod: "film.fill"
        case .series: "play.tv.fill"
        }
    }

    public nonisolated var contentTypeColorHex: String {
        switch item.type {
        case .live: "#0A84FF" // Electric Blue
        case .vod: "#BF5AF2" // Obsidian Purple
        case .series: "#FF9F0A" // Sunset Amber
        }
    }

    public nonisolated var contentTypeColor: Color {
        Color(hex: contentTypeColorHex)
    }
}
