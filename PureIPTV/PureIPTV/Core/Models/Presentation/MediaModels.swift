import Foundation

public enum MediaModels: Sendable {
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
        public var displayLogoURL: URL? {
            logoURLOverride ?? coverURL
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
        public let seriesID: String?
        /// Normalized playback position restored when this item enters a MultiView slot.
        public let resumePosition: Double?

        public init(
            id: String,
            title: String,
            streamURL: URL? = nil,
            coverURL: URL? = nil,
            logoURLOverride: URL? = nil,
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
            seriesID: String? = nil,
            resumePosition: Double? = nil
        ) {
            self.id = id
            self.title = title
            self.streamURL = streamURL
            self.coverURL = coverURL
            self.logoURLOverride = logoURLOverride
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
                seriesID: seriesID,
                resumePosition: resumePosition
            )
        }

        public func replacingLogoURLOverride(_ value: URL?) -> Self {
            Self(
                id: id,
                title: title,
                streamURL: streamURL,
                coverURL: coverURL,
                logoURLOverride: value,
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
                seriesID: seriesID,
                resumePosition: resumePosition
            )
        }

        public func replacingResumePosition(_ value: Double?) -> Self {
            Self(
                id: id,
                title: title,
                streamURL: streamURL,
                coverURL: coverURL,
                logoURLOverride: logoURLOverride,
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
                seriesID: seriesID,
                resumePosition: value
            )
        }
    }

    public struct Category: Equatable, Identifiable, Sendable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
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
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }

    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startTime)
    }
}
