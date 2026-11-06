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

    func testSecondaryPersonalizationShelvesPublishTogether() async {
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
        }
        store.exhaustivity = .off

        await store.send(.localRecommendationsLoaded(
            playlistID: playlistID,
            refreshID: localRefreshID,
            profileScope: scope,
            recommendations: [item],
            reasons: [:]
        ))
        XCTAssertTrue(store.state.recommendedVODs.isEmpty)

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
}
