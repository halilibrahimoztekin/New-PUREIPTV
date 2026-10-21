import ComposableArchitecture
import Foundation
@testable import PureIPTV
import XCTest

@MainActor
final class TraktSyncEngineTests: XCTestCase {
    func testTraktMediaParserMovie() {
        let title1 = "Inception (2010) [1080p] [Dual].mkv"
        let parsed1 = TraktMediaParser.parse(title: title1)
        XCTAssertEqual(parsed1.cleanTitle, "Inception")
        XCTAssertEqual(parsed1.year, 2010)
        XCTAssertFalse(parsed1.isEpisode)
        XCTAssertNil(parsed1.season)
        XCTAssertNil(parsed1.episode)

        let title2 = "The Dark Knight 2008 4K UHD Remux"
        let parsed2 = TraktMediaParser.parse(title: title2)
        XCTAssertEqual(parsed2.cleanTitle, "The Dark Knight")
        XCTAssertEqual(parsed2.year, 2008)
        XCTAssertFalse(parsed2.isEpisode)
    }

    func testTraktMediaParserSeriesEpisode() {
        let title1 = "Breaking Bad S01E05 720p HD.mp4"
        let parsed1 = TraktMediaParser.parse(title: title1)
        XCTAssertEqual(parsed1.cleanTitle, "Breaking Bad")
        XCTAssertEqual(parsed1.season, 1)
        XCTAssertEqual(parsed1.episode, 5)
        XCTAssertTrue(parsed1.isEpisode)

        let title2 = "Game of Thrones 03x09 The Rains of Castamere"
        let parsed2 = TraktMediaParser.parse(title: title2)
        XCTAssertTrue(parsed2.cleanTitle.contains("Game of Thrones"))
        XCTAssertEqual(parsed2.season, 3)
        XCTAssertEqual(parsed2.episode, 9)
        XCTAssertTrue(parsed2.isEpisode)

        let title3 = "S02E10 Finale"
        let parsed3 = TraktMediaParser.parse(title: title3, seriesTitle: "Stranger Things")
        XCTAssertEqual(parsed3.cleanTitle, "Stranger Things")
        XCTAssertEqual(parsed3.season, 2)
        XCTAssertEqual(parsed3.episode, 10)
        XCTAssertTrue(parsed3.isEpisode)
    }

    func testTraktScrobblePayloadBuilder() {
        // Live stream should NOT generate Trakt scrobble payload
        let livePayload = TraktMediaParser.makePayload(
            title: "TRT 1 HD",
            isLive: true,
            progress: 50.0
        )
        XCTAssertNil(livePayload)

        // VOD stream generates valid payload with clamped progress
        let vodPayload = TraktMediaParser.makePayload(
            title: "Interstellar (2014) 1080p",
            isLive: false,
            progress: 45.5
        )
        XCTAssertNotNil(vodPayload)
        XCTAssertEqual(vodPayload?.title, "Interstellar")
        XCTAssertEqual(vodPayload?.year, 2014)
        XCTAssertEqual(vodPayload?.progress, 45.5)
        XCTAssertFalse(vodPayload?.isEpisode ?? true)

        // Progress clamp check
        let overPayload = TraktMediaParser.makePayload(
            title: "Avatar 2009",
            isLive: false,
            progress: 150.0
        )
        XCTAssertEqual(overPayload?.progress, 100.0)
    }

    func testTraktClientAutoScrobbleToggle() {
        let client = TraktClient.liveValue
        client.setAutoScrobbleEnabled(false)
        XCTAssertFalse(client.isAutoScrobbleEnabled())

        client.setAutoScrobbleEnabled(true)
        XCTAssertTrue(client.isAutoScrobbleEnabled())
    }

    func testTraktFeatureAuthFlow() async {
        let mockDeviceCode = TraktDeviceCode(
            deviceCode: "dev-code-123",
            userCode: "WDPA50TW",
            verificationURL: "https://trakt.tv/activate",
            expiresIn: 600,
            interval: 5
        )

        let clock = TestClock()
        let store = TestStore(initialState: TraktFeature.State()) {
            TraktFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.traktClient.isAuthenticated = { false }
            $0.traktClient.currentUser = { nil }
            $0.traktClient.isAutoScrobbleEnabled = { true }
            $0.traktClient.generateDeviceCode = { mockDeviceCode }
            $0.traktClient.pollDeviceToken = { _ in nil } // Pending
            $0.traktClient.logout = {}
        }

        // 1. Initial State
        await store.send(.onAppear)

        // 2. Start Auth
        await store.send(.startDeviceAuth) {
            $0.isAuthorizing = true
            $0.authError = nil
            $0.deviceCodeInfo = nil
        }

        await store.receive(\.deviceCodeResponse.success) {
            $0.deviceCodeInfo = mockDeviceCode
        }

        // 3. Toggle Auto-Scrobble
        await store.send(.toggleAutoScrobble(false)) {
            $0.isAutoScrobbleEnabled = false
        }

        // 4. Cancel Auth
        await store.send(.cancelAuth) {
            $0.isAuthorizing = false
            $0.deviceCodeInfo = nil
        }

        // 5. Logout (no state change when already logged out)
        await store.send(.logout)
    }
}
