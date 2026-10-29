import ComposableArchitecture
import FactoryKit
import FlowStacks
import Foundation
import RevenueCat
import SwiftUI
import SwiftVLC
import TCACoordinators
import UniformTypeIdentifiers

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
        public var playlistTransferPresentationID: UUID?
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
        case selectPlaylistForTransfer(sessionID: UUID, presentationID: UUID, playlistID: UUID)
        case playlistTransferPlaylistsLoaded(sessionID: UUID, presentationID: UUID, playlists: [SavedPlaylist]?)
        case confirmPlaylistTransfer(sessionID: UUID, presentationID: UUID)
        case cancelPlaylistTransfer(sessionID: UUID, presentationID: UUID)
        case playlistTransferRouteDidDisappear(presentationID: UUID, sessionID: UUID)
        case playlistTransferSubmissionResponse(sessionID: UUID, presentationID: UUID, succeeded: Bool)
        case playlistManagementSettingsRouteDidDisappear(
            presentationID: UUID,
            playlistManagementRouteIndex: Int,
            editRequestID: UUID
        )
        case playlistManagementPINRouteDidDisappear(
            presentationID: UUID,
            playlistManagementRouteIndex: Int,
            requestID: UUID,
            flow: PlaylistManagementFeature.State.PINFlow
        )
        case playlistManagementAddPlaylistRouteDidDisappear(
            presentationID: UUID,
            playlistManagementRouteIndex: Int,
            requestID: UUID
        )
        case playlistManagementAddPlaylistChildAction(
            presentationID: UUID,
            requestID: UUID,
            action: AddPlaylistFeature.Action
        )
        case playerSpeedTestRouteDidDisappear(
            presentationID: UUID,
            playerRouteIndex: Int,
            requestID: UUID
        )
        case playerSubtitleSearchRouteDidDisappear(
            presentationID: UUID,
            playerRouteIndex: Int,
            requestID: UUID
        )
        case settingsSpeedTestRouteDidDisappear(
            presentationID: UUID,
            homeRouteIndex: Int,
            requestID: UUID
        )
        case settingsPINSetupRouteDidDisappear(
            presentationID: UUID,
            homeRouteIndex: Int,
            requestID: UUID
        )
        case settingsTraktAuthRouteDidDisappear(
            presentationID: UUID,
            homeRouteIndex: Int,
            requestID: UUID
        )
        case settingsTraktWatchlistRouteDidDisappear(
            presentationID: UUID,
            homeRouteIndex: Int,
            requestID: UUID
        )
        case settingsHiddenContentRouteDidDisappear(
            presentationID: UUID,
            homeRouteIndex: Int,
            requestID: UUID
        )
        case settingsDiagnosticReportRouteDidDisappear(
            presentationID: UUID,
            homeRouteIndex: Int,
            requestID: UUID
        )
        case settingsBackupPreviewRouteDidDisappear(
            presentationID: UUID,
            homeRouteIndex: Int,
            requestID: UUID
        )
        case detailTMDBMatchPickerRouteDidDisappear(
            presentationID: UUID,
            detailRouteIndex: Int,
            parent: DetailTMDBMatchPickerRouteFeature.Parent,
            requestID: UUID
        )
        case detailSynopsisRouteDidDisappear(
            presentationID: UUID,
            parentRouteIndex: Int,
            parent: DetailSynopsisRouteFeature.Parent,
            requestID: UUID
        )
        case detailActorBiographyRouteDidDisappear(
            presentationID: UUID,
            parentRouteIndex: Int,
            itemID: String,
            requestID: UUID
        )
        case detailTrailerRouteDidDisappear(
            presentationID: UUID,
            parentRouteIndex: Int,
            parent: DetailTrailerRouteFeature.Parent,
            requestID: UUID
        )
        case detailUnmatchedMovieRouteDidDisappear(
            presentationID: UUID,
            parentRouteIndex: Int,
            itemID: String,
            requestID: UUID
        )
        case presentDetailSynopsis(parent: DetailSynopsisRouteFeature.Parent, text: String)
        case customEPGSettingsRouteDidDisappear(
            presentationID: UUID,
            homeRouteIndex: Int,
            requestID: UUID
        )
        case customEPGSourceAddRouteDidDisappear(
            presentationID: UUID,
            customEPGSettingsPresentationID: UUID,
            homeRouteIndex: Int,
            requestID: UUID
        )
        case receiveStreamHandoff(StreamHandoffRequest)
        case streamHandoffResolved(requestID: UUID, playable: PlayerFeature.PlayableItem?)
        case dismissStreamHandoffError
        case appEnteredForeground
        case appEnteredBackground
        case epgReminderMonitorTick([EPGReminder])
        case epgGuideRouteDidDisappear(UUID)
        case epgTimelineRouteDidDisappear(UUID)
        case epgTimelineProgramDetailRouteDidDisappear(
            presentationID: UUID,
            timelineRouteIndex: Int,
            timelinePresentationID: UUID,
            detailRequestID: UUID
        )
        case epgTimelineChannelLogoEditorRouteDidDisappear(UUID)
        case profileAddProfileRouteDidDisappear(presentationID: UUID, profileSelectionRouteIndex: Int)
        case favoriteChannelListManagementRouteDidDisappear(UUID)
        case addPlaylistQRTransferRouteDidDisappear(
            presentationID: UUID,
            parent: AddPlaylistQRTransferRouteFeature.State.Parent,
            wasPaired: Bool
        )
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
        case let .router(.routeAction(routeIndex, .profileSelection(.addProfileTapped))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .profileSelection(profileState) = state.routes[routeIndex].screen,
                  !profileState.isEditing,
                  profileState.profiles.count < 6,
                  !state.routes.contains(where: { route in
                      guard case let .profileAddProfile(routeState) = route.screen else { return false }
                      return routeState.profileSelectionRouteIndex == routeIndex
                  })
            else { return .none }

            state.routes.presentSheet(.profileAddProfile(
                ProfileAddProfileRouteFeature.State(
                    profileSelectionRouteIndex: routeIndex,
                    profileCountAtPresentation: profileState.profiles.count
                )
            ))
            return .none

        case let .router(.routeAction(routeIndex, .profileAddProfile(.delegate(.close(presentationID))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .profileAddProfile(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  state.routes.indices.contains(routeState.profileSelectionRouteIndex),
                  case .profileSelection = state.routes[routeState.profileSelectionRouteIndex].screen
            else { return .none }

            state.routes.dismiss()
            return .send(.router(.routeAction(
                id: routeState.profileSelectionRouteIndex,
                action: .profileSelection(.binding(.set(\.showingAddProfile, false)))
            )))

        case let .profileAddProfileRouteDidDisappear(presentationID, profileSelectionRouteIndex):
            guard !state.routes.contains(where: { route in
                      guard case let .profileAddProfile(routeState) = route.screen else { return false }
                      return routeState.presentationID == presentationID
                          || routeState.profileSelectionRouteIndex == profileSelectionRouteIndex
                  }),
                  state.routes.indices.contains(profileSelectionRouteIndex),
                  case let .profileSelection(profileState) = state.routes[profileSelectionRouteIndex].screen,
                  profileState.showingAddProfile
            else { return .none }

            return .send(.router(.routeAction(
                id: profileSelectionRouteIndex,
                action: .profileSelection(.binding(.set(\.showingAddProfile, false)))
            )))

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
        case let .router(.routeAction(routeIndex, .addPlaylist(.delegate(.presentQRTransfer)))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case .addPlaylist = state.routes[routeIndex].screen
            else { return .none }
            state.routes.presentSheet(.addPlaylistQRTransfer(
                AddPlaylistQRTransferRouteFeature.State(
                    parent: .addPlaylistRoute(routeIndex: routeIndex)
                )
            ))
            return .none

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

        case let .router(.routeAction(routeIndex, .epgTimeline(.delegate(.presentProgramDetails(
            timelinePresentationID: timelinePresentationID,
            detailRequestID: detailRequestID,
            program: program,
            channel: channel
        ))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .epgTimeline(timelineState) = state.routes[routeIndex].screen,
                  timelineState.presentationID == timelinePresentationID,
                  timelineState.selectedProgramDetailRequestID == detailRequestID,
                  timelineState.selectedProgramDetail == program,
                  timelineState.selectedProgramChannel == channel
            else { return .none }

            state.routes.presentSheet(.epgTimelineProgramDetail(
                EPGTimelineProgramDetailRouteFeature.State(
                    timelineRouteIndex: routeIndex,
                    timelinePresentationID: timelinePresentationID,
                    detailRequestID: detailRequestID,
                    config: timelineState.config,
                    program: program,
                    channel: channel
                )
            ))
            return .none

        case let .router(.routeAction(routeIndex, .epgTimeline(.delegate(.presentChannelLogoEditor(
            timelinePresentationID: timelinePresentationID,
            channelID: channelID
        ))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .epgTimeline(timelineState) = state.routes[routeIndex].screen,
                  timelineState.presentationID == timelinePresentationID,
                  let playlistID = timelineState.config.playlistID,
                  let channel = timelineState.channels.first(where: { $0.id == channelID && $0.type == .live })
            else { return .none }

            state.routes.presentSheet(.epgTimelineChannelLogoEditor(
                EPGTimelineChannelLogoEditorRouteFeature.State(
                    timelineRouteIndex: routeIndex,
                    timelinePresentationID: timelinePresentationID,
                    playlistID: playlistID,
                    channel: channel
                )
            ))
            return .none

        case let .router(.routeAction(routeIndex, .epgTimeline(.dismissProgramDetails))):
            guard state.routes.indices.contains(routeIndex),
                  case let .epgTimeline(timelineState) = state.routes[routeIndex].screen,
                  let detailRequestID = timelineState.selectedProgramDetailRequestID
            else { return .none }

            if let detailRouteIndex = state.routes.indices.last(where: { index in
                guard case let .epgTimelineProgramDetail(detailState) = state.routes[index].screen else { return false }
                return detailState.timelineRouteIndex == routeIndex
                    && detailState.timelinePresentationID == timelineState.presentationID
                    && detailState.detailRequestID == detailRequestID
            }), detailRouteIndex == state.routes.count - 1 {
                state.routes.dismiss()
            }
            return .none

        case let .router(.routeAction(routeIndex, .epgTimelineProgramDetail(.delegate(.close(presentationID))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .epgTimelineProgramDetail(detailState) = state.routes[routeIndex].screen,
                  detailState.presentationID == presentationID
            else { return .none }
            state.routes.dismiss()
            return .send(.router(.routeAction(
                id: detailState.timelineRouteIndex,
                action: .epgTimeline(.dismissProgramDetailsIfCurrent(detailState.detailRequestID))
            )))

        case let .router(.routeAction(routeIndex, .epgTimelineChannelLogoEditor(.closeTapped(presentationID)))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .epgTimelineChannelLogoEditor(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID
            else { return .none }
            state.routes.dismiss()
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

        case let .router(.routeAction(routeIndex, .favoriteChannelListManagement(.delegate(.close(presentationID))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .favoriteChannelListManagement(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID
            else { return .none }
            state.routes.dismiss()
            return .none

        case let .router(.routeAction(routeIndex, .addPlaylistQRTransfer(.delegate(.close(presentationID))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .addPlaylistQRTransfer(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID
            else { return .none }
            return .send(.addPlaylistQRTransferRouteDidDisappear(
                presentationID: presentationID,
                parent: routeState.parent,
                wasPaired: routeState.isPaired
            ))

        case let .router(.routeAction(routeIndex, .addPlaylistQRTransfer(.delegate(.complete(presentationID))))):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .addPlaylistQRTransfer(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.isPaired
            else { return .none }
            return .send(.addPlaylistQRTransferRouteDidDisappear(
                presentationID: presentationID,
                parent: routeState.parent,
                wasPaired: true
            ))

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

        case let .router(.routeAction(
            routeIndex,
            .playlistQRTransferConfirmation(.delegate(.cancel(presentationID, sessionID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .playlistQRTransferConfirmation(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.sessionID == sessionID
            else { return .none }
            state.routes.dismiss()
            return .send(.cancelPlaylistTransfer(sessionID: sessionID, presentationID: presentationID))

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

        case let .favoriteChannelListManagementRouteDidDisappear(presentationID):
            if let routeIndex = state.routes.indices.last(where: { index in
                if case let .favoriteChannelListManagement(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID
                }
                return false
            }), routeIndex == state.routes.count - 1 {
                state.routes.dismiss()
            }
            return .none

        case let .addPlaylistQRTransferRouteDidDisappear(presentationID, parent, wasPaired):
            var didPair = wasPaired
            if let routeIndex = state.routes.indices.last(where: { index in
                if case let .addPlaylistQRTransfer(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID
                }
                return false
            }) {
                guard routeIndex == state.routes.count - 1,
                      case let .addPlaylistQRTransfer(routeState) = state.routes[routeIndex].screen
                else { return .none }
                didPair = didPair || routeState.isPaired
                state.routes.dismiss()
            }

            switch parent {
            case let .addPlaylistRoute(routeIndex):
                guard state.routes.indices.contains(routeIndex),
                      routeIndex == state.routes.count - 1,
                      case .addPlaylist = state.routes[routeIndex].screen
                else { return .none }
                let childAction: AddPlaylistFeature.Action = didPair
                    ? .delegate(.didReceiveTransferredPlaylist)
                    : .qrTransferRouteDidDismiss(presentationID)
                return .send(.router(.routeAction(
                    id: routeIndex,
                    action: .addPlaylist(childAction)
                )))

            case let .playlistManagementAddPlaylistRoute(routeIndex, parentPresentationID, requestID):
                guard state.routes.indices.contains(routeIndex),
                      routeIndex == state.routes.count - 1,
                      case let .playlistManagementAddPlaylist(addPlaylistState) = state.routes[routeIndex].screen,
                      addPlaylistState.presentationID == parentPresentationID,
                      addPlaylistState.requestID == requestID,
                      state.routes.indices.contains(addPlaylistState.playlistManagementRouteIndex),
                      case let .playlistManagement(managementState) = state.routes[addPlaylistState.playlistManagementRouteIndex].screen,
                      managementState.addPlaylistPresentationRequestID == requestID,
                      managementState.addPlaylist != nil,
                      managementState.startupUnlockPlaylistID == nil
                else { return .none }
                let childAction: AddPlaylistFeature.Action = didPair
                    ? .delegate(.didReceiveTransferredPlaylist)
                    : .qrTransferRouteDidDismiss(presentationID)
                return .send(.playlistManagementAddPlaylistChildAction(
                    presentationID: parentPresentationID,
                    requestID: requestID,
                    action: childAction
                ))
            }

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

        case let .playlistTransferRouteDidDisappear(presentationID, sessionID):
            let routeIndex = state.routes.indices.last(where: { index in
                if case let .playlistQRTransferConfirmation(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.sessionID == sessionID
                }
                return false
            })
            if let routeIndex {
                guard routeIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.playlistTransferPresentationID == presentationID,
                  state.playlistTransferPairing?.sessionID == sessionID
            else { return .none }
            return .send(.cancelPlaylistTransfer(sessionID: sessionID, presentationID: presentationID))

        case let .playlistManagementSettingsRouteDidDisappear(presentationID, playlistManagementRouteIndex, editRequestID):
            let settingsRouteIndex = state.routes.indices.last(where: { index in
                if case let .playlistManagementSettings(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.editRequestID == editRequestID
                }
                return false
            })
            if let settingsRouteIndex {
                guard settingsRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(playlistManagementRouteIndex),
                  case let .playlistManagement(managementState) = state.routes[playlistManagementRouteIndex].screen,
                  managementState.playlistSettingsEditRequestID == editRequestID
            else { return .none }
            return .send(.router(.routeAction(
                id: playlistManagementRouteIndex,
                action: .playlistManagement(.cancelPlaylistSettings)
            )))

        case let .playlistManagementPINRouteDidDisappear(presentationID, playlistManagementRouteIndex, requestID, flow):
            let pinRouteIndex = state.routes.indices.last(where: { index in
                if case let .playlistManagementPIN(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let pinRouteIndex {
                guard pinRouteIndex == state.routes.count - 1,
                      case let .playlistManagementPIN(routeState) = state.routes[pinRouteIndex].screen,
                      !routeState.isStartupUnlock
                else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(playlistManagementRouteIndex),
                  case let .playlistManagement(managementState) = state.routes[playlistManagementRouteIndex].screen,
                  managementState.pinPresentationRequestID == requestID,
                  managementState.pinFlow == flow
            else { return .none }
            if case .startup = flow { return .none }
            return .send(.router(.routeAction(
                id: playlistManagementRouteIndex,
                action: .playlistManagement(.cancelPlaylistPIN)
            )))

        case let .playlistManagementAddPlaylistRouteDidDisappear(presentationID, playlistManagementRouteIndex, requestID):
            let addPlaylistRouteIndex = state.routes.indices.last(where: { index in
                if case let .playlistManagementAddPlaylist(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let addPlaylistRouteIndex {
                guard addPlaylistRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(playlistManagementRouteIndex),
                  case let .playlistManagement(managementState) = state.routes[playlistManagementRouteIndex].screen,
                  managementState.addPlaylistPresentationRequestID == requestID,
                  managementState.addPlaylist != nil
            else { return .none }
            return .send(.router(.routeAction(
                id: playlistManagementRouteIndex,
                action: .playlistManagement(.closeAddPlaylistTapped(requestID: requestID))
            )))

        case let .playlistManagementAddPlaylistChildAction(presentationID, requestID, childAction):
            guard case let .playlistManagementAddPlaylist(addPlaylistRouteState) = state.routes.last?.screen,
                  addPlaylistRouteState.presentationID == presentationID,
                  addPlaylistRouteState.requestID == requestID,
                  state.routes.indices.contains(addPlaylistRouteState.playlistManagementRouteIndex),
                  case let .playlistManagement(managementState) = state.routes[addPlaylistRouteState.playlistManagementRouteIndex].screen,
                  managementState.addPlaylistPresentationRequestID == requestID,
                  managementState.addPlaylist != nil,
                  managementState.startupUnlockPlaylistID == nil
            else { return .none }

            return .send(.router(.routeAction(
                id: addPlaylistRouteState.playlistManagementRouteIndex,
                action: .playlistManagement(.addPlaylist(.presented(childAction)))
            )))

        case let .playerSpeedTestRouteDidDisappear(presentationID, playerRouteIndex, requestID):
            let speedTestRouteIndex = state.routes.indices.last(where: { index in
                if case let .playerSpeedTest(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let speedTestRouteIndex {
                guard speedTestRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(playerRouteIndex),
                  case let .player(playerState) = state.routes[playerRouteIndex].screen,
                  playerState.speedTestPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: playerRouteIndex,
                action: .player(.closeSpeedTest(requestID: requestID))
            )))

        case let .playerSubtitleSearchRouteDidDisappear(presentationID, playerRouteIndex, requestID):
            let subtitleSearchRouteIndex = state.routes.indices.last(where: { index in
                if case let .playerSubtitleSearch(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let subtitleSearchRouteIndex {
                guard subtitleSearchRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(playerRouteIndex),
                  case let .player(playerState) = state.routes[playerRouteIndex].screen,
                  playerState.subtitleSearchPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: playerRouteIndex,
                action: .player(.closeSubtitleSearch(requestID: requestID))
            )))

        case let .settingsSpeedTestRouteDidDisappear(presentationID, homeRouteIndex, requestID):
            let settingsSpeedTestRouteIndex = state.routes.indices.last(where: { index in
                if case let .settingsSpeedTest(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let settingsSpeedTestRouteIndex {
                guard settingsSpeedTestRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.settings.speedTestPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.settings(.closeSpeedTest(requestID: requestID)))
            )))

        case let .settingsPINSetupRouteDidDisappear(presentationID, homeRouteIndex, requestID):
            let pinSetupRouteIndex = state.routes.indices.last(where: { index in
                if case let .settingsPINSetup(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let pinSetupRouteIndex {
                guard pinSetupRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.settings.pinSetupPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.settings(.coordinatorDismissPINSetup(requestID: requestID)))
            )))

        case let .settingsTraktAuthRouteDidDisappear(presentationID, homeRouteIndex, requestID):
            let traktAuthRouteIndex = state.routes.indices.last(where: { index in
                if case let .settingsTraktAuth(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let traktAuthRouteIndex {
                guard traktAuthRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.settings.traktAuthPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.settings(.coordinatorDismissTraktAuth(requestID: requestID)))
            )))

        case let .settingsTraktWatchlistRouteDidDisappear(presentationID, homeRouteIndex, requestID):
            let traktWatchlistRouteIndex = state.routes.indices.last(where: { index in
                if case let .settingsTraktWatchlist(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let traktWatchlistRouteIndex {
                guard traktWatchlistRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.settings.traktWatchlistPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.settings(.coordinatorDismissTraktWatchlist(requestID: requestID)))
            )))

        case let .settingsHiddenContentRouteDidDisappear(presentationID, homeRouteIndex, requestID):
            let hiddenContentRouteIndex = state.routes.indices.last(where: { index in
                if case let .settingsHiddenContent(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let hiddenContentRouteIndex {
                guard hiddenContentRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.settings.hiddenContentPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.settings(.coordinatorDismissHiddenContentManagement(requestID: requestID)))
            )))

        case let .settingsDiagnosticReportRouteDidDisappear(presentationID, homeRouteIndex, requestID):
            let diagnosticReportRouteIndex = state.routes.indices.last(where: { index in
                if case let .settingsDiagnosticReport(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let diagnosticReportRouteIndex {
                guard diagnosticReportRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.settings.diagnosticReportPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.settings(.coordinatorDismissDiagnosticReport(requestID: requestID)))
            )))

        case let .settingsBackupPreviewRouteDidDisappear(presentationID, homeRouteIndex, requestID):
            let backupPreviewRouteIndex = state.routes.indices.last(where: { index in
                if case let .settingsBackupPreview(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let backupPreviewRouteIndex {
                guard backupPreviewRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.settings.backupPreviewPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.settings(.coordinatorDismissBackupPreview(requestID: requestID)))
            )))

        case let .detailTMDBMatchPickerRouteDidDisappear(presentationID, detailRouteIndex, parent, requestID):
            let pickerRouteIndex = state.routes.indices.last(where: { index in
                if case let .detailTMDBMatchPicker(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let pickerRouteIndex {
                guard pickerRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(detailRouteIndex) else { return .none }
            switch (parent, state.routes[detailRouteIndex].screen) {
            case let (.vod(itemID), .vodDetail(vodState))
                where vodState.vod.id == itemID && vodState.tmdbMatchPresentationRequestID == requestID:
                return .send(.router(.routeAction(
                    id: detailRouteIndex,
                    action: .vodDetail(.coordinatorDismissTMDBMatchPicker(requestID: requestID))
                )))

            case let (.series(itemID), .seriesDetail(seriesState))
                where seriesState.series.id == itemID && seriesState.tmdbMatchPresentationRequestID == requestID:
                return .send(.router(.routeAction(
                    id: detailRouteIndex,
                    action: .seriesDetail(.coordinatorDismissTMDBMatchPicker(requestID: requestID))
                )))

            default:
                return .none
            }

        case let .detailSynopsisRouteDidDisappear(presentationID, parentRouteIndex, parent, requestID):
            let synopsisRouteIndex = state.routes.indices.last(where: { index in
                if case let .detailSynopsis(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID
                        && routeState.requestID == requestID
                        && routeState.parentRouteIndex == parentRouteIndex
                        && routeState.parent == parent
                }
                return false
            })
            if let synopsisRouteIndex {
                guard synopsisRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }
            return .none

        case let .detailActorBiographyRouteDidDisappear(presentationID, parentRouteIndex, itemID, requestID):
            let actorRouteIndex = state.routes.indices.last(where: { index in
                if case let .detailActorBiography(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID
                        && routeState.parentRouteIndex == parentRouteIndex
                        && routeState.itemID == itemID
                        && routeState.requestID == requestID
                }
                return false
            })
            if let actorRouteIndex {
                guard actorRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(parentRouteIndex),
                  case let .vodDetail(vodState) = state.routes[parentRouteIndex].screen,
                  vodState.vod.id == itemID,
                  vodState.actorBiographyPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: parentRouteIndex,
                action: .vodDetail(.coordinatorDismissActorBiography(requestID: requestID))
            )))

        case let .detailTrailerRouteDidDisappear(presentationID, parentRouteIndex, parent, requestID):
            let trailerRouteIndex = state.routes.indices.last(where: { index in
                if case let .detailTrailer(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID
                        && routeState.parentRouteIndex == parentRouteIndex
                        && routeState.parent == parent
                        && routeState.requestID == requestID
                }
                return false
            })
            if let trailerRouteIndex {
                guard trailerRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(parentRouteIndex) else { return .none }
            switch (parent, state.routes[parentRouteIndex].screen) {
            case let (.vod(itemID), .vodDetail(vodState))
                where vodState.vod.id == itemID && vodState.trailerPresentationRequestID == requestID:
                return .send(.router(.routeAction(
                    id: parentRouteIndex,
                    action: .vodDetail(.coordinatorDismissTrailer(requestID: requestID))
                )))

            case let (.series(itemID), .seriesDetail(seriesState))
                where seriesState.series.id == itemID && seriesState.trailerPresentationRequestID == requestID:
                return .send(.router(.routeAction(
                    id: parentRouteIndex,
                    action: .seriesDetail(.coordinatorDismissTrailer(requestID: requestID))
                )))

            default:
                return .none
            }

        case let .detailUnmatchedMovieRouteDidDisappear(presentationID, parentRouteIndex, itemID, requestID):
            let unmatchedMovieRouteIndex = state.routes.indices.last(where: { index in
                if case let .detailUnmatchedMovie(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID
                        && routeState.parentRouteIndex == parentRouteIndex
                        && routeState.itemID == itemID
                        && routeState.requestID == requestID
                }
                return false
            })
            if let unmatchedMovieRouteIndex {
                guard unmatchedMovieRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(parentRouteIndex),
                  case let .vodDetail(vodState) = state.routes[parentRouteIndex].screen,
                  vodState.vod.id == itemID,
                  vodState.unmatchedMoviePresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: parentRouteIndex,
                action: .vodDetail(.coordinatorDismissUnmatchedMovie(requestID: requestID))
            )))

        case let .customEPGSettingsRouteDidDisappear(presentationID, homeRouteIndex, requestID):
            let customEPGRouteIndex = state.routes.indices.last(where: { index in
                if case let .customEPGSettings(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let customEPGRouteIndex {
                guard customEPGRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.settings.customEPGPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.settings(.coordinatorDismissCustomEPGSettings(requestID: requestID)))
            )))

        case let .customEPGSourceAddRouteDidDisappear(presentationID, customEPGSettingsPresentationID, homeRouteIndex, requestID):
            let sourceAddRouteIndex = state.routes.indices.last(where: { index in
                if case let .customEPGSourceAdd(routeState) = state.routes[index].screen {
                    return routeState.presentationID == presentationID && routeState.requestID == requestID
                }
                return false
            })
            if let sourceAddRouteIndex {
                guard sourceAddRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard case let .customEPGSettings(customEPGState) = state.routes.last?.screen,
                  customEPGState.presentationID == customEPGSettingsPresentationID,
                  customEPGState.homeRouteIndex == homeRouteIndex,
                  state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.settings.customEPGPresentationRequestID == customEPGState.requestID,
                  homeState.settings.customEPGSourceAddPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: homeRouteIndex,
                action: .home(.settings(.coordinatorDismissCustomEPGSourceAdd(requestID: requestID)))
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

        case let .router(.routeAction(
            routeIndex,
            .playlistManagementSettings(.delegate(.close(presentationID, editRequestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .playlistManagementSettings(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.editRequestID == editRequestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.playlistManagementRouteIndex),
                  case let .playlistManagement(managementState) = state.routes[routeState.playlistManagementRouteIndex].screen,
                  managementState.playlistSettingsEditRequestID == editRequestID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.playlistManagementRouteIndex,
                action: .playlistManagement(.cancelPlaylistSettings)
            )))

        case let .router(.routeAction(
            routeIndex,
            .playlistManagementPIN(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .playlistManagementPIN(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID,
                  !routeState.isStartupUnlock
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.playlistManagementRouteIndex),
                  case let .playlistManagement(managementState) = state.routes[routeState.playlistManagementRouteIndex].screen,
                  managementState.pinPresentationRequestID == requestID,
                  managementState.pinFlow == routeState.flow
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.playlistManagementRouteIndex,
                action: .playlistManagement(.cancelPlaylistPIN)
            )))

        case let .router(.routeAction(
            routeIndex,
            .playlistManagementAddPlaylist(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .playlistManagementAddPlaylist(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.playlistManagementRouteIndex),
                  case let .playlistManagement(managementState) = state.routes[routeState.playlistManagementRouteIndex].screen,
                  managementState.addPlaylistPresentationRequestID == requestID,
                  managementState.addPlaylist != nil
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.playlistManagementRouteIndex,
                action: .playlistManagement(.closeAddPlaylistTapped(requestID: requestID))
            )))

        case let .router(.routeAction(
            routeIndex,
            .playerSpeedTest(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .playerSpeedTest(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.playerRouteIndex),
                  case let .player(playerState) = state.routes[routeState.playerRouteIndex].screen,
                  playerState.speedTestPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.playerRouteIndex,
                action: .player(.closeSpeedTest(requestID: requestID))
            )))

        case let .router(.routeAction(
            routeIndex,
            .playerSubtitleSearch(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .playerSubtitleSearch(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.playerRouteIndex),
                  case let .player(playerState) = state.routes[routeState.playerRouteIndex].screen,
                  playerState.subtitleSearchPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.playerRouteIndex,
                action: .player(.closeSubtitleSearch(requestID: requestID))
            )))

        case let .router(.routeAction(
            routeIndex,
            .settingsSpeedTest(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .settingsSpeedTest(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.homeRouteIndex),
                  case let .home(homeState) = state.routes[routeState.homeRouteIndex].screen,
                  homeState.settings.speedTestPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.homeRouteIndex,
                action: .home(.settings(.closeSpeedTest(requestID: requestID)))
            )))

        case let .router(.routeAction(
            routeIndex,
            .settingsPINSetup(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .settingsPINSetup(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.homeRouteIndex),
                  case let .home(homeState) = state.routes[routeState.homeRouteIndex].screen,
                  homeState.settings.pinSetupPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.homeRouteIndex,
                action: .home(.settings(.coordinatorDismissPINSetup(requestID: requestID)))
            )))

        case let .router(.routeAction(
            routeIndex,
            .settingsTraktAuth(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .settingsTraktAuth(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.homeRouteIndex),
                  case let .home(homeState) = state.routes[routeState.homeRouteIndex].screen,
                  homeState.settings.traktAuthPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.homeRouteIndex,
                action: .home(.settings(.coordinatorDismissTraktAuth(requestID: requestID)))
            )))

        case let .router(.routeAction(
            routeIndex,
            .settingsTraktWatchlist(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .settingsTraktWatchlist(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.homeRouteIndex),
                  case let .home(homeState) = state.routes[routeState.homeRouteIndex].screen,
                  homeState.settings.traktWatchlistPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.homeRouteIndex,
                action: .home(.settings(.coordinatorDismissTraktWatchlist(requestID: requestID)))
            )))

        case let .router(.routeAction(
            routeIndex,
            .settingsHiddenContent(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .settingsHiddenContent(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.homeRouteIndex),
                  case let .home(homeState) = state.routes[routeState.homeRouteIndex].screen,
                  homeState.settings.hiddenContentPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.homeRouteIndex,
                action: .home(.settings(.coordinatorDismissHiddenContentManagement(requestID: requestID)))
            )))

        case let .router(.routeAction(
            routeIndex,
            .settingsDiagnosticReport(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .settingsDiagnosticReport(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.homeRouteIndex),
                  case let .home(homeState) = state.routes[routeState.homeRouteIndex].screen,
                  homeState.settings.diagnosticReportPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.homeRouteIndex,
                action: .home(.settings(.coordinatorDismissDiagnosticReport(requestID: requestID)))
            )))

        case let .router(.routeAction(
            routeIndex,
            .settingsBackupPreview(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .settingsBackupPreview(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.homeRouteIndex),
                  case let .home(homeState) = state.routes[routeState.homeRouteIndex].screen,
                  homeState.settings.backupPreviewPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.homeRouteIndex,
                action: .home(.settings(.coordinatorDismissBackupPreview(requestID: requestID)))
            )))

        case let .router(.routeAction(
            routeIndex,
            .customEPGSettings(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .customEPGSettings(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.homeRouteIndex),
                  case let .home(homeState) = state.routes[routeState.homeRouteIndex].screen,
                  homeState.settings.customEPGPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.homeRouteIndex,
                action: .home(.settings(.coordinatorDismissCustomEPGSettings(requestID: requestID)))
            )))

        case let .router(.routeAction(
            routeIndex,
            .customEPGSourceAdd(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .customEPGSourceAdd(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard case let .customEPGSettings(customEPGState) = state.routes.last?.screen,
                  customEPGState.presentationID == routeState.customEPGSettingsPresentationID,
                  customEPGState.homeRouteIndex == routeState.homeRouteIndex,
                  state.routes.indices.contains(routeState.homeRouteIndex),
                  case let .home(homeState) = state.routes[routeState.homeRouteIndex].screen,
                  homeState.settings.customEPGPresentationRequestID == customEPGState.requestID,
                  homeState.settings.customEPGSourceAddPresentationRequestID == requestID
            else { return .none }
            return .send(.router(.routeAction(
                id: routeState.homeRouteIndex,
                action: .home(.settings(.coordinatorDismissCustomEPGSourceAdd(requestID: requestID)))
            )))

        case let .router(.routeAction(
            routeIndex,
            .detailTMDBMatchPicker(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .detailTMDBMatchPicker(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()

            guard state.routes.indices.contains(routeState.detailRouteIndex) else { return .none }
            switch (routeState.parent, state.routes[routeState.detailRouteIndex].screen) {
            case let (.vod(itemID), .vodDetail(vodState))
                where vodState.vod.id == itemID && vodState.tmdbMatchPresentationRequestID == requestID:
                return .send(.router(.routeAction(
                    id: routeState.detailRouteIndex,
                    action: .vodDetail(.coordinatorDismissTMDBMatchPicker(requestID: requestID))
                )))

            case let (.series(itemID), .seriesDetail(seriesState))
                where seriesState.series.id == itemID && seriesState.tmdbMatchPresentationRequestID == requestID:
                return .send(.router(.routeAction(
                    id: routeState.detailRouteIndex,
                    action: .seriesDetail(.coordinatorDismissTMDBMatchPicker(requestID: requestID))
                )))

            default:
                return .none
            }

        case let .router(.routeAction(
            routeIndex,
            .detailSynopsis(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .detailSynopsis(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            state.routes.dismiss()
            return .none

        case let .router(.routeAction(
            routeIndex,
            .detailActorBiography(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .detailActorBiography(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            return .send(.detailActorBiographyRouteDidDisappear(
                presentationID: presentationID,
                parentRouteIndex: routeState.parentRouteIndex,
                itemID: routeState.itemID,
                requestID: requestID
            ))

        case let .router(.routeAction(
            routeIndex,
            .detailTrailer(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .detailTrailer(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            return .send(.detailTrailerRouteDidDisappear(
                presentationID: presentationID,
                parentRouteIndex: routeState.parentRouteIndex,
                parent: routeState.parent,
                requestID: requestID
            ))

        case let .router(.routeAction(
            routeIndex,
            .detailUnmatchedMovie(.delegate(.close(presentationID, requestID)))
        )):
            guard state.routes.indices.contains(routeIndex),
                  routeIndex == state.routes.count - 1,
                  case let .detailUnmatchedMovie(routeState) = state.routes[routeIndex].screen,
                  routeState.presentationID == presentationID,
                  routeState.requestID == requestID
            else { return .none }
            return .send(.detailUnmatchedMovieRouteDidDisappear(
                presentationID: presentationID,
                parentRouteIndex: routeState.parentRouteIndex,
                itemID: routeState.itemID,
                requestID: requestID
            ))

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

        case let .router(.routeAction(categoryRouteIndex, .categoryManagement(.delegate(.categoriesUpdated)))):
            guard state.routes.indices.contains(categoryRouteIndex),
                  case let .categoryManagement(categoryState) = state.routes[categoryRouteIndex].screen
            else { return .none }

            switch categoryState.parent {
            case let .liveTV(homeRouteIndex):
                guard state.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = state.routes[homeRouteIndex].screen,
                      homeState.selectedTab == .liveTV,
                      homeState.liveTV.config == categoryState.config,
                      categoryState.type == .live
                else { return .none }
                return .send(.router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.liveTV(.categoryPreferencesUpdated))
                )))

            case let .vod(homeRouteIndex):
                guard state.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = state.routes[homeRouteIndex].screen,
                      homeState.selectedTab == .movies,
                      homeState.vod.config == categoryState.config,
                      categoryState.type == .vod
                else { return .none }
                return .send(.router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.vod(.reloadPreferences))
                )))

            case let .series(homeRouteIndex):
                guard state.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = state.routes[homeRouteIndex].screen,
                      homeState.selectedTab == .series,
                      homeState.series.config == categoryState.config,
                      categoryState.type == .series
                else { return .none }
                return .send(.router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.series(.reloadPreferences))
                )))

            case nil:
                return forwardLiveTVAction(.categoryPreferencesUpdated, state: state)
            }

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
            switch parentalLockState.parent {
            case let .vod(homeRouteIndex, config):
                guard state.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = state.routes[homeRouteIndex].screen,
                      homeState.selectedTab == .movies,
                      homeState.vod.config == config
                else { return .none }
                return .send(.router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.vod(.coordinatorParentalLockUnlocked(category: category, item: item)))
                )))

            case let .series(homeRouteIndex, config):
                guard state.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = state.routes[homeRouteIndex].screen,
                      homeState.selectedTab == .series,
                      homeState.series.config == config
                else { return .none }
                return .send(.router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.series(.coordinatorParentalLockUnlocked(category: category, item: item)))
                )))

            case nil:
                return forwardLiveTVAction(.parentalLockUnlocked(category: category, item: item), state: state)
            }

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
        case let .router(.routeAction(homeRouteIndex, .home(.delegate(.presentSearch)))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen
            else { return .none }
            state.routes.presentCover(.globalSearch(GlobalSearchRouteFeature.State(
                homeRouteIndex: homeRouteIndex,
                config: homeState.config
            )))
            return .none

        case let .router(.routeAction(searchRouteIndex, .globalSearch(.delegate(.close(presentationID))))):
            guard state.routes.indices.contains(searchRouteIndex),
                  searchRouteIndex == state.routes.count - 1,
                  case let .globalSearch(searchState) = state.routes[searchRouteIndex].screen,
                  searchState.presentationID == presentationID
            else { return .none }
            state.routes.dismiss()
            return .none

        case let .router(.routeAction(searchRouteIndex, .globalSearch(.delegate(.didSelectChannel(channel, playlist))))):
            guard state.routes.indices.contains(searchRouteIndex),
                  searchRouteIndex == state.routes.count - 1,
                  case let .globalSearch(searchState) = state.routes[searchRouteIndex].screen,
                  state.routes.indices.contains(searchState.homeRouteIndex),
                  case .home = state.routes[searchState.homeRouteIndex].screen
            else { return .none }
            state.routes.dismiss()
            return .send(.router(.routeAction(
                searchState.homeRouteIndex,
                .home(.delegate(.didSelectChannel(channel, playlist: playlist)))
            )))

        case let .router(.routeAction(searchRouteIndex, .globalSearch(.delegate(.didSelectVOD(vod))))):
            guard state.routes.indices.contains(searchRouteIndex),
                  searchRouteIndex == state.routes.count - 1,
                  case let .globalSearch(searchState) = state.routes[searchRouteIndex].screen,
                  state.routes.indices.contains(searchState.homeRouteIndex),
                  case .home = state.routes[searchState.homeRouteIndex].screen
            else { return .none }
            state.routes.dismiss()
            return .send(.router(.routeAction(
                searchState.homeRouteIndex,
                .home(.delegate(.didSelectVOD(vod)))
            )))

        case let .router(.routeAction(searchRouteIndex, .globalSearch(.delegate(.didSelectSeries(series))))):
            guard state.routes.indices.contains(searchRouteIndex),
                  searchRouteIndex == state.routes.count - 1,
                  case let .globalSearch(searchState) = state.routes[searchRouteIndex].screen,
                  state.routes.indices.contains(searchState.homeRouteIndex),
                  case .home = state.routes[searchState.homeRouteIndex].screen
            else { return .none }
            state.routes.dismiss()
            return .send(.router(.routeAction(
                searchState.homeRouteIndex,
                .home(.delegate(.didSelectSeries(series)))
            )))

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

        case let .router(.routeAction(homeRouteIndex, .home(.settings(.delegate(.presentSpeedTest(requestID)))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .settings,
                  homeState.settings.speedTestPresentationRequestID == requestID
            else { return .none }
            state.routes.presentSheet(.settingsSpeedTest(
                SettingsSpeedTestRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    requestID: requestID
                )
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.settings(.delegate(.presentPINSetup(requestID)))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .settings,
                  homeState.settings.pinSetupPresentationRequestID == requestID,
                  homeState.settings.isShowingPINSetup
            else { return .none }
            state.routes.presentSheet(.settingsPINSetup(
                SettingsPINSetupRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    requestID: requestID
                )
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.settings(.delegate(.presentTraktAuth(requestID)))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .settings,
                  homeState.settings.traktAuthPresentationRequestID == requestID,
                  homeState.settings.isTraktAuthSheetPresented
            else { return .none }
            state.routes.presentSheet(.settingsTraktAuth(
                SettingsTraktAuthRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    requestID: requestID
                )
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.settings(.delegate(.presentTraktWatchlist(requestID)))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .settings,
                  homeState.settings.traktWatchlistPresentationRequestID == requestID,
                  homeState.settings.isTraktWatchlistPresented
            else { return .none }
            state.routes.presentSheet(.settingsTraktWatchlist(
                SettingsTraktWatchlistRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    requestID: requestID
                )
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.settings(.delegate(.presentHiddenContentManagement(requestID)))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .settings,
                  homeState.settings.hiddenContentPresentationRequestID == requestID,
                  homeState.settings.isShowingHiddenContentSheet
            else { return .none }
            state.routes.presentSheet(.settingsHiddenContent(
                SettingsHiddenContentRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    requestID: requestID
                )
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.settings(.delegate(.presentDiagnosticReport(requestID)))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.settings.diagnosticReportPresentationRequestID == requestID,
                  let url = homeState.settings.diagnosticReportURL
            else { return .none }
            guard homeRouteIndex == state.routes.count - 1,
                  homeState.selectedTab == .settings
            else {
                return .send(.router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.settings(.coordinatorDismissDiagnosticReport(requestID: requestID)))
                )))
            }
            state.routes.presentSheet(.settingsDiagnosticReport(
                SettingsDiagnosticReportRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    requestID: requestID,
                    url: url
                )
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.settings(.delegate(.presentBackupPreview(requestID)))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.settings.backupPreviewPresentationRequestID == requestID,
                  homeState.settings.backupPreview != nil,
                  homeState.settings.pendingBackupURL != nil
            else { return .none }
            guard homeRouteIndex == state.routes.count - 1,
                  homeState.selectedTab == .settings
            else {
                return .send(.router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.settings(.coordinatorDismissBackupPreview(requestID: requestID)))
                )))
            }
            state.routes.presentSheet(.settingsBackupPreview(
                SettingsBackupPreviewRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    requestID: requestID
                )
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.settings(.delegate(.presentCustomEPGSettings(requestID)))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .settings,
                  homeState.settings.customEPGPresentationRequestID == requestID,
                  homeState.settings.isCustomEPGSheetPresented
            else { return .none }
            state.routes.presentSheet(.customEPGSettings(
                CustomEPGSettingsRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    requestID: requestID
                )
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.settings(.delegate(.presentCustomEPGSourceAdd(requestID)))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  case let .customEPGSettings(customEPGState) = state.routes.last?.screen,
                  customEPGState.homeRouteIndex == homeRouteIndex,
                  homeState.settings.customEPGPresentationRequestID == customEPGState.requestID,
                  homeState.settings.isCustomEPGSheetPresented,
                  homeState.settings.customEPGSourceAddPresentationRequestID == requestID,
                  homeState.settings.isAddCustomEPGSourceSheetPresented
            else { return .none }
            state.routes.presentSheet(.customEPGSourceAdd(
                CustomEPGSourceAddRouteFeature.State(
                    customEPGSettingsPresentationID: customEPGState.presentationID,
                    homeRouteIndex: homeRouteIndex,
                    requestID: requestID
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

        case let .router(.routeAction(homeRouteIndex, .home(.delegate(.presentCategoryManagement(categoryState))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .liveTV,
                  homeState.liveTV.config == categoryState.config,
                  categoryState.type == .live
            else { return .none }
            var categoryState = categoryState
            categoryState.parent = .liveTV(routeIndex: homeRouteIndex)
            state.routes.presentSheet(.categoryManagement(categoryState))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.delegate(.presentVODCategoryManagement(categoryState))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .movies,
                  homeState.vod.config == categoryState.config,
                  categoryState.type == .vod
            else { return .none }
            var categoryState = categoryState
            categoryState.parent = .vod(routeIndex: homeRouteIndex)
            state.routes.presentSheet(.categoryManagement(categoryState))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.delegate(.presentSeriesCategoryManagement(categoryState))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .series,
                  homeState.series.config == categoryState.config,
                  categoryState.type == .series
            else { return .none }
            var categoryState = categoryState
            categoryState.parent = .series(routeIndex: homeRouteIndex)
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

        case let .router(.routeAction(
            homeRouteIndex,
            .home(.delegate(.presentVODParentalLock(parentalLockState, closeVODDetailsOnExpiry)))
        )):
            guard state.routes.indices.contains(homeRouteIndex),
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .movies,
                  let config = homeState.vod.config,
                  parentalLockState.pendingCategory != nil,
                  parentalLockState.isCoordinatorRoute
            else { return .none }

            let categoryID = parentalLockState.pendingCategory?.id
            let hasMatchingVODDetail = state.routes.indices.contains { routeIndex in
                guard routeIndex > homeRouteIndex,
                      case let .vodDetail(detailState) = state.routes[routeIndex].screen
                else { return false }
                return detailState.config == config && detailState.vod.categoryID == categoryID
            }
            let homeIsTopRoute = homeRouteIndex == state.routes.count - 1
            guard homeIsTopRoute || (closeVODDetailsOnExpiry && hasMatchingVODDetail) else { return .none }

            if closeVODDetailsOnExpiry, hasMatchingVODDetail {
                while state.routes.count - 1 > homeRouteIndex {
                    state.routes.dismiss()
                }
            }

            var parentalLockState = parentalLockState
            parentalLockState.parent = .vod(routeIndex: homeRouteIndex, config: config)
            state.routes.presentSheet(.parentalLock(parentalLockState))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.delegate(.presentSeriesParentalLock(parentalLockState))))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .series,
                  let config = homeState.series.config,
                  parentalLockState.pendingCategory != nil,
                  parentalLockState.isCoordinatorRoute
            else { return .none }
            var parentalLockState = parentalLockState
            parentalLockState.parent = .series(routeIndex: homeRouteIndex, config: config)
            state.routes.presentSheet(.parentalLock(parentalLockState))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.delegate(.presentSmartGroupManager)))):
            guard state.routes.indices.contains(homeRouteIndex),
                  case .home = state.routes[homeRouteIndex].screen
            else { return .none }
            state.routes.presentSheet(.smartChannelGroupManagement(
                SmartChannelGroupManagementRouteFeature.State(homeRouteIndex: homeRouteIndex)
            ))
            return .none

        case let .router(.routeAction(homeRouteIndex, .home(.delegate(.presentFavoriteListManagement)))):
            guard state.routes.indices.contains(homeRouteIndex),
                  homeRouteIndex == state.routes.count - 1,
                  case let .home(homeState) = state.routes[homeRouteIndex].screen,
                  homeState.selectedTab == .liveTV,
                  homeState.liveTV.config == homeState.config
            else { return .none }
            state.routes.presentSheet(.favoriteChannelListManagement(
                FavoriteChannelListManagementRouteFeature.State(
                    homeRouteIndex: homeRouteIndex,
                    homeConfig: homeState.config
                )
            ))
            return .none

        case let .router(.routeAction(
            playlistManagementRouteIndex,
            .playlistManagement(.delegate(.presentAddPlaylistQRTransfer(requestID)))
        )):
            guard state.routes.indices.contains(playlistManagementRouteIndex),
                  case let .playlistManagement(managementState) = state.routes[playlistManagementRouteIndex].screen,
                  managementState.addPlaylistPresentationRequestID == requestID,
                  managementState.addPlaylist != nil,
                  managementState.startupUnlockPlaylistID == nil,
                  let addPlaylistRouteIndex = state.routes.indices.last(where: { routeIndex in
                      guard routeIndex > playlistManagementRouteIndex,
                            case let .playlistManagementAddPlaylist(routeState) = state.routes[routeIndex].screen
                      else { return false }
                      return routeState.playlistManagementRouteIndex == playlistManagementRouteIndex
                          && routeState.requestID == requestID
                  }),
                  addPlaylistRouteIndex == state.routes.count - 1,
                  case let .playlistManagementAddPlaylist(addPlaylistRouteState) = state.routes[addPlaylistRouteIndex].screen
            else { return .none }
            state.routes.presentSheet(.addPlaylistQRTransfer(
                AddPlaylistQRTransferRouteFeature.State(
                    parent: .playlistManagementAddPlaylistRoute(
                        routeIndex: addPlaylistRouteIndex,
                        presentationID: addPlaylistRouteState.presentationID,
                        requestID: requestID
                    )
                )
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

        case let .presentDetailSynopsis(parent, text):
            let parentRouteIndex = state.routes.indices.last(where: { index in
                switch (parent, state.routes[index].screen) {
                case let (.vod(itemID), .vodDetail(vodState)):
                    return vodState.vod.id == itemID
                case let (.series(itemID), .seriesDetail(seriesState)):
                    return seriesState.series.id == itemID
                default:
                    return false
                }
            })
            guard let parentRouteIndex, parentRouteIndex == state.routes.count - 1 else { return .none }
            state.routes.presentSheet(.detailSynopsis(
                DetailSynopsisRouteFeature.State(
                    parentRouteIndex: parentRouteIndex,
                    parent: parent,
                    text: text
                )
            ))
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

        case let .router(.routeAction(
            detailRouteIndex,
            .seriesDetail(.delegate(.presentTMDBMatchPicker(requestID)))
        )):
            guard state.routes.indices.contains(detailRouteIndex),
                  detailRouteIndex == state.routes.count - 1,
                  case let .seriesDetail(seriesState) = state.routes[detailRouteIndex].screen,
                  seriesState.tmdbMatchPresentationRequestID == requestID,
                  seriesState.isTMDBMatchPickerPresented
            else { return .none }
            state.routes.presentSheet(.detailTMDBMatchPicker(
                DetailTMDBMatchPickerRouteFeature.State(
                    detailRouteIndex: detailRouteIndex,
                    parent: .series(itemID: seriesState.series.id),
                    requestID: requestID
                )
            ))
            return .none

        case let .router(.routeAction(
            detailRouteIndex,
            .seriesDetail(.delegate(.presentTrailer(requestID)))
        )):
            guard state.routes.indices.contains(detailRouteIndex),
                  detailRouteIndex == state.routes.count - 1,
                  case let .seriesDetail(seriesState) = state.routes[detailRouteIndex].screen,
                  seriesState.trailerPresentationRequestID == requestID,
                  seriesState.isTrailerPresented,
                  seriesState.trailerVideoKey != nil,
                  !state.routes.contains(where: { route in
                      if case let .detailTrailer(routeState) = route.screen {
                          return routeState.requestID == requestID
                      }
                      return false
                  })
            else { return .none }
            state.routes.presentSheet(.detailTrailer(
                DetailTrailerRouteFeature.State(
                    parentRouteIndex: detailRouteIndex,
                    parent: .series(itemID: seriesState.series.id),
                    requestID: requestID
                )
            ))
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

        case let .router(.routeAction(
            detailRouteIndex,
            .vodDetail(.delegate(.presentTMDBMatchPicker(requestID)))
        )):
            guard state.routes.indices.contains(detailRouteIndex),
                  detailRouteIndex == state.routes.count - 1,
                  case let .vodDetail(vodState) = state.routes[detailRouteIndex].screen,
                  vodState.tmdbMatchPresentationRequestID == requestID,
                  vodState.isTMDBMatchPickerPresented
            else { return .none }
            state.routes.presentSheet(.detailTMDBMatchPicker(
                DetailTMDBMatchPickerRouteFeature.State(
                    detailRouteIndex: detailRouteIndex,
                    parent: .vod(itemID: vodState.vod.id),
                    requestID: requestID
                )
            ))
            return .none

        case let .router(.routeAction(
            detailRouteIndex,
            .vodDetail(.delegate(.presentActorBiography(requestID)))
        )):
            guard state.routes.indices.contains(detailRouteIndex),
                  detailRouteIndex == state.routes.count - 1,
                  case let .vodDetail(vodState) = state.routes[detailRouteIndex].screen,
                  vodState.actorBiographyPresentationRequestID == requestID,
                  vodState.selectedActor != nil,
                  !state.routes.contains(where: { route in
                      if case let .detailActorBiography(routeState) = route.screen {
                          return routeState.requestID == requestID
                      }
                      return false
                  })
            else { return .none }
            state.routes.presentSheet(.detailActorBiography(
                DetailActorBiographyRouteFeature.State(
                    parentRouteIndex: detailRouteIndex,
                    itemID: vodState.vod.id,
                    requestID: requestID
                )
            ))
            return .none

        case let .router(.routeAction(
            detailRouteIndex,
            .vodDetail(.delegate(.presentTrailer(requestID)))
        )):
            guard state.routes.indices.contains(detailRouteIndex),
                  detailRouteIndex == state.routes.count - 1,
                  case let .vodDetail(vodState) = state.routes[detailRouteIndex].screen,
                  vodState.trailerPresentationRequestID == requestID,
                  vodState.isTrailerPresented,
                  vodState.trailerVideoKey != nil,
                  !state.routes.contains(where: { route in
                      if case let .detailTrailer(routeState) = route.screen {
                          return routeState.requestID == requestID
                      }
                      return false
                  })
            else { return .none }
            state.routes.presentSheet(.detailTrailer(
                DetailTrailerRouteFeature.State(
                    parentRouteIndex: detailRouteIndex,
                    parent: .vod(itemID: vodState.vod.id),
                    requestID: requestID
                )
            ))
            return .none

        case let .router(.routeAction(
            detailRouteIndex,
            .vodDetail(.delegate(.presentUnmatchedMovie(requestID)))
        )):
            guard state.routes.indices.contains(detailRouteIndex),
                  detailRouteIndex == state.routes.count - 1,
                  case let .vodDetail(vodState) = state.routes[detailRouteIndex].screen,
                  vodState.unmatchedMoviePresentationRequestID == requestID,
                  vodState.selectedUnmatchedMovie != nil,
                  !state.routes.contains(where: { route in
                      if case let .detailUnmatchedMovie(routeState) = route.screen {
                          return routeState.requestID == requestID
                      }
                      return false
                  })
            else { return .none }
            state.routes.presentSheet(.detailUnmatchedMovie(
                DetailUnmatchedMovieRouteFeature.State(
                    parentRouteIndex: detailRouteIndex,
                    itemID: vodState.vod.id,
                    requestID: requestID
                )
            ))
            return .none

        case .router(.routeAction(_, .vodDetail(.delegate(.close)))):
            if case .vodDetail = state.routes.last?.screen {
                state.routes.goBack()
            }
            return .none

        // ── Playlist Management Delegates ────────────────────────
        case let .router(.routeAction(
            playlistManagementRouteIndex,
            .playlistManagement(.delegate(.presentPlaylistPIN(requestID, flow)))
        )):
            guard state.routes.indices.contains(playlistManagementRouteIndex),
                  playlistManagementRouteIndex == state.routes.count - 1,
                  case let .playlistManagement(managementState) = state.routes[playlistManagementRouteIndex].screen,
                  managementState.pinPresentationRequestID == requestID,
                  managementState.pinFlow == flow
            else { return .none }
            state.routes.presentSheet(.playlistManagementPIN(
                PlaylistManagementPINRouteFeature.State(
                    playlistManagementRouteIndex: playlistManagementRouteIndex,
                    requestID: requestID,
                    flow: flow
                )
            ))
            return .none

        case let .router(.routeAction(
            playlistManagementRouteIndex,
            .playlistManagement(.delegate(.presentPlaylistSettings(requestID, playlistID)))
        )):
            guard state.routes.indices.contains(playlistManagementRouteIndex),
                  playlistManagementRouteIndex == state.routes.count - 1,
                  case let .playlistManagement(managementState) = state.routes[playlistManagementRouteIndex].screen,
                  managementState.playlistSettingsEditRequestID == requestID,
                  managementState.playlistBeingEdited?.id == playlistID
            else { return .none }
            state.routes.presentSheet(.playlistManagementSettings(
                PlaylistManagementSettingsRouteFeature.State(
                    playlistManagementRouteIndex: playlistManagementRouteIndex,
                    editRequestID: requestID,
                    playlistID: playlistID
                )
            ))
            return .none

        case let .router(.routeAction(
            playlistManagementRouteIndex,
            .playlistManagement(.delegate(.presentAddPlaylist(requestID)))
        )):
            guard state.routes.indices.contains(playlistManagementRouteIndex),
                  playlistManagementRouteIndex == state.routes.count - 1,
                  case let .playlistManagement(managementState) = state.routes[playlistManagementRouteIndex].screen,
                  managementState.addPlaylistPresentationRequestID == requestID,
                  managementState.addPlaylist != nil,
                  managementState.startupUnlockPlaylistID == nil
            else { return .none }
            state.routes.presentSheet(.playlistManagementAddPlaylist(
                PlaylistManagementAddPlaylistRouteFeature.State(
                    playlistManagementRouteIndex: playlistManagementRouteIndex,
                    requestID: requestID
                )
            ))
            return .none

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
        case let .router(.routeAction(playerRouteIndex, .player(.delegate(.presentSpeedTest(requestID))))):
            guard state.routes.indices.contains(playerRouteIndex),
                  playerRouteIndex == state.routes.count - 1,
                  case let .player(playerState) = state.routes[playerRouteIndex].screen,
                  playerState.speedTestPresentationRequestID == requestID,
                  !playerState.isMinimized,
                  !playerState.isClosing
            else { return .none }
            state.routes.presentSheet(.playerSpeedTest(
                PlayerSpeedTestRouteFeature.State(
                    playerRouteIndex: playerRouteIndex,
                    requestID: requestID,
                    itemID: playerState.item.id,
                    playbackRequestID: playerState.playbackRequestID
                )
            ))
            return .none

        case let .router(.routeAction(playerRouteIndex, .player(.delegate(.presentSubtitleSearch(requestID))))):
            guard state.routes.indices.contains(playerRouteIndex),
                  playerRouteIndex == state.routes.count - 1,
                  case let .player(playerState) = state.routes[playerRouteIndex].screen,
                  playerState.subtitleSearchPresentationRequestID == requestID,
                  playerState.item.isLive == false,
                  playerState.playbackEngine == .vlc,
                  !playerState.isMinimized,
                  !playerState.isClosing
            else { return .none }
            state.routes.presentSheet(.playerSubtitleSearch(
                PlayerSubtitleSearchRouteFeature.State(
                    playerRouteIndex: playerRouteIndex,
                    requestID: requestID,
                    itemID: playerState.item.id,
                    playbackRequestID: playerState.playbackRequestID,
                    itemTitle: [playerState.item.seriesTitle, playerState.item.title]
                        .compactMap(\.self)
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                )
            ))
            return .none

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

        case let .router(.routeAction(playerRouteIndex, .player(.delegate(.didClose)))):
            state.miniPlayer = nil
            state.isPlayerMini = false
            let playerOverlayRouteIndex: Int?
            switch state.routes.last?.screen {
            case let .some(.playerSpeedTest(routeState)):
                playerOverlayRouteIndex = routeState.playerRouteIndex
            case let .some(.playerSubtitleSearch(routeState)):
                playerOverlayRouteIndex = routeState.playerRouteIndex
            default:
                playerOverlayRouteIndex = nil
            }
            if playerOverlayRouteIndex == playerRouteIndex,
               state.routes.indices.contains(playerRouteIndex),
               case .player = state.routes[playerRouteIndex].screen
            {
                state.routes.dismiss()
                if case .player = state.routes.last?.screen {
                    state.routes.dismiss()
                }
            } else if playerRouteIndex == state.routes.count - 1,
                      state.routes.indices.contains(playerRouteIndex),
                      case .player = state.routes[playerRouteIndex].screen
            {
                state.routes.dismiss()
            }
            return .none

        case let .router(.routeAction(playerRouteIndex, .player(.delegate(.didRequestMinimize)))):
            guard state.routes.indices.contains(playerRouteIndex),
                  case let .player(playerState) = state.routes[playerRouteIndex].screen
            else { return .none }
            var miniPlayerState = playerState
            miniPlayerState.speedTestPresentationRequestID = nil
            miniPlayerState.subtitleSearchPresentationRequestID = nil
            state.miniPlayer = miniPlayerState
            state.isPlayerMini = true
            let playerOverlayRouteIndex: Int?
            switch state.routes.last?.screen {
            case let .some(.playerSpeedTest(routeState)):
                playerOverlayRouteIndex = routeState.playerRouteIndex
            case let .some(.playerSubtitleSearch(routeState)):
                playerOverlayRouteIndex = routeState.playerRouteIndex
            default:
                playerOverlayRouteIndex = nil
            }
            if playerOverlayRouteIndex == playerRouteIndex {
                state.routes.dismiss()
            }
            guard playerRouteIndex == state.routes.count - 1,
                  case .player = state.routes[playerRouteIndex].screen
            else { return .none }
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

        case let .epgTimelineProgramDetailRouteDidDisappear(
            presentationID,
            timelineRouteIndex,
            timelinePresentationID,
            detailRequestID
        ):
            if let detailRouteIndex = state.routes.indices.last(where: { index in
                guard case let .epgTimelineProgramDetail(detailState) = state.routes[index].screen else { return false }
                return detailState.presentationID == presentationID
            }) {
                guard detailRouteIndex == state.routes.count - 1 else { return .none }
                state.routes.dismiss()
            }

            guard state.routes.indices.contains(timelineRouteIndex),
                  case let .epgTimeline(timelineState) = state.routes[timelineRouteIndex].screen,
                  timelineState.presentationID == timelinePresentationID,
                  timelineState.selectedProgramDetailRequestID == detailRequestID
            else { return .none }
            return .send(.router(.routeAction(
                id: timelineRouteIndex,
                action: .epgTimeline(.dismissProgramDetailsIfCurrent(detailRequestID))
            )))

        case let .epgTimelineChannelLogoEditorRouteDidDisappear(presentationID):
            if let routeIndex = state.routes.indices.last(where: { index in
                guard case let .epgTimelineChannelLogoEditor(routeState) = state.routes[index].screen else { return false }
                return routeState.presentationID == presentationID
            }), routeIndex == state.routes.count - 1 {
                state.routes.dismiss()
            }
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
                let presentationID = UUID()
                if let previous = state.playlistTransferPairing, previous.sessionID != sessionID {
                    PlaylistQRTransferManager.shared.endSession(previous.sessionID)
                }
                state.playlistTransferPresentationID = presentationID
                state.playlistTransferPairing = pairing
                state.playlistTransferPlaylists = []
                state.playlistTransferSelectedID = nil
                state.isLoadingPlaylistTransfer = true
                state.isSubmittingPlaylistTransfer = false
                state.playlistTransferError = nil
                #if os(iOS)
                    state.routes.presentSheet(.playlistQRTransferConfirmation(
                        PlaylistQRTransferConfirmationRouteFeature.State(
                            sessionID: sessionID,
                            presentationID: presentationID
                        )
                    ))
                #endif
                return .merge(
                    .cancel(id: CancelID.playlistTransferLoad),
                    .cancel(id: CancelID.playlistTransferSubmission),
                    .run { send in
                        for _ in 0 ..< 15 {
                            guard !Task.isCancelled else { return }
                            if let playlists = PlaylistQRTransferManager.shared.availablePlaylists(for: pairing) {
                                await send(.playlistTransferPlaylistsLoaded(
                                    sessionID: sessionID,
                                    presentationID: presentationID,
                                    playlists: playlists
                                ))
                                return
                            }
                            try? await Task.sleep(for: .seconds(1))
                        }
                        guard !Task.isCancelled else { return }
                        await send(.playlistTransferPlaylistsLoaded(
                            sessionID: sessionID,
                            presentationID: presentationID,
                            playlists: nil
                        ))
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

        case let .selectPlaylistForTransfer(sessionID, presentationID, playlistID):
            guard state.playlistTransferPresentationID == presentationID,
                  state.playlistTransferPairing?.sessionID == sessionID,
                  state.playlistTransferPlaylists.contains(where: { $0.id == playlistID })
            else { return .none }
            state.playlistTransferSelectedID = playlistID
            return .none

        case let .playlistTransferPlaylistsLoaded(sessionID, presentationID, playlists):
            guard state.playlistTransferPresentationID == presentationID,
                  state.playlistTransferPairing?.sessionID == sessionID
            else { return .none }
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

        case let .confirmPlaylistTransfer(sessionID, presentationID):
            guard state.playlistTransferPresentationID == presentationID,
                  let pairing = state.playlistTransferPairing,
                  pairing.sessionID == sessionID,
                  let playlistID = state.playlistTransferSelectedID,
                  state.playlistTransferPlaylists.contains(where: { $0.id == playlistID }),
                  !state.isSubmittingPlaylistTransfer
            else { return .none }
            state.isSubmittingPlaylistTransfer = true
            state.playlistTransferError = nil
            return .run { send in
                let succeeded = (try? PlaylistQRTransferManager.shared.submit(playlistID: playlistID, for: pairing)) != nil
                await send(.playlistTransferSubmissionResponse(
                    sessionID: pairing.sessionID,
                    presentationID: presentationID,
                    succeeded: succeeded
                ))
            }
            .cancellable(id: CancelID.playlistTransferSubmission, cancelInFlight: true)

        case let .playlistTransferSubmissionResponse(sessionID, presentationID, succeeded):
            guard state.playlistTransferPresentationID == presentationID,
                  state.playlistTransferPairing?.sessionID == sessionID
            else { return .none }
            state.isSubmittingPlaylistTransfer = false
            if succeeded {
                if case let .playlistQRTransferConfirmation(routeState) = state.routes.last?.screen,
                   routeState.presentationID == presentationID,
                   routeState.sessionID == sessionID
                {
                    state.routes.dismiss()
                }
                state.playlistTransferPairing = nil
                state.playlistTransferPresentationID = nil
                state.playlistTransferPlaylists = []
                state.playlistTransferSelectedID = nil
            } else {
                state.playlistTransferError = "Oturum süresi dolmuş olabilir. Apple TV’de yeni bir QR kod oluşturun."
            }
            return .none

        case let .cancelPlaylistTransfer(sessionID, presentationID):
            guard state.playlistTransferPresentationID == presentationID,
                  state.playlistTransferPairing?.sessionID == sessionID
            else { return .none }
            PlaylistQRTransferManager.shared.endSession(sessionID)
            state.playlistTransferPairing = nil
            state.playlistTransferPresentationID = nil
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
    // Alert buttons act on the context currently presented before SwiftUI clears the binding.
    @State private var rootAlertButtonActionContext: RootAlertContext?
    @State private var confirmationDialogButtonActionPending = false

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
            case let .profileAddProfile(screenStore):
                ProfileAddProfileRouteView(coordinatorStore: store, routeStore: screenStore)
            case let .home(store):
                HomeView(store: store)
            case let .globalSearch(screenStore):
                GlobalSearchRouteView(routeStore: screenStore)
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
            case let .epgTimelineProgramDetail(screenStore):
                EPGTimelineProgramDetailRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .epgTimelineChannelLogoEditor(screenStore):
                EPGTimelineChannelLogoEditorRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
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
            case let .addPlaylistQRTransfer(screenStore):
                #if os(tvOS)
                    AddPlaylistQRTransferRouteView(
                        coordinatorStore: store,
                        routeStore: screenStore
                    )
                #else
                    EmptyView()
                #endif
            case let .playlistQRTransferConfirmation(screenStore):
                #if os(iOS)
                    PlaylistQRTransferConfirmationRouteView(
                        coordinatorStore: store,
                        routeStore: screenStore
                    )
                #else
                    EmptyView()
                #endif
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
            case let .favoriteChannelListManagement(screenStore):
                FavoriteChannelListManagementRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .channelPresentationEditor(screenStore):
                ChannelPresentationEditorRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .seriesDetail(detailStore):
                SeriesDetailView(store: detailStore) { text in
                    store.send(.presentDetailSynopsis(
                        parent: .series(itemID: detailStore.series.id),
                        text: text
                    ))
                }
            case let .vodDetail(detailStore):
                VODDetailView(store: detailStore) { text in
                    store.send(.presentDetailSynopsis(
                        parent: .vod(itemID: detailStore.vod.id),
                        text: text
                    ))
                }
            case let .playlistManagementSettings(screenStore):
                PlaylistManagementSettingsRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .playlistManagementPIN(screenStore):
                PlaylistManagementPINRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .playlistManagementAddPlaylist(screenStore):
                PlaylistManagementAddPlaylistRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .playerSpeedTest(screenStore):
                PlayerSpeedTestRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .playerSubtitleSearch(screenStore):
                PlayerSubtitleSearchRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .settingsSpeedTest(screenStore):
                SettingsSpeedTestRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .settingsPINSetup(screenStore):
                SettingsPINSetupRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .settingsTraktAuth(screenStore):
                SettingsTraktAuthRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .settingsTraktWatchlist(screenStore):
                SettingsTraktWatchlistRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .settingsHiddenContent(screenStore):
                SettingsHiddenContentRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .settingsDiagnosticReport(screenStore):
                SettingsDiagnosticReportRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .settingsBackupPreview(screenStore):
                SettingsBackupPreviewRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .detailSynopsis(screenStore):
                DetailSynopsisRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .detailActorBiography(screenStore):
                DetailActorBiographyRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .detailTrailer(screenStore):
                DetailTrailerRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .detailUnmatchedMovie(screenStore):
                DetailUnmatchedMovieRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .detailTMDBMatchPicker(screenStore):
                DetailTMDBMatchPickerRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .customEPGSettings(screenStore):
                CustomEPGSettingsRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .customEPGSourceAdd(screenStore):
                CustomEPGSourceAddRouteView(
                    coordinatorStore: store,
                    routeStore: screenStore
                )
            case let .playlistManagement(store):
                PlaylistManagementView(store: store)
            case let .paywall(store):
                PaywallView(store: store)
            }
        }
        .useNavigationStack(.whenAvailable)
        .alert(
            rootAlertContext?.title ?? "",
            isPresented: rootAlertIsPresented
        ) {
            switch rootAlertContext {
            case .streamHandoff:
                Button("OK", role: .cancel) {
                    performRootAlertButtonAction(for: .streamHandoff) {
                        store.send(.dismissStreamHandoffError)
                    }
                }
            case let .rememberedPlaybackChoice(routeIndex, reminder):
                Button(AppStrings.Player.useRememberedPlaybackChoice(reminder.choice.title)) {
                    performRootAlertButtonAction(
                        for: .rememberedPlaybackChoice(routeIndex: routeIndex, reminder: reminder)
                    ) {
                        sendRememberedPlaybackChoiceAction(
                            .applyRememberedPlaybackChoice,
                            routeIndex: routeIndex,
                            reminder: reminder
                        )
                    }
                }
                Button(AppStrings.Player.forgetRememberedPlaybackChoice, role: .destructive) {
                    performRootAlertButtonAction(
                        for: .rememberedPlaybackChoice(routeIndex: routeIndex, reminder: reminder)
                    ) {
                        sendRememberedPlaybackChoiceAction(
                            .forgetRememberedPlaybackChoice,
                            routeIndex: routeIndex,
                            reminder: reminder
                        )
                    }
                }
                Button(AppStrings.Common.cancel, role: .cancel) {
                    performRootAlertButtonAction(
                        for: .rememberedPlaybackChoice(routeIndex: routeIndex, reminder: reminder)
                    ) {
                        sendRememberedPlaybackChoiceAction(
                            .dismissRememberedPlaybackChoice,
                            routeIndex: routeIndex,
                            reminder: reminder
                        )
                    }
                }
            case let .clearCacheConfirmation(routeIndex):
                Button(AppStrings.Settings.clearCacheConfirm, role: .destructive) {
                    performRootAlertButtonAction(for: .clearCacheConfirmation(routeIndex: routeIndex)) {
                        sendSettingsAlertAction(.confirmClearCache, routeIndex: routeIndex)
                    }
                }
                Button(AppStrings.Common.cancel, role: .cancel) {
                    performRootAlertButtonAction(for: .clearCacheConfirmation(routeIndex: routeIndex)) {
                        sendSettingsAlertAction(.cancelClearCache, routeIndex: routeIndex)
                    }
                }
            case let .clearCacheSuccess(routeIndex):
                Button(AppStrings.Common.ok, role: .cancel) {
                    performRootAlertButtonAction(for: .clearCacheSuccess(routeIndex: routeIndex)) {
                        sendSettingsAlertAction(.clearCacheSuccessDismissed, routeIndex: routeIndex)
                    }
                }
            case let .recommendationHistoryResetConfirmation(routeIndex):
                Button("Öneri geçmişini sıfırla", role: .destructive) {
                    performRootAlertButtonAction(for: .recommendationHistoryResetConfirmation(routeIndex: routeIndex)) {
                        sendSettingsAlertAction(.confirmRecommendationHistoryReset, routeIndex: routeIndex)
                    }
                }
                Button(AppStrings.Common.cancel, role: .cancel) {
                    performRootAlertButtonAction(for: .recommendationHistoryResetConfirmation(routeIndex: routeIndex)) {
                        sendSettingsAlertAction(.cancelRecommendationHistoryReset, routeIndex: routeIndex)
                    }
                }
            case let .recommendationHistoryResetSuccess(routeIndex):
                Button(AppStrings.Common.ok, role: .cancel) {
                    performRootAlertButtonAction(for: .recommendationHistoryResetSuccess(routeIndex: routeIndex)) {
                        sendSettingsAlertAction(.recommendationHistoryResetSuccessDismissed, routeIndex: routeIndex)
                    }
                }
            case let .backupImportError(routeIndex, message):
                Button(AppStrings.Common.ok, role: .cancel) {
                    performRootAlertButtonAction(for: .backupImportError(routeIndex: routeIndex, message: message)) {
                        sendSettingsAlertAction(.backupImportAlertDismissed, routeIndex: routeIndex)
                    }
                }
            case let .backupExportNotice(routeIndex, message):
                Button(AppStrings.Common.ok, role: .cancel) {
                    performRootAlertButtonAction(for: .backupExportNotice(routeIndex: routeIndex, message: message)) {
                        sendSettingsAlertAction(.backupExportAlertDismissed, routeIndex: routeIndex)
                    }
                }
            case let .downloadsError(routeIndex, message):
                Button(AppStrings.Common.ok, role: .cancel) {
                    performRootAlertButtonAction(for: .downloadsError(routeIndex: routeIndex, message: message)) {
                        sendDownloadsAction(.dismissError, routeIndex: routeIndex)
                    }
                }
            case nil:
                EmptyView()
            }
        } message: {
            switch rootAlertContext {
            case .streamHandoff:
                Text(AppStrings.Common.handoffPlaybackUnavailableMessage)
            case let .rememberedPlaybackChoice(_, reminder):
                Text(AppStrings.Player.rememberedPlaybackChoiceMessage(reminder.choice.title))
            case .clearCacheConfirmation:
                Text(AppStrings.Settings.clearCacheMessage)
            case .clearCacheSuccess:
                Text(AppStrings.Settings.clearCacheSuccess)
            case .recommendationHistoryResetConfirmation:
                Text("Bu profildeki eski izleme geçmişi öneri sinyali olmaktan çıkar. İzlemeye Devam Et ilerlemesi ve favoriler silinmez.")
            case .recommendationHistoryResetSuccess:
                Text("Yeni izlemeler For You önerilerine yeniden katkı sağlayabilir.")
            case let .backupImportError(_, message):
                Text(message)
            case let .backupExportNotice(_, message):
                Text(message)
            case let .downloadsError(_, message):
                Text(message)
            case nil:
                EmptyView()
            }
        }
        #if os(iOS)
        .fileImporter(
            isPresented: backupImportFileImporterIsPresented,
            allowedContentTypes: [UTType(filenameExtension: "iptvbackup") ?? .data],
            allowsMultipleSelection: false,
            onCompletion: { [presentedContext = backupImportPickerContext] result in
                guard let presentedContext else { return }
                handleBackupImport(result, context: presentedContext)
            }
        )
        #endif
        .confirmationDialog(
            confirmationDialogContext?.title ?? "",
            isPresented: confirmationDialogIsPresented,
            titleVisibility: .visible
        ) {
            switch confirmationDialogContext {
            case .playlistDeletion:
                Button(AppStrings.Common.delete, role: .destructive) {
                    performConfirmationDialogButtonAction {
                        confirmActiveConfirmation()
                    }
                }
                Button(AppStrings.Common.cancel, role: .cancel) {
                    performConfirmationDialogButtonAction {
                        cancelActiveConfirmation()
                    }
                }
            case let .hideSelectedChannels(_, selectedCount):
                Button("\(selectedCount) Kanalı Gizle", role: .destructive) {
                    performConfirmationDialogButtonAction {
                        confirmActiveConfirmation()
                    }
                }
                Button("İptal", role: .cancel) {
                    performConfirmationDialogButtonAction {
                        cancelActiveConfirmation()
                    }
                }
            case let .downloadsClearCompleted(_, isDeletionInProgress):
                Button(AppStrings.Downloads.clearCompleted, role: .destructive) {
                    performConfirmationDialogButtonAction {
                        confirmActiveConfirmation()
                    }
                }
                .disabled(isDeletionInProgress)
                #if os(iOS)
                .accessibilityValue(isDeletionInProgress ? AppStrings.Common.loading : "")
                #endif
                Button(AppStrings.Common.cancel, role: .cancel) {
                    performConfirmationDialogButtonAction {
                        cancelActiveConfirmation()
                    }
                }
            case let .downloadsDelete(_, _, isDeletionInProgress):
                Button(AppStrings.Common.delete, role: .destructive) {
                    performConfirmationDialogButtonAction {
                        confirmActiveConfirmation()
                    }
                }
                .disabled(isDeletionInProgress)
                #if os(iOS)
                .accessibilityValue(isDeletionInProgress ? AppStrings.Common.loading : "")
                #endif
                Button(AppStrings.Common.cancel, role: .cancel) {
                    performConfirmationDialogButtonAction {
                        cancelActiveConfirmation()
                    }
                }
            case nil:
                EmptyView()
            }
        } message: {
            switch confirmationDialogContext {
            case let .playlistDeletion(_, playlist):
                let name = playlist.name
                Text("\"\(name)\" çalma listesini silmek istediğinize emin misiniz?")
            case .hideSelectedChannels:
                Text("Seçili kanallar görünür listelerden kaldırılacak. Ayarlar > Gizlenen İçerikler bölümünden kanalları geri alabilirsiniz.")
            case .downloadsClearCompleted:
                Text(AppStrings.Downloads.clearCompletedMessage)
            case let .downloadsDelete(_, item, _):
                Text(AppStrings.Downloads.deleteDownloadMessage(item.title))
            case nil:
                EmptyView()
            }
        }
    }

    private enum ConfirmationDialogContext {
        case playlistDeletion(routeIndex: Int, playlist: SavedPlaylist)
        case hideSelectedChannels(routeIndex: Int, selectedCount: Int)
        case downloadsClearCompleted(routeIndex: Int, isDeletionInProgress: Bool)
        case downloadsDelete(routeIndex: Int, item: OfflineMediaSnapshot, isDeletionInProgress: Bool)

        var title: String {
            switch self {
            case .playlistDeletion:
                AppStrings.Common.delete
            case .hideSelectedChannels:
                "Seçili Kanalları Gizle"
            case .downloadsClearCompleted:
                AppStrings.Downloads.clearCompletedTitle
            case .downloadsDelete:
                AppStrings.Downloads.deleteDownloadTitle
            }
        }
    }

    private enum RootAlertContext {
        case streamHandoff
        case rememberedPlaybackChoice(routeIndex: Int, reminder: PlaybackChoiceReminder)
        case clearCacheConfirmation(routeIndex: Int)
        case clearCacheSuccess(routeIndex: Int)
        case recommendationHistoryResetConfirmation(routeIndex: Int)
        case recommendationHistoryResetSuccess(routeIndex: Int)
        case backupImportError(routeIndex: Int, message: String)
        case backupExportNotice(routeIndex: Int, message: String)
        case downloadsError(routeIndex: Int, message: String)

        var title: String {
            switch self {
            case .streamHandoff:
                AppStrings.Common.handoffPlaybackUnavailableTitle
            case .rememberedPlaybackChoice:
                AppStrings.Player.rememberedPlaybackChoiceTitle
            case .clearCacheConfirmation, .clearCacheSuccess:
                AppStrings.Settings.clearCacheTitle
            case .recommendationHistoryResetConfirmation:
                "Öneri geçmişi sıfırlansın mı?"
            case .recommendationHistoryResetSuccess:
                "Öneri geçmişi sıfırlandı"
            case .backupImportError, .backupExportNotice:
                "PureIPTV Bildirimi"
            case .downloadsError:
                AppStrings.Downloads.title
            }
        }
    }

    private var rememberedPlaybackChoiceContext: (routeIndex: Int, reminder: PlaybackChoiceReminder)? {
        guard let routeIndex = store.routes.indices.last,
              case let .player(state) = store.routes[routeIndex].screen,
              let reminder = state.rememberedPlaybackChoice,
              state.playerState == .playing,
              state.errorMessage == nil,
              !state.isReconnecting,
              !state.isSwitchingPlaybackEngine,
              !state.isMinimized,
              !state.isPiPActive,
              !state.isAppInBackground
        else { return nil }
        return (routeIndex, reminder)
    }

    private var rootAlertContext: RootAlertContext? {
        if store.isStreamHandoffErrorPresented {
            return .streamHandoff
        }
        if let context = rememberedPlaybackChoiceContext {
            return .rememberedPlaybackChoice(routeIndex: context.routeIndex, reminder: context.reminder)
        }
        if let context = clearCacheAlertContext {
            return context.isSuccess
                ? .clearCacheSuccess(routeIndex: context.routeIndex)
                : .clearCacheConfirmation(routeIndex: context.routeIndex)
        }
        if let context = recommendationHistoryResetAlertContext {
            return context.isSuccess
                ? .recommendationHistoryResetSuccess(routeIndex: context.routeIndex)
                : .recommendationHistoryResetConfirmation(routeIndex: context.routeIndex)
        }
        if let routeIndex = store.routes.indices.last,
           case let .home(state) = store.routes[routeIndex].screen,
           state.selectedTab == .settings,
           let message = state.settings.backupImportAlertMessage
        {
            return .backupImportError(routeIndex: routeIndex, message: message)
        }
        if let routeIndex = store.routes.indices.last,
           case let .home(state) = store.routes[routeIndex].screen,
           state.selectedTab == .settings,
           let message = state.settings.backupExportAlertMessage
        {
            return .backupExportNotice(routeIndex: routeIndex, message: message)
        }
        if let routeIndex = store.routes.indices.last,
           case let .home(state) = store.routes[routeIndex].screen,
           state.selectedTab == .downloads,
           let message = state.downloads.errorMessage
        {
            return .downloadsError(routeIndex: routeIndex, message: message)
        }
        return nil
    }

    private var clearCacheAlertContext: (routeIndex: Int, isSuccess: Bool)? {
        guard let routeIndex = store.routes.indices.last,
              case let .home(state) = store.routes[routeIndex].screen,
              state.selectedTab == .settings
        else { return nil }
        if state.settings.isShowingClearCacheConfirmation {
            return (routeIndex, false)
        }
        if state.settings.isShowingClearCacheSuccess {
            return (routeIndex, true)
        }
        return nil
    }

    private var recommendationHistoryResetAlertContext: (routeIndex: Int, isSuccess: Bool)? {
        guard let routeIndex = store.routes.indices.last,
              case let .home(state) = store.routes[routeIndex].screen,
              state.selectedTab == .settings
        else { return nil }
        if state.settings.isShowingRecommendationHistoryResetConfirmation {
            return (routeIndex, false)
        }
        if state.settings.isShowingRecommendationHistoryResetSuccess {
            return (routeIndex, true)
        }
        return nil
    }

    #if os(iOS)
    private var backupImportPickerContext: (routeIndex: Int, requestID: UUID)? {
        guard let routeIndex = store.routes.indices.last,
              case let .home(state) = store.routes[routeIndex].screen,
              state.selectedTab == .settings,
              let requestID = state.settings.backupImportPickerRequestID
        else { return nil }
        return (routeIndex, requestID)
    }

    private var backupImportFileImporterIsPresented: Binding<Bool> {
        Binding(
            get: {
                guard let context = backupImportPickerContext,
                      case let .home(state) = store.routes[context.routeIndex].screen
                else { return false }
                return state.settings.isImportingBackup
            },
            set: { isPresented in
                guard !isPresented, let context = backupImportPickerContext else { return }
                sendSettingsAlertAction(
                    .backupImportPickerDismissed(requestID: context.requestID),
                    routeIndex: context.routeIndex
                )
            }
        )
    }

    private func handleBackupImport(
        _ result: Result<[URL], Error>,
        context: (routeIndex: Int, requestID: UUID)
    ) {
        switch result {
        case let .failure(error):
            sendSettingsAlertAction(
                .backupImportPickerFailed(
                    requestID: context.requestID,
                    message: "Yedek dosyası açılamadı: \(error.localizedDescription)"
                ),
                routeIndex: context.routeIndex
            )
        case let .success(urls):
            sendSettingsAlertAction(
                .backupImportFilesSelected(requestID: context.requestID, urls: urls),
                routeIndex: context.routeIndex
            )
        }
    }
    #endif

    private var rootAlertIsPresented: Binding<Bool> {
        Binding(
            get: { rootAlertContext != nil },
            set: { isPresented in
                guard !isPresented else { return }
                if rootAlertButtonActionContext != nil {
                    rootAlertButtonActionContext = nil
                    return
                }
                guard let context = rootAlertContext else { return }
                switch context {
                case .streamHandoff:
                    store.send(.dismissStreamHandoffError)
                case .rememberedPlaybackChoice:
                    return
                case let .clearCacheConfirmation(routeIndex):
                    sendSettingsAlertAction(.cancelClearCache, routeIndex: routeIndex)
                case let .clearCacheSuccess(routeIndex):
                    sendSettingsAlertAction(.clearCacheSuccessDismissed, routeIndex: routeIndex)
                case let .recommendationHistoryResetConfirmation(routeIndex):
                    sendSettingsAlertAction(.cancelRecommendationHistoryReset, routeIndex: routeIndex)
                case let .recommendationHistoryResetSuccess(routeIndex):
                    sendSettingsAlertAction(.recommendationHistoryResetSuccessDismissed, routeIndex: routeIndex)
                case let .backupImportError(routeIndex, _):
                    sendSettingsAlertAction(.backupImportAlertDismissed, routeIndex: routeIndex)
                case let .backupExportNotice(routeIndex, _):
                    sendSettingsAlertAction(.backupExportAlertDismissed, routeIndex: routeIndex)
                case let .downloadsError(routeIndex, _):
                    sendDownloadsAction(.dismissError, routeIndex: routeIndex)
                }
            }
        )
    }

    private func performRootAlertButtonAction(for context: RootAlertContext, action: () -> Void) {
        rootAlertButtonActionContext = context
        action()
    }

    private var playlistDeletionContext: (routeIndex: Int, playlist: SavedPlaylist)? {
        guard let routeIndex = store.routes.indices.last(where: { index in
                  guard case let .playlistManagement(state) = store.routes[index].screen else { return false }
                  return state.startupUnlockPlaylistID == nil && state.playlistToDelete != nil
              }),
              case let .playlistManagement(state) = store.routes[routeIndex].screen,
              let playlist = state.playlistToDelete
        else { return nil }
        return (routeIndex, playlist)
    }

    private var hideSelectedChannelsContext: (routeIndex: Int, selectedCount: Int)? {
        guard let routeIndex = store.routes.indices.last(where: { index in
                  guard case let .home(state) = store.routes[index].screen else { return false }
                  return state.selectedTab == .liveTV
                      && state.liveTV.isChannelSelectionMode
                      && state.liveTV.isConfirmingHideSelectedChannels
                      && !state.liveTV.selectedCurrentChannelIDs.isEmpty
              }),
              case let .home(state) = store.routes[routeIndex].screen
        else { return nil }
        return (routeIndex, state.liveTV.selectedCurrentChannelIDs.count)
    }

    private var confirmationDialogContext: ConfirmationDialogContext? {
        if let context = playlistDeletionContext {
            return .playlistDeletion(routeIndex: context.routeIndex, playlist: context.playlist)
        }
        if let context = hideSelectedChannelsContext {
            return .hideSelectedChannels(routeIndex: context.routeIndex, selectedCount: context.selectedCount)
        }
        if let context = downloadsConfirmationContext {
            return context
        }
        return nil
    }

    private var downloadsConfirmationContext: ConfirmationDialogContext? {
        guard let routeIndex = store.routes.indices.last,
              case let .home(state) = store.routes[routeIndex].screen,
              state.selectedTab == .downloads
        else { return nil }
        let downloads = state.downloads
        let isDeletionInProgress = downloads.isClearingCompleted || !downloads.deletingDownloadIDs.isEmpty
        if downloads.isConfirmingClearCompleted {
            return .downloadsClearCompleted(
                routeIndex: routeIndex,
                isDeletionInProgress: isDeletionInProgress
            )
        }
        if let item = downloads.pendingDeleteItem {
            return .downloadsDelete(
                routeIndex: routeIndex,
                item: item,
                isDeletionInProgress: isDeletionInProgress
            )
        }
        return nil
    }

    private var confirmationDialogIsPresented: Binding<Bool> {
        Binding(
            get: { confirmationDialogContext != nil },
            set: { isPresented in
                if !isPresented {
                    if confirmationDialogButtonActionPending {
                        confirmationDialogButtonActionPending = false
                        return
                    }
                    cancelActiveConfirmation()
                }
            }
        )
    }

    private func performConfirmationDialogButtonAction(_ action: () -> Void) {
        confirmationDialogButtonActionPending = true
        action()
    }

    private func sendRememberedPlaybackChoiceAction(
        _ action: PlayerFeature.Action,
        routeIndex: Int,
        reminder: PlaybackChoiceReminder
    ) {
        guard let currentContext = rememberedPlaybackChoiceContext,
              currentContext.routeIndex == routeIndex,
              currentContext.reminder == reminder
        else { return }
        store.send(.router(.routeAction(
            id: routeIndex,
            action: .player(action)
        )))
    }

    private func sendSettingsAlertAction(_ action: SettingsFeature.Action, routeIndex: Int) {
        guard store.routes.indices.contains(routeIndex),
              routeIndex == store.routes.count - 1,
              case let .home(state) = store.routes[routeIndex].screen,
              state.selectedTab == .settings
        else { return }
        store.send(.router(.routeAction(
            id: routeIndex,
            action: .home(.settings(action))
        )))
    }

    private func sendDownloadsAction(_ action: DownloadsFeature.Action, routeIndex: Int) {
        guard store.routes.indices.contains(routeIndex),
              routeIndex == store.routes.count - 1,
              case let .home(state) = store.routes[routeIndex].screen,
              state.selectedTab == .downloads
        else { return }
        store.send(.router(.routeAction(
            id: routeIndex,
            action: .home(.downloads(action))
        )))
    }

    private func confirmActiveConfirmation() {
        switch confirmationDialogContext {
        case .playlistDeletion:
            sendPlaylistDeletionAction(.deletePlaylistConfirmed)
        case let .hideSelectedChannels(routeIndex, _):
            sendHideSelectedChannelsAction(.hideSelectedChannels, routeIndex: routeIndex)
        case let .downloadsClearCompleted(routeIndex, _):
            sendDownloadsAction(.clearCompletedConfirmed, routeIndex: routeIndex)
        case let .downloadsDelete(routeIndex, _, _):
            sendDownloadsAction(.deleteDownloadConfirmed, routeIndex: routeIndex)
        case nil:
            return
        }
    }

    private func cancelActiveConfirmation() {
        switch confirmationDialogContext {
        case .playlistDeletion:
            sendPlaylistDeletionAction(.cancelDeletePlaylist)
        case let .hideSelectedChannels(routeIndex, _):
            sendHideSelectedChannelsAction(.cancelHideSelectedChannelsConfirmation, routeIndex: routeIndex)
        case let .downloadsClearCompleted(routeIndex, _):
            sendDownloadsAction(.clearCompletedCancelled, routeIndex: routeIndex)
        case let .downloadsDelete(routeIndex, _, _):
            sendDownloadsAction(.deleteDownloadCancelled, routeIndex: routeIndex)
        case nil:
            return
        }
    }

    private func sendPlaylistDeletionAction(_ action: PlaylistManagementFeature.Action) {
        guard let context = playlistDeletionContext else { return }
        store.send(.router(.routeAction(
            id: context.routeIndex,
            action: .playlistManagement(action)
        )))
    }

    private func sendHideSelectedChannelsAction(_ action: LiveTVFeature.Action, routeIndex: Int) {
        guard store.routes.indices.contains(routeIndex),
              case let .home(state) = store.routes[routeIndex].screen,
              state.selectedTab == .liveTV,
              state.liveTV.isChannelSelectionMode
        else { return }
        store.send(.router(.routeAction(
            id: routeIndex,
            action: .home(.liveTV(action))
        )))
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

private struct FavoriteChannelListManagementRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<FavoriteChannelListManagementRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                FavoriteChannelListManagementView(
                    store: liveTVStore,
                    onDismiss: { routeStore.send(.closeTapped) }
                )
                #if os(tvOS)
                    .onExitCommand { routeStore.send(.closeTapped) }
                #endif
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear {
            coordinatorStore.send(.favoriteChannelListManagementRouteDidDisappear(routeStore.presentationID))
        }
    }

    private var homeState: HomeFeature.State? {
        let homeRouteIndex = routeStore.homeRouteIndex
        guard coordinatorStore.routes.indices.contains(homeRouteIndex),
              case let .home(homeState) = coordinatorStore.routes[homeRouteIndex].screen
        else { return nil }
        return homeState
    }

    private var isCurrentPresentation: Bool {
        guard let homeState else { return false }
        return homeState.selectedTab == .liveTV
            && homeState.config == routeStore.homeConfig
            && homeState.liveTV.config == routeStore.homeConfig
    }

    private var isRouteActive: Bool {
        guard case let .favoriteChannelListManagement(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID
    }

    private var liveTVStore: StoreOf<LiveTVFeature> {
        let homeRouteIndex = routeStore.homeRouteIndex
        let homeConfig = routeStore.homeConfig
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = coordinatorState.routes[homeRouteIndex].screen,
                      homeState.selectedTab == .liveTV,
                      homeState.config == homeConfig,
                      homeState.liveTV.config == homeConfig
                else { return LiveTVFeature.State() }
                return homeState.liveTV
            },
            action: {
                .router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.liveTV($0))
                ))
            }
        )
    }

    private func closeIfStale() {
        guard isCurrentPresentation else {
            guard isRouteActive else { return }
            routeStore.send(.closeTapped)
            return
        }
    }
}

private struct AddPlaylistQRTransferRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<AddPlaylistQRTransferRouteFeature>

    var body: some View {
        Group {
            if isParentCurrent {
                TVOnboardingQRView(
                    onDismiss: { routeStore.send(.closeTapped) },
                    onPaired: { routeStore.send(.paired) }
                )
                #if os(tvOS)
                    .onExitCommand { routeStore.send(.closeTapped) }
                #endif
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isParentCurrent) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear {
            coordinatorStore.send(.addPlaylistQRTransferRouteDidDisappear(
                presentationID: routeStore.presentationID,
                parent: routeStore.parent,
                wasPaired: routeStore.isPaired
            ))
        }
    }

    private var isParentCurrent: Bool {
        switch routeStore.parent {
        case let .addPlaylistRoute(routeIndex):
            guard coordinatorStore.routes.indices.contains(routeIndex),
                  case .addPlaylist = coordinatorStore.routes[routeIndex].screen
            else { return false }
            return true

        case let .playlistManagementAddPlaylistRoute(routeIndex, presentationID, requestID):
            guard coordinatorStore.routes.indices.contains(routeIndex),
                  case let .playlistManagementAddPlaylist(addPlaylistState) = coordinatorStore.routes[routeIndex].screen,
                  addPlaylistState.presentationID == presentationID,
                  addPlaylistState.requestID == requestID,
                  coordinatorStore.routes.indices.contains(addPlaylistState.playlistManagementRouteIndex),
                  case let .playlistManagement(managementState) = coordinatorStore.routes[addPlaylistState.playlistManagementRouteIndex].screen,
                  managementState.addPlaylistPresentationRequestID == requestID,
                  managementState.addPlaylist != nil,
                  managementState.startupUnlockPlaylistID == nil
            else { return false }
            return true
        }
    }

    private var isRouteActive: Bool {
        guard case let .addPlaylistQRTransfer(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID
    }

    private func closeIfStale() {
        guard !isParentCurrent, isRouteActive else { return }
        routeStore.send(.closeTapped)
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

private struct ProfileAddProfileRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<ProfileAddProfileRouteFeature>

    var body: some View {
        Group {
            if isCurrentContext {
                ProfileAddProfileRouteForm(
                    isPerformingProfileOperation: profileSelectionState?.isPerformingProfileOperation ?? false,
                    errorMessage: profileSelectionState?.errorMessage,
                    onClose: close,
                    onRetry: { profileSelectionStore.send(.retry) },
                    onAdd: { name, isKidsMode, avatarIcon in
                        profileSelectionStore.send(.addProfile(
                            name: name,
                            isKidsMode: isKidsMode,
                            avatarIcon: avatarIcon
                        ))
                    }
                )
            } else {
                EmptyView()
            }
        }
        .onAppear(perform: closeIfContextChanged)
        .onChange(of: profileSelectionState?.profiles.count) { _, newCount in
            guard let newCount, newCount > routeStore.profileCountAtPresentation else { return }
            routeStore.send(.closeTapped)
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var profileSelectionState: ProfileSelectionFeature.State? {
        let routeIndex = routeStore.profileSelectionRouteIndex
        guard coordinatorStore.routes.indices.contains(routeIndex),
              case let .profileSelection(state) = coordinatorStore.routes[routeIndex].screen
        else { return nil }
        return state
    }

    private var profileSelectionStore: StoreOf<ProfileSelectionFeature> {
        let routeIndex = routeStore.profileSelectionRouteIndex
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(routeIndex),
                      case let .profileSelection(state) = coordinatorState.routes[routeIndex].screen
                else { return ProfileSelectionFeature.State() }
                return state
            },
            action: {
                .router(.routeAction(
                    id: routeIndex,
                    action: .profileSelection($0)
                ))
            }
        )
    }

    private var isCurrentContext: Bool {
        guard let profileSelectionState else { return false }
        return !profileSelectionState.isEditing && profileSelectionState.profiles.count < 6
    }

    private var isRouteActive: Bool {
        guard case let .profileAddProfile(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID
    }

    private func closeIfContextChanged() {
        guard !isCurrentContext, isRouteActive else { return }
        routeStore.send(.closeTapped)
    }

    private func close() {
        if profileSelectionState?.errorMessage != nil {
            profileSelectionStore.send(.dismissError)
        }
        routeStore.send(.closeTapped)
    }

    private func notifyRouteDidDisappear() {
        if isRouteActive {
            routeStore.send(.closeTapped)
        }
        coordinatorStore.send(.profileAddProfileRouteDidDisappear(
            presentationID: routeStore.presentationID,
            profileSelectionRouteIndex: routeStore.profileSelectionRouteIndex
        ))
    }
}

private struct EPGTimelineProgramDetailRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<EPGTimelineProgramDetailRouteFeature>

    var body: some View {
        Group {
            if isCurrentContext {
                EPGTimelineView(store: timelineStore)
                    .programDetailSheet(program: routeStore.program, channel: routeStore.channel)
                    #if os(tvOS)
                    .onExitCommand { routeStore.send(.closeTapped) }
                    #endif
            } else {
                EmptyView()
            }
        }
        .onAppear(perform: closeIfContextChanged)
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var isCurrentContext: Bool {
        guard let timelineState else { return false }
        return timelineState.selectedProgramDetailRequestID == routeStore.detailRequestID
            && timelineState.selectedProgramDetail == routeStore.program
            && timelineState.selectedProgramChannel == routeStore.channel
    }

    private var timelineState: EPGTimelineFeature.State? {
        guard coordinatorStore.routes.indices.contains(routeStore.timelineRouteIndex),
              case let .epgTimeline(state) = coordinatorStore.routes[routeStore.timelineRouteIndex].screen,
              state.presentationID == routeStore.timelinePresentationID
        else { return nil }
        return state
    }

    private var timelineStore: StoreOf<EPGTimelineFeature> {
        let timelineRouteIndex = routeStore.timelineRouteIndex
        let fallbackState = EPGTimelineFeature.State(
            config: routeStore.config,
            channels: [],
            presentationID: routeStore.timelinePresentationID
        )
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(timelineRouteIndex),
                      case let .epgTimeline(state) = coordinatorState.routes[timelineRouteIndex].screen
                else { return fallbackState }
                return state
            },
            action: {
                .router(.routeAction(
                    id: timelineRouteIndex,
                    action: .epgTimeline($0)
                ))
            }
        )
    }

    private func closeIfContextChanged() {
        guard isCurrentContext else {
            routeStore.send(.closeTapped)
            return
        }
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.epgTimelineProgramDetailRouteDidDisappear(
            presentationID: routeStore.presentationID,
            timelineRouteIndex: routeStore.timelineRouteIndex,
            timelinePresentationID: routeStore.timelinePresentationID,
            detailRequestID: routeStore.detailRequestID
        ))
    }
}

private struct EPGTimelineChannelLogoEditorRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<EPGTimelineChannelLogoEditorRouteFeature>
    @State private var logoURLDraft: String

    init(
        coordinatorStore: StoreOf<AppCoordinator>,
        routeStore: StoreOf<EPGTimelineChannelLogoEditorRouteFeature>
    ) {
        self.coordinatorStore = coordinatorStore
        self.routeStore = routeStore
        // The draft is intentionally seeded once from the selected channel.
        _logoURLDraft = State(initialValue: routeStore.channel.logoURLOverride?.absoluteString ?? "")
    }

    var body: some View {
        Group {
            if isCurrentContext {
                EPGTimelineChannelLogoEditorForm(
                    logoURLDraft: $logoURLDraft,
                    onSave: saveOverride,
                    onClose: close
                )
                #if os(tvOS)
                    .onExitCommand(perform: close)
                #endif
            } else {
                EmptyView()
            }
        }
        .onAppear(perform: closeIfContextChanged)
        .onChange(of: isCurrentContext) { _, isCurrent in
            if !isCurrent { close() }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var timelineState: EPGTimelineFeature.State? {
        guard coordinatorStore.routes.indices.contains(routeStore.timelineRouteIndex),
              case let .epgTimeline(state) = coordinatorStore.routes[routeStore.timelineRouteIndex].screen,
              state.presentationID == routeStore.timelinePresentationID
        else { return nil }
        return state
    }

    private var isCurrentContext: Bool {
        guard let timelineState else { return false }
        return timelineState.config.playlistID == routeStore.playlistID
            && timelineState.channels.contains(where: { $0.id == routeStore.channel.id && $0.type == .live })
    }

    private func close() {
        routeStore.send(.closeTapped(presentationID: routeStore.presentationID))
    }

    private func closeIfContextChanged() {
        guard isCurrentContext else { close(); return }
    }

    private func saveOverride(_ rawValue: String?) {
        guard isCurrentContext else { close(); return }
        coordinatorStore.send(.router(.routeAction(
            id: routeStore.timelineRouteIndex,
            action: .epgTimeline(.saveChannelLogoOverride(
                channelID: routeStore.channel.id,
                rawValue: rawValue
            ))
        )))
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.epgTimelineChannelLogoEditorRouteDidDisappear(routeStore.presentationID))
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

#if os(iOS)
    private struct PlaylistQRTransferConfirmationRouteView: View {
        @Bindable var coordinatorStore: StoreOf<AppCoordinator>
        let routeStore: StoreOf<PlaylistQRTransferConfirmationRouteFeature>

        var body: some View {
            Group {
                if isCurrentPresentation {
                    PlaylistQRTransferConfirmationView(
                        playlists: coordinatorStore.playlistTransferPlaylists,
                        selectedID: coordinatorStore.playlistTransferSelectedID,
                        isLoading: coordinatorStore.isLoadingPlaylistTransfer,
                        isSubmitting: coordinatorStore.isSubmittingPlaylistTransfer,
                        error: coordinatorStore.playlistTransferError,
                        onSelect: { playlistID in
                            coordinatorStore.send(.selectPlaylistForTransfer(
                                sessionID: routeStore.sessionID,
                                presentationID: routeStore.presentationID,
                                playlistID: playlistID
                            ))
                        },
                        onConfirm: {
                            coordinatorStore.send(.confirmPlaylistTransfer(
                                sessionID: routeStore.sessionID,
                                presentationID: routeStore.presentationID
                            ))
                        },
                        onCancel: { routeStore.send(.cancelTapped) }
                    )
                } else {
                    EmptyView()
                }
            }
            .onAppear(perform: closeIfStale)
            .onChange(of: coordinatorStore.playlistTransferPresentationID) { _, _ in closeIfStale() }
            .onChange(of: coordinatorStore.playlistTransferPairing?.sessionID) { _, _ in closeIfStale() }
            .onDisappear(perform: notifyRouteDidDisappear)
        }

        private var isCurrentPresentation: Bool {
            coordinatorStore.playlistTransferPresentationID == routeStore.presentationID
                && coordinatorStore.playlistTransferPairing?.sessionID == routeStore.sessionID
        }

        private func closeIfStale() {
            guard !isCurrentPresentation else { return }
            routeStore.send(.cancelTapped)
        }

        private func notifyRouteDidDisappear() {
            coordinatorStore.send(.playlistTransferRouteDidDisappear(
                presentationID: routeStore.presentationID,
                sessionID: routeStore.sessionID
            ))
        }
    }
#endif

private struct PlaylistManagementSettingsRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<PlaylistManagementSettingsRouteFeature>

    var body: some View {
        Group {
            if let playlist {
                let managementStore = playlistManagementStore
                NavigationStack {
                    PlaylistManagementView(store: managementStore)
                        .playlistSettingsForm(for: playlist)
                        .navigationTitle(AppStrings.PlaylistMgmt.playbackSettings)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(AppStrings.Common.cancel) {
                                    routeStore.send(.closeTapped)
                                }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button(AppStrings.Common.save) {
                                    guard managementStore.canSaveUserAgentDraft,
                                          !managementStore.isRefreshingPlaylist
                                    else { return }
                                    managementStore.send(.savePlaylistSettings)
                                }
                            }
                        }
                }
                #if os(tvOS)
                    .onExitCommand { routeStore.send(.closeTapped) }
                #endif
            } else {
                EmptyView()
            }
        }
        .onAppear(perform: closeIfContextChanged)
        .onChange(of: playlistManagementState?.playlistSettingsEditRequestID) { _, _ in closeIfContextChanged() }
        .onChange(of: playlistManagementState?.playlistBeingEdited?.id) { _, _ in closeIfContextChanged() }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var playlistManagementState: PlaylistManagementFeature.State? {
        guard coordinatorStore.routes.indices.contains(routeStore.playlistManagementRouteIndex),
              case let .playlistManagement(state) = coordinatorStore.routes[routeStore.playlistManagementRouteIndex].screen
        else { return nil }
        return state
    }

    private var playlist: SavedPlaylist? {
        guard let playlistManagementState,
              playlistManagementState.playlistSettingsEditRequestID == routeStore.editRequestID,
              playlistManagementState.playlistBeingEdited?.id == routeStore.playlistID
        else { return nil }
        return playlistManagementState.playlistBeingEdited
    }

    private var playlistManagementStore: StoreOf<PlaylistManagementFeature> {
        let parentRouteIndex = routeStore.playlistManagementRouteIndex
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(parentRouteIndex),
                      case let .playlistManagement(state) = coordinatorState.routes[parentRouteIndex].screen
                else { return PlaylistManagementFeature.State() }
                return state
            },
            action: {
                .router(.routeAction(
                    id: parentRouteIndex,
                    action: .playlistManagement($0)
                ))
            }
        )
    }

    private func closeIfContextChanged() {
        guard playlist != nil else {
            routeStore.send(.closeTapped)
            return
        }
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.playlistManagementSettingsRouteDidDisappear(
            presentationID: routeStore.presentationID,
            playlistManagementRouteIndex: routeStore.playlistManagementRouteIndex,
            editRequestID: routeStore.editRequestID
        ))
    }
}

private struct PlaylistManagementPINRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<PlaylistManagementPINRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                let managementStore = playlistManagementStore
                PlaylistManagementPINPromptView(
                    store: managementStore,
                    isStartupUnlock: routeStore.isStartupUnlock,
                    onCancel: { routeStore.send(.closeTapped) }
                )
                .interactiveDismissDisabled(routeStore.isStartupUnlock)
                #if os(tvOS)
                    .onExitCommand {
                        if !routeStore.isStartupUnlock {
                            routeStore.send(.closeTapped)
                        }
                    }
                #endif
            } else {
                EmptyView()
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: playlistManagementState?.pinPresentationRequestID) { _, _ in closeIfStale() }
        .onChange(of: playlistManagementState?.pinFlow) { _, _ in closeIfStale() }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var playlistManagementState: PlaylistManagementFeature.State? {
        guard coordinatorStore.routes.indices.contains(routeStore.playlistManagementRouteIndex),
              case let .playlistManagement(state) = coordinatorStore.routes[routeStore.playlistManagementRouteIndex].screen
        else { return nil }
        return state
    }

    private var isCurrentPresentation: Bool {
        playlistManagementState?.pinPresentationRequestID == routeStore.requestID
            && playlistManagementState?.pinFlow == routeStore.flow
    }

    private var playlistManagementStore: StoreOf<PlaylistManagementFeature> {
        let parentRouteIndex = routeStore.playlistManagementRouteIndex
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(parentRouteIndex),
                      case let .playlistManagement(state) = coordinatorState.routes[parentRouteIndex].screen
                else { return PlaylistManagementFeature.State() }
                return state
            },
            action: {
                .router(.routeAction(
                    id: parentRouteIndex,
                    action: .playlistManagement($0)
                ))
            }
        )
    }

    private func closeIfStale() {
        guard isCurrentPresentation else {
            routeStore.send(.closeTapped)
            return
        }
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.playlistManagementPINRouteDidDisappear(
            presentationID: routeStore.presentationID,
            playlistManagementRouteIndex: routeStore.playlistManagementRouteIndex,
            requestID: routeStore.requestID,
            flow: routeStore.flow
        ))
    }
}

private struct PlaylistManagementAddPlaylistRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<PlaylistManagementAddPlaylistRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                NavigationStack {
                    AddPlaylistView(store: addPlaylistStore)
                        #if os(tvOS)
                            .onExitCommand {
                                routeStore.send(.closeTapped)
                            }
                        #endif
                }
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var playlistManagementState: PlaylistManagementFeature.State? {
        let parentRouteIndex = routeStore.playlistManagementRouteIndex
        guard coordinatorStore.routes.indices.contains(parentRouteIndex),
              case let .playlistManagement(state) = coordinatorStore.routes[parentRouteIndex].screen
        else { return nil }
        return state
    }

    private var isCurrentPresentation: Bool {
        playlistManagementState?.startupUnlockPlaylistID == nil
            && playlistManagementState?.addPlaylistPresentationRequestID == routeStore.requestID
            && playlistManagementState?.addPlaylist != nil
    }

    private var isRouteActive: Bool {
        guard case let .playlistManagementAddPlaylist(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private var addPlaylistStore: StoreOf<AddPlaylistFeature> {
        let parentRouteIndex = routeStore.playlistManagementRouteIndex
        let requestID = routeStore.requestID
        let presentationID = routeStore.presentationID
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(parentRouteIndex),
                      case let .playlistManagement(managementState) = coordinatorState.routes[parentRouteIndex].screen,
                      managementState.addPlaylistPresentationRequestID == requestID,
                      let addPlaylistState = managementState.addPlaylist
                else { return AddPlaylistFeature.State() }
                return addPlaylistState
            },
            action: {
                .playlistManagementAddPlaylistChildAction(
                    presentationID: presentationID,
                    requestID: requestID,
                    action: $0
                )
            }
        )
    }

    private func closeIfStale() {
        guard isCurrentPresentation else {
            guard isRouteActive else { return }
            routeStore.send(.closeTapped)
            return
        }
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.playlistManagementAddPlaylistRouteDidDisappear(
            presentationID: routeStore.presentationID,
            playlistManagementRouteIndex: routeStore.playlistManagementRouteIndex,
            requestID: routeStore.requestID
        ))
    }
}

private struct PlayerSpeedTestRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<PlayerSpeedTestRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                StreamSpeedTestView {
                    routeStore.send(.closeTapped)
                }
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var playerState: PlayerFeature.State? {
        let playerRouteIndex = routeStore.playerRouteIndex
        guard coordinatorStore.routes.indices.contains(playerRouteIndex),
              case let .player(state) = coordinatorStore.routes[playerRouteIndex].screen
        else { return nil }
        return state
    }

    private var isCurrentPresentation: Bool {
        playerState?.speedTestPresentationRequestID == routeStore.requestID
            && playerState?.item.id == routeStore.itemID
            && playerState?.playbackRequestID == routeStore.playbackRequestID
            && playerState?.isMinimized == false
            && playerState?.isClosing == false
    }

    private var isRouteActive: Bool {
        guard case let .playerSpeedTest(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func closeIfStale() {
        guard isCurrentPresentation else {
            guard isRouteActive else { return }
            routeStore.send(.closeTapped)
            return
        }
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.playerSpeedTestRouteDidDisappear(
            presentationID: routeStore.presentationID,
            playerRouteIndex: routeStore.playerRouteIndex,
            requestID: routeStore.requestID
        ))
    }
}

private struct PlayerSubtitleSearchRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<PlayerSubtitleSearchRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                OpenSubtitlesSearchView(
                    itemTitle: routeStore.itemTitle,
                    onSubtitleDownloaded: { url in
                        guard isCurrentPresentation, isRouteActive else { return }
                        coordinatorStore.send(.router(.routeAction(
                            id: routeStore.playerRouteIndex,
                            action: .player(.installSubtitleSearchTrack(
                                url: url,
                                requestID: routeStore.requestID,
                                playbackRequestID: routeStore.playbackRequestID
                            ))
                        )))
                    },
                    onClose: {
                        routeStore.send(.closeTapped)
                    },
                    isActive: { isCurrentPresentation && isRouteActive },
                    isInstallingTrack: playerState?.subtitleSearchTrackInstallRequestID == routeStore.requestID,
                    installationErrorMessage: playerState?.subtitleSearchTrackInstallErrorMessage
                )
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var playerState: PlayerFeature.State? {
        let playerRouteIndex = routeStore.playerRouteIndex
        guard coordinatorStore.routes.indices.contains(playerRouteIndex),
              case let .player(state) = coordinatorStore.routes[playerRouteIndex].screen
        else { return nil }
        return state
    }

    private var isCurrentPresentation: Bool {
        playerState?.subtitleSearchPresentationRequestID == routeStore.requestID
            && playerState?.item.id == routeStore.itemID
            && playerState?.playbackRequestID == routeStore.playbackRequestID
            && playerState?.item.isLive == false
            && playerState?.playbackEngine == .vlc
            && playerState?.isMinimized == false
            && playerState?.isClosing == false
    }

    private var isRouteActive: Bool {
        guard case let .playerSubtitleSearch(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func closeIfStale() {
        guard isCurrentPresentation else {
            guard isRouteActive else { return }
            routeStore.send(.closeTapped)
            return
        }
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.playerSubtitleSearchRouteDidDisappear(
            presentationID: routeStore.presentationID,
            playerRouteIndex: routeStore.playerRouteIndex,
            requestID: routeStore.requestID
        ))
    }
}

private struct SettingsSpeedTestRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<SettingsSpeedTestRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                StreamSpeedTestView {
                    routeStore.send(.closeTapped)
                }
                #if os(iOS)
                    .presentationDetents([.medium, .large])
                #endif
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var homeState: HomeFeature.State? {
        let homeRouteIndex = routeStore.homeRouteIndex
        guard coordinatorStore.routes.indices.contains(homeRouteIndex),
              case let .home(state) = coordinatorStore.routes[homeRouteIndex].screen
        else { return nil }
        return state
    }

    private var isCurrentPresentation: Bool {
        homeState?.selectedTab == .settings
            && homeState?.settings.speedTestPresentationRequestID == routeStore.requestID
    }

    private var isRouteActive: Bool {
        guard case let .settingsSpeedTest(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func closeIfStale() {
        guard isCurrentPresentation else {
            guard isRouteActive else { return }
            routeStore.send(.closeTapped)
            return
        }
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.settingsSpeedTestRouteDidDisappear(
            presentationID: routeStore.presentationID,
            homeRouteIndex: routeStore.homeRouteIndex,
            requestID: routeStore.requestID
        ))
    }
}

private struct SettingsPINSetupRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<SettingsPINSetupRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                PINSetupView(store: settingsStore)
                    #if os(iOS)
                    .presentationDetents([.height(300)])
                    #endif
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var homeState: HomeFeature.State? {
        let homeRouteIndex = routeStore.homeRouteIndex
        guard coordinatorStore.routes.indices.contains(homeRouteIndex),
              case let .home(state) = coordinatorStore.routes[homeRouteIndex].screen
        else { return nil }
        return state
    }

    private var settingsStore: StoreOf<SettingsFeature> {
        let homeRouteIndex = routeStore.homeRouteIndex
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = coordinatorState.routes[homeRouteIndex].screen
                else { return SettingsFeature.State() }
                return homeState.settings
            },
            action: { action in
                .router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.settings(action))
                ))
            }
        )
    }

    private var isCurrentPresentation: Bool {
        homeState?.selectedTab == .settings
            && homeState?.settings.isShowingPINSetup == true
            && homeState?.settings.pinSetupPresentationRequestID == routeStore.requestID
    }

    private var isRouteActive: Bool {
        guard case let .settingsPINSetup(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func closeIfStale() {
        guard !isCurrentPresentation, isRouteActive else { return }
        routeStore.send(.closeTapped)
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.settingsPINSetupRouteDidDisappear(
            presentationID: routeStore.presentationID,
            homeRouteIndex: routeStore.homeRouteIndex,
            requestID: routeStore.requestID
        ))
    }
}

private struct SettingsTraktAuthRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<SettingsTraktAuthRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                TraktAuthView(store: traktStore, onClose: close)
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var homeState: HomeFeature.State? {
        let homeRouteIndex = routeStore.homeRouteIndex
        guard coordinatorStore.routes.indices.contains(homeRouteIndex),
              case let .home(state) = coordinatorStore.routes[homeRouteIndex].screen
        else { return nil }
        return state
    }

    private var traktStore: StoreOf<TraktFeature> {
        let homeRouteIndex = routeStore.homeRouteIndex
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = coordinatorState.routes[homeRouteIndex].screen
                else { return TraktFeature.State() }
                return homeState.settings.traktState
            },
            action: { action in
                .router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.settings(.traktAction(action)))
                ))
            }
        )
    }

    private var isCurrentPresentation: Bool {
        homeState?.selectedTab == .settings
            && homeState?.settings.isTraktAuthSheetPresented == true
            && homeState?.settings.traktAuthPresentationRequestID == routeStore.requestID
    }

    private var isRouteActive: Bool {
        guard case let .settingsTraktAuth(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func close() {
        routeStore.send(.closeTapped)
    }

    private func closeIfStale() {
        guard !isCurrentPresentation, isRouteActive else { return }
        close()
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.settingsTraktAuthRouteDidDisappear(
            presentationID: routeStore.presentationID,
            homeRouteIndex: routeStore.homeRouteIndex,
            requestID: routeStore.requestID
        ))
    }
}

private struct SettingsTraktWatchlistRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<SettingsTraktWatchlistRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                NavigationStack {
                    TraktWatchlistView(store: traktStore)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(AppStrings.Common.close) {
                                    close()
                                }
                            }
                        }
                }
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var homeState: HomeFeature.State? {
        let homeRouteIndex = routeStore.homeRouteIndex
        guard coordinatorStore.routes.indices.contains(homeRouteIndex),
              case let .home(state) = coordinatorStore.routes[homeRouteIndex].screen
        else { return nil }
        return state
    }

    private var traktStore: StoreOf<TraktFeature> {
        let homeRouteIndex = routeStore.homeRouteIndex
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = coordinatorState.routes[homeRouteIndex].screen
                else { return TraktFeature.State() }
                return homeState.settings.traktState
            },
            action: { action in
                .router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.settings(.traktAction(action)))
                ))
            }
        )
    }

    private var isCurrentPresentation: Bool {
        homeState?.selectedTab == .settings
            && homeState?.settings.isTraktWatchlistPresented == true
            && homeState?.settings.traktWatchlistPresentationRequestID == routeStore.requestID
    }

    private var isRouteActive: Bool {
        guard case let .settingsTraktWatchlist(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func close() {
        routeStore.send(.closeTapped)
    }

    private func closeIfStale() {
        guard !isCurrentPresentation, isRouteActive else { return }
        close()
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.settingsTraktWatchlistRouteDidDisappear(
            presentationID: routeStore.presentationID,
            homeRouteIndex: routeStore.homeRouteIndex,
            requestID: routeStore.requestID
        ))
    }
}

private struct SettingsHiddenContentRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<SettingsHiddenContentRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                HiddenContentManagementView(store: settingsStore)
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var homeState: HomeFeature.State? {
        let homeRouteIndex = routeStore.homeRouteIndex
        guard coordinatorStore.routes.indices.contains(homeRouteIndex),
              case let .home(state) = coordinatorStore.routes[homeRouteIndex].screen
        else { return nil }
        return state
    }

    private var settingsStore: StoreOf<SettingsFeature> {
        let homeRouteIndex = routeStore.homeRouteIndex
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = coordinatorState.routes[homeRouteIndex].screen
                else { return SettingsFeature.State() }
                return homeState.settings
            },
            action: { action in
                .router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.settings(action))
                ))
            }
        )
    }

    private var isCurrentPresentation: Bool {
        homeState?.selectedTab == .settings
            && homeState?.settings.isShowingHiddenContentSheet == true
            && homeState?.settings.hiddenContentPresentationRequestID == routeStore.requestID
    }

    private var isRouteActive: Bool {
        guard case let .settingsHiddenContent(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func closeIfStale() {
        guard !isCurrentPresentation, isRouteActive else { return }
        routeStore.send(.closeTapped)
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.settingsHiddenContentRouteDidDisappear(
            presentationID: routeStore.presentationID,
            homeRouteIndex: routeStore.homeRouteIndex,
            requestID: routeStore.requestID
        ))
    }
}

private struct SettingsDiagnosticReportRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<SettingsDiagnosticReportRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                DiagnosticReportPreviewView(url: routeStore.url, onClose: close)
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var homeState: HomeFeature.State? {
        let homeRouteIndex = routeStore.homeRouteIndex
        guard coordinatorStore.routes.indices.contains(homeRouteIndex),
              case let .home(state) = coordinatorStore.routes[homeRouteIndex].screen
        else { return nil }
        return state
    }

    private var isCurrentPresentation: Bool {
        homeState?.selectedTab == .settings
            && homeState?.settings.diagnosticReportPresentationRequestID == routeStore.requestID
            && homeState?.settings.diagnosticReportURL == routeStore.url
    }

    private var isRouteActive: Bool {
        guard case let .settingsDiagnosticReport(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func close() {
        routeStore.send(.closeTapped)
    }

    private func closeIfStale() {
        guard !isCurrentPresentation, isRouteActive else { return }
        close()
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.settingsDiagnosticReportRouteDidDisappear(
            presentationID: routeStore.presentationID,
            homeRouteIndex: routeStore.homeRouteIndex,
            requestID: routeStore.requestID
        ))
    }
}

private struct SettingsBackupPreviewRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<SettingsBackupPreviewRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation, let preview = homeState?.settings.backupPreview {
                NavigationStack {
                    List {
                        Section("Dosya bilgisi") {
                            LabeledContent("Uygulama sürümü", value: preview.appVersion)
                            LabeledContent("Yedek tarihi", value: preview.backupDate.formatted(date: .long, time: .shortened))
                            LabeledContent("Dosya boyutu", value: ByteCountFormatter.string(fromByteCount: Int64(preview.fileSizeBytes), countStyle: .file))
                        }
                        Section("Dahil edilen ayarlar") {
                            if preview.includedSettings.isEmpty {
                                Text("Bu yedekte geri yüklenecek ayar bulunamadı.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(preview.includedSettings, id: \.self) { setting in
                                    Text(setting)
                                }
                            }
                        }
                        Section("Üzerine yazılacaklar") {
                            Text("\(preview.existingSettingsToOverwrite) mevcut tercih değiştirilecek.")
                            Text("Yedekte bulunmayan ayarlar korunacak.")
                                .foregroundStyle(.secondary)
                        }
                        Section("Bütünlük kontrolü") {
                            Text(homeState?.settings.backupPreviewMessage ?? "JSON yapısı ve desteklenen ayar değerleri doğrulandı.")
                                .foregroundStyle(homeState?.settings.backupRestoreCompleted == true ? .green : .secondary)
                        }
                    }
                    .navigationTitle("Yedek Önizlemesi")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(AppStrings.Common.cancel, action: close)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            if homeState?.settings.backupRestoreCompleted == true {
                                Button("Bitti", action: close)
                            } else {
                                Button("Ayarları Geri Yükle", role: .destructive) {
                                    settingsStore.send(.restorePendingBackup(requestID: routeStore.requestID))
                                }
                                .disabled(
                                    preview.includedSettings.isEmpty
                                        || homeState?.settings.isBackupRestoreInProgress == true
                                )
                            }
                        }
                    }
                }
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var homeState: HomeFeature.State? {
        let homeRouteIndex = routeStore.homeRouteIndex
        guard coordinatorStore.routes.indices.contains(homeRouteIndex),
              case let .home(state) = coordinatorStore.routes[homeRouteIndex].screen
        else { return nil }
        return state
    }

    private var settingsStore: StoreOf<SettingsFeature> {
        let homeRouteIndex = routeStore.homeRouteIndex
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = coordinatorState.routes[homeRouteIndex].screen
                else { return SettingsFeature.State() }
                return homeState.settings
            },
            action: { action in
                .router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.settings(action))
                ))
            }
        )
    }

    private var isCurrentPresentation: Bool {
        homeState?.selectedTab == .settings
            && homeState?.settings.backupPreviewPresentationRequestID == routeStore.requestID
            && homeState?.settings.backupPreview != nil
            && homeState?.settings.pendingBackupURL != nil
    }

    private var isRouteActive: Bool {
        guard case let .settingsBackupPreview(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func close() {
        routeStore.send(.closeTapped)
    }

    private func closeIfStale() {
        guard !isCurrentPresentation, isRouteActive else { return }
        close()
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.settingsBackupPreviewRouteDidDisappear(
            presentationID: routeStore.presentationID,
            homeRouteIndex: routeStore.homeRouteIndex,
            requestID: routeStore.requestID
        ))
    }
}

private struct DetailSynopsisRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<DetailSynopsisRouteFeature>

    var body: some View {
        Group {
            if isCurrentParent {
                NavigationStack {
                    ScrollView {
                        Text(routeStore.text)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(32)
                    }
                    .background(Color.black.ignoresSafeArea())
                    .navigationTitle(AppStrings.VODDetail.overview)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(AppStrings.Common.done, action: close)
                        }
                    }
                }
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentParent) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var isCurrentParent: Bool {
        let parentRouteIndex = routeStore.parentRouteIndex
        guard coordinatorStore.routes.indices.contains(parentRouteIndex) else { return false }
        switch (routeStore.parent, coordinatorStore.routes[parentRouteIndex].screen) {
        case let (.vod(itemID), .vodDetail(vodState)):
            return vodState.vod.id == itemID
        case let (.series(itemID), .seriesDetail(seriesState)):
            return seriesState.series.id == itemID
        default:
            return false
        }
    }

    private var isRouteActive: Bool {
        guard case let .detailSynopsis(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func close() {
        routeStore.send(.closeTapped)
    }

    private func closeIfStale() {
        guard !isCurrentParent, isRouteActive else { return }
        close()
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.detailSynopsisRouteDidDisappear(
            presentationID: routeStore.presentationID,
            parentRouteIndex: routeStore.parentRouteIndex,
            parent: routeStore.parent,
            requestID: routeStore.requestID
        ))
    }
}

private struct DetailActorBiographyRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<DetailActorBiographyRouteFeature>

    var body: some View {
        Group {
            if let vodState, let actor = vodState.selectedActor {
                VODActorBiographyContent(
                    actor: actor,
                    details: vodState.selectedActorDetails,
                    isLoading: vodState.isLoadingActorDetails,
                    close: close
                )
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentParent) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var vodState: VODDetailFeature.State? {
        let parentRouteIndex = routeStore.parentRouteIndex
        guard coordinatorStore.routes.indices.contains(parentRouteIndex),
              case let .vodDetail(state) = coordinatorStore.routes[parentRouteIndex].screen,
              state.vod.id == routeStore.itemID,
              state.actorBiographyPresentationRequestID == routeStore.requestID
        else { return nil }
        return state
    }

    private var isCurrentParent: Bool {
        vodState?.selectedActor != nil
    }

    private var isRouteActive: Bool {
        guard case let .detailActorBiography(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func close() {
        routeStore.send(.closeTapped)
    }

    private func closeIfStale() {
        guard !isCurrentParent, isRouteActive else { return }
        close()
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.detailActorBiographyRouteDidDisappear(
            presentationID: routeStore.presentationID,
            parentRouteIndex: routeStore.parentRouteIndex,
            itemID: routeStore.itemID,
            requestID: routeStore.requestID
        ))
    }
}

private struct DetailTrailerRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<DetailTrailerRouteFeature>

    var body: some View {
        Group {
            if isCurrentParent {
                trailerContent
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentParent) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    @ViewBuilder
    private var trailerContent: some View {
        switch routeStore.parent {
        case .vod:
            if let vodState, let videoKey = vodState.trailerVideoKey {
                DetailTrailerRouteContent(
                    videoKey: videoKey,
                    close: close
                )
            }
        case .series:
            if let seriesState, let videoKey = seriesState.trailerVideoKey {
                DetailTrailerRouteContent(
                    videoKey: videoKey,
                    close: close
                )
            }
        }
    }

    private var vodState: VODDetailFeature.State? {
        let parentRouteIndex = routeStore.parentRouteIndex
        guard case let .vod(itemID) = routeStore.parent,
              coordinatorStore.routes.indices.contains(parentRouteIndex),
              case let .vodDetail(state) = coordinatorStore.routes[parentRouteIndex].screen,
              state.vod.id == itemID,
              state.trailerPresentationRequestID == routeStore.requestID,
              state.isTrailerPresented
        else { return nil }
        return state
    }

    private var seriesState: SeriesDetailFeature.State? {
        let parentRouteIndex = routeStore.parentRouteIndex
        guard case let .series(itemID) = routeStore.parent,
              coordinatorStore.routes.indices.contains(parentRouteIndex),
              case let .seriesDetail(state) = coordinatorStore.routes[parentRouteIndex].screen,
              state.series.id == itemID,
              state.trailerPresentationRequestID == routeStore.requestID,
              state.isTrailerPresented
        else { return nil }
        return state
    }

    private var isCurrentParent: Bool {
        switch routeStore.parent {
        case .vod:
            return vodState?.trailerVideoKey != nil
        case .series:
            return seriesState?.trailerVideoKey != nil
        }
    }

    private var isRouteActive: Bool {
        guard case let .detailTrailer(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func close() {
        routeStore.send(.closeTapped)
    }

    private func closeIfStale() {
        guard !isCurrentParent, isRouteActive else { return }
        close()
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.detailTrailerRouteDidDisappear(
            presentationID: routeStore.presentationID,
            parentRouteIndex: routeStore.parentRouteIndex,
            parent: routeStore.parent,
            requestID: routeStore.requestID
        ))
    }
}

private struct DetailUnmatchedMovieRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<DetailUnmatchedMovieRouteFeature>

    var body: some View {
        Group {
            if let state = vodState, let item = state.selectedUnmatchedMovie {
                VODUnmatchedMovieRouteContent(item: item, close: close)
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentParent) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var vodState: VODDetailFeature.State? {
        let parentRouteIndex = routeStore.parentRouteIndex
        guard coordinatorStore.routes.indices.contains(parentRouteIndex),
              case let .vodDetail(state) = coordinatorStore.routes[parentRouteIndex].screen,
              state.vod.id == routeStore.itemID,
              state.unmatchedMoviePresentationRequestID == routeStore.requestID,
              state.selectedUnmatchedMovie != nil
        else { return nil }
        return state
    }

    private var isCurrentParent: Bool {
        vodState?.selectedUnmatchedMovie != nil
    }

    private var isRouteActive: Bool {
        guard case let .detailUnmatchedMovie(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func close() {
        routeStore.send(.closeTapped)
    }

    private func closeIfStale() {
        guard !isCurrentParent, isRouteActive else { return }
        close()
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.detailUnmatchedMovieRouteDidDisappear(
            presentationID: routeStore.presentationID,
            parentRouteIndex: routeStore.parentRouteIndex,
            itemID: routeStore.itemID,
            requestID: routeStore.requestID
        ))
    }
}

private struct DetailTMDBMatchPickerRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<DetailTMDBMatchPickerRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                picker
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    @ViewBuilder
    private var picker: some View {
        switch routeStore.parent {
        case .vod:
            if let state = vodState {
                TMDBMatchPickerSheet(
                    results: state.tmdbSearchResults,
                    selectedTMDBID: state.selectedTMDBMatchID,
                    isLoading: state.isTMDBLoading,
                    search: sendSearch,
                    select: sendSelection,
                    clear: sendClear,
                    dismiss: close
                )
            }
        case .series:
            if let state = seriesState {
                TMDBMatchPickerSheet(
                    results: state.tmdbSearchResults,
                    selectedTMDBID: state.selectedTMDBMatchID,
                    isLoading: state.isTMDBLoading,
                    search: sendSearch,
                    select: sendSelection,
                    clear: sendClear,
                    dismiss: close
                )
            }
        }
    }

    private var vodState: VODDetailFeature.State? {
        let routeIndex = routeStore.detailRouteIndex
        guard coordinatorStore.routes.indices.contains(routeIndex),
              case let .vodDetail(state) = coordinatorStore.routes[routeIndex].screen,
              case let .vod(itemID) = routeStore.parent,
              state.vod.id == itemID,
              state.tmdbMatchPresentationRequestID == routeStore.requestID
        else { return nil }
        return state
    }

    private var seriesState: SeriesDetailFeature.State? {
        let routeIndex = routeStore.detailRouteIndex
        guard coordinatorStore.routes.indices.contains(routeIndex),
              case let .seriesDetail(state) = coordinatorStore.routes[routeIndex].screen,
              case let .series(itemID) = routeStore.parent,
              state.series.id == itemID,
              state.tmdbMatchPresentationRequestID == routeStore.requestID
        else { return nil }
        return state
    }

    private var isCurrentPresentation: Bool {
        switch routeStore.parent {
        case .vod:
            return vodState?.isTMDBMatchPickerPresented == true
        case .series:
            return seriesState?.isTMDBMatchPickerPresented == true
        }
    }

    private var isRouteActive: Bool {
        guard case let .detailTMDBMatchPicker(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func sendSearch(_ query: String) {
        let routeIndex = routeStore.detailRouteIndex
        switch routeStore.parent {
        case .vod:
            coordinatorStore.send(.router(.routeAction(
                id: routeIndex,
                action: .vodDetail(.manualTMDBSearch(query))
            )))
        case .series:
            coordinatorStore.send(.router(.routeAction(
                id: routeIndex,
                action: .seriesDetail(.manualTMDBSearch(query))
            )))
        }
    }

    private func sendSelection(_ tmdbID: Int) {
        let routeIndex = routeStore.detailRouteIndex
        switch routeStore.parent {
        case .vod:
            coordinatorStore.send(.router(.routeAction(
                id: routeIndex,
                action: .vodDetail(.selectTMDBMatch(tmdbID))
            )))
        case .series:
            coordinatorStore.send(.router(.routeAction(
                id: routeIndex,
                action: .seriesDetail(.selectTMDBMatch(tmdbID))
            )))
        }
    }

    private func sendClear() {
        let routeIndex = routeStore.detailRouteIndex
        switch routeStore.parent {
        case .vod:
            coordinatorStore.send(.router(.routeAction(
                id: routeIndex,
                action: .vodDetail(.clearTMDBMatchOverride)
            )))
        case .series:
            coordinatorStore.send(.router(.routeAction(
                id: routeIndex,
                action: .seriesDetail(.clearTMDBMatchOverride)
            )))
        }
    }

    private func close() {
        routeStore.send(.closeTapped)
    }

    private func closeIfStale() {
        guard isCurrentPresentation else {
            guard isRouteActive else { return }
            close()
            return
        }
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.detailTMDBMatchPickerRouteDidDisappear(
            presentationID: routeStore.presentationID,
            detailRouteIndex: routeStore.detailRouteIndex,
            parent: routeStore.parent,
            requestID: routeStore.requestID
        ))
    }
}

private struct CustomEPGSettingsRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<CustomEPGSettingsRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                CustomEPGSettingsView(store: settingsStore, onClose: close)
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var homeState: HomeFeature.State? {
        let homeRouteIndex = routeStore.homeRouteIndex
        guard coordinatorStore.routes.indices.contains(homeRouteIndex),
              case let .home(state) = coordinatorStore.routes[homeRouteIndex].screen
        else { return nil }
        return state
    }

    private var settingsStore: StoreOf<SettingsFeature> {
        let homeRouteIndex = routeStore.homeRouteIndex
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = coordinatorState.routes[homeRouteIndex].screen
                else { return SettingsFeature.State() }
                return homeState.settings
            },
            action: { action in
                .router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.settings(action))
                ))
            }
        )
    }

    private var isCurrentPresentation: Bool {
        homeState?.selectedTab == .settings
            && homeState?.settings.isCustomEPGSheetPresented == true
            && homeState?.settings.customEPGPresentationRequestID == routeStore.requestID
    }

    private var isRouteActive: Bool {
        guard case let .customEPGSettings(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func close() {
        routeStore.send(.closeTapped)
    }

    private func closeIfStale() {
        guard !isCurrentPresentation, isRouteActive else { return }
        close()
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.customEPGSettingsRouteDidDisappear(
            presentationID: routeStore.presentationID,
            homeRouteIndex: routeStore.homeRouteIndex,
            requestID: routeStore.requestID
        ))
    }
}

private struct CustomEPGSourceAddRouteView: View {
    @Bindable var coordinatorStore: StoreOf<AppCoordinator>
    let routeStore: StoreOf<CustomEPGSourceAddRouteFeature>

    var body: some View {
        Group {
            if isCurrentPresentation {
                CustomEPGSourceEntryView(store: settingsStore, onClose: close)
            }
        }
        .onAppear(perform: closeIfStale)
        .onChange(of: isCurrentPresentation) { _, isCurrent in
            if !isCurrent {
                closeIfStale()
            }
        }
        .onDisappear(perform: notifyRouteDidDisappear)
    }

    private var homeState: HomeFeature.State? {
        let homeRouteIndex = routeStore.homeRouteIndex
        guard coordinatorStore.routes.indices.contains(homeRouteIndex),
              case let .home(state) = coordinatorStore.routes[homeRouteIndex].screen
        else { return nil }
        return state
    }

    private var customEPGSettingsState: CustomEPGSettingsRouteFeature.State? {
        for route in coordinatorStore.routes {
            guard case let .customEPGSettings(state) = route.screen,
                  state.presentationID == routeStore.customEPGSettingsPresentationID
            else { continue }
            return state
        }
        return nil
    }

    private var settingsStore: StoreOf<SettingsFeature> {
        let homeRouteIndex = routeStore.homeRouteIndex
        return coordinatorStore.scope(
            state: { coordinatorState in
                guard coordinatorState.routes.indices.contains(homeRouteIndex),
                      case let .home(homeState) = coordinatorState.routes[homeRouteIndex].screen
                else { return SettingsFeature.State() }
                return homeState.settings
            },
            action: { action in
                .router(.routeAction(
                    id: homeRouteIndex,
                    action: .home(.settings(action))
                ))
            }
        )
    }

    private var isCurrentPresentation: Bool {
        guard let homeState,
              let customEPGSettingsState,
              customEPGSettingsState.homeRouteIndex == routeStore.homeRouteIndex
        else { return false }
        return homeState.selectedTab == .settings
            && homeState.settings.isCustomEPGSheetPresented
            && homeState.settings.customEPGPresentationRequestID == customEPGSettingsState.requestID
            && homeState.settings.isAddCustomEPGSourceSheetPresented
            && homeState.settings.customEPGSourceAddPresentationRequestID == routeStore.requestID
    }

    private var isRouteActive: Bool {
        guard case let .customEPGSourceAdd(state) = coordinatorStore.routes.last?.screen
        else { return false }
        return state.presentationID == routeStore.presentationID && state.requestID == routeStore.requestID
    }

    private func close() {
        routeStore.send(.closeTapped)
    }

    private func closeIfStale() {
        guard !isCurrentPresentation, isRouteActive else { return }
        close()
    }

    private func notifyRouteDidDisappear() {
        coordinatorStore.send(.customEPGSourceAddRouteDidDisappear(
            presentationID: routeStore.presentationID,
            customEPGSettingsPresentationID: routeStore.customEPGSettingsPresentationID,
            homeRouteIndex: routeStore.homeRouteIndex,
            requestID: routeStore.requestID
        ))
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
