import ComposableArchitecture
import Foundation
@testable import PureIPTV
import SwiftVLC
import XCTest

@MainActor
final class PiPBackgroundEngineTests: XCTestCase {
    func testBackgroundPlaybackModeProperties() {
        let pipMode = BackgroundPlaybackMode.pip
        XCTAssertEqual(pipMode.id, "pip")
        XCTAssertEqual(pipMode.title, "Resim İçinde Resim (PiP)")
        XCTAssertEqual(pipMode.icon, "pip.enter")
        XCTAssertFalse(pipMode.descriptionText.isEmpty)

        let audioMode = BackgroundPlaybackMode.audioOnly
        XCTAssertEqual(audioMode.id, "audioOnly")
        XCTAssertEqual(audioMode.title, "Yalnızca Ses (Arka Plan)")
        XCTAssertEqual(audioMode.icon, "waveform")
        XCTAssertFalse(audioMode.descriptionText.isEmpty)

        let disabledMode = BackgroundPlaybackMode.disabled
        XCTAssertEqual(disabledMode.id, "disabled")
        XCTAssertEqual(disabledMode.title, "Kapalı (Durdur)")
        XCTAssertEqual(disabledMode.icon, "slash.circle")
        XCTAssertFalse(disabledMode.descriptionText.isEmpty)

        XCTAssertEqual(BackgroundPlaybackMode.allCases.count, 3)
    }

    func testPiPClientDefaultAndToggle() {
        let autoPiP = LockIsolated(true)
        let bgMode = LockIsolated(BackgroundPlaybackMode.pip)

        let client = PiPClient(
            isPiPSupported: { true },
            isAutoPiPEnabled: { autoPiP.value },
            setAutoPiPEnabled: { autoPiP.setValue($0) },
            backgroundPlaybackMode: { bgMode.value },
            setBackgroundPlaybackMode: { bgMode.setValue($0) },
            configureAudioSession: { _ in }
        )

        XCTAssertTrue(client.isPiPSupported())
        XCTAssertTrue(client.isAutoPiPEnabled())
        XCTAssertEqual(client.backgroundPlaybackMode(), .pip)

        // Change auto PiP
        client.setAutoPiPEnabled(false)
        XCTAssertFalse(client.isAutoPiPEnabled())

        // Change background mode
        client.setBackgroundPlaybackMode(.audioOnly)
        XCTAssertEqual(client.backgroundPlaybackMode(), .audioOnly)

        client.setBackgroundPlaybackMode(.disabled)
        XCTAssertEqual(client.backgroundPlaybackMode(), .disabled)
    }

    func testPlayerFeaturePiPLifecycle() async throws {
        let testItem = try PlayerFeature.PlayableItem(
            id: "channel-1",
            title: "beIN Sports 1",
            seriesTitle: nil,
            streamURL: XCTUnwrap(URL(string: "http://example.com/live.m3u8")),
            coverURL: nil,
            seriesID: nil,
            startPosition: nil,
            initialDuration: nil,
            initialProgress: nil,
            isLive: true,
            config: nil,
            epgChannelID: nil,
            tvArchive: nil
        )

        var state = PlayerFeature.State(item: testItem)
        state.isPiPActive = false
        state.shouldTriggerPiP = false

        let store = TestStore(initialState: state) {
            PlayerFeature()
        } withDependencies: {
            $0.pipClient.isPiPSupported = { true }
            $0.pipClient.isAutoPiPEnabled = { true }
            $0.pipClient.backgroundPlaybackMode = { .pip }
            $0.pipClient.setAutoPiPEnabled = { _ in }
            $0.pipClient.setBackgroundPlaybackMode = { _ in }
            $0.pipClient.configureAudioSession = { _ in }
        }

        // 1. Toggle PiP
        await store.send(.togglePiP) {
            $0.shouldTriggerPiP = true
        }

        // 2. Reset Trigger
        await store.send(.resetPiPTrigger) {
            $0.shouldTriggerPiP = false
        }

        // 3. PiP Started
        await store.send(.pipStarted) {
            $0.isPiPActive = true
        }

        // 4. On PiP status changed
        await store.send(.onPiPStatusChanged(isActive: true))

        // 5. Restore UI
        await store.send(.pipRestoreUI) {
            $0.isPiPActive = false
            $0.isControlsVisible = true
            $0.oledInactivitySeconds = 0
        }

        // 6. Set Auto PiP
        await store.send(.setAutoPiPEnabled(false)) {
            $0.isAutoPiPEnabled = false
        }

        // 7. Set Background Playback Mode
        await store.send(.setBackgroundPlaybackMode(.audioOnly)) {
            $0.backgroundPlaybackMode = .audioOnly
        }
    }

    func testPlayerFeatureAppMovedToBackground() async throws {
        let testItem = try PlayerFeature.PlayableItem(
            id: "movie-1",
            title: "Inception (2010)",
            seriesTitle: nil,
            streamURL: XCTUnwrap(URL(string: "http://example.com/movie.mp4")),
            coverURL: nil,
            seriesID: nil,
            startPosition: nil,
            initialDuration: nil,
            initialProgress: nil,
            isLive: false,
            config: nil,
            epgChannelID: nil,
            tvArchive: nil
        )

        var state = PlayerFeature.State(item: testItem)
        state.playerState = .playing
        state.isPiPSupported = true
        state.isAutoPiPEnabled = true
        state.backgroundPlaybackMode = .pip

        let store = TestStore(initialState: state) {
            PlayerFeature()
        } withDependencies: {
            $0.pipClient.isPiPSupported = { true }
            $0.pipClient.isAutoPiPEnabled = { true }
            $0.pipClient.backgroundPlaybackMode = { .pip }
        }

        // In .pip mode while playing, app moving to background triggers PiP
        await store.send(.appMovedToBackground) {
            $0.shouldTriggerPiP = true
        }

        // Switch to audioOnly mode
        await store.send(.setBackgroundPlaybackMode(.audioOnly)) {
            $0.backgroundPlaybackMode = .audioOnly
        }
        await store.send(.resetPiPTrigger) {
            $0.shouldTriggerPiP = false
        }

        // In .audioOnly mode, app moving to background activates background audio
        await store.send(.appMovedToBackground) {
            $0.isBackgroundAudioActive = true
        }

        // Foreground restores audio active flag
        await store.send(.appMovedToForeground) {
            $0.isBackgroundAudioActive = false
        }
    }

    func testSettingsFeaturePiPUpdates() async {
        var savedAutoPiP = true
        var savedBgMode = BackgroundPlaybackMode.pip

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.pipClient.isAutoPiPEnabled = { savedAutoPiP }
            $0.pipClient.setAutoPiPEnabled = { savedAutoPiP = $0 }
            $0.pipClient.backgroundPlaybackMode = { savedBgMode }
            $0.pipClient.setBackgroundPlaybackMode = { savedBgMode = $0 }
        }

        await store.send(.setAutoPiPEnabled(false)) {
            $0.isAutoPiPEnabled = false
        }

        await store.send(.setBackgroundPlaybackMode(.audioOnly)) {
            $0.backgroundPlaybackMode = .audioOnly
        }
    }
}
