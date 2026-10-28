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
public struct ChannelPresentationEditorRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let homeRouteIndex: Int
        public let channel: MediaModels.Item
        public let playlistID: UUID
        public let profileScope: ProfileContextSnapshot

        public init(
            homeRouteIndex: Int,
            channel: MediaModels.Item,
            playlistID: UUID,
            profileScope: ProfileContextSnapshot,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.homeRouteIndex = homeRouteIndex
            self.channel = channel
            self.playlistID = playlistID
            self.profileScope = profileScope
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
public struct M3UCategoryMappingEditorRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let categoryRouteIndex: Int
        public let categoryPresentationID: UUID
        public let homeRouteIndex: Int
        public let config: PlaylistConfig

        public init(
            categoryRouteIndex: Int,
            categoryPresentationID: UUID,
            homeRouteIndex: Int,
            config: PlaylistConfig,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.categoryRouteIndex = categoryRouteIndex
            self.categoryPresentationID = categoryPresentationID
            self.homeRouteIndex = homeRouteIndex
            self.config = config
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
public struct MultiViewChannelSelectionRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let multiViewRouteIndex: Int
        public let multiViewPresentationID: UUID
        public let slotID: Int

        public init(
            multiViewRouteIndex: Int,
            multiViewPresentationID: UUID,
            slotID: Int,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.multiViewRouteIndex = multiViewRouteIndex
            self.multiViewPresentationID = multiViewPresentationID
            self.slotID = slotID
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
public struct DashboardPresentationRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public enum Presentation: Equatable {
            case homeSettings(reloadConfig: PlaylistConfig)
            case categoryPinManagement(playlistID: UUID?, profileScope: ProfileContextSnapshot?)
            case epgChannelPicker(playlistID: UUID, profileScope: ProfileContextSnapshot?, event: DashboardFeature.EPGEvent)
        }

        public let presentationID: UUID
        public let homeRouteIndex: Int
        public let homeConfig: PlaylistConfig
        public let presentation: Presentation

        public init(
            homeRouteIndex: Int,
            homeConfig: PlaylistConfig,
            presentation: Presentation,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.homeRouteIndex = homeRouteIndex
            self.homeConfig = homeConfig
            self.presentation = presentation
        }
    }

    public enum Action {
        case closeTapped
        case selectEPGChannel(MediaModels.Item)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID)
            case selectEPGChannel(presentationID: UUID, channel: MediaModels.Item)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(presentationID: state.presentationID)))

            case let .selectEPGChannel(channel):
                guard case .epgChannelPicker = state.presentation else { return .none }
                return .send(.delegate(.selectEPGChannel(
                    presentationID: state.presentationID,
                    channel: channel
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct PlaylistQRTransferConfirmationRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let sessionID: UUID

        public init(sessionID: UUID, presentationID: UUID = UUID()) {
            self.presentationID = presentationID
            self.sessionID = sessionID
        }
    }

    public enum Action {
        case cancelTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case cancel(presentationID: UUID, sessionID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .cancelTapped:
                return .send(.delegate(.cancel(
                    presentationID: state.presentationID,
                    sessionID: state.sessionID
                )))

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
    case channelPresentationEditor(ChannelPresentationEditorRouteFeature)
    case m3uCategoryMappingEditor(M3UCategoryMappingEditorRouteFeature)
    case multiViewChannelSelection(MultiViewChannelSelectionRouteFeature)
    case dashboardPresentation(DashboardPresentationRouteFeature)
    case playlistQRTransferConfirmation(PlaylistQRTransferConfirmationRouteFeature)
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
        case let (.channelPresentationEditor(l), .channelPresentationEditor(r)): l.presentationID == r.presentationID
        case let (.m3uCategoryMappingEditor(l), .m3uCategoryMappingEditor(r)): l.presentationID == r.presentationID
        case let (.multiViewChannelSelection(l), .multiViewChannelSelection(r)): l.presentationID == r.presentationID
        case let (.dashboardPresentation(l), .dashboardPresentation(r)): l.presentationID == r.presentationID
        case let (.playlistQRTransferConfirmation(l), .playlistQRTransferConfirmation(r)): l.presentationID == r.presentationID
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
        case let .channelPresentationEditor(state):
            hasher.combine(16)
            hasher.combine(state.presentationID)
        case let .m3uCategoryMappingEditor(state):
            hasher.combine(17)
            hasher.combine(state.presentationID)
        case let .multiViewChannelSelection(state):
            hasher.combine(18)
            hasher.combine(state.presentationID)
        case let .dashboardPresentation(state):
            hasher.combine(19)
            hasher.combine(state.presentationID)
        case let .playlistQRTransferConfirmation(state):
            hasher.combine(20)
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
