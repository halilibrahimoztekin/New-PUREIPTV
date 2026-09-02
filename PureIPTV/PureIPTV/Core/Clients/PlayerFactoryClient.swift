import AVFoundation
import ComposableArchitecture
import Foundation
import SwiftVLC

public struct PlayerFactoryClient: Sendable {
    public var createPlayer: @Sendable () -> PlayerClient
}

extension PlayerFactoryClient: DependencyKey {
    public static let liveValue: PlayerFactoryClient = .init(
        createPlayer: {
            // Initialize a new Box for every client
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
                setAudioDelay: { _ in },
                setSubtitleDelay: { _ in },
                getStats: { nil },
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
        }
    )

    public nonisolated static let testValue = PlayerFactoryClient(
        createPlayer: { .testValue }
    )
}

public extension DependencyValues {
    var playerFactoryClient: PlayerFactoryClient {
        get { self[PlayerFactoryClient.self] }
        set { self[PlayerFactoryClient.self] = newValue }
    }
}
