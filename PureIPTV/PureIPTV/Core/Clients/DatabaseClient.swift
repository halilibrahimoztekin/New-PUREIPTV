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

    public var fetchCategoryPreferences: @Sendable (_ type: String, _ scope: CategoryPreferenceScope) async throws -> [CategoryPreferenceDTO]
    public var saveCategoryPreferences: @Sendable (_ preferences: [CategoryPreferenceDTO], _ scope: CategoryPreferenceScope) async throws -> Void
    public var fetchHiddenMediaItems: @Sendable (_ type: String?, _ scope: ProfileContextSnapshot) async throws -> [HiddenMediaEntry]
    public var setHiddenMediaItem: @Sendable (_ item: HiddenMediaEntry, _ isHidden: Bool, _ scope: ProfileContextSnapshot) async throws -> Bool

    public var fetchSearchHistory: @Sendable (_ retainingSince: Date) async throws -> [SearchHistoryItem]
    public var saveSearchHistory: @Sendable (_ query: String, _ retainingSince: Date) async throws -> Void
    public var clearSearchHistory: @Sendable () async throws -> Void
}

public struct CategoryPreferenceScope: Equatable, Sendable {
    public let profileID: UUID?
    public let playlistID: UUID?

    public init(profileID: UUID?, playlistID: UUID?) {
        self.profileID = profileID
        self.playlistID = playlistID
    }
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

private func categoryPreferenceStorageID(
    type: String,
    categoryID: String,
    scope: CategoryPreferenceScope
) -> String {
    let encodedComponents = [
        type,
        scope.profileID?.uuidString.lowercased() ?? "default-profile",
        scope.playlistID?.uuidString.lowercased() ?? "default-playlist",
        categoryID,
    ]
    .map { "\($0.utf8.count):\($0)" }
    .joined(separator: "|")
    return "category-preference-v2|" + encodedComponents
}

private func legacyCategoryPreferenceID(type: String, categoryID: String) -> String {
    "\(type)_\(categoryID)"
}

private func hiddenMediaEntries(
    in context: ModelContext,
    profileID: UUID?,
    type: String? = nil
) throws -> [HiddenMediaEntry] {
    let ownedDescriptor = FetchDescriptor<HiddenMediaRecord>(
        predicate: #Predicate { $0.profileID == profileID },
        sortBy: [SortDescriptor(\.hiddenAt, order: .reverse)]
    )
    let owned = try context.fetch(ownedDescriptor)
    let legacyRows: [HiddenMediaRecord]
    if let profileID, profileID == legacyDataOwnerID(in: context) {
        let legacyDescriptor = FetchDescriptor<HiddenMediaRecord>(
            predicate: #Predicate { $0.profileID == nil },
            sortBy: [SortDescriptor(\.hiddenAt, order: .reverse)]
        )
        legacyRows = try context.fetch(legacyDescriptor)
    } else {
        legacyRows = []
    }

    let shadowedKeys = Set(owned.map(\.identityKey))
    var seenKeys = Set<String>()
    return (owned + legacyRows.filter { !shadowedKeys.contains($0.identityKey) })
        .filter { record in
            guard record.removedAt == nil else { return false }
            guard let type else { return true }
            return record.type.caseInsensitiveCompare(type) == .orderedSame
        }
        .compactMap { record in
            guard seenKeys.insert(record.identityKey).inserted else { return nil }
            return HiddenMediaEntry(
                identity: HiddenMediaIdentity(type: record.type, playlistID: record.playlistID, mediaID: record.mediaID),
                title: record.title,
                hiddenAt: record.hiddenAt
            )
        }
}

private func setHiddenMediaEntry(
    _ entry: HiddenMediaEntry,
    isHidden: Bool,
    scope: ProfileContextSnapshot,
    modelContainer: ModelContainer,
    profileContextClient: ProfileContextClient
) throws -> Bool {
    guard entry.identity.type == "vod" || entry.identity.type == "series" else { return false }

    let profileID = scope.profileID
    let identityKey = entry.identity.storageKey
    let context = ModelContext(modelContainer)
    let descriptor = FetchDescriptor<HiddenMediaRecord>(predicate: #Predicate {
        $0.identityKey == identityKey && $0.profileID == profileID
    })
    var records = try context.fetch(descriptor)

    if records.isEmpty,
       let profileID,
       profileID == legacyDataOwnerID(in: context)
    {
        let legacyDescriptor = FetchDescriptor<HiddenMediaRecord>(predicate: #Predicate {
            $0.identityKey == identityKey && $0.profileID == nil
        })
        records = try context.fetch(legacyDescriptor)
    }

    if let primaryRecord = records.first {
        if let profileID, primaryRecord.profileID == nil {
            records.forEach { $0.profileID = profileID }
        }
        if isHidden {
            primaryRecord.mediaID = entry.identity.mediaID
            primaryRecord.type = entry.identity.type
            primaryRecord.title = entry.title
            primaryRecord.playlistID = entry.identity.playlistID
            primaryRecord.hiddenAt = Date()
            primaryRecord.removedAt = nil
            for duplicate in records.dropFirst() where duplicate.removedAt == nil {
                duplicate.removedAt = Date()
            }
        } else {
            let removedAt = Date()
            for record in records where record.removedAt == nil {
                record.removedAt = removedAt
            }
        }
    } else if isHidden {
        context.insert(HiddenMediaRecord(entry: entry, profileID: profileID))
    } else {
        return true
    }

    guard profileContextClient.snapshot() == scope else { return false }
    try context.save()
    NotificationCenter.default.post(name: .hiddenMediaDidChange, object: nil)
    return true
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
    let rawList = (owned + visibleLegacy).filter { $0.removedAt == nil }
        .sorted { $0.lastWatchedAt > $1.lastWatchedAt }

    // Deduplicate duplicate rows by historyScopeKey, preserving the newest entry
    var seenScopeKeys = Set<String>()
    var deduplicated: [WatchHistoryItem] = []
    for item in rawList {
        let key = historyScopeKey(item)
        if !seenScopeKeys.contains(key) {
            seenScopeKeys.insert(key)
            deduplicated.append(item)
        }
    }
    return deduplicated
}

extension DatabaseClient: DependencyKey {
    public static let liveValue: DatabaseClient = {
        // SwiftData Context Setup - Use shared container
        let profileContextClient = ProfileContextClient.liveValue

        return DatabaseClient(
            fetchFavorites: { scope in
                let profileID = scope.profileID
                let context = try ModelContext(SharedDatabaseConfig.shared)
                return try favorites(in: context, profileID: profileID)
            },
            fetchFavoritesByType: { type, scope in
                let profileID = scope.profileID
                let context = try ModelContext(SharedDatabaseConfig.shared)
                return try favorites(in: context, profileID: profileID, type: type)
            },
            isFavorite: { id, type, playlistID, scope in
                let profileID = scope.profileID
                let context = try ModelContext(SharedDatabaseConfig.shared)
                return try favorites(in: context, profileID: profileID, type: type).contains { $0.id == id && $0.playlistID == playlistID }
            },
            toggleFavorite: { item, scope in
                let profileID = scope.profileID
                let context = try ModelContext(SharedDatabaseConfig.shared)
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
                    modelContainer: SharedDatabaseConfig.shared,
                    profileContextClient: profileContextClient
                )
            },
            fetchWatchHistory: { scope in
                let profileID = scope.profileID
                let context = try ModelContext(SharedDatabaseConfig.shared)
                let allItems = try watchHistory(in: context, profileID: profileID)
                var seenSeriesIDs = Set<String>()
                var seenItemIDs = Set<String>()
                var deduplicatedItems: [WatchHistoryItem] = []

                for item in allItems {
                    guard !seenItemIDs.contains(item.id) else { continue }
                    if let seriesID = item.seriesID, !seriesID.isEmpty {
                        let key = "\(seriesID)|\(item.playlistID?.uuidString ?? "")"
                        if !seenSeriesIDs.contains(key) {
                            seenSeriesIDs.insert(key)
                            seenItemIDs.insert(item.id)
                            deduplicatedItems.append(item)
                        }
                    } else {
                        seenItemIDs.insert(item.id)
                        deduplicatedItems.append(item)
                    }
                }

                return deduplicatedItems
            },
            fetchEpisodeWatchHistory: { scope in
                let context = try ModelContext(SharedDatabaseConfig.shared)
                return try watchHistory(in: context, profileID: scope.profileID).filter {
                    $0.type.caseInsensitiveCompare("episode") == .orderedSame
                }
            },
            saveWatchProgress: { item, scope in
                let profileID = scope.profileID
                let context = try ModelContext(SharedDatabaseConfig.shared)
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
                NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
                if let saved = try? context.fetch(descriptor).first(where: { $0.playlistID == item.playlistID }) {
                    try? await WatchProgressSyncClient.liveValue.syncItem(saved)
                }
            },
            deleteWatchProgress: { id, type, playlistID, scope in
                let profileID = scope.profileID
                let context = try ModelContext(SharedDatabaseConfig.shared)
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
                let context = try ModelContext(SharedDatabaseConfig.shared)
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
                let context = try ModelContext(SharedDatabaseConfig.shared)
                return try watchHistory(in: context, profileID: scope.profileID).first { $0.id == id && $0.type == type && $0.playlistID == playlistID }
            },
            getSeriesWatchProgress: { seriesID, playlistID, scope in
                let context = try ModelContext(SharedDatabaseConfig.shared)
                return try watchHistory(in: context, profileID: scope.profileID).first {
                    $0.seriesID == seriesID && $0.type == "episode" && $0.playlistID == playlistID
                }
            },
            fetchSeriesEpisodesWatchHistory: { seriesID, playlistID, scope in
                let context = try ModelContext(SharedDatabaseConfig.shared)
                return try watchHistory(in: context, profileID: scope.profileID).filter {
                    $0.seriesID == seriesID && $0.type == "episode" && $0.playlistID == playlistID
                }
            },
            fetchCategoryPreferences: { type, scope in
                let context = try ModelContext(SharedDatabaseConfig.shared)
                let descriptor = FetchDescriptor<CategoryPreference>(
                    predicate: #Predicate { $0.type == type },
                    sortBy: [SortDescriptor(\.orderIndex)]
                )
                let models = try context.fetch(descriptor)

                var preferencesByCategory: [String: CategoryPreferenceDTO] = [:]
                for model in models where model.profileID == nil
                    && model.playlistID == nil
                    && model.id == legacyCategoryPreferenceID(type: type, categoryID: model.categoryID)
                {
                    preferencesByCategory[model.categoryID] = CategoryPreferenceDTO(
                        id: categoryPreferenceStorageID(type: type, categoryID: model.categoryID, scope: scope),
                        type: model.type,
                        categoryID: model.categoryID,
                        isHidden: model.isHidden,
                        isLocked: model.isLocked,
                        orderIndex: model.orderIndex
                    )
                }

                for model in models where model.profileID == scope.profileID
                    && model.playlistID == scope.playlistID
                    && model.id == categoryPreferenceStorageID(type: type, categoryID: model.categoryID, scope: scope)
                {
                    preferencesByCategory[model.categoryID] = CategoryPreferenceDTO(
                        id: model.id,
                        type: model.type,
                        categoryID: model.categoryID,
                        isHidden: model.isHidden,
                        isLocked: model.isLocked,
                        orderIndex: model.orderIndex
                    )
                }

                return preferencesByCategory.values.sorted {
                    if $0.orderIndex != $1.orderIndex {
                        return $0.orderIndex < $1.orderIndex
                    }
                    return $0.categoryID < $1.categoryID
                }
            },
            saveCategoryPreferences: { preferences, scope in
                let context = try ModelContext(SharedDatabaseConfig.shared)
                for pref in preferences {
                    let id = categoryPreferenceStorageID(type: pref.type, categoryID: pref.categoryID, scope: scope)
                    let descriptor = FetchDescriptor<CategoryPreference>(
                        predicate: #Predicate { $0.id == id }
                    )
                    if let existing = try context.fetch(descriptor).first {
                        existing.type = pref.type
                        existing.categoryID = pref.categoryID
                        existing.profileID = scope.profileID
                        existing.playlistID = scope.playlistID
                        existing.isHidden = pref.isHidden
                        existing.isLocked = pref.isLocked
                        existing.orderIndex = pref.orderIndex
                    } else {
                        let newModel = CategoryPreference(
                            id: id,
                            type: pref.type,
                            categoryID: pref.categoryID,
                            profileID: scope.profileID,
                            playlistID: scope.playlistID,
                            isHidden: pref.isHidden,
                            isLocked: pref.isLocked,
                            orderIndex: pref.orderIndex
                        )
                        context.insert(newModel)
                    }
                }
                try context.save()
            },
            fetchHiddenMediaItems: { type, scope in
                guard profileContextClient.snapshot() == scope else { return [] }
                let context = try ModelContext(SharedDatabaseConfig.shared)
                return try hiddenMediaEntries(in: context, profileID: scope.profileID, type: type)
            },
            setHiddenMediaItem: { item, isHidden, scope in
                try setHiddenMediaEntry(
                    item,
                    isHidden: isHidden,
                    scope: scope,
                    modelContainer: SharedDatabaseConfig.shared,
                    profileContextClient: profileContextClient
                )
            },
            fetchSearchHistory: { retainingSince in
                let context = try ModelContext(SharedDatabaseConfig.shared)
                let descriptor = FetchDescriptor<SearchHistoryItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
                let items = try context.fetch(descriptor)
                let expiredItems = items.filter { $0.timestamp < retainingSince }
                for item in expiredItems {
                    context.delete(item)
                }
                if !expiredItems.isEmpty {
                    try context.save()
                }
                return items.filter { $0.timestamp >= retainingSince }
            },
            saveSearchHistory: { query, retainingSince in
                let context = try ModelContext(SharedDatabaseConfig.shared)

                let allDescriptor = FetchDescriptor<SearchHistoryItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
                let allItems = try context.fetch(allDescriptor)
                for item in allItems where item.timestamp < retainingSince {
                    context.delete(item)
                }

                let descriptor = FetchDescriptor<SearchHistoryItem>(predicate: #Predicate { $0.query == query })
                let existing = try context.fetch(descriptor)

                if let first = existing.first {
                    first.timestamp = Date()
                } else {
                    let newItem = SearchHistoryItem(query: query)
                    context.insert(newItem)
                }

                // Keep only top 20
                let retainedItems = try context.fetch(allDescriptor)
                if retainedItems.count > 20 {
                    for item in retainedItems.dropFirst(20) {
                        context.delete(item)
                    }
                }

                try context.save()
            },
            clearSearchHistory: {
                let context = try ModelContext(SharedDatabaseConfig.shared)
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
