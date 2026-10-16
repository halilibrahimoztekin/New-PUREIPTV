import Foundation

#if os(tvOS)
    import TVServices
#endif

// MARK: - Top Shelf Data Models

public struct TopShelfItemDTO: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let imageURL: String?
    public let deepLinkURL: String
    public let progress: Double? // 0.0 to 1.0
    public let duration: Double?
    public let isLive: Bool

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        imageURL: String? = nil,
        deepLinkURL: String,
        progress: Double? = nil,
        duration: Double? = nil,
        isLive: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.deepLinkURL = deepLinkURL
        self.progress = progress
        self.duration = duration
        self.isLive = isLive
    }
}

public struct TopShelfSectionDTO: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let items: [TopShelfItemDTO]

    public init(id: String, title: String, items: [TopShelfItemDTO]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

public struct TopShelfDataDTO: Codable, Equatable, Sendable {
    public let continueWatching: [TopShelfItemDTO]
    public let favoriteChannels: [TopShelfItemDTO]
    public let recentMovies: [TopShelfItemDTO]
    public let updatedAt: Date

    public init(
        continueWatching: [TopShelfItemDTO] = [],
        favoriteChannels: [TopShelfItemDTO] = [],
        recentMovies: [TopShelfItemDTO] = [],
        updatedAt: Date = .now
    ) {
        self.continueWatching = continueWatching
        self.favoriteChannels = favoriteChannels
        self.recentMovies = recentMovies
        self.updatedAt = updatedAt
    }
}

// MARK: - Top Shelf Service

public final class TopShelfService: @unchecked Sendable {
    public static let shared = TopShelfService()

    private let appGroupID = "group.com.pureiptv.app"
    private let topShelfKey = "PureIPTV.TopShelfData"

    private init() {}

    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
    }

    /// Verileri kaydeder ve Apple TV sistemine Top Shelf güncelleme bildirimi gönderir
    public func updateTopShelfData(
        continueWatching: [TopShelfItemDTO],
        favoriteChannels: [TopShelfItemDTO],
        recentMovies: [TopShelfItemDTO]
    ) {
        let payload = TopShelfDataDTO(
            continueWatching: continueWatching,
            favoriteChannels: favoriteChannels,
            recentMovies: recentMovies,
            updatedAt: .now
        )

        if let encoded = try? JSONEncoder().encode(payload) {
            sharedDefaults.set(encoded, forKey: topShelfKey)
        }

        #if os(tvOS)
            NotificationCenter.default.post(name: .TVTopShelfItemsDidChange, object: nil)
        #endif
    }

    /// Kaydedilen verileri okur
    public func loadTopShelfData() -> TopShelfDataDTO? {
        guard let data = sharedDefaults.data(forKey: topShelfKey) else { return nil }
        return try? JSONDecoder().decode(TopShelfDataDTO.self, from: data)
    }

    /// Deep Link URL üretici
    public static func makeDeepLink(
        id: String,
        type: String,
        title: String,
        streamURL: String,
        coverURL: String? = nil,
        startPosition: Double? = nil
    ) -> String {
        var components = URLComponents()
        components.scheme = "pureiptv"
        components.host = "play"
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "streamURL", value: streamURL),
        ]
        if let coverURL {
            queryItems.append(URLQueryItem(name: "coverURL", value: coverURL))
        }
        if let startPosition {
            queryItems.append(URLQueryItem(name: "startPosition", value: String(startPosition)))
        }
        components.queryItems = queryItems
        return components.url?.absoluteString ?? "pureiptv://play?id=\(id)"
    }
}
