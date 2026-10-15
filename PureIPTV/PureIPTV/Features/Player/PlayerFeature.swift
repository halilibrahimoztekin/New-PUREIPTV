import ComposableArchitecture
import CoreGraphics
import FactoryKit
import Foundation
import GroupActivities
import SwiftVLC
import XCoordinator

@Reducer
public struct PlayerFeature {
    public enum CancelID {
        public static let playerEvents = "PlayerFeature.playerEvents"
        public static let statsTimer = "PlayerFeature.statsTimer"
        public static let sleepTimer = "PlayerFeature.sleepTimer"
        public static let seriesPlaylist = "PlayerFeature.seriesPlaylist"
    }

    public struct PlayableItem: Equatable {
        public let id: String
        public let title: String
        public let seriesTitle: String?
        public let streamURL: URL
        public let coverURL: URL?
        public let seriesID: String?
        public let startPosition: Double? // 0.0 to 1.0
        public let initialDuration: Double?
        public let initialProgress: Double?
        public let isLive: Bool
        public let config: PlaylistConfig?
        public let epgChannelID: String?
        public let tvArchive: Int?

        public init(
            id: String,
            title: String,
            seriesTitle: String? = nil,
            streamURL: URL,
            coverURL: URL? = nil,
            seriesID: String? = nil,
            startPosition: Double? = nil,
            initialDuration: Double? = nil,
            initialProgress: Double? = nil,
            isLive: Bool = false,
            config: PlaylistConfig? = nil,
            epgChannelID: String? = nil,
            tvArchive: Int? = nil
        ) {
            self.id = id
            self.title = title
            self.seriesTitle = seriesTitle
            self.streamURL = streamURL
            self.coverURL = coverURL
            self.seriesID = seriesID
            self.startPosition = startPosition
            self.initialDuration = initialDuration
            self.initialProgress = initialProgress
            self.isLive = isLive
            self.config = config
            self.epgChannelID = epgChannelID
            self.tvArchive = tvArchive
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
        public var lastDragTranslation: CGSize = .zero
        public var lastDragScreenWidth: CGFloat = 1.0

        // EPG
        public var epgListings: [EPGProgram] = []
        public var isEPGVisible: Bool = false
        public var isEPGLoading: Bool = false

        // Tracks
        public var audioTracks: [Track] = []
        public var subtitleTracks: [Track] = []
        public var selectedAudioTrack: Track?
        public var selectedSubtitleTrack: Track?
        public var audioDelay: Int = 0
        public var subtitleDelay: Int = 0
        public var isShowingStats: Bool = false
        public var playerStats: String = ""
        public var isTracksMenuVisible: Bool = false

        // Gestures
        public var volume: Int32 = 100
        public var brightness: Double = 1.0
        public var gestureFeedback: String?

        /// PiP
        public var isPiPActive: Bool = false

        /// Auto-Reconnect
        public var retryCount: Int = 0

        /// Sleep Timer
        public var sleepTimerSeconds: Int?

        /// Track whether initial seek was applied
        public var hasAppliedInitialSeek: Bool = false

        public init(item: PlayableItem, playlist: [PlayableItem]? = nil) {
            self.item = item
            self.playlist = playlist
            if let startPos = item.startPosition, startPos > 0 {
                position = min(1.0, max(0.0, startPos))
            }
            if let dur = item.initialDuration, dur > 0 {
                totalTime = Duration.seconds(dur)
            }
            if let prog = item.initialProgress, prog > 0 {
                currentTime = Duration.seconds(prog)
            }
        }
    }

    public enum Action {
        case onAppear
        case onDisappear
        case play
        case pause
        case stop
        case retryPlayback
        case toggleControls
        case hideControls

        // Sync & Stats
        case setAudioDelay(Int)
        case setSubtitleDelay(Int)
        case toggleStats
        case updateStats(String)

        // Gestures & Adjustments
        case setVolume(Int32)
        case setBrightness(Double)
        case showGestureFeedback(String)
        case hideGestureFeedback
        case dragGestureChanged(translation: CGSize, screenWidth: CGFloat, screenHeight: CGFloat, startLocation: CGPoint)
        case dragGestureEnded

        // Sleep Timer
        case setSleepTimer(Int?)
        case sleepTimerTick
        case sleepTimerEnded

        // New actions for video features
        case jumpForward
        case jumpBackward
        case restartPlayback
        case seek(Double)
        case seekToTime(Duration)
        case toggleInfo
        case toggleEPG

        // Zapping Actions
        case toggleChannelList
        case selectChannel(PlayableItem)
        case nextChannel
        case previousChannel

        // EPG Actions
        case fetchEPG
        case fetchEPGResponse(Result<[EPGProgram], Error>)
        case playArchive(EPGProgram)
        case sharePlayTapped

        case fetchMediaInfo
        case mediaInfoResponse(MediaInfo?)

        // Track actions
        case toggleTracksMenu
        case fetchTracks
        case tracksResponse(audio: [Track], subtitle: [Track], selectedAudio: Track?, selectedSubtitle: Track?)
        case selectAudioTrack(Track?)
        case selectSubtitleTrack(Track?)

        // Series Playlist
        case loadSeriesPlaylist
        case seriesPlaylistResponse(Result<[PlayableItem], Error>)

        case playerEvent(PlayerEvent)
        case handlePlayerEvent(PlayerEvent)
        case closeTapped
        case delegate(Delegate)

        // PiP
        case pipStarted
        case pipStopped
        case pipRestoreUI

        public enum Delegate: Equatable {
            case didClose
        }
    }

    @Injected(\.playerClient) var playerClient
    @Injected(\.appCoordinator) var appCoordinator
    @Dependency(\.databaseClient) var databaseClient
    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        let playerClient = playerClient
        let appCoordinator = appCoordinator
        let databaseClient = databaseClient
        let settingsClient = settingsClient

        Reduce { state, action in
            Self.reduceHelper(state: &state, action: action, playerClient: playerClient, appCoordinator: appCoordinator, databaseClient: databaseClient, iptvClient: iptvClient, settingsClient: settingsClient)
        }
    }

    static func reduceHelper(state: inout State, action: Action, playerClient: PlayerClient, appCoordinator: AppCoordinator, databaseClient: DatabaseClient, iptvClient: IPTVClient, settingsClient: SettingsClient) -> Effect<Action> {
        switch action {
        case .onAppear:
            let url = state.item.streamURL
            let position = state.item.startPosition ?? 0.0
            let seriesID = state.item.seriesID
            let config = state.item.config
            let needsPlaylist = (seriesID != nil && config != nil && (state.playlist == nil || state.playlist?.isEmpty == true))

            return .run { send in
                if needsPlaylist {
                    await send(.loadSeriesPlaylist)
                }

                // Listen to events immediately without waiting so no lifecycle events are missed
                let eventsStream = await playerClient.events()
                let eventTask = Task {
                    for await event in eventsStream {
                        await send(.handlePlayerEvent(event))
                    }
                }

                try await playerClient.play(url)
                if settingsClient.startMuted() {
                    try? await playerClient.setVolume(0)
                }

                if position > 0 {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    try? await playerClient.seek(position)
                }

                _ = await eventTask.value
            } catch: { error, send in
                print("Player error: \(error)")
                await send(.handlePlayerEvent(.encounteredError))
            }
            .cancellable(id: CancelID.playerEvents)

        case .onDisappear:
            let currentSecs = Double(state.currentTime.components.seconds)
            let totalSecs = Double(state.totalTime.components.seconds)
            let item = state.item
            let isPiPActive = state.isPiPActive
            return .merge(
                .cancel(id: CancelID.playerEvents),
                .cancel(id: CancelID.seriesPlaylist),
                .run { _ in
                    if currentSecs > 10 {
                        let type = item.title.contains("S") && item.title.contains("E") ? "episode" : "vod"
                        let historyItem = WatchHistoryItem(
                            id: item.id,
                            type: type,
                            title: item.title,
                            coverURL: item.coverURL?.absoluteString,
                            streamURL: item.streamURL.absoluteString,
                            progress: currentSecs,
                            duration: totalSecs,
                            seriesID: item.seriesID
                        )
                        try? await databaseClient.saveWatchProgress(historyItem)
                    }

                    if !isPiPActive {
                        await playerClient.release()
                    }
                }
            )

        case let .setAudioDelay(delay):
            state.audioDelay = delay
            return .run { _ in
                await playerClient.setAudioDelay(delay)
            }

        case let .setSubtitleDelay(delay):
            state.subtitleDelay = delay
            return .run { _ in
                await playerClient.setSubtitleDelay(delay)
            }

        case .toggleStats:
            state.isShowingStats.toggle()
            if state.isShowingStats {
                return .run { send in
                    while !Task.isCancelled {
                        let stats = await playerClient.getStats()
                        await send(.updateStats(stats ?? ""))
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }.cancellable(id: CancelID.statsTimer, cancelInFlight: true)
            } else {
                return .cancel(id: CancelID.statsTimer)
            }

        case let .updateStats(stats):
            state.playerStats = stats
            return .none

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

        case .retryPlayback:
            if state.errorMessage == AppStrings.Errors.cannotPlayStream {
                state.retryCount = 0
            }
            state.errorMessage = nil
            let url = state.item.streamURL
            let position = state.position > 0 ? state.position : (state.item.startPosition ?? 0.0)
            return .run { send in
                try await playerClient.play(url)
                if position > 0 {
                    try await Task.sleep(nanoseconds: 500_000_000)
                    try await playerClient.seek(position)
                }
                for await event in await playerClient.events() {
                    await send(.handlePlayerEvent(event))
                }
            } catch: { error, send in
                print("Player retry error: \(error)")
                await send(.handlePlayerEvent(.encounteredError))
            }
            .cancellable(id: CancelID.playerEvents, cancelInFlight: true)

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

        case let .setSleepTimer(minutes):
            if let minutes {
                state.sleepTimerSeconds = minutes * 60
                state.gestureFeedback = AppStrings.Player.sleepTimerMinutes(minutes)
                return .run { send in
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    await send(.hideGestureFeedback)
                    while !Task.isCancelled {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        await send(.sleepTimerTick)
                    }
                }
                .cancellable(id: CancelID.sleepTimer, cancelInFlight: true)
            } else {
                state.sleepTimerSeconds = nil
                state.gestureFeedback = AppStrings.Player.sleepTimerDisabled
                return .merge(
                    .cancel(id: CancelID.sleepTimer),
                    .run { send in
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        await send(.hideGestureFeedback)
                    }
                )
            }

        case .sleepTimerTick:
            if let current = state.sleepTimerSeconds, current > 0 {
                state.sleepTimerSeconds = current - 1
                if current - 1 == 0 {
                    return .send(.sleepTimerEnded)
                }
            }
            return .none

        case .sleepTimerEnded:
            return .send(.closeTapped)

        case let .dragGestureChanged(translation, screenWidth, _, _):
            state.lastDragTranslation = translation
            state.lastDragScreenWidth = screenWidth
            if abs(translation.width) > abs(translation.height) {
                if state.item.isLive, state.totalTime.components.seconds == 0 {
                    if translation.width > 50 {
                        return .send(.showGestureFeedback(AppStrings.Player.previousChannel))
                    } else if translation.width < -50 {
                        return .send(.showGestureFeedback(AppStrings.Player.nextChannel))
                    }
                    return .none
                } else {
                    let percentage = translation.width / screenWidth
                    if state.totalTime.components.seconds == 0 {
                        let newPos = max(0.0, min(1.0, state.position + percentage))
                        return .send(.showGestureFeedback(String(format: "%.0f%%", newPos * 100)))
                    } else {
                        let secondsToSeek = percentage * Double(state.totalTime.components.seconds)
                        let newTime = max(0, min(Double(state.totalTime.components.seconds), Double(state.currentTime.components.seconds) + secondsToSeek))

                        let newMins = Int(newTime) / 60
                        let newSecs = Int(newTime) % 60
                        return .send(.showGestureFeedback(String(format: "%02d:%02d", newMins, newSecs)))
                    }
                }
            } else {
                return .none
            }

        case .dragGestureEnded:
            if state.item.isLive, state.totalTime.components.seconds == 0 {
                let feedback = state.gestureFeedback
                let nextChannelStr = AppStrings.Player.nextChannel
                let prevChannelStr = AppStrings.Player.previousChannel
                return .run { send in
                    await send(.hideGestureFeedback)
                    if feedback == nextChannelStr {
                        await send(.nextChannel)
                    } else if feedback == prevChannelStr {
                        await send(.previousChannel)
                    }
                }
            } else {
                guard state.gestureFeedback != nil else { return .none }
                let translation = state.lastDragTranslation
                let percentage = translation.width / state.lastDragScreenWidth

                return .run { [totalTime = state.totalTime, currentTime = state.currentTime, position = state.position] send in
                    await send(.hideGestureFeedback)

                    if totalTime.components.seconds == 0 {
                        let newPos = max(0.0, min(1.0, position + percentage))
                        await send(.seek(newPos))
                    } else {
                        let secondsToSeek = percentage * Double(totalTime.components.seconds)
                        let newTime = max(0, min(Double(totalTime.components.seconds), Double(currentTime.components.seconds) + secondsToSeek))
                        let newPos = newTime / Double(totalTime.components.seconds)
                        await send(.seek(newPos))
                    }
                }
            }

        case .jumpForward:
            let offset: Int64 = 10
            let currentSecs = Double(state.currentTime.components.seconds)
            let totalSecs = Double(state.totalTime.components.seconds)
            let targetSecs = currentSecs + Double(offset)
            if totalSecs > 0 {
                let clampedSecs = min(totalSecs, max(0, targetSecs))
                state.currentTime = Duration.seconds(clampedSecs)
                state.position = clampedSecs / totalSecs
            } else {
                state.currentTime = Duration.seconds(max(0, targetSecs))
            }
            return .run { _ in try await playerClient.jump(offset) }

        case .jumpBackward:
            let offset: Int64 = -10
            let currentSecs = Double(state.currentTime.components.seconds)
            let totalSecs = Double(state.totalTime.components.seconds)
            let targetSecs = currentSecs + Double(offset)
            if totalSecs > 0 {
                let clampedSecs = min(totalSecs, max(0, targetSecs))
                state.currentTime = Duration.seconds(clampedSecs)
                state.position = clampedSecs / totalSecs
            } else {
                state.currentTime = Duration.seconds(max(0, targetSecs))
            }
            return .run { _ in try await playerClient.jump(offset) }

        case .restartPlayback:
            state.currentTime = .zero
            state.position = 0.0
            return .run { send in
                await send(.seek(0.0))
                await send(.seekToTime(.zero))
                await send(.play)
            }

        case let .seek(position):
            let clamped = max(0.0, min(1.0, position))
            state.position = clamped
            if state.totalTime.components.seconds > 0 {
                state.currentTime = Duration.seconds(Double(state.totalTime.components.seconds) * clamped)
            }
            return .run { _ in try await playerClient.seek(clamped) }

        case let .seekToTime(time):
            state.currentTime = time
            if state.totalTime.components.seconds > 0 {
                state.position = min(1.0, max(0.0, Double(time.components.seconds) / Double(state.totalTime.components.seconds)))
            }
            return .run { _ in try await playerClient.seekToTime(time) }

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
            state.hasAppliedInitialSeek = false

            return .run { send in
                try await playerClient.stop()
                await send(.onAppear)
                await send(.fetchEPG)
            }

        case .nextChannel:
            guard let playlist = state.playlist, let currentIndex = playlist.firstIndex(where: { $0.id == state.item.id }) else { return .none }
            let nextIndex = (currentIndex + 1) % playlist.count
            return .send(.selectChannel(playlist[nextIndex]))

        case .previousChannel:
            guard let playlist = state.playlist, let currentIndex = playlist.firstIndex(where: { $0.id == state.item.id }) else { return .none }
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
                await send(.fetchEPGResponse(Result {
                    try await iptvClient.fetchShortEPG(config, epgID, 10)
                }))
            }

        case let .fetchEPGResponse(.success(listings)):
            state.isEPGLoading = false
            state.epgListings = listings
            return .none

        case let .fetchEPGResponse(.failure(error)):
            print("EPG Fetch error: \(error)")
            state.isEPGLoading = false
            return .none

        case .loadSeriesPlaylist:
            guard let seriesID = state.item.seriesID, let config = state.item.config else { return .none }
            let currentItem = state.item
            let seriesTitle = currentItem.seriesTitle ?? currentItem.title
            let coverURL = currentItem.coverURL

            return .run { send in
                await send(.seriesPlaylistResponse(Result {
                    let result = try await iptvClient.fetchSeriesInfo(config, seriesID)
                    let currentEp = result.episodes.first(where: { $0.id == currentItem.id })
                    let targetSeason = currentEp?.season

                    let episodesInSeason = targetSeason != nil
                        ? result.episodes.filter { $0.season == targetSeason }
                        : result.episodes

                    let sorted = episodesInSeason.sorted { $0.episodeNum < $1.episodeNum }

                    return sorted.map { ep in
                        PlayableItem(
                            id: ep.id,
                            title: "\(seriesTitle) - S\(String(format: "%02d", ep.season))E\(String(format: "%02d", ep.episodeNum))",
                            seriesTitle: seriesTitle,
                            streamURL: ep.streamURL,
                            coverURL: ep.coverURL ?? coverURL,
                            seriesID: seriesID,
                            isLive: false,
                            config: config
                        )
                    }
                }))
            }
            .cancellable(id: CancelID.seriesPlaylist, cancelInFlight: true)

        case let .seriesPlaylistResponse(.success(playlist)):
            if !playlist.isEmpty {
                state.playlist = playlist
            }
            return .none

        case .seriesPlaylistResponse(.failure):
            return .none

        case let .playArchive(program):
            guard state.item.tvArchive == 1 else { return .none }

            let startFormat = DateFormatter()
            startFormat.dateFormat = "yyyy-MM-dd:HH-mm"
            let startTimeString = startFormat.string(from: program.startTime)
            let durationMinutes = Int(program.endTime.timeIntervalSince(program.startTime) / 60)

            guard let streamURL = URL(string: state.item.streamURL.absoluteString),
                  var components = URLComponents(url: streamURL, resolvingAgainstBaseURL: true)
            else {
                return .none
            }

            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "timeshift", value: "\(durationMinutes)"))
            queryItems.append(URLQueryItem(name: "start", value: startTimeString))
            components.queryItems = queryItems

            if let catchupURL = components.url {
                state.playerState = .playing
                state.isEPGVisible = false
                return .run { _ in
                    try await playerClient.play(catchupURL)
                } catch: { error, _ in
                    print("Failed to play catchup: \(error)")
                }
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
            if state.isTracksMenuVisible, state.audioTracks.isEmpty, state.subtitleTracks.isEmpty {
                return .send(.fetchTracks)
            }
            return .none

        case .fetchTracks:
            return .run { send in
                var audio = await playerClient.getAudioTracks()
                var subtitle = await playerClient.getSubtitleTracks()

                // If tracks aren't ready immediately, give VLC a short delay to parse the streams
                if audio.isEmpty, subtitle.isEmpty {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    audio = await playerClient.getAudioTracks()
                    subtitle = await playerClient.getSubtitleTracks()
                }

                var selAudio = await playerClient.getSelectedAudioTrack()
                var selSubtitle = await playerClient.getSelectedSubtitleTrack()

                // 1. Auto-select user's saved preferred audio language if available
                if let preferredAudio = UserDefaults.standard.string(forKey: "com.pureiptv.preferredAudioLanguage"),
                   let matchedAudio = audio.first(where: { matchesLanguage(trackName: $0.name, preferredLanguage: preferredAudio) })
                {
                    await playerClient.setAudioTrack(matchedAudio)
                    selAudio = matchedAudio
                }

                // 2. Auto-select user's saved preferred subtitle language if available
                if let preferredSubtitle = UserDefaults.standard.string(forKey: "com.pureiptv.preferredSubtitleLanguage") {
                    if preferredSubtitle == "off" {
                        await playerClient.setSubtitleTrack(nil)
                        selSubtitle = nil
                    } else if let matchedSubtitle = subtitle.first(where: { matchesLanguage(trackName: $0.name, preferredLanguage: preferredSubtitle) }) {
                        await playerClient.setSubtitleTrack(matchedSubtitle)
                        selSubtitle = matchedSubtitle
                    }
                }

                await send(.tracksResponse(audio: audio, subtitle: subtitle, selectedAudio: selAudio, selectedSubtitle: selSubtitle))
            }

        case let .tracksResponse(audio, subtitle, selectedAudio, selectedSubtitle):
            state.audioTracks = audio
            state.subtitleTracks = subtitle
            state.selectedAudioTrack = selectedAudio
            state.selectedSubtitleTrack = selectedSubtitle
            return .none

        case let .selectAudioTrack(track):
            state.selectedAudioTrack = track
            state.isTracksMenuVisible = false
            let trackName = track?.name
            return .run { _ in
                if let trackName {
                    UserDefaults.standard.set(trackName, forKey: "com.pureiptv.preferredAudioLanguage")
                }
                await playerClient.setAudioTrack(track)
            }

        case let .selectSubtitleTrack(track):
            state.selectedSubtitleTrack = track
            state.isTracksMenuVisible = false
            let trackName = track?.name
            return .run { _ in
                if let trackName {
                    UserDefaults.standard.set(trackName, forKey: "com.pureiptv.preferredSubtitleLanguage")
                } else {
                    UserDefaults.standard.set("off", forKey: "com.pureiptv.preferredSubtitleLanguage")
                }
                await playerClient.setSubtitleTrack(track)
            }

        case let .handlePlayerEvent(event):
            // Handle different VLC events
            switch event {
            case let .stateChanged(newState):
                state.playerState = newState
                if newState == .playing {
                    state.retryCount = 0 // Reset on successful play
                    state.errorMessage = nil
                    var actions: [Effect<Action>] = []

                    // Apply initial progress / seek if not yet applied
                    if !state.hasAppliedInitialSeek {
                        state.hasAppliedInitialSeek = true
                        if let startPosition = state.item.startPosition, startPosition > 0.005 {
                            actions.append(.send(.seek(startPosition)))
                        } else if let progress = state.item.initialProgress, progress > 1 {
                            actions.append(.send(.seekToTime(Duration.seconds(progress))))
                        }
                    }

                    if state.mediaInfo == nil {
                        actions.append(.send(.fetchMediaInfo))
                    }
                    if state.audioTracks.isEmpty, state.subtitleTracks.isEmpty {
                        actions.append(.send(.fetchTracks))
                    }
                    if state.item.config != nil, state.item.epgChannelID != nil, state.epgListings.isEmpty {
                        actions.append(.send(.fetchEPG))
                    }
                    return .merge(actions)
                } else if newState == .stopped {
                    // Auto Play Next Episode
                    if settingsClient.autoPlayNextEpisode(), let playlist = state.playlist, let currentIdx = playlist.firstIndex(where: { $0.id == state.item.id }) {
                        let nextIdx = currentIdx + 1
                        if nextIdx < playlist.count {
                            // Only auto-play if it's a series episode
                            let currentItem = state.item
                            if currentItem.seriesID != nil || (currentItem.title.contains("S") && currentItem.title.contains("E")) {
                                return .send(.selectChannel(playlist[nextIdx]))
                            }
                        }
                    }
                }
            case .encounteredError:
                if state.retryCount < 3 {
                    state.retryCount += 1
                    state.errorMessage = AppStrings.Player.reconnecting(state.retryCount)
                    return .run { send in
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await send(.retryPlayback)
                    }
                } else {
                    state.errorMessage = AppStrings.Errors.cannotPlayStream
                }
            case let .timeChanged(time):
                state.currentTime = time
                if state.item.epgChannelID == nil, state.totalTime.components.seconds == 0, state.position > 0.001, time.components.seconds > 0 {
                    let totalSecs = Double(time.components.seconds) / state.position
                    state.totalTime = Duration.seconds(totalSecs)
                }
            case let .lengthChanged(length):
                state.totalTime = length
            case let .positionChanged(pos):
                state.position = pos
                if state.item.epgChannelID == nil, state.totalTime.components.seconds == 0, pos > 0.001, state.currentTime.components.seconds > 0 {
                    let totalSecs = Double(state.currentTime.components.seconds) / pos
                    state.totalTime = Duration.seconds(totalSecs)
                }
            default:
                break
            }
            return .none

        case .playerEvent:
            return .none

        case .closeTapped:
            let currentSecs = Double(state.currentTime.components.seconds)
            let totalSecs = Double(state.totalTime.components.seconds)
            let item = state.item
            return .merge(
                .cancel(id: CancelID.playerEvents),
                .run { send in
                    @Dependency(\.dismiss) var dismiss
                    // Save Watch History before stopping
                    if currentSecs > 10 { // Only save if watched for more than 10 seconds
                        let type = item.title.contains("S") && item.title.contains("E") ? "episode" : "vod" // Basic detection
                        let historyItem = WatchHistoryItem(
                            id: item.id,
                            type: type,
                            title: item.title,
                            coverURL: item.coverURL?.absoluteString,
                            streamURL: item.streamURL.absoluteString,
                            progress: currentSecs,
                            duration: totalSecs,
                            seriesID: item.seriesID
                        )
                        try? await databaseClient.saveWatchProgress(historyItem)
                    }

                    try? await playerClient.stop()
                    await send(.delegate(.didClose))
                    await MainActor.run {
                        appCoordinator.trigger(.dismissPlayer)
                    }
                    await dismiss()
                }
            )

        case .delegate:
            return .none

        case .sharePlayTapped:
            // TODO: Implement SharePlay
            return .none

        // ── PiP ─────────────────────────────────────────────────
        case .pipStarted:
            state.isPiPActive = true
            return .none

        case .pipStopped:
            state.isPiPActive = false
            return .none

        case .pipRestoreUI:
            // PiP floating window'dan "geri dön" tıklandı → full-screen'e dön
            state.isPiPActive = false
            return .none
        }
    }

    // MARK: - Language Matching Helper

    private nonisolated static func matchesLanguage(trackName: String, preferredLanguage: String) -> Bool {
        let t = trackName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let p = preferredLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if t == p {
            return true
        }
        if t.contains(p) || p.contains(t) {
            return true
        }

        let aliases: [Set<String>] = [
            ["tr", "tur", "turkish", "türkçe", "turkce"],
            ["en", "eng", "english", "ingilizce", "i̇ngilizce"],
            ["de", "ger", "deu", "german", "almanca", "deutsch"],
            ["fr", "fra", "fre", "french", "fransızca", "français", "francais"],
            ["es", "spa", "spanish", "ispanyolca", "español", "espanol"],
            ["it", "ita", "italian", "italyanca", "italiano"],
            ["ru", "rus", "russian", "rusça", "rusca"],
            ["ar", "ara", "arabic", "arapça", "arapca"],
            ["pt", "por", "portuguese", "portekizce", "portugues", "português"],
            ["nl", "nld", "dut", "dutch", "hollandaca", "nederlands"],
            ["ja", "jpn", "japanese", "japonca"],
            ["ko", "kor", "korean", "korece"],
            ["zh", "zho", "chi", "chinese", "çince", "cince"],
            ["az", "aze", "azerbaijani", "azerice", "azeri"],
            ["pl", "pol", "polish", "lehçe", "lehce"],
            ["uk", "ukr", "ukrainian", "ukraynaca"],
            ["hi", "hin", "hindi", "hintçe", "hintce"],
        ]

        for group in aliases {
            let matchesP = group.contains(where: { p.contains($0) || $0 == p })
            let matchesT = group.contains(where: { t.contains($0) || $0 == t })
            if matchesP, matchesT {
                return true
            }
        }

        return false
    }
}
