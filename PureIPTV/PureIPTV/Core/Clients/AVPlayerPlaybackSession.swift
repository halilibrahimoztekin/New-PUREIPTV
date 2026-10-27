import AVFoundation
import Foundation
import SwiftVLC

@MainActor
final class AVPlayerPlaybackSession {
    let player = AVPlayer()

    private var timeObserver: Any?
    private var playerObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var eventContinuation: AsyncStream<PlayerEvent>.Continuation?
    private var eventGeneration = UUID()
    private var preparationGeneration = UUID()

    var currentTimeSeconds: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? max(0, seconds) : 0
    }

    func prepare(
        url: URL,
        positionSeconds: Double,
        isPlaying: Bool,
        playbackRate: Float,
        volume _: Int32,
        audioName: String?,
        audioLanguage: String?,
        subtitleName: String?,
        subtitleLanguage: String?
    ) async throws {
        stop()
        let generation = UUID()
        preparationGeneration = generation
        player.volume = 0

        let asset = AVURLAsset(url: url)
        guard try await asset.load(.isPlayable) else {
            throw PlaybackEngineSwitchError.mediaUnavailable
        }
        try checkPreparation(generation)
        let duration = try await asset.load(.duration)
        try checkPreparation(generation)
        let durationSeconds = duration.seconds
        guard duration.isNumeric, durationSeconds.isFinite, durationSeconds > 0 else {
            throw PlaybackEngineSwitchError.durationUnavailable
        }

        let item = AVPlayerItem(asset: asset)
        item.audioTimePitchAlgorithm = .spectral
        try checkPreparation(generation)
        player.replaceCurrentItem(with: item)

        for _ in 0 ..< 120 {
            try Task.checkCancellation()
            try checkPreparation(generation)
            if item.status == .readyToPlay {
                break
            }
            if item.status == .failed {
                throw item.error ?? PlaybackEngineSwitchError.mediaUnavailable
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        guard item.status == .readyToPlay else { throw PlaybackEngineSwitchError.backendNotReady }

        if let group = try? await asset.loadMediaSelectionGroup(for: .audible) {
            try checkPreparation(generation)
            if let option = matchingOption(in: group, name: audioName, language: audioLanguage) {
                item.select(option, in: group)
            }
        }
        if let group = try? await asset.loadMediaSelectionGroup(for: .legible) {
            try checkPreparation(generation)
            let option = matchingOption(in: group, name: subtitleName, language: subtitleLanguage)
            item.select(option, in: group)
        }

        let clampedPosition = min(durationSeconds, max(0, positionSeconds.isFinite ? positionSeconds : 0))
        let target = CMTime(seconds: clampedPosition, preferredTimescale: 600)
        let didSeek = await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        try checkPreparation(generation)
        guard didSeek else {
            throw PlaybackEngineSwitchError.seekFailed
        }

        if isPlaying {
            player.playImmediately(atRate: max(0.25, min(4, playbackRate)))
            var reachedPlayingState = false
            for _ in 0 ..< 100 {
                try Task.checkCancellation()
                try checkPreparation(generation)
                if player.timeControlStatus == .playing {
                    reachedPlayingState = true
                    break
                }
                if item.status == .failed {
                    throw item.error ?? PlaybackEngineSwitchError.mediaUnavailable
                }
                try await Task.sleep(for: .milliseconds(50))
            }
            guard reachedPlayingState else { throw PlaybackEngineSwitchError.backendNotReady }
        } else {
            player.pause()
        }
        player.volume = 0
    }

    func play(rate: Float) {
        player.playImmediately(atRate: max(0.25, min(4, rate)))
    }

    func pause() {
        player.pause()
    }

    func stop() {
        preparationGeneration = UUID()
        removeObservers()
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func setVolume(_ volume: Int32) {
        player.volume = Float(max(0, min(100, volume))) / 100
    }

    func setRate(_ rate: Float) {
        if player.rate != 0 {
            player.rate = max(0.25, min(4, rate))
        }
    }

    func seek(to seconds: Double) async throws {
        guard let item = player.currentItem, item.status == .readyToPlay else {
            throw PlaybackEngineSwitchError.backendNotReady
        }
        let duration = item.duration.seconds
        let safeDuration = duration.isFinite && duration > 0 ? duration : max(0, seconds)
        let target = CMTime(seconds: min(safeDuration, max(0, seconds)), preferredTimescale: 600)
        guard await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) else {
            throw PlaybackEngineSwitchError.seekFailed
        }
    }

    func events() -> AsyncStream<PlayerEvent> {
        removeObservers()
        let generation = eventGeneration
        return AsyncStream { continuation in
            eventContinuation = continuation
            emitCurrentState()

            playerObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor in
                    guard let self, self.eventGeneration == generation else { return }
                    self.emitCurrentState()
                }
            }

            if let item = player.currentItem {
                itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                    Task { @MainActor in
                        guard let self, self.eventGeneration == generation else { return }
                        switch item.status {
                        case .readyToPlay:
                            let seconds = item.duration.seconds
                            if seconds.isFinite, seconds > 0 {
                                self.eventContinuation?.yield(.lengthChanged(.seconds(seconds)))
                            }
                            self.eventContinuation?.yield(.tracksChanged)
                        case .failed:
                            self.eventContinuation?.yield(.encounteredError)
                        case .unknown:
                            break
                        @unknown default:
                            break
                        }
                    }
                }

                endObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor in
                        guard let self, self.eventGeneration == generation else { return }
                        self.eventContinuation?.yield(.endReached)
                        self.eventContinuation?.yield(.stateChanged(.stopped))
                    }
                }
            }

            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                Task { @MainActor in
                    guard let self, self.eventGeneration == generation else { return }
                    self.emitTime(time)
                }
            }

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.eventGeneration == generation else { return }
                    self.removeObservers()
                }
            }
        }
    }

    private func matchingOption(
        in group: AVMediaSelectionGroup,
        name: String?,
        language: String?
    ) -> AVMediaSelectionOption? {
        if let name, !name.isEmpty {
            if let match = group.options.first(where: {
                $0.displayName.localizedCaseInsensitiveCompare(name) == .orderedSame
            }) {
                return match
            }
        }
        if let language, !language.isEmpty {
            let normalized = language.lowercased()
            return group.options.first(where: {
                let tag = ($0.extendedLanguageTag ?? "").lowercased()
                return tag == normalized || tag.hasPrefix(normalized + "-")
            })
        }
        return nil
    }

    private func checkPreparation(_ generation: UUID) throws {
        try Task.checkCancellation()
        guard preparationGeneration == generation else { throw CancellationError() }
    }

    private func emitCurrentState() {
        guard let eventContinuation else { return }
        switch player.timeControlStatus {
        case .playing:
            eventContinuation.yield(.stateChanged(.playing))
        case .waitingToPlayAtSpecifiedRate:
            eventContinuation.yield(.stateChanged(.buffering))
        case .paused:
            eventContinuation.yield(.stateChanged(.paused))
        @unknown default:
            eventContinuation.yield(.stateChanged(.opening))
        }
    }

    private func emitTime(_ time: CMTime) {
        let seconds = time.seconds
        guard seconds.isFinite else { return }
        eventContinuation?.yield(.timeChanged(.seconds(seconds)))
        if let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
            eventContinuation?.yield(.positionChanged(min(1, max(0, seconds / duration))))
        }
    }

    private func removeObservers() {
        eventGeneration = UUID()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        playerObservation?.invalidate()
        playerObservation = nil
        itemObservation?.invalidate()
        itemObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        eventContinuation?.finish()
        eventContinuation = nil
    }
}

enum PlaybackEngineSwitchError: LocalizedError {
    case customUserAgentUnsupported
    case durationUnavailable
    case backendNotReady
    case mediaUnavailable
    case seekFailed

    var errorDescription: String? {
        switch self {
        case .customUserAgentUnsupported: "AVPlayer cannot use this playlist's custom User-Agent."
        case .durationUnavailable: "AVPlayer could not read a finite VOD duration."
        case .backendNotReady: "AVPlayer did not become ready in time."
        case .mediaUnavailable: "AVPlayer could not play this media URL."
        case .seekFailed: "AVPlayer could not restore the current playback position."
        }
    }
}
