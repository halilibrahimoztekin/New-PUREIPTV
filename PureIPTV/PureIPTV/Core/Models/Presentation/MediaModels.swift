import Foundation

public enum LocalTimePresentation {
    public static func string(from date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale))
    }
}

public enum EPGArtworkURL {
    public static func parse(_ rawValue: String?) -> URL? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty
        else { return nil }
        return components.url
    }
}

public nonisolated enum MediaModels: Sendable {
    /// Safe, display-only description of a media-server playback source.
    /// The source identifier is sent back to the server for fresh resolution; URLs and headers stay private.
    public struct MediaServerPlaybackOption: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let detail: String?
        public var displayLabel: String {
            [title, detail].compactMap(\.self).joined(separator: " · ")
        }

        public init(id: String, title: String, detail: String? = nil) {
            self.id = id
            self.title = title
            self.detail = detail
        }
    }

    public struct ServerPlaybackStatus: Equatable, Sendable {
        public enum Mode: String, Equatable, Sendable {
            case directPlay
            case directStream
            case transcoding
        }

        public enum Evidence: Equatable, Sendable {
            case serverSession
            case playbackResponse
        }

        public let mode: Mode
        public let evidence: Evidence
        public let resolution: String?
        public let bitrateKbps: Int?

        public init(mode: Mode, evidence: Evidence, resolution: String? = nil, bitrateKbps: Int? = nil) {
            self.mode = mode
            self.evidence = evidence
            self.resolution = resolution
            self.bitrateKbps = bitrateKbps
        }
    }

    public enum ItemType: String, Equatable, Sendable {
        case live
        case vod
        case series
    }

    public struct Item: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let streamURL: URL? // Nil for Series until an episode is selected
        public let coverURL: URL?
        public let logoURLOverride: URL?
        public let logoOverrideStorageKey: String?
        public let presentationOverride: MediaPresentationOverride?
        public var displayLogoURL: URL? {
            logoURLOverride ?? coverURL
        }

        public var displayTitle: String {
            presentationOverride?.title ?? title
        }

        public var displayCoverURL: URL? {
            presentationOverride?.posterURL ?? coverURL
        }

        public let categoryID: String
        public let type: ItemType
        public let originalLanguageCode: String?
        public let originalLanguageSourceValue: String?

        // Optional metadata, mainly populated for VOD/Series listings
        public let rating: Double?
        public let releaseDate: String?
        public let duration: String?
        public let addedDate: Date?
        public let epgChannelID: String?
        public let tvArchive: Int?
        public let tvArchiveDuration: Int?
        public let userAgentOverride: String?
        /// Nonsecret identity used to select authenticated artwork requests from Keychain-backed configuration.
        public let playlistID: UUID?
        /// Request-only headers returned by the media server for the current playback source.
        /// They remain transient and are never copied into persisted favorites or watch history.
        public let playbackRequestHeaders: [String: String]?
        public let serverPlaybackStatus: ServerPlaybackStatus?
        public let seriesID: String?
        /// Normalized playback position restored when this item enters a MultiView slot.
        public let resumePosition: Double?

        public init(
            id: String,
            title: String,
            streamURL: URL? = nil,
            coverURL: URL? = nil,
            logoURLOverride: URL? = nil,
            logoOverrideStorageKey: String? = nil,
            presentationOverride: MediaPresentationOverride? = nil,
            categoryID: String,
            type: ItemType,
            originalLanguageCode: String? = nil,
            originalLanguageSourceValue: String? = nil,
            rating: Double? = nil,
            releaseDate: String? = nil,
            duration: String? = nil,
            addedDate: Date? = nil,
            epgChannelID: String? = nil,
            tvArchive: Int? = nil,
            tvArchiveDuration: Int? = nil,
            userAgentOverride: String? = nil,
            playlistID: UUID? = nil,
            seriesID: String? = nil,
            resumePosition: Double? = nil,
            playbackRequestHeaders: [String: String]? = nil,
            serverPlaybackStatus: ServerPlaybackStatus? = nil
        ) {
            self.id = id
            self.title = title
            self.streamURL = streamURL
            self.coverURL = coverURL
            self.logoURLOverride = logoURLOverride
            self.logoOverrideStorageKey = logoOverrideStorageKey
            self.presentationOverride = presentationOverride
            self.categoryID = categoryID
            self.type = type
            self.originalLanguageSourceValue = originalLanguageSourceValue ?? originalLanguageCode
            self.originalLanguageCode = ISO639LanguageCode.normalize(originalLanguageSourceValue ?? originalLanguageCode)
            self.rating = rating
            self.releaseDate = releaseDate
            self.duration = duration
            self.addedDate = addedDate
            self.epgChannelID = epgChannelID
            self.tvArchive = tvArchive
            self.tvArchiveDuration = tvArchiveDuration
            self.userAgentOverride = userAgentOverride
            self.playlistID = playlistID
            self.playbackRequestHeaders = playbackRequestHeaders
            self.serverPlaybackStatus = serverPlaybackStatus
            self.seriesID = seriesID
            self.resumePosition = resumePosition.map { min(1, max(0, $0)) }
        }

        public func replacingUserAgentOverride(_ value: String?) -> Self {
            Self(
                id: id,
                title: title,
                streamURL: streamURL,
                coverURL: coverURL,
                logoURLOverride: logoURLOverride,
                logoOverrideStorageKey: logoOverrideStorageKey,
                presentationOverride: presentationOverride,
                categoryID: categoryID,
                type: type,
                originalLanguageCode: originalLanguageCode,
                originalLanguageSourceValue: originalLanguageSourceValue,
                rating: rating,
                releaseDate: releaseDate,
                duration: duration,
                addedDate: addedDate,
                epgChannelID: epgChannelID,
                tvArchive: tvArchive,
                tvArchiveDuration: tvArchiveDuration,
                userAgentOverride: value,
                playlistID: playlistID,
                seriesID: seriesID,
                resumePosition: resumePosition,
                playbackRequestHeaders: playbackRequestHeaders,
                serverPlaybackStatus: serverPlaybackStatus
            )
        }

        public func replacingPlaylistID(_ value: UUID?) -> Self {
            Self(
                id: id,
                title: title,
                streamURL: streamURL,
                coverURL: coverURL,
                logoURLOverride: logoURLOverride,
                logoOverrideStorageKey: logoOverrideStorageKey,
                presentationOverride: presentationOverride,
                categoryID: categoryID,
                type: type,
                originalLanguageCode: originalLanguageCode,
                originalLanguageSourceValue: originalLanguageSourceValue,
                rating: rating,
                releaseDate: releaseDate,
                duration: duration,
                addedDate: addedDate,
                epgChannelID: epgChannelID,
                tvArchive: tvArchive,
                tvArchiveDuration: tvArchiveDuration,
                userAgentOverride: userAgentOverride,
                playlistID: value,
                seriesID: seriesID,
                resumePosition: resumePosition,
                playbackRequestHeaders: playbackRequestHeaders,
                serverPlaybackStatus: serverPlaybackStatus
            )
        }

        public func replacingLogoURLOverride(_ value: URL?) -> Self {
            Self(
                id: id,
                title: title,
                streamURL: streamURL,
                coverURL: coverURL,
                logoURLOverride: value,
                logoOverrideStorageKey: logoOverrideStorageKey,
                presentationOverride: presentationOverride,
                categoryID: categoryID,
                type: type,
                originalLanguageCode: originalLanguageCode,
                originalLanguageSourceValue: originalLanguageSourceValue,
                rating: rating,
                releaseDate: releaseDate,
                duration: duration,
                addedDate: addedDate,
                epgChannelID: epgChannelID,
                tvArchive: tvArchive,
                tvArchiveDuration: tvArchiveDuration,
                userAgentOverride: userAgentOverride,
                playlistID: playlistID,
                seriesID: seriesID,
                resumePosition: resumePosition,
                playbackRequestHeaders: playbackRequestHeaders,
                serverPlaybackStatus: serverPlaybackStatus
            )
        }

        public func replacingResumePosition(_ value: Double?) -> Self {
            Self(
                id: id,
                title: title,
                streamURL: streamURL,
                coverURL: coverURL,
                logoURLOverride: logoURLOverride,
                logoOverrideStorageKey: logoOverrideStorageKey,
                presentationOverride: presentationOverride,
                categoryID: categoryID,
                type: type,
                originalLanguageCode: originalLanguageCode,
                originalLanguageSourceValue: originalLanguageSourceValue,
                rating: rating,
                releaseDate: releaseDate,
                duration: duration,
                addedDate: addedDate,
                epgChannelID: epgChannelID,
                tvArchive: tvArchive,
                tvArchiveDuration: tvArchiveDuration,
                userAgentOverride: userAgentOverride,
                playlistID: playlistID,
                seriesID: seriesID,
                resumePosition: value,
                playbackRequestHeaders: playbackRequestHeaders,
                serverPlaybackStatus: serverPlaybackStatus
            )
        }

        public func replacingStreamURL(_ value: URL?) -> Self {
            Self(
                id: id,
                title: title,
                streamURL: value,
                coverURL: coverURL,
                logoURLOverride: logoURLOverride,
                logoOverrideStorageKey: logoOverrideStorageKey,
                presentationOverride: presentationOverride,
                categoryID: categoryID,
                type: type,
                originalLanguageCode: originalLanguageCode,
                originalLanguageSourceValue: originalLanguageSourceValue,
                rating: rating,
                releaseDate: releaseDate,
                duration: duration,
                addedDate: addedDate,
                epgChannelID: epgChannelID,
                tvArchive: tvArchive,
                tvArchiveDuration: tvArchiveDuration,
                userAgentOverride: userAgentOverride,
                playlistID: playlistID,
                seriesID: seriesID,
                resumePosition: resumePosition,
                playbackRequestHeaders: playbackRequestHeaders,
                serverPlaybackStatus: serverPlaybackStatus
            )
        }

        public func replacingPresentationOverride(_ value: MediaPresentationOverride?) -> Self {
            Self(
                id: id,
                title: title,
                streamURL: streamURL,
                coverURL: coverURL,
                logoURLOverride: logoURLOverride,
                logoOverrideStorageKey: logoOverrideStorageKey,
                presentationOverride: value,
                categoryID: categoryID,
                type: type,
                originalLanguageCode: originalLanguageCode,
                originalLanguageSourceValue: originalLanguageSourceValue,
                rating: rating,
                releaseDate: releaseDate,
                duration: duration,
                addedDate: addedDate,
                epgChannelID: epgChannelID,
                tvArchive: tvArchive,
                tvArchiveDuration: tvArchiveDuration,
                userAgentOverride: userAgentOverride,
                playlistID: playlistID,
                seriesID: seriesID,
                resumePosition: resumePosition,
                playbackRequestHeaders: playbackRequestHeaders,
                serverPlaybackStatus: serverPlaybackStatus
            )
        }
    }

    public struct Category: Equatable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let sourceName: String

        public init(id: String, name: String, sourceName: String? = nil) {
            self.id = id
            self.name = name
            self.sourceName = sourceName ?? name
        }
    }
}

// MARK: - Placeholder Support

public extension MediaModels.Item {
    static var placeholder: MediaModels.Item {
        MediaModels.Item(
            id: UUID().uuidString,
            title: "Loading...",
            streamURL: nil,
            coverURL: nil,
            categoryID: "",
            type: .vod
        )
    }

    static var placeholders: [MediaModels.Item] {
        (0 ..< 10).map { i in
            MediaModels.Item(
                id: "placeholder_\(i)",
                title: "Loading...",
                streamURL: nil,
                coverURL: nil,
                categoryID: "",
                type: .vod
            )
        }
    }

    struct EPGProgram: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let description: String
        public let startTime: Date
        public let endTime: Date
        public let isPlayingNow: Bool
        public let categories: [String]

        public init(id: String, title: String, description: String, startTime: Date, endTime: Date, isPlayingNow: Bool, categories: [String] = []) {
            self.id = id
            self.title = title
            self.description = description
            self.startTime = startTime
            self.endTime = endTime
            self.isPlayingNow = isPlayingNow
            self.categories = categories
        }
    }
}

public struct EPGProgram: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let startTime: Date
    public let endTime: Date
    public let isPlayingNow: Bool
    public let categories: [String]
    public let artworkURL: URL?

    public init(
        id: String,
        title: String,
        description: String,
        startTime: Date,
        endTime: Date,
        isPlayingNow: Bool,
        categories: [String] = [],
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.isPlayingNow = isPlayingNow
        self.categories = categories
        self.artworkURL = artworkURL
    }
}

public extension EPGProgram {
    func progress(at date: Date = Date()) -> Double {
        let total = endTime.timeIntervalSince(startTime)
        guard total > 0 else { return 0.0 }
        let elapsed = date.timeIntervalSince(startTime)
        return max(0.0, min(1.0, elapsed / total))
    }

    func remainingMinutes(at date: Date = Date()) -> Int {
        let remaining = endTime.timeIntervalSince(date)
        return max(0, Int(remaining / 60))
    }

    func elapsedMinutes(at date: Date = Date()) -> Int {
        let elapsed = date.timeIntervalSince(startTime)
        return max(0, Int(elapsed / 60))
    }

    var formattedTimeRange: String {
        formattedTimeRange(locale: .autoupdatingCurrent)
    }

    var formattedStartTime: String {
        formattedStartTime(locale: .autoupdatingCurrent)
    }

    func formattedTimeRange(locale: Locale) -> String {
        "\(LocalTimePresentation.string(from: startTime, locale: locale)) - \(LocalTimePresentation.string(from: endTime, locale: locale))"
    }

    func formattedStartTime(locale: Locale) -> String {
        LocalTimePresentation.string(from: startTime, locale: locale)
    }
}
