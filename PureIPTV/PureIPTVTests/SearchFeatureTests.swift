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
            $0.debouncedQuery = ""
            $0.isSearching = false
            $0.liveResults = []
            $0.vodResults = []
            $0.seriesResults = []
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
            $0.isLoading = false
            $0.isSearching = false
            $0.allChannels = []
            $0.allVODs = []
            $0.allSeries = []
            $0.liveResults = []
            $0.vodResults = []
            $0.seriesResults = []
            $0.searchQuery = ""
            $0.debouncedQuery = ""
            $0.lastLoadedConfig = nil
        }
    }
}
