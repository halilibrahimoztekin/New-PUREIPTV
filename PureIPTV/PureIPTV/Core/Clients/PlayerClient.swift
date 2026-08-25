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

@DependencyClient
public struct PlayerClient: Sendable {
    public var vlcPlayer: @MainActor @Sendable () -> Player = { fatalError("Unimplemented") }
    public var play: @MainActor @Sendable (_ url: URL) async throws -> Void
    public var resume: @MainActor @Sendable () async throws -> Void
    public var pause: @MainActor @Sendable () async throws -> Void
    public var stop: @MainActor @Sendable () async throws -> Void
    public var setVolume: @MainActor @Sendable (_ volume: Int32) async throws -> Void
    public var jump: @MainActor @Sendable (_ offsetSeconds: Int64) async throws -> Void
    public var seek: @MainActor @Sendable (_ position: Double) async throws -> Void
    public var getMediaInfo: @MainActor @Sendable () async -> MediaInfo?
    public var getAudioTracks: @MainActor @Sendable () async -> [Track] = { [] }
    public var getSubtitleTracks: @MainActor @Sendable () async -> [Track] = { [] }
    public var setAudioTrack: @MainActor @Sendable (_ track: Track?) async -> Void = { _ in }
    public var setSubtitleTrack: @MainActor @Sendable (_ track: Track?) async -> Void = { _ in }
    public var events: @MainActor @Sendable () async -> AsyncStream<PlayerEvent> = { AsyncStream { $0.finish() } }
}

extension PlayerClient: DependencyKey {
    public static let liveValue: PlayerClient = {
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
            setVolume: { volume in
                try box.getPlayer().setAudioVolume(Volume(Float(volume) / 100.0))
            },
            jump: { offset in
                _ = box.getPlayer().jump(by: .seconds(offset))
            },
            seek: { position in
                _ = box.getPlayer().seek(toPosition: PlaybackPosition(position))
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
            setAudioTrack: { track in
                box.getPlayer().selectedAudioTrack = track
            },
            setSubtitleTrack: { track in
                box.getPlayer().selectedSubtitleTrack = track
            },
            events: {
                let player = box.getPlayer()
                return AsyncStream { continuation in
                    let task = Task {
                        for await event in player.events {
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

    public static let testValue = PlayerClient(
        vlcPlayer: { fatalError() },
        play: { _ in },
        resume: {},
        pause: {},
        stop: {},
        setVolume: { _ in },
        jump: { _ in },
        seek: { _ in },
        getMediaInfo: { nil },
        getAudioTracks: { [] },
        getSubtitleTracks: { [] },
        setAudioTrack: { _ in },
        setSubtitleTrack: { _ in },
        events: { AsyncStream { $0.finish() } }
    )
}

public extension DependencyValues {
    var playerClient: PlayerClient {
        get { self[PlayerClient.self] }
        set { self[PlayerClient.self] = newValue }
    }
}
