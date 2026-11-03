import Foundation
import SwiftUI

public struct CategorySearchResultItem: Identifiable, Equatable, Sendable {
    public var id: String {
        let components = [type.rawValue, playlistBadge.id, category.id]
        return "category-result-v1|" + components.map { "\($0.utf8.count):\($0)" }.joined()
    }

    public let category: MediaModels.Category
    public let type: MediaModels.ItemType
    public let playlistBadge: PlaylistSourceBadge
    public let playlistID: UUID?
    public let itemCount: Int
    public let score: Int

    public nonisolated init(
        category: MediaModels.Category,
        type: MediaModels.ItemType,
        playlistBadge: PlaylistSourceBadge,
        playlistID: UUID? = nil,
        itemCount: Int = 0,
        score: Int = 0
    ) {
        self.category = category
        self.type = type
        self.playlistBadge = playlistBadge
        self.playlistID = playlistID
        self.itemCount = itemCount
        self.score = score
    }

    @MainActor
    public var typeTitle: String {
        switch type {
        case .live: AppStrings.Search.liveTV
        case .vod: AppStrings.Search.movies
        case .series: AppStrings.Search.series
        }
    }

    public nonisolated var typeIcon: String {
        switch type {
        case .live: "tv.fill"
        case .vod: "film.fill"
        case .series: "play.tv.fill"
        }
    }

    public nonisolated var typeColorHex: String {
        switch type {
        case .live: "#0A84FF" // Electric Blue
        case .vod: "#BF5AF2" // Cinema Violet
        case .series: "#FF9F0A" // Sunset Amber
        }
    }

    public var typeColor: Color {
        switch type {
        case .live: AppColors.primary
        case .vod: AppColors.premium
        case .series: AppColors.amber
        }
    }

    @MainActor
    public var formattedItemCount: String {
        switch type {
        case .live: String(format: AppStrings.Search.channelCountFormat, itemCount)
        case .vod: String(format: AppStrings.Search.movieCountFormat, itemCount)
        case .series: String(format: AppStrings.Search.seriesCountFormat, itemCount)
        }
    }
}
