import Foundation
import SwiftData

public struct PureIPTVBackupData: Codable, Sendable {
    public let appVersion: String
    public let backupDate: Date
    public let preferredAudioLanguage: String?
    public let preferredSubtitleLanguage: String?
    public let subtitleAppearanceProfile: String?
    public let playbackDefaultsByKind: [String: PlaybackDefaults]?
    public let hideAdultContent: Bool?
    public let defaultStartupTab: String?
    public let defaultStartupTabsByProfile: [String: String]?
    public let vodSortMethod: String?
    public let seriesSortMethod: String?
    public let customUserAgentPreset: String?
    public let customUserAgentString: String?
    public let themeColorHex: String?
    public let themePresetID: String?

    public init(
        appVersion: String = "1.0",
        backupDate: Date = Date(),
        preferredAudioLanguage: String? = nil,
        preferredSubtitleLanguage: String? = nil,
        subtitleAppearanceProfile: String? = nil,
        playbackDefaultsByKind: [String: PlaybackDefaults]? = nil,
        hideAdultContent: Bool? = nil,
        defaultStartupTab: String? = nil,
        defaultStartupTabsByProfile: [String: String]? = nil,
        vodSortMethod: String? = nil,
        seriesSortMethod: String? = nil,
        customUserAgentPreset: String? = nil,
        customUserAgentString: String? = nil,
        themeColorHex: String? = nil,
        themePresetID: String? = nil
    ) {
        self.appVersion = appVersion
        self.backupDate = backupDate
        self.preferredAudioLanguage = preferredAudioLanguage
        self.preferredSubtitleLanguage = preferredSubtitleLanguage
        self.subtitleAppearanceProfile = subtitleAppearanceProfile
        self.playbackDefaultsByKind = playbackDefaultsByKind
        self.hideAdultContent = hideAdultContent
        self.defaultStartupTab = defaultStartupTab
        self.defaultStartupTabsByProfile = defaultStartupTabsByProfile
        self.vodSortMethod = vodSortMethod
        self.seriesSortMethod = seriesSortMethod
        self.customUserAgentPreset = customUserAgentPreset
        self.customUserAgentString = customUserAgentString
        self.themeColorHex = themeColorHex
        self.themePresetID = themePresetID
    }
}

public struct PureIPTVBackupPreview: Equatable, Sendable {
    public let appVersion: String
    public let backupDate: Date
    public let fileSizeBytes: Int
    public let includedSettings: [String]
    public let existingSettingsToOverwrite: Int
}

@MainActor
public final class BackupManager: Sendable {
    public static let shared = BackupManager()

    static let maximumBackupFileSize = 1_048_576

    private init() {}

    public func createBackupFile() throws -> URL {
        let defaults = UserDefaults.standard
        let vodPlaybackDefaults = PlaybackDefaultsStore.load(for: .vod, defaults: defaults)
        let playbackDefaultsByKind = Dictionary(
            uniqueKeysWithValues: PlaybackContentKind.allCases.map { kind in
                (kind.rawValue, PlaybackDefaultsStore.load(for: kind, defaults: defaults))
            }
        )
        let startupTabsByProfile = Self.profileStartupTabs(defaults: defaults)
        let activeProfileID = Self.activeProfileID(defaults: defaults)
        let activeStartupTab = activeProfileID
            .flatMap { startupTabsByProfile[$0.uuidString] }
            ?? defaults.string(forKey: StartupTabPreferenceStorageKey.legacy)
        let defaultStartupTab = activeStartupTab.flatMap { HomeTab(rawValue: $0) == nil ? nil : $0 }
            ?? "Keşfet"

        let backup = PureIPTVBackupData(
            appVersion: "1.0",
            backupDate: Date(),
            preferredAudioLanguage: vodPlaybackDefaults.preferredAudioLanguage,
            preferredSubtitleLanguage: vodPlaybackDefaults.preferredSubtitleLanguage,
            subtitleAppearanceProfile: SubtitleAppearanceProfile.selectedForNextLaunch.rawValue,
            playbackDefaultsByKind: playbackDefaultsByKind,
            hideAdultContent: defaults.object(forKey: "com.pureiptv.hideAdultContent") as? Bool,
            defaultStartupTab: defaultStartupTab,
            defaultStartupTabsByProfile: startupTabsByProfile.isEmpty ? nil : startupTabsByProfile,
            vodSortMethod: defaults.string(forKey: "com.pureiptv.vodSortMethod"),
            seriesSortMethod: defaults.string(forKey: "com.pureiptv.seriesSortMethod"),
            customUserAgentPreset: defaults.string(forKey: "pureiptv_user_agent_preset"),
            customUserAgentString: defaults.string(forKey: "pureiptv_user_agent_custom"),
            themeColorHex: defaults.string(forKey: "appThemeColorHex"),
            themePresetID: defaults.string(forKey: "appThemePresetID")
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateStr = formatter.string(from: Date())
        let filename = "PureIPTV_Backup_\(dateStr).iptvbackup"

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }

    public func previewBackup(from fileURL: URL) throws -> PureIPTVBackupPreview {
        let (backup, fileSize) = try decodeValidatedBackup(from: fileURL)
        let defaults = UserDefaults.standard
        var includedSettings: [String] = []
        var existingKeys = Set<String>()

        func include(_ title: String, keys: [String]) {
            includedSettings.append(title)
            existingKeys.formUnion(keys.filter { defaults.object(forKey: $0) != nil })
        }

        let playbackDefaultsKeys = PlaybackContentKind.allCases.map {
            "com.pureiptv.playbackDefaults.v1.\($0.rawValue)"
        }
        if backup.playbackDefaultsByKind != nil {
            include(
                "İçerik türüne göre oynatma varsayılanları",
                keys: [
                    "com.pureiptv.preferredAudioLanguage",
                    "com.pureiptv.preferredSubtitleLanguage",
                ] + playbackDefaultsKeys
            )
        } else {
            if backup.preferredAudioLanguage != nil {
                include("Tercih edilen ses dili", keys: ["com.pureiptv.preferredAudioLanguage"] + playbackDefaultsKeys)
            }
            if backup.preferredSubtitleLanguage != nil {
                include("Tercih edilen altyazı dili", keys: ["com.pureiptv.preferredSubtitleLanguage"] + playbackDefaultsKeys)
            }
        }
        if backup.hideAdultContent != nil {
            include("Yetişkin içeriğini gizle", keys: ["com.pureiptv.hideAdultContent"])
        }
        if backup.subtitleAppearanceProfile != nil {
            include("VLC altyazı görünümü", keys: [SubtitleAppearanceProfile.userDefaultsKey])
        }
        if backup.defaultStartupTab != nil || backup.defaultStartupTabsByProfile != nil {
            let profileIDs = Set(
                (backup.defaultStartupTabsByProfile ?? [:]).keys.compactMap(UUID.init(uuidString:))
            )
            var startupTabKeys = profileIDs.map(StartupTabPreferenceStorageKey.profile)
            if backup.defaultStartupTab != nil {
                startupTabKeys.append(StartupTabPreferenceStorageKey.legacy)
                if let activeProfileID = Self.activeProfileID(defaults: defaults),
                   !profileIDs.contains(activeProfileID)
                {
                    startupTabKeys.append(StartupTabPreferenceStorageKey.profile(activeProfileID))
                }
            }
            include("Başlangıç sekmesi", keys: startupTabKeys)
        }
        if backup.vodSortMethod != nil {
            include("Film sıralaması", keys: ["com.pureiptv.vodSortMethod"])
        }
        if backup.seriesSortMethod != nil {
            include("Dizi sıralaması", keys: ["com.pureiptv.seriesSortMethod"])
        }
        if backup.customUserAgentPreset != nil || backup.customUserAgentString != nil {
            include("User-Agent tercihi", keys: ["pureiptv_user_agent_preset", "pureiptv_user_agent_custom"])
        }
        if backup.themeColorHex != nil || backup.themePresetID != nil {
            include("Tema rengi", keys: ["appThemeColorHex", "appThemePresetID"])
        }

        return PureIPTVBackupPreview(
            appVersion: backup.appVersion,
            backupDate: backup.backupDate,
            fileSizeBytes: fileSize,
            includedSettings: includedSettings,
            existingSettingsToOverwrite: existingKeys.count
        )
    }

    public func restoreBackup(from fileURL: URL) throws -> PureIPTVBackupData {
        let (backup, _) = try decodeValidatedBackup(from: fileURL)
        let defaults = UserDefaults.standard
        if let audio = backup.preferredAudioLanguage {
            defaults.set(audio, forKey: "com.pureiptv.preferredAudioLanguage")
        }
        if let sub = backup.preferredSubtitleLanguage {
            defaults.set(sub, forKey: "com.pureiptv.preferredSubtitleLanguage")
        }
        if let rawProfile = backup.subtitleAppearanceProfile,
           let profile = SubtitleAppearanceProfile(rawValue: rawProfile)
        {
            defaults.set(profile.rawValue, forKey: SubtitleAppearanceProfile.userDefaultsKey)
        }
        if let scopedPlaybackDefaults = backup.playbackDefaultsByKind {
            for kind in PlaybackContentKind.allCases {
                if let value = scopedPlaybackDefaults[kind.rawValue] {
                    PlaybackDefaultsStore.save(value, for: kind, defaults: defaults)
                }
            }
        } else if backup.preferredAudioLanguage != nil || backup.preferredSubtitleLanguage != nil {
            // Older backups stored one global language choice. Apply it to every
            // content kind so previously saved scoped values cannot mask restore.
            for kind in PlaybackContentKind.allCases {
                var value = PlaybackDefaultsStore.load(for: kind, defaults: defaults)
                if let audio = backup.preferredAudioLanguage {
                    value.preferredAudioLanguage = audio
                }
                if let subtitle = backup.preferredSubtitleLanguage {
                    value.preferredSubtitleLanguage = subtitle
                }
                PlaybackDefaultsStore.save(value, for: kind, defaults: defaults)
            }
        }
        if let hideAdult = backup.hideAdultContent {
            defaults.set(hideAdult, forKey: "com.pureiptv.hideAdultContent")
        }
        if let tab = backup.defaultStartupTab {
            defaults.set(tab, forKey: StartupTabPreferenceStorageKey.legacy)
        }
        var restoredProfileIDs = Set<UUID>()
        for (rawID, tab) in backup.defaultStartupTabsByProfile ?? [:] {
            guard let profileID = UUID(uuidString: rawID) else { continue }
            defaults.set(tab, forKey: StartupTabPreferenceStorageKey.profile(profileID))
            restoredProfileIDs.insert(profileID)
        }
        if let tab = backup.defaultStartupTab,
           let activeProfileID = Self.activeProfileID(defaults: defaults),
           !restoredProfileIDs.contains(activeProfileID)
        {
            // Apply the backup's effective tab to the active profile when it has no
            // matching entry, so a local override cannot mask the restore.
            defaults.set(tab, forKey: StartupTabPreferenceStorageKey.profile(activeProfileID))
        }
        if let vodSort = backup.vodSortMethod {
            defaults.set(vodSort, forKey: "com.pureiptv.vodSortMethod")
        }
        if let serSort = backup.seriesSortMethod {
            defaults.set(serSort, forKey: "com.pureiptv.seriesSortMethod")
        }
        if let uap = backup.customUserAgentPreset {
            defaults.set(uap, forKey: "pureiptv_user_agent_preset")
        }
        if let uas = backup.customUserAgentString {
            defaults.set(uas, forKey: "pureiptv_user_agent_custom")
            UserAgentManager.shared.customUserAgentString = uas
        }
        if let uap = backup.customUserAgentPreset, let preset = UserAgentPreset(rawValue: uap) {
            UserAgentManager.shared.currentPreset = preset
        }
        if let themePresetID = backup.themePresetID,
           ThemeManager.shared.availablePresets.contains(where: { $0.id == themePresetID })
        {
            ThemeManager.shared.setThemePreset(id: themePresetID)
        } else if let themeColorHex = backup.themeColorHex {
            ThemeManager.shared.setThemeColor(hex: themeColorHex)
        }

        return backup
    }

    private func decodeValidatedBackup(from fileURL: URL) throws -> (PureIPTVBackupData, Int) {
        guard fileURL.isFileURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let fileSize = attributes[.size] as? NSNumber,
              fileSize.intValue > 0,
              fileSize.intValue <= Self.maximumBackupFileSize
        else {
            throw NSError(domain: "PureIPTVBackup", code: 1, userInfo: [NSLocalizedDescriptionKey: "Yedek dosyası boş, erişilemiyor veya 1 MB sınırını aşıyor."])
        }

        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(PureIPTVBackupData.self, from: data)
        let validPlaybackDefaults = backup.playbackDefaultsByKind.map { values in
            let knownKinds = Set(PlaybackContentKind.allCases.map(\.rawValue))
            return Set(values.keys).isSubset(of: knownKinds)
                && values.values.allSatisfy {
                    Self.isSafeString($0.preferredAudioLanguage, maximumLength: 512)
                        && Self.isSafeString($0.preferredSubtitleLanguage, maximumLength: 512)
                }
        } ?? true
        guard !backup.appVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              backup.appVersion.count <= 64,
              backup.backupDate <= Date().addingTimeInterval(5 * 60),
              Self.isSafeString(backup.preferredAudioLanguage, maximumLength: 512),
              Self.isSafeString(backup.preferredSubtitleLanguage, maximumLength: 512),
              backup.subtitleAppearanceProfile.map({ SubtitleAppearanceProfile(rawValue: $0) != nil }) ?? true,
              Self.isSafeString(backup.defaultStartupTab, maximumLength: 128),
              backup.defaultStartupTab.map({ HomeTab(rawValue: $0) != nil }) ?? true,
              backup.defaultStartupTabsByProfile.map({ startupTabs in
                  startupTabs.count <= 1000 && startupTabs.allSatisfy { rawID, tab in
                      UUID(uuidString: rawID) != nil
                          && Self.isSafeString(tab, maximumLength: 128)
                          && HomeTab(rawValue: tab) != nil
                  }
              }) ?? true,
              Self.isSafeString(backup.vodSortMethod, maximumLength: 128),
              backup.vodSortMethod.map({ SortMethod(rawValue: $0) != nil }) ?? true,
              Self.isSafeString(backup.seriesSortMethod, maximumLength: 128),
              backup.seriesSortMethod.map({ SortMethod(rawValue: $0) != nil }) ?? true,
              Self.isSafeString(backup.customUserAgentPreset, maximumLength: 128),
              backup.customUserAgentPreset.map({ UserAgentPreset(rawValue: $0) != nil }) ?? true,
              Self.isSafeString(backup.customUserAgentString, maximumLength: 512),
              Self.isValidThemeColor(backup.themeColorHex),
              Self.isSafeString(backup.themePresetID, maximumLength: 64),
              backup.themePresetID.map({ presetID in ThemeManager.shared.availablePresets.contains(where: { $0.id == presetID }) }) ?? true,
              validPlaybackDefaults
        else {
            throw NSError(domain: "PureIPTVBackup", code: 2, userInfo: [NSLocalizedDescriptionKey: "Yedek içeriği geçersiz veya desteklenmeyen değerler içeriyor."])
        }
        return (backup, fileSize.intValue)
    }

    private nonisolated static func isSafeString(_ value: String?, maximumLength: Int) -> Bool {
        guard let value else { return true }
        return value.count <= maximumLength && value.rangeOfCharacter(from: .controlCharacters) == nil
    }

    private static func activeProfileID(defaults: UserDefaults) -> UUID? {
        defaults.string(forKey: "currentProfileID").flatMap(UUID.init(uuidString:))
    }

    private static func profileStartupTabs(defaults: UserDefaults) -> [String: String] {
        var startupTabs: [String: String] = [:]
        for (key, value) in defaults.dictionaryRepresentation() {
            guard key.hasPrefix(StartupTabPreferenceStorageKey.profilePrefix),
                  let profileID = UUID(
                      uuidString: String(key.dropFirst(StartupTabPreferenceStorageKey.profilePrefix.count))
                  ),
                  let tab = value as? String,
                  HomeTab(rawValue: tab) != nil
            else { continue }
            startupTabs[profileID.uuidString] = tab
        }
        return startupTabs
    }

    private nonisolated static func isValidThemeColor(_ value: String?) -> Bool {
        guard let value else { return true }
        let normalized = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        return normalized.count == 6 && normalized.allSatisfy(\.isHexDigit)
    }
}
