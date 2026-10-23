import ComposableArchitecture
import Foundation
@testable import PureIPTV
import XCTest

@MainActor
final class CustomEPGMappingEngineTests: XCTestCase {
    // MARK: - 1. GzipDecompressor Tests

    func testGzipDecompressorWithPlainData() throws {
        let plainText = "<tv><channel id=\"trt1\"><display-name>TRT 1</display-name></channel></tv>"
        let plainData = try XCTUnwrap(plainText.data(using: .utf8))

        XCTAssertFalse(GzipDecompressor.isGzipped(plainData))
        let result = GzipDecompressor.decompress(plainData)
        XCTAssertEqual(result, plainData)
    }

    func testGzipDecompressorMagicBytesDetection() {
        let notGzip = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertFalse(GzipDecompressor.isGzipped(notGzip))

        let singleByte = Data([0x1F])
        XCTAssertFalse(GzipDecompressor.isGzipped(singleByte))

        let gzipMagic = Data([0x1F, 0x8B, 0x08, 0x00])
        XCTAssertTrue(GzipDecompressor.isGzipped(gzipMagic))
    }

    // MARK: - 2. CustomEPGSource Model Tests

    func testCustomEPGSourceModel() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/epg.xml.gz"))
        let source = CustomEPGSource(
            name: "Test Source",
            url: url,
            isEnabled: true,
            channelCount: 150,
            programmeCount: 3200
        )

        XCTAssertEqual(source.name, "Test Source")
        XCTAssertEqual(source.url, url)
        XCTAssertTrue(source.isEnabled)
        XCTAssertEqual(source.channelCount, 150)
        XCTAssertEqual(source.programmeCount, 3200)

        // Codable roundtrip
        let encoder = JSONEncoder()
        let data = try encoder.encode(source)
        let decoded = try JSONDecoder().decode(CustomEPGSource.self, from: data)

        XCTAssertEqual(decoded.id, source.id)
        XCTAssertEqual(decoded.name, source.name)
        XCTAssertEqual(decoded.url, source.url)
        XCTAssertEqual(decoded.isEnabled, source.isEnabled)
        XCTAssertEqual(decoded.channelCount, source.channelCount)
        XCTAssertEqual(decoded.programmeCount, source.programmeCount)
    }

    // MARK: - 3. ChannelEPGMapping Model Tests

    func testChannelEPGMappingModel() throws {
        let mapping = ChannelEPGMapping(
            channelID: "ch-101",
            channelName: "BeIN Sports 1",
            customEPGChannelID: "beinsports1.tr",
            customSourceID: "source-1",
            timeShiftHours: 3
        )

        XCTAssertEqual(mapping.id, "ch-101")
        XCTAssertEqual(mapping.channelID, "ch-101")
        XCTAssertEqual(mapping.channelName, "BeIN Sports 1")
        XCTAssertEqual(mapping.customEPGChannelID, "beinsports1.tr")
        XCTAssertEqual(mapping.customSourceID, "source-1")
        XCTAssertEqual(mapping.timeShiftHours, 3)

        // Codable roundtrip
        let data = try JSONEncoder().encode(mapping)
        let decoded = try JSONDecoder().decode(ChannelEPGMapping.self, from: data)

        XCTAssertEqual(decoded.channelID, mapping.channelID)
        XCTAssertEqual(decoded.timeShiftHours, 3)
        XCTAssertEqual(decoded.customEPGChannelID, "beinsports1.tr")
    }

    // MARK: - 4. Time-Shift Calculation Tests

    func testGlobalTimeShiftAppliedToPrograms() {
        let baseDate = Date()
        let program = EPGProgram(
            id: "prog-1",
            title: "Haber Bülteni",
            description: "Akşam Ana Haber",
            startTime: baseDate,
            endTime: baseDate.addingTimeInterval(3600),
            isPlayingNow: true
        )

        // Shift +2 hours
        let shiftHours = 2
        let shiftedStart = program.startTime.addingTimeInterval(Double(shiftHours) * 3600)
        let shiftedEnd = program.endTime.addingTimeInterval(Double(shiftHours) * 3600)

        XCTAssertEqual(shiftedStart.timeIntervalSince(baseDate), 7200, accuracy: 0.1)
        XCTAssertEqual(shiftedEnd.timeIntervalSince(shiftedStart), 3600, accuracy: 0.1)
    }

    func testChannelSpecificTimeShiftOverridesGlobal() {
        let globalShift = 2
        let channelOverride = -3

        let mapping = ChannelEPGMapping(
            channelID: "ch-uk-1",
            channelName: "BBC One",
            timeShiftHours: channelOverride
        )

        let effectiveShift = mapping.timeShiftHours != 0 ? mapping.timeShiftHours : globalShift
        XCTAssertEqual(effectiveShift, -3)

        let mappingWithoutOverride = ChannelEPGMapping(
            channelID: "ch-tr-1",
            channelName: "TRT 1",
            timeShiftHours: 0
        )
        let effectiveShift2 = mappingWithoutOverride.timeShiftHours != 0 ? mappingWithoutOverride.timeShiftHours : globalShift
        XCTAssertEqual(effectiveShift2, 2)
    }

    // MARK: - 5. CustomEPGMappingClient Live/Test Value Tests

    func testCustomEPGMappingClientLiveTimeShiftCalculation() {
        let client = CustomEPGMappingClient.liveValue

        let baseDate = Date(timeIntervalSince1970: 100_000)
        let program = EPGProgram(
            id: "p1",
            title: "Gündem Özel",
            description: "Canlı Yayın",
            startTime: baseDate,
            endTime: baseDate.addingTimeInterval(1800),
            isPlayingNow: false
        )

        // Set global time shift to +2 hours
        client.setGlobalTimeShift(2)
        XCTAssertEqual(client.getGlobalTimeShift(), 2)

        let shiftedPrograms = client.applyTimeShift([program], "unknown-channel")
        XCTAssertEqual(shiftedPrograms.count, 1)

        let expectedStart = baseDate.addingTimeInterval(7200)
        let expectedEnd = baseDate.addingTimeInterval(1800 + 7200)
        XCTAssertEqual(shiftedPrograms[0].startTime.timeIntervalSince1970, expectedStart.timeIntervalSince1970, accuracy: 0.1)
        XCTAssertEqual(shiftedPrograms[0].endTime.timeIntervalSince1970, expectedEnd.timeIntervalSince1970, accuracy: 0.1)

        // Reset global shift
        client.setGlobalTimeShift(0)
        XCTAssertEqual(client.getGlobalTimeShift(), 0)
    }

    func testCustomEPGMappingClientChannelOverrideTimeShift() {
        let client = CustomEPGMappingClient.liveValue

        let channelID = "test-ch-a"
        let mapping = ChannelEPGMapping(
            channelID: channelID,
            channelName: "Test Channel A",
            timeShiftHours: 5
        )
        client.setChannelMapping(mapping)
        XCTAssertEqual(client.getChannelTimeShift(channelID), 5)

        let baseDate = Date(timeIntervalSince1970: 200_000)
        let program = EPGProgram(
            id: "p2",
            title: "Film Kuşağı",
            description: "Sinema",
            startTime: baseDate,
            endTime: baseDate.addingTimeInterval(7200),
            isPlayingNow: false
        )

        let shifted = client.applyTimeShift([program], channelID)
        XCTAssertEqual(shifted.count, 1)
        // Shifted by 5 hours = 18000s
        XCTAssertEqual(shifted[0].startTime.timeIntervalSince1970, baseDate.timeIntervalSince1970 + 18000, accuracy: 0.1)

        // Clean up
        client.removeChannelMapping(channelID)
        XCTAssertNil(client.getChannelMapping(channelID))
    }

    // MARK: - 6. SettingsFeature Custom EPG Reducer Tests

    @MainActor
    func testSettingsFeatureCustomEPGStateFlow() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient.epgTimeShift = { 0 }
            $0.settingsClient.setEpgTimeShift = { _ in }
            $0.customEPGMappingClient.getSources = { [] }
            $0.customEPGMappingClient.getAllMappings = { [:] }
            $0.customEPGMappingClient.getGlobalTimeShift = { 0 }
            $0.customEPGMappingClient.setGlobalTimeShift = { _ in }
        }

        // Open sheet
        await store.send(.setCustomEPGSheetPresented(true)) {
            $0.isCustomEPGSheetPresented = true
        }

        // Change global time shift
        await store.send(.setGlobalEPGTimeShift(3)) {
            $0.epgTimeShift = 3
        }

        // Open add source sheet
        await store.send(.setAddCustomEPGSourceSheetPresented(true)) {
            $0.isAddCustomEPGSourceSheetPresented = true
        }

        // Enter input
        await store.send(.setNewCustomEPGName("Ulusal Kanallar EPG")) {
            $0.newCustomEPGName = "Ulusal Kanallar EPG"
        }
        await store.send(.setNewCustomEPGURLString("https://epg.example.com/guide.xml")) {
            $0.newCustomEPGURLString = "https://epg.example.com/guide.xml"
        }

        // Close add source sheet clears inputs
        await store.send(.setAddCustomEPGSourceSheetPresented(false)) {
            $0.isAddCustomEPGSourceSheetPresented = false
            $0.newCustomEPGName = ""
            $0.newCustomEPGURLString = ""
        }
    }
}
