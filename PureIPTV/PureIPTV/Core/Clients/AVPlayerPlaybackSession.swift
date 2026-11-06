import AVFoundation
import Foundation
import SwiftVLC

@MainActor
final class AVPlayerPlaybackSession {
    let player = AVPlayer()

    init() {
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
    }

    private var timeObserver: Any?
    private var playerObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var observedItem: AVPlayerItem?
    private var endObserver: NSObjectProtocol?
    private var eventContinuation: AsyncStream<PlayerEvent>.Continuation?
    private var eventGeneration = UUID()
    private var preparationGeneration = UUID()
    private var pendingSeekID: UUID?
    private var pendingSeekContinuation: CheckedContinuation<SeekAttempt, Never>?
    private var pendingSeekTimeoutTask: Task<Void, Never>?
    private let seekTolerance = CMTime(value: 1, timescale: 2)

    private enum SeekAttempt {
        case completed(Bool)
        case timedOut
        case cancelled
    }

    var currentTimeSeconds: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? max(0, seconds) : 0
    }

    #if os(tvOS)
        func preferredDisplayCriteria() async -> AVDisplayCriteria? {
            guard let asset = player.currentItem?.asset else { return nil }
            return try? await asset.load(.preferredDisplayCriteria)
        }
    #endif

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
        // Use the same bounded, cancellation-aware seek path as user initiated
        // seeks. Without this, restoring a position during engine preparation
        // could leave the player loading forever if AVPlayer never calls back.
        try await seek(to: clampedPosition)
        try checkPreparation(generation)

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
        cancelPendingSeek()
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

        let seekID = UUID()
        let attempt = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                cancelPendingSeek()
                pendingSeekID = seekID
                pendingSeekContinuation = continuation
                pendingSeekTimeoutTask = Task { @MainActor [self] in
                    do {
                        try await Task.sleep(for: .seconds(6))
                    } catch {
                        return
                    }
                    guard pendingSeekID == seekID else { return }
                    player.currentItem?.cancelPendingSeeks()
                    finishPendingSeek(seekID, with: .timedOut)
                }

                // Sample-accurate seeks can add decoding delay on compressed streams.
                // The reducer confirms the landed time, so a half-second window keeps
                // forward seeking responsive without accepting a large jump.
                player.seek(
                    to: target,
                    toleranceBefore: seekTolerance,
                    toleranceAfter: seekTolerance
                ) { [session = self] finished in
                    Task { @MainActor in
                        session.finishPendingSeek(seekID, with: .completed(finished))
                    }
                }
            }
        } onCancel: { [session = self] in
            Task { @MainActor in
                session.cancelPendingSeek(seekID: seekID)
            }
        }

        switch attempt {
        case let .completed(didSeek):
            guard didSeek else { throw PlaybackEngineSwitchError.seekFailed }
        case .timedOut:
            throw PlaybackEngineSwitchError.seekTimedOut
        case .cancelled:
            throw CancellationError()
        }
    }

    private func cancelPendingSeek(seekID: UUID? = nil) {
        guard let pendingSeekID,
              seekID == nil || seekID == pendingSeekID
        else { return }
        player.currentItem?.cancelPendingSeeks()
        finishPendingSeek(pendingSeekID, with: .cancelled)
    }

    private func finishPendingSeek(_ seekID: UUID, with result: SeekAttempt) {
        guard pendingSeekID == seekID else { return }
        pendingSeekID = nil
        pendingSeekTimeoutTask?.cancel()
        pendingSeekTimeoutTask = nil
        let continuation = pendingSeekContinuation
        pendingSeekContinuation = nil
        continuation?.resume(returning: result)
    }

    func events() -> AsyncStream<PlayerEvent> {
        removeObservers()
        let generation = eventGeneration
        return AsyncStream { continuation in
            eventContinuation = continuation
            emitCurrentState()

            playerObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self, eventGeneration == generation else { return }
                    emitCurrentState()
                }
            }
            currentItemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self, eventGeneration == generation else { return }
                    // Read the live value on the actor. KVO callbacks are
                    // asynchronous here, so multiple item replacements can
                    // coalesce before this task runs.
                    observe(item: player.currentItem, generation: generation)
                }
            }

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, eventGeneration == generation else { return }
                    removeObservers()
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
        // Ignore the empty interval between stopping the previous item and
        // installing the next one. Reporting `.paused` here makes the reducer
        // dismiss its loading state before the new engine has produced a frame.
        guard let item = player.currentItem else { return }
        switch player.timeControlStatus {
        case .playing:
            eventContinuation.yield(.stateChanged(.playing))
        case .waitingToPlayAtSpecifiedRate:
            eventContinuation.yield(.stateChanged(.buffering))
        case .paused:
            eventContinuation.yield(.stateChanged(item.status == .readyToPlay ? .paused : .opening))
        @unknown default:
            eventContinuation.yield(.stateChanged(.opening))
        }
    }

    private func observe(item: AVPlayerItem?, generation: UUID) {
        guard eventGeneration == generation else { return }
        guard player.currentItem === item else { return }
        if let item, observedItem === item, itemObservation != nil {
            return
        }
        itemObservation?.invalidate()
        itemObservation = nil
        removeTimeObserver()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        guard let item else {
            observedItem = nil
            return
        }
        observedItem = item
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self,
                      eventGeneration == generation,
                      player.currentItem === item
                else { return }
                switch item.status {
                case .readyToPlay:
                    let seconds = item.duration.seconds
                    if seconds.isFinite, seconds > 0 {
                        eventContinuation?.yield(.lengthChanged(.seconds(seconds)))
                    }
                    eventContinuation?.yield(.tracksChanged)
                    emitCurrentState()
                case .failed:
                    eventContinuation?.yield(.encounteredError)
                case .unknown:
                    emitCurrentState()
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
            Task { @MainActor [weak self] in
                guard let self,
                      eventGeneration == generation,
                      player.currentItem === item
                else { return }
                eventContinuation?.yield(.endReached)
                eventContinuation?.yield(.stateChanged(.stopped))
            }
        }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self,
                      eventGeneration == generation,
                      player.currentItem === item
                else { return }
                emitTime(time)
            }
        }
    }

    private func emitTime(_ time: CMTime) {
        guard player.currentItem != nil else { return }
        let seconds = time.seconds
        guard seconds.isFinite else { return }
        eventContinuation?.yield(.timeChanged(.seconds(seconds)))
        if let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
            eventContinuation?.yield(.positionChanged(min(1, max(0, seconds / duration))))
        }
    }

    private func removeObservers() {
        eventGeneration = UUID()
        removeTimeObserver()
        playerObservation?.invalidate()
        playerObservation = nil
        currentItemObservation?.invalidate()
        currentItemObservation = nil
        itemObservation?.invalidate()
        itemObservation = nil
        observedItem = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        eventContinuation?.finish()
        eventContinuation = nil
    }

    private func removeTimeObserver() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }
}

enum PlaybackEngineSwitchError: LocalizedError {
    case customUserAgentUnsupported
    case durationUnavailable
    case backendNotReady
    case mediaUnavailable
    case seekFailed
    case seekTimedOut

    var errorDescription: String? {
        switch self {
        case .customUserAgentUnsupported: "AVPlayer cannot use this playlist's custom User-Agent."
        case .durationUnavailable: "AVPlayer could not read a finite VOD duration."
        case .backendNotReady: "AVPlayer did not become ready in time."
        case .mediaUnavailable: "AVPlayer could not play this media URL."
        case .seekFailed: "AVPlayer could not restore the current playback position."
        case .seekTimedOut: "AVPlayer did not finish seeking before the timeout."
        }
    }
}
