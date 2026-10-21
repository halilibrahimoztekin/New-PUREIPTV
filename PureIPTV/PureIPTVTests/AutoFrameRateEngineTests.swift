import ComposableArchitecture
import Foundation
@testable import PureIPTV
import XCTest

final class AutoFrameRateEngineTests: XCTestCase {
    // MARK: - 1. FrameRate Enum & Properties Tests

    func testFrameRateProperties() {
        XCTAssertEqual(FrameRate.fps23_976.displayHz, 24.0)
        XCTAssertEqual(FrameRate.fps24.displayHz, 24.0)
        XCTAssertEqual(FrameRate.fps25.displayHz, 50.0)
        XCTAssertEqual(FrameRate.fps29_97.displayHz, 60.0)
        XCTAssertEqual(FrameRate.fps30.displayHz, 60.0)
        XCTAssertEqual(FrameRate.fps50.displayHz, 50.0)
        XCTAssertEqual(FrameRate.fps59_94.displayHz, 60.0)
        XCTAssertEqual(FrameRate.fps60.displayHz, 60.0)
        XCTAssertEqual(FrameRate.fps120.displayHz, 120.0)

        XCTAssertTrue(FrameRate.fps23_976.isCinematic)
        XCTAssertTrue(FrameRate.fps24.isCinematic)
        XCTAssertFalse(FrameRate.fps50.isCinematic)
        XCTAssertFalse(FrameRate.fps60.isCinematic)

        XCTAssertEqual(FrameRate.fps24.displayString, "24.00 Hz")
        XCTAssertEqual(FrameRate.fps50.displayString, "50.00 Hz")
        XCTAssertEqual(FrameRate.fps60.displayString, "60.00 Hz")

        for rate in FrameRate.allCases {
            XCTAssertFalse(rate.label.isEmpty)
        }
    }

    // MARK: - 2. FrameRateDetector Regex & Heuristics Tests

    func test50FPSDetection() {
        let sample1 = "Sky Sports Premier League HD 50fps"
        XCTAssertEqual(FrameRateDetector.detect(title: sample1, isLive: true), .fps50)

        let sample2 = "TRT Spor Yıldız 50 Hz Canlı"
        XCTAssertEqual(FrameRateDetector.detect(title: sample2, isLive: true), .fps50)

        let sample3 = "BeIN Sports 1 1080p 50 FPS"
        XCTAssertEqual(FrameRateDetector.detect(title: sample3, isLive: true), .fps50)
    }

    func test60FPSDetection() {
        let sample1 = "Fox Sports 1 UHD 60fps"
        XCTAssertEqual(FrameRateDetector.detect(title: sample1, isLive: true), .fps60)

        let sample2 = "ESPN 2 HD 60Hz"
        XCTAssertEqual(FrameRateDetector.detect(title: sample2, isLive: true), .fps60)

        let sample3 = "CBS Sports Network 59.94"
        XCTAssertEqual(FrameRateDetector.detect(title: sample3, isLive: true), .fps60)
    }

    func test24FPSCinematicDetection() {
        let sample1 = "Interstellar (2014) [4K UHD] [24fps] [Atmos]"
        XCTAssertEqual(FrameRateDetector.detect(title: sample1, isLive: false), .fps24)

        let sample2 = "Dune: Part Two 23.976fps Remux"
        XCTAssertEqual(FrameRateDetector.detect(title: sample2, isLive: false), .fps24)

        let sample3 = "Oppenheimer (2023) 24p TrueHD"
        XCTAssertEqual(FrameRateDetector.detect(title: sample3, isLive: false), .fps24)
    }

    func test25And30FPSDetection() {
        let sample25 = "BBC News 1080p 25fps"
        XCTAssertEqual(FrameRateDetector.detect(title: sample25, isLive: true), .fps25)

        let sample30 = "NASA TV Public HD 30fps"
        XCTAssertEqual(FrameRateDetector.detect(title: sample30, isLive: true), .fps30)
    }

    func testHeuristicFallbacks() {
        // VOD movies without explicit tag should default to 24p cinematic
        let vodMovie = "The Matrix Resurrections (2021) 1080p"
        XCTAssertEqual(FrameRateDetector.detect(title: vodMovie, isLive: false), .fps24)

        // Live broadcast without explicit tag should default to 50fps broadcast standard
        let liveChannel = "HaberTurk TV HD"
        XCTAssertEqual(FrameRateDetector.detect(title: liveChannel, isLive: true), .fps50)
    }

    // MARK: - 3. DisplayModeClient & Matching Logic Tests

    func testDisplayModeClientSwitch() async {
        let client = DisplayModeClient.liveValue

        // Switch to 24p with Dolby Vision
        let result24 = await client.switchDisplayMode(24.0, .dolbyVision)
        XCTAssertEqual(result24.matchedRate, 24.0)
        XCTAssertEqual(result24.matchedRange, .dolbyVision)
        XCTAssertTrue(result24.isJudderFree)
        XCTAssertTrue(result24.message.contains("24 Hz Sinematik"))
        XCTAssertTrue(result24.message.contains("DV"))

        // Switch to 50fps live TV with HDR10
        let result50 = await client.switchDisplayMode(50.0, .hdr10)
        XCTAssertEqual(result50.matchedRate, 50.0)
        XCTAssertEqual(result50.matchedRange, .hdr10)
        XCTAssertTrue(result50.isJudderFree)
        XCTAssertTrue(result50.message.contains("50 Hz Canlı Spor Eşleme"))
        XCTAssertTrue(result50.message.contains("HDR"))

        // Switch to 60fps with SDR
        let result60 = await client.switchDisplayMode(60.0, .sdr)
        XCTAssertEqual(result60.matchedRate, 60.0)
        XCTAssertEqual(result60.matchedRange, .sdr)
        XCTAssertTrue(result60.isJudderFree)
        XCTAssertTrue(result60.message.contains("60 Hz Akıcı Mod"))
    }

    // MARK: - 4. PlayerFeature AFR Integration Tests

    func testPlayerFeatureAFRStateAndActions() async throws {
        let streamURL = try XCTUnwrap(URL(string: "http://example.com/stream.m3u8"))
        let cinematicMovie = PlayerFeature.PlayableItem(
            id: "vod_movie",
            title: "Oppenheimer (2023) [4K UHD] [24fps]",
            streamURL: streamURL,
            isLive: false
        )

        // State init automatically analyzes title and sets currentFrameRate
        var state = PlayerFeature.State(item: cinematicMovie)
        XCTAssertEqual(state.currentFrameRate, .fps24)
        XCTAssertTrue(state.isAFREnabled)
        XCTAssertFalse(state.isAFRToastVisible)

        let store = TestStore(initialState: state) {
            PlayerFeature()
        } withDependencies: {
            $0.displayModeClient = .init(
                isAFREnabled: { true },
                setAFREnabled: { _ in },
                isMatchDynamicRangeEnabled: { true },
                setMatchDynamicRangeEnabled: { _ in },
                currentDisplayRefreshRate: { 60.0 },
                availableRefreshRates: { [24.0, 50.0, 60.0] },
                switchDisplayMode: { rate, range in
                    DisplayMatchResult(matchedRate: rate, matchedRange: range, message: "\(Int(rate)) Hz • Eşlendi")
                },
                resetDisplayMode: {}
            )
        }

        // 1. Toggle AFR Enabled to false
        await store.send(.setAFREnabled(false)) {
            $0.isAFREnabled = false
        }

        // 2. Toggle Match Dynamic Range to false
        await store.send(.setMatchDynamicRangeEnabled(false)) {
            $0.isMatchDynamicRangeEnabled = false
        }

        // 3. Re-enable AFR
        await store.send(.setAFREnabled(true)) {
            $0.isAFREnabled = true
        }

        // 4. Trigger displayModeSwitched
        let matchResult = DisplayMatchResult(matchedRate: 24.0, matchedRange: .dolbyVision, message: "24 Hz Sinematik Eşleme")
        await store.send(.displayModeSwitched(matchResult)) {
            $0.afrMatchResult = matchResult
            $0.isAFRToastVisible = true
        }

        // 5. Hide AFR toast
        await store.send(.hideAFRToast) {
            $0.isAFRToastVisible = false
        }

        // 6. Manual show AFR toast
        await store.send(.showAFRToast(matchResult)) {
            $0.afrMatchResult = matchResult
            $0.isAFRToastVisible = true
        }

        // 7. Hide again
        await store.send(.hideAFRToast) {
            $0.isAFRToastVisible = false
        }
    }
}
