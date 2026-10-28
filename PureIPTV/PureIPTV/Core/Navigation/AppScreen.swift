import ComposableArchitecture
import Foundation

@Reducer
public struct SmartChannelGroupManagementRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let homeRouteIndex: Int

        public init(homeRouteIndex: Int, presentationID: UUID = UUID()) {
            self.presentationID = presentationID
            self.homeRouteIndex = homeRouteIndex
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(presentationID: state.presentationID)))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public enum AppScreen {
    case splash(SplashFeature)
    case onboarding(OnboardingFeature)
    case addPlaylist(AddPlaylistFeature)
    case profileSelection(ProfileSelectionFeature)
    case home(HomeFeature)
    case player(PlayerFeature)
    case epgGuide(EPGGuideFeature)
    case epgTimeline(EPGTimelineFeature)
    case multiView(MultiViewFeature)
    case categoryManagement(CategoryManagementFeature)
    case parentalLock(ParentalLockFeature)
    case smartChannelGroupManagement(SmartChannelGroupManagementRouteFeature)
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
        case let (.epgGuide(l), .epgGuide(r)): l.presentationID == r.presentationID
        case let (.epgTimeline(l), .epgTimeline(r)): l.presentationID == r.presentationID
        case let (.multiView(l), .multiView(r)): l.presentationID == r.presentationID
        case let (.categoryManagement(l), .categoryManagement(r)): l.presentationID == r.presentationID
        case let (.parentalLock(l), .parentalLock(r)): l.presentationID == r.presentationID
        case let (.smartChannelGroupManagement(l), .smartChannelGroupManagement(r)): l.presentationID == r.presentationID
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
        case let .epgGuide(state):
            hasher.combine(10)
            hasher.combine(state.presentationID)
        case let .epgTimeline(state):
            hasher.combine(11)
            hasher.combine(state.presentationID)
        case let .multiView(state):
            hasher.combine(12)
            hasher.combine(state.presentationID)
        case let .categoryManagement(state):
            hasher.combine(13)
            hasher.combine(state.presentationID)
        case let .parentalLock(state):
            hasher.combine(14)
            hasher.combine(state.presentationID)
        case let .smartChannelGroupManagement(state):
            hasher.combine(15)
            hasher.combine(state.presentationID)
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
