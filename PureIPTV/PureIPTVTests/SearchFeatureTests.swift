import ComposableArchitecture
import Foundation
@testable import PureIPTV
import XCTest

@MainActor
final class SearchFeatureTests: XCTestCase {
    func testFuzzySearchEngineRelevance() {
        let item1 = MediaModels.Item(
            id: "1",
            title: "beIN SPORTS 1 HD",
            categoryID: "cat1",
            type: .live
        )
        let item2 = MediaModels.Item(
            id: "2",
            title: "beIN SPORTS HABER HD",
            categoryID: "cat1",
            type: .live
        )
        let item3 = MediaModels.Item(
            id: "3",
            title: "EUROSPORT 1 TR",
            categoryID: "cat1",
            type: .live
        )

        let items = [item1, item2, item3]

        // Multi-token match: "bein 1" should rank item1 first
        let results1 = FuzzySearchEngine.searchItems(items, query: "bein 1")
        XCTAssertFalse(results1.isEmpty)
        XCTAssertEqual(results1.first?.id, "1")

        // Turkish diacritic match: "sampiyon" vs "Şampiyonlar"
        let turkishItem = MediaModels.Item(
            id: "tr",
            title: "Şampiyonlar Ligi Özel",
            categoryID: "cat1",
            type: .live
        )
        let resultsTR = FuzzySearchEngine.searchItems([turkishItem], query: "sampiyon")
        XCTAssertEqual(resultsTR.count, 1)

        // Empty query returns empty
        let emptyResults = FuzzySearchEngine.searchItems(items, query: "   ")
        XCTAssertTrue(emptyResults.isEmpty)
    }

    func testSearchQueryAndClear() async {
        let clock = TestClock()
        let store = TestStore(initialState: SearchFeature.State()) {
            SearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.queryChanged("Batman")) {
            $0.searchQuery = "Batman"
            $0.isSearching = true
        }

        await store.send(.queryChanged("")) {
            $0.searchQuery = ""
            $0.isSearching = false
        }
    }

    func testResetCache() async {
        var state = SearchFeature.State()
        state.hasLoaded = true
        state.searchQuery = "test"
        state.debouncedQuery = "test"
        state.allChannels = [
            MediaModels.Item(id: "1", title: "Channel 1", categoryID: "c1", type: .live),
        ]

        let store = TestStore(initialState: state) {
            SearchFeature()
        }

        await store.send(.resetCache) {
            $0.hasLoaded = false
            $0.allChannels = []
            $0.searchQuery = ""
            $0.debouncedQuery = ""
        }
    }

    func testGlobalSearchEngineFilteringAnd4KDetection() {
        let channel1 = MediaModels.Item(id: "c1", title: "TRT 1 4K UHD", categoryID: "cat1", type: .live)
        let channel2 = MediaModels.Item(id: "c2", title: "beIN Sports 1 HD", categoryID: "cat1", type: .live)
        let movie1 = MediaModels.Item(id: "m1", title: "Inception 2160p UHD", categoryID: "cat2", type: .vod)
        let series1 = MediaModels.Item(id: "s1", title: "Severance S02", categoryID: "cat3", type: .series)

        let playlistAId = UUID()
        let playlistBId = UUID()
        let playlistA = PlaylistSourceBadge(id: playlistAId.uuidString, playlistName: "Ev Sunucusu", colorHex: "#3B82F6")
        let playlistB = PlaylistSourceBadge(id: playlistBId.uuidString, playlistName: "Yedek Sunucu", colorHex: "#10B981")

        let indexedChannels = [
            GlobalSearchResultItem(item: channel1, playlistBadge: playlistA),
            GlobalSearchResultItem(item: channel2, playlistBadge: playlistB),
        ]
        let indexedVODs = [
            GlobalSearchResultItem(item: movie1, playlistBadge: playlistA),
        ]
        let indexedSeries = [
            GlobalSearchResultItem(item: series1, playlistBadge: playlistA),
        ]

        // 1. Check 4K Detection
        XCTAssertTrue(indexedChannels[0].is4K)
        XCTAssertFalse(indexedChannels[1].is4K)
        XCTAssertTrue(indexedVODs[0].is4K)

        // 2. Multi-filter search output & counts
        let output = GlobalSearchEngine.search(
            query: "1",
            filter: .all,
            selectedPlaylistID: nil,
            channels: indexedChannels,
            vods: indexedVODs,
            series: indexedSeries
        )
        // Matches query "1": "TRT 1 4K UHD" (live), "beIN Sports 1 HD" (live), "Inception 2160p UHD" (vod, contains 1)
        XCTAssertEqual(output.counts[.live], 2)
        XCTAssertEqual(output.counts[.vod], 1)
        XCTAssertEqual(output.counts[.series], 0)
        XCTAssertEqual(output.counts[.uhd4k], 2) // TRT 1 and Inception

        // 3. Filter by 4K UHD
        let uhdOutput = GlobalSearchEngine.search(
            query: "1",
            filter: .uhd4k,
            selectedPlaylistID: nil,
            channels: indexedChannels,
            vods: indexedVODs,
            series: indexedSeries
        )
        let totalUHDItems = uhdOutput.live + uhdOutput.vods + uhdOutput.series
        XCTAssertEqual(totalUHDItems.count, 2)
        XCTAssertTrue(totalUHDItems.allSatisfy(\.is4K))

        // 4. Multi-playlist scoping
        let pBOutput = GlobalSearchEngine.search(
            query: "Sports",
            filter: .all,
            selectedPlaylistID: playlistBId,
            channels: indexedChannels,
            vods: indexedVODs,
            series: indexedSeries
        )
        XCTAssertEqual(pBOutput.live.count, 1)
        XCTAssertEqual(pBOutput.live.first?.item.id, "c2")
    }
}
