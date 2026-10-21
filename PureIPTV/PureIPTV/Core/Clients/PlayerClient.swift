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

    public nonisolated init(
        decodedFrames: UInt64 = 0,
        droppedFrames: UInt64 = 0,
        lateFrames: UInt64 = 0,
        sourceReadBytes: UInt64 = 0
    ) {
        self.decodedFrames = decodedFrames
        self.droppedFrames = droppedFrames
        self.lateFrames = lateFrames
        self.sourceReadBytes = sourceReadBytes
    }
}

public struct PlayerClient: Sendable {
    public var vlcPlayer: @MainActor @Sendable () -> Player
    public var play: @MainActor @Sendable (_ url: URL) async throws -> Void
    public var resume: @MainActor @Sendable () async throws -> Void
    public var pause: @MainActor @Sendable () async throws -> Void
    public var stop: @MainActor @Sendable () async throws -> Void
    public var release: @MainActor @Sendable () async -> Void
    public var setVolume: @MainActor @Sendable (_ volume: Int32) async throws -> Void
    public var setPlaybackRate: @MainActor @Sendable (_ rate: Float) async throws -> Void
    public var jump: @MainActor @Sendable (_ offsetSeconds: Int64) async throws -> Void
    public var seek: @MainActor @Sendable (_ position: Double) async throws -> Void
    public var seekToTime: @MainActor @Sendable (_ time: Duration) async throws -> Void
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

    public var events: @MainActor @Sendable () async -> AsyncStream<PlayerEvent>
}

extension PlayerClient: DependencyKey {
    public nonisolated static let liveValue: PlayerClient = {
        final class Box: @unchecked Sendable {
            @MainActor var player: Player?
            @MainActor func getPlayer() -> Player {
                if let p = player {
                    return p
                }
                let p = Player()
                player = p
                return p
            }
        }
        let box = Box()

        // Configure AVAudioSession for AirPlay and Media Playback
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormAudio)
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }

        return PlayerClient(
            vlcPlayer: { box.getPlayer() },
            play: { url in
                let player = box.getPlayer()
                try player.play(url: url)
            },
            resume: {
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
                    sourceReadBytes: c.sourceReadBytes
                )
            },
            events: {
                let player = box.getPlayer()
                return AsyncStream { continuation in
                    let task = Task {
                        for await event in player.events {
                            // Filter out high-frequency unused events that flood TCA
                            if case .bufferingProgress = event {
                                continue
                            }
                            continuation.yield(event)
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
        play: { _ in },
        resume: {},
        pause: {},
        stop: {},
        release: {},
        setVolume: { _ in },
        setPlaybackRate: { _ in },
        jump: { _ in },
        seek: { _ in },
        seekToTime: { _ in },
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
        events: { AsyncStream { $0.finish() } }
    )
}

public extension DependencyValues {
    var playerClient: PlayerClient {
        get { self[PlayerClient.self] }
        set { self[PlayerClient.self] = newValue }
    }
}
