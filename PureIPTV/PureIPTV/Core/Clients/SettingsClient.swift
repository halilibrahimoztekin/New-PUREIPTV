import ComposableArchitecture
import Foundation
#if os(iOS)
    import LocalAuthentication
#endif

enum StartupTabPreferenceStorageKey {
    static let legacy = "com.pureiptv.defaultStartupTab"
    static let profilePrefix = legacy + ".profile."

    static func profile(_ profileID: UUID) -> String {
        profilePrefix + profileID.uuidString
    }
}

public enum SortMethod: String, CaseIterable, Equatable, Identifiable {
    case defaultOrder = "Varsayılan"
    case alphabetical = "A-Z (Alfabetik)"
    case rating = "IMDb Puanı"
    case dateAdded = "Eklenme Tarihi"
    case dateAddedOldest = "Eklenme Tarihi (En Eski)"

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .defaultOrder: AppStrings.Settings.defaultSort
        case .alphabetical: AppStrings.Settings.alphabeticalSort
        case .rating: AppStrings.Settings.ratingSort
        case .dateAdded: "\(AppStrings.Settings.dateAddedSort) · \(AppStrings.SeriesDetail.newestEpisodesFirst)"
        case .dateAddedOldest: "\(AppStrings.Settings.dateAddedSort) · \(AppStrings.SeriesDetail.oldestEpisodesFirst)"
        }
    }
}

public enum EPGAutoRefreshInterval: Int, CaseIterable, Equatable, Identifiable, Sendable {
    case fourHours = 4
    case twelveHours = 12
    case twentyFourHours = 24

    public var id: Int {
        rawValue
    }

    public var duration: TimeInterval {
        TimeInterval(rawValue * 60 * 60)
    }

    public var title: String {
        "\(rawValue) h"
    }
}

public enum SearchHistoryRetention: Int, CaseIterable, Equatable, Identifiable, Sendable {
    case sevenDays = 7
    case thirtyDays = 30
    case ninetyDays = 90

    public var id: Int {
        rawValue
    }

    public var duration: TimeInterval {
        TimeInterval(rawValue * 24 * 60 * 60)
    }

    public var title: String {
        switch self {
        case .sevenDays: AppStrings.Settings.searchHistorySevenDays
        case .thirtyDays: AppStrings.Settings.searchHistoryThirtyDays
        case .ninetyDays: AppStrings.Settings.searchHistoryNinetyDays
        }
    }
}

public enum LiveTVArtworkSource: String, CaseIterable, Equatable, Identifiable, Sendable {
    case epgProgram
    case channelLogo

    public static let storageKey = "com.pureiptv.liveTVArtworkSource"

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .epgProgram: AppStrings.Settings.liveTVArtworkEPG
        case .channelLogo: AppStrings.Settings.liveTVArtworkChannel
        }
    }

    public func primaryArtworkURL(for program: EPGProgram?, channel: MediaModels.Item?) -> URL? {
        if let logoOverride = channel?.logoURLOverride {
            return logoOverride
        }
        if self == .epgProgram, let artworkURL = program?.artworkURL {
            return artworkURL
        }
        return channel?.coverURL
    }
}

public struct EPGRefreshStatus: Equatable, Sendable {
    public let lastSuccessDate: Date?
    public let lastFailureDate: Date?
    public let sourceChanged: Bool

    public init(lastSuccessDate: Date? = nil, lastFailureDate: Date? = nil, sourceChanged: Bool = false) {
        self.lastSuccessDate = lastSuccessDate
        self.lastFailureDate = lastFailureDate
        self.sourceChanged = sourceChanged
    }
}

public enum EPGPreviewDelay: Int, CaseIterable, Equatable, Identifiable, Sendable {
    case off = 0
    case short = 400
    case long = 1000

    public var id: Int {
        rawValue
    }

    public var title: String {
        switch self {
        case .off: "Kapalı"
        case .short: "Kısa (0,4 sn)"
        case .long: "Uzun (1 sn)"
        }
    }
}

public enum EPGPreviewCorner: String, CaseIterable, Equatable, Identifiable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public var id: String {
        rawValue
    }

    public var isTop: Bool {
        self == .topLeft || self == .topRight
    }

    public var isLeft: Bool {
        self == .topLeft || self == .bottomLeft
    }

    public var accessibilityTitle: String {
        let verticalDirection = isTop ? AppStrings.Settings.remoteDirectionUp : AppStrings.Settings.remoteDirectionDown
        let horizontalDirection = isLeft ? AppStrings.Settings.remoteDirectionLeft : AppStrings.Settings.remoteDirectionRight
        return "\(verticalDirection), \(horizontalDirection)"
    }

    public var symbolName: String {
        switch self {
        case .topLeft: "arrow.up.left"
        case .topRight: "arrow.up.right"
        case .bottomLeft: "arrow.down.left"
        case .bottomRight: "arrow.down.right"
        }
    }
}

public struct SettingsClient: Sendable {
    public var isParentalControlEnabled: @Sendable () -> Bool = { false }
    public var getParentalPIN: @Sendable () -> String? = { nil }
    public var setParentalControl: @Sendable (_ enabled: Bool, _ pin: String?) async throws -> Void = { _, _ in }
    public var verifyPIN: @Sendable (_ pin: String) -> Bool = { _ in false }
    public var isAdultContent: @Sendable (_ text: String) -> Bool = { _ in false }
    public var authenticateWithBiometrics: @Sendable (_ reason: String) async throws -> Bool = { _ in false }

    public var getVODSortMethod: @Sendable () -> SortMethod = { .defaultOrder }
    public var setVODSortMethod: @Sendable (SortMethod) -> Void = { _ in }

    public var getSeriesSortMethod: @Sendable () -> SortMethod = { .defaultOrder }
    public var setSeriesSortMethod: @Sendable (SortMethod) -> Void = { _ in }

    public var getWatchAvailabilityRegionCode: @Sendable () -> String? = { nil }
    public var setWatchAvailabilityRegionCode: @Sendable (String?) -> Void = { _ in }

    public var getLiveTVSortOption: @Sendable () -> ChannelSortOption = { .defaultOrder }
    public var setLiveTVSortOption: @Sendable (ChannelSortOption) -> Void = { _ in }
    public var liveTVArtworkSource: @Sendable () -> LiveTVArtworkSource = { .epgProgram }
    public var setLiveTVArtworkSource: @Sendable (LiveTVArtworkSource) -> Void = { _ in }
    public var getLiveTVChannelSortOption: @Sendable (
        _ profileID: UUID?,
        _ playlistID: UUID?
    ) -> LiveTVChannelSortOption = { _, _ in .providerOrder }
    public var setLiveTVChannelSortOption: @Sendable (
        _ option: LiveTVChannelSortOption,
        _ profileID: UUID?,
        _ playlistID: UUID?
    ) -> Void = { _, _, _ in }

    // MARK: - New Settings

    public var autoPlayNextEpisode: @Sendable () -> Bool = { true }
    public var setAutoPlayNextEpisode: @Sendable (Bool) -> Void = { _ in }

    public var autoSelectFirstAlternativeSource: @Sendable () -> Bool = { false }
    public var setAutoSelectFirstAlternativeSource: @Sendable (Bool) -> Void = { _ in }

    public var reverseChannelZappingDirection: @Sendable () -> Bool = { false }
    public var setReverseChannelZappingDirection: @Sendable (Bool) -> Void = { _ in }

    public var startMuted: @Sendable () -> Bool = { false }
    public var setStartMuted: @Sendable (Bool) -> Void = { _ in }

    public var epgTimeShift: @Sendable () -> Int = { 0 }
    public var setEpgTimeShift: @Sendable (Int) -> Void = { _ in }

    public var autoUpdateEPG: @Sendable () -> Bool = { true }
    public var setAutoUpdateEPG: @Sendable (Bool) -> Void = { _ in }
    public var epgAutoRefreshInterval: @Sendable () -> EPGAutoRefreshInterval = { .fourHours }
    public var setEPGAutoRefreshInterval: @Sendable (EPGAutoRefreshInterval) -> Void = { _ in }
    public var deferAutoEPGRefreshOnConstrainedNetwork: @Sendable () -> Bool = { false }
    public var setDeferAutoEPGRefreshOnConstrainedNetwork: @Sendable (Bool) -> Void = { _ in }
    public var epgPreviewDelay: @Sendable () -> EPGPreviewDelay = { .short }
    public var setEPGPreviewDelay: @Sendable (EPGPreviewDelay) -> Void = { _ in }
    public var getEPGPreviewCorner: @Sendable () -> EPGPreviewCorner = { .topRight }
    public var setEPGPreviewCorner: @Sendable (EPGPreviewCorner) -> Void = { _ in }
    public var autoSwitchOnEPGReminder: @Sendable () -> Bool = { false }
    public var setAutoSwitchOnEPGReminder: @Sendable (Bool) -> Void = { _ in }
    public var downloadConcurrencyLimit: @Sendable () -> Int = { 1 }
    public var setDownloadConcurrencyLimit: @Sendable (Int) -> Void = { _ in }
    public var getLastEPGRefreshDate: @Sendable (_ playlistID: UUID?) -> Date? = { _ in nil }
    public var setLastEPGRefreshDate: @Sendable (_ playlistID: UUID?, _ date: Date?) -> Void = { _, _ in }
    public var getLastEPGRefreshFailureDate: @Sendable (_ playlistID: UUID?) -> Date? = { _ in nil }
    public var setLastEPGRefreshFailureDate: @Sendable (_ playlistID: UUID?, _ date: Date?) -> Void = { _, _ in }
    public var resolveEPGRefreshStatus: @Sendable (_ playlistID: UUID?, _ sourceFingerprint: String?) -> EPGRefreshStatus = { _, _ in .init() }
    public var getLastEPGAutoRefreshAttemptDate: @Sendable (_ playlistID: UUID?) -> Date? = { _ in nil }
    public var setLastEPGAutoRefreshAttemptDate: @Sendable (_ playlistID: UUID?, _ date: Date?) -> Void = { _, _ in }
    public var getEPGProviderCooldownUntil: @Sendable (_ playlistID: UUID?) -> Date? = { _ in nil }
    public var setEPGProviderCooldownUntil: @Sendable (_ playlistID: UUID?, _ date: Date?) -> Void = { _, _ in }

    public var hideAdultContent: @Sendable () -> Bool = { false }
    public var setHideAdultContent: @Sendable (Bool) -> Void = { _ in }

    public var defaultStartupTab: @Sendable () -> String = { "Keşfet" }
    public var setDefaultStartupTab: @Sendable (String) -> Void = { _ in }
    public var defaultStartupTabForProfile: @Sendable (UUID?) -> String = { _ in "Keşfet" }
    public var setDefaultStartupTabForProfile: @Sendable (UUID?, String) -> Void = { _, _ in }
    public var hideEmptyContentTabs: @Sendable () -> Bool = { true }
    public var setHideEmptyContentTabs: @Sendable (Bool) -> Void = { _ in }
    public var liveTVOnlyNavigation: @Sendable () -> Bool = { false }
    public var setLiveTVOnlyNavigation: @Sendable (Bool) -> Void = { _ in }

    public var preferredAudioLanguage: @Sendable () -> String = { "tr" }
    public var setPreferredAudioLanguage: @Sendable (String) -> Void = { _ in }

    public var secondaryAudioLanguage: @Sendable () -> String = { "en" }
    public var setSecondaryAudioLanguage: @Sendable (String) -> Void = { _ in }

    public var preferredSubtitleLanguage: @Sendable () -> String = { "off" }
    public var setPreferredSubtitleLanguage: @Sendable (String) -> Void = { _ in }
    public var subtitleTextSize: @Sendable () -> SubtitleTextSize = { .standard }
    public var setSubtitleTextSize: @Sendable (SubtitleTextSize) -> Void = { _ in }
    public var externalSubtitleTextEncoding: @Sendable () -> ExternalSubtitleTextEncoding = { .automatic }
    public var setExternalSubtitleTextEncoding: @Sendable (ExternalSubtitleTextEncoding) -> Void = { _ in }
    public var subtitleAppearanceProfile: @Sendable () -> SubtitleAppearanceProfile = { .standard }
    public var setSubtitleAppearanceProfile: @Sendable (SubtitleAppearanceProfile) -> Void = { _ in }
    public var playbackDefaults: @Sendable (_ kind: PlaybackContentKind) -> PlaybackDefaults = {
        PlaybackDefaultsStore.load(for: $0)
    }

    public var setPlaybackDefaults: @Sendable (_ kind: PlaybackContentKind, _ defaults: PlaybackDefaults) -> Void = {
        PlaybackDefaultsStore.save($1, for: $0)
    }

    public var getChannelPreferredAudioTrack: @Sendable (_ channelID: String) -> String? = { _ in nil }
    public var setChannelPreferredAudioTrack: @Sendable (_ channelID: String, _ track: String?) -> Void = { _, _ in }

    public var getChannelPreferredSubtitleTrack: @Sendable (_ channelID: String) -> String? = { _ in nil }
    public var setChannelPreferredSubtitleTrack: @Sendable (_ channelID: String, _ track: String?) -> Void = { _, _ in }

    public var rememberMediaTrackPreferences: @Sendable () -> Bool = { true }
    public var setRememberMediaTrackPreferences: @Sendable (Bool) -> Void = { _ in }

    public var isICloudSyncEnabled: @Sendable () -> Bool = { true }
    public var setIsICloudSyncEnabled: @Sendable (Bool) -> Void = { _ in }

    public var isSearchHistorySavingEnabled: @Sendable () -> Bool = { true }
    public var setIsSearchHistorySavingEnabled: @Sendable (Bool) -> Void = { _ in }
    public var searchHistoryRetention: @Sendable () -> SearchHistoryRetention = { .thirtyDays }
    public var setSearchHistoryRetention: @Sendable (SearchHistoryRetention) -> Void = { _ in }
    public var pinnedSearchQueries: @Sendable () -> [String] = { [] }
    public var setPinnedSearchQueries: @Sendable ([String]) -> Void = { _ in }

    public var isOLEDDimmingEnabled: @Sendable () -> Bool = { true }
    public var setIsOLEDDimmingEnabled: @Sendable (Bool) -> Void = { _ in }

    // MARK: - Channel Lip-Sync (Audio & Subtitle Delay) Persistence

    public var getChannelAudioDelay: @Sendable (_ channelID: String) -> Int? = { _ in nil }
    public var setChannelAudioDelay: @Sendable (_ channelID: String, _ delay: Int?) -> Void = { _, _ in }
    public var getChannelSubtitleDelay: @Sendable (_ channelID: String) -> Int? = { _ in nil }
    public var setChannelSubtitleDelay: @Sendable (_ channelID: String, _ delay: Int?) -> Void = { _, _ in }

    // MARK: - Audio Equalizer & Dialogue Enhancer (Madde #14)

    public var audioEQPreset: @Sendable () -> AudioEQPreset = { .flat }
    public var setAudioEQPreset: @Sendable (AudioEQPreset) -> Void = { _ in }
    public var getChannelAudioEQPreset: @Sendable (_ channelID: String) -> AudioEQPreset? = { _ in nil }
    public var setChannelAudioEQPreset: @Sendable (_ channelID: String, _ preset: AudioEQPreset?) -> Void = { _, _ in }

    // MARK: - Smart Channel Name Cleaner

    public var isChannelNameCleaningEnabled: @Sendable () -> Bool = { true }
    public var setIsChannelNameCleaningEnabled: @Sendable (Bool) -> Void = { _ in }
    public var showTwoLineTVChannelTitles: @Sendable () -> Bool = { false }
    public var setShowTwoLineTVChannelTitles: @Sendable (Bool) -> Void = { _ in }
}

extension SettingsClient: DependencyKey {
    public static let liveValue: SettingsClient = {
        let defaults = UserDefaults.standard
        let pinKey = "com.pureiptv.parentalPIN"
        let enabledKey = "com.pureiptv.parentalControlEnabled"
        let vodSortKey = "com.pureiptv.vodSortMethod"
        let seriesSortKey = "com.pureiptv.seriesSortMethod"
        let watchAvailabilityRegionKey = "com.pureiptv.watchAvailabilityRegionCode"
        let autoPlayKey = "com.pureiptv.autoPlayNextEpisode"
        let liveTVArtworkSourceKey = LiveTVArtworkSource.storageKey
        let autoSelectAlternativeSourceKey = "com.pureiptv.autoSelectFirstAlternativeSource"
        let reverseChannelZappingDirectionKey = "com.pureiptv.reverseChannelZappingDirection"
        let startMutedKey = "com.pureiptv.startMuted"
        let epgShiftKey = "com.pureiptv.epgTimeShift"
        let autoUpdateEpgKey = "com.pureiptv.autoUpdateEPG"
        let epgAutoRefreshIntervalKey = "com.pureiptv.epgAutoRefreshIntervalHours"
        let deferAutoEPGRefreshOnConstrainedNetworkKey = "com.pureiptv.deferAutoEPGRefreshOnConstrainedNetwork"
        let epgPreviewDelayKey = "com.pureiptv.epgPreviewDelayMilliseconds"
        let epgPreviewCornerKey = "com.pureiptv.epgPreviewCorner"
        let autoSwitchOnEPGReminderKey = "com.pureiptv.autoSwitchOnEPGReminder"
        let downloadConcurrencyLimitKey = "com.pureiptv.downloadConcurrencyLimit"
        let lastEPGRefreshPrefix = "com.pureiptv.lastEPGRefresh."
        let lastEPGRefreshFailurePrefix = "com.pureiptv.lastEPGRefreshFailure."
        let lastEPGRefreshSourcePrefix = "com.pureiptv.lastEPGRefreshSource."
        let lastEPGAutoRefreshAttemptPrefix = "com.pureiptv.lastEPGAutoRefreshAttempt."
        let epgProviderCooldownPrefix = "com.pureiptv.epgProviderCooldownUntil."
        let hideAdultKey = "com.pureiptv.hideAdultContent"
        let startupTabKey = StartupTabPreferenceStorageKey.legacy
        let hideEmptyContentTabsKey = "com.pureiptv.hideEmptyContentTabs"
        let liveTVOnlyNavigationKey = "com.pureiptv.liveTVOnlyNavigation"
        let preferredAudioKey = "com.pureiptv.preferredAudioLanguage"
        let secondaryAudioKey = "com.pureiptv.secondaryAudioLanguage"
        let preferredSubtitleKey = "com.pureiptv.preferredSubtitleLanguage"
        let subtitleTextSizeKey = "com.pureiptv.subtitleTextSize"
        let externalSubtitleTextEncodingKey = ExternalSubtitleTextEncoding.userDefaultsKey
        let rememberTracksKey = "com.pureiptv.rememberMediaTrackPreferences"
        let iCloudSyncKey = "com.pureiptv.isICloudSyncEnabled"
        let searchHistorySavingEnabledKey = "com.pureiptv.isSearchHistorySavingEnabled"
        let searchHistoryRetentionKey = "com.pureiptv.searchHistoryRetentionDays"
        let pinnedSearchQueriesKey = "com.pureiptv.pinnedSearchQueries"
        let oledDimmingKey = "com.pureiptv.isOLEDDimmingEnabled"
        let channelAudioDelayPrefix = "com.pureiptv.channelAudioDelay."
        let channelSubDelayPrefix = "com.pureiptv.channelSubDelay."
        let channelAudioTrackPrefix = "com.pureiptv.channelAudioTrack."
        let channelSubTrackPrefix = "com.pureiptv.channelSubTrack."
        let liveTVSortKey = "com.pureiptv.liveTVSortOption"
        let liveTVChannelSortKeyPrefix = "com.pureiptv.liveTVChannelSortOption.v1"
        let audioEQKey = "com.pureiptv.audioEQPreset"
        let channelEQPrefix = "com.pureiptv.channelAudioEQ."
        let channelNameCleaningKey = "com.pureiptv.isChannelNameCleaningEnabled"
        let twoLineTVChannelTitlesKey = "com.pureiptv.tvOSChannelTitlesTwoLines"

        // Set defaults for some keys
        defaults.register(defaults: [
            autoPlayKey: true,
            liveTVArtworkSourceKey: LiveTVArtworkSource.epgProgram.rawValue,
            autoUpdateEpgKey: true,
            epgAutoRefreshIntervalKey: EPGAutoRefreshInterval.fourHours.rawValue,
            deferAutoEPGRefreshOnConstrainedNetworkKey: false,
            epgPreviewDelayKey: EPGPreviewDelay.short.rawValue,
            downloadConcurrencyLimitKey: 1,
            startupTabKey: "Keşfet",
            hideEmptyContentTabsKey: true,
            liveTVOnlyNavigationKey: false,
            preferredAudioKey: "tr",
            secondaryAudioKey: "en",
            preferredSubtitleKey: "off",
            subtitleTextSizeKey: SubtitleTextSize.standard.rawValue,
            externalSubtitleTextEncodingKey: ExternalSubtitleTextEncoding.automatic.rawValue,
            SubtitleAppearanceProfile.userDefaultsKey: SubtitleAppearanceProfile.standard.rawValue,
            rememberTracksKey: true,
            iCloudSyncKey: true,
            searchHistorySavingEnabledKey: true,
            searchHistoryRetentionKey: SearchHistoryRetention.thirtyDays.rawValue,
            oledDimmingKey: true,
            audioEQKey: "flat",
            channelNameCleaningKey: true,
            twoLineTVChannelTitlesKey: false,
        ])

        return SettingsClient(
            isParentalControlEnabled: {
                defaults.bool(forKey: enabledKey)
            },
            getParentalPIN: {
                if let pin = try? KeychainManager.shared.retrieve(for: pinKey, as: String.self) {
                    return pin
                }
                // Fallback & Migration: Check legacy UserDefaults
                if let legacyPin = defaults.string(forKey: pinKey) {
                    try? KeychainManager.shared.save(legacyPin, for: pinKey)
                    defaults.removeObject(forKey: pinKey)
                    return legacyPin
                }
                return nil
            },
            setParentalControl: { enabled, pin in
                defaults.set(enabled, forKey: enabledKey)
                if let pin, enabled {
                    try? KeychainManager.shared.save(pin, for: pinKey)
                    defaults.removeObject(forKey: pinKey)
                } else {
                    try? KeychainManager.shared.delete(for: pinKey)
                    defaults.removeObject(forKey: pinKey)
                }
            },
            verifyPIN: { inputPin in
                guard defaults.bool(forKey: enabledKey) else {
                    return true // If not enabled, always verify
                }
                let savedPin = (try? KeychainManager.shared.retrieve(for: pinKey, as: String.self)) ?? defaults.string(forKey: pinKey)
                guard let savedPin else {
                    return true
                }
                return savedPin == inputPin
            },
            isAdultContent: { text in
                let lowercased = text.lowercased()
                let adultKeywords = ["adult", "xxx", "18+", "yetişkin", "porn", "erotic"]
                return adultKeywords.contains { lowercased.contains($0) }
            },
            authenticateWithBiometrics: { reason in
                #if os(tvOS)
                    // LocalAuthentication (Biometrics/FaceID) is not available on Apple TV
                    return false
                #else
                    let context = LAContext()
                    var error: NSError?

                    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                        do {
                            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                        } catch {
                            return false
                        }
                    } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                        // Fallback to passcode if biometrics are not available
                        do {
                            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                        } catch {
                            return false
                        }
                    }
                    return false
                #endif
            },
            getVODSortMethod: {
                if let raw = defaults.string(forKey: vodSortKey), let method = SortMethod(rawValue: raw) {
                    return method
                }
                return .defaultOrder
            },
            setVODSortMethod: { method in
                defaults.set(method.rawValue, forKey: vodSortKey)
            },
            getSeriesSortMethod: {
                if let raw = defaults.string(forKey: seriesSortKey), let method = SortMethod(rawValue: raw) {
                    return method
                }
                return .defaultOrder
            },
            setSeriesSortMethod: { method in
                defaults.set(method.rawValue, forKey: seriesSortKey)
            },
            getWatchAvailabilityRegionCode: {
                guard let value = defaults.string(forKey: watchAvailabilityRegionKey)?.uppercased(),
                      value.count == 2,
                      value.unicodeScalars.allSatisfy({ (65 ... 90).contains($0.value) }) else { return nil }
                return value
            },
            setWatchAvailabilityRegionCode: { value in
                guard let value else {
                    defaults.removeObject(forKey: watchAvailabilityRegionKey)
                    return
                }
                let normalized = value.uppercased()
                guard normalized.count == 2,
                      normalized.unicodeScalars.allSatisfy({ (65 ... 90).contains($0.value) })
                else {
                    defaults.removeObject(forKey: watchAvailabilityRegionKey)
                    return
                }
                defaults.set(normalized, forKey: watchAvailabilityRegionKey)
            },
            getLiveTVSortOption: {
                if let raw = defaults.string(forKey: liveTVSortKey), let opt = ChannelSortOption(rawValue: raw) {
                    return opt
                }
                return .defaultOrder
            },
            setLiveTVSortOption: { opt in
                defaults.set(opt.rawValue, forKey: liveTVSortKey)
            },
            liveTVArtworkSource: {
                LiveTVArtworkSource(rawValue: defaults.string(forKey: liveTVArtworkSourceKey) ?? "") ?? .epgProgram
            },
            setLiveTVArtworkSource: { defaults.set($0.rawValue, forKey: liveTVArtworkSourceKey) },
            getLiveTVChannelSortOption: { profileID, playlistID in
                let profileKey = profileID?.uuidString ?? "legacy"
                let playlistKey = playlistID?.uuidString ?? "default"
                let key = "\(liveTVChannelSortKeyPrefix).\(profileKey).\(playlistKey)"
                guard let rawValue = defaults.string(forKey: key) else { return .providerOrder }
                return LiveTVChannelSortOption(rawValue: rawValue) ?? .providerOrder
            },
            setLiveTVChannelSortOption: { option, profileID, playlistID in
                let profileKey = profileID?.uuidString ?? "legacy"
                let playlistKey = playlistID?.uuidString ?? "default"
                let key = "\(liveTVChannelSortKeyPrefix).\(profileKey).\(playlistKey)"
                defaults.set(option.rawValue, forKey: key)
            },
            autoPlayNextEpisode: { defaults.bool(forKey: autoPlayKey) },
            setAutoPlayNextEpisode: { defaults.set($0, forKey: autoPlayKey) },
            autoSelectFirstAlternativeSource: { defaults.bool(forKey: autoSelectAlternativeSourceKey) },
            setAutoSelectFirstAlternativeSource: { defaults.set($0, forKey: autoSelectAlternativeSourceKey) },
            reverseChannelZappingDirection: { defaults.bool(forKey: reverseChannelZappingDirectionKey) },
            setReverseChannelZappingDirection: { defaults.set($0, forKey: reverseChannelZappingDirectionKey) },
            startMuted: { defaults.bool(forKey: startMutedKey) },
            setStartMuted: { defaults.set($0, forKey: startMutedKey) },
            epgTimeShift: { defaults.integer(forKey: epgShiftKey) },
            setEpgTimeShift: { defaults.set($0, forKey: epgShiftKey) },
            autoUpdateEPG: { defaults.bool(forKey: autoUpdateEpgKey) },
            setAutoUpdateEPG: { defaults.set($0, forKey: autoUpdateEpgKey) },
            epgAutoRefreshInterval: {
                EPGAutoRefreshInterval(rawValue: defaults.integer(forKey: epgAutoRefreshIntervalKey)) ?? .fourHours
            },
            setEPGAutoRefreshInterval: { defaults.set($0.rawValue, forKey: epgAutoRefreshIntervalKey) },
            deferAutoEPGRefreshOnConstrainedNetwork: { defaults.bool(forKey: deferAutoEPGRefreshOnConstrainedNetworkKey) },
            setDeferAutoEPGRefreshOnConstrainedNetwork: { defaults.set($0, forKey: deferAutoEPGRefreshOnConstrainedNetworkKey) },
            epgPreviewDelay: {
                EPGPreviewDelay(rawValue: defaults.integer(forKey: epgPreviewDelayKey)) ?? .short
            },
            setEPGPreviewDelay: { defaults.set($0.rawValue, forKey: epgPreviewDelayKey) },
            getEPGPreviewCorner: {
                EPGPreviewCorner(rawValue: defaults.string(forKey: epgPreviewCornerKey) ?? "") ?? .topRight
            },
            setEPGPreviewCorner: { defaults.set($0.rawValue, forKey: epgPreviewCornerKey) },
            autoSwitchOnEPGReminder: { defaults.bool(forKey: autoSwitchOnEPGReminderKey) },
            setAutoSwitchOnEPGReminder: { defaults.set($0, forKey: autoSwitchOnEPGReminderKey) },
            downloadConcurrencyLimit: { min(4, max(1, defaults.integer(forKey: downloadConcurrencyLimitKey))) },
            setDownloadConcurrencyLimit: { defaults.set(min(4, max(1, $0)), forKey: downloadConcurrencyLimitKey) },
            getLastEPGRefreshDate: { playlistID in
                guard let playlistID else { return nil }
                return defaults.object(forKey: lastEPGRefreshPrefix + playlistID.uuidString) as? Date
            },
            setLastEPGRefreshDate: { playlistID, date in
                guard let playlistID else { return }
                let key = lastEPGRefreshPrefix + playlistID.uuidString
                if let date {
                    defaults.set(date, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            },
            getLastEPGRefreshFailureDate: { playlistID in
                guard let playlistID else { return nil }
                return defaults.object(forKey: lastEPGRefreshFailurePrefix + playlistID.uuidString) as? Date
            },
            setLastEPGRefreshFailureDate: { playlistID, date in
                guard let playlistID else { return }
                let key = lastEPGRefreshFailurePrefix + playlistID.uuidString
                if let date {
                    defaults.set(date, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            },
            resolveEPGRefreshStatus: { playlistID, sourceFingerprint in
                guard let playlistID,
                      let sourceFingerprint,
                      !sourceFingerprint.isEmpty else { return .init() }

                let playlistKey = playlistID.uuidString
                let sourceKey = lastEPGRefreshSourcePrefix + playlistKey
                let previousFingerprint = defaults.string(forKey: sourceKey)
                guard previousFingerprint == sourceFingerprint else {
                    defaults.removeObject(forKey: lastEPGRefreshPrefix + playlistKey)
                    defaults.removeObject(forKey: lastEPGRefreshFailurePrefix + playlistKey)
                    defaults.set(sourceFingerprint, forKey: sourceKey)
                    return EPGRefreshStatus(sourceChanged: previousFingerprint != nil)
                }

                return EPGRefreshStatus(
                    lastSuccessDate: defaults.object(forKey: lastEPGRefreshPrefix + playlistKey) as? Date,
                    lastFailureDate: defaults.object(forKey: lastEPGRefreshFailurePrefix + playlistKey) as? Date
                )
            },
            getLastEPGAutoRefreshAttemptDate: { playlistID in
                guard let playlistID else { return nil }
                return defaults.object(forKey: lastEPGAutoRefreshAttemptPrefix + playlistID.uuidString) as? Date
            },
            setLastEPGAutoRefreshAttemptDate: { playlistID, date in
                guard let playlistID else { return }
                let key = lastEPGAutoRefreshAttemptPrefix + playlistID.uuidString
                if let date {
                    defaults.set(date, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            },
            getEPGProviderCooldownUntil: { playlistID in
                guard let playlistID else { return nil }
                return defaults.object(forKey: epgProviderCooldownPrefix + playlistID.uuidString) as? Date
            },
            setEPGProviderCooldownUntil: { playlistID, date in
                guard let playlistID else { return }
                let key = epgProviderCooldownPrefix + playlistID.uuidString
                if let date {
                    defaults.set(date, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            },
            hideAdultContent: { defaults.bool(forKey: hideAdultKey) },
            setHideAdultContent: { defaults.set($0, forKey: hideAdultKey) },
            defaultStartupTab: { defaults.string(forKey: startupTabKey) ?? "Keşfet" },
            setDefaultStartupTab: { defaults.set($0, forKey: startupTabKey) },
            defaultStartupTabForProfile: { profileID in
                guard let profileID else {
                    return defaults.string(forKey: startupTabKey) ?? "Keşfet"
                }
                return defaults.string(forKey: StartupTabPreferenceStorageKey.profile(profileID))
                    ?? defaults.string(forKey: startupTabKey)
                    ?? "Keşfet"
            },
            setDefaultStartupTabForProfile: { profileID, tab in
                guard let profileID else {
                    defaults.set(tab, forKey: startupTabKey)
                    return
                }
                defaults.set(tab, forKey: StartupTabPreferenceStorageKey.profile(profileID))
            },
            hideEmptyContentTabs: { defaults.bool(forKey: hideEmptyContentTabsKey) },
            setHideEmptyContentTabs: { defaults.set($0, forKey: hideEmptyContentTabsKey) },
            liveTVOnlyNavigation: { defaults.bool(forKey: liveTVOnlyNavigationKey) },
            setLiveTVOnlyNavigation: { defaults.set($0, forKey: liveTVOnlyNavigationKey) },
            preferredAudioLanguage: { defaults.string(forKey: preferredAudioKey) ?? "tr" },
            setPreferredAudioLanguage: { defaults.set($0, forKey: preferredAudioKey) },
            secondaryAudioLanguage: { defaults.string(forKey: secondaryAudioKey) ?? "en" },
            setSecondaryAudioLanguage: { defaults.set($0, forKey: secondaryAudioKey) },
            preferredSubtitleLanguage: { defaults.string(forKey: preferredSubtitleKey) ?? "off" },
            setPreferredSubtitleLanguage: { defaults.set($0, forKey: preferredSubtitleKey) },
            subtitleTextSize: {
                SubtitleTextSize(rawValue: defaults.integer(forKey: subtitleTextSizeKey)) ?? .standard
            },
            setSubtitleTextSize: { defaults.set($0.rawValue, forKey: subtitleTextSizeKey) },
            externalSubtitleTextEncoding: {
                ExternalSubtitleTextEncoding(rawValue: defaults.string(forKey: externalSubtitleTextEncodingKey) ?? "") ?? .automatic
            },
            setExternalSubtitleTextEncoding: { defaults.set($0.rawValue, forKey: externalSubtitleTextEncodingKey) },
            subtitleAppearanceProfile: {
                SubtitleAppearanceProfile(rawValue: defaults.string(forKey: SubtitleAppearanceProfile.userDefaultsKey) ?? "") ?? .standard
            },
            setSubtitleAppearanceProfile: { defaults.set($0.rawValue, forKey: SubtitleAppearanceProfile.userDefaultsKey) },
            playbackDefaults: { PlaybackDefaultsStore.load(for: $0, defaults: defaults) },
            setPlaybackDefaults: { kind, playbackDefaults in
                PlaybackDefaultsStore.save(playbackDefaults, for: kind, defaults: defaults)
            },
            getChannelPreferredAudioTrack: { channelID in
                defaults.string(forKey: channelAudioTrackPrefix + channelID)
            },
            setChannelPreferredAudioTrack: { channelID, track in
                let key = channelAudioTrackPrefix + channelID
                if let track {
                    defaults.set(track, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            },
            getChannelPreferredSubtitleTrack: { channelID in
                defaults.string(forKey: channelSubTrackPrefix + channelID)
            },
            setChannelPreferredSubtitleTrack: { channelID, track in
                let key = channelSubTrackPrefix + channelID
                if let track {
                    defaults.set(track, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            },
            rememberMediaTrackPreferences: { defaults.bool(forKey: rememberTracksKey) },
            setRememberMediaTrackPreferences: { defaults.set($0, forKey: rememberTracksKey) },
            isICloudSyncEnabled: { defaults.bool(forKey: iCloudSyncKey) },
            setIsICloudSyncEnabled: { defaults.set($0, forKey: iCloudSyncKey) },
            isSearchHistorySavingEnabled: { defaults.bool(forKey: searchHistorySavingEnabledKey) },
            setIsSearchHistorySavingEnabled: { defaults.set($0, forKey: searchHistorySavingEnabledKey) },
            searchHistoryRetention: {
                SearchHistoryRetention(rawValue: defaults.integer(forKey: searchHistoryRetentionKey)) ?? .thirtyDays
            },
            setSearchHistoryRetention: { defaults.set($0.rawValue, forKey: searchHistoryRetentionKey) },
            pinnedSearchQueries: { defaults.stringArray(forKey: pinnedSearchQueriesKey) ?? [] },
            setPinnedSearchQueries: { defaults.set($0, forKey: pinnedSearchQueriesKey) },
            isOLEDDimmingEnabled: {
                defaults.object(forKey: oledDimmingKey) == nil ? true : defaults.bool(forKey: oledDimmingKey)
            },
            setIsOLEDDimmingEnabled: { defaults.set($0, forKey: oledDimmingKey) },
            getChannelAudioDelay: { channelID in
                guard defaults.object(forKey: channelAudioDelayPrefix + channelID) != nil else { return nil }
                return defaults.integer(forKey: channelAudioDelayPrefix + channelID)
            },
            setChannelAudioDelay: { channelID, delay in
                let key = channelAudioDelayPrefix + channelID
                if let delay {
                    defaults.set(delay, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            },
            getChannelSubtitleDelay: { channelID in
                guard defaults.object(forKey: channelSubDelayPrefix + channelID) != nil else { return nil }
                return defaults.integer(forKey: channelSubDelayPrefix + channelID)
            },
            setChannelSubtitleDelay: { channelID, delay in
                let key = channelSubDelayPrefix + channelID
                if let delay {
                    defaults.set(delay, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            },
            audioEQPreset: {
                guard let raw = defaults.string(forKey: audioEQKey),
                      let preset = AudioEQPreset(rawValue: raw)
                else {
                    return .flat
                }
                return preset
            },
            setAudioEQPreset: { preset in
                defaults.set(preset.rawValue, forKey: audioEQKey)
            },
            getChannelAudioEQPreset: { channelID in
                guard let raw = defaults.string(forKey: channelEQPrefix + channelID) else { return nil }
                return AudioEQPreset(rawValue: raw)
            },
            setChannelAudioEQPreset: { channelID, preset in
                let key = channelEQPrefix + channelID
                if let preset {
                    defaults.set(preset.rawValue, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            },
            isChannelNameCleaningEnabled: {
                defaults.object(forKey: channelNameCleaningKey) == nil ? true : defaults.bool(forKey: channelNameCleaningKey)
            },
            setIsChannelNameCleaningEnabled: { enabled in
                defaults.set(enabled, forKey: channelNameCleaningKey)
            },
            showTwoLineTVChannelTitles: { defaults.bool(forKey: twoLineTVChannelTitlesKey) },
            setShowTwoLineTVChannelTitles: { defaults.set($0, forKey: twoLineTVChannelTitlesKey) }
        )
    }()

    public static let testValue: SettingsClient = .liveValue
}

public extension DependencyValues {
    var settingsClient: SettingsClient {
        get { self[SettingsClient.self] }
        set { self[SettingsClient.self] = newValue }
    }
}
