import AVFoundation
import ComposableArchitecture
import CoreVideo
import FactoryKit
@testable import PureIPTV
import SwiftVLC
import XCTest

@MainActor
final class PlayerFeatureTests: XCTestCase {
    func testPlayerRouteEqualityUsesPlayableItemIdentity() throws {
        let firstItem = try PlayerFeature.PlayableItem(
            id: "same-route-item",
            title: "Episode",
            streamURL: XCTUnwrap(URL(string: "https://example.com/episode.m3u8"))
        )
        let sameIdentityItem = try PlayerFeature.PlayableItem(
            id: "same-route-item",
            title: "Updated title",
            streamURL: XCTUnwrap(URL(string: "https://example.com/updated.m3u8"))
        )
        let anotherItem = try PlayerFeature.PlayableItem(
            id: "another-route-item",
            title: "Another episode",
            streamURL: XCTUnwrap(URL(string: "https://example.com/another.m3u8"))
        )

        let firstRoute = AppScreen.State.player(PlayerFeature.State(item: firstItem))
        var changedPlaybackState = PlayerFeature.State(item: sameIdentityItem)
        changedPlaybackState.currentTime = .seconds(120)
        changedPlaybackState.position = 0.25
        let sameRoute = AppScreen.State.player(changedPlaybackState)
        let differentRoute = AppScreen.State.player(PlayerFeature.State(item: anotherItem))

        XCTAssertEqual(firstRoute, sameRoute)
        XCTAssertEqual(firstRoute.hashValue, sameRoute.hashValue)
        XCTAssertNotEqual(firstRoute, differentRoute)
    }

    func testAbsoluteResumeTimeSkipsCompetingPositionRecoverySeek() {
        XCTAssertFalse(PlayerFeature.shouldRestorePositionOnPlaybackStart(
            isLive: false,
            isPlayingCatchup: false,
            initialProgress: 480
        ))
        XCTAssertTrue(PlayerFeature.shouldRestorePositionOnPlaybackStart(
            isLive: false,
            isPlayingCatchup: false,
            initialProgress: nil
        ))
        XCTAssertFalse(PlayerFeature.shouldRestorePositionOnPlaybackStart(
            isLive: true,
            isPlayingCatchup: true,
            initialProgress: 480
        ))
        XCTAssertFalse(PlayerFeature.shouldRestorePositionOnPlaybackStart(
            isLive: true,
            isPlayingCatchup: false,
            initialProgress: nil
        ))
    }

    func testInitialResumeVerificationWaitsForPendingSeekBeforeRetrying() async throws {
        let targetSeconds = 71.0
        let item = try PlayerFeature.PlayableItem(
            id: "episode-resume-verification-pending",
            title: "Episode",
            streamURL: XCTUnwrap(URL(string: "https://example.com/episode.m3u8")),
            startPosition: targetSeconds / 498,
            initialDuration: 498,
            initialProgress: targetSeconds
        )
        let requestID = UUID()
        let clock = TestClock()
        var initialState = PlayerFeature.State(item: item)
        initialState.playerState = .playing
        initialState.activeVODSeekRequestID = requestID
        initialState.pendingInitialResumeSeekTargetSeconds = targetSeconds
        initialState.expectedVODSeekTargetSeconds = targetSeconds
        initialState.vodSeekPreviousTime = .seconds(targetSeconds)
        initialState.vodSeekPreviousPosition = targetSeconds / 498

        registerPlayerClient { client in
            client.currentPlaybackTime = { .zero }
            client.seekAndConfirm = { _ in
                PlaybackSeekResult(
                    currentTime: .seconds(targetSeconds),
                    position: targetSeconds / 498,
                    status: .settled
                )
            }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) { PlayerFeature() } withDependencies: {
            $0.continuousClock = clock
        }
        store.exhaustivity = .off

        await store.send(
            .verifyInitialResumeSeek(
                itemID: item.id,
                playbackRequestID: initialState.playbackRequestID,
                targetSeconds: targetSeconds,
                actualTime: .zero,
                verificationAttempt: 0
            )
        )

        await store.send(
            .vodSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                playbackRequestID: initialState.playbackRequestID,
                result: PlaybackSeekResult(
                    currentTime: .seconds(targetSeconds),
                    position: targetSeconds / 498,
                    status: .settled
                )
            )
        )
        XCTAssertNil(store.state.activeVODSeekRequestID)

        await clock.advance(by: .seconds(1))
        await store.receive(\.verifyInitialResumeSeek) {
            $0.initialResumeSeekRetryCount = 1
        }
        await store.receive(\.initialResumeSeekRequested)
        await store.receive(\.seekToTime)

        XCTAssertNotNil(store.state.activeVODSeekRequestID)
        XCTAssertEqual(store.state.currentTime, .seconds(targetSeconds))
    }

    func testInitialResumeVerificationRetriesWhenFailedSeekRolledBackToZero() async throws {
        let targetSeconds = 71.0
        let item = try PlayerFeature.PlayableItem(
            id: "episode-resume-verification-rollback",
            title: "Episode",
            streamURL: XCTUnwrap(URL(string: "https://example.com/episode.m3u8")),
            initialDuration: 498,
            initialProgress: targetSeconds
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.playerState = .playing
        initialState.currentTime = .zero
        initialState.position = 0
        initialState.hasAppliedInitialSeek = true
        initialState.pendingInitialResumeSeekTargetSeconds = targetSeconds

        registerPlayerClient { client in
            client.seekAndConfirm = { _ in
                PlaybackSeekResult(
                    currentTime: .seconds(targetSeconds),
                    position: targetSeconds / 498,
                    status: .settled
                )
            }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) { PlayerFeature() }
        store.exhaustivity = .off

        await store.send(
            .verifyInitialResumeSeek(
                itemID: item.id,
                playbackRequestID: initialState.playbackRequestID,
                targetSeconds: targetSeconds,
                actualTime: .zero,
                verificationAttempt: 4
            )
        ) {
            $0.initialResumeSeekRetryCount = 1
        }
        await store.receive(\.initialResumeSeekRequested)
        await store.receive(\.seekToTime)
        await store.receive(\.vodSeekCompleted)

        XCTAssertNil(store.state.pendingInitialResumeSeekTargetSeconds)
        XCTAssertEqual(store.state.currentTime, .seconds(targetSeconds))
    }

    func testInitialResumeVerificationDoesNotUndoManualSeekAwayFromSavedPoint() async throws {
        let targetSeconds = 71.0
        let item = try PlayerFeature.PlayableItem(
            id: "episode-resume-verification-manual-seek",
            title: "Episode",
            streamURL: XCTUnwrap(URL(string: "https://example.com/episode.m3u8")),
            startPosition: targetSeconds / 498,
            initialDuration: 498,
            initialProgress: targetSeconds
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.playerState = .playing
        initialState.currentTime = .zero
        initialState.position = 0
        initialState.pendingInitialResumeSeekTargetSeconds = nil
        let recorder = SeekCommandRecorder()
        registerPlayerClient { client in
            client.currentPlaybackTime = { .zero }
            client.seekAndConfirm = { command in
                await recorder.record(command)
                return PlaybackSeekResult(currentTime: .zero, position: 0, status: .settled)
            }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) { PlayerFeature() }
        store.exhaustivity = .off

        await store.send(
            .verifyInitialResumeSeek(
                itemID: item.id,
                playbackRequestID: initialState.playbackRequestID,
                targetSeconds: targetSeconds,
                actualTime: .zero,
                verificationAttempt: 4
            )
        )

        XCTAssertEqual(store.state.currentTime, .zero)
        XCTAssertEqual(store.state.initialResumeSeekRetryCount, 0)
        XCTAssertNil(store.state.activeVODSeekRequestID)
        let commands = await recorder.commandDescriptions
        XCTAssertTrue(commands.isEmpty)
    }

    func testAVPlayerSessionSeeksForwardAndBackwardOnLocalMedia() async throws {
        let fixtureURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PureIPTV-seek-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: fixtureURL) }
        try await Self.makeAVPlayerSeekFixture(at: fixtureURL)

        let session = AVPlayerPlaybackSession()
        defer { session.stop() }

        try await session.prepare(
            url: fixtureURL,
            positionSeconds: 0,
            isPlaying: true,
            playbackRate: 1,
            volume: 0,
            audioName: nil,
            audioLanguage: nil,
            subtitleName: nil,
            subtitleLanguage: nil
        )

        try await session.seek(to: 4)
        XCTAssertEqual(session.currentTimeSeconds, 4, accuracy: 0.8)

        try await session.seek(to: 1)
        XCTAssertEqual(session.currentTimeSeconds, 1, accuracy: 0.8)
    }

    func testAVPlayerEventStreamObservesItemInstalledAfterSubscription() async throws {
        let fixtureURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PureIPTV-events-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: fixtureURL) }
        try await Self.makeAVPlayerSeekFixture(at: fixtureURL)

        let session = AVPlayerPlaybackSession()
        defer { session.stop() }
        let events = session.events()
        let collector = Task { @MainActor in
            var collected: [PlayerEvent] = []
            for await event in events {
                collected.append(event)
                if collected.contains(where: {
                    if case .stateChanged(.playing) = $0 {
                        return true
                    }
                    return false
                }), collected.contains(where: {
                    if case let .lengthChanged(duration) = $0 {
                        return duration.components.seconds > 0
                    }
                    return false
                }) {
                    return collected
                }
            }
            return collected
        }
        defer { collector.cancel() }

        try await session.prepare(
            url: fixtureURL,
            positionSeconds: 0,
            isPlaying: true,
            playbackRate: 1,
            volume: 0,
            audioName: nil,
            audioLanguage: nil,
            subtitleName: nil,
            subtitleLanguage: nil
        )

        let collected = await withTaskGroup(of: [PlayerEvent]?.self) { group in
            group.addTask { await collector.value }
            group.addTask {
                try? await Task.sleep(for: .seconds(4))
                collector.cancel()
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? []
        }
        XCTAssertTrue(collected.contains {
            if case .stateChanged(.playing) = $0 {
                return true
            }
            return false
        })
        XCTAssertTrue(collected.contains {
            if case let .lengthChanged(duration) = $0 {
                return duration.components.seconds > 0
            }
            return false
        })
    }

    func testPlayerClientEventsFollowAVPlayerSelectedAfterSubscription() async throws {
        let fixtureURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PureIPTV-engine-events-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: fixtureURL) }
        try await Self.makeAVPlayerSeekFixture(at: fixtureURL)

        let client = PlayerClient.liveValue
        let events = await client.events()
        let collector = Task { @MainActor in
            var collected: [PlayerEvent] = []
            for await event in events {
                collected.append(event)
                if collected.contains(where: {
                    if case .stateChanged(.playing) = $0 {
                        return true
                    }
                    return false
                }), collected.contains(where: {
                    if case let .lengthChanged(duration) = $0 {
                        return duration.components.seconds > 0
                    }
                    return false
                }) {
                    return collected
                }
            }
            return collected
        }
        defer { collector.cancel() }

        let playback: PlaybackStartResult
        do {
            playback = try await client.play(
                fixtureURL,
                nil,
                nil,
                .automatic,
                .avPlayer,
                nil,
                nil,
                nil,
                nil
            )
        } catch {
            collector.cancel()
            try? await client.stop()
            throw error
        }
        XCTAssertEqual(playback.engine, .avPlayer)

        let collected = await withTaskGroup(of: [PlayerEvent]?.self) { group in
            group.addTask { await collector.value }
            group.addTask {
                try? await Task.sleep(for: .seconds(4))
                collector.cancel()
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? []
        }
        XCTAssertTrue(collected.contains {
            if case .stateChanged(.playing) = $0 {
                return true
            }
            return false
        })
        XCTAssertTrue(collected.contains {
            if case let .lengthChanged(duration) = $0 {
                return duration.components.seconds > 0
            }
            return false
        })
        try await client.stop()
    }

    private static func makeAVPlayerSeekFixture(at fixtureURL: URL) async throws {
        let writer = try AVAssetWriter(outputURL: fixtureURL, fileType: .mov)
        let width = 64
        let height = 64
        let framesPerSecond: Int32 = 15
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoMaxKeyFrameIntervalKey: 1,
                    AVVideoExpectedSourceFrameRateKey: framesPerSecond,
                    AVVideoAverageBitRateKey: 120_000,
                ],
            ]
        )
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
        )
        guard writer.canAdd(input) else {
            throw NSError(domain: "PureIPTVSeekFixture", code: 1)
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "PureIPTVSeekFixture", code: 2)
        }
        writer.startSession(atSourceTime: .zero)

        guard let pool = adaptor.pixelBufferPool else {
            throw NSError(domain: "PureIPTVSeekFixture", code: 3)
        }
        for frame in 0 ..< 90 {
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else {
                    throw writer.error ?? NSError(domain: "PureIPTVSeekFixture", code: 4)
                }
                try await Task.sleep(for: .milliseconds(5))
            }

            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            guard status == kCVReturnSuccess, let pixelBuffer else {
                throw NSError(domain: "PureIPTVSeekFixture", code: Int(status))
            }
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
                memset(baseAddress, 0, CVPixelBufferGetBytesPerRow(pixelBuffer) * height)
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

            let presentationTime = CMTime(value: Int64(frame), timescale: framesPerSecond)
            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? NSError(domain: "PureIPTVSeekFixture", code: 5)
            }
        }

        input.markAsFinished()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writer.finishWriting { continuation.resume() }
        }
        guard writer.status == .completed else {
            throw writer.error ?? NSError(domain: "PureIPTVSeekFixture", code: 6)
        }
    }

    func testStalePlayerTimelineEventsDoNotOverwriteActiveVODSeek() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-1",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(300)
        initialState.position = 0.5
        initialState.activeVODSeekRequestID = UUID()
        initialState.vodSeekPreviousTime = .seconds(300)
        initialState.vodSeekPreviousPosition = 0.5

        let store = TestStore(initialState: initialState) {
            PlayerFeature()
        }
        store.exhaustivity = .off

        await store.send(.handlePlayerEvent(.timeChanged(.seconds(5))))
        await store.send(.handlePlayerEvent(.positionChanged(0.01)))

        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
        XCTAssertNotNil(store.state.activeVODSeekRequestID)
    }

    func testAdvancingTimelineClearsStaleBufferingState() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-stale-buffering-state",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.playerState = .buffering
        initialState.currentTime = .seconds(30)
        initialState.totalTime = .seconds(600)
        initialState.hasAppliedInitialSeek = true

        let store = TestStore(initialState: initialState) {
            PlayerFeature()
        }
        store.exhaustivity = .off

        await store.send(.handlePlayerEvent(.timeChanged(.seconds(31))))
        await store.receive(\.handlePlayerEvent)

        XCTAssertEqual(store.state.playerState, .playing)
        XCTAssertEqual(store.state.currentTime, .seconds(31))
    }

    func testVODSkipPreservesFractionalTimeline() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-fractional-seek",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600.5)
        initialState.currentTime = .seconds(30.75)
        initialState.position = 30.75 / 600.5
        let recorder = SeekCommandRecorder()
        registerPlayerClient { client in
            client.seekAndConfirm = { command in
                await recorder.record(command)
                return PlaybackSeekResult(
                    currentTime: .seconds(40.75),
                    position: 40.75 / 600.5,
                    status: .settled
                )
            }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) {
            PlayerFeature()
        }
        store.exhaustivity = .off

        await store.send(.jumpBySeconds(10))
        await store.receive(\.vodSeekCompleted)

        XCTAssertEqual(store.state.currentTime, .seconds(40.75))
        XCTAssertEqual(store.state.position, 40.75 / 600.5, accuracy: 0.000_001)
        XCTAssertEqual(store.state.expectedVODSeekTargetSeconds, 40.75)
        let recordedTargets = await recorder.timeTargets
        XCTAssertEqual(recordedTargets, [.seconds(40.75)])
    }

    func testCloseSavesLatestEngineTimeForResumeProgress() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "episode-latest-progress",
            title: "Episode",
            seriesTitle: "Series",
            streamURL: XCTUnwrap(URL(string: "https://example.com/episode.m3u8")),
            seriesID: "series-1"
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.currentTime = .seconds(83)
        initialState.totalTime = .seconds(498)

        let recorder = SavedWatchProgressRecorder()
        registerPlayerClient { client in
            client.currentPlaybackTime = { .seconds(177) }
        }
        defer { Container.shared.playerClient.reset() }

        let store = withDependencies {
            $0.databaseClient.saveWatchProgress = { savedItem, _ in
                await recorder.record(
                    id: savedItem.id,
                    type: savedItem.type,
                    progress: savedItem.progress,
                    duration: savedItem.duration
                )
            }
        } operation: {
            TestStore(initialState: initialState) { PlayerFeature() }
        }
        store.exhaustivity = .off

        await store.send(.closeTapped)
        let saved = await recorder.waitForSave()
        XCTAssertEqual(saved.id, item.id)
        XCTAssertEqual(saved.type, "episode")
        XCTAssertEqual(saved.progress, 177)
        XCTAssertEqual(saved.duration, 498)
    }

    func testDisappearSavesLatestEngineTimeForResumeProgress() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "episode-latest-progress-disappear",
            title: "Episode",
            seriesTitle: "Series",
            streamURL: XCTUnwrap(URL(string: "https://example.com/episode.m3u8")),
            seriesID: "series-1"
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.currentTime = .seconds(83)
        initialState.totalTime = .seconds(498)

        let recorder = SavedWatchProgressRecorder()
        registerPlayerClient { client in
            client.currentPlaybackTime = { .seconds(177) }
        }
        defer { Container.shared.playerClient.reset() }

        let store = withDependencies {
            $0.databaseClient.saveWatchProgress = { savedItem, _ in
                await recorder.record(
                    id: savedItem.id,
                    type: savedItem.type,
                    progress: savedItem.progress,
                    duration: savedItem.duration
                )
            }
        } operation: {
            TestStore(initialState: initialState) { PlayerFeature() }
        }
        store.exhaustivity = .off

        await store.send(.onDisappear)
        let saved = await recorder.waitForSave()
        XCTAssertEqual(saved.id, item.id)
        XCTAssertEqual(saved.type, "episode")
        XCTAssertEqual(saved.progress, 177)
        XCTAssertEqual(saved.duration, 498)
    }

    func testRestartPlaybackUsesOneConfirmedSeekThenResumes() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-2",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(300)
        initialState.position = 0.5
        let recorder = SeekCommandRecorder()
        registerPlayerClient { client in
            client.seekAndConfirm = { command in
                await recorder.record(command)
                return PlaybackSeekResult(currentTime: .zero, position: 0, status: .settled)
            }
            client.resume = { _ in }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) {
            PlayerFeature()
        }
        store.exhaustivity = .off

        await store.send(.restartPlayback) {
            $0.currentTime = .zero
            $0.position = 0
            $0.expectedVODSeekTargetSeconds = 0
            $0.vodSeekPreviousTime = .seconds(300)
            $0.vodSeekPreviousPosition = 0.5
        }

        _ = try XCTUnwrap(store.state.activeVODSeekRequestID)
        await store.receive(
            \.vodSeekCompleted
        ) {
            $0.activeVODSeekRequestID = nil
            $0.restartPlaybackAfterVODSeekRequestID = nil
            $0.expectedVODSeekTargetSeconds = 0
            $0.expectedVODSeekTargetPosition = nil
            $0.vodSeekPreviousTime = nil
            $0.vodSeekPreviousPosition = nil
        }
        await store.receive(\.play)

        let recordedCommands = await recorder.commandDescriptions
        XCTAssertEqual(recordedCommands, ["time:0"])
    }

    func testPauseDuringRestartSeekPreventsAutomaticResume() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-pause-restart",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        let requestID = UUID()
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .zero
        initialState.position = 0
        initialState.activeVODSeekRequestID = requestID
        initialState.restartPlaybackAfterVODSeekRequestID = requestID
        initialState.expectedVODSeekTargetSeconds = 0
        initialState.vodSeekPreviousTime = .seconds(300)
        initialState.vodSeekPreviousPosition = 0.5
        let playbackRequestID = initialState.playbackRequestID
        let resumeSpy = PlaybackResumeSpy()
        registerPlayerClient { client in
            client.pause = {}
            client.resume = { _ in resumeSpy.recordResume() }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) {
            PlayerFeature()
        }
        store.exhaustivity = .off

        await store.send(.pause)
        XCTAssertTrue(store.state.isUserPaused)
        XCTAssertNil(store.state.restartPlaybackAfterVODSeekRequestID)

        await store.send(
            .vodSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                playbackRequestID: playbackRequestID,
                result: PlaybackSeekResult(currentTime: .zero, position: 0, status: .settled)
            )
        )

        XCTAssertEqual(resumeSpy.resumeCount, 0)
        XCTAssertTrue(store.state.isUserPaused)
    }

    func testCatchupRestartCompletionDoesNotResumeAfterPause() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "catchup-pause-restart",
            title: "Channel",
            streamURL: XCTUnwrap(URL(string: "https://example.com/channel.m3u8")),
            isLive: true
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.activeCatchupProgram = EPGProgram(
            id: "program-1",
            title: "Program",
            description: "",
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            isPlayingNow: false
        )
        let requestID = UUID()
        initialState.activeCatchupSeekRequestID = requestID
        initialState.restartPlaybackAfterCatchupSeekRequestID = requestID
        initialState.isUserPaused = false
        let resumeSpy = PlaybackResumeSpy()
        registerPlayerClient { client in
            client.pause = {}
            client.resume = { _ in resumeSpy.recordResume() }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) {
            PlayerFeature()
        }
        store.exhaustivity = .off

        await store.send(.pause)
        XCTAssertTrue(store.state.isUserPaused)
        XCTAssertNil(store.state.restartPlaybackAfterCatchupSeekRequestID)
        await store.send(
            .catchupSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                result: CatchupSeekResult(currentTime: .zero, position: 0, didSucceed: true)
            )
        )

        XCTAssertEqual(resumeSpy.resumeCount, 0)
        XCTAssertTrue(store.state.isUserPaused)
    }

    func testFailedCatchupSeekRestoresPreviousTimeline() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "catchup-seek-failure",
            title: "Channel",
            streamURL: XCTUnwrap(URL(string: "https://example.com/channel.m3u8")),
            isLive: true
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.catchupArchiveDurationSeconds = 600
        initialState.activeCatchupProgram = EPGProgram(
            id: "program-2",
            title: "Program",
            description: "",
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            isPlayingNow: false
        )
        let requestID = UUID()
        initialState.activeCatchupSeekRequestID = requestID
        initialState.currentTime = .zero
        initialState.position = 0
        initialState.isUserPaused = true
        initialState.catchupSeekPreviousTime = .seconds(300)
        initialState.catchupSeekPreviousPosition = 0.5
        registerPlayerClient { client in
            client.catchupSeek = { _ in
                CatchupSeekResult(currentTime: .zero, position: 0, didSucceed: false)
            }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) {
            PlayerFeature()
        }
        store.exhaustivity = .off

        await store.send(
            .catchupSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                result: CatchupSeekResult(currentTime: .zero, position: 0, didSucceed: false)
            )
        )
        await store.receive(\.catchupSeekRollbackCompleted)

        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
        XCTAssertEqual(store.state.catchupSeekPreviousTime, .seconds(300))
        XCTAssertEqual(store.state.catchupSeekPreviousPosition, 0.5)
        XCTAssertNotNil(store.state.catchupSeekFailureMessage)
        XCTAssertTrue(store.state.catchupSeekTimelineRecoveryRequired)
        await store.send(.handlePlayerEvent(.timeChanged(.zero)))
        await store.send(.handlePlayerEvent(.positionChanged(0)))
        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
        XCTAssertTrue(store.state.catchupSeekTimelineRecoveryRequired)
        await store.send(.handlePlayerEvent(.timeChanged(.seconds(300))))
        await store.send(.handlePlayerEvent(.positionChanged(0.5)))
        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
        XCTAssertFalse(store.state.catchupSeekTimelineRecoveryRequired)
    }

    func testInaccurateCatchupSeekAcceptsNearbyKeyframeLanding() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "catchup-seek-inaccurate",
            title: "Channel",
            streamURL: XCTUnwrap(URL(string: "https://example.com/channel.m3u8")),
            isLive: true
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.catchupArchiveDurationSeconds = 600
        initialState.activeCatchupProgram = EPGProgram(
            id: "program-inaccurate",
            title: "Program",
            description: "",
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            isPlayingNow: false
        )
        let requestID = UUID()
        initialState.activeCatchupSeekRequestID = requestID
        initialState.catchupSeekExpectedTimeSeconds = 450
        initialState.catchupSeekPreviousTime = .seconds(300)
        initialState.catchupSeekPreviousPosition = 0.5

        let store = TestStore(initialState: initialState) { PlayerFeature() }
        store.exhaustivity = .off
        await store.send(
            .catchupSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                result: CatchupSeekResult(
                    currentTime: .seconds(438),
                    position: 438.0 / 600.0,
                    didSucceed: true,
                    status: .inaccurate
                )
            )
        )

        XCTAssertEqual(store.state.currentTime, .seconds(438))
        XCTAssertEqual(store.state.position, 438.0 / 600.0, accuracy: 0.0001)
        XCTAssertFalse(store.state.catchupSeekTimelineRecoveryRequired)
        XCTAssertNil(store.state.catchupSeekFailureMessage)
        XCTAssertEqual(store.state.catchupSeekExpectedTimeSeconds, 438)
        await store.send(.handlePlayerEvent(.timeChanged(.zero)))
        await store.send(.handlePlayerEvent(.positionChanged(0)))
        XCTAssertEqual(store.state.currentTime, .seconds(438))
        XCTAssertEqual(store.state.position, 438.0 / 600.0, accuracy: 0.0001)
        XCTAssertEqual(store.state.catchupSeekExpectedTimeSeconds, 438)
        await store.send(.handlePlayerEvent(.timeChanged(.seconds(439))))
        XCTAssertNil(store.state.catchupSeekExpectedTimeSeconds)
    }

    func testSettledVODSeekLandingFarFromTargetRestoresPriorTimelineAndShowsFailure() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-seek-mismatch",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        let requestID = UUID()
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(450)
        initialState.position = 0.75
        initialState.activeVODSeekRequestID = requestID
        initialState.expectedVODSeekTargetSeconds = 450
        initialState.vodSeekPreviousTime = .seconds(300)
        initialState.vodSeekPreviousPosition = 0.5
        let playbackRequestID = initialState.playbackRequestID
        let recorder = SeekCommandRecorder()
        registerPlayerClient { client in
            client.seekAndConfirm = { command in
                await recorder.record(command)
                switch command {
                case .time(.seconds(300)):
                    return PlaybackSeekResult(currentTime: .seconds(300), position: 0.5, status: .settled)
                default:
                    return PlaybackSeekResult(currentTime: .zero, position: 0, status: .settled)
                }
            }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) {
            PlayerFeature()
        }
        store.exhaustivity = .off

        await store.send(
            .vodSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                playbackRequestID: playbackRequestID,
                result: PlaybackSeekResult(currentTime: .zero, position: 0, status: .settled)
            )
        )

        let rollbackRequestID = try XCTUnwrap(store.state.activeVODSeekRequestID)
        XCTAssertNotEqual(rollbackRequestID, requestID)
        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
        await store.receive(\.vodSeekRollbackCompleted) {
            $0.activeVODSeekRequestID = nil
            $0.vodSeekPreviousTime = nil
            $0.vodSeekPreviousPosition = nil
            $0.vodSeekFailureRequestID = rollbackRequestID
        }

        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
        XCTAssertEqual(store.state.vodSeekFailureRequestID, rollbackRequestID)
        let recordedCommands = await recorder.commandDescriptions
        XCTAssertEqual(recordedCommands, ["time:300"])
    }

    func testInaccurateVODSeekAcceptsNearbyKeyframeLanding() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-seek-inaccurate",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        let requestID = UUID()
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(450)
        initialState.position = 0.75
        initialState.activeVODSeekRequestID = requestID
        initialState.expectedVODSeekTargetSeconds = 450
        initialState.vodSeekPreviousTime = .seconds(300)
        initialState.vodSeekPreviousPosition = 0.5
        let playbackRequestID = initialState.playbackRequestID

        let store = TestStore(initialState: initialState) {
            PlayerFeature()
        }
        store.exhaustivity = .off

        await store.send(
            .vodSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                playbackRequestID: playbackRequestID,
                result: PlaybackSeekResult(currentTime: .seconds(438), position: 438.0 / 600.0, status: .inaccurate)
            )
        )
        XCTAssertNil(store.state.vodSeekFailureRequestID)
        XCTAssertEqual(store.state.currentTime, .seconds(438))
        XCTAssertEqual(store.state.position, 438.0 / 600.0, accuracy: 0.0001)
    }

    func testTimedOutVODSeekRestoresEngineBeforeReleasingTimeline() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-seek-timeout",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        let requestID = UUID()
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(450)
        initialState.position = 0.75
        initialState.activeVODSeekRequestID = requestID
        initialState.expectedVODSeekTargetSeconds = 450
        initialState.vodSeekPreviousTime = .seconds(300)
        initialState.vodSeekPreviousPosition = 0.5
        let playbackRequestID = initialState.playbackRequestID
        registerPlayerClient { client in
            client.seekAndConfirm = { command in
                guard case .time(.seconds(300)) = command else {
                    return PlaybackSeekResult(currentTime: .zero, position: 0, status: .timedOut)
                }
                return PlaybackSeekResult(currentTime: .seconds(300), position: 0.5, status: .settled)
            }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) {
            PlayerFeature()
        }
        store.exhaustivity = .off

        await store.send(
            .vodSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                playbackRequestID: playbackRequestID,
                result: PlaybackSeekResult(currentTime: .zero, position: 0, status: .timedOut)
            )
        )

        let rollbackRequestID = try XCTUnwrap(store.state.activeVODSeekRequestID)
        XCTAssertNotEqual(rollbackRequestID, requestID)
        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
        await store.receive(\.vodSeekRollbackCompleted) {
            $0.activeVODSeekRequestID = nil
            $0.vodSeekPreviousTime = nil
            $0.vodSeekPreviousPosition = nil
            $0.vodSeekFailureRequestID = rollbackRequestID
        }
    }

    func testTimedOutVODSeekThatLandedAtTargetDoesNotRollback() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-seek-timeout-landed",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        let requestID = UUID()
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(450)
        initialState.position = 0.75
        initialState.activeVODSeekRequestID = requestID
        initialState.expectedVODSeekTargetSeconds = 450
        initialState.vodSeekPreviousTime = .seconds(300)
        initialState.vodSeekPreviousPosition = 0.5
        let playbackRequestID = initialState.playbackRequestID
        let recorder = SeekCommandRecorder()
        registerPlayerClient { client in
            client.seekAndConfirm = { command in
                await recorder.record(command)
                return PlaybackSeekResult(
                    currentTime: .seconds(300),
                    position: 0.5,
                    status: .settled
                )
            }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) { PlayerFeature() }
        store.exhaustivity = .off

        await store.send(
            .vodSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                playbackRequestID: playbackRequestID,
                result: PlaybackSeekResult(
                    currentTime: .seconds(450),
                    position: 0.75,
                    status: .timedOut
                )
            )
        ) {
            $0.activeVODSeekRequestID = nil
            $0.expectedVODSeekTargetSeconds = 450
            $0.expectedVODSeekTargetPosition = nil
            $0.vodSeekPreviousTime = nil
            $0.vodSeekPreviousPosition = nil
            $0.vodSeekFailureRequestID = nil
        }

        XCTAssertEqual(store.state.currentTime, .seconds(450))
        XCTAssertEqual(store.state.position, 0.75)
        let commands = await recorder.commandDescriptions
        XCTAssertTrue(commands.isEmpty, "A confirmed target landing must not issue a rollback seek")
    }

    func testRejectedVODSeekStartsConfirmedRollback() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-seek-rejected",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        let requestID = UUID()
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(450)
        initialState.position = 0.75
        initialState.activeVODSeekRequestID = requestID
        initialState.expectedVODSeekTargetSeconds = 450
        initialState.vodSeekPreviousTime = .seconds(300)
        initialState.vodSeekPreviousPosition = 0.5
        let playbackRequestID = initialState.playbackRequestID
        let recorder = SeekCommandRecorder()
        registerPlayerClient { client in
            client.seekAndConfirm = { command in
                await recorder.record(command)
                guard case .time(.seconds(300)) = command else {
                    return PlaybackSeekResult(currentTime: .zero, position: 0, status: .rejected)
                }
                return PlaybackSeekResult(currentTime: .seconds(300), position: 0.5, status: .settled)
            }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) { PlayerFeature() }
        store.exhaustivity = .off

        await store.send(
            .vodSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                playbackRequestID: playbackRequestID,
                result: PlaybackSeekResult(currentTime: .zero, position: 0, status: .rejected)
            )
        )
        let rollbackRequestID = try XCTUnwrap(store.state.activeVODSeekRequestID)
        XCTAssertNotEqual(rollbackRequestID, requestID)
        XCTAssertEqual(store.state.currentTime, .seconds(300))

        await store.receive(\.vodSeekRollbackCompleted) {
            $0.activeVODSeekRequestID = nil
            $0.vodSeekPreviousTime = nil
            $0.vodSeekPreviousPosition = nil
            $0.vodSeekFailureRequestID = rollbackRequestID
        }
        let recordedCommands = await recorder.commandDescriptions
        XCTAssertEqual(recordedCommands, ["time:300"])
        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
    }

    func testFailedVODRollbackRecoversTimelineFromValidEngineEvents() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-seek-rollback-failed",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        let requestID = UUID()
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(450)
        initialState.position = 0.75
        initialState.isUserPaused = true
        initialState.activeVODSeekRequestID = requestID
        initialState.expectedVODSeekTargetSeconds = 450
        initialState.vodSeekPreviousTime = .seconds(300)
        initialState.vodSeekPreviousPosition = 0.5
        let playbackRequestID = initialState.playbackRequestID
        registerPlayerClient { client in
            client.seekAndConfirm = { command in
                if case .time(.seconds(300)) = command {
                    return PlaybackSeekResult(currentTime: .zero, position: 0, status: .settled)
                }
                return PlaybackSeekResult(currentTime: .zero, position: 0, status: .settled)
            }
        }
        defer { Container.shared.playerClient.reset() }

        let store = TestStore(initialState: initialState) { PlayerFeature() }
        store.exhaustivity = .off
        await store.send(
            .vodSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                playbackRequestID: playbackRequestID,
                result: PlaybackSeekResult(currentTime: .zero, position: 0, status: .settled)
            )
        )
        let rollbackRequestID = try XCTUnwrap(store.state.activeVODSeekRequestID)
        await store.receive(\.vodSeekRollbackCompleted) {
            $0.activeVODSeekRequestID = nil
            $0.vodSeekPreviousTime = .seconds(300)
            $0.vodSeekPreviousPosition = 0.5
            $0.vodSeekTimelineRecoveryRequired = true
            $0.vodSeekFailureRequestID = rollbackRequestID
        }

        XCTAssertNil(store.state.activeVODSeekRequestID)
        XCTAssertTrue(store.state.vodSeekTimelineRecoveryRequired)
        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
        await store.send(.handlePlayerEvent(.timeChanged(.zero)))
        await store.send(.handlePlayerEvent(.positionChanged(0)))
        XCTAssertTrue(store.state.vodSeekTimelineRecoveryRequired)
        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
        await store.send(.handlePlayerEvent(.timeChanged(.seconds(301))))
        await store.send(.handlePlayerEvent(.positionChanged(301.0 / 600.0)))
        XCTAssertEqual(store.state.currentTime, .seconds(301))
        XCTAssertEqual(store.state.position, 301.0 / 600.0, accuracy: 0.0001)
        XCTAssertFalse(store.state.vodSeekTimelineRecoveryRequired)
    }

    func testSuccessfulVODSeekIgnoresDelayedPreSeekTimelineEvents() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-seek-delayed-timeline",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        let requestID = UUID()
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(450)
        initialState.position = 0.75
        initialState.activeVODSeekRequestID = requestID
        initialState.expectedVODSeekTargetSeconds = 450
        initialState.vodSeekPreviousTime = .seconds(300)
        initialState.vodSeekPreviousPosition = 0.5
        let playbackRequestID = initialState.playbackRequestID

        let store = TestStore(initialState: initialState) { PlayerFeature() }
        store.exhaustivity = .off
        await store.send(
            .vodSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                playbackRequestID: playbackRequestID,
                result: PlaybackSeekResult(currentTime: .seconds(450), position: 0.75, status: .settled)
            )
        )

        XCTAssertEqual(store.state.currentTime, .seconds(450))
        XCTAssertEqual(store.state.expectedVODSeekTargetSeconds, 450)
        await store.send(.handlePlayerEvent(.timeChanged(.zero)))
        await store.send(.handlePlayerEvent(.positionChanged(0)))
        XCTAssertEqual(store.state.currentTime, .seconds(450))
        XCTAssertEqual(store.state.position, 0.75)
        XCTAssertEqual(store.state.expectedVODSeekTargetSeconds, 450)

        await store.send(.handlePlayerEvent(.timeChanged(.seconds(451))))
        XCTAssertEqual(store.state.currentTime, .seconds(451))
        XCTAssertNil(store.state.expectedVODSeekTargetSeconds)
    }

    func testVODStallWatchdogRearmsAfterDeferringReconnectForSeek() async throws {
        let clock = TestClock()
        let item = try PlayerFeature.PlayableItem(
            id: "movie-seek-buffering-watchdog",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        let seekRequestID = UUID()
        var initialState = PlayerFeature.State(item: item)
        initialState.playerState = .buffering
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(200)
        initialState.position = 1.0 / 3.0
        initialState.activeVODSeekRequestID = seekRequestID
        initialState.expectedVODSeekTargetSeconds = 200
        initialState.vodSeekPreviousTime = .seconds(100)
        initialState.vodSeekPreviousPosition = 1.0 / 6.0
        initialState.maxReconnectAttempts = 0
        let playbackRequestID = initialState.playbackRequestID

        let store = TestStore(initialState: initialState) {
            PlayerFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }
        store.exhaustivity = .off

        await store.send(.handlePlayerEvent(.stateChanged(.buffering)))

        await clock.advance(by: .seconds(45))
        await store.receive(\.streamStalled)
        XCTAssertNil(store.state.errorMessage)
        XCTAssertFalse(store.state.isReconnecting)

        await store.send(
            .vodSeekCompleted(
                requestID: seekRequestID,
                itemID: item.id,
                playbackRequestID: playbackRequestID,
                result: PlaybackSeekResult(
                    currentTime: .seconds(200),
                    position: 1.0 / 3.0,
                    status: .settled
                )
            )
        )
        XCTAssertNil(store.state.activeVODSeekRequestID)

        await clock.advance(by: .seconds(45))
        await store.receive(\.streamStalled)
        await store.receive(\.initiateAutoReconnect)
        XCTAssertTrue(store.state.errorMessage != nil)
    }

    func testPlayAfterFailedVODSeekStartsRecoveryFromLastConfirmedPosition() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-seek-recovery-resume",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(300)
        initialState.position = 0.5
        initialState.isUserPaused = true
        initialState.vodSeekTimelineRecoveryRequired = true
        initialState.vodSeekPreviousTime = .seconds(300)
        initialState.vodSeekPreviousPosition = 0.5

        let store = TestStore(initialState: initialState) { PlayerFeature() }
        store.exhaustivity = .off

        await store.send(.play)
        await store.receive(\.initiateAutoReconnect)

        XCTAssertFalse(store.state.isUserPaused)
        XCTAssertTrue(store.state.isReconnecting)
        XCTAssertEqual(store.state.retryCount, 1)
        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
    }

    func testMislandedCatchupSeekCompensatesToPreviousPosition() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "catchup-seek-mislanded",
            title: "Channel",
            streamURL: XCTUnwrap(URL(string: "https://example.com/channel.m3u8")),
            isLive: true
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.activeCatchupProgram = EPGProgram(
            id: "program-mislanded",
            title: "Program",
            description: "",
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            isPlayingNow: false
        )
        initialState.catchupArchiveDurationSeconds = 600
        initialState.activeCatchupSeekRequestID = UUID()
        initialState.catchupSeekExpectedTimeSeconds = 450
        initialState.catchupSeekPreviousTime = .seconds(300)
        initialState.catchupSeekPreviousPosition = 0.5
        let recorder = SeekCommandRecorder()
        registerPlayerClient { client in
            client.catchupSeek = { command in
                switch command {
                case let .time(time, _):
                    await recorder.record(.time(time))
                    return CatchupSeekResult(currentTime: time, position: 0.5, didSucceed: true)
                case .relative, .position:
                    return CatchupSeekResult(currentTime: .zero, position: 0, didSucceed: true)
                }
            }
        }
        defer { Container.shared.playerClient.reset() }
        let store = TestStore(initialState: initialState) { PlayerFeature() }
        store.exhaustivity = .off
        let requestID = try XCTUnwrap(initialState.activeCatchupSeekRequestID)

        await store.send(
            .catchupSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                result: CatchupSeekResult(currentTime: .zero, position: 0, didSucceed: true)
            )
        )
        let rollbackRequestID = try XCTUnwrap(store.state.activeCatchupSeekRequestID)
        XCTAssertNotEqual(rollbackRequestID, requestID)
        XCTAssertEqual(store.state.currentTime, .seconds(300))
        await store.receive(\.catchupSeekRollbackCompleted) {
            $0.activeCatchupSeekRequestID = nil
            $0.catchupSeekPreviousTime = nil
            $0.catchupSeekPreviousPosition = nil
            $0.catchupSeekExpectedTimeSeconds = 300
            $0.catchupSeekFailureRequestID = rollbackRequestID
        }
        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
        let commands = await recorder.commandDescriptions
        XCTAssertEqual(commands, ["time:300"])
    }

    func testRejectedCatchupSeekAlsoRestoresEngine() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "catchup-seek-rejected",
            title: "Channel",
            streamURL: XCTUnwrap(URL(string: "https://example.com/channel.m3u8")),
            isLive: true
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.activeCatchupProgram = EPGProgram(
            id: "program-rejected",
            title: "Program",
            description: "",
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            isPlayingNow: false
        )
        initialState.catchupArchiveDurationSeconds = 600
        let requestID = UUID()
        initialState.activeCatchupSeekRequestID = requestID
        initialState.catchupSeekExpectedTimeSeconds = 450
        initialState.catchupSeekPreviousTime = .seconds(300)
        initialState.catchupSeekPreviousPosition = 0.5
        let recorder = SeekCommandRecorder()
        registerPlayerClient { client in
            client.catchupSeek = { command in
                switch command {
                case let .time(time, _):
                    await recorder.record(.time(time))
                    return CatchupSeekResult(currentTime: time, position: 0.5, didSucceed: true)
                case .relative, .position:
                    return CatchupSeekResult(currentTime: .zero, position: 0, didSucceed: false)
                }
            }
        }
        defer { Container.shared.playerClient.reset() }
        let store = TestStore(initialState: initialState) { PlayerFeature() }
        store.exhaustivity = .off

        await store.send(
            .catchupSeekCompleted(
                requestID: requestID,
                itemID: item.id,
                result: CatchupSeekResult(currentTime: .zero, position: 0, didSucceed: false)
            )
        )
        let rollbackRequestID = try XCTUnwrap(store.state.activeCatchupSeekRequestID)
        await store.receive(\.catchupSeekRollbackCompleted)
        XCTAssertNotNil(store.state.catchupSeekFailureMessage)
        XCTAssertEqual(store.state.currentTime, .seconds(300))
        let commands = await recorder.commandDescriptions
        XCTAssertEqual(commands, ["time:300"])
        XCTAssertNotEqual(rollbackRequestID, requestID)
    }

    func testResumeRecoveryRejectsValidButWrongLandingPosition() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-resume-wrong-position",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(300)
        initialState.position = 0.5
        initialState.playbackRequestID = UUID()
        initialState.playbackPositionRecoveryRequestID = initialState.playbackRequestID
        initialState.playbackPositionRecoveryExpectedPosition = 0.5
        initialState.isReconnecting = true
        let store = TestStore(initialState: initialState) { PlayerFeature() }
        store.exhaustivity = .off

        await store.send(
            .playbackPositionRecoveryFinished(
                PlaybackSeekResult(currentTime: .zero, position: 0, status: .settled),
                itemID: item.id,
                playbackRequestID: initialState.playbackRequestID
            )
        )

        XCTAssertEqual(store.state.currentTime, .seconds(300))
        XCTAssertEqual(store.state.position, 0.5)
        XCTAssertFalse(store.state.isReconnecting)
    }

    func testResumeRecoveryAcceptsNearbyInaccurateKeyframeLanding() async throws {
        let item = try PlayerFeature.PlayableItem(
            id: "movie-resume-inaccurate-position",
            title: "Movie",
            streamURL: XCTUnwrap(URL(string: "https://example.com/movie.m3u8"))
        )
        var initialState = PlayerFeature.State(item: item)
        initialState.totalTime = .seconds(600)
        initialState.currentTime = .seconds(300)
        initialState.position = 0.5
        initialState.playbackRequestID = UUID()
        initialState.playbackPositionRecoveryRequestID = initialState.playbackRequestID
        initialState.playbackPositionRecoveryExpectedPosition = 0.5
        initialState.isReconnecting = true
        let store = TestStore(initialState: initialState) { PlayerFeature() }
        store.exhaustivity = .off

        await store.send(
            .playbackPositionRecoveryFinished(
                PlaybackSeekResult(currentTime: .seconds(288), position: 0.48, status: .inaccurate),
                itemID: item.id,
                playbackRequestID: initialState.playbackRequestID
            )
        )

        XCTAssertEqual(store.state.currentTime, .seconds(288))
        XCTAssertEqual(store.state.position, 0.48)
        XCTAssertFalse(store.state.isReconnecting)
    }
}

@MainActor
private func registerPlayerClient(_ update: (inout PlayerClient) -> Void) {
    Container.shared.playerClient.reset()
    var client = PlayerClient.testValue
    update(&client)
    let registeredClient = client
    Container.shared.playerClient.register { registeredClient }
}

private actor SeekCommandRecorder {
    private(set) var commandDescriptions: [String] = []
    private(set) var timeTargets: [Duration] = []

    func record(_ command: PlaybackSeekCommand) {
        switch command {
        case let .time(time):
            commandDescriptions.append("time:\(time.components.seconds)")
            timeTargets.append(time)
        case let .position(position):
            commandDescriptions.append("position:\(position)")
        case let .relative(seconds):
            commandDescriptions.append("relative:\(seconds)")
        }
    }
}

private actor SavedWatchProgressRecorder {
    struct Snapshot: Equatable {
        let id: String
        let type: String
        let progress: Double
        let duration: Double
    }

    private(set) var savedProgress: Snapshot?
    private var waiter: CheckedContinuation<Snapshot, Never>?

    func record(id: String, type: String, progress: Double, duration: Double) {
        let snapshot = Snapshot(id: id, type: type, progress: progress, duration: duration)
        savedProgress = snapshot
        waiter?.resume(returning: snapshot)
        waiter = nil
    }

    func waitForSave() async -> Snapshot {
        if let savedProgress {
            return savedProgress
        }
        return await withCheckedContinuation { continuation in
            waiter = continuation
        }
    }
}

@MainActor
private final class PlaybackResumeSpy {
    private(set) var resumeCount = 0

    func recordResume() {
        resumeCount += 1
    }
}
