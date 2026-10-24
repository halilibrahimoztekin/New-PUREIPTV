import AVFoundation
import ComposableArchitecture
import Foundation
import SwiftVLC

public struct MediaInfo: Equatable, Sendable {
    public var resolution: String?
    public var videoCodec: String?
    public var audioCodec: String?
    public var bitrate: Int?

    public init(resolution: String? = nil, videoCodec: String? = nil, audioCodec: String? = nil, bitrate: Int? = nil) {
        self.resolution = resolution
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.bitrate = bitrate
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
        let gate = ThumbnailGenerationGate.shared
        try await gate.acquire()
        do {
            try Task.checkCancellation()
            let userAgent = userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
            let media = try Media(
                url: url,
                httpUserAgent: userAgent?.isEmpty == false ? userAgent : UserAgentManager.shared.resolvedUserAgent,
                httpReferrer: nil
            )
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

public struct PlayerClient: Sendable {
    public var vlcPlayer: @MainActor @Sendable () -> Player
    public var adoptPreviewPlayer: @MainActor @Sendable (_ player: Player, _ streamURL: URL, _ startsMuted: Bool) -> Void = { _, _, _ in }
    public var consumePreviewPromotion: @MainActor @Sendable (_ streamURL: URL) -> Bool = { _ in false }
    public var play: @MainActor @Sendable (_ url: URL, _ userAgentOverride: String?, _ networkCachingMilliseconds: Int?) async throws -> Void
    public var resume: @MainActor @Sendable () async throws -> Void
    public var pause: @MainActor @Sendable () async throws -> Void
    public var stop: @MainActor @Sendable () async throws -> Void
    public var release: @MainActor @Sendable () async -> Void
    public var setVolume: @MainActor @Sendable (_ volume: Int32) async throws -> Void
    public var setPlaybackRate: @MainActor @Sendable (_ rate: Float) async throws -> Void
    public var jump: @MainActor @Sendable (_ offsetSeconds: Int64) async throws -> Void
    public var seek: @MainActor @Sendable (_ position: Double) async throws -> Void
    public var seekToTime: @MainActor @Sendable (_ time: Duration) async throws -> Void
    public var thumbnail: @Sendable (_ url: URL, _ userAgentOverride: String?, _ time: Duration) async throws -> Data
    public var getMediaInfo: @MainActor @Sendable () async -> MediaInfo?
    public var getAudioTracks: @MainActor @Sendable () async -> [Track]
    public var getSubtitleTracks: @MainActor @Sendable () async -> [Track]
    public var getSelectedAudioTrack: @MainActor @Sendable () async -> Track?
    public var getSelectedSubtitleTrack: @MainActor @Sendable () async -> Track?
    public var setAudioTrack: @MainActor @Sendable (_ track: Track?) async -> Void
    public var setSubtitleTrack: @MainActor @Sendable (_ track: Track?) async -> Void
    public var setAudioDelay: @MainActor @Sendable (_ delay: Int) async -> Void
    public var setSubtitleDelay: @MainActor @Sendable (_ delay: Int) async -> Void
    public var getStats: @MainActor @Sendable () async -> String?
    public var getPlaybackCounters: @MainActor @Sendable () async -> PlayerPlaybackCounters
    public var setEqualizerPreset: @MainActor @Sendable (_ preset: AudioEQPreset) async -> Void

    public var events: @MainActor @Sendable () async -> AsyncStream<PlayerEvent>
}

extension PlayerClient: DependencyKey {
    public nonisolated static let liveValue: PlayerClient = {
        final class Box: @unchecked Sendable {
            @MainActor var player: Player?
            @MainActor var promotedStreamURL: URL?
            @MainActor func getPlayer() -> Player {
                if let p = player {
                    return p
                }
                let p = PlaybackVLC.makePlayer()
                player = p
                return p
            }
        }
        let box = Box()

        return PlayerClient(
            vlcPlayer: { box.getPlayer() },
            adoptPreviewPlayer: { player, streamURL, startsMuted in
                if let currentPlayer = box.player, currentPlayer !== player {
                    currentPlayer.stop()
                }
                box.player = player
                box.promotedStreamURL = streamURL
                try? player.setAudioVolume(Volume(startsMuted ? 0.0 : 1.0))
            },
            consumePreviewPromotion: { streamURL in
                guard box.promotedStreamURL == streamURL,
                      let player = box.player,
                      player.isPlaying
                else { return false }
                box.promotedStreamURL = nil
                return true
            },
            play: { url, userAgentOverride, networkCachingMilliseconds in
                try await PlaybackAudioSession.setActive(true)
                try Task.checkCancellation()
                let player = box.getPlayer()
                if box.promotedStreamURL == url, player.isPlaying {
                    box.promotedStreamURL = nil
                    return
                }
                box.promotedStreamURL = nil
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
            },
            resume: {
                try await PlaybackAudioSession.setActive(true)
                try Task.checkCancellation()
                try box.getPlayer().play()
            },
            pause: {
                box.getPlayer().pause()
            },
            stop: {
                box.getPlayer().stop()
            },
            release: {
                box.player?.stop()
                box.player = nil
                box.promotedStreamURL = nil
            },
            setVolume: { volume in
                try box.getPlayer().setAudioVolume(Volume(Float(volume) / 100.0))
            },
            setPlaybackRate: { rate in
                try box.getPlayer().setPlaybackRate(PlaybackRate(rate))
            },
            jump: { offset in
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
            seek: { position in
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
            getMediaInfo: {
                var info = MediaInfo()
                let player = box.getPlayer()

                if let video = player.videoTracks.first {
                    info.videoCodec = video.codecString
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

                return info.videoCodec != nil || info.audioCodec != nil ? info : nil
            },
            getAudioTracks: {
                box.getPlayer().audioTracks
            },
            getSubtitleTracks: {
                box.getPlayer().subtitleTracks
            },
            getSelectedAudioTrack: {
                box.getPlayer().selectedAudioTrack
            },
            getSelectedSubtitleTrack: {
                box.getPlayer().selectedSubtitleTrack
            },
            setAudioTrack: { track in
                box.getPlayer().selectedAudioTrack = track
            },
            setSubtitleTrack: { track in
                box.getPlayer().selectedSubtitleTrack = track
            },
            setAudioDelay: { delay in
                try? box.getPlayer().setAudioDelay(.milliseconds(delay))
            },
            setSubtitleDelay: { delay in
                try? box.getPlayer().setSubtitleDelay(.milliseconds(delay))
            },
            getStats: {
                let health = box.getPlayer().playbackHealth
                let c = health.counters
                let mbRead = String(format: "%.1f", Double(c.sourceReadBytes) / (1024.0 * 1024.0))
                return "Decoded: \(c.decodedVideoFrames)f | Dropped: \(c.droppedVideoFrames)f | Data: \(mbRead)MB"
            },
            getPlaybackCounters: {
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
                let player = box.getPlayer()
                return AsyncStream { continuation in
                    let task = Task {
                        var lastEmittedTimeSecond: Int64 = -1
                        var lastEmittedPosition: Double = -1.0
                        var lastEmittedPositionDate = Date.distantPast

                        for await event in player.events {
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
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            }
        )
    }()

    public nonisolated static let testValue = PlayerClient(
        vlcPlayer: { fatalError() },
        play: { _, _, _ in },
        resume: {},
        pause: {},
        stop: {},
        release: {},
        setVolume: { _ in },
        setPlaybackRate: { _ in },
        jump: { _ in },
        seek: { _ in },
        seekToTime: { _ in },
        thumbnail: { _, _, _ in Data() },
        getMediaInfo: { nil },
        getAudioTracks: { [] },
        getSubtitleTracks: { [] },
        getSelectedAudioTrack: { nil },
        getSelectedSubtitleTrack: { nil },
        setAudioTrack: { _ in },
        setSubtitleTrack: { _ in },
        setAudioDelay: { _ in },
        setSubtitleDelay: { _ in },
        getStats: { nil },
        getPlaybackCounters: { PlayerPlaybackCounters() },
        setEqualizerPreset: { _ in },
        events: { AsyncStream { $0.finish() } }
    )
}

public extension DependencyValues {
    var playerClient: PlayerClient {
        get { self[PlayerClient.self] }
        set { self[PlayerClient.self] = newValue }
    }
}
