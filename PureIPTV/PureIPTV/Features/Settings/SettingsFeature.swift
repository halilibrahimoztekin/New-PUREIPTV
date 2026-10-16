import ComposableArchitecture
import Foundation
import Kingfisher
import RevenueCat

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
        public var epgTimeShift: Int = 0
        public var autoUpdateEPG: Bool = true
        public var hideAdultContent: Bool = false
        public var defaultStartupTab: String = "Keşfet"

        // Audio & Subtitle Language Settings (Madde #34)
        public var preferredAudioLanguage: String = "tr"
        public var preferredSubtitleLanguage: String = "off"
        public var rememberMediaTrackPreferences: Bool = true

        public var cacheSize: String = AppStrings.Settings.calculating
        public var isShowingClearCacheConfirmation: Bool = false
        public var isShowingClearCacheSuccess: Bool = false
        public var isPremium: Bool = false

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
        case setEpgTimeShift(Int)
        case setAutoUpdateEPG(Bool)
        case setHideAdultContent(Bool)
        case setDefaultStartupTab(String)
        case setPreferredAudioLanguage(String)
        case setPreferredSubtitleLanguage(String)
        case setRememberMediaTrackPreferences(Bool)

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
    }

    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.purchases) var purchases

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isParentalControlEnabled = settingsClient.isParentalControlEnabled()
                state.vodSortMethod = settingsClient.getVODSortMethod()
                state.seriesSortMethod = settingsClient.getSeriesSortMethod()

                state.autoPlayNextEpisode = settingsClient.autoPlayNextEpisode()
                state.startMuted = settingsClient.startMuted()
                state.hardwareAcceleration = settingsClient.hardwareAcceleration()
                state.epgTimeShift = settingsClient.epgTimeShift()
                state.autoUpdateEPG = settingsClient.autoUpdateEPG()
                state.hideAdultContent = settingsClient.hideAdultContent()
                state.defaultStartupTab = settingsClient.defaultStartupTab()
                state.preferredAudioLanguage = settingsClient.preferredAudioLanguage()
                state.preferredSubtitleLanguage = settingsClient.preferredSubtitleLanguage()
                state.rememberMediaTrackPreferences = settingsClient.rememberMediaTrackPreferences()

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

            case let .setEpgTimeShift(val):
                state.epgTimeShift = val
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
            }
        }
    }
}
