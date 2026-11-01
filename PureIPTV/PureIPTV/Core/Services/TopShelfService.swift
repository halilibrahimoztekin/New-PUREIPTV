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

public enum TopShelfContentSection: String, Codable, CaseIterable, Hashable, Sendable {
    case continueWatching
    case favoriteChannels
    case recentMovies

    public static let defaultOrder: [Self] = [
        .continueWatching,
        .favoriteChannels,
        .recentMovies,
    ]
}

public struct TopShelfContentSelection: Codable, Equatable, Sendable {
    public var continueWatching = true
    public var favoriteChannels = true
    public var recentMovies = true

    public init(continueWatching: Bool = true, favoriteChannels: Bool = true, recentMovies: Bool = true) {
        self.continueWatching = continueWatching
        self.favoriteChannels = favoriteChannels
        self.recentMovies = recentMovies
    }

    public mutating func setEnabled(_ isEnabled: Bool, for section: TopShelfContentSection) {
        switch section {
        case .continueWatching: continueWatching = isEnabled
        case .favoriteChannels: favoriteChannels = isEnabled
        case .recentMovies: recentMovies = isEnabled
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
    private static let syncDeviceIDLock = NSRecursiveLock()
    private static let syncDeviceIDDefaultsKey = "com.pureiptv.iCloudSyncDeviceUUID"

    public static var syncDeviceID: String {
        syncDeviceIDLock.lock()
        defer { syncDeviceIDLock.unlock() }
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: syncDeviceIDDefaultsKey) {
            return existing
        }
        let newID = UUID().uuidString
        defaults.set(newID, forKey: syncDeviceIDDefaultsKey)
        return newID
    }

    private let appGroupID = "group.com.pureiptv.app"
    private let topShelfKey = "PureIPTV.TopShelfData"
    private let topShelfStyleKey = "PureIPTV.TopShelfStyle"
    private let topShelfSectionOrderKey = "PureIPTV.TopShelfSectionOrder"
    private let topShelfContentSelectionKey = "PureIPTV.TopShelfContentSelection"
    private let topShelfContentSelectionModifiedAtKey = "PureIPTV.TopShelfContentSelectionModifiedAt"
    private let topShelfContentSelectionDeviceIDKey = "PureIPTV.TopShelfContentSelectionDeviceID"
    private let contentSelectionLock = NSRecursiveLock()

    private init() {}

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    func withContentSelectionSyncLock<Value>(_ operation: () throws -> Value) rethrows -> Value {
        contentSelectionLock.lock()
        defer { contentSelectionLock.unlock() }
        return try operation()
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
            if let payload = loadRawTopShelfData(), payload.preferredStyle != newValue {
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

    public var contentSelection: TopShelfContentSelection {
        get {
            contentSelectionLock.lock()
            defer { contentSelectionLock.unlock() }
            guard let data = sharedDefaults?.data(forKey: topShelfContentSelectionKey),
                  let selection = try? JSONDecoder().decode(TopShelfContentSelection.self, from: data)
            else { return TopShelfContentSelection() }
            return selection
        }
        set {
            contentSelectionLock.lock()
            let didChange: Bool
            if let sharedDefaults,
               contentSelection != newValue,
               let data = try? JSONEncoder().encode(newValue)
            {
                sharedDefaults.set(data, forKey: topShelfContentSelectionKey)
                sharedDefaults.set(Date(), forKey: topShelfContentSelectionModifiedAtKey)
                sharedDefaults.set(Self.syncDeviceID, forKey: topShelfContentSelectionDeviceIDKey)
                didChange = true
            } else {
                didChange = false
            }
            contentSelectionLock.unlock()
            if didChange {
                notifyContentDidChange()
            }
        }
    }

    /// Order of the Sectioned Top Shelf rows, shared with the tvOS extension.
    /// Carousel presentation keeps its existing item order because it has no sections.
    public var sectionOrder: [TopShelfContentSection] {
        get {
            contentSelectionLock.lock()
            defer { contentSelectionLock.unlock() }
            let storedOrder = sharedDefaults?.stringArray(forKey: topShelfSectionOrderKey)?
                .compactMap(TopShelfContentSection.init(rawValue:)) ?? []
            return Self.normalizedSectionOrder(storedOrder)
        }
        set {
            contentSelectionLock.lock()
            let normalizedOrder = Self.normalizedSectionOrder(newValue)
            let didChange = sectionOrder != normalizedOrder
            if didChange {
                sharedDefaults?.set(normalizedOrder.map(\.rawValue), forKey: topShelfSectionOrderKey)
            }
            contentSelectionLock.unlock()
            if didChange {
                notifyContentDidChange()
            }
        }
    }

    public var contentSelectionSyncModifiedAt: Date? {
        contentSelectionLock.lock()
        defer { contentSelectionLock.unlock() }
        return sharedDefaults?.object(forKey: topShelfContentSelectionModifiedAtKey) as? Date
    }

    public var contentSelectionSyncDeviceID: String? {
        contentSelectionLock.lock()
        defer { contentSelectionLock.unlock() }
        return sharedDefaults?.string(forKey: topShelfContentSelectionDeviceIDKey)
    }

    public func applySyncedContentSelection(
        _ selection: TopShelfContentSelection,
        modifiedAt: Date,
        deviceID: String
    ) {
        contentSelectionLock.lock()
        guard let sharedDefaults else {
            contentSelectionLock.unlock()
            return
        }
        let existing = sharedDefaults.data(forKey: topShelfContentSelectionKey)
            .flatMap { try? JSONDecoder().decode(TopShelfContentSelection.self, from: $0) }
        let didChange = existing != selection
        if didChange, let data = try? JSONEncoder().encode(selection) {
            sharedDefaults.set(data, forKey: topShelfContentSelectionKey)
        }
        sharedDefaults.set(modifiedAt, forKey: topShelfContentSelectionModifiedAtKey)
        sharedDefaults.set(deviceID, forKey: topShelfContentSelectionDeviceIDKey)
        contentSelectionLock.unlock()
        if didChange {
            notifyContentDidChange()
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
        if let currentPayload = loadRawTopShelfData(),
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
        guard let payload = loadRawTopShelfData() else { return nil }
        let selection = contentSelection
        return TopShelfDataDTO(
            continueWatching: selection.continueWatching ? payload.continueWatching : [],
            favoriteChannels: selection.favoriteChannels ? payload.favoriteChannels : [],
            recentMovies: selection.recentMovies ? payload.recentMovies : [],
            preferredStyle: payload.preferredStyle,
            updatedAt: payload.updatedAt
        )
    }

    private func loadRawTopShelfData() -> TopShelfDataDTO? {
        guard let sharedDefaults else { return nil }
        guard let data = sharedDefaults.data(forKey: topShelfKey) else { return nil }
        guard let payload = try? JSONDecoder().decode(TopShelfDataDTO.self, from: data) else { return nil }
        let items = payload.continueWatching + payload.favoriteChannels + payload.recentMovies
        let containsLegacyStreamURL = items.contains { item in
            URLComponents(string: item.deepLinkURL)?.queryItems?.contains(where: { $0.name == "streamURL" }) == true
        }
        guard !containsLegacyStreamURL else {
            sharedDefaults.removeObject(forKey: topShelfKey)
            notifyContentDidChange()
            return nil
        }
        return payload
    }

    private static func normalizedSectionOrder(_ sections: [TopShelfContentSection]) -> [TopShelfContentSection] {
        var normalized: [TopShelfContentSection] = []
        for section in sections where !normalized.contains(section) {
            normalized.append(section)
        }
        for section in TopShelfContentSection.defaultOrder where !normalized.contains(section) {
            normalized.append(section)
        }
        return normalized
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
        playlistID: UUID?,
        profileID: UUID?,
        seriesID: String? = nil,
        startPosition: Double? = nil
    ) -> String {
        var components = URLComponents()
        components.scheme = "pureiptv"
        components.host = "topshelf"
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "type", value: type),
        ]
        if let playlistID {
            queryItems.append(URLQueryItem(name: "playlistID", value: playlistID.uuidString))
        }
        if let profileID {
            queryItems.append(URLQueryItem(name: "profileID", value: profileID.uuidString))
        }
        if let seriesID {
            queryItems.append(URLQueryItem(name: "seriesID", value: seriesID))
        }
        if let startPosition, startPosition.isFinite {
            queryItems.append(URLQueryItem(name: "startPosition", value: String(startPosition)))
        }
        components.queryItems = queryItems
        return components.url?.absoluteString ?? "pureiptv://topshelf?id=\(id)"
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
        public var getSectionOrder: @Sendable () -> [TopShelfContentSection] = { TopShelfContentSection.defaultOrder }
        public var setSectionOrder: @Sendable (_ order: [TopShelfContentSection]) -> Void = { _ in }
        public var getContentSelection: @Sendable () -> TopShelfContentSelection = { TopShelfContentSelection() }
        public var setContentSelection: @Sendable (_ selection: TopShelfContentSelection) -> Void = { _ in }
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
                },
                getSectionOrder: {
                    service.sectionOrder
                },
                setSectionOrder: { order in
                    service.sectionOrder = order
                },
                getContentSelection: {
                    service.contentSelection
                },
                setContentSelection: { selection in
                    service.contentSelection = selection
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
