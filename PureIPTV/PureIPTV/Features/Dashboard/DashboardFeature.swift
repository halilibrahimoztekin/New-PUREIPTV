import ComposableArchitecture
import FactoryKit
import Foundation

private enum DashboardPrimaryCatalogResult: Sendable {
    case live([MediaModels.Item]?)
    case movies([MediaModels.Item]?)
    case series([MediaModels.Item]?)
}

@Reducer
public struct DashboardFeature {
    public enum PrimaryCatalog: CaseIterable, Hashable, Sendable {
        case live
        case movies
        case series
    }

    public struct EPGEvent: Equatable, Identifiable, Sendable {
        public let channel: MediaModels.Item
        public let program: EPGProgram
        public let alternateChannels: [MediaModels.Item]

        public var id: String {
            "\(channel.id)::\(program.id)"
        }

        public nonisolated init(channel: MediaModels.Item, program: EPGProgram, alternateChannels: [MediaModels.Item] = []) {
            self.channel = channel
            self.program = program
            self.alternateChannels = alternateChannels
        }
    }

    public struct ExploreCollection: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let items: [MediaModels.Item]

        public nonisolated init(id: String, title: String, items: [MediaModels.Item]) {
            self.id = id
            self.title = title
            self.items = items
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var isLoading: Bool = false
        public var activePlaylistName: String = ""
        public var featuredChannels: [MediaModels.Item] = []
        public var hasResolvedLiveCatalog = false
        public var hasLiveContent = true
        public var hasResolvedMovieCatalog = false
        public var hasMovieContent = true
        public var hasResolvedSeriesCatalog = false
        public var hasSeriesContent = true
        public var failedPrimaryCatalogs: Set<PrimaryCatalog> = []
        public var epgCandidateChannels: [MediaModels.Item] = []
        public var epgCandidatePlaylistID: UUID?
        public var epgCandidateSourceLoaded = false
        public var epgEvents: [EPGEvent] = []
        public var manualEPGChannelMappings: [String: String] = [:]
        public var hasLoadedEPGEvents = false
        public var isSportsHubVisible = true
        public var featuredVODs: [MediaModels.Item] = []
        public var featuredSeries: [MediaModels.Item] = []
        public var newEpisodeSeries: [NewEpisodeDiscoveryEngine.SeriesEntry] = []
        public var mostRatedMovies: [MovieRatingDiscoveryEngine.RankedMovie] = []
        public var highestRatedMovies: [MovieRatingDiscoveryEngine.RankedMovie] = []
        public var hasLoadedMovieRatingDiscovery = false
        public var awardWinningMovies: [AwardDiscoveryEngine.MovieEntry] = []
        public var awardNomineeMovies: [AwardDiscoveryEngine.MovieEntry] = []
        public var hasLoadedAwardDiscovery = false
        public var recommendedVODs: [MediaModels.Item] = []
        public var recommendationReasons: [String: SmartRecommendationEngine.Reason] = [:]
        public var actorRecommendationCollections: [ActorRecommendationEngine.Collection] = []
        public var actorRecommendationMovieCandidates: [MediaModels.Item] = []
        public var actorRecommendationSeriesCandidates: [MediaModels.Item] = []
        public var mostWatchedActors: [ActorRecommendationEngine.MostWatchedActor] = []
        public var selectedActorID: Int?
        public var selectedActorName: String?
        public var selectedActorCollections: [ActorRecommendationEngine.Collection] = []
        public var isLoadingActorFilmography = false
        public var hasLoadedSelectedActorFilmography = false
        public var selectedActorFilmographyRequestID: UUID?
        public var activeNewEpisodeRefreshID: UUID?
        public var activeMovieRatingRefreshID: UUID?
        public var activeAwardRefreshID: UUID?
        public var activeActorRecommendationRefreshID: UUID?
        public var exploreCollections: [ExploreCollection] = []
        public var availableHomeCategoryCollections: [ExploreCollection] = []
        public var pinnedHomeCategoryIDs: [String] = []

        public var pinnedHomeCategoryCollections: [ExploreCollection] {
            let byID = Dictionary(availableHomeCategoryCollections.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return pinnedHomeCategoryIDs.compactMap { byID[$0] }
        }

        public var visibleExploreCollections: [ExploreCollection] {
            let pinnedIDs = Set(pinnedHomeCategoryIDs)
            let pinned = pinnedHomeCategoryCollections
            let automatic = exploreCollections.filter { !pinnedIDs.contains($0.id) }
            return pinned + automatic
        }

        public var homeSections: [HomeSectionConfig] = HomeSectionManager.defaultSections
        public var hasLoadedRemoteData = false
        public var activePlaylistID: UUID?
        public var activePlaylistConfig: PlaylistConfig?
        public var lastRemoteRefreshAt: Date?
        public var activeRefreshID: UUID?
        public var activeEPGRefreshID: UUID?
        public var activeProfileScope: ProfileContextSnapshot?
        public var activePersonalizationRefreshID: UUID?
        public var isPersonalizationEnabled = false
        public var lastSportsHubVisibility: Bool?
        public var deferInitialRemoteRefresh = false

        public var favoriteItems: [FavoriteItem] = []
        public var favoriteSeriesUnwatchedEpisodeCounts: [String: Int] = [:]
        public var watchHistoryItems: [WatchHistoryItem] = []

        public var favoriteIDs: Set<FavoriteIdentity> {
            Set(favoriteItems.map(FavoriteIdentity.init))
        }

        public var favoriteItemsByType: [String: [FavoriteItem]] {
            favoriteItems.reduce(into: [:]) { result, item in
                result[item.type.lowercased(), default: []].append(item)
            }
        }

        public var continueWatchingItems: [WatchHistoryItem] {
            watchHistoryItems.filter { item in
                guard item.duration > 0 else { return true }
                return item.progress / item.duration < 0.90
            }
        }

        public var isLoadingPersonalizedContent: Bool {
            activePersonalizationRefreshID != nil
                || activeActorRecommendationRefreshID != nil
                || activeNewEpisodeRefreshID != nil
                || activeMovieRatingRefreshID != nil
                || activeAwardRefreshID != nil
        }

        public var hasPersonalizedContent: Bool {
            !recommendedVODs.isEmpty
                || !newEpisodeSeries.isEmpty
                || !mostRatedMovies.isEmpty
                || !highestRatedMovies.isEmpty
                || !awardWinningMovies.isEmpty
                || !awardNomineeMovies.isEmpty
                || !actorRecommendationCollections.isEmpty
                || !mostWatchedActors.isEmpty
                || !selectedActorCollections.isEmpty
        }

        public var errorMessage: String?
        public var lastAdultHidden: Bool?

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case onDisappear
        case refreshTapped
        case openManagePlaylistsTapped
        case loadFeaturedData(config: PlaylistConfig, playlistID: UUID?, hideAdult: Bool, loadEPGEvents: Bool, refreshID: UUID)
        case primaryCatalogLoaded(playlistID: UUID?, hideAdult: Bool, refreshID: UUID, profileScope: ProfileContextSnapshot, type: MediaModels.ItemType, items: [MediaModels.Item])
        case loadEPGEvents(config: PlaylistConfig, playlistID: UUID?, refreshID: UUID, channels: [MediaModels.Item])
        case loadLocalData
        case localDataLoaded(favorites: [FavoriteItem], history: [WatchHistoryItem], scope: ProfileContextSnapshot)
        case localPersonalizationPreferencesChanged
        case localRecommendationsLoaded(playlistID: UUID?, refreshID: UUID, profileScope: ProfileContextSnapshot, recommendations: [MediaModels.Item], reasons: [String: SmartRecommendationEngine.Reason])
        case dataLoaded(playlistID: UUID?, hideAdult: Bool, refreshID: UUID, profileScope: ProfileContextSnapshot, channels: [MediaModels.Item]?, epgCandidateChannels: [MediaModels.Item], epgSourceLoaded: Bool, vods: [MediaModels.Item]?, series: [MediaModels.Item]?, failedPrimaryCatalogs: Set<PrimaryCatalog>, actorMovieCandidates: [MediaModels.Item], actorSeriesCandidates: [MediaModels.Item], vodExploreCollections: [ExploreCollection]?, seriesExploreCollections: [ExploreCollection]?, yearExploreCollections: [ExploreCollection]?, homeCategoryCollections: [ExploreCollection]?)
        case actorRecommendationsLoaded(playlistID: UUID?, hideAdult: Bool, refreshID: UUID, profileScope: ProfileContextSnapshot, collections: [ActorRecommendationEngine.Collection], actors: [ActorRecommendationEngine.MostWatchedActor])
        case newEpisodeSeriesLoaded(playlistID: UUID?, hideAdult: Bool, refreshID: UUID, profileScope: ProfileContextSnapshot, series: [NewEpisodeDiscoveryEngine.SeriesEntry])
        case movieRatingShelvesLoaded(playlistID: UUID?, hideAdult: Bool, refreshID: UUID, shelves: MovieRatingDiscoveryEngine.Shelves)
        case awardShelvesLoaded(playlistID: UUID?, hideAdult: Bool, refreshID: UUID, shelves: AwardDiscoveryEngine.Shelves)
        case actorSelected(id: Int, name: String)
        case actorFilmographyLoaded(id: Int, requestID: UUID, playlistID: UUID?, hideAdult: Bool, collections: [ActorRecommendationEngine.Collection])
        case dataFailed(playlistID: UUID?, hideAdult: Bool, refreshID: UUID, Error)
        case epgEventsLoaded(playlistID: UUID?, refreshID: UUID, events: [EPGEvent], succeeded: Bool)
        case channelSelected(MediaModels.Item)
        case mapEPGEventToChannel(playlistID: UUID, event: EPGEvent, channelID: String)
        case vodSelected(MediaModels.Item)
        case seriesSelected(MediaModels.Item)
        case toggleHomeCategoryPin(String)
        case moveHomeCategoryPin(String, Int)

        // Navigation from local items
        case favoriteSelected(FavoriteItem)
        case toggleFavorite(item: MediaModels.Item, type: String)
        case deleteFavorite(FavoriteItem)
        case historySelected(WatchHistoryItem)
        case restartHistorySelected(WatchHistoryItem)
        case deleteHistorySelected(WatchHistoryItem)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item, playlist: [MediaModels.Item]?)
            case didSelectVOD(MediaModels.Item)
            case didSelectSeries(MediaModels.Item)
            case playHistoryItem(WatchHistoryItem)
            case restartHistoryItem(WatchHistoryItem)
            case openManagePlaylists
        }
    }

    private nonisolated enum CancelID: Hashable, Sendable {
        case watchHistoryObserver
        case personalizationPreferencesObserver
        case localRecommendations
        case remoteData
        case actorRecommendations
        case actorFilmography
        case newEpisodeDiscovery
        case movieRatingDiscovery
        case awardDiscovery
    }

    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.tmdbClient) var tmdbClient
    @Dependency(\.wikidataAwardClient) var wikidataAwardClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let playlistRepository = playlistRepository
        let settingsClient = settingsClient
        let tmdbClient = tmdbClient
        let wikidataAwardClient = wikidataAwardClient

        let profileContextClient = profileContextClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                state.activePlaylistConfig = config
                state.activePlaylistName = playlistRepository.getActivePlaylist()?.name ?? ""
                let localEffect: Effect<Action> = .send(.loadLocalData)
                let currentAdultHidden = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdult = settingsClient.isAdultContent
                let playlistID = playlistRepository.getActivePlaylistID()
                let profileScope = profileContextClient.snapshot()
                let profileChanged = state.activeProfileScope != profileScope
                let playlistChanged = state.activePlaylistID != playlistID
                let personalizationEnabled = LocalPersonalizationPreferences.recommendationsEnabled(
                    for: profileScope.profileID
                )
                state.isPersonalizationEnabled = personalizationEnabled
                if profileChanged || playlistChanged || !personalizationEnabled {
                    Self.clearPersonalizationState(&state)
                }
                state.activeProfileScope = profileScope
                let profileCancellationEffect: Effect<Action> = profileChanged
                    ? .merge(
                        .cancel(id: CancelID.localRecommendations),
                        .cancel(id: CancelID.actorRecommendations),
                        .cancel(id: CancelID.actorFilmography),
                        .cancel(id: CancelID.newEpisodeDiscovery)
                    )
                    : .none
                state.pinnedHomeCategoryIDs = HomeCategoryPinStore.load(profileID: profileScope.profileID, playlistID: playlistID)
                state.manualEPGChannelMappings = Self.loadManualEPGChannelMappings(playlistID: playlistID)
                if playlistChanged {
                    state.hasResolvedLiveCatalog = false
                    state.hasLiveContent = true
                    state.hasResolvedMovieCatalog = false
                    state.hasMovieContent = true
                    state.hasResolvedSeriesCatalog = false
                    state.hasSeriesContent = true
                    state.failedPrimaryCatalogs = []
                    state.errorMessage = nil
                    state.newEpisodeSeries = []
                    state.favoriteSeriesUnwatchedEpisodeCounts = [:]
                    state.activeNewEpisodeRefreshID = nil
                    state.mostRatedMovies = []
                    state.highestRatedMovies = []
                    state.hasLoadedMovieRatingDiscovery = false
                    state.activeMovieRatingRefreshID = nil
                    state.awardWinningMovies = []
                    state.awardNomineeMovies = []
                    state.hasLoadedAwardDiscovery = false
                    state.activeAwardRefreshID = nil
                    state.exploreCollections = []
                    state.availableHomeCategoryCollections = []
                    state.actorRecommendationCollections = []
                    state.actorRecommendationMovieCandidates = []
                    state.actorRecommendationSeriesCandidates = []
                    state.mostWatchedActors = []
                    state.selectedActorID = nil
                    state.selectedActorFilmographyRequestID = nil
                    state.selectedActorName = nil
                    state.selectedActorCollections = []
                    state.isLoadingActorFilmography = false
                    state.hasLoadedSelectedActorFilmography = false
                    state.activeActorRecommendationRefreshID = nil
                    state.epgEvents = []
                    state.hasLoadedEPGEvents = false
                    state.epgCandidateChannels = []
                    state.epgCandidatePlaylistID = nil
                    state.epgCandidateSourceLoaded = false
                }
                state.homeSections = HomeSectionManager.shared.sections
                let isSportsHubVisible = state.homeSections.first {
                    $0.type == .sportsHub
                }?.isVisible ?? true
                state.isSportsHubVisible = isSportsHubVisible
                let preferencesChanged = state.lastAdultHidden.map { $0 != currentAdultHidden } ?? false
                if preferencesChanged {
                    Self.clearPersonalizationState(&state)
                    state.hasResolvedLiveCatalog = false
                    state.hasLiveContent = true
                    state.hasResolvedMovieCatalog = false
                    state.hasMovieContent = true
                    state.hasResolvedSeriesCatalog = false
                    state.hasSeriesContent = true
                    state.failedPrimaryCatalogs = []
                    state.errorMessage = nil
                    // Drop both rendered and pin-management candidates before
                    // the refreshed adult-filtered catalog arrives.
                    state.availableHomeCategoryCollections = []
                    state.newEpisodeSeries = []
                    state.favoriteSeriesUnwatchedEpisodeCounts = [:]
                    state.activeNewEpisodeRefreshID = nil
                    state.mostRatedMovies = []
                    state.highestRatedMovies = []
                    state.hasLoadedMovieRatingDiscovery = false
                    state.activeMovieRatingRefreshID = nil
                    state.awardWinningMovies = []
                    state.awardNomineeMovies = []
                    state.hasLoadedAwardDiscovery = false
                    state.activeAwardRefreshID = nil
                    state.exploreCollections = []
                    state.actorRecommendationCollections = []
                    state.actorRecommendationMovieCandidates = []
                    state.actorRecommendationSeriesCandidates = []
                    state.mostWatchedActors = []
                    state.selectedActorID = nil
                    state.selectedActorFilmographyRequestID = nil
                    state.selectedActorName = nil
                    state.selectedActorCollections = []
                    state.isLoadingActorFilmography = false
                    state.hasLoadedSelectedActorFilmography = false
                    state.activeActorRecommendationRefreshID = nil
                    state.epgEvents = state.epgEvents.filter {
                        !currentAdultHidden || (!isAdult($0.channel.title) && !isAdult($0.program.title))
                    }
                    // Candidate channels were fetched using the previous adult-content
                    // setting. Force a fresh catalog response before retrying EPG alone.
                    state.hasLoadedEPGEvents = false
                    state.epgCandidateChannels = []
                    state.epgCandidatePlaylistID = nil
                    state.epgCandidateSourceLoaded = false
                }
                let sportsHubVisibilityChanged = state.lastSportsHubVisibility.map {
                    $0 != isSportsHubVisible
                } ?? false
                if !state.hasLoadedRemoteData || playlistChanged || preferencesChanged {
                    let snapshot = DashboardFeaturedCache.load(
                        playlistID: playlistID,
                        hideAdult: currentAdultHidden
                    )
                    state.featuredChannels = snapshot?.channels.compactMap(\.mediaItem).filter {
                        !currentAdultHidden || !isAdult($0.title)
                    } ?? []
                    state.featuredVODs = snapshot?.vods.compactMap(\.mediaItem).filter {
                        !currentAdultHidden || !isAdult($0.title)
                    } ?? []
                    state.featuredSeries = snapshot?.series.compactMap(\.mediaItem).filter {
                        !currentAdultHidden || !isAdult($0.title)
                    } ?? []
                    state.recommendedVODs = []
                    state.recommendationReasons = [:]
                    state.lastRemoteRefreshAt = snapshot?.updatedAt
                    state.isLoading = snapshot == nil && !state.deferInitialRemoteRefresh
                }
                let shouldReload = !state.deferInitialRemoteRefresh && (
                    !state.hasLoadedRemoteData
                        || playlistChanged
                        || profileChanged
                        || preferencesChanged
                        || sportsHubVisibilityChanged
                        || (state.lastRemoteRefreshAt.map { Date().timeIntervalSince($0) >= 15 * 60 } ?? true)
                        || (state.featuredChannels.isEmpty && state.featuredVODs.isEmpty && state.featuredSeries.isEmpty)
                        || !state.failedPrimaryCatalogs.isEmpty
                )
                state.activePlaylistID = playlistID
                state.lastAdultHidden = currentAdultHidden
                state.lastSportsHubVisibility = isSportsHubVisible
                if !isSportsHubVisible {
                    state.epgEvents = []
                    state.hasLoadedEPGEvents = false
                }
                let needsEPGLoad = isSportsHubVisible && !state.hasLoadedEPGEvents
                let hasCurrentEPGCandidates = state.epgCandidatePlaylistID == playlistID
                    && state.epgCandidateSourceLoaded
                let remoteEffect: Effect<Action>
                if shouldReload || (needsEPGLoad && !hasCurrentEPGCandidates && !state.deferInitialRemoteRefresh) {
                    let refreshID = UUID()
                    state.activeRefreshID = refreshID
                    state.activeEPGRefreshID = isSportsHubVisible ? refreshID : nil
                    remoteEffect = .send(.loadFeaturedData(
                        config: config,
                        playlistID: playlistID,
                        hideAdult: currentAdultHidden,
                        loadEPGEvents: isSportsHubVisible,
                        refreshID: refreshID
                    ))
                } else if needsEPGLoad, !state.deferInitialRemoteRefresh {
                    let refreshID = UUID()
                    state.activeEPGRefreshID = refreshID
                    remoteEffect = .send(.loadEPGEvents(
                        config: config,
                        playlistID: playlistID,
                        refreshID: refreshID,
                        channels: state.epgCandidateChannels
                    ))
                } else {
                    remoteEffect = .none
                }
                let movieRatingEffect: Effect<Action>
                if !shouldReload,
                   !state.hasLoadedMovieRatingDiscovery,
                   !state.actorRecommendationMovieCandidates.isEmpty
                {
                    let requestID = UUID()
                    let movieCandidates = state.actorRecommendationMovieCandidates
                    state.activeMovieRatingRefreshID = requestID
                    movieRatingEffect = .run { send in
                        let shelves = await MovieRatingDiscoveryEngine.discover(
                            from: movieCandidates,
                            using: tmdbClient
                        )
                        guard !Task.isCancelled else { return }
                        await send(.movieRatingShelvesLoaded(
                            playlistID: playlistID,
                            hideAdult: currentAdultHidden,
                            refreshID: requestID,
                            shelves: shelves
                        ))
                    }
                    .cancellable(id: CancelID.movieRatingDiscovery, cancelInFlight: true)
                } else {
                    movieRatingEffect = .none
                }
                let notificationEffect: Effect<Action> = .run { send in
                    for await _ in NotificationCenter.default.notifications(named: .watchHistoryDidChange) {
                        await send(.loadLocalData)
                    }
                }
                .cancellable(id: CancelID.watchHistoryObserver, cancelInFlight: true)
                let personalizationNotificationEffect: Effect<Action> = .run { send in
                    for await _ in NotificationCenter.default.notifications(
                        named: LocalPersonalizationPreferences.didChangeNotification
                    ) {
                        await send(.localPersonalizationPreferencesChanged)
                    }
                }
                .cancellable(id: CancelID.personalizationPreferencesObserver, cancelInFlight: true)
                let awardEffect: Effect<Action>
                if !shouldReload, !state.hasLoadedAwardDiscovery, !state.actorRecommendationMovieCandidates.isEmpty {
                    let requestID = UUID()
                    let candidates = state.actorRecommendationMovieCandidates
                    state.activeAwardRefreshID = requestID
                    awardEffect = .run { send in
                        let shelves = await AwardDiscoveryEngine.discover(from: candidates, using: tmdbClient, awardClient: wikidataAwardClient)
                        guard !Task.isCancelled else { return }
                        await send(.awardShelvesLoaded(playlistID: playlistID, hideAdult: currentAdultHidden, refreshID: requestID, shelves: shelves))
                    }.cancellable(id: CancelID.awardDiscovery, cancelInFlight: true)
                } else {
                    awardEffect = .none
                }
                return .merge(
                    localEffect,
                    remoteEffect,
                    profileCancellationEffect,
                    notificationEffect,
                    personalizationNotificationEffect,
                    movieRatingEffect,
                    awardEffect
                )

            case .refreshTapped:
                guard state.activeRefreshID == nil else { return .none }
                guard let config = state.activePlaylistConfig else { return .none }
                state.deferInitialRemoteRefresh = false
                let refreshID = UUID()
                state.activeRefreshID = refreshID
                state.activeEPGRefreshID = state.isSportsHubVisible ? refreshID : nil
                let loadAction = Action.loadFeaturedData(
                    config: config,
                    playlistID: state.activePlaylistID,
                    hideAdult: state.lastAdultHidden ?? settingsClient.hideAdultContent(),
                    loadEPGEvents: state.isSportsHubVisible,
                    refreshID: refreshID
                )
                if config.type == .plex || config.type == .emby {
                    return .run { send in
                        try? await iptvClient.refreshContent(config, .movies) { _ in }
                        await send(loadAction)
                    }
                }
                return .send(loadAction)

            case let .mapEPGEventToChannel(playlistID, event, channelID):
                let fixtureKey = Self.fixtureMappingKey(title: event.program.title, startTime: event.program.startTime)
                guard state.activePlaylistID == playlistID,
                      state.epgCandidatePlaylistID == playlistID,
                      let currentEvent = state.epgEvents.first(where: {
                          $0.program.id == event.program.id
                              && Self.fixtureMappingKey(title: $0.program.title, startTime: $0.program.startTime) == fixtureKey
                      }),
                      let channel = state.epgCandidateChannels.first(where: { $0.id == channelID && $0.type == .live })
                else { return .none }
                guard !fixtureKey.isEmpty else { return .none }
                let currentFixtureKey = Self.fixtureMappingKey(title: currentEvent.program.title, startTime: currentEvent.program.startTime)
                state.manualEPGChannelMappings[currentFixtureKey] = channel.id
                UserDefaults.standard.set(
                    state.manualEPGChannelMappings,
                    forKey: Self.manualEPGChannelMappingsStorageKey(playlistID: playlistID)
                )
                state.epgEvents = state.epgEvents.map { current in
                    guard Self.fixtureMappingKey(title: current.program.title, startTime: current.program.startTime) == currentFixtureKey else { return current }
                    return EPGEvent(
                        channel: channel,
                        program: current.program,
                        alternateChannels: current.alternateChannels.filter { $0.id != channel.id }
                    )
                }
                return .none

            case .onDisappear:
                if state.activeEPGRefreshID != nil {
                    state.hasLoadedEPGEvents = false
                }
                state.activeRefreshID = nil
                state.activeEPGRefreshID = nil
                state.activeActorRecommendationRefreshID = nil
                state.activePersonalizationRefreshID = nil
                state.isLoadingActorFilmography = false
                state.hasLoadedSelectedActorFilmography = false
                state.selectedActorID = nil
                state.selectedActorFilmographyRequestID = nil
                state.selectedActorName = nil
                state.selectedActorCollections = []
                state.newEpisodeSeries = []
                state.favoriteSeriesUnwatchedEpisodeCounts = [:]
                state.activeNewEpisodeRefreshID = nil
                if state.activeMovieRatingRefreshID != nil,
                   state.mostRatedMovies.isEmpty,
                   state.highestRatedMovies.isEmpty
                {
                    state.hasLoadedMovieRatingDiscovery = false
                }
                state.activeMovieRatingRefreshID = nil
                if state.activeAwardRefreshID != nil, state.awardWinningMovies.isEmpty, state.awardNomineeMovies.isEmpty {
                    state.hasLoadedAwardDiscovery = false
                }
                state.activeAwardRefreshID = nil
                return .merge(
                    .cancel(id: CancelID.remoteData),
                    .cancel(id: CancelID.actorRecommendations),
                    .cancel(id: CancelID.actorFilmography),
                    .cancel(id: CancelID.newEpisodeDiscovery),
                    .cancel(id: CancelID.movieRatingDiscovery),
                    .cancel(id: CancelID.awardDiscovery),
                    .cancel(id: CancelID.watchHistoryObserver),
                    .cancel(id: CancelID.personalizationPreferencesObserver),
                    .cancel(id: CancelID.localRecommendations)
                )

            case .openManagePlaylistsTapped:
                return .send(.delegate(.openManagePlaylists))

            case .loadLocalData:
                let profileScope = profileContextClient.snapshot()
                return .run { send in
                    let favorites = await (try? databaseClient.fetchFavorites(profileScope)) ?? []
                    let history = await (try? databaseClient.fetchWatchHistory(profileScope)) ?? []
                    await send(.localDataLoaded(favorites: favorites, history: history, scope: profileScope))
                }

            case .localPersonalizationPreferencesChanged:
                let profileScope = profileContextClient.snapshot()
                state.activeProfileScope = profileScope
                state.isPersonalizationEnabled = LocalPersonalizationPreferences.recommendationsEnabled(
                    for: profileScope.profileID
                )
                let personalizationCancellations = Effect<Action>.merge(
                    .cancel(id: CancelID.localRecommendations),
                    .cancel(id: CancelID.actorRecommendations),
                    .cancel(id: CancelID.actorFilmography),
                    .cancel(id: CancelID.newEpisodeDiscovery)
                )
                guard state.isPersonalizationEnabled else {
                    Self.clearPersonalizationState(&state)
                    return personalizationCancellations
                }
                Self.clearPersonalizationState(&state)
                return .concatenate(personalizationCancellations, .send(.loadLocalData))

            case let .localDataLoaded(favorites, history, scope):
                guard profileContextClient.snapshot() == scope,
                      state.activeProfileScope == scope
                else { return .none }
                state.favoriteSeriesUnwatchedEpisodeCounts = [:]
                state.favoriteItems = favorites
                state.watchHistoryItems = history
                Self.syncTopShelf(history: history, favorites: favorites, vods: state.featuredVODs)
                guard LocalPersonalizationPreferences.recommendationsEnabled(for: scope.profileID) else {
                    Self.clearPersonalizationState(&state)
                    return .merge(
                        .cancel(id: CancelID.localRecommendations),
                        .cancel(id: CancelID.actorRecommendations),
                        .cancel(id: CancelID.actorFilmography),
                        .cancel(id: CancelID.newEpisodeDiscovery)
                    )
                }
                guard
                    state.hasLoadedRemoteData,
                    let playlistID = state.activePlaylistID,
                    let hideAdult = state.lastAdultHidden
                else { return .none }
                let refreshID = UUID()
                state.activeActorRecommendationRefreshID = refreshID
                state.activeNewEpisodeRefreshID = nil
                let recommendationRequestID = UUID()
                state.activePersonalizationRefreshID = recommendationRequestID
                let movies = state.actorRecommendationMovieCandidates
                let series = state.actorRecommendationSeriesCandidates
                let isAdult = settingsClient.isAdultContent
                let cutoff = LocalPersonalizationPreferences.watchHistoryCutoff(for: scope.profileID)
                let playlistHistory = history.filter { item in
                    guard item.playlistID == playlistID else { return false }
                    return cutoff.map { item.lastWatchedAt > $0 } ?? true
                }
                let eligibleHistory = hideAdult
                    ? playlistHistory.filter { !isAdult($0.title) && !isAdult($0.seriesTitle ?? "") }
                    : playlistHistory
                let playlistFavorites = favorites.filter { $0.playlistID == playlistID }
                let newEpisodeRequestID = UUID()
                state.activeNewEpisodeRefreshID = newEpisodeRequestID
                let safeMovies = hideAdult ? movies.filter { !isAdult($0.title) } : movies
                let safeSeries = hideAdult ? series.filter { !isAdult($0.title) } : series
                let localRecommendationsEffect = Effect<Action>.run { send in
                    let scoredRecommendations = SmartRecommendationEngine.recommendations(
                        from: safeMovies,
                        history: eligibleHistory,
                        favorites: playlistFavorites,
                        limit: 12
                    )
                    let recommendations = scoredRecommendations.map(\.item)
                    let reasons = Dictionary(
                        scoredRecommendations.compactMap { recommendation in
                            recommendation.reason.map { (recommendation.id, $0) }
                        },
                        uniquingKeysWith: { first, _ in first }
                    )
                    guard !Task.isCancelled else { return }
                    await send(.localRecommendationsLoaded(
                        playlistID: playlistID,
                        refreshID: recommendationRequestID,
                        profileScope: scope,
                        recommendations: recommendations,
                        reasons: reasons
                    ))
                }
                .cancellable(id: CancelID.localRecommendations, cancelInFlight: true)
                let actorRecommendationEffect = Effect<Action>.run { send in
                    let collections = await ActorRecommendationEngine.collections(
                        history: eligibleHistory,
                        playlistID: playlistID,
                        movies: safeMovies,
                        series: safeSeries,
                        tmdbClient: tmdbClient
                    )
                    let actors = safeMovies.isEmpty && safeSeries.isEmpty
                        ? []
                        : await ActorRecommendationEngine.mostWatchedActors(
                            history: eligibleHistory,
                            playlistID: playlistID,
                            movies: safeMovies,
                            series: safeSeries,
                            tmdbClient: tmdbClient
                        )
                    guard !Task.isCancelled else { return }
                    await send(.actorRecommendationsLoaded(
                        playlistID: playlistID,
                        hideAdult: hideAdult,
                        refreshID: refreshID,
                        profileScope: scope,
                        collections: collections,
                        actors: actors
                    ))
                }
                .cancellable(id: CancelID.actorRecommendations, cancelInFlight: true)
                let newEpisodeEffect: Effect<Action>
                if let config = state.activePlaylistConfig {
                    newEpisodeEffect = .run { send in
                        let fullEpisodeHistory = await (try? databaseClient.fetchEpisodeWatchHistory(scope)) ?? []
                        let playlistEpisodeHistory = fullEpisodeHistory.filter { item in
                            guard item.playlistID == playlistID else { return false }
                            return cutoff.map { item.lastWatchedAt > $0 } ?? true
                        }
                        let eligibleEpisodeHistory = hideAdult
                            ? playlistEpisodeHistory.filter { !isAdult($0.title) && !isAdult($0.seriesTitle ?? "") }
                            : playlistEpisodeHistory
                        let entries = await NewEpisodeDiscoveryEngine.discover(
                            history: eligibleEpisodeHistory,
                            playlistID: playlistID,
                            seriesCatalog: safeSeries,
                            favoriteSeriesIDs: Set(playlistFavorites.filter {
                                $0.playlistID == playlistID && $0.type.caseInsensitiveCompare("series") == .orderedSame
                            }.map(\.id)),
                            config: config,
                            iptvClient: iptvClient
                        )
                        guard !Task.isCancelled else { return }
                        await send(.newEpisodeSeriesLoaded(
                            playlistID: playlistID,
                            hideAdult: hideAdult,
                            refreshID: newEpisodeRequestID,
                            profileScope: scope,
                            series: entries
                        ))
                    }
                    .cancellable(id: CancelID.newEpisodeDiscovery, cancelInFlight: true)
                } else {
                    state.activeNewEpisodeRefreshID = nil
                    newEpisodeEffect = .none
                }
                return .merge(localRecommendationsEffect, actorRecommendationEffect, newEpisodeEffect)

            case let .actorSelected(id, name):
                if state.selectedActorID == id {
                    state.selectedActorID = nil
                    state.selectedActorFilmographyRequestID = nil
                    state.selectedActorName = nil
                    state.selectedActorCollections = []
                    state.isLoadingActorFilmography = false
                    state.hasLoadedSelectedActorFilmography = false
                    state.selectedActorFilmographyRequestID = nil
                    return .cancel(id: CancelID.actorFilmography)
                }
                state.selectedActorID = id
                state.selectedActorName = name
                state.selectedActorCollections = []
                state.isLoadingActorFilmography = true
                state.hasLoadedSelectedActorFilmography = false
                let requestID = UUID()
                state.selectedActorFilmographyRequestID = requestID
                let playlistID = state.activePlaylistID
                let hideAdult = state.lastAdultHidden ?? false
                let movies = state.actorRecommendationMovieCandidates
                let series = state.actorRecommendationSeriesCandidates
                return .run { send in
                    let collections = await ActorRecommendationEngine.filmography(
                        actorID: id,
                        actorName: name,
                        movies: movies,
                        series: series,
                        tmdbClient: tmdbClient
                    )
                    guard !Task.isCancelled else { return }
                    await send(.actorFilmographyLoaded(id: id, requestID: requestID, playlistID: playlistID, hideAdult: hideAdult, collections: collections))
                }
                .cancellable(id: CancelID.actorFilmography, cancelInFlight: true)

            case let .actorFilmographyLoaded(id, requestID, playlistID, hideAdult, collections):
                guard
                    state.selectedActorID == id,
                    state.selectedActorFilmographyRequestID == requestID,
                    state.activePlaylistID == playlistID,
                    state.lastAdultHidden == hideAdult
                else { return .none }
                state.selectedActorFilmographyRequestID = nil
                state.selectedActorCollections = collections
                state.isLoadingActorFilmography = false
                state.hasLoadedSelectedActorFilmography = true
                return .none

            case let .primaryCatalogLoaded(playlistID, hideAdult, refreshID, profileScope, type, items):
                guard
                    state.activePlaylistID == playlistID,
                    state.lastAdultHidden == hideAdult,
                    state.activeRefreshID == refreshID,
                    profileContextClient.snapshot() == profileScope,
                    state.activeProfileScope == profileScope
                else { return .none }

                switch type {
                case .live:
                    state.failedPrimaryCatalogs.remove(.live)
                    state.hasResolvedLiveCatalog = true
                    state.hasLiveContent = !items.isEmpty
                    state.featuredChannels = items
                case .vod:
                    state.failedPrimaryCatalogs.remove(.movies)
                    state.hasResolvedMovieCatalog = true
                    state.hasMovieContent = !items.isEmpty
                    state.featuredVODs = items
                case .series:
                    state.failedPrimaryCatalogs.remove(.series)
                    state.hasResolvedSeriesCatalog = true
                    state.hasSeriesContent = !items.isEmpty
                    state.featuredSeries = items
                }
                if !items.isEmpty {
                    state.isLoading = false
                }
                return .none

            case let .loadFeaturedData(config, playlistID, hideAdult, loadEPGEvents, refreshID):
                let profileScope = profileContextClient.snapshot()
                let personalizationEnabled = LocalPersonalizationPreferences.recommendationsEnabled(
                    for: profileScope.profileID
                )
                guard
                    state.activePlaylistID == playlistID,
                    state.activeRefreshID == refreshID
                else { return .none }
                state.isPersonalizationEnabled = personalizationEnabled
                state.failedPrimaryCatalogs = []
                state.activePersonalizationRefreshID = nil
                if !personalizationEnabled {
                    Self.clearPersonalizationState(&state)
                }
                state.activeEPGRefreshID = loadEPGEvents ? refreshID : nil
                state.activeActorRecommendationRefreshID = nil
                state.activeNewEpisodeRefreshID = nil
                state.activeMovieRatingRefreshID = nil
                state.hasLoadedMovieRatingDiscovery = false
                state.activeAwardRefreshID = nil
                state.hasLoadedAwardDiscovery = false
                state.isLoadingActorFilmography = false
                state.hasLoadedSelectedActorFilmography = false
                state.selectedActorID = nil
                state.selectedActorFilmographyRequestID = nil
                state.selectedActorName = nil
                state.selectedActorCollections = []
                if loadEPGEvents {
                    state.hasLoadedEPGEvents = false
                } else {
                    state.epgEvents = []
                    state.hasLoadedEPGEvents = false
                }
                state.isLoading = state.featuredChannels.isEmpty
                    && state.featuredVODs.isEmpty
                    && state.featuredSeries.isEmpty
                state.errorMessage = nil
                let isAdult = settingsClient.isAdultContent
                let manualEPGChannelMappings = state.manualEPGChannelMappings
                let movieCollectionPrefix = "Filmler".localized
                let seriesCollectionPrefix = "Diziler".localized
                let liveCollectionPrefix = "Canlı TV".localized
                let remoteEffect = Effect<Action>.run { send in
                    async let liveCategories = try? iptvClient.fetchLiveCategories(config)
                    async let vodCategories = try? iptvClient.fetchVODCategories(config)
                    async let seriesCategories = try? iptvClient.fetchSeriesCategories(config)
                    let primaryCatalogs = await withTaskGroup(
                        of: DashboardPrimaryCatalogResult.self
                    ) { group -> (channels: [MediaModels.Item]?, vods: [MediaModels.Item]?, series: [MediaModels.Item]?) in
                        group.addTask {
                            await .live(try? iptvClient.fetchLiveChannels(config, nil))
                        }
                        group.addTask {
                            await .movies(try? iptvClient.fetchVODs(config, nil))
                        }
                        group.addTask {
                            await .series(try? iptvClient.fetchSeries(config, nil))
                        }

                        var channels: [MediaModels.Item]?
                        var vods: [MediaModels.Item]?
                        var series: [MediaModels.Item]?
                        for await result in group {
                            guard !Task.isCancelled else { continue }
                            switch result {
                            case let .live(items):
                                channels = items
                                if let items, !items.isEmpty {
                                    let shelfItems = Array(
                                        (hideAdult ? items.filter { !isAdult($0.title) } : items).prefix(10)
                                    )
                                    guard !shelfItems.isEmpty else { continue }
                                    await send(.primaryCatalogLoaded(
                                        playlistID: playlistID,
                                        hideAdult: hideAdult,
                                        refreshID: refreshID,
                                        profileScope: profileScope,
                                        type: .live,
                                        items: shelfItems
                                    ))
                                }
                            case let .movies(items):
                                vods = items
                                if let items, !items.isEmpty {
                                    let filteredItems = hideAdult ? items.filter { !isAdult($0.title) } : items
                                    let shelfItems = Array(
                                        filteredItems.sorted {
                                            ($0.addedDate ?? .distantPast) > ($1.addedDate ?? .distantPast)
                                        }.prefix(10)
                                    )
                                    guard !shelfItems.isEmpty else { continue }
                                    await send(.primaryCatalogLoaded(
                                        playlistID: playlistID,
                                        hideAdult: hideAdult,
                                        refreshID: refreshID,
                                        profileScope: profileScope,
                                        type: .vod,
                                        items: shelfItems
                                    ))
                                }
                            case let .series(items):
                                series = items
                                if let items, !items.isEmpty {
                                    let filteredItems = hideAdult ? items.filter { !isAdult($0.title) } : items
                                    let shelfItems = Array(
                                        filteredItems.sorted {
                                            ($0.addedDate ?? .distantPast) > ($1.addedDate ?? .distantPast)
                                        }.prefix(10)
                                    )
                                    guard !shelfItems.isEmpty else { continue }
                                    await send(.primaryCatalogLoaded(
                                        playlistID: playlistID,
                                        hideAdult: hideAdult,
                                        refreshID: refreshID,
                                        profileScope: profileScope,
                                        type: .series,
                                        items: shelfItems
                                    ))
                                }
                            }
                        }
                        return (channels, vods, series)
                    }

                    let fetchedChannels = primaryCatalogs.channels
                    let fetchedLiveCategories = await liveCategories
                    let fetchedVODs = primaryCatalogs.vods
                    let fetchedSeries = primaryCatalogs.series
                    let failedPrimaryCatalogs = Set([
                        fetchedChannels == nil ? PrimaryCatalog.live : nil,
                        fetchedVODs == nil ? PrimaryCatalog.movies : nil,
                        fetchedSeries == nil ? PrimaryCatalog.series : nil,
                    ].compactMap(\.self))
                    let fetchedVODCategories = await vodCategories
                    let fetchedSeriesCategories = await seriesCategories
                    guard !Task.isCancelled else { return }
                    let epgCandidateChannels = fetchedChannels.map { channels in
                        Array((hideAdult ? channels.filter { !isAdult($0.title) } : channels).prefix(200))
                    } ?? []
                    var channels: [MediaModels.Item]?
                    var vods: [MediaModels.Item]?
                    var series: [MediaModels.Item]?
                    var vodExploreCollections: [ExploreCollection]?
                    var seriesExploreCollections: [ExploreCollection]?
                    var yearExploreCollections: [ExploreCollection]?
                    var homeCategoryCollections: [ExploreCollection]?
                    let actorMovieCandidates = fetchedVODs.map {
                        hideAdult ? $0.filter { !isAdult($0.title) } : $0
                    } ?? []
                    let actorSeriesCandidates = fetchedSeries.map {
                        hideAdult ? $0.filter { !isAdult($0.title) } : $0
                    } ?? []
                    if let fetchedChannels {
                        let filtered = hideAdult ? fetchedChannels.filter { !isAdult($0.title) } : fetchedChannels
                        channels = Array(filtered.prefix(10))
                        if let fetchedLiveCategories {
                            homeCategoryCollections = Self.makeCategoryCollections(
                                prefix: "live-category",
                                label: liveCollectionPrefix,
                                categories: fetchedLiveCategories,
                                items: filtered,
                                minimumItems: 1,
                                limit: Int.max
                            )
                        }
                    }

                    if let fetchedVODs {
                        let safeVODs = hideAdult ? fetchedVODs.filter { !isAdult($0.title) } : fetchedVODs
                        let sorted = safeVODs.sorted { ($0.addedDate ?? Date.distantPast) > ($1.addedDate ?? Date.distantPast) }
                        vods = Array(sorted.prefix(10))
                    }

                    if let fetchedSeries {
                        let safeSeries = hideAdult ? fetchedSeries.filter { !isAdult($0.title) } : fetchedSeries
                        let sorted = safeSeries.sorted { ($0.addedDate ?? Date.distantPast) > ($1.addedDate ?? Date.distantPast) }
                        series = Array(sorted.prefix(10))
                    }

                    if let fetchedVODs, let fetchedVODCategories {
                        let safeVODs = hideAdult ? fetchedVODs.filter { !isAdult($0.title) } : fetchedVODs
                        vodExploreCollections = Self.makeCategoryCollections(
                            prefix: "movie-category",
                            label: movieCollectionPrefix,
                            categories: fetchedVODCategories,
                            items: safeVODs
                        )
                        homeCategoryCollections = (homeCategoryCollections ?? []) + Self.makeCategoryCollections(
                            prefix: "movie-category",
                            label: movieCollectionPrefix,
                            categories: fetchedVODCategories,
                            items: safeVODs,
                            limit: Int.max
                        )
                    }
                    if let fetchedSeries, let fetchedSeriesCategories {
                        let safeSeries = hideAdult ? fetchedSeries.filter { !isAdult($0.title) } : fetchedSeries
                        seriesExploreCollections = Self.makeCategoryCollections(
                            prefix: "series-category",
                            label: seriesCollectionPrefix,
                            categories: fetchedSeriesCategories,
                            items: safeSeries
                        )
                        homeCategoryCollections = (homeCategoryCollections ?? []) + Self.makeCategoryCollections(
                            prefix: "series-category",
                            label: seriesCollectionPrefix,
                            categories: fetchedSeriesCategories,
                            items: safeSeries,
                            limit: Int.max
                        )
                    }
                    if let fetchedSeries {
                        let safeSeries = hideAdult ? fetchedSeries.filter { !isAdult($0.title) } : fetchedSeries
                        yearExploreCollections = Self.makeYearCollections(from: safeSeries)
                    }

                    if channels == nil, vods == nil, series == nil {
                        guard !Task.isCancelled else { return }
                        await send(.dataFailed(
                            playlistID: playlistID,
                            hideAdult: hideAdult,
                            refreshID: refreshID,
                            URLError(.cannotLoadFromNetwork)
                        ))
                    } else {
                        guard !Task.isCancelled else { return }
                        await send(.dataLoaded(
                            playlistID: playlistID,
                            hideAdult: hideAdult,
                            refreshID: refreshID,
                            profileScope: profileScope,
                            channels: channels,
                            epgCandidateChannels: epgCandidateChannels,
                            epgSourceLoaded: fetchedChannels != nil,
                            vods: vods,
                            series: series,
                            failedPrimaryCatalogs: failedPrimaryCatalogs,
                            actorMovieCandidates: actorMovieCandidates,
                            actorSeriesCandidates: actorSeriesCandidates,
                            vodExploreCollections: vodExploreCollections,
                            seriesExploreCollections: seriesExploreCollections,
                            yearExploreCollections: yearExploreCollections,
                            homeCategoryCollections: homeCategoryCollections
                        ))
                    }
                    if loadEPGEvents {
                        guard !Task.isCancelled else { return }
                        guard fetchedChannels != nil else {
                            await send(.epgEventsLoaded(
                                playlistID: playlistID,
                                refreshID: refreshID,
                                events: [],
                                succeeded: false
                            ))
                            return
                        }
                        let result = await Self.fetchEPGEvents(
                            config: config,
                            channels: epgCandidateChannels,
                            iptvClient: iptvClient,
                            manualChannelMappings: manualEPGChannelMappings
                        )
                        guard !Task.isCancelled else { return }
                        await send(.epgEventsLoaded(
                            playlistID: playlistID,
                            refreshID: refreshID,
                            events: result.events,
                            succeeded: result.succeeded
                        ))
                    }
                } catch: { error, send in
                    await send(.dataFailed(
                        playlistID: playlistID,
                        hideAdult: hideAdult,
                        refreshID: refreshID,
                        error
                    ))
                }
                let cancellableRemoteEffect = remoteEffect.cancellable(
                    id: CancelID.remoteData,
                    cancelInFlight: true
                )
                let cancellations = Effect<Action>.merge(
                    .cancel(id: CancelID.actorRecommendations),
                    .cancel(id: CancelID.actorFilmography),
                    .cancel(id: CancelID.newEpisodeDiscovery),
                    .cancel(id: CancelID.localRecommendations),
                    .cancel(id: CancelID.movieRatingDiscovery),
                    .cancel(id: CancelID.awardDiscovery)
                )
                return .concatenate(cancellations, cancellableRemoteEffect)

            case let .loadEPGEvents(config, playlistID, refreshID, channels):
                guard
                    state.activePlaylistID == playlistID,
                    state.activeEPGRefreshID == refreshID,
                    state.epgCandidatePlaylistID == playlistID,
                    state.epgCandidateSourceLoaded
                else { return .none }
                let manualEPGChannelMappings = state.manualEPGChannelMappings
                return .run { send in
                    let result = await Self.fetchEPGEvents(
                        config: config,
                        channels: channels,
                        iptvClient: iptvClient,
                        manualChannelMappings: manualEPGChannelMappings
                    )
                    guard !Task.isCancelled else { return }
                    await send(.epgEventsLoaded(
                        playlistID: playlistID,
                        refreshID: refreshID,
                        events: result.events,
                        succeeded: result.succeeded
                    ))
                }
                .cancellable(id: CancelID.remoteData, cancelInFlight: true)

            case let .epgEventsLoaded(playlistID, refreshID, events, succeeded):
                guard
                    state.activePlaylistID == playlistID,
                    state.activeEPGRefreshID == refreshID
                else { return .none }
                state.activeEPGRefreshID = nil
                state.epgEvents = Self.applyingManualChannelMappings(
                    events,
                    channels: state.epgCandidateChannels,
                    mappings: state.manualEPGChannelMappings
                )
                state.hasLoadedEPGEvents = succeeded
                return .none

            case let .localRecommendationsLoaded(playlistID, refreshID, profileScope, recommendations, reasons):
                guard
                    LocalPersonalizationPreferences.recommendationsEnabled(for: profileScope.profileID),
                    profileContextClient.snapshot() == profileScope,
                    state.activeProfileScope == profileScope,
                    state.activePlaylistID == playlistID,
                    state.activePersonalizationRefreshID == refreshID
                else { return .none }
                state.activePersonalizationRefreshID = nil
                state.recommendedVODs = recommendations
                state.recommendationReasons = reasons
                return .none

            case let .dataLoaded(playlistID, hideAdult, refreshID, profileScope, channels, epgCandidateChannels, epgSourceLoaded, vods, series, failedPrimaryCatalogs, actorMovieCandidates, actorSeriesCandidates, vodExploreCollections, seriesExploreCollections, yearExploreCollections, homeCategoryCollections):
                guard
                    state.activePlaylistID == playlistID,
                    state.lastAdultHidden == hideAdult,
                    state.activeRefreshID == refreshID,
                    profileContextClient.snapshot() == profileScope,
                    state.activeProfileScope == profileScope
                else { return .none }
                let personalizationEnabled = LocalPersonalizationPreferences.recommendationsEnabled(
                    for: profileScope.profileID
                )
                state.isLoading = false
                state.hasLoadedRemoteData = true
                state.activeRefreshID = nil
                state.failedPrimaryCatalogs = failedPrimaryCatalogs
                if failedPrimaryCatalogs.isEmpty {
                    state.lastRemoteRefreshAt = Date()
                }
                state.errorMessage = failedPrimaryCatalogs.isEmpty
                    ? nil
                    : URLError(.cannotLoadFromNetwork).localizedDescription
                if let channels {
                    state.hasResolvedLiveCatalog = true
                    state.hasLiveContent = !channels.isEmpty
                    state.featuredChannels = channels
                }
                state.epgCandidateChannels = epgCandidateChannels
                state.epgCandidatePlaylistID = playlistID
                state.epgCandidateSourceLoaded = epgSourceLoaded
                if let vods {
                    state.hasResolvedMovieCatalog = true
                    state.hasMovieContent = !vods.isEmpty
                    state.featuredVODs = vods
                }
                if let series {
                    state.hasResolvedSeriesCatalog = true
                    state.hasSeriesContent = !series.isEmpty
                    state.featuredSeries = series
                }
                state.actorRecommendationMovieCandidates = actorMovieCandidates
                state.actorRecommendationSeriesCandidates = actorSeriesCandidates
                state.activePersonalizationRefreshID = nil
                if !personalizationEnabled {
                    Self.clearPersonalizationState(&state)
                }
                if let vodExploreCollections {
                    state.exploreCollections.removeAll { $0.id.hasPrefix("movie-category:") }
                    state.exploreCollections.append(contentsOf: vodExploreCollections)
                }
                if let seriesExploreCollections {
                    state.exploreCollections.removeAll { $0.id.hasPrefix("series-category:") }
                    state.exploreCollections.append(contentsOf: seriesExploreCollections)
                }
                if let yearExploreCollections {
                    state.exploreCollections.removeAll { $0.id.hasPrefix("year:") }
                    state.exploreCollections.append(contentsOf: yearExploreCollections)
                }
                if let homeCategoryCollections {
                    var merged = state.availableHomeCategoryCollections
                    if channels != nil {
                        merged.removeAll { $0.id.hasPrefix("live-category:") }
                    }
                    if vodExploreCollections != nil {
                        merged.removeAll { $0.id.hasPrefix("movie-category:") }
                    }
                    if seriesExploreCollections != nil {
                        merged.removeAll { $0.id.hasPrefix("series-category:") }
                    }
                    for collection in homeCategoryCollections {
                        merged.removeAll { $0.id == collection.id }
                        merged.append(collection)
                    }
                    state.availableHomeCategoryCollections = merged
                }
                Self.syncTopShelf(history: state.watchHistoryItems, favorites: state.favoriteItems, vods: state.featuredVODs)
                let cachedChannels = state.featuredChannels
                let cachedVODs = state.featuredVODs
                let cachedSeries = state.featuredSeries
                let cacheEffect = Effect<Action>.run { _ in
                    await DashboardFeaturedCache.save(
                        playlistID: playlistID,
                        hideAdult: hideAdult,
                        channels: cachedChannels,
                        vods: cachedVODs,
                        series: cachedSeries
                    )
                }
                let localDataEffect = Effect<Action>.send(.loadLocalData)
                let movieRatingRequestID = UUID()
                state.activeMovieRatingRefreshID = movieRatingRequestID
                let movieRatingEffect = Effect<Action>.run { send in
                    let shelves = await MovieRatingDiscoveryEngine.discover(
                        from: actorMovieCandidates,
                        using: tmdbClient
                    )
                    guard !Task.isCancelled else { return }
                    await send(.movieRatingShelvesLoaded(
                        playlistID: playlistID,
                        hideAdult: hideAdult,
                        refreshID: movieRatingRequestID,
                        shelves: shelves
                    ))
                }
                .cancellable(id: CancelID.movieRatingDiscovery, cancelInFlight: true)
                let awardRequestID = UUID()
                state.activeAwardRefreshID = awardRequestID
                state.hasLoadedAwardDiscovery = false
                let awardEffect = Effect<Action>.run { send in
                    let shelves = await AwardDiscoveryEngine.discover(from: actorMovieCandidates, using: tmdbClient, awardClient: wikidataAwardClient)
                    guard !Task.isCancelled else { return }
                    await send(.awardShelvesLoaded(playlistID: playlistID, hideAdult: hideAdult, refreshID: awardRequestID, shelves: shelves))
                }.cancellable(id: CancelID.awardDiscovery, cancelInFlight: true)
                return .merge(cacheEffect, localDataEffect, movieRatingEffect, awardEffect)

            case let .actorRecommendationsLoaded(playlistID, hideAdult, refreshID, profileScope, collections, actors):
                guard
                    LocalPersonalizationPreferences.recommendationsEnabled(for: profileScope.profileID),
                    profileContextClient.snapshot() == profileScope,
                    state.activeProfileScope == profileScope,
                    state.activePlaylistID == playlistID,
                    state.lastAdultHidden == hideAdult,
                    state.activeActorRecommendationRefreshID == refreshID
                else { return .none }
                state.actorRecommendationCollections = collections
                state.mostWatchedActors = actors
                state.activeActorRecommendationRefreshID = nil
                return .none

            case let .newEpisodeSeriesLoaded(playlistID, hideAdult, refreshID, profileScope, series):
                guard LocalPersonalizationPreferences.recommendationsEnabled(for: profileScope.profileID),
                      profileContextClient.snapshot() == profileScope,
                      state.activeProfileScope == profileScope,
                      state.activePlaylistID == playlistID,
                      state.lastAdultHidden == hideAdult,
                      state.activeNewEpisodeRefreshID == refreshID
                else { return .none }
                state.newEpisodeSeries = series.filter { $0.newEpisodeCount > 0 }
                state.favoriteSeriesUnwatchedEpisodeCounts = Dictionary(
                    series.filter { $0.unwatchedEpisodeCount > 0 }.map { ($0.id, $0.unwatchedEpisodeCount) },
                    uniquingKeysWith: { first, _ in first }
                )
                state.activeNewEpisodeRefreshID = nil
                return .none

            case let .movieRatingShelvesLoaded(playlistID, hideAdult, refreshID, shelves):
                guard
                    state.activePlaylistID == playlistID,
                    state.lastAdultHidden == hideAdult,
                    state.activeMovieRatingRefreshID == refreshID
                else { return .none }
                state.mostRatedMovies = shelves.mostRated
                state.highestRatedMovies = shelves.highestRated
                state.activeMovieRatingRefreshID = nil
                state.hasLoadedMovieRatingDiscovery = true
                return .none

            case let .awardShelvesLoaded(playlistID, hideAdult, refreshID, shelves):
                guard state.activePlaylistID == playlistID, state.lastAdultHidden == hideAdult, state.activeAwardRefreshID == refreshID else { return .none }
                state.awardWinningMovies = shelves.winners
                state.awardNomineeMovies = shelves.nominees
                state.activeAwardRefreshID = nil
                state.hasLoadedAwardDiscovery = true
                return .none

            case let .dataFailed(playlistID, hideAdult, refreshID, error):
                guard
                    state.activePlaylistID == playlistID,
                    state.lastAdultHidden == hideAdult,
                    state.activeRefreshID == refreshID
                else { return .none }
                state.isLoading = false
                state.activeRefreshID = nil
                state.activeEPGRefreshID = nil
                state.activeActorRecommendationRefreshID = nil
                state.hasLoadedEPGEvents = false
                state.failedPrimaryCatalogs = Set(PrimaryCatalog.allCases)
                state.errorMessage = error.localizedDescription
                return .none

            case let .channelSelected(channel):
                return .send(.delegate(.didSelectChannel(channel, playlist: state.featuredChannels)))

            case let .vodSelected(vod):
                return .send(.delegate(.didSelectVOD(vod)))

            case let .seriesSelected(series):
                return .send(.delegate(.didSelectSeries(series)))

            case let .favoriteSelected(fav):
                let itemType: MediaModels.ItemType = switch fav.type {
                case "live": .live
                case "series": .series
                default: .vod
                }
                let item = MediaModels.Item(
                    id: fav.id,
                    title: fav.title,
                    streamURL: fav.streamURL.flatMap { URL(string: $0) },
                    coverURL: fav.coverURL.flatMap { URL(string: $0) },
                    categoryID: "fav",
                    type: itemType
                )
                switch item.type {
                case .live:
                    return .send(.delegate(.didSelectChannel(item, playlist: state.featuredChannels)))
                case .vod:
                    return .send(.delegate(.didSelectVOD(item)))
                case .series:
                    return .send(.delegate(.didSelectSeries(item)))
                }

            case let .toggleFavorite(item, type):
                let profileScope = profileContextClient.snapshot()
                let playlistID = state.activePlaylistID
                let favItem = FavoriteItem(
                    id: item.id,
                    type: type,
                    title: item.title,
                    coverURL: item.coverURL?.absoluteString,
                    streamURL: item.streamURL?.absoluteString,
                    playlistID: playlistID
                )
                if let index = state.favoriteItems.firstIndex(where: { $0.id == item.id && $0.type == type && $0.playlistID == playlistID }) {
                    state.favoriteItems.remove(at: index)
                } else {
                    state.favoriteItems.insert(favItem, at: 0)
                }
                Self.syncTopShelf(history: state.watchHistoryItems, favorites: state.favoriteItems, vods: state.featuredVODs)
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(favItem, profileScope)
                }

            case let .deleteFavorite(fav):
                let profileScope = profileContextClient.snapshot()
                state.favoriteItems.removeAll { $0.id == fav.id && $0.type == fav.type && $0.playlistID == fav.playlistID }
                Self.syncTopShelf(history: state.watchHistoryItems, favorites: state.favoriteItems, vods: state.featuredVODs)
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(fav, profileScope)
                }

            case let .historySelected(hist):
                if hist.streamURL != nil {
                    return .send(.delegate(.playHistoryItem(hist)))
                }

                if hist.type == "episode" {
                    // Route to series details
                    guard let seriesID = hist.seriesID else {
                        // If no seriesID is saved, we cannot open series details.
                        // Fallback or ignore.
                        return .none
                    }
                    let item = MediaModels.Item(
                        id: seriesID,
                        title: hist.seriesTitle ?? hist.title,
                        streamURL: nil, // Series don't have streamURL, episodes do
                        coverURL: hist.coverURL.flatMap { URL(string: $0) },
                        categoryID: "hist",
                        type: .series
                    )
                    return .send(.delegate(.didSelectSeries(item)))
                } else {
                    let item = MediaModels.Item(
                        id: hist.id,
                        title: hist.title,
                        streamURL: nil,
                        coverURL: hist.coverURL.flatMap { URL(string: $0) },
                        categoryID: "hist",
                        type: .vod
                    )
                    return .send(.delegate(.didSelectVOD(item)))
                }

            case let .restartHistorySelected(hist):
                return .send(.delegate(.restartHistoryItem(hist)))

            case let .deleteHistorySelected(hist):
                let profileScope = profileContextClient.snapshot()
                state.watchHistoryItems.removeAll { $0.id == hist.id && $0.type == hist.type && $0.playlistID == hist.playlistID }
                Self.syncTopShelf(history: state.watchHistoryItems, favorites: state.favoriteItems, vods: state.featuredVODs)
                return .run { [id = hist.id] _ in
                    try? await databaseClient.deleteWatchProgress(id, hist.type, hist.playlistID, profileScope)
                }

            case let .toggleHomeCategoryPin(collectionID):
                let profileID = profileContextClient.snapshot().profileID
                guard
                    let playlistID = state.activePlaylistID,
                    let profileID,
                    state.availableHomeCategoryCollections.contains(where: { $0.id == collectionID })
                else { return .none }
                if let index = state.pinnedHomeCategoryIDs.firstIndex(of: collectionID) {
                    state.pinnedHomeCategoryIDs.remove(at: index)
                } else {
                    state.pinnedHomeCategoryIDs.append(collectionID)
                }
                HomeCategoryPinStore.save(
                    state.pinnedHomeCategoryIDs,
                    profileID: profileID,
                    playlistID: playlistID
                )
                return .none

            case let .moveHomeCategoryPin(collectionID, offset):
                let profileID = profileContextClient.snapshot().profileID
                guard
                    let playlistID = state.activePlaylistID,
                    let profileID,
                    let index = state.pinnedHomeCategoryIDs.firstIndex(of: collectionID),
                    state.pinnedHomeCategoryIDs.indices.contains(index + offset)
                else { return .none }
                state.pinnedHomeCategoryIDs.swapAt(index, index + offset)
                HomeCategoryPinStore.save(
                    state.pinnedHomeCategoryIDs,
                    profileID: profileID,
                    playlistID: playlistID
                )
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private nonisolated static func makeCategoryCollections(
        prefix: String,
        label: String,
        categories: [MediaModels.Category],
        items: [MediaModels.Item],
        minimumItems: Int = 3,
        limit: Int = 4
    ) -> [ExploreCollection] {
        let itemsByCategory = Dictionary(grouping: items, by: \.categoryID)
        return categories.compactMap { category -> (Int, ExploreCollection)? in
            guard let matches = itemsByCategory[category.id], matches.count >= minimumItems else { return nil }
            let sortedMatches = matches.sorted {
                let lhsDate = $0.addedDate ?? .distantPast
                let rhsDate = $1.addedDate ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return (
                matches.count,
                ExploreCollection(
                    id: "\(prefix):\(category.id)",
                    title: "\(label) · \(category.name)",
                    items: Array(sortedMatches.prefix(12))
                )
            )
        }
        .sorted {
            if $0.0 != $1.0 {
                return $0.0 > $1.0
            }
            return $0.1.id.localizedStandardCompare($1.1.id) == .orderedAscending
        }
        .prefix(limit)
        .map(\.1)
    }

    private nonisolated static func makeYearCollections(from series: [MediaModels.Item]) -> [ExploreCollection] {
        let datedItems = series.compactMap { item -> (Int, MediaModels.Item)? in
            guard
                let date = item.releaseDate,
                date.count >= 4,
                let year = Int(date.prefix(4)), (1900 ... Calendar.current.component(.year, from: Date()) + 2).contains(year)
            else { return nil }
            return (year, item)
        }
        return Dictionary(grouping: datedItems, by: \.0)
            .compactMap { year, entries -> (Int, ExploreCollection)? in
                let items = entries.map(\.1).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                guard items.count >= 3 else { return nil }
                return (year, ExploreCollection(id: "year:\(year)", title: "\(year)", items: Array(items.prefix(12))))
            }
            .sorted { $0.0 > $1.0 }
            .prefix(4)
            .map(\.1)
    }

    private static func syncTopShelf(
        history: [WatchHistoryItem],
        favorites: [FavoriteItem],
        vods: [MediaModels.Item]
    ) {
        let continueWatching = history.filter { item in
            item.duration <= 0 || item.progress / item.duration < 0.90
        }.prefix(10).map { item in
            let prog = item.duration > 0 ? (item.progress / item.duration) : nil
            let link = TopShelfService.makeDeepLink(
                id: item.id,
                type: item.type,
                title: item.title,
                streamURL: item.streamURL ?? "",
                coverURL: item.coverURL,
                startPosition: item.progress
            )
            return TopShelfItemDTO(
                id: topShelfItemIdentifier(type: item.type, playlistID: item.playlistID, itemID: item.id),
                title: item.title,
                subtitle: item.seriesTitle,
                summary: topShelfContinueSummary(seriesTitle: item.seriesTitle, progress: prog),
                imageURL: item.coverURL,
                deepLinkURL: link,
                progress: prog,
                duration: item.duration > 0 ? item.duration : nil,
                isLive: false
            )
        }

        let favoriteChannels = favorites.filter { $0.type == "live" }.prefix(10).map { fav in
            let link = TopShelfService.makeDeepLink(
                id: fav.id,
                type: "live",
                title: fav.title,
                streamURL: fav.streamURL ?? "",
                coverURL: fav.coverURL
            )
            return TopShelfItemDTO(
                id: topShelfItemIdentifier(type: "live", playlistID: fav.playlistID, itemID: fav.id),
                title: fav.title,
                subtitle: nil,
                summary: "Favori TV Kanalı",
                imageURL: fav.coverURL,
                deepLinkURL: link,
                progress: nil,
                duration: nil,
                isLive: true
            )
        }

        let recentMovies = vods.prefix(10).map { vod in
            let link = TopShelfService.makeDeepLink(
                id: vod.id,
                type: "vod",
                title: vod.title,
                streamURL: vod.streamURL?.absoluteString ?? "",
                coverURL: vod.coverURL?.absoluteString
            )
            return TopShelfItemDTO(
                id: topShelfItemIdentifier(type: "vod", playlistID: vod.playlistID, itemID: vod.id),
                title: vod.title,
                subtitle: nil,
                summary: topShelfMovieSummary(rating: vod.rating, releaseDate: vod.releaseDate, duration: vod.duration),
                imageURL: vod.coverURL?.absoluteString,
                landscapeImageURL: nil,
                deepLinkURL: link,
                progress: nil,
                duration: topShelfDuration(from: vod.duration),
                rating: vod.rating,
                creationDate: topShelfCreationDate(from: vod.releaseDate),
                isLive: false
            )
        }

        TopShelfService.shared.updateTopShelfData(
            continueWatching: Array(continueWatching),
            favoriteChannels: Array(favoriteChannels),
            recentMovies: Array(recentMovies)
        )
    }

    private nonisolated static func topShelfItemIdentifier(type: String, playlistID: UUID?, itemID: String) -> String {
        let playlist = playlistID?.uuidString ?? "default"
        return "\(type):\(playlist):\(itemID)"
    }

    private nonisolated static func topShelfContinueSummary(seriesTitle: String?, progress: Double?) -> String {
        var details = ["Kaldığın yerden devam et"]
        if let seriesTitle, !seriesTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            details.append(seriesTitle)
        }
        if let progress, progress.isFinite, progress > 0 {
            details.append("%\(Int((min(1, progress) * 100).rounded())) izlendi")
        }
        return details.joined(separator: " · ")
    }

    private nonisolated static func topShelfMovieSummary(rating: Double?, releaseDate: String?, duration: String?) -> String? {
        var details: [String] = []
        if let year = releaseDate.flatMap(topShelfYear(from:)) {
            details.append(String(year))
        }
        if let rating, rating.isFinite, rating > 0 {
            details.append("★ \(rating.formatted(.number.precision(.fractionLength(1))))")
        }
        if let duration = duration?.trimmingCharacters(in: .whitespacesAndNewlines),
           topShelfDuration(from: duration) != nil
        {
            details.append(duration)
        }
        return details.isEmpty ? nil : details.joined(separator: " · ")
    }

    private nonisolated static func topShelfCreationDate(from value: String?) -> Date? {
        guard let year = value.flatMap(topShelfYear(from:)) else { return nil }
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = 1
        components.day = 1
        return components.date
    }

    private nonisolated static func topShelfYear(from value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4,
              let year = Int(trimmed.prefix(4)),
              (1900 ... Calendar.current.component(.year, from: .now) + 2).contains(year)
        else {
            return nil
        }
        return year
    }

    private nonisolated static func topShelfDuration(from value: String?) -> Double? {
        guard let value else { return nil }
        let parts = value.split(whereSeparator: \.isWhitespace)
        guard !parts.isEmpty else { return nil }

        var seconds = 0.0
        for part in parts {
            guard let unit = part.last,
                  let amount = Double(part.dropLast()), amount.isFinite, amount >= 0
            else {
                return nil
            }
            switch unit {
            case "h": seconds += amount * 3600
            case "m": seconds += amount * 60
            case "s": seconds += amount
            default: return nil
            }
        }
        return seconds > 0 ? seconds : nil
    }

    private nonisolated static func fetchEPGEvents(
        config: PlaylistConfig,
        channels: [MediaModels.Item],
        iptvClient: IPTVClient,
        manualChannelMappings: [String: String]
    ) async -> (events: [EPGEvent], succeeded: Bool) {
        guard !Task.isCancelled else { return ([], false) }
        let eligibleChannels = Array(channels.filter { channel in
            channel.type == .live && (config.type == .xtream || channel.epgChannelID != nil)
        }.prefix(8))
        guard !eligibleChannels.isEmpty else { return ([], true) }

        let now = Date()
        let maxConcurrentRequests = config.type == .m3u ? 1 : 2
        return await withTaskGroup(of: (MediaModels.Item, [EPGProgram], Bool).self) { group in
            var nextChannelIndex = 0
            let initialRequestCount = min(maxConcurrentRequests, eligibleChannels.count)

            for _ in 0 ..< initialRequestCount {
                guard !Task.isCancelled else { break }
                let channel = eligibleChannels[nextChannelIndex]
                nextChannelIndex += 1
                group.addTask {
                    let epgID = config.type == .m3u ? channel.epgChannelID : channel.id
                    guard let epgID else { return (channel, [], true) }
                    do {
                        let programs = try await iptvClient.fetchShortEPG(config, epgID, 8)
                        return (channel, programs, true)
                    } catch {
                        return (channel, [], false)
                    }
                }
            }

            var events: [EPGEvent] = []
            var succeeded = true
            while !Task.isCancelled, let (channel, programs, requestSucceeded) = await group.next() {
                succeeded = succeeded && requestSucceeded
                events.append(contentsOf: programs.compactMap { program in
                    guard
                        !program.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        program.endTime >= now,
                        program.startTime <= now.addingTimeInterval(24 * 60 * 60)
                    else { return nil }
                    return EPGEvent(channel: channel, program: program)
                })

                if !Task.isCancelled, nextChannelIndex < eligibleChannels.count {
                    let nextChannel = eligibleChannels[nextChannelIndex]
                    nextChannelIndex += 1
                    group.addTask {
                        let epgID = config.type == .m3u ? nextChannel.epgChannelID : nextChannel.id
                        guard let epgID else { return (nextChannel, [], true) }
                        do {
                            let programs = try await iptvClient.fetchShortEPG(config, epgID, 8)
                            return (nextChannel, programs, true)
                        } catch {
                            return (nextChannel, [], false)
                        }
                    }
                }
            }

            let channelsByFixture = Dictionary(grouping: events.filter { Self.isSportsFixtureTitle($0.program.title) }) {
                FuzzySearchEngine.normalize($0.program.title)
            }
            let linkedEvents = events.map { event in
                let fixtureKey = fixtureMappingKey(title: event.program.title, startTime: event.program.startTime)
                let mappedChannel = manualChannelMappings[fixtureKey].flatMap { mappedID in
                    channels.first(where: { $0.id == mappedID })
                }
                let channel = mappedChannel ?? event.channel
                let alternatives = (channelsByFixture[FuzzySearchEngine.normalize(event.program.title)] ?? [])
                    .map(\.channel)
                    .filter { $0.id != channel.id }
                    .reduce(into: [MediaModels.Item]()) { result, channel in
                        if !result.contains(where: { $0.id == channel.id }) {
                            result.append(channel)
                        }
                    }
                return EPGEvent(channel: channel, program: event.program, alternateChannels: alternatives)
            }
            return (linkedEvents.sorted { $0.program.startTime < $1.program.startTime }.prefix(16).map(\.self), succeeded)
        }
    }

    private nonisolated static func isSportsFixtureTitle(_ title: String) -> Bool {
        let lowered = title.lowercased()
        return lowered.contains(" vs ") || lowered.contains(" v ") || title.contains(" - ")
    }

    private static func clearPersonalizationState(_ state: inout State) {
        state.recommendedVODs = []
        state.recommendationReasons = [:]
        state.actorRecommendationCollections = []
        state.mostWatchedActors = []
        state.selectedActorID = nil
        state.selectedActorName = nil
        state.selectedActorCollections = []
        state.isLoadingActorFilmography = false
        state.hasLoadedSelectedActorFilmography = false
        state.selectedActorFilmographyRequestID = nil
        state.newEpisodeSeries = []
        state.favoriteSeriesUnwatchedEpisodeCounts = [:]
        state.activeActorRecommendationRefreshID = nil
        state.activeNewEpisodeRefreshID = nil
        state.activePersonalizationRefreshID = nil
    }

    private nonisolated static func fixtureMappingKey(title: String, startTime: Date) -> String {
        let normalizedTitle = FuzzySearchEngine.normalize(title)
        guard !normalizedTitle.isEmpty else { return "" }
        let utcDay = Int(startTime.timeIntervalSince1970 / 86400)
        return "\(utcDay)::\(normalizedTitle)"
    }

    private nonisolated static func applyingManualChannelMappings(
        _ events: [EPGEvent],
        channels: [MediaModels.Item],
        mappings: [String: String]
    ) -> [EPGEvent] {
        events.map { event in
            let fixtureKey = fixtureMappingKey(title: event.program.title, startTime: event.program.startTime)
            guard let mappedID = mappings[fixtureKey],
                  let channel = channels.first(where: { $0.id == mappedID && $0.type == .live })
            else { return event }
            return EPGEvent(
                channel: channel,
                program: event.program,
                alternateChannels: event.alternateChannels.filter { $0.id != channel.id }
            )
        }
    }

    private static func manualEPGChannelMappingsStorageKey(playlistID: UUID) -> String {
        "Dashboard.manualEPGChannelMappings.\(playlistID.uuidString.lowercased())"
    }

    private static func loadManualEPGChannelMappings(playlistID: UUID?) -> [String: String] {
        guard let playlistID else { return [:] }
        return UserDefaults.standard.dictionary(forKey: manualEPGChannelMappingsStorageKey(playlistID: playlistID)) as? [String: String] ?? [:]
    }
}
