import ComposableArchitecture
import Foundation
import SwiftData

// MARK: - FavoriteSyncDTO

/// Lightweight, Codable transfer model for syncing favorite channels/movies across iCloud devices (Madde #24).
public struct FavoriteSyncDTO: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let type: String // "live", "vod", "series"
    public let title: String
    public let coverURL: String?
    public let streamURL: String?
    public let addedAt: Date
    public let playlistID: UUID?
    public let profileID: UUID?
    public let removedAt: Date?

    public init(
        id: String,
        type: String,
        title: String,
        coverURL: String? = nil,
        streamURL: String? = nil,
        addedAt: Date = Date(),
        playlistID: UUID? = nil,
        profileID: UUID? = nil,
        removedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.coverURL = coverURL
        self.streamURL = streamURL
        self.addedAt = addedAt
        self.playlistID = playlistID
        self.profileID = profileID
        self.removedAt = removedAt
    }

    public init(from favorite: FavoriteItem) {
        id = favorite.id
        type = favorite.type
        title = favorite.title
        coverURL = favorite.coverURL
        streamURL = favorite.streamURL
        addedAt = favorite.addedAt
        playlistID = favorite.playlistID
        profileID = favorite.profileID
        removedAt = favorite.removedAt
    }

    public func toFavoriteItem() -> FavoriteItem {
        FavoriteItem(
            id: id,
            type: type,
            title: title,
            coverURL: coverURL,
            streamURL: streamURL,
            addedAt: addedAt,
            playlistID: playlistID,
            profileID: profileID,
            removedAt: removedAt
        )
    }
}

private func favoriteSyncVersion(_ dto: FavoriteSyncDTO) -> Date {
    dto.removedAt ?? dto.addedAt
}

private func favoriteSyncWins(_ candidate: FavoriteSyncDTO, over current: FavoriteSyncDTO) -> Bool {
    let candidateVersion = favoriteSyncVersion(candidate)
    let currentVersion = favoriteSyncVersion(current)
    if candidateVersion != currentVersion {
        return candidateVersion > currentVersion
    }
    if (candidate.removedAt != nil) != (current.removedAt != nil) {
        return candidate.removedAt != nil
    }
    let candidateStable = "\(candidate.title)|\(candidate.coverURL ?? "")|\(candidate.streamURL ?? "")"
    let currentStable = "\(current.title)|\(current.coverURL ?? "")|\(current.streamURL ?? "")"
    return candidateStable > currentStable
}

// MARK: - CloudSync Models

public struct CloudSyncSummary: Codable, Equatable, Sendable {
    public var favoritesCount: Int
    public var hiddenChannelsCount: Int
    public var blacklistedCategoriesCount: Int
    public var watchProgressCount: Int
    public var lastSyncDate: Date
    public var deviceID: String

    public init(
        favoritesCount: Int = 0,
        hiddenChannelsCount: Int = 0,
        blacklistedCategoriesCount: Int = 0,
        watchProgressCount: Int = 0,
        lastSyncDate: Date = Date(),
        deviceID: String = ""
    ) {
        self.favoritesCount = favoritesCount
        self.hiddenChannelsCount = hiddenChannelsCount
        self.blacklistedCategoriesCount = blacklistedCategoriesCount
        self.watchProgressCount = watchProgressCount
        self.lastSyncDate = lastSyncDate
        self.deviceID = deviceID
    }
}

public enum CloudSyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case success(Date)
    case error(String)
}

// MARK: - CloudSyncClient

@DependencyClient
public struct CloudSyncClient: Sendable {
    public var isSyncEnabled: @Sendable () -> Bool = { true }
    public var setSyncEnabled: @Sendable (_ enabled: Bool) -> Void
    public var syncFavorites: @Sendable (_ favorites: [FavoriteSyncDTO]) async throws -> Void
    public var pullFavorites: @Sendable () async throws -> [FavoriteSyncDTO] = { [] }
    public var syncHiddenItems: @Sendable (_ items: [HiddenItemDTO]) async throws -> Void
    public var pullHiddenItems: @Sendable () async throws -> [HiddenItemDTO] = { [] }
    public var performFullSync: @Sendable () async throws -> CloudSyncSummary
    public var observeRemoteChanges: @Sendable () -> AsyncStream<CloudSyncSummary> = { AsyncStream { $0.finish() } }
    public var lastSyncDate: @Sendable () -> Date? = { nil }
    public var getSyncStatus: @Sendable () -> CloudSyncStatus = { .idle }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let cloudSyncDidComplete = Notification.Name("com.pureiptv.cloudSyncDidComplete")
    static let favoritesDidChange = Notification.Name("com.pureiptv.favoritesDidChange")
    static let hiddenContentDidChange = Notification.Name("com.pureiptv.hiddenContentDidChange")
}

// MARK: - DependencyKey & Live Value

extension CloudSyncClient: DependencyKey {
    private nonisolated static let favoritesKey = "com.pureiptv.icloud.favorites"
    private nonisolated static let hiddenChannelsKey = "com.pureiptv.icloud.hiddenChannels"
    private nonisolated static let blacklistedCategoriesKey = "com.pureiptv.icloud.blacklistedCategories"
    private nonisolated static let lastSyncKey = "com.pureiptv.icloud.lastSyncTimestamp"
    private nonisolated static let enabledKey = "com.pureiptv.isICloudSyncEnabled"
    private nonisolated static let deviceIDKey = "com.pureiptv.iCloudSyncDeviceUUID"
    private nonisolated static let maxFavoritesCount = 500
    private nonisolated static let maxHiddenCount = 300

    private static var deviceUUID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: deviceIDKey) {
            return existing
        }
        let newID = UUID().uuidString
        defaults.set(newID, forKey: deviceIDKey)
        return newID
    }

    public static let liveValue: CloudSyncClient = {
        let store = NSUbiquitousKeyValueStore.default
        let defaults = UserDefaults.standard

        let localHiddenChannelsKey = "com.pureiptv.hiddenChannelsMetadata"
        let localCategoriesKey = "com.pureiptv.blacklistedCategoriesMetadata"

        @Sendable func isEnabled() -> Bool {
            if defaults.object(forKey: enabledKey) == nil {
                defaults.set(true, forKey: enabledKey)
                return true
            }
            return defaults.bool(forKey: enabledKey)
        }

        @Sendable func pullRemoteFavorites() -> [FavoriteSyncDTO] {
            let keys = store.dictionaryRepresentation.keys.filter { $0 == favoritesKey || $0.hasPrefix(favoritesKey + ".profile.") }
            return keys.flatMap { key in
                guard let data = store.data(forKey: key) else { return [FavoriteSyncDTO]() }
                return (try? JSONDecoder().decode([FavoriteSyncDTO].self, from: data)) ?? [FavoriteSyncDTO]()
            }
        }

        @Sendable func pushLocalFavorites(_ favorites: [FavoriteSyncDTO]) {
            let grouped = Dictionary(grouping: favorites.prefix(maxFavoritesCount)) { $0.profileID?.uuidString ?? "legacy" }
            for (scope, records) in grouped {
                let key = scope == "legacy" ? favoritesKey : favoritesKey + ".profile." + scope
                if let data = try? JSONEncoder().encode(Array(records)) {
                    store.set(data, forKey: key)
                }
            }
            store.synchronize()
        }

        @Sendable func pullRemoteHiddenItems() -> [HiddenItemDTO] {
            var items: [HiddenItemDTO] = []
            if let chanData = store.data(forKey: hiddenChannelsKey),
               let chans = try? JSONDecoder().decode([HiddenItemDTO].self, from: chanData)
            {
                items.append(contentsOf: chans)
            }
            if let catData = store.data(forKey: blacklistedCategoriesKey),
               let cats = try? JSONDecoder().decode([HiddenItemDTO].self, from: catData)
            {
                items.append(contentsOf: cats)
            }
            return items
        }

        @Sendable func pushLocalHiddenItems(_ items: [HiddenItemDTO]) {
            let channels = items.filter { $0.type == .channel }
            let categories = items.filter { $0.type == .category }

            if let cData = try? JSONEncoder().encode(Array(channels.prefix(maxHiddenCount))) {
                store.set(cData, forKey: hiddenChannelsKey)
            }
            if let catData = try? JSONEncoder().encode(Array(categories.prefix(maxHiddenCount))) {
                store.set(catData, forKey: blacklistedCategoriesKey)
            }
            store.synchronize()
        }

        @Sendable func mergeRemoteFavoritesIntoDatabase(remote: [FavoriteSyncDTO], modelContainer: ModelContainer) async throws -> Int {
            guard !remote.isEmpty else { return 0 }
            let context = ModelContext(modelContainer)
            var merged = 0

            for dto in remote {
                let id = dto.id
                let type = dto.type
                let profileID = dto.profileID
                let descriptor = FetchDescriptor<FavoriteItem>(
                    predicate: #Predicate { $0.id == id && $0.type == type && $0.profileID == profileID }
                )
                if let local = try context.fetch(descriptor).first(where: { $0.playlistID == dto.playlistID }) {
                    // Preserve timestamped soft-deletes even when addedAt is unchanged.
                    if favoriteSyncWins(dto, over: FavoriteSyncDTO(from: local)) {
                        local.title = dto.title
                        local.coverURL = dto.coverURL
                        local.streamURL = dto.streamURL
                        local.addedAt = dto.addedAt
                        local.playlistID = dto.playlistID
                        local.profileID = dto.profileID
                        local.removedAt = dto.removedAt
                        merged += 1
                    }
                } else {
                    let newItem = dto.toFavoriteItem()
                    context.insert(newItem)
                    merged += 1
                }
            }

            if merged > 0 {
                try context.save()
                await MainActor.run {
                    NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
                }
            }
            return merged
        }

        @Sendable func mergeRemoteHiddenItemsIntoDefaults(remote: [HiddenItemDTO]) async -> Int {
            guard !remote.isEmpty else { return 0 }

            let decoder = JSONDecoder()
            let encoder = JSONEncoder()

            var localChannels: [HiddenItemDTO] = []
            if let data = defaults.data(forKey: localHiddenChannelsKey) {
                localChannels = (try? decoder.decode([HiddenItemDTO].self, from: data)) ?? []
            }

            var localCats: [HiddenItemDTO] = []
            if let data = defaults.data(forKey: localCategoriesKey) {
                localCats = (try? decoder.decode([HiddenItemDTO].self, from: data)) ?? []
            }

            var mergedCount = 0

            // Merge channels
            var channelMap = Dictionary(uniqueKeysWithValues: localChannels.map { ($0.id, $0) })
            for r in remote where r.type == .channel {
                if let existing = channelMap[r.id] {
                    if r.hiddenAt > existing.hiddenAt {
                        channelMap[r.id] = r
                        mergedCount += 1
                    }
                } else {
                    channelMap[r.id] = r
                    mergedCount += 1
                }
            }

            // Merge categories
            var catMap = Dictionary(uniqueKeysWithValues: localCats.map { ($0.id, $0) })
            for r in remote where r.type == .category {
                if let existing = catMap[r.id] {
                    if r.hiddenAt > existing.hiddenAt {
                        catMap[r.id] = r
                        mergedCount += 1
                    }
                } else {
                    catMap[r.id] = r
                    mergedCount += 1
                }
            }

            if mergedCount > 0 {
                let newChannels = Array(channelMap.values)
                let newCats = Array(catMap.values)

                if let cData = try? encoder.encode(newChannels) {
                    defaults.set(cData, forKey: localHiddenChannelsKey)
                }
                if let catData = try? encoder.encode(newCats) {
                    defaults.set(catData, forKey: localCategoriesKey)
                }

                await MainActor.run {
                    NotificationCenter.default.post(name: .hiddenContentDidChange, object: nil)
                }
            }

            return mergedCount
        }

        @Sendable func fullSync() async throws -> CloudSyncSummary {
            guard isEnabled() else {
                return CloudSyncSummary(
                    favoritesCount: 0,
                    hiddenChannelsCount: 0,
                    blacklistedCategoriesCount: 0,
                    watchProgressCount: 0,
                    lastSyncDate: Date(),
                    deviceID: deviceUUID
                )
            }

            // Open persistence before touching either cloud or local sync state.
            let modelContainer = try SharedDatabaseConfig.shared

            store.synchronize()

            // 1. Pull & Merge Remote Favorites
            let remoteFavorites = pullRemoteFavorites()
            _ = try await mergeRemoteFavoritesIntoDatabase(remote: remoteFavorites, modelContainer: modelContainer)

            // 2. Read all local favorites and push union to cloud
            let context = ModelContext(modelContainer)
            let localFavorites = try context.fetch(FetchDescriptor<FavoriteItem>())
            func identity(_ dto: FavoriteSyncDTO) -> String {
                "\(dto.profileID?.uuidString ?? "legacy")|\(dto.type)|\(dto.playlistID?.uuidString ?? "")|\(dto.id)"
            }
            var favoriteMap: [String: FavoriteSyncDTO] = [:]
            for remote in remoteFavorites {
                let key = identity(remote)
                if let current = favoriteMap[key] {
                    if favoriteSyncWins(remote, over: current) {
                        favoriteMap[key] = remote
                    }
                } else {
                    favoriteMap[key] = remote
                }
            }
            for local in localFavorites {
                let dto = FavoriteSyncDTO(from: local)
                let key = identity(dto)
                if let existing = favoriteMap[key] {
                    if favoriteSyncWins(dto, over: existing) {
                        favoriteMap[key] = dto
                    }
                } else {
                    favoriteMap[key] = dto
                }
            }
            let mergedFavorites = Array(favoriteMap.values)
            pushLocalFavorites(mergedFavorites)

            // 3. Pull & Merge Remote Hidden Items
            let remoteHidden = pullRemoteHiddenItems()
            _ = await mergeRemoteHiddenItemsIntoDefaults(remote: remoteHidden)

            // 4. Read local hidden items and push union to cloud
            var allLocalHidden: [HiddenItemDTO] = []
            if let cData = defaults.data(forKey: localHiddenChannelsKey),
               let chans = try? JSONDecoder().decode([HiddenItemDTO].self, from: cData)
            {
                allLocalHidden.append(contentsOf: chans)
            }
            if let catData = defaults.data(forKey: localCategoriesKey),
               let cats = try? JSONDecoder().decode([HiddenItemDTO].self, from: catData)
            {
                allLocalHidden.append(contentsOf: cats)
            }

            var hiddenMap = Dictionary(uniqueKeysWithValues: remoteHidden.map { ($0.id, $0) })
            for l in allLocalHidden {
                if let existing = hiddenMap[l.id] {
                    if l.hiddenAt >= existing.hiddenAt {
                        hiddenMap[l.id] = l
                    }
                } else {
                    hiddenMap[l.id] = l
                }
            }
            let mergedHidden = Array(hiddenMap.values)
            pushLocalHiddenItems(mergedHidden)

            // 5. Watch Progress Sync
            let watchMerged = try await WatchProgressSyncClient.liveValue.pullAndMergeRemoteChanges()

            let now = Date()
            defaults.set(now.timeIntervalSince1970, forKey: lastSyncKey)
            store.set(now.timeIntervalSince1970, forKey: lastSyncKey)
            store.synchronize()

            let summary = CloudSyncSummary(
                favoritesCount: mergedFavorites.count,
                hiddenChannelsCount: mergedHidden.filter { $0.type == .channel }.count,
                blacklistedCategoriesCount: mergedHidden.filter { $0.type == .category }.count,
                watchProgressCount: watchMerged,
                lastSyncDate: now,
                deviceID: deviceUUID
            )

            await MainActor.run {
                NotificationCenter.default.post(name: .cloudSyncDidComplete, object: nil, userInfo: ["summary": summary])
            }

            return summary
        }

        return CloudSyncClient(
            isSyncEnabled: {
                isEnabled()
            },
            setSyncEnabled: { enabled in
                defaults.set(enabled, forKey: enabledKey)
            },
            syncFavorites: { favorites in
                guard isEnabled() else { return }
                pushLocalFavorites(favorites)
            },
            pullFavorites: {
                guard isEnabled() else { return [] }
                return pullRemoteFavorites()
            },
            syncHiddenItems: { items in
                guard isEnabled() else { return }
                pushLocalHiddenItems(items)
            },
            pullHiddenItems: {
                guard isEnabled() else { return [] }
                return pullRemoteHiddenItems()
            },
            performFullSync: {
                try await fullSync()
            },
            observeRemoteChanges: {
                AsyncStream { continuation in
                    let observer = NotificationCenter.default.addObserver(
                        forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                        object: store,
                        queue: .main
                    ) { _ in
                        guard isEnabled() else { return }
                        Task {
                            if let summary = try? await fullSync() {
                                continuation.yield(summary)
                            }
                        }
                    }

                    continuation.onTermination = { @Sendable _ in
                        NotificationCenter.default.removeObserver(observer)
                    }
                }
            },
            lastSyncDate: {
                let timestamp = defaults.double(forKey: lastSyncKey)
                guard timestamp > 0 else { return nil }
                return Date(timeIntervalSince1970: timestamp)
            },
            getSyncStatus: {
                let timestamp = defaults.double(forKey: lastSyncKey)
                if timestamp > 0 {
                    return .success(Date(timeIntervalSince1970: timestamp))
                }
                return .idle
            }
        )
    }()

    public static let testValue: CloudSyncClient = .init()
}

// MARK: - DependencyValues Registration

public extension DependencyValues {
    var cloudSyncClient: CloudSyncClient {
        get { self[CloudSyncClient.self] }
        set { self[CloudSyncClient.self] = newValue }
    }
}
