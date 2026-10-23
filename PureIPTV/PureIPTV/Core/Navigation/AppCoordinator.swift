import ComposableArchitecture
import FactoryKit
import FlowStacks
import Foundation
import RevenueCat
import SwiftUI
import TCACoordinators

// MARK: - App Coordinator Reducer

@Reducer
public struct AppCoordinator {
    public enum PlayerDisplayMode: Equatable, Sendable {
        case fullScreen
        case miniPlayer
        case hidden
    }

    @ObservableState
    public struct State: Equatable {
        public var routes: [Route<AppScreen.State>]

        /// Mini player state when player is docked
        public var miniPlayer: PlayerFeature.State?
        public var isPlayerMini: Bool = false

        public var isPremium: Bool = false

        public static var initialState: State {
            State(routes: [.root(.splash(SplashFeature.State()), withNavigation: true)])
        }

        public init(routes: [Route<AppScreen.State>] = [.root(.splash(SplashFeature.State()), withNavigation: true)]) {
            self.routes = routes
        }

        /// Helper to find the active playlist config from routes or repository
        public var activeConfig: PlaylistConfig? {
            for route in routes.reversed() {
                if case let .home(homeState) = route.screen {
                    return homeState.config
                }
            }
            @Injected(\.playlistRepository) var playlistRepo
            return playlistRepo.getActivePlaylist()?.toPlaylistConfig()
        }
    }

    public enum Action {
        case router(IndexedRouterActionOf<AppScreen>)
        case miniPlayer(PlayerFeature.Action)

        // Mini player controls
        case toggleMiniPlayer
        case expandPlayer
        case closeMiniPlayer

        // Global flows
        case proceedToApp
        case presentPaywall
        case checkSubscriptionStatus
        case subscriptionStatusResponse(TaskResult<RevenueCat.CustomerInfo>)
        case handleDeepLink(URL)
    }

    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.purchases) var purchases

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce<State, Action> { state, action in
            core(state: &state, action: action)
        }
        .forEachRoute(\.routes, action: \.router)
        .ifLet(\.miniPlayer, action: \.miniPlayer) {
            PlayerFeature()
        }
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        let playlistRepository = playlistRepository

        switch action {
        // ── Splash ───────────────────────────────────────────────
        case .router(.routeAction(_, .splash(.splashDidFinish))):
            let isWelcomeCompleted = UserDefaults.standard.bool(forKey: "isOnboardingCompleted")
            if !isWelcomeCompleted {
                withAnimation(.easeInOut(duration: 0.35)) {
                    state.routes = [.root(.onboarding(OnboardingFeature.State()), withNavigation: true)]
                }
                return .none
            }
            return .send(.proceedToApp)

        // ── Onboarding ───────────────────────────────────────────
        case .router(.routeAction(_, .onboarding(.delegate(.didCompleteOnboarding)))):
            return .send(.proceedToApp)

        // ── Proceed To App ───────────────────────────────────────
        case .proceedToApp:
            let activePlaylist = playlistRepository.getActivePlaylist()
            var hasValidPlaylist = false

            if let playlist = activePlaylist {
                if playlist.type == .xtream {
                    if playlist.serverURL != nil, playlist.username != nil, playlist.password != nil {
                        hasValidPlaylist = true
                    }
                } else if playlist.type == .m3u {
                    if playlist.m3uURL != nil {
                        hasValidPlaylist = true
                    }
                }
            }

            withAnimation(.easeInOut(duration: 0.35)) {
                if hasValidPlaylist {
                    state.routes = [.root(.profileSelection(ProfileSelectionFeature.State()), withNavigation: true)]
                } else {
                    state.routes = [.root(.addPlaylist(AddPlaylistFeature.State()), withNavigation: true)]
                }
            }
            return .none

        // ── Profile Selection ────────────────────────────────────
        case .router(.routeAction(_, .profileSelection(.delegate(.didSelectProfile)))):
            let activePlaylist = playlistRepository.getActivePlaylist()
            guard let playlist = activePlaylist, let config = playlist.toPlaylistConfig() else { return .none }

            withAnimation(.easeInOut(duration: 0.35)) {
                state.routes = [.root(.home(HomeFeature.State(config: config)), withNavigation: true)]
            }
            return .send(.checkSubscriptionStatus)

        // ── Add Playlist ─────────────────────────────────────────
        case .router(.routeAction(_, .addPlaylist(.delegate(.didConnect)))):
            withAnimation(.easeInOut(duration: 0.35)) {
                state.routes = [.root(.splash(SplashFeature.State()), withNavigation: true)]
            }
            return .none

        // ── Subscription Check ───────────────────────────────────
        case .checkSubscriptionStatus:
            return .run { send in
                await send(.subscriptionStatusResponse(TaskResult {
                    try await purchases.customerInfo()
                }))
            }

        case let .subscriptionStatusResponse(.success(info)):
            state.isPremium = !info.entitlements.active.isEmpty
            if !state.isPremium {
                return .send(.presentPaywall)
            }
            return .none

        case .subscriptionStatusResponse(.failure):
            state.isPremium = false
            return .send(.presentPaywall)

        case .presentPaywall:
            state.routes.presentSheet(.paywall(PaywallFeature.State()))
            return .none

        case .router(.routeAction(_, .paywall(.dismiss))),
             .router(.routeAction(_, .paywall(.closeButtonTapped))):
            if case .paywall = state.routes.last?.screen {
                state.routes.dismiss()
            }
            return .send(.checkSubscriptionStatus)

        // ── Home Delegates ───────────────────────────────────────
        case let .router(.routeAction(_, .home(.delegate(.didSelectChannel(channel, playlist))))):
            guard let streamURL = channel.streamURL else { return .none }
            guard let config = state.activeConfig else { return .none }

            let playablePlaylist = playlist?.compactMap { item -> PlayerFeature.PlayableItem? in
                guard let itemStreamURL = item.streamURL else { return nil }
                return PlayerFeature.PlayableItem(
                    id: item.id,
                    title: item.title,
                    streamURL: itemStreamURL,
                    coverURL: item.coverURL,
                    seriesID: nil,
                    startPosition: nil,
                    isLive: true,
                    config: config,
                    epgChannelID: item.epgChannelID,
                    categoryID: item.categoryID
                )
            }

            let playerState = PlayerFeature.State(
                item: .init(
                    id: channel.id,
                    title: channel.title,
                    streamURL: streamURL,
                    coverURL: channel.coverURL,
                    seriesID: nil,
                    startPosition: nil,
                    isLive: true,
                    config: config,
                    epgChannelID: channel.epgChannelID,
                    categoryID: channel.categoryID
                ),
                playlist: playablePlaylist
            )
            state.isPlayerMini = false
            state.miniPlayer = nil
            state.routes.presentCover(.player(playerState))
            return .none

        case let .router(.routeAction(_, .home(.delegate(.didSelectVOD(vod))))):
            if !state.isPremium {
                return .send(.presentPaywall)
            }
            guard let config = state.activeConfig else { return .none }
            state.routes.push(.vodDetail(VODDetailFeature.State(vod: vod, config: config)))
            return .none

        case let .router(.routeAction(_, .home(.delegate(.didSelectSeries(series))))):
            if !state.isPremium {
                return .send(.presentPaywall)
            }
            guard let config = state.activeConfig else { return .none }
            state.routes.push(.seriesDetail(SeriesDetailFeature.State(series: series, config: config)))
            return .none

        case let .router(.routeAction(_, .home(.delegate(.playHistoryItem(item))))):
            return playHistoryItem(item, state: &state, forceRestart: false)

        case let .router(.routeAction(_, .home(.delegate(.restartHistoryItem(item))))):
            return playHistoryItem(item, state: &state, forceRestart: true)

        case .router(.routeAction(_, .home(.delegate(.openManagePlaylists)))):
            state.routes.push(.playlistManagement(PlaylistManagementFeature.State()))
            return .none

        case .router(.routeAction(_, .home(.delegate(.switchProfile)))):
            state.routes = [.root(.profileSelection(ProfileSelectionFeature.State()), withNavigation: true)]
            return .none

        // ── Series Detail Delegates ──────────────────────────────
        case let .router(.routeAction(_, .seriesDetail(.delegate(.didSelectEpisode(playable, playlist))))):
            let playerState = PlayerFeature.State(item: playable, playlist: playlist)
            state.isPlayerMini = false
            state.miniPlayer = nil
            state.routes.presentCover(.player(playerState))
            return .none

        case .router(.routeAction(_, .seriesDetail(.delegate(.close)))):
            if case .seriesDetail = state.routes.last?.screen {
                state.routes.goBack()
            }
            return .none

        // ── VOD Detail Delegates ─────────────────────────────────
        case let .router(.routeAction(_, .vodDetail(.delegate(.didSelectPlay(playable))))):
            let playerState = PlayerFeature.State(item: playable)
            state.isPlayerMini = false
            state.miniPlayer = nil
            state.routes.presentCover(.player(playerState))
            return .none

        case let .router(.routeAction(_, .vodDetail(.delegate(.didSelectVOD(vod))))):
            if !state.isPremium {
                return .send(.presentPaywall)
            }
            guard let config = state.activeConfig else { return .none }
            state.routes.push(.vodDetail(VODDetailFeature.State(vod: vod, config: config)))
            return .none

        case .router(.routeAction(_, .vodDetail(.delegate(.close)))):
            if case .vodDetail = state.routes.last?.screen {
                state.routes.goBack()
            }
            return .none

        // ── Playlist Management Delegates ────────────────────────
        case .router(.routeAction(_, .playlistManagement(.delegate(.didChangeActivePlaylist)))):
            state.miniPlayer = nil
            state.isPlayerMini = false

            withAnimation(.easeInOut(duration: 0.35)) {
                if let activePlaylist = playlistRepository.getActivePlaylist(),
                   let config = activePlaylist.toPlaylistConfig()
                {
                    state.routes = [.root(.home(HomeFeature.State(config: config)), withNavigation: true)]
                } else {
                    state.routes = [.root(.addPlaylist(AddPlaylistFeature.State()), withNavigation: true)]
                }
            }
            return .none

        case .router(.routeAction(_, .playlistManagement(.delegate(.addPlaylistDidConnect)))):
            withAnimation(.easeInOut(duration: 0.35)) {
                state.routes = [.root(.splash(SplashFeature.State()), withNavigation: true)]
            }
            return .none

        case .router(.routeAction(_, .playlistManagement(.delegate(.dismissed)))):
            if case .playlistManagement = state.routes.last?.screen {
                state.routes.goBack()
            }
            return .none

        // ── Player Delegates ─────────────────────────────────────
        case .router(.routeAction(_, .player(.delegate(.didClose)))):
            state.miniPlayer = nil
            state.isPlayerMini = false
            if case .player = state.routes.last?.screen {
                state.routes.dismiss()
            }
            return .run { _ in
                @Injected(\.playerClient) var playerClient
                #if os(iOS)
                    await MainActor.run {
                        OrientationManager.shared.unlockPortrait()
                    }
                #endif
                try? await playerClient.stop()
                await playerClient.release()
            }

        case .router(.routeAction(_, .player(.delegate(.didRequestMinimize)))):
            if case let .player(playerState) = state.routes.last?.screen {
                state.miniPlayer = playerState
                state.isPlayerMini = true
            }
            state.routes.dismiss()
            return .run { _ in
                #if os(iOS)
                    await MainActor.run {
                        OrientationManager.shared.unlockPortrait()
                    }
                #endif
            }

        // ── Mini Player Controls ─────────────────────────────────
        case .expandPlayer:
            guard let mini = state.miniPlayer else { return .none }
            var expanded = mini
            expanded.isMinimized = false
            state.miniPlayer = nil
            state.isPlayerMini = false
            state.routes.presentCover(.player(expanded))
            return .run { _ in
                #if os(iOS)
                    await MainActor.run {
                        OrientationManager.shared.lockLandscape()
                    }
                #endif
            }

        case .closeMiniPlayer:
            state.isPlayerMini = false
            state.miniPlayer = nil
            return .run { _ in
                @Injected(\.playerClient) var playerClient
                #if os(iOS)
                    await MainActor.run {
                        OrientationManager.shared.unlockPortrait()
                    }
                #endif
                try? await playerClient.stop()
                await playerClient.release()
            }

        case .toggleMiniPlayer:
            state.isPlayerMini.toggle()
            return .none

        // ── Deep Linking ─────────────────────────────────────────
        case let .handleDeepLink(url):
            guard url.scheme == "pureiptv" else { return .none }
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return .none }
            guard let host = components.host, host == "play" || host == "channel" else { return .none }
            let queryItems = components.queryItems ?? []
            guard let id = queryItems.first(where: { $0.name == "id" })?.value,
                  let streamURLStr = queryItems.first(where: { $0.name == "streamURL" })?.value,
                  let streamURL = URL(string: streamURLStr)
            else {
                return .none
            }

            let title = queryItems.first(where: { $0.name == "title" })?.value ?? "Yayın"
            let type = queryItems.first(where: { $0.name == "type" })?.value ?? "live"
            let coverURL = queryItems.first(where: { $0.name == "coverURL" })?.value.flatMap { URL(string: $0) }
            let startPosition = queryItems.first(where: { $0.name == "startPosition" })?.value.flatMap { Double($0) }
            let isLive = type == "live" || host == "channel"

            let item = PlayerFeature.PlayableItem(
                id: id,
                title: title,
                seriesTitle: nil,
                streamURL: streamURL,
                coverURL: coverURL,
                seriesID: nil,
                startPosition: startPosition,
                initialDuration: nil,
                initialProgress: nil,
                isLive: isLive,
                config: state.activeConfig,
                epgChannelID: isLive ? id : nil,
                tvArchive: nil
            )

            let playerState = PlayerFeature.State(item: item)
            state.isPlayerMini = false
            state.miniPlayer = nil
            state.routes.presentCover(.player(playerState))
            return .none

        default:
            return .none
        }
    }

    private func playHistoryItem(_ item: WatchHistoryItem, state: inout State, forceRestart: Bool = false) -> Effect<Action> {
        if item.seriesID != nil || item.type == "vod" || item.type == "episode", !state.isPremium {
            return .send(.presentPaywall)
        }

        guard let config = state.activeConfig else { return .none }

        var streamURL: URL? = item.streamURL.flatMap { URL(string: $0) }
        if streamURL == nil, item.type == "vod",
           let serverURL = config.serverURL, let username = config.username, let password = config.password
        {
            streamURL = serverURL.appendingPathComponent("movie/\(username)/\(password)/\(item.id).mp4")
        }

        guard let finalStreamURL = streamURL else { return .none }

        let coverURL = item.coverURL.flatMap { URL(string: $0) }
        let startPosition: Double? = if forceRestart {
            0.0
        } else if item.duration > 0 {
            item.progress / item.duration
        } else {
            nil
        }

        let isLive = item.type == "live"

        let playable = PlayerFeature.PlayableItem(
            id: item.id,
            title: item.title,
            seriesTitle: item.seriesTitle,
            streamURL: finalStreamURL,
            coverURL: coverURL,
            seriesID: item.seriesID,
            startPosition: startPosition,
            initialDuration: item.duration > 0 ? item.duration : nil,
            initialProgress: forceRestart ? 0.0 : (item.progress > 0 ? item.progress : nil),
            isLive: isLive,
            config: config,
            epgChannelID: isLive ? item.id : nil,
            tvArchive: nil
        )

        let playerState = PlayerFeature.State(item: playable)
        state.isPlayerMini = false
        state.miniPlayer = nil
        state.routes.presentCover(.player(playerState))
        return .none
    }
}

// MARK: - AppFeature Typealias for backwards compatibility

public typealias AppFeature = AppCoordinator

// MARK: - App Coordinator View (SwiftUI + TCARouter)

public struct AppCoordinatorView: View {
    let store: StoreOf<AppCoordinator>

    public init(store: StoreOf<AppCoordinator>) {
        self.store = store
    }

    public var body: some View {
        TCARouter(store.scope(state: \.routes, action: \.router)) { screen in
            switch screen.case {
            case let .splash(store):
                SplashView(store: store)
            case let .onboarding(store):
                OnboardingView(store: store)
            case let .addPlaylist(store):
                AddPlaylistView(store: store)
            case let .profileSelection(store):
                ProfileSelectionView(store: store)
            case let .home(store):
                HomeView(store: store)
            case let .player(store):
                PlayerView(store: store)
            case let .seriesDetail(store):
                SeriesDetailView(store: store)
            case let .vodDetail(store):
                VODDetailView(store: store)
            case let .playlistManagement(store):
                PlaylistManagementView(store: store)
            case let .paywall(store):
                PaywallView(store: store)
            }
        }
        .useNavigationStack(.whenAvailable)
    }
}
