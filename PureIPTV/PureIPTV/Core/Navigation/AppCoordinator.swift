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
    private enum CancelID {
        static let streamHandoffResolution = "AppCoordinator.streamHandoffResolution"
        static let epgReminderMonitor = "AppCoordinator.epgReminderMonitor"
        static let playlistTransferLoad = "AppCoordinator.playlistTransferLoad"
        static let playlistTransferSubmission = "AppCoordinator.playlistTransferSubmission"
    }

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
        public var activeStreamHandoffRequestID: UUID?
        public var isStreamHandoffErrorPresented = false
        public var isForeground = false
        public var handledEPGReminderIDs: Set<String> = []
        public var unlockedPlaylistIDs: Set<UUID> = []
        public var playlistTransferPairing: PlaylistQRTransferManager.Pairing?
        public var playlistTransferPlaylists: [SavedPlaylist] = []
        public var playlistTransferSelectedID: UUID?
        public var isSubmittingPlaylistTransfer = false
        public var isLoadingPlaylistTransfer = false
        public var playlistTransferError: String?

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
        case selectPlaylistForTransfer(UUID)
        case playlistTransferPlaylistsLoaded(sessionID: UUID, playlists: [SavedPlaylist]?)
        case confirmPlaylistTransfer
        case cancelPlaylistTransfer
        case playlistTransferSubmissionResponse(sessionID: UUID, succeeded: Bool)
        case receiveStreamHandoff(StreamHandoffRequest)
        case streamHandoffResolved(requestID: UUID, playable: PlayerFeature.PlayableItem?)
        case dismissStreamHandoffError
        case appEnteredForeground
        case appEnteredBackground
        case epgReminderMonitorTick([EPGReminder])
    }

    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.parentalControlClient) var parentalControlClient
    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.reminderClient) var reminderClient
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
        let iptvClient = iptvClient

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
            if let activePlaylist,
               parentalControlClient.isPlaylistLocked(activePlaylist.id),
               !state.unlockedPlaylistIDs.contains(activePlaylist.id)
            {
                state.routes = [.root(
                    .playlistManagement(PlaylistManagementFeature.State(startupUnlockPlaylistID: activePlaylist.id)),
                    withNavigation: true
                )]
                return .none
            }
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

        case let .router(.routeAction(_, .playlistManagement(.delegate(.didUnlockPlaylist(id))))):
            state.unlockedPlaylistIDs.insert(id)
            state.miniPlayer = nil
            state.isPlayerMini = false
            guard let playlist = playlistRepository.getActivePlaylist(), let config = playlist.toPlaylistConfig() else { return .none }
            state.routes = [.root(.home(HomeFeature.State(config: config)), withNavigation: true)]
            return .send(.checkSubscriptionStatus)

        case let .router(.routeAction(_, .playlistManagement(.delegate(.didChangePlaylistLock(id, isLocked))))):
            state.unlockedPlaylistIDs.remove(id)
            guard isLocked, playlistRepository.getActivePlaylistID() == id else { return .none }
            state.miniPlayer = nil
            state.isPlayerMini = false
            state.routes = [.root(
                .playlistManagement(PlaylistManagementFeature.State(startupUnlockPlaylistID: id)),
                withNavigation: true
            )]
            return .none

        case let .router(.routeAction(_, .playlistManagement(.delegate(.didUnlockStartupPlaylist(id))))):
            state.unlockedPlaylistIDs.insert(id)
            state.routes = [.root(.profileSelection(ProfileSelectionFeature.State()), withNavigation: true)]
            return .none

        // ── Add Playlist ─────────────────────────────────────────
        case .router(.routeAction(_, .addPlaylist(.delegate(.didConnect)))),
             .router(.routeAction(_, .addPlaylist(.delegate(.didReceiveTransferredPlaylist)))):
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

        case let .receiveStreamHandoff(request):
            if parentalControlClient.isPlaylistLocked(request.playlistID),
               !state.unlockedPlaylistIDs.contains(request.playlistID)
            {
                state.isStreamHandoffErrorPresented = true
                return .none
            }
            let requestID = UUID()
            state.activeStreamHandoffRequestID = requestID
            state.isStreamHandoffErrorPresented = false
            return .run { send in
                let playlist = playlistRepository.getPlaylists().first { $0.id == request.playlistID }
                guard let playlist, let config = playlist.toPlaylistConfig() else {
                    await send(.streamHandoffResolved(requestID: requestID, playable: nil))
                    return
                }

                let playable: PlayerFeature.PlayableItem?
                switch request.mediaKind {
                case .live:
                    let item = try? await iptvClient.resolveLiveItem(config, request.itemID, request.categoryID)
                    playable = item.flatMap { item in
                        guard let url = item.streamURL else { return nil }
                        return PlayerFeature.PlayableItem(
                            id: item.id,
                            title: request.title,
                            streamURL: url,
                            coverURL: item.displayLogoURL,
                            isLive: true,
                            config: config,
                            epgChannelID: item.epgChannelID,
                            tvArchive: item.tvArchive,
                            categoryID: item.categoryID
                        )
                    }
                case .vod:
                    let item = try? await iptvClient.resolveVODItem(config, request.itemID, request.categoryID)
                    playable = item.flatMap { item in
                        guard let url = item.streamURL else { return nil }
                        return PlayerFeature.PlayableItem(
                            id: item.id,
                            title: item.title,
                            streamURL: url,
                            coverURL: item.displayLogoURL,
                            startPosition: request.playbackPosition,
                            config: config,
                            categoryID: item.categoryID
                        )
                    }
                case .episode:
                    guard let seriesID = request.seriesID else {
                        await send(.streamHandoffResolved(requestID: requestID, playable: nil))
                        return
                    }
                    let details = try? await iptvClient.fetchSeriesInfo(config, seriesID)
                    playable = details?.episodes.first(where: { $0.id == request.itemID }).map { episode in
                        PlayerFeature.PlayableItem(
                            id: episode.id,
                            title: request.title,
                            seriesTitle: request.seriesTitle,
                            streamURL: episode.streamURL,
                            coverURL: episode.coverURL,
                            seriesID: seriesID,
                            startPosition: request.playbackPosition,
                            config: config
                        )
                    }
                }
                await send(.streamHandoffResolved(requestID: requestID, playable: playable))
            }
            .cancellable(id: CancelID.streamHandoffResolution, cancelInFlight: true)

        case let .streamHandoffResolved(requestID, playable):
            guard state.activeStreamHandoffRequestID == requestID else { return .none }
            state.activeStreamHandoffRequestID = nil
            guard let playable else {
                state.isStreamHandoffErrorPresented = true
                return .none
            }
            let playerState = PlayerFeature.State(item: playable)
            state.isPlayerMini = false
            state.miniPlayer = nil
            state.routes.presentCover(.player(playerState))
            return .none

        case .dismissStreamHandoffError:
            state.isStreamHandoffErrorPresented = false
            return .none

        case .appEnteredForeground:
            state.isForeground = true
            let reminderClient = reminderClient
            return .run { send in
                while !Task.isCancelled {
                    let due = await reminderClient.reconcileScheduledReminders()
                    await send(.epgReminderMonitorTick(due))
                    do {
                        try await Task.sleep(for: .seconds(15))
                    } catch {
                        return
                    }
                }
            }.cancellable(id: CancelID.epgReminderMonitor, cancelInFlight: true)

        case .appEnteredBackground:
            state.isForeground = false
            return .cancel(id: CancelID.epgReminderMonitor)

        case let .epgReminderMonitorTick(reminders):
            guard state.isForeground,
                  settingsClient.autoSwitchOnEPGReminder(),
                  state.routes.count == 1,
                  !state.isPlayerMini,
                  state.miniPlayer == nil,
                  case let .home(home) = state.routes[0].screen,
                  home.liveTV.epgTimeline?.activePreviewChannel == nil,
                  home.liveTV.epgTimeline?.isPiPActive != true,
                  let activeConfig = state.activeConfig
            else { return .none }
            let activeIdentity = EPGReminderIdentifier.playlistIdentity(for: activeConfig)
            guard let reminder = reminders.first(where: {
                !$0.autoSwitchHandled && !state.handledEPGReminderIDs.contains($0.id)
                    && $0.playlistIdentity == activeIdentity
                    && $0.startTime <= Date() && Date() < $0.endTime
            }) else { return .none }
            let channels = home.liveTV.channelsByCategory.values.flatMap(\.self)
                + home.liveTV.smartGroupChannels
                + home.liveTV.favoriteListResolvedChannels
            guard let channel = channels.first(where: { $0.id == reminder.channelID }),
                  let streamURL = channel.streamURL
            else {
                return .none
            }
            state.handledEPGReminderIDs.insert(reminder.id)
            let playable = PlayerFeature.PlayableItem(
                id: channel.id, title: channel.title, streamURL: streamURL,
                coverURL: channel.displayLogoURL, isLive: true, config: activeConfig,
                epgChannelID: channel.epgChannelID, tvArchive: channel.tvArchive,
                categoryID: channel.categoryID
            )
            state.routes.presentCover(.player(PlayerFeature.State(item: playable)))
            let reminderClient = reminderClient
            return .run { _ in
                await reminderClient.markAutoSwitchHandled(reminder.id)
            }

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
                    coverURL: item.displayLogoURL,
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
                    coverURL: channel.displayLogoURL,
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

            if let activePlaylist = playlistRepository.getActivePlaylist(),
               parentalControlClient.isPlaylistLocked(activePlaylist.id),
               !state.unlockedPlaylistIDs.contains(activePlaylist.id)
            {
                state.routes = [.root(
                    .playlistManagement(PlaylistManagementFeature.State(startupUnlockPlaylistID: activePlaylist.id)),
                    withNavigation: true
                )]
                return .none
            }

            withAnimation(.easeInOut(duration: 0.35)) {
                if let activePlaylist = playlistRepository.getActivePlaylist(),
                   let config = activePlaylist.toPlaylistConfig()
                {
                    state.routes = [.root(.home(HomeFeature.State(config: config, deferDashboardRefresh: true)), withNavigation: true)]
                } else {
                    state.routes = [.root(.addPlaylist(AddPlaylistFeature.State()), withNavigation: true)]
                }
            }
            return .none

        case let .router(.routeAction(_, .playlistManagement(.delegate(.didUpdateActivePlaylistSettings(config))))):
            if let homeState = state.routes.compactMap({ route -> HomeFeature.State? in
                guard case let .home(home) = route.screen else { return nil }
                return home
            }).first {
                let connectionChanged = homeState.config.type != config.type
                    || homeState.config.serverURL != config.serverURL
                    || homeState.config.username != config.username
                    || homeState.config.password != config.password
                    || homeState.config.m3uURL != config.m3uURL
                if connectionChanged {
                    var refreshedHome = HomeFeature.State(config: config)
                    refreshedHome.selectedTab = homeState.selectedTab
                    state.miniPlayer = nil
                    state.isPlayerMini = false
                    withAnimation(.easeInOut(duration: 0.35)) {
                        state.routes = [.root(.home(refreshedHome), withNavigation: true)]
                    }
                    return .none
                }
            }
            for index in state.routes.indices {
                guard case var .home(homeState) = state.routes[index].screen else { continue }
                homeState.config = config
                homeState.liveTV.config = config
                homeState.liveTV.channelsByCategory = homeState.liveTV.channelsByCategory.mapValues { items in
                    items.map { $0.replacingUserAgentOverride(config.userAgentOverride) }
                }
                homeState.vod.config = config
                homeState.vod.vodsByCategory = homeState.vod.vodsByCategory.mapValues { items in
                    items.map { $0.replacingUserAgentOverride(config.userAgentOverride) }
                }
                homeState.series.config = config
                homeState.series.seriesByCategory = homeState.series.seriesByCategory.mapValues { items in
                    items.map { $0.replacingUserAgentOverride(config.userAgentOverride) }
                }
                homeState.dashboard.featuredChannels = homeState.dashboard.featuredChannels.map {
                    $0.replacingUserAgentOverride(config.userAgentOverride)
                }
                homeState.dashboard.featuredVODs = homeState.dashboard.featuredVODs.map {
                    $0.replacingUserAgentOverride(config.userAgentOverride)
                }
                homeState.dashboard.featuredSeries = homeState.dashboard.featuredSeries.map {
                    $0.replacingUserAgentOverride(config.userAgentOverride)
                }
                homeState.dashboard.recommendedVODs = homeState.dashboard.recommendedVODs.map {
                    $0.replacingUserAgentOverride(config.userAgentOverride)
                }
                state.routes[index].screen = .home(homeState)
            }
            if let miniPlayer = state.miniPlayer {
                var updated = miniPlayer
                updated.item = miniPlayer.item.replacingPlaylistConfig(config)
                updated.playlist = miniPlayer.playlist?.map {
                    $0.replacingPlaylistConfig(config)
                }
                updated.liveChannels = miniPlayer.liveChannels.map {
                    $0.replacingPlaylistConfig(config)
                }
                updated.epgBrowseChannel = miniPlayer.epgBrowseChannel?.replacingPlaylistConfig(config)
                state.miniPlayer = updated
            }
            for index in state.routes.indices {
                guard case let .player(playerState) = state.routes[index].screen else { continue }
                var updated = playerState
                updated.item = playerState.item.replacingPlaylistConfig(config)
                updated.playlist = playerState.playlist?.map {
                    $0.replacingPlaylistConfig(config)
                }
                updated.liveChannels = playerState.liveChannels.map {
                    $0.replacingPlaylistConfig(config)
                }
                updated.epgBrowseChannel = playerState.epgBrowseChannel?.replacingPlaylistConfig(config)
                state.routes[index].screen = .player(updated)
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
            return .none

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
            let queryItems = components.queryItems ?? []
            if components.host == "setup" {
                guard let sessionValue = queryItems.first(where: { $0.name == "session" })?.value,
                      let sessionID = UUID(uuidString: sessionValue),
                      let secretValue = queryItems.first(where: { $0.name == "secret" })?.value,
                      let secret = UUID(uuidString: secretValue)
                else { return .none }

                let pairing = PlaylistQRTransferManager.Pairing(sessionID: sessionID, secret: secret)
                if let previous = state.playlistTransferPairing, previous.sessionID != sessionID {
                    PlaylistQRTransferManager.shared.endSession(previous.sessionID)
                }
                state.playlistTransferPairing = pairing
                state.playlistTransferPlaylists = []
                state.playlistTransferSelectedID = nil
                state.isLoadingPlaylistTransfer = true
                state.isSubmittingPlaylistTransfer = false
                state.playlistTransferError = nil
                return .merge(
                    .cancel(id: CancelID.playlistTransferLoad),
                    .cancel(id: CancelID.playlistTransferSubmission),
                    .run { send in
                        for _ in 0 ..< 15 {
                            guard !Task.isCancelled else { return }
                            if let playlists = PlaylistQRTransferManager.shared.availablePlaylists(for: pairing) {
                                await send(.playlistTransferPlaylistsLoaded(sessionID: sessionID, playlists: playlists))
                                return
                            }
                            try? await Task.sleep(for: .seconds(1))
                        }
                        guard !Task.isCancelled else { return }
                        await send(.playlistTransferPlaylistsLoaded(sessionID: sessionID, playlists: nil))
                    }
                    .cancellable(id: CancelID.playlistTransferLoad, cancelInFlight: true)
                )
            }
            guard let host = components.host, host == "play" || host == "channel" else { return .none }
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

        case let .selectPlaylistForTransfer(id):
            guard state.playlistTransferPlaylists.contains(where: { $0.id == id }) else { return .none }
            state.playlistTransferSelectedID = id
            return .none

        case let .playlistTransferPlaylistsLoaded(sessionID, playlists):
            guard state.playlistTransferPairing?.sessionID == sessionID else { return .none }
            state.isLoadingPlaylistTransfer = false
            guard let playlists else {
                state.playlistTransferError = "QR oturumu iCloud Keychain’e ulaşmadı. İki cihazda aynı Apple ID ile iCloud Keychain’in açık olduğunu kontrol edip yeniden tarayın."
                return .none
            }
            state.playlistTransferPlaylists = playlists
            state.playlistTransferSelectedID = playlists.first?.id
            if playlists.isEmpty {
                state.playlistTransferError = "Bu iPhone’da aktarılabilecek kayıtlı playlist bulunamadı."
            }
            return .none

        case .confirmPlaylistTransfer:
            guard let pairing = state.playlistTransferPairing,
                  let playlistID = state.playlistTransferSelectedID,
                  state.playlistTransferPlaylists.contains(where: { $0.id == playlistID })
            else { return .none }
            state.isSubmittingPlaylistTransfer = true
            state.playlistTransferError = nil
            return .run { send in
                let succeeded = (try? PlaylistQRTransferManager.shared.submit(playlistID: playlistID, for: pairing)) != nil
                await send(.playlistTransferSubmissionResponse(sessionID: pairing.sessionID, succeeded: succeeded))
            }
            .cancellable(id: CancelID.playlistTransferSubmission, cancelInFlight: true)

        case let .playlistTransferSubmissionResponse(sessionID, succeeded):
            guard state.playlistTransferPairing?.sessionID == sessionID else { return .none }
            state.isSubmittingPlaylistTransfer = false
            if succeeded {
                state.playlistTransferPairing = nil
                state.playlistTransferPlaylists = []
                state.playlistTransferSelectedID = nil
            } else {
                state.playlistTransferError = "Oturum süresi dolmuş olabilir. Apple TV’de yeni bir QR kod oluşturun."
            }
            return .none

        case .cancelPlaylistTransfer:
            if let pairing = state.playlistTransferPairing {
                PlaylistQRTransferManager.shared.endSession(pairing.sessionID)
            }
            state.playlistTransferPairing = nil
            state.playlistTransferPlaylists = []
            state.playlistTransferSelectedID = nil
            state.isLoadingPlaylistTransfer = false
            state.isSubmittingPlaylistTransfer = false
            state.playlistTransferError = nil
            return .merge(
                .cancel(id: CancelID.playlistTransferLoad),
                .cancel(id: CancelID.playlistTransferSubmission)
            )

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
        .alert(
            AppStrings.Common.handoffPlaybackUnavailableTitle,
            isPresented: Binding(
                get: { store.isStreamHandoffErrorPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.dismissStreamHandoffError)
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                store.send(.dismissStreamHandoffError)
            }
        } message: {
            Text(AppStrings.Common.handoffPlaybackUnavailableMessage)
        }
    }
}
