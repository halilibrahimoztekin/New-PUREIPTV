import Foundation
import SwiftVLC

// MARK: - Audio & Subtitle Track Auto-Selector Engine (Madde #13)

public enum AudioTrackSelector {
    public struct SelectionResult: Equatable, Sendable {
        public let selectedTrack: Track?
        public let isAutoSelected: Bool
        public let reason: String?

        public init(selectedTrack: Track?, isAutoSelected: Bool, reason: String?) {
            self.selectedTrack = selectedTrack
            self.isAutoSelected = isAutoSelected
            self.reason = reason
        }
    }

    /// Selects the best audio track based on priority:
    /// 1. Channel-specific preferred track name (if previously set)
    /// 2. Primary global preferred language (e.g. "tr")
    /// 3. Secondary global fallback language (e.g. "en")
    /// 4. Current/Default stream track
    public static func selectAudioTrack(
        from tracks: [Track],
        channelPreferred: String?,
        primaryLanguage: String,
        secondaryLanguage: String? = nil,
        currentTrack: Track? = nil
    ) -> SelectionResult {
        guard !tracks.isEmpty else {
            return SelectionResult(selectedTrack: nil, isAutoSelected: false, reason: nil)
        }

        // 1. Channel-specific preference
        if let channelPref = channelPreferred, !channelPref.isEmpty {
            if let match = tracks.first(where: { matchesLanguage(trackName: $0.name, target: channelPref) }) {
                return SelectionResult(
                    selectedTrack: match,
                    isAutoSelected: match.id != currentTrack?.id,
                    reason: "Kanal Tercihi"
                )
            }
        }

        // 2. Primary Language Match
        if let match = tracks.first(where: { matchesLanguage(trackName: $0.name, target: primaryLanguage) }) {
            return SelectionResult(
                selectedTrack: match,
                isAutoSelected: match.id != currentTrack?.id,
                reason: "Birincil Dil: \(primaryLanguage.uppercased())"
            )
        }

        // 3. Secondary Language Match
        if let secondary = secondaryLanguage, !secondary.isEmpty,
           let match = tracks.first(where: { matchesLanguage(trackName: $0.name, target: secondary) })
        {
            return SelectionResult(
                selectedTrack: match,
                isAutoSelected: match.id != currentTrack?.id,
                reason: "Yedek Dil: \(secondary.uppercased())"
            )
        }

        // 4. Default Track (current or first)
        return SelectionResult(
            selectedTrack: currentTrack ?? tracks.first,
            isAutoSelected: false,
            reason: nil
        )
    }

    /// Selects the best subtitle track based on priority:
    /// 1. Channel-specific preferred subtitle
    /// 2. If preferred is "off", return nil
    /// 3. If primary language matches, return matched subtitle
    public static func selectSubtitleTrack(
        from tracks: [Track],
        channelPreferred: String?,
        preferredLanguage: String,
        currentTrack: Track? = nil
    ) -> SelectionResult {
        if preferredLanguage.lowercased() == "off", channelPreferred == nil || channelPreferred?.isEmpty == true {
            return SelectionResult(selectedTrack: nil, isAutoSelected: false, reason: "Kapalı")
        }

        // 1. Channel-specific preference
        if let channelPref = channelPreferred, !channelPref.isEmpty {
            if channelPref.lowercased() == "off" {
                return SelectionResult(selectedTrack: nil, isAutoSelected: currentTrack != nil, reason: "Kanal Tercihi: Kapalı")
            }
            if let match = tracks.first(where: { matchesLanguage(trackName: $0.name, target: channelPref) }) {
                return SelectionResult(selectedTrack: match, isAutoSelected: match.id != currentTrack?.id, reason: "Kanal Tercihi")
            }
        }

        // 2. Global preferred subtitle
        if let match = tracks.first(where: { matchesLanguage(trackName: $0.name, target: preferredLanguage) }) {
            return SelectionResult(
                selectedTrack: match,
                isAutoSelected: match.id != currentTrack?.id,
                reason: "Tercih Edilen Altyazı"
            )
        }

        return SelectionResult(selectedTrack: currentTrack, isAutoSelected: false, reason: nil)
    }

    /// Check if a track name matches a target language code or name
    public static func matchesLanguage(trackName: String, target: String) -> Bool {
        let t = trackName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let p = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if t == p {
            return true
        }
        if t.contains(p) || p.contains(t) {
            return true
        }

        let aliases: [Set<String>] = [
            ["tr", "tur", "turkish", "türkçe", "turkce"],
            ["en", "eng", "english", "ingilizce", "i̇ngilizce", "original", "orig"],
            ["de", "ger", "deu", "german", "almanca", "deutsch"],
            ["fr", "fra", "fre", "french", "fransızca", "français", "francais"],
            ["es", "spa", "spanish", "ispanyolca", "español", "espanol"],
            ["it", "ita", "italian", "italyanca", "italiano"],
            ["ru", "rus", "russian", "rusça", "rusca"],
            ["ar", "ara", "arabic", "arapça", "arapca"],
            ["pt", "por", "portuguese", "portekizce", "portugues", "português"],
            ["nl", "nld", "dut", "dutch", "hollandaca", "nederlands"],
            ["ja", "jpn", "japanese", "japonca"],
            ["ko", "kor", "korean", "korece"],
            ["zh", "zho", "chi", "chinese", "çince", "cince"],
            ["az", "aze", "azerbaijani", "azerice", "azeri"],
            ["pl", "pol", "polish", "lehçe", "lehce"],
            ["uk", "ukr", "ukrainian", "ukraynaca"],
            ["hi", "hin", "hindi", "hintçe", "hintce"],
        ]

        for group in aliases {
            let matchesP = group.contains(where: { p.contains($0) || $0 == p })
            let matchesT = group.contains(where: { t.contains($0) || $0 == t })
            if matchesP, matchesT {
                return true
            }
        }
        return false
    }
}
