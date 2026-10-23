import AVFoundation
import ComposableArchitecture
import Foundation
import SwiftVLC

// MARK: - PreviewPlaybackStatus

public struct PreviewPlaybackStatus: Equatable, Sendable {
    public var isPlaying: Bool
    public var isMuted: Bool
    public var currentChannelID: String?
    public var currentTitle: String?
    public var currentStreamURL: URL?
    public var hasError: Bool
    public var errorMessage: String?

    public init(
        isPlaying: Bool = false,
        isMuted: Bool = true,
        currentChannelID: String? = nil,
        currentTitle: String? = nil,
        currentStreamURL: URL? = nil,
        hasError: Bool = false,
        errorMessage: String? = nil
    ) {
        self.isPlaying = isPlaying
        self.isMuted = isMuted
        self.currentChannelID = currentChannelID
        self.currentTitle = currentTitle
        self.currentStreamURL = currentStreamURL
        self.hasError = hasError
        self.errorMessage = errorMessage
    }
}

// MARK: - PreviewPlayerClient (TCA)

@DependencyClient
public struct PreviewPlayerClient: Sendable {
    public var playPreview: @MainActor @Sendable (_ channel: MediaModels.Item) async throws -> Void
    public var stopPreview: @MainActor @Sendable () async -> Void
    public var toggleMute: @MainActor @Sendable () async -> Bool = { true }
    public var setMuted: @MainActor @Sendable (_ isMuted: Bool) async -> Void
    public var getStatus: @MainActor @Sendable () -> PreviewPlaybackStatus = { PreviewPlaybackStatus() }
    public var vlcPlayer: @MainActor @Sendable () -> Player? = { nil }
}

extension PreviewPlayerClient: DependencyKey {
    public static let liveValue: PreviewPlayerClient = {
        final class PreviewBox: @unchecked Sendable {
            @MainActor private var player: Player?
            @MainActor private var status = PreviewPlaybackStatus()

            @MainActor func getPlayer() -> Player {
                if let p = player {
                    return p
                }
                let p = PlaybackVLC.makePlayer()
                _ = try? p.setAudioVolume(Volume(0.0))
                player = p
                return p
            }

            @MainActor func play(channel: MediaModels.Item) throws {
                guard let streamURL = channel.streamURL else {
                    status = PreviewPlaybackStatus(
                        isPlaying: false,
                        isMuted: status.isMuted,
                        currentChannelID: channel.id,
                        currentTitle: channel.title,
                        hasError: true,
                        errorMessage: "Geçersiz yayın bağlantısı"
                    )
                    return
                }

                if status.isPlaying && status.currentChannelID == channel.id {
                    return
                }

                let p = getPlayer()
                let targetVol: Float = status.isMuted ? 0.0 : 0.85
                _ = try? p.setAudioVolume(Volume(targetVol))
                let userAgent = channel.userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
                let media = try Media(
                    url: streamURL,
                    httpUserAgent: userAgent?.isEmpty == false ? userAgent : UserAgentManager.shared.resolvedUserAgent,
                    httpReferrer: nil
                )
                try p.play(media)

                status = PreviewPlaybackStatus(
                    isPlaying: true,
                    isMuted: status.isMuted,
                    currentChannelID: channel.id,
                    currentTitle: channel.title,
                    currentStreamURL: streamURL,
                    hasError: false,
                    errorMessage: nil
                )
            }

            @MainActor func stop() {
                player?.stop()
                status = PreviewPlaybackStatus(
                    isPlaying: false,
                    isMuted: status.isMuted,
                    currentChannelID: nil,
                    currentTitle: nil,
                    currentStreamURL: nil,
                    hasError: false,
                    errorMessage: nil
                )
            }

            @MainActor func setMuted(_ isMuted: Bool) {
                status.isMuted = isMuted
                let targetVol: Float = isMuted ? 0.0 : 0.85
                _ = try? player?.setAudioVolume(Volume(targetVol))
            }

            @MainActor func toggleMute() -> Bool {
                let newMute = !status.isMuted
                setMuted(newMute)
                return newMute
            }

            @MainActor func currentStatus() -> PreviewPlaybackStatus {
                status
            }
        }

        let box = PreviewBox()

        return PreviewPlayerClient(
            playPreview: { channel in
                try await PlaybackAudioSession.setActive(true)
                try Task.checkCancellation()
                try box.play(channel: channel)
            },
            stopPreview: {
                box.stop()
            },
            toggleMute: {
                box.toggleMute()
            },
            setMuted: { isMuted in
                box.setMuted(isMuted)
            },
            getStatus: {
                box.currentStatus()
            },
            vlcPlayer: {
                box.getPlayer()
            }
        )
    }()

    public static let testValue: PreviewPlayerClient = {
        final class TestBox: @unchecked Sendable {
            @MainActor var status = PreviewPlaybackStatus()
        }
        let box = TestBox()

        return PreviewPlayerClient(
            playPreview: { channel in
                box.status = PreviewPlaybackStatus(
                    isPlaying: true,
                    isMuted: true,
                    currentChannelID: channel.id,
                    currentTitle: channel.title,
                    currentStreamURL: channel.streamURL
                )
            },
            stopPreview: {
                box.status = PreviewPlaybackStatus(
                    isPlaying: false,
                    isMuted: box.status.isMuted
                )
            },
            toggleMute: {
                let newMute = !box.status.isMuted
                box.status.isMuted = newMute
                return newMute
            },
            setMuted: { isMuted in
                box.status.isMuted = isMuted
            },
            getStatus: {
                box.status
            },
            vlcPlayer: {
                nil
            }
        )
    }()
}

public extension DependencyValues {
    var previewPlayerClient: PreviewPlayerClient {
        get { self[PreviewPlayerClient.self] }
        set { self[PreviewPlayerClient.self] = newValue }
    }
}
