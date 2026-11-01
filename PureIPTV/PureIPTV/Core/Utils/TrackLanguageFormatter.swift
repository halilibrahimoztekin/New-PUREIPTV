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
    public static func formatSubtitle(trackName: String, reportedLanguage: String?) -> FormattedTrackInfo {
        let named = format(trackName: trackName, isSubtitle: true)
        guard let reportedLanguage = reportedLanguage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !reportedLanguage.isEmpty
        else { return named }

        let language = format(trackName: reportedLanguage, isSubtitle: true)
        guard language.flag != nil || language.languageName.localizedCaseInsensitiveCompare(reportedLanguage) != .orderedSame
        else { return named }
        return FormattedTrackInfo(
            rawName: named.rawName,
            displayName: language.displayName,
            flag: language.flag ?? named.flag,
            languageName: language.languageName,
            formatDetail: named.formatDetail,
            isSDHOrCC: named.isSDHOrCC
        )
    }

    public static func format(trackName: String, isSubtitle: Bool = false) -> FormattedTrackInfo {
        let trimmed = trackName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // 1. Detect audio / subtitle tags
        let formatDetail: String? = if isSubtitle {
            subtitleFormat(in: trimmed)
        } else if lower.contains("5.1") || lower.contains("surround") {
            "5.1 Surround"
        } else if lower.contains("7.1") {
            "7.1 Surround"
        } else if lower.contains("atmos") {
            "Dolby Atmos"
        } else if lower.contains("dts") {
            "DTS"
        } else if lower.contains("ac3") || lower.contains("ac-3") {
            "Dolby Digital"
        } else if lower.contains("aac") {
            "AAC"
        } else if lower.contains("stereo") {
            "Stereo"
        } else {
            nil
        }

        let isSDH = lower.contains("sdh") || lower.contains("cc") || lower.contains("hearing")

        // 2. Detect language
        let (lang, flag) = detectLanguage(lower)

        let resolvedName: String
        if let lang {
            if !isSubtitle, let detail = formatDetail {
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

    private static func subtitleFormat(in trackName: String) -> String? {
        let supportedFormats = [
            ("webvtt", "WebVTT"),
            ("srt", "SRT"),
            ("ass", "ASS"),
            ("ssa", "SSA"),
            ("vtt", "WebVTT"),
            ("idx", "VobSub"),
            ("pgs", "PGS"),
            ("dvb", "DVB"),
            ("ttml", "TTML"),
            ("stl", "STL"),
            ("smi", "SAMI"),
            ("sbv", "SBV"),
            ("scc", "SCC"),
            ("sub", "SUB"),
        ]
        let ext = URL(fileURLWithPath: trackName).pathExtension.lowercased()
        if let format = supportedFormats.first(where: { $0.0 == ext })?.1 {
            return format
        }
        let lower = trackName.lowercased()
        for (token, format) in supportedFormats {
            let pattern = #"(?i)\b"# + NSRegularExpression.escapedPattern(for: token) + #"\b"#
            guard let expression = try? NSRegularExpression(pattern: pattern),
                  expression.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil
            else { continue }
            return format
        }
        return nil
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
