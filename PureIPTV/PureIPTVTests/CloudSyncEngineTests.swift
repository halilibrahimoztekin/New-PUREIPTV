import ComposableArchitecture
import Foundation
@testable import PureIPTV
import XCTest

@MainActor
final class CloudSyncEngineTests: XCTestCase {
    // MARK: - 1. FavoriteSyncDTO Model Tests

    func testFavoriteSyncDTOInitializationAndCodable() throws {
        let now = Date()
        let playlistUUID = UUID()
        let dto = FavoriteSyncDTO(
            id: "ch-trt1",
            type: "live",
            title: "TRT 1 HD",
            coverURL: "https://example.com/trt1.png",
            streamURL: "https://example.com/trt1.m3u8",
            addedAt: now,
            playlistID: playlistUUID
        )

        XCTAssertEqual(dto.id, "ch-trt1")
        XCTAssertEqual(dto.type, "live")
        XCTAssertEqual(dto.title, "TRT 1 HD")
        XCTAssertEqual(dto.coverURL, "https://example.com/trt1.png")
        XCTAssertEqual(dto.streamURL, "https://example.com/trt1.m3u8")
        XCTAssertEqual(dto.addedAt, now)
        XCTAssertEqual(dto.playlistID, playlistUUID)

        // Codable roundtrip
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(FavoriteSyncDTO.self, from: data)

        XCTAssertEqual(decoded, dto)
    }

    func testFavoriteItemConversion() {
        let favorite = FavoriteItem(
            id: "vod-100",
            type: "vod",
            title: "Interstellar",
            coverURL: "https://example.com/interstellar.jpg",
            streamURL: "https://example.com/stream.mp4"
        )

        let dto = FavoriteSyncDTO(from: favorite)
        XCTAssertEqual(dto.id, favorite.id)
        XCTAssertEqual(dto.type, favorite.type)
        XCTAssertEqual(dto.title, favorite.title)

        let backToItem = dto.toFavoriteItem()
        XCTAssertEqual(backToItem.id, dto.id)
        XCTAssertEqual(backToItem.type, dto.type)
        XCTAssertEqual(backToItem.title, dto.title)
    }

    // MARK: - 2. CloudSyncSummary Model Tests

    func testCloudSyncSummaryModel() throws {
        let now = Date()
        let summary = CloudSyncSummary(
            favoritesCount: 24,
            hiddenChannelsCount: 3,
            blacklistedCategoriesCount: 2,
            watchProgressCount: 15,
            lastSyncDate: now,
            deviceID: "device-uuid-test"
        )

        XCTAssertEqual(summary.favoritesCount, 24)
        XCTAssertEqual(summary.hiddenChannelsCount, 3)
        XCTAssertEqual(summary.blacklistedCategoriesCount, 2)
        XCTAssertEqual(summary.watchProgressCount, 15)
        XCTAssertEqual(summary.deviceID, "device-uuid-test")

        let data = try JSONEncoder().encode(summary)
        let decoded = try JSONDecoder().decode(CloudSyncSummary.self, from: data)

        XCTAssertEqual(decoded.favoritesCount, summary.favoritesCount)
        XCTAssertEqual(decoded.hiddenChannelsCount, summary.hiddenChannelsCount)
        XCTAssertEqual(decoded.watchProgressCount, summary.watchProgressCount)
        XCTAssertEqual(decoded.deviceID, summary.deviceID)
    }

    // MARK: - 3. Conflict Resolution Heuristics Tests

    func testFavoriteConflictResolutionNewerTimestampWins() {
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)

        let localFavorite = FavoriteSyncDTO(
            id: "fav-1",
            type: "live",
            title: "Old Channel Name",
            addedAt: olderDate
        )

        let remoteFavorite = FavoriteSyncDTO(
            id: "fav-1",
            type: "live",
            title: "Updated Channel Name",
            addedAt: newerDate
        )

        var map = [localFavorite.id: localFavorite]
        if let existing = map[remoteFavorite.id] {
            if remoteFavorite.addedAt > existing.addedAt {
                map[remoteFavorite.id] = remoteFavorite
            }
        }

        XCTAssertEqual(map["fav-1"]?.title, "Updated Channel Name")
    }

    func testHiddenItemsUnionMergeResolution() {
        let date1 = Date(timeIntervalSince1970: 100)
        let date2 = Date(timeIntervalSince1970: 200)

        let localItems = [
            HiddenItemDTO(id: "ch-1", title: "Kanal 1", type: .channel, hiddenAt: date1),
            HiddenItemDTO(id: "cat-1", title: "Yetişkin", type: .category, hiddenAt: date1),
        ]

        let remoteItems = [
            HiddenItemDTO(id: "ch-1", title: "Kanal 1 (Yeni)", type: .channel, hiddenAt: date2),
            HiddenItemDTO(id: "ch-2", title: "Kanal 2", type: .channel, hiddenAt: date1),
        ]

        var mergedMap: [String: HiddenItemDTO] = Dictionary(uniqueKeysWithValues: localItems.map { ($0.id, $0) })
        for r in remoteItems {
            if let existing = mergedMap[r.id] {
                if r.hiddenAt >= existing.hiddenAt {
                    mergedMap[r.id] = r
                }
            } else {
                mergedMap[r.id] = r
            }
        }

        XCTAssertEqual(mergedMap.count, 3)
        XCTAssertEqual(mergedMap["ch-1"]?.title, "Kanal 1 (Yeni)")
        XCTAssertNotNil(mergedMap["ch-2"])
        XCTAssertNotNil(mergedMap["cat-1"])
    }

    // MARK: - 4. SettingsFeature iCloud Sync Reducer Flow Tests

    func testSettingsFeatureSyncNowSuccessFlow() async {
        let now = Date()
        let testSummary = CloudSyncSummary(
            favoritesCount: 10,
            hiddenChannelsCount: 2,
            blacklistedCategoriesCount: 1,
            watchProgressCount: 5,
            lastSyncDate: now,
            deviceID: "mock-device"
        )

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.cloudSyncClient.isSyncEnabled = { true }
            $0.cloudSyncClient.performFullSync = { testSummary }
            $0.cloudSyncClient.lastSyncDate = { now }
            $0.cloudSyncClient.getSyncStatus = { .success(now) }
            $0.cloudSyncClient.observeRemoteChanges = { AsyncStream { $0.finish() } }
        }

        // Tap Sync Now
        await store.send(.syncNowTapped) {
            $0.isCloudSyncing = true
            $0.cloudSyncStatus = .syncing
            $0.cloudSyncMessage = nil
        }

        // Response arrives successfully
        await store.receive(\.syncNowResponse.success) {
            $0.isCloudSyncing = false
            $0.cloudSyncStatus = .success(now)
            $0.lastCloudSyncDate = now
            $0.cloudSyncSummary = testSummary
            $0.cloudSyncMessage = "iCloud senkronizasyonu tamamlandı (10 favori, 2 gizli kanal)."
        }
    }

    func testSettingsFeatureSyncNowFailureFlow() async {
        struct MockSyncError: Error, LocalizedError, Equatable {
            var errorDescription: String? {
                "Ağ bağlantısı yok."
            }
        }

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.cloudSyncClient.isSyncEnabled = { true }
            $0.cloudSyncClient.performFullSync = { throw MockSyncError() }
            $0.cloudSyncClient.lastSyncDate = { nil }
            $0.cloudSyncClient.getSyncStatus = { .idle }
            $0.cloudSyncClient.observeRemoteChanges = { AsyncStream { $0.finish() } }
        }

        await store.send(.syncNowTapped) {
            $0.isCloudSyncing = true
            $0.cloudSyncStatus = .syncing
            $0.cloudSyncMessage = nil
        }

        await store.receive(\.syncNowResponse.failure) {
            $0.isCloudSyncing = false
            $0.cloudSyncStatus = .error("Ağ bağlantısı yok.")
            $0.cloudSyncMessage = "iCloud eşitleme hatası: Ağ bağlantısı yok."
        }
    }

    func testSettingsFeatureToggleICloudSync() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.cloudSyncClient.setSyncEnabled = { _ in }
            $0.settingsClient.setIsICloudSyncEnabled = { _ in }
        }

        await store.send(.setICloudSyncEnabled(false)) {
            $0.isICloudSyncEnabled = false
        }

        await store.send(.setICloudSyncEnabled(true)) {
            $0.isICloudSyncEnabled = true
        }
    }
}
