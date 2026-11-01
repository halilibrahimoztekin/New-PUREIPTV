import ComposableArchitecture
@testable import PureIPTV
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class ViewSnapshotTests: XCTestCase {
    private let sampleConfig = PlaylistConfig(
        type: .xtream,
        serverURL: URL(string: "http://example.com:8080"),
        username: "testuser",
        password: "testpassword"
    )

    func testDashboardView_tvOS() {
        var state = DashboardFeature.State()
        state.isLoading = false
        state.hasLoadedRemoteData = true
        state.hasResolvedLiveCatalog = true
        state.hasResolvedMovieCatalog = true
        state.hasResolvedSeriesCatalog = true
        state.activePlaylistName = "Pure Cinema VIP"

        let heroMovie = MediaModels.Item(
            id: "vod_1",
            title: "Inception",
            categoryID: "cat_action",
            type: .vod,
            rating: 8.8,
            releaseDate: "2010",
            duration: "148m"
        )
        let movie2 = MediaModels.Item(
            id: "vod_2",
            title: "Interstellar",
            categoryID: "cat_scifi",
            type: .vod,
            rating: 8.7,
            releaseDate: "2014",
            duration: "169m"
        )
        let movie3 = MediaModels.Item(
            id: "vod_3",
            title: "The Dark Knight",
            categoryID: "cat_action",
            type: .vod,
            rating: 9.0,
            releaseDate: "2008",
            duration: "152m"
        )
        state.featuredVODs = [heroMovie, movie2, movie3]

        let ch1 = MediaModels.Item(
            id: "ch_1",
            title: "BBC News HD",
            categoryID: "cat_news",
            type: .live
        )
        let ch2 = MediaModels.Item(
            id: "ch_2",
            title: "Sky Sports Premier League",
            categoryID: "cat_sports",
            type: .live
        )
        state.featuredChannels = [ch1, ch2]

        let series1 = MediaModels.Item(
            id: "ser_1",
            title: "Severance",
            categoryID: "cat_drama",
            type: .series,
            rating: 8.7,
            releaseDate: "2022"
        )
        let series2 = MediaModels.Item(
            id: "ser_2",
            title: "Succession",
            categoryID: "cat_drama",
            type: .series,
            rating: 8.9,
            releaseDate: "2018"
        )
        state.featuredSeries = [series1, series2]

        let store = Store(initialState: state) {
            Reduce<DashboardFeature.State, DashboardFeature.Action> { _, _ in .none }
        }

        #if os(tvOS)
            let view = DashboardView_tvOS(store: store, config: sampleConfig)
            let vc = UIHostingController(rootView: view)
            vc.view.overrideUserInterfaceStyle = .dark
            assertSnapshot(of: vc, as: .image(on: .tv, precision: 0.95))
        #endif
    }

    func testLiveTVView_tvOS() {
        var state = LiveTVFeature.State()
        let cat1 = MediaModels.Category(id: "1", name: "Spor")
        let cat2 = MediaModels.Category(id: "2", name: "Haber")
        let cat3 = MediaModels.Category(id: "3", name: "Sinema")
        state.categories = [cat1, cat2, cat3]
        state.selectedCategoryID = "1"
        state.hasResolvedCategories = true
        state.isLoadingCategories = false
        state.isLoadingChannels = false

        let ch1 = MediaModels.Item(id: "ch_1", title: "beIN SPORTS 1 HD", categoryID: "1", type: .live)
        let ch2 = MediaModels.Item(id: "ch_2", title: "EuroSport 1 HD", categoryID: "1", type: .live)
        let ch3 = MediaModels.Item(id: "ch_3", title: "S Sport Plus", categoryID: "1", type: .live)
        state.channelsByCategory = ["1": [ch1, ch2, ch3]]
        state.selectedChannel = ch1

        let store = Store(initialState: state) {
            Reduce<LiveTVFeature.State, LiveTVFeature.Action> { _, _ in .none }
        }

        let view = LiveTVView(store: store, config: sampleConfig)
        let vc = UIHostingController(rootView: view)
        vc.view.overrideUserInterfaceStyle = .dark
        #if os(tvOS)
            assertSnapshot(of: vc, as: .image(on: .tv, precision: 0.95))
        #endif
    }

    func testVODView_tvOS() {
        var state = VODFeature.State()
        let cat1 = MediaModels.Category(id: "vod_cat_1", name: "Aksiyon")
        let cat2 = MediaModels.Category(id: "vod_cat_2", name: "Bilim Kurgu")
        state.categories = [cat1, cat2]
        state.selectedCategoryID = "vod_cat_1"
        state.hasResolvedCategories = true
        state.isLoadingCategories = false
        state.isLoadingVODs = false

        let m1 = MediaModels.Item(
            id: "vod_1",
            title: "Avatar: The Way of Water",
            categoryID: "vod_cat_1",
            type: .vod,
            rating: 7.6,
            releaseDate: "2022",
            duration: "192m"
        )
        let m2 = MediaModels.Item(
            id: "vod_2",
            title: "Top Gun: Maverick",
            categoryID: "vod_cat_1",
            type: .vod,
            rating: 8.3,
            releaseDate: "2022",
            duration: "130m"
        )
        let m3 = MediaModels.Item(
            id: "vod_3",
            title: "Gladiator II",
            categoryID: "vod_cat_1",
            type: .vod,
            rating: 7.4,
            releaseDate: "2024",
            duration: "148m"
        )
        state.vodsByCategory = ["vod_cat_1": [m1, m2, m3]]
        state.selectedVOD = m1

        let store = Store(initialState: state) {
            Reduce<VODFeature.State, VODFeature.Action> { _, _ in .none }
        }

        let view = VODView(store: store, config: sampleConfig)
        let vc = UIHostingController(rootView: view)
        vc.view.overrideUserInterfaceStyle = .dark
        #if os(tvOS)
            assertSnapshot(of: vc, as: .image(on: .tv, precision: 0.95))
        #endif
    }

    func testSeriesView_tvOS() {
        var state = SeriesFeature.State()
        let cat1 = MediaModels.Category(id: "ser_cat_1", name: "Popüler Diziler")
        let cat2 = MediaModels.Category(id: "ser_cat_2", name: "Bilim Kurgu")
        state.categories = [cat1, cat2]
        state.selectedCategoryID = "ser_cat_1"
        state.hasResolvedCategories = true
        state.isLoadingCategories = false
        state.isLoadingSeries = false

        let s1 = MediaModels.Item(
            id: "ser_1",
            title: "Severance",
            categoryID: "ser_cat_1",
            type: .series,
            rating: 8.7,
            releaseDate: "2022"
        )
        let s2 = MediaModels.Item(
            id: "ser_2",
            title: "The Last of Us",
            categoryID: "ser_cat_1",
            type: .series,
            rating: 8.8,
            releaseDate: "2023"
        )
        let s3 = MediaModels.Item(
            id: "ser_3",
            title: "Stranger Things",
            categoryID: "ser_cat_1",
            type: .series,
            rating: 8.7,
            releaseDate: "2016"
        )
        state.seriesByCategory = ["ser_cat_1": [s1, s2, s3]]
        state.selectedSeries = s1

        let store = Store(initialState: state) {
            Reduce<SeriesFeature.State, SeriesFeature.Action> { _, _ in .none }
        }

        let view = SeriesView(store: store, config: sampleConfig)
        let vc = UIHostingController(rootView: view)
        vc.view.overrideUserInterfaceStyle = .dark
        #if os(tvOS)
            assertSnapshot(of: vc, as: .image(on: .tv, precision: 0.95))
        #endif
    }

    func testSettingsView_tvOS() {
        var state = SettingsFeature.State()
        state.isParentalControlEnabled = false
        state.isOLEDDimmingEnabled = true
        state.isChannelNameCleaningEnabled = true
        state.defaultStartupTab = "Keşfet"
        state.cacheSize = "128 MB"

        let store = Store(initialState: state) {
            Reduce<SettingsFeature.State, SettingsFeature.Action> { _, _ in .none }
        }

        let view = SettingsView(store: store)
        let vc = UIHostingController(rootView: view)
        vc.view.overrideUserInterfaceStyle = .dark
        #if os(tvOS)
            assertSnapshot(of: vc, as: .image(on: .tv, precision: 0.95))
        #endif
    }
}
