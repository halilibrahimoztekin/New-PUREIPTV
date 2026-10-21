import ComposableArchitecture
import Foundation
import Kingfisher
import RevenueCat

public enum BufferProfile: String, CaseIterable, Sendable, Equatable {
    case lowLatency = "Düşük Gecikme (1s)"
    case balanced = "Dengeli (3s)"
    case smooth = "Kesintisiz / Yüksek Arabellek (8s)"

    public var seconds: Double {
        switch self {
        case .lowLatency: 1.0
        case .balanced: 3.0
        case .smooth: 8.0
        }
    }
}

@Reducer
public struct SettingsFeature {
    @ObservableState
    public struct State: Equatable {
        public var isParentalControlEnabled: Bool = false
        public var isShowingPINSetup: Bool = false
        public var pinInput: String = ""
        public var pinConfirm: String = ""
        public var step: PINStep = .enterNew
        public var errorMessage: String?
        public var vodSortMethod: SortMethod = .defaultOrder
        public var seriesSortMethod: SortMethod = .defaultOrder

        // New Settings
        public var autoPlayNextEpisode: Bool = true
        public var startMuted: Bool = false
        public var hardwareAcceleration: Bool = true
        public var isOLEDDimmingEnabled: Bool = true
        public var isChannelNameCleaningEnabled: Bool = true
        public var epgTimeShift: Int = 0
        public var autoUpdateEPG: Bool = true
        public var hideAdultContent: Bool = false
        public var defaultStartupTab: String = "Keşfet"

        // Picture-in-Picture & Background Audio (Madde #18)
        public var isAutoPiPEnabled: Bool = true
        public var backgroundPlaybackMode: BackgroundPlaybackMode = .pip

        // Audio & Subtitle Language Settings (Madde #34)
        public var preferredAudioLanguage: String = "tr"
        public var preferredSubtitleLanguage: String = "off"
        public var rememberMediaTrackPreferences: Bool = true
        public var isICloudSyncEnabled: Bool = true

        /// Frame Rate and Dynamic Range Matching (Madde #38)
        public var tvOSMatchContent: Bool = true

        /// Auto Frame Rate & Match Dynamic Range (Madde #21)
        public var isAFREnabled: Bool = true
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

        // Trakt.tv Integration (Madde #17)
        public var isTraktAuthenticated: Bool = false
        public var traktUsername: String?
        public var isTraktAutoScrobbleEnabled: Bool = true
        public var isTraktAuthSheetPresented: Bool = false
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
        public var isCustomEPGSheetPresented: Bool = false
        public var isAddCustomEPGSourceSheetPresented: Bool = false
        public var newCustomEPGName: String = ""
        public var newCustomEPGURLString: String = ""
        public var customEPGErrorMessage: String?
        public var isCustomEPGLoading: Bool = false

        public enum PINStep: Equatable {
            case enterNew
            case confirm
        }

        public init() {}
    }

    public enum Action: BindableAction {
        case managePlaylistsTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case openManagePlaylists
            case switchProfile
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
        case setStartMuted(Bool)
        case setHardwareAcceleration(Bool)
        case setOLEDDimmingEnabled(Bool)
        case setChannelNameCleaningEnabled(Bool)
        case setEpgTimeShift(Int)
        case setAutoUpdateEPG(Bool)
        case setHideAdultContent(Bool)
        case setDefaultStartupTab(String)
        case setPreferredAudioLanguage(String)
        case setPreferredSubtitleLanguage(String)
        case setRememberMediaTrackPreferences(Bool)
        case setICloudSyncEnabled(Bool)
        case setTvOSMatchContent(Bool)
        case setAFREnabled(Bool)
        case setMatchDynamicRangeEnabled(Bool)
        case setTopShelfStyle(TopShelfStyle)
        case setBufferProfile(BufferProfile)
        case setComplianceDemoMode(Bool)

        case calculateCacheSize
        case cacheSizeCalculated(String)
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
        case refreshCustomEPGSourceResponse(TaskResult<CustomEPGSource>)
        case refreshAllCustomEPGSources
        case refreshAllCustomEPGSourcesCompleted
    }

    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.purchases) var purchases
    @Dependency(\.traktClient) var traktClient
    @Dependency(\.pipClient) var pipClient
    @Dependency(\.parentalControlClient) var parentalControlClient
    @Dependency(\.displayModeClient) var displayModeClient
    @Dependency(\.topShelfClient) var topShelfClient
    @Dependency(\.customEPGMappingClient) var customEPGMappingClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Scope(state: \.traktState, action: \.traktAction) {
            TraktFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isParentalControlEnabled = settingsClient.isParentalControlEnabled()
                state.vodSortMethod = settingsClient.getVODSortMethod()
                state.seriesSortMethod = settingsClient.getSeriesSortMethod()

                state.autoPlayNextEpisode = settingsClient.autoPlayNextEpisode()
                state.startMuted = settingsClient.startMuted()
                state.hardwareAcceleration = settingsClient.hardwareAcceleration()
                state.isOLEDDimmingEnabled = settingsClient.isOLEDDimmingEnabled()
                state.isChannelNameCleaningEnabled = settingsClient.isChannelNameCleaningEnabled()
                state.epgTimeShift = settingsClient.epgTimeShift()
                state.autoUpdateEPG = settingsClient.autoUpdateEPG()
                state.hideAdultContent = settingsClient.hideAdultContent()
                state.defaultStartupTab = settingsClient.defaultStartupTab()
                state.preferredAudioLanguage = settingsClient.preferredAudioLanguage()
                state.preferredSubtitleLanguage = settingsClient.preferredSubtitleLanguage()
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
                state.isAFREnabled = displayModeClient.isAFREnabled()
                state.isMatchDynamicRangeEnabled = displayModeClient.isMatchDynamicRangeEnabled()

                // Apple TV Top Shelf Style (Madde #22)
                state.topShelfStyle = topShelfClient.getPreferredStyle()

                // Custom EPG XMLTV & Time-Shift (Madde #23)
                state.customEPGSources = customEPGMappingClient.getSources()
                state.channelEPGMappings = customEPGMappingClient.getAllMappings()

                return .merge(
                    .send(.calculateCacheSize),
                    .run { send in
                        if let info = try? await purchases.customerInfo() {
                            await send(.updatePremiumStatus(!info.entitlements.active.isEmpty))
                        }
                    }
                )

            case .managePlaylistsTapped:
                return .send(.delegate(.openManagePlaylists))

            case .switchProfileTapped:
                return .send(.delegate(.switchProfile))

            case .delegate:
                return .none

            case .binding:
                return .none

            case let .toggleParentalControl(enabled):
                if enabled {
                    // Kapatmaktan açmaya geçiyorsa PIN belirleme ekranını aç
                    state.isShowingPINSetup = true
                    state.step = .enterNew
                    state.pinInput = ""
                    state.pinConfirm = ""
                    state.errorMessage = nil
                    // Toggle'ı UI'da hemen true yapma, PIN belirlenince true yapacağız
                    return .none
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

            case let .setStartMuted(val):
                state.startMuted = val
                return .run { _ in settingsClient.setStartMuted(val) }

            case let .setHardwareAcceleration(val):
                state.hardwareAcceleration = val
                return .run { _ in settingsClient.setHardwareAcceleration(val) }

            case let .setOLEDDimmingEnabled(val):
                state.isOLEDDimmingEnabled = val
                return .run { _ in settingsClient.setIsOLEDDimmingEnabled(val) }

            case let .setChannelNameCleaningEnabled(val):
                state.isChannelNameCleaningEnabled = val
                return .run { _ in settingsClient.setIsChannelNameCleaningEnabled(val) }

            case let .setEpgTimeShift(val), let .setGlobalEPGTimeShift(val):
                state.epgTimeShift = val
                customEPGMappingClient.setGlobalTimeShift(val)
                return .run { _ in settingsClient.setEpgTimeShift(val) }

            case let .setAutoUpdateEPG(val):
                state.autoUpdateEPG = val
                return .run { _ in settingsClient.setAutoUpdateEPG(val) }

            case let .setHideAdultContent(val):
                state.hideAdultContent = val
                return .run { _ in settingsClient.setHideAdultContent(val) }

            case let .setDefaultStartupTab(val):
                state.defaultStartupTab = val
                return .run { _ in settingsClient.setDefaultStartupTab(val) }

            case let .setPreferredAudioLanguage(val):
                state.preferredAudioLanguage = val
                return .run { _ in settingsClient.setPreferredAudioLanguage(val) }

            case let .setPreferredSubtitleLanguage(val):
                state.preferredSubtitleLanguage = val
                return .run { _ in settingsClient.setPreferredSubtitleLanguage(val) }

            case let .setRememberMediaTrackPreferences(val):
                state.rememberMediaTrackPreferences = val
                return .run { _ in settingsClient.setRememberMediaTrackPreferences(val) }

            case let .setICloudSyncEnabled(val):
                state.isICloudSyncEnabled = val
                return .run { _ in
                    settingsClient.setIsICloudSyncEnabled(val)
                }

            case let .setTvOSMatchContent(enabled):
                state.tvOSMatchContent = enabled
                UserDefaults.standard.set(enabled, forKey: "pureiptv_match_content")
                return .none

            case let .setAFREnabled(enabled):
                state.isAFREnabled = enabled
                displayModeClient.setAFREnabled(enabled)
                return .none

            case let .setMatchDynamicRangeEnabled(enabled):
                state.isMatchDynamicRangeEnabled = enabled
                displayModeClient.setMatchDynamicRangeEnabled(enabled)
                return .none

            case let .setTopShelfStyle(style):
                state.topShelfStyle = style
                topShelfClient.setPreferredStyle(style)
                return .none

            case let .setBufferProfile(profile):
                state.bufferProfile = profile
                UserDefaults.standard.set(profile.rawValue, forKey: "pureiptv_buffer_profile")
                return .none

            case let .setComplianceDemoMode(enabled):
                state.isComplianceDemoMode = enabled
                ComplianceModeManager.shared.isComplianceModeActive = enabled
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
                state.isTraktAuthSheetPresented = presented
                if !presented {
                    state.isTraktAuthenticated = traktClient.isAuthenticated()
                    state.traktUsername = traktClient.currentUser()?.username
                }
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
                state.isCustomEPGSheetPresented = val
                if val {
                    state.customEPGSources = customEPGMappingClient.getSources()
                    state.channelEPGMappings = customEPGMappingClient.getAllMappings()
                    state.epgTimeShift = customEPGMappingClient.getGlobalTimeShift()
                }
                return .none

            case let .setAddCustomEPGSourceSheetPresented(val):
                state.isAddCustomEPGSourceSheetPresented = val
                state.customEPGErrorMessage = nil
                if !val {
                    state.newCustomEPGName = ""
                    state.newCustomEPGURLString = ""
                }
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
                return .none

            case let .toggleCustomEPGSource(id, enabled):
                customEPGMappingClient.toggleSource(id, enabled)
                if let idx = state.customEPGSources.firstIndex(where: { $0.id == id }) {
                    state.customEPGSources[idx].isEnabled = enabled
                }
                return .none

            case let .refreshCustomEPGSource(id):
                state.isCustomEPGLoading = true
                return .run { send in
                    await send(.refreshCustomEPGSourceResponse(TaskResult {
                        try await customEPGMappingClient.refreshSource(id)
                    }))
                }

            case let .refreshCustomEPGSourceResponse(.success(source)):
                state.isCustomEPGLoading = false
                if let idx = state.customEPGSources.firstIndex(where: { $0.id == source.id }) {
                    state.customEPGSources[idx] = source
                }
                return .none

            case let .refreshCustomEPGSourceResponse(.failure(error)):
                state.isCustomEPGLoading = false
                state.customEPGErrorMessage = "Güncelleme başarısız: \(error.localizedDescription)"
                return .none

            case .refreshAllCustomEPGSources:
                state.isCustomEPGLoading = true
                return .run { send in
                    _ = try? await customEPGMappingClient.refreshAllSources()
                    await send(.refreshAllCustomEPGSourcesCompleted)
                }

            case .refreshAllCustomEPGSourcesCompleted:
                state.isCustomEPGLoading = false
                state.customEPGSources = customEPGMappingClient.getSources()
                state.channelEPGMappings = customEPGMappingClient.getAllMappings()
                return .none
            }
        }
    }
}
