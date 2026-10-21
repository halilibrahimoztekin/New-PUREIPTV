import ComposableArchitecture
import Foundation
@testable import PureIPTV
#if os(tvOS)
    import TVServices
#endif
import XCTest

final class TopShelfEngineTests: XCTestCase {
    // MARK: - 1. DTO & Serialization Tests

    func testTopShelfItemDTOEncodingDecoding() throws {
        let item = TopShelfItemDTO(
            id: "ch_1",
            title: "TRT 1 HD",
            subtitle: "Canlı Yayın",
            imageURL: "http://example.com/logo.png",
            deepLinkURL: "pureiptv://play?id=ch_1&type=live",
            progress: 0.5,
            duration: 7200,
            isLive: true
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(TopShelfItemDTO.self, from: data)

        XCTAssertEqual(decoded.id, "ch_1")
        XCTAssertEqual(decoded.title, "TRT 1 HD")
        XCTAssertEqual(decoded.subtitle, "Canlı Yayın")
        XCTAssertEqual(decoded.imageURL, "http://example.com/logo.png")
        XCTAssertEqual(decoded.deepLinkURL, "pureiptv://play?id=ch_1&type=live")
        XCTAssertEqual(decoded.progress, 0.5)
        XCTAssertEqual(decoded.duration, 7200)
        XCTAssertTrue(decoded.isLive)
    }

    func testTopShelfDataDTOWithPreferredStyle() throws {
        let item1 = TopShelfItemDTO(
            id: "vod_1",
            title: "Dune",
            deepLinkURL: "pureiptv://play?id=vod_1",
            progress: 0.75,
            isLive: false
        )

        let dataSectioned = TopShelfDataDTO(
            continueWatching: [item1],
            favoriteChannels: [],
            recentMovies: [],
            preferredStyle: .sectioned
        )

        let encoded = try JSONEncoder().encode(dataSectioned)
        let decoded = try JSONDecoder().decode(TopShelfDataDTO.self, from: encoded)

        XCTAssertEqual(decoded.preferredStyle, .sectioned)
        XCTAssertEqual(decoded.continueWatching.count, 1)
        XCTAssertEqual(decoded.continueWatching.first?.title, "Dune")

        let dataCarousel = TopShelfDataDTO(
            continueWatching: [item1],
            favoriteChannels: [],
            recentMovies: [],
            preferredStyle: .carousel
        )
        let encodedCarousel = try JSONEncoder().encode(dataCarousel)
        let decodedCarousel = try JSONDecoder().decode(TopShelfDataDTO.self, from: encodedCarousel)
        XCTAssertEqual(decodedCarousel.preferredStyle, .carousel)
    }

    // MARK: - 2. Deep Link Generator Tests

    func testMakeDeepLink() {
        let link1 = TopShelfService.makeDeepLink(
            id: "101",
            type: "live",
            title: "BeIN Sports 1",
            streamURL: "http://stream.example.com/live.m3u8",
            coverURL: "http://stream.example.com/logo.png"
        )

        XCTAssertTrue(link1.hasPrefix("pureiptv://play"))
        XCTAssertTrue(link1.contains("id=101"))
        XCTAssertTrue(link1.contains("type=live"))
        XCTAssertTrue(link1.contains("title=BeIN%20Sports%201"))
        XCTAssertTrue(link1.contains("coverURL=http://stream.example.com/logo.png"))

        let link2 = TopShelfService.makeDeepLink(
            id: "movie_500",
            type: "vod",
            title: "Inception",
            streamURL: "http://stream.example.com/movie.mp4",
            startPosition: 1245.5
        )

        XCTAssertTrue(link2.contains("type=vod"))
        XCTAssertTrue(link2.contains("startPosition=1245.5"))
    }

    // MARK: - 3. TopShelfClient & Service Tests

    func testTopShelfClientUpdateAndLoad() {
        let client = TopShelfClient.liveValue

        let item = TopShelfItemDTO(
            id: "test_ch",
            title: "Test Kanalı",
            deepLinkURL: "pureiptv://play?id=test_ch"
        )

        client.setPreferredStyle(.carousel)
        XCTAssertEqual(client.getPreferredStyle(), .carousel)

        client.updateTopShelfData([item], [], [])
        let loaded = client.loadTopShelfData()

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.continueWatching.count, 1)
        XCTAssertEqual(loaded?.continueWatching.first?.id, "test_ch")
        XCTAssertEqual(loaded?.preferredStyle, .carousel)

        // Reset to sectioned
        client.setPreferredStyle(.sectioned)
        XCTAssertEqual(client.getPreferredStyle(), .sectioned)
    }

    // MARK: - 4. SettingsFeature Integration Tests

    func testSettingsFeatureTopShelfStyleAction() async {
        var state = SettingsFeature.State()
        state.topShelfStyle = .sectioned

        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.topShelfClient = .init(
                updateTopShelfData: { _, _, _ in },
                loadTopShelfData: { nil },
                getPreferredStyle: { .sectioned },
                setPreferredStyle: { _ in }
            )
        }

        // Switch to Carousel style
        await store.send(.setTopShelfStyle(.carousel)) {
            $0.topShelfStyle = .carousel
        }

        // Switch back to Sectioned style
        await store.send(.setTopShelfStyle(.sectioned)) {
            $0.topShelfStyle = .sectioned
        }
    }

    // MARK: - 5. tvOS Provider Carousel & Sectioned Content Tests

    #if os(tvOS)
        func testPureIPTVTopShelfContentProviderCarousel() {
            let provider = PureIPTVTopShelfContentProvider()
            let service = TopShelfService.shared

            let item = TopShelfItemDTO(
                id: "carousel_item_1",
                title: "Oppenheimer",
                subtitle: "Sinema Kulübü",
                imageURL: "http://example.com/oppenheimer.jpg",
                deepLinkURL: "pureiptv://play?id=carousel_item_1&type=vod"
            )

            service.updateTopShelfData(
                continueWatching: [item],
                favoriteChannels: [],
                recentMovies: [],
                style: .carousel
            )

            let expectation = expectation(description: "loadTopShelfContent carousel")
            provider.loadTopShelfContent { content in
                XCTAssertNotNil(content)
                XCTAssertTrue(content is TVTopShelfCarouselContent)
                if let carousel = content as? TVTopShelfCarouselContent {
                    XCTAssertEqual(carousel.items.count, 1)
                    XCTAssertEqual(carousel.items.first?.title, "Oppenheimer")
                }
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 2.0)
        }

        func testPureIPTVTopShelfContentProviderSectioned() {
            let provider = PureIPTVTopShelfContentProvider()
            let service = TopShelfService.shared

            let item = TopShelfItemDTO(
                id: "section_item_1",
                title: "TRT Spor",
                deepLinkURL: "pureiptv://play?id=section_item_1&type=live",
                isLive: true
            )

            service.updateTopShelfData(
                continueWatching: [],
                favoriteChannels: [item],
                recentMovies: [],
                style: .sectioned
            )

            let expectation = expectation(description: "loadTopShelfContent sectioned")
            provider.loadTopShelfContent { content in
                XCTAssertNotNil(content)
                XCTAssertTrue(content is TVTopShelfSectionedContent)
                if let sectioned = content as? TVTopShelfSectionedContent {
                    XCTAssertEqual(sectioned.sections.count, 1)
                    XCTAssertEqual(sectioned.sections.first?.title, "Favori Kanallar")
                }
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 2.0)
        }
    #endif
}
