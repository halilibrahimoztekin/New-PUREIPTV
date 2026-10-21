import ComposableArchitecture
import Foundation
@testable import PureIPTV
import Testing

@MainActor
struct LiveEPGPreviewEngineTests {
    private func createSampleChannel(id: String, name: String) -> MediaModels.Item {
        MediaModels.Item(
            id: id,
            title: name,
            streamURL: URL(string: "https://stream.example.com/\(id).m3u8"),
            coverURL: URL(string: "https://stream.example.com/logo/\(id).png"),
            categoryID: "news",
            type: .live,
            epgChannelID: "epg_\(id)"
        )
    }

    private func createSampleConfig() -> PlaylistConfig {
        PlaylistConfig(
            type: .m3u,
            m3uURL: URL(string: "https://example.com/playlist.m3u")
        )
    }

    // MARK: - Test 1: PreviewPlaybackStatus Default Init

    @Test
    func previewPlaybackStatus_defaults() {
        let status = PreviewPlaybackStatus()
        #expect(status.isPlaying == false)
        #expect(status.isMuted == true)
        #expect(status.currentChannelID == nil)
        #expect(status.currentTitle == nil)
        #expect(status.currentStreamURL == nil)
        #expect(status.hasError == false)
        #expect(status.errorMessage == nil)
    }

    // MARK: - Test 2: PreviewPlayerClient Play & Stop

    @Test
    func previewPlayerClient_playAndStop() async throws {
        let client = PreviewPlayerClient.testValue
        let channel = createSampleChannel(id: "ch_1", name: "TRT 1 HD")

        try await client.playPreview(channel)
        let playingStatus = client.getStatus()
        #expect(playingStatus.isPlaying == true)
        #expect(playingStatus.isMuted == true)
        #expect(playingStatus.currentChannelID == "ch_1")
        #expect(playingStatus.currentTitle == "TRT 1 HD")
        #expect(playingStatus.currentStreamURL == URL(string: "https://stream.example.com/ch_1.m3u8"))

        await client.stopPreview()
        let stoppedStatus = client.getStatus()
        #expect(stoppedStatus.isPlaying == false)
    }

    // MARK: - Test 3: PreviewPlayerClient Mute Toggling

    @Test
    func previewPlayerClient_muteToggling() async {
        let client = PreviewPlayerClient.testValue
        #expect(client.getStatus().isMuted == true)

        let unmuted = await client.toggleMute()
        #expect(unmuted == false)
        #expect(client.getStatus().isMuted == false)

        let reMuted = await client.toggleMute()
        #expect(reMuted == true)
        #expect(client.getStatus().isMuted == true)

        await client.setMuted(false)
        #expect(client.getStatus().isMuted == false)
    }

    // MARK: - Test 4: EPGTimelineFeature Focus Debounce Triggers Preview

    @Test
    func ePGTimelineFeature_focusDebounceTriggersPreview() async {
        let clock = TestClock()
        let channel = createSampleChannel(id: "ch_news", name: "CNN Turk")
        let config = createSampleConfig()

        let store = TestStore(
            initialState: EPGTimelineFeature.State(
                config: config,
                channels: [channel]
            )
        ) {
            EPGTimelineFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.previewPlayerClient = .testValue
        }

        // Focus channel
        await store.send(.channelFocused(channel)) {
            $0.focusedChannelID = "ch_news"
        }

        // Advance clock past 400ms debounce
        await clock.advance(by: .milliseconds(400))

        await store.receive(\.startPreviewDebounce) {
            $0.activePreviewChannel = channel
            $0.isPiPActive = true
            $0.isPreviewLoading = true
            $0.previewErrorMessage = nil
        }

        await store.receive(\.previewStarted) {
            $0.isPreviewLoading = false
            $0.previewErrorMessage = nil
        }
    }

    // MARK: - Test 5: Rapid Focus Changes Cancel In-Flight Debounce

    @Test
    func ePGTimelineFeature_rapidFocusChangeCancelsDebounce() async {
        let clock = TestClock()
        let ch1 = createSampleChannel(id: "ch_1", name: "Kanal 1")
        let ch2 = createSampleChannel(id: "ch_2", name: "Kanal 2")
        let ch3 = createSampleChannel(id: "ch_3", name: "Kanal 3")
        let config = createSampleConfig()

        let store = TestStore(
            initialState: EPGTimelineFeature.State(
                config: config,
                channels: [ch1, ch2, ch3]
            )
        ) {
            EPGTimelineFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.previewPlayerClient = .testValue
        }

        // Rapid zapping through channels
        await store.send(.channelFocused(ch1)) {
            $0.focusedChannelID = "ch_1"
        }
        await clock.advance(by: .milliseconds(100))

        await store.send(.channelFocused(ch2)) {
            $0.focusedChannelID = "ch_2"
        }
        await clock.advance(by: .milliseconds(150))

        // Settles on ch3
        await store.send(.channelFocused(ch3)) {
            $0.focusedChannelID = "ch_3"
        }
        await clock.advance(by: .milliseconds(400))

        // Only ch3 triggers preview, ch1 and ch2 were cancelled
        await store.receive(\.startPreviewDebounce) {
            $0.activePreviewChannel = ch3
            $0.isPiPActive = true
            $0.isPreviewLoading = true
            $0.previewErrorMessage = nil
        }

        await store.receive(\.previewStarted) {
            $0.isPreviewLoading = false
        }
    }

    // MARK: - Test 6: EPGTimelineFeature Toggle Preview Mute

    @Test
    func ePGTimelineFeature_togglePreviewMute() async {
        let store = TestStore(
            initialState: EPGTimelineFeature.State(
                config: createSampleConfig(),
                channels: []
            )
        ) {
            EPGTimelineFeature()
        } withDependencies: {
            $0.previewPlayerClient = .testValue
        }

        #expect(store.state.isPreviewMuted == true)

        await store.send(.togglePreviewMute) {
            $0.isPreviewMuted = false
        }

        await store.send(.togglePreviewMute) {
            $0.isPreviewMuted = true
        }

        await store.send(.setPreviewMuted(false)) {
            $0.isPreviewMuted = false
        }
    }

    // MARK: - Test 7: EPGTimelineFeature Expand Preview to Fullscreen

    @Test
    func ePGTimelineFeature_expandPreviewToFullscreen() async {
        let channel = createSampleChannel(id: "ch_sport", name: "BeIN Sports")
        var state = EPGTimelineFeature.State(
            config: createSampleConfig(),
            channels: [channel]
        )
        state.activePreviewChannel = channel
        state.isPiPActive = true

        let store = TestStore(
            initialState: state
        ) {
            EPGTimelineFeature()
        } withDependencies: {
            $0.previewPlayerClient = .testValue
        }

        await store.send(.expandPreviewToFullscreen) {
            $0.activePreviewChannel = nil
            $0.isPiPActive = false
        }

        await store.receive(\.delegate)
    }

    // MARK: - Test 8: EPGTimelineFeature Close PiP Preview

    @Test
    func ePGTimelineFeature_closePiPPreview() async {
        let channel = createSampleChannel(id: "ch_doc", name: "Discovery")
        var state = EPGTimelineFeature.State(
            config: createSampleConfig(),
            channels: [channel]
        )
        state.activePreviewChannel = channel
        state.isPiPActive = true
        state.isPreviewLoading = true

        let store = TestStore(
            initialState: state
        ) {
            EPGTimelineFeature()
        } withDependencies: {
            $0.previewPlayerClient = .testValue
        }

        await store.send(.closePiPPreview) {
            $0.activePreviewChannel = nil
            $0.isPiPActive = false
            $0.isPreviewLoading = false
        }
    }

    // MARK: - Test 9: EPGGuideFeature Focus Debounce & Stop Preview

    @Test
    func ePGGuideFeature_focusDebounceAndStop() async {
        let clock = TestClock()
        let channel = createSampleChannel(id: "ch_guide", name: "EuroNews")
        let config = createSampleConfig()

        let store = TestStore(
            initialState: EPGGuideFeature.State(
                config: config,
                channels: [channel],
                initialChannel: nil
            )
        ) {
            EPGGuideFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.previewPlayerClient = .testValue
            $0.iptvClient.fetchShortEPG = { _, _, _ in [] }
        }

        await store.send(.channelFocused(channel))

        await clock.advance(by: .milliseconds(400))

        await store.receive(\.startPreviewDebounce) {
            $0.activePreviewChannel = channel
            $0.isPreviewPlaying = true
        }

        await store.receive(\.previewPlaybackStarted)

        await store.send(.togglePreviewMute) {
            $0.isPreviewMuted = false
        }

        await store.send(.stopPreview) {
            $0.activePreviewChannel = nil
            $0.isPreviewPlaying = false
        }
    }
}
