import ComposableArchitecture
import Foundation
@testable import PureIPTV
import XCTest

@MainActor
final class PlaylistManagementFeatureTests: XCTestCase {
    func testAddPlaylistSheetToggles() async {
        let store = TestStore(initialState: PlaylistManagementFeature.State()) {
            PlaylistManagementFeature()
        }

        await store.send(.addPlaylistButtonTapped) {
            $0.addPlaylist = AddPlaylistFeature.State()
        }

        await store.send(.closeAddPlaylistTapped) {
            $0.addPlaylist = nil
        }
    }

    func testDeleteConfirmationFlow() async {
        let samplePlaylist = SavedPlaylist(
            id: UUID(),
            name: "Test Server",
            type: .xtream,
            serverURL: "http://example.com",
            username: "user",
            password: "pwd"
        )

        var state = PlaylistManagementFeature.State()
        state.playlists = [samplePlaylist]
        state.activePlaylistID = samplePlaylist.id

        let store = TestStore(initialState: state) {
            PlaylistManagementFeature()
        }

        // 1. Confirm delete opens dialog
        await store.send(.confirmDeletePlaylist(samplePlaylist)) {
            $0.playlistToDelete = samplePlaylist
        }

        // 2. Cancel delete resets state
        await store.send(.cancelDeletePlaylist) {
            $0.playlistToDelete = nil
        }
    }

    func testCloseTappedSendsDismissed() async {
        let store = TestStore(initialState: PlaylistManagementFeature.State()) {
            PlaylistManagementFeature()
        }

        await store.send(.closeTapped)
        await store.receive(\.delegate.dismissed)
    }
}
