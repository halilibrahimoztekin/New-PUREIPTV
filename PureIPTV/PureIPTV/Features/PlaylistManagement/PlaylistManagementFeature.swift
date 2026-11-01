import ComposableArchitecture
import FactoryKit
import Foundation

@Reducer
public struct PlaylistManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public enum PlaylistStoreStatus: Equatable {
            case available
            case empty
            case unavailable
        }

        public enum PINFlow: Equatable, Sendable {
            case configure(UUID)
            case activate(UUID)
            case remove(UUID)
            case startup(UUID)
        }

        public enum UpdateSourceKind: Equatable, Sendable {
            case playlistCatalog(UUID)
            case providerEPG(UUID)
            case customEPG(String)

            public var id: String {
                switch self {
                case let .playlistCatalog(id): "catalog:\(id.uuidString)"
                case let .providerEPG(id): "provider-epg:\(id.uuidString)"
                case let .customEPG(id): "custom-epg:\(id)"
                }
            }
        }

        public enum UpdateSourceStatus: Equatable, Sendable {
            case ready
            case queued
            case updating(String)
            case succeeded
            case failed
            case unavailable
        }

        public struct UpdateSource: Equatable, Identifiable, Sendable {
            public let kind: UpdateSourceKind
            public let title: String
            public var status: UpdateSourceStatus

            public var id: String {
                kind.id
            }

            public init(kind: UpdateSourceKind, title: String, status: UpdateSourceStatus = .ready) {
                self.kind = kind
                self.title = title
                self.status = status
            }
        }

        public var playlists: [SavedPlaylist] = []
        public var playlistStoreStatus: PlaylistStoreStatus = .empty
        public var activePlaylistID: UUID?
        public var defaultStartupPlaylistID: UUID?
        public var updateSources: [UpdateSource] = []
        public var isUpdatingSources = false
        public var sourceUpdateRequestID: UUID?
        public var lockedPlaylistIDs: Set<UUID> = []
        public var unlockedPlaylistIDs: Set<UUID> = []
        public var contentSourceSelection = PlaylistContentSourceSelection()
        public var contentSourceProfileContext: ProfileContextSnapshot?
        public var startupUnlockPlaylistID: UUID?
        public var pinFlow: PINFlow?
        public var playlistPIN = ""
        public var playlistPINConfirmation = ""
        public var playlistPINError: String?
        public var pinPresentationRequestID: UUID?
        public var playlistToDelete: SavedPlaylist?
        public var playlistBeingEdited: SavedPlaylist?
        public var playlistSettingsEditRequestID: UUID?
        public var userAgentDraft = ""
        public var channelZappingDelayDraft = 0
        public var automaticCatalogRefreshEnabledDraft = true
        public var refreshScheduleDraft = PlaylistRefreshSchedule()
        public var refreshScheduleProfileIDDraft: UUID?
        public var playlistCloudSyncEnabledDraft = true
        public var mediaServerPlaybackPreferenceDraft: MediaServerPlaybackPreference = .automatic
        public var serverURLDraft = ""
        public var usernameDraft = ""
        public var passwordDraft = ""
        public var m3uURLDraft = ""
        public var playlistValidationMessage: String?
        public var isRefreshingPlaylist = false
        public var isCheckingPlaylistHealth = false
        public var playlistHealthCheckRequestID: UUID?
        public var playlistHealthReport: PlaylistHealthReport?
        public var addPlaylistPresentationRequestID: UUID?
        @Presents public var addPlaylist: AddPlaylistFeature.State?

        public var canSaveUserAgentDraft: Bool {
            let value = userAgentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.utf8.count <= 512
                && value.rangeOfCharacter(from: .controlCharacters) == nil
        }

        public var assignableContentPlaylists: [SavedPlaylist] {
            playlists.filter { !lockedPlaylistIDs.contains($0.id) || unlockedPlaylistIDs.contains($0.id) }
        }

        public init(startupUnlockPlaylistID: UUID? = nil, unlockedPlaylistIDs: Set<UUID> = []) {
            self.startupUnlockPlaylistID = startupUnlockPlaylistID
            self.unlockedPlaylistIDs = unlockedPlaylistIDs
        }
    }

    public enum Action: BindableAction {
        case onAppear
        case refreshPlaylistStore
        case viewDidDisappear
        case binding(BindingAction<State>)
        case setActivePlaylist(UUID)
        case setDefaultStartupPlaylist(UUID?)
        case updateAllSources
        case cancelSourceUpdates
        case updateSourceTapped(String)
        case performSourceUpdates(requestID: UUID, sources: [State.UpdateSource], playlists: [SavedPlaylist])
        case updateSourceStarted(requestID: UUID, id: String)
        case updateSourceProgress(requestID: UUID, id: String, stage: String)
        case updateSourceFinished(requestID: UUID, id: String, status: State.UpdateSourceStatus)
        case providerEPGAvailabilityChanged(requestID: UUID, playlistID: UUID, isAvailable: Bool)
        case sourceUpdatesCompleted(requestID: UUID)
        case setContentSource(area: PlaylistContentArea, playlistID: UUID?)
        case playlistLockTapped(UUID)
        case playlistPINChanged(String)
        case playlistPINConfirmationChanged(String)
        case submitPlaylistPIN
        case cancelPlaylistPIN
        case editPlaylistSettings(SavedPlaylist)
        case setPlaylistCloudSyncEnabled(UUID, Bool)
        case checkPlaylistHealth
        case playlistHealthCheckCompleted(requestID: UUID, report: PlaylistHealthReport)
        case savePlaylistSettings
        case playlistSettingsSaveSucceeded(requestID: UUID, playlist: SavedPlaylist)
        case playlistSettingsSaveFailed(requestID: UUID, message: String)
        case cancelPlaylistSettings
        case deletePlaylist(UUID)
        case confirmDeletePlaylist(SavedPlaylist)
        case cancelDeletePlaylist
        case deletePlaylistConfirmed
        case addPlaylistButtonTapped
        case closeAddPlaylistTapped(requestID: UUID)
        case addPlaylist(PresentationAction<AddPlaylistFeature.Action>)
        case closeTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case didChangeActivePlaylist
            case didChangeContentPlaylistSources(ProfileContextSnapshot)
            case didUpdateActivePlaylistSettings(PlaylistConfig)
            case didUpdatePlaylistSettings(SavedPlaylist, ProfileContextSnapshot)
            case presentPlaylistSettings(requestID: UUID, playlistID: UUID)
            case presentPlaylistPIN(requestID: UUID, flow: State.PINFlow)
            case didChangePlaylistLock(UUID, isLocked: Bool)
            case didUnlockPlaylist(UUID)
            case didUnlockStartupPlaylist(UUID)
            case addPlaylistTapped
            case presentAddPlaylist(requestID: UUID)
            case presentAddPlaylistQRTransfer(requestID: UUID)
            case addPlaylistDidConnect
            case dismissed
        }
    }

    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.dismiss) var dismiss
    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.customEPGMappingClient) var customEPGMappingClient
    @Dependency(\.playlistHealthClient) var playlistHealthClient
    @Dependency(\.parentalControlClient) var parentalControlClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.playlistRefreshScheduleClient) var playlistRefreshScheduleClient
    @Dependency(\.cloudSyncClient) var cloudSyncClient
    @Dependency(\.playlistContentSourceClient) var playlistContentSourceClient

    public init() {}

    private static func isValidHTTPURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty
        else { return false }
        return true
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                Self.refreshPlaylistStore(
                    state: &state,
                    repository: playlistRepository,
                    customEPGMappingClient: customEPGMappingClient
                )
                state.activePlaylistID = playlistRepository.getActivePlaylistID()
                state.lockedPlaylistIDs = Set(state.playlists.filter { parentalControlClient.isPlaylistLocked($0.id) }.map(\.id))
                let profileContext = profileContextClient.snapshot()
                state.contentSourceProfileContext = profileContext
                state.contentSourceSelection = playlistContentSourceClient.load(profileContext.profileID)
                if let startupID = state.startupUnlockPlaylistID,
                   state.lockedPlaylistIDs.contains(startupID)
                {
                    if state.pinFlow == .startup(startupID), state.pinPresentationRequestID != nil {
                        return .none
                    }
                    let requestID = UUID()
                    state.pinFlow = .startup(startupID)
                    state.pinPresentationRequestID = requestID
                    state.playlistPIN = ""
                    state.playlistPINError = nil
                    return .send(.delegate(.presentPlaylistPIN(
                        requestID: requestID,
                        flow: .startup(startupID)
                    )))
                }
                return .none

            case .refreshPlaylistStore:
                Self.refreshPlaylistStore(
                    state: &state,
                    repository: playlistRepository,
                    customEPGMappingClient: customEPGMappingClient
                )
                return .none

            case .updateAllSources:
                guard !state.isUpdatingSources else { return .none }
                let sources = state.updateSources.filter { source in
                    if case .customEPG = source.kind {
                        return true
                    }
                    return state.playlistStoreStatus == .available
                }
                guard !sources.isEmpty else { return .none }
                let requestID = UUID()
                state.isUpdatingSources = true
                state.sourceUpdateRequestID = requestID
                for index in state.updateSources.indices where sources.contains(where: { $0.id == state.updateSources[index].id }) {
                    state.updateSources[index].status = .queued
                }
                return .send(.performSourceUpdates(requestID: requestID, sources: sources, playlists: state.playlists))

            case .cancelSourceUpdates:
                guard state.sourceUpdateRequestID != nil else { return .none }
                state.isUpdatingSources = false
                state.sourceUpdateRequestID = nil
                for index in state.updateSources.indices {
                    switch state.updateSources[index].status {
                    case .queued, .updating:
                        state.updateSources[index].status = .ready
                    case .ready, .succeeded, .failed, .unavailable:
                        break
                    }
                }
                return .cancel(id: "PlaylistManagementFeature.sourceUpdates")

            case let .updateSourceTapped(id):
                guard !state.isUpdatingSources,
                      let sourceIndex = state.updateSources.firstIndex(where: { $0.id == id })
                else { return .none }
                let source = state.updateSources[sourceIndex]
                if case .unavailable = source.status {
                    return .none
                }
                if case .customEPG = source.kind {} else if state.playlistStoreStatus != .available {
                    return .none
                }
                let requestID = UUID()
                state.updateSources[sourceIndex].status = .queued
                state.isUpdatingSources = true
                state.sourceUpdateRequestID = requestID
                return .send(.performSourceUpdates(requestID: requestID, sources: [source], playlists: state.playlists))

            case let .performSourceUpdates(requestID, sources, playlists):
                guard state.sourceUpdateRequestID == requestID else { return .none }
                return .run { [iptvClient, customEPGMappingClient] send in
                    var providerEPGAvailability: [UUID: Bool] = [:]
                    for source in sources {
                        guard !Task.isCancelled else {
                            await send(.sourceUpdatesCompleted(requestID: requestID))
                            return
                        }
                        await send(.updateSourceStarted(requestID: requestID, id: source.id))
                        do {
                            let result: State.UpdateSourceStatus
                            switch source.kind {
                            case let .playlistCatalog(playlistID):
                                guard let playlist = playlists.first(where: { $0.id == playlistID }),
                                      let config = playlist.toPlaylistConfig()
                                else {
                                    throw NetworkError.invalidURL
                                }
                                let hasEPGSource = try await iptvClient.refreshCatalog(config) { stage in
                                    await send(.updateSourceProgress(requestID: requestID, id: source.id, stage: stage.title))
                                }
                                providerEPGAvailability[playlistID] = hasEPGSource
                                await send(.providerEPGAvailabilityChanged(
                                    requestID: requestID,
                                    playlistID: playlistID,
                                    isAvailable: hasEPGSource
                                ))
                                result = .succeeded

                            case let .providerEPG(playlistID):
                                if providerEPGAvailability[playlistID] == false {
                                    result = .unavailable
                                    break
                                }
                                guard let playlist = playlists.first(where: { $0.id == playlistID }),
                                      let config = playlist.toPlaylistConfig()
                                else {
                                    throw NetworkError.invalidURL
                                }
                                result = try await iptvClient.refreshEPGCacheIfAvailable(config) ? .succeeded : .unavailable

                            case let .customEPG(sourceID):
                                _ = try await customEPGMappingClient.refreshSource(sourceID)
                                result = .succeeded
                            }
                            await send(.updateSourceFinished(requestID: requestID, id: source.id, status: result))
                        } catch is CancellationError {
                            await send(.sourceUpdatesCompleted(requestID: requestID))
                            return
                        } catch {
                            await send(.updateSourceFinished(requestID: requestID, id: source.id, status: .failed))
                        }
                    }
                    await send(.sourceUpdatesCompleted(requestID: requestID))
                }
                .cancellable(id: "PlaylistManagementFeature.sourceUpdates", cancelInFlight: true)

            case let .updateSourceStarted(requestID, id):
                guard state.sourceUpdateRequestID == requestID else { return .none }
                guard let index = state.updateSources.firstIndex(where: { $0.id == id }) else { return .none }
                state.updateSources[index].status = .updating(AppStrings.Common.loadingAlt)
                return .none

            case let .updateSourceProgress(requestID, id, stage):
                guard state.sourceUpdateRequestID == requestID else { return .none }
                guard let index = state.updateSources.firstIndex(where: { $0.id == id }) else { return .none }
                state.updateSources[index].status = .updating(stage)
                return .none

            case let .updateSourceFinished(requestID, id, status):
                guard state.sourceUpdateRequestID == requestID else { return .none }
                guard let index = state.updateSources.firstIndex(where: { $0.id == id }) else { return .none }
                state.updateSources[index].status = status
                return .none

            case let .providerEPGAvailabilityChanged(requestID, playlistID, isAvailable):
                guard state.sourceUpdateRequestID == requestID else { return .none }
                let id = State.UpdateSourceKind.providerEPG(playlistID).id
                guard let index = state.updateSources.firstIndex(where: { $0.id == id }) else { return .none }
                if !isAvailable {
                    state.updateSources[index].status = .unavailable
                } else if case .unavailable = state.updateSources[index].status {
                    state.updateSources[index].status = .ready
                }
                return .none

            case let .sourceUpdatesCompleted(requestID):
                guard state.sourceUpdateRequestID == requestID else { return .none }
                state.isUpdatingSources = false
                state.sourceUpdateRequestID = nil
                for index in state.updateSources.indices {
                    switch state.updateSources[index].status {
                    case .queued, .updating:
                        state.updateSources[index].status = .ready
                    case .ready, .succeeded, .failed, .unavailable:
                        break
                    }
                }
                return .none

            case let .setContentSource(area, playlistID):
                guard state.startupUnlockPlaylistID == nil,
                      state.playlistStoreStatus == .available,
                      let profileContext = state.contentSourceProfileContext,
                      profileContextClient.snapshot() == profileContext
                else { return .none }
                if let playlistID {
                    guard state.assignableContentPlaylists.contains(where: { $0.id == playlistID }),
                          state.playlists.first(where: { $0.id == playlistID })?.toPlaylistConfig() != nil
                    else { return .none }
                }
                guard state.contentSourceSelection.playlistID(for: area) != playlistID else { return .none }
                var selection = state.contentSourceSelection
                selection.setPlaylistID(playlistID, for: area)
                playlistContentSourceClient.save(selection, profileContext.profileID)
                state.contentSourceSelection = selection
                return .send(.delegate(.didChangeContentPlaylistSources(profileContext)))

            case let .setDefaultStartupPlaylist(id):
                guard state.playlistStoreStatus == .available else { return .none }
                if let id {
                    guard state.playlists.contains(where: { $0.id == id }) else { return .none }
                } else if state.defaultStartupPlaylistID == nil {
                    return .none
                }
                playlistRepository.setDefaultStartupPlaylistID(id)
                state.defaultStartupPlaylistID = id
                return .none

            case .viewDidDisappear:
                state.isRefreshingPlaylist = false
                state.isCheckingPlaylistHealth = false
                state.playlistHealthCheckRequestID = nil
                state.isUpdatingSources = false
                state.sourceUpdateRequestID = nil
                for index in state.updateSources.indices {
                    switch state.updateSources[index].status {
                    case .queued, .updating:
                        state.updateSources[index].status = .ready
                    case .ready, .succeeded, .failed, .unavailable:
                        break
                    }
                }
                return .merge(
                    .cancel(id: "PlaylistManagementFeature.connectionValidation"),
                    .cancel(id: "PlaylistManagementFeature.healthCheck"),
                    .cancel(id: "PlaylistManagementFeature.sourceUpdates")
                )

            case .closeTapped:
                guard state.startupUnlockPlaylistID == nil else { return .none }
                return .send(.delegate(.dismissed))

            case .binding:
                state.playlistHealthReport = nil
                guard state.isCheckingPlaylistHealth else { return .none }
                state.isCheckingPlaylistHealth = false
                state.playlistHealthCheckRequestID = nil
                return .cancel(id: "PlaylistManagementFeature.healthCheck")

            case let .setActivePlaylist(id):
                guard !state.isUpdatingSources,
                      state.activePlaylistID != id
                else { return .none }
                if state.lockedPlaylistIDs.contains(id), !state.unlockedPlaylistIDs.contains(id) {
                    let flow = State.PINFlow.activate(id)
                    let requestID = UUID()
                    state.pinFlow = flow
                    state.pinPresentationRequestID = requestID
                    state.playlistPIN = ""
                    state.playlistPINConfirmation = ""
                    state.playlistPINError = nil
                    return .send(.delegate(.presentPlaylistPIN(requestID: requestID, flow: flow)))
                }
                playlistRepository.setActivePlaylistID(id)
                state.activePlaylistID = id
                return .send(.delegate(.didChangeActivePlaylist))

            case let .playlistLockTapped(id):
                guard !state.isUpdatingSources,
                      state.playlists.contains(where: { $0.id == id })
                else { return .none }
                let flow = state.lockedPlaylistIDs.contains(id) ? State.PINFlow.remove(id) : .configure(id)
                let requestID = UUID()
                state.pinFlow = flow
                state.pinPresentationRequestID = requestID
                state.playlistPIN = ""
                state.playlistPINConfirmation = ""
                state.playlistPINError = nil
                return .send(.delegate(.presentPlaylistPIN(requestID: requestID, flow: flow)))

            case let .playlistPINChanged(input):
                state.playlistPIN = String(input.filter { $0 >= "0" && $0 <= "9" }.prefix(4))
                state.playlistPINError = nil
                return .none

            case let .playlistPINConfirmationChanged(input):
                state.playlistPINConfirmation = String(input.filter { $0 >= "0" && $0 <= "9" }.prefix(4))
                state.playlistPINError = nil
                return .none

            case .submitPlaylistPIN:
                guard let flow = state.pinFlow else { return .none }
                let pin = state.playlistPIN
                switch flow {
                case let .configure(id):
                    guard pin.count == 4 else {
                        state.playlistPINError = "PIN 4 rakamdan oluşmalı."
                        return .none
                    }
                    guard pin == state.playlistPINConfirmation else {
                        state.playlistPINError = "PIN değerleri eşleşmiyor."
                        return .none
                    }
                    guard parentalControlClient.setPlaylistPIN(id, pin) else {
                        state.playlistPINError = "PIN güvenli olarak kaydedilemedi."
                        return .none
                    }
                    parentalControlClient.clearPlaylistPINFailures(id)
                    state.lockedPlaylistIDs.insert(id)
                    state.pinFlow = nil
                    state.pinPresentationRequestID = nil
                    state.playlistPIN = ""
                    state.playlistPINConfirmation = ""
                    return .send(.delegate(.didChangePlaylistLock(id, isLocked: true)))

                case let .activate(id), let .startup(id), let .remove(id):
                    let remainingSeconds = parentalControlClient.playlistPINLockoutRemainingSeconds(id)
                    guard remainingSeconds == 0 else {
                        state.playlistPINError = "Çok fazla hatalı deneme. \(remainingSeconds) saniye sonra tekrar deneyin."
                        state.playlistPIN = ""
                        return .none
                    }
                    guard pin.count == 4, parentalControlClient.verifyPlaylistPIN(id, pin) else {
                        let lockoutSeconds = parentalControlClient.recordPlaylistPINFailure(id)
                        state.playlistPINError = "PIN yanlış. Tekrar deneyin."
                        if lockoutSeconds > 0 {
                            state.playlistPINError = "Çok fazla hatalı deneme. \(lockoutSeconds) saniye sonra tekrar deneyin."
                        }
                        state.playlistPIN = ""
                        return .none
                    }
                    parentalControlClient.clearPlaylistPINFailures(id)
                    state.playlistPIN = ""
                    switch flow {
                    case .activate:
                        state.unlockedPlaylistIDs.insert(id)
                        playlistRepository.setActivePlaylistID(id)
                        state.activePlaylistID = id
                        state.pinFlow = nil
                        state.pinPresentationRequestID = nil
                        return .send(.delegate(.didUnlockPlaylist(id)))
                    case .startup:
                        state.unlockedPlaylistIDs.insert(id)
                        state.pinFlow = nil
                        state.pinPresentationRequestID = nil
                        state.startupUnlockPlaylistID = nil
                        return .send(.delegate(.didUnlockStartupPlaylist(id)))
                    case .remove:
                        guard parentalControlClient.setPlaylistPIN(id, nil) else {
                            state.playlistPINError = "PIN kilidi kaldırılamadı."
                            return .none
                        }
                        state.lockedPlaylistIDs.remove(id)
                        state.unlockedPlaylistIDs.remove(id)
                        state.pinFlow = nil
                        state.pinPresentationRequestID = nil
                        return .send(.delegate(.didChangePlaylistLock(id, isLocked: false)))
                    case .configure:
                        return .none
                    }
                }

            case .cancelPlaylistPIN:
                if case .startup = state.pinFlow {
                    return .none
                }
                state.pinFlow = nil
                state.pinPresentationRequestID = nil
                state.playlistPIN = ""
                state.playlistPINConfirmation = ""
                state.playlistPINError = nil
                return .none

            case let .editPlaylistSettings(playlist):
                guard !state.isUpdatingSources else { return .none }
                guard let currentPlaylist = state.playlists.first(where: { $0.id == playlist.id }) else { return .none }
                let profileID = profileContextClient.snapshot().profileID
                let defaultEPGInterval = settingsClient.autoUpdateEPG()
                    ? PlaylistRefreshInterval.epgInterval(for: settingsClient.epgAutoRefreshInterval())
                    : .disabled
                var refreshSchedule = PlaylistRefreshSchedule(epg: defaultEPGInterval)
                for target in PlaylistRefreshTarget.allCases {
                    refreshSchedule[target] = playlistRefreshScheduleClient.interval(
                        profileID,
                        currentPlaylist.id,
                        target,
                        target == .epg ? defaultEPGInterval : target.defaultInterval
                    )
                }
                let requestID = UUID()
                state.playlistBeingEdited = currentPlaylist
                state.playlistSettingsEditRequestID = requestID
                state.userAgentDraft = currentPlaylist.userAgentOverride ?? ""
                state.channelZappingDelayDraft = currentPlaylist.channelZappingDelayMilliseconds ?? 0
                state.automaticCatalogRefreshEnabledDraft = currentPlaylist.isAutomaticCatalogRefreshEnabled
                state.refreshScheduleDraft = refreshSchedule
                state.refreshScheduleProfileIDDraft = profileID
                state.playlistCloudSyncEnabledDraft = cloudSyncClient.isPlaylistSyncEnabled(currentPlaylist.id)
                state.mediaServerPlaybackPreferenceDraft = currentPlaylist.mediaServerPlaybackPreference ?? .automatic
                state.serverURLDraft = currentPlaylist.serverURL ?? ""
                state.usernameDraft = currentPlaylist.username ?? ""
                state.passwordDraft = currentPlaylist.password ?? ""
                state.m3uURLDraft = currentPlaylist.m3uURL ?? ""
                state.playlistValidationMessage = nil
                state.isCheckingPlaylistHealth = false
                state.playlistHealthCheckRequestID = nil
                state.playlistHealthReport = nil
                return .merge(
                    .send(.delegate(.presentPlaylistSettings(requestID: requestID, playlistID: currentPlaylist.id))),
                    .cancel(id: "PlaylistManagementFeature.healthCheck")
                )

            case let .setPlaylistCloudSyncEnabled(playlistID, isEnabled):
                guard state.playlistBeingEdited?.id == playlistID else { return .none }
                let previousValue = state.playlistCloudSyncEnabledDraft
                guard playlistRepository.setPlaylistCloudSyncEnabled(playlistID, enabled: isEnabled) else {
                    state.playlistValidationMessage = "iCloud tercihi kaydedilemedi; mevcut playlist ayarları korundu."
                    return .none
                }
                state.playlistCloudSyncEnabledDraft = isEnabled
                state.playlistValidationMessage = nil
                guard previousValue != isEnabled else { return .none }
                return .run { _ in
                    await cloudSyncClient.setPlaylistSyncEnabled(playlistID, isEnabled)
                }

            case .checkPlaylistHealth:
                guard !state.isCheckingPlaylistHealth,
                      !state.isRefreshingPlaylist,
                      let playlist = state.playlistBeingEdited else { return .none }
                let requestID = UUID()
                guard let config = Self.playlistHealthConfig(state: state, playlist: playlist) else {
                    let report = Self.invalidPlaylistHealthReport(for: playlist.type)
                    state.playlistHealthReport = report
                    return .run { _ in
                        await FeedbackReportManager.shared.recordPlaylistHealthReport(report)
                    }
                }
                state.isCheckingPlaylistHealth = true
                state.playlistHealthCheckRequestID = requestID
                state.playlistHealthReport = nil
                return .run { [playlistHealthClient] send in
                    do {
                        let report = try await playlistHealthClient.inspect(config)
                        await send(.playlistHealthCheckCompleted(requestID: requestID, report: report))
                    } catch is CancellationError {
                        return
                    } catch {
                        let report = Self.unexpectedPlaylistHealthFailure(for: playlist.type)
                        await send(.playlistHealthCheckCompleted(requestID: requestID, report: report))
                    }
                }.cancellable(id: "PlaylistManagementFeature.healthCheck", cancelInFlight: true)

            case let .playlistHealthCheckCompleted(requestID, report):
                guard state.playlistHealthCheckRequestID == requestID,
                      state.playlistBeingEdited?.type == report.playlistType else { return .none }
                state.isCheckingPlaylistHealth = false
                state.playlistHealthCheckRequestID = nil
                state.playlistHealthReport = report
                return .run { _ in
                    await FeedbackReportManager.shared.recordPlaylistHealthReport(report)
                }

            case .savePlaylistSettings:
                guard !state.isRefreshingPlaylist,
                      !state.isCheckingPlaylistHealth,
                      let requestID = state.playlistSettingsEditRequestID,
                      let playlist = state.playlistBeingEdited
                else { return .none }
                let value = state.userAgentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard
                    value.utf8.count <= 512,
                    value.rangeOfCharacter(from: .controlCharacters) == nil
                else {
                    state.playlistValidationMessage = "User-Agent 512 baytı aşamaz ve kontrol karakteri içeremez."
                    return .none
                }
                let serverURL = state.serverURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                let username = state.usernameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                let m3uURL = state.m3uURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                let serverBackedType = playlist.type == .xtream || playlist.type == .plex || playlist.type == .emby
                let updatedPlaylist = playlist
                    .replacingConnection(
                        serverURL: serverBackedType ? serverURL : nil,
                        username: playlist.type == .xtream ? username : playlist.username,
                        password: playlist.type == .xtream ? state.passwordDraft : playlist.password,
                        m3uURL: playlist.type == .m3u ? m3uURL : playlist.m3uURL
                    )
                    .replacingMediaServerPlaybackPreference(
                        playlist.type == .emby
                            ? state.mediaServerPlaybackPreferenceDraft
                            : playlist.mediaServerPlaybackPreference
                    )
                    .replacingUserAgentOverride(value.isEmpty ? nil : value)
                    .replacingChannelZappingDelayMilliseconds(state.channelZappingDelayDraft)
                    .replacingAutomaticCatalogRefreshOnStartup(state.automaticCatalogRefreshEnabledDraft)
                let defaultEPGInterval = settingsClient.autoUpdateEPG()
                    ? PlaylistRefreshInterval.epgInterval(for: settingsClient.epgAutoRefreshInterval())
                    : .disabled
                let refreshScheduleChanged = PlaylistRefreshTarget.allCases.contains { target in
                    let defaultInterval = target == .epg ? defaultEPGInterval : target.defaultInterval
                    return playlistRefreshScheduleClient.interval(
                        state.refreshScheduleProfileIDDraft,
                        playlist.id,
                        target,
                        defaultInterval
                    ) != state.refreshScheduleDraft[target]
                }
                let nonScheduleSettingsUnchanged =
                    updatedPlaylist.serverURL == playlist.serverURL
                        && updatedPlaylist.username == playlist.username
                        && updatedPlaylist.password == playlist.password
                        && updatedPlaylist.xtreamLiveOutputFormat == playlist.xtreamLiveOutputFormat
                        && updatedPlaylist.m3uURL == playlist.m3uURL
                        && updatedPlaylist.mediaServerCredentials == playlist.mediaServerCredentials
                        && (updatedPlaylist.mediaServerPlaybackPreference ?? .automatic)
                        == (playlist.mediaServerPlaybackPreference ?? .automatic)
                        && updatedPlaylist.userAgentOverride == playlist.userAgentOverride
                        && (updatedPlaylist.channelZappingDelayMilliseconds ?? 0)
                        == (playlist.channelZappingDelayMilliseconds ?? 0)
                        && updatedPlaylist.isAutomaticCatalogRefreshEnabled == playlist.isAutomaticCatalogRefreshEnabled
                if refreshScheduleChanged, nonScheduleSettingsUnchanged {
                    state.playlistValidationMessage = nil
                    return .send(.playlistSettingsSaveSucceeded(requestID: requestID, playlist: updatedPlaylist))
                }
                switch playlist.type {
                case .xtream:
                    guard Self.isValidHTTPURL(serverURL), !username.isEmpty, !state.passwordDraft.isEmpty else {
                        state.playlistValidationMessage = "Xtream adresi, kullanıcı adı ve parola geçerli olmalı."
                        return .none
                    }
                case .m3u:
                    guard Self.isValidHTTPURL(m3uURL) else {
                        state.playlistValidationMessage = "M3U adresi geçerli bir HTTP veya HTTPS URL olmalı."
                        return .none
                    }
                case .plex, .emby:
                    guard Self.isValidHTTPURL(serverURL) else {
                        state.playlistValidationMessage = "Media server adresi geçerli bir HTTPS URL olmalı."
                        return .none
                    }
                }
                if updatedPlaylist.type == .m3u || updatedPlaylist.type == .plex || updatedPlaylist.type == .emby {
                    guard let config = updatedPlaylist.toPlaylistConfig() else {
                        state.playlistValidationMessage = "Playlist bağlantı ayarları geçerli değil."
                        return .none
                    }
                    if updatedPlaylist.type == .plex || updatedPlaylist.type == .emby,
                       MediaServerRequestContextFactory.baseURL(for: config) == nil
                    {
                        state.playlistValidationMessage = "Plex/Emby sunucusu güvenli HTTPS bağlantısıyla doğrulanmalı."
                        return .none
                    }
                    state.isRefreshingPlaylist = true
                    state.playlistValidationMessage = nil
                    return .run { [iptvClient] send in
                        do {
                            try await iptvClient.authenticate(config)
                            await send(.playlistSettingsSaveSucceeded(requestID: requestID, playlist: updatedPlaylist))
                        } catch is CancellationError {
                            return
                        } catch {
                            await send(.playlistSettingsSaveFailed(
                                requestID: requestID,
                                message: error.localizedDescription
                            ))
                        }
                    }.cancellable(id: "PlaylistManagementFeature.connectionValidation", cancelInFlight: true)
                }
                return .send(.playlistSettingsSaveSucceeded(requestID: requestID, playlist: updatedPlaylist))

            case let .playlistSettingsSaveSucceeded(requestID, updatedPlaylist):
                guard state.playlistSettingsEditRequestID == requestID,
                      state.playlistBeingEdited?.id == updatedPlaylist.id
                else { return .none }
                state.isRefreshingPlaylist = false
                guard playlistRepository.updatePlaylist(updatedPlaylist) else {
                    state.playlistValidationMessage = "Ayarlar güvenli olarak kaydedilemedi. iCloud Keychain erişimini kontrol edip tekrar deneyin."
                    return .none
                }
                for target in PlaylistRefreshTarget.allCases {
                    playlistRefreshScheduleClient.setInterval(
                        state.refreshScheduleDraft[target],
                        state.refreshScheduleProfileIDDraft,
                        updatedPlaylist.id,
                        target
                    )
                }
                Self.refreshPlaylistStore(
                    state: &state,
                    repository: playlistRepository,
                    customEPGMappingClient: customEPGMappingClient
                )
                state.playlistBeingEdited = nil
                state.playlistSettingsEditRequestID = nil
                state.userAgentDraft = ""
                state.channelZappingDelayDraft = 0
                state.automaticCatalogRefreshEnabledDraft = true
                state.refreshScheduleDraft = PlaylistRefreshSchedule()
                state.refreshScheduleProfileIDDraft = nil
                state.playlistCloudSyncEnabledDraft = true
                state.mediaServerPlaybackPreferenceDraft = .automatic
                state.serverURLDraft = ""
                state.usernameDraft = ""
                state.passwordDraft = ""
                state.m3uURLDraft = ""
                state.playlistValidationMessage = nil
                state.isCheckingPlaylistHealth = false
                state.playlistHealthCheckRequestID = nil
                state.playlistHealthReport = nil
                if state.activePlaylistID == updatedPlaylist.id,
                   let config = updatedPlaylist.toPlaylistConfig()
                {
                    return .send(.delegate(.didUpdateActivePlaylistSettings(config)))
                }
                guard let profileContext = state.contentSourceProfileContext,
                      profileContextClient.snapshot() == profileContext
                else { return .none }
                return .send(.delegate(.didUpdatePlaylistSettings(updatedPlaylist, profileContext)))

            case let .playlistSettingsSaveFailed(requestID, message):
                guard state.playlistSettingsEditRequestID == requestID else { return .none }
                state.isRefreshingPlaylist = false
                state.playlistValidationMessage = "Playlist doğrulanamadı; mevcut ayarlar korundu. \(message)"
                return .none

            case .cancelPlaylistSettings:
                state.isRefreshingPlaylist = false
                state.playlistBeingEdited = nil
                state.playlistSettingsEditRequestID = nil
                state.userAgentDraft = ""
                state.channelZappingDelayDraft = 0
                state.automaticCatalogRefreshEnabledDraft = true
                state.refreshScheduleDraft = PlaylistRefreshSchedule()
                state.refreshScheduleProfileIDDraft = nil
                state.playlistCloudSyncEnabledDraft = true
                state.mediaServerPlaybackPreferenceDraft = .automatic
                state.serverURLDraft = ""
                state.usernameDraft = ""
                state.passwordDraft = ""
                state.m3uURLDraft = ""
                state.playlistValidationMessage = nil
                state.isCheckingPlaylistHealth = false
                state.playlistHealthCheckRequestID = nil
                state.playlistHealthReport = nil
                return .merge(
                    .cancel(id: "PlaylistManagementFeature.connectionValidation"),
                    .cancel(id: "PlaylistManagementFeature.healthCheck")
                )

            case let .confirmDeletePlaylist(playlist):
                guard !state.isUpdatingSources else { return .none }
                state.playlistToDelete = playlist
                return .none

            case .cancelDeletePlaylist:
                state.playlistToDelete = nil
                return .none

            case .deletePlaylistConfirmed:
                guard let playlist = state.playlistToDelete else { return .none }
                state.playlistToDelete = nil
                return .send(.deletePlaylist(playlist.id))

            case let .deletePlaylist(id):
                guard !state.isUpdatingSources else { return .none }
                let profileContext = state.contentSourceProfileContext
                let hadContentSourceAssignment = state.contentSourceSelection.liveTVPlaylistID == id
                    || state.contentSourceSelection.moviesPlaylistID == id
                    || state.contentSourceSelection.seriesPlaylistID == id
                guard playlistRepository.deletePlaylist(id: id) else {
                    state.playlistValidationMessage = "Playlist silinemedi; kayıt korunuyor. iCloud Keychain erişimini kontrol edin."
                    return .none
                }
                _ = parentalControlClient.setPlaylistPIN(id, nil)
                parentalControlClient.clearPlaylistPINFailures(id)
                playlistContentSourceClient.removePlaylistReferences(id)
                if let profileContext, profileContextClient.snapshot() == profileContext {
                    state.contentSourceSelection = playlistContentSourceClient.load(profileContext.profileID)
                }
                Self.refreshPlaylistStore(
                    state: &state,
                    repository: playlistRepository,
                    customEPGMappingClient: customEPGMappingClient
                )
                if state.activePlaylistID == id {
                    let newActive = state.playlists.first?.id
                    playlistRepository.setActivePlaylistID(newActive)
                    state.activePlaylistID = newActive
                    return .send(.delegate(.didChangeActivePlaylist))
                }
                if hadContentSourceAssignment, let profileContext {
                    return .send(.delegate(.didChangeContentPlaylistSources(profileContext)))
                }
                return .none

            case .addPlaylistButtonTapped:
                guard !state.isUpdatingSources else { return .none }
                return Self.beginAddPlaylist(state: &state)

            case let .closeAddPlaylistTapped(requestID):
                guard state.startupUnlockPlaylistID == nil,
                      state.addPlaylistPresentationRequestID == requestID
                else { return .none }
                state.addPlaylistPresentationRequestID = nil
                state.addPlaylist = nil
                return .none

            case .addPlaylist(.presented(.delegate(.didConnect))),
                 .addPlaylist(.presented(.delegate(.didReceiveTransferredPlaylist))):
                Self.refreshPlaylistStore(
                    state: &state,
                    repository: playlistRepository,
                    customEPGMappingClient: customEPGMappingClient
                )
                state.activePlaylistID = playlistRepository.getActivePlaylistID()
                state.addPlaylistPresentationRequestID = nil
                state.addPlaylist = nil
                return .send(.delegate(.addPlaylistDidConnect))

            case .addPlaylist(.presented(.delegate(.presentQRTransfer))):
                guard state.startupUnlockPlaylistID == nil,
                      state.addPlaylist != nil,
                      let requestID = state.addPlaylistPresentationRequestID
                else { return .none }
                return .send(.delegate(.presentAddPlaylistQRTransfer(requestID: requestID)))

            case .addPlaylist:
                return .none

            case .delegate(.addPlaylistTapped):
                return Self.beginAddPlaylist(state: &state)

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$addPlaylist, action: \.addPlaylist) {
            AddPlaylistFeature()
        }
    }

    private static func beginAddPlaylist(state: inout State) -> Effect<Action> {
        guard !state.isUpdatingSources,
              state.startupUnlockPlaylistID == nil,
              state.addPlaylist == nil,
              state.addPlaylistPresentationRequestID == nil
        else { return .none }

        let requestID = UUID()
        state.addPlaylistPresentationRequestID = requestID
        state.addPlaylist = AddPlaylistFeature.State()
        return .send(.delegate(.presentAddPlaylist(requestID: requestID)))
    }

    private static func playlistHealthConfig(state: State, playlist: SavedPlaylist) -> PlaylistConfig? {
        let userAgent = state.userAgentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard userAgent.utf8.count <= 512,
              userAgent.rangeOfCharacter(from: .controlCharacters) == nil else { return nil }

        let serverURL = state.serverURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = state.usernameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let m3uURL = state.m3uURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedPlaylist = playlist
            .replacingConnection(
                serverURL: playlist.type == .xtream || playlist.type == .plex || playlist.type == .emby
                    ? serverURL
                    : playlist.serverURL,
                username: playlist.type == .xtream ? username : playlist.username,
                password: playlist.type == .xtream ? state.passwordDraft : playlist.password,
                m3uURL: playlist.type == .m3u ? m3uURL : playlist.m3uURL
            )
            .replacingMediaServerPlaybackPreference(
                playlist.type == .emby ? state.mediaServerPlaybackPreferenceDraft : playlist.mediaServerPlaybackPreference
            )
            .replacingUserAgentOverride(userAgent.isEmpty ? nil : userAgent)
            .replacingChannelZappingDelayMilliseconds(state.channelZappingDelayDraft)

        guard let config = updatedPlaylist.toPlaylistConfig() else { return nil }
        if playlist.type == .plex || playlist.type == .emby,
           MediaServerRequestContextFactory.baseURL(for: config) == nil
        {
            return nil
        }
        return config
    }

    private static func invalidPlaylistHealthReport(for type: PlaylistType) -> PlaylistHealthReport {
        PlaylistHealthReport(
            playlistType: type,
            checks: [
                .init(kind: .connection, status: .failed(.invalidConfiguration)),
                .init(kind: .authentication, status: .notChecked(.invalidConfiguration)),
                .init(kind: .format, status: .notChecked(.invalidConfiguration)),
                .init(kind: .parsing, status: .notChecked(.invalidConfiguration)),
                .init(kind: .epg, status: type == .m3u ? .notChecked(.invalidConfiguration) : .notApplicable),
            ]
        )
    }

    private static func unexpectedPlaylistHealthFailure(for type: PlaylistType) -> PlaylistHealthReport {
        PlaylistHealthReport(
            playlistType: type,
            checks: [
                .init(kind: .connection, status: .failed(.connectionFailed)),
                .init(kind: .authentication, status: .notChecked(.invalidResponse)),
                .init(kind: .format, status: .notChecked(.invalidResponse)),
                .init(kind: .parsing, status: .notChecked(.invalidResponse)),
                .init(kind: .epg, status: type == .m3u ? .notChecked(.invalidResponse) : .notApplicable),
            ]
        )
    }

    private static func refreshPlaylistStore(
        state: inout State,
        repository: PlaylistRepository,
        customEPGMappingClient: CustomEPGMappingClient
    ) {
        switch repository.readPlaylists() {
        case let .loaded(playlists):
            state.playlists = playlists
            state.playlistStoreStatus = .available
            let startupID = repository.getDefaultStartupPlaylistID()
            if let startupID, playlists.contains(where: { $0.id == startupID }) {
                state.defaultStartupPlaylistID = startupID
            } else {
                repository.setDefaultStartupPlaylistID(nil)
                state.defaultStartupPlaylistID = nil
            }
        case .notFound:
            state.playlists = []
            state.playlistStoreStatus = .empty
            repository.setDefaultStartupPlaylistID(nil)
            state.defaultStartupPlaylistID = nil
        case .failed:
            state.playlistStoreStatus = .unavailable
        }
        refreshUpdateSources(state: &state, customEPGMappingClient: customEPGMappingClient)
    }

    private static func refreshUpdateSources(
        state: inout State,
        customEPGMappingClient: CustomEPGMappingClient
    ) {
        let previousStatuses = Dictionary(uniqueKeysWithValues: state.updateSources.map { ($0.id, $0.status) })
        var sources: [State.UpdateSource] = []
        for playlist in state.playlists {
            let catalogKind = State.UpdateSourceKind.playlistCatalog(playlist.id)
            sources.append(State.UpdateSource(
                kind: catalogKind,
                title: playlist.name,
                status: previousStatuses[catalogKind.id] ?? .ready
            ))
            if playlist.type == .m3u {
                let epgKind = State.UpdateSourceKind.providerEPG(playlist.id)
                sources.append(State.UpdateSource(
                    kind: epgKind,
                    title: "\(playlist.name) · EPG",
                    status: previousStatuses[epgKind.id] ?? .ready
                ))
            }
        }
        for source in customEPGMappingClient.getSources() where source.isEnabled {
            let kind = State.UpdateSourceKind.customEPG(source.id)
            sources.append(State.UpdateSource(
                kind: kind,
                title: source.name,
                status: previousStatuses[kind.id] ?? .ready
            ))
        }
        state.updateSources = sources
    }
}
