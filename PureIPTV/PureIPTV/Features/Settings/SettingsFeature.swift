import ComposableArchitecture
import FactoryKit
import Foundation
import Kingfisher
import RevenueCat

@Reducer
public struct SettingsFeature {
    @ObservableState
    public struct State: Equatable {
        public var isParentalControlEnabled: Bool = false
        public var isShowingPINSetup: Bool = false
        public var pinSetupPresentationRequestID: UUID?
        public var pinInput: String = ""
        public var pinConfirm: String = ""
        public var step: PINStep = .enterNew
        public var errorMessage: String?
        public var vodSortMethod: SortMethod = .defaultOrder
        public var seriesSortMethod: SortMethod = .defaultOrder

        // New Settings
        public var autoPlayNextEpisode: Bool = true
        public var autoSelectFirstAlternativeSource = false
        public var reverseChannelZappingDirection = false
        public var startMuted: Bool = false
        public var isOLEDDimmingEnabled: Bool = true
        public var isChannelNameCleaningEnabled: Bool = true
        public var showTwoLineTVChannelTitles = false
        public var epgTimeShift: Int = 0
        public var autoUpdateEPG: Bool = true
        public var epgAutoRefreshInterval: EPGAutoRefreshInterval = .fourHours
        public var epgPreviewDelay: EPGPreviewDelay = .short
        public var autoSwitchOnEPGReminder: Bool = false
        public var downloadConcurrencyLimit: Int = 1
        public var hideAdultContent: Bool = false
        public var defaultStartupTab: String = "Keşfet"
        public var hideEmptyContentTabs = true
        public var liveTVOnlyNavigation = false

        // Picture-in-Picture & Background Audio (Madde #18)
        public var isAutoPiPEnabled: Bool = true
        public var backgroundPlaybackMode: BackgroundPlaybackMode = .pip

        // Audio & Subtitle Language Settings (Madde #34)
        public var preferredAudioLanguage: String = "tr"
        public var preferredSubtitleLanguage: String = "off"
        public var subtitleTextSize: SubtitleTextSize = .standard
        public var selectedPlaybackContentKind: PlaybackContentKind = .vod
        public var playbackDefaultsByKind: [PlaybackContentKind: PlaybackDefaults] = [:]
        public var rememberMediaTrackPreferences: Bool = true
        public var isICloudSyncEnabled: Bool = true

        /// Frame Rate and Dynamic Range Matching (Madde #38)
        public var tvOSMatchContent: Bool = true

        /// Auto Frame Rate & Match Dynamic Range (Madde #21)
        public var isAFREnabledForLive: Bool = true
        public var isAFREnabledForVOD: Bool = true
        public var isMatchDynamicRangeEnabled: Bool = true

        /// Apple TV Top Shelf Style (Madde #22)
        public var topShelfStyle: TopShelfStyle = .sectioned

        /// Buffer Profile (Madde #39)
        public var bufferProfile: BufferProfile = .balanced

        /// Compliance Demo Mode (Madde #88)
        public var isComplianceDemoMode: Bool = false

        public var cacheSize: String = AppStrings.Settings.calculating
        public var isShowingClearCacheConfirmation: Bool = false
        public var isShowingClearCacheSuccess: Bool = false
        public var isPremium: Bool = false
        public var speedTestPresentationRequestID: UUID?

        // Trakt.tv Integration (Madde #17)
        public var isTraktAuthenticated: Bool = false
        public var traktUsername: String?
        public var isTraktAutoScrobbleEnabled: Bool = true
        public var isTraktAuthSheetPresented: Bool = false
        public var traktAuthPresentationRequestID: UUID?
        public var isTraktWatchlistPresented: Bool = false
        public var traktWatchlistPresentationRequestID: UUID?
        public var traktState: TraktFeature.State = .init()

        // Hidden Content & Category Blacklist (Madde #19)
        public var hiddenChannelsCount: Int = 0
        public var blacklistedCategoriesCount: Int = 0
        public var isShowingHiddenContentSheet: Bool = false
        public var hiddenChannelsList: [HiddenItemDTO] = []
        public var blacklistedCategoriesList: [HiddenItemDTO] = []
        public var isUnlockingHiddenContent: Bool = false
        public var hiddenContentUnlockPIN: String = ""
        public var hiddenContentUnlockError: String?

        // Custom EPG XMLTV & Time-Shift Offset (Madde #23)
        public var customEPGSources: [CustomEPGSource] = []
        public var channelEPGMappings: [String: ChannelEPGMapping] = [:]
        public var epgMappingChannels: [MediaModels.Item] = []
        public var epgMappingOptions: [CustomEPGChannelOption] = []
        public var epgMappingSuggestions: [EPGMappingSuggestion] = []
        public var isLoadingEPGMappingSuggestions = false
        public var epgMappingSuggestionError: String?
        public var epgMappingRequestID: UUID?
        public var epgMappingSuggestionsPlaylistID: UUID?
        public var isCustomEPGSheetPresented: Bool = false
        public var customEPGPresentationRequestID: UUID?
        public var isAddCustomEPGSourceSheetPresented: Bool = false
        public var customEPGSourceAddPresentationRequestID: UUID?
        public var newCustomEPGName: String = ""
        public var newCustomEPGURLString: String = ""
        public var customEPGErrorMessage: String?
        public var isCustomEPGLoading: Bool = false
        public var customEPGSourceErrors: [String: String] = [:]

        // iCloud Cross-Device Sync (Madde #24)
        public var cloudSyncStatus: CloudSyncStatus = .idle
        public var lastCloudSyncDate: Date?
        public var isCloudSyncing: Bool = false
        public var cloudSyncSummary: CloudSyncSummary?
        public var cloudSyncMessage: String?

        public var personalizationProfileID: UUID?
        public var isPersonalizedRecommendationsEnabled = true
        public var isShowingRecommendationHistoryResetConfirmation = false
        public var isShowingRecommendationHistoryResetSuccess = false

        public enum PINStep: Equatable {
            case enterNew
            case confirm
        }

        public init() {}
    }

    public enum Action: BindableAction {
        case managePlaylistsTapped
        case speedTestTapped
        case closeSpeedTest(requestID: UUID)
        case coordinatorDismissPINSetup(requestID: UUID)
        case coordinatorDismissCustomEPGSettings(requestID: UUID)
        case coordinatorDismissCustomEPGSourceAdd(requestID: UUID)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case openManagePlaylists
            case switchProfile
            case presentSpeedTest(requestID: UUID)
            case presentCustomEPGSettings(requestID: UUID)
            case presentCustomEPGSourceAdd(requestID: UUID)
            case presentPINSetup(requestID: UUID)
            case presentTraktAuth(requestID: UUID)
            case presentTraktWatchlist(requestID: UUID)
        }

        case onAppear
        case binding(BindingAction<State>)
        case toggleParentalControl(Bool)
        case pinInputChanged(String)
        case cancelPINSetup
        case savePIN
        case setVODSortMethod(SortMethod)
        case setSeriesSortMethod(SortMethod)

        // New Setting Actions
        case setAutoPlayNextEpisode(Bool)
        case setAutoSelectFirstAlternativeSource(Bool)
        case setReverseChannelZappingDirection(Bool)
        case setStartMuted(Bool)
        case setOLEDDimmingEnabled(Bool)
        case setChannelNameCleaningEnabled(Bool)
        case setShowTwoLineTVChannelTitles(Bool)
        case setEpgTimeShift(Int)
        case setAutoUpdateEPG(Bool)
        case setEPGAutoRefreshInterval(EPGAutoRefreshInterval)
        case setEPGPreviewDelay(EPGPreviewDelay)
        case setAutoSwitchOnEPGReminder(Bool)
        case setDownloadConcurrencyLimit(Int)
        case setHideAdultContent(Bool)
        case setDefaultStartupTab(String)
        case setHideEmptyContentTabs(Bool)
        case setLiveTVOnlyNavigation(Bool)
        case setPreferredAudioLanguage(String)
        case setPreferredSubtitleLanguage(String)
        case setSubtitleTextSize(SubtitleTextSize)
        case selectPlaybackContentKind(PlaybackContentKind)
        case updatePlaybackDefaults(PlaybackPreferenceUpdate)
        case setRememberMediaTrackPreferences(Bool)
        case setICloudSyncEnabled(Bool)
        case setTvOSMatchContent(Bool)
        case setAFREnabledForLive(Bool)
        case setAFREnabledForVOD(Bool)
        case setAFREnabledForArchive(Bool)
        case setMatchDynamicRangeEnabled(Bool)
        case setTopShelfStyle(TopShelfStyle)
        case setBufferProfile(BufferProfile)
        case setComplianceDemoMode(Bool)
        case setPersonalizedRecommendationsEnabled(Bool)

        case calculateCacheSize
        case cacheSizeCalculated(String)
        case resetRecommendationHistoryTapped
        case cancelRecommendationHistoryReset
        case confirmRecommendationHistoryReset
        case recommendationHistoryResetSuccessDismissed
        case clearCacheTapped
        case cancelClearCache
        case confirmClearCache
        case clearCache
        case clearCacheCompleted
        case clearCacheSuccessDismissed
        case restorePurchases
        case restorePurchasesResponse(TaskResult<RevenueCat.CustomerInfo>)
        case updatePremiumStatus(Bool)
        case switchProfileTapped

        // Trakt.tv Actions (Madde #17)
        case setTraktAuthSheetPresented(Bool)
        case coordinatorDismissTraktAuth(requestID: UUID)
        case openTraktWatchlist
        case coordinatorDismissTraktWatchlist(requestID: UUID)
        case traktAction(TraktFeature.Action)
        case toggleTraktAutoScrobble(Bool)
        case traktLogout

        // PiP & Background Playback Actions (Madde #18)
        case setAutoPiPEnabled(Bool)
        case setBackgroundPlaybackMode(BackgroundPlaybackMode)

        // Hidden Content & Category Blacklist (Madde #19)
        case openHiddenContentManagement
        case closeHiddenContentManagement
        case loadHiddenContentData
        case hiddenContentUnlockPINChanged(String)
        case cancelHiddenContentUnlock
        case submitHiddenContentUnlock
        case biometricUnlockResult(Bool)
        case unhideChannelFromSettings(String)
        case unblacklistCategoryFromSettings(String)
        case unhideAllChannelsFromSettings
        case unblacklistAllCategoriesFromSettings

        // Custom EPG & Time-Shift (Madde #23)
        case setCustomEPGSheetPresented(Bool)
        case setAddCustomEPGSourceSheetPresented(Bool)
        case setNewCustomEPGName(String)
        case setNewCustomEPGURLString(String)
        case loadCustomEPGData
        case setGlobalEPGTimeShift(Int)
        case addCustomEPGSource
        case addCustomEPGSourceResponse(TaskResult<CustomEPGSource>)
        case removeCustomEPGSource(String)
        case toggleCustomEPGSource(id: String, enabled: Bool)
        case refreshCustomEPGSource(String)
        case refreshCustomEPGSourceResponse(id: String, result: TaskResult<CustomEPGSource>)
        case refreshAllCustomEPGSources
        case refreshAllCustomEPGSourcesCompleted(CustomEPGRefreshSummary)
        case retryFailedCustomEPGSources
        case retryFailedCustomEPGSourcesCompleted(attemptedIDs: [String], failures: [String: String])
        case loadEPGMappingSuggestions
        case epgMappingInputsLoaded(UUID, playlistID: UUID, channels: [MediaModels.Item], options: [CustomEPGChannelOption])
        case epgMappingSuggestionsLoaded(UUID, playlistID: UUID, [EPGMappingSuggestion])
        case applySuggestedEPGMapping(channelID: String, channelName: String, sourceID: String, epgChannelID: String)

        // iCloud Cross-Device Sync (Madde #24)
        case syncNowTapped
        case syncNowResponse(TaskResult<CloudSyncSummary>)
        case cloudSyncSummaryUpdated(CloudSyncSummary)
        case startCloudSyncObservation
        case dismissCloudSyncMessage
    }

    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.playerClient) var playerClient
    @Dependency(\.purchases) var purchases
    @Dependency(\.traktClient) var traktClient
    @Dependency(\.pipClient) var pipClient
    @Dependency(\.parentalControlClient) var parentalControlClient
    @Dependency(\.displayModeClient) var displayModeClient
    @Dependency(\.topShelfClient) var topShelfClient
    @Dependency(\.customEPGMappingClient) var customEPGMappingClient
    @Dependency(\.cloudSyncClient) var cloudSyncClient
    @Dependency(\.downloadClient) var downloadClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Injected(\.iptvClient) var iptvClient
    @Injected(\.playlistRepository) var playlistRepository

    public init() {}

    private static func updatePlaybackDefaults(
        state: inout State,
        kind explicitKind: PlaybackContentKind? = nil,
        update: PlaybackPreferenceUpdate,
        settingsClient: SettingsClient
    ) -> Effect<Action> {
        let kind = explicitKind ?? state.selectedPlaybackContentKind
        var defaults = state.playbackDefaultsByKind[kind] ?? settingsClient.playbackDefaults(kind)
        update.apply(to: &defaults)
        state.playbackDefaultsByKind[kind] = defaults
        if kind == .vod {
            state.bufferProfile = defaults.bufferChoice.profile ?? .balanced
        }
        settingsClient.setPlaybackDefaults(kind, defaults)
        return .none
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Scope(state: \.traktState, action: \.traktAction) {
            TraktFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                let currentProfileID = profileContextClient.snapshot().profileID
                state.personalizationProfileID = currentProfileID
                state.isPersonalizedRecommendationsEnabled = LocalPersonalizationPreferences.recommendationsEnabled(
                    for: currentProfileID
                )
                state.isParentalControlEnabled = settingsClient.isParentalControlEnabled()
                state.vodSortMethod = settingsClient.getVODSortMethod()
                state.seriesSortMethod = settingsClient.getSeriesSortMethod()

                state.autoPlayNextEpisode = settingsClient.autoPlayNextEpisode()
                state.autoSelectFirstAlternativeSource = settingsClient.autoSelectFirstAlternativeSource()
                state.reverseChannelZappingDirection = settingsClient.reverseChannelZappingDirection()
                state.startMuted = settingsClient.startMuted()
                state.isOLEDDimmingEnabled = settingsClient.isOLEDDimmingEnabled()
                state.isChannelNameCleaningEnabled = settingsClient.isChannelNameCleaningEnabled()
                state.showTwoLineTVChannelTitles = settingsClient.showTwoLineTVChannelTitles()
                state.epgTimeShift = settingsClient.epgTimeShift()
                state.autoUpdateEPG = settingsClient.autoUpdateEPG()
                state.epgAutoRefreshInterval = settingsClient.epgAutoRefreshInterval()
                state.epgPreviewDelay = settingsClient.epgPreviewDelay()
                state.autoSwitchOnEPGReminder = settingsClient.autoSwitchOnEPGReminder()
                state.downloadConcurrencyLimit = settingsClient.downloadConcurrencyLimit()
                state.hideAdultContent = settingsClient.hideAdultContent()
                state.defaultStartupTab = settingsClient.defaultStartupTab()
                state.hideEmptyContentTabs = settingsClient.hideEmptyContentTabs()
                state.liveTVOnlyNavigation = settingsClient.liveTVOnlyNavigation()
                state.preferredAudioLanguage = settingsClient.preferredAudioLanguage()
                state.preferredSubtitleLanguage = settingsClient.preferredSubtitleLanguage()
                state.subtitleTextSize = settingsClient.subtitleTextSize()
                state.rememberMediaTrackPreferences = settingsClient.rememberMediaTrackPreferences()
                state.isICloudSyncEnabled = settingsClient.isICloudSyncEnabled()

                // Trakt State (Madde #17)
                state.isTraktAuthenticated = traktClient.isAuthenticated()
                state.traktUsername = traktClient.currentUser()?.username
                state.isTraktAutoScrobbleEnabled = traktClient.isAutoScrobbleEnabled()

                // PiP & Background Playback (Madde #18)
                state.isAutoPiPEnabled = pipClient.isAutoPiPEnabled()
                state.backgroundPlaybackMode = pipClient.backgroundPlaybackMode()

                // Hidden Content Counts (Madde #19)
                state.hiddenChannelsCount = parentalControlClient.hiddenChannelIDs().count
                state.blacklistedCategoriesCount = parentalControlClient.blacklistedCategoryIDs().count

                // Auto Frame Rate & Match Dynamic Range (Madde #21)
                state.isAFREnabledForLive = displayModeClient.isAFREnabledForLive()
                state.isAFREnabledForVOD = displayModeClient.isAFREnabledForVOD()
                state.isMatchDynamicRangeEnabled = displayModeClient.isMatchDynamicRangeEnabled()

                // Apple TV Top Shelf Style (Madde #22)
                state.topShelfStyle = topShelfClient.getPreferredStyle()

                state.playbackDefaultsByKind = Dictionary(
                    uniqueKeysWithValues: PlaybackContentKind.allCases.map { kind in
                        (kind, settingsClient.playbackDefaults(kind))
                    }
                )
                if let vodDefaults = state.playbackDefaultsByKind[.vod] {
                    state.preferredAudioLanguage = vodDefaults.preferredAudioLanguage
                    state.preferredSubtitleLanguage = vodDefaults.preferredSubtitleLanguage
                    state.subtitleTextSize = vodDefaults.subtitleTextSize
                    state.isAFREnabledForVOD = vodDefaults.isAFREnabled
                    state.isMatchDynamicRangeEnabled = vodDefaults.isMatchDynamicRangeEnabled
                }
                if let liveDefaults = state.playbackDefaultsByKind[.live] {
                    state.isAFREnabledForLive = liveDefaults.isAFREnabled
                }
                state.bufferProfile = state.playbackDefaultsByKind[.vod]?.bufferChoice.profile ?? .balanced

                // Custom EPG XMLTV & Time-Shift (Madde #23)
                state.customEPGSources = customEPGMappingClient.getSources()
                state.channelEPGMappings = customEPGMappingClient.getAllMappings()

                // iCloud Cross-Device Sync (Madde #24)
                state.isICloudSyncEnabled = cloudSyncClient.isSyncEnabled()
                state.lastCloudSyncDate = cloudSyncClient.lastSyncDate()
                state.cloudSyncStatus = cloudSyncClient.getSyncStatus()

                return .merge(
                    .send(.calculateCacheSize),
                    .send(.startCloudSyncObservation),
                    .run { send in
                        if let info = try? await purchases.customerInfo() {
                            await send(.updatePremiumStatus(!info.entitlements.active.isEmpty))
                        }
                    }
                )

            case .managePlaylistsTapped:
                return .send(.delegate(.openManagePlaylists))

            case .speedTestTapped:
                guard state.speedTestPresentationRequestID == nil else { return .none }
                let requestID = UUID()
                state.speedTestPresentationRequestID = requestID
                return .send(.delegate(.presentSpeedTest(requestID: requestID)))

            case let .closeSpeedTest(requestID):
                guard state.speedTestPresentationRequestID == requestID else { return .none }
                state.speedTestPresentationRequestID = nil
                return .none

            case .switchProfileTapped:
                return .send(.delegate(.switchProfile))

            case .delegate:
                return .none

            case .binding:
                return .none

            case let .toggleParentalControl(enabled):
                if enabled {
                    guard state.pinSetupPresentationRequestID == nil else { return .none }
                    let requestID = UUID()
                    state.pinSetupPresentationRequestID = requestID
                    // Kapatmaktan açmaya geçiyorsa PIN belirleme ekranını aç
                    state.isShowingPINSetup = true
                    state.step = .enterNew
                    state.pinInput = ""
                    state.pinConfirm = ""
                    state.errorMessage = nil
                    // Toggle'ı UI'da hemen true yapma, PIN belirlenince true yapacağız
                    return .send(.delegate(.presentPINSetup(requestID: requestID)))
                } else {
                    // Kapatılıyorsa direkt kapat
                    state.isParentalControlEnabled = false
                    return .run { _ in
                        try await settingsClient.setParentalControl(false, nil)
                    }
                }

            case let .pinInputChanged(input):
                let filtered = input.filter(\.isNumber)
                if filtered.count <= 4 {
                    if state.step == .enterNew {
                        state.pinInput = filtered
                        if filtered.count == 4 {
                            state.step = .confirm
                            state.errorMessage = nil
                        }
                    } else {
                        state.pinConfirm = filtered
                        if filtered.count == 4 {
                            return .send(.savePIN)
                        }
                    }
                }
                return .none

            case .cancelPINSetup:
                state.isShowingPINSetup = false
                state.isParentalControlEnabled = false
                return .none

            case let .coordinatorDismissPINSetup(requestID):
                guard state.pinSetupPresentationRequestID == requestID else { return .none }
                state.isShowingPINSetup = false
                state.pinSetupPresentationRequestID = nil
                return .none

            case .savePIN:
                if state.pinInput == state.pinConfirm {
                    state.isParentalControlEnabled = true
                    state.isShowingPINSetup = false
                    let finalPIN = state.pinInput
                    return .run { _ in
                        try await settingsClient.setParentalControl(true, finalPIN)
                    }
                } else {
                    state.errorMessage = AppStrings.Errors.pinMismatch
                    state.pinConfirm = ""
                    state.step = .confirm
                    return .none
                }

            case let .setVODSortMethod(method):
                state.vodSortMethod = method
                return .run { _ in
                    settingsClient.setVODSortMethod(method)
                }

            case let .setSeriesSortMethod(method):
                state.seriesSortMethod = method
                return .run { _ in
                    settingsClient.setSeriesSortMethod(method)
                }

            case let .setAutoPlayNextEpisode(val):
                state.autoPlayNextEpisode = val
                return .run { _ in settingsClient.setAutoPlayNextEpisode(val) }

            case let .setAutoSelectFirstAlternativeSource(val):
                state.autoSelectFirstAlternativeSource = val
                return .run { _ in settingsClient.setAutoSelectFirstAlternativeSource(val) }

            case let .setReverseChannelZappingDirection(val):
                state.reverseChannelZappingDirection = val
                return .run { _ in settingsClient.setReverseChannelZappingDirection(val) }

            case let .setDownloadConcurrencyLimit(value):
                let limit = min(4, max(1, value))
                state.downloadConcurrencyLimit = limit
                return .run { _ in
                    settingsClient.setDownloadConcurrencyLimit(limit)
                    await downloadClient.setConcurrencyLimit(limit)
                }

            case let .setStartMuted(val):
                state.startMuted = val
                return .run { _ in settingsClient.setStartMuted(val) }

            case let .setOLEDDimmingEnabled(val):
                state.isOLEDDimmingEnabled = val
                return .run { _ in settingsClient.setIsOLEDDimmingEnabled(val) }

            case let .setChannelNameCleaningEnabled(val):
                state.isChannelNameCleaningEnabled = val
                return .run { _ in settingsClient.setIsChannelNameCleaningEnabled(val) }

            case let .setShowTwoLineTVChannelTitles(enabled):
                state.showTwoLineTVChannelTitles = enabled
                return .run { _ in settingsClient.setShowTwoLineTVChannelTitles(enabled) }

            case let .setEpgTimeShift(val), let .setGlobalEPGTimeShift(val):
                state.epgTimeShift = val
                customEPGMappingClient.setGlobalTimeShift(val)
                return .run { _ in settingsClient.setEpgTimeShift(val) }

            case let .setAutoUpdateEPG(val):
                state.autoUpdateEPG = val
                return .run { _ in settingsClient.setAutoUpdateEPG(val) }

            case let .setEPGAutoRefreshInterval(interval):
                state.epgAutoRefreshInterval = interval
                return .run { _ in settingsClient.setEPGAutoRefreshInterval(interval) }

            case let .setEPGPreviewDelay(delay):
                state.epgPreviewDelay = delay
                return .run { _ in settingsClient.setEPGPreviewDelay(delay) }

            case let .setAutoSwitchOnEPGReminder(val):
                state.autoSwitchOnEPGReminder = val
                return .run { _ in settingsClient.setAutoSwitchOnEPGReminder(val) }

            case let .setHideAdultContent(val):
                state.hideAdultContent = val
                return .run { _ in settingsClient.setHideAdultContent(val) }

            case let .setDefaultStartupTab(val):
                state.defaultStartupTab = val
                return .run { _ in settingsClient.setDefaultStartupTab(val) }

            case let .setHideEmptyContentTabs(val):
                state.hideEmptyContentTabs = val
                return .run { _ in settingsClient.setHideEmptyContentTabs(val) }

            case let .setLiveTVOnlyNavigation(val):
                state.liveTVOnlyNavigation = val
                return .run { _ in settingsClient.setLiveTVOnlyNavigation(val) }

            case let .setPreferredAudioLanguage(val):
                state.preferredAudioLanguage = val
                return Self.updatePlaybackDefaults(
                    state: &state,
                    update: .preferredAudioLanguage(val),
                    settingsClient: settingsClient
                )

            case let .setPreferredSubtitleLanguage(val):
                state.preferredSubtitleLanguage = val
                return Self.updatePlaybackDefaults(
                    state: &state,
                    update: .preferredSubtitleLanguage(val),
                    settingsClient: settingsClient
                )

            case let .setSubtitleTextSize(size):
                state.subtitleTextSize = size
                return Self.updatePlaybackDefaults(
                    state: &state,
                    update: .subtitleTextSize(size),
                    settingsClient: settingsClient
                )

            case let .selectPlaybackContentKind(kind):
                state.selectedPlaybackContentKind = kind
                return .none

            case let .updatePlaybackDefaults(update):
                return Self.updatePlaybackDefaults(
                    state: &state,
                    update: update,
                    settingsClient: settingsClient
                )

            case let .setRememberMediaTrackPreferences(val):
                state.rememberMediaTrackPreferences = val
                return .run { _ in settingsClient.setRememberMediaTrackPreferences(val) }

            case let .setICloudSyncEnabled(val):
                state.isICloudSyncEnabled = val
                cloudSyncClient.setSyncEnabled(val)
                return .run { _ in
                    settingsClient.setIsICloudSyncEnabled(val)
                }

            case let .setTvOSMatchContent(enabled):
                state.tvOSMatchContent = enabled
                UserDefaults.standard.set(enabled, forKey: "pureiptv_match_content")
                return .none

            case let .setAFREnabledForLive(enabled):
                state.isAFREnabledForLive = enabled
                return Self.updatePlaybackDefaults(
                    state: &state,
                    kind: .live,
                    update: .isAFREnabled(enabled),
                    settingsClient: settingsClient
                )

            case let .setAFREnabledForVOD(enabled):
                state.isAFREnabledForVOD = enabled
                return Self.updatePlaybackDefaults(
                    state: &state,
                    kind: .vod,
                    update: .isAFREnabled(enabled),
                    settingsClient: settingsClient
                )

            case let .setAFREnabledForArchive(enabled):
                return Self.updatePlaybackDefaults(
                    state: &state,
                    kind: .archive,
                    update: .isAFREnabled(enabled),
                    settingsClient: settingsClient
                )

            case let .setMatchDynamicRangeEnabled(enabled):
                state.isMatchDynamicRangeEnabled = enabled
                return Self.updatePlaybackDefaults(
                    state: &state,
                    update: .isMatchDynamicRangeEnabled(enabled),
                    settingsClient: settingsClient
                )

            case let .setTopShelfStyle(style):
                state.topShelfStyle = style
                topShelfClient.setPreferredStyle(style)
                return .none

            case let .setBufferProfile(profile):
                state.bufferProfile = profile
                return Self.updatePlaybackDefaults(
                    state: &state,
                    kind: state.selectedPlaybackContentKind,
                    update: .bufferChoice(PlaybackBufferChoice.choice(for: profile)),
                    settingsClient: settingsClient
                )

            case let .setComplianceDemoMode(enabled):
                state.isComplianceDemoMode = enabled
                ComplianceModeManager.shared.isComplianceModeActive = enabled
                return .none

            case let .setPersonalizedRecommendationsEnabled(enabled):
                let profileID = profileContextClient.snapshot().profileID
                guard state.personalizationProfileID == profileID
                else { return .none }
                state.isPersonalizedRecommendationsEnabled = enabled
                LocalPersonalizationPreferences.setRecommendationsEnabled(enabled, for: profileID)
                return .none

            case .resetRecommendationHistoryTapped:
                state.isShowingRecommendationHistoryResetConfirmation = true
                return .none

            case .cancelRecommendationHistoryReset:
                state.isShowingRecommendationHistoryResetConfirmation = false
                return .none

            case .confirmRecommendationHistoryReset:
                let profileID = profileContextClient.snapshot().profileID
                guard state.personalizationProfileID == profileID
                else { return .none }
                state.isShowingRecommendationHistoryResetConfirmation = false
                state.isShowingRecommendationHistoryResetSuccess = true
                LocalPersonalizationPreferences.clearWatchHistorySignal(for: profileID)
                return .none

            case .recommendationHistoryResetSuccessDismissed:
                state.isShowingRecommendationHistoryResetSuccess = false
                return .none

            case let .setAutoPiPEnabled(enabled):
                state.isAutoPiPEnabled = enabled
                return .run { _ in pipClient.setAutoPiPEnabled(enabled) }

            case let .setBackgroundPlaybackMode(mode):
                state.backgroundPlaybackMode = mode
                return .run { _ in pipClient.setBackgroundPlaybackMode(mode) }

            case .calculateCacheSize:
                return .run { send in
                    let kingfisherBytes: Int64 = await withCheckedContinuation { continuation in
                        ImageCache.default.calculateDiskStorageSize { result in
                            switch result {
                            case let .success(size):
                                continuation.resume(returning: Int64(size))
                            case .failure:
                                continuation.resume(returning: 0)
                            }
                        }
                    }
                    let urlCacheBytes = Int64(URLCache.shared.currentDiskUsage)

                    var tmpBytes: Int64 = 0
                    let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    if let enumerator = FileManager.default.enumerator(at: tmpURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
                        for case let fileURL as URL in enumerator {
                            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                               values.isDirectory == false,
                               let size = values.fileSize
                            {
                                tmpBytes += Int64(size)
                            }
                        }
                    }

                    let totalBytes = max(0, kingfisherBytes + urlCacheBytes + tmpBytes)

                    let formatter = ByteCountFormatter()
                    formatter.countStyle = .file
                    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
                    let sizeStr = formatter.string(fromByteCount: totalBytes)
                    await send(.cacheSizeCalculated(sizeStr))
                }

            case let .cacheSizeCalculated(size):
                state.cacheSize = size
                return .none

            case .clearCacheTapped:
                state.isShowingClearCacheConfirmation = true
                return .none

            case .cancelClearCache:
                state.isShowingClearCacheConfirmation = false
                return .none

            case .confirmClearCache, .clearCache:
                state.isShowingClearCacheConfirmation = false
                state.cacheSize = AppStrings.Settings.clearing
                return .run { send in
                    // 1. Clear URLCache
                    URLCache.shared.removeAllCachedResponses()

                    // 2. Clear Kingfisher disk and memory cache
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        ImageCache.default.clearDiskCache {
                            ImageCache.default.clearMemoryCache()
                            continuation.resume()
                        }
                    }

                    // 3. Clear temporary files safely
                    let tmpPath = NSTemporaryDirectory()
                    let tmpURL = URL(fileURLWithPath: tmpPath)
                    if let files = try? FileManager.default.contentsOfDirectory(at: tmpURL, includingPropertiesForKeys: nil) {
                        for file in files {
                            try? FileManager.default.removeItem(at: file)
                        }
                    }

                    #if os(iOS)
                        await MainActor.run {
                            HapticManager.shared.trigger(.success)
                        }
                    #endif

                    await send(.clearCacheCompleted)
                    await send(.calculateCacheSize)
                }

            case .clearCacheCompleted:
                state.isShowingClearCacheSuccess = true
                return .none

            case .clearCacheSuccessDismissed:
                state.isShowingClearCacheSuccess = false
                return .none

            case .restorePurchases:
                return .run { send in
                    await send(.restorePurchasesResponse(TaskResult {
                        try await purchases.restorePurchases()
                    }))
                }

            case let .restorePurchasesResponse(.success(info)):
                state.isPremium = !info.entitlements.active.isEmpty
                return .none

            case .restorePurchasesResponse(.failure):
                return .none

            case let .updatePremiumStatus(isPremium):
                state.isPremium = isPremium
                return .none

            // Trakt.tv Reducer Handlers (Madde #17)
            case let .setTraktAuthSheetPresented(presented):
                if !presented {
                    state.isTraktAuthSheetPresented = false
                    state.traktAuthPresentationRequestID = nil
                    state.isTraktAuthenticated = traktClient.isAuthenticated()
                    state.traktUsername = traktClient.currentUser()?.username
                    return .none
                }
                guard state.traktAuthPresentationRequestID == nil else { return .none }
                let requestID = UUID()
                state.isTraktAuthSheetPresented = true
                state.traktAuthPresentationRequestID = requestID
                return .send(.delegate(.presentTraktAuth(requestID: requestID)))

            case let .coordinatorDismissTraktAuth(requestID):
                guard state.traktAuthPresentationRequestID == requestID else { return .none }
                state.isTraktAuthSheetPresented = false
                state.traktAuthPresentationRequestID = nil
                state.isTraktAuthenticated = traktClient.isAuthenticated()
                state.traktUsername = traktClient.currentUser()?.username
                return .none

            case .openTraktWatchlist:
                guard state.traktWatchlistPresentationRequestID == nil else { return .none }
                let requestID = UUID()
                state.isTraktWatchlistPresented = true
                state.traktWatchlistPresentationRequestID = requestID
                return .send(.delegate(.presentTraktWatchlist(requestID: requestID)))

            case let .coordinatorDismissTraktWatchlist(requestID):
                guard state.traktWatchlistPresentationRequestID == requestID else { return .none }
                state.isTraktWatchlistPresented = false
                state.traktWatchlistPresentationRequestID = nil
                return .none

            case let .toggleTraktAutoScrobble(enabled):
                state.isTraktAutoScrobbleEnabled = enabled
                traktClient.setAutoScrobbleEnabled(enabled)
                return .none

            case .traktLogout:
                traktClient.logout()
                state.isTraktAuthenticated = false
                state.traktUsername = nil
                return .send(.traktAction(.logout))

            case .traktAction(.pollTokenResponse(.success(.some))):
                state.isTraktAuthenticated = true
                state.traktUsername = traktClient.currentUser()?.username
                return .none

            case .traktAction:
                return .none

            // ── Hidden Content & Category Blacklist (Madde #19) ──
            case .openHiddenContentManagement:
                if parentalControlClient.isParentalControlEnabled() {
                    #if os(tvOS)
                        state.isUnlockingHiddenContent = true
                        state.hiddenContentUnlockPIN = ""
                        state.hiddenContentUnlockError = nil
                        return .none
                    #else
                        return .run { send in
                            let authSuccess = await parentalControlClient.authenticateWithBiometrics("Gizlenen kanalları yönetmek için doğrulayın")
                            await send(.biometricUnlockResult(authSuccess))
                        }
                    #endif
                } else {
                    return .send(.loadHiddenContentData)
                }

            case let .biometricUnlockResult(success):
                if success {
                    return .send(.loadHiddenContentData)
                } else {
                    state.isUnlockingHiddenContent = true
                    state.hiddenContentUnlockPIN = ""
                    state.hiddenContentUnlockError = nil
                    return .none
                }

            case .cancelHiddenContentUnlock:
                state.isUnlockingHiddenContent = false
                state.hiddenContentUnlockPIN = ""
                state.hiddenContentUnlockError = nil
                return .none

            case let .hiddenContentUnlockPINChanged(input):
                let filtered = input.filter(\.isNumber)
                if filtered.count <= 4 {
                    state.hiddenContentUnlockPIN = filtered
                    if filtered.count == 4 {
                        return .send(.submitHiddenContentUnlock)
                    }
                }
                return .none

            case .submitHiddenContentUnlock:
                if parentalControlClient.verifyPIN(state.hiddenContentUnlockPIN) {
                    state.isUnlockingHiddenContent = false
                    state.hiddenContentUnlockPIN = ""
                    state.hiddenContentUnlockError = nil
                    return .send(.loadHiddenContentData)
                } else {
                    state.hiddenContentUnlockError = AppStrings.Errors.incorrectPIN
                    state.hiddenContentUnlockPIN = ""
                    return .none
                }

            case .loadHiddenContentData:
                state.hiddenChannelsList = parentalControlClient.fetchHiddenChannels()
                state.blacklistedCategoriesList = parentalControlClient.fetchBlacklistedCategories()
                state.hiddenChannelsCount = state.hiddenChannelsList.count
                state.blacklistedCategoriesCount = state.blacklistedCategoriesList.count
                state.isShowingHiddenContentSheet = true
                return .none

            case .closeHiddenContentManagement:
                state.isShowingHiddenContentSheet = false
                return .none

            case let .unhideChannelFromSettings(id):
                parentalControlClient.unhideChannel(id)
                state.hiddenChannelsList.removeAll { $0.id == id }
                state.hiddenChannelsCount = state.hiddenChannelsList.count
                return .none

            case let .unblacklistCategoryFromSettings(id):
                parentalControlClient.unblacklistCategory(id)
                state.blacklistedCategoriesList.removeAll { $0.id == id }
                state.blacklistedCategoriesCount = state.blacklistedCategoriesList.count
                return .none

            case .unhideAllChannelsFromSettings:
                parentalControlClient.unhideAllChannels()
                state.hiddenChannelsList.removeAll()
                state.hiddenChannelsCount = 0
                return .none

            case .unblacklistAllCategoriesFromSettings:
                parentalControlClient.unblacklistAllCategories()
                state.blacklistedCategoriesList.removeAll()
                state.blacklistedCategoriesCount = 0
                return .none

            // Custom EPG & Time-Shift (Madde #23)
            case let .setCustomEPGSheetPresented(val):
                guard val else {
                    state.isCustomEPGSheetPresented = false
                    return .none
                }
                guard state.customEPGPresentationRequestID == nil else { return .none }
                let requestID = UUID()
                state.customEPGPresentationRequestID = requestID
                state.isCustomEPGSheetPresented = true
                state.customEPGSources = customEPGMappingClient.getSources()
                state.channelEPGMappings = customEPGMappingClient.getAllMappings()
                state.epgTimeShift = customEPGMappingClient.getGlobalTimeShift()
                return .send(.delegate(.presentCustomEPGSettings(requestID: requestID)))

            case let .coordinatorDismissCustomEPGSettings(requestID):
                guard state.customEPGPresentationRequestID == requestID else { return .none }
                state.isCustomEPGSheetPresented = false
                state.customEPGPresentationRequestID = nil
                state.isAddCustomEPGSourceSheetPresented = false
                state.customEPGSourceAddPresentationRequestID = nil
                state.newCustomEPGName = ""
                state.newCustomEPGURLString = ""
                return .none

            case .loadEPGMappingSuggestions:
                guard !state.isLoadingEPGMappingSuggestions,
                      let playlist = playlistRepository.getActivePlaylist(),
                      let config = playlist.toPlaylistConfig()
                else { return .none }
                let requestID = UUID()
                state.epgMappingRequestID = requestID
                state.epgMappingSuggestionsPlaylistID = playlist.id
                state.isLoadingEPGMappingSuggestions = true
                state.epgMappingSuggestionError = nil
                return .run { send in
                    async let channels = try? iptvClient.fetchLiveChannels(config, nil)
                    async let options = customEPGMappingClient.getAvailableEPGChannelOptions()
                    let fetchedChannels = await channels ?? []
                    let fetchedOptions = await options
                    await send(.epgMappingInputsLoaded(requestID, playlistID: playlist.id, channels: fetchedChannels, options: fetchedOptions))
                }

            case let .epgMappingInputsLoaded(requestID, playlistID, channels, options):
                guard state.epgMappingRequestID == requestID else { return .none }
                guard playlistRepository.getActivePlaylistID() == playlistID else {
                    state.isLoadingEPGMappingSuggestions = false
                    state.epgMappingRequestID = nil
                    return .none
                }
                state.epgMappingChannels = channels
                state.epgMappingOptions = options
                state.epgMappingSuggestionsPlaylistID = playlistID
                return .run { send in
                    let suggestions = await EPGMappingSuggestionEngine.suggestions(for: channels, from: options)
                    await send(.epgMappingSuggestionsLoaded(requestID, playlistID: playlistID, suggestions))
                }

            case let .epgMappingSuggestionsLoaded(requestID, playlistID, suggestions):
                guard state.epgMappingRequestID == requestID else { return .none }
                guard playlistRepository.getActivePlaylistID() == playlistID else {
                    state.isLoadingEPGMappingSuggestions = false
                    state.epgMappingRequestID = nil
                    return .none
                }
                state.isLoadingEPGMappingSuggestions = false
                state.epgMappingSuggestions = suggestions
                state.epgMappingSuggestionError = suggestions.isEmpty ? AppStrings.Settings.noEPGMappingSuggestions : nil
                return .none

            case let .applySuggestedEPGMapping(channelID, channelName, sourceID, epgChannelID):
                guard state.epgMappingSuggestionsPlaylistID == playlistRepository.getActivePlaylistID() else {
                    state.epgMappingSuggestions = []
                    return .none
                }
                let previous = state.channelEPGMappings[channelID]
                let mapping = ChannelEPGMapping(
                    channelID: channelID,
                    channelName: channelName,
                    customEPGChannelID: epgChannelID,
                    customSourceID: sourceID,
                    timeShiftHours: previous?.timeShiftHours ?? 0
                )
                customEPGMappingClient.setChannelMapping(mapping)
                state.channelEPGMappings[channelID] = mapping
                state.epgMappingSuggestions.removeAll { $0.channelID == channelID }
                return .none

            case let .setAddCustomEPGSourceSheetPresented(val):
                guard val else {
                    state.isAddCustomEPGSourceSheetPresented = false
                    state.customEPGErrorMessage = nil
                    state.newCustomEPGName = ""
                    state.newCustomEPGURLString = ""
                    return .none
                }
                guard state.isCustomEPGSheetPresented,
                      state.customEPGPresentationRequestID != nil,
                      state.customEPGSourceAddPresentationRequestID == nil
                else { return .none }
                let requestID = UUID()
                state.customEPGSourceAddPresentationRequestID = requestID
                state.isAddCustomEPGSourceSheetPresented = true
                state.customEPGErrorMessage = nil
                return .send(.delegate(.presentCustomEPGSourceAdd(requestID: requestID)))

            case let .coordinatorDismissCustomEPGSourceAdd(requestID):
                guard state.customEPGSourceAddPresentationRequestID == requestID else { return .none }
                state.isAddCustomEPGSourceSheetPresented = false
                state.customEPGSourceAddPresentationRequestID = nil
                state.customEPGErrorMessage = nil
                state.newCustomEPGName = ""
                state.newCustomEPGURLString = ""
                return .none

            case let .setNewCustomEPGName(val):
                state.newCustomEPGName = val
                return .none

            case let .setNewCustomEPGURLString(val):
                state.newCustomEPGURLString = val
                return .none

            case .loadCustomEPGData:
                state.customEPGSources = customEPGMappingClient.getSources()
                state.channelEPGMappings = customEPGMappingClient.getAllMappings()
                state.epgTimeShift = customEPGMappingClient.getGlobalTimeShift()
                return .none

            case .addCustomEPGSource:
                let urlString = state.newCustomEPGURLString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: urlString), url.scheme != nil else {
                    state.customEPGErrorMessage = "Geçersiz URL formatı. Lütfen http:// veya https:// ile başlayan bir link girin."
                    return .none
                }
                let name = state.newCustomEPGName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    state.customEPGErrorMessage = "Lütfen kaynak adı girin."
                    return .none
                }
                state.isCustomEPGLoading = true
                state.customEPGErrorMessage = nil
                return .run { send in
                    await send(.addCustomEPGSourceResponse(TaskResult {
                        try await customEPGMappingClient.addSource(name, url)
                    }))
                }

            case let .addCustomEPGSourceResponse(.success(source)):
                state.isCustomEPGLoading = false
                state.customEPGSources.append(source)
                state.isAddCustomEPGSourceSheetPresented = false
                state.newCustomEPGName = ""
                state.newCustomEPGURLString = ""
                state.customEPGErrorMessage = nil
                return .none

            case let .addCustomEPGSourceResponse(.failure(error)):
                state.isCustomEPGLoading = false
                state.customEPGErrorMessage = "Kaynak eklenemedi: \(error.localizedDescription)"
                return .none

            case let .removeCustomEPGSource(id):
                customEPGMappingClient.removeSource(id)
                state.customEPGSources.removeAll { $0.id == id }
                state.customEPGSourceErrors.removeValue(forKey: id)
                return .none

            case let .toggleCustomEPGSource(id, enabled):
                customEPGMappingClient.toggleSource(id, enabled)
                if let idx = state.customEPGSources.firstIndex(where: { $0.id == id }) {
                    state.customEPGSources[idx].isEnabled = enabled
                }
                return .none

            case let .refreshCustomEPGSource(id):
                guard !state.isCustomEPGLoading else { return .none }
                guard state.customEPGSources.contains(where: { $0.id == id }) else { return .none }
                state.isCustomEPGLoading = true
                return .run { send in
                    await send(.refreshCustomEPGSourceResponse(id: id, result: TaskResult {
                        try await customEPGMappingClient.refreshSource(id)
                    }))
                }

            case let .refreshCustomEPGSourceResponse(id, .success(source)):
                state.isCustomEPGLoading = false
                if let idx = state.customEPGSources.firstIndex(where: { $0.id == source.id }) {
                    state.customEPGSources[idx] = source
                }
                state.customEPGSourceErrors.removeValue(forKey: id)
                return .none

            case let .refreshCustomEPGSourceResponse(id, .failure(error)):
                state.isCustomEPGLoading = false
                if state.customEPGSources.contains(where: { $0.id == id }) {
                    state.customEPGSourceErrors[id] = error.localizedDescription
                }
                return .none

            case .refreshAllCustomEPGSources:
                guard !state.isCustomEPGLoading else { return .none }
                state.isCustomEPGLoading = true
                return .run { send in
                    let summary = await customEPGMappingClient.refreshAllSources()
                    await send(.refreshAllCustomEPGSourcesCompleted(summary))
                }

            case let .refreshAllCustomEPGSourcesCompleted(summary):
                state.isCustomEPGLoading = false
                state.customEPGSources = customEPGMappingClient.getSources()
                let currentSourceIDs = Set(state.customEPGSources.map(\.id))
                state.customEPGSourceErrors = state.customEPGSourceErrors.filter { currentSourceIDs.contains($0.key) }
                for sourceID in summary.refreshedSourceIDs {
                    state.customEPGSourceErrors.removeValue(forKey: sourceID)
                }
                for failure in summary.failures where currentSourceIDs.contains(failure.sourceID) {
                    state.customEPGSourceErrors[failure.sourceID] = failure.message
                }
                return .none

            case .retryFailedCustomEPGSources:
                guard !state.isCustomEPGLoading else { return .none }
                let failedSources = state.customEPGSources.filter {
                    $0.isEnabled && state.customEPGSourceErrors[$0.id] != nil
                }
                guard !failedSources.isEmpty else { return .none }

                state.isCustomEPGLoading = true
                return .run { send in
                    var failures: [String: String] = [:]
                    for source in failedSources {
                        do {
                            _ = try await customEPGMappingClient.refreshSource(source.id)
                        } catch {
                            failures[source.id] = error.localizedDescription
                        }
                    }
                    await send(.retryFailedCustomEPGSourcesCompleted(
                        attemptedIDs: failedSources.map(\.id),
                        failures: failures
                    ))
                }

            case let .retryFailedCustomEPGSourcesCompleted(attemptedIDs, failures):
                state.isCustomEPGLoading = false
                state.customEPGSources = customEPGMappingClient.getSources()
                let currentSourceIDs = Set(state.customEPGSources.map(\.id))
                state.customEPGSourceErrors = state.customEPGSourceErrors.filter { currentSourceIDs.contains($0.key) }
                for sourceID in attemptedIDs {
                    state.customEPGSourceErrors.removeValue(forKey: sourceID)
                }
                for (sourceID, message) in failures where currentSourceIDs.contains(sourceID) {
                    state.customEPGSourceErrors[sourceID] = message
                }
                return .none

            // iCloud Cross-Device Sync (Madde #24)
            case .syncNowTapped:
                guard !state.isCloudSyncing else { return .none }
                state.isCloudSyncing = true
                state.cloudSyncStatus = .syncing
                state.cloudSyncMessage = nil
                return .run { send in
                    await send(.syncNowResponse(TaskResult {
                        try await cloudSyncClient.performFullSync()
                    }))
                }

            case let .syncNowResponse(.success(summary)):
                state.isCloudSyncing = false
                state.cloudSyncStatus = .success(summary.lastSyncDate)
                state.lastCloudSyncDate = summary.lastSyncDate
                state.cloudSyncSummary = summary
                state.cloudSyncMessage = "iCloud senkronizasyonu tamamlandı (\(summary.favoritesCount) favori, \(summary.hiddenChannelsCount) gizli kanal)."
                return .none

            case let .syncNowResponse(.failure(error)):
                state.isCloudSyncing = false
                state.cloudSyncStatus = .error(error.localizedDescription)
                state.cloudSyncMessage = "iCloud eşitleme hatası: \(error.localizedDescription)"
                return .none

            case let .cloudSyncSummaryUpdated(summary):
                state.lastCloudSyncDate = summary.lastSyncDate
                state.cloudSyncStatus = .success(summary.lastSyncDate)
                state.cloudSyncSummary = summary
                return .none

            case .startCloudSyncObservation:
                return .run { send in
                    for await summary in cloudSyncClient.observeRemoteChanges() {
                        await send(.cloudSyncSummaryUpdated(summary))
                    }
                }

            case .dismissCloudSyncMessage:
                state.cloudSyncMessage = nil
                return .none
            }
        }
    }
}
