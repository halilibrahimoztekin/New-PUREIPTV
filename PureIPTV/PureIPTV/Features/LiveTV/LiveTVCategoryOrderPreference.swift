import Foundation

public enum LiveTVCategoryOrder: String, CaseIterable, Equatable, Hashable, Sendable {
    case provider
    case custom
    case alphabetical

    var title: String {
        switch self {
        case .provider: AppStrings.LiveTV.categoryOrderProvider
        case .custom: AppStrings.LiveTV.categoryOrderCustom
        case .alphabetical: AppStrings.LiveTV.categoryOrderAlphabetical
        }
    }
}

enum LiveTVCategoryOrderPreferenceStore {
    private static let keyPrefix = "com.pureiptv.liveTVCategoryOrder.v1"

    static func load(playlistID: UUID?) -> LiveTVCategoryOrder {
        guard let playlistID,
              let rawValue = UserDefaults.standard.string(forKey: key(playlistID: playlistID)),
              let order = LiveTVCategoryOrder(rawValue: rawValue)
        else { return .custom }
        return order
    }

    static func save(_ order: LiveTVCategoryOrder, playlistID: UUID?) {
        guard let playlistID else { return }
        UserDefaults.standard.set(order.rawValue, forKey: key(playlistID: playlistID))
    }

    private static func key(playlistID: UUID) -> String {
        "\(keyPrefix).\(playlistID.uuidString.lowercased())"
    }
}

enum LiveTVFocusPreferenceKeys {
    static let favoriteChannelWrapAround = "com.pureiptv.tvOSFavoriteChannelWrapAroundFocus"
}
