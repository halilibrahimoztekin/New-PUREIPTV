import Foundation

#if !TOPSHELF_EXTENSION
    import ComposableArchitecture
#endif

#if os(tvOS)
    import TVServices
#endif

// MARK: - Top Shelf Style

public enum TopShelfStyle: String, Codable, CaseIterable, Sendable {
    case sectioned
    case carousel

    public var title: String {
        switch self {
        case .sectioned:
            "Bölümlü Liste (Kaldığın Yerden, Favoriler, Yeni Filmler)"
        case .carousel:
            "Sinematik Vitrin (Tam Ekran Carousel)"
        }
    }
}

// MARK: - Top Shelf Data Models

public struct TopShelfItemDTO: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let summary: String?
    public let imageURL: String?
    public let landscapeImageURL: String?
    public let deepLinkURL: String
    public let progress: Double? // 0.0 to 1.0
    public let duration: Double?
    public let rating: Double?
    public let creationDate: Date?
    public let genre: String?
    public let isLive: Bool

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        summary: String? = nil,
        imageURL: String? = nil,
        landscapeImageURL: String? = nil,
        deepLinkURL: String,
        progress: Double? = nil,
        duration: Double? = nil,
        rating: Double? = nil,
        creationDate: Date? = nil,
        genre: String? = nil,
        isLive: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.imageURL = imageURL
        self.landscapeImageURL = landscapeImageURL
        self.deepLinkURL = deepLinkURL
        self.progress = progress
        self.duration = duration
        self.rating = rating
        self.creationDate = creationDate
        self.genre = genre
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
    public let preferredStyle: TopShelfStyle
    public let updatedAt: Date

    public init(
        continueWatching: [TopShelfItemDTO] = [],
        favoriteChannels: [TopShelfItemDTO] = [],
        recentMovies: [TopShelfItemDTO] = [],
        preferredStyle: TopShelfStyle = .sectioned,
        updatedAt: Date = .now
    ) {
        self.continueWatching = continueWatching
        self.favoriteChannels = favoriteChannels
        self.recentMovies = recentMovies
        self.preferredStyle = preferredStyle
        self.updatedAt = updatedAt
    }
}

// MARK: - Top Shelf Service

public final class TopShelfService: @unchecked Sendable {
    public static let shared = TopShelfService()

    private let appGroupID = "group.com.pureiptv.app"
    private let topShelfKey = "PureIPTV.TopShelfData"
    private let topShelfStyleKey = "PureIPTV.TopShelfStyle"

    private init() {}

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public var preferredStyle: TopShelfStyle {
        get {
            guard let sharedDefaults,
                  let raw = sharedDefaults.string(forKey: topShelfStyleKey),
                  let style = TopShelfStyle(rawValue: raw)
            else {
                return .sectioned
            }
            return style
        }
        set {
            guard let sharedDefaults, preferredStyle != newValue else { return }
            sharedDefaults.set(newValue.rawValue, forKey: topShelfStyleKey)
            if let payload = loadTopShelfData(), payload.preferredStyle != newValue {
                let updatedPayload = TopShelfDataDTO(
                    continueWatching: payload.continueWatching,
                    favoriteChannels: payload.favoriteChannels,
                    recentMovies: payload.recentMovies,
                    preferredStyle: newValue,
                    updatedAt: .now
                )
                if let encoded = try? JSONEncoder().encode(updatedPayload) {
                    sharedDefaults.set(encoded, forKey: topShelfKey)
                }
                notifyContentDidChange()
            }
        }
    }

    /// Verileri kaydeder ve Apple TV sistemine Top Shelf güncelleme bildirimi gönderir
    public func updateTopShelfData(
        continueWatching: [TopShelfItemDTO],
        favoriteChannels: [TopShelfItemDTO],
        recentMovies: [TopShelfItemDTO],
        style: TopShelfStyle? = nil
    ) {
        guard let sharedDefaults else { return }
        let currentStyle = style ?? preferredStyle
        if let currentPayload = loadTopShelfData(),
           currentPayload.continueWatching == continueWatching,
           currentPayload.favoriteChannels == favoriteChannels,
           currentPayload.recentMovies == recentMovies,
           currentPayload.preferredStyle == currentStyle
        {
            return
        }

        let payload = TopShelfDataDTO(
            continueWatching: continueWatching,
            favoriteChannels: favoriteChannels,
            recentMovies: recentMovies,
            preferredStyle: currentStyle,
            updatedAt: .now
        )

        guard let encoded = try? JSONEncoder().encode(payload) else { return }
        sharedDefaults.set(encoded, forKey: topShelfKey)
        notifyContentDidChange()
    }

    /// Kaydedilen verileri okur
    public func loadTopShelfData() -> TopShelfDataDTO? {
        guard let sharedDefaults else { return nil }
        guard let data = sharedDefaults.data(forKey: topShelfKey) else { return nil }
        return try? JSONDecoder().decode(TopShelfDataDTO.self, from: data)
    }

    private func notifyContentDidChange() {
        #if os(tvOS)
            TVTopShelfContentProvider.topShelfContentDidChange()
        #endif
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

#if !TOPSHELF_EXTENSION

    // MARK: - TopShelfClient (TCA)

    @DependencyClient
    public struct TopShelfClient: Sendable {
        public var updateTopShelfData: @Sendable (
            _ continueWatching: [TopShelfItemDTO],
            _ favoriteChannels: [TopShelfItemDTO],
            _ recentMovies: [TopShelfItemDTO]
        ) -> Void
        public var loadTopShelfData: @Sendable () -> TopShelfDataDTO? = { nil }
        public var getPreferredStyle: @Sendable () -> TopShelfStyle = { .sectioned }
        public var setPreferredStyle: @Sendable (_ style: TopShelfStyle) -> Void
    }

    extension TopShelfClient: DependencyKey {
        public static let liveValue: TopShelfClient = {
            let service = TopShelfService.shared
            return TopShelfClient(
                updateTopShelfData: { continueWatching, favoriteChannels, recentMovies in
                    service.updateTopShelfData(
                        continueWatching: continueWatching,
                        favoriteChannels: favoriteChannels,
                        recentMovies: recentMovies
                    )
                },
                loadTopShelfData: {
                    service.loadTopShelfData()
                },
                getPreferredStyle: {
                    service.preferredStyle
                },
                setPreferredStyle: { style in
                    service.preferredStyle = style
                }
            )
        }()

        public static let testValue = TopShelfClient()
    }

    public extension DependencyValues {
        var topShelfClient: TopShelfClient {
            get { self[TopShelfClient.self] }
            set { self[TopShelfClient.self] = newValue }
        }
    }
#endif
