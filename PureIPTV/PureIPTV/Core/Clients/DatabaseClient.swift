import ComposableArchitecture
import Foundation
import SwiftData

@DependencyClient
public struct DatabaseClient {
    public var fetchFavorites: @Sendable () async throws -> [FavoriteItem]
    public var fetchFavoritesByType: @Sendable (_ type: String) async throws -> [FavoriteItem]
    public var isFavorite: @Sendable (_ id: String) async throws -> Bool
    public var toggleFavorite: @Sendable (_ item: FavoriteItem) async throws -> Bool // Returns true if added, false if removed

    public var fetchWatchHistory: @Sendable () async throws -> [WatchHistoryItem]
    public var saveWatchProgress: @Sendable (_ item: WatchHistoryItem) async throws -> Void
    public var getWatchProgress: @Sendable (_ id: String) async throws -> WatchHistoryItem?
    public var getSeriesWatchProgress: @Sendable (_ seriesID: String) async throws -> WatchHistoryItem?

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
    public var orderIndex: Int

    public init(id: String, type: String, categoryID: String, isHidden: Bool, orderIndex: Int) {
        self.id = id
        self.type = type
        self.categoryID = categoryID
        self.isHidden = isHidden
        self.orderIndex = orderIndex
    }
}

extension DatabaseClient: DependencyKey {
    public static let liveValue: DatabaseClient = {
        // SwiftData Context Setup - Use shared container
        let modelContainer = SharedDatabaseConfig.shared

        return DatabaseClient(
            fetchFavorites: {
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<FavoriteItem>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)])
                return try context.fetch(descriptor)
            },
            fetchFavoritesByType: { type in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<FavoriteItem>(
                    predicate: #Predicate { $0.type == type },
                    sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
                )
                return try context.fetch(descriptor)
            },
            isFavorite: { id in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<FavoriteItem>(
                    predicate: #Predicate { $0.id == id }
                )
                return try context.fetchCount(descriptor) > 0
            },
            toggleFavorite: { item in
                let context = ModelContext(modelContainer)
                let id = item.id
                let descriptor = FetchDescriptor<FavoriteItem>(
                    predicate: #Predicate { $0.id == id }
                )

                let existing = try context.fetch(descriptor)
                if let first = existing.first {
                    context.delete(first)
                    try context.save()
                    return false
                } else {
                    context.insert(item)
                    try context.save()
                    return true
                }
            },
            fetchWatchHistory: {
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<WatchHistoryItem>(sortBy: [SortDescriptor(\.lastWatchedAt, order: .reverse)])
                return try context.fetch(descriptor)
            },
            saveWatchProgress: { item in
                let context = ModelContext(modelContainer)
                let id = item.id
                let descriptor = FetchDescriptor<WatchHistoryItem>(
                    predicate: #Predicate { $0.id == id }
                )

                let existing = try context.fetch(descriptor)
                if let first = existing.first {
                    first.progress = item.progress
                    first.duration = item.duration
                    first.lastWatchedAt = Date()
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
                    context.insert(item)
                }
                try context.save()
            },
            getWatchProgress: { id in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<WatchHistoryItem>(
                    predicate: #Predicate { $0.id == id }
                )
                return try context.fetch(descriptor).first
            },
            getSeriesWatchProgress: { seriesID in
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<WatchHistoryItem>(
                    predicate: #Predicate { $0.seriesID == seriesID },
                    sortBy: [SortDescriptor(\.lastWatchedAt, order: .reverse)]
                )
                return try context.fetch(descriptor).first
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
                        existing.orderIndex = pref.orderIndex
                    } else {
                        let newModel = CategoryPreference(
                            id: pref.id,
                            type: pref.type,
                            categoryID: pref.categoryID,
                            isHidden: pref.isHidden,
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
