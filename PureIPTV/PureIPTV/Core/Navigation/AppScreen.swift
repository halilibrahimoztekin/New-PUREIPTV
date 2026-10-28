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
public struct PlaylistManagementSettingsRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let playlistManagementRouteIndex: Int
        public let editRequestID: UUID
        public let playlistID: UUID

        public init(
            playlistManagementRouteIndex: Int,
            editRequestID: UUID,
            playlistID: UUID,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.playlistManagementRouteIndex = playlistManagementRouteIndex
            self.editRequestID = editRequestID
            self.playlistID = playlistID
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, editRequestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    editRequestID: state.editRequestID
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct PlaylistManagementPINRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let playlistManagementRouteIndex: Int
        public let requestID: UUID
        public let flow: PlaylistManagementFeature.State.PINFlow

        public init(
            playlistManagementRouteIndex: Int,
            requestID: UUID,
            flow: PlaylistManagementFeature.State.PINFlow,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.playlistManagementRouteIndex = playlistManagementRouteIndex
            self.requestID = requestID
            self.flow = flow
        }

        public var isStartupUnlock: Bool {
            if case .startup = flow { return true }
            return false
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, requestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    requestID: state.requestID
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct PlaylistManagementAddPlaylistRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let playlistManagementRouteIndex: Int
        public let requestID: UUID

        public init(
            playlistManagementRouteIndex: Int,
            requestID: UUID,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.playlistManagementRouteIndex = playlistManagementRouteIndex
            self.requestID = requestID
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, requestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    requestID: state.requestID
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct PlayerSpeedTestRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let playerRouteIndex: Int
        public let requestID: UUID
        public let itemID: String
        public let playbackRequestID: UUID

        public init(
            playerRouteIndex: Int,
            requestID: UUID,
            itemID: String,
            playbackRequestID: UUID,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.playerRouteIndex = playerRouteIndex
            self.requestID = requestID
            self.itemID = itemID
            self.playbackRequestID = playbackRequestID
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, requestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    requestID: state.requestID
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct PlayerSubtitleSearchRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let playerRouteIndex: Int
        public let requestID: UUID
        public let itemID: String
        public let playbackRequestID: UUID
        public let itemTitle: String

        public init(
            playerRouteIndex: Int,
            requestID: UUID,
            itemID: String,
            playbackRequestID: UUID,
            itemTitle: String,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.playerRouteIndex = playerRouteIndex
            self.requestID = requestID
            self.itemID = itemID
            self.playbackRequestID = playbackRequestID
            self.itemTitle = itemTitle
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, requestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    requestID: state.requestID
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct SettingsSpeedTestRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let homeRouteIndex: Int
        public let requestID: UUID

        public init(
            homeRouteIndex: Int,
            requestID: UUID,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.homeRouteIndex = homeRouteIndex
            self.requestID = requestID
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, requestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    requestID: state.requestID
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct SettingsPINSetupRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let homeRouteIndex: Int
        public let requestID: UUID

        public init(
            homeRouteIndex: Int,
            requestID: UUID,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.homeRouteIndex = homeRouteIndex
            self.requestID = requestID
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, requestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    requestID: state.requestID
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct SettingsTraktAuthRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let homeRouteIndex: Int
        public let requestID: UUID

        public init(
            homeRouteIndex: Int,
            requestID: UUID,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.homeRouteIndex = homeRouteIndex
            self.requestID = requestID
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, requestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    requestID: state.requestID
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct SettingsTraktWatchlistRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let homeRouteIndex: Int
        public let requestID: UUID

        public init(
            homeRouteIndex: Int,
            requestID: UUID,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.homeRouteIndex = homeRouteIndex
            self.requestID = requestID
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, requestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    requestID: state.requestID
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct SettingsHiddenContentRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let homeRouteIndex: Int
        public let requestID: UUID

        public init(
            homeRouteIndex: Int,
            requestID: UUID,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.homeRouteIndex = homeRouteIndex
            self.requestID = requestID
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, requestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    requestID: state.requestID
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct DetailTMDBMatchPickerRouteFeature {
    public enum Parent: Equatable {
        case vod(itemID: String)
        case series(itemID: String)
    }

    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let detailRouteIndex: Int
        public let parent: Parent
        public let requestID: UUID

        public init(
            detailRouteIndex: Int,
            parent: Parent,
            requestID: UUID,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.detailRouteIndex = detailRouteIndex
            self.parent = parent
            self.requestID = requestID
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, requestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    requestID: state.requestID
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct CustomEPGSettingsRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let homeRouteIndex: Int
        public let requestID: UUID

        public init(
            homeRouteIndex: Int,
            requestID: UUID,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.homeRouteIndex = homeRouteIndex
            self.requestID = requestID
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, requestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    requestID: state.requestID
                )))

            case .delegate:
                return .none
            }
        }
    }
}

@Reducer
public struct CustomEPGSourceAddRouteFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let customEPGSettingsPresentationID: UUID
        public let homeRouteIndex: Int
        public let requestID: UUID

        public init(
            customEPGSettingsPresentationID: UUID,
            homeRouteIndex: Int,
            requestID: UUID,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.customEPGSettingsPresentationID = customEPGSettingsPresentationID
            self.homeRouteIndex = homeRouteIndex
            self.requestID = requestID
        }
    }

    public enum Action {
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close(presentationID: UUID, requestID: UUID)
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.close(
                    presentationID: state.presentationID,
                    requestID: state.requestID
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
    case playlistManagementSettings(PlaylistManagementSettingsRouteFeature)
    case playlistManagementPIN(PlaylistManagementPINRouteFeature)
    case playlistManagementAddPlaylist(PlaylistManagementAddPlaylistRouteFeature)
    case playerSpeedTest(PlayerSpeedTestRouteFeature)
    case playerSubtitleSearch(PlayerSubtitleSearchRouteFeature)
    case settingsSpeedTest(SettingsSpeedTestRouteFeature)
    case settingsPINSetup(SettingsPINSetupRouteFeature)
    case settingsTraktAuth(SettingsTraktAuthRouteFeature)
    case settingsTraktWatchlist(SettingsTraktWatchlistRouteFeature)
    case settingsHiddenContent(SettingsHiddenContentRouteFeature)
    case detailTMDBMatchPicker(DetailTMDBMatchPickerRouteFeature)
    case customEPGSettings(CustomEPGSettingsRouteFeature)
    case customEPGSourceAdd(CustomEPGSourceAddRouteFeature)
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
        case let (.playlistManagementSettings(l), .playlistManagementSettings(r)): l.presentationID == r.presentationID
        case let (.playlistManagementPIN(l), .playlistManagementPIN(r)): l.presentationID == r.presentationID
        case let (.playlistManagementAddPlaylist(l), .playlistManagementAddPlaylist(r)): l.presentationID == r.presentationID
        case let (.playerSpeedTest(l), .playerSpeedTest(r)): l.presentationID == r.presentationID
        case let (.playerSubtitleSearch(l), .playerSubtitleSearch(r)): l.presentationID == r.presentationID
        case let (.settingsSpeedTest(l), .settingsSpeedTest(r)): l.presentationID == r.presentationID
        case let (.settingsPINSetup(l), .settingsPINSetup(r)): l.presentationID == r.presentationID
        case let (.settingsTraktAuth(l), .settingsTraktAuth(r)): l.presentationID == r.presentationID
        case let (.settingsTraktWatchlist(l), .settingsTraktWatchlist(r)): l.presentationID == r.presentationID
        case let (.settingsHiddenContent(l), .settingsHiddenContent(r)): l.presentationID == r.presentationID
        case let (.detailTMDBMatchPicker(l), .detailTMDBMatchPicker(r)): l.presentationID == r.presentationID
        case let (.customEPGSettings(l), .customEPGSettings(r)): l.presentationID == r.presentationID
        case let (.customEPGSourceAdd(l), .customEPGSourceAdd(r)): l.presentationID == r.presentationID
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
        case let .playlistManagementSettings(state):
            hasher.combine(21)
            hasher.combine(state.presentationID)
        case let .playlistManagementPIN(state):
            hasher.combine(22)
            hasher.combine(state.presentationID)
        case let .playlistManagementAddPlaylist(state):
            hasher.combine(23)
            hasher.combine(state.presentationID)
        case let .playerSpeedTest(state):
            hasher.combine(24)
            hasher.combine(state.presentationID)
        case let .playerSubtitleSearch(state):
            hasher.combine(25)
            hasher.combine(state.presentationID)
        case let .settingsSpeedTest(state):
            hasher.combine(26)
            hasher.combine(state.presentationID)
        case let .settingsPINSetup(state):
            hasher.combine(30)
            hasher.combine(state.presentationID)
        case let .settingsTraktAuth(state):
            hasher.combine(31)
            hasher.combine(state.presentationID)
        case let .settingsTraktWatchlist(state):
            hasher.combine(32)
            hasher.combine(state.presentationID)
        case let .settingsHiddenContent(state):
            hasher.combine(33)
            hasher.combine(state.presentationID)
        case let .detailTMDBMatchPicker(state):
            hasher.combine(27)
            hasher.combine(state.presentationID)
        case let .customEPGSettings(state):
            hasher.combine(28)
            hasher.combine(state.presentationID)
        case let .customEPGSourceAdd(state):
            hasher.combine(29)
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
