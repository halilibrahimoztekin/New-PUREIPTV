import ComposableArchitecture
import CoreGraphics
import CryptoKit
import Dispatch
import FactoryKit
import Foundation
import GroupActivities
import SwiftUI
import SwiftVLC
#if canImport(UIKit)
    import UIKit
#endif

@Reducer
public struct PlayerFeature {
    public enum CancelID {
        public static let playerEvents = "PlayerFeature.playerEvents"
        public static let nowPlayingCommands = "PlayerFeature.nowPlayingCommands"
        public static let nowPlayingMetadata = "PlayerFeature.nowPlayingMetadata"
        public static let mediaServerPlaybackStatus = "PlayerFeature.mediaServerPlaybackStatus"
        public static let mediaServerPlaybackOptions = "PlayerFeature.mediaServerPlaybackOptions"
        public static let playbackEngineSwitch = "PlayerFeature.playbackEngineSwitch"
        public static let statsTimer = "PlayerFeature.statsTimer"
        public static let liveVideoStallMonitor = "PlayerFeature.liveVideoStallMonitor"
        public static let sleepTimer = "PlayerFeature.sleepTimer"
        public static let seriesPlaylist = "PlayerFeature.seriesPlaylist"
        public static let oledDimTimer = "PlayerFeature.oledDimTimer"
        public static let audioRoute = "PlayerFeature.audioRoute"
        public static let audioRouteHUD = "PlayerFeature.audioRouteHUD"
        public static let trackHUD = "PlayerFeature.trackHUD"
        public static let upNextCountdown = "PlayerFeature.upNextCountdown"
        public static let offlineEpisodeAvailability = "PlayerFeature.offlineEpisodeAvailability"
        public static let aspectFeedback = "PlayerFeature.aspectFeedback"
        public static let channelOSD = "PlayerFeature.channelOSD"
        public static let sourcePlaylistName = "PlayerFeature.sourcePlaylistName"
        public static let lockPill = "PlayerFeature.lockPill"
        public static let stallWatchdog = "PlayerFeature.stallWatchdog"
        public static let reconnectTimer = "PlayerFeature.reconnectTimer"
        public static let recentChannelsHUD = "PlayerFeature.recentChannelsHUD"
        public static let recallHUD = "PlayerFeature.recallHUD"
        public static let dialerAutoSubmit = "PlayerFeature.dialerAutoSubmit"
        public static let dynamicRangeHUD = "PlayerFeature.dynamicRangeHUD"
        public static let afrToast = "PlayerFeature.afrToast"
        public static let displayMode = "PlayerFeature.displayMode"
        public static let epgBrowse = "PlayerFeature.epgBrowse"
        public static let epgFetch = "PlayerFeature.epgFetch"
        public static let channelSwitch = "PlayerFeature.channelSwitch"
        public static let scrubThumbnail = "PlayerFeature.scrubThumbnail"
        public static let catchupSeek = "PlayerFeature.catchupSeek"
        public static let catchupSeekFeedback = "PlayerFeature.catchupSeekFeedback"
        public static let vodSeek = "PlayerFeature.vodSeek"
        public static let vodSeekFeedback = "PlayerFeature.vodSeekFeedback"
        public static let initialResumeSeekVerification = "PlayerFeature.initialResumeSeekVerification"
        public static let subtitleReplaySeek = "PlayerFeature.subtitleReplaySeek"
        public static let subtitleReplayTrackSelection = "PlayerFeature.subtitleReplayTrackSelection"
        public static let xtreamLiveOutputFormats = "PlayerFeature.xtreamLiveOutputFormats"
        public static let highFPSFeedback = "PlayerFeature.highFPSFeedback"
        public static let subtitleSearchTrackInstall = "PlayerFeature.subtitleSearchTrackInstall"
        public static let recordingMonitor = "PlayerFeature.recordingMonitor"
        public static let recordingStatus = "PlayerFeature.recordingStatus"
        public static let recordingStopTimeout = "PlayerFeature.recordingStopTimeout"
        public static let skipMarkerLoad = "PlayerFeature.skipMarkerLoad"
        public static let deinterlaceModeChange = "PlayerFeature.deinterlaceModeChange"
        public static let memoryPressureWarnings = "PlayerFeature.memoryPressureWarnings"
        public static let memoryPressureDeinterlaceFallback = "PlayerFeature.memoryPressureDeinterlaceFallback"
    }

    public struct PlayableItem: Equatable, Sendable {
        public let id: String
        public let title: String
        public let seriesTitle: String?
        public let streamURL: URL
        public let coverURL: URL?
        public let fallbackCoverURL: URL?
        public let seriesID: String?
        public let episodeOrdinal: Int?
        public let seasonNumber: Int?
        public let episodeNumber: Int?
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
            fallbackCoverURL: URL? = nil,
            seriesID: String? = nil,
            episodeOrdinal: Int? = nil,
            seasonNumber: Int? = nil,
            episodeNumber: Int? = nil,
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
            self.fallbackCoverURL = fallbackCoverURL
            self.seriesID = seriesID
            self.episodeOrdinal = episodeOrdinal
            self.seasonNumber = seasonNumber
            self.episodeNumber = episodeNumber
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
                fallbackCoverURL: fallbackCoverURL,
                seriesID: seriesID,
                episodeOrdinal: episodeOrdinal,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
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
                fallbackCoverURL: fallbackCoverURL,
                seriesID: seriesID,
                episodeOrdinal: episodeOrdinal,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
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

        public func replacingLiveStreamURL(_ value: URL, playlistConfig: PlaylistConfig? = nil) -> Self {
            let resolvedConfig = playlistConfig ?? config
            return Self(
                id: id,
                title: title,
                seriesTitle: seriesTitle,
                streamURL: value,
                coverURL: coverURL,
                fallbackCoverURL: fallbackCoverURL,
                seriesID: seriesID,
                episodeOrdinal: episodeOrdinal,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                startPosition: startPosition,
                initialDuration: initialDuration,
                initialProgress: initialProgress,
                isLive: isLive,
                config: resolvedConfig,
                epgChannelID: epgChannelID,
                tvArchive: tvArchive,
                categoryID: categoryID,
                userAgentOverride: resolvedConfig?.userAgentOverride ?? userAgentOverride
            )
        }
    }

    @ObservableState
    public struct State: Equatable {
        public struct SubtitleReplaySession: Equatable, Sendable {
            public let requestID: UUID
            public let itemID: String
            public let playbackRequestID: UUID
            public let restoreAt: Duration
            public let originalSubtitleTrackID: String?
            public var temporarySubtitleTrackID: String?

            public init(
                requestID: UUID,
                itemID: String,
                playbackRequestID: UUID,
                restoreAt: Duration,
                originalSubtitleTrackID: String?,
                temporarySubtitleTrackID: String? = nil
            ) {
                self.requestID = requestID
                self.itemID = itemID
                self.playbackRequestID = playbackRequestID
                self.restoreAt = restoreAt
                self.originalSubtitleTrackID = originalSubtitleTrackID
                self.temporarySubtitleTrackID = temporarySubtitleTrackID
            }
        }

        public var item: PlayableItem
        public var playlist: [PlayableItem]?
        public var liveChannels: [PlayableItem] = []
        public var isChannelListVisible: Bool = false
        public var isMinimized: Bool = false
        public var isAppInBackground: Bool = false
        public var isClosing: Bool = false

        public var playerState: PlayerState = .stopped
        public var isNowPlayingSuppressed = false
        public var nowPlayingGeneration: UInt64 = 0
        public var playbackEngine: PlaybackEngine = .vlc
        public var deinterlaceMode: DeinterlaceMode = .automatic
        public var deinterlaceModeRequestID: UUID?
        public var deinterlaceModeRevision = UUID()
        public var isDeinterlaceModeKnown = true
        public var memoryPressureDeinterlaceFallbackRequestID: UUID?
        public var isSwitchingPlaybackEngine = false
        public var playbackEngineSwitchID: UUID?
        var playbackEngineSwitchProfileID: UUID?
        public var playbackEngineError: String?
        var rememberedPlaybackChoice: PlaybackChoiceReminder?
        var didLoadRememberedPlaybackChoice = false
        var rememberedPlaybackChoiceProfileScope: ProfileContextSnapshot?
        public var itemSpecificPlaybackEnginePreference: PlaybackEngine?
        var dismissedRememberedPlaybackChoiceScopeKeys: Set<String> = []
        public var isControlsVisible: Bool = true
        public var errorMessage: String?
        public var didRequestXtreamLiveOutputFormats = false
        public var isLoadingXtreamLiveOutputFormats = false
        public var xtreamLiveOutputFormatOptions: [XtreamLiveOutputFormat] = []
        public var xtreamLiveOutputFormatError: String?
        public var activeXtreamLiveOutputFormatRequestID: UUID?
        public var playbackRecoveryErrorMessage: String?
        public var playbackPositionRecoveryRequestID: UUID?
        public var playbackPositionRecoveryExpectedPosition: Double?
        public var isRecording: Bool = false
        public var isRecordingStartPending: Bool = false
        public var isRecordingStopPending: Bool = false
        public var recordingFilePath: String?
        public var recordingStartedAt: Date?
        public var recordingStatusMessage: String?

        // New properties for video features
        public var currentTime: Duration = .zero
        public var totalTime: Duration = .zero
        public var position: Double = 0.0
        var viewingStatisticsProfileID: UUID?
        var viewingStatisticsMedia: ViewingStatisticsMedia?
        var viewingStatisticsLastPlaybackSeconds: Double?
        var viewingStatisticsLastWallTime: TimeInterval?
        var viewingStatisticsPendingSeconds: Double = 0
        public var skipMarkers = PlaybackSkipMarkers()
        public var skipMarkerRequestID: UUID?
        public var skipMarkersProfileScope: ProfileContextSnapshot?
        public var isSkipMarkersLoading = false
        public var skipMarkerSaveRevision: UInt64 = 0
        public var scrubThumbnailData: Data?
        public var scrubThumbnailRequestID: UUID?
        public var mediaInfo: MediaInfo?
        public var mediaInfoRequestID: UUID?
        public var playbackRequestID = UUID()
        public var speedTestPresentationRequestID: UUID?
        public var subtitleSearchPresentationRequestID: UUID?
        public var subtitleSearchTrackInstallRequestID: UUID?
        public var subtitleSearchTrackInstallErrorMessage: String?
        public var firstPresentedFrameLatency: Duration?
        public var firstPresentedFrameFeedbackRequestID: UUID?
        public var activeVODSeekRequestID: UUID?
        public var restartPlaybackAfterVODSeekRequestID: UUID?
        public var restartPlaybackAfterCatchupSeekRequestID: UUID?
        public var expectedVODSeekTargetSeconds: Double?
        public var expectedVODSeekTargetPosition: Double?
        public var vodSeekPreviousPosition: Double?
        public var vodSeekPreviousTime: Duration?
        public var vodSeekFailureRequestID: UUID?
        public var vodSeekTimelineRecoveryRequired = false
        public var isInfoVisible: Bool = false
        public var lastDragTranslation: CGSize = .zero
        public var lastDragScreenWidth: CGFloat = 1.0

        // EPG
        public var epgListings: [EPGProgram] = []
        public var isEPGVisible: Bool = false
        public var isEPGLoading: Bool = false
        public var epgRequestID: UUID?
        public var epgPreviewCorner: EPGPreviewCorner = .topRight
        public var epgBrowseChannel: PlayableItem?
        public var epgBrowseListings: [EPGProgram] = []
        public var isEPGBrowseLoading = false

        // Tracks
        public var audioTracks: [Track] = []
        public var subtitleTracks: [Track] = []
        public var externalSubtitleTrackIDs: Set<String> = []
        public var selectedAudioTrack: Track?
        public var selectedSubtitleTrack: Track?
        public var subtitleReplaySession: SubtitleReplaySession?
        public var audioDelay: Int = 0
        public var subtitleDelay: Int = 0
        public var isShowingStats: Bool = false
        public var playerStats: String = ""
        public var streamHealthMetrics: StreamHealthMetrics?
        public var streamHealthGenerationID = UUID()
        public var isLiveVideoStallDetected = false
        public var liveVideoStallMonitorID = UUID()
        public var liveVideoStallLastCounters: PlayerPlaybackCounters?
        public var liveVideoStallLastSampleUptimeNanoseconds: UInt64?
        public var liveVideoStallLastPlaybackTime: Duration?
        public var liveVideoStallLastClockAdvanceUptimeNanoseconds: UInt64?
        public var liveVideoStallNoFrameStartUptimeNanoseconds: UInt64?
        public var activePlaybackURL: URL
        public var mediaServerProxyURL: URL?
        public var mediaServerPlaybackRequestID: UUID?
        public var mediaServerPlaybackOptionsRequestID: UUID?
        public var mediaServerPlaybackOptionsCheckedItemID: String?
        public var mediaServerPlaybackOptions: [MediaModels.MediaServerPlaybackOption] = []
        public var isMediaServerPlaybackOptionsPresented = false
        public var selectedMediaServerPlaybackSourceID: String?
        public var mediaServerPlaybackStatus: MediaModels.ServerPlaybackStatus?
        public var mediaServerPlaybackStatusRequestID: UUID?
        public var hasAttemptedMediaServerPlaybackStatus = false
        public var isStreamHealthHUDVisible: Bool = false
        public var activeCatchupProgram: EPGProgram?
        public var activeCatchupSeekRequestID: UUID?
        public var catchupSeekPreviousTime: Duration?
        public var catchupSeekPreviousPosition: Double?
        public var catchupSeekExpectedTimeSeconds: Double?
        public var catchupSeekExpectedPosition: Double?
        public var catchupSeekTimelineRecoveryRequired = false
        public var catchupSeekFailureMessage: String?
        public var catchupSeekFailureRequestID: UUID?
        public var catchupSkipInterval: PlaybackSkipInterval = .minute
        public var vodSkipInterval: PlaybackSkipInterval = .seconds10
        public var catchupArchiveDurationSeconds: Double?
        public var isPlayingCatchup: Bool {
            activeCatchupProgram != nil
        }

        public var canReplayWithSubtitles: Bool {
            guard playbackEngine == .vlc,
                  !isSwitchingPlaybackEngine,
                  !isMinimized,
                  !isClosing,
                  !isUserPaused,
                  playerState == .playing || playerState == .buffering,
                  subtitleReplaySession == nil,
                  activeVODSeekRequestID == nil,
                  activeCatchupSeekRequestID == nil,
                  currentTime > .zero,
                  subtitleTracks.contains(where: { $0.id != "-1" })
            else { return false }

            let duration: Duration
            if isPlayingCatchup {
                guard let archiveDuration = catchupArchiveDurationSeconds,
                      archiveDuration.isFinite,
                      archiveDuration > 0
                else { return false }
                duration = .seconds(archiveDuration)
            } else {
                guard !item.isLive, totalTime > .zero else { return false }
                duration = totalTime
            }
            return currentTime <= duration
        }

        public var playbackContentKind: PlaybackContentKind {
            PlaybackContentKind.resolve(isLive: item.isLive, isArchive: isPlayingCatchup)
        }

        public var skipIntervalSeconds: Int64 {
            if isPlayingCatchup {
                return Int64(catchupSkipInterval.rawValue)
            }
            return item.isLive ? 15 : Int64(vodSkipInterval.rawValue)
        }

        public var activeSkipInterval: PlaybackSkipInterval {
            isPlayingCatchup ? catchupSkipInterval : vodSkipInterval
        }

        public var isHighFrameRateVOD: Bool {
            guard !item.isLive, !isPlayingCatchup, playbackEngine == .vlc,
                  let frameRate = mediaInfo?.reportedFrameRate,
                  frameRate.isFinite
            else { return false }
            return frameRate >= 48
        }

        public var firstPresentedFrameLatencySeconds: Double? {
            guard let firstPresentedFrameLatency else { return nil }
            let components = firstPresentedFrameLatency.components
            let seconds = Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
            return seconds.isFinite && seconds >= 0 ? seconds : nil
        }

        public var canSwitchPlaybackEngine: Bool {
            guard item.config?.type != .plex, item.config?.type != .emby else { return false }
            let path = item.streamURL.pathExtension.lowercased()
            let sharedRequirements = !item.isLive && activeCatchupProgram == nil && !isMinimized && !isPiPActive
                && !isRecording
                && ["m3u8", "mp4", "m4v"].contains(path)
                && ["http", "https"].contains(item.streamURL.scheme?.lowercased() ?? "")
                && item.userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
            guard sharedRequirements else { return false }
            return playbackEngine == .avPlayer || (audioEQPreset == .flat && audioDelay == 0 && subtitleDelay == 0)
        }

        public var canManagePlaybackEnginePreference: Bool {
            SpecificPlaybackEnginePreferenceStore.scopeKey(item: item, profileID: nil) != nil
                && (canSwitchPlaybackEngine || itemSpecificPlaybackEnginePreference != nil)
        }

        public var canManageSkipMarkers: Bool {
            !item.isLive
                && !item.id.isEmpty
                && item.config?.playlistID != nil
                && skipMarkersProfileScope?.profileID != nil
                && !isSkipMarkersLoading
        }

        public var activeSkipMarkerKind: PlaybackSkipMarkerKind? {
            guard canManageSkipMarkers else { return nil }
            let duration = Double(totalTime.components.seconds)
            let seconds = Double(currentTime.components.seconds)
            if skipMarkers.intro.isValid(duration: duration), skipMarkers.intro.contains(seconds) {
                return .intro
            }
            if skipMarkers.credits.isValid(duration: duration), skipMarkers.credits.contains(seconds) {
                return .credits
            }
            return nil
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
        public var canSetPlaybackRate: Bool {
            !item.isLive && !isPlayingCatchup && !isSwitchingPlaybackEngine
        }

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
        public var initialResumeSeekRetryCount: Int = 0
        public var pendingInitialResumeSeekTargetSeconds: Double?
        public var isDispatchingInitialResumeSeek = false

        /// OLED & Dark Room Dimming
        public var isOLEDDimmingEnabled: Bool = true
        public var oledDimLevel: Double = 0.0
        public var isDeepDimmed: Bool = false
        public var oledInactivitySeconds: Int = 0

        /// Smart Channel Name Cleaner (Madde #16)
        public var isChannelNameCleaningEnabled: Bool = true
        public var autoSelectFirstAlternativeSource: Bool = false
        public var reverseChannelZappingDirection: Bool = false

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
        public var isAFREnabledForArchive: Bool = true
        public var isAFREnabledForCurrentItem: Bool {
            switch playbackContentKind {
            case .live: isAFREnabledForLive
            case .vod: isAFREnabledForVOD
            case .archive: isAFREnabledForArchive
            }
        }

        public var isDisplayModeMatchingEnabledForCurrentItem: Bool {
            isAFREnabledForCurrentItem || isMatchDynamicRangeEnabled
        }

        public var isMatchDynamicRangeEnabled: Bool = true
        public var isForceSDROutputEnabled: Bool = false
        public var currentFrameRate: FrameRate?
        public var afrMatchResult: DisplayMatchResult?
        public var isAFRToastVisible: Bool = false
        public var displayModeRequestID: UUID?

        /// Up Next Episode Auto-Play (Madde #48)
        public var isUpNextVisible: Bool = false
        public var upNextCountdownSeconds: Int = 15
        public var upNextInitialSeconds: Int = 15
        public var isUpNextDismissed: Bool = false
        public var isTransitioningEpisode: Bool = false
        public var offlineEpisodeTransitionRequestID: UUID?

        public var nextEpisodeItem: PlayableItem? {
            guard !item.isLive, let playlist, let idx = currentChannelIndex, idx + 1 < playlist.count else {
                return nil
            }
            let next = playlist[idx + 1]
            if item.streamURL.isFileURL {
                guard let currentOrdinal = item.episodeOrdinal,
                      let nextOrdinal = next.episodeOrdinal,
                      nextOrdinal == currentOrdinal + 1
                else { return nil }
            }
            return next
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
            guard item.isLive,
                  activeCatchupProgram == nil,
                  let playlistID = item.config?.playlistID,
                  let playlist,
                  !playlist.isEmpty
            else { return nil }
            return playlist.first(where: { candidate in
                candidate.id != item.id &&
                    candidate.config?.playlistID == playlistID &&
                    candidate.isLive == item.isLive &&
                    !failedStreamIDs.contains(candidate.id) &&
                    !hiddenChannelIDs.contains(candidate.id) &&
                    !(candidate.categoryID.map(blacklistedCategoryIDs.contains) ?? false) &&
                    PlayerFeature.areAlternativeSources(candidate.title, item.title)
            })
        }

        /// Channel OSD Info Card (Madde #95)
        public var isChannelOSDVisible: Bool = false
        public var sourcePlaylistName: String?
        public var sourcePlaylistNamePlaylistID: UUID?
        public var sourcePlaylistNameRequestID: UUID?

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
            activePlaybackURL = item.streamURL
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

    public indirect enum Action {
        case onAppear
        case startSelectedChannel(id: String)
        case onDisappear
        case nowPlayingSessionActivated(playbackRequestID: UUID, generation: UInt64)
        case nowPlayingRemoteCommand(NowPlayingRemoteCommand)
        case play
        case pause
        case stop
        case retryPlayback
        case requestXtreamLiveOutputFormats
        case xtreamLiveOutputFormatsResponse(
            requestID: UUID,
            itemID: String,
            playlistID: UUID,
            configuration: PlaylistConfig,
            result: Result<[XtreamLiveOutputFormat], Error>
        )
        case selectXtreamLiveOutputFormat(XtreamLiveOutputFormat)
        case switchPlaybackEngineFromError(PlaybackEngine)
        case playbackPositionRecoveryFinished(PlaybackSeekResult, itemID: String, playbackRequestID: UUID)
        case verifyInitialResumeSeek(
            itemID: String,
            playbackRequestID: UUID,
            targetSeconds: Double,
            actualTime: Duration?,
            verificationAttempt: Int
        )
        case initialResumeSeekRequested(targetSeconds: Double)
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
        case updateStats(String, itemID: String, generationID: UUID)
        case toggleStreamHealthHUD
        case setStreamHealthHUDVisible(Bool)
        case updateStreamHealth(StreamHealthMetrics, itemID: String, generationID: UUID)
        case startStreamHealthSampling(itemID: String, generationID: UUID)
        case startLiveVideoStallMonitoring(itemID: String, playbackRequestID: UUID)
        case liveVideoStallSample(
            PlayerPlaybackCounters,
            uptimeNanoseconds: UInt64,
            itemID: String,
            playbackRequestID: UUID,
            monitorID: UUID
        )
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
        case replayWithSubtitles
        case subtitleReplaySeekCompleted(
            requestID: UUID,
            itemID: String,
            playbackRequestID: UUID,
            landedTime: Duration?,
            isAccurate: Bool,
            subtitleTracks: [Track],
            selectedSubtitleTrack: Track?
        )
        case restartPlayback
        case seek(Double)
        case seekToTime(Duration)
        case vodSeekCompleted(requestID: UUID, itemID: String, playbackRequestID: UUID, result: PlaybackSeekResult)
        case vodSeekRollbackCompleted(requestID: UUID, itemID: String, playbackRequestID: UUID, result: PlaybackSeekResult)
        case clearVODSeekFailure(requestID: UUID, itemID: String, playbackRequestID: UUID)
        case playbackHealthEvent(PlaybackHealthEvent, itemID: String, playbackRequestID: UUID, baselineGeneration: PlaybackGeneration, baselineHadPresentedFrame: Bool)
        case clearHighFPSFrameMetric(requestID: UUID, itemID: String, playbackRequestID: UUID)
        case catchupSeekCompleted(requestID: UUID, itemID: String, result: CatchupSeekResult)
        case catchupSeekRollbackCompleted(requestID: UUID, itemID: String, result: CatchupSeekResult)
        case clearCatchupSeekFailureMessage(requestID: UUID, itemID: String)
        case loadSkipMarkers
        case skipMarkersLoaded(requestID: UUID, itemID: String, playlistID: UUID, profileScope: ProfileContextSnapshot, markers: PlaybackSkipMarkers)
        case setSkipMarkerBoundary(kind: PlaybackSkipMarkerKind, isStart: Bool)
        case clearSkipMarker(PlaybackSkipMarkerKind)
        case skipMarkedSegment(PlaybackSkipMarkerKind)
        case requestScrubThumbnail(Duration)
        case scrubThumbnailLoaded(requestID: UUID, itemID: String, data: Data?)
        case cancelScrubThumbnail
        case setPlaybackRate(Float)
        case setDeinterlaceMode(DeinterlaceMode)
        case deinterlaceModeApplied(DeinterlaceMode, UUID, String, URL)
        case deinterlaceModeFailed(UUID, String, URL)
        case memoryPressureWarning
        case memoryPressureDeinterlaceFallbackApplied(UUID, String, URL, UUID)
        case memoryPressureDeinterlaceFallbackFailed(UUID, String, URL, UUID)
        case deinterlaceModePlaybackResolved(requested: DeinterlaceMode, applied: DeinterlaceMode?, engine: PlaybackEngine, revision: UUID, itemID: String, streamURL: URL)
        case playbackEngineStartFailed(engine: PlaybackEngine, itemID: String, streamURL: URL, playbackRequestID: UUID)
        case mediaServerPlaybackResolved(
            requestID: UUID,
            itemID: String,
            streamURL: URL,
            proxyURL: URL,
            status: MediaModels.ServerPlaybackStatus?
        )
        case mediaServerPlaybackOptionsLoaded(
            requestID: UUID,
            itemID: String,
            result: Result<[MediaModels.MediaServerPlaybackOption], Error>
        )
        case selectMediaServerPlaybackSource(String)
        case cancelMediaServerPlaybackSourceSelection
        case mediaServerPlaybackStatusLoaded(
            requestID: UUID,
            itemID: String,
            playbackRequestID: UUID,
            status: MediaModels.ServerPlaybackStatus?
        )
        case toggleInfo
        case toggleEPG
        case selectEPGBrowseChannel(PlayableItem)
        case epgBrowseResponse(channelID: String, Result<[EPGProgram], Error>)
        case watchEPGBrowseChannel
        case returnToPlayingChannelInEPG

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
        case channelUp
        case channelDown
        case keyboardChannelUp
        case keyboardChannelDown
        case channelDownOrRecentChannels
        case recallLastChannel
        case setRecallHUDVisible(Bool)
        case hideRecallHUD
        case showZappingHUD(item: PlayableItem, direction: ZappingDirection)
        case hideZappingHUD
        case showChannelOSD
        case hideChannelOSD
        case resolveSourcePlaylistName
        case sourcePlaylistNameResolved(requestID: UUID, playlistID: UUID, name: String?)

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
        case setEPGPreviewCorner(EPGPreviewCorner)
        case fetchEPG
        case fetchEPGResponse(channelID: String, requestID: UUID, Result<[EPGProgram], Error>)
        case playArchive(EPGProgram)
        case sharePlayTapped

        case fetchMediaInfo
        case mediaInfoResponse(MediaInfo?, itemID: String, playbackRequestID: UUID, requestID: UUID)

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
        case toggleRecordingTapped
        case recordingStartFailed
        case recordingStartTimedOut
        case recordingFinalized(String?)
        case recordingStopUnconfirmed
        case recordingStopTimedOut
        case recordingLimitCheck
        case dismissRecordingStatus
        case closeTapped
        case switchPlaybackEngine(PlaybackEngine)
        case saveCurrentPlaybackEnginePreference
        case clearCurrentPlaybackEnginePreference
        case playbackEngineSwitchFinished(PlaybackEngine, DeinterlaceMode, UUID, String)
        case playbackEngineSwitchFailed(String, UUID, String)
        case listenForPlayerEvents
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
        case speedTestTapped
        case closeSpeedTest(requestID: UUID)
        case subtitleSearchTapped
        case closeSubtitleSearch(requestID: UUID)
        case installSubtitleSearchTrack(url: URL, requestID: UUID, playbackRequestID: UUID)
        case subtitleSearchTrackInstallResponse(requestID: UUID, playbackRequestID: UUID, didAdd: Bool, externalTrackIDs: [String])

        // Up Next Episode Auto-Play (Madde #48)
        case showUpNext
        case dismissUpNext
        case playNextEpisode
        case offlineEpisodeAvailabilityResponse(requestID: UUID, playbackRequestID: UUID, itemID: String, next: PlayableItem?)
        case upNextCountdownTick

        case applyRememberedPlaybackChoice
        case dismissRememberedPlaybackChoice
        case forgetRememberedPlaybackChoice

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
        case setAFREnabledForArchive(Bool)
        case setMatchDynamicRangeEnabled(Bool)
        case matchDisplayMode
        case displayModeSwitched(DisplayMatchResult)
        case displayModeRequestFinished(DisplayMatchResult, requestID: UUID)
        case showAFRToast(DisplayMatchResult)
        case hideAFRToast

        public enum Delegate: Equatable {
            case didClose
            case didRequestMinimize
            case presentSpeedTest(requestID: UUID)
            case presentSubtitleSearch(requestID: UUID)
            case didSelectXtreamLiveOutputFormat(PlaylistConfig)
        }
    }

    @Injected(\.playerClient) var playerClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.viewingStatisticsClient) var viewingStatisticsClient
    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.downloadClient) var downloadClient
    @Dependency(\.recentChannelsClient) var recentChannelsClient
    @Dependency(\.streamHealthClient) var streamHealthClient
    @Dependency(\.pipClient) var pipClient
    @Dependency(\.parentalControlClient) var parentalControlClient
    @Dependency(\.displayModeClient) var displayModeClient
    @Dependency(\.customEPGMappingClient) var customEPGMappingClient
    @Dependency(\.playbackSkipMarkerClient) var playbackSkipMarkerClient
    @Dependency(\.mediaServerClient) var mediaServerClient
    @Dependency(\.nowPlayingClient) var nowPlayingClient
    @Dependency(\.continuousClock) var continuousClock
    @Injected(\.playlistRepository) var playlistRepository

    public init() {}

    private static func catchupSeekEffect(
        requestID: UUID,
        itemID: String,
        command: CatchupSeekCommand,
        client: PlayerClient
    ) -> Effect<Action> {
        .merge(
            .cancel(id: CancelID.catchupSeekFeedback),
            .run { send in
                let result = await client.catchupSeek(command)
                await send(.catchupSeekCompleted(requestID: requestID, itemID: itemID, result: result))
            }
            .cancellable(id: CancelID.catchupSeek, cancelInFlight: true)
        )
    }

    private static func vodSeekEffect(
        requestID: UUID,
        itemID: String,
        playbackRequestID: UUID,
        command: PlaybackSeekCommand,
        client: PlayerClient
    ) -> Effect<Action> {
        .merge(
            .cancel(id: CancelID.vodSeekFeedback),
            .run { send in
                let commandDescription = switch command {
                case let .position(position): "position=\(position)"
                case let .time(time): "time=\(Self.durationSeconds(time))s"
                case let .relative(seconds): "relative=\(seconds)s"
                }
                let shortRequestID = String(requestID.uuidString.prefix(8))
                PlayerLogger.shared.info(
                    category: "Seek",
                    message: "VOD seek started request=\(shortRequestID) \(commandDescription)"
                )
                let result = await client.seekAndConfirm(command)
                let landedTime = result.currentTime.map(Self.durationSeconds).map { String($0) } ?? "unknown"
                let landedPosition = result.position.map { String($0) } ?? "unknown"
                PlayerLogger.shared.info(
                    category: "Seek",
                    message: "VOD seek finished request=\(shortRequestID) status=\(result.status) time=\(landedTime)s position=\(landedPosition)"
                )
                await send(.vodSeekCompleted(
                    requestID: requestID,
                    itemID: itemID,
                    playbackRequestID: playbackRequestID,
                    result: result
                ))
            }
            .cancellable(id: CancelID.vodSeek, cancelInFlight: true)
        )
    }

    private nonisolated static func durationSeconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    private nonisolated static func catchupDurationSeconds(reported: Duration, maximum: Double?) -> Double? {
        let reportedSeconds = durationSeconds(reported)
        let validReported = reportedSeconds.isFinite && reportedSeconds > 0 ? reportedSeconds : nil
        let validMaximum = maximum.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        if let validReported, let validMaximum {
            return min(validReported, validMaximum)
        }
        return validReported ?? validMaximum
    }

    private nonisolated static func seekLanded(
        currentTime: Duration?,
        position: Double?,
        expectedSeconds: Double?,
        expectedPosition: Double?,
        durationSeconds: Double,
        toleranceSeconds: Double = 2
    ) -> Bool {
        let landedSeconds = currentTime.map(Self.durationSeconds)
            ?? position.flatMap { position in
                durationSeconds.isFinite && durationSeconds > 0 && position.isFinite
                    ? position * durationSeconds
                    : nil
            }
        let landedPosition = position.flatMap { $0.isFinite ? $0 : nil }
            ?? (durationSeconds.isFinite && durationSeconds > 0
                ? landedSeconds.map { $0 / durationSeconds }
                : nil)

        if let expectedSeconds, expectedSeconds.isFinite {
            guard let landedSeconds, landedSeconds.isFinite else { return false }
            return landedSeconds >= 0
                && (!durationSeconds.isFinite || durationSeconds <= 0 || landedSeconds <= durationSeconds + 2)
                && abs(landedSeconds - expectedSeconds) <= toleranceSeconds
        }
        if let expectedPosition, expectedPosition.isFinite {
            let tolerance = durationSeconds.isFinite && durationSeconds > 0
                ? max(0.001, toleranceSeconds / durationSeconds)
                : min(0.025, max(0.005, toleranceSeconds / 600))
            guard let landedPosition, landedPosition.isFinite else { return false }
            return abs(landedPosition - expectedPosition) <= tolerance
        }
        return false
    }

    private nonisolated static func timelineTimeIsValid(_ time: Duration, totalSeconds: Double) -> Bool {
        let seconds = durationSeconds(time)
        guard seconds.isFinite, seconds >= 0 else { return false }
        return !totalSeconds.isFinite || totalSeconds <= 0 || seconds <= totalSeconds + 2
    }

    private nonisolated static func timelinePositionIsValid(_ position: Double) -> Bool {
        position.isFinite && (0 ... 1).contains(position)
    }

    static func shouldRestorePositionOnPlaybackStart(
        isLive: Bool,
        isPlayingCatchup: Bool,
        initialProgress: Double?
    ) -> Bool {
        let supportsPositionRecovery = !isLive || isPlayingCatchup
        let hasAbsoluteResumeTime = supportsPositionRecovery
            && initialProgress.map { $0.isFinite && $0 > 1 } == true
        return supportsPositionRecovery && !hasAbsoluteResumeTime
    }

    private static func nowPlayingMetadata(for state: State) -> NowPlayingMetadata {
        func seconds(_ duration: Duration) -> Double {
            let components = duration.components
            return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
        }

        let isLive = state.item.isLive && !state.isPlayingCatchup
        let isPlaying = state.playerState == .playing && !state.isUserPaused && !state.isSwitchingPlaybackEngine
        let duration = seconds(state.totalTime)
        return NowPlayingMetadata(
            itemID: state.item.id,
            playbackRequestID: state.playbackRequestID,
            title: state.item.title,
            seriesTitle: state.item.seriesTitle,
            artworkURL: state.item.coverURL ?? state.item.fallbackCoverURL,
            artworkUserAgent: state.item.userAgentOverride,
            duration: !isLive && duration.isFinite && duration > 0 ? duration : nil,
            elapsedTime: isLive ? 0 : max(0, seconds(state.currentTime)),
            playbackRate: isPlaying ? Double(state.playbackRate) : 0,
            isLive: isLive,
            canSeek: !isLive,
            skipIntervalSeconds: state.skipIntervalSeconds
        )
    }

    private static func viewingStatisticsMedia(for item: PlayableItem) -> ViewingStatisticsMedia {
        if item.isLive {
            return ViewingStatisticsMedia(
                kind: .live,
                id: stableViewingStatisticsID(for: item),
                playlistID: item.config?.playlistID,
                title: item.title
            )
        }
        if item.seriesTitle != nil || item.seriesID != nil {
            let seriesID = item.config?.type == .m3u
                ? stableM3USeriesStatisticsID(for: item)
                : (item.seriesID ?? item.id)
            return ViewingStatisticsMedia(
                kind: .series,
                id: seriesID,
                playlistID: item.config?.playlistID,
                title: item.seriesTitle ?? item.title
            )
        }
        return ViewingStatisticsMedia(
            kind: .movie,
            id: stableViewingStatisticsID(for: item),
            playlistID: item.config?.playlistID,
            title: item.title
        )
    }

    private static func stableViewingStatisticsID(for item: PlayableItem) -> String {
        guard item.config?.type == .m3u else { return item.id }

        let tvgID = normalizedStatisticsIdentityComponent(item.epgChannelID)
        let sourceIdentity = if tvgID.isEmpty {
            "title:\(normalizedStatisticsIdentityComponent(item.title))|category:\(normalizedStatisticsIdentityComponent(item.categoryID))"
        } else {
            "tvg:\(tvgID)"
        }
        return opaqueStatisticsIdentity(sourceIdentity)
    }

    private static func stableM3USeriesStatisticsID(for item: PlayableItem) -> String {
        let seriesTitle = normalizedStatisticsIdentityComponent(item.seriesTitle ?? item.title)
        let category = normalizedStatisticsIdentityComponent(item.categoryID)
        return opaqueStatisticsIdentity("series:\(seriesTitle)|category:\(category)")
    }

    private static func opaqueStatisticsIdentity(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        let opaqueID = digest.map { String(format: "%02x", Int($0)) }.joined()
        return "m3u:\(opaqueID)"
    }

    private static func normalizedStatisticsIdentityComponent(_ value: String?) -> String {
        (value ?? "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .precomposedStringWithCanonicalMapping
            .lowercased()
    }

    private static func flushViewingStatistics(
        state: inout State,
        client: ViewingStatisticsClient
    ) -> Effect<Action> {
        let seconds = state.viewingStatisticsPendingSeconds
        guard seconds > 0,
              let media = state.viewingStatisticsMedia
        else { return .none }
        state.viewingStatisticsPendingSeconds = 0
        let profileID = state.viewingStatisticsProfileID
        let date = Date()
        return .run { _ in
            await client.record(profileID, media, seconds, date)
        }
    }

    private static func updateNowPlaying(
        state: State,
        client: NowPlayingClient,
        force: Bool = true
    ) -> Effect<Action> {
        #if os(iOS)
            guard !state.isSwitchingPlaybackEngine,
                  !state.isNowPlayingSuppressed,
                  state.playerState != .stopped
            else { return .none }
            let metadata = nowPlayingMetadata(for: state)
            let generation = state.nowPlayingGeneration
            return .run { _ in
                guard !Task.isCancelled else { return }
                await client.update(metadata, force, generation)
            }
            .cancellable(id: CancelID.nowPlayingMetadata, cancelInFlight: true)
        #else
            return .none
        #endif
    }

    private static func clearNowPlaying(state: inout State, client: NowPlayingClient) -> Effect<Action> {
        state.nowPlayingGeneration += 1
        let generation = state.nowPlayingGeneration
        return .concatenate(
            .cancel(id: CancelID.nowPlayingMetadata),
            .run { _ in await client.clear(generation) }
        )
    }

    private static func deactivateNowPlaying(state: inout State, client: NowPlayingClient) -> Effect<Action> {
        state.nowPlayingGeneration += 1
        let generation = state.nowPlayingGeneration
        return .concatenate(
            .cancel(id: CancelID.nowPlayingMetadata),
            .cancel(id: CancelID.nowPlayingCommands),
            .run { _ in await client.deactivate(generation) }
        )
    }

    private static func listenForNowPlayingCommands(
        playbackRequestID: UUID,
        generation: UInt64,
        client: NowPlayingClient
    ) -> Effect<Action> {
        #if os(iOS)
            return .run { send in
                let commands = await client.activate(generation)
                guard !Task.isCancelled else {
                    await client.deactivate(generation)
                    return
                }
                await send(.nowPlayingSessionActivated(playbackRequestID: playbackRequestID, generation: generation))
                for await command in commands {
                    guard !Task.isCancelled else { return }
                    await send(.nowPlayingRemoteCommand(command))
                }
            }
            .cancellable(id: CancelID.nowPlayingCommands, cancelInFlight: true)
        #else
            return .none
        #endif
    }

    public var body: some Reducer<State, Action> {
        let playerClient = playerClient
        let databaseClient = databaseClient
        let mediaServerClient = mediaServerClient
        let profileContextClient = profileContextClient
        let settingsClient = settingsClient
        let downloadClient = downloadClient
        let recentChannelsClient = recentChannelsClient
        let streamHealthClient = streamHealthClient
        let pipClient = pipClient
        let parentalControlClient = parentalControlClient
        let displayModeClient = displayModeClient
        let customEPGMappingClient = customEPGMappingClient
        let playbackSkipMarkerClient = playbackSkipMarkerClient
        let playlistRepository = playlistRepository
        let viewingStatisticsClient = viewingStatisticsClient
        let nowPlayingClient = nowPlayingClient
        let continuousClock = continuousClock

        Reduce { state, action in
            Self.reduceHelper(state: &state, action: action, playerClient: playerClient, databaseClient: databaseClient, iptvClient: iptvClient, mediaServerClient: mediaServerClient, settingsClient: settingsClient, downloadClient: downloadClient, recentChannelsClient: recentChannelsClient, streamHealthClient: streamHealthClient, pipClient: pipClient, parentalControlClient: parentalControlClient, displayModeClient: displayModeClient, customEPGMappingClient: customEPGMappingClient, playbackSkipMarkerClient: playbackSkipMarkerClient, playlistRepository: playlistRepository, profileContextClient: profileContextClient, viewingStatisticsClient: viewingStatisticsClient, nowPlayingClient: nowPlayingClient, continuousClock: continuousClock)
        }
    }

    private static func stallWatchdogEffect(
        clock: any Clock<Duration>,
        isLive: Bool
    ) -> Effect<Action> {
        let timeout: Duration = isLive ? .seconds(15) : .seconds(45)
        return .run { send in
            do {
                try await clock.sleep(for: timeout)
            } catch {
                return
            }
            await send(.streamStalled)
        }
        .cancellable(id: CancelID.stallWatchdog, cancelInFlight: true)
    }

    private static func initialResumeSeekVerificationEffect(
        itemID: String,
        playbackRequestID: UUID,
        targetSeconds: Double,
        verificationAttempt: Int,
        delay: Duration,
        clock: any Clock<Duration>,
        playerClient: PlayerClient
    ) -> Effect<Action> {
        .run { send in
            do {
                try await clock.sleep(for: delay)
            } catch {
                return
            }
            let actualTime = await playerClient.currentPlaybackTime()
            await send(.verifyInitialResumeSeek(
                itemID: itemID,
                playbackRequestID: playbackRequestID,
                targetSeconds: targetSeconds,
                actualTime: actualTime,
                verificationAttempt: verificationAttempt
            ))
        }
        .cancellable(id: CancelID.initialResumeSeekVerification, cancelInFlight: true)
    }

    /// Initial playback can spend several seconds opening the stream before its
    /// decoder accepts a seek. Keep verification alive through the VOD stall window.
    private static let maxInitialResumeSeekVerificationAttempt = 40

    private static let liveVideoStallThresholdNanoseconds: UInt64 = 3_500_000_000
    private static let liveVideoClockStaleToleranceNanoseconds: UInt64 = 2_500_000_000

    private static func canMonitorLiveVideoStall(state: State) -> Bool {
        guard state.item.isLive,
              state.activeCatchupProgram == nil,
              state.playbackEngine == .vlc,
              state.playerState == .playing,
              !state.isUserPaused,
              !state.isMinimized,
              !state.isPiPActive,
              !state.isAppInBackground,
              !state.isBackgroundAudioActive,
              let videoCodec = state.mediaInfo?.videoCodec
        else { return false }
        return !videoCodec.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func resetLiveVideoStallTracking(state: inout State) {
        state.isLiveVideoStallDetected = false
        state.liveVideoStallMonitorID = UUID()
        state.liveVideoStallLastCounters = nil
        state.liveVideoStallLastSampleUptimeNanoseconds = nil
        state.liveVideoStallLastPlaybackTime = nil
        state.liveVideoStallLastClockAdvanceUptimeNanoseconds = nil
        state.liveVideoStallNoFrameStartUptimeNanoseconds = nil
    }

    private static func stopLiveVideoStallMonitoring(state: inout State) -> Effect<Action> {
        resetLiveVideoStallTracking(state: &state)
        return .cancel(id: CancelID.liveVideoStallMonitor)
    }

    private static func startLiveVideoStallMonitoring(
        state: inout State,
        playerClient: PlayerClient,
        itemID: String,
        playbackRequestID: UUID
    ) -> Effect<Action> {
        guard state.item.id == itemID,
              state.playbackRequestID == playbackRequestID
        else { return .none }

        guard canMonitorLiveVideoStall(state: state) else {
            return stopLiveVideoStallMonitoring(state: &state)
        }

        resetLiveVideoStallTracking(state: &state)
        let monitorID = state.liveVideoStallMonitorID
        return .run { [playerClient] send in
            while !Task.isCancelled {
                let counters = await playerClient.getPlaybackCounters()
                let uptimeNanoseconds = DispatchTime.now().uptimeNanoseconds
                guard !Task.isCancelled else { return }
                await send(.liveVideoStallSample(
                    counters,
                    uptimeNanoseconds: uptimeNanoseconds,
                    itemID: itemID,
                    playbackRequestID: playbackRequestID,
                    monitorID: monitorID
                ))
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
            }
        }
        .cancellable(id: CancelID.liveVideoStallMonitor, cancelInFlight: true)
    }

    private static func streamHealthSamplingEffect(
        itemID: String,
        streamURL: URL,
        generationID: UUID,
        includesStats: Bool,
        playerClient: PlayerClient,
        streamHealthClient: StreamHealthClient
    ) -> Effect<Action> {
        .run { send in
            var previousCounters: PlayerPlaybackCounters?
            var previousSampleUptimeNanoseconds: UInt64?
            while !Task.isCancelled {
                var stats: String?
                if includesStats {
                    stats = await playerClient.getStats()
                }
                let counters = await playerClient.getPlaybackCounters()
                let now = DispatchTime.now().uptimeNanoseconds
                let elapsed = previousSampleUptimeNanoseconds.map {
                    Double(now - $0) / 1_000_000_000
                } ?? 0
                let isPlaying = await MainActor.run { playerClient.isPlaying() }
                let mediaBitrate = await playerClient.getMediaInfo()?.bitrate
                let health = await streamHealthClient.evaluateHealth(
                    streamURL,
                    isPlaying,
                    counters,
                    previousCounters,
                    elapsed,
                    mediaBitrate
                )
                previousCounters = counters
                previousSampleUptimeNanoseconds = now
                if includesStats {
                    await send(.updateStats(stats ?? "", itemID: itemID, generationID: generationID))
                }
                await send(.updateStreamHealth(health, itemID: itemID, generationID: generationID))
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
            }
        }
        .cancellable(id: CancelID.statsTimer, cancelInFlight: true)
    }

    private static func beginStreamHealthSampling(
        state: inout State,
        playerClient: PlayerClient,
        streamHealthClient: StreamHealthClient
    ) -> Effect<Action> {
        let generationID = UUID()
        state.streamHealthGenerationID = generationID
        state.streamHealthMetrics = nil
        return streamHealthSamplingEffect(
            itemID: state.item.id,
            streamURL: state.activePlaybackURL,
            generationID: generationID,
            includesStats: state.isShowingStats,
            playerClient: playerClient,
            streamHealthClient: streamHealthClient
        )
    }

    private static func cancelStreamHealthSamplingIfNeeded(state: inout State) -> Effect<Action> {
        guard !state.isShowingStats, !state.isStreamHealthHUDVisible else { return .none }
        state.streamHealthGenerationID = UUID()
        state.streamHealthMetrics = nil
        return .cancel(id: CancelID.statsTimer)
    }

    private static func persistSkipMarkers(
        _ markers: PlaybackSkipMarkers,
        revision: UInt64,
        item: PlayableItem,
        profileScope: ProfileContextSnapshot,
        markerClient: PlaybackSkipMarkerClient,
        profileContextClient: ProfileContextClient
    ) -> Effect<Action> {
        guard
            let profileID = profileScope.profileID,
            let playlistID = item.config?.playlistID,
            !item.isLive,
            !item.id.isEmpty
        else { return .none }

        let mediaKind = item.seriesID == nil ? "movie" : "episode"
        return .run { _ in
            guard profileContextClient.snapshot() == profileScope else { return }
            await markerClient.save(markers, revision, profileID, playlistID, mediaKind, item.id, item.seriesID)
        }
    }

    private static func reloadSkipMarkersAfterProfileChange(
        state: inout State,
        profileContextClient: ProfileContextClient
    ) -> Effect<Action> {
        guard
            let loadedScope = state.skipMarkersProfileScope,
            profileContextClient.snapshot() != loadedScope
        else { return .none }
        state.skipMarkers = .init()
        state.skipMarkerRequestID = nil
        state.skipMarkersProfileScope = nil
        state.isSkipMarkersLoading = false
        return .merge(
            .cancel(id: CancelID.skipMarkerLoad),
            .send(.loadSkipMarkers)
        )
    }

    private static func loadRememberedPlaybackChoice(state: inout State, profileScope: ProfileContextSnapshot) {
        state.rememberedPlaybackChoiceProfileScope = profileScope
        state.itemSpecificPlaybackEnginePreference = SpecificPlaybackEnginePreferenceStore.load(
            item: state.item,
            profileID: profileScope.profileID
        )
        guard state.itemSpecificPlaybackEnginePreference == nil else {
            state.rememberedPlaybackChoice = nil
            return
        }
        guard let reminder = PlaybackChoicePreferenceStore.load(
            item: state.item,
            playbackURL: state.activePlaybackURL,
            profileID: profileScope.profileID
        ) else {
            state.rememberedPlaybackChoice = nil
            return
        }
        guard !state.dismissedRememberedPlaybackChoiceScopeKeys.contains(reminder.scopeKey) else {
            state.rememberedPlaybackChoice = nil
            return
        }

        let engine = reminder.choice.playbackEngine
        guard state.canSwitchPlaybackEngine, engine != state.playbackEngine else {
            state.rememberedPlaybackChoice = nil
            return
        }

        state.rememberedPlaybackChoice = reminder
    }

    private static func reloadRememberedPlaybackChoiceAfterProfileChange(
        state: inout State,
        profileContextClient: ProfileContextClient
    ) -> Effect<Action> {
        let profileScope = profileContextClient.snapshot()
        guard state.rememberedPlaybackChoiceProfileScope != profileScope else { return .none }
        state.rememberedPlaybackChoice = nil
        loadRememberedPlaybackChoice(state: &state, profileScope: profileScope)
        return .none
    }

    private static func resolvedPlaybackEngine(
        item: PlayableItem,
        kind: PlaybackContentKind,
        defaults: PlaybackDefaults,
        settingsClient: SettingsClient,
        profileID: UUID?
    ) -> PlaybackEngine {
        let itemPreference = SpecificPlaybackEnginePreferenceStore.load(item: item, profileID: profileID)
        if itemPreference == .vlc {
            return .vlc
        }

        let supportsAVPlayer = kind == .vod
            && item.config?.type != .plex && item.config?.type != .emby
            && ["m3u8", "mp4", "m4v"].contains(item.streamURL.pathExtension.lowercased())
            && ["http", "https"].contains(item.streamURL.scheme?.lowercased() ?? "")
            && item.userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
            && (settingsClient.getChannelAudioEQPreset(item.id) ?? settingsClient.audioEQPreset()) == .flat
            && (settingsClient.getChannelAudioDelay(item.id) ?? 0) == 0
            && (settingsClient.getChannelSubtitleDelay(item.id) ?? 0) == 0

        guard supportsAVPlayer else { return .vlc }
        if itemPreference == .avPlayer || defaults.preferredEngine == .avPlayer {
            return .avPlayer
        }
        return .vlc
    }

    private static func savedAudioTrackName(itemID: String, settingsClient: SettingsClient) -> String? {
        settingsClient.getChannelPreferredAudioTrack(itemID)
            ?? (settingsClient.rememberMediaTrackPreferences()
                ? UserDefaults.standard.string(forKey: "com.pureiptv.media_\(itemID)_audio")
                : nil)
    }

    private static func savedSubtitleTrackName(itemID: String, settingsClient: SettingsClient) -> String? {
        settingsClient.getChannelPreferredSubtitleTrack(itemID)
            ?? (settingsClient.rememberMediaTrackPreferences()
                ? UserDefaults.standard.string(forKey: "com.pureiptv.media_\(itemID)_subtitle")
                : nil)
    }

    static func reduceHelper(state: inout State, action: Action, playerClient: PlayerClient, databaseClient: DatabaseClient, iptvClient: IPTVClient, mediaServerClient: MediaServerClient, settingsClient: SettingsClient, downloadClient: DownloadClient, recentChannelsClient: RecentChannelsClient, streamHealthClient: StreamHealthClient, pipClient: PiPClient, parentalControlClient: ParentalControlClient, displayModeClient: DisplayModeClient, customEPGMappingClient: CustomEPGMappingClient, playbackSkipMarkerClient: PlaybackSkipMarkerClient, playlistRepository: PlaylistRepository, profileContextClient: ProfileContextClient, viewingStatisticsClient: ViewingStatisticsClient, nowPlayingClient: NowPlayingClient, continuousClock: any Clock<Duration>) -> Effect<Action> {
        switch action {
        case .onAppear:
            if let config = state.item.config,
               !state.item.isLive,
               config.type == .plex || config.type == .emby,
               state.mediaServerPlaybackOptionsCheckedItemID != state.item.id
            {
                guard state.mediaServerPlaybackOptionsRequestID == nil else { return .none }
                let requestID = UUID()
                let itemID = state.item.id
                state.mediaServerPlaybackOptionsRequestID = requestID
                return .run { send in
                    do {
                        let options = try await iptvClient.fetchMediaServerPlaybackOptions(config, itemID)
                        await send(.mediaServerPlaybackOptionsLoaded(
                            requestID: requestID,
                            itemID: itemID,
                            result: .success(options)
                        ))
                    } catch {
                        await send(.mediaServerPlaybackOptionsLoaded(
                            requestID: requestID,
                            itemID: itemID,
                            result: .failure(error)
                        ))
                    }
                }
                .cancellable(id: CancelID.mediaServerPlaybackOptions, cancelInFlight: true)
            }
            resetLiveVideoStallTracking(state: &state)
            state.epgPreviewCorner = settingsClient.getEPGPreviewCorner()
            state.playbackRequestID = UUID()
            state.mediaServerPlaybackStatus = nil
            state.mediaServerPlaybackStatusRequestID = nil
            state.hasAttemptedMediaServerPlaybackStatus = false
            state.mediaInfoRequestID = nil
            state.mediaInfo = nil
            state.firstPresentedFrameLatency = nil
            state.firstPresentedFrameFeedbackRequestID = nil
            state.activeVODSeekRequestID = nil
            state.vodSeekTimelineRecoveryRequired = false
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            state.expectedVODSeekTargetSeconds = nil
            state.expectedVODSeekTargetPosition = nil
            state.vodSeekPreviousPosition = nil
            state.vodSeekPreviousTime = nil
            state.vodSeekFailureRequestID = nil
            state.isMinimized = false
            state.isAppInBackground = false
            state.isUserPaused = false
            state.isNowPlayingSuppressed = false
            state.nowPlayingGeneration += 1
            let isAlreadyPlaying = state.playerState == .playing || state.playerState == .buffering
            let playbackKind = state.playbackContentKind
            let playbackDefaults = settingsClient.playbackDefaults(playbackKind)
            if playbackKind == .vod {
                state.vodSkipInterval = playbackDefaults.vodSkipInterval
            } else if playbackKind == .archive {
                state.catchupSkipInterval = playbackDefaults.catchupSkipInterval
            }
            let profileScope = profileContextClient.snapshot()
            let statisticsMedia = Self.viewingStatisticsMedia(for: state.item)
            var viewingStatisticsAppearanceEffect: Effect<Action> = .none
            if state.viewingStatisticsProfileID != profileScope.profileID || state.viewingStatisticsMedia != statisticsMedia {
                viewingStatisticsAppearanceEffect = Self.flushViewingStatistics(state: &state, client: viewingStatisticsClient)
                state.viewingStatisticsProfileID = profileScope.profileID
                state.viewingStatisticsMedia = statisticsMedia
            }
            state.viewingStatisticsLastPlaybackSeconds = nil
            state.viewingStatisticsLastWallTime = nil
            if state.item.config?.type == .plex || state.item.config?.type == .emby {
                state.playbackEngine = .vlc
            } else if isAlreadyPlaying {
                state.playbackEngine = playerClient.activeEngine()
            } else {
                state.playbackEngine = Self.resolvedPlaybackEngine(
                    item: state.item,
                    kind: playbackKind,
                    defaults: playbackDefaults,
                    settingsClient: settingsClient,
                    profileID: profileScope.profileID
                )
            }
            if !isAlreadyPlaying {
                state.deinterlaceMode = playbackDefaults.deinterlaceMode
            }
            if !state.didLoadRememberedPlaybackChoice {
                state.didLoadRememberedPlaybackChoice = true
                Self.loadRememberedPlaybackChoice(state: &state, profileScope: profileScope)
            }
            state.autoSelectFirstAlternativeSource = settingsClient.autoSelectFirstAlternativeSource()
            state.reverseChannelZappingDirection = settingsClient.reverseChannelZappingDirection()
            state.isOLEDDimmingEnabled = settingsClient.isOLEDDimmingEnabled()
            state.isChannelNameCleaningEnabled = settingsClient.isChannelNameCleaningEnabled()
            state.isPiPSupported = state.playbackEngine == .vlc && pipClient.isPiPSupported()
            state.isAutoPiPEnabled = pipClient.isAutoPiPEnabled()
            state.backgroundPlaybackMode = pipClient.backgroundPlaybackMode()
            state.hiddenChannelIDs = parentalControlClient.hiddenChannelIDs()
            state.blacklistedCategoryIDs = parentalControlClient.blacklistedCategoryIDs()
            state.isAFREnabledForLive = settingsClient.playbackDefaults(.live).isAFREnabled
            state.isAFREnabledForVOD = settingsClient.playbackDefaults(.vod).isAFREnabled
            state.isAFREnabledForArchive = settingsClient.playbackDefaults(.archive).isAFREnabled
            state.isMatchDynamicRangeEnabled = playbackDefaults.isMatchDynamicRangeEnabled
            state.isForceSDROutputEnabled = playbackDefaults.isForceSDROutputEnabled ?? false

            // Restore per-channel lip-sync and subtitle preferences
            if let savedAudio = settingsClient.getChannelAudioDelay(state.item.id) {
                state.audioDelay = savedAudio
            }
            if let savedSub = settingsClient.getChannelSubtitleDelay(state.item.id) {
                state.subtitleDelay = savedSub
            }

            let url = state.activePlaybackURL
            let isLive = state.item.isLive
            let seriesID = state.item.seriesID
            let config = state.item.config
            let userAgentOverride = state.item.userAgentOverride
            let requiresAuthenticatedMediaServer = config?.type == .plex || config?.type == .emby
            let networkCachingMilliseconds = playbackDefaults.networkCachingMilliseconds(for: playbackKind)
            let subtitleTextScale = playbackDefaults.subtitleTextSize.scale
            let preferredAudioLanguage = playbackDefaults.preferredAudioLanguage
            let preferredSubtitleLanguage = playbackDefaults.preferredSubtitleLanguage
            let playbackEngine = state.playbackEngine
            let audioName = Self.savedAudioTrackName(itemID: state.item.id, settingsClient: settingsClient)
            let subtitleName = Self.savedSubtitleTrackName(itemID: state.item.id, settingsClient: settingsClient)
            let deinterlaceMode = state.deinterlaceMode
            let deinterlaceModeRevision = state.deinterlaceModeRevision
            let itemID = state.item.id
            let itemTitle = state.item.title
            let selectedMediaServerPlaybackSourceID = state.selectedMediaServerPlaybackSourceID
            let playbackRequestID = state.playbackRequestID
            let needsPlaylist = (seriesID != nil && config != nil && (state.playlist == nil || state.playlist?.isEmpty == true))
            if requiresAuthenticatedMediaServer, !isAlreadyPlaying {
                state.mediaServerPlaybackRequestID = UUID()
            } else if !requiresAuthenticatedMediaServer {
                state.mediaServerPlaybackRequestID = nil
            }
            let mediaServerPlaybackRequestID = state.mediaServerPlaybackRequestID
            if !isAlreadyPlaying {
                state.isDeinterlaceModeKnown = false
            }
            let recentEffect: Effect<Action> = isLive ? .run { [item = state.item] send in
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
                if let playlistID = item.config?.playlistID {
                    await recentChannelsClient.recordScopedChannel(
                        recentDTO,
                        profileScope.profileID,
                        playlistID
                    )
                }
                await send(.loadRecentChannels)
            } : .none

            #if canImport(UIKit)
                let memoryPressureEffect: Effect<Action> = .run { send in
                    for await _ in NotificationCenter.default.notifications(
                        named: UIApplication.didReceiveMemoryWarningNotification
                    ) {
                        guard !Task.isCancelled else { return }
                        await send(.memoryPressureWarning)
                    }
                }
                .cancellable(id: CancelID.memoryPressureWarnings, cancelInFlight: true)
            #else
                let memoryPressureEffect: Effect<Action> = .none
            #endif

            return .merge(
                viewingStatisticsAppearanceEffect,
                memoryPressureEffect,
                .run { _ in
                    try? await pipClient.configureAudioSession(true)
                },
                state.item.isLive ? .send(.showChannelOSD) : .none,
                state.videoDynamicRange?.isHDR == true ? .run { send in
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    await send(.hideDynamicRangeHUD)
                }.cancellable(id: CancelID.dynamicRangeHUD, cancelInFlight: true) : .none,
                isAlreadyPlaying
                    ? .concatenate(.send(.loadAFRPreferences), .send(.matchDisplayMode))
                    : .none,
                .send(.loadChannelSortPreferences),
                .send(.loadAudioEQPreferences),
                .send(.loadSkipMarkers),
                state.item.isLive && state.playbackEngine == .vlc && isAlreadyPlaying
                    ? .send(.fetchMediaInfo)
                    : .none,
                recentEffect,
                .send(.startOLEDDimTimer),
                .cancel(id: CancelID.mediaServerPlaybackStatus),
                .cancel(id: CancelID.vodSeek),
                .cancel(id: CancelID.vodSeekFeedback),
                .cancel(id: CancelID.highFPSFeedback),
                .cancel(id: CancelID.liveVideoStallMonitor),
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
                    if requiresAuthenticatedMediaServer, !isAlreadyPlaying, !isPreviewPromotion {
                        try? await playerClient.stop()
                    }
                    let eventsStream = await playerClient.events()
                    let healthBaseline = await playerClient.playbackHealthSnapshot()
                    let healthStream = await playerClient.playbackHealthEvents()
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

                        if let healthBaseline {
                            group.addTask {
                                for await event in healthStream {
                                    await send(.playbackHealthEvent(
                                        event,
                                        itemID: itemID,
                                        playbackRequestID: playbackRequestID,
                                        baselineGeneration: healthBaseline.generation,
                                        baselineHadPresentedFrame: healthBaseline.lastPresentedAt != nil
                                    ))
                                }
                            }
                        }

                        group.addTask {
                            if isAlreadyPlaying || isPreviewPromotion {
                                await playerClient.setSubtitleTextScale(subtitleTextScale)
                            } else {
                                do {
                                    let playbackURL: URL
                                    let activeURL: URL
                                    if requiresAuthenticatedMediaServer {
                                        guard let config,
                                              let resolvedItem = try await iptvClient.resolveVODItem(
                                                  config,
                                                  itemID,
                                                  nil,
                                                  selectedMediaServerPlaybackSourceID
                                              ),
                                              let resolvedURL = resolvedItem.streamURL
                                        else { throw NetworkError.invalidResponse }
                                        activeURL = resolvedURL
                                        playbackURL = try await MediaServerStreamProxy.shared.makePlaybackURL(
                                            for: activeURL,
                                            config: config,
                                            additionalHeaders: resolvedItem.playbackRequestHeaders
                                        )
                                        guard let mediaServerPlaybackRequestID else {
                                            throw NetworkError.invalidResponse
                                        }
                                        await send(.mediaServerPlaybackResolved(
                                            requestID: mediaServerPlaybackRequestID,
                                            itemID: itemID,
                                            streamURL: activeURL,
                                            proxyURL: playbackURL,
                                            status: resolvedItem.serverPlaybackStatus
                                        ))
                                    } else {
                                        playbackURL = url
                                        activeURL = url
                                    }
                                    PlayerLogger.shared.info(
                                        category: "Playback",
                                        message: "Starting stream: \"\(itemTitle)\" [ID: \(itemID), Type: \(isLive ? "Live" : "VOD"), Engine: \(playbackEngine.rawValue), URL: \(activeURL.absoluteString)]"
                                    )
                                    let playbackResult = try await playerClient.play(
                                        playbackURL,
                                        userAgentOverride,
                                        networkCachingMilliseconds,
                                        deinterlaceMode,
                                        playbackEngine,
                                        audioName,
                                        preferredAudioLanguage,
                                        subtitleName,
                                        preferredSubtitleLanguage
                                    )
                                    await send(.deinterlaceModePlaybackResolved(requested: deinterlaceMode, applied: playbackResult.deinterlaceMode, engine: playbackResult.engine, revision: deinterlaceModeRevision, itemID: itemID, streamURL: activeURL))
                                    await playerClient.setSubtitleTextScale(subtitleTextScale)
                                    if settingsClient.startMuted() {
                                        try? await playerClient.setVolume(0)
                                    }

                                } catch {
                                    PlayerLogger.shared.error(
                                        category: "Playback",
                                        message: "Playback start failed for \"\(itemTitle)\": \(error.localizedDescription) [URL: \(url.absoluteString)]"
                                    )
                                    print("Player error: \(error)")
                                    await send(.playbackEngineStartFailed(
                                        engine: playerClient.activeEngine(),
                                        itemID: itemID,
                                        streamURL: url,
                                        playbackRequestID: playbackRequestID
                                    ))
                                    await send(.handlePlayerEvent(.encounteredError))
                                }
                            }
                        }
                    }
                }
                .cancellable(id: CancelID.playerEvents, cancelInFlight: true),
                Self.listenForNowPlayingCommands(
                    playbackRequestID: state.playbackRequestID,
                    generation: state.nowPlayingGeneration,
                    client: nowPlayingClient
                )
            )

        case let .startSelectedChannel(id):
            guard state.item.id == id else { return .none }
            let appearanceEffect = Self.reduceHelper(
                state: &state,
                action: .onAppear,
                playerClient: playerClient,
                databaseClient: databaseClient,
                iptvClient: iptvClient,
                mediaServerClient: mediaServerClient,
                settingsClient: settingsClient,
                downloadClient: downloadClient,
                recentChannelsClient: recentChannelsClient,
                streamHealthClient: streamHealthClient,
                pipClient: pipClient,
                parentalControlClient: parentalControlClient,
                displayModeClient: displayModeClient,
                customEPGMappingClient: customEPGMappingClient,
                playbackSkipMarkerClient: playbackSkipMarkerClient,
                playlistRepository: playlistRepository,
                profileContextClient: profileContextClient,
                viewingStatisticsClient: viewingStatisticsClient,
                nowPlayingClient: nowPlayingClient,
                continuousClock: continuousClock
            )
            return .merge(appearanceEffect, .send(.fetchEPG))

        case let .mediaServerPlaybackOptionsLoaded(requestID, itemID, result):
            guard state.mediaServerPlaybackOptionsRequestID == requestID,
                  state.item.id == itemID,
                  let config = state.item.config,
                  config.type == .plex || config.type == .emby
            else { return .none }
            state.mediaServerPlaybackOptionsRequestID = nil
            switch result {
            case let .success(options) where options.count > 1:
                state.mediaServerPlaybackOptions = options
                state.isMediaServerPlaybackOptionsPresented = true
                return .none
            case let .success(options):
                state.mediaServerPlaybackOptions = []
                state.isMediaServerPlaybackOptionsPresented = false
                state.mediaServerPlaybackOptionsCheckedItemID = itemID
                state.selectedMediaServerPlaybackSourceID = options.first?.id
                return .send(.onAppear)
            case .failure:
                state.mediaServerPlaybackOptions = []
                state.isMediaServerPlaybackOptionsPresented = false
                state.mediaServerPlaybackOptionsCheckedItemID = itemID
                state.selectedMediaServerPlaybackSourceID = nil
                return .send(.onAppear)
            }

        case let .selectMediaServerPlaybackSource(sourceID):
            guard state.isMediaServerPlaybackOptionsPresented,
                  state.mediaServerPlaybackOptions.contains(where: { $0.id == sourceID })
            else { return .none }
            state.mediaServerPlaybackOptions = []
            state.isMediaServerPlaybackOptionsPresented = false
            state.mediaServerPlaybackOptionsCheckedItemID = state.item.id
            state.selectedMediaServerPlaybackSourceID = sourceID
            return .send(.onAppear)

        case .cancelMediaServerPlaybackSourceSelection:
            guard state.isMediaServerPlaybackOptionsPresented else { return .none }
            state.mediaServerPlaybackOptions = []
            state.isMediaServerPlaybackOptionsPresented = false
            state.mediaServerPlaybackOptionsCheckedItemID = nil
            state.selectedMediaServerPlaybackSourceID = nil
            return .send(.closeTapped)

        case .onDisappear:
            guard !state.isClosing else { return .none }
            let reducerCurrentTime = state.currentTime
            let totalSecs = Self.durationSeconds(state.totalTime)
            let item = state.item
            let mediaServerProxyURL = state.mediaServerProxyURL
            let profileScope = profileContextClient.snapshot()
            let isPiPActive = state.isPiPActive
            let isMinimized = state.isMinimized
            state.scrubThumbnailRequestID = nil
            state.scrubThumbnailData = nil

            // If transitioning to In-App MiniPlayer or PiP is active, keep player alive and active!
            if isMinimized || isPiPActive {
                return .merge(
                    .cancel(id: CancelID.scrubThumbnail),
                    Self.stopLiveVideoStallMonitoring(state: &state)
                )
            }
            let viewingStatisticsFlush = Self.flushViewingStatistics(state: &state, client: viewingStatisticsClient)
            state.isClosing = true
            state.subtitleReplaySession = nil
            state.offlineEpisodeTransitionRequestID = nil
            state.sourcePlaylistNameRequestID = nil
            state.memoryPressureDeinterlaceFallbackRequestID = nil
            state.playbackRequestID = UUID()
            state.mediaInfoRequestID = nil
            state.firstPresentedFrameLatency = nil
            state.firstPresentedFrameFeedbackRequestID = nil
            state.activeVODSeekRequestID = nil
            state.vodSeekTimelineRecoveryRequired = false
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            state.expectedVODSeekTargetSeconds = nil
            state.expectedVODSeekTargetPosition = nil
            state.vodSeekPreviousPosition = nil
            state.vodSeekPreviousTime = nil
            state.vodSeekFailureRequestID = nil
            state.didRequestXtreamLiveOutputFormats = false
            state.isLoadingXtreamLiveOutputFormats = false
            state.xtreamLiveOutputFormatOptions = []
            state.xtreamLiveOutputFormatError = nil
            state.activeXtreamLiveOutputFormatRequestID = nil
            state.mediaServerPlaybackRequestID = nil
            state.mediaServerPlaybackOptionsRequestID = nil
            state.mediaServerPlaybackOptions = []
            state.isMediaServerPlaybackOptionsPresented = false
            state.mediaServerProxyURL = nil
            state.activeCatchupSeekRequestID = nil
            state.catchupSeekPreviousTime = nil
            state.catchupSeekPreviousPosition = nil
            state.catchupSeekExpectedTimeSeconds = nil
            state.catchupSeekExpectedPosition = nil
            state.catchupSeekTimelineRecoveryRequired = false
            state.catchupSeekFailureMessage = nil
            state.catchupSeekFailureRequestID = nil
            state.displayModeRequestID = UUID()
            Self.resetLiveVideoStallTracking(state: &state)

            return .merge(
                viewingStatisticsFlush,
                .cancel(id: CancelID.channelSwitch),
                .cancel(id: CancelID.mediaServerPlaybackOptions),
                .cancel(id: CancelID.scrubThumbnail),
                .cancel(id: CancelID.sourcePlaylistName),
                .cancel(id: CancelID.xtreamLiveOutputFormats),
                .cancel(id: CancelID.catchupSeek),
                .cancel(id: CancelID.catchupSeekFeedback),
                .cancel(id: CancelID.vodSeek),
                .cancel(id: CancelID.vodSeekFeedback),
                .cancel(id: CancelID.initialResumeSeekVerification),
                .cancel(id: CancelID.subtitleReplaySeek),
                .cancel(id: CancelID.subtitleReplayTrackSelection),
                .cancel(id: CancelID.highFPSFeedback),
                .cancel(id: CancelID.playerEvents),
                .cancel(id: CancelID.memoryPressureWarnings),
                .cancel(id: CancelID.memoryPressureDeinterlaceFallback),
                .cancel(id: CancelID.playbackEngineSwitch),
                .cancel(id: CancelID.seriesPlaylist),
                .cancel(id: CancelID.oledDimTimer),
                .cancel(id: CancelID.audioRoute),
                .cancel(id: CancelID.audioRouteHUD),
                .cancel(id: CancelID.upNextCountdown),
                .cancel(id: CancelID.offlineEpisodeAvailability),
                .cancel(id: CancelID.statsTimer),
                Self.deactivateNowPlaying(state: &state, client: nowPlayingClient),
                .cancel(id: CancelID.liveVideoStallMonitor),
                .cancel(id: CancelID.stallWatchdog),
                .cancel(id: CancelID.reconnectTimer),
                .cancel(id: CancelID.dynamicRangeHUD),
                .cancel(id: CancelID.afrToast),
                .cancel(id: CancelID.displayMode),
                .run { _ in
                    await displayModeClient.resetDisplayMode()
                },
                .run { send in
                    #if os(iOS)
                        await MainActor.run {
                            OrientationManager.shared.unlockPortrait()
                        }
                    #endif
                    let savedTime = await playerClient.currentPlaybackTime() ?? reducerCurrentTime
                    let currentSecs = Self.durationSeconds(savedTime)
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
                        do {
                            try await databaseClient.saveWatchProgress(historyItem, profileScope)
                            PlayerLogger.shared.info(
                                category: "PlaybackProgress",
                                message: "Saved progress on disappear for \(item.id) at \(currentSecs)s"
                            )
                        } catch {
                            PlayerLogger.shared.error(
                                category: "PlaybackProgress",
                                message: "Failed to save progress on disappear for \(item.id): \(error.localizedDescription)"
                            )
                        }
                    }

                    if !isPiPActive {
                        try? await playerClient.stop()
                        await playerClient.release()
                        await MediaServerStreamProxy.shared.closeSession(for: mediaServerProxyURL)
                        await send(.delegate(.didClose))
                    }
                }
            )

        case let .setAudioDelay(delay):
            guard state.playbackEngine == .vlc else { return .none }
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
            guard state.playbackEngine == .vlc else { return .none }
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
            guard state.playbackEngine == .vlc else { return .none }
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
                let timerEffect = Self.beginStreamHealthSampling(
                    state: &state,
                    playerClient: playerClient,
                    streamHealthClient: streamHealthClient
                )
                return .merge(fetchInfoEffect, timerEffect)
            } else if !state.isStreamHealthHUDVisible {
                state.streamHealthGenerationID = UUID()
                state.streamHealthMetrics = nil
                return .cancel(id: CancelID.statsTimer)
            } else {
                return beginStreamHealthSampling(
                    state: &state,
                    playerClient: playerClient,
                    streamHealthClient: streamHealthClient
                )
            }

        case let .updateStats(stats, itemID, generationID):
            guard state.item.id == itemID, state.streamHealthGenerationID == generationID else { return .none }
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
                return beginStreamHealthSampling(
                    state: &state,
                    playerClient: playerClient,
                    streamHealthClient: streamHealthClient
                )
            } else if !state.isShowingStats {
                state.streamHealthGenerationID = UUID()
                state.streamHealthMetrics = nil
                return .cancel(id: CancelID.statsTimer)
            } else {
                return beginStreamHealthSampling(
                    state: &state,
                    playerClient: playerClient,
                    streamHealthClient: streamHealthClient
                )
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
                state.streamHealthGenerationID = UUID()
                state.streamHealthMetrics = nil
                return .cancel(id: CancelID.statsTimer)
            }
            guard visible || state.isShowingStats else { return .none }
            return Self.beginStreamHealthSampling(
                state: &state,
                playerClient: playerClient,
                streamHealthClient: streamHealthClient
            )

        case let .updateStreamHealth(metrics, itemID, generationID):
            guard state.item.id == itemID, state.streamHealthGenerationID == generationID else { return .none }
            state.streamHealthMetrics = metrics
            return .none

        case let .startStreamHealthSampling(itemID, generationID):
            guard
                state.item.id == itemID,
                state.streamHealthGenerationID == generationID,
                state.isShowingStats || state.isStreamHealthHUDVisible
            else { return .none }
            return Self.beginStreamHealthSampling(
                state: &state,
                playerClient: playerClient,
                streamHealthClient: streamHealthClient
            )

        case let .startLiveVideoStallMonitoring(itemID, playbackRequestID):
            return Self.startLiveVideoStallMonitoring(
                state: &state,
                playerClient: playerClient,
                itemID: itemID,
                playbackRequestID: playbackRequestID
            )

        case let .liveVideoStallSample(counters, uptimeNanoseconds, itemID, playbackRequestID, monitorID):
            guard state.item.id == itemID,
                  state.playbackRequestID == playbackRequestID,
                  state.liveVideoStallMonitorID == monitorID,
                  Self.canMonitorLiveVideoStall(state: state)
            else { return .none }

            guard counters.presentedFrames > 0 else {
                state.isLiveVideoStallDetected = false
                state.liveVideoStallNoFrameStartUptimeNanoseconds = nil
                state.liveVideoStallLastCounters = counters
                state.liveVideoStallLastSampleUptimeNanoseconds = uptimeNanoseconds
                state.liveVideoStallLastPlaybackTime = state.currentTime
                state.liveVideoStallLastClockAdvanceUptimeNanoseconds = nil
                return .none
            }

            guard let previousCounters = state.liveVideoStallLastCounters,
                  let previousUptime = state.liveVideoStallLastSampleUptimeNanoseconds,
                  let previousPlaybackTime = state.liveVideoStallLastPlaybackTime,
                  uptimeNanoseconds > previousUptime
            else {
                state.isLiveVideoStallDetected = false
                state.liveVideoStallLastCounters = counters
                state.liveVideoStallLastSampleUptimeNanoseconds = uptimeNanoseconds
                state.liveVideoStallLastPlaybackTime = state.currentTime
                state.liveVideoStallLastClockAdvanceUptimeNanoseconds = nil
                state.liveVideoStallNoFrameStartUptimeNanoseconds = nil
                return .none
            }

            let playbackTimeMovedBackward = state.currentTime < previousPlaybackTime
            let countersReset = counters.presentedFrames < previousCounters.presentedFrames
            let sampleGapNanoseconds = uptimeNanoseconds - previousUptime
            let sampleGapIsUsable = sampleGapNanoseconds <= Self.liveVideoClockStaleToleranceNanoseconds

            if playbackTimeMovedBackward || countersReset || !sampleGapIsUsable {
                state.isLiveVideoStallDetected = false
                state.liveVideoStallNoFrameStartUptimeNanoseconds = nil
                state.liveVideoStallLastClockAdvanceUptimeNanoseconds = nil
            }

            if state.currentTime > previousPlaybackTime {
                state.liveVideoStallLastClockAdvanceUptimeNanoseconds = uptimeNanoseconds
            }

            if counters.presentedFrames > previousCounters.presentedFrames {
                state.isLiveVideoStallDetected = false
                state.liveVideoStallNoFrameStartUptimeNanoseconds = nil
            } else if !playbackTimeMovedBackward,
                      !countersReset,
                      sampleGapIsUsable,
                      let lastClockAdvance = state.liveVideoStallLastClockAdvanceUptimeNanoseconds,
                      uptimeNanoseconds >= lastClockAdvance,
                      uptimeNanoseconds - lastClockAdvance <= Self.liveVideoClockStaleToleranceNanoseconds
            {
                let noFrameStart = state.liveVideoStallNoFrameStartUptimeNanoseconds ?? previousUptime
                state.liveVideoStallNoFrameStartUptimeNanoseconds = noFrameStart
                state.isLiveVideoStallDetected = uptimeNanoseconds >= noFrameStart
                    && uptimeNanoseconds - noFrameStart >= Self.liveVideoStallThresholdNanoseconds
            } else {
                state.isLiveVideoStallDetected = false
                state.liveVideoStallNoFrameStartUptimeNanoseconds = nil
            }

            state.liveVideoStallLastCounters = counters
            state.liveVideoStallLastSampleUptimeNanoseconds = uptimeNanoseconds
            state.liveVideoStallLastPlaybackTime = state.currentTime
            return .none

        case let .nowPlayingSessionActivated(playbackRequestID, generation):
            guard state.playbackRequestID == playbackRequestID,
                  state.nowPlayingGeneration == generation,
                  !state.isClosing
            else { return .none }
            return Self.updateNowPlaying(state: state, client: nowPlayingClient)

        case let .nowPlayingRemoteCommand(command):
            guard !state.isClosing || state.isPiPActive,
                  !state.isSwitchingPlaybackEngine,
                  !state.isNowPlayingSuppressed,
                  command.playbackRequestID == state.playbackRequestID
            else { return .none }
            let isPlaying = state.playerState == .playing || state.playerState == .buffering
            switch command {
            case .play:
                return isPlaying && !state.isUserPaused ? .none : .send(.play)
            case .pause:
                return isPlaying && !state.isUserPaused ? .send(.pause) : .none
            case .togglePlayback:
                return isPlaying && !state.isUserPaused ? .send(.pause) : .send(.play)
            case .skipForward:
                guard !state.item.isLive || state.isPlayingCatchup else { return .none }
                return .send(.jumpBySeconds(state.skipIntervalSeconds))
            case .skipBackward:
                guard !state.item.isLive || state.isPlayingCatchup else { return .none }
                return .send(.jumpBySeconds(-state.skipIntervalSeconds))
            case let .seek(seconds, _):
                guard !state.item.isLive || state.isPlayingCatchup, seconds.isFinite else { return .none }
                let totalSeconds = state.isPlayingCatchup
                    ? state.catchupArchiveDurationSeconds
                    : Self.nowPlayingMetadata(for: state).duration
                let targetSeconds = max(0, totalSeconds.map { min($0, seconds) } ?? seconds)
                return .send(.seekToTime(.seconds(targetSeconds)))
            }

        case .play:
            guard !state.isSwitchingPlaybackEngine else { return .none }
            let requiresPositionRecovery = state.vodSeekTimelineRecoveryRequired
                || state.catchupSeekTimelineRecoveryRequired
            state.isNowPlayingSuppressed = false
            state.isUserPaused = false
            state.oledInactivitySeconds = 0
            state.oledDimLevel = 0.0
            state.isDeepDimmed = false
            if requiresPositionRecovery {
                return .merge(
                    .send(.initiateAutoReconnect),
                    updateNowPlaying(state: state, client: nowPlayingClient)
                )
            }
            let playbackRate = state.playbackRate
            return .merge(
                .run { _ in
                    try await playerClient.resume(playbackRate)
                },
                updateNowPlaying(state: state, client: nowPlayingClient)
            )

        case .pause:
            guard !state.isSwitchingPlaybackEngine else { return .none }
            state.isUserPaused = true
            state.pendingInitialResumeSeekTargetSeconds = nil
            state.isDispatchingInitialResumeSeek = false
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            let cancelSubtitleReplay = state.subtitleReplaySession == nil
                ? Effect<Action>.none
                : .merge(
                    .cancel(id: CancelID.subtitleReplaySeek),
                    .cancel(id: CancelID.subtitleReplayTrackSelection)
                )
            state.subtitleReplaySession = nil
            state.oledInactivitySeconds = 0
            return .merge(
                cancelSubtitleReplay,
                .cancel(id: CancelID.initialResumeSeekVerification),
                stopLiveVideoStallMonitoring(state: &state),
                .cancel(id: CancelID.stallWatchdog),
                .run { _ in
                    try await playerClient.pause()
                },
                updateNowPlaying(state: state, client: nowPlayingClient)
            )

        case .stop:
            state.isNowPlayingSuppressed = true
            state.subtitleReplaySession = nil
            let shouldStopRecording = state.isRecording || state.isRecordingStartPending
            let mediaServerProxyURL = state.mediaServerProxyURL
            state.mediaServerPlaybackRequestID = nil
            state.mediaServerProxyURL = nil
            state.isSwitchingPlaybackEngine = false
            state.playbackEngineSwitchID = nil
            state.playbackRequestID = UUID()
            state.playbackRecoveryErrorMessage = nil
            state.playbackPositionRecoveryRequestID = nil
            state.playbackPositionRecoveryExpectedPosition = nil
            state.pendingInitialResumeSeekTargetSeconds = nil
            state.isDispatchingInitialResumeSeek = false
            state.mediaInfoRequestID = nil
            state.firstPresentedFrameLatency = nil
            state.firstPresentedFrameFeedbackRequestID = nil
            state.activeVODSeekRequestID = nil
            state.vodSeekTimelineRecoveryRequired = false
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            state.expectedVODSeekTargetSeconds = nil
            state.expectedVODSeekTargetPosition = nil
            state.vodSeekPreviousPosition = nil
            state.vodSeekPreviousTime = nil
            state.vodSeekFailureRequestID = nil
            state.didRequestXtreamLiveOutputFormats = false
            state.isLoadingXtreamLiveOutputFormats = false
            state.xtreamLiveOutputFormatOptions = []
            state.xtreamLiveOutputFormatError = nil
            state.activeXtreamLiveOutputFormatRequestID = nil
            Self.resetLiveVideoStallTracking(state: &state)
            return .merge(
                .cancel(id: CancelID.liveVideoStallMonitor),
                .cancel(id: CancelID.playbackEngineSwitch),
                .cancel(id: CancelID.vodSeek),
                .cancel(id: CancelID.vodSeekFeedback),
                .cancel(id: CancelID.initialResumeSeekVerification),
                .cancel(id: CancelID.subtitleReplaySeek),
                .cancel(id: CancelID.subtitleReplayTrackSelection),
                .cancel(id: CancelID.xtreamLiveOutputFormats),
                .cancel(id: CancelID.highFPSFeedback),
                Self.clearNowPlaying(state: &state, client: nowPlayingClient),
                .run { send in
                    if shouldStopRecording {
                        await playerClient.requestRecordingStop()
                        await send(.recordingStopUnconfirmed)
                    }
                    try await playerClient.stop()
                    await MediaServerStreamProxy.shared.closeSession(for: mediaServerProxyURL)
                }
            )

        case .requestXtreamLiveOutputFormats:
            guard state.errorMessage != nil,
                  !state.isReconnecting,
                  !state.isSwitchingPlaybackEngine,
                  !state.isLoadingXtreamLiveOutputFormats,
                  state.item.isLive,
                  !state.isPlayingCatchup,
                  state.activeCatchupProgram == nil,
                  let config = state.item.config,
                  config.type == .xtream,
                  let playlistID = config.playlistID else { return .none }
            let requestID = UUID()
            let itemID = state.item.id
            state.didRequestXtreamLiveOutputFormats = true
            state.isLoadingXtreamLiveOutputFormats = true
            state.xtreamLiveOutputFormatOptions = []
            state.xtreamLiveOutputFormatError = nil
            state.activeXtreamLiveOutputFormatRequestID = requestID
            return .run { send in
                do {
                    let formats = try await iptvClient.fetchSupportedXtreamLiveOutputFormats(config)
                    await send(.xtreamLiveOutputFormatsResponse(
                        requestID: requestID,
                        itemID: itemID,
                        playlistID: playlistID,
                        configuration: config,
                        result: .success(formats)
                    ))
                } catch is CancellationError {
                    return
                } catch {
                    await send(.xtreamLiveOutputFormatsResponse(
                        requestID: requestID,
                        itemID: itemID,
                        playlistID: playlistID,
                        configuration: config,
                        result: .failure(error)
                    ))
                }
            }
            .cancellable(id: CancelID.xtreamLiveOutputFormats, cancelInFlight: true)

        case let .xtreamLiveOutputFormatsResponse(requestID, itemID, playlistID, configuration, result):
            guard state.activeXtreamLiveOutputFormatRequestID == requestID else { return .none }
            state.activeXtreamLiveOutputFormatRequestID = nil
            state.isLoadingXtreamLiveOutputFormats = false
            guard state.item.id == itemID,
                  state.item.config?.playlistID == playlistID,
                  state.item.config == configuration,
                  state.errorMessage != nil,
                  !state.isReconnecting,
                  state.item.isLive,
                  !state.isPlayingCatchup,
                  state.activeCatchupProgram == nil
            else {
                state.didRequestXtreamLiveOutputFormats = false
                state.xtreamLiveOutputFormatOptions = []
                state.xtreamLiveOutputFormatError = nil
                return .none
            }
            switch result {
            case let .success(formats):
                state.xtreamLiveOutputFormatOptions = Array(Set(formats))
                    .filter { $0 != configuration.xtreamLiveOutputFormat }
                    .sorted { $0.rawValue < $1.rawValue }
                state.xtreamLiveOutputFormatError = nil
            case .failure:
                state.xtreamLiveOutputFormatOptions = []
                state.xtreamLiveOutputFormatError = "Sağlayıcı biçimleri alınamadı."
            }
            return .none

        case let .selectXtreamLiveOutputFormat(format):
            guard state.errorMessage != nil,
                  !state.isReconnecting,
                  !state.isSwitchingPlaybackEngine,
                  state.item.isLive,
                  !state.isPlayingCatchup,
                  state.activeCatchupProgram == nil,
                  state.xtreamLiveOutputFormatOptions.contains(format),
                  let config = state.item.config,
                  config.type == .xtream,
                  config.xtreamLiveOutputFormat != format,
                  let playlistID = config.playlistID else { return .none }
            let updatedConfig = config.replacingXtreamLiveOutputFormat(format)
            guard let currentStreamURL = makeXtreamLiveStreamURL(config: updatedConfig, streamID: state.item.id) else {
                state.xtreamLiveOutputFormatError = "Yayın bağlantısı oluşturulamadı."
                return .none
            }
            guard let savedPlaylist = playlistRepository.getPlaylists().first(where: { $0.id == playlistID }),
                  playlistRepository.updatePlaylist(savedPlaylist.replacingXtreamLiveOutputFormat(format))
            else {
                state.xtreamLiveOutputFormatError = "Biçim tercihi kaydedilemedi."
                return .none
            }

            func updatedItem(_ item: PlayableItem) -> PlayableItem {
                guard item.config?.playlistID == playlistID else { return item }
                if item.isLive, let streamURL = makeXtreamLiveStreamURL(config: updatedConfig, streamID: item.id) {
                    return item.replacingLiveStreamURL(streamURL, playlistConfig: updatedConfig)
                }
                return item.replacingPlaylistConfig(updatedConfig)
            }

            let selectedItem = state.item.replacingLiveStreamURL(currentStreamURL, playlistConfig: updatedConfig)
            state.item = selectedItem
            state.activePlaybackURL = currentStreamURL
            Self.loadRememberedPlaybackChoice(state: &state, profileScope: profileContextClient.snapshot())
            state.playlist = state.playlist?.map(updatedItem)
            state.liveChannels = state.liveChannels.map(updatedItem)
            state.epgBrowseChannel = state.epgBrowseChannel.map(updatedItem)
            state.didRequestXtreamLiveOutputFormats = false
            state.xtreamLiveOutputFormatOptions = []
            state.xtreamLiveOutputFormatError = nil
            return .merge(
                .send(.delegate(.didSelectXtreamLiveOutputFormat(updatedConfig))),
                .send(.retryPlayback)
            )

        case .retryPlayback:
            guard !state.isSwitchingPlaybackEngine else { return .none }
            state.didRequestXtreamLiveOutputFormats = false
            state.isLoadingXtreamLiveOutputFormats = false
            state.xtreamLiveOutputFormatOptions = []
            state.xtreamLiveOutputFormatError = nil
            state.activeXtreamLiveOutputFormatRequestID = nil
            let shouldStopRecording = state.isRecording || state.isRecordingStartPending
            state.errorMessage = nil
            state.isUserPaused = false
            if state.retryCount >= state.maxReconnectAttempts {
                state.retryCount = 0
                state.failedStreamIDs.removeAll()
            }
            state.isReconnecting = true
            state.isDeinterlaceModeKnown = false
            state.playbackRequestID = UUID()
            Self.resetLiveVideoStallTracking(state: &state)
            state.mediaInfoRequestID = nil
            state.mediaInfo = nil
            state.firstPresentedFrameLatency = nil
            state.firstPresentedFrameFeedbackRequestID = nil
            if state.activeVODSeekRequestID != nil {
                if let previousTime = state.vodSeekPreviousTime {
                    state.currentTime = previousTime
                }
                if let previousPosition = state.vodSeekPreviousPosition {
                    state.position = previousPosition
                }
            }
            state.activeVODSeekRequestID = nil
            state.vodSeekTimelineRecoveryRequired = false
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            state.expectedVODSeekTargetSeconds = nil
            state.expectedVODSeekTargetPosition = nil
            state.vodSeekPreviousPosition = nil
            state.vodSeekPreviousTime = nil
            state.vodSeekFailureRequestID = nil
            state.playbackPositionRecoveryRequestID = nil
            state.playbackPositionRecoveryExpectedPosition = nil
            let url = state.activePlaybackURL
            let playbackRequestID = state.playbackRequestID
            let oldMediaServerProxyURL = state.mediaServerProxyURL
            state.mediaServerProxyURL = nil
            state.streamHealthGenerationID = UUID()
            state.streamHealthMetrics = nil
            let isLive = state.item.isLive
            let shouldRestorePosition = Self.shouldRestorePositionOnPlaybackStart(
                isLive: isLive,
                isPlayingCatchup: state.activeCatchupProgram != nil,
                initialProgress: state.hasAppliedInitialSeek ? nil : state.item.initialProgress
            )
            let resumeTime = state.pendingInitialResumeSeekTargetSeconds.map(Duration.seconds)
                ?? state.currentTime
            let durationComponents = state.totalTime.components
            let resumeTimeComponents = resumeTime.components
            let durationSeconds = Double(durationComponents.seconds)
                + Double(durationComponents.attoseconds) / 1_000_000_000_000_000_000
            let resumeTimeSeconds = Double(resumeTimeComponents.seconds)
                + Double(resumeTimeComponents.attoseconds) / 1_000_000_000_000_000_000
            let position: Double = if resumeTime > .zero, durationSeconds > 0 {
                max(0, min(1, resumeTimeSeconds / durationSeconds))
            } else if state.position > 0 {
                state.position
            } else if state.activeCatchupProgram == nil, !state.hasAppliedInitialSeek {
                state.item.startPosition ?? 0.0
            } else {
                0.0
            }
            let currentRate = state.playbackRate
            let userAgentOverride = state.item.userAgentOverride
            let playbackKind = state.playbackContentKind
            let playbackDefaults = settingsClient.playbackDefaults(playbackKind)
            state.playbackEngine = Self.resolvedPlaybackEngine(
                item: state.item,
                kind: playbackKind,
                defaults: playbackDefaults,
                settingsClient: settingsClient,
                profileID: profileContextClient.snapshot().profileID
            )
            state.deinterlaceMode = playbackDefaults.deinterlaceMode
            let networkCachingMilliseconds = playbackDefaults.networkCachingMilliseconds(for: playbackKind)
            let subtitleTextScale = playbackDefaults.subtitleTextSize.scale
            let preferredAudioLanguage = playbackDefaults.preferredAudioLanguage
            let preferredSubtitleLanguage = playbackDefaults.preferredSubtitleLanguage
            let playbackEngine = state.playbackEngine
            let audioName = Self.savedAudioTrackName(itemID: state.item.id, settingsClient: settingsClient)
            let subtitleName = Self.savedSubtitleTrackName(itemID: state.item.id, settingsClient: settingsClient)
            let deinterlaceMode = state.deinterlaceMode
            let deinterlaceModeRevision = state.deinterlaceModeRevision
            let itemID = state.item.id
            let itemTitle = state.item.title
            let selectedMediaServerPlaybackSourceID = state.selectedMediaServerPlaybackSourceID
            state.playbackPositionRecoveryRequestID = shouldRestorePosition && position > 0 ? playbackRequestID : nil
            state.playbackPositionRecoveryExpectedPosition = state.playbackPositionRecoveryRequestID == nil ? nil : position
            let categoryID = state.item.categoryID
            let config = state.item.config
            let requiresAuthenticatedMediaServer = config?.type == .plex || config?.type == .emby
            let mediaServerPlaybackRequestID = UUID()
            state.mediaServerPlaybackRequestID = requiresAuthenticatedMediaServer ? mediaServerPlaybackRequestID : nil
            return .concatenate(
                .cancel(id: CancelID.statsTimer),
                .cancel(id: CancelID.liveVideoStallMonitor),
                .cancel(id: CancelID.vodSeek),
                .cancel(id: CancelID.vodSeekFeedback),
                .cancel(id: CancelID.xtreamLiveOutputFormats),
                .cancel(id: CancelID.highFPSFeedback),
                .run { send in
                    // Flush and cleanly reset VLC engine to avoid pipeline lockups
                    if shouldStopRecording {
                        await playerClient.requestRecordingStop()
                        await send(.recordingStopUnconfirmed)
                    }
                    try? await playerClient.stop()
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    await MediaServerStreamProxy.shared.closeSession(for: oldMediaServerProxyURL)

                    let eventsStream = await playerClient.events()
                    let healthBaseline = await playerClient.playbackHealthSnapshot()
                    let healthStream = await playerClient.playbackHealthEvents()
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            for await event in eventsStream {
                                guard !Task.isCancelled else { return }
                                await send(.handlePlayerEvent(event))
                            }
                        }

                        if let healthBaseline {
                            group.addTask {
                                for await event in healthStream {
                                    guard !Task.isCancelled else { return }
                                    await send(.playbackHealthEvent(
                                        event,
                                        itemID: itemID,
                                        playbackRequestID: playbackRequestID,
                                        baselineGeneration: healthBaseline.generation,
                                        baselineHadPresentedFrame: healthBaseline.lastPresentedAt != nil
                                    ))
                                }
                            }
                        }

                        group.addTask {
                            do {
                                let playbackURL: URL
                                let activeURL: URL
                                if requiresAuthenticatedMediaServer {
                                    guard let config,
                                          let resolvedItem = try await iptvClient.resolveVODItem(
                                              config,
                                              itemID,
                                              categoryID,
                                              selectedMediaServerPlaybackSourceID
                                          ),
                                          let resolvedURL = resolvedItem.streamURL
                                    else { throw NetworkError.invalidResponse }
                                    activeURL = resolvedURL
                                    playbackURL = try await MediaServerStreamProxy.shared.makePlaybackURL(
                                        for: activeURL,
                                        config: config,
                                        additionalHeaders: resolvedItem.playbackRequestHeaders
                                    )
                                    await send(.mediaServerPlaybackResolved(
                                        requestID: mediaServerPlaybackRequestID,
                                        itemID: itemID,
                                        streamURL: activeURL,
                                        proxyURL: playbackURL,
                                        status: resolvedItem.serverPlaybackStatus
                                    ))
                                } else {
                                    playbackURL = url
                                    activeURL = url
                                }
                                let playbackResult = try await playerClient.play(
                                    playbackURL,
                                    userAgentOverride,
                                    networkCachingMilliseconds,
                                    deinterlaceMode,
                                    playbackEngine,
                                    audioName,
                                    preferredAudioLanguage,
                                    subtitleName,
                                    preferredSubtitleLanguage
                                )
                                await playerClient.setSubtitleTextScale(subtitleTextScale)
                                await send(.deinterlaceModePlaybackResolved(requested: deinterlaceMode, applied: playbackResult.deinterlaceMode, engine: playbackResult.engine, revision: deinterlaceModeRevision, itemID: itemID, streamURL: activeURL))
                                if shouldRestorePosition, position > 0 {
                                    var reachedPlayingState = false
                                    let maxChecks = isLive ? 200 : 800
                                    for _ in 0 ..< maxChecks {
                                        try Task.checkCancellation()
                                        let isPlaying = await MainActor.run { playerClient.isPlaying() }
                                        if isPlaying {
                                            reachedPlayingState = true
                                            break
                                        }
                                        try await Task.sleep(for: .milliseconds(50))
                                    }
                                    guard reachedPlayingState else {
                                        await send(.handlePlayerEvent(.encounteredError))
                                        return
                                    }
                                    let seekResult = await playerClient.seekAndConfirm(.position(position))
                                    try Task.checkCancellation()
                                    await send(.playbackPositionRecoveryFinished(
                                        seekResult,
                                        itemID: itemID,
                                        playbackRequestID: playbackRequestID
                                    ))
                                }
                                if currentRate != 1.0 {
                                    try? await playerClient.setPlaybackRate(currentRate)
                                }
                            } catch is CancellationError {
                                return
                            } catch {
                                print("Player retry error: \(error)")
                                await send(.playbackEngineStartFailed(
                                    engine: playerClient.activeEngine(),
                                    itemID: itemID,
                                    streamURL: url,
                                    playbackRequestID: playbackRequestID
                                ))
                                await send(.handlePlayerEvent(.encounteredError))
                            }
                        }
                    }
                }
                .cancellable(id: CancelID.playerEvents, cancelInFlight: true)
            )

        case let .switchPlaybackEngineFromError(target):
            guard let errorMessage = state.errorMessage,
                  state.canSwitchPlaybackEngine,
                  !state.isSwitchingPlaybackEngine,
                  target != state.playbackEngine
            else { return .none }
            state.playbackRecoveryErrorMessage = errorMessage
            state.errorMessage = nil
            state.isReconnecting = true
            state.didRequestXtreamLiveOutputFormats = false
            state.isLoadingXtreamLiveOutputFormats = false
            state.xtreamLiveOutputFormatOptions = []
            state.xtreamLiveOutputFormatError = nil
            state.activeXtreamLiveOutputFormatRequestID = nil
            return .merge(
                .cancel(id: CancelID.xtreamLiveOutputFormats),
                .send(.switchPlaybackEngine(target))
            )

        case let .playbackPositionRecoveryFinished(result, itemID, playbackRequestID):
            guard state.item.id == itemID,
                  state.playbackRequestID == playbackRequestID,
                  state.playbackPositionRecoveryRequestID == playbackRequestID
            else { return .none }
            let expectedPosition = state.playbackPositionRecoveryExpectedPosition
            state.playbackPositionRecoveryRequestID = nil
            state.playbackPositionRecoveryExpectedPosition = nil
            let timeSeconds = result.currentTime.map { time in
                Double(time.components.seconds) + Double(time.components.attoseconds) / 1_000_000_000_000_000_000
            }
            let durationSeconds = Double(state.totalTime.components.seconds)
                + Double(state.totalTime.components.attoseconds) / 1_000_000_000_000_000_000
            let position = result.position ?? timeSeconds.flatMap { time in
                durationSeconds.isFinite && durationSeconds > 0 ? time / durationSeconds : nil
            }
            let didRestorePosition = (result.status == .settled || result.status == .inaccurate)
                && timeSeconds?.isFinite == true
                && (timeSeconds ?? -1) >= 0
                && position?.isFinite == true
                && (position ?? -1) >= 0
                && (position ?? 2) <= 1
                && Self.seekLanded(
                    currentTime: result.currentTime,
                    position: result.position,
                    expectedSeconds: nil,
                    expectedPosition: expectedPosition,
                    durationSeconds: durationSeconds,
                    toleranceSeconds: result.status == .inaccurate ? 15 : 2
                )
            state.isReconnecting = false
            guard didRestorePosition, let currentTime = result.currentTime, let position else {
                return .send(.showGestureFeedback(AppStrings.Player.playbackPositionNotRestored))
            }
            state.currentTime = currentTime
            state.position = position
            if state.activeCatchupProgram != nil {
                state.catchupSeekTimelineRecoveryRequired = false
                state.catchupSeekPreviousTime = nil
                state.catchupSeekPreviousPosition = nil
            } else if !state.item.isLive {
                state.vodSeekTimelineRecoveryRequired = false
                state.vodSeekPreviousTime = nil
                state.vodSeekPreviousPosition = nil
            }
            let feedback = result.status == .settled
                ? AppStrings.Player.playbackPositionRestored
                : AppStrings.Player.playbackPositionRestoredApproximately
            return .send(.showGestureFeedback(feedback))

        case let .initialResumeSeekRequested(targetSeconds):
            guard !state.item.isLive,
                  !state.isPlayingCatchup,
                  !state.isSwitchingPlaybackEngine,
                  targetSeconds.isFinite,
                  targetSeconds > 1,
                  !state.isUserPaused,
                  !state.isClosing
            else { return .none }
            state.pendingInitialResumeSeekTargetSeconds = targetSeconds
            state.isDispatchingInitialResumeSeek = true
            return .send(.seekToTime(.seconds(targetSeconds)))

        case let .verifyInitialResumeSeek(itemID, playbackRequestID, targetSeconds, actualTime, verificationAttempt):
            guard state.item.id == itemID,
                  state.playbackRequestID == playbackRequestID,
                  !state.item.isLive,
                  !state.isUserPaused,
                  !state.isClosing,
                  state.initialResumeSeekRetryCount == 0,
                  state.pendingInitialResumeSeekTargetSeconds == targetSeconds,
                  targetSeconds.isFinite,
                  targetSeconds > 10,
                  verificationAttempt <= Self.maxInitialResumeSeekVerificationAttempt
            else { return .none }

            if state.playerState != .playing
                || state.activeVODSeekRequestID != nil
                || state.playbackPositionRecoveryRequestID != nil
                || actualTime == nil
            {
                guard verificationAttempt < Self.maxInitialResumeSeekVerificationAttempt else {
                    state.pendingInitialResumeSeekTargetSeconds = nil
                    return .none
                }
                return initialResumeSeekVerificationEffect(
                    itemID: itemID,
                    playbackRequestID: playbackRequestID,
                    targetSeconds: targetSeconds,
                    verificationAttempt: verificationAttempt + 1,
                    delay: .seconds(1),
                    clock: continuousClock,
                    playerClient: playerClient
                )
            }

            guard let actualTime else { return .none }
            let actualSeconds = Self.durationSeconds(actualTime)
            guard actualSeconds.isFinite else { return .none }
            guard actualSeconds + 3 < targetSeconds else {
                // The seek landed, or playback has naturally advanced beyond
                // the resume point. Either case ends the one-shot recovery.
                state.pendingInitialResumeSeekTargetSeconds = nil
                return .none
            }

            state.initialResumeSeekRetryCount = 1
            PlayerLogger.shared.warning(
                category: "PlaybackProgress",
                message: "Initial resume seek did not land for \(itemID); retrying once at \(targetSeconds)s (engine at \(Self.durationSeconds(actualTime))s)"
            )
            return .send(.initialResumeSeekRequested(targetSeconds: targetSeconds))

        case .streamStalled:
            PlayerLogger.shared.warning(
                category: "Stream",
                message: "Stream playback stalled / buffering watchdog fired for \"\(state.item.title)\""
            )
            guard !state.isUserPaused, !state.isMinimized else { return .none }
            if (state.activeVODSeekRequestID != nil || state.playbackPositionRecoveryRequestID != nil) && !state.item.isLive {
                PlayerLogger.shared.info(
                    category: "Stream",
                    message: "Deferring streamStalled during initial position recovery or seek for \"\(state.item.title)\""
                )
                return stallWatchdogEffect(clock: continuousClock, isLive: false)
            }
            if state.playerState == .buffering || state.playerState == .opening {
                return .send(.initiateAutoReconnect)
            }
            return .none

        case .initiateAutoReconnect:
            guard !state.isUserPaused, !state.isMinimized else { return .none }

            // If within retry limit for current item, attempt retry with progressive jittered exponential backoff
            if state.retryCount < state.maxReconnectAttempts {
                state.playbackPositionRecoveryRequestID = nil
                state.playbackPositionRecoveryExpectedPosition = nil
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

                PlayerLogger.shared.warning(
                    category: "Reconnect",
                    message: "Auto reconnecting \"\(state.item.title)\" (Attempt \(attempt)/\(state.maxReconnectAttempts), delay: \(String(format: "%.2f", backoffDelay))s)"
                )

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
                    PlayerLogger.shared.warning(
                        category: "Reconnect",
                        message: "Retries exhausted for \"\(state.item.title)\". Switching to backup channel \"\(failoverItem.title)\""
                    )
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
                    PlayerLogger.shared.error(
                        category: "Reconnect",
                        message: "All reconnect attempts failed for \"\(state.item.title)\". No backup source available."
                    )
                    state.isReconnecting = false
                    state.isFallbackSwitching = false
                    state.fallbackStreamName = nil
                    state.playbackPositionRecoveryRequestID = nil
                    state.playbackPositionRecoveryExpectedPosition = nil
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
            guard !state.isSwitchingPlaybackEngine else { return .none }
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
            guard !state.isSwitchingPlaybackEngine,
                  !state.item.isLive || state.isPlayingCatchup
            else { return .none }
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            let subtitleReplayCancellation: Effect<Action> = state.subtitleReplaySession == nil
                ? .none
                : .merge(
                    .cancel(id: CancelID.subtitleReplaySeek),
                    .cancel(id: CancelID.subtitleReplayTrackSelection)
                )
            state.subtitleReplaySession = nil
            if state.isPlayingCatchup {
                state.expectedVODSeekTargetSeconds = nil
                state.expectedVODSeekTargetPosition = nil
                let currentSeconds = Self.durationSeconds(state.currentTime)
                let rawTarget = currentSeconds + Double(offset)
                let catchupDuration = Self.catchupDurationSeconds(
                    reported: state.totalTime,
                    maximum: state.catchupArchiveDurationSeconds
                )
                state.catchupSeekExpectedTimeSeconds = max(
                    0,
                    catchupDuration.map { min($0, rawTarget) } ?? rawTarget
                )
                state.catchupSeekExpectedPosition = nil
                state.catchupSeekTimelineRecoveryRequired = false
                let requestID = UUID()
                let previousTime = state.activeCatchupSeekRequestID != nil
                    ? state.catchupSeekPreviousTime ?? state.currentTime
                    : state.currentTime
                let previousPosition = state.activeCatchupSeekRequestID != nil
                    ? state.catchupSeekPreviousPosition ?? state.position
                    : state.position
                state.activeCatchupSeekRequestID = requestID
                state.catchupSeekPreviousTime = previousTime
                state.catchupSeekPreviousPosition = previousPosition
                state.catchupSeekFailureMessage = nil
                state.catchupSeekFailureRequestID = nil
                return .merge(
                    subtitleReplayCancellation,
                    Self.catchupSeekEffect(
                        requestID: requestID,
                        itemID: state.item.id,
                        command: .relative(
                            seconds: offset,
                            maximumDurationSeconds: state.catchupArchiveDurationSeconds
                        ),
                        client: playerClient
                    )
                )
            }
            guard !state.item.isLive else { return .none }
            let currentSecs = Self.durationSeconds(state.currentTime)
            let totalSecs = Self.durationSeconds(state.totalTime)
            let targetSecs = max(0, currentSecs + Double(offset))
            let requestID = UUID()
            let previousPosition = state.activeVODSeekRequestID != nil
                ? state.vodSeekPreviousPosition ?? state.position
                : state.position
            let previousTime = state.activeVODSeekRequestID != nil
                ? state.vodSeekPreviousTime ?? state.currentTime
                : state.currentTime
            state.activeVODSeekRequestID = requestID
            state.vodSeekTimelineRecoveryRequired = false
            state.expectedVODSeekTargetSeconds = totalSecs > 0 ? min(totalSecs, targetSecs) : targetSecs
            state.expectedVODSeekTargetPosition = nil
            state.vodSeekPreviousPosition = previousPosition
            state.vodSeekPreviousTime = previousTime
            state.vodSeekFailureRequestID = nil
            let seekCommand: PlaybackSeekCommand
            if totalSecs > 0 {
                let clampedSecs = min(totalSecs, targetSecs)
                state.currentTime = .seconds(clampedSecs)
                state.position = clampedSecs / totalSecs
                seekCommand = .time(.seconds(clampedSecs))
            } else {
                state.currentTime = .seconds(targetSecs)
                seekCommand = .relative(seconds: offset)
            }
            let playbackRequestID = state.playbackRequestID
            let upNextEffect = updateUpNextState(state: &state, settingsClient: settingsClient)
            return .merge(
                subtitleReplayCancellation,
                Self.vodSeekEffect(
                    requestID: requestID,
                    itemID: state.item.id,
                    playbackRequestID: playbackRequestID,
                    command: seekCommand,
                    client: playerClient
                ),
                upNextEffect,
                Self.updateNowPlaying(state: state, client: nowPlayingClient)
            )

        case .replayWithSubtitles:
            guard state.canReplayWithSubtitles,
                  state.subtitleReplaySession == nil,
                  state.activeVODSeekRequestID == nil,
                  state.activeCatchupSeekRequestID == nil
            else { return .none }

            let requestID = UUID()
            let itemID = state.item.id
            let playbackRequestID = state.playbackRequestID
            let replayFrom = state.currentTime
            let targetTime = Duration.seconds(max(0, Self.durationSeconds(replayFrom) - 10))
            let originalSubtitleTrackID = state.selectedSubtitleTrack.flatMap { $0.id == "-1" ? nil : $0.id }
            state.subtitleReplaySession = State.SubtitleReplaySession(
                requestID: requestID,
                itemID: itemID,
                playbackRequestID: playbackRequestID,
                restoreAt: replayFrom,
                originalSubtitleTrackID: originalSubtitleTrackID
            )
            let isCatchup = state.isPlayingCatchup
            let maximumDuration = state.catchupArchiveDurationSeconds
            let targetSeconds = Self.durationSeconds(targetTime)

            return .run { send in
                if isCatchup {
                    let result = await playerClient.catchupSeek(
                        .time(targetTime, maximumDurationSeconds: maximumDuration)
                    )
                    let landedSeconds = Self.durationSeconds(result.currentTime)
                    let subtitleTracks = result.didSucceed && abs(landedSeconds - targetSeconds) <= 1.5
                        ? await playerClient.getSubtitleTracks()
                        : []
                    let selectedSubtitleTrack = result.didSucceed && abs(landedSeconds - targetSeconds) <= 1.5
                        ? await playerClient.getSelectedSubtitleTrack()
                        : nil
                    await send(.subtitleReplaySeekCompleted(
                        requestID: requestID,
                        itemID: itemID,
                        playbackRequestID: playbackRequestID,
                        landedTime: result.currentTime,
                        isAccurate: result.didSucceed && abs(landedSeconds - targetSeconds) <= 1.5,
                        subtitleTracks: subtitleTracks,
                        selectedSubtitleTrack: selectedSubtitleTrack
                    ))
                } else {
                    let result = await playerClient.seekAndConfirm(.time(targetTime))
                    let isAccurate: Bool = switch result.status {
                    case .settled:
                        if let landedTime = result.currentTime {
                            abs(Self.durationSeconds(landedTime) - targetSeconds) <= 1.5
                        } else {
                            false
                        }
                    default:
                        false
                    }
                    let subtitleTracks = isAccurate ? await playerClient.getSubtitleTracks() : []
                    let selectedSubtitleTrack = isAccurate ? await playerClient.getSelectedSubtitleTrack() : nil
                    await send(.subtitleReplaySeekCompleted(
                        requestID: requestID,
                        itemID: itemID,
                        playbackRequestID: playbackRequestID,
                        landedTime: result.currentTime,
                        isAccurate: isAccurate,
                        subtitleTracks: subtitleTracks,
                        selectedSubtitleTrack: selectedSubtitleTrack
                    ))
                }
            }
            .cancellable(id: CancelID.subtitleReplaySeek, cancelInFlight: true)

        case let .subtitleReplaySeekCompleted(
            requestID,
            itemID,
            playbackRequestID,
            landedTime,
            isAccurate,
            subtitleTracks,
            selectedSubtitleTrack
        ):
            guard var session = state.subtitleReplaySession,
                  session.requestID == requestID,
                  session.itemID == itemID,
                  session.playbackRequestID == playbackRequestID,
                  state.item.id == itemID,
                  state.playbackRequestID == playbackRequestID,
                  !state.isSwitchingPlaybackEngine,
                  !state.isClosing
            else { return .none }

            state.subtitleReplaySession = nil
            guard isAccurate, let landedTime else { return .none }
            state.subtitleTracks = subtitleTracks
            state.selectedSubtitleTrack = selectedSubtitleTrack
            state.currentTime = landedTime
            let totalSeconds = state.isPlayingCatchup
                ? state.catchupArchiveDurationSeconds ?? 0
                : Self.durationSeconds(state.totalTime)
            let landedSeconds = Self.durationSeconds(landedTime)
            if totalSeconds.isFinite, totalSeconds > 0 {
                state.position = max(0, min(1, landedSeconds / totalSeconds))
            }

            let currentSubtitleTrackID = selectedSubtitleTrack.flatMap { $0.id == "-1" ? nil : $0.id }
            guard currentSubtitleTrackID == session.originalSubtitleTrackID,
                  session.originalSubtitleTrackID == nil
            else {
                return Self.updateNowPlaying(state: state, client: nowPlayingClient)
            }

            let availableSubtitleTracks = state.subtitleTracks.filter { $0.id != "-1" }
            let playbackDefaults = settingsClient.playbackDefaults(state.playbackContentKind)
            let rememberedSubtitle = settingsClient.getChannelPreferredSubtitleTrack(itemID)
                ?? (settingsClient.rememberMediaTrackPreferences()
                    ? UserDefaults.standard.string(forKey: "com.pureiptv.media_\(itemID)_subtitle")
                    : nil)
            let selectedByPreference = AudioTrackSelector.selectSubtitleTrack(
                from: availableSubtitleTracks,
                channelPreferred: rememberedSubtitle,
                preferredLanguage: playbackDefaults.preferredSubtitleLanguage
            ).selectedTrack
            guard let track = selectedByPreference ?? availableSubtitleTracks.first else {
                return Self.updateNowPlaying(state: state, client: nowPlayingClient)
            }

            session.temporarySubtitleTrackID = track.id
            state.subtitleReplaySession = session
            state.selectedSubtitleTrack = track
            let displayName = TrackLanguageFormatter.formatSubtitle(
                trackName: track.name,
                reportedLanguage: track.language
            ).titleWithFlag
            return .merge(
                .run { _ in await playerClient.setSubtitleTrack(track) }
                    .cancellable(id: CancelID.subtitleReplayTrackSelection, cancelInFlight: true),
                .send(.showTrackHUD(message: AppStrings.Player.subtitleTrackChanged(displayName), icon: "captions.bubble.fill")),
                Self.updateNowPlaying(state: state, client: nowPlayingClient)
            )

        case .jumpForward:
            guard !state.item.isLive || state.isPlayingCatchup else { return .none }
            return .send(.jumpBySeconds(state.skipIntervalSeconds))

        case .jumpBackward:
            guard !state.item.isLive || state.isPlayingCatchup else { return .none }
            return .send(.jumpBySeconds(-state.skipIntervalSeconds))

        case .restartPlayback:
            guard !state.isSwitchingPlaybackEngine,
                  !state.item.isLive || state.isPlayingCatchup
            else { return .none }
            state.pendingInitialResumeSeekTargetSeconds = nil
            state.isDispatchingInitialResumeSeek = false
            let cancelSubtitleReplay = state.subtitleReplaySession == nil
                ? Effect<Action>.none
                : .merge(
                    .cancel(id: CancelID.subtitleReplaySeek),
                    .cancel(id: CancelID.subtitleReplayTrackSelection)
                )
            state.subtitleReplaySession = nil
            state.scrubThumbnailRequestID = nil
            state.scrubThumbnailData = nil

            if state.isPlayingCatchup {
                state.expectedVODSeekTargetSeconds = nil
                state.expectedVODSeekTargetPosition = nil
                state.catchupSeekExpectedTimeSeconds = 0
                state.catchupSeekExpectedPosition = nil
                state.catchupSeekTimelineRecoveryRequired = false
                let requestID = UUID()
                let previousTime = state.activeCatchupSeekRequestID != nil
                    ? state.catchupSeekPreviousTime ?? state.currentTime
                    : state.currentTime
                let previousPosition = state.activeCatchupSeekRequestID != nil
                    ? state.catchupSeekPreviousPosition ?? state.position
                    : state.position
                state.activeCatchupSeekRequestID = requestID
                state.catchupSeekPreviousTime = previousTime
                state.catchupSeekPreviousPosition = previousPosition
                state.restartPlaybackAfterCatchupSeekRequestID = requestID
                state.catchupSeekFailureMessage = nil
                state.catchupSeekFailureRequestID = nil
                return .merge(
                    cancelSubtitleReplay,
                    .cancel(id: CancelID.initialResumeSeekVerification),
                    .cancel(id: CancelID.scrubThumbnail),
                    Self.catchupSeekEffect(
                        requestID: requestID,
                        itemID: state.item.id,
                        command: .time(.zero, maximumDurationSeconds: state.catchupArchiveDurationSeconds),
                        client: playerClient
                    )
                )
            }

            let requestID = UUID()
            let previousPosition = state.activeVODSeekRequestID != nil
                ? state.vodSeekPreviousPosition ?? state.position
                : state.position
            let previousTime = state.activeVODSeekRequestID != nil
                ? state.vodSeekPreviousTime ?? state.currentTime
                : state.currentTime
            state.activeVODSeekRequestID = requestID
            state.vodSeekTimelineRecoveryRequired = false
            state.restartPlaybackAfterVODSeekRequestID = requestID
            state.expectedVODSeekTargetSeconds = 0
            state.expectedVODSeekTargetPosition = nil
            state.vodSeekPreviousPosition = previousPosition
            state.vodSeekPreviousTime = previousTime
            state.vodSeekFailureRequestID = nil
            state.currentTime = .zero
            state.position = 0.0
            let playbackRequestID = state.playbackRequestID
            let upNextEffect = updateUpNextState(state: &state, settingsClient: settingsClient)
            return .merge(
                cancelSubtitleReplay,
                .cancel(id: CancelID.initialResumeSeekVerification),
                .cancel(id: CancelID.scrubThumbnail),
                Self.vodSeekEffect(
                    requestID: requestID,
                    itemID: state.item.id,
                    playbackRequestID: playbackRequestID,
                    command: .time(.zero),
                    client: playerClient
                ),
                upNextEffect,
                Self.updateNowPlaying(state: state, client: nowPlayingClient)
            )

        case let .seek(position):
            guard !state.isSwitchingPlaybackEngine else { return .none }
            state.pendingInitialResumeSeekTargetSeconds = nil
            state.isDispatchingInitialResumeSeek = false
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            state.expectedVODSeekTargetSeconds = nil
            state.expectedVODSeekTargetPosition = nil
            let cancelSubtitleReplay = state.subtitleReplaySession == nil
                ? Effect<Action>.none
                : .merge(
                    .cancel(id: CancelID.subtitleReplaySeek),
                    .cancel(id: CancelID.subtitleReplayTrackSelection)
                )
            state.subtitleReplaySession = nil
            state.scrubThumbnailRequestID = nil
            state.scrubThumbnailData = nil
            let clamped = max(0.0, min(1.0, position))
            if state.isPlayingCatchup {
                let catchupDuration = Self.catchupDurationSeconds(
                    reported: state.totalTime,
                    maximum: state.catchupArchiveDurationSeconds
                )
                state.catchupSeekExpectedTimeSeconds = catchupDuration.flatMap {
                    $0 * clamped
                }
                state.catchupSeekExpectedPosition = state.catchupSeekExpectedTimeSeconds == nil ? clamped : nil
                state.catchupSeekTimelineRecoveryRequired = false
                let requestID = UUID()
                let previousTime = state.activeCatchupSeekRequestID != nil
                    ? state.catchupSeekPreviousTime ?? state.currentTime
                    : state.currentTime
                let previousPosition = state.activeCatchupSeekRequestID != nil
                    ? state.catchupSeekPreviousPosition ?? state.position
                    : state.position
                state.activeCatchupSeekRequestID = requestID
                state.catchupSeekPreviousTime = previousTime
                state.catchupSeekPreviousPosition = previousPosition
                state.catchupSeekFailureMessage = nil
                state.catchupSeekFailureRequestID = nil
                return .merge(
                    cancelSubtitleReplay,
                    .cancel(id: CancelID.initialResumeSeekVerification),
                    .cancel(id: CancelID.scrubThumbnail),
                    Self.catchupSeekEffect(
                        requestID: requestID,
                        itemID: state.item.id,
                        command: .position(
                            clamped,
                            maximumDurationSeconds: state.catchupArchiveDurationSeconds
                        ),
                        client: playerClient
                    )
                )
            }
            if !state.item.isLive {
                let requestID = UUID()
                let previousPosition = state.activeVODSeekRequestID != nil
                    ? state.vodSeekPreviousPosition ?? state.position
                    : state.position
                let previousTime = state.activeVODSeekRequestID != nil
                    ? state.vodSeekPreviousTime ?? state.currentTime
                    : state.currentTime
                state.activeVODSeekRequestID = requestID
                state.vodSeekTimelineRecoveryRequired = false
                let totalSeconds = Self.durationSeconds(state.totalTime)
                state.expectedVODSeekTargetSeconds = totalSeconds.isFinite && totalSeconds > 0
                    ? totalSeconds * clamped
                    : nil
                state.expectedVODSeekTargetPosition = totalSeconds.isFinite && totalSeconds > 0
                    ? nil
                    : clamped
                state.vodSeekPreviousPosition = previousPosition
                state.vodSeekPreviousTime = previousTime
                state.vodSeekFailureRequestID = nil
                state.position = clamped
                if totalSeconds.isFinite, totalSeconds > 0 {
                    state.currentTime = .seconds(totalSeconds * clamped)
                }
                let playbackRequestID = state.playbackRequestID
                let upNextEffect = updateUpNextState(state: &state, settingsClient: settingsClient)
                return .merge(
                    cancelSubtitleReplay,
                    .cancel(id: CancelID.initialResumeSeekVerification),
                    .cancel(id: CancelID.scrubThumbnail),
                    Self.vodSeekEffect(
                        requestID: requestID,
                        itemID: state.item.id,
                        playbackRequestID: playbackRequestID,
                        command: .position(clamped),
                        client: playerClient
                    ),
                    upNextEffect
                )
            }
            state.position = clamped
            if state.totalTime.components.seconds > 0 {
                state.currentTime = Duration.seconds(Double(state.totalTime.components.seconds) * clamped)
            }
            let upNextEffect = updateUpNextState(state: &state, settingsClient: settingsClient)
            return .merge(
                cancelSubtitleReplay,
                .cancel(id: CancelID.initialResumeSeekVerification),
                .cancel(id: CancelID.scrubThumbnail),
                .run { _ in try await playerClient.seek(clamped) },
                upNextEffect
            )

        case let .requestScrubThumbnail(time):
            guard
                !state.item.isLive || state.isPlayingCatchup,
                state.totalTime > .zero,
                time >= .zero,
                time < state.totalTime
            else { return .none }
            let requestID = UUID()
            let itemID = state.item.id
            let url = state.mediaServerProxyURL ?? state.activePlaybackURL
            let userAgentOverride = state.item.userAgentOverride
            let isPlayingCatchup = state.isPlayingCatchup
            let thumbnailDebounce = isPlayingCatchup ? Duration.milliseconds(80) : .milliseconds(300)
            state.scrubThumbnailRequestID = requestID
            state.scrubThumbnailData = nil
            return .run { send in
                do {
                    try await Task.sleep(for: thumbnailDebounce)
                    try Task.checkCancellation()
                    let data: Data? = if isPlayingCatchup {
                        try? await playerClient.currentPlaybackThumbnail(time)
                    } else {
                        try? await playerClient.thumbnail(url, userAgentOverride, time)
                    }
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
            state.scrubThumbnailRequestID = nil
            return .none

        case .cancelScrubThumbnail:
            state.scrubThumbnailRequestID = nil
            state.scrubThumbnailData = nil
            return .cancel(id: CancelID.scrubThumbnail)

        case let .seekToTime(time):
            guard !state.isSwitchingPlaybackEngine else { return .none }
            let requestedSeconds = Self.durationSeconds(time)
            let isInitialResumeCommand = state.isDispatchingInitialResumeSeek
                && state.pendingInitialResumeSeekTargetSeconds.map { abs($0 - requestedSeconds) < 0.001 } == true
            state.isDispatchingInitialResumeSeek = false
            if !isInitialResumeCommand {
                state.pendingInitialResumeSeekTargetSeconds = nil
            }
            let cancelInitialResumeVerification: Effect<Action> = isInitialResumeCommand
                ? .none
                : .cancel(id: CancelID.initialResumeSeekVerification)
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            state.expectedVODSeekTargetSeconds = nil
            state.expectedVODSeekTargetPosition = nil
            let cancelSubtitleReplay = state.subtitleReplaySession == nil
                ? Effect<Action>.none
                : .merge(
                    .cancel(id: CancelID.subtitleReplaySeek),
                    .cancel(id: CancelID.subtitleReplayTrackSelection)
                )
            state.subtitleReplaySession = nil
            state.scrubThumbnailRequestID = nil
            state.scrubThumbnailData = nil
            if state.isPlayingCatchup {
                let requestedSeconds = Self.durationSeconds(time)
                let catchupDuration = Self.catchupDurationSeconds(
                    reported: state.totalTime,
                    maximum: state.catchupArchiveDurationSeconds
                )
                state.catchupSeekExpectedTimeSeconds = max(
                    0,
                    catchupDuration.map { min($0, requestedSeconds) } ?? requestedSeconds
                )
                state.catchupSeekExpectedPosition = nil
                state.catchupSeekTimelineRecoveryRequired = false
                let requestID = UUID()
                let previousTime = state.activeCatchupSeekRequestID != nil
                    ? state.catchupSeekPreviousTime ?? state.currentTime
                    : state.currentTime
                let previousPosition = state.activeCatchupSeekRequestID != nil
                    ? state.catchupSeekPreviousPosition ?? state.position
                    : state.position
                state.activeCatchupSeekRequestID = requestID
                state.catchupSeekPreviousTime = previousTime
                state.catchupSeekPreviousPosition = previousPosition
                state.catchupSeekFailureMessage = nil
                state.catchupSeekFailureRequestID = nil
                return .merge(
                    cancelSubtitleReplay,
                    cancelInitialResumeVerification,
                    .cancel(id: CancelID.scrubThumbnail),
                    Self.catchupSeekEffect(
                        requestID: requestID,
                        itemID: state.item.id,
                        command: .time(
                            time,
                            maximumDurationSeconds: state.catchupArchiveDurationSeconds
                        ),
                        client: playerClient
                    )
                )
            }
            if !state.item.isLive {
                let requestID = UUID()
                let previousPosition = state.activeVODSeekRequestID != nil
                    ? state.vodSeekPreviousPosition ?? state.position
                    : state.position
                let previousTime = state.activeVODSeekRequestID != nil
                    ? state.vodSeekPreviousTime ?? state.currentTime
                    : state.currentTime
                state.activeVODSeekRequestID = requestID
                state.vodSeekTimelineRecoveryRequired = false
                let totalSeconds = Self.durationSeconds(state.totalTime)
                let requestedSeconds = Self.durationSeconds(time)
                state.expectedVODSeekTargetSeconds = totalSeconds.isFinite && totalSeconds > 0
                    ? max(0, min(totalSeconds, requestedSeconds))
                    : max(0, requestedSeconds)
                state.expectedVODSeekTargetPosition = nil
                state.vodSeekPreviousPosition = previousPosition
                state.vodSeekPreviousTime = previousTime
                state.vodSeekFailureRequestID = nil
                state.currentTime = time
                if totalSeconds.isFinite, totalSeconds > 0 {
                    state.position = min(1.0, max(0.0, Self.durationSeconds(time) / totalSeconds))
                }
                let playbackRequestID = state.playbackRequestID
                let upNextEffect = updateUpNextState(state: &state, settingsClient: settingsClient)
                return .merge(
                    cancelSubtitleReplay,
                    cancelInitialResumeVerification,
                    .cancel(id: CancelID.scrubThumbnail),
                    Self.vodSeekEffect(
                        requestID: requestID,
                        itemID: state.item.id,
                        playbackRequestID: playbackRequestID,
                        command: .time(time),
                        client: playerClient
                    ),
                    upNextEffect,
                    Self.updateNowPlaying(state: state, client: nowPlayingClient)
                )
            }
            state.currentTime = time
            let totalSeconds = Self.durationSeconds(state.totalTime)
            if totalSeconds.isFinite, totalSeconds > 0 {
                state.position = min(1.0, max(0.0, Self.durationSeconds(time) / totalSeconds))
            }
            let upNextEffect = updateUpNextState(state: &state, settingsClient: settingsClient)
            return .merge(
                cancelSubtitleReplay,
                cancelInitialResumeVerification,
                .cancel(id: CancelID.scrubThumbnail),
                .run { _ in try await playerClient.seekToTime(time) },
                upNextEffect,
                Self.updateNowPlaying(state: state, client: nowPlayingClient)
            )

        case let .vodSeekCompleted(requestID, itemID, playbackRequestID, result):
            guard
                state.activeVODSeekRequestID == requestID,
                state.item.id == itemID,
                state.playbackRequestID == playbackRequestID,
                !state.isSwitchingPlaybackEngine,
                !state.item.isLive,
                !state.isPlayingCatchup
            else { return .none }
            let shouldResumeAfterRestart = state.restartPlaybackAfterVODSeekRequestID == requestID
            let expectedTargetSeconds = state.expectedVODSeekTargetSeconds
            let expectedTargetPosition = state.expectedVODSeekTargetPosition
            let totalSeconds = Self.durationSeconds(state.totalTime)
            let landedSeconds = result.currentTime.map(Self.durationSeconds)
                ?? result.position.flatMap { position in
                    totalSeconds.isFinite && totalSeconds > 0 && position.isFinite
                        ? position * totalSeconds
                        : nil
                }
            let landedPosition = result.position.flatMap { $0.isFinite ? $0 : nil }
                ?? (totalSeconds.isFinite && totalSeconds > 0
                    ? landedSeconds.map { $0 / totalSeconds }
                    : nil)
            let landedWithinTarget = Self.seekLanded(
                currentTime: result.currentTime,
                position: result.position,
                expectedSeconds: expectedTargetSeconds,
                expectedPosition: expectedTargetPosition,
                durationSeconds: totalSeconds,
                toleranceSeconds: result.status == .inaccurate ? 15 : 2
            )
            let statusCanSucceed = result.status == .settled
                || result.status == .inaccurate
                || result.status == .superseded
                // A backend can miss its seek completion callback after the
                // timeline has already landed. Treat a timed-out command as
                // successful only when the reported playback time confirms the
                // requested target; otherwise the rollback path remains active.
                || (result.status == .timedOut && landedWithinTarget)
            let seekSucceeded = statusCanSucceed && landedWithinTarget
            let expectedDescription = expectedTargetSeconds.map { String($0) } ?? "unknown"
            let landedDescription = landedSeconds.map { String($0) } ?? "unknown"
            let shortRequestID = String(requestID.uuidString.prefix(8))
            PlayerLogger.shared.info(
                category: "Seek",
                message: "VOD seek reconciled request=\(shortRequestID) expected=\(expectedDescription)s landed=\(landedDescription)s accepted=\(seekSucceeded)"
            )
            // A completed seek can report success while the engine has landed at
            // an unrelated time (notably zero). Restore the engine as well as
            // reducer state, and keep timeline events gated until that finishes.
            if !seekSucceeded, let previousTime = state.vodSeekPreviousTime {
                let rollbackRequestID = UUID()
                state.activeVODSeekRequestID = rollbackRequestID
                state.restartPlaybackAfterVODSeekRequestID = nil
                state.restartPlaybackAfterCatchupSeekRequestID = nil
                state.expectedVODSeekTargetSeconds = nil
                state.expectedVODSeekTargetPosition = nil
                state.currentTime = previousTime
                state.position = state.vodSeekPreviousPosition ?? state.position
                return Effect<Action>.run { send in
                    let rollbackResult = await playerClient.seekAndConfirm(.time(previousTime))
                    await send(.vodSeekRollbackCompleted(
                        requestID: rollbackRequestID,
                        itemID: itemID,
                        playbackRequestID: playbackRequestID,
                        result: rollbackResult
                    ))
                }
                .cancellable(id: CancelID.vodSeek, cancelInFlight: true)
            }
            state.activeVODSeekRequestID = nil
            state.vodSeekTimelineRecoveryRequired = false
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            state.expectedVODSeekTargetSeconds = nil
            state.expectedVODSeekTargetPosition = nil
            if !seekSucceeded {
                state.currentTime = state.vodSeekPreviousTime ?? state.currentTime
                state.position = state.vodSeekPreviousPosition ?? state.position
            } else {
                if let landedSeconds, landedSeconds.isFinite {
                    state.currentTime = .seconds(landedSeconds)
                } else {
                    state.currentTime = state.vodSeekPreviousTime ?? state.currentTime
                }
                if let landedPosition, landedPosition.isFinite {
                    state.position = max(0, min(1, landedPosition))
                } else {
                    state.position = state.vodSeekPreviousPosition ?? state.position
                }
                // Keep the landed time as an event reconciliation gate. AVPlayer
                // can deliver a periodic sample captured before the seek after
                // this completion action; accepting it would rewind the timeline.
                state.expectedVODSeekTargetSeconds = landedSeconds
                state.expectedVODSeekTargetPosition = landedSeconds == nil ? landedPosition : nil
                if state.initialResumeSeekRetryCount > 0 {
                    state.pendingInitialResumeSeekTargetSeconds = nil
                    state.isDispatchingInitialResumeSeek = false
                }
            }
            state.vodSeekPreviousPosition = nil
            state.vodSeekPreviousTime = nil
            let shouldShowFailure = !seekSucceeded
            state.vodSeekFailureRequestID = shouldShowFailure ? requestID : nil
            let upNextEffect = updateUpNextState(state: &state, settingsClient: settingsClient)
            guard shouldShowFailure else {
                return .merge(
                    .cancel(id: CancelID.vodSeekFeedback),
                    upNextEffect,
                    Self.updateNowPlaying(state: state, client: nowPlayingClient),
                    shouldResumeAfterRestart ? .send(.play) : .none
                )
            }
            let failureFeedback: Effect<Action> = .run { send in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                await send(.clearVODSeekFailure(requestID: requestID, itemID: itemID, playbackRequestID: playbackRequestID))
            }
            .cancellable(id: CancelID.vodSeekFeedback, cancelInFlight: true)
            return .merge(
                failureFeedback,
                upNextEffect,
                Self.updateNowPlaying(state: state, client: nowPlayingClient)
            )

        case let .vodSeekRollbackCompleted(requestID, itemID, playbackRequestID, result):
            guard state.activeVODSeekRequestID == requestID,
                  state.item.id == itemID,
                  state.playbackRequestID == playbackRequestID,
                  !state.item.isLive,
                  !state.isPlayingCatchup
            else { return .none }
            let previousTime = state.vodSeekPreviousTime ?? state.currentTime
            let previousPosition = state.vodSeekPreviousPosition ?? state.position
            let totalSeconds = Self.durationSeconds(state.totalTime)
            let rollbackStatusCanSucceed = result.status == .settled
                || result.status == .inaccurate
                || result.status == .superseded
            let rollbackSucceeded = rollbackStatusCanSucceed && Self.seekLanded(
                currentTime: result.currentTime,
                position: result.position,
                expectedSeconds: Self.durationSeconds(previousTime),
                expectedPosition: nil,
                durationSeconds: totalSeconds,
                toleranceSeconds: result.status == .inaccurate ? 15 : 2
            )
            if rollbackSucceeded {
                if let landedSeconds = result.currentTime.map(Self.durationSeconds), landedSeconds.isFinite {
                    state.currentTime = .seconds(landedSeconds)
                    if totalSeconds.isFinite, totalSeconds > 0 {
                        state.position = max(0, min(1, landedSeconds / totalSeconds))
                    }
                } else if let landedPosition = result.position, landedPosition.isFinite {
                    state.position = max(0, min(1, landedPosition))
                }
            } else {
                state.currentTime = previousTime
                state.position = previousPosition
            }
            state.activeVODSeekRequestID = nil
            if rollbackSucceeded {
                let confirmedSeconds = result.currentTime.map(Self.durationSeconds)
                    ?? result.position.flatMap { position in
                        totalSeconds.isFinite && totalSeconds > 0 ? position * totalSeconds : nil
                    }
                    ?? Self.durationSeconds(previousTime)
                state.expectedVODSeekTargetSeconds = confirmedSeconds
                state.expectedVODSeekTargetPosition = nil
                state.vodSeekPreviousTime = nil
                state.vodSeekPreviousPosition = nil
            } else {
                state.expectedVODSeekTargetSeconds = nil
                state.expectedVODSeekTargetPosition = nil
            }
            state.vodSeekTimelineRecoveryRequired = !rollbackSucceeded
            state.vodSeekFailureRequestID = requestID
            let failureFeedback = Effect<Action>.run { send in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                await send(.clearVODSeekFailure(requestID: requestID, itemID: itemID, playbackRequestID: playbackRequestID))
            }
            .cancellable(id: CancelID.vodSeekFeedback, cancelInFlight: true)
            let upNextEffect = updateUpNextState(state: &state, settingsClient: settingsClient)
            return .merge(
                failureFeedback,
                upNextEffect,
                Self.updateNowPlaying(state: state, client: nowPlayingClient),
                !rollbackSucceeded && !state.isUserPaused && !state.isClosing
                    ? .send(.initiateAutoReconnect)
                    : .none
            )

        case let .clearVODSeekFailure(requestID, itemID, playbackRequestID):
            guard state.item.id == itemID,
                  state.playbackRequestID == playbackRequestID,
                  state.vodSeekFailureRequestID == requestID
            else { return .none }
            state.vodSeekFailureRequestID = nil
            return .none

        case let .catchupSeekCompleted(requestID, itemID, result):
            guard
                state.activeCatchupSeekRequestID == requestID,
                state.item.id == itemID,
                state.isPlayingCatchup
            else { return .none }
            let totalSeconds = Self.catchupDurationSeconds(
                reported: state.totalTime,
                maximum: state.catchupArchiveDurationSeconds
            ) ?? 0
            let seekReachedTarget = result.didSucceed && Self.seekLanded(
                currentTime: result.currentTime,
                position: result.position,
                expectedSeconds: state.catchupSeekExpectedTimeSeconds,
                expectedPosition: state.catchupSeekExpectedPosition,
                durationSeconds: totalSeconds,
                toleranceSeconds: result.status == .inaccurate ? 15 : 2
            )
            if !seekReachedTarget, let previousTime = state.catchupSeekPreviousTime {
                let rollbackRequestID = UUID()
                state.currentTime = previousTime
                state.position = state.catchupSeekPreviousPosition ?? state.position
                state.activeCatchupSeekRequestID = rollbackRequestID
                state.restartPlaybackAfterCatchupSeekRequestID = nil
                state.catchupSeekExpectedTimeSeconds = Self.durationSeconds(previousTime)
                state.catchupSeekExpectedPosition = nil
                let itemID = state.item.id
                let maximumDurationSeconds = state.catchupArchiveDurationSeconds
                return .run { send in
                    let rollbackResult = await playerClient.catchupSeek(
                        .time(previousTime, maximumDurationSeconds: maximumDurationSeconds)
                    )
                    await send(.catchupSeekRollbackCompleted(
                        requestID: rollbackRequestID,
                        itemID: itemID,
                        result: rollbackResult
                    ))
                }
                .cancellable(id: CancelID.catchupSeek, cancelInFlight: true)
            }
            let shouldResumeAfterRestart = state.restartPlaybackAfterCatchupSeekRequestID == requestID
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            state.activeCatchupSeekRequestID = nil
            if seekReachedTarget {
                state.currentTime = result.currentTime
                state.position = max(0, min(1, result.position))
                state.catchupSeekExpectedTimeSeconds = Self.durationSeconds(result.currentTime)
                state.catchupSeekExpectedPosition = nil
            } else {
                state.currentTime = state.catchupSeekPreviousTime ?? result.currentTime
                state.position = state.catchupSeekPreviousPosition ?? max(0, min(1, result.position))
                state.catchupSeekExpectedTimeSeconds = nil
                state.catchupSeekExpectedPosition = nil
            }
            state.catchupSeekPreviousTime = nil
            state.catchupSeekPreviousPosition = nil
            state.catchupSeekTimelineRecoveryRequired = !seekReachedTarget
            state.catchupSeekFailureMessage = seekReachedTarget
                ? nil
                : "Catch-up konumu doğrulanamadı; bilinen son konum korundu.".localized
            state.catchupSeekFailureRequestID = seekReachedTarget ? nil : requestID
            let upNextEffect = updateUpNextState(state: &state, settingsClient: settingsClient)
            if state.catchupSeekFailureMessage == nil {
                return .merge(
                    upNextEffect,
                    .cancel(id: CancelID.catchupSeekFeedback),
                    Self.updateNowPlaying(state: state, client: nowPlayingClient),
                    shouldResumeAfterRestart ? .send(.play) : .none
                )
            }
            return .merge(
                upNextEffect,
                Self.updateNowPlaying(state: state, client: nowPlayingClient),
                .run { send in
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    await send(.clearCatchupSeekFailureMessage(requestID: requestID, itemID: itemID))
                }
                .cancellable(id: CancelID.catchupSeekFeedback, cancelInFlight: true)
            )

        case let .catchupSeekRollbackCompleted(requestID, itemID, result):
            guard state.activeCatchupSeekRequestID == requestID,
                  state.item.id == itemID,
                  state.isPlayingCatchup
            else { return .none }
            let previousTime = state.catchupSeekPreviousTime ?? state.currentTime
            let previousPosition = state.catchupSeekPreviousPosition ?? state.position
            let totalSeconds = Self.catchupDurationSeconds(
                reported: state.totalTime,
                maximum: state.catchupArchiveDurationSeconds
            ) ?? 0
            let rollbackSucceeded = result.didSucceed && Self.seekLanded(
                currentTime: result.currentTime,
                position: result.position,
                expectedSeconds: Self.durationSeconds(previousTime),
                expectedPosition: nil,
                durationSeconds: totalSeconds,
                toleranceSeconds: result.status == .inaccurate ? 15 : 2
            )
            state.currentTime = rollbackSucceeded ? result.currentTime : previousTime
            state.position = rollbackSucceeded
                ? max(0, min(1, result.position))
                : previousPosition
            state.activeCatchupSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            if rollbackSucceeded {
                state.catchupSeekExpectedTimeSeconds = Self.durationSeconds(result.currentTime)
                state.catchupSeekExpectedPosition = nil
                state.catchupSeekPreviousTime = nil
                state.catchupSeekPreviousPosition = nil
            } else {
                state.catchupSeekExpectedTimeSeconds = nil
                state.catchupSeekExpectedPosition = nil
            }
            state.catchupSeekTimelineRecoveryRequired = !rollbackSucceeded
            state.catchupSeekFailureMessage = "Catch-up konumu doğrulanamadı; bilinen son konum korundu.".localized
            state.catchupSeekFailureRequestID = requestID
            let failureFeedback = Effect<Action>.run { send in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                await send(.clearCatchupSeekFailureMessage(requestID: requestID, itemID: itemID))
            }
            .cancellable(id: CancelID.catchupSeekFeedback, cancelInFlight: true)
            return .merge(
                updateUpNextState(state: &state, settingsClient: settingsClient),
                Self.updateNowPlaying(state: state, client: nowPlayingClient),
                failureFeedback,
                !rollbackSucceeded && !state.isUserPaused && !state.isClosing
                    ? .send(.initiateAutoReconnect)
                    : .none
            )

        case let .clearCatchupSeekFailureMessage(requestID, itemID):
            guard state.item.id == itemID, state.catchupSeekFailureRequestID == requestID else { return .none }
            state.catchupSeekFailureMessage = nil
            state.catchupSeekFailureRequestID = nil
            return .none

        case .loadSkipMarkers:
            let profileScope = profileContextClient.snapshot()
            guard
                !state.item.isLive,
                !state.item.id.isEmpty,
                let playlistID = state.item.config?.playlistID,
                let profileID = profileScope.profileID
            else {
                state.skipMarkers = .init()
                state.skipMarkerRequestID = nil
                state.skipMarkersProfileScope = nil
                state.isSkipMarkersLoading = false
                return .cancel(id: CancelID.skipMarkerLoad)
            }
            let item = state.item
            let requestID = UUID()
            state.skipMarkerRequestID = requestID
            state.skipMarkersProfileScope = profileScope
            state.isSkipMarkersLoading = true
            let mediaKind = item.seriesID == nil ? "movie" : "episode"
            return .run { send in
                let markers = await playbackSkipMarkerClient.load(
                    profileID,
                    playlistID,
                    mediaKind,
                    item.id,
                    item.seriesID
                )
                await send(.skipMarkersLoaded(
                    requestID: requestID,
                    itemID: item.id,
                    playlistID: playlistID,
                    profileScope: profileScope,
                    markers: markers
                ))
            }
            .cancellable(id: CancelID.skipMarkerLoad, cancelInFlight: true)

        case let .skipMarkersLoaded(requestID, itemID, playlistID, profileScope, markers):
            guard
                state.skipMarkerRequestID == requestID,
                state.item.id == itemID,
                state.item.config?.playlistID == playlistID,
                state.skipMarkersProfileScope == profileScope,
                profileContextClient.snapshot() == profileScope
            else { return .none }
            state.skipMarkers = markers
            state.isSkipMarkersLoading = false
            return .none

        case let .setSkipMarkerBoundary(kind, isStart):
            guard
                state.canManageSkipMarkers,
                let profileScope = state.skipMarkersProfileScope,
                profileContextClient.snapshot() == profileScope
            else { return .none }
            let duration = Double(state.totalTime.components.seconds)
            let seconds = min(duration, max(0, Double(state.currentTime.components.seconds)))
            guard duration > 0 else { return .none }

            var marker = state.skipMarkers[kind]
            if isStart {
                guard seconds < duration else { return .none }
                marker.startSeconds = seconds
                if let end = marker.endSeconds, end <= seconds {
                    marker.endSeconds = nil
                }
            } else {
                guard let start = marker.startSeconds, seconds > start else { return .none }
                marker.endSeconds = seconds
            }
            state.skipMarkers[kind] = marker
            state.skipMarkerSaveRevision = max(state.skipMarkerSaveRevision + 1, DispatchTime.now().uptimeNanoseconds)
            return persistSkipMarkers(
                state.skipMarkers,
                revision: state.skipMarkerSaveRevision,
                item: state.item,
                profileScope: profileScope,
                markerClient: playbackSkipMarkerClient,
                profileContextClient: profileContextClient
            )

        case let .clearSkipMarker(kind):
            guard
                state.canManageSkipMarkers,
                let profileScope = state.skipMarkersProfileScope,
                profileContextClient.snapshot() == profileScope
            else { return .none }
            state.skipMarkers[kind] = .init()
            state.skipMarkerSaveRevision = max(state.skipMarkerSaveRevision + 1, DispatchTime.now().uptimeNanoseconds)
            return persistSkipMarkers(
                state.skipMarkers,
                revision: state.skipMarkerSaveRevision,
                item: state.item,
                profileScope: profileScope,
                markerClient: playbackSkipMarkerClient,
                profileContextClient: profileContextClient
            )

        case let .skipMarkedSegment(kind):
            let duration = Double(state.totalTime.components.seconds)
            let marker = state.skipMarkers[kind]
            guard
                state.activeSkipMarkerKind == kind,
                let profileScope = state.skipMarkersProfileScope,
                profileContextClient.snapshot() == profileScope,
                marker.isValid(duration: duration),
                let endSeconds = marker.endSeconds
            else { return .none }
            return .send(.seekToTime(.seconds(endSeconds)))

        case let .setPlaybackRate(rate):
            guard state.canSetPlaybackRate else { return .none }
            let clamped = max(0.25, min(4.0, rate))
            state.playbackRate = clamped
            return .merge(
                Self.updateNowPlaying(state: state, client: nowPlayingClient),
                .run { _ in
                    try await playerClient.setPlaybackRate(clamped)
                } catch: { error, _ in
                    print("Failed to set playback rate: \(error)")
                }
            )

        case let .setDeinterlaceMode(mode):
            guard state.playbackEngine == .vlc, !state.isSwitchingPlaybackEngine else { return .none }
            var playbackDefaults = settingsClient.playbackDefaults(state.playbackContentKind)
            playbackDefaults.deinterlaceMode = mode
            settingsClient.setPlaybackDefaults(state.playbackContentKind, playbackDefaults)
            state.playbackEngineError = nil
            state.memoryPressureDeinterlaceFallbackRequestID = nil
            let requestID = UUID()
            state.deinterlaceModeRequestID = requestID
            state.deinterlaceModeRevision = UUID()
            state.isDeinterlaceModeKnown = false
            let itemID = state.item.id
            let streamURL = state.activePlaybackURL
            return .merge(
                .cancel(id: CancelID.memoryPressureDeinterlaceFallback),
                .run { send in
                    do {
                        try await playerClient.setDeinterlaceMode(mode)
                        await send(.deinterlaceModeApplied(mode, requestID, itemID, streamURL))
                    } catch {
                        await send(.deinterlaceModeFailed(requestID, itemID, streamURL))
                    }
                }
                .cancellable(id: CancelID.deinterlaceModeChange, cancelInFlight: true)
            )

        case .memoryPressureWarning:
            guard state.playbackEngine == .vlc,
                  !state.isSwitchingPlaybackEngine,
                  !state.isClosing,
                  state.deinterlaceMode == .on,
                  state.deinterlaceModeRequestID == nil,
                  state.memoryPressureDeinterlaceFallbackRequestID == nil,
                  state.isDeinterlaceModeKnown
            else { return .none }

            let requestID = UUID()
            state.memoryPressureDeinterlaceFallbackRequestID = requestID
            state.deinterlaceModeRevision = UUID()
            let itemID = state.item.id
            let streamURL = state.activePlaybackURL
            let playbackRequestID = state.playbackRequestID
            return .run { send in
                do {
                    try await playerClient.setDeinterlaceMode(.off)
                    await send(.memoryPressureDeinterlaceFallbackApplied(
                        requestID,
                        itemID,
                        streamURL,
                        playbackRequestID
                    ))
                } catch {
                    await send(.memoryPressureDeinterlaceFallbackFailed(
                        requestID,
                        itemID,
                        streamURL,
                        playbackRequestID
                    ))
                }
            }
            .cancellable(id: CancelID.memoryPressureDeinterlaceFallback, cancelInFlight: true)

        case let .memoryPressureDeinterlaceFallbackApplied(requestID, itemID, streamURL, playbackRequestID):
            guard state.memoryPressureDeinterlaceFallbackRequestID == requestID,
                  state.playbackRequestID == playbackRequestID,
                  state.item.id == itemID,
                  state.activePlaybackURL == streamURL,
                  state.playbackEngine == .vlc,
                  !state.isSwitchingPlaybackEngine,
                  !state.isClosing
            else { return .none }
            state.deinterlaceMode = .off
            state.memoryPressureDeinterlaceFallbackRequestID = nil
            state.playbackEngineError = AppStrings.Player.deinterlaceMemoryPressureFallback
            return .none

        case let .memoryPressureDeinterlaceFallbackFailed(requestID, itemID, streamURL, playbackRequestID):
            guard state.memoryPressureDeinterlaceFallbackRequestID == requestID,
                  state.playbackRequestID == playbackRequestID,
                  state.item.id == itemID,
                  state.activePlaybackURL == streamURL,
                  state.playbackEngine == .vlc,
                  !state.isSwitchingPlaybackEngine,
                  !state.isClosing
            else { return .none }
            state.memoryPressureDeinterlaceFallbackRequestID = nil
            state.playbackEngineError = AppStrings.Player.deinterlaceMemoryPressureFallbackFailed
            return .none

        case let .deinterlaceModeApplied(mode, requestID, itemID, streamURL):
            guard state.deinterlaceModeRequestID == requestID,
                  state.item.id == itemID,
                  state.activePlaybackURL == streamURL
            else { return .none }
            state.deinterlaceMode = mode
            state.deinterlaceModeRequestID = nil
            state.isDeinterlaceModeKnown = true
            return .none

        case let .deinterlaceModeFailed(requestID, itemID, streamURL):
            guard state.deinterlaceModeRequestID == requestID,
                  state.item.id == itemID,
                  state.activePlaybackURL == streamURL
            else { return .none }
            state.deinterlaceModeRequestID = nil
            state.isDeinterlaceModeKnown = false
            state.playbackEngineError = "Deinterlace ayarı bu akışta uygulanamadı.".localized
            return .none

        case let .mediaServerPlaybackResolved(requestID, itemID, streamURL, proxyURL, status):
            guard state.mediaServerPlaybackRequestID == requestID,
                  state.item.id == itemID,
                  state.item.config?.type == .plex || state.item.config?.type == .emby
            else {
                return .run { _ in
                    await MediaServerStreamProxy.shared.closeSession(for: proxyURL)
                }
            }
            state.activePlaybackURL = streamURL
            state.mediaServerProxyURL = proxyURL
            state.mediaServerPlaybackStatus = status
            state.mediaServerPlaybackStatusRequestID = nil
            state.hasAttemptedMediaServerPlaybackStatus = false
            return .cancel(id: CancelID.mediaServerPlaybackStatus)

        case let .mediaServerPlaybackStatusLoaded(requestID, itemID, playbackRequestID, status):
            guard state.mediaServerPlaybackStatusRequestID == requestID,
                  state.playbackRequestID == playbackRequestID,
                  state.item.id == itemID,
                  state.item.config?.type == .plex || state.item.config?.type == .emby
            else { return .none }
            state.mediaServerPlaybackStatusRequestID = nil
            if let status {
                state.mediaServerPlaybackStatus = status
            }
            return .none

        case let .deinterlaceModePlaybackResolved(requested, applied, engine, revision, itemID, streamURL):
            guard !state.isClosing,
                  state.item.id == itemID,
                  state.activePlaybackURL == streamURL,
                  state.deinterlaceModeRequestID == nil,
                  state.deinterlaceModeRevision == revision
            else { return .none }
            let didFallbackToVLC = state.playbackEngine == .avPlayer && engine == .vlc
            let didChangeEngine = state.playbackEngine != engine
            state.playbackEngine = engine
            let nowPlayingClear = didChangeEngine
                ? Self.clearNowPlaying(state: &state, client: nowPlayingClient)
                : .none
            let nowPlayingUpdate = Self.updateNowPlaying(state: state, client: nowPlayingClient)
            let nowPlayingEngineUpdate = didChangeEngine
                ? .concatenate(nowPlayingClear, nowPlayingUpdate)
                : nowPlayingUpdate
            state.isPiPSupported = engine == .vlc && pipClient.isPiPSupported()
            if engine == .avPlayer {
                state.audioTracks = []
                state.subtitleTracks = []
                state.externalSubtitleTrackIDs = []
                state.selectedAudioTrack = nil
                state.selectedSubtitleTrack = nil
                state.subtitleReplaySession = nil
                state.deinterlaceMode = requested
                state.isDeinterlaceModeKnown = false
                return .merge(
                    .cancel(id: CancelID.subtitleReplaySeek),
                    .cancel(id: CancelID.subtitleReplayTrackSelection),
                    .concatenate(
                        nowPlayingEngineUpdate,
                        .send(.loadAFRPreferences),
                        .send(.matchDisplayMode)
                    )
                )
            }
            guard let applied else {
                state.isDeinterlaceModeKnown = false
                state.playbackEngineError = AppStrings.Player.deinterlaceUnknown
                return .merge(
                    nowPlayingEngineUpdate,
                    didFallbackToVLC ? .send(.fetchTracks) : .none
                )
            }
            state.deinterlaceMode = applied
            state.isDeinterlaceModeKnown = true
            if applied != requested {
                state.playbackEngineError = AppStrings.Player.deinterlaceFallback
            }
            return .concatenate(
                nowPlayingEngineUpdate,
                didFallbackToVLC ? .send(.fetchTracks) : .none,
                .send(.loadAFRPreferences),
                .send(.matchDisplayMode)
            )

        case let .playbackEngineStartFailed(engine, itemID, streamURL, playbackRequestID):
            guard state.playbackRequestID == playbackRequestID,
                  state.item.id == itemID,
                  state.activePlaybackURL == streamURL
            else { return .none }
            let didChangeEngine = state.playbackEngine != engine
            state.playbackEngine = engine
            state.isPiPSupported = engine == .vlc && pipClient.isPiPSupported()
            let nowPlayingClear = didChangeEngine
                ? Self.clearNowPlaying(state: &state, client: nowPlayingClient)
                : .none
            let nowPlayingUpdate = Self.updateNowPlaying(state: state, client: nowPlayingClient)
            return didChangeEngine
                ? .concatenate(nowPlayingClear, nowPlayingUpdate)
                : nowPlayingUpdate

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
            guard let playlistID else {
                state.recentChannels = []
                state.pinnedRecentChannelIDs = []
                state.pinnableRecentChannelIDs = []
                state.recentChannelsRequestID = nil
                return .none
            }
            let hiddenIDs = state.hiddenChannelIDs
            let blacklistedCategoryIDs = state.blacklistedCategoryIDs
            return .run { [playlist = state.playlist, config = state.item.config] send in
                let recentDTOs = await recentChannelsClient.fetchScopedRecentChannels(profileScope.profileID, playlistID)
                let pinnedIDs = await recentChannelsClient.fetchPinnedChannelIDs(profileScope.profileID, playlistID)
                let pinnedItems: [PlayableItem] = pinnedIDs.compactMap { id in
                    playlist?.first(where: {
                        $0.id == id
                            && $0.isLive
                            && !hiddenIDs.contains($0.id)
                            && !($0.categoryID.map(blacklistedCategoryIDs.contains) ?? false)
                    })
                }
                let recentItems: [PlayableItem] = recentDTOs.records.compactMap { dto in
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
            let shouldStopRecording = state.isRecording || state.isRecordingStartPending
            let currentItem = state.item
            let didChangeItem = newItem.id != currentItem.id
            let oldMediaServerProxyURL = state.mediaServerProxyURL
            let isPreservingFallbackStatus = state.isReconnecting && state.isFallbackSwitching
            let fallbackStreamName = state.fallbackStreamName
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
                state.isNowPlayingSuppressed = true
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
            let streamHealthGenerationID = UUID()
            state.streamHealthGenerationID = streamHealthGenerationID
            state.streamHealthMetrics = nil
            Self.resetLiveVideoStallTracking(state: &state)
            state.playbackRequestID = UUID()
            state.subtitleReplaySession = nil
            state.playbackPositionRecoveryRequestID = nil
            state.playbackPositionRecoveryExpectedPosition = nil
            state.mediaInfoRequestID = nil
            state.firstPresentedFrameLatency = nil
            state.firstPresentedFrameFeedbackRequestID = nil
            state.playbackRecoveryErrorMessage = nil
            state.activeCatchupProgram = nil
            state.catchupArchiveDurationSeconds = nil
            state.activeCatchupSeekRequestID = nil
            state.catchupSeekPreviousTime = nil
            state.catchupSeekPreviousPosition = nil
            state.catchupSeekExpectedTimeSeconds = nil
            state.catchupSeekExpectedPosition = nil
            state.catchupSeekTimelineRecoveryRequired = false
            state.catchupSeekFailureMessage = nil
            state.catchupSeekFailureRequestID = nil
            state.isCatchupTimelineVisible = false
            state.activeVODSeekRequestID = nil
            state.vodSeekTimelineRecoveryRequired = false
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            state.expectedVODSeekTargetSeconds = nil
            state.expectedVODSeekTargetPosition = nil
            state.vodSeekPreviousPosition = nil
            state.vodSeekPreviousTime = nil
            state.vodSeekFailureRequestID = nil
            state.didRequestXtreamLiveOutputFormats = false
            state.isLoadingXtreamLiveOutputFormats = false
            state.xtreamLiveOutputFormatOptions = []
            state.xtreamLiveOutputFormatError = nil
            state.activeXtreamLiveOutputFormatRequestID = nil
            state.activePlaybackURL = newItem.streamURL
            state.mediaServerPlaybackRequestID = nil
            state.mediaServerProxyURL = nil
            state.mediaServerPlaybackStatus = nil
            state.mediaServerPlaybackStatusRequestID = nil
            state.hasAttemptedMediaServerPlaybackStatus = false
            state.item = newItem
            if didChangeItem {
                state.mediaServerPlaybackOptionsRequestID = nil
                state.mediaServerPlaybackOptionsCheckedItemID = nil
                state.mediaServerPlaybackOptions = []
                state.isMediaServerPlaybackOptionsPresented = false
                state.selectedMediaServerPlaybackSourceID = nil
            }
            state.sourcePlaylistName = nil
            state.sourcePlaylistNamePlaylistID = nil
            state.sourcePlaylistNameRequestID = nil
            state.playbackEngine = .vlc
            Self.loadRememberedPlaybackChoice(state: &state, profileScope: profileContextClient.snapshot())
            state.deinterlaceModeRequestID = nil
            state.memoryPressureDeinterlaceFallbackRequestID = nil
            state.isDeinterlaceModeKnown = false
            state.isSwitchingPlaybackEngine = false
            state.playbackEngineSwitchID = nil
            state.playbackEngineSwitchProfileID = nil
            state.playbackEngineError = nil
            state.skipMarkers = .init()
            state.skipMarkerRequestID = nil
            state.skipMarkersProfileScope = nil
            state.isSkipMarkersLoading = false
            state.skipMarkerSaveRevision = 0
            state.scrubThumbnailRequestID = nil
            state.scrubThumbnailData = nil
            state.catchupTimeShiftHours = customEPGMappingClient.getCatchupTimeShift(newItem.id, newItem.config?.playlistID)
            state.isChannelListVisible = false
            state.isRecentChannelsHUDVisible = false
            state.isAudioSyncHUDVisible = false
            state.isAudioEQHUDVisible = false
            state.audioDelay = settingsClient.getChannelAudioDelay(newItem.id) ?? 0
            state.subtitleDelay = settingsClient.getChannelSubtitleDelay(newItem.id) ?? 0
            state.audioTracks = []
            state.subtitleTracks = []
            state.externalSubtitleTrackIDs = []
            state.selectedAudioTrack = nil
            state.selectedSubtitleTrack = nil
            state.subtitleReplaySession = nil
            state.epgListings = []
            state.epgRequestID = nil
            state.isEPGLoading = false
            state.mediaInfo = nil
            state.currentTime = .zero
            state.totalTime = .zero
            state.position = 0.0
            state.hasAppliedInitialSeek = false
            state.initialResumeSeekRetryCount = 0
            state.pendingInitialResumeSeekTargetSeconds = nil
            state.isDispatchingInitialResumeSeek = false
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
            state.isReconnecting = isPreservingFallbackStatus
            state.isFallbackSwitching = isPreservingFallbackStatus
            state.fallbackStreamName = isPreservingFallbackStatus ? fallbackStreamName : nil
            state.retryCount = 0
            state.errorMessage = nil
            state.isUpNextVisible = false
            state.isUpNextDismissed = false
            state.offlineEpisodeTransitionRequestID = nil

            return .concatenate(
                .cancel(id: CancelID.statsTimer),
                .send(.resolveSourcePlaylistName),
                .cancel(id: CancelID.liveVideoStallMonitor),
                .cancel(id: CancelID.scrubThumbnail),
                .cancel(id: CancelID.stallWatchdog),
                .cancel(id: CancelID.reconnectTimer),
                .cancel(id: CancelID.playerEvents),
                .cancel(id: CancelID.offlineEpisodeAvailability),
                .cancel(id: CancelID.mediaServerPlaybackOptions),
                .cancel(id: CancelID.vodSeek),
                .cancel(id: CancelID.vodSeekFeedback),
                .cancel(id: CancelID.initialResumeSeekVerification),
                .cancel(id: CancelID.subtitleReplaySeek),
                .cancel(id: CancelID.subtitleReplayTrackSelection),
                .cancel(id: CancelID.xtreamLiveOutputFormats),
                .cancel(id: CancelID.highFPSFeedback),
                .cancel(id: CancelID.playbackEngineSwitch),
                .cancel(id: CancelID.deinterlaceModeChange),
                .cancel(id: CancelID.memoryPressureDeinterlaceFallback),
                .cancel(id: CancelID.mediaServerPlaybackStatus),
                .cancel(id: CancelID.epgFetch),
                didChangeItem ? Self.clearNowPlaying(state: &state, client: nowPlayingClient) : .none,
                .run { send in
                    if shouldStopRecording {
                        await playerClient.requestRecordingStop()
                        await send(.recordingStopUnconfirmed)
                    }
                    try await playerClient.stop()
                    await MediaServerStreamProxy.shared.closeSession(for: oldMediaServerProxyURL)
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

        case .channelUp:
            return .send(state.reverseChannelZappingDirection ? .previousChannel : .nextChannel)

        case .channelDown:
            return .send(state.reverseChannelZappingDirection ? .nextChannel : .previousChannel)

        case .keyboardChannelUp:
            return .send(state.reverseChannelZappingDirection ? .nextChannel : .previousChannel)

        case .keyboardChannelDown:
            return .send(state.reverseChannelZappingDirection ? .previousChannel : .nextChannel)

        case .channelDownOrRecentChannels:
            if state.reverseChannelZappingDirection {
                return .send(.channelDown)
            }
            return .send(.setRecentChannelsHUDVisible(true))

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
            return .merge(
                .run { send in
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    await send(.hideChannelOSD)
                }
                .cancellable(id: CancelID.channelOSD, cancelInFlight: true),
                .send(.resolveSourcePlaylistName)
            )

        case .resolveSourcePlaylistName:
            guard let playlistID = state.item.config?.playlistID else {
                state.sourcePlaylistName = nil
                state.sourcePlaylistNamePlaylistID = nil
                state.sourcePlaylistNameRequestID = nil
                return .cancel(id: CancelID.sourcePlaylistName)
            }
            if state.sourcePlaylistNamePlaylistID == playlistID,
               state.sourcePlaylistName != nil || state.sourcePlaylistNameRequestID != nil
            {
                return .none
            }

            let requestID = UUID()
            state.sourcePlaylistName = nil
            state.sourcePlaylistNamePlaylistID = playlistID
            state.sourcePlaylistNameRequestID = requestID
            return .run { [playlistRepository] send in
                let name: String? = await Task.detached(priority: .userInitiated) {
                    guard case let .loaded(playlists) = playlistRepository.readPlaylists(),
                          let playlist = playlists.first(where: { $0.id == playlistID })
                    else { return nil }
                    let name = playlist.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    return name.isEmpty ? nil : name
                }.value
                guard !Task.isCancelled else { return }
                await send(.sourcePlaylistNameResolved(requestID: requestID, playlistID: playlistID, name: name))
            }
            .cancellable(id: CancelID.sourcePlaylistName, cancelInFlight: true)

        case let .sourcePlaylistNameResolved(requestID, playlistID, name):
            guard state.sourcePlaylistNameRequestID == requestID,
                  state.item.config?.playlistID == playlistID
            else { return .none }
            state.sourcePlaylistName = name
            state.sourcePlaylistNameRequestID = nil
            return .none

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
                return .merge(
                    .send(.fetchMediaInfo),
                    cancelStreamHealthSamplingIfNeeded(state: &state)
                )
            }
            return .none

        case .toggleEPG:
            state.isEPGVisible.toggle()
            guard state.isEPGVisible else { return .cancel(id: CancelID.epgBrowse) }
            let currentChannel = state.item
            state.epgBrowseChannel = currentChannel
            state.epgBrowseListings = state.epgListings
            state.isEPGBrowseLoading = false
            guard state.epgListings.isEmpty, !state.isEPGLoading else { return .none }
            return .send(.fetchEPG)

        case let .setEPGPreviewCorner(corner):
            guard state.epgPreviewCorner != corner else { return .none }
            state.epgPreviewCorner = corner
            return .run { _ in settingsClient.setEPGPreviewCorner(corner) }

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
            let epgID = channel.epgChannelID ?? channel.id
            return .run { [iptvClient] send in
                let programs = try await iptvClient.fetchShortEPG(config, channel.id, channel.epgChannelID, 10)
                await send(.epgBrowseResponse(
                    channelID: channelID,
                    .success(programs)
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

        case .returnToPlayingChannelInEPG:
            guard state.isEPGVisible else { return .none }
            return .send(.selectEPGBrowseChannel(state.item))

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
            let requestID = UUID()
            state.epgRequestID = requestID
            state.isEPGLoading = true
            let channelID = state.item.id
            let channelTitle = state.item.title
            let fallbackEpgID = state.item.epgChannelID
            let config = state.item.config

            guard let config else {
                return .run { [customEPGMappingClient] send in
                    let customPrograms = await customEPGMappingClient.fetchProgramsForChannel(
                        channelID,
                        channelTitle,
                        fallbackEpgID,
                        nil
                    )
                    let shiftedPrograms = customEPGMappingClient.applyTimeShift(customPrograms, channelID, nil)
                    await send(.fetchEPGResponse(channelID: channelID, requestID: requestID, .success(shiftedPrograms)))
                }
                .cancellable(id: CancelID.epgFetch, cancelInFlight: true)
            }

            let epgID = fallbackEpgID ?? channelID
            return .run { send in
                await send(.fetchEPGResponse(
                    channelID: channelID,
                    requestID: requestID,
                    Result { try await iptvClient.fetchShortEPG(config, channelID, fallbackEpgID, 10) }
                ))
            }
            .cancellable(id: CancelID.epgFetch, cancelInFlight: true)

        case let .fetchEPGResponse(channelID, requestID, .success(listings)):
            guard state.epgRequestID == requestID, state.item.id == channelID else { return .none }
            state.epgRequestID = nil
            state.isEPGLoading = false
            state.epgListings = listings
            if state.epgBrowseChannel?.id == state.item.id {
                state.epgBrowseListings = state.epgListings
            }
            return .none

        case let .fetchEPGResponse(channelID, requestID, .failure(error)):
            guard state.epgRequestID == requestID, state.item.id == channelID else { return .none }
            print("EPG Fetch error: \(error)")
            state.epgRequestID = nil
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
                            seasonNumber: ep.season,
                            episodeNumber: ep.episodeNum,
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
            state.subtitleReplaySession = nil
            let userAgentOverride = state.item.userAgentOverride

            let archiveStart = program.startTime.addingTimeInterval(
                TimeInterval(customEPGMappingClient.getCatchupTimeShift(state.item.id, state.item.config?.playlistID) * 3600)
            )
            let startTimeString = AppFormatters.catchupTimeString(archiveStart)
            let durationMinutes = Int(program.endTime.timeIntervalSince(program.startTime) / 60)

            let catchupBaseURL: URL
            if let config = state.item.config, config.type == .xtream {
                guard let tsStreamURL = makeXtreamLiveStreamURL(
                    config: config.replacingXtreamLiveOutputFormat(.ts),
                    streamID: state.item.id
                ) else { return .none }
                catchupBaseURL = tsStreamURL
            } else {
                guard let streamURL = URL(string: state.item.streamURL.absoluteString) else { return .none }
                catchupBaseURL = streamURL
            }
            guard var components = URLComponents(url: catchupBaseURL, resolvingAgainstBaseURL: true) else {
                return .none
            }

            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "timeshift", value: "\(durationMinutes)"))
            queryItems.append(URLQueryItem(name: "start", value: startTimeString))
            components.queryItems = queryItems

            if let catchupURL = components.url {
                Self.resetLiveVideoStallTracking(state: &state)
                state.playerState = .playing
                state.isEPGVisible = false
                state.isCatchupTimelineVisible = false
                state.activeCatchupProgram = program
                state.catchupArchiveDurationSeconds = durationMinutes > 0 ? Double(durationMinutes) * 60 : nil
                state.activeCatchupSeekRequestID = nil
                state.catchupSeekPreviousTime = nil
                state.catchupSeekPreviousPosition = nil
                state.catchupSeekExpectedTimeSeconds = nil
                state.catchupSeekExpectedPosition = nil
                state.catchupSeekTimelineRecoveryRequired = false
                state.catchupSeekFailureMessage = nil
                state.catchupSeekFailureRequestID = nil
                state.scrubThumbnailRequestID = nil
                state.scrubThumbnailData = nil
                state.activePlaybackURL = catchupURL
                let playbackDefaults = settingsClient.playbackDefaults(.archive)
                state.catchupSkipInterval = playbackDefaults.catchupSkipInterval
                state.playbackEngine = .vlc
                state.deinterlaceMode = playbackDefaults.deinterlaceMode
                state.isMatchDynamicRangeEnabled = playbackDefaults.isMatchDynamicRangeEnabled
                state.isForceSDROutputEnabled = playbackDefaults.isForceSDROutputEnabled ?? false
                Self.loadRememberedPlaybackChoice(state: &state, profileScope: profileContextClient.snapshot())
                state.currentTime = .zero
                state.totalTime = .zero
                state.position = 0.0
                state.streamHealthGenerationID = UUID()
                state.streamHealthMetrics = nil
                let deinterlaceMode = state.deinterlaceMode
                let deinterlaceModeRevision = state.deinterlaceModeRevision
                let itemID = state.item.id
                let playbackRequestID = state.playbackRequestID
                let networkCachingMilliseconds = playbackDefaults.networkCachingMilliseconds(for: .archive)
                let playbackEngine = state.playbackEngine
                let subtitleTextScale = playbackDefaults.subtitleTextSize.scale
                let audioName = Self.savedAudioTrackName(itemID: itemID, settingsClient: settingsClient)
                let subtitleName = Self.savedSubtitleTrackName(itemID: itemID, settingsClient: settingsClient)
                state.isDeinterlaceModeKnown = false
                return .merge(
                    .cancel(id: CancelID.statsTimer),
                    .cancel(id: CancelID.liveVideoStallMonitor),
                    .cancel(id: CancelID.scrubThumbnail),
                    .cancel(id: CancelID.catchupSeek),
                    .cancel(id: CancelID.catchupSeekFeedback),
                    .cancel(id: CancelID.subtitleReplaySeek),
                    .cancel(id: CancelID.subtitleReplayTrackSelection),
                    .run { send in
                        do {
                            let playbackResult = try await playerClient.play(
                                catchupURL,
                                userAgentOverride,
                                networkCachingMilliseconds,
                                deinterlaceMode,
                                playbackEngine,
                                audioName,
                                playbackDefaults.preferredAudioLanguage,
                                subtitleName,
                                playbackDefaults.preferredSubtitleLanguage
                            )
                            await playerClient.setSubtitleTextScale(subtitleTextScale)
                            await send(.deinterlaceModePlaybackResolved(requested: deinterlaceMode, applied: playbackResult.deinterlaceMode, engine: playbackResult.engine, revision: deinterlaceModeRevision, itemID: itemID, streamURL: catchupURL))
                        } catch is CancellationError {
                            return
                        } catch {
                            print("Failed to play catchup: \(error)")
                            let activeEngine = await playerClient.activeEngine()
                            await send(Action.playbackEngineStartFailed(
                                engine: activeEngine,
                                itemID: itemID,
                                streamURL: catchupURL,
                                playbackRequestID: playbackRequestID
                            ))
                        }
                    }
                )
            }
            return .none

        case .returnToLiveStream:
            state.subtitleReplaySession = nil
            resetLiveVideoStallTracking(state: &state)
            state.activeCatchupProgram = nil
            state.catchupArchiveDurationSeconds = nil
            state.activeCatchupSeekRequestID = nil
            state.catchupSeekPreviousTime = nil
            state.catchupSeekPreviousPosition = nil
            state.catchupSeekExpectedTimeSeconds = nil
            state.catchupSeekExpectedPosition = nil
            state.catchupSeekTimelineRecoveryRequired = false
            state.catchupSeekFailureMessage = nil
            state.catchupSeekFailureRequestID = nil
            state.scrubThumbnailRequestID = nil
            state.scrubThumbnailData = nil
            state.isCatchupTimelineVisible = false
            state.playerState = .playing
            let liveURL = state.item.streamURL
            state.activePlaybackURL = liveURL
            let playbackDefaults = settingsClient.playbackDefaults(.live)
            state.playbackEngine = .vlc
            state.deinterlaceMode = playbackDefaults.deinterlaceMode
            state.isMatchDynamicRangeEnabled = playbackDefaults.isMatchDynamicRangeEnabled
            state.isForceSDROutputEnabled = playbackDefaults.isForceSDROutputEnabled ?? false
            Self.loadRememberedPlaybackChoice(state: &state, profileScope: profileContextClient.snapshot())
            state.streamHealthGenerationID = UUID()
            state.streamHealthMetrics = nil
            let userAgentOverride = state.item.userAgentOverride
            let deinterlaceMode = state.deinterlaceMode
            let deinterlaceModeRevision = state.deinterlaceModeRevision
            let itemID = state.item.id
            let playbackRequestID = state.playbackRequestID
            let networkCachingMilliseconds = playbackDefaults.networkCachingMilliseconds(for: .live)
            let playbackEngine = state.playbackEngine
            let subtitleTextScale = playbackDefaults.subtitleTextSize.scale
            let audioName = Self.savedAudioTrackName(itemID: itemID, settingsClient: settingsClient)
            let subtitleName = Self.savedSubtitleTrackName(itemID: itemID, settingsClient: settingsClient)
            state.isDeinterlaceModeKnown = false
            return .merge(
                .cancel(id: CancelID.statsTimer),
                .cancel(id: CancelID.liveVideoStallMonitor),
                .cancel(id: CancelID.scrubThumbnail),
                .cancel(id: CancelID.catchupSeek),
                .cancel(id: CancelID.catchupSeekFeedback),
                .cancel(id: CancelID.subtitleReplaySeek),
                .cancel(id: CancelID.subtitleReplayTrackSelection),
                .run { send in
                    do {
                        let playbackResult = try await playerClient.play(
                            liveURL,
                            userAgentOverride,
                            networkCachingMilliseconds,
                            deinterlaceMode,
                            playbackEngine,
                            audioName,
                            playbackDefaults.preferredAudioLanguage,
                            subtitleName,
                            playbackDefaults.preferredSubtitleLanguage
                        )
                        await playerClient.setSubtitleTextScale(subtitleTextScale)
                        await send(.deinterlaceModePlaybackResolved(requested: deinterlaceMode, applied: playbackResult.deinterlaceMode, engine: playbackResult.engine, revision: deinterlaceModeRevision, itemID: itemID, streamURL: liveURL))
                    } catch is CancellationError {
                        return
                    } catch {
                        print("Failed to return to live stream: \(error)")
                        let activeEngine = await playerClient.activeEngine()
                        await send(Action.playbackEngineStartFailed(
                            engine: activeEngine,
                            itemID: itemID,
                            streamURL: liveURL,
                            playbackRequestID: playbackRequestID
                        ))
                    }
                }
            )

        case .toggleCatchupTimeline:
            state.isCatchupTimelineVisible.toggle()
            if state.isCatchupTimelineVisible {
                state.catchupTimeShiftHours = customEPGMappingClient.getCatchupTimeShift(state.item.id, state.item.config?.playlistID)
                state.isTracksMenuVisible = false
                state.isInfoVisible = false
                state.isStreamHealthHUDVisible = false
                state.isAudioSyncHUDVisible = false
                state.isAudioEQHUDVisible = false
                state.isRecentChannelsHUDVisible = false
                if state.epgListings.isEmpty {
                    return .merge(
                        .send(.fetchEPG),
                        cancelStreamHealthSamplingIfNeeded(state: &state)
                    )
                }
                return cancelStreamHealthSamplingIfNeeded(state: &state)
            }
            return .none

        case let .setCatchupTimelineVisible(visible):
            state.isCatchupTimelineVisible = visible
            if visible, state.epgListings.isEmpty {
                state.catchupTimeShiftHours = customEPGMappingClient.getCatchupTimeShift(state.item.id, state.item.config?.playlistID)
                return .send(.fetchEPG)
            }
            if visible {
                state.catchupTimeShiftHours = customEPGMappingClient.getCatchupTimeShift(state.item.id, state.item.config?.playlistID)
            }
            return .none

        case let .setCatchupTimeShiftHours(hours):
            let boundedHours = min(12, max(-12, hours))
            state.catchupTimeShiftHours = boundedHours
            customEPGMappingClient.setCatchupTimeShift(state.item.id, state.item.config?.playlistID, boundedHours)
            return .none

        case .fetchMediaInfo:
            guard state.playbackEngine == .vlc else { return .none }
            let requestID = UUID()
            let itemID = state.item.id
            let playbackRequestID = state.playbackRequestID
            state.mediaInfoRequestID = requestID
            return .run { send in
                let info = await playerClient.getMediaInfo()
                await send(.mediaInfoResponse(
                    info,
                    itemID: itemID,
                    playbackRequestID: playbackRequestID,
                    requestID: requestID
                ))
            }

        case let .mediaInfoResponse(info, itemID, playbackRequestID, requestID):
            guard state.item.id == itemID,
                  state.playbackRequestID == playbackRequestID,
                  state.mediaInfoRequestID == requestID,
                  state.playbackEngine == .vlc
            else { return .none }
            state.mediaInfo = info
            if state.item.isLive {
                return Self.startLiveVideoStallMonitoring(
                    state: &state,
                    playerClient: playerClient,
                    itemID: itemID,
                    playbackRequestID: playbackRequestID
                )
            }
            if state.isHighFrameRateVOD,
               state.firstPresentedFrameLatency != nil,
               state.firstPresentedFrameFeedbackRequestID == nil
            {
                let feedbackID = UUID()
                state.firstPresentedFrameFeedbackRequestID = feedbackID
                return .run { send in
                    try? await Task.sleep(for: .seconds(4))
                    guard !Task.isCancelled else { return }
                    await send(.clearHighFPSFrameMetric(
                        requestID: feedbackID,
                        itemID: itemID,
                        playbackRequestID: playbackRequestID
                    ))
                }
                .cancellable(id: CancelID.highFPSFeedback, cancelInFlight: true)
            }
            return .none

        case let .playbackHealthEvent(event, itemID, playbackRequestID, baselineGeneration, baselineHadPresentedFrame):
            guard state.item.id == itemID,
                  state.playbackRequestID == playbackRequestID,
                  !state.isSwitchingPlaybackEngine,
                  !state.item.isLive,
                  !state.isPlayingCatchup,
                  state.playbackEngine == .vlc,
                  case .firstPresentedFrame = event.kind,
                  let latency = event.snapshot.lastPresentedAt
            else { return .none }
            let generationIsCurrent = event.snapshot.generation > baselineGeneration
                || (event.snapshot.generation == baselineGeneration && !baselineHadPresentedFrame)
            guard generationIsCurrent else { return .none }
            state.firstPresentedFrameLatency = latency
            guard state.isHighFrameRateVOD else { return .none }
            let feedbackID = UUID()
            state.firstPresentedFrameFeedbackRequestID = feedbackID
            return .run { send in
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                await send(.clearHighFPSFrameMetric(
                    requestID: feedbackID,
                    itemID: itemID,
                    playbackRequestID: playbackRequestID
                ))
            }
            .cancellable(id: CancelID.highFPSFeedback, cancelInFlight: true)

        case let .clearHighFPSFrameMetric(requestID, itemID, playbackRequestID):
            guard state.item.id == itemID,
                  state.playbackRequestID == playbackRequestID,
                  state.firstPresentedFrameFeedbackRequestID == requestID
            else { return .none }
            state.firstPresentedFrameFeedbackRequestID = nil
            state.firstPresentedFrameLatency = nil
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
                    return .merge(
                        .send(.fetchTracks),
                        cancelStreamHealthSamplingIfNeeded(state: &state)
                    )
                }
                return cancelStreamHealthSamplingIfNeeded(state: &state)
            }
            return .none

        case .fetchTracks:
            guard state.playbackEngine == .vlc else { return .none }
            let mediaID = state.item.id
            let playbackDefaults = settingsClient.playbackDefaults(state.playbackContentKind)
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
                let primaryAudioLang = playbackDefaults.preferredAudioLanguage
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
                let preferredSubLang = playbackDefaults.preferredSubtitleLanguage

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
            let playbackKind = state.playbackContentKind
            let updatedPlaybackDefaults = trackName.map { _ in
                var playbackDefaults = settingsClient.playbackDefaults(playbackKind)
                playbackDefaults.preferredAudioLanguage = track?.language ?? playbackDefaults.preferredAudioLanguage
                return playbackDefaults
            }
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
                        if let updatedPlaybackDefaults {
                            settingsClient.setPlaybackDefaults(playbackKind, updatedPlaybackDefaults)
                        }
                    }
                    await playerClient.setAudioTrack(track)
                }
            )

        case let .selectSubtitleTrack(track):
            state.selectedSubtitleTrack = track
            let subtitleReplayCancellation = state.subtitleReplaySession == nil
                ? Effect<Action>.none
                : .cancel(id: CancelID.subtitleReplaySeek)
            state.subtitleReplaySession = nil
            state.isTracksMenuVisible = false
            let trackName = track?.name
            let mediaID = state.item.id
            let playbackKind = state.playbackContentKind
            let updatedPlaybackDefaults: PlaybackDefaults = {
                var defaults = settingsClient.playbackDefaults(playbackKind)
                if let track {
                    defaults.preferredSubtitleLanguage = track.language ?? defaults.preferredSubtitleLanguage
                } else {
                    defaults.preferredSubtitleLanguage = "off"
                }
                return defaults
            }()
            let displayName = trackName.map { TrackLanguageFormatter.format(trackName: $0, isSubtitle: true).titleWithFlag } ?? AppStrings.Player.off
            let hudMessage = AppStrings.Player.subtitleTrackChanged(displayName)
            return .merge(
                subtitleReplayCancellation,
                .cancel(id: CancelID.subtitleReplayTrackSelection),
                .send(.showTrackHUD(message: hudMessage, icon: track == nil ? "captions.bubble" : "captions.bubble.fill")),
                .run { _ in
                    if let trackName {
                        settingsClient.setChannelPreferredSubtitleTrack(mediaID, trackName)
                        if settingsClient.rememberMediaTrackPreferences() {
                            UserDefaults.standard.set(trackName, forKey: "com.pureiptv.media_\(mediaID)_subtitle")
                        }
                        settingsClient.setPlaybackDefaults(playbackKind, updatedPlaybackDefaults)
                    } else {
                        settingsClient.setChannelPreferredSubtitleTrack(mediaID, "off")
                        if settingsClient.rememberMediaTrackPreferences() {
                            UserDefaults.standard.set("off", forKey: "com.pureiptv.media_\(mediaID)_subtitle")
                        }
                        settingsClient.setPlaybackDefaults(playbackKind, updatedPlaybackDefaults)
                    }
                    await playerClient.setSubtitleTrack(track)
                }
            )

        case .toggleAudioEQHUD:
            guard state.playbackEngine == .vlc else { return .none }
            state.isAudioEQHUDVisible.toggle()
            if state.isAudioEQHUDVisible {
                state.isTracksMenuVisible = false
                state.isInfoVisible = false
                state.isStreamHealthHUDVisible = false
                state.isAudioSyncHUDVisible = false
                state.isCatchupTimelineVisible = false
                state.isRecentChannelsHUDVisible = false
            }
            return cancelStreamHealthSamplingIfNeeded(state: &state)

        case let .setAudioEQHUDVisible(visible):
            state.isAudioEQHUDVisible = visible
            return .none

        case let .selectAudioEQPreset(preset):
            guard state.playbackEngine == .vlc else { return .none }
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
            case let .recordingChanged(isRecording, filePath):
                if isRecording {
                    state.isRecording = true
                    state.isRecordingStartPending = false
                    state.recordingFilePath = filePath
                    state.recordingStartedAt = Date()
                    let title = state.item.title
                    return .merge(
                        .run { _ in await MainActor.run { LocalDVRManager.shared.beginRecording(channelTitle: title) } },
                        .run { send in
                            while !Task.isCancelled {
                                try await Task.sleep(for: .seconds(5))
                                await send(.recordingLimitCheck)
                            }
                        }.cancellable(id: CancelID.recordingMonitor, cancelInFlight: true)
                    )
                }
                return .send(.recordingFinalized(filePath))
            case let .stateChanged(newState):
                PlayerLogger.shared.info(
                    category: "State",
                    message: "Player state changed to: \(newState) for \"\(state.item.title)\""
                )
                state.playerState = newState
                state.viewingStatisticsLastPlaybackSeconds = nil
                state.viewingStatisticsLastWallTime = nil
                let viewingStatisticsStateEffect: Effect<Action> = newState == .playing
                    ? .none
                    : Self.flushViewingStatistics(state: &state, client: viewingStatisticsClient)
                if newState == .playing {
                    state.isNowPlayingSuppressed = false
                } else if newState == .stopped {
                    state.isNowPlayingSuppressed = true
                }
                let nowPlayingUpdate = Self.updateNowPlaying(state: state, client: nowPlayingClient)
                let liveVideoMonitorCancellation: Effect<Action> = if newState == .playing {
                    .none
                } else {
                    Self.stopLiveVideoStallMonitoring(state: &state)
                }
                if newState == .playing {
                    state.retryCount = 0 // Reset on successful play
                    state.isReconnecting = state.playbackPositionRecoveryRequestID == state.playbackRequestID
                    state.isFallbackSwitching = false
                    state.fallbackStreamName = nil
                    state.errorMessage = nil
                    state.failedStreamIDs.removeAll()
                    var actions: [Effect<Action>] = [
                        .cancel(id: CancelID.stallWatchdog),
                        .cancel(id: CancelID.reconnectTimer),
                        nowPlayingUpdate,
                    ]

                    if let config = state.item.config,
                       config.type == .plex || config.type == .emby,
                       !state.hasAttemptedMediaServerPlaybackStatus
                    {
                        state.hasAttemptedMediaServerPlaybackStatus = true
                        let statusRequestID = UUID()
                        let itemID = state.item.id
                        let playbackRequestID = state.playbackRequestID
                        state.mediaServerPlaybackStatusRequestID = statusRequestID
                        actions.append(
                            .run { [mediaServerClient] send in
                                for attempt in 0 ..< 5 {
                                    if attempt > 0 {
                                        try await Task.sleep(for: .seconds(1))
                                    }
                                    if let status = try? await mediaServerClient.fetchPlaybackStatus(config, itemID) {
                                        await send(.mediaServerPlaybackStatusLoaded(
                                            requestID: statusRequestID,
                                            itemID: itemID,
                                            playbackRequestID: playbackRequestID,
                                            status: status
                                        ))
                                        return
                                    }
                                }
                                await send(.mediaServerPlaybackStatusLoaded(
                                    requestID: statusRequestID,
                                    itemID: itemID,
                                    playbackRequestID: playbackRequestID,
                                    status: nil
                                ))
                            }
                            .cancellable(id: CancelID.mediaServerPlaybackStatus, cancelInFlight: true)
                        )
                    }

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
                        // Prefer the persisted absolute time for resume. A ratio seek can
                        // be ignored by some engines while duration is still unknown.
                        if let progress = state.item.initialProgress, progress > 1, progress.isFinite {
                            actions.append(.send(.initialResumeSeekRequested(targetSeconds: progress)))
                            state.pendingInitialResumeSeekTargetSeconds = progress
                            if progress > 10 {
                                let itemID = state.item.id
                                let playbackRequestID = state.playbackRequestID
                                actions.append(Self.initialResumeSeekVerificationEffect(
                                    itemID: itemID,
                                    playbackRequestID: playbackRequestID,
                                    targetSeconds: progress,
                                    verificationAttempt: 0,
                                    delay: .seconds(4),
                                    clock: continuousClock,
                                    playerClient: playerClient
                                ))
                            }
                        } else if let startPosition = state.item.startPosition, startPosition > 0 {
                            actions.append(.send(.seek(startPosition)))
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
                    if state.isShowingStats || state.isStreamHealthHUDVisible {
                        actions.append(.send(.startStreamHealthSampling(
                            itemID: state.item.id,
                            generationID: state.streamHealthGenerationID
                        )))
                    }
                    if Self.canMonitorLiveVideoStall(state: state) {
                        actions.append(.send(.startLiveVideoStallMonitoring(
                            itemID: state.item.id,
                            playbackRequestID: state.playbackRequestID
                        )))
                    } else {
                        actions.append(Self.stopLiveVideoStallMonitoring(state: &state))
                    }
                    return .merge(actions)
                } else if newState == .buffering || newState == .opening {
                    if !state.isUserPaused {
                        return .merge(
                            viewingStatisticsStateEffect,
                            liveVideoMonitorCancellation,
                            nowPlayingUpdate,
                            Self.stallWatchdogEffect(clock: continuousClock, isLive: state.item.isLive)
                        )
                    }
                    return .merge(viewingStatisticsStateEffect, liveVideoMonitorCancellation, nowPlayingUpdate)
                } else if newState == .stopped {
                    let reconnectEffect: Effect<Action> = if state.item.isLive, !state.isUserPaused, !state.isMinimized {
                        .send(.initiateAutoReconnect)
                    } else {
                        .none
                    }
                    return .concatenate(
                        viewingStatisticsStateEffect,
                        liveVideoMonitorCancellation,
                        Self.clearNowPlaying(state: &state, client: nowPlayingClient),
                        reconnectEffect
                    )
                } else if newState == .error {
                    PlayerLogger.shared.error(
                        category: "VLC",
                        message: "VLC state changed to .error for \"\(state.item.title)\""
                    )
                    state.isTransitioningEpisode = false
                    return .merge(viewingStatisticsStateEffect, liveVideoMonitorCancellation, nowPlayingUpdate, .send(.initiateAutoReconnect))
                }
                return .merge(viewingStatisticsStateEffect, liveVideoMonitorCancellation, nowPlayingUpdate)
            case .endReached:
                PlayerLogger.shared.info(
                    category: "VLC",
                    message: "Stream end reached for \"\(state.item.title)\" (Live: \(state.item.isLive))"
                )
                if state.item.isLive, !state.isUserPaused, !state.isMinimized {
                    return .send(.initiateAutoReconnect)
                } else if !state.item.isLive {
                    if settingsClient.autoPlayNextEpisode(), !state.isTransitioningEpisode {
                        return .send(.playNextEpisode)
                    }
                }
            case .encounteredError:
                PlayerLogger.shared.error(
                    category: "VLC",
                    message: "VLC encountered playback error on \"\(state.item.title)\""
                )
                state.isTransitioningEpisode = false
                return .send(.initiateAutoReconnect)
            case let .timeChanged(time):
                guard state.isPlayingCatchup
                    ? state.activeCatchupSeekRequestID == nil
                    : state.item.isLive || state.activeVODSeekRequestID == nil
                else {
                    return .none
                }
                let advancedDuringBuffering = !state.isUserPaused
                    && (state.playerState == .buffering || state.playerState == .opening)
                    && Self.durationSeconds(time) > Self.durationSeconds(state.currentTime) + 0.5
                if state.isPlayingCatchup,
                   state.catchupSeekExpectedTimeSeconds != nil || state.catchupSeekExpectedPosition != nil
                {
                    let duration = Self.catchupDurationSeconds(
                        reported: state.totalTime,
                        maximum: state.catchupArchiveDurationSeconds
                    ) ?? 0
                    guard Self.timelineTimeIsValid(time, totalSeconds: duration),
                          Self.seekLanded(
                              currentTime: time,
                              position: nil,
                              expectedSeconds: state.catchupSeekExpectedTimeSeconds,
                              expectedPosition: state.catchupSeekExpectedPosition,
                              durationSeconds: duration
                          )
                    else { return .none }
                    state.catchupSeekExpectedTimeSeconds = nil
                    state.catchupSeekExpectedPosition = nil
                } else if state.isPlayingCatchup, state.catchupSeekTimelineRecoveryRequired {
                    let duration = Self.catchupDurationSeconds(
                        reported: state.totalTime,
                        maximum: state.catchupArchiveDurationSeconds
                    ) ?? 0
                    guard Self.timelineTimeIsValid(time, totalSeconds: duration) else { return .none }
                    guard Self.seekLanded(
                        currentTime: time,
                        position: nil,
                        expectedSeconds: state.catchupSeekPreviousTime.map(Self.durationSeconds),
                        expectedPosition: nil,
                        durationSeconds: duration
                    ) else { return .none }
                    state.catchupSeekTimelineRecoveryRequired = false
                    state.catchupSeekPreviousTime = nil
                    state.catchupSeekPreviousPosition = nil
                } else if !state.isPlayingCatchup, !state.item.isLive, state.vodSeekTimelineRecoveryRequired {
                    let duration = Self.durationSeconds(state.totalTime)
                    guard Self.timelineTimeIsValid(time, totalSeconds: duration) else { return .none }
                    guard Self.seekLanded(
                        currentTime: time,
                        position: nil,
                        expectedSeconds: state.vodSeekPreviousTime.map(Self.durationSeconds),
                        expectedPosition: nil,
                        durationSeconds: duration
                    ) else { return .none }
                    state.vodSeekTimelineRecoveryRequired = false
                    state.vodSeekPreviousTime = nil
                    state.vodSeekPreviousPosition = nil
                } else if !state.isPlayingCatchup, !state.item.isLive,
                          state.expectedVODSeekTargetSeconds != nil || state.expectedVODSeekTargetPosition != nil
                {
                    let duration = Self.durationSeconds(state.totalTime)
                    guard Self.timelineTimeIsValid(time, totalSeconds: duration),
                          Self.seekLanded(
                              currentTime: time,
                              position: nil,
                              expectedSeconds: state.expectedVODSeekTargetSeconds,
                              expectedPosition: state.expectedVODSeekTargetPosition,
                              durationSeconds: duration
                          )
                    else { return .none }
                    state.expectedVODSeekTargetSeconds = nil
                    state.expectedVODSeekTargetPosition = nil
                }
                let isSameSecond = time.components.seconds == state.currentTime.components.seconds
                state.currentTime = time
                if state.item.epgChannelID == nil, state.totalTime.components.seconds == 0, state.position > 0.001, time.components.seconds > 0 {
                    let totalSecs = Double(time.components.seconds) / state.position
                    state.totalTime = Duration.seconds(totalSecs)
                }

                // If within the same second and total duration is already known, avoid CPU churn
                if isSameSecond, state.totalTime.components.seconds > 0, state.subtitleReplaySession == nil,
                   !advancedDuringBuffering
                {
                    return .none
                }

                var effects: [Effect<Action>] = []
                if advancedDuringBuffering {
                    PlayerLogger.shared.info(
                        category: "State",
                        message: "Clearing stale \(state.playerState) state after playback timeline advanced to \(Self.durationSeconds(time))s"
                    )
                    effects.append(.send(.handlePlayerEvent(.stateChanged(.playing))))
                }
                if let session = state.subtitleReplaySession,
                   let temporaryTrackID = session.temporarySubtitleTrackID,
                   session.itemID == state.item.id,
                   session.playbackRequestID == state.playbackRequestID,
                   time >= session.restoreAt,
                   !state.isUserPaused,
                   !state.isSwitchingPlaybackEngine,
                   !state.isClosing
                {
                    let originalTrack = session.originalSubtitleTrackID.flatMap { originalID in
                        state.subtitleTracks.first(where: { $0.id == originalID })
                    }
                    state.subtitleReplaySession = nil
                    if state.selectedSubtitleTrack?.id == temporaryTrackID {
                        state.selectedSubtitleTrack = originalTrack
                        effects.append(
                            .run { _ in await playerClient.setSubtitleTrack(originalTrack) }
                                .cancellable(id: CancelID.subtitleReplayTrackSelection, cancelInFlight: true)
                        )
                    } else {
                        effects.append(.cancel(id: CancelID.subtitleReplayTrackSelection))
                    }
                }
                let activeProfileID = profileContextClient.snapshot().profileID
                if state.viewingStatisticsProfileID != activeProfileID {
                    effects.append(Self.flushViewingStatistics(state: &state, client: viewingStatisticsClient))
                    state.viewingStatisticsProfileID = activeProfileID
                    state.viewingStatisticsLastPlaybackSeconds = nil
                    state.viewingStatisticsLastWallTime = nil
                }
                let media = Self.viewingStatisticsMedia(for: state.item)
                if state.viewingStatisticsMedia != media {
                    effects.append(Self.flushViewingStatistics(state: &state, client: viewingStatisticsClient))
                    state.viewingStatisticsMedia = media
                    state.viewingStatisticsLastPlaybackSeconds = nil
                    state.viewingStatisticsLastWallTime = nil
                }
                let wallTime = Date.timeIntervalSinceReferenceDate
                let playbackSeconds = Double(time.components.seconds)
                if state.playerState == .playing,
                   !state.isUserPaused,
                   !state.isSwitchingPlaybackEngine,
                   !state.isClosing
                {
                    if let lastPlayback = state.viewingStatisticsLastPlaybackSeconds,
                       let lastWallTime = state.viewingStatisticsLastWallTime
                    {
                        let elapsed = wallTime - lastWallTime
                        let playbackAdvance = playbackSeconds - lastPlayback
                        if elapsed > 0, elapsed <= 8, playbackAdvance > 0, playbackAdvance <= elapsed * 4 + 2 {
                            state.viewingStatisticsPendingSeconds += min(elapsed, 5)
                        }
                    }
                    state.viewingStatisticsLastPlaybackSeconds = playbackSeconds
                    state.viewingStatisticsLastWallTime = wallTime
                    if state.viewingStatisticsPendingSeconds >= 10 {
                        effects.append(Self.flushViewingStatistics(state: &state, client: viewingStatisticsClient))
                    }
                } else {
                    state.viewingStatisticsLastPlaybackSeconds = nil
                    state.viewingStatisticsLastWallTime = nil
                }
                effects.append(updateUpNextState(state: &state, settingsClient: settingsClient))
                effects.append(reloadSkipMarkersAfterProfileChange(state: &state, profileContextClient: profileContextClient))
                effects.append(reloadRememberedPlaybackChoiceAfterProfileChange(state: &state, profileContextClient: profileContextClient))
                effects.append(Self.updateNowPlaying(state: state, client: nowPlayingClient, force: false))
                return .merge(effects)
            case let .lengthChanged(length):
                state.totalTime = length
                return .merge(
                    updateUpNextState(state: &state, settingsClient: settingsClient),
                    Self.updateNowPlaying(state: state, client: nowPlayingClient)
                )
            case let .positionChanged(pos):
                guard state.isPlayingCatchup
                    ? state.activeCatchupSeekRequestID == nil
                    : state.item.isLive || state.activeVODSeekRequestID == nil
                else {
                    return .none
                }
                if state.isPlayingCatchup, state.catchupSeekTimelineRecoveryRequired {
                    // Time events are emitted immediately before position events. Keep
                    // both timeline values frozen until time confirms the restored item;
                    // otherwise a delayed position=0 sample can move the slider to start.
                    return .none
                } else if !state.isPlayingCatchup, !state.item.isLive, state.vodSeekTimelineRecoveryRequired {
                    return .none
                }
                if state.isPlayingCatchup,
                   state.catchupSeekExpectedTimeSeconds != nil || state.catchupSeekExpectedPosition != nil
                {
                    return .none
                } else if !state.isPlayingCatchup, !state.item.isLive,
                          state.expectedVODSeekTargetSeconds != nil || state.expectedVODSeekTargetPosition != nil
                {
                    return .none
                }
                let delta = abs(pos - state.position)
                state.position = pos
                if state.item.epgChannelID == nil, state.totalTime.components.seconds == 0, pos > 0.001, state.currentTime.components.seconds > 0 {
                    let totalSecs = Double(state.currentTime.components.seconds) / pos
                    state.totalTime = Duration.seconds(totalSecs)
                }

                if delta < 0.005, state.totalTime.components.seconds > 0 {
                    return .none
                }

                let effects: [Effect<Action>] = [
                    updateUpNextState(state: &state, settingsClient: settingsClient),
                    reloadSkipMarkersAfterProfileChange(state: &state, profileContextClient: profileContextClient),
                    reloadRememberedPlaybackChoiceAfterProfileChange(state: &state, profileContextClient: profileContextClient),
                ]

                return .merge(effects)
            default:
                break
            }
            return .none

        case .toggleRecordingTapped:
            if state.isRecording {
                guard !state.isRecordingStopPending else { return .none }
                return .run { send in
                    await playerClient.requestRecordingStop()
                    await send(.recordingStopUnconfirmed)
                }
            }
            guard state.item.isLive,
                  state.activeCatchupProgram == nil,
                  state.playerState == .playing,
                  !state.isRecordingStartPending
            else { return .none }
            state.isRecordingStartPending = true
            state.recordingStatusMessage = nil
            let channelTitle = state.item.title
            return .run { send in
                do {
                    let directory = try await MainActor.run {
                        try LocalDVRManager.shared.prepareRecordingDirectory()
                    }
                    await MainActor.run {
                        LocalDVRManager.shared.beginRecording(channelTitle: channelTitle)
                    }
                    guard await playerClient.startRecording(directory) else {
                        await send(.recordingStartFailed)
                        return
                    }
                    try await Task.sleep(for: .seconds(5))
                    await send(.recordingStartTimedOut)
                } catch {
                    await send(.recordingStartFailed)
                }
            }

        case .recordingStartFailed:
            state.isRecordingStartPending = false
            state.isRecording = false
            state.isRecordingStopPending = false
            state.recordingFilePath = nil
            state.recordingStartedAt = nil
            state.recordingStatusMessage = AppStrings.Player.recordingCouldNotStart
            return .merge(
                .run { _ in await MainActor.run { LocalDVRManager.shared.cancelRecordingSession() } },
                .run { send in
                    try? await Task.sleep(for: .seconds(4))
                    await send(.dismissRecordingStatus)
                }.cancellable(id: CancelID.recordingStatus, cancelInFlight: true)
            )

        case .recordingStartTimedOut:
            guard state.isRecordingStartPending, !state.isRecording else { return .none }
            return .run { send in
                await playerClient.requestRecordingStop()
                await send(.recordingStopUnconfirmed)
            }

        case .recordingStopUnconfirmed:
            guard state.isRecording || state.isRecordingStartPending else { return .none }
            if state.isRecording {
                state.isRecordingStartPending = false
            }
            state.isRecordingStopPending = true
            if !state.isRecordingStartPending {
                state.isRecording = true
            }
            state.recordingStatusMessage = AppStrings.Player.recordingStopping
            return .run { send in
                try? await Task.sleep(for: .seconds(8))
                await send(.recordingStopTimedOut)
            }
            .cancellable(id: CancelID.recordingStopTimeout, cancelInFlight: true)

        case .recordingStopTimedOut:
            guard state.isRecordingStopPending else { return .none }
            state.isRecordingStopPending = false
            if state.isRecordingStartPending, !state.isRecording {
                state.isRecordingStartPending = false
                state.recordingFilePath = nil
                state.recordingStartedAt = nil
                state.recordingStatusMessage = AppStrings.Player.recordingCouldNotStart
                LocalDVRManager.shared.cancelRecordingSession()
                return .run { _ in
                    await playerClient.cancelRecordingStopObserver()
                }
            }
            state.recordingStatusMessage = AppStrings.Player.recordingCouldNotStop
            return .none

        case let .recordingFinalized(filePath):
            guard state.isRecording || state.isRecordingStartPending else { return .none }
            state.isRecording = false
            state.isRecordingStartPending = false
            state.isRecordingStopPending = false
            state.recordingFilePath = nil
            state.recordingStartedAt = nil
            let saved = LocalDVRManager.shared.finishRecording(filePath: filePath) != nil
            state.recordingStatusMessage = saved ? AppStrings.Player.recordingSaved : AppStrings.Player.recordingCouldNotStart
            return .merge(
                .cancel(id: CancelID.recordingMonitor),
                .cancel(id: CancelID.recordingStopTimeout),
                .run { send in
                    try? await Task.sleep(for: .seconds(4))
                    await send(.dismissRecordingStatus)
                }.cancellable(id: CancelID.recordingStatus, cancelInFlight: true)
            )

        case .recordingLimitCheck:
            guard state.isRecording else { return .cancel(id: CancelID.recordingMonitor) }
            guard !state.isRecordingStopPending else { return .none }
            let elapsed = state.recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
            let currentSize = LocalDVRManager.shared.recordingFileSize(at: state.recordingFilePath)
            guard elapsed >= 4 * 60 * 60 || currentSize >= LocalDVRManager.shared.maximumRecordingBytes - 50_000_000 else { return .none }
            return .run { send in
                await playerClient.requestRecordingStop()
                await send(.recordingStopUnconfirmed)
            }

        case .dismissRecordingStatus:
            state.recordingStatusMessage = nil
            return .none

        case .saveCurrentPlaybackEnginePreference:
            guard state.canSwitchPlaybackEngine,
                  state.canManagePlaybackEnginePreference,
                  !state.isSwitchingPlaybackEngine
            else { return .none }
            let profileID = profileContextClient.snapshot().profileID
            SpecificPlaybackEnginePreferenceStore.save(
                state.playbackEngine,
                item: state.item,
                profileID: profileID
            )
            state.itemSpecificPlaybackEnginePreference = state.playbackEngine
            state.rememberedPlaybackChoice = nil
            return .none

        case .clearCurrentPlaybackEnginePreference:
            guard state.canManagePlaybackEnginePreference,
                  !state.isSwitchingPlaybackEngine,
                  state.itemSpecificPlaybackEnginePreference != nil
            else { return .none }
            let profileID = profileContextClient.snapshot().profileID
            SpecificPlaybackEnginePreferenceStore.clear(item: state.item, profileID: profileID)
            state.itemSpecificPlaybackEnginePreference = nil
            let playbackDefaults = settingsClient.playbackDefaults(state.playbackContentKind)
            let fallbackEngine = Self.resolvedPlaybackEngine(
                item: state.item,
                kind: state.playbackContentKind,
                defaults: playbackDefaults,
                settingsClient: settingsClient,
                profileID: profileID
            )
            return fallbackEngine == state.playbackEngine ? .none : .send(.switchPlaybackEngine(fallbackEngine))

        case let .switchPlaybackEngine(target):
            guard state.canSwitchPlaybackEngine, !state.isSwitchingPlaybackEngine,
                  target != state.playbackEngine else { return .none }
            state.isSwitchingPlaybackEngine = true
            state.subtitleReplaySession = nil
            state.memoryPressureDeinterlaceFallbackRequestID = nil
            state.playbackEngineError = nil
            if state.activeVODSeekRequestID != nil {
                if let previousTime = state.vodSeekPreviousTime {
                    state.currentTime = previousTime
                }
                if let previousPosition = state.vodSeekPreviousPosition {
                    state.position = previousPosition
                }
            }
            state.activeVODSeekRequestID = nil
            state.vodSeekTimelineRecoveryRequired = false
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            state.expectedVODSeekTargetSeconds = nil
            state.expectedVODSeekTargetPosition = nil
            state.vodSeekPreviousTime = nil
            state.vodSeekPreviousPosition = nil
            state.vodSeekFailureRequestID = nil
            state.didRequestXtreamLiveOutputFormats = false
            state.isLoadingXtreamLiveOutputFormats = false
            state.xtreamLiveOutputFormatOptions = []
            state.xtreamLiveOutputFormatError = nil
            state.activeXtreamLiveOutputFormatRequestID = nil
            let requestID = UUID()
            state.playbackEngineSwitchID = requestID
            state.playbackEngineSwitchProfileID = profileContextClient.snapshot().profileID
            state.mediaInfoRequestID = nil
            let itemID = state.item.id
            let item = state.item
            let playbackDefaults = settingsClient.playbackDefaults(state.playbackContentKind)
            let subtitleTextScale = playbackDefaults.subtitleTextSize.scale
            let currentTimeComponents = state.currentTime.components
            let currentPositionSeconds = Double(currentTimeComponents.seconds)
                + Double(currentTimeComponents.attoseconds) / 1_000_000_000_000_000_000
            let request = PlaybackEngineSwitchRequest(
                requestID: requestID,
                target: target,
                url: item.streamURL,
                userAgentOverride: item.userAgentOverride,
                networkCachingMilliseconds: playbackDefaults.networkCachingMilliseconds(for: state.playbackContentKind),
                deinterlaceMode: state.isDeinterlaceModeKnown ? state.deinterlaceMode : .automatic,
                positionSeconds: currentPositionSeconds,
                isPlaying: state.playbackRecoveryErrorMessage != nil
                    || state.playerState == .playing
                    || state.playerState == .buffering,
                playbackRate: state.playbackRate,
                volume: state.volume,
                selectedAudioName: state.selectedAudioTrack?.name,
                selectedAudioLanguage: state.selectedAudioTrack?.language,
                selectedSubtitleName: state.selectedSubtitleTrack?.name,
                selectedSubtitleLanguage: state.selectedSubtitleTrack?.language
            )
            return .merge(
                .cancel(id: CancelID.memoryPressureDeinterlaceFallback),
                .cancel(id: CancelID.vodSeek),
                .cancel(id: CancelID.vodSeekFeedback),
                .cancel(id: CancelID.subtitleReplaySeek),
                .cancel(id: CancelID.subtitleReplayTrackSelection),
                .cancel(id: CancelID.xtreamLiveOutputFormats),
                Self.clearNowPlaying(state: &state, client: nowPlayingClient),
                .run { send in
                    do {
                        let appliedMode = try await playerClient.switchEngine(request)
                        if target == .vlc {
                            await playerClient.setSubtitleTextScale(subtitleTextScale)
                        }
                        await send(.playbackEngineSwitchFinished(target, appliedMode, requestID, itemID))
                    } catch {
                        await send(.playbackEngineSwitchFailed(error.localizedDescription, requestID, itemID))
                    }
                }
                .cancellable(id: CancelID.playbackEngineSwitch, cancelInFlight: true)
            )

        case let .playbackEngineSwitchFinished(engine, deinterlaceMode, requestID, itemID):
            guard state.playbackEngineSwitchID == requestID, state.item.id == itemID else { return .none }
            let profileID = state.playbackEngineSwitchProfileID
            if let scopeKey = PlaybackChoicePreferenceStore.scopeKey(
                item: state.item,
                playbackURL: state.activePlaybackURL,
                profileID: profileID
            ) {
                state.dismissedRememberedPlaybackChoiceScopeKeys.insert(scopeKey)
            }
            PlaybackChoicePreferenceStore.save(
                .inApp(engine),
                item: state.item,
                playbackURL: state.activePlaybackURL,
                profileID: profileID
            )
            state.playbackEngineSwitchProfileID = nil
            state.rememberedPlaybackChoice = nil
            let isErrorRecovery = state.playbackRecoveryErrorMessage != nil
            state.playbackRecoveryErrorMessage = nil
            state.isSwitchingPlaybackEngine = false
            state.playbackEngineSwitchID = nil
            state.playbackEngine = engine
            if isErrorRecovery {
                state.errorMessage = nil
                state.isReconnecting = false
            }
            state.playbackRequestID = UUID()
            state.playbackPositionRecoveryRequestID = nil
            state.playbackPositionRecoveryExpectedPosition = nil
            state.mediaInfoRequestID = nil
            state.mediaInfo = nil
            state.firstPresentedFrameLatency = nil
            state.firstPresentedFrameFeedbackRequestID = nil
            state.activeVODSeekRequestID = nil
            state.vodSeekTimelineRecoveryRequired = false
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            state.expectedVODSeekTargetSeconds = nil
            state.expectedVODSeekTargetPosition = nil
            state.vodSeekPreviousPosition = nil
            state.vodSeekPreviousTime = nil
            state.vodSeekFailureRequestID = nil
            let requestedMode = state.deinterlaceMode
            state.deinterlaceMode = deinterlaceMode
            state.isDeinterlaceModeKnown = true
            if engine == .vlc, requestedMode != deinterlaceMode {
                state.playbackEngineError = AppStrings.Player.deinterlaceFallback
            }
            state.isPiPSupported = engine == .vlc && pipClient.isPiPSupported()
            if engine == .avPlayer {
                state.audioTracks = []
                state.subtitleTracks = []
                state.externalSubtitleTrackIDs = []
                state.isAudioSyncHUDVisible = false
                state.isAudioEQHUDVisible = false
                state.subtitleReplaySession = nil
            }
            return .merge(
                .cancel(id: CancelID.playerEvents),
                .cancel(id: CancelID.vodSeek),
                .cancel(id: CancelID.vodSeekFeedback),
                .cancel(id: CancelID.highFPSFeedback),
                .send(.listenForPlayerEvents),
                Self.updateNowPlaying(state: state, client: nowPlayingClient),
                engine == .vlc ? .send(.fetchMediaInfo) : .none
            )

        case let .playbackEngineSwitchFailed(message, requestID, itemID):
            guard state.playbackEngineSwitchID == requestID, state.item.id == itemID else { return .none }
            if let recoveryError = state.playbackRecoveryErrorMessage {
                state.errorMessage = recoveryError
                state.isReconnecting = false
            }
            state.playbackRecoveryErrorMessage = nil
            state.isSwitchingPlaybackEngine = false
            state.playbackEngineSwitchID = nil
            state.playbackEngineSwitchProfileID = nil
            _ = message
            state.playbackEngineError = AppStrings.Player.playbackEngineSwitchFailed
            return Self.updateNowPlaying(state: state, client: nowPlayingClient)

        case .listenForPlayerEvents:
            let itemID = state.item.id
            let playbackRequestID = state.playbackRequestID
            return .run { send in
                let stream = await playerClient.events()
                let healthBaseline = await playerClient.playbackHealthSnapshot()
                let healthStream = await playerClient.playbackHealthEvents()
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await event in stream {
                            guard !Task.isCancelled else { return }
                            await send(.handlePlayerEvent(event))
                        }
                    }
                    if let healthBaseline {
                        group.addTask {
                            for await event in healthStream {
                                await send(.playbackHealthEvent(
                                    event,
                                    itemID: itemID,
                                    playbackRequestID: playbackRequestID,
                                    baselineGeneration: healthBaseline.generation,
                                    baselineHadPresentedFrame: healthBaseline.lastPresentedAt != nil
                                ))
                            }
                        }
                    }
                }
            }.cancellable(id: CancelID.playerEvents, cancelInFlight: true)

        case .playerEvent:
            return .none

        case .closeTapped:
            guard !state.isClosing else { return .none }
            state.isClosing = true
            state.subtitleReplaySession = nil
            state.mediaServerPlaybackOptionsRequestID = nil
            state.mediaServerPlaybackOptionsCheckedItemID = nil
            state.mediaServerPlaybackOptions = []
            state.isMediaServerPlaybackOptionsPresented = false
            state.selectedMediaServerPlaybackSourceID = nil
            state.offlineEpisodeTransitionRequestID = nil
            state.memoryPressureDeinterlaceFallbackRequestID = nil
            state.playbackRequestID = UUID()
            state.speedTestPresentationRequestID = nil
            state.subtitleSearchPresentationRequestID = nil
            state.subtitleSearchTrackInstallRequestID = nil
            state.subtitleSearchTrackInstallErrorMessage = nil
            state.playbackRecoveryErrorMessage = nil
            state.playbackPositionRecoveryRequestID = nil
            state.playbackPositionRecoveryExpectedPosition = nil
            state.mediaInfoRequestID = nil
            state.firstPresentedFrameLatency = nil
            state.firstPresentedFrameFeedbackRequestID = nil
            state.activeVODSeekRequestID = nil
            state.vodSeekTimelineRecoveryRequired = false
            state.restartPlaybackAfterVODSeekRequestID = nil
            state.restartPlaybackAfterCatchupSeekRequestID = nil
            state.expectedVODSeekTargetSeconds = nil
            state.expectedVODSeekTargetPosition = nil
            state.vodSeekPreviousPosition = nil
            state.vodSeekPreviousTime = nil
            state.vodSeekFailureRequestID = nil
            state.didRequestXtreamLiveOutputFormats = false
            state.isLoadingXtreamLiveOutputFormats = false
            state.xtreamLiveOutputFormatOptions = []
            state.xtreamLiveOutputFormatError = nil
            state.activeXtreamLiveOutputFormatRequestID = nil
            state.activeCatchupSeekRequestID = nil
            state.catchupSeekPreviousTime = nil
            state.catchupSeekPreviousPosition = nil
            state.catchupSeekExpectedTimeSeconds = nil
            state.catchupSeekExpectedPosition = nil
            state.catchupSeekTimelineRecoveryRequired = false
            state.catchupSeekFailureMessage = nil
            state.catchupSeekFailureRequestID = nil
            let shouldStopRecording = state.isRecording || state.isRecordingStartPending
            let reducerCurrentTime = state.currentTime
            let totalSecs = Self.durationSeconds(state.totalTime)
            let item = state.item
            let mediaServerProxyURL = state.mediaServerProxyURL
            let profileScope = profileContextClient.snapshot()
            let isPiPActive = state.isPiPActive
            let nowPlayingCleanup: Effect<Action> = if isPiPActive {
                .none
            } else {
                Self.deactivateNowPlaying(state: &state, client: nowPlayingClient)
            }
            let viewingStatisticsFlush = Self.flushViewingStatistics(state: &state, client: viewingStatisticsClient)
            state.mediaServerPlaybackRequestID = nil
            state.mediaServerPlaybackStatus = nil
            state.mediaServerPlaybackStatusRequestID = nil
            state.hasAttemptedMediaServerPlaybackStatus = false
            state.displayModeRequestID = UUID()
            if !isPiPActive {
                state.mediaServerProxyURL = nil
            }
            return .merge(
                viewingStatisticsFlush,
                .cancel(id: CancelID.playerEvents),
                .cancel(id: CancelID.memoryPressureWarnings),
                .cancel(id: CancelID.memoryPressureDeinterlaceFallback),
                .cancel(id: CancelID.mediaServerPlaybackOptions),
                .cancel(id: CancelID.mediaServerPlaybackStatus),
                .cancel(id: CancelID.playbackEngineSwitch),
                .cancel(id: CancelID.channelSwitch),
                .cancel(id: CancelID.scrubThumbnail),
                .cancel(id: CancelID.xtreamLiveOutputFormats),
                .cancel(id: CancelID.catchupSeek),
                .cancel(id: CancelID.catchupSeekFeedback),
                .cancel(id: CancelID.vodSeek),
                .cancel(id: CancelID.vodSeekFeedback),
                .cancel(id: CancelID.subtitleReplaySeek),
                .cancel(id: CancelID.subtitleReplayTrackSelection),
                .cancel(id: CancelID.highFPSFeedback),
                .cancel(id: CancelID.seriesPlaylist),
                .cancel(id: CancelID.oledDimTimer),
                .cancel(id: CancelID.audioRoute),
                .cancel(id: CancelID.audioRouteHUD),
                .cancel(id: CancelID.upNextCountdown),
                .cancel(id: CancelID.offlineEpisodeAvailability),
                .cancel(id: CancelID.subtitleSearchTrackInstall),
                .cancel(id: CancelID.channelOSD),
                .cancel(id: CancelID.statsTimer),
                nowPlayingCleanup,
                .cancel(id: CancelID.liveVideoStallMonitor),
                .cancel(id: CancelID.stallWatchdog),
                .cancel(id: CancelID.initialResumeSeekVerification),
                .cancel(id: CancelID.reconnectTimer),
                .cancel(id: CancelID.dynamicRangeHUD),
                .cancel(id: CancelID.afrToast),
                .cancel(id: CancelID.displayMode),
                .run { _ in
                    if !isPiPActive {
                        await displayModeClient.resetDisplayMode()
                    }
                },
                .run { send in
                    if shouldStopRecording {
                        await playerClient.requestRecordingStop()
                        await send(.recordingStopUnconfirmed)
                    }
                    // Save Watch History before stopping
                    let savedTime = await playerClient.currentPlaybackTime() ?? reducerCurrentTime
                    let currentSecs = Self.durationSeconds(savedTime)
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
                        do {
                            try await databaseClient.saveWatchProgress(historyItem, profileScope)
                            PlayerLogger.shared.info(
                                category: "PlaybackProgress",
                                message: "Saved progress on close for \(item.id) at \(currentSecs)s"
                            )
                        } catch {
                            PlayerLogger.shared.error(
                                category: "PlaybackProgress",
                                message: "Failed to save progress on close for \(item.id): \(error.localizedDescription)"
                            )
                        }
                    }

                    if !isPiPActive {
                        try? await playerClient.stop()
                        await playerClient.release()
                        await MediaServerStreamProxy.shared.closeSession(for: mediaServerProxyURL)
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
            guard state.playbackEngine == .vlc else { return .none }
            guard !state.isMinimized else { return .none }
            state.isMinimized = true
            state.speedTestPresentationRequestID = nil
            state.subtitleSearchPresentationRequestID = nil
            state.subtitleSearchTrackInstallRequestID = nil
            state.subtitleSearchTrackInstallErrorMessage = nil
            return .merge(
                stopLiveVideoStallMonitoring(state: &state),
                .cancel(id: CancelID.subtitleSearchTrackInstall),
                .run { send in
                    await send(.delegate(.didRequestMinimize))
                    await MainActor.run {
                        #if os(iOS)
                            OrientationManager.shared.unlockPortrait()
                        #endif
                    }
                }
            )

        case .speedTestTapped:
            guard !state.isMinimized,
                  !state.isClosing,
                  state.speedTestPresentationRequestID == nil
            else { return .none }
            let requestID = UUID()
            state.speedTestPresentationRequestID = requestID
            return .send(.delegate(.presentSpeedTest(requestID: requestID)))

        case let .closeSpeedTest(requestID):
            guard state.speedTestPresentationRequestID == requestID else { return .none }
            state.speedTestPresentationRequestID = nil
            return .none

        case .subtitleSearchTapped:
            guard !state.item.isLive,
                  state.playbackEngine == .vlc,
                  !state.isMinimized,
                  !state.isClosing,
                  state.subtitleSearchPresentationRequestID == nil
            else { return .none }
            let requestID = UUID()
            state.subtitleSearchPresentationRequestID = requestID
            state.subtitleSearchTrackInstallRequestID = nil
            state.subtitleSearchTrackInstallErrorMessage = nil
            return .send(.delegate(.presentSubtitleSearch(requestID: requestID)))

        case let .closeSubtitleSearch(requestID):
            guard state.subtitleSearchPresentationRequestID == requestID else { return .none }
            state.subtitleSearchPresentationRequestID = nil
            state.subtitleSearchTrackInstallRequestID = nil
            state.subtitleSearchTrackInstallErrorMessage = nil
            return .cancel(id: CancelID.subtitleSearchTrackInstall)

        case let .installSubtitleSearchTrack(url, requestID, playbackRequestID):
            guard state.subtitleSearchPresentationRequestID == requestID,
                  state.playbackRequestID == playbackRequestID,
                  state.item.isLive == false,
                  state.playbackEngine == .vlc,
                  !state.isMinimized,
                  !state.isClosing,
                  state.subtitleSearchTrackInstallRequestID == nil
            else {
                if ExternalSubtitleTextEncoding.isOwnedTemporaryFile(url) {
                    try? FileManager.default.removeItem(at: url)
                }
                return .none
            }
            state.subtitleSearchTrackInstallRequestID = requestID
            state.subtitleSearchTrackInstallErrorMessage = nil
            return .run { send in
                var didInstall = false
                defer {
                    if !didInstall, ExternalSubtitleTextEncoding.isOwnedTemporaryFile(url) {
                        try? FileManager.default.removeItem(at: url)
                    }
                }
                let existingTrackIDs = await Set((playerClient.getSubtitleTracks()).map(\.id))
                let didAdd = await playerClient.addExternalSubtitleTrack(url)
                didInstall = didAdd
                let externalTrackIDs = await didAdd
                    ? Set((playerClient.getSubtitleTracks()).map(\.id)).subtracting(existingTrackIDs).sorted()
                    : []
                await send(.subtitleSearchTrackInstallResponse(
                    requestID: requestID,
                    playbackRequestID: playbackRequestID,
                    didAdd: didAdd,
                    externalTrackIDs: externalTrackIDs
                ))
            }
            .cancellable(id: CancelID.subtitleSearchTrackInstall, cancelInFlight: true)

        case let .subtitleSearchTrackInstallResponse(requestID, playbackRequestID, didAdd, externalTrackIDs):
            guard state.subtitleSearchPresentationRequestID == requestID,
                  state.playbackRequestID == playbackRequestID,
                  state.subtitleSearchTrackInstallRequestID == requestID,
                  !state.isMinimized,
                  !state.isClosing
            else { return .none }
            state.subtitleSearchTrackInstallRequestID = nil
            guard didAdd else {
                state.subtitleSearchTrackInstallErrorMessage = AppStrings.Player.externalSubtitleAddFailed
                return .none
            }
            state.externalSubtitleTrackIDs.formUnion(externalTrackIDs)
            state.subtitleSearchTrackInstallErrorMessage = nil
            return .merge(
                .send(.fetchTracks),
                .send(.closeSubtitleSearch(requestID: requestID))
            )

        case .sharePlayTapped:
            guard state.item.config?.type != .plex, state.item.config?.type != .emby else { return .none }
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
            guard state.playbackEngine == .vlc else { return .none }
            state.shouldTriggerPiP = true
            return .none

        case .resetPiPTrigger:
            state.shouldTriggerPiP = false
            return .none

        case let .onPiPStatusChanged(isActive):
            state.isPiPActive = isActive
            return isActive
                ? Self.stopLiveVideoStallMonitoring(state: &state)
                : .send(.startLiveVideoStallMonitoring(itemID: state.item.id, playbackRequestID: state.playbackRequestID))

        case let .setAutoPiPEnabled(enabled):
            state.isAutoPiPEnabled = enabled
            return .run { _ in pipClient.setAutoPiPEnabled(enabled) }

        case let .setBackgroundPlaybackMode(mode):
            state.backgroundPlaybackMode = mode
            return .run { _ in pipClient.setBackgroundPlaybackMode(mode) }

        case .appMovedToBackground:
            state.isAppInBackground = true
            let nowPlayingUpdate = Self.updateNowPlaying(state: state, client: nowPlayingClient)
            if state.playbackEngine == .avPlayer {
                return .merge(stopLiveVideoStallMonitoring(state: &state), .send(.pause))
            }
            if state.isRecording || state.isRecordingStartPending {
                return .merge(
                    stopLiveVideoStallMonitoring(state: &state),
                    nowPlayingUpdate,
                    .run { send in
                        await playerClient.requestRecordingStop()
                        await send(.recordingStopUnconfirmed)
                    }
                )
            }
            switch state.backgroundPlaybackMode {
            case .pip:
                if state.isAutoPiPEnabled, state.isPiPSupported, state.playerState == .playing {
                    state.shouldTriggerPiP = true
                }
                return .merge(stopLiveVideoStallMonitoring(state: &state), nowPlayingUpdate)
            case .audioOnly:
                if state.playerState == .playing {
                    state.isBackgroundAudioActive = true
                }
                return .merge(stopLiveVideoStallMonitoring(state: &state), nowPlayingUpdate)
            case .disabled:
                return .merge(
                    stopLiveVideoStallMonitoring(state: &state),
                    .run { send in
                        await send(.pause)
                    }
                )
            }

        case .appMovedToForeground:
            state.isAppInBackground = false
            state.isBackgroundAudioActive = false
            return .merge(
                updateNowPlaying(state: state, client: nowPlayingClient),
                .send(.startLiveVideoStallMonitoring(itemID: state.item.id, playbackRequestID: state.playbackRequestID))
            )

        case .pipStarted:
            state.isPiPActive = true
            return stopLiveVideoStallMonitoring(state: &state)

        case .pipStopped:
            state.isPiPActive = false
            #if os(iOS)
                if UIApplication.shared.applicationState == .background {
                    if state.backgroundPlaybackMode == .audioOnly {
                        state.isBackgroundAudioActive = true
                        return .none
                    } else {
                        let shouldStopRecording = state.isRecording || state.isRecordingStartPending
                        return .run { send in
                            if shouldStopRecording {
                                await playerClient.requestRecordingStop()
                                await send(.recordingStopUnconfirmed)
                            }
                            try? await playerClient.stop()
                            await playerClient.release()
                            await send(.delegate(.didClose))
                        }
                    }
                } else {
                    return .send(.startLiveVideoStallMonitoring(itemID: state.item.id, playbackRequestID: state.playbackRequestID))
                }
            #else
                return .send(.startLiveVideoStallMonitoring(itemID: state.item.id, playbackRequestID: state.playbackRequestID))
            #endif

        case .pipRestoreUI:
            // PiP floating window'dan "geri dön" tıklandı → full-screen'e dön
            state.isPiPActive = false
            state.isControlsVisible = true
            state.oledInactivitySeconds = 0
            return .merge(
                .send(.startLiveVideoStallMonitoring(itemID: state.item.id, playbackRequestID: state.playbackRequestID)),
                .run { _ in
                    #if os(iOS)
                        await MainActor.run {
                            OrientationManager.shared.lockLandscape()
                        }
                    #endif
                }
            )

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
            guard !state.isClosing, !state.isTransitioningEpisode else { return .none }
            guard let next = state.nextEpisodeItem else {
                state.isUpNextVisible = false
                return .cancel(id: CancelID.upNextCountdown)
            }
            state.isTransitioningEpisode = true
            state.isUpNextVisible = false
            state.isUpNextDismissed = false

            if state.item.streamURL.isFileURL, state.item.seriesID != nil,
               let playlist = state.playlist,
               playlist.firstIndex(where: { $0.id == state.item.id }) != nil
            {
                let requestID = UUID()
                let playbackRequestID = state.playbackRequestID
                let itemID = state.item.id
                state.offlineEpisodeTransitionRequestID = requestID
                return .merge(
                    .cancel(id: CancelID.upNextCountdown),
                    .run { [downloadClient] send in
                        let snapshots = await (try? downloadClient.getDownloadedMedia()) ?? []
                        let availablePathsByID = Dictionary(
                            snapshots.filter(\.isAvailable).map {
                                ($0.id, URL(fileURLWithPath: $0.localFilePath).standardizedFileURL.path)
                            },
                            uniquingKeysWith: { _, latest in latest }
                        )
                        let availableNext = next.streamURL.isFileURL &&
                            availablePathsByID[next.id] == next.streamURL.standardizedFileURL.path
                            ? next
                            : nil
                        guard !Task.isCancelled else { return }
                        await send(.offlineEpisodeAvailabilityResponse(
                            requestID: requestID,
                            playbackRequestID: playbackRequestID,
                            itemID: itemID,
                            next: availableNext
                        ))
                    }
                    .cancellable(id: CancelID.offlineEpisodeAvailability, cancelInFlight: true)
                )
            }

            return .merge(
                .cancel(id: CancelID.upNextCountdown),
                .send(.selectChannel(next))
            )

        case let .offlineEpisodeAvailabilityResponse(requestID, playbackRequestID, itemID, next):
            guard state.offlineEpisodeTransitionRequestID == requestID else { return .none }
            state.offlineEpisodeTransitionRequestID = nil
            guard !state.isClosing,
                  state.isTransitioningEpisode,
                  state.item.id == itemID,
                  state.playbackRequestID == playbackRequestID
            else {
                state.isTransitioningEpisode = false
                return .cancel(id: CancelID.offlineEpisodeAvailability)
            }
            guard let next,
                  next.streamURL.isFileURL,
                  next.seriesID == state.item.seriesID,
                  next.config?.playlistID == state.item.config?.playlistID,
                  state.nextEpisodeItem?.id == next.id,
                  state.nextEpisodeItem?.streamURL == next.streamURL
            else {
                state.isTransitioningEpisode = false
                state.isUpNextVisible = false
                state.isUpNextDismissed = true
                return .cancel(id: CancelID.offlineEpisodeAvailability)
            }
            return .concatenate(
                .cancel(id: CancelID.offlineEpisodeAvailability),
                .send(.selectChannel(next))
            )

        case .upNextCountdownTick:
            return .none

        case .applyRememberedPlaybackChoice:
            guard let reminder = state.rememberedPlaybackChoice,
                  PlaybackChoicePreferenceStore.scopeKey(
                      item: state.item,
                      playbackURL: state.activePlaybackURL,
                      profileID: profileContextClient.snapshot().profileID
                  ) == reminder.scopeKey
            else {
                state.rememberedPlaybackChoice = nil
                return .none
            }

            let engine = reminder.choice.playbackEngine
            guard state.canSwitchPlaybackEngine, engine != state.playbackEngine else {
                state.rememberedPlaybackChoice = nil
                return .none
            }
            return .send(.switchPlaybackEngine(engine))

        case .dismissRememberedPlaybackChoice:
            if let reminder = state.rememberedPlaybackChoice {
                state.dismissedRememberedPlaybackChoiceScopeKeys.insert(reminder.scopeKey)
            }
            state.rememberedPlaybackChoice = nil
            return .none

        case .forgetRememberedPlaybackChoice:
            if let reminder = state.rememberedPlaybackChoice {
                PlaybackChoicePreferenceStore.clear(scopeKey: reminder.scopeKey)
            }
            state.rememberedPlaybackChoice = nil
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
            state.isAFREnabledForLive = settingsClient.playbackDefaults(.live).isAFREnabled
            state.isAFREnabledForVOD = settingsClient.playbackDefaults(.vod).isAFREnabled
            state.isAFREnabledForArchive = settingsClient.playbackDefaults(.archive).isAFREnabled
            state.isMatchDynamicRangeEnabled = settingsClient.playbackDefaults(state.playbackContentKind).isMatchDynamicRangeEnabled
            state.isForceSDROutputEnabled = settingsClient.playbackDefaults(state.playbackContentKind).isForceSDROutputEnabled ?? false
            return .none

        case let .setAFREnabledForLive(enabled):
            state.isAFREnabledForLive = enabled
            var playbackDefaults = settingsClient.playbackDefaults(.live)
            playbackDefaults.isAFREnabled = enabled
            settingsClient.setPlaybackDefaults(.live, playbackDefaults)
            #if os(tvOS)
                return .send(.matchDisplayMode)
            #else
                return .none
            #endif

        case let .setAFREnabledForVOD(enabled):
            state.isAFREnabledForVOD = enabled
            var playbackDefaults = settingsClient.playbackDefaults(.vod)
            playbackDefaults.isAFREnabled = enabled
            settingsClient.setPlaybackDefaults(.vod, playbackDefaults)
            #if os(tvOS)
                return .send(.matchDisplayMode)
            #else
                return .none
            #endif

        case let .setAFREnabledForArchive(enabled):
            state.isAFREnabledForArchive = enabled
            var playbackDefaults = settingsClient.playbackDefaults(.archive)
            playbackDefaults.isAFREnabled = enabled
            settingsClient.setPlaybackDefaults(.archive, playbackDefaults)
            #if os(tvOS)
                return .send(.matchDisplayMode)
            #else
                return .none
            #endif

        case let .setMatchDynamicRangeEnabled(enabled):
            state.isMatchDynamicRangeEnabled = enabled
            var playbackDefaults = settingsClient.playbackDefaults(state.playbackContentKind)
            playbackDefaults.isMatchDynamicRangeEnabled = enabled
            settingsClient.setPlaybackDefaults(state.playbackContentKind, playbackDefaults)
            #if os(tvOS)
                return .send(.matchDisplayMode)
            #else
                return .none
            #endif

        case .matchDisplayMode:
            guard state.isDisplayModeMatchingEnabledForCurrentItem else {
                state.displayModeRequestID = UUID()
                return .concatenate(
                    .cancel(id: CancelID.displayMode),
                    .run { _ in await displayModeClient.resetDisplayMode() }
                )
            }
            #if os(tvOS)
                guard state.isAFREnabledForCurrentItem, state.isMatchDynamicRangeEnabled else {
                    state.displayModeRequestID = UUID()
                    return .concatenate(
                        .cancel(id: CancelID.displayMode),
                        .run { _ in await displayModeClient.resetDisplayMode() }
                    )
                }

                guard state.playbackEngine == .avPlayer else {
                    state.displayModeRequestID = UUID()
                    return .concatenate(
                        .cancel(id: CancelID.displayMode),
                        .run { _ in await displayModeClient.resetDisplayMode() }
                    )
                }

                let requestID = UUID()
                state.displayModeRequestID = requestID
                return .run { [displayModeClient, playerClient] send in
                    try Task.checkCancellation()
                    let criteria = await playerClient.preferredDisplayCriteria()
                    try Task.checkCancellation()
                    let result = await displayModeClient.applyPreferredDisplayCriteria(criteria)
                    await send(.displayModeRequestFinished(result, requestID: requestID))
                }.cancellable(id: CancelID.displayMode, cancelInFlight: true)
            #else
                let requestID = UUID()
                state.displayModeRequestID = requestID
                let result = DisplayMatchResult(
                    matchedRate: 0,
                    matchedRange: .unknown,
                    message: AppStrings.Player.displayMatchUnsupportedPlatform,
                    isJudderFree: false,
                    status: .unsupportedPlatform
                )
                return .send(.displayModeRequestFinished(result, requestID: requestID))
            #endif

        case let .displayModeSwitched(result):
            return .send(.showAFRToast(result))

        case let .displayModeRequestFinished(result, requestID):
            guard state.displayModeRequestID == requestID else { return .none }
            guard result.status != .criteriaUnavailable, result.status != .systemMatchingDisabled else {
                return .none
            }
            state.afrMatchResult = result
            state.isAFRToastVisible = true
            return .run { send in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await send(.hideAFRToast)
            }.cancellable(id: CancelID.afrToast, cancelInFlight: true)

        case let .showAFRToast(result):
            guard result.status != .criteriaUnavailable, result.status != .systemMatchingDisabled else {
                return .none
            }
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
