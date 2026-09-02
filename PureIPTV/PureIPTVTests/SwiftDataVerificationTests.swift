@testable import PureIPTV
import SwiftData
import XCTest

/// Verification tests for SwiftData schema fix implementation
final class SwiftDataVerificationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()

        // Create in-memory container for testing
        do {
            let schema = Schema(SharedDatabaseConfig.allModels)
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try ModelContainer(for: schema, configurations: [config])
            context = ModelContext(container)
        } catch {
            XCTFail("Failed to create test ModelContainer: \(error)")
        }
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - ModelContainer Initialization Tests

    func testModelContainerInitializationSucceeds() {
        // Verify that the SharedDatabaseConfig can create a ModelContainer
        XCTAssertNotNil(container, "ModelContainer should be initialized")
        XCTAssertNotNil(context, "ModelContext should be initialized")
    }

    func testSchemaContainsAllSixModels() {
        // Verify all 6 models are in the schema
        let modelTypes = SharedDatabaseConfig.allModels
        XCTAssertEqual(modelTypes.count, 6, "Schema should contain exactly 6 models")

        // Verify each model type is present
        let typeNames = modelTypes.map { String(describing: $0) }
        XCTAssertTrue(typeNames.contains("FavoriteItem"), "Schema should contain FavoriteItem")
        XCTAssertTrue(typeNames.contains("WatchHistoryItem"), "Schema should contain WatchHistoryItem")
        XCTAssertTrue(typeNames.contains("CategoryPreference"), "Schema should contain CategoryPreference")
        XCTAssertTrue(typeNames.contains("SearchHistoryItem"), "Schema should contain SearchHistoryItem")
        XCTAssertTrue(typeNames.contains("UserProfile"), "Schema should contain UserProfile")
        XCTAssertTrue(typeNames.contains("OfflineMedia"), "Schema should contain OfflineMedia")
    }

    // MARK: - CRUD Tests for FavoriteItem

    func testFavoriteItemCRUD() throws {
        // Create
        let favorite = FavoriteItem(
            id: "test_123",
            type: "live",
            title: "Test Channel",
            coverURL: "https://example.com/cover.jpg",
            playlistID: UUID()
        )
        context.insert(favorite)
        try context.save()

        // Read
        let fetchDescriptor = FetchDescriptor<FavoriteItem>(
            predicate: #Predicate { $0.id == "test_123" }
        )
        let fetchedFavorites = try context.fetch(fetchDescriptor)
        XCTAssertEqual(fetchedFavorites.count, 1, "Should fetch one favorite")
        XCTAssertEqual(fetchedFavorites.first?.title, "Test Channel")

        // Update
        fetchedFavorites.first?.title = "Updated Channel"
        try context.save()
        let updatedFavorites = try context.fetch(fetchDescriptor)
        XCTAssertEqual(updatedFavorites.first?.title, "Updated Channel")

        // Delete
        if let favoriteToDelete = fetchedFavorites.first {
            context.delete(favoriteToDelete)
            try context.save()
        }
        let deletedFavorites = try context.fetch(fetchDescriptor)
        XCTAssertEqual(deletedFavorites.count, 0, "Favorite should be deleted")
    }

    // MARK: - CRUD Tests for WatchHistoryItem

    func testWatchHistoryItemCRUD() throws {
        // Create
        let watchHistory = WatchHistoryItem(
            id: "vod_456",
            type: "vod",
            title: "Test Movie",
            progress: 120.0,
            duration: 7200.0,
            playlistID: UUID()
        )
        context.insert(watchHistory)
        try context.save()

        // Read
        let fetchDescriptor = FetchDescriptor<WatchHistoryItem>(
            predicate: #Predicate { $0.id == "vod_456" }
        )
        let fetchedHistory = try context.fetch(fetchDescriptor)
        XCTAssertEqual(fetchedHistory.count, 1)
        XCTAssertEqual(fetchedHistory.first?.progress, 120.0)

        // Update
        fetchedHistory.first?.progress = 240.0
        try context.save()
        let updatedHistory = try context.fetch(fetchDescriptor)
        XCTAssertEqual(updatedHistory.first?.progress, 240.0)

        // Delete
        if let historyToDelete = fetchedHistory.first {
            context.delete(historyToDelete)
            try context.save()
        }
        let deletedHistory = try context.fetch(fetchDescriptor)
        XCTAssertEqual(deletedHistory.count, 0)
    }

    // MARK: - CRUD Tests for CategoryPreference

    func testCategoryPreferenceCRUD() throws {
        // Create
        let preference = CategoryPreference(
            id: "live_789",
            type: "live",
            categoryID: "789",
            isHidden: false,
            orderIndex: 0
        )
        context.insert(preference)
        try context.save()

        // Read
        let fetchDescriptor = FetchDescriptor<CategoryPreference>(
            predicate: #Predicate { $0.id == "live_789" }
        )
        let fetchedPreferences = try context.fetch(fetchDescriptor)
        XCTAssertEqual(fetchedPreferences.count, 1)
        XCTAssertFalse(fetchedPreferences.first?.isHidden ?? true)

        // Update
        fetchedPreferences.first?.isHidden = true
        try context.save()
        let updatedPreferences = try context.fetch(fetchDescriptor)
        XCTAssertTrue(updatedPreferences.first?.isHidden ?? false)

        // Delete
        if let preferenceToDelete = fetchedPreferences.first {
            context.delete(preferenceToDelete)
            try context.save()
        }
        let deletedPreferences = try context.fetch(fetchDescriptor)
        XCTAssertEqual(deletedPreferences.count, 0)
    }

    // MARK: - CRUD Tests for SearchHistoryItem

    func testSearchHistoryItemCRUD() throws {
        // Create
        let searchItem = SearchHistoryItem(query: "test search")
        context.insert(searchItem)
        try context.save()

        // Read
        let fetchDescriptor = FetchDescriptor<SearchHistoryItem>(
            predicate: #Predicate { $0.query == "test search" }
        )
        let fetchedSearches = try context.fetch(fetchDescriptor)
        XCTAssertEqual(fetchedSearches.count, 1)
        XCTAssertEqual(fetchedSearches.first?.query, "test search")

        // Update (search query typically wouldn't be updated, but testing capability)
        fetchedSearches.first?.timestamp = Date()
        try context.save()
        let updatedSearches = try context.fetch(fetchDescriptor)
        XCTAssertNotNil(updatedSearches.first?.timestamp)

        // Delete
        if let searchToDelete = fetchedSearches.first {
            context.delete(searchToDelete)
            try context.save()
        }
        let deletedSearches = try context.fetch(fetchDescriptor)
        XCTAssertEqual(deletedSearches.count, 0)
    }
}
