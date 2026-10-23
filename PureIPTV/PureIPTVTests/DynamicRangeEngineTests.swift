import ComposableArchitecture
import Foundation
@testable import PureIPTV
import XCTest

final class DynamicRangeEngineTests: XCTestCase {
    // MARK: - 1. ColorSpaceDetector Text Analysis Tests

    func testDolbyVisionDetection() {
        let sample1 = "Spider-Man: Across the Spider-Verse (2023) [4K UHD] [Dolby Vision] [Atmos]"
        let info1 = ColorSpaceDetector.detectFromText(title: sample1)
        XCTAssertEqual(info1.range, .dolbyVision)
        XCTAssertEqual(info1.detectedResolution, "4K UHD")
        XCTAssertTrue(info1.range.isHDR)
        XCTAssertEqual(info1.range.shortBadge, "DV")
        XCTAssertEqual(info1.range.badgeTitle, "DOLBY VISION")
        XCTAssertEqual(info1.bitDepth, 12)

        let sample2 = "Avatar: The Way of Water 2160p DoVi Profile 8"
        let info2 = ColorSpaceDetector.detectFromText(title: sample2)
        XCTAssertEqual(info2.range, .dolbyVision)

        let sample3 = "Formula 1: Monaco GP Live"
        let url3 = "http://iptv.example.com/live/user/pass/stream.m3u8?format=dvh1"
        let info3 = ColorSpaceDetector.detectFromText(title: sample3, urlString: url3)
        XCTAssertEqual(info3.range, .dolbyVision)
    }

    func testHDR10PlusDetection() {
        let sample = "Top Gun: Maverick (2022) 2160p UHD HDR10+ TrueHD"
        let info = ColorSpaceDetector.detectFromText(title: sample)
        XCTAssertEqual(info.range, .hdr10Plus)
        XCTAssertEqual(info.detectedResolution, "4K UHD")
        XCTAssertTrue(info.range.isHDR)
        XCTAssertEqual(info.range.shortBadge, "HDR10+")
        XCTAssertEqual(info.bitDepth, 10)
    }

    func testHDR10Detection() {
        let sample1 = "Sky Sports Main Event 4K HDR10 50fps"
        let info1 = ColorSpaceDetector.detectFromText(title: sample1)
        XCTAssertEqual(info1.range, .hdr10)
        XCTAssertEqual(info1.detectedResolution, "4K UHD")
        XCTAssertTrue(info1.range.isHDR)
        XCTAssertEqual(info1.range.shortBadge, "HDR")
        XCTAssertEqual(info1.bitDepth, 10)

        let sample2 = "TRT 4K HDR Canlı Yayın"
        let info2 = ColorSpaceDetector.detectFromText(title: sample2)
        XCTAssertEqual(info2.range, .hdr10)

        let sample3 = "Inception (2010) 1080p FHD BT.2020 10bit"
        let info3 = ColorSpaceDetector.detectFromText(title: sample3)
        XCTAssertEqual(info3.range, .hdr10)
        XCTAssertEqual(info3.detectedResolution, "1080p FHD")
    }

    func testHLGDetection() {
        let sample = "BBC One UHD HLG Live Broadcast"
        let info = ColorSpaceDetector.detectFromText(title: sample)
        XCTAssertEqual(info.range, .hlg)
        XCTAssertEqual(info.detectedResolution, "4K UHD")
        XCTAssertTrue(info.range.isHDR)
        XCTAssertEqual(info.range.shortBadge, "HLG")
        XCTAssertEqual(info.range.badgeTitle, "HLG")
        XCTAssertEqual(info.bitDepth, 10)
    }

    func testSDRDetectionAndFallback() {
        let sample1 = "Kanal D HD 1080p SDR"
        let info1 = ColorSpaceDetector.detectFromText(title: sample1)
        XCTAssertEqual(info1.range, .sdr)
        XCTAssertEqual(info1.detectedResolution, "1080p FHD")
        XCTAssertFalse(info1.range.isHDR)
        XCTAssertEqual(info1.bitDepth, 8)

        let sample2 = "Eurosport 1 Live"
        let info2 = ColorSpaceDetector.detectFromText(title: sample2)
        XCTAssertEqual(info2.range, .sdr)
        XCTAssertFalse(info2.range.isHDR)
    }

    // MARK: - 2. VideoDynamicRange Properties Tests

    func testVideoDynamicRangeProperties() {
        for range in VideoDynamicRange.allCases {
            XCTAssertFalse(range.displayName.isEmpty)
            XCTAssertFalse(range.badgeTitle.isEmpty)
            XCTAssertFalse(range.shortBadge.isEmpty)
            XCTAssertFalse(range.iconName.isEmpty)
            XCTAssertFalse(range.primaryColorHex.isEmpty)
            XCTAssertGreaterThanOrEqual(range.gradientHexes.count, 2)
            XCTAssertFalse(range.colorGamut.isEmpty)
            XCTAssertFalse(range.transferFunction.isEmpty)
            XCTAssertFalse(range.peakLuminanceDescription.isEmpty)
            XCTAssertGreaterThanOrEqual(range.bitDepth, 8)
        }

        XCTAssertTrue(VideoDynamicRange.dolbyVision.isHDR)
        XCTAssertTrue(VideoDynamicRange.hdr10Plus.isHDR)
        XCTAssertTrue(VideoDynamicRange.hdr10.isHDR)
        XCTAssertTrue(VideoDynamicRange.hlg.isHDR)
        XCTAssertFalse(VideoDynamicRange.sdr.isHDR)
        XCTAssertFalse(VideoDynamicRange.unknown.isHDR)
    }

    // MARK: - 3. PlayerFeature Dynamic Range Integration Tests

    func testPlayerFeatureDynamicRangeState() async throws {
        let streamURL = try XCTUnwrap(URL(string: "http://example.com/stream.m3u8"))
        let hdrChannel = PlayerFeature.PlayableItem(
            id: "ch_hdr",
            title: "TRT 4K HDR",
            streamURL: streamURL,
            isLive: true
        )
        let sdrChannel = PlayerFeature.PlayableItem(
            id: "ch_sdr",
            title: "HaberTurk HD",
            streamURL: streamURL,
            isLive: true
        )

        // Initial state with HDR channel automatically initializes videoDynamicRange and shows HUD
        var state = PlayerFeature.State(item: hdrChannel)
        XCTAssertEqual(state.videoDynamicRange, .hdr10)
        XCTAssertTrue(state.isDynamicRangeHUDVisible)

        let store = TestStore(initialState: state) {
            PlayerFeature()
        }

        // 1. Manually hide Dynamic Range HUD
        await store.send(.hideDynamicRangeHUD) {
            $0.isDynamicRangeHUDVisible = false
        }

        // 2. Show Dynamic Range HUD
        await store.send(.showDynamicRangeHUD) {
            $0.isDynamicRangeHUDVisible = true
        }

        // 3. Detect new dynamic range: Dolby Vision
        let dvInfo = DynamicRangeInfo(range: .dolbyVision, detectedResolution: "4K UHD")
        await store.send(.dynamicRangeDetected(dvInfo)) {
            $0.dynamicRangeInfo = dvInfo
            $0.videoDynamicRange = .dolbyVision
            $0.isDynamicRangeHUDVisible = true
        }

        // 4. Hide Dynamic Range HUD
        await store.send(.hideDynamicRangeHUD) {
            $0.isDynamicRangeHUDVisible = false
        }

        // 5. Detect SDR: HUD should NOT auto-show for SDR
        let sdrInfo = DynamicRangeInfo(range: .sdr, detectedResolution: "1080p FHD")
        await store.send(.dynamicRangeDetected(sdrInfo)) {
            $0.dynamicRangeInfo = sdrInfo
            $0.videoDynamicRange = .sdr
            $0.isDynamicRangeHUDVisible = false
        }
    }
}
