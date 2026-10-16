import ComposableArchitecture
import FactoryKit
import Foundation
import RevenueCat
import XCoordinator

@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public var splash = SplashFeature.State()
        public var addPlaylist = AddPlaylistFeature.State()
        public var home: HomeFeature.State?
        public var player: PlayerFeature.State?
        public var isPlayerMini: Bool = false
        @Presents public var seriesDetail: SeriesDetailFeature.State?
        @Presents public var vodDetail: VODDetailFeature.State?
        @Presents public var playlistManagement: PlaylistManagementFeature.State?
        public var onboarding: OnboardingFeature.State?
        public var profileSelection: ProfileSelectionFeature.State?
        @Presents public var paywall: PaywallFeature.State?

        public var splashIsActive = true
        public var isOnboarded = false
        public var isPremium = false

        public init() {}
    }

    public enum Action {
        case splash(SplashFeature.Action)
        case addPlaylist(AddPlaylistFeature.Action)
        case home(HomeFeature.Action)
        case player(PlayerFeature.Action)
        case toggleMiniPlayer
        case expandPlayer
        case closeMiniPlayer
        case seriesDetail(PresentationAction<SeriesDetailFeature.Action>)
        case vodDetail(PresentationAction<VODDetailFeature.Action>)
        case playlistManagement(PresentationAction<PlaylistManagementFeature.Action>)
        case onboarding(OnboardingFeature.Action)
        case profileSelection(ProfileSelectionFeature.Action)
        case paywall(PresentationAction<PaywallFeature.Action>)
        case presentPaywall
        case checkSubscriptionStatus
        case subscriptionStatusResponse(TaskResult<RevenueCat.CustomerInfo>)
        case proceedToApp
        case handleDeepLink(URL)
    }

    @Injected(\.playlistRepository) var playlistRepository
    @Injected(\.appCoordinator) var appCoordinator
    @Dependency(\.purchases) var purchases

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.splash, action: \.splash) {
            SplashFeature()
        }

        Scope(state: \.addPlaylist, action: \.addPlaylist) {
            AddPlaylistFeature()
        }

        Reduce { state, action in
            core(state: &state, action: action)
        }.ifLet(\.$seriesDetail, action: \.seriesDetail) {
            SeriesDetailFeature()
        }
        .ifLet(\.$vodDetail, action: \.vodDetail) {
            VODDetailFeature()
        }
        .ifLet(\.$playlistManagement, action: \.playlistManagement) {
            PlaylistManagementFeature()
        }
        .ifLet(\.$paywall, action: \.paywall) {
            PaywallFeature()
        }
        .ifLet(\.home, action: \.home) {
            HomeFeature()
        }
        .ifLet(\.player, action: \.player) {
            PlayerFeature()
        }
        .ifLet(\.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
        .ifLet(\.profileSelection, action: \.profileSelection) {
            ProfileSelectionFeature()
        }
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        let playlistRepository = playlistRepository
        let appCoordinator = appCoordinator

        switch action {
        // ── Splash ───────────────────────────────────────────────
        case .splash(.splashDidFinish):
            state.splashIsActive = false

            let isWelcomeCompleted = UserDefaults.standard.bool(forKey: "isOnboardingCompleted")
            if !isWelcomeCompleted {
                state.onboarding = OnboardingFeature.State()
                return .run { _ in
                    await MainActor.run { appCoordinator.trigger(.onboarding) }
                }
            }

            return .send(.proceedToApp)

        case .splash:
            return .none

        // ── Onboarding ───────────────────────────────────────────
        case .onboarding(.delegate(.didCompleteOnboarding)):
            state.onboarding = nil
            return .send(.proceedToApp)

        case .onboarding:
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
                // Abonelik yoksa Paywall göster
                return .send(.presentPaywall)
            }
            return .none

        case .subscriptionStatusResponse(.failure):
            state.isPremium = false
            // Hata olursa yine de paywall gösterilebilir
            return .send(.presentPaywall)

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

            if hasValidPlaylist {
                state.profileSelection = ProfileSelectionFeature.State()
                state.isOnboarded = true
                return .run { _ in
                    await MainActor.run { appCoordinator.trigger(.profileSelection) }
                }
            } else {
                return .run { _ in
                    await MainActor.run { appCoordinator.trigger(.login) }
                }
            }

        // ── Profile Selection ────────────────────────────────────
        case .profileSelection(.delegate(.didSelectProfile)):
            state.profileSelection = nil

            let activePlaylist = playlistRepository.getActivePlaylist()
            guard let playlist = activePlaylist else { return .none }

            let config: PlaylistConfig
            if playlist.type == .xtream {
                guard let serverURLStr = playlist.serverURL, let url = URL(string: serverURLStr),
                      let username = playlist.username, let password = playlist.password else { return .none }
                config = PlaylistConfig(type: .xtream, serverURL: url, username: username, password: password)
            } else if playlist.type == .m3u {
                guard let m3uURLStr = playlist.m3uURL, let url = URL(string: m3uURLStr) else { return .none }
                config = PlaylistConfig(type: .m3u, m3uURL: url)
            } else {
                return .none
            }

            state.home = HomeFeature.State(config: config)
            return .run { send in
                await MainActor.run { appCoordinator.trigger(.home) }
                await send(.checkSubscriptionStatus)
            }

        case .toggleMiniPlayer:
            state.isPlayerMini.toggle()
            return .none

        case .profileSelection:
            return .none

        // ── AddPlaylist ──────────────────────────────────────────
        case .addPlaylist(.delegate(.didConnect)):
            state.addPlaylist = AddPlaylistFeature.State() // reset it
            state.splash = SplashFeature.State()
            state.splashIsActive = true
            state.isOnboarded = true
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.splash) }
            }

        case .addPlaylist:
            return .none

        // ── Home ─────────────────────────────────────────────────
        case let .home(.delegate(.didSelectChannel(channel, playlist))):
            guard let streamURL = channel.streamURL else { return .none }
            guard let config = state.home?.config else { return .none }

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

            state.player = PlayerFeature.State(
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
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.player) }
            }

        case let .home(.delegate(.didSelectVOD(vod))):
            if !state.isPremium {
                return .send(.presentPaywall)
            }
            if let config = state.home?.config {
                state.vodDetail = VODDetailFeature.State(
                    vod: vod,
                    config: config
                )
                return .run { _ in
                    await MainActor.run { appCoordinator.trigger(.vodDetail) }
                }
            }
            return .none

        case let .home(.delegate(.didSelectSeries(series))):
            if !state.isPremium {
                return .send(.presentPaywall)
            }
            if let config = state.home?.config {
                state.seriesDetail = SeriesDetailFeature.State(
                    series: series,
                    config: config
                )
                return .run { _ in
                    await MainActor.run { appCoordinator.trigger(.seriesDetail) }
                }
            }
            return .none

        case let .home(.delegate(.playHistoryItem(item))):
            return playHistoryItem(item, state: &state, forceRestart: false)

        case let .home(.delegate(.restartHistoryItem(item))):
            return playHistoryItem(item, state: &state, forceRestart: true)

        case .home(.delegate(.openManagePlaylists)):
            state.playlistManagement = PlaylistManagementFeature.State()
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.playlistManagement) }
            }

        case .home(.delegate(.switchProfile)):
            state.home = nil
            state.profileSelection = ProfileSelectionFeature.State()
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.profileSelection) }
            }

        case .home:
            return .none

        // ── Series Detail ─────────────────────────────────────────
        case let .seriesDetail(.presented(.delegate(.didSelectEpisode(playable, playlist)))):
            state.player = PlayerFeature.State(item: playable, playlist: playlist)
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.player) }
            }

        case .seriesDetail(.presented(.delegate(.close))):
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.dismissSeriesDetail) }
            }

        case .seriesDetail(.presented(.viewDidDisappear)):
            if state.player == nil, state.paywall == nil {
                state.seriesDetail = nil
            }
            return .none

        case .seriesDetail:
            return .none

        // ── Player ───────────────────────────────────────────────
        case .player(.delegate(.didClose)):
            state.player = nil
            state.isPlayerMini = false
            return .none

        case .player(.delegate(.didRequestMinimize)):
            state.isPlayerMini = true
            return .none

        case .expandPlayer:
            state.isPlayerMini = false
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.player) }
            }

        case .closeMiniPlayer:
            state.isPlayerMini = false
            return .send(.player(.closeTapped))

        case .player:
            return .none

        // ── VOD Detail ───────────────────────────────────────────
        case let .vodDetail(.presented(.delegate(.didSelectPlay(playable)))):
            state.player = PlayerFeature.State(item: playable)
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.player) }
            }

        case .vodDetail(.presented(.delegate(.didSelectVOD))):
            // VOD detail handles transition internally, delegate kept for coordinator awareness
            return .none

        case .vodDetail(.presented(.delegate(.close))):
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.dismissVodDetail) }
            }

        case .vodDetail(.presented(.viewDidDisappear)):
            if state.player == nil, state.paywall == nil {
                state.vodDetail = nil
            }
            return .none

        case .vodDetail:
            return .none

        // ── Playlist Management ──────────────────────────────────
        case .playlistManagement(.presented(.delegate(.didChangeActivePlaylist))):
            // Playlist değiştiğinde ana ekrana geri dön
            state.playlistManagement = nil
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.dismissPlaylistManagement) }
            }

        case .playlistManagement(.presented(.delegate(.addPlaylistDidConnect))):
            state.playlistManagement = nil
            state.splash = SplashFeature.State()
            state.splashIsActive = true
            state.isOnboarded = true
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.splash) }
            }

        case .playlistManagement(.presented(.delegate(.dismissed))):
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.dismissPlaylistManagement) }
            }

        case .playlistManagement(.presented(.viewDidDisappear)):
            state.playlistManagement = nil
            return .none

        case .playlistManagement:
            return .none

        case .presentPaywall:
            state.paywall = PaywallFeature.State()
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.paywall) }
            }

        case .paywall(.presented(.dismiss)):
            state.paywall = nil
            return .run { send in
                await MainActor.run { appCoordinator.trigger(.dismissPaywall) }
                // Re-check subscription in case they purchased something
                await send(.checkSubscriptionStatus)
            }

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
                config: state.home?.config,
                epgChannelID: isLive ? id : nil,
                tvArchive: nil
            )

            state.player = PlayerFeature.State(item: item)
            return .run { _ in
                await MainActor.run { appCoordinator.trigger(.player) }
            }

        case .paywall:
            return .none
        }
    }

    private func playHistoryItem(_ item: WatchHistoryItem, state: inout State, forceRestart: Bool = false) -> Effect<Action> {
        // Eğer VOD veya Dizi ise ve kullanıcı premium değilse engelle
        if item.seriesID != nil || item.type == "vod" || item.type == "episode", !state.isPremium {
            return .send(.presentPaywall)
        }

        guard let config = state.home?.config else { return .none }

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

        state.player = PlayerFeature.State(item: playable)
        return .run { _ in
            await MainActor.run { appCoordinator.trigger(.player) }
        }
    }
}
