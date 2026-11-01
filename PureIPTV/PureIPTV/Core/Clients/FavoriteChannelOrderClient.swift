import ComposableArchitecture
import Foundation

public struct FavoriteChannelOrderSnapshot: Equatable, Sendable {
    public var mode: FavoriteChannelSortMode
    public var orderedIDs: [String]
    public var revision: UInt64

    public nonisolated init(mode: FavoriteChannelSortMode = .defaultOrder, orderedIDs: [String] = [], revision: UInt64 = 0) {
        self.mode = mode
        self.orderedIDs = orderedIDs
        self.revision = revision
    }
}

public struct FavoriteChannelOrderClient: Sendable {
    public var load: @Sendable (_ profileID: UUID?, _ playlistID: UUID?, _ listID: UUID?) async -> FavoriteChannelOrderSnapshot
    public var save: @Sendable (_ snapshot: FavoriteChannelOrderSnapshot, _ profileID: UUID?, _ playlistID: UUID?, _ listID: UUID?) async -> Void
    public var loadMediaFavorites: @Sendable (_ profileID: UUID?, _ playlistID: UUID?, _ mediaType: String) async -> FavoriteChannelOrderSnapshot
    public var saveMediaFavorites: @Sendable (_ snapshot: FavoriteChannelOrderSnapshot, _ profileID: UUID?, _ playlistID: UUID?, _ mediaType: String) async -> Void

    public init(
        load: @escaping @Sendable (UUID?, UUID?, UUID?) async -> FavoriteChannelOrderSnapshot,
        save: @escaping @Sendable (FavoriteChannelOrderSnapshot, UUID?, UUID?, UUID?) async -> Void,
        loadMediaFavorites: @escaping @Sendable (UUID?, UUID?, String) async -> FavoriteChannelOrderSnapshot = { _, _, _ in
            FavoriteChannelOrderSnapshot()
        },
        saveMediaFavorites: @escaping @Sendable (FavoriteChannelOrderSnapshot, UUID?, UUID?, String) async -> Void = { _, _, _, _ in }
    ) {
        self.load = load
        self.save = save
        self.loadMediaFavorites = loadMediaFavorites
        self.saveMediaFavorites = saveMediaFavorites
    }
}

public nonisolated enum FavoriteSeriesSortMode: String, Codable, Equatable, Sendable {
    case existingOrder
    case newestEpisode
}

public nonisolated struct FavoriteSeriesEpisodeDateCacheEntry: Codable, Equatable, Sendable {
    public let latestEpisodeDate: Date?
    public let resolvedAt: Date

    public nonisolated init(latestEpisodeDate: Date?, resolvedAt: Date) {
        self.latestEpisodeDate = latestEpisodeDate
        self.resolvedAt = resolvedAt
    }
}

public struct FavoriteSeriesSortClient: Sendable {
    public var loadMode: @Sendable (_ profileID: UUID?) async -> FavoriteSeriesSortMode
    public var saveMode: @Sendable (_ mode: FavoriteSeriesSortMode, _ profileID: UUID?) async -> Void
    public var loadEpisodeDates: @Sendable (_ profileID: UUID?, _ playlistID: UUID?) async -> [String: FavoriteSeriesEpisodeDateCacheEntry]
    public var saveEpisodeDates: @Sendable (
        _ entries: [String: FavoriteSeriesEpisodeDateCacheEntry],
        _ profileID: UUID?,
        _ playlistID: UUID?
    ) async -> Void

    public init(
        loadMode: @escaping @Sendable (UUID?) async -> FavoriteSeriesSortMode,
        saveMode: @escaping @Sendable (FavoriteSeriesSortMode, UUID?) async -> Void,
        loadEpisodeDates: @escaping @Sendable (UUID?, UUID?) async -> [String: FavoriteSeriesEpisodeDateCacheEntry],
        saveEpisodeDates: @escaping @Sendable ([String: FavoriteSeriesEpisodeDateCacheEntry], UUID?, UUID?) async -> Void
    ) {
        self.loadMode = loadMode
        self.saveMode = saveMode
        self.loadEpisodeDates = loadEpisodeDates
        self.saveEpisodeDates = saveEpisodeDates
    }
}

private actor FavoriteChannelOrderStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private func key(_ profileID: UUID, _ playlistID: UUID, _ listID: UUID?, _ field: String) -> String {
        let listScope = listID.map { ".list.\($0.uuidString)" } ?? ""
        return "com.pureiptv.favoriteChannelOrder.\(profileID.uuidString).\(playlistID.uuidString)\(listScope).\(field)"
    }

    private func mediaFavoritesKey(_ profileID: UUID, _ playlistID: UUID, _ mediaType: String, _ field: String) -> String {
        "com.pureiptv.favoriteMediaOrder.\(profileID.uuidString).\(playlistID.uuidString).\(mediaType.lowercased()).\(field)"
    }

    func load(_ profileID: UUID, _ playlistID: UUID, _ listID: UUID?) -> FavoriteChannelOrderSnapshot {
        let mode = defaults.string(forKey: key(profileID, playlistID, listID, "mode"))
            .flatMap(FavoriteChannelSortMode.init(rawValue:)) ?? .defaultOrder
        let orderedIDs = defaults.stringArray(forKey: key(profileID, playlistID, listID, "ids")) ?? []
        let revision = UInt64(max(0, defaults.integer(forKey: key(profileID, playlistID, listID, "revision"))))
        return FavoriteChannelOrderSnapshot(mode: mode, orderedIDs: orderedIDs, revision: revision)
    }

    func save(_ snapshot: FavoriteChannelOrderSnapshot, _ profileID: UUID, _ playlistID: UUID, _ listID: UUID?) {
        let revisionKey = key(profileID, playlistID, listID, "revision")
        let currentRevision = UInt64(max(0, defaults.integer(forKey: revisionKey)))
        guard snapshot.revision > currentRevision else { return }
        defaults.set(snapshot.mode.rawValue, forKey: key(profileID, playlistID, listID, "mode"))
        defaults.set(snapshot.orderedIDs, forKey: key(profileID, playlistID, listID, "ids"))
        defaults.set(Int(snapshot.revision), forKey: revisionKey)
    }

    func loadMediaFavorites(_ profileID: UUID, _ playlistID: UUID, _ mediaType: String) -> FavoriteChannelOrderSnapshot {
        guard mediaType == "vod" || mediaType == "series" else { return FavoriteChannelOrderSnapshot() }
        let mode = defaults.string(forKey: mediaFavoritesKey(profileID, playlistID, mediaType, "mode"))
            .flatMap(FavoriteChannelSortMode.init(rawValue:)) ?? .defaultOrder
        let orderedIDs = defaults.stringArray(forKey: mediaFavoritesKey(profileID, playlistID, mediaType, "ids")) ?? []
        let revision = UInt64(max(0, defaults.integer(forKey: mediaFavoritesKey(profileID, playlistID, mediaType, "revision"))))
        return FavoriteChannelOrderSnapshot(mode: mode, orderedIDs: orderedIDs, revision: revision)
    }

    func saveMediaFavorites(
        _ snapshot: FavoriteChannelOrderSnapshot,
        _ profileID: UUID,
        _ playlistID: UUID,
        _ mediaType: String
    ) {
        guard mediaType == "vod" || mediaType == "series" else { return }
        let revisionKey = mediaFavoritesKey(profileID, playlistID, mediaType, "revision")
        let currentRevision = UInt64(max(0, defaults.integer(forKey: revisionKey)))
        guard snapshot.revision > currentRevision else { return }
        defaults.set(snapshot.mode.rawValue, forKey: mediaFavoritesKey(profileID, playlistID, mediaType, "mode"))
        defaults.set(snapshot.orderedIDs, forKey: mediaFavoritesKey(profileID, playlistID, mediaType, "ids"))
        defaults.set(Int(snapshot.revision), forKey: revisionKey)
    }
}

private actor FavoriteSeriesSortStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private func key(_ profileID: UUID, _ field: String) -> String {
        "com.pureiptv.favoriteSeriesSort.\(profileID.uuidString).\(field)"
    }

    private func episodeDatesKey(_ profileID: UUID, _ playlistID: UUID) -> String {
        "com.pureiptv.favoriteSeriesEpisodeDates.\(profileID.uuidString).\(playlistID.uuidString)"
    }

    func loadMode(_ profileID: UUID) -> FavoriteSeriesSortMode {
        defaults.string(forKey: key(profileID, "mode"))
            .flatMap(FavoriteSeriesSortMode.init(rawValue:)) ?? .existingOrder
    }

    func saveMode(_ mode: FavoriteSeriesSortMode, _ profileID: UUID) {
        defaults.set(mode.rawValue, forKey: key(profileID, "mode"))
    }

    func loadEpisodeDates(_ profileID: UUID, _ playlistID: UUID) -> [String: FavoriteSeriesEpisodeDateCacheEntry] {
        guard let data = defaults.data(forKey: episodeDatesKey(profileID, playlistID)),
              let entries = try? PropertyListDecoder().decode([String: FavoriteSeriesEpisodeDateCacheEntry].self, from: data)
        else { return [:] }
        return entries
    }

    func saveEpisodeDates(
        _ entries: [String: FavoriteSeriesEpisodeDateCacheEntry],
        _ profileID: UUID,
        _ playlistID: UUID
    ) {
        let key = episodeDatesKey(profileID, playlistID)
        guard !entries.isEmpty else {
            defaults.removeObject(forKey: key)
            return
        }
        guard let data = try? PropertyListEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}

extension FavoriteChannelOrderClient: DependencyKey {
    public static let liveValue: FavoriteChannelOrderClient = {
        let store = FavoriteChannelOrderStore(defaults: .standard)
        return FavoriteChannelOrderClient(
            load: { profileID, playlistID, listID in
                guard let profileID, let playlistID else { return FavoriteChannelOrderSnapshot() }
                return await store.load(profileID, playlistID, listID)
            },
            save: { snapshot, profileID, playlistID, listID in
                guard let profileID, let playlistID else { return }
                await store.save(snapshot, profileID, playlistID, listID)
            },
            loadMediaFavorites: { profileID, playlistID, mediaType in
                guard let profileID, let playlistID else { return FavoriteChannelOrderSnapshot() }
                return await store.loadMediaFavorites(profileID, playlistID, mediaType)
            },
            saveMediaFavorites: { snapshot, profileID, playlistID, mediaType in
                guard let profileID, let playlistID else { return }
                await store.saveMediaFavorites(snapshot, profileID, playlistID, mediaType)
            }
        )
    }()

    public static let testValue = FavoriteChannelOrderClient(
        load: { _, _, _ in FavoriteChannelOrderSnapshot() },
        save: { _, _, _, _ in }
    )
}

extension FavoriteSeriesSortClient: DependencyKey {
    public static let liveValue: FavoriteSeriesSortClient = {
        let store = FavoriteSeriesSortStore(defaults: .standard)
        return FavoriteSeriesSortClient(
            loadMode: { profileID in
                guard let profileID else { return .existingOrder }
                return await store.loadMode(profileID)
            },
            saveMode: { mode, profileID in
                guard let profileID else { return }
                await store.saveMode(mode, profileID)
            },
            loadEpisodeDates: { profileID, playlistID in
                guard let profileID, let playlistID else { return [:] }
                return await store.loadEpisodeDates(profileID, playlistID)
            },
            saveEpisodeDates: { entries, profileID, playlistID in
                guard let profileID, let playlistID else { return }
                await store.saveEpisodeDates(entries, profileID, playlistID)
            }
        )
    }()

    public static let testValue = FavoriteSeriesSortClient(
        loadMode: { _ in .existingOrder },
        saveMode: { _, _ in },
        loadEpisodeDates: { _, _ in [:] },
        saveEpisodeDates: { _, _, _ in }
    )
}

public extension DependencyValues {
    var favoriteChannelOrderClient: FavoriteChannelOrderClient {
        get { self[FavoriteChannelOrderClient.self] }
        set { self[FavoriteChannelOrderClient.self] = newValue }
    }

    var favoriteSeriesSortClient: FavoriteSeriesSortClient {
        get { self[FavoriteSeriesSortClient.self] }
        set { self[FavoriteSeriesSortClient.self] = newValue }
    }
}
