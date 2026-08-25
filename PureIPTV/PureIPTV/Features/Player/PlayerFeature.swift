import ComposableArchitecture
import Factory
import Foundation
import SwiftVLC
import XCoordinator

@Reducer
public struct PlayerFeature {
    public struct PlayableItem: Equatable {
        public let id: String
        public let title: String
        public let streamURL: URL

        public init(id: String, title: String, streamURL: URL) {
            self.id = id
            self.title = title
            self.streamURL = streamURL
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var item: PlayableItem
        public var playerState: PlayerState = .stopped
        public var isControlsVisible: Bool = true
        public var errorMessage: String?

        // New properties for video features
        public var currentTime: Duration = .zero
        public var totalTime: Duration = .zero
        public var position: Double = 0.0
        public var mediaInfo: MediaInfo?
        public var isInfoVisible: Bool = false

        // Tracks
        public var audioTracks: [Track] = []
        public var subtitleTracks: [Track] = []
        public var isTracksMenuVisible: Bool = false

        // Gestures
        public var volume: Int32 = 100
        public var brightness: Double = 1.0
        public var gestureFeedback: String?

        public init(item: PlayableItem) {
            self.item = item
        }
    }

    public enum Action {
        case onAppear
        case onDisappear
        case play
        case pause
        case stop
        case toggleControls
        case hideControls

        // Gestures & Adjustments
        case setVolume(Int32)
        case setBrightness(Double)
        case showGestureFeedback(String)
        case hideGestureFeedback

        // New actions for video features
        case jumpForward
        case jumpBackward
        case seek(Double)
        case toggleInfo
        case fetchMediaInfo
        case mediaInfoResponse(MediaInfo?)

        // Track actions
        case toggleTracksMenu
        case fetchTracks
        case tracksResponse(audio: [Track], subtitle: [Track])
        case selectAudioTrack(Track?)
        case selectSubtitleTrack(Track?)

        case playerEvent(PlayerEvent)
        case handlePlayerEvent(PlayerEvent)
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didClose
        }
    }

    @Injected(\.playerClient) var playerClient
    @Injected(\.appCoordinator) var appCoordinator

    public init() {}

    public var body: some Reducer<State, Action> {
        let playerClient = self.playerClient
        let appCoordinator = self.appCoordinator

        Reduce { state, action in
            switch action {
            case .onAppear:
                let url = state.item.streamURL
                return .run { send in
                    try await playerClient.play(url)
                    for await event in await playerClient.events() {
                        await send(.handlePlayerEvent(event))
                    }
                }
                .cancellable(id: "PlayerEventsCancelID")

            case .onDisappear:
                return .merge(
                    .cancel(id: "PlayerEventsCancelID"),
                    .run { _ in try? await playerClient.stop() }
                )

            case .play:
                return .run { _ in
                    try await playerClient.resume()
                }

            case .pause:
                return .run { _ in
                    try await playerClient.pause()
                }

            case .stop:
                return .run { _ in
                    try await playerClient.stop()
                }

            case .toggleControls:
                state.isControlsVisible.toggle()
                return .none

            case .hideControls:
                state.isControlsVisible = false
                state.isInfoVisible = false
                state.isTracksMenuVisible = false
                return .none

            case let .setVolume(volume):
                state.volume = volume
                return .run { _ in
                    try await playerClient.setVolume(volume)
                }

            case let .setBrightness(brightness):
                state.brightness = brightness
                return .none

            case let .showGestureFeedback(message):
                state.gestureFeedback = message
                return .none

            case .hideGestureFeedback:
                state.gestureFeedback = nil
                return .none

            case .jumpForward:
                return .run { _ in try await playerClient.jump(10) }

            case .jumpBackward:
                return .run { _ in try await playerClient.jump(-10) }

            case let .seek(position):
                return .run { _ in try await playerClient.seek(position) }

            case .toggleInfo:
                state.isInfoVisible.toggle()
                if state.isInfoVisible && state.mediaInfo == nil {
                    return .send(.fetchMediaInfo)
                }
                return .none

            case .fetchMediaInfo:
                return .run { send in
                    let info = await playerClient.getMediaInfo()
                    await send(.mediaInfoResponse(info))
                }

            case let .mediaInfoResponse(info):
                state.mediaInfo = info
                return .none

            case .toggleTracksMenu:
                state.isTracksMenuVisible.toggle()
                if state.isTracksMenuVisible && state.audioTracks.isEmpty && state.subtitleTracks.isEmpty {
                    return .send(.fetchTracks)
                }
                return .none

            case .fetchTracks:
                return .run { send in
                    let audio = await playerClient.getAudioTracks()
                    let subtitle = await playerClient.getSubtitleTracks()
                    await send(.tracksResponse(audio: audio, subtitle: subtitle))
                }

            case let .tracksResponse(audio, subtitle):
                state.audioTracks = audio
                state.subtitleTracks = subtitle
                return .none

            case let .selectAudioTrack(track):
                state.isTracksMenuVisible = false
                return .run { _ in
                    await playerClient.setAudioTrack(track)
                }

            case let .selectSubtitleTrack(track):
                state.isTracksMenuVisible = false
                return .run { _ in
                    await playerClient.setSubtitleTrack(track)
                }

            case let .handlePlayerEvent(event):
                // Handle different VLC events
                switch event {
                case let .stateChanged(newState):
                    state.playerState = newState
                    if newState == .playing && state.mediaInfo == nil {
                        return .merge(
                            .send(.fetchMediaInfo),
                            .send(.fetchTracks)
                        )
                    }
                case .encounteredError:
                    state.errorMessage = String(localized: "Yayın oynatılamıyor.")
                case let .timeChanged(time):
                    state.currentTime = time
                case let .lengthChanged(length):
                    state.totalTime = length
                case let .positionChanged(pos):
                    state.position = pos
                default:
                    break
                }
                return .none

            case .playerEvent:
                return .none

            case .closeTapped:
                return .merge(
                    .cancel(id: "PlayerEventsCancelID"),
                    .run { send in
                        try? await playerClient.stop()
                        await MainActor.run {
                            appCoordinator.trigger(.dismissPlayer)
                        }
                        await send(.delegate(.didClose))
                    }
                )

            case .delegate:
                return .none
            }
        }
    }
}
