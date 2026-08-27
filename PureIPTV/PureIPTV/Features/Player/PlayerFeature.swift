import ComposableArchitecture
import FactoryKit
import Foundation
import SwiftVLC
import XCoordinator

@Reducer
public struct PlayerFeature {
    public struct PlayableItem: Equatable {
        public let id: String
        public let title: String
        public let streamURL: URL
        public let coverURL: URL?
        public let seriesID: String?
        public let startPosition: Double? // 0.0 to 1.0
        public let config: PlaylistConfig?
        public let epgChannelID: String?

        public init(id: String, title: String, streamURL: URL, coverURL: URL? = nil, seriesID: String? = nil, startPosition: Double? = nil, config: PlaylistConfig? = nil, epgChannelID: String? = nil) {
            self.id = id
            self.title = title
            self.streamURL = streamURL
            self.coverURL = coverURL
            self.seriesID = seriesID
            self.startPosition = startPosition
            self.config = config
            self.epgChannelID = epgChannelID
        }

        public init(id: String, title: String, streamURL: URL, coverURL: URL? = nil, seriesID: String? = nil, startPosition: Double? = nil) {
            self.id = id
            self.title = title
            self.streamURL = streamURL
            self.coverURL = coverURL
            self.seriesID = seriesID
            self.startPosition = startPosition
            config = nil
            epgChannelID = nil
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var item: PlayableItem
        public var playlist: [PlayableItem]?
        public var isChannelListVisible: Bool = false

        public var playerState: PlayerState = .stopped
        public var isControlsVisible: Bool = true
        public var errorMessage: String?

        // New properties for video features
        public var currentTime: Duration = .zero
        public var totalTime: Duration = .zero
        public var position: Double = 0.0
        public var mediaInfo: MediaInfo?
        public var isInfoVisible: Bool = false

        // EPG
        public var epgListings: [EPGProgram] = []
        public var isEPGVisible: Bool = false
        public var isEPGLoading: Bool = false

        // Tracks
        public var audioTracks: [Track] = []
        public var subtitleTracks: [Track] = []
        public var isTracksMenuVisible: Bool = false

        // Gestures
        public var volume: Int32 = 100
        public var brightness: Double = 1.0
        public var gestureFeedback: String?

        public init(item: PlayableItem, playlist: [PlayableItem]? = nil) {
            self.item = item
            self.playlist = playlist
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
        case dragGestureChanged(translation: CGSize, screenWidth: CGFloat, screenHeight: CGFloat, startLocation: CGPoint)
        case dragGestureEnded

        // New actions for video features
        case jumpForward
        case jumpBackward
        case seek(Double)
        case toggleInfo
        case toggleEPG

        // Zapping Actions
        case toggleChannelList
        case selectChannel(PlayableItem)
        case nextChannel
        case previousChannel

        // EPG Actions
        case fetchEPG
        case epgResponse(Result<[EPGProgram], Error>)

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
    @Dependency(\.databaseClient) var databaseClient
    @Injected(\.iptvClient) var iptvClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let playerClient = self.playerClient
        let appCoordinator = self.appCoordinator

        Reduce { state, action in
            switch action {
            case .onAppear:
                let url = state.item.streamURL
                let position = state.item.startPosition ?? 0.0
                return .run { send in
                    try await playerClient.play(url)
                    if position > 0 {
                        try await Task.sleep(nanoseconds: 500_000_000)
                        try await playerClient.seek(position)
                    }
                    for await event in await playerClient.events() {
                        await send(.playerEvent(event))
                    }
                } catch: { error, _ in
                    print("Player error: \(error)")
                }

            case .onDisappear:
                return .merge(
                    .cancel(id: "PlayerEventsCancelID"),
                    .run { [state] send in
                        // Save Watch History
                        let progressSeconds = Double(state.currentTime.components.seconds)
                        let durationSeconds = Double(state.totalTime.components.seconds)

                        if progressSeconds > 10 { // Only save if watched for more than 10 seconds
                            let type = state.item.title.contains("S") && state.item.title.contains("E") ? "episode" : "vod" // Basic detection
                            let item = WatchHistoryItem(
                                id: state.item.id,
                                type: type,
                                title: state.item.title,
                                coverURL: state.item.coverURL?.absoluteString,
                                streamURL: state.item.streamURL.absoluteString,
                                progress: progressSeconds,
                                duration: durationSeconds,
                                seriesID: state.item.seriesID
                            )
                            try? await databaseClient.saveWatchProgress(item)
                        }

                        try? await playerClient.stop()
                        await send(.delegate(.didClose))
                    }
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
                state.isEPGVisible = false
                return .none

            case let .setVolume(volume):
                state.volume = volume
                return .run { _ in
                    try await playerClient.setVolume(volume)
                }

            case let .setBrightness(brightness):
                state.brightness = brightness
                return .none

            case let .showGestureFeedback(feedback):
                state.gestureFeedback = feedback
                return .none

            case .hideGestureFeedback:
                state.gestureFeedback = nil
                return .none

            case let .dragGestureChanged(translation, screenWidth, _, _):
                // Simple horizontal drag for seeking or zapping, vertical for volume/brightness
                if abs(translation.width) > abs(translation.height) {
                    if state.totalTime.components.seconds == 0 {
                        // Live TV: Zapping instead of seeking
                        if translation.width > 50 {
                            return .send(.showGestureFeedback("Önceki Kanal"))
                        } else if translation.width < -50 {
                            return .send(.showGestureFeedback("Sonraki Kanal"))
                        }
                        return .none
                    } else {
                        // Seeking
                        let percentage = translation.width / screenWidth
                        let secondsToSeek = percentage * Double(state.totalTime.components.seconds)
                        let newTime = max(0, min(Double(state.totalTime.components.seconds), Double(state.currentTime.components.seconds) + secondsToSeek))

                        let newMins = Int(newTime) / 60
                        let newSecs = Int(newTime) % 60
                        return .send(.showGestureFeedback(String(format: "%02d:%02d", newMins, newSecs)))
                    }
                } else {
                    // Vertical swipe (volume/brightness)
                    return .none
                }

            case .dragGestureEnded:
                if state.totalTime.components.seconds == 0 {
                    // Live TV Zapping
                    let feedback = state.gestureFeedback
                    return .run { send in
                        await send(.hideGestureFeedback)
                        if feedback == "Sonraki Kanal" {
                            await send(.nextChannel)
                        } else if feedback == "Önceki Kanal" {
                            await send(.previousChannel)
                        }
                    }
                } else {
                    return .send(.hideGestureFeedback)
                }

            case .jumpForward:
                return .run { _ in try await playerClient.jump(10) }

            case .jumpBackward:
                return .run { _ in try await playerClient.jump(-10) }

            case let .seek(position):
                return .run { _ in try await playerClient.seek(position) }

            case .toggleChannelList:
                state.isChannelListVisible.toggle()
                return .none

            case let .selectChannel(newItem):
                state.item = newItem
                state.isChannelListVisible = false
                state.epgListings = []
                state.mediaInfo = nil
                state.currentTime = .zero
                state.totalTime = .zero
                state.position = 0.0

                return .run { send in
                    try await playerClient.stop()
                    await send(.onAppear)
                    await send(.fetchEPG)
                }

            case .nextChannel:
                guard let playlist = state.playlist, let currentIndex = playlist.firstIndex(of: state.item) else { return .none }
                let nextIndex = (currentIndex + 1) % playlist.count
                return .send(.selectChannel(playlist[nextIndex]))

            case .previousChannel:
                guard let playlist = state.playlist, let currentIndex = playlist.firstIndex(of: state.item) else { return .none }
                let prevIndex = (currentIndex - 1 + playlist.count) % playlist.count
                return .send(.selectChannel(playlist[prevIndex]))

            case .toggleInfo:
                state.isInfoVisible.toggle()
                return .none

            case .toggleEPG:
                state.isEPGVisible.toggle()
                return .none

            case .fetchEPG:
                guard let config = state.item.config, let epgID = state.item.epgChannelID else { return .none }
                state.isEPGLoading = true
                return .run { send in
                    await send(.epgResponse(Result {
                        try await iptvClient.fetchShortEPG(config, epgID, 10) // limit to 10 for performance
                    }))
                }

            case let .epgResponse(.success(listings)):
                state.isEPGLoading = false
                state.epgListings = listings
                return .none

            case .epgResponse(.failure):
                state.isEPGLoading = false
                // Handle or ignore EPG fetch error quietly
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
                    if newState == .playing {
                        var actions: [Effect<Action>] = []
                        if state.mediaInfo == nil {
                            actions.append(.send(.fetchMediaInfo))
                        }
                        if state.audioTracks.isEmpty && state.subtitleTracks.isEmpty {
                            actions.append(.send(.fetchTracks))
                        }
                        if let config = state.item.config, state.item.epgChannelID != nil, state.epgListings.isEmpty {
                            actions.append(.send(.fetchEPG))
                        }
                        return .merge(actions)
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
