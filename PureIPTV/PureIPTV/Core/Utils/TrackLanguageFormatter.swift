import Foundation

public struct FormattedTrackInfo: Equatable, Sendable {
    public let rawName: String
    public let displayName: String
    public let flag: String?
    public let languageName: String
    public let formatDetail: String?
    public let isSDHOrCC: Bool

    public var titleWithFlag: String {
        if let flag, !flag.isEmpty {
            return "\(flag) \(displayName)"
        }
        return displayName
    }
}

public enum TrackLanguageFormatter {
    public static func format(trackName: String, isSubtitle _: Bool = false) -> FormattedTrackInfo {
        let trimmed = trackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // 1. Detect audio / subtitle tags
        var formatDetail: String?
        if lower.contains("5.1") || lower.contains("surround") {
            formatDetail = "5.1 Surround"
        } else if lower.contains("7.1") {
            formatDetail = "7.1 Surround"
        } else if lower.contains("atmos") {
            formatDetail = "Dolby Atmos"
        } else if lower.contains("dts") {
            formatDetail = "DTS"
        } else if lower.contains("ac3") || lower.contains("ac-3") {
            formatDetail = "Dolby Digital"
        } else if lower.contains("aac") {
            formatDetail = "AAC"
        } else if lower.contains("stereo") {
            formatDetail = "Stereo"
        }

        let isSDH = lower.contains("sdh") || lower.contains("cc") || lower.contains("hearing")

        // 2. Detect language
        let (lang, flag) = detectLanguage(lower)

        let resolvedName: String
        if let lang {
            if let detail = formatDetail {
                resolvedName = "\(lang) (\(detail))"
            } else if isSDH {
                resolvedName = "\(lang) [CC]"
            } else {
                resolvedName = lang
            }
        } else {
            // Clean up common VLC noise like "Track 1 -", "Stream 2", brackets
            var sanitized = trimmed
            sanitized = sanitized.replacingOccurrences(of: "(und)", with: "", options: .caseInsensitive)
            sanitized = sanitized.replacingOccurrences(of: "[und]", with: "", options: .caseInsensitive)
            sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
            resolvedName = sanitized.isEmpty ? trackName : sanitized
        }

        return FormattedTrackInfo(
            rawName: trackName,
            displayName: resolvedName,
            flag: flag,
            languageName: lang ?? resolvedName,
            formatDetail: formatDetail,
            isSDHOrCC: isSDH
        )
    }

    private static func detectLanguage(_ text: String) -> (String?, String?) {
        let rules: [(keywords: [String], name: String, flag: String)] = [
            (["tr", "tur", "turkish", "türkçe", "turkce"], "Türkçe", "🇹🇷"),
            (["en", "eng", "english", "ingilizce", "i̇ngilizce"], "English", "🇬🇧"),
            (["de", "ger", "deu", "german", "almanca", "deutsch"], "Deutsch", "🇩🇪"),
            (["fr", "fra", "fre", "french", "fransızca", "français", "francais"], "Français", "🇫🇷"),
            (["es", "spa", "spanish", "ispanyolca", "español", "espanol"], "Español", "🇪🇸"),
            (["it", "ita", "italian", "italyanca", "italiano"], "Italiano", "🇮🇹"),
            (["ru", "rus", "russian", "rusça", "rusca"], "Русский", "🇷🇺"),
            (["ar", "ara", "arabic", "arapça", "arapca"], "العربية", "🇸🇦"),
            (["pt", "por", "portuguese", "portekizce", "portugues", "português"], "Português", "🇵🇹"),
            (["nl", "nld", "dut", "dutch", "hollandaca", "nederlands"], "Nederlands", "🇳🇱"),
            (["ja", "jpn", "japanese", "japonca"], "日本語", "🇯🇵"),
            (["ko", "kor", "korean", "korece"], "한국어", "🇰🇷"),
            (["zh", "zho", "chi", "chinese", "çince", "cince"], "中文", "🇨🇳"),
            (["az", "aze", "azerbaijani", "azerice", "azeri"], "Azərbaycanca", "🇦🇿"),
            (["pl", "pol", "polish", "lehçe", "lehce"], "Polski", "🇵🇱"),
            (["uk", "ukr", "ukrainian", "ukraynaca"], "Українська", "🇺🇦"),
            (["hi", "hin", "hindi", "hintçe", "hintce"], "हिन्दी", "🇮🇳"),
            (["el", "ell", "gre", "greek", "yunanca"], "Ελληνικά", "🇬🇷"),
            (["sv", "swe", "swedish", "isveççe"], "Svenska", "🇸🇪"),
            (["no", "nor", "norwegian", "norveççe"], "Norsk", "🇳🇴"),
            (["da", "dan", "danish", "danimarkaca"], "Dansk", "🇩🇰"),
            (["fi", "fin", "finnish", "fince"], "Suomi", "🇫🇮"),
        ]

        for rule in rules {
            for kw in rule.keywords {
                if text == kw ||
                    text.contains("[\(kw)]") ||
                    text.contains("(\(kw))") ||
                    text.contains("-\(kw)-") ||
                    text.contains(" \(kw) ") ||
                    text.hasPrefix("\(kw) ") ||
                    text.hasSuffix(" \(kw)") ||
                    (kw.count >= 4 && text.contains(kw))
                {
                    return (rule.name, rule.flag)
                }
            }
        }
        return (nil, nil)
    }
}
