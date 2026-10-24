import ComposableArchitecture
import CoreGraphics
import FactoryKit
import Foundation
import GroupActivities
import SwiftUI
import SwiftVLC

@Reducer
public struct PlayerFeature {
    public enum CancelID {
        public static let playerEvents = "PlayerFeature.playerEvents"
        public static let statsTimer = "PlayerFeature.statsTimer"
        public static let sleepTimer = "PlayerFeature.sleepTimer"
        public static let seriesPlaylist = "PlayerFeature.seriesPlaylist"
        public static let oledDimTimer = "PlayerFeature.oledDimTimer"
        public static let audioRoute = "PlayerFeature.audioRoute"
        public static let audioRouteHUD = "PlayerFeature.audioRouteHUD"
        public static let trackHUD = "PlayerFeature.trackHUD"
        public static let upNextCountdown = "PlayerFeature.upNextCountdown"
        public static let aspectFeedback = "PlayerFeature.aspectFeedback"
        public static let channelOSD = "PlayerFeature.channelOSD"
        public static let lockPill = "PlayerFeature.lockPill"
        public static let stallWatchdog = "PlayerFeature.stallWatchdog"
        public static let reconnectTimer = "PlayerFeature.reconnectTimer"
        public static let recentChannelsHUD = "PlayerFeature.recentChannelsHUD"
        public static let recallHUD = "PlayerFeature.recallHUD"
        public static let dialerAutoSubmit = "PlayerFeature.dialerAutoSubmit"
        public static let traktScrobbleHUD = "PlayerFeature.traktScrobbleHUD"
        public static let dynamicRangeHUD = "PlayerFeature.dynamicRangeHUD"
        public static let afrToast = "PlayerFeature.afrToast"
        public static let epgBrowse = "PlayerFeature.epgBrowse"
        public static let channelSwitch = "PlayerFeature.channelSwitch"
        public static let scrubThumbnail = "PlayerFeature.scrubThumbnail"
    }

    public struct PlayableItem: Equatable, Sendable {
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
        public let categoryID: String?
        public let userAgentOverride: String?

        public nonisolated init(
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
            tvArchive: Int? = nil,
            categoryID: String? = nil,
            userAgentOverride: String? = nil
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
            self.categoryID = categoryID
            self.userAgentOverride = userAgentOverride ?? config?.userAgentOverride
        }

        public func replacingUserAgentOverride(_ value: String?) -> Self {
            Self(
                id: id,
                title: title,
                seriesTitle: seriesTitle,
                streamURL: streamURL,
                coverURL: coverURL,
                seriesID: seriesID,
                startPosition: startPosition,
                initialDuration: initialDuration,
                initialProgress: initialProgress,
                isLive: isLive,
                config: config?.replacingUserAgentOverride(value),
                epgChannelID: epgChannelID,
                tvArchive: tvArchive,
                categoryID: categoryID,
                userAgentOverride: value
            )
        }

        public func replacingPlaylistConfig(_ value: PlaylistConfig) -> Self {
            guard config?.playlistID == value.playlistID else { return self }
            return Self(
                id: id,
                title: title,
                seriesTitle: seriesTitle,
                streamURL: streamURL,
                coverURL: coverURL,
                seriesID: seriesID,
                startPosition: startPosition,
                initialDuration: initialDuration,
                initialProgress: initialProgress,
                isLive: isLive,
                config: value,
                epgChannelID: epgChannelID,
                tvArchive: tvArchive,
                categoryID: categoryID,
                userAgentOverride: value.userAgentOverride
            )
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var item: PlayableItem
        public var playlist: [PlayableItem]?
        public var liveChannels: [PlayableItem] = []
        public var isChannelListVisible: Bool = false
        public var isMinimized: Bool = false

        public var playerState: PlayerState = .stopped
        public var isControlsVisible: Bool = true
        public var errorMessage: String?

        // New properties for video features
        public var currentTime: Duration = .zero
        public var totalTime: Duration = .zero
        public var position: Double = 0.0
        public var scrubThumbnailData: Data?
        public var scrubThumbnailRequestID: UUID?
        public var mediaInfo: MediaInfo?
        public var isInfoVisible: Bool = false
        public var lastDragTranslation: CGSize = .zero
        public var lastDragScreenWidth: CGFloat = 1.0

        // EPG
        public var epgListings: [EPGProgram] = []
        public var isEPGVisible: Bool = false
        public var isEPGLoading: Bool = false
        public var epgBrowseChannel: PlayableItem?
        public var epgBrowseListings: [EPGProgram] = []
        public var isEPGBrowseLoading = false

        // Tracks
        public var audioTracks: [Track] = []
        public var subtitleTracks: [Track] = []
        public var selectedAudioTrack: Track?
        public var selectedSubtitleTrack: Track?
        public var audioDelay: Int = 0
        public var subtitleDelay: Int = 0
        public var isShowingStats: Bool = false
        public var playerStats: String = ""
        public var streamHealthMetrics: StreamHealthMetrics?
        public var isStreamHealthHUDVisible: Bool = false
        public var activeCatchupProgram: EPGProgram?
        public var isPlayingCatchup: Bool {
            activeCatchupProgram != nil
        }

        public var isCatchupTimelineVisible: Bool = false
        public var catchupTimeShiftHours: Int = 0
        public var isTracksMenuVisible: Bool = false

        // Gestures
        public var volume: Int32 = 100
        public var brightness: Double = 1.0
        public var gestureFeedback: String?

        /// PiP & Background Playback Engine (Madde #18)
        public var isPiPActive: Bool = false
        public var isPiPSupported: Bool = true
        public var isAutoPiPEnabled: Bool = true
        public var backgroundPlaybackMode: BackgroundPlaybackMode = .pip
        public var isBackgroundAudioActive: Bool = false
        public var shouldTriggerPiP: Bool = false

        /// Playback Rate (Madde #43)
        public var playbackRate: Float = 1.0

        /// Auto-Reconnect & Failover Engine
        public var retryCount: Int = 0
        public var maxReconnectAttempts: Int = 5
        public var isReconnecting: Bool = false
        public var isFallbackSwitching: Bool = false
        public var fallbackStreamName: String?
        public var isUserPaused: Bool = false
        public var failedStreamIDs: Set<String> = []

        /// Sleep Timer
        public var sleepTimerSeconds: Int?
        public var sleepTimerInitialVolume: Int32 = 100
        public var isSleepFadingActive: Bool = false

        /// Track whether initial seek was applied
        public var hasAppliedInitialSeek: Bool = false

        /// OLED & Dark Room Dimming
        public var isOLEDDimmingEnabled: Bool = true
        public var oledDimLevel: Double = 0.0
        public var isDeepDimmed: Bool = false
        public var oledInactivitySeconds: Int = 0

        /// Smart Channel Name Cleaner (Madde #16)
        public var isChannelNameCleaningEnabled: Bool = true

        /// Trakt.tv Watchlist & Scrobble Sync Engine (Madde #17)
        public var isTraktScrobbleStarted: Bool = false
        public var lastTraktScrobbleProgress: Double = 0.0
        public var isTraktScrobbleHUDVisible: Bool = false
        public var traktScrobbleHUDMessage: String = ""
        public var traktScrobbleHUDPercent: Double?

        /// Zapping & Last Channel Recall
        public var previousChannel: PlayableItem?
        public var zappingHistory: [PlayableItem] = []
        public var isRecallHUDVisible: Bool = false
        public var recalledChannelItem: PlayableItem?

        /// Direct Channel Number Dialing HUD (Madde #11)
        public var dialedChannelNumber: String = ""
        public var isChannelDialerVisible: Bool = false

        public var matchedDialedChannels: [(index: Int, item: PlayableItem)] {
            guard let playlist, !playlist.isEmpty, !dialedChannelNumber.isEmpty else { return [] }
            guard let targetIndex = Int(dialedChannelNumber) else { return [] }

            var results: [(index: Int, item: PlayableItem)] = []
            if targetIndex >= 1, targetIndex <= playlist.count {
                results.append((index: targetIndex, item: playlist[targetIndex - 1]))
            }
            for (idx, ch) in playlist.enumerated() {
                let chNum = idx + 1
                if chNum != targetIndex, "\(chNum)".hasPrefix(dialedChannelNumber) {
                    results.append((index: chNum, item: ch))
                    if results.count >= 6 {
                        break
                    }
                }
            }
            return results
        }

        /// Quick Recent Channels Carousel HUD (Quick-Zap Dock)
        public var isRecentChannelsHUDVisible: Bool = false
        public var recentChannels: [PlayableItem] = []
        public var pinnedRecentChannelIDs: [String] = []
        public var pinnableRecentChannelIDs: Set<String> = []
        public var recentChannelsRequestID: UUID?
        public var recentChannelPinRequestID: UUID?

        /// Smart Channel Sorting & Watch Counts (Madde #12)
        public var channelSortOption: ChannelSortOption = .defaultOrder
        public var channelWatchCounts: [String: Int] = [:]

        /// Lip-Sync & Subtitle Sync HUD
        public var isAudioSyncHUDVisible: Bool = false
        public var rememberDelayForChannel: Bool = true

        /// Aspect Ratio & Zoom (Madde #14)
        public var videoAspectRatioMode: VideoAspectRatioMode = .fit
        public var videoZoomScale: CGFloat = 1.0
        public var isAspectFeedbackVisible: Bool = false

        /// Channel Zapping & Haptic Feedback (Madde #16)
        public var zappingHUDItem: PlayableItem?
        public var zappingHUDDirection: ZappingDirection?
        public var isZappingHUDVisible: Bool = false

        /// Screen Lock (Madde #19)
        public var isScreenLocked: Bool = false
        public var isLockPillVisible: Bool = false

        /// Audio Routing (Madde #20)
        public var currentAudioRoute: AudioRouteInfo = .defaultSpeaker
        public var isAudioRouteHUDVisible: Bool = false

        /// Audio Equalizer & Dialogue Enhancer (Madde #14)
        public var audioEQPreset: AudioEQPreset = .flat
        public var isAudioEQHUDVisible: Bool = false

        /// Audio / Subtitle Track & Sync HUD (Madde #34)
        public var trackHUDMessage: String?
        public var trackHUDIcon: String?
        public var isTrackHUDVisible: Bool = false

        /// Channel Hide & Category Blacklist (Madde #19)
        public var hiddenChannelIDs: Set<String> = []
        public var blacklistedCategoryIDs: Set<String> = []

        /// HDR, Dolby Vision & SDR Dynamic Range Indicator (Madde #20)
        public var videoDynamicRange: VideoDynamicRange?
        public var dynamicRangeInfo: DynamicRangeInfo?
        public var isDynamicRangeHUDVisible: Bool = false

        /// Auto Frame Rate & Match Dynamic Range (Madde #21)
        public var isAFREnabledForLive: Bool = true
        public var isAFREnabledForVOD: Bool = true
        public var isAFREnabledForCurrentItem: Bool {
            item.isLive ? isAFREnabledForLive : isAFREnabledForVOD
        }

        public var isMatchDynamicRangeEnabled: Bool = true
        public var currentFrameRate: FrameRate?
        public var afrMatchResult: DisplayMatchResult?
        public var isAFRToastVisible: Bool = false

        /// Up Next Episode Auto-Play (Madde #48)
        public var isUpNextVisible: Bool = false
        public var upNextCountdownSeconds: Int = 15
        public var upNextInitialSeconds: Int = 15
        public var isUpNextDismissed: Bool = false
        public var isTransitioningEpisode: Bool = false

        public var nextEpisodeItem: PlayableItem? {
            guard !item.isLive, let playlist, let idx = currentChannelIndex, idx + 1 < playlist.count else {
                return nil
            }
            return playlist[idx + 1]
        }

        public var currentChannelIndex: Int? {
            guard let playlist else { return nil }
            return playlist.firstIndex(where: { $0.id == item.id })
        }

        public var nextChannelItem: PlayableItem? {
            guard let playlist, let idx = currentChannelIndex, !playlist.isEmpty else { return nil }
            let nextIndex = (idx + 1) % playlist.count
            return playlist[nextIndex]
        }

        public var previousChannelItem: PlayableItem? {
            guard let playlist, let idx = currentChannelIndex, !playlist.isEmpty else { return nil }
            let prevIndex = (idx - 1 + playlist.count) % playlist.count
            return playlist[prevIndex]
        }

        public var backupStreamItem: PlayableItem? {
            guard let playlist, !playlist.isEmpty else { return nil }
            return playlist.first(where: {
                $0.id != item.id &&
                    !failedStreamIDs.contains($0.id) &&
                    PlayerFeature.areChannelsRelated($0.title, item.title)
            })
        }

        /// Channel OSD Info Card (Madde #95)
        public var isChannelOSDVisible: Bool = false

        public var currentEPGProgram: EPGProgram? {
            let now = Date()
            return epgListings.first(where: { $0.startTime <= now && now <= $0.endTime })
                ?? epgListings.first
        }

        public var nextEPGProgram: EPGProgram? {
            guard let current = currentEPGProgram,
                  let idx = epgListings.firstIndex(where: { $0.id == current.id }),
                  idx + 1 < epgListings.count
            else {
                return nil
            }
            return epgListings[idx + 1]
        }

        public init(item: PlayableItem, playlist: [PlayableItem]? = nil) {
            self.item = item
            self.playlist = playlist
            liveChannels = playlist?.filter(\.isLive) ?? []
            let drInfo = ColorSpaceDetector.detectFromText(title: item.title, urlString: item.streamURL.absoluteString)
            dynamicRangeInfo = drInfo
            videoDynamicRange = drInfo.range
            isDynamicRangeHUDVisible = drInfo.range.isHDR
            let detectedFPS = FrameRateDetector.detect(title: item.title, urlString: item.streamURL.absoluteString, isLive: item.isLive)
            currentFrameRate = detectedFPS
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
        case startSelectedChannel(id: String)
        case onDisappear
        case play
        case pause
        case stop
        case retryPlayback
        case streamStalled
        case initiateAutoReconnect
        case autoReconnectPulse
        case switchToBackupStream
        case toggleControls
        case hideControls
        case toggleScreenLock
        case setScreenLocked(Bool)
        case showLockPill
        case hideLockPill

        // Audio Route Actions (Madde #20)
        case audioRouteUpdated(AudioRouteInfo)
        case showAudioRouteHUD(AudioRouteInfo)
        case hideAudioRouteHUD

        // Track & Sync HUD Actions (Madde #34)
        case showTrackHUD(message: String, icon: String)
        case hideTrackHUD

        // Sync & Stats
        case setAudioDelay(Int)
        case setSubtitleDelay(Int)
        case toggleAudioSyncHUD
        case setAudioSyncHUDVisible(Bool)
        case setRememberDelayForChannel(Bool)
        case toggleStats
        case updateStats(String)
        case toggleStreamHealthHUD
        case setStreamHealthHUDVisible(Bool)
        case updateStreamHealth(StreamHealthMetrics)
        case toggleCatchupTimeline
        case setCatchupTimelineVisible(Bool)
        case setCatchupTimeShiftHours(Int)
        case returnToLiveStream

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

        // OLED & Dark Room Dimming
        case userInteracted
        case startOLEDDimTimer
        case oledDimTimerTick
        case setOLEDDimLevel(Double)
        case toggleOLEDDimming(Bool)

        // New actions for video features
        case jumpForward
        case jumpBackward
        case jumpBySeconds(Int64)
        case restartPlayback
        case seek(Double)
        case seekToTime(Duration)
        case requestScrubThumbnail(Duration)
        case scrubThumbnailLoaded(requestID: UUID, itemID: String, data: Data?)
        case cancelScrubThumbnail
        case setPlaybackRate(Float)
        case toggleInfo
        case toggleEPG
        case selectEPGBrowseChannel(PlayableItem)
        case epgBrowseResponse(channelID: String, Result<[EPGProgram], Error>)
        case watchEPGBrowseChannel

        // Aspect Ratio & Zoom Actions (Madde #14)
        case setVideoAspectRatioMode(VideoAspectRatioMode)
        case setVideoZoomScale(CGFloat)
        case toggleAspectRatioMode
        case hideAspectFeedback

        // Zapping Actions
        case toggleChannelList
        case setChannelListVisible(Bool)
        case toggleChannelNameCleaning
        case setChannelNameCleaningEnabled(Bool)
        case selectChannel(PlayableItem)
        case nextChannel
        case previousChannel
        case recallLastChannel
        case setRecallHUDVisible(Bool)
        case hideRecallHUD
        case showZappingHUD(item: PlayableItem, direction: ZappingDirection)
        case hideZappingHUD
        case showChannelOSD
        case hideChannelOSD

        // Direct Channel Number Dialing Actions (Madde #11)
        case openChannelDialer
        case setChannelDialerVisible(Bool)
        case appendDialedDigit(String)
        case deleteDialedDigit
        case clearDialedDigits
        case submitDialedChannel

        // Smart Channel Sorting Actions (Madde #12)
        case setChannelSortOption(ChannelSortOption)
        case loadChannelSortPreferences
        case channelSortPreferencesLoaded(sortOption: ChannelSortOption, watchCounts: [String: Int])

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

        // Audio Equalizer & Dialogue Enhancer Actions (Madde #14)
        case toggleAudioEQHUD
        case setAudioEQHUDVisible(Bool)
        case selectAudioEQPreset(AudioEQPreset)
        case loadAudioEQPreferences

        // Series Playlist
        case loadSeriesPlaylist
        case seriesPlaylistResponse(Result<[PlayableItem], Error>)

        case playerEvent(PlayerEvent)
        case handlePlayerEvent(PlayerEvent)
        case closeTapped
        case delegate(Delegate)

        // PiP & Background Playback Engine (Madde #18)
        case togglePiP
        case onPiPStatusChanged(isActive: Bool)
        case setAutoPiPEnabled(Bool)
        case setBackgroundPlaybackMode(BackgroundPlaybackMode)
        case appMovedToBackground
        case appMovedToForeground
        case resetPiPTrigger
        case pipStarted
        case pipStopped
        case pipRestoreUI
        case minimizeTapped

        // Up Next Episode Auto-Play (Madde #48)
        case showUpNext
        case dismissUpNext
        case playNextEpisode
        case upNextCountdownTick

        /// External Player (Madde #86)
        case openInExternalPlayer(ExternalPlayer)

        // Category Jump (Madde #97)
        case jumpToNextCategory
        case jumpToPreviousCategory

        // Quick Recent Channels Carousel HUD (Quick-Zap Dock)
        case toggleRecentChannelsHUD
        case setRecentChannelsHUDVisible(Bool)
        case selectRecentChannel(PlayableItem)
        case togglePinnedRecentChannel(String)
        case recentChannelPinMutationCompleted(
            requestID: UUID,
            playlistID: UUID,
            profileScope: ProfileContextSnapshot
        )
        case loadRecentChannels
        case recentChannelsLoaded(
            items: [PlayableItem],
            pinnedIDs: [String],
            pinnableIDs: Set<String>,
            requestID: UUID,
            playlistID: UUID?,
            profileScope: ProfileContextSnapshot
        )

        // Trakt.tv Scrobbler (Madde #17)
        case traktScrobbleStart
        case traktScrobblePause
        case traktScrobbleStop
        case showTraktScrobbleHUD(message: String, progress: Double?)
        case dismissTraktScrobbleHUD

        // Channel Hide & Category Blacklist (Madde #19)
        case loadHiddenContentPreferences
        case hideChannel(id: String, title: String)
        case unhideChannel(id: String)
        case hideCurrentChannel

        // HDR & Dolby Vision Dynamic Range Indicator (Madde #20)
        case detectDynamicRange
        case dynamicRangeDetected(DynamicRangeInfo)
        case showDynamicRangeHUD
        case hideDynamicRangeHUD

        // Auto Frame Rate & Match Dynamic Range (Madde #21)
        case loadAFRPreferences
        case setAFREnabledForLive(Bool)
        case setAFREnabledForVOD(Bool)
        case setMatchDynamicRangeEnabled(Bool)
        case matchDisplayMode
        case displayModeSwitched(DisplayMatchResult)
        case showAFRToast(DisplayMatchResult)
        case hideAFRToast

        public enum Delegate: Equatable {
            case didClose
            case didRequestMinimize
        }
    }

    @Injected(\.playerClient) var playerClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.recentChannelsClient) var recentChannelsClient
    @Dependency(\.streamHealthClient) var streamHealthClient
    @Dependency(\.traktClient) var traktClient
    @Dependency(\.pipClient) var pipClient
    @Dependency(\.parentalControlClient) var parentalControlClient
    @Dependency(\.displayModeClient) var displayModeClient
    @Dependency(\.customEPGMappingClient) var customEPGMappingClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let playerClient = playerClient
        let databaseClient = databaseClient
        let profileContextClient = profileContextClient
        let settingsClient = settingsClient
        let recentChannelsClient = recentChannelsClient
        let streamHealthClient = streamHealthClient
        let traktClient = traktClient
        let pipClient = pipClient
        let parentalControlClient = parentalControlClient
        let displayModeClient = displayModeClient
        let customEPGMappingClient = customEPGMappingClient

        Reduce { state, action in
            Self.reduceHelper(state: &state, action: action, playerClient: playerClient, databaseClient: databaseClient, iptvClient: iptvClient, settingsClient: settingsClient, recentChannelsClient: recentChannelsClient, streamHealthClient: streamHealthClient, traktClient: traktClient, pipClient: pipClient, parentalControlClient: parentalControlClient, displayModeClient: displayModeClient, customEPGMappingClient: customEPGMappingClient, profileContextClient: profileContextClient)
        }
    }

    static func reduceHelper(state: inout State, action: Action, playerClient: PlayerClient, databaseClient: DatabaseClient, iptvClient: IPTVClient, settingsClient: SettingsClient, recentChannelsClient: RecentChannelsClient, streamHealthClient: StreamHealthClient, traktClient: TraktClient, pipClient: PiPClient, parentalControlClient: ParentalControlClient, displayModeClient: DisplayModeClient, customEPGMappingClient: CustomEPGMappingClient, profileContextClient: ProfileContextClient) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.isMinimized = false
            state.isUserPaused = false
            state.isOLEDDimmingEnabled = settingsClient.isOLEDDimmingEnabled()
            state.isChannelNameCleaningEnabled = settingsClient.isChannelNameCleaningEnabled()
            state.isPiPSupported = pipClient.isPiPSupported()
            state.isAutoPiPEnabled = pipClient.isAutoPiPEnabled()
            state.backgroundPlaybackMode = pipClient.backgroundPlaybackMode()
            state.hiddenChannelIDs = parentalControlClient.hiddenChannelIDs()
            state.blacklistedCategoryIDs = parentalControlClient.blacklistedCategoryIDs()
            state.isAFREnabledForLive = displayModeClient.isAFREnabledForLive()
            state.isAFREnabledForVOD = displayModeClient.isAFREnabledForVOD()
            state.isMatchDynamicRangeEnabled = displayModeClient.isMatchDynamicRangeEnabled()

            // Restore per-channel lip-sync and subtitle preferences
            if let savedAudio = settingsClient.getChannelAudioDelay(state.item.id) {
                state.audioDelay = savedAudio
            }
            if let savedSub = settingsClient.getChannelSubtitleDelay(state.item.id) {
                state.subtitleDelay = savedSub
            }

            let url = state.item.streamURL
            let isLive = state.item.isLive
            let position = state.item.startPosition ?? 0.0
            let seriesID = state.item.seriesID
            let config = state.item.config
            let userAgentOverride = state.item.userAgentOverride
            let networkCachingMilliseconds = BufferProfile.activeNetworkCachingMilliseconds(for: isLive)
            let needsPlaylist = (seriesID != nil && config != nil && (state.playlist == nil || state.playlist?.isEmpty == true))
            let isAlreadyPlaying = state.playerState == .playing || state.playerState == .buffering

            let recentEffect: Effect<Action> = isLive ? .run { [item = state.item] send in
                await send(.loadRecentChannels)
                let recentDTO = RecentChannelDTO(
                    id: item.id,
                    title: item.title,
                    seriesTitle: item.seriesTitle,
                    streamURL: item.streamURL,
                    coverURL: item.coverURL,
                    epgChannelID: item.epgChannelID,
                    categoryID: item.categoryID,
                    tvArchive: item.tvArchive
                )
                await recentChannelsClient.recordChannel(recentDTO)
            } : .none

            return .merge(
                .run { _ in
                    try? await pipClient.configureAudioSession(true)
                },
                state.item.isLive ? .send(.showChannelOSD) : .none,
                state.videoDynamicRange?.isHDR == true ? .run { send in
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    await send(.hideDynamicRangeHUD)
                }.cancellable(id: CancelID.dynamicRangeHUD, cancelInFlight: true) : .none,
                state.isAFREnabledForCurrentItem ? .send(.matchDisplayMode) : .none,
                .send(.loadChannelSortPreferences),
                .send(.loadAudioEQPreferences),
                recentEffect,
                .send(.startOLEDDimTimer),
                .run { _ in
                    #if os(iOS)
                        await MainActor.run {
                            OrientationManager.shared.lockLandscape()
                        }
                    #endif
                },
                .run { send in
                    for await route in await AudioRouteManager.shared.routeStream() {
                        await send(.audioRouteUpdated(route))
                    }
                }
                .cancellable(id: CancelID.audioRoute),
                .run { send in
                    if needsPlaylist {
                        await send(.loadSeriesPlaylist)
                    }

                    // Structured concurrency: event stream and playback run inside a task group
                    // so cooperative cancellation immediately cancels the event stream listener!
                    let isPreviewPromotion = await playerClient.consumePreviewPromotion(url)
                    let eventsStream = await playerClient.events()
                    if isPreviewPromotion {
                        // The preview may have reached `.playing` before this
                        // feature subscribed. Reconcile its current state once,
                        // then keep listening for subsequent transport changes.
                        await send(.handlePlayerEvent(.stateChanged(.playing)))
                    }
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            for await event in eventsStream {
                                await send(.handlePlayerEvent(event))
                            }
                        }

                        group.addTask {
                            if !isAlreadyPlaying, !isPreviewPromotion {
                                do {
                                    try await playerClient.play(url, userAgentOverride, networkCachingMilliseconds)
                                    if settingsClient.startMuted() {
                                        try? await playerClient.setVolume(0)
                                    }

                                    if !isLive, position > 0 {
                                        try? await Task.sleep(nanoseconds: 600_000_000)
                                        try? await playerClient.seek(position)
                                    }
                                } catch {
                                    print("Player error: \(error)")
                                    await send(.handlePlayerEvent(.encounteredError))
                                }
                            }
                        }
                    }
                }
                .cancellable(id: CancelID.playerEvents, cancelInFlight: true)
            )

        case let .startSelectedChannel(id):
            guard state.item.id == id else { return .none }
            let appearanceEffect = Self.reduceHelper(
                state: &state,
                action: .onAppear,
                playerClient: playerClient,
                databaseClient: databaseClient,
                iptvClient: iptvClient,
                settingsClient: settingsClient,
                recentChannelsClient: recentChannelsClient,
                streamHealthClient: streamHealthClient,
                traktClient: traktClient,
                pipClient: pipClient,
                parentalControlClient: parentalControlClient,
                displayModeClient: displayModeClient,
                customEPGMappingClient: customEPGMappingClient,
                profileContextClient: profileContextClient
            )
            return .merge(appearanceEffect, .send(.fetchEPG))

        case .onDisappear:
            let currentSecs = Double(state.currentTime.components.seconds)
            let totalSecs = Double(state.totalTime.components.seconds)
            let item = state.item
            let profileScope = profileContextClient.snapshot()
            let isPiPActive = state.isPiPActive
            let isMinimized = state.isMinimized
            state.scrubThumbnailRequestID = nil
            state.scrubThumbnailData = nil

            // If transitioning to In-App MiniPlayer or PiP is active, keep player alive and active!
            if isMinimized || isPiPActive {
                return .cancel(id: CancelID.scrubThumbnail)
            }

            return .merge(
                .cancel(id: CancelID.channelSwitch),
                .cancel(id: CancelID.scrubThumbnail),
                .cancel(id: CancelID.playerEvents),
                .cancel(id: CancelID.seriesPlaylist),
                .cancel(id: CancelID.oledDimTimer),
                .cancel(id: CancelID.audioRoute),
                .cancel(id: CancelID.audioRouteHUD),
                .cancel(id: CancelID.upNextCountdown),
                .cancel(id: CancelID.statsTimer),
                .cancel(id: CancelID.stallWatchdog),
                .cancel(id: CancelID.reconnectTimer),
                .cancel(id: CancelID.dynamicRangeHUD),
                .cancel(id: CancelID.afrToast),
                .run { _ in
                    await displayModeClient.resetDisplayMode()
                },
                .run { send in
                    #if os(iOS)
                        await MainActor.run {
                            OrientationManager.shared.unlockPortrait()
                        }
                    #endif
                    if currentSecs > 10 {
                        let type = item.seriesTitle == nil ? "vod" : "episode"
                        let historyItem = WatchHistoryItem(
                            id: item.id,
                            type: type,
                            title: item.title,
                            seriesTitle: item.seriesTitle,
                            coverURL: item.coverURL?.absoluteString,
                            streamURL: item.streamURL.absoluteString,
                            progress: currentSecs,
                            duration: totalSecs,
                            playlistID: item.config?.playlistID,
                            seriesID: item.seriesID
                        )
                        // Keep completed progress so detail screens can expose
                        // an explicit mark-as-unwatched action. Continue
                        // Watching surfaces filter completed entries.
                        try? await databaseClient.saveWatchProgress(historyItem, profileScope)

                        // Trakt.tv scrobble stop on close (Madde #17)
                        if !item.isLive {
                            let pct = totalSecs > 0 ? (currentSecs / totalSecs) * 100.0 : 0.0
                            if let payload = TraktMediaParser.makePayload(title: item.title, seriesTitle: item.seriesTitle, isLive: item.isLive, progress: pct) {
                                _ = try? await traktClient.scrobbleStop(payload)
                            }
                        }
                    }

                    if !isPiPActive {
                        try? await playerClient.stop()
                        await playerClient.release()
                        await send(.delegate(.didClose))
                    }
                }
            )

        case let .setAudioDelay(delay):
            state.audioDelay = delay
            let delayStr = AppStrings.Player.audioDelayMs(delay)
            let hudMessage = "\(AppStrings.Player.audioSync): \(delayStr)"
            if state.rememberDelayForChannel {
                settingsClient.setChannelAudioDelay(state.item.id, delay == 0 ? nil : delay)
            }
            return .merge(
                .send(.showTrackHUD(message: hudMessage, icon: "waveform.circle")),
                .run { _ in
                    await playerClient.setAudioDelay(delay)
                }
            )

        case let .setSubtitleDelay(delay):
            state.subtitleDelay = delay
            let delayStr = AppStrings.Player.subtitleDelayMs(delay)
            let hudMessage = "\(AppStrings.Player.subtitleSync): \(delayStr)"
            if state.rememberDelayForChannel {
                settingsClient.setChannelSubtitleDelay(state.item.id, delay == 0 ? nil : delay)
            }
            return .merge(
                .send(.showTrackHUD(message: hudMessage, icon: "timer")),
                .run { _ in
                    await playerClient.setSubtitleDelay(delay)
                }
            )

        case .toggleAudioSyncHUD:
            state.isAudioSyncHUDVisible.toggle()
            if state.isAudioSyncHUDVisible {
                state.isControlsVisible = false
                state.isRecentChannelsHUDVisible = false
                state.isChannelListVisible = false
                state.isEPGVisible = false
            }
            return .none

        case let .setAudioSyncHUDVisible(isVisible):
            state.isAudioSyncHUDVisible = isVisible
            if isVisible {
                state.isControlsVisible = false
                state.isRecentChannelsHUDVisible = false
                state.isChannelListVisible = false
                state.isEPGVisible = false
            }
            return .none

        case let .setRememberDelayForChannel(remember):
            state.rememberDelayForChannel = remember
            return .none

        case .toggleStats:
            state.isShowingStats.toggle()
            if state.isShowingStats {
                let fetchInfoEffect: Effect<Action> = .send(.fetchMediaInfo)
                let timerEffect: Effect<Action> = .run { [item = state.item, isPlaying = (state.playerState == .playing), mediaBitrate = state.mediaInfo?.bitrate] send in
                    var prevCounters: PlayerPlaybackCounters?
                    while !Task.isCancelled {
                        let stats = await playerClient.getStats()
                        let counters = await playerClient.getPlaybackCounters()
                        let health = await streamHealthClient.evaluateHealth(
                            item.streamURL,
                            isPlaying,
                            counters,
                            prevCounters,
                            1.0,
                            mediaBitrate
                        )
                        prevCounters = counters
                        await send(.updateStats(stats ?? ""))
                        await send(.updateStreamHealth(health))
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }.cancellable(id: CancelID.statsTimer, cancelInFlight: true)
                return .merge(fetchInfoEffect, timerEffect)
            } else if !state.isStreamHealthHUDVisible {
                return .cancel(id: CancelID.statsTimer)
            } else {
                return .none
            }

        case let .updateStats(stats):
            state.playerStats = stats
            return .none

        case .toggleStreamHealthHUD:
            state.isStreamHealthHUDVisible.toggle()
            if state.isStreamHealthHUDVisible {
                state.isTracksMenuVisible = false
                state.isInfoVisible = false
                state.isAudioSyncHUDVisible = false
                state.isAudioEQHUDVisible = false
                state.isCatchupTimelineVisible = false
                state.isRecentChannelsHUDVisible = false
                let timerEffect: Effect<Action> = .run { [item = state.item, isPlaying = (state.playerState == .playing), mediaBitrate = state.mediaInfo?.bitrate] send in
                    var prevCounters: PlayerPlaybackCounters?
                    while !Task.isCancelled {
                        let counters = await playerClient.getPlaybackCounters()
                        let health = await streamHealthClient.evaluateHealth(
                            item.streamURL,
                            isPlaying,
                            counters,
                            prevCounters,
                            1.0,
                            mediaBitrate
                        )
                        prevCounters = counters
                        await send(.updateStreamHealth(health))
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }.cancellable(id: CancelID.statsTimer, cancelInFlight: true)
                return timerEffect
            } else if !state.isShowingStats {
                return .cancel(id: CancelID.statsTimer)
            } else {
                return .none
            }

        case let .setStreamHealthHUDVisible(visible):
            state.isStreamHealthHUDVisible = visible
            if visible {
                state.isTracksMenuVisible = false
                state.isInfoVisible = false
                state.isAudioSyncHUDVisible = false
                state.isAudioEQHUDVisible = false
                state.isCatchupTimelineVisible = false
                state.isRecentChannelsHUDVisible = false
            } else if !state.isShowingStats {
                return .cancel(id: CancelID.statsTimer)
            }
            return .none

        case let .updateStreamHealth(metrics):
            state.streamHealthMetrics = metrics
            return .none

        case .play:
            state.isUserPaused = false
            state.oledInactivitySeconds = 0
            state.oledDimLevel = 0.0
            state.isDeepDimmed = false
            return .merge(
                .run { _ in
                    try await playerClient.resume()
                },
                state.isTraktScrobbleStarted ? .send(.traktScrobbleStart) : .none
            )

        case .pause:
            state.isUserPaused = true
            state.oledInactivitySeconds = 0
            return .merge(
                .cancel(id: CancelID.stallWatchdog),
                .run { _ in
                    try await playerClient.pause()
                },
                .send(.traktScrobblePause)
            )

        case .stop:
            return .merge(
                .run { _ in
                    try await playerClient.stop()
                },
                .send(.traktScrobbleStop)
            )

        case .retryPlayback:
            state.errorMessage = nil
            state.isUserPaused = false
            if state.retryCount >= state.maxReconnectAttempts {
                state.retryCount = 0
                state.failedStreamIDs.removeAll()
            }
            state.isReconnecting = true
            let url = state.item.streamURL
            let isLive = state.item.isLive
            let position = state.position > 0 ? state.position : (state.item.startPosition ?? 0.0)
            let currentRate = state.playbackRate
            let userAgentOverride = state.item.userAgentOverride
            let networkCachingMilliseconds = BufferProfile.activeNetworkCachingMilliseconds(for: isLive)
            return .run { send in
                // Flush and cleanly reset VLC engine to avoid pipeline lockups
                try? await playerClient.stop()
                try? await Task.sleep(nanoseconds: 200_000_000)

                let eventsStream = await playerClient.events()
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await event in eventsStream {
                            await send(.handlePlayerEvent(event))
                        }
                    }

                    group.addTask {
                        do {
                            try await playerClient.play(url, userAgentOverride, networkCachingMilliseconds)
                            if !isLive, position > 0 {
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                try? await playerClient.seek(position)
                            }
                            if currentRate != 1.0 {
                                try? await playerClient.setPlaybackRate(currentRate)
                            }
                        } catch {
                            print("Player retry error: \(error)")
                            await send(.handlePlayerEvent(.encounteredError))
                        }
                    }
                }
            }
            .cancellable(id: CancelID.playerEvents, cancelInFlight: true)

        case .streamStalled:
            guard !state.isUserPaused, !state.isMinimized else { return .none }
            if state.playerState == .buffering || state.playerState == .opening {
                return .send(.initiateAutoReconnect)
            }
            return .none

        case .initiateAutoReconnect:
            guard !state.isUserPaused, !state.isMinimized else { return .none }

            // If within retry limit for current item, attempt retry with progressive jittered exponential backoff
            if state.retryCount < state.maxReconnectAttempts {
                state.retryCount += 1
                state.isReconnecting = true
                state.isFallbackSwitching = false
                state.errorMessage = nil

                let attempt = state.retryCount
                // Jittered Exponential Backoff: 1.0 * (1.8^(attempt-1)) + jitter, max 12.0s
                let exponential = pow(1.8, Double(attempt - 1)) * 1.0
                let jitter = Double.random(in: 0.15 ... 0.45)
                let backoffDelay = min(exponential + jitter, 12.0)
                let delayNanoseconds = UInt64(backoffDelay * 1_000_000_000)

                return .concatenate(
                    .cancel(id: CancelID.stallWatchdog),
                    .run { send in
                        try? await Task.sleep(nanoseconds: delayNanoseconds)
                        await send(.retryPlayback)
                    }
                    .cancellable(id: CancelID.reconnectTimer, cancelInFlight: true)
                )
            } else {
                // Retries exhausted on this specific source
                state.failedStreamIDs.insert(state.item.id)

                // Automatic failover source search (Feature #8)
                if let failoverItem = state.backupStreamItem {
                    state.retryCount = 0
                    state.isReconnecting = true
                    state.isFallbackSwitching = true
                    state.fallbackStreamName = failoverItem.title
                    state.errorMessage = nil
                    return .concatenate(
                        .cancel(id: CancelID.stallWatchdog),
                        .cancel(id: CancelID.reconnectTimer),
                        .send(.showGestureFeedback(AppStrings.Player.switchingToBackup(failoverItem.title))),
                        .send(.selectChannel(failoverItem))
                    )
                } else {
                    // No alternate backup sources available in playlist
                    state.isReconnecting = false
                    state.isFallbackSwitching = false
                    state.errorMessage = AppStrings.Errors.cannotPlayStream

                    // For live streams, schedule silent background pulse (every 12 seconds)
                    if state.item.isLive {
                        return .concatenate(
                            .cancel(id: CancelID.stallWatchdog),
                            .run { send in
                                try? await Task.sleep(nanoseconds: 12_000_000_000)
                                await send(.autoReconnectPulse)
                            }
                            .cancellable(id: CancelID.reconnectTimer, cancelInFlight: true)
                        )
                    } else {
                        return .cancel(id: CancelID.stallWatchdog)
                    }
                }
            }

        case .autoReconnectPulse:
            guard state.item.isLive, !state.isUserPaused, !state.isMinimized else { return .none }
            if state.errorMessage != nil {
                state.isReconnecting = true
                return .send(.retryPlayback)
            }
            return .none

        case .switchToBackupStream:
            guard let backup = state.backupStreamItem else { return .none }
            state.retryCount = 0
            state.isReconnecting = true
            state.isFallbackSwitching = true
            state.fallbackStreamName = backup.title
            state.errorMessage = nil
            return .concatenate(
                .cancel(id: CancelID.stallWatchdog),
                .cancel(id: CancelID.reconnectTimer),
                .send(.showGestureFeedback(AppStrings.Player.switchingToBackup(backup.title))),
                .send(.selectChannel(backup))
            )

        case .toggleControls:
            if state.isScreenLocked {
                state.isLockPillVisible = true
                return .run { send in
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    await send(.hideLockPill)
                }
            }
            state.isControlsVisible.toggle()
            state.oledInactivitySeconds = 0
            if !state.isControlsVisible, state.playerState == .playing {
                state.oledDimLevel = 0.0
                state.isDeepDimmed = false
            }
            return .none

        case .toggleScreenLock:
            state.isScreenLocked.toggle()
            if state.isScreenLocked {
                state.isControlsVisible = false
                state.isLockPillVisible = true
                return .run { send in
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    await send(.hideLockPill)
                }
            } else {
                state.isControlsVisible = true
                state.isLockPillVisible = false
                return .none
            }

        case let .setScreenLocked(locked):
            state.isScreenLocked = locked
            if locked {
                state.isControlsVisible = false
                state.isLockPillVisible = true
            }
            return .none

        case .showLockPill:
            state.isLockPillVisible = true
            return .run { send in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await send(.hideLockPill)
            }
            .cancellable(id: CancelID.lockPill, cancelInFlight: true)

        case .hideLockPill:
            state.isLockPillVisible = false
            return .none

        case let .audioRouteUpdated(route):
            let oldRoute = state.currentAudioRoute
            state.currentAudioRoute = route
            if oldRoute != route, route.isExternal || oldRoute.isExternal {
                state.isAudioRouteHUDVisible = true
                return .run { send in
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    await send(.hideAudioRouteHUD, animation: .easeOut(duration: 0.3))
                }
                .cancellable(id: CancelID.audioRouteHUD, cancelInFlight: true)
            }
            return .none

        case let .showAudioRouteHUD(route):
            state.currentAudioRoute = route
            state.isAudioRouteHUDVisible = true
            return .run { send in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await send(.hideAudioRouteHUD, animation: .easeOut(duration: 0.3))
            }
            .cancellable(id: CancelID.audioRouteHUD, cancelInFlight: true)

        case .hideAudioRouteHUD:
            state.isAudioRouteHUDVisible = false
            return .none

        case let .showTrackHUD(message, icon):
            state.trackHUDMessage = message
            state.trackHUDIcon = icon
            state.isTrackHUDVisible = true
            return .run { send in
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                await send(.hideTrackHUD, animation: .easeOut(duration: 0.3))
            }
            .cancellable(id: CancelID.trackHUD, cancelInFlight: true)

        case .hideTrackHUD:
            state.isTrackHUDVisible = false
            return .none

        case .hideControls:
            state.isControlsVisible = false
            state.isInfoVisible = false
            state.isTracksMenuVisible = false
            state.isEPGVisible = false
            state.oledInactivitySeconds = 0
            if state.playerState == .playing {
                state.oledDimLevel = 0.0
                state.isDeepDimmed = false
            }
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
                state.sleepTimerInitialVolume = state.volume
                state.isSleepFadingActive = false
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
                let wasFading = state.isSleepFadingActive
                let restoreVol = state.sleepTimerInitialVolume
                state.sleepTimerSeconds = nil
                state.isSleepFadingActive = false
                if wasFading {
                    state.volume = restoreVol
                    state.oledDimLevel = 0.0
                }
                state.gestureFeedback = AppStrings.Player.sleepTimerDisabled
                return .merge(
                    .cancel(id: CancelID.sleepTimer),
                    .run { send in
                        if wasFading {
                            try? await playerClient.setVolume(restoreVol)
                        }
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        await send(.hideGestureFeedback)
                    }
                )
            }

        case .sleepTimerTick:
            guard let current = state.sleepTimerSeconds, current > 0 else { return .none }
            let remaining = current - 1
            state.sleepTimerSeconds = remaining

            if remaining == 0 {
                state.isSleepFadingActive = false
                return .send(.sleepTimerEnded)
            }

            // Smooth audio fade & screen dimming during the last 60 seconds
            if remaining <= 60 {
                state.isSleepFadingActive = true
                let progress = Double(60 - remaining) / 60.0
                let initial = Double(state.sleepTimerInitialVolume)
                let newVolume = max(0, Int32(initial * (1.0 - progress)))
                state.volume = newVolume
                state.oledDimLevel = max(state.oledDimLevel, progress * 0.85)

                return .run { _ in
                    try? await playerClient.setVolume(newVolume)
                }
            }
            return .none

        case .sleepTimerEnded:
            state.isSleepFadingActive = false
            return .concatenate(
                .run { _ in
                    try? await playerClient.setVolume(0)
                },
                .send(.closeTapped)
            )

        case .userInteracted:
            state.oledInactivitySeconds = 0
            if state.isSleepFadingActive {
                state.isSleepFadingActive = false
                let restoredVol = state.sleepTimerInitialVolume
                state.volume = restoredVol
                state.oledDimLevel = 0.0
                state.isDeepDimmed = false
                return .run { _ in
                    try? await playerClient.setVolume(restoredVol)
                }
            }
            if state.oledDimLevel > 0 || state.isDeepDimmed {
                state.oledDimLevel = 0.0
                state.isDeepDimmed = false
            }
            return .none

        case .startOLEDDimTimer:
            return .run { send in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await send(.oledDimTimerTick)
                }
            }
            .cancellable(id: CancelID.oledDimTimer, cancelInFlight: true)

        case .oledDimTimerTick:
            guard state.isOLEDDimmingEnabled else { return .none }
            if state.playerState == .paused || state.isControlsVisible || state.isEPGVisible {
                state.oledInactivitySeconds += 1
                if state.oledInactivitySeconds >= 30 {
                    if state.oledDimLevel != 0.75 || !state.isDeepDimmed {
                        state.oledDimLevel = 0.75
                        state.isDeepDimmed = true
                    }
                } else if state.oledInactivitySeconds >= 15 {
                    if state.oledDimLevel != 0.40 || state.isDeepDimmed {
                        state.oledDimLevel = 0.40
                        state.isDeepDimmed = false
                    }
                }
            } else {
                if state.oledDimLevel > 0 || state.isDeepDimmed {
                    state.oledDimLevel = 0.0
                    state.isDeepDimmed = false
                }
                state.oledInactivitySeconds = 0
            }
            return .none

        case let .setOLEDDimLevel(level):
            state.oledDimLevel = max(0.0, min(1.0, level))
            return .none

        case let .toggleOLEDDimming(enabled):
            state.isOLEDDimmingEnabled = enabled
            if !enabled {
                state.oledDimLevel = 0.0
                state.isDeepDimmed = false
                state.oledInactivitySeconds = 0
            }
            return .run { _ in
                settingsClient.setIsOLEDDimmingEnabled(enabled)
            }

        case .toggleChannelNameCleaning:
            let newValue = !state.isChannelNameCleaningEnabled
            state.isChannelNameCleaningEnabled = newValue
            return .run { _ in
                settingsClient.setIsChannelNameCleaningEnabled(newValue)
            }

        case let .setChannelNameCleaningEnabled(enabled):
            state.isChannelNameCleaningEnabled = enabled
            return .run { _ in
                settingsClient.setIsChannelNameCleaningEnabled(enabled)
            }

        // Trakt.tv Scrobbler (Madde #17)
        case .traktScrobbleStart:
            guard !state.item.isLive, traktClient.isAuthenticated(), traktClient.isAutoScrobbleEnabled() else {
                return .none
            }
            let item = state.item
            let percent = state.position * 100.0
            guard let payload = TraktMediaParser.makePayload(
                title: item.title,
                seriesTitle: item.seriesTitle,
                isLive: item.isLive,
                progress: percent
            ) else { return .none }

            return .run { send in
                if let resp = try? await traktClient.scrobbleStart(payload) {
                    await send(.showTraktScrobbleHUD(message: "Trakt: Scrobble Başlatıldı", progress: resp.progress))
                }
            }

        case .traktScrobblePause:
            guard !state.item.isLive, traktClient.isAuthenticated(), traktClient.isAutoScrobbleEnabled() else {
                return .none
            }
            let item = state.item
            let percent = state.position * 100.0
            guard let payload = TraktMediaParser.makePayload(
                title: item.title,
                seriesTitle: item.seriesTitle,
                isLive: item.isLive,
                progress: percent
            ) else { return .none }

            return .run { _ in
                _ = try? await traktClient.scrobblePause(payload)
            }

        case .traktScrobbleStop:
            guard !state.item.isLive, traktClient.isAuthenticated(), traktClient.isAutoScrobbleEnabled() else {
                return .none
            }
            let item = state.item
            let percent = state.position * 100.0
            guard let payload = TraktMediaParser.makePayload(
                title: item.title,
                seriesTitle: item.seriesTitle,
                isLive: item.isLive,
                progress: percent
            ) else { return .none }

            return .run { send in
                if let resp = try? await traktClient.scrobbleStop(payload) {
                    if resp.action == "scrobble" || percent >= 80.0 {
                        await send(.showTraktScrobbleHUD(message: "Trakt: İzlendi Olarak İşaretlendi", progress: resp.progress))
                    }
                }
            }

        case let .showTraktScrobbleHUD(message, progress):
            state.traktScrobbleHUDMessage = message
            state.traktScrobbleHUDPercent = progress
            state.isTraktScrobbleHUDVisible = true
            return .run { send in
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                await send(.dismissTraktScrobbleHUD)
            }
            .cancellable(id: CancelID.traktScrobbleHUD, cancelInFlight: true)

        case .dismissTraktScrobbleHUD:
            state.isTraktScrobbleHUDVisible = false
            return .cancel(id: CancelID.traktScrobbleHUD)

        case let .dragGestureChanged(translation, screenWidth, _, startLocation):
            state.lastDragTranslation = translation
            state.lastDragScreenWidth = screenWidth
            if abs(translation.width) > abs(translation.height) {
                if state.item.isLive, state.totalTime.components.seconds == 0 {
                    if startLocation.x < 60, translation.width > 40 {
                        return .send(.showGestureFeedback("📺 " + AppStrings.LiveTV.channelsTitle))
                    } else if translation.width > 50 {
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
                if state.item.isLive, state.totalTime.components.seconds == 0, translation.height > 60 {
                    let label = state.previousChannel != nil
                        ? "⏮ " + state.previousChannel!.title
                        : AppStrings.Player.recallLastChannel
                    return .send(.showGestureFeedback(label))
                }
                return .none
            }

        case .dragGestureEnded:
            if state.item.isLive, state.totalTime.components.seconds == 0 {
                let feedback = state.gestureFeedback
                let nextChannelStr = AppStrings.Player.nextChannel
                let prevChannelStr = AppStrings.Player.previousChannel
                let recallLabel = AppStrings.Player.recallLastChannel
                let sidebarStr = "📺 " + AppStrings.LiveTV.channelsTitle
                return .run { send in
                    await send(.hideGestureFeedback)
                    if feedback == sidebarStr {
                        await send(.setChannelListVisible(true))
                    } else if feedback == nextChannelStr {
                        await send(.nextChannel)
                    } else if feedback == prevChannelStr {
                        await send(.previousChannel)
                    } else if feedback == recallLabel || feedback?.hasPrefix("⏮") == true {
                        await send(.recallLastChannel)
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

        case let .jumpBySeconds(offset):
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

        case .jumpForward:
            return .send(.jumpBySeconds(10))

        case .jumpBackward:
            return .send(.jumpBySeconds(-10))

        case .restartPlayback:
            state.currentTime = .zero
            state.position = 0.0
            return .run { send in
                await send(.seek(0.0))
                await send(.seekToTime(.zero))
                await send(.play)
            }

        case let .seek(position):
            state.scrubThumbnailRequestID = nil
            state.scrubThumbnailData = nil
            let clamped = max(0.0, min(1.0, position))
            state.position = clamped
            if state.totalTime.components.seconds > 0 {
                state.currentTime = Duration.seconds(Double(state.totalTime.components.seconds) * clamped)
            }
            let upNextEffect = updateUpNextState(state: &state, settingsClient: settingsClient)
            return .merge(
                .cancel(id: CancelID.scrubThumbnail),
                .run { _ in try await playerClient.seek(clamped) },
                upNextEffect
            )

        case let .requestScrubThumbnail(time):
            guard
                !state.item.isLive,
                state.totalTime > .zero,
                time >= .zero,
                time < state.totalTime
            else { return .none }
            let requestID = UUID()
            let itemID = state.item.id
            let url = state.item.streamURL
            let userAgentOverride = state.item.userAgentOverride
            state.scrubThumbnailRequestID = requestID
            state.scrubThumbnailData = nil
            return .run { send in
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    try Task.checkCancellation()
                    let data = try? await playerClient.thumbnail(url, userAgentOverride, time)
                    try Task.checkCancellation()
                    await send(.scrubThumbnailLoaded(requestID: requestID, itemID: itemID, data: data))
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }
            .cancellable(id: CancelID.scrubThumbnail, cancelInFlight: true)

        case let .scrubThumbnailLoaded(requestID, itemID, data):
            guard state.scrubThumbnailRequestID == requestID, state.item.id == itemID else { return .none }
            state.scrubThumbnailData = data
            return .none

        case .cancelScrubThumbnail:
            state.scrubThumbnailRequestID = nil
            state.scrubThumbnailData = nil
            return .cancel(id: CancelID.scrubThumbnail)

        case let .seekToTime(time):
            state.scrubThumbnailRequestID = nil
            state.scrubThumbnailData = nil
            state.currentTime = time
            if state.totalTime.components.seconds > 0 {
                state.position = min(1.0, max(0.0, Double(time.components.seconds) / Double(state.totalTime.components.seconds)))
            }
            let upNextEffect = updateUpNextState(state: &state, settingsClient: settingsClient)
            return .merge(
                .cancel(id: CancelID.scrubThumbnail),
                .run { _ in try await playerClient.seekToTime(time) },
                upNextEffect
            )

        case let .setPlaybackRate(rate):
            let clamped = max(0.25, min(4.0, rate))
            state.playbackRate = clamped
            return .run { _ in
                try await playerClient.setPlaybackRate(clamped)
            } catch: { error, _ in
                print("Failed to set playback rate: \(error)")
            }

        case .toggleChannelList:
            state.isChannelListVisible.toggle()
            return .none

        case let .setChannelListVisible(isVisible):
            state.isChannelListVisible = isVisible
            return .none

        case .toggleRecentChannelsHUD:
            state.isRecentChannelsHUDVisible.toggle()
            if state.isRecentChannelsHUDVisible {
                state.isControlsVisible = false
                state.isChannelListVisible = false
                state.isEPGVisible = false
                return .send(.loadRecentChannels)
            }
            return .none

        case let .setRecentChannelsHUDVisible(isVisible):
            state.isRecentChannelsHUDVisible = isVisible
            if isVisible {
                state.isControlsVisible = false
                state.isChannelListVisible = false
                state.isEPGVisible = false
                return .send(.loadRecentChannels)
            }
            return .none

        case let .selectRecentChannel(targetItem):
            state.isRecentChannelsHUDVisible = false
            return .send(.selectChannel(targetItem))

        case let .togglePinnedRecentChannel(channelID):
            let hiddenIDs = state.hiddenChannelIDs
            let blacklistedCategoryIDs = state.blacklistedCategoryIDs
            guard
                let playlistID = state.item.config?.playlistID,
                state.playlist?.contains(where: {
                    $0.id == channelID
                        && $0.isLive
                        && !hiddenIDs.contains($0.id)
                        && !($0.categoryID.map(blacklistedCategoryIDs.contains) ?? false)
                }) == true
            else { return .none }
            let profileScope = profileContextClient.snapshot()
            let requestID = UUID()
            state.recentChannelPinRequestID = requestID
            state.recentChannelsRequestID = nil
            return .run { send in
                _ = await recentChannelsClient.togglePinnedChannel(
                    channelID,
                    profileScope.profileID,
                    playlistID
                )
                guard profileContextClient.snapshot() == profileScope else { return }
                await send(.recentChannelPinMutationCompleted(
                    requestID: requestID,
                    playlistID: playlistID,
                    profileScope: profileScope
                ))
            }

        case let .recentChannelPinMutationCompleted(requestID, playlistID, profileScope):
            guard
                state.recentChannelPinRequestID == requestID,
                profileContextClient.snapshot() == profileScope,
                state.item.config?.playlistID == playlistID
            else { return .none }
            state.recentChannelPinRequestID = nil
            return .send(.loadRecentChannels)

        case .loadRecentChannels:
            let requestID = UUID()
            state.recentChannelsRequestID = requestID
            let playlistID = state.item.config?.playlistID
            let profileScope = profileContextClient.snapshot()
            let hiddenIDs = state.hiddenChannelIDs
            let blacklistedCategoryIDs = state.blacklistedCategoryIDs
            return .run { [playlist = state.playlist, config = state.item.config] send in
                let recentDTOs = await recentChannelsClient.fetchRecentChannels()
                let pinnedIDs: [String] = if let playlistID {
                    await recentChannelsClient.fetchPinnedChannelIDs(profileScope.profileID, playlistID)
                } else {
                    []
                }
                let pinnedItems: [PlayableItem] = pinnedIDs.compactMap { id in
                    playlist?.first(where: {
                        $0.id == id
                            && $0.isLive
                            && !hiddenIDs.contains($0.id)
                            && !($0.categoryID.map(blacklistedCategoryIDs.contains) ?? false)
                    })
                }
                let recentItems: [PlayableItem] = recentDTOs.compactMap { dto in
                    let item: PlayableItem = if let match = playlist?.first(where: { $0.id == dto.id }) {
                        match
                    } else {
                        PlayableItem(
                            id: dto.id,
                            title: dto.title,
                            seriesTitle: dto.seriesTitle,
                            streamURL: dto.streamURL,
                            coverURL: dto.coverURL,
                            isLive: true,
                            config: config,
                            epgChannelID: dto.epgChannelID,
                            tvArchive: dto.tvArchive,
                            categoryID: dto.categoryID
                        )
                    }
                    guard
                        !hiddenIDs.contains(item.id),
                        !(item.categoryID.map(blacklistedCategoryIDs.contains) ?? false)
                    else { return nil }
                    return item
                }
                let pinnedSet = Set(pinnedItems.map(\.id))
                let items = pinnedItems + recentItems.filter { !pinnedSet.contains($0.id) }
                let eligibleIDs: Set<String> = Set((playlist ?? []).compactMap { item in
                    guard
                        item.isLive,
                        !hiddenIDs.contains(item.id),
                        !(item.categoryID.map(blacklistedCategoryIDs.contains) ?? false)
                    else { return nil }
                    return item.id
                })
                guard profileContextClient.snapshot() == profileScope else { return }
                await send(.recentChannelsLoaded(
                    items: items,
                    pinnedIDs: pinnedItems.map(\.id),
                    pinnableIDs: eligibleIDs,
                    requestID: requestID,
                    playlistID: playlistID,
                    profileScope: profileScope
                ))
            }

        case let .recentChannelsLoaded(items, pinnedIDs, pinnableIDs, requestID, playlistID, profileScope):
            guard
                state.recentChannelsRequestID == requestID,
                profileContextClient.snapshot() == profileScope,
                state.item.config?.playlistID == playlistID
            else { return .none }
            state.recentChannels = items
            state.pinnedRecentChannelIDs = pinnedIDs
            state.pinnableRecentChannelIDs = pinnableIDs
            return .none

        case let .selectChannel(newItem):
            let currentItem = state.item
            let channelZappingDelay: Int = if
                !state.isReconnecting,
                !state.isFallbackSwitching,
                currentItem.isLive,
                newItem.isLive,
                newItem.id != currentItem.id,
                let currentPlaylistID = currentItem.config?.playlistID,
                currentPlaylistID == newItem.config?.playlistID
            {
                newItem.config?.channelZappingDelayMilliseconds ?? 0
            } else {
                0
            }
            if newItem.id != currentItem.id {
                state.previousChannel = currentItem
                state.zappingHistory.removeAll(where: { $0.id == currentItem.id })
                state.zappingHistory.append(currentItem)
                if state.zappingHistory.count > 10 {
                    state.zappingHistory.removeFirst()
                }
                state.channelWatchCounts[newItem.id] = (state.channelWatchCounts[newItem.id] ?? 0) + 1
            }
            if !state.isReconnecting {
                state.failedStreamIDs.removeAll()
            }
            state.item = newItem
            state.scrubThumbnailRequestID = nil
            state.scrubThumbnailData = nil
            state.catchupTimeShiftHours = customEPGMappingClient.getCatchupTimeShift(newItem.id)
            state.isChannelListVisible = false
            state.isRecentChannelsHUDVisible = false
            state.isAudioSyncHUDVisible = false
            state.isAudioEQHUDVisible = false
            state.audioDelay = settingsClient.getChannelAudioDelay(newItem.id) ?? 0
            state.subtitleDelay = settingsClient.getChannelSubtitleDelay(newItem.id) ?? 0
            state.audioTracks = []
            state.subtitleTracks = []
            state.selectedAudioTrack = nil
            state.selectedSubtitleTrack = nil
            state.epgListings = []
            state.mediaInfo = nil
            state.currentTime = .zero
            state.totalTime = .zero
            state.position = 0.0
            state.hasAppliedInitialSeek = false
            let drInfo = ColorSpaceDetector.detectFromText(title: newItem.title, urlString: newItem.streamURL.absoluteString)
            state.dynamicRangeInfo = drInfo
            state.videoDynamicRange = drInfo.range
            state.isDynamicRangeHUDVisible = drInfo.range.isHDR
            let detectedFPS = FrameRateDetector.detect(title: newItem.title, urlString: newItem.streamURL.absoluteString, isLive: newItem.isLive)
            state.currentFrameRate = detectedFPS
            state.zappingHUDItem = newItem
            state.isZappingHUDVisible = true
            state.isChannelOSDVisible = newItem.isLive
            state.isUserPaused = false
            state.isReconnecting = false
            state.isFallbackSwitching = false
            state.fallbackStreamName = nil
            state.retryCount = 0
            state.errorMessage = nil
            state.isUpNextVisible = false
            state.isUpNextDismissed = false

            return .concatenate(
                .cancel(id: CancelID.scrubThumbnail),
                .cancel(id: CancelID.stallWatchdog),
                .cancel(id: CancelID.reconnectTimer),
                .cancel(id: CancelID.playerEvents),
                .run { send in
                    try await playerClient.stop()
                    guard !Task.isCancelled else { return }
                    if channelZappingDelay > 0 {
                        do {
                            try await Task.sleep(for: .milliseconds(Int64(channelZappingDelay)))
                        } catch {
                            return
                        }
                    }
                    guard !Task.isCancelled else { return }
                    await send(.startSelectedChannel(id: newItem.id))
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await send(.hideZappingHUD)
                }
                .cancellable(id: CancelID.channelSwitch, cancelInFlight: true)
            )

        case .recallLastChannel:
            guard let prev = state.previousChannel ?? state.zappingHistory.last(where: { $0.id != state.item.id }) else {
                return .run { send in
                    await send(.showGestureFeedback(AppStrings.Player.noPreviousChannel))
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await send(.hideGestureFeedback)
                }
            }
            state.recalledChannelItem = prev
            state.isRecallHUDVisible = true
            state.zappingHUDDirection = .previous
            return .concatenate(
                .send(.selectChannel(prev)),
                .run { send in
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    await send(.hideRecallHUD)
                }
                .cancellable(id: CancelID.recallHUD, cancelInFlight: true)
            )

        case let .setRecallHUDVisible(visible):
            state.isRecallHUDVisible = visible
            if !visible {
                state.recalledChannelItem = nil
            }
            return .none

        case .hideRecallHUD:
            state.isRecallHUDVisible = false
            state.recalledChannelItem = nil
            return .none

        case .nextChannel:
            guard let next = state.nextChannelItem else { return .none }
            state.zappingHUDDirection = .next
            return .send(.selectChannel(next))

        case .previousChannel:
            guard let prev = state.previousChannelItem else { return .none }
            state.zappingHUDDirection = .previous
            return .send(.selectChannel(prev))

        case let .showZappingHUD(item, direction):
            state.zappingHUDItem = item
            state.zappingHUDDirection = direction
            state.isZappingHUDVisible = true
            return .none

        case .hideZappingHUD:
            state.isZappingHUDVisible = false
            state.zappingHUDItem = nil
            state.zappingHUDDirection = nil
            return .none

        case .openChannelDialer:
            state.dialedChannelNumber = ""
            state.isChannelDialerVisible = true
            return .none

        case let .setChannelDialerVisible(visible):
            state.isChannelDialerVisible = visible
            if !visible {
                state.dialedChannelNumber = ""
                return .cancel(id: CancelID.dialerAutoSubmit)
            }
            return .none

        case let .appendDialedDigit(digit):
            guard state.dialedChannelNumber.count < 5 else { return .none }
            state.dialedChannelNumber.append(digit)
            state.isChannelDialerVisible = true
            return .run { send in
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                await send(.submitDialedChannel)
            }
            .cancellable(id: CancelID.dialerAutoSubmit, cancelInFlight: true)

        case .deleteDialedDigit:
            if !state.dialedChannelNumber.isEmpty {
                state.dialedChannelNumber.removeLast()
            }
            if state.dialedChannelNumber.isEmpty {
                return .cancel(id: CancelID.dialerAutoSubmit)
            } else {
                return .run { send in
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    await send(.submitDialedChannel)
                }
                .cancellable(id: CancelID.dialerAutoSubmit, cancelInFlight: true)
            }

        case .clearDialedDigits:
            state.dialedChannelNumber = ""
            return .cancel(id: CancelID.dialerAutoSubmit)

        case .submitDialedChannel:
            guard !state.dialedChannelNumber.isEmpty else {
                state.isChannelDialerVisible = false
                return .cancel(id: CancelID.dialerAutoSubmit)
            }
            let dialed = state.dialedChannelNumber
            let matches = state.matchedDialedChannels
            state.dialedChannelNumber = ""
            state.isChannelDialerVisible = false

            if let targetIdx = Int(dialed), targetIdx >= 1,
               let list = state.playlist, targetIdx <= list.count
            {
                let targetChannel = list[targetIdx - 1]
                state.zappingHUDDirection = .next
                return .concatenate(
                    .cancel(id: CancelID.dialerAutoSubmit),
                    .send(.selectChannel(targetChannel))
                )
            } else if let matched = matches.first {
                state.zappingHUDDirection = .next
                return .concatenate(
                    .cancel(id: CancelID.dialerAutoSubmit),
                    .send(.selectChannel(matched.item))
                )
            } else {
                return .concatenate(
                    .cancel(id: CancelID.dialerAutoSubmit),
                    .run { send in
                        await send(.showGestureFeedback(AppStrings.LiveTV.noChannels))
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        await send(.hideGestureFeedback)
                    }
                )
            }

        case .loadChannelSortPreferences:
            return .run { send in
                let sort = settingsClient.getLiveTVSortOption()
                let counts = await recentChannelsClient.fetchWatchCounts()
                await send(.channelSortPreferencesLoaded(sortOption: sort, watchCounts: counts))
            }

        case let .channelSortPreferencesLoaded(opt, counts):
            state.channelSortOption = opt
            state.channelWatchCounts = counts
            return .none

        case let .setChannelSortOption(opt):
            state.channelSortOption = opt
            return .run { _ in
                settingsClient.setLiveTVSortOption(opt)
            }

        case .showChannelOSD:
            state.isChannelOSDVisible = true
            return .run { send in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                await send(.hideChannelOSD)
            }
            .cancellable(id: CancelID.channelOSD, cancelInFlight: true)

        case .hideChannelOSD:
            state.isChannelOSDVisible = false
            return .none

        case .toggleInfo:
            state.isInfoVisible.toggle()
            if state.isInfoVisible {
                state.isTracksMenuVisible = false
                state.isStreamHealthHUDVisible = false
                state.isAudioSyncHUDVisible = false
                state.isAudioEQHUDVisible = false
                state.isCatchupTimelineVisible = false
                state.isRecentChannelsHUDVisible = false
                return .send(.fetchMediaInfo)
            }
            return .none

        case .toggleEPG:
            state.isEPGVisible.toggle()
            guard state.isEPGVisible else { return .cancel(id: CancelID.epgBrowse) }
            let currentChannel = state.item
            state.epgBrowseChannel = currentChannel
            state.epgBrowseListings = state.epgListings
            state.isEPGBrowseLoading = false
            return state.epgListings.isEmpty ? .send(.fetchEPG) : .none

        case let .selectEPGBrowseChannel(channel):
            guard state.isEPGVisible, channel.isLive else { return .none }
            state.epgBrowseChannel = channel
            if channel.id == state.item.id {
                state.epgBrowseListings = state.epgListings
                state.isEPGBrowseLoading = false
                return .cancel(id: CancelID.epgBrowse)
            }
            guard let config = channel.config else {
                state.epgBrowseListings = []
                state.isEPGBrowseLoading = false
                return .cancel(id: CancelID.epgBrowse)
            }
            state.epgBrowseListings = []
            state.isEPGBrowseLoading = true
            let channelID = channel.id
            let channelTitle = channel.title
            let epgID = channel.epgChannelID ?? channel.id
            return .run { [iptvClient, customEPGMappingClient] send in
                let customPrograms = await customEPGMappingClient.fetchProgramsForChannel(
                    channelID, channelTitle, channel.epgChannelID
                )
                let programs: [EPGProgram] = if !customPrograms.isEmpty {
                    customPrograms
                } else {
                    try await iptvClient.fetchShortEPG(config, epgID, 10)
                }
                await send(.epgBrowseResponse(
                    channelID: channelID,
                    .success(customEPGMappingClient.applyTimeShift(programs, channelID))
                ))
            } catch: { error, send in
                await send(.epgBrowseResponse(channelID: channelID, .failure(error)))
            }
            .cancellable(id: CancelID.epgBrowse, cancelInFlight: true)

        case let .epgBrowseResponse(channelID, result):
            guard
                state.isEPGVisible,
                state.epgBrowseChannel?.id == channelID
            else { return .none }
            state.isEPGBrowseLoading = false
            if case let .success(programs) = result {
                state.epgBrowseListings = programs
            } else {
                state.epgBrowseListings = []
            }
            return .none

        case .watchEPGBrowseChannel:
            guard let channel = state.epgBrowseChannel else { return .none }
            state.isEPGVisible = false
            return .merge(
                .cancel(id: CancelID.epgBrowse),
                .send(.selectChannel(channel))
            )

        case let .setVideoAspectRatioMode(mode):
            state.videoAspectRatioMode = mode
            if mode == .fit {
                state.videoZoomScale = 1.0
            } else if mode == .fill {
                state.videoZoomScale = 1.25
            } else if mode == .stretch {
                state.videoZoomScale = 1.0
            }
            state.isAspectFeedbackVisible = true
            return .concatenate(
                .cancel(id: CancelID.aspectFeedback),
                .run { send in
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    await send(.hideAspectFeedback)
                }
                .cancellable(id: CancelID.aspectFeedback)
            )

        case let .setVideoZoomScale(scale):
            let clamped = max(1.0, min(3.0, scale))
            state.videoZoomScale = clamped
            if clamped > 1.05 {
                state.videoAspectRatioMode = .zoom
            } else if state.videoAspectRatioMode == .zoom {
                state.videoAspectRatioMode = .fit
            }
            state.isAspectFeedbackVisible = true
            return .concatenate(
                .cancel(id: CancelID.aspectFeedback),
                .run { send in
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    await send(.hideAspectFeedback)
                }
                .cancellable(id: CancelID.aspectFeedback)
            )

        case .toggleAspectRatioMode:
            let nextMode: VideoAspectRatioMode = switch state.videoAspectRatioMode {
            case .fit: .fill
            case .fill: .stretch
            case .stretch: .fit
            case .zoom: .fit
            }
            return .send(.setVideoAspectRatioMode(nextMode))

        case .hideAspectFeedback:
            state.isAspectFeedbackVisible = false
            return .none

        case .fetchEPG:
            guard state.item.isLive else { return .none }
            state.isEPGLoading = true
            let channelID = state.item.id
            let channelTitle = state.item.title
            let fallbackEpgID = state.item.epgChannelID
            let config = state.item.config

            return .run { [customEPGMappingClient] send in
                // 1. Check custom XMLTV sources first
                let customPrograms = await customEPGMappingClient.fetchProgramsForChannel(channelID, channelTitle, fallbackEpgID)
                if !customPrograms.isEmpty {
                    await send(.fetchEPGResponse(.success(customPrograms)))
                    return
                }

                // 2. Fall back to IPTV client fetch
                guard let config, let fallbackEpgID else {
                    await send(.fetchEPGResponse(.success([])))
                    return
                }

                await send(.fetchEPGResponse(Result {
                    let rawListings = try await iptvClient.fetchShortEPG(config, fallbackEpgID, 10)
                    return customEPGMappingClient.applyTimeShift(rawListings, channelID)
                }))
            }

        case let .fetchEPGResponse(.success(listings)):
            state.isEPGLoading = false
            state.epgListings = customEPGMappingClient.applyTimeShift(listings, state.item.id)
            if state.epgBrowseChannel?.id == state.item.id {
                state.epgBrowseListings = state.epgListings
            }
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
                state.liveChannels = playlist.filter(\.isLive)
            }
            return .none

        case .seriesPlaylistResponse(.failure):
            return .none

        case let .playArchive(program):
            guard state.item.tvArchive == 1 else { return .none }
            let userAgentOverride = state.item.userAgentOverride

            let archiveStart = program.startTime.addingTimeInterval(
                TimeInterval(customEPGMappingClient.getCatchupTimeShift(state.item.id) * 3600)
            )
            let startFormat = DateFormatter()
            startFormat.dateFormat = "yyyy-MM-dd:HH-mm"
            let startTimeString = startFormat.string(from: archiveStart)
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
                state.isCatchupTimelineVisible = false
                state.activeCatchupProgram = program
                return .run { _ in
                    try await playerClient.play(catchupURL, userAgentOverride, nil)
                } catch: { error, _ in
                    print("Failed to play catchup: \(error)")
                }
            }
            return .none

        case .returnToLiveStream:
            state.activeCatchupProgram = nil
            state.isCatchupTimelineVisible = false
            state.playerState = .playing
            let liveURL = state.item.streamURL
            let userAgentOverride = state.item.userAgentOverride
            return .run { _ in
                try await playerClient.play(liveURL, userAgentOverride, nil)
            } catch: { error, _ in
                print("Failed to return to live stream: \(error)")
            }

        case .toggleCatchupTimeline:
            state.isCatchupTimelineVisible.toggle()
            if state.isCatchupTimelineVisible {
                state.catchupTimeShiftHours = customEPGMappingClient.getCatchupTimeShift(state.item.id)
                state.isTracksMenuVisible = false
                state.isInfoVisible = false
                state.isStreamHealthHUDVisible = false
                state.isAudioSyncHUDVisible = false
                state.isAudioEQHUDVisible = false
                state.isRecentChannelsHUDVisible = false
                if state.epgListings.isEmpty {
                    return .send(.fetchEPG)
                }
            }
            return .none

        case let .setCatchupTimelineVisible(visible):
            state.isCatchupTimelineVisible = visible
            if visible, state.epgListings.isEmpty {
                state.catchupTimeShiftHours = customEPGMappingClient.getCatchupTimeShift(state.item.id)
                return .send(.fetchEPG)
            }
            if visible {
                state.catchupTimeShiftHours = customEPGMappingClient.getCatchupTimeShift(state.item.id)
            }
            return .none

        case let .setCatchupTimeShiftHours(hours):
            let boundedHours = min(12, max(-12, hours))
            state.catchupTimeShiftHours = boundedHours
            customEPGMappingClient.setCatchupTimeShift(state.item.id, boundedHours)
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
            if state.isTracksMenuVisible {
                state.isInfoVisible = false
                state.isStreamHealthHUDVisible = false
                state.isAudioSyncHUDVisible = false
                state.isAudioEQHUDVisible = false
                state.isCatchupTimelineVisible = false
                state.isRecentChannelsHUDVisible = false
                if state.audioTracks.isEmpty, state.subtitleTracks.isEmpty {
                    return .send(.fetchTracks)
                }
            }
            return .none

        case .fetchTracks:
            let mediaID = state.item.id
            return .run { send in
                var audio = await playerClient.getAudioTracks()
                var subtitle = await playerClient.getSubtitleTracks()

                // If tracks aren't ready immediately, progressive polling for live/VOD demuxing
                if audio.isEmpty, subtitle.isEmpty {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    audio = await playerClient.getAudioTracks()
                    subtitle = await playerClient.getSubtitleTracks()
                }
                if audio.isEmpty, subtitle.isEmpty {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    audio = await playerClient.getAudioTracks()
                    subtitle = await playerClient.getSubtitleTracks()
                }

                var selAudio = await playerClient.getSelectedAudioTrack()
                var selSubtitle = await playerClient.getSelectedSubtitleTrack()

                // Cascading Audio Selection: Channel-Specific -> Primary Language -> Secondary Fallback -> Default
                let remember = settingsClient.rememberMediaTrackPreferences()
                let legacyMediaAudio = remember ? UserDefaults.standard.string(forKey: "com.pureiptv.media_\(mediaID)_audio") : nil
                let channelAudioPref = settingsClient.getChannelPreferredAudioTrack(mediaID) ?? legacyMediaAudio
                let primaryAudioLang = settingsClient.preferredAudioLanguage()
                let secondaryAudioLang = settingsClient.secondaryAudioLanguage()

                let audioResult = AudioTrackSelector.selectAudioTrack(
                    from: audio,
                    channelPreferred: channelAudioPref,
                    primaryLanguage: primaryAudioLang,
                    secondaryLanguage: secondaryAudioLang,
                    currentTrack: selAudio
                )

                if let trackToSet = audioResult.selectedTrack, audioResult.isAutoSelected {
                    await playerClient.setAudioTrack(trackToSet)
                    selAudio = trackToSet
                    let displayName = TrackLanguageFormatter.format(trackName: trackToSet.name).titleWithFlag
                    let reasonText = audioResult.reason.map { " (\($0))" } ?? ""
                    await send(.showTrackHUD(message: "🔊 \(displayName)\(reasonText)", icon: "waveform.circle.fill"))
                } else if let trackToSet = audioResult.selectedTrack, selAudio == nil {
                    await playerClient.setAudioTrack(trackToSet)
                    selAudio = trackToSet
                }

                // Subtitle Selection: Channel-Specific -> Global Preference -> Off
                let legacyMediaSub = remember ? UserDefaults.standard.string(forKey: "com.pureiptv.media_\(mediaID)_subtitle") : nil
                let channelSubPref = settingsClient.getChannelPreferredSubtitleTrack(mediaID) ?? legacyMediaSub
                let preferredSubLang = settingsClient.preferredSubtitleLanguage()

                let subResult = AudioTrackSelector.selectSubtitleTrack(
                    from: subtitle,
                    channelPreferred: channelSubPref,
                    preferredLanguage: preferredSubLang,
                    currentTrack: selSubtitle
                )

                if subResult.isAutoSelected {
                    await playerClient.setSubtitleTrack(subResult.selectedTrack)
                    selSubtitle = subResult.selectedTrack
                    if let selTrack = subResult.selectedTrack {
                        let displayName = TrackLanguageFormatter.format(trackName: selTrack.name, isSubtitle: true).titleWithFlag
                        await send(.showTrackHUD(message: "💬 \(displayName) (Altyazı)", icon: "captions.bubble.fill"))
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
            let mediaID = state.item.id
            let displayName = trackName.map { TrackLanguageFormatter.format(trackName: $0).titleWithFlag } ?? AppStrings.Player.off
            let hudMessage = AppStrings.Player.audioTrackChanged(displayName)
            return .merge(
                .send(.showTrackHUD(message: hudMessage, icon: "waveform.circle.fill")),
                .run { _ in
                    if let trackName {
                        settingsClient.setChannelPreferredAudioTrack(mediaID, trackName)
                        if settingsClient.rememberMediaTrackPreferences() {
                            UserDefaults.standard.set(trackName, forKey: "com.pureiptv.media_\(mediaID)_audio")
                        }
                        UserDefaults.standard.set(trackName, forKey: "com.pureiptv.preferredAudioLanguage")
                        settingsClient.setPreferredAudioLanguage(trackName)
                    }
                    await playerClient.setAudioTrack(track)
                }
            )

        case let .selectSubtitleTrack(track):
            state.selectedSubtitleTrack = track
            state.isTracksMenuVisible = false
            let trackName = track?.name
            let mediaID = state.item.id
            let displayName = trackName.map { TrackLanguageFormatter.format(trackName: $0, isSubtitle: true).titleWithFlag } ?? AppStrings.Player.off
            let hudMessage = AppStrings.Player.subtitleTrackChanged(displayName)
            return .merge(
                .send(.showTrackHUD(message: hudMessage, icon: track == nil ? "captions.bubble" : "captions.bubble.fill")),
                .run { _ in
                    if let trackName {
                        settingsClient.setChannelPreferredSubtitleTrack(mediaID, trackName)
                        if settingsClient.rememberMediaTrackPreferences() {
                            UserDefaults.standard.set(trackName, forKey: "com.pureiptv.media_\(mediaID)_subtitle")
                        }
                        UserDefaults.standard.set(trackName, forKey: "com.pureiptv.preferredSubtitleLanguage")
                        settingsClient.setPreferredSubtitleLanguage(trackName)
                    } else {
                        settingsClient.setChannelPreferredSubtitleTrack(mediaID, "off")
                        if settingsClient.rememberMediaTrackPreferences() {
                            UserDefaults.standard.set("off", forKey: "com.pureiptv.media_\(mediaID)_subtitle")
                        }
                        UserDefaults.standard.set("off", forKey: "com.pureiptv.preferredSubtitleLanguage")
                        settingsClient.setPreferredSubtitleLanguage("off")
                    }
                    await playerClient.setSubtitleTrack(track)
                }
            )

        case .toggleAudioEQHUD:
            state.isAudioEQHUDVisible.toggle()
            if state.isAudioEQHUDVisible {
                state.isTracksMenuVisible = false
                state.isInfoVisible = false
                state.isStreamHealthHUDVisible = false
                state.isAudioSyncHUDVisible = false
                state.isCatchupTimelineVisible = false
                state.isRecentChannelsHUDVisible = false
            }
            return .none

        case let .setAudioEQHUDVisible(visible):
            state.isAudioEQHUDVisible = visible
            return .none

        case let .selectAudioEQPreset(preset):
            state.audioEQPreset = preset
            let mediaID = state.item.id
            settingsClient.setChannelAudioEQPreset(mediaID, preset)
            settingsClient.setAudioEQPreset(preset)
            let hudMessage = "🎛️ Ses Modu: \(preset.title)"
            return .merge(
                .send(.showTrackHUD(message: hudMessage, icon: preset.icon)),
                .run { _ in
                    await playerClient.setEqualizerPreset(preset)
                }
            )

        case .loadAudioEQPreferences:
            let mediaID = state.item.id
            let activePreset = settingsClient.getChannelAudioEQPreset(mediaID) ?? settingsClient.audioEQPreset()
            state.audioEQPreset = activePreset
            return .run { _ in
                await playerClient.setEqualizerPreset(activePreset)
            }

        case let .handlePlayerEvent(event):
            // Handle different VLC events
            switch event {
            case let .stateChanged(newState):
                state.playerState = newState
                if newState == .playing {
                    state.retryCount = 0 // Reset on successful play
                    state.isReconnecting = false
                    state.errorMessage = nil
                    state.failedStreamIDs.removeAll()
                    var actions: [Effect<Action>] = [
                        .cancel(id: CancelID.stallWatchdog),
                        .cancel(id: CancelID.reconnectTimer),
                    ]

                    LiveStreamActivityManager.shared.startStreamActivity(
                        channelTitle: state.item.title,
                        programTitle: state.currentEPGProgram?.title,
                        categoryName: state.item.seriesTitle
                    )
                    if let playlistID = state.item.config?.playlistID {
                        let mediaKind: StreamHandoffRequest.MediaKind = if state.item.isLive {
                            .live
                        } else if state.item.seriesID != nil {
                            .episode
                        } else {
                            .vod
                        }
                        StreamHandoffManager.shared.updatePlaybackActivity(
                            StreamHandoffRequest(
                                playlistID: playlistID,
                                itemID: state.item.id,
                                mediaKind: mediaKind,
                                seriesID: state.item.seriesID,
                                seriesTitle: state.item.seriesTitle,
                                categoryID: state.item.categoryID?.isEmpty == false ? state.item.categoryID : nil,
                                playbackPosition: state.position,
                                title: state.item.title
                            )
                        )
                    } else {
                        StreamHandoffManager.shared.invalidateActivity()
                    }
                    CompanionModeManager.shared.broadcastPlayback(
                        info: CompanionPlaybackInfo(
                            channelID: state.item.id,
                            channelTitle: state.item.title,
                            programTitle: state.currentEPGProgram?.title,
                            isPlaying: true
                        )
                    )

                    state.isTransitioningEpisode = false

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
                } else if newState == .buffering || newState == .opening {
                    if !state.isUserPaused {
                        return .run { send in
                            try await Task.sleep(nanoseconds: 12_000_000_000)
                            await send(.streamStalled)
                        }
                        .cancellable(id: CancelID.stallWatchdog, cancelInFlight: true)
                    }
                } else if newState == .stopped {
                    if state.item.isLive, !state.isUserPaused, !state.isMinimized {
                        return .send(.initiateAutoReconnect)
                    }
                } else if newState == .error {
                    state.isTransitioningEpisode = false
                    return .send(.initiateAutoReconnect)
                }
            case .endReached:
                if state.item.isLive, !state.isUserPaused, !state.isMinimized {
                    return .send(.initiateAutoReconnect)
                } else if !state.item.isLive {
                    if settingsClient.autoPlayNextEpisode(), !state.isTransitioningEpisode {
                        return .send(.playNextEpisode)
                    }
                }
            case .encounteredError:
                state.isTransitioningEpisode = false
                return .send(.initiateAutoReconnect)
            case let .timeChanged(time):
                state.currentTime = time
                if state.item.epgChannelID == nil, state.totalTime.components.seconds == 0, state.position > 0.001, time.components.seconds > 0 {
                    let totalSecs = Double(time.components.seconds) / state.position
                    state.totalTime = Duration.seconds(totalSecs)
                }
                return updateUpNextState(state: &state, settingsClient: settingsClient)
            case let .lengthChanged(length):
                state.totalTime = length
                return updateUpNextState(state: &state, settingsClient: settingsClient)
            case let .positionChanged(pos):
                state.position = pos
                if state.item.epgChannelID == nil, state.totalTime.components.seconds == 0, pos > 0.001, state.currentTime.components.seconds > 0 {
                    let totalSecs = Double(state.currentTime.components.seconds) / pos
                    state.totalTime = Duration.seconds(totalSecs)
                }

                var effects: [Effect<Action>] = [
                    updateUpNextState(state: &state, settingsClient: settingsClient),
                ]

                // Trakt.tv VOD scrobble progress detection (Madde #17)
                if !state.item.isLive {
                    let curSecs = Double(state.currentTime.components.seconds)
                    let pct = pos * 100.0
                    if curSecs >= 10, !state.isTraktScrobbleStarted {
                        state.isTraktScrobbleStarted = true
                        state.lastTraktScrobbleProgress = pct
                        effects.append(.send(.traktScrobbleStart))
                    } else if pct >= 80.0, state.lastTraktScrobbleProgress < 80.0 {
                        state.lastTraktScrobbleProgress = pct
                        effects.append(.send(.traktScrobbleStop))
                    }
                }

                return .merge(effects)
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
            let profileScope = profileContextClient.snapshot()
            let isPiPActive = state.isPiPActive
            return .merge(
                .cancel(id: CancelID.playerEvents),
                .cancel(id: CancelID.channelOSD),
                .cancel(id: CancelID.statsTimer),
                .cancel(id: CancelID.stallWatchdog),
                .cancel(id: CancelID.reconnectTimer),
                .run { send in
                    // Save Watch History before stopping
                    if currentSecs > 10 { // Only save if watched for more than 10 seconds
                        let type = item.seriesTitle == nil ? "vod" : "episode"
                        let historyItem = WatchHistoryItem(
                            id: item.id,
                            type: type,
                            title: item.title,
                            seriesTitle: item.seriesTitle,
                            coverURL: item.coverURL?.absoluteString,
                            streamURL: item.streamURL.absoluteString,
                            progress: currentSecs,
                            duration: totalSecs,
                            playlistID: item.config?.playlistID,
                            seriesID: item.seriesID
                        )
                        // Retain completed progress as the watched marker;
                        // detail screens can then let the user reset it.
                        try? await databaseClient.saveWatchProgress(historyItem, profileScope)

                        // Trakt.tv scrobble stop on close (Madde #17)
                        if !item.isLive {
                            let pct = totalSecs > 0 ? (currentSecs / totalSecs) * 100.0 : 0.0
                            if let payload = TraktMediaParser.makePayload(title: item.title, seriesTitle: item.seriesTitle, isLive: item.isLive, progress: pct) {
                                _ = try? await traktClient.scrobbleStop(payload)
                            }
                        }
                    }

                    if !isPiPActive {
                        try? await playerClient.stop()
                        await playerClient.release()
                    }

                    await MainActor.run {
                        LiveStreamActivityManager.shared.endStreamActivity()
                        StreamHandoffManager.shared.invalidateActivity()
                        CompanionModeManager.shared.clearPlayback()
                        #if os(iOS)
                            OrientationManager.shared.unlockPortrait()
                        #endif
                    }

                    await send(.delegate(.didClose))
                }
            )

        case .delegate:
            return .none

        case .minimizeTapped:
            guard !state.isMinimized else { return .none }
            state.isMinimized = true
            return .run { send in
                await send(.delegate(.didRequestMinimize))
                await MainActor.run {
                    #if os(iOS)
                        OrientationManager.shared.unlockPortrait()
                    #endif
                }
            }

        case .sharePlayTapped:
            let activity = PureIPTVSharePlayActivity(
                itemID: state.item.id,
                title: state.item.title,
                streamURLString: state.item.streamURL.absoluteString,
                type: state.item.isLive ? "live" : "vod"
            )
            return .run { _ in
                _ = try? await activity.activate()
            }

        // ── PiP & Background Playback Engine (Madde #18) ───────────────────────────
        case .togglePiP:
            state.shouldTriggerPiP = true
            return .none

        case .resetPiPTrigger:
            state.shouldTriggerPiP = false
            return .none

        case let .onPiPStatusChanged(isActive):
            state.isPiPActive = isActive
            return .none

        case let .setAutoPiPEnabled(enabled):
            state.isAutoPiPEnabled = enabled
            return .run { _ in pipClient.setAutoPiPEnabled(enabled) }

        case let .setBackgroundPlaybackMode(mode):
            state.backgroundPlaybackMode = mode
            return .run { _ in pipClient.setBackgroundPlaybackMode(mode) }

        case .appMovedToBackground:
            switch state.backgroundPlaybackMode {
            case .pip:
                if state.isAutoPiPEnabled, state.isPiPSupported, state.playerState == .playing {
                    state.shouldTriggerPiP = true
                }
                return .none
            case .audioOnly:
                if state.playerState == .playing {
                    state.isBackgroundAudioActive = true
                }
                return .none
            case .disabled:
                return .run { send in
                    await send(.pause)
                }
            }

        case .appMovedToForeground:
            state.isBackgroundAudioActive = false
            return .none

        case .pipStarted:
            state.isPiPActive = true
            return .none

        case .pipStopped:
            state.isPiPActive = false
            #if os(iOS)
                if UIApplication.shared.applicationState == .background {
                    if state.backgroundPlaybackMode == .audioOnly {
                        state.isBackgroundAudioActive = true
                        return .none
                    } else {
                        return .run { send in
                            try? await playerClient.stop()
                            await playerClient.release()
                            await send(.delegate(.didClose))
                        }
                    }
                } else {
                    return .none
                }
            #else
                return .none
            #endif

        case .pipRestoreUI:
            // PiP floating window'dan "geri dön" tıklandı → full-screen'e dön
            state.isPiPActive = false
            state.isControlsVisible = true
            state.oledInactivitySeconds = 0
            return .run { _ in
                #if os(iOS)
                    await MainActor.run {
                        OrientationManager.shared.lockLandscape()
                    }
                #endif
            }

        // ── Up Next Episode Auto-Play (Madde #48 / #42) ──
        case .showUpNext:
            guard state.nextEpisodeItem != nil, !state.isUpNextVisible, !state.isUpNextDismissed else { return .none }
            state.isUpNextVisible = true
            let total = Double(state.totalTime.components.seconds)
            let current = Double(state.currentTime.components.seconds)
            let remaining = max(1, Int(total - current))
            state.upNextInitialSeconds = remaining
            state.upNextCountdownSeconds = remaining
            return .none

        case .dismissUpNext:
            state.isUpNextVisible = false
            state.isUpNextDismissed = true
            return .cancel(id: CancelID.upNextCountdown)

        case .playNextEpisode:
            guard !state.isTransitioningEpisode else { return .none }
            guard let next = state.nextEpisodeItem else {
                state.isUpNextVisible = false
                return .cancel(id: CancelID.upNextCountdown)
            }
            state.isTransitioningEpisode = true
            state.isUpNextVisible = false
            state.isUpNextDismissed = false
            return .merge(
                .cancel(id: CancelID.upNextCountdown),
                .send(.selectChannel(next))
            )

        case .upNextCountdownTick:
            return .none

        case let .openInExternalPlayer(player):
            #if canImport(UIKit)
                let url = state.item.streamURL
                _ = ExternalPlayerManager.shared.openStream(url, in: player)
            #endif
            return .none

        // ── Channel Hide & Category Blacklist (Madde #19) ──
        case .loadHiddenContentPreferences:
            state.hiddenChannelIDs = parentalControlClient.hiddenChannelIDs()
            state.blacklistedCategoryIDs = parentalControlClient.blacklistedCategoryIDs()
            return .none

        case let .hideChannel(id, title):
            parentalControlClient.hideChannel(id, title)
            state.hiddenChannelIDs.insert(id)
            if state.item.id == id {
                if let playlist = state.playlist, let next = playlist.first(where: { !state.hiddenChannelIDs.contains($0.id) }) {
                    return .send(.selectChannel(next))
                }
            }
            return .none

        case let .unhideChannel(id):
            parentalControlClient.unhideChannel(id)
            state.hiddenChannelIDs.remove(id)
            return .none

        case .hideCurrentChannel:
            return .send(.hideChannel(id: state.item.id, title: state.item.title))

        case .jumpToNextCategory:
            guard let playlist = state.playlist, !playlist.isEmpty else { return .none }
            let categories = Array(Set(playlist.compactMap(\.categoryID))).sorted()
            guard categories.count > 1, let currentCat = state.item.categoryID,
                  let currentIdx = categories.firstIndex(of: currentCat) else { return .none }
            let nextCat = categories[(currentIdx + 1) % categories.count]
            if let firstInNext = playlist.first(where: { $0.categoryID == nextCat }) {
                return .send(.selectChannel(firstInNext))
            }
            return .none

        case .jumpToPreviousCategory:
            guard let playlist = state.playlist, !playlist.isEmpty else { return .none }
            let categories = Array(Set(playlist.compactMap(\.categoryID))).sorted()
            guard categories.count > 1, let currentCat = state.item.categoryID,
                  let currentIdx = categories.firstIndex(of: currentCat) else { return .none }
            let prevIdx = (currentIdx - 1 + categories.count) % categories.count
            let prevCat = categories[prevIdx]
            if let firstInPrev = playlist.first(where: { $0.categoryID == prevCat }) {
                return .send(.selectChannel(firstInPrev))
            }
            return .none

        // ── HDR, Dolby Vision & SDR Dynamic Range Indicator (Madde #20) ──
        case .detectDynamicRange:
            let info = ColorSpaceDetector.detectFromText(title: state.item.title, urlString: state.item.streamURL.absoluteString)
            return .send(.dynamicRangeDetected(info))

        case let .dynamicRangeDetected(info):
            state.dynamicRangeInfo = info
            state.videoDynamicRange = info.range
            if info.range.isHDR {
                state.isDynamicRangeHUDVisible = true
                return .run { send in
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    await send(.hideDynamicRangeHUD)
                }.cancellable(id: CancelID.dynamicRangeHUD, cancelInFlight: true)
            }
            return .none

        case .showDynamicRangeHUD:
            state.isDynamicRangeHUDVisible = true
            return .run { send in
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                await send(.hideDynamicRangeHUD)
            }.cancellable(id: CancelID.dynamicRangeHUD, cancelInFlight: true)

        case .hideDynamicRangeHUD:
            state.isDynamicRangeHUDVisible = false
            return .cancel(id: CancelID.dynamicRangeHUD)

        // ── Auto Frame Rate & Match Dynamic Range (Madde #21) ──
        case .loadAFRPreferences:
            state.isAFREnabledForLive = displayModeClient.isAFREnabledForLive()
            state.isAFREnabledForVOD = displayModeClient.isAFREnabledForVOD()
            state.isMatchDynamicRangeEnabled = displayModeClient.isMatchDynamicRangeEnabled()
            return .none

        case let .setAFREnabledForLive(enabled):
            state.isAFREnabledForLive = enabled
            displayModeClient.setAFREnabledForLive(enabled)
            return .none

        case let .setAFREnabledForVOD(enabled):
            state.isAFREnabledForVOD = enabled
            displayModeClient.setAFREnabledForVOD(enabled)
            return .none

        case let .setMatchDynamicRangeEnabled(enabled):
            state.isMatchDynamicRangeEnabled = enabled
            displayModeClient.setMatchDynamicRangeEnabled(enabled)
            return .none

        case .matchDisplayMode:
            guard state.isAFREnabledForCurrentItem else { return .none }
            let detectedFPS = state.currentFrameRate ?? FrameRateDetector.detect(
                title: state.item.title,
                urlString: state.item.streamURL.absoluteString,
                isLive: state.item.isLive
            )
            state.currentFrameRate = detectedFPS
            let dRange = state.videoDynamicRange ?? .sdr

            return .run { [displayModeClient] send in
                let result = await displayModeClient.switchDisplayMode(detectedFPS.rawValue, dRange)
                await send(.displayModeSwitched(result))
            }

        case let .displayModeSwitched(result):
            state.afrMatchResult = result
            state.isAFRToastVisible = true
            return .run { send in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await send(.hideAFRToast)
            }.cancellable(id: CancelID.afrToast, cancelInFlight: true)

        case let .showAFRToast(result):
            state.afrMatchResult = result
            state.isAFRToastVisible = true
            return .run { send in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await send(.hideAFRToast)
            }.cancellable(id: CancelID.afrToast, cancelInFlight: true)

        case .hideAFRToast:
            state.isAFRToastVisible = false
            return .cancel(id: CancelID.afrToast)
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

    // MARK: - Failover Source Matching Helpers

    static func cleanChannelTitle(_ title: String) -> String {
        var cleaned = title.lowercased()
        let tagsToRemove = [
            "fhd", "uhd", "4k", "8k", "hevc", "h.265", "h265", "h.264", "h264",
            "hd", "sd", "1080p", "720p", "50fps", "60fps", "raw", "vip", "backup",
        ]
        for tag in tagsToRemove {
            cleaned = cleaned.replacingOccurrences(of: tag, with: " ")
        }
        let punctuation = CharacterSet(charactersIn: ":|[]()-–_.")
        let components = cleaned.components(separatedBy: punctuation)
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 1 }
        return components.joined(separator: " ")
    }

    static func areChannelsRelated(_ titleA: String, _ titleB: String) -> Bool {
        let cleanA = cleanChannelTitle(titleA)
        let cleanB = cleanChannelTitle(titleB)
        if cleanA == cleanB {
            return true
        }
        if !cleanA.isEmpty, !cleanB.isEmpty {
            if cleanA.contains(cleanB) || cleanB.contains(cleanA) {
                return true
            }
        }
        return false
    }

    /// Matches source variants only when their normalized channel names agree
    /// exactly. The broader relation above remains reserved for automatic
    /// recovery, where a fuzzy best-effort match is preferable to a dead end.
    static func areAlternativeSources(_ titleA: String, _ titleB: String) -> Bool {
        let ignoredTokens: Set = [
            "fhd", "uhd", "4k", "8k", "hevc", "h265", "h264", "hd", "sd",
            "1080p", "1080i", "2160p", "720p", "50fps", "60fps", "raw", "vip", "backup",
        ]
        func key(_ title: String) -> String {
            var tokens = title
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }

            var index = 0
            while index + 1 < tokens.count {
                if tokens[index] == "h", tokens[index + 1] == "264" || tokens[index + 1] == "265" {
                    tokens.removeSubrange(index ... index + 1)
                } else {
                    index += 1
                }
            }

            return tokens.filter { !ignoredTokens.contains($0) }.joined(separator: " ")
        }
        let lhs = key(titleA)
        return !lhs.isEmpty && lhs == key(titleB)
    }

    // MARK: - Up Next Episode State Synchronization Helper

    private static func updateUpNextState(state: inout State, settingsClient: SettingsClient) -> Effect<Action> {
        guard !state.item.isLive, state.nextEpisodeItem != nil, settingsClient.autoPlayNextEpisode() else {
            if state.isUpNextVisible {
                state.isUpNextVisible = false
            }
            return .none
        }

        let total = Double(state.totalTime.components.seconds)
        let current = Double(state.currentTime.components.seconds)
        guard total > 60 else { return .none }

        let remaining = max(0, Int(total - current))

        if remaining <= 15, remaining > 0 {
            if !state.isUpNextDismissed {
                if !state.isUpNextVisible {
                    state.isUpNextVisible = true
                    state.upNextInitialSeconds = max(remaining, 1)
                }
                state.upNextCountdownSeconds = remaining
            }
        } else if remaining > 18 {
            // User scrubbed backward away from the ending threshold
            if state.isUpNextVisible {
                state.isUpNextVisible = false
            }
            state.isUpNextDismissed = false
        } else if remaining <= 0 {
            if state.isUpNextVisible, !state.isTransitioningEpisode {
                state.isUpNextVisible = false
                return .send(.playNextEpisode)
            }
        }
        return .none
    }
}
