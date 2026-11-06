import AVFoundation
import AVKit
import ComposableArchitecture
import Foundation
import SwiftVLC

public struct MediaInfo: Equatable, Sendable {
    public var resolution: String?
    public var videoCodec: String?
    public var audioCodec: String?
    public var bitrate: Int?
    /// Nominal or average frame rate reported by the source track.
    public var reportedFrameRate: Double?

    public init(
        resolution: String? = nil,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        bitrate: Int? = nil,
        reportedFrameRate: Double? = nil
    ) {
        self.resolution = resolution
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.bitrate = bitrate
        self.reportedFrameRate = reportedFrameRate
    }
}

public struct PlayerPlaybackCounters: Equatable, Sendable {
    public var decodedFrames: UInt64
    public var droppedFrames: UInt64
    public var lateFrames: UInt64
    public var sourceReadBytes: UInt64
    public var presentedFrames: UInt64

    public nonisolated init(
        decodedFrames: UInt64 = 0,
        droppedFrames: UInt64 = 0,
        lateFrames: UInt64 = 0,
        sourceReadBytes: UInt64 = 0,
        presentedFrames: UInt64 = 0
    ) {
        self.decodedFrames = decodedFrames
        self.droppedFrames = droppedFrames
        self.lateFrames = lateFrames
        self.sourceReadBytes = sourceReadBytes
        self.presentedFrames = presentedFrames
    }
}

public nonisolated enum PlaybackEngine: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case vlc
    case avPlayer

    public var title: String {
        switch self {
        case .vlc: "VLC"
        case .avPlayer: "AVPlayer"
        }
    }
}

public nonisolated enum DeinterlaceMode: Int, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case automatic = -1
    case off = 0
    case on = 1

    public var title: String {
        switch self {
        case .automatic: "Otomatik"
        case .off: "Kapalı"
        case .on: "Açık"
        }
    }
}

public struct PlaybackStartResult: Equatable, Sendable {
    public let engine: PlaybackEngine
    public let deinterlaceMode: DeinterlaceMode?

    public init(engine: PlaybackEngine, deinterlaceMode: DeinterlaceMode?) {
        self.engine = engine
        self.deinterlaceMode = deinterlaceMode
    }
}

public struct PlaybackEngineSwitchRequest: Sendable {
    public let requestID: UUID
    public let target: PlaybackEngine
    public let url: URL
    public let userAgentOverride: String?
    public let networkCachingMilliseconds: Int?
    public let deinterlaceMode: DeinterlaceMode
    public let positionSeconds: Double
    public let isPlaying: Bool
    public let playbackRate: Float
    public let volume: Int32
    public let selectedAudioName: String?
    public let selectedAudioLanguage: String?
    public let selectedSubtitleName: String?
    public let selectedSubtitleLanguage: String?

    public init(
        requestID: UUID,
        target: PlaybackEngine,
        url: URL,
        userAgentOverride: String?,
        networkCachingMilliseconds: Int?,
        deinterlaceMode: DeinterlaceMode,
        positionSeconds: Double,
        isPlaying: Bool,
        playbackRate: Float,
        volume: Int32,
        selectedAudioName: String?,
        selectedAudioLanguage: String?,
        selectedSubtitleName: String?,
        selectedSubtitleLanguage: String?
    ) {
        self.requestID = requestID
        self.target = target
        self.url = url
        self.userAgentOverride = userAgentOverride
        self.networkCachingMilliseconds = networkCachingMilliseconds
        self.deinterlaceMode = deinterlaceMode
        self.positionSeconds = positionSeconds
        self.isPlaying = isPlaying
        self.playbackRate = playbackRate
        self.volume = volume
        self.selectedAudioName = selectedAudioName
        self.selectedAudioLanguage = selectedAudioLanguage
        self.selectedSubtitleName = selectedSubtitleName
        self.selectedSubtitleLanguage = selectedSubtitleLanguage
    }
}

actor ThumbnailGenerationGate {
    static let shared = ThumbnailGenerationGate()

    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Bool, Never>
    }

    private var isOccupied = false
    private var waiters: [Waiter] = []

    func acquire() async throws {
        try Task.checkCancellation()
        guard isOccupied else {
            isOccupied = true
            return
        }

        let waiterID = UUID()
        let acquired = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(returning: false)
                } else {
                    waiters.append(Waiter(id: waiterID, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancel(waiterID) }
        }
        guard acquired else { throw CancellationError() }
    }

    func release() {
        while !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.continuation.resume(returning: true)
            return
        }
        isOccupied = false
    }

    private func cancel(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(returning: false)
    }
}

enum PlayerThumbnailGenerator {
    static func generate(url: URL, userAgentOverride: String?, time: Duration) async throws -> Data {
        try Task.checkCancellation()
        let userAgent = userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let media = try Media(
            url: url,
            httpUserAgent: userAgent?.isEmpty == false ? userAgent : UserAgentManager.shared.resolvedUserAgent,
            httpReferrer: nil
        )
        return try await generate(media: media, time: time)
    }

    static func generate(media: Media, time: Duration) async throws -> Data {
        let gate = ThumbnailGenerationGate.shared
        try await gate.acquire()
        do {
            try Task.checkCancellation()
            let data = try await media.thumbnail(
                at: time,
                width: 360,
                height: 203,
                crop: true,
                seekMode: .precise,
                timeout: .seconds(3),
                instance: PlaybackVLC.instance
            )
            await gate.release()
            return data
        } catch {
            await gate.release()
            throw error
        }
    }
}

public enum CatchupSeekCommand: Sendable {
    case relative(seconds: Int64, maximumDurationSeconds: Double?)
    case position(Double, maximumDurationSeconds: Double?)
    case time(Duration, maximumDurationSeconds: Double?)
}

public struct CatchupSeekResult: Equatable, Sendable {
    public let currentTime: Duration
    public let position: Double
    public let didSucceed: Bool
    public let status: PlaybackSeekStatus?

    public init(
        currentTime: Duration,
        position: Double,
        didSucceed: Bool,
        status: PlaybackSeekStatus? = nil
    ) {
        self.currentTime = currentTime
        self.position = position
        self.didSucceed = didSucceed
        self.status = status
    }
}

public enum PlaybackSeekCommand: Sendable {
    case position(Double)
    case time(Duration)
    case relative(seconds: Int64)
}

public enum PlaybackSeekStatus: Equatable, Sendable {
    case settled
    case inaccurate
    case rejected
    case timedOut
    case superseded
}

public struct PlaybackSeekResult: Equatable, Sendable {
    public let currentTime: Duration?
    public let position: Double?
    public let status: PlaybackSeekStatus

    public init(currentTime: Duration?, position: Double?, status: PlaybackSeekStatus) {
        self.currentTime = currentTime
        self.position = position
        self.status = status
    }
}

@MainActor
func confirmedVLCSeek(player: Player, command: PlaybackSeekCommand) async -> PlaybackSeekResult {
    func snapshot(_ status: PlaybackSeekStatus) -> PlaybackSeekResult {
        let rawPosition = player.position
        let duration = player.duration
        let time = player.currentTime
        let durationSeconds = duration.map {
            Double($0.components.seconds) + Double($0.components.attoseconds) / 1_000_000_000_000_000_000
        }
        let timeSeconds = Double(time.components.seconds) + Double(time.components.attoseconds) / 1_000_000_000_000_000_000
        let measuredPosition: Double? = if rawPosition.isFinite {
            max(0, min(1, rawPosition))
        } else if let durationSeconds, durationSeconds.isFinite, durationSeconds > 0, timeSeconds.isFinite {
            max(0, min(1, timeSeconds / durationSeconds))
        } else {
            nil
        }
        return PlaybackSeekResult(
            currentTime: time,
            position: measuredPosition,
            status: status
        )
    }

    let request: SeekRequest
    do {
        switch command {
        case let .position(position):
            request = try player.requestSeek(to: PlaybackPosition(max(0, min(1, position))), fast: false)
        case let .time(time):
            request = try player.requestSeek(to: max(.zero, time), fast: false)
        case let .relative(seconds):
            request = try player.requestSeek(by: .seconds(Double(seconds)), fast: false)
        }
    } catch {
        return snapshot(.rejected)
    }

    let outcome = request.initialOutcome == .pending ? await request.outcome : request.initialOutcome
    let status: PlaybackSeekStatus = switch outcome {
    case .settled: .settled
    case .inaccurate: .inaccurate
    case .rejected: .rejected
    case .timedOut: .timedOut
    case .superseded: .superseded
    case .pending: .timedOut
    }
    return snapshot(status)
}

public struct PlayerClient: Sendable {
    public var vlcPlayer: @MainActor @Sendable () -> Player
    public var avPlayer: @MainActor @Sendable () -> AVPlayer = { AVPlayer() }
    #if os(tvOS)
        public var preferredDisplayCriteria: @MainActor @Sendable () async -> AVDisplayCriteria? = { nil }
    #endif
    public var activeEngine: @MainActor @Sendable () -> PlaybackEngine = { .vlc }
    public var isPlaying: @MainActor @Sendable () -> Bool = { false }
    public var switchEngine: @MainActor @Sendable (_ request: PlaybackEngineSwitchRequest) async throws -> DeinterlaceMode = { $0.deinterlaceMode }
    public var adoptPreviewPlayer: @MainActor @Sendable (_ player: Player, _ streamURL: URL, _ startsMuted: Bool, _ ownerID: UUID) -> Void = { _, _, _, _ in }
    public var consumePreviewPromotion: @MainActor @Sendable (_ streamURL: URL) -> Bool = { _ in false }
    public var discardPreviewPromotion: @MainActor @Sendable (_ player: Player, _ streamURL: URL, _ ownerID: UUID) -> Void = { _, _, _ in }
    public var discardPreviewPromotionOwned: @MainActor @Sendable (_ ownerID: UUID) -> Void = { _ in }
    public var play: @MainActor @Sendable (
        _ url: URL,
        _ userAgentOverride: String?,
        _ networkCachingMilliseconds: Int?,
        _ deinterlaceMode: DeinterlaceMode,
        _ engine: PlaybackEngine,
        _ audioName: String?,
        _ audioLanguage: String?,
        _ subtitleName: String?,
        _ subtitleLanguage: String?
    ) async throws -> PlaybackStartResult
    public var resume: @MainActor @Sendable (_ rate: Float) async throws -> Void
    public var pause: @MainActor @Sendable () async throws -> Void
    public var stop: @MainActor @Sendable () async throws -> Void
    public var release: @MainActor @Sendable () async -> Void
    public var startRecording: @MainActor @Sendable (_ directory: URL) -> Bool = { _ in false }
    public var requestRecordingStop: @MainActor @Sendable () -> Void = {}
    public var cancelRecordingStopObserver: @MainActor @Sendable () -> Void = {}
    public var setVolume: @MainActor @Sendable (_ volume: Int32) async throws -> Void
    public var setPlaybackRate: @MainActor @Sendable (_ rate: Float) async throws -> Void
    public var setDeinterlaceMode: @MainActor @Sendable (_ mode: DeinterlaceMode) async throws -> Void = { _ in }
    public var jump: @MainActor @Sendable (_ offsetSeconds: Int64) async throws -> Void
    public var catchupSeek: @MainActor @Sendable (_ command: CatchupSeekCommand) async -> CatchupSeekResult = { _ in
        CatchupSeekResult(currentTime: .zero, position: 0, didSucceed: false)
    }

    public var seekAndConfirm: @MainActor @Sendable (_ command: PlaybackSeekCommand) async -> PlaybackSeekResult = { _ in
        PlaybackSeekResult(currentTime: .zero, position: 0, status: .rejected)
    }

    public var seek: @MainActor @Sendable (_ position: Double) async throws -> Void
    public var seekToTime: @MainActor @Sendable (_ time: Duration) async throws -> Void
    public var thumbnail: @Sendable (_ url: URL, _ userAgentOverride: String?, _ time: Duration) async throws -> Data
    public var currentPlaybackThumbnail: @MainActor @Sendable (_ time: Duration) async throws -> Data? = { _ in nil }
    public var getMediaInfo: @MainActor @Sendable () async -> MediaInfo?
    public var getAudioTracks: @MainActor @Sendable () async -> [Track]
    public var getSubtitleTracks: @MainActor @Sendable () async -> [Track]
    public var getSelectedAudioTrack: @MainActor @Sendable () async -> Track?
    public var getSelectedSubtitleTrack: @MainActor @Sendable () async -> Track?
    public var setAudioTrack: @MainActor @Sendable (_ track: Track?) async -> Void
    public var setSubtitleTrack: @MainActor @Sendable (_ track: Track?) async -> Void
    public var addExternalSubtitleTrack: @MainActor @Sendable (_ url: URL) async -> Bool = { _ in false }
    public var setAudioDelay: @MainActor @Sendable (_ delay: Int) async -> Void
    public var setSubtitleDelay: @MainActor @Sendable (_ delay: Int) async -> Void
    public var setSubtitleTextScale: @MainActor @Sendable (_ scale: Float) async -> Void
    public var getStats: @MainActor @Sendable () async -> String?
    public var getPlaybackCounters: @MainActor @Sendable () async -> PlayerPlaybackCounters
    public var setEqualizerPreset: @MainActor @Sendable (_ preset: AudioEQPreset) async -> Void

    public var events: @MainActor @Sendable () async -> AsyncStream<PlayerEvent>
    public var playbackHealthEvents: @MainActor @Sendable () async -> AsyncStream<PlaybackHealthEvent>
    public var playbackHealthSnapshot: @MainActor @Sendable () -> PlaybackHealthSnapshot? = { nil }
}

extension PlayerClient: DependencyKey {
    public nonisolated static let liveValue: PlayerClient = {
        final class Box: @unchecked Sendable {
            @MainActor var player: Player?
            @MainActor var playbackEngine: PlaybackEngine = .vlc
            @MainActor var deinterlaceMode: DeinterlaceMode? = .automatic
            @MainActor var engineSwitchGeneration = UUID()
            @MainActor var alternateSession: AVPlayerPlaybackSession?
            @MainActor var promotedStreamURL: URL?
            @MainActor var promotedPreviewOwnerID: UUID?
            @MainActor var externalSubtitleFiles = Set<URL>()
            @MainActor var recordingStopObserver: Task<Void, Never>?
            @MainActor func removeExternalSubtitleFiles() {
                for url in externalSubtitleFiles {
                    try? FileManager.default.removeItem(at: url)
                }
                externalSubtitleFiles.removeAll()
            }

            @MainActor func getPlayer() -> Player {
                if let p = player {
                    return p
                }
                let p = PlaybackVLC.makePlayer()
                player = p
                return p
            }

            @MainActor func getAlternateSession() -> AVPlayerPlaybackSession {
                if let alternateSession {
                    return alternateSession
                }
                let session = AVPlayerPlaybackSession()
                alternateSession = session
                return session
            }
        }
        let box = Box()

        var client = PlayerClient(
            vlcPlayer: { box.getPlayer() },
            avPlayer: { box.getAlternateSession().player },
            activeEngine: { box.playbackEngine },
            isPlaying: {
                box.playbackEngine == .avPlayer
                    ? box.getAlternateSession().player.rate != 0
                    : box.getPlayer().isPlaying
            },
            switchEngine: { request in
                try Task.checkCancellation()
                guard box.playbackEngine != request.target else { return box.deinterlaceMode ?? request.deinterlaceMode }
                box.engineSwitchGeneration = request.requestID
                let vlc = box.getPlayer()
                let alternate = box.getAlternateSession()
                let previousEngine = box.playbackEngine
                let clampedPosition = max(0, request.positionSeconds.isFinite ? request.positionSeconds : 0)
                let clampedRate = max(0.25, min(4.0, request.playbackRate))
                let clampedVolume = max(0, min(100, request.volume))
                var appliedDeinterlaceMode = request.deinterlaceMode

                switch request.target {
                case .avPlayer:
                    guard request.userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true else {
                        throw PlaybackEngineSwitchError.customUserAgentUnsupported
                    }
                    guard previousEngine == .vlc else { return appliedDeinterlaceMode }
                    let actualPosition = vlc.currentTime.components.seconds > 0
                        ? Double(vlc.currentTime.components.seconds)
                        : clampedPosition
                    try await alternate.prepare(
                        url: request.url,
                        positionSeconds: actualPosition,
                        isPlaying: request.isPlaying,
                        playbackRate: clampedRate,
                        volume: clampedVolume,
                        audioName: request.selectedAudioName,
                        audioLanguage: request.selectedAudioLanguage,
                        subtitleName: request.selectedSubtitleName,
                        subtitleLanguage: request.selectedSubtitleLanguage
                    )
                    guard box.engineSwitchGeneration == request.requestID else { throw CancellationError() }
                    let latestPosition = max(0, Double(vlc.currentTime.components.seconds))
                    vlc.pause()
                    do {
                        try await alternate.seek(to: latestPosition)
                    } catch {
                        if box.engineSwitchGeneration == request.requestID, request.isPlaying {
                            try? vlc.play()
                        }
                        throw error
                    }
                    guard box.engineSwitchGeneration == request.requestID else {
                        throw CancellationError()
                    }
                    alternate.setVolume(clampedVolume)
                    box.playbackEngine = .avPlayer

                case .vlc:
                    guard previousEngine == .avPlayer else { return appliedDeinterlaceMode }
                    let agent = UserAgentManager.shared.resolvedUserAgent
                    let media = try Media(url: request.url, httpUserAgent: agent, httpReferrer: nil)
                    if let caching = request.networkCachingMilliseconds, caching > 0 {
                        media.addOption(":network-caching=\(caching)")
                    }
                    try vlc.setAudioVolume(Volume(0))
                    do {
                        do {
                            try vlc.setDeinterlace(state: request.deinterlaceMode.rawValue, mode: nil)
                        } catch {
                            try vlc.setDeinterlace(state: DeinterlaceMode.automatic.rawValue, mode: nil)
                            appliedDeinterlaceMode = .automatic
                        }
                        box.deinterlaceMode = appliedDeinterlaceMode
                        guard box.engineSwitchGeneration == request.requestID else { throw CancellationError() }
                        try vlc.play(media)
                        for _ in 0 ..< 100 where !vlc.isPlaying {
                            try Task.checkCancellation()
                            guard box.engineSwitchGeneration == request.requestID else { throw CancellationError() }
                            try await Task.sleep(for: .milliseconds(50))
                        }
                        guard box.engineSwitchGeneration == request.requestID else { throw CancellationError() }
                        guard vlc.isPlaying else { throw PlaybackEngineSwitchError.backendNotReady }
                        let avSeconds = alternate.currentTimeSeconds
                        let actualPosition = avSeconds.isFinite ? max(0, avSeconds) : clampedPosition
                        try vlc.seek(to: .seconds(actualPosition), fast: false)
                        try? vlc.setPlaybackRate(PlaybackRate(clampedRate))
                        let audioLanguage = request.selectedAudioLanguage?.lowercased()
                        let selectedAudioName = request.selectedAudioName
                        if let track = vlc.audioTracks.first(where: { candidate in
                            (audioLanguage != nil && candidate.language?.lowercased() == audioLanguage)
                                || selectedAudioName.map { candidate.name.localizedCaseInsensitiveCompare($0) == .orderedSame } == true
                        }) {
                            vlc.selectedAudioTrack = track
                        }
                        let subtitleLanguage = request.selectedSubtitleLanguage?.lowercased()
                        let selectedSubtitleName = request.selectedSubtitleName
                        if let track = vlc.subtitleTracks.first(where: { candidate in
                            (subtitleLanguage != nil && candidate.language?.lowercased() == subtitleLanguage)
                                || selectedSubtitleName.map { candidate.name.localizedCaseInsensitiveCompare($0) == .orderedSame } == true
                        }) {
                            vlc.selectedSubtitleTrack = track
                        }
                        if !request.isPlaying {
                            vlc.pause()
                        }
                        try vlc.setAudioVolume(Volume(Float(clampedVolume) / 100.0))
                    } catch {
                        if box.engineSwitchGeneration == request.requestID, !Task.isCancelled {
                            vlc.stop()
                        }
                        throw error
                    }
                    guard box.engineSwitchGeneration == request.requestID else { throw CancellationError() }
                    alternate.pause()
                    box.playbackEngine = .vlc
                    box.removeExternalSubtitleFiles()
                }
                return appliedDeinterlaceMode
            },
            adoptPreviewPlayer: { player, streamURL, startsMuted, ownerID in
                if let currentPlayer = box.player, currentPlayer !== player {
                    currentPlayer.stop()
                    box.removeExternalSubtitleFiles()
                }
                box.player = player
                box.promotedStreamURL = streamURL
                box.promotedPreviewOwnerID = ownerID
                try? player.setAudioVolume(Volume(startsMuted ? 0.0 : 1.0))
            },
            consumePreviewPromotion: { streamURL in
                guard box.promotedStreamURL == streamURL,
                      let player = box.player,
                      player.isPlaying
                else {
                    box.promotedStreamURL = nil
                    box.promotedPreviewOwnerID = nil
                    return false
                }
                box.promotedStreamURL = nil
                box.promotedPreviewOwnerID = nil
                return true
            },
            discardPreviewPromotion: { player, streamURL, ownerID in
                guard box.player === player,
                      box.promotedStreamURL == streamURL,
                      box.promotedPreviewOwnerID == ownerID
                else { return }
                player.stop()
                box.removeExternalSubtitleFiles()
                box.player = nil
                box.promotedStreamURL = nil
                box.promotedPreviewOwnerID = nil
            },
            discardPreviewPromotionOwned: { ownerID in
                guard box.promotedPreviewOwnerID == ownerID,
                      let player = box.player
                else { return }
                player.stop()
                box.removeExternalSubtitleFiles()
                box.player = nil
                box.promotedStreamURL = nil
                box.promotedPreviewOwnerID = nil
            },
            play: { url, userAgentOverride, networkCachingMilliseconds, deinterlaceMode, engine, audioName, audioLanguage, subtitleName, subtitleLanguage in
                let playGeneration = UUID()
                box.engineSwitchGeneration = playGeneration
                try await PlaybackAudioSession.setActive(true)
                try Task.checkCancellation()
                guard box.engineSwitchGeneration == playGeneration else { throw CancellationError() }
                if box.playbackEngine != engine {
                    box.getPlayer().stop()
                    box.getAlternateSession().stop()
                    box.removeExternalSubtitleFiles()
                    box.playbackEngine = engine
                }
                if box.playbackEngine == .avPlayer {
                    let alternate = box.getAlternateSession()
                    do {
                        try await alternate.prepare(
                            url: url,
                            positionSeconds: 0,
                            isPlaying: true,
                            playbackRate: 1,
                            volume: 100,
                            audioName: audioName,
                            audioLanguage: audioLanguage,
                            subtitleName: subtitleName,
                            subtitleLanguage: subtitleLanguage
                        )
                        guard box.engineSwitchGeneration == playGeneration else { throw CancellationError() }
                        alternate.setVolume(100)
                        return PlaybackStartResult(engine: .avPlayer, deinterlaceMode: nil)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        try Task.checkCancellation()
                        guard box.engineSwitchGeneration == playGeneration else { throw CancellationError() }
                        alternate.stop()
                        let player = box.getPlayer()
                        player.stop()
                        box.playbackEngine = .vlc
                        let appliedDeinterlaceMode: DeinterlaceMode?
                        do {
                            try player.setDeinterlace(state: deinterlaceMode.rawValue, mode: nil)
                            appliedDeinterlaceMode = deinterlaceMode
                        } catch {
                            do {
                                try player.setDeinterlace(state: DeinterlaceMode.automatic.rawValue, mode: nil)
                                appliedDeinterlaceMode = .automatic
                            } catch {
                                appliedDeinterlaceMode = nil
                            }
                        }
                        box.deinterlaceMode = appliedDeinterlaceMode
                        let userAgent = userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let media = try Media(
                            url: url,
                            httpUserAgent: userAgent?.isEmpty == false ? userAgent : UserAgentManager.shared.resolvedUserAgent,
                            httpReferrer: nil
                        )
                        if let networkCachingMilliseconds, networkCachingMilliseconds > 0 {
                            media.addOption(":network-caching=\(networkCachingMilliseconds)")
                        }
                        try player.play(media)
                        return PlaybackStartResult(engine: .vlc, deinterlaceMode: appliedDeinterlaceMode)
                    }
                }
                let player = box.getPlayer()
                let appliedDeinterlaceMode: DeinterlaceMode?
                do {
                    try player.setDeinterlace(state: deinterlaceMode.rawValue, mode: nil)
                    appliedDeinterlaceMode = deinterlaceMode
                } catch {
                    do {
                        try player.setDeinterlace(state: DeinterlaceMode.automatic.rawValue, mode: nil)
                        appliedDeinterlaceMode = .automatic
                    } catch {
                        appliedDeinterlaceMode = nil
                    }
                }
                box.deinterlaceMode = appliedDeinterlaceMode
                if box.promotedStreamURL == url, player.isPlaying {
                    box.promotedStreamURL = nil
                    box.promotedPreviewOwnerID = nil
                    return PlaybackStartResult(engine: .vlc, deinterlaceMode: appliedDeinterlaceMode)
                }
                box.promotedStreamURL = nil
                box.promotedPreviewOwnerID = nil
                let userAgent = userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
                let media = try Media(
                    url: url,
                    httpUserAgent: userAgent?.isEmpty == false ? userAgent : UserAgentManager.shared.resolvedUserAgent,
                    httpReferrer: nil
                )
                if let networkCachingMilliseconds, networkCachingMilliseconds > 0 {
                    media.addOption(":network-caching=\(networkCachingMilliseconds)")
                }
                try player.play(media)
                box.removeExternalSubtitleFiles()
                return PlaybackStartResult(engine: .vlc, deinterlaceMode: appliedDeinterlaceMode)
            },
            resume: { rate in
                try await PlaybackAudioSession.setActive(true)
                try Task.checkCancellation()
                if box.playbackEngine == .avPlayer {
                    box.getAlternateSession().play(rate: rate)
                } else {
                    let player = box.getPlayer()
                    try player.play()
                    try player.setPlaybackRate(PlaybackRate(max(0.25, min(4, rate))))
                }
            },
            pause: {
                if box.playbackEngine == .avPlayer {
                    box.getAlternateSession().pause()
                } else {
                    box.getPlayer().pause()
                }
            },
            stop: {
                box.engineSwitchGeneration = UUID()
                box.getAlternateSession().stop()
                box.playbackEngine = .vlc
                box.getPlayer().stop()
                box.removeExternalSubtitleFiles()
                box.promotedStreamURL = nil
                box.promotedPreviewOwnerID = nil
            },
            release: {
                box.engineSwitchGeneration = UUID()
                box.getAlternateSession().stop()
                box.playbackEngine = .vlc
                box.player?.stop()
                box.removeExternalSubtitleFiles()
                box.player = nil
                box.promotedStreamURL = nil
                box.promotedPreviewOwnerID = nil
            },
            startRecording: { directory in
                let player = box.getPlayer()
                guard player.isPlaying else { return false }
                player.startRecording(to: directory.path)
                return true
            },
            requestRecordingStop: {
                let player = box.getPlayer()
                if box.recordingStopObserver == nil {
                    let events = player.events
                    box.recordingStopObserver = Task { @MainActor in
                        let timeout = Task { @MainActor in
                            try? await Task.sleep(for: .seconds(30))
                            box.recordingStopObserver?.cancel()
                        }
                        defer {
                            timeout.cancel()
                            box.recordingStopObserver = nil
                        }
                        for await event in events {
                            guard !Task.isCancelled else { return }
                            if case let .recordingChanged(isRecording: false, filePath: path) = event {
                                _ = LocalDVRManager.shared.finishRecording(filePath: path)
                                return
                            }
                        }
                    }
                }
                player.stopRecording()
            },
            cancelRecordingStopObserver: {
                box.recordingStopObserver?.cancel()
            },
            setVolume: { volume in
                if box.playbackEngine == .avPlayer {
                    box.getAlternateSession().setVolume(volume)
                } else {
                    try box.getPlayer().setAudioVolume(Volume(Float(volume) / 100.0))
                }
            },
            setPlaybackRate: { rate in
                if box.playbackEngine == .avPlayer {
                    box.getAlternateSession().setRate(rate)
                } else {
                    try box.getPlayer().setPlaybackRate(PlaybackRate(rate))
                }
            },
            setDeinterlaceMode: { mode in
                guard box.playbackEngine == .vlc else { return }
                try box.getPlayer().setDeinterlace(state: mode.rawValue, mode: nil)
                box.deinterlaceMode = mode
            },
            jump: { offset in
                if box.playbackEngine == .avPlayer {
                    try await box.getAlternateSession().seek(to: max(0, box.getAlternateSession().currentTimeSeconds + Double(offset)))
                    return
                }
                let player = box.getPlayer()
                let offsetDuration = Duration.seconds(offset)

                // Strategy 1: Attempt strict relative seek (uses VLC set_time under the hood)
                if (try? player.seek(by: offsetDuration, fast: true)) != nil {
                    return
                }

                // Strategy 2: Calculate target absolute time from current time
                let targetDuration = max(.zero, player.currentTime + offsetDuration)
                if (try? player.seek(to: targetDuration, fast: true)) != nil {
                    return
                }

                if let duration = player.duration {
                    let totalSecs = Double(duration.components.seconds)
                    if totalSecs > 0 {
                        let targetSecs = Double(targetDuration.components.seconds)
                        let targetPos = targetSecs / totalSecs
                        _ = player.seek(toPosition: PlaybackPosition(targetPos), fast: true)
                        return
                    }
                }

                // Strategy 3: Fallback to native jump_time
                _ = player.jump(by: offsetDuration)
            },
            catchupSeek: { command in
                func effectiveDuration(reportedSeconds: Double?, maximumSeconds: Double?) -> Double? {
                    let reported = reportedSeconds.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
                    let maximum = maximumSeconds.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
                    if let reported, let maximum {
                        return min(reported, maximum)
                    }
                    return reported ?? maximum
                }

                func seconds(_ duration: Duration) -> Double {
                    let components = duration.components
                    return Double(components.seconds)
                        + Double(components.attoseconds) / 1_000_000_000_000_000_000
                }

                func maximumDurationSeconds(for command: CatchupSeekCommand) -> Double? {
                    switch command {
                    case let .relative(_, maximumSeconds), let .position(_, maximumSeconds), let .time(_, maximumSeconds):
                        maximumSeconds
                    }
                }

                if box.playbackEngine == .avPlayer {
                    let session = box.getAlternateSession()
                    let duration = effectiveDuration(
                        reportedSeconds: session.player.currentItem?.duration.seconds ?? 0,
                        maximumSeconds: maximumDurationSeconds(for: command)
                    )
                    let rawCurrentTime = session.currentTimeSeconds
                    let currentTime = rawCurrentTime.isFinite ? max(0, rawCurrentTime) : 0

                    let rawTarget: Double
                    switch command {
                    case let .relative(seconds, _):
                        rawTarget = currentTime + Double(seconds)
                    case let .position(position, _):
                        guard let duration else {
                            return CatchupSeekResult(
                                currentTime: .seconds(currentTime),
                                position: 0,
                                didSucceed: false,
                                status: .rejected
                            )
                        }
                        rawTarget = max(0, min(1, position)) * duration
                    case let .time(time, _):
                        rawTarget = seconds(time)
                    }
                    let target = max(0, duration.map { min($0, rawTarget) } ?? rawTarget)

                    do {
                        try await session.seek(to: target)
                        let rawLandedTime = session.currentTimeSeconds
                        let landedTime = rawLandedTime.isFinite
                            ? max(0, duration.map { min($0, rawLandedTime) } ?? rawLandedTime)
                            : currentTime
                        return CatchupSeekResult(
                            currentTime: .seconds(max(0, landedTime)),
                            position: duration.map { max(0, min(1, landedTime / $0)) } ?? 0,
                            didSucceed: true,
                            status: .settled
                        )
                    } catch {
                        let rawLandedTime = session.currentTimeSeconds
                        let landedTime = rawLandedTime.isFinite
                            ? max(0, duration.map { min($0, rawLandedTime) } ?? rawLandedTime)
                            : currentTime
                        let status: PlaybackSeekStatus = if let switchError = error as? PlaybackEngineSwitchError,
                                                            case .seekTimedOut = switchError
                        {
                            .timedOut
                        } else {
                            .rejected
                        }
                        return CatchupSeekResult(
                            currentTime: .seconds(max(0, landedTime)),
                            position: duration.map { max(0, min(1, landedTime / $0)) } ?? 0,
                            didSucceed: false,
                            status: status
                        )
                    }
                }

                let player = box.getPlayer()
                @MainActor func snapshot(status: PlaybackSeekStatus) -> CatchupSeekResult {
                    let currentTime = seconds(player.currentTime)
                    let duration: Double? = switch command {
                    case .relative, .position, .time:
                        effectiveDuration(
                            reportedSeconds: player.duration.map(seconds),
                            maximumSeconds: maximumDurationSeconds(for: command)
                        )
                    }
                    let boundedTime = currentTime.isFinite
                        ? max(0, duration.map { min($0, currentTime) } ?? currentTime)
                        : 0
                    let rawPosition = duration.map { boundedTime / $0 } ?? player.position
                    return CatchupSeekResult(
                        currentTime: .seconds(boundedTime),
                        position: rawPosition.isFinite ? max(0, min(1, rawPosition)) : 0,
                        didSucceed: status == .settled || status == .inaccurate,
                        status: status
                    )
                }

                let maximumSeconds = maximumDurationSeconds(for: command)
                let duration = effectiveDuration(
                    reportedSeconds: player.duration.map(seconds),
                    maximumSeconds: maximumSeconds
                )
                let request: SeekRequest
                switch command {
                case let .relative(offsetSeconds, _):
                    let currentSeconds = seconds(player.currentTime)
                    if currentSeconds.isFinite, let duration {
                        let targetSeconds = max(0, min(duration, currentSeconds + Double(offsetSeconds)))
                        do {
                            request = try player.requestSeek(to: .seconds(targetSeconds), fast: false)
                        } catch {
                            return snapshot(status: .rejected)
                        }
                    } else {
                        request = player.requestJump(by: .seconds(Double(offsetSeconds)))
                    }
                case let .position(position, _):
                    let boundedPosition = max(0, min(1, position))
                    if let duration {
                        do {
                            request = try player.requestSeek(to: .seconds(boundedPosition * duration), fast: false)
                        } catch {
                            return snapshot(status: .rejected)
                        }
                    } else {
                        request = player.requestSeek(toPosition: PlaybackPosition(boundedPosition), fast: false)
                    }
                case let .time(time, _):
                    let targetSeconds = max(0, duration.map { min($0, seconds(time)) } ?? seconds(time))
                    do {
                        request = try player.requestSeek(to: .seconds(targetSeconds), fast: false)
                    } catch {
                        return snapshot(status: .rejected)
                    }
                }

                let initialOutcome = request.initialOutcome
                guard initialOutcome == .pending else {
                    let status: PlaybackSeekStatus = switch initialOutcome {
                    case .settled: .settled
                    case .inaccurate: .inaccurate
                    case .timedOut: .timedOut
                    case .superseded: .superseded
                    case .rejected, .pending: .rejected
                    }
                    return snapshot(status: status)
                }

                let outcome = await request.outcome
                let status: PlaybackSeekStatus = switch outcome {
                case .settled: .settled
                case .inaccurate: .inaccurate
                case .timedOut: .timedOut
                case .superseded: .superseded
                case .rejected, .pending: .rejected
                }
                return snapshot(status: status)
            },
            seekAndConfirm: { command in
                if box.playbackEngine == .avPlayer {
                    let session = box.getAlternateSession()
                    let rawCurrentTime = session.player.currentTime().seconds
                    let currentTime = rawCurrentTime.isFinite ? max(0, rawCurrentTime) : nil
                    let rawDuration = session.player.currentItem?.duration.seconds ?? 0
                    let duration = rawDuration.isFinite && rawDuration > 0 ? rawDuration : nil
                    let target: Double
                    switch command {
                    case let .position(position):
                        guard let duration else {
                            return PlaybackSeekResult(
                                currentTime: currentTime.map { .seconds($0) },
                                position: nil,
                                status: .rejected
                            )
                        }
                        target = max(0, min(1, position)) * duration
                    case let .time(time):
                        let components = time.components
                        target = Double(components.seconds)
                            + Double(components.attoseconds) / 1_000_000_000_000_000_000
                    case let .relative(seconds):
                        guard let currentTime else {
                            return PlaybackSeekResult(currentTime: nil, position: nil, status: .rejected)
                        }
                        target = currentTime + Double(seconds)
                    }
                    guard target.isFinite else {
                        return PlaybackSeekResult(
                            currentTime: currentTime.map { .seconds($0) },
                            position: nil,
                            status: .rejected
                        )
                    }
                    let clampedTarget = max(0, duration.map { min($0, target) } ?? target)
                    do {
                        try await session.seek(to: clampedTarget)
                        let rawLandedTime = session.player.currentTime().seconds
                        let landedTime = rawLandedTime.isFinite ? max(0, rawLandedTime) : nil
                        return PlaybackSeekResult(
                            currentTime: landedTime.map { .seconds($0) },
                            position: duration.flatMap { duration in
                                landedTime.map { max(0, min(1, $0 / duration)) }
                            },
                            status: .settled
                        )
                    } catch {
                        let rawLandedTime = session.player.currentTime().seconds
                        let landedTime = rawLandedTime.isFinite ? max(0, rawLandedTime) : nil
                        let seekStatus: PlaybackSeekStatus = if let switchError = error as? PlaybackEngineSwitchError,
                                                                case .seekTimedOut = switchError
                        {
                            // Keep timeouts distinct: the reducer must perform a
                            // confirmed rollback because AVPlayer may have moved
                            // before its seek callback timed out.
                            .timedOut
                        } else {
                            .rejected
                        }
                        return PlaybackSeekResult(
                            currentTime: landedTime.map { .seconds($0) },
                            position: duration.flatMap { duration in
                                landedTime.map { max(0, min(1, $0 / duration)) }
                            },
                            status: seekStatus
                        )
                    }
                }
                return await confirmedVLCSeek(player: box.getPlayer(), command: command)
            },
            seek: { position in
                if box.playbackEngine == .avPlayer {
                    let item = box.getAlternateSession().player.currentItem
                    let duration = item?.duration.seconds ?? 0
                    guard duration.isFinite, duration > 0 else { return }
                    try await box.getAlternateSession().seek(to: max(0, min(1, position)) * duration)
                    return
                }
                let player = box.getPlayer()
                let clamped = max(0.0, min(1.0, position))
                if clamped == 0.0 {
                    _ = try? player.seek(to: Duration.zero, fast: false)
                    _ = player.seek(toPosition: PlaybackPosition(0.0), fast: false)
                    return
                }
                if let duration = player.duration {
                    let totalSecs = Double(duration.components.seconds)
                    if totalSecs > 0 {
                        let targetDuration = Duration.seconds(clamped * totalSecs)
                        if (try? player.seek(to: targetDuration, fast: false)) != nil {
                            return
                        }
                    }
                }
                _ = player.seek(toPosition: PlaybackPosition(clamped), fast: false)
            },
            seekToTime: { time in
                if box.playbackEngine == .avPlayer {
                    try await box.getAlternateSession().seek(to: Double(time.components.seconds))
                    return
                }
                let player = box.getPlayer()
                if (try? player.seek(to: time, fast: false)) != nil {
                    return
                }
                if let duration = player.duration {
                    let totalSecs = Double(duration.components.seconds)
                    if totalSecs > 0 {
                        let targetPos = Double(time.components.seconds) / totalSecs
                        _ = player.seek(toPosition: PlaybackPosition(targetPos), fast: false)
                    }
                }
            },
            thumbnail: { url, userAgentOverride, time in
                try await PlayerThumbnailGenerator.generate(
                    url: url,
                    userAgentOverride: userAgentOverride,
                    time: time
                )
            },
            currentPlaybackThumbnail: { time in
                guard box.playbackEngine == .vlc,
                      let media = box.player?.currentMedia
                else { return nil }
                return try await PlayerThumbnailGenerator.generate(media: media, time: time)
            },
            getMediaInfo: {
                if box.playbackEngine == .avPlayer {
                    return nil
                }
                var info = MediaInfo()
                let player = box.getPlayer()

                if let video = player.videoTracks.first {
                    info.videoCodec = video.codecString
                    info.reportedFrameRate = video.frameRate
                    if let w = video.width, let h = video.height, w > 0, h > 0 {
                        info.resolution = "\(w)x\(h)"
                    }
                    info.bitrate = video.bitrate > 0 ? video.bitrate : nil
                }

                if let audio = player.audioTracks.first {
                    info.audioCodec = audio.codecString
                    if info.bitrate == nil, audio.bitrate > 0 {
                        info.bitrate = audio.bitrate
                    }
                }

                return info.videoCodec != nil || info.audioCodec != nil || info.reportedFrameRate != nil ? info : nil
            },
            getAudioTracks: {
                if box.playbackEngine == .avPlayer {
                    return []
                }
                return box.getPlayer().audioTracks
            },
            getSubtitleTracks: {
                if box.playbackEngine == .avPlayer {
                    return []
                }
                return box.getPlayer().subtitleTracks
            },
            getSelectedAudioTrack: {
                if box.playbackEngine == .avPlayer {
                    return nil
                }
                return box.getPlayer().selectedAudioTrack
            },
            getSelectedSubtitleTrack: {
                if box.playbackEngine == .avPlayer {
                    return nil
                }
                return box.getPlayer().selectedSubtitleTrack
            },
            setAudioTrack: { track in
                PlayerLogger.shared.info(category: "Audio", message: "Client setting audio track: \(track?.name ?? "nil") [ID: \(track?.id ?? "nil")]")
                guard box.playbackEngine == .vlc else { return }
                box.getPlayer().selectedAudioTrack = track
            },
            setSubtitleTrack: { track in
                PlayerLogger.shared.info(category: "Subtitle", message: "Client setting subtitle track: \(track?.name ?? "Off") [ID: \(track?.id ?? "nil")]")
                guard box.playbackEngine == .vlc else { return }
                box.getPlayer().selectedSubtitleTrack = track
            },
            addExternalSubtitleTrack: { url in
                guard box.playbackEngine == .vlc else {
                    if ExternalSubtitleTextEncoding.isOwnedTemporaryFile(url) {
                        try? FileManager.default.removeItem(at: url)
                    }
                    return false
                }
                do {
                    try box.getPlayer().addExternalTrack(from: url, type: .subtitle, select: true)
                    if ExternalSubtitleTextEncoding.isOwnedTemporaryFile(url) {
                        box.externalSubtitleFiles.insert(url)
                    }
                    return true
                } catch {
                    if ExternalSubtitleTextEncoding.isOwnedTemporaryFile(url) {
                        try? FileManager.default.removeItem(at: url)
                    }
                    return false
                }
            },
            setAudioDelay: { delay in
                guard box.playbackEngine == .vlc else { return }
                try? box.getPlayer().setAudioDelay(.milliseconds(delay))
            },
            setSubtitleDelay: { delay in
                guard box.playbackEngine == .vlc else { return }
                try? box.getPlayer().setSubtitleDelay(.milliseconds(delay))
            },
            setSubtitleTextScale: { scale in
                guard box.playbackEngine == .vlc, let player = box.player else { return }
                player.setSubtitleScale(SubtitleScale(scale))
            },
            getStats: {
                guard box.playbackEngine == .vlc else { return nil }
                let health = box.getPlayer().playbackHealth
                let c = health.counters
                let mbRead = String(format: "%.1f", Double(c.sourceReadBytes) / (1024.0 * 1024.0))
                return "Decoded: \(c.decodedVideoFrames)f | Dropped: \(c.droppedVideoFrames)f | Data: \(mbRead)MB"
            },
            getPlaybackCounters: {
                guard box.playbackEngine == .vlc else { return PlayerPlaybackCounters() }
                let health = box.getPlayer().playbackHealth
                let c = health.counters
                return PlayerPlaybackCounters(
                    decodedFrames: c.decodedVideoFrames,
                    droppedFrames: c.droppedVideoFrames,
                    lateFrames: c.lateVideoFrames,
                    sourceReadBytes: c.sourceReadBytes,
                    presentedFrames: c.presentedVideoFrames
                )
            },
            setEqualizerPreset: { preset in
                guard box.playbackEngine == .vlc else { return }
                let player = box.getPlayer()
                if preset == .flat {
                    player.equalizer = nil
                } else {
                    let eq = player.equalizer ?? Equalizer()
                    _ = try? eq.setBands(preset.bandGains)
                    eq.preampGain = EqualizerGain(preset.preamp)
                    player.equalizer = eq
                }
            },
            events: {
                // Playback can switch engines after the feature starts listening
                // (events are subscribed before `play` to catch startup state).
                // Subscribe to both sources and forward only the active engine's
                // events so an AVPlayer start is never stranded on the VLC stream.
                let playerEvents = box.getPlayer().events
                let alternateEvents = box.getAlternateSession().events()
                return AsyncStream { continuation in
                    let vlcTask = Task { @MainActor in
                        var lastEmittedTimeSecond: Int64 = -1
                        var lastEmittedPosition: Double = -1.0
                        var lastEmittedPositionDate = Date.distantPast

                        for await event in playerEvents {
                            guard !Task.isCancelled else { return }
                            guard box.playbackEngine == .vlc else { continue }
                            switch event {
                            case .bufferingProgress:
                                continue

                            case let .timeChanged(time):
                                let sec = time.components.seconds
                                if sec == lastEmittedTimeSecond {
                                    continue
                                }
                                lastEmittedTimeSecond = sec
                                continuation.yield(event)

                            case let .positionChanged(pos):
                                let now = Date()
                                // Yield if position moved by at least 0.5% or at least 1 second passed
                                if abs(pos - lastEmittedPosition) < 0.005, now.timeIntervalSince(lastEmittedPositionDate) < 1.0 {
                                    continue
                                }
                                lastEmittedPosition = pos
                                lastEmittedPositionDate = now
                                continuation.yield(event)

                            default:
                                continuation.yield(event)
                            }
                        }
                    }
                    let alternateTask = Task { @MainActor in
                        for await event in alternateEvents {
                            guard !Task.isCancelled else { return }
                            guard box.playbackEngine == .avPlayer else { continue }
                            continuation.yield(event)
                        }
                    }
                    continuation.onTermination = { _ in
                        vlcTask.cancel()
                        alternateTask.cancel()
                    }
                }
            },
            playbackHealthEvents: {
                guard box.playbackEngine == .vlc else { return AsyncStream { $0.finish() } }
                return box.getPlayer().playbackHealthEvents
            },
            playbackHealthSnapshot: {
                guard box.playbackEngine == .vlc else { return nil }
                return box.getPlayer().playbackHealth
            }
        )
        #if os(tvOS)
            client.preferredDisplayCriteria = { await box.getAlternateSession().preferredDisplayCriteria() }
        #endif
        return client
    }()

    public nonisolated static let testValue = PlayerClient(
        vlcPlayer: { fatalError() },
        play: { _, _, _, mode, engine, _, _, _, _ in
            PlaybackStartResult(engine: engine, deinterlaceMode: mode)
        },
        resume: { _ in },
        pause: {},
        stop: {},
        release: {},
        startRecording: { _ in false },
        requestRecordingStop: {},
        cancelRecordingStopObserver: {},
        setVolume: { _ in },
        setPlaybackRate: { _ in },
        jump: { _ in },
        seekAndConfirm: { _ in PlaybackSeekResult(currentTime: .zero, position: 0, status: .rejected) },
        seek: { _ in },
        seekToTime: { _ in },
        thumbnail: { _, _, _ in Data() },
        currentPlaybackThumbnail: { _ in nil },
        getMediaInfo: { nil },
        getAudioTracks: { [] },
        getSubtitleTracks: { [] },
        getSelectedAudioTrack: { nil },
        getSelectedSubtitleTrack: { nil },
        setAudioTrack: { _ in },
        setSubtitleTrack: { _ in },
        setAudioDelay: { _ in },
        setSubtitleDelay: { _ in },
        setSubtitleTextScale: { _ in },
        getStats: { nil },
        getPlaybackCounters: { PlayerPlaybackCounters() },
        setEqualizerPreset: { _ in },
        events: { AsyncStream { $0.finish() } },
        playbackHealthEvents: { AsyncStream { $0.finish() } },
        playbackHealthSnapshot: { nil }
    )
}

public extension DependencyValues {
    var playerClient: PlayerClient {
        get { self[PlayerClient.self] }
        set { self[PlayerClient.self] = newValue }
    }
}
