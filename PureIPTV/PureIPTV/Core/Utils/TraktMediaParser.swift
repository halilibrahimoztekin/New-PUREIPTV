import Foundation

// MARK: - Parsed Trakt Media Info

public struct ParsedTraktMediaInfo: Equatable, Sendable {
    public let cleanTitle: String
    public let isEpisode: Bool
    public let season: Int?
    public let episode: Int?
    public let year: Int?

    public nonisolated init(
        cleanTitle: String,
        isEpisode: Bool,
        season: Int? = nil,
        episode: Int? = nil,
        year: Int? = nil
    ) {
        self.cleanTitle = cleanTitle
        self.isEpisode = isEpisode
        self.season = season
        self.episode = episode
        self.year = year
    }
}

// MARK: - Trakt Media Parser Engine

public nonisolated enum TraktMediaParser: Sendable {
    private static func createRegex(_ pattern: String, options: NSRegularExpression.Options = []) -> NSRegularExpression {
        (try? NSRegularExpression(pattern: pattern, options: options)) ?? NSRegularExpression()
    }

    /// 1. Season and Episode pattern (S01E05, S1E5, 1x05, 01x05)
    private static let seasonEpisodeRegex: NSRegularExpression = createRegex(
        #"(?:s|season\s*)(\d{1,2})[\s\.\-_]*(?:e|ep|episode\s*)(\d{1,3})|(\d{1,2})x(\d{1,3})"#,
        options: [.caseInsensitive]
    )

    /// 2. Year pattern (1950 - 2039)
    private static let yearRegex: NSRegularExpression = createRegex(
        #"(?:\[|\(|\b)(19[5-9]\d|20[0-3]\d)(?:\]|\)|\b)"#
    )

    /// 3. Technical clutter noise in VOD titles
    private static let vodClutterRegex: NSRegularExpression = createRegex(
        #"(?:\[|\(|\b)(?:4K|UHD|1080P|720P|FHD|HD|BLURAY|WEBDL|WEB[\-_]DL|HDRIP|REMUX|HEVC|X265|H265|X264|H264|AAC|AC3|5\.1|7\.1|DTS|DUAL|SUB|TR|EN|MULTISUB)(?:\]|\)|\b|\.)"#,
        options: [.caseInsensitive]
    )

    /// 4. File extensions (.mkv, .mp4, .avi, etc.)
    private static let fileExtensionRegex: NSRegularExpression = createRegex(
        #"\.(?:mkv|mp4|avi|mov|ts|m3u8|flv)$"#,
        options: [.caseInsensitive]
    )

    /// Parses an IPTV media title into structured movie or series episode information suitable for Trakt.
    public static func parse(title: String, seriesTitle: String? = nil, isExplicitSeries: Bool = false) -> ParsedTraktMediaInfo {
        var working = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working.isEmpty else {
            return ParsedTraktMediaInfo(cleanTitle: "", isEpisode: false)
        }

        // 1. Strip file extension
        working = fileExtensionRegex.stringByReplacingMatches(
            in: working,
            options: [],
            range: NSRange(location: 0, length: (working as NSString).length),
            withTemplate: ""
        )

        // 2. Extract Season & Episode
        var detectedSeason: Int?
        var detectedEpisode: Int?
        var isEpisode = isExplicitSeries

        let fullRange = NSRange(location: 0, length: (working as NSString).length)
        if let match = seasonEpisodeRegex.firstMatch(in: working, options: [], range: fullRange) {
            isEpisode = true
            // Pattern has two branches: (s)(e) or (season)x(episode)
            if match.range(at: 1).location != NSNotFound, match.range(at: 2).location != NSNotFound {
                detectedSeason = Int((working as NSString).substring(with: match.range(at: 1)))
                detectedEpisode = Int((working as NSString).substring(with: match.range(at: 2)))
            } else if match.range(at: 3).location != NSNotFound, match.range(at: 4).location != NSNotFound {
                detectedSeason = Int((working as NSString).substring(with: match.range(at: 3)))
                detectedEpisode = Int((working as NSString).substring(with: match.range(at: 4)))
            }

            // Remove SxxExx from title
            working = seasonEpisodeRegex.stringByReplacingMatches(
                in: working,
                options: [],
                range: match.range,
                withTemplate: " "
            )
        }

        // 3. Extract Year
        var detectedYear: Int?
        let yearSearchRange = NSRange(location: 0, length: (working as NSString).length)
        if let yearMatch = yearRegex.firstMatch(in: working, options: [], range: yearSearchRange),
           yearMatch.numberOfRanges > 1,
           yearMatch.range(at: 1).location != NSNotFound
        {
            detectedYear = Int((working as NSString).substring(with: yearMatch.range(at: 1)))
            working = yearRegex.stringByReplacingMatches(
                in: working,
                options: [],
                range: yearMatch.range,
                withTemplate: " "
            )
        }

        // 4. Strip clutter
        working = vodClutterRegex.stringByReplacingMatches(
            in: working,
            options: [],
            range: NSRange(location: 0, length: (working as NSString).length),
            withTemplate: " "
        )

        // 5. Clean up symbols (replace underscores, dots, hyphens with spaces)
        working = working.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "[", with: " ")
            .replacingOccurrences(of: "]", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")

        // 6. Condense spaces
        let trimmed = working.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // If a seriesTitle was explicitly provided and valid, use that as clean show title
        let finalTitle: String = if isEpisode, let sTitle = seriesTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !sTitle.isEmpty {
            sTitle
        } else {
            trimmed.isEmpty ? title : trimmed
        }

        return ParsedTraktMediaInfo(
            cleanTitle: finalTitle,
            isEpisode: isEpisode,
            season: detectedSeason,
            episode: detectedEpisode,
            year: detectedYear
        )
    }

    /// Convenience builder creating TraktScrobblePayload from PlayableItem and current playback progress.
    public static func makePayload(
        title: String,
        seriesTitle: String? = nil,
        isLive: Bool,
        progress: Double
    ) -> TraktScrobblePayload? {
        guard !isLive else { return nil } // Trakt only scrobbles VOD movies & episodes
        let info = parse(title: title, seriesTitle: seriesTitle)

        // Trakt requires progress between 0 and 100
        let clampedProgress = min(max(progress, 0.0), 100.0)

        return TraktScrobblePayload(
            title: info.cleanTitle,
            year: info.year,
            season: info.season,
            episode: info.episode,
            progress: clampedProgress,
            isEpisode: info.isEpisode
        )
    }
}
