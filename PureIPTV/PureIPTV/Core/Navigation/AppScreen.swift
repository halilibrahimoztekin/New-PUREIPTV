import ComposableArchitecture
import Foundation

@Reducer
public enum AppScreen {
    case splash(SplashFeature)
    case onboarding(OnboardingFeature)
    case addPlaylist(AddPlaylistFeature)
    case profileSelection(ProfileSelectionFeature)
    case home(HomeFeature)
    case player(PlayerFeature)
    case seriesDetail(SeriesDetailFeature)
    case vodDetail(VODDetailFeature)
    case playlistManagement(PlaylistManagementFeature)
    case paywall(PaywallFeature)
}

extension AppScreen.State: Hashable {
    public static func == (lhs: AppScreen.State, rhs: AppScreen.State) -> Bool {
        switch (lhs, rhs) {
        case let (.splash(l), .splash(r)): l == r
        case let (.onboarding(l), .onboarding(r)): l == r
        case let (.addPlaylist(l), .addPlaylist(r)): l == r
        case let (.profileSelection(l), .profileSelection(r)): l == r
        case let (.home(l), .home(r)): l == r
        case let (.player(l), .player(r)): l == r
        case let (.seriesDetail(l), .seriesDetail(r)): l == r
        case let (.vodDetail(l), .vodDetail(r)): l == r
        case let (.playlistManagement(l), .playlistManagement(r)): l == r
        case let (.paywall(l), .paywall(r)): l == r
        default: false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .splash:
            hasher.combine(0)
        case .onboarding:
            hasher.combine(1)
        case .addPlaylist:
            hasher.combine(2)
        case .profileSelection:
            hasher.combine(3)
        case .home:
            hasher.combine(4)
        case let .player(state):
            hasher.combine(5)
            hasher.combine(state.item.id)
        case let .seriesDetail(state):
            hasher.combine(6)
            hasher.combine(state.series.id)
        case let .vodDetail(state):
            hasher.combine(7)
            hasher.combine(state.vod.id)
        case .playlistManagement:
            hasher.combine(8)
        case .paywall:
            hasher.combine(9)
        }
    }
}
