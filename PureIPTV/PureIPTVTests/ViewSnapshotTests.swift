import ComposableArchitecture
@testable import PureIPTV
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class ViewSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Record all snapshots on the first run, set to false afterwards
        // isRecording = true
    }

    func testSplashView() {
        let store = Store(initialState: SplashFeature.State()) {
            SplashFeature()
        }
        let view = SplashView(store: store)
        let vc = UIHostingController(rootView: view)

        assertSnapshot(of: vc, as: .image(on: .iPhone13))
    }

    func testAddPlaylistView() {
        let store = Store(initialState: AddPlaylistFeature.State()) {
            AddPlaylistFeature()
        }
        let view = AddPlaylistView(store: store)
        let vc = UIHostingController(rootView: view)

        assertSnapshot(of: vc, as: .image(on: .iPhone13))
    }

    func testHomeView() {
        let store = Store(
            initialState: HomeFeature.State(
                serverURL: "http://example.com",
                username: "user1",
                password: "password1"
            )
        ) {
            HomeFeature()
        }
        let view = HomeView(store: store)
        let vc = UIHostingController(rootView: view)

        assertSnapshot(of: vc, as: .image(on: .iPhone13))
    }

    func testLiveTVView() {
        let store = Store(initialState: LiveTVFeature.State()) {
            LiveTVFeature()
        }
        let view = LiveTVView(
            store: store,
            serverURL: "http://example.com",
            username: "user1",
            password: "password1"
        )
        let vc = UIHostingController(rootView: view)

        assertSnapshot(of: vc, as: .image(on: .iPhone13))
    }
}
