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

        public var isStartupPlaylistReadFailed = false
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
        case presentParentalLock(ParentalLockFeature.State)
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
        case epgGuideRouteDidDisappear(UUID)
        case epgTimelineRouteDidDisappear(UUID)
        case multiViewChannelSelectionRouteDidDisappear(
            presentationID: UUID,
            multiViewRouteIndex: Int,
            multiViewPresentationID: UUID,
            slotID: Int
        )
        case dashboardPresentationRouteDidDisappear(
            presentationID: UUID,
            homeRouteIndex: Int,
            homeConfig: PlaylistConfig,
            reloadConfig: PlaylistConfig?
        )
        case m3uCategoryMappingsSaved(
            presentationID: UUID,
            categoryRouteIndex: Int,
            categoryPresentationID: UUID,
            homeRouteIndex: Int,
            playlistID: UUID?
        )
    }

    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.parentalControlClient) var parentalControlClient
    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.reminderClient) var reminderClient
    @Dependency(\.previewPlayerClient) var previewPlayerClient
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
        let previewPlayerClient = previewPlayerClient

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
            let activePlaylist: SavedPlaylist?
            switch playlistRepository.readActivePlaylist() {
            case let .loaded(playlist):
                activePlaylist = playlist
                state.isStartupPlaylistReadFailed = false
            case .failed:
                state.isStartupPlaylistReadFailed = true
                return .none
            }
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
            let hasValidPlaylist = activePlaylist?.toPlaylistConfig() != nil

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
            guard case let .loaded(activePlaylist) = playlistRepository.readActivePlaylist() else {
                state.isStartupPlaylistReadFailed = true
                return .none
            }
            guard let playlist = activePlaylist, let config = playlist.toPlaylistConfig() else { return .none }

            withAnimation(.easeInOut(duration: 0.35)) {
                state.routes = [.root(.home(HomeFeature.State(config: config)), withNavigation: true)]
            }
            return .send(.checkSubscriptionStatus)

        case let .router(.routeAction(_, .playlistManagement(.delegate(.didUnlockPlaylist(id))))):
            state.unlockedPlaylistIDs.insert(id)
            state.miniPlayer = nil
            state.isPlayerMini = false
            guard case let .loaded(activePlaylist) = playlistRepository.readActivePlaylist() else {
                state.isStartupPlaylistReadFailed = true
                return .none
            }
            guard let playlist = activePlaylist, let config = playlist.toPlaylistConfig() else { return .none }
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
            var effects: [Effect<Action>] = [.cancel(id: CancelID.epgReminderMonitor)]
            for routeIndex in state.routes.indices {
                guard case .epgTimeline = state.routes[routeIndex].screen else { continue }
                effects.append(.send(.router(.routeAction(id: routeIndex, action: .epgTimeline(.cancelEPGSync)))))
            }
            return .merge(effects)

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

        case let .router(.routeAction(routeIndex, .epgGuide(.delegate(.close)))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .epgGuide(guideState) = state.routes[routeIndex].screen
            else { return .none }
            state.routes.dismiss()
            return .run { [previewPlayerClient, ownerID = guideState.presentationID] _ in
                await previewPlayerClient.stopPreviewOwned(ownerID)
            }

        case let .router(.routeAction(routeIndex, .epgGuide(.delegate(.playChannel(channel))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .epgGuide(guideState) = state.routes[routeIndex].screen,
                  let playerState = makeLivePlayerState(
                      channel: channel,
                      playlist: guideState.channels,
                      config: guideState.config
                  )
            else { return .none }
            state.routes.dismiss()
            state.isPlayerMini = false
            state.miniPlayer = nil
            state.routes.presentCover(.player(playerState))
            return .none

        case let .router(.routeAction(routeIndex, .epgTimeline(.delegate(.close)))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .epgTimeline(timelineState) = state.routes[routeIndex].screen
            else { return .none }
            state.routes.dismiss()
            return .run { [previewPlayerClient, ownerID = timelineState.presentationID] _ in
                await previewPlayerClient.stopPreviewOwned(ownerID)
            }

        case let .router(.routeAction(routeIndex, .epgTimeline(.delegate(.playChannel(channel))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .epgTimeline(timelineState) = state.routes[routeIndex].screen,
                  let playerState = makeLivePlayerState(
                      channel: channel,
                      playlist: timelineState.channels,
                      config: timelineState.config
                  )
            else { return .none }
            state.routes.dismiss()
            state.isPlayerMini = false
            state.miniPlayer = nil
            state.routes.presentCover(.player(playerState))
            return .run { [previewPlayerClient, ownerID = timelineState.presentationID] _ in
                await previewPlayerClient.stopPreviewOwned(ownerID)
            }

        case let .router(.routeAction(routeIndex, .epgTimeline(.delegate(.channelLogoOverrideChanged(channelID, playlistID, url))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .epgTimeline(timelineState) = state.routes[routeIndex].screen,
                  timelineState.config.playlistID == playlistID,
                  let homeRouteIndex = state.routes.lastIndex(where: { route in
                      if case .home = route.screen {
                          return true
                      }
                      return false
                  })
            else { return .none }
            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.liveTV(.channelLogoOverrideUpdated(channelID: channelID, playlistID: playlistID, url: url)))
            )))

        case let .router(.routeAction(routeIndex, .multiView(.delegate(.close)))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case .multiView = state.routes[routeIndex].screen
            else { return .none }
            state.routes.dismiss()
            return .none

        case let .router(.routeAction(routeIndex, .multiViewChannelSelection(.delegate(.close(presentationID))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .multiViewChannelSelection(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.multiViewRouteIndex),
                  case let .multiView(multiViewState) = state.routes[routeState.multiViewRouteIndex].screen,
                  multiViewState.presentationID == routeState.multiViewPresentationID,
                  multiViewState.isSelectingChannelForSlotID == routeState.slotID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.multiViewRouteIndex,
                action: .multiView(.channelSelectionDismissed)
            )))

        case let .router(.routeAction(routeIndex, .dashboardPresentation(.delegate(.close(presentationID))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .dashboardPresentation(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID
            else { return .none }
            state.routes.dismiss()
            return .none

        case let .router(.routeAction(routeIndex, .dashboardPresentation(.delegate(.selectEPGChannel(presentationID, channel))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .dashboardPresentation(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  case let .epgChannelPicker(playlistID, profileScope, event) = routeState.presentation,
                  state.routes.indices.contains(routeState.homeRouteIndex),
                  case let .home(homeState) = state.routes[routeState.homeRouteIndex].screen,
                  homeState.config == routeState.homeConfig,
                  homeState.dashboard.activePlaylistID == playlistID,
                  homeState.dashboard.epgCandidatePlaylistID == playlistID,
                  profileScope.map({ homeState.dashboard.activeProfileScope == $0 }) ?? true,
                  homeState.dashboard.epgEvents.contains(where: { $0.id == event.id }),
                  homeState.dashboard.epgCandidateChannels.contains(where: { $0.id == channel.id && $0.type == .live })
            else { return .none }
            state.routes.dismiss()
            return .send(.router(.routeAction(
                id: routeState.homeRouteIndex,
                action: .home(.dashboard(.mapEPGEventToChannel(
                    playlistID: playlistID,
                    event: event,
                    channelID: channel.id
                )))
            )))

        case let .dashboardPresentationRouteDidDisappear(presentationID, homeRouteIndex, homeConfig, reloadConfig):
            if let routeIndex = state.routes.indices.last(where: { index in
                if case let .dashboardPresentation(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID
                }
                return false
            }), routeIndex == state.routes.count - 1 {
                state.routes.dismiss()
            }

            guard let reloadConfig,
                  state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.config == homeConfig
            else { return .none }
            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.dashboard(.onAppear(config: reloadConfig)))
            )))

        case let .multiViewChannelSelectionRouteDidDisappear(presentationID, multiViewRouteIndex, multiViewPresentationID, slotID):
            if let selectionRouteIndex = state.routes.indices.last(where: { index in
                if case let .multiViewChannelSelection(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID
                }
                return false
            }), selectionRouteIndex == state.routes.count - 1 {
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(multiViewRouteIndex),
                  case let .multiView(multiViewState) = state.routes[multiViewRouteIndex].screen,
                  multiViewState.presentationID == multiViewPresentationID,
                  multiViewState.isSelectingChannelForSlotID == slotID
            else { return .none }
            return .send(.router(.routeAction(
                id: multiViewRouteIndex,
                action: .multiView(.channelSelectionDismissed)
            )))

        case let .router(.routeAction(multiViewRouteIndex, .multiView(.delegate(.channelSelectionFinished(slotID, presentationID))))):
            guard state.routes.indices.contains(multiViewRouteIndex),
                  case let .multiView(multiViewState) = state.routes[multiViewRouteIndex].screen,
                  multiViewState.presentationID == presentationID,
                  multiViewState.isSelectingChannelForSlotID == nil,
                  case let .multiViewChannelSelection(selectionState) = state.routes.last?.screen,
                  selectionState.multiViewRouteIndex == multiViewRouteIndex,
                  selectionState.multiViewPresentationID == presentationID,
                  selectionState.slotID == slotID
            else { return .none }
            state.routes.dismiss()
            return .none

        case let .router(.routeAction(routeIndex, .categoryManagement(.delegate(.close)))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case .categoryManagement = state.routes[routeIndex].screen
            else { return .none }
            state.routes.dismiss()
            return .none

        case let .router(.routeAction(routeIndex, .m3uCategoryMappingEditor(.delegate(.close(presentationID))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .m3uCategoryMappingEditor(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID
            else { return .none }
            state.routes.dismiss()
            return .none

        case let .m3uCategoryMappingsSaved(presentationID, categoryRouteIndex, categoryPresentationID, homeRouteIndex, maybePlaylistID):
            if let editorRouteIndex = state.routes.indices.last(where: { index in
                if case let .m3uCategoryMappingEditor(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID
                }
                return false
            }), editorRouteIndex == state.routes.count - 1 {
                state.routes.dismiss()
            }

            guard let playlistID = maybePlaylistID,
                  state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.liveTV.config?.type == .m3u,
                  homeState.liveTV.config?.playlistID == playlistID
            else { return .none }

            if state.routes.indices.contains(categoryRouteIndex),
               categoryRouteIndex > homeRouteIndex,
               case let .categoryManagement(categoryState) = state.routes[categoryRouteIndex].screen,
               categoryState.presentationID == categoryPresentationID,
               categoryState.type == .live,
               categoryState.config.type == .m3u,
               categoryState.config.playlistID == playlistID
            {
                return .send(.router(.routeAction(
                    id: categoryRouteIndex,
                    action: .categoryManagement(.m3uCategoryMappingsUpdated)
                )))
            }

            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.liveTV(.liveCategoryMappingsUpdated))
            )))

        case .router(.routeAction(_, .categoryManagement(.delegate(.categoriesUpdated)))):
            return forwardLiveTVAction(.categoryPreferencesUpdated, state: state)

        case let .router(.routeAction(categoryRouteIndex, .categoryManagement(.delegate(.m3uMappingsUpdated)))):
            guard state.routes.indices.contains(categoryRouteIndex),
                  categoryRouteIndex == state.routes.count - 1,
                  case let .categoryManagement(categoryState) = state.routes[categoryRouteIndex].screen,
                  categoryState.type == .live,
                  categoryState.config.type == .m3u,
                  let playlistID = categoryState.config.playlistID
            else { return .none }

            guard let homeRouteIndex = state.routes.indices.last(where: { routeIndex in
                guard routeIndex < categoryRouteIndex else { return false }
                if case .home = state.routes[routeIndex].screen { return true }
                return false
            }),
            case let .home(homeState) = state.routes[homeRouteIndex].screen,
            homeState.liveTV.config?.type == .m3u,
            homeState.liveTV.config?.playlistID == playlistID
            else { return .none }
            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.liveTV(.liveCategoryMappingsUpdated))
            )))

        case let .router(.routeAction(routeIndex, .parentalLock(.delegate(.didCancelFromRoute(presentationID))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .parentalLock(parentalLockState) = state.routes[routeIndex].screen,
                  parentalLockState.presentationID == presentationID
            else { return .none }
            state.routes.dismiss()
            return .none

        case let .router(.routeAction(routeIndex, .parentalLock(.delegate(.didUnlockFromRoute(presentationID, category, item))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .parentalLock(parentalLockState) = state.routes[routeIndex].screen,
                  parentalLockState.presentationID == presentationID
            else { return .none }
            state.routes.dismiss()
            return forwardLiveTVAction(.parentalLockUnlocked(category: category, item: item), state: state)

        case let .router(.routeAction(routeIndex, .smartChannelGroupManagement(.delegate(.close(presentationID))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .smartChannelGroupManagement(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID
            else { return .none }
            state.routes.dismiss()
            return .none

        case let .router(.routeAction(routeIndex, .channelPresentationEditor(.delegate(.close(presentationID))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .channelPresentationEditor(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID
            else { return .none }
            state.routes.dismiss()
            return .none

        // ── Home Delegates ───────────────────────────────────────
        case let .router(.routeAction(_, .home(.delegate(.didSelectChannel(channel, playlist))))):
            guard let config = state.activeConfig else { return .none }
            guard let playerState = makeLivePlayerState(channel: channel, playlist: playlist, config: config) else { return .none }
            state.isPlayerMini = false
            state.miniPlayer = nil
            state.routes.presentCover(.player(playerState))
            return .none

        case let .router(.routeAction(_, .home(.delegate(.presentEPGGuide(guideState))))):
            #if os(tvOS)
                state.routes.presentCover(.epgGuide(guideState))
            #else
                state.routes.presentSheet(.epgGuide(guideState))
            #endif
            return .none

        case let .router(.routeAction(_, .home(.delegate(.presentEPGTimeline(timelineState))))):
            #if os(tvOS)
                state.routes.presentCover(.epgTimeline(timelineState))
            #else
                state.routes.presentSheet(.epgTimeline(timelineState))
            #endif
            return .none

        case let .router(.routeAction(_, .home(.delegate(.presentMultiView(multiViewState))))):
            state.routes.presentCover(.multiView(multiViewState))
            return .none

        case let .router(.routeAction(multiViewRouteIndex, .multiView(.delegate(.presentChannelSelection(slotID, presentationID))))):
            guard state.routes.indices.contains(multiViewRouteIndex),
                  multiViewRouteIndex == state.routes.count - 1,
                  case let .multiView(multiViewState) = state.routes[multiViewRouteIndex].screen,
                  multiViewState.presentationID == presentationID,
                  multiViewState.isSelectingChannelForSlotID == slotID,
                  multiViewState.slots.contains(where: { $0.id == slotID && $0.item == nil })
            else { return .none }
            state.routes.presentSheet(.multiViewChannelSelection(
                MultiViewChannelSelectionRouteFeature.State(
                    multiViewRouteIndex: multiViewRouteIndex,
                    multiViewPresentationID: presentationID,
                    slotID: slotID
                )
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.dashboard(.delegate(.presentHomeSettings(config)))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .dashboard,
                  homeState.config == config
            else { return .none }
            state.routes.presentSheet(.dashboardPresentation(
                DashboardPresentationRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    homeConfig: homeState.config,
                    presentation: .homeSettings(reloadConfig: config)
                )
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.dashboard(.delegate(.presentHomeCategoryPinManagement(playlistID, profileScope)))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .dashboard,
                  homeState.dashboard.activePlaylistID == playlistID,
                  homeState.dashboard.activeProfileScope == profileScope
            else { return .none }
            state.routes.presentSheet(.dashboardPresentation(
                DashboardPresentationRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    homeConfig: homeState.config,
                    presentation: .categoryPinManagement(
                        playlistID: playlistID,
                        profileScope: profileScope
                    )
                )
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.dashboard(.delegate(.presentEPGChannelPicker(playlistID, event)))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .dashboard,
                  homeState.dashboard.activePlaylistID == playlistID,
                  homeState.dashboard.epgCandidatePlaylistID == playlistID,
                  homeState.dashboard.epgEvents.contains(where: { $0.id == event.id })
            else { return .none }
            state.routes.presentSheet(.dashboardPresentation(
                DashboardPresentationRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    homeConfig: homeState.config,
                    presentation: .epgChannelPicker(
                        playlistID: playlistID,
                        profileScope: homeState.dashboard.activeProfileScope,
                        event: event
                    )
                )
            ))
            return .none

        case let .router(.routeAction(_, .home(.delegate(.presentCategoryManagement(categoryState))))):
            state.routes.presentSheet(.categoryManagement(categoryState))
            return .none

        case let .router(.routeAction(categoryRouteIndex, .categoryManagement(.delegate(.presentM3UCategoryMapping(categoryPresentationID))))):
            guard state.routes.indices.contains(categoryRouteIndex),
                  categoryRouteIndex == state.routes.count - 1,
                  case let .categoryManagement(categoryState) = state.routes[categoryRouteIndex].screen,
                  categoryState.presentationID == categoryPresentationID,
                  categoryState.type == .live,
                  categoryState.config.type == .m3u,
                  let homeRouteIndex = state.routes.indices.last(where: { routeIndex in
                      guard routeIndex < categoryRouteIndex else { return false }
                      if case .home = state.routes[routeIndex].screen { return true }
                      return false
                  }),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.liveTV.config?.type == .m3u,
                  homeState.liveTV.config?.playlistID == categoryState.config.playlistID
            else { return .none }

            state.routes.presentSheet(.m3uCategoryMappingEditor(
                M3UCategoryMappingEditorRouteFeature.State(
                    categoryRouteIndex: categoryRouteIndex,
                    categoryPresentationID: categoryPresentationID,
                    homeRouteIndex: homeRouteIndex,
                    config: categoryState.config
                )
            ))
            return .none

        case let .router(.routeAction(_, .home(.delegate(.presentParentalLock(parentalLockState))))):
            return .send(.presentParentalLock(parentalLockState))

        case let .router(.routeAction(homeRouteIndex, .home(.delegate(.presentSmartGroupManager)))):
            guard state.routes.indices.contains(homeRouteIndex),
                  case .home = state.routes[homeRouteIndex].screen
            else { return .none }
            state.routes.presentSheet(.smartChannelGroupManagement(
                SmartChannelGroupManagementRouteFeature.State(homeRouteIndex: homeRouteIndex)
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.delegate(.presentChannelPresentationEditor(channel, playlistID, profileScope))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.liveTV.config?.playlistID == playlistID,
                  homeState.liveTV.channelPresentationPlaylistID == playlistID,
                  homeState.liveTV.channelPresentationProfileScope == profileScope
            else { return .none }
            state.routes.presentSheet(.channelPresentationEditor(
                ChannelPresentationEditorRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    channel: channel,
                    playlistID: playlistID,
                    profileScope: profileScope
                )
            ))
            return .none

        case let .router(.routeAction(_, .home(.delegate(.restrictMultiViewCategoryAndPresentParentalLock(categoryID, parentalLockState))))):
            let multiViewRouteIndices = state.routes.indices.filter { routeIndex in
                if case .multiView = state.routes[routeIndex].screen {
                    return true
                }
                return false
            }
            return .run { send in
                for routeIndex in multiViewRouteIndices {
                    await send(.router(.routeAction(
                        id: routeIndex,
                        action: .multiView(.restrictCategory(categoryID))
                    )))
                }
                await send(.presentParentalLock(parentalLockState))
            }

        case let .presentParentalLock(parentalLockState):
            state.routes.presentSheet(.parentalLock(parentalLockState))
            return .none

        case let .router(.routeAction(_, .home(.delegate(.restrictMultiViewCategory(categoryID))))):
            let effects = state.routes.indices.compactMap { routeIndex -> Effect<Action>? in
                guard case .multiView = state.routes[routeIndex].screen else { return nil }
                return .send(.router(.routeAction(
                    id: routeIndex,
                    action: .multiView(.restrictCategory(categoryID))
                )))
            }
            return .merge(effects)

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
        case let .router(.routeAction(_, .player(.delegate(.didSelectXtreamLiveOutputFormat(config))))):
            guard config.type == .xtream, let playlistID = config.playlistID else { return .none }

            func refreshedMediaItem(_ item: MediaModels.Item) -> MediaModels.Item {
                guard item.type == .live,
                      item.playlistID == nil || item.playlistID == playlistID,
                      let streamURL = makeXtreamLiveStreamURL(config: config, streamID: item.id) else { return item }
                return item.replacingStreamURL(streamURL)
            }

            func refreshedPlayableItem(_ item: PlayerFeature.PlayableItem) -> PlayerFeature.PlayableItem {
                guard item.config?.playlistID == playlistID else { return item }
                if item.isLive,
                   let streamURL = makeXtreamLiveStreamURL(config: config, streamID: item.id)
                {
                    return item.replacingLiveStreamURL(streamURL, playlistConfig: config)
                }
                return item.replacingPlaylistConfig(config)
            }

            for index in state.routes.indices {
                switch state.routes[index].screen {
                case var .home(homeState) where homeState.config.playlistID == playlistID:
                    homeState.config = config
                    homeState.liveTV.config = config
                    homeState.liveTV.channelsByCategory = homeState.liveTV.channelsByCategory.mapValues {
                        $0.map(refreshedMediaItem)
                    }
                    homeState.liveTV.selectedChannel = homeState.liveTV.selectedChannel.map(refreshedMediaItem)
                    homeState.liveTV.smartGroupChannels = homeState.liveTV.smartGroupChannels.map(refreshedMediaItem)
                    homeState.liveTV.favoriteListResolvedChannels = homeState.liveTV.favoriteListResolvedChannels.map(refreshedMediaItem)
                    if var epgTimeline = homeState.liveTV.epgTimeline {
                        epgTimeline.channels = epgTimeline.channels.map(refreshedMediaItem)
                        epgTimeline.providerOrderChannels = epgTimeline.providerOrderChannels.map(refreshedMediaItem)
                        homeState.liveTV.epgTimeline = epgTimeline
                    }
                    homeState.dashboard.featuredChannels = homeState.dashboard.featuredChannels.map(refreshedMediaItem)
                    homeState.dashboard.epgCandidateChannels = homeState.dashboard.epgCandidateChannels.map(refreshedMediaItem)
                    state.routes[index].screen = .home(homeState)
                case var .player(playerState) where playerState.item.config?.playlistID == playlistID:
                    playerState.item = refreshedPlayableItem(playerState.item)
                    playerState.activePlaybackURL = playerState.item.streamURL
                    playerState.playlist = playerState.playlist?.map(refreshedPlayableItem)
                    playerState.liveChannels = playerState.liveChannels.map(refreshedPlayableItem)
                    playerState.epgBrowseChannel = playerState.epgBrowseChannel.map(refreshedPlayableItem)
                    state.routes[index].screen = .player(playerState)
                default:
                    continue
                }
            }

            if let miniPlayer = state.miniPlayer, miniPlayer.item.config?.playlistID == playlistID {
                var updated = miniPlayer
                updated.item = refreshedPlayableItem(updated.item)
                updated.activePlaybackURL = updated.item.streamURL
                updated.playlist = updated.playlist?.map(refreshedPlayableItem)
                updated.liveChannels = updated.liveChannels.map(refreshedPlayableItem)
                updated.epgBrowseChannel = updated.epgBrowseChannel.map(refreshedPlayableItem)
                state.miniPlayer = updated
            }
            return .none

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

        case let .epgGuideRouteDidDisappear(presentationID):
            return .run { [previewPlayerClient] _ in
                await previewPlayerClient.stopPreviewOwned(presentationID)
            }

        case let .epgTimelineRouteDidDisappear(presentationID):
            return .run { [previewPlayerClient] _ in
                await previewPlayerClient.stopPreviewOwned(presentationID)
            }

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

    private func forwardLiveTVAction(
        _ action: LiveTVFeature.Action,
        state: State
    ) -> Effect<Action> {
        guard let homeRouteIndex = state.routes.lastIndex(where: { route in
            if case .home = route.screen {
                return true
            }
            return false
        }) else { return .none }

        return .send(.router(.routeAction(
            id: homeRouteIndex,
            action: .home(.liveTV(action))
        )))
    }

    private func makeLivePlayerState(
        channel: MediaModels.Item,
        playlist: [MediaModels.Item]?,
        config: PlaylistConfig
    ) -> PlayerFeature.State? {
        guard let streamURL = channel.streamURL else { return nil }
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
        let playable = PlayerFeature.PlayableItem(
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
        )
        return PlayerFeature.State(item: playable, playlist: playablePlaylist)
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
        if store.isStartupPlaylistReadFailed {
            playlistRecoveryContent
        } else {
            routerContent
        }
    }

    private var playlistRecoveryContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "lock.icloud")
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                Text(AppStrings.Startup.playlistUnavailableTitle)
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(AppStrings.Startup.playlistUnavailableMessage)
                    .font(.body)
                Button(AppStrings.Common.retry) { store.send(.proceedToApp) }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 48)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 900)
            .padding(48)
            .frame(maxWidth: .infinity)
        }
    }

    private var routerContent: some View {
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
            case let .epgGuide(screenStore):
                let presentationID = screenStore.presentationID
                #if os(tvOS)
                    EPGGuideView_tvOS(store: screenStore)
                        .onDisappear {
                            store.send(.epgGuideRouteDidDisappear(presentationID))
                        }
                #else
                    EPGGuideView_iOS(store: screenStore)
                        .onDisappear {
                            store.send(.epgGuideRouteDidDisappear(presentationID))
                        }
                #endif
            case let .epgTimeline(screenStore):
                let presentationID = screenStore.presentationID
                EPGTimelineView(store: screenStore)
                    .onDisappear {
                        store.send(.epgTimelineRouteDidDisappear(presentationID))
                    }
            case let .multiView(screenStore):
                MultiView(store: screenStore)
            case let .multiViewChannelSelection(screenStore):
                MultiViewChannelSelectionRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .dashboardPresentation(screenStore):
                DashboardPresentationRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .categoryManagement(screenStore):
                CategoryManagementView(store: screenStore)
            case let .m3uCategoryMappingEditor(screenStore):
                M3UCategoryMappingEditorRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .parentalLock(screenStore):
                #if os(iOS)
                    ParentalLockView(store: screenStore)
                        .presentationDetents([.height(300)])
                #else
                    ParentalLockView(store: screenStore)
                #endif
            case let .smartChannelGroupManagement(screenStore):
                SmartChannelGroupManagementRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .channelPresentationEditor(screenStore):
                ChannelPresentationEditorRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
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

private struct SmartChannelGroupManagementRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<SmartChannelGroupManagementRouteFeature>

    @ViewBuilder
    var body: some View {
        if coordinatorStore.routes.indices.contains(routeStore.homeRouteIndex),
           case let .home(homeState) = coordinatorStore.routes[routeStore.homeRouteIndex].screen
        {
            let liveTVState = homeState.liveTV
            SmartChannelGroupManagementView(
                groups: liveTVState.smartChannelGroups,
                selectableCategories: liveTVState.smartGroupSelectableCategories,
                isLoading: liveTVState.isLoadingSmartGroups,
                onSave: { id, name, categoryIDs in
                    sendToLiveTV(.saveSmartChannelGroup(id: id, name: name, categoryIDs: categoryIDs))
                },
                onDelete: { groupID in
                    sendToLiveTV(.deleteSmartChannelGroup(groupID))
                },
                onClose: {
                    routeStore.send(.closeTapped)
                }
            )
        } else {
            EmptyView()
        }
    }

    private func sendToLiveTV(_ action: LiveTVFeature.Action) {
        guard coordinatorStore.routes.indices.contains(routeStore.homeRouteIndex),
              case .home = coordinatorStore.routes[routeStore.homeRouteIndex].screen
        else { return }
        coordinatorStore.send(.router(.routeAction(
            id: routeStore.homeRouteIndex,
            action: .home(.liveTV(action))
        )))
    }
}

private struct ChannelPresentationEditorRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<ChannelPresentationEditorRouteFeature>

    var body: some View {
        Group {
            if let liveTVState, isCurrentContext(liveTVState) {
                let override = liveTVState.channelPresentationOverrides[routeStore.channel.id]
                ChannelPresentationEditorView(
                    channelTitle: routeStore.channel.title,
                    currentName: override?.name,
                    currentNumber: override?.number,
                    onSave: { name, number in
                        sendToLiveTV(.saveChannelPresentationOverride(
                            channelID: routeStore.channel.id,
                            name: name,
                            number: number,
                            playlistID: routeStore.playlistID,
                            profileScope: routeStore.profileScope
                        ))
                    },
                    onClose: {
                        routeStore.send(.closeTapped)
                    }
                )
            } else {
                EmptyView()
            }
        }
        .onAppear(perform: closeIfContextChanged)
        .onChange(of: liveTVState?.channelPresentationPlaylistID) { _, _ in closeIfContextChanged() }
        .onChange(of: liveTVState?.channelPresentationProfileScope) { _, _ in closeIfContextChanged() }
    }

    private var liveTVState: LiveTVFeature.State? {
        guard coordinatorStore.routes.indices.contains(routeStore.homeRouteIndex),
              case let .home(homeState) = coordinatorStore.routes[routeStore.homeRouteIndex].screen
        else { return nil }
        return homeState.liveTV
    }

    private func isCurrentContext(_ liveTVState: LiveTVFeature.State) -> Bool {
        liveTVState.config?.playlistID == routeStore.playlistID
            && liveTVState.channelPresentationPlaylistID == routeStore.playlistID
            && liveTVState.channelPresentationProfileScope == routeStore.profileScope
    }

    private func closeIfContextChanged() {
        guard let liveTVState, isCurrentContext(liveTVState) else {
            routeStore.send(.closeTapped)
            return
        }
    }

    private func sendToLiveTV(_ action: LiveTVFeature.Action) {
        guard let liveTVState, isCurrentContext(liveTVState) else { return }
        coordinatorStore.send(.router(.routeAction(
            id: routeStore.homeRouteIndex,
            action: .home(.liveTV(action))
        )))
    }
}

private struct M3UCategoryMappingEditorRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<M3UCategoryMappingEditorRouteFeature>

    var body: some View {
        M3UCategoryMappingEditorView(
            config: routeStore.config,
            onSave: {
                coordinatorStore.send(.m3uCategoryMappingsSaved(
                    presentationID: routeStore.presentationID,
                    categoryRouteIndex: routeStore.categoryRouteIndex,
                    categoryPresentationID: routeStore.categoryPresentationID,
                    homeRouteIndex: routeStore.homeRouteIndex,
                    playlistID: routeStore.config.playlistID
                ))
            },
            onClose: {
                routeStore.send(.closeTapped)
            }
        )
    }
}

private struct MultiViewChannelSelectionRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<MultiViewChannelSelectionRouteFeature>

    var body: some View {
        Group {
            if let multiViewState, isCurrentContext(multiViewState) {
                ChannelSelectionSheet(
                    state: multiViewState,
                    send: sendToMultiView,
                    onSelect: { sendToMultiView(.channelSelected($0)) },
                    onDismiss: { routeStore.send(.closeTapped) }
                )
                .presentationDetents([.medium, .large])
            } else {
                EmptyView()
            }
        }
        .onAppear(perform: closeIfContextChanged)
        .onChange(of: multiViewState?.presentationID) { _, _ in closeIfContextChanged() }
        .onChange(of: multiViewState?.isSelectingChannelForSlotID) { _, _ in closeIfContextChanged() }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var multiViewState: MultiViewFeature.State? {
        guard coordinatorStore.routes.indices.contains(routeStore.multiViewRouteIndex),
              case let .multiView(multiViewState) = coordinatorStore.routes[routeStore.multiViewRouteIndex].screen
        else { return nil }
        return multiViewState
    }

    private func isCurrentContext(_ multiViewState: MultiViewFeature.State) -> Bool {
        multiViewState.presentationID == routeStore.multiViewPresentationID
            && multiViewState.isSelectingChannelForSlotID == routeStore.slotID
            && multiViewState.slots.contains(where: { $0.id == routeStore.slotID && $0.item == nil })
    }

    private func closeIfContextChanged() {
        guard let multiViewState, isCurrentContext(multiViewState) else {
            notifyRouteDidDisappear()
            return
        }
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.multiViewChannelSelectionRouteDidDisappear(
            presentationID: routeStore.presentationID,
            multiViewRouteIndex: routeStore.multiViewRouteIndex,
            multiViewPresentationID: routeStore.multiViewPresentationID,
            slotID: routeStore.slotID
        ))
    }

    private func sendToMultiView(_ action: MultiViewFeature.Action) {
        guard let multiViewState, isCurrentContext(multiViewState) else {
            notifyRouteDidDisappear()
            return
        }
        coordinatorStore.send(.router(.routeAction(
            id: routeStore.multiViewRouteIndex,
            action: .multiView(action)
        )))
    }
}

private struct DashboardPresentationRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<DashboardPresentationRouteFeature>

    var body: some View {
        Group {
            if let homeState, isCurrentContext(homeState) {
                switch routeStore.presentation {
                case .homeSettings:
                    ModularHomeSettingsView(onClose: close)

                case .categoryPinManagement:
                    HomeCategoryPinManagementView(
                        state: homeState.dashboard,
                        send: sendToDashboard,
                        onClose: close
                    )

                case let .epgChannelPicker(_, _, _):
                    DashboardEPGChannelPicker(
                        channels: homeState.dashboard.epgCandidateChannels,
                        onSelect: { routeStore.send(.selectEPGChannel($0)) },
                        onCancel: close
                    )
                }
            } else {
                EmptyView()
            }
        }
        .onAppear(perform: closeIfContextChanged)
        .onChange(of: homeState?.config) { _, _ in closeIfContextChanged() }
        .onChange(of: homeState?.dashboard.activePlaylistID) { _, _ in closeIfContextChanged() }
        .onChange(of: homeState?.dashboard.activeProfileScope) { _, _ in closeIfContextChanged() }
        .onChange(of: homeState?.dashboard.epgCandidatePlaylistID) { _, _ in closeIfContextChanged() }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var homeState: HomeFeature.State? {
        guard coordinatorStore.routes.indices.contains(routeStore.homeRouteIndex),
              case let .home(homeState) = coordinatorStore.routes[routeStore.homeRouteIndex].screen
        else { return nil }
        return homeState
    }

    private func isCurrentContext(_ homeState: HomeFeature.State) -> Bool {
        guard homeState.config == routeStore.homeConfig else { return false }

        switch routeStore.presentation {
        case let .homeSettings(reloadConfig):
            return reloadConfig == routeStore.homeConfig

        case let .categoryPinManagement(playlistID, profileScope):
            return (playlistID == nil || playlistID == homeState.dashboard.activePlaylistID)
                && (profileScope == nil || profileScope == homeState.dashboard.activeProfileScope)

        case let .epgChannelPicker(playlistID, profileScope, event):
            return homeState.dashboard.activePlaylistID == playlistID
                && homeState.dashboard.epgCandidatePlaylistID == playlistID
                && (profileScope == nil || profileScope == homeState.dashboard.activeProfileScope)
                && homeState.dashboard.epgEvents.contains(where: { $0.id == event.id })
        }
    }

    private func closeIfContextChanged() {
        guard let homeState, isCurrentContext(homeState) else {
            routeStore.send(.closeTapped)
            return
        }
    }

    private func close() {
        routeStore.send(.closeTapped)
    }

    private func notifyRouteDidDisappear() {
        let reloadConfig: PlaylistConfig? = if case let .homeSettings(config) = routeStore.presentation {
            config
        } else {
            nil
        }
        coordinatorStore.send(.dashboardPresentationRouteDidDisappear(
            presentationID: routeStore.presentationID,
            homeRouteIndex: routeStore.homeRouteIndex,
            homeConfig: routeStore.homeConfig,
            reloadConfig: reloadConfig
        ))
    }

    private func sendToDashboard(_ action: DashboardFeature.Action) {
        guard let homeState, isCurrentContext(homeState) else {
            routeStore.send(.closeTapped)
            return
        }
        coordinatorStore.send(.router(.routeAction(
            id: routeStore.homeRouteIndex,
            action: .home(.dashboard(action))
        )))
    }
}
