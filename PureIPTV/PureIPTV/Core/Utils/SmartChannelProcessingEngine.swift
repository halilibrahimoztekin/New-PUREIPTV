import Foundation

// MARK: - Smart Channel Processing Engine (Madde #54 & #92)

/// Automatic channel title cleaning and rule-based categorization engine.
/// Cleans clutter prefixes (TR:, VIP_, | FHD |) and infers categories for uncategorized M3U playlists.
public enum SmartChannelProcessingEngine: Sendable {
    public struct ProcessedChannel: Sendable, Equatable {
        public let cleanTitle: String
        public let inferredCategory: String
        public let qualityBadge: String?

        public init(cleanTitle: String, inferredCategory: String, qualityBadge: String? = nil) {
            self.cleanTitle = cleanTitle
            self.inferredCategory = inferredCategory
            self.qualityBadge = qualityBadge
        }
    }

    /// Cleans the channel title and extracts a quality badge (4K, FHD, HEVC, HD, etc.)
    public static func cleanTitle(_ rawTitle: String) -> (title: String, quality: String?) {
        var text = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Detect and extract quality badge
        var detectedQuality: String?
        let lower = text.lowercased()

        if lower.contains("4k") || lower.contains("uhd") || lower.contains("2160p") {
            detectedQuality = "4K UHD"
        } else if lower.contains("hevc") || lower.contains("h.265") || lower.contains("x265") {
            detectedQuality = "HEVC"
        } else if lower.contains("fhd") || lower.contains("1080p") || lower.contains("1080i") {
            detectedQuality = "FHD"
        } else if lower.contains("hd") || lower.contains("720p") {
            detectedQuality = "HD"
        }

        // 2. Remove common country and VIP prefix tags: "TR:", "TR |", "TR -", "VIP_", etc.
        let prefixRegexes = [
            #"^(TR|EN|DE|FR|AR|ES|IT|NL|RU|AZ|VIP|UHD|4K)[\s]*[:\|\-_\.]\s*"#,
            #"^\[(TR|EN|DE|FR|AR|ES|VIP)\]\s*"#,
            #"^\((TR|EN|DE|FR|AR|ES|VIP)\)\s*"#,
        ]

        for pattern in prefixRegexes {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: text.utf16.count)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            }
        }

        // 3. Remove quality noise patterns inside brackets or pipes: "| FHD |", "[4K]", "(1080p)"
        let noisePatterns = [
            #"\|\s*(4K|UHD|FHD|1080P|1080I|HD|720P|HEVC|H\.265|RAW|50FPS|60FPS|VIP)\s*\|"#,
            #"\[\s*(4K|UHD|FHD|1080P|1080I|HD|720P|HEVC|H\.265|RAW|50FPS|60FPS|VIP)\s*\]"#,
            #"\(\s*(4K|UHD|FHD|1080P|1080I|HD|720P|HEVC|H\.265|RAW|50FPS|60FPS|VIP)\s*\)"#,
            #"\s*\|\s*(4K|UHD|FHD|HD|HEVC)\s*$"#,
            #"\s*-\s*(4K|UHD|FHD|HD|HEVC)\s*$"#,
        ]

        for pattern in noisePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: text.utf16.count)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
            }
        }

        // Clean up redundant trailing or leading pipes, dashes, and extra spaces
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " -_|:[]()"))
        text = text.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)

        let finalTitle = text.isEmpty ? rawTitle : text
        return (finalTitle, detectedQuality)
    }

    /// Infers an appropriate category if none exists or if labeled as "Uncategorized"
    public static func inferCategory(title: String, existingGroup: String?) -> String {
        let trimmedGroup = existingGroup?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lowerGroup = trimmedGroup.lowercased()

        // If a meaningful category already exists, keep it
        let isGeneric = lowerGroup.isEmpty ||
            lowerGroup == "uncategorized" ||
            lowerGroup == "default" ||
            lowerGroup == "unknown" ||
            lowerGroup == "all" ||
            lowerGroup == "genel" ||
            lowerGroup == "diğer" ||
            lowerGroup == "channels"

        if !isGeneric {
            return trimmedGroup
        }

        let lower = title.lowercased()

        // 1. Spor (Sports)
        let sportsKeywords = [
            "spor", "sport", "bein", "exxen", "s sport", "tivibu spor", "eurosport",
            "dazn", "nba", "f1", "formula", "football", "lig tv", "smart spor",
            "arena sport", "sky sport", "espn", "supersport", "futbol", "golf",
        ]
        if sportsKeywords.contains(where: { lower.contains($0) }) {
            return "Spor"
        }

        // 2. Haber (News)
        let newsKeywords = [
            "haber", "news", "cnn", "bbc", "ntv", "haberturk", "habertürk", "a haber",
            "trthaber", "trt haber", "al jazeera", "euronews", "bloomberg", "tgrt",
            "tele 1", "halk tv", "sozcu", "sözcü", "sky news", "france 24",
        ]
        if newsKeywords.contains(where: { lower.contains($0) }) {
            return "Haber"
        }

        // 3. Sinema & Film (Cinema / Movies)
        let cinemaKeywords = [
            "sinema", "cinema", "film", "movie", "hbo", "beur sinema", "d-smart film",
            "tivibu sinema", "action", "comedy", "drama", "box office", "showtime",
            "cine", "movietv", "filmbox", "paramount",
        ]
        if cinemaKeywords.contains(where: { lower.contains($0) }) {
            return "Sinema"
        }

        // 4. Belgesel (Documentary)
        let docKeywords = [
            "belgesel", "doc", "nat geo", "national geographic", "discovery", "history",
            "animal planet", "dmax", "tlc", "bbc earth", "science", "wild", "investigation",
            "viasat", "trt belgesel",
        ]
        if docKeywords.contains(where: { lower.contains($0) }) {
            return "Belgesel"
        }

        // 5. Çocuk (Kids)
        let kidsKeywords = [
            "cocuk", "çocuk", "kids", "cartoon", "disney", "minika", "trtcocuk", "trt çocuk",
            "nickelodeon", "baby tv", "boomerang", "nick jr", "cbeebies", "animasyon",
        ]
        if kidsKeywords.contains(where: { lower.contains($0) }) {
            return "Çocuk"
        }

        // 6. Müzik (Music)
        let musicKeywords = [
            "muzik", "müzik", "music", "mtv", "kral", "powerturk", "power turk", "nrj",
            "trace", "number one", "dream tv", "mezz",
        ]
        if musicKeywords.contains(where: { lower.contains($0) }) {
            return "Müzik"
        }

        // 7. Ulusal / Ulusal Kanallar (National / General)
        let nationalKeywords = [
            "trt 1", "trt 2", "atv", "kanal d", "show tv", "star tv", "tv8", "tv8.5",
            "now tv", "fox", "beyaz tv", "teve2", "kanal 7", "ülke tv", "tv 100",
            "24 tv", "a2", "akilli tv", "flash",
        ]
        if nationalKeywords.contains(where: { lower.contains($0) }) {
            return "Ulusal"
        }

        return "Genel Kanallar"
    }

    /// High-level processor for an M3U channel
    public static func process(rawTitle: String, groupTitle: String?) -> ProcessedChannel {
        let (cleaned, quality) = cleanTitle(rawTitle)
        let category = inferCategory(title: rawTitle, existingGroup: groupTitle)
        return ProcessedChannel(cleanTitle: cleaned, inferredCategory: category, qualityBadge: quality)
    }
}
