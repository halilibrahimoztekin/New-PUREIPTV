import ComposableArchitecture
@testable import PureIPTV
import XCTest

@MainActor
final class SearchFeatureTests: XCTestCase {
    func testSearchQueryAndClear() async {
        let store = TestStore(initialState: SearchFeature.State()) {
            SearchFeature()
        }

        await store.send(.queryChanged("Batman")) {
            $0.searchQuery = "Batman"
            // Assuming debounce handles the debouncedQuery state
        }

        await store.send(.queryChanged("")) {
            $0.searchQuery = ""
        }
    }
}
