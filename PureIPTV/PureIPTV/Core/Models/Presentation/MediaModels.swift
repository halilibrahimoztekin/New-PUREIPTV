import Foundation

public enum MediaModels {
    public enum ItemType: String, Equatable {
        case live
        case vod
        case series
    }

    public struct Item: Equatable, Identifiable {
        public let id: String
        public let title: String
        public let streamURL: URL? // Nil for Series until an episode is selected
        public let coverURL: URL?
        public let categoryID: String
        public let type: ItemType

        // Optional metadata, mainly populated for VOD/Series listings
        public let rating: Double?
        public let releaseDate: String?
        public let duration: String?
        public let addedDate: Date?
        public let epgChannelID: String?

        public init(
            id: String,
            title: String,
            streamURL: URL? = nil,
            coverURL: URL? = nil,
            categoryID: String,
            type: ItemType,
            rating: Double? = nil,
            releaseDate: String? = nil,
            duration: String? = nil,
            addedDate: Date? = nil,
            epgChannelID: String? = nil
        ) {
            self.id = id
            self.title = title
            self.streamURL = streamURL
            self.coverURL = coverURL
            self.categoryID = categoryID
            self.type = type
            self.rating = rating
            self.releaseDate = releaseDate
            self.duration = duration
            self.addedDate = addedDate
            self.epgChannelID = epgChannelID
        }
    }

    public struct Category: Equatable, Identifiable {
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

    struct EPGProgram: Equatable, Identifiable {
        public let id: String
        public let title: String
        public let description: String
        public let startTime: Date
        public let endTime: Date
        public let isPlayingNow: Bool

        public init(id: String, title: String, description: String, startTime: Date, endTime: Date, isPlayingNow: Bool) {
            self.id = id
            self.title = title
            self.description = description
            self.startTime = startTime
            self.endTime = endTime
            self.isPlayingNow = isPlayingNow
        }
    }
}

public struct EPGProgram: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let startTime: Date
    public let endTime: Date
    public let isPlayingNow: Bool

    public init(id: String, title: String, description: String, startTime: Date, endTime: Date, isPlayingNow: Bool) {
        self.id = id
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.isPlayingNow = isPlayingNow
    }
}
