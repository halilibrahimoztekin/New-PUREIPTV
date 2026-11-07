import ComposableArchitecture
import Foundation
@testable import PureIPTV
import XCTest

@MainActor
final class DashboardFeatureTests: XCTestCase {
    func testPrimaryCatalogLoadingPlaceholderStateIsTrackedPerCatalog() async {
        let playlistID = UUID()
        let refreshID = UUID()
        let scope = ProfileContextSnapshot(profileID: UUID(), generation: UUID())
        var initialState = DashboardFeature.State()
        initialState.activePlaylistID = playlistID
        initialState.activeProfileScope = scope
        initialState.lastAdultHidden = false
        initialState.activeRefreshID = refreshID
        initialState.loadingPrimaryCatalogs = [.live, .movies, .series]

        let store = TestStore(initialState: initialState) {
            DashboardFeature()
        } withDependencies: {
            $0.profileContextClient.snapshot = { scope }
            $0.wikidataAwardClient.fetchRecognitions = { _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.primaryCatalogLoaded(
            playlistID: playlistID,
            hideAdult: false,
            refreshID: refreshID,
            profileScope: scope,
            type: .live,
            items: [MediaModels.Item(id: "channel", title: "Channel", categoryID: "live", type: .live)]
        ))

        XCTAssertEqual(store.state.loadingPrimaryCatalogs, [.movies, .series])
        XCTAssertTrue(store.state.hasResolvedLiveCatalog)
        XCTAssertEqual(store.state.featuredChannels.map(\.id), ["channel"])
    }

    func testLocalRecommendationsAppearBeforeSecondaryDiscoveryShelves() async {
        let playlistID = UUID()
        let profileID = UUID()
        let scope = ProfileContextSnapshot(profileID: profileID, generation: UUID())
        LocalPersonalizationPreferences.setRecommendationsEnabled(true, for: profileID)

        let actorRefreshID = UUID()
        let localRefreshID = UUID()
        let episodeRefreshID = UUID()
        let movieRefreshID = UUID()
        let awardRefreshID = UUID()
        let item = MediaModels.Item(
            id: "recommended-movie",
            title: "Recommended Movie",
            categoryID: "movies",
            type: .vod
        )
        let actorCollection = ActorRecommendationEngine.Collection(
            actorID: 42,
            actorName: "Actor",
            sourceTitle: "Watched Movie",
            kind: .movie,
            items: [item]
        )
        let rankedMovie = MovieRatingDiscoveryEngine.RankedMovie(
            item: item,
            voteAverage: 8.5,
            voteCount: 1000
        )
        let awardMovie = AwardDiscoveryEngine.MovieEntry(item: item, recognitionCount: 2)

        var initialState = DashboardFeature.State()
        initialState.activePlaylistID = playlistID
        initialState.activeProfileScope = scope
        initialState.lastAdultHidden = false
        initialState.activeActorRecommendationRefreshID = actorRefreshID
        initialState.activePersonalizationRefreshID = localRefreshID
        initialState.activeNewEpisodeRefreshID = episodeRefreshID
        initialState.activeMovieRatingRefreshID = movieRefreshID
        initialState.activeAwardRefreshID = awardRefreshID

        let store = TestStore(initialState: initialState) {
            DashboardFeature()
        } withDependencies: {
            $0.profileContextClient.snapshot = { scope }
            $0.wikidataAwardClient.fetchRecognitions = { _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.localRecommendationsLoaded(
            playlistID: playlistID,
            refreshID: localRefreshID,
            profileScope: scope,
            recommendations: [item],
            reasons: [:]
        ))
        XCTAssertEqual(store.state.recommendedVODs, [item])
        XCTAssertTrue(store.state.isLoadingPersonalizedContent)
        XCTAssertTrue(store.state.actorRecommendationCollections.isEmpty)
        XCTAssertTrue(store.state.mostRatedMovies.isEmpty)

        await store.send(.actorRecommendationsLoaded(
            playlistID: playlistID,
            hideAdult: false,
            refreshID: actorRefreshID,
            profileScope: scope,
            collections: [actorCollection],
            actors: []
        ))
        XCTAssertTrue(store.state.actorRecommendationCollections.isEmpty)

        await store.send(.newEpisodeSeriesLoaded(
            playlistID: playlistID,
            hideAdult: false,
            refreshID: episodeRefreshID,
            profileScope: scope,
            series: []
        ))
        XCTAssertTrue(store.state.actorRecommendationCollections.isEmpty)

        await store.send(.movieRatingShelvesLoaded(
            playlistID: playlistID,
            hideAdult: false,
            refreshID: movieRefreshID,
            shelves: .init(mostRated: [rankedMovie], highestRated: [])
        ))
        XCTAssertTrue(store.state.actorRecommendationCollections.isEmpty)
        XCTAssertTrue(store.state.mostRatedMovies.isEmpty)
        XCTAssertFalse(store.state.hasLoadedMovieRatingDiscovery)

        await store.send(.awardShelvesLoaded(
            playlistID: playlistID,
            hideAdult: false,
            refreshID: awardRefreshID,
            shelves: .init(winners: [awardMovie], nominees: [])
        ))

        XCTAssertEqual(store.state.actorRecommendationCollections, [actorCollection])
        XCTAssertEqual(store.state.recommendedVODs, [item])
        XCTAssertEqual(store.state.mostRatedMovies, [rankedMovie])
        XCTAssertEqual(store.state.awardWinningMovies, [awardMovie])
        XCTAssertTrue(store.state.hasLoadedMovieRatingDiscovery)
        XCTAssertTrue(store.state.hasLoadedAwardDiscovery)
        XCTAssertNil(store.state.activeActorRecommendationRefreshID)
        XCTAssertNil(store.state.activeNewEpisodeRefreshID)
        XCTAssertNil(store.state.activeMovieRatingRefreshID)
        XCTAssertNil(store.state.activeAwardRefreshID)
    }

    func testSecondaryDiscoveryWaitsForItsSectionToBecomeVisible() async throws {
        let playlistID = UUID()
        let profileID = UUID()
        let scope = ProfileContextSnapshot(profileID: profileID, generation: UUID())
        LocalPersonalizationPreferences.setRecommendationsEnabled(true, for: profileID)
        defer { LocalPersonalizationPreferences.setRecommendationsEnabled(false, for: profileID) }

        var initialState = DashboardFeature.State()
        initialState.isVisible = true
        initialState.hasLoadedRemoteData = true
        initialState.hasLoadedLocalData = true
        initialState.isPersonalizationEnabled = true
        initialState.activePlaylistID = playlistID
        initialState.activeProfileScope = scope
        initialState.lastAdultHidden = false

        let store = TestStore(initialState: initialState) {
            DashboardFeature()
        } withDependencies: {
            $0.profileContextClient.snapshot = { scope }
            $0.settingsClient.isAdultContent = { _ in false }
            $0.wikidataAwardClient.fetchRecognitions = { _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.recommendationsSectionBecameVisible)
        let localRefreshID = try XCTUnwrap(store.state.activePersonalizationRefreshID)
        XCTAssertTrue(store.state.hasStartedPersonalizationForCurrentData)
        XCTAssertFalse(store.state.hasStartedPersonalizationDiscoveryForCurrentData)
        XCTAssertNil(store.state.activeActorRecommendationRefreshID)
        XCTAssertNil(store.state.activeMovieRatingRefreshID)
        XCTAssertNil(store.state.activeAwardRefreshID)

        await store.receive(\.localRecommendationsLoaded)

        await store.send(.personalizationDiscoverySectionBecameVisible)
        XCTAssertTrue(store.state.hasStartedPersonalizationDiscoveryForCurrentData)
        XCTAssertNotNil(store.state.activeActorRecommendationRefreshID)
        XCTAssertNotNil(store.state.activeMovieRatingRefreshID)
        XCTAssertNotNil(store.state.activeAwardRefreshID)

        LocalPersonalizationPreferences.setRecommendationsEnabled(false, for: profileID)
        await store.send(.localPersonalizationPreferencesChanged)
        XCTAssertNil(store.state.activeActorRecommendationRefreshID)
        XCTAssertNil(store.state.activeMovieRatingRefreshID)
        XCTAssertNil(store.state.activeAwardRefreshID)
    }

    func testOnDisappearPreservesLoadedPersonalizationAndKeepsDiscoveryInFlight() async {
        let playlistID = UUID()
        let profileID = UUID()
        let scope = ProfileContextSnapshot(profileID: profileID, generation: UUID())
        let series = MediaModels.Item(
            id: "series",
            title: "Series",
            categoryID: "series",
            type: .series
        )
        let recommendation = MediaModels.Item(
            id: "recommendation",
            title: "Recommendation",
            categoryID: "movies",
            type: .vod
        )
        let episodeEntry = NewEpisodeDiscoveryEngine.SeriesEntry(
            series: series,
            newEpisodeCount: 2,
            unwatchedEpisodeCount: 3,
            latestSeason: 1,
            latestEpisodeNumber: 4,
            latestEpisodeTitle: "Episode"
        )

        var initialState = DashboardFeature.State()
        initialState.isVisible = true
        initialState.activePlaylistID = playlistID
        initialState.activeProfileScope = scope
        initialState.lastAdultHidden = false
        initialState.hasLoadedRemoteData = true
        initialState.hasLoadedLocalData = true
        initialState.hasEnteredRecommendationsSection = true
        initialState.hasStartedPersonalizationForCurrentData = true
        initialState.recommendedVODs = [recommendation]
        initialState.newEpisodeSeries = [episodeEntry]
        initialState.favoriteSeriesUnwatchedEpisodeCounts = [series.id: 3]
        initialState.activePersonalizationRefreshID = UUID()
        initialState.activeNewEpisodeRefreshID = UUID()

        let store = TestStore(initialState: initialState) {
            DashboardFeature()
        } withDependencies: {
            $0.profileContextClient.snapshot = { scope }
            $0.wikidataAwardClient.fetchRecognitions = { _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.onDisappear)

        XCTAssertFalse(store.state.isVisible)
        XCTAssertEqual(store.state.recommendedVODs, [recommendation])
        XCTAssertEqual(store.state.newEpisodeSeries, [episodeEntry])
        XCTAssertEqual(store.state.favoriteSeriesUnwatchedEpisodeCounts, [series.id: 3])
        XCTAssertTrue(store.state.hasStartedPersonalizationForCurrentData)
        XCTAssertNotNil(store.state.activePersonalizationRefreshID)
        XCTAssertNotNil(store.state.activeNewEpisodeRefreshID)
    }

    func testOffscreenLocalDatabaseChangesMarkSnapshotStaleWithoutFetching() async {
        var initialState = DashboardFeature.State()
        initialState.hasLoadedLocalData = true

        let store = TestStore(initialState: initialState) {
            DashboardFeature()
        } withDependencies: {
            $0.wikidataAwardClient.fetchRecognitions = { _, _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.localDatabaseDidChange)

        XCTAssertTrue(store.state.needsLocalDataRefresh)
        XCTAssertTrue(store.state.hasLoadedLocalData)
    }
}
