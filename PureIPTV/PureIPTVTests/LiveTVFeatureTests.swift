import ComposableArchitecture
@testable import PureIPTV
import XCTest

@MainActor
final class LiveTVFeatureTests: XCTestCase {
    func testOnDisappearPreservesCompletedChannelSortCache() async {
        let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)
        var initialState = LiveTVFeature.State()
        initialState.isVisible = true
        initialState.channelSortLoadedCategoryID = "sports"
        initialState.channelSortReferenceDate = referenceDate

        let store = TestStore(initialState: initialState) {
            LiveTVFeature()
        }
        store.exhaustivity = .off

        await store.send(.onDisappear)

        XCTAssertFalse(store.state.isVisible)
        XCTAssertEqual(store.state.channelSortLoadedCategoryID, "sports")
        XCTAssertEqual(store.state.channelSortReferenceDate, referenceDate)
        XCTAssertFalse(store.state.isLoadingChannelSortEPG)
    }
}
