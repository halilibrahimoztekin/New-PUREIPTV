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
                    let p = PlaybackVLC.makePlayer()
                    player = p
                    return p
                }
            }

            let box = Box()

            return PlayerClient(
                vlcPlayer: { box.getPlayer() },
                play: { url, userAgentOverride, networkCachingMilliseconds in
                    try await PlaybackAudioSession.setActive(true)
                    try Task.checkCancellation()
                    let player = box.getPlayer()
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
                    if (try? player.seek(by: offsetDuration, fast: true)) != nil {
                        return
                    }
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
                getStats: { nil },
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
