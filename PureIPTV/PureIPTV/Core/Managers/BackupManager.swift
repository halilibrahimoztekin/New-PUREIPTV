import Foundation
import SwiftData

public struct PureIPTVBackupData: Codable, Sendable {
    public let appVersion: String
    public let backupDate: Date
    public let preferredAudioLanguage: String?
    public let preferredSubtitleLanguage: String?
    public let hideAdultContent: Bool?
    public let defaultStartupTab: String?
    public let vodSortMethod: String?
    public let seriesSortMethod: String?
    public let customUserAgentPreset: String?
    public let customUserAgentString: String?
    public let themeColorHex: String?

    public init(
        appVersion: String = "1.0",
        backupDate: Date = Date(),
        preferredAudioLanguage: String? = nil,
        preferredSubtitleLanguage: String? = nil,
        hideAdultContent: Bool? = nil,
        defaultStartupTab: String? = nil,
        vodSortMethod: String? = nil,
        seriesSortMethod: String? = nil,
        customUserAgentPreset: String? = nil,
        customUserAgentString: String? = nil,
        themeColorHex: String? = nil
    ) {
        self.appVersion = appVersion
        self.backupDate = backupDate
        self.preferredAudioLanguage = preferredAudioLanguage
        self.preferredSubtitleLanguage = preferredSubtitleLanguage
        self.hideAdultContent = hideAdultContent
        self.defaultStartupTab = defaultStartupTab
        self.vodSortMethod = vodSortMethod
        self.seriesSortMethod = seriesSortMethod
        self.customUserAgentPreset = customUserAgentPreset
        self.customUserAgentString = customUserAgentString
        self.themeColorHex = themeColorHex
    }
}

@MainActor
public final class BackupManager: Sendable {
    public static let shared = BackupManager()

    private init() {}

    public func createBackupFile() throws -> URL {
        let defaults = UserDefaults.standard

        let backup = PureIPTVBackupData(
            appVersion: "1.0",
            backupDate: Date(),
            preferredAudioLanguage: defaults.string(forKey: "pureiptv_pref_audio_lang"),
            preferredSubtitleLanguage: defaults.string(forKey: "pureiptv_pref_sub_lang"),
            hideAdultContent: defaults.bool(forKey: "pureiptv_hide_adult_content"),
            defaultStartupTab: defaults.string(forKey: "pureiptv_startup_tab"),
            vodSortMethod: defaults.string(forKey: "pureiptv_vod_sort"),
            seriesSortMethod: defaults.string(forKey: "pureiptv_series_sort"),
            customUserAgentPreset: defaults.string(forKey: "pureiptv_user_agent_preset"),
            customUserAgentString: defaults.string(forKey: "pureiptv_user_agent_custom"),
            themeColorHex: defaults.string(forKey: "pureiptv_theme_color")
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

    public func restoreBackup(from fileURL: URL) throws -> PureIPTVBackupData {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(PureIPTVBackupData.self, from: data)

        let defaults = UserDefaults.standard
        if let audio = backup.preferredAudioLanguage {
            defaults.set(audio, forKey: "pureiptv_pref_audio_lang")
        }
        if let sub = backup.preferredSubtitleLanguage {
            defaults.set(sub, forKey: "pureiptv_pref_sub_lang")
        }
        if let hideAdult = backup.hideAdultContent {
            defaults.set(hideAdult, forKey: "pureiptv_hide_adult_content")
        }
        if let tab = backup.defaultStartupTab {
            defaults.set(tab, forKey: "pureiptv_startup_tab")
        }
        if let vodSort = backup.vodSortMethod {
            defaults.set(vodSort, forKey: "pureiptv_vod_sort")
        }
        if let serSort = backup.seriesSortMethod {
            defaults.set(serSort, forKey: "pureiptv_series_sort")
        }
        if let uap = backup.customUserAgentPreset {
            defaults.set(uap, forKey: "pureiptv_user_agent_preset")
        }
        if let uas = backup.customUserAgentString {
            defaults.set(uas, forKey: "pureiptv_user_agent_custom")
        }
        if let th = backup.themeColorHex {
            defaults.set(th, forKey: "pureiptv_theme_color")
        }

        return backup
    }
}
