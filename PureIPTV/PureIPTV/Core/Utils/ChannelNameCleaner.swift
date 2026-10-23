import Foundation

// MARK: - Channel Quality Badge

public enum ChannelQualityBadge: String, Equatable, Sendable, CaseIterable {
    case uhd4k = "4K"
    case fhd1080 = "FHD"
    case hd720 = "HD"
    case sd = "SD"

    public var badgeColorHex: String {
        switch self {
        case .uhd4k: "#FFD60A" // Radiant Gold
        case .fhd1080: "#0A84FF" // Electric Blue
        case .hd720: "#30D158" // Emerald Green
        case .sd: "#8E8E93" // System Grey
        }
    }
}

// MARK: - Cleaned Channel Metadata

public struct CleanedChannelMetadata: Equatable, Sendable {
    public let originalTitle: String
    public let cleanTitle: String
    public let detectedQuality: ChannelQualityBadge?
    public let detectedCountry: String?
    public let isBackup: Bool
    public let isHEVC: Bool
    public let hasStrippedClutter: Bool

    public nonisolated init(
        originalTitle: String,
        cleanTitle: String,
        detectedQuality: ChannelQualityBadge?,
        detectedCountry: String?,
        isBackup: Bool,
        isHEVC: Bool,
        hasStrippedClutter: Bool
    ) {
        self.originalTitle = originalTitle
        self.cleanTitle = cleanTitle
        self.detectedQuality = detectedQuality
        self.detectedCountry = detectedCountry
        self.isBackup = isBackup
        self.isHEVC = isHEVC
        self.hasStrippedClutter = hasStrippedClutter
    }
}

// MARK: - Channel Name Cleaner Engine

/// Ultra-fast regex-based channel title decluttering & metadata extraction engine.
public nonisolated enum ChannelNameCleaner: Sendable {
    // MARK: - Regex Patterns

    /// 1. Country & Language Prefixes (e.g. "[TR]", "TR:", "TR -", "TR|", "[USA]", etc.)
    private static let countryPrefixRegex: NSRegularExpression = {
        let pattern = #"^(?:\[|\(|\b)(TR|TUR|TURK|TURKEY|EN|ENG|USA|US|UK|GB|DE|GER|FR|FRA|IT|ITA|ES|SPA|AR|ARA|NL|NED|AZ|AZE|PT|POR|RU|RUS|PL|POL|EX-YU|ALB|GR|GRE|SCAND)(?:\]|\)|\b)\s*[:\-\|\/]?\s*"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// 2. Trailing Country Tags (e.g. "TR", "TUR", "(TR)", "[TR]")
    private static let countrySuffixRegex: NSRegularExpression = {
        let pattern = #"\s*(?:\[|\(|\b)(TR|TUR|TURKEY|EN|ENG|USA|UK|DE|GER|FR|IT|ES|AR|NL|AZ|PT|RU)(?:\]|\)|\b)\s*$"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// 3. 4K / UHD Indicators
    private static let uhd4kRegex: NSRegularExpression = {
        let pattern = #"(?:\[|\(|\b)(?:4K[\s\-_]*UHD|4K|ULTRA[\s\-_]*HD|2160P|2160I|UHD)(?:\]|\)|\b)"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// 4. FHD / 1080p Indicators
    private static let fhdRegex: NSRegularExpression = {
        let pattern = #"(?:\[|\(|\b)(?:1080P|1080I|FHD|FULL[\s\-_]*HD)(?:\]|\)|\b)"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// 5. HD / 720p Indicators
    private static let hdRegex: NSRegularExpression = {
        let pattern = #"(?:\[|\(|\b)(?:720P|720I|HD\+|HD)(?:\]|\)|\b)"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// 6. SD Indicators
    private static let sdRegex: NSRegularExpression = {
        let pattern = #"(?:\[|\(|\b)(?:576P|576I|480P|480I|SD)(?:\]|\)|\b)"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// 7. Codecs & Audio tags (HEVC, H.265, RAW, 50fps, 60fps, Multi-audio)
    private static let codecNoiseRegex: NSRegularExpression = {
        let pattern = #"(?:\[|\(|\b|\|)(?:HEVC|H\.?265|H\.?264|AVC|RAW|50FPS|60FPS|50\s*FPS|60\s*FPS|MULTI[\s\-_]*AUDIO|MULTI[\s\-_]*SUB|DUAL)(?:\]|\)|\b|\|)"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// 8. Server / Provider Noise (VIP, PREMIUM, BACKUP, YEDEK, etc.)
    private static let providerNoiseRegex: NSRegularExpression = {
        let pattern = #"(?:\[|\(|\b|\|)(?:VIP|PREMIUM|BACKUP|YEDEK|MAIN)(?:\]|\)|\b|\|)"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// 9. Stray wrapper symbols and brackets left behind
    private static let straySymbolsRegex: NSRegularExpression = {
        let pattern = #"^[\|\-\:\/\s]+|[\|\-\:\/\s]+$|\[\s*\]|\(\s*\)"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    /// 10. Multiple spaces
    private static let multiSpaceRegex: NSRegularExpression = {
        let pattern = #"\s{2,}"#
        return try! NSRegularExpression(pattern: pattern)
    }()

    // MARK: - Cleaning & Extraction

    /// Cleans the channel title and extracts rich metadata (quality badge, country, backup, HEVC).
    public static func analyze(_ title: String) -> CleanedChannelMetadata {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CleanedChannelMetadata(
                originalTitle: title,
                cleanTitle: title,
                detectedQuality: nil,
                detectedCountry: nil,
                isBackup: false,
                isHEVC: false,
                hasStrippedClutter: false
            )
        }

        var workingTitle = trimmed
        var detectedQuality: ChannelQualityBadge?
        var detectedCountry: String?
        var isBackup = false
        var isHEVC = false

        // 1. Detect HEVC
        let fullRange = NSRange(location: 0, length: (workingTitle as NSString).length)
        if codecNoiseRegex.firstMatch(in: workingTitle, options: [], range: fullRange) != nil {
            let lower = workingTitle.lowercased()
            if lower.contains("hevc") || lower.contains("h.265") || lower.contains("h265") {
                isHEVC = true
            }
        }

        // 2. Detect Backup / Yedek
        let lower = workingTitle.lowercased()
        if lower.contains("backup") || lower.contains("yedek") {
            isBackup = true
        }

        // 3. Detect Quality (Highest priority first: 4K -> FHD -> HD -> SD)
        if uhd4kRegex.firstMatch(in: workingTitle, options: [], range: fullRange) != nil {
            detectedQuality = .uhd4k
        } else if fhdRegex.firstMatch(in: workingTitle, options: [], range: fullRange) != nil {
            detectedQuality = .fhd1080
        } else if hdRegex.firstMatch(in: workingTitle, options: [], range: fullRange) != nil {
            detectedQuality = .hd720
        } else if sdRegex.firstMatch(in: workingTitle, options: [], range: fullRange) != nil {
            detectedQuality = .sd
        }

        // 4. Extract Country Prefix
        if let match = countryPrefixRegex.firstMatch(in: workingTitle, options: [], range: fullRange), match.numberOfRanges > 1 {
            let countryRange = match.range(at: 1)
            if countryRange.location != NSNotFound {
                detectedCountry = (workingTitle as NSString).substring(with: countryRange).uppercased()
            }
            workingTitle = countryPrefixRegex.stringByReplacingMatches(
                in: workingTitle,
                options: [],
                range: match.range,
                withTemplate: ""
            )
        }

        // 5. Extract Country Suffix (if not already found at prefix)
        let afterPrefixRange = NSRange(location: 0, length: (workingTitle as NSString).length)
        if detectedCountry == nil, let match = countrySuffixRegex.firstMatch(in: workingTitle, options: [], range: afterPrefixRange), match.numberOfRanges > 1 {
            let countryRange = match.range(at: 1)
            if countryRange.location != NSNotFound {
                detectedCountry = (workingTitle as NSString).substring(with: countryRange).uppercased()
            }
            workingTitle = countrySuffixRegex.stringByReplacingMatches(
                in: workingTitle,
                options: [],
                range: match.range,
                withTemplate: ""
            )
        }

        // 6. Strip Quality tokens
        workingTitle = uhd4kRegex.stringByReplacingMatches(
            in: workingTitle,
            options: [],
            range: NSRange(location: 0, length: (workingTitle as NSString).length),
            withTemplate: " "
        )
        workingTitle = fhdRegex.stringByReplacingMatches(
            in: workingTitle,
            options: [],
            range: NSRange(location: 0, length: (workingTitle as NSString).length),
            withTemplate: " "
        )
        workingTitle = hdRegex.stringByReplacingMatches(
            in: workingTitle,
            options: [],
            range: NSRange(location: 0, length: (workingTitle as NSString).length),
            withTemplate: " "
        )
        workingTitle = sdRegex.stringByReplacingMatches(
            in: workingTitle,
            options: [],
            range: NSRange(location: 0, length: (workingTitle as NSString).length),
            withTemplate: " "
        )

        // 7. Strip Codec noise
        workingTitle = codecNoiseRegex.stringByReplacingMatches(
            in: workingTitle,
            options: [],
            range: NSRange(location: 0, length: (workingTitle as NSString).length),
            withTemplate: " "
        )

        // 8. Strip Provider noise (VIP, Backup, etc.)
        workingTitle = providerNoiseRegex.stringByReplacingMatches(
            in: workingTitle,
            options: [],
            range: NSRange(location: 0, length: (workingTitle as NSString).length),
            withTemplate: " "
        )

        // 9. Strip stray symbols and trim
        var cleaned = workingTitle
        for _ in 0 ..< 3 {
            cleaned = straySymbolsRegex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(location: 0, length: (cleaned as NSString).length),
                withTemplate: ""
            )
        }

        // 10. Collapse multiple spaces
        cleaned = multiSpaceRegex.stringByReplacingMatches(
            in: cleaned,
            options: [],
            range: NSRange(location: 0, length: (cleaned as NSString).length),
            withTemplate: " "
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        // Safety fallback: if cleaning stripped everything (e.g. channel was named literally "FHD"), revert to original
        let finalTitle = cleaned.isEmpty ? trimmed : cleaned
        let hasStripped = finalTitle != trimmed

        return CleanedChannelMetadata(
            originalTitle: trimmed,
            cleanTitle: finalTitle,
            detectedQuality: detectedQuality,
            detectedCountry: detectedCountry,
            isBackup: isBackup,
            isHEVC: isHEVC,
            hasStrippedClutter: hasStripped
        )
    }

    /// Convenience method returning just the cleaned channel title string.
    public static func clean(_ title: String) -> String {
        analyze(title).cleanTitle
    }
}

// MARK: - Presentation Extensions

public extension MediaModels.Item {
    /// Returns the clutter-stripped, clean channel title.
    var cleanTitle: String {
        ChannelNameCleaner.clean(title)
    }

    /// Full metadata analysis of channel title.
    var cleanedMetadata: CleanedChannelMetadata {
        ChannelNameCleaner.analyze(title)
    }
}

public extension PlayerFeature.PlayableItem {
    /// Returns the clutter-stripped, clean channel title.
    var cleanTitle: String {
        ChannelNameCleaner.clean(title)
    }

    /// Full metadata analysis of channel title.
    var cleanedMetadata: CleanedChannelMetadata {
        ChannelNameCleaner.analyze(title)
    }
}
