//
//  PureIPTVTests.swift
//  PureIPTVTests
//
//  Created by ibrahim öztekin on 19.08.2026.
//

@testable import PureIPTV
import XCTest

final class PureIPTVTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        XCTAssertEqual(MemoryLayout<AppCoordinator.Action>.size, 8, "AppCoordinator.Action must be an indirect enum (8 bytes) to avoid stack overflow")
        XCTAssertEqual(MemoryLayout<HomeFeature.Action>.size, 8, "HomeFeature.Action must be an indirect enum (8 bytes) to avoid stack overflow")
        XCTAssertEqual(MemoryLayout<PlayerFeature.Action>.size, 8, "PlayerFeature.Action must be an indirect enum (8 bytes) to avoid stack overflow")
        XCTAssertEqual(MemoryLayout<SeriesDetailFeature.Action>.size, 8, "SeriesDetailFeature.Action must be an indirect enum (8 bytes) to avoid stack overflow")
        XCTAssertEqual(MemoryLayout<VODDetailFeature.Action>.size, 8, "VODDetailFeature.Action must be an indirect enum (8 bytes) to avoid stack overflow")
    }

    func testPlayerLoggerFilterableConsoleOutput() {
        PlayerLogger.shared.clear()

        let rawURL = "http://example.com:8080/live/user123/pass456/9999.ts"
        let sanitized = PlayerLogger.sanitize(message: "Playing \(rawURL) with token=secretToken123")
        XCTAssertFalse(sanitized.contains("pass456"), "Credentials must be redacted")
        XCTAssertFalse(sanitized.contains("secretToken123"), "Tokens must be redacted")
        XCTAssertTrue(sanitized.contains("***"), "Sanitized string must contain redaction mask")

        PlayerLogger.shared.info(category: "Stream", message: "Stream test started")
        PlayerLogger.shared.error(category: "VLC", message: "VLC test error")

        let entries = PlayerLogger.shared.getEntries()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].level, .info)
        XCTAssertEqual(entries[1].level, .error)
        XCTAssertTrue(entries[1].filterableConsoleLine.contains("[PureIPTV:Player] 🔴 [ERROR] [VLC]"))
    }

    func testAppFormatters() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertFalse(AppFormatters.timeShort(date).isEmpty)
        XCTAssertFalse(AppFormatters.dayShort(date).isEmpty)
        XCTAssertFalse(AppFormatters.dateTimeShort(date).isEmpty)
        XCTAssertFalse(AppFormatters.mediumDateShortTime(date).isEmpty)
        XCTAssertFalse(AppFormatters.catchupTimeString(date).isEmpty)
        XCTAssertTrue(AppFormatters.formatFileSize(1024 * 1024 * 50).contains("MB"))
        XCTAssertTrue(AppFormatters.formatDownloadSpeed(1024 * 500).contains("/s"))

        let parsedXtream = AppFormatters.parseXtreamReleaseDate("2024-05-15")
        XCTAssertNotNil(parsedXtream)

        let parsedFallback = AppFormatters.parseEPGFallbackDate("1700000000")
        XCTAssertEqual(parsedFallback, date)
    }

    func testChannelNameCleanerMemoization() {
        let title = "[TR] BEIN SPORTS 1 HD"
        let res1 = ChannelNameCleaner.analyze(title)
        let res2 = ChannelNameCleaner.analyze(title)
        XCTAssertEqual(res1.cleanTitle, "BEIN SPORTS 1")
        XCTAssertEqual(res2.cleanTitle, res1.cleanTitle)
        XCTAssertEqual(res2.detectedQuality, res1.detectedQuality)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
}
