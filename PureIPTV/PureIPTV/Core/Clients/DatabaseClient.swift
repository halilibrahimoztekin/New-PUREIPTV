import ComposableArchitecture
import Foundation
import SwiftData

@DependencyClient
public struct DatabaseClient {
    public var fetchFavorites: @Sendable (_ scope: ProfileContextSnapshot) async throws -> [FavoriteItem]
    public var fetchFavoritesByType: @Sendable (_ type: String, _ scope: ProfileContextSnapshot) async throws -> [FavoriteItem]
    public var isFavorite: @Sendable (_ id: String, _ type: String, _ playlistID: UUID?, _ scope: ProfileContextSnapshot) async throws -> Bool
    public var toggleFavorite: @Sendable (_ item: FavoriteItem, _ scope: ProfileContextSnapshot) async throws -> Bool // Returns true if added, false if removed
    public var setFavorites: @Sendable (_ items: [FavoriteItem], _ isFavorite: Bool, _ scope: ProfileContextSnapshot) async throws -> Bool

    public var fetchWatchHistory: @Sendable (_ scope: ProfileContextSnapshot) async throws -> [WatchHistoryItem]
    public var fetchEpisodeWatchHistory: @Sendable (_ scope: ProfileContextSnapshot) async throws -> [WatchHistoryItem]
    public var saveWatchProgress: @Sendable (_ item: WatchHistoryItem, _ scope: ProfileContextSnapshot) async throws -> Void
    public var deleteWatchProgress: @Sendable (_ id: String, _ type: String, _ playlistID: UUID?, _ scope: ProfileContextSnapshot) async throws -> Void
    public var clearWatchHistory: @Sendable (_ scope: ProfileContextSnapshot) async throws -> Void
    public var getWatchProgress: @Sendable (_ id: String, _ type: String, _ playlistID: UUID?, _ scope: ProfileContextSnapshot) async throws -> WatchHistoryItem?
    public var getSeriesWatchProgress: @Sendable (_ seriesID: String, _ playlistID: UUID?, _ scope: ProfileContextSnapshot) async throws -> WatchHistoryItem?
    public var fetchSeriesEpisodesWatchHistory: @Sendable (_ seriesID: String, _ playlistID: UUID?, _ scope: ProfileContextSnapshot) async throws -> [WatchHistoryItem]

    public var fetchCategoryPreferences: @Sendable (_ type: String) async throws -> [CategoryPreferenceDTO]
    public var saveCategoryPreferences: @Sendable (_ preferences: [CategoryPreferenceDTO]) async throws -> Void

    public var fetchSearchHistory: @Sendable () async throws -> [SearchHistoryItem]
    public var saveSearchHistory: @Sendable (_ query: String) async throws -> Void
    public var clearSearchHistory: @Sendable () async throws -> Void
}

public struct CategoryPreferenceDTO: Equatable, Sendable {
    public var id: String
    public var type: String
    public var categoryID: String
    public var isHidden: Bool
    public var isLocked: Bool
    public var orderIndex: Int

    public init(id: String, type: String, categoryID: String, isHidden: Bool, isLocked: Bool = false, orderIndex: Int) {
        self.id = id
        self.type = type
        self.categoryID = categoryID
        self.isHidden = isHidden
        self.isLocked = isLocked
        self.orderIndex = orderIndex
    }
}

private func legacyDataOwnerID(in context: ModelContext) -> UUID? {
    guard let profiles = try? context.fetch(FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])) else {
        return nil
    }
    return profiles.first(where: { !$0.isKidsMode })?.id ?? profiles.first?.id
}

private func favoriteScopeKey(_ item: FavoriteItem) -> String {
    "\(item.type)|\(item.playlistID?.uuidString ?? "")|\(item.id)"
}

private func historyScopeKey(_ item: WatchHistoryItem) -> String {
    "\(item.type)|\(item.playlistID?.uuidString ?? "")|\(item.id)"
}

private func favorites(in context: ModelContext, profileID: UUID?, type: String? = nil) throws -> [FavoriteItem] {
    let owned: [FavoriteItem]
    if let type {
        let requestedType = type
        let descriptor = FetchDescriptor<FavoriteItem>(predicate: #Predicate {
            $0.profileID == profileID && $0.type == requestedType
        }, sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
        owned = try context.fetch(descriptor)
    } else {
        let descriptor = FetchDescriptor<FavoriteItem>(
            predicate: #Predicate { $0.profileID == profileID },
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        owned = try context.fetch(descriptor)
    }
    let legacyRows: [FavoriteItem]
    if let profileID, profileID == legacyDataOwnerID(in: context) {
        if let type {
            let requestedType = type
            let descriptor = FetchDescriptor<FavoriteItem>(predicate: #Predicate {
                $0.profileID == nil && $0.type == requestedType
            }, sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
            legacyRows = try context.fetch(descriptor)
        } else {
            let descriptor = FetchDescriptor<FavoriteItem>(
                predicate: #Predicate { $0.profileID == nil },
                sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
            )
            legacyRows = try context.fetch(descriptor)
        }
    } else {
        legacyRows = []
    }
    let shadowed = Set(owned.map(favoriteScopeKey))
    let visibleLegacy = legacyRows.filter { !shadowed.contains(favoriteScopeKey($0)) }
    return (owned + visibleLegacy).filter { $0.removedAt == nil }
        .sorted { $0.addedAt > $1.addedAt }
}

private func setFavoriteItems(
    _ items: [FavoriteItem],
    isFavorite: Bool,
    scope: ProfileContextSnapshot,
    modelContainer: ModelContainer,
    profileContextClient: ProfileContextClient
) throws -> Bool {
    let profileID = scope.profileID
    let eligibleItems = items.filter { $0.type == "live" }
    guard !eligibleItems.isEmpty else { return true }

    let context = ModelContext(modelContainer)
    let descriptor = FetchDescriptor<FavoriteItem>(predicate: #Predicate { $0.profileID == profileID })
    let ownedRows = try context.fetch(descriptor)
    let ownsLegacyRows = profileID == legacyDataOwnerID(in: context)
    let legacyRows: [FavoriteItem] = if ownsLegacyRows {
        try context.fetch(FetchDescriptor<FavoriteItem>(predicate: #Predicate { $0.profileID == nil }))
    } else {
        []
    }

    var ownedByKey: [String: FavoriteItem] = [:]
    ownedByKey.reserveCapacity(ownedRows.count)
    for row in ownedRows {
        let key = favoriteScopeKey(row)
        if ownedByKey[key] == nil {
            ownedByKey[key] = row
        }
    }
    var legacyByKey: [String: FavoriteItem] = [:]
    legacyByKey.reserveCapacity(legacyRows.count)
    for row in legacyRows {
        let key = favoriteScopeKey(row)
        if legacyByKey[key] == nil {
            legacyByKey[key] = row
        }
    }

    var changed = false
    let now = Date()
    var seen = Set<String>()
    for item in eligibleItems where seen.insert(favoriteScopeKey(item)).inserted {
        let key = favoriteScopeKey(item)
        let owned = ownedByKey[key]
        let legacy = owned == nil ? legacyByKey[key] : nil

        if let row = owned ?? legacy {
            if legacy != nil {
                row.profileID = profileID; changed = true
            }
            if isFavorite {
                if row.removedAt != nil {
                    row.removedAt = nil
                    row.title = item.title
                    row.coverURL = item.coverURL
                    row.streamURL = item.streamURL
                    row.addedAt = now
                    changed = true
                }
            } else if row.removedAt == nil {
                row.removedAt = now
                changed = true
            }
        } else if isFavorite {
            context.insert(FavoriteItem(
                id: item.id,
                type: item.type,
                title: item.title,
                coverURL: item.coverURL,
                streamURL: item.streamURL,
                addedAt: now,
                playlistID: item.playlistID,
                profileID: profileID
            ))
            changed = true
        }
    }

    guard changed else { return true }
    guard profileContextClient.snapshot() == scope else { return false }
    try context.save()
    return true
}

private func watchHistory(in context: ModelContext, profileID: UUID?) throws -> [WatchHistoryItem] {
    let ownedDescriptor = FetchDescriptor<WatchHistoryItem>(predicate: #Predicate { $0.profileID == profileID })
    let owned = try context.fetch(ownedDescriptor)
    let legacyRows: [WatchHistoryItem]
    if let profileID, profileID == legacyDataOwnerID(in: context) {
        let legacyDescriptor = FetchDescriptor<WatchHistoryItem>(predicate: #Predicate { $0.profileID == nil })
        legacyRows = try context.fetch(legacyDescriptor)
    } else {
        legacyRows = []
    }
    let shadowed = Set(owned.map(historyScopeKey))
    let visibleLegacy = legacyRows.filter { !shadowed.contains(historyScopeKey($0)) }
    return (owned + visibleLegacy).filter { $0.removedAt == nil }
        .sorted { $0.lastWatchedAt > $1.lastWatchedAt }
}

extension DatabaseClient: DependencyKey {
    public static let liveValue: DatabaseClient = {
        // SwiftData Context Setup - Use shared container
        let modelContainer = SharedDatabaseConfig.shared
        let profileContextClient = ProfileContextClient.liveValue

        return DatabaseClient(
            fetchFavorites: { scope in
                let profileID = scope.profileID
                let context = ModelContext(modelContainer)
                return try favorites(in: context, profileID: profileID)
            },
            fetchFavoritesByType: { type, scope in
                let profileID = scope.profileID
                let context = ModelContext(modelContainer)
                return try favorites(in: context, profileID: profileID, type: type)
            },
            isFavorite: { id, type, playlistID, scope in
                let profileID = scope.profileID
                let context = ModelContext(modelContainer)
                return try favorites(in: context, profileID: profileID, type: type).contains { $0.id == id && $0.playlistID == playlistID }
            },
            toggleFavorite: { item, scope in
                let profileID = scope.profileID
                let context = ModelContext(modelContainer)
                let id = item.id
                let type = item.type
                let descriptor = FetchDescriptor<FavoriteItem>(predicate: #Predicate {
                    $0.id == id && $0.type == type && $0.profileID == profileID
                })
                let existing = try context.fetch(descriptor)
                if let first = existing.first(where: { $0.playlistID == item.playlistID }) {
                    first.removedAt = first.removedAt == nil ? Date() : nil
                    if first.removedAt == nil {
                        first.title = item.title
                        first.coverURL = item.coverURL
                        first.streamURL = item.streamURL
                        first.addedAt = Date()
                    }
                    guard profileContextClient.snapshot() == scope else { return false }
                    try context.save()
                    return first.removedAt == nil
                }
                if let profileID, profileID == legacyDataOwnerID(in: context) {
                    let legacyDescriptor = FetchDescriptor<FavoriteItem>(predicate: #Predicate {
                        $0.id == id && $0.type == type && $0.profileID == nil
                    })
                    if let legacy = try context.fetch(legacyDescriptor).first(where: { $0.playlistID == item.playlistID }) {
                        legacy.profileID = profileID
                        legacy.removedAt = Date()
                        guard profileContextClient.snapshot() == scope else { return false }
                        try context.save()
                        return false
                    }
                }
                context.insert(FavoriteItem(
                    id: item.id, type: item.type, title: item.title,
                    coverURL: item.coverURL, streamURL: item.streamURL,
                    addedAt: item.addedAt, playlistID: item.playlistID,
                    profileID: profileID
                ))
                guard profileContextClient.snapshot() == scope else { return false }
                try context.save()
                return true
            },
            setFavorites: { items, isFavorite, scope in
                try setFavoriteItems(
                    items,
                    isFavorite: isFavorite,
                    scope: scope,
                    modelContainer: modelContainer,
                    profileContextClient: profileContextClient
                )
            },
            fetchWatchHistory: { scope in
                let profileID = scope.profileID
                let context = ModelContext(modelContainer)
                let allItems = try watchHistory(in: context, profileID: profileID)
                var seenSeriesIDs = Set<String>()
                var deduplicatedItems: [WatchHistoryItem] = []

                for item in allItems {
                    if let seriesID = item.seriesID, !seriesID.isEmpty {
                        let key = "\(seriesID)|\(item.playlistID?.uuidString ?? "")"
                        if !seenSeriesIDs.contains(key) {
                            seenSeriesIDs.insert(key)
                            deduplicatedItems.append(item)
                        }
                    } else {
                        deduplicatedItems.append(item)
                    }
                }

                return deduplicatedItems
            },
            fetchEpisodeWatchHistory: { scope in
                let context = ModelContext(modelContainer)
                return try watchHistory(in: context, profileID: scope.profileID).filter {
                    $0.type.caseInsensitiveCompare("episode") == .orderedSame
                }
            },
            saveWatchProgress: { item, scope in
                let profileID = scope.profileID
                let context = ModelContext(modelContainer)
                let id = item.id
                let type = item.type
                let descriptor = FetchDescriptor<WatchHistoryItem>(predicate: #Predicate {
                    $0.id == id && $0.type == type && $0.profileID == profileID
                })
                let existing = try context.fetch(descriptor)
                let first = try existing.first(where: { $0.playlistID == item.playlistID }) ?? (profileID != nil && profileID == legacyDataOwnerID(in: context)
                    ? context.fetch(FetchDescriptor<WatchHistoryItem>(predicate: #Predicate {
                        $0.id == id && $0.type == type && $0.profileID == nil
                    })).first(where: { $0.playlistID == item.playlistID })
                    : nil)
                if let first {
                    first.profileID = profileID
                    first.removedAt = nil
                    first.progress = item.progress
                    first.duration = item.duration
                    first.lastWatchedAt = Date()
                    first.playlistID = item.playlistID
                    first.seriesID = item.seriesID
                    if let cover = item.coverURL {
                        first.coverURL = cover
                    }
                    if let stream = item.streamURL {
                        first.streamURL = stream
                    }
                    first.title = item.title
                    if let sTitle = item.seriesTitle {
                        first.seriesTitle = sTitle
                    }
                } else {
                    context.insert(WatchHistoryItem(
                        id: item.id, type: item.type, title: item.title,
                        seriesTitle: item.seriesTitle, coverURL: item.coverURL,
                        streamURL: item.streamURL, progress: item.progress,
                        duration: item.duration, lastWatchedAt: Date(),
                        playlistID: item.playlistID, seriesID: item.seriesID,
                        profileID: profileID
                    ))
                }
                guard profileContextClient.snapshot() == scope else { return }
                try context.save()
                if let saved = try? context.fetch(descriptor).first(where: { $0.playlistID == item.playlistID }) {
                    try? await WatchProgressSyncClient.liveValue.syncItem(saved)
                }
            },
            deleteWatchProgress: { id, type, playlistID, scope in
                let profileID = scope.profileID
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<WatchHistoryItem>(predicate: #Predicate {
                    $0.id == id && $0.type == type && $0.profileID == profileID
                })
                let existing = try context.fetch(descriptor)
                let item = try existing.first(where: { $0.playlistID == playlistID }) ?? (profileID != nil && profileID == legacyDataOwnerID(in: context)
                    ? context.fetch(FetchDescriptor<WatchHistoryItem>(predicate: #Predicate {
                        $0.id == id && $0.type == type && $0.profileID == nil
                    })).first(where: { $0.playlistID == playlistID })
                    : nil)
                guard let item else { return }
                item.profileID = profileID
                let deletionDate = Date()
                item.lastWatchedAt = deletionDate
                item.removedAt = deletionDate
                guard profileContextClient.snapshot() == scope else { return }
                try context.save()
                try? await WatchProgressSyncClient.liveValue.syncItem(item)
                NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
            },
            clearWatchHistory: { scope in
                let profileID = scope.profileID
                let context = ModelContext(modelContainer)
                let existing = try watchHistory(in: context, profileID: profileID)
                let deletionDate = Date()
                for item in existing {
                    item.profileID = profileID
                    item.lastWatchedAt = deletionDate
                    item.removedAt = deletionDate
                }
                guard profileContextClient.snapshot() == scope else { return }
                try context.save()
                for item in existing {
                    try? await WatchProgressSyncClient.liveValue.syncItem(item)
                }
                NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
            },
            getWatchProgress: { id, type, playlistID, scope in
                let context = ModelContext(modelContainer)
                return try watchHistory(in: context, profileID: scope.profileID).first { $0.id == id && $0.type == type && $0.playlistID == playlistID }
            },
            getSeriesWatchProgress: { seriesID, playlistID, scope in
                let context = ModelContext(modelContainer)
                return try watchHistory(in: context, profileID: scope.profileID).first {
                    $0.seriesID == seriesID && $0.type == "episode" && $0.playlistID == playlistID
                }
            },
            fetchSeriesEpisodesWatchHistory: { seriesID, playlistID, scope in
                let context = ModelContext(modelContainer)
                return try watchHistory(in: context, profileID: scope.profileID).filter {
                    $0.seriesID == seriesID && $0.type == "episode" && $0.playlistID == playlistID
                }
            },
            fetchCategoryPreferences: { type in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<CategoryPreference>(
                    predicate: #Predicate { $0.type == type },
                    sortBy: [SortDescriptor(\.orderIndex)]
                )
                let models = try context.fetch(descriptor)
                return models.map {
                    CategoryPreferenceDTO(
                        id: $0.id,
                        type: $0.type,
                        categoryID: $0.categoryID,
                        isHidden: $0.isHidden,
                        isLocked: $0.isLocked,
                        orderIndex: $0.orderIndex
                    )
                }
            },
            saveCategoryPreferences: { preferences in
                let context = ModelContext(modelContainer)
                for pref in preferences {
                    let id = pref.id
                    let descriptor = FetchDescriptor<CategoryPreference>(
                        predicate: #Predicate { $0.id == id }
                    )
                    if let existing = try? context.fetch(descriptor).first {
                        existing.isHidden = pref.isHidden
                        existing.isLocked = pref.isLocked
                        existing.orderIndex = pref.orderIndex
                    } else {
                        let newModel = CategoryPreference(
                            id: pref.id,
                            type: pref.type,
                            categoryID: pref.categoryID,
                            isHidden: pref.isHidden,
                            isLocked: pref.isLocked,
                            orderIndex: pref.orderIndex
                        )
                        context.insert(newModel)
                    }
                }
                try context.save()
            },
            fetchSearchHistory: {
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<SearchHistoryItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
                return try context.fetch(descriptor)
            },
            saveSearchHistory: { query in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<SearchHistoryItem>(predicate: #Predicate { $0.query == query })
                let existing = try context.fetch(descriptor)

                if let first = existing.first {
                    first.timestamp = Date()
                } else {
                    let newItem = SearchHistoryItem(query: query)
                    context.insert(newItem)
                }

                // Keep only top 20
                let allDescriptor = FetchDescriptor<SearchHistoryItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
                let allItems = try context.fetch(allDescriptor)
                if allItems.count > 20 {
                    for item in allItems.dropFirst(20) {
                        context.delete(item)
                    }
                }

                try context.save()
            },
            clearSearchHistory: {
                let context = ModelContext(modelContainer)
                try context.delete(model: SearchHistoryItem.self)
                try context.save()
            }
        )
    }()

    public nonisolated static let testValue = DatabaseClient()
}

public extension DependencyValues {
    var databaseClient: DatabaseClient {
        get { self[DatabaseClient.self] }
        set { self[DatabaseClient.self] = newValue }
    }
}
