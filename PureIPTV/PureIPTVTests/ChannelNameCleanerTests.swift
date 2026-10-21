import Foundation
@testable import PureIPTV
import XCTest

final class ChannelNameCleanerTests: XCTestCase {
    func testTurkishChannelDecluttering() {
        let title1 = "[TR] TRT 1 HD"
        let meta1 = ChannelNameCleaner.analyze(title1)
        XCTAssertEqual(meta1.cleanTitle, "TRT 1")
        XCTAssertEqual(meta1.detectedCountry, "TR")
        XCTAssertEqual(meta1.detectedQuality, ChannelQualityBadge.hd720)
        XCTAssertFalse(meta1.isBackup)
        XCTAssertFalse(meta1.isHEVC)
        XCTAssertTrue(meta1.hasStrippedClutter)

        let title2 = "TR: ATV FHD (HEVC)"
        let meta2 = ChannelNameCleaner.analyze(title2)
        XCTAssertEqual(meta2.cleanTitle, "ATV")
        XCTAssertEqual(meta2.detectedCountry, "TR")
        XCTAssertEqual(meta2.detectedQuality, ChannelQualityBadge.fhd1080)
        XCTAssertTrue(meta2.isHEVC)
        XCTAssertFalse(meta2.isBackup)

        let title3 = "TR - BEIN SPORTS 1 4K UHD VIP"
        let meta3 = ChannelNameCleaner.analyze(title3)
        XCTAssertEqual(meta3.cleanTitle, "BEIN SPORTS 1")
        XCTAssertEqual(meta3.detectedCountry, "TR")
        XCTAssertEqual(meta3.detectedQuality, ChannelQualityBadge.uhd4k)
        XCTAssertTrue(meta3.hasStrippedClutter)

        let title4 = "TR | KANAL D (YEDEK)"
        let meta4 = ChannelNameCleaner.analyze(title4)
        XCTAssertEqual(meta4.cleanTitle, "KANAL D")
        XCTAssertEqual(meta4.detectedCountry, "TR")
        XCTAssertTrue(meta4.isBackup)
    }

    func testInternationalChannelDecluttering() {
        let title1 = "[DE] SKY SPORT BUNDESLIGA 1 FHD 50FPS"
        let meta1 = ChannelNameCleaner.analyze(title1)
        XCTAssertEqual(meta1.cleanTitle, "SKY SPORT BUNDESLIGA 1")
        XCTAssertEqual(meta1.detectedCountry, "DE")
        XCTAssertEqual(meta1.detectedQuality, ChannelQualityBadge.fhd1080)

        let title2 = "UK: BBC ONE HD [RAW]"
        let meta2 = ChannelNameCleaner.analyze(title2)
        XCTAssertEqual(meta2.cleanTitle, "BBC ONE")
        XCTAssertEqual(meta2.detectedCountry, "UK")
        XCTAssertEqual(meta2.detectedQuality, ChannelQualityBadge.hd720)

        let title3 = "FR - CANAL+ SPORT 1080p MULTI-AUDIO"
        let meta3 = ChannelNameCleaner.analyze(title3)
        XCTAssertEqual(meta3.cleanTitle, "CANAL+ SPORT")
        XCTAssertEqual(meta3.detectedCountry, "FR")
        XCTAssertEqual(meta3.detectedQuality, ChannelQualityBadge.fhd1080)

        let title4 = "[USA] HBO EAST HD"
        let meta4 = ChannelNameCleaner.analyze(title4)
        XCTAssertEqual(meta4.cleanTitle, "HBO EAST")
        XCTAssertEqual(meta4.detectedCountry, "USA")
        XCTAssertEqual(meta4.detectedQuality, ChannelQualityBadge.hd720)
    }

    func testQualityDetectionWithoutCountryPrefix() {
        let meta4k = ChannelNameCleaner.analyze("Discovery Science 4K")
        XCTAssertEqual(meta4k.cleanTitle, "Discovery Science")
        XCTAssertEqual(meta4k.detectedQuality, ChannelQualityBadge.uhd4k)

        let meta720 = ChannelNameCleaner.analyze("Eurosport 1 720p")
        XCTAssertEqual(meta720.cleanTitle, "Eurosport 1")
        XCTAssertEqual(meta720.detectedQuality, ChannelQualityBadge.hd720)

        let metaSD = ChannelNameCleaner.analyze("Cartoon Network SD")
        XCTAssertEqual(metaSD.cleanTitle, "Cartoon Network")
        XCTAssertEqual(metaSD.detectedQuality, ChannelQualityBadge.sd)
    }

    func testSafetyFallback() {
        // When title consists only of stripped tokens
        let fhd = ChannelNameCleaner.clean("FHD")
        XCTAssertEqual(fhd, "FHD")

        // Empty string
        let empty = ChannelNameCleaner.clean("")
        XCTAssertEqual(empty, "")

        // Clean title already
        let metaClean = ChannelNameCleaner.analyze("National Geographic")
        XCTAssertEqual(metaClean.cleanTitle, "National Geographic")
        XCTAssertFalse(metaClean.hasStrippedClutter)
    }

    func testExtensionsOnModels() throws {
        let mediaItem = MediaModels.Item(
            id: "ch-1",
            title: "[TR] FOX HD",
            streamURL: URL(string: "https://example.com/stream.m3u8"),
            categoryID: "cat-1",
            type: .live
        )
        XCTAssertEqual(mediaItem.cleanTitle, "FOX")
        XCTAssertEqual(mediaItem.cleanedMetadata.detectedQuality, ChannelQualityBadge.hd720)
        XCTAssertEqual(mediaItem.cleanedMetadata.detectedCountry, "TR")

        let playableItem = try PlayerFeature.PlayableItem(
            id: "play-1",
            title: "DE: ZDF FHD",
            streamURL: XCTUnwrap(URL(string: "https://example.com/stream.m3u8")),
            isLive: true
        )
        XCTAssertEqual(playableItem.cleanTitle, "ZDF")
        XCTAssertEqual(playableItem.cleanedMetadata.detectedQuality, ChannelQualityBadge.fhd1080)
        XCTAssertEqual(playableItem.cleanedMetadata.detectedCountry, "DE")
    }

    func testSettingsClientChannelCleaningPersistence() {
        let client = SettingsClient.liveValue
        client.setIsChannelNameCleaningEnabled(true)
        XCTAssertTrue(client.isChannelNameCleaningEnabled())

        client.setIsChannelNameCleaningEnabled(false)
        XCTAssertFalse(client.isChannelNameCleaningEnabled())

        // Reset to default true
        client.setIsChannelNameCleaningEnabled(true)
        XCTAssertTrue(client.isChannelNameCleaningEnabled())
    }
}
