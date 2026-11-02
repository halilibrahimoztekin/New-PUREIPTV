import ComposableArchitecture
import FactoryKit
import Foundation

public struct DashboardCatalogCountSnapshot: Codable, Equatable, Sendable {
    public var live: Int?
    public var movies: Int?
    public var series: Int?
    public var hidesAdultContent: Bool

    public nonisolated init(
        live: Int? = nil,
        movies: Int? = nil,
        series: Int? = nil,
        hidesAdultContent: Bool = false
    ) {
        self.live = live
        self.movies = movies
        self.series = series
        self.hidesAdultContent = hidesAdultContent
    }

    fileprivate func count(for catalog: DashboardFeature.PrimaryCatalog) -> Int? {
        switch catalog {
        case .live: live
        case .movies: movies
        case .series: series
        }
    }

    fileprivate mutating func setCount(_ count: Int, for catalog: DashboardFeature.PrimaryCatalog) {
        switch catalog {
        case .live: live = count
        case .movies: movies = count
        case .series: series = count
        }
    }
}

public struct DashboardCatalogCountChange: Equatable, Identifiable, Sendable {
    public let catalog: DashboardFeature.PrimaryCatalog
    public let previousCount: Int
    public let currentCount: Int

    public var id: String {
        switch catalog {
        case .live: "live"
        case .movies: "movies"
        case .series: "series"
        }
    }

    public var netChange: Int {
        currentCount - previousCount
    }

    public nonisolated init(catalog: DashboardFeature.PrimaryCatalog, previousCount: Int, currentCount: Int) {
        self.catalog = catalog
        self.previousCount = previousCount
        self.currentCount = currentCount
    }
}

private enum DashboardCatalogCountStore {
    static func update(
        profileID: UUID?,
        playlistID: UUID?,
        eligibleCatalogs: Set<DashboardFeature.PrimaryCatalog>,
        currentCounts: DashboardCatalogCountSnapshot
    ) -> [DashboardCatalogCountChange] {
        guard let playlistID, !eligibleCatalogs.isEmpty else { return [] }
        let profileKey = profileID?.uuidString.lowercased() ?? "default"
        let key = "com.pureiptv.dashboardCatalogCounts.v1.\(profileKey).\(playlistID.uuidString.lowercased())"
        let defaults = UserDefaults.standard
        var previous = defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode(DashboardCatalogCountSnapshot.self, from: $0) }
            ?? DashboardCatalogCountSnapshot()
        let canCompare = previous.hidesAdultContent == currentCounts.hidesAdultContent
        if !canCompare {
            previous.live = nil
            previous.movies = nil
            previous.series = nil
        }
        var changes: [DashboardCatalogCountChange] = []

        for catalog in eligibleCatalogs {
            guard let currentCount = currentCounts.count(for: catalog) else { continue }
            if canCompare,
               let previousCount = previous.count(for: catalog),
               previousCount != currentCount
            {
                changes.append(DashboardCatalogCountChange(
                    catalog: catalog,
                    previousCount: previousCount,
                    currentCount: currentCount
                ))
            }
            previous.setCount(currentCount, for: catalog)
        }
        previous.hidesAdultContent = currentCounts.hidesAdultContent

        if let data = try? JSONEncoder().encode(previous) {
            defaults.set(data, forKey: key)
        }
        return changes.sorted { $0.id < $1.id }
    }
}

private enum DashboardPrimaryCatalogResult: Sendable {
    case live([MediaModels.Item]?)
    case movies([MediaModels.Item]?)
    case series([MediaModels.Item]?)
}

private nonisolated struct FavoriteMediaOrderScope: Hashable, Sendable {
    let type: String
    let playlistID: UUID

    var storageKey: String {
        "\(type.lowercased()):\(playlistID.uuidString.lowercased())"
    }
}

private nonisolated struct FavoriteMediaOrderSave: Sendable {
    let profileID: UUID
    let scope: FavoriteMediaOrderScope
    let snapshot: FavoriteChannelOrderSnapshot
}

private nonisolated struct FavoriteMediaOrderRecord: Sendable {
    let scope: FavoriteMediaOrderScope
    let snapshot: FavoriteChannelOrderSnapshot
}

private nonisolated struct FavoriteSeriesDateJob: Sendable {
    let playlistID: UUID
    let seriesID: String
    let config: PlaylistConfig
}

private nonisolated struct FavoriteSeriesDateResolution: Sendable {
    let playlistID: UUID
    let seriesID: String
    let latestEpisodeDate: Date?
}

private nonisolated struct FavoriteSeriesDateFetchOutcome: Sendable {
    let resolution: FavoriteSeriesDateResolution?
    let failed: Bool
}

private nonisolated func latestFavoriteEpisodeDate(in episodes: [DetailModels.Episode], asOf now: Date) -> Date? {
    episodes.reduce(into: Date?.none) { latest, episode in
        let candidate: Date? = if let releaseDate = episode.releaseDate {
            releaseDate <= now ? releaseDate : nil
        } else if let addedDate = episode.addedDate {
            addedDate <= now ? addedDate : nil
        } else {
            nil
        }
        if let candidate, latest.map({ candidate > $0 }) ?? true {
            latest = candidate
        }
    }
}

@Reducer
public struct DashboardFeature {
    public nonisolated enum PrimaryCatalog: CaseIterable, Hashable, Sendable {
        case live
        case movies
        case series

        var refreshTarget: PlaylistRefreshTarget {
            switch self {
            case .live: .live
            case .movies: .movies
            case .series: .series
            }
        }

        var playlistContentType: PlaylistContentType {
            switch self {
            case .live: .live
            case .movies: .movies
            case .series: .series
            }
        }
    }

    public struct EPGEvent: Equatable, Identifiable, Sendable {
        public let channel: MediaModels.Item
        public let program: EPGProgram
        public let alternateChannels: [MediaModels.Item]
        public let isSportsFixture: Bool

        public var id: String {
            "\(channel.id)::\(program.id)"
        }

        public nonisolated init(
            channel: MediaModels.Item,
            program: EPGProgram,
            alternateChannels: [MediaModels.Item] = [],
            isSportsFixture: Bool? = nil
        ) {
            self.channel = channel
            self.program = program
            self.alternateChannels = alternateChannels
            self.isSportsFixture = isSportsFixture
                ?? SportsHubManager.isSportsFixture(program: program, channelTitle: channel.title)
        }
    }

    public nonisolated struct SportsHubEventGroup: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String?
        public let events: [EPGEvent]
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

    public nonisolated struct RecentLiveChannel: Equatable, Identifiable, Sendable {
        public let channel: MediaModels.Item
        public let playlistID: UUID
        public let playlistName: String
        public let lastWatchedAt: Date
        public let pinnedOrder: Int?
        public let playlistOrder: Int

        public var id: String {
            "\(playlistID.uuidString.lowercased()):\(channel.id)"
        }

        public var isPinned: Bool {
            pinnedOrder != nil
        }

        public nonisolated init(
            channel: MediaModels.Item,
            playlistID: UUID,
            playlistName: String,
            lastWatchedAt: Date,
            pinnedOrder: Int?,
            playlistOrder: Int
        ) {
            self.channel = channel
            self.playlistID = playlistID
            self.playlistName = playlistName
            self.lastWatchedAt = lastWatchedAt
            self.pinnedOrder = pinnedOrder
            self.playlistOrder = playlistOrder
        }
    }

    @ObservableState
    public struct State: Equatable {
        public var isVisible = false
        public var presentationPreferencesGeneration: UUID?
        public var isLoading: Bool = false
        public var activePlaylistName: String = ""
        public var featuredChannels: [MediaModels.Item] = []
        public var recentLiveChannels: [RecentLiveChannel] = []
        public var recentLiveChannelsRequestID: UUID?
        public var pendingRecentLiveChannelMutationIDs: [String: UUID] = [:]
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
        public var followedSportsIDs: Set<String> = []
        public var sportsFollowRecordsByID: [String: SportsFollowSyncRecord] = [:]
        public var pendingSportsFollowIDs: [String: UUID] = [:]
        public var pendingSportsFollowValues: [String: Bool] = [:]
        public var sportsFollowLoadRequestID: UUID?

        public var sportsHubEvents: [EPGEvent] {
            epgEvents.filter(\.isSportsFixture)
        }

        public var sportsHubEventGroups: [SportsHubEventGroup] {
            Self.groupSportsEvents(sportsHubEvents)
        }

        public var followedSportsHubEventGroups: [SportsHubEventGroup] {
            Self.groupSportsEvents(sportsHubEvents, followedSportsIDs: followedSportsIDs)
        }

        private static func groupSportsEvents(
            _ events: [EPGEvent],
            followedSportsIDs: Set<String>? = nil
        ) -> [SportsHubEventGroup] {
            var orderedGroupIDs: [String] = []
            var titlesByGroupID: [String: String] = [:]
            var eventsByGroupID: [String: [EPGEvent]] = [:]

            for event in events {
                let fixture = SportsHubManager.fixtureIdentity(
                    program: event.program,
                    channelTitle: event.channel.title
                )
                let competition = fixture?.competition

                if let followedSportsIDs {
                    guard let fixture else { continue }
                    let followedTeam = [fixture.homeTeam, fixture.awayTeam].contains {
                        followedSportsIDs.contains(SportsFollowSyncRecord.identity(kind: .team, displayName: $0))
                    }
                    let followedCompetition = fixture.competition.map {
                        followedSportsIDs.contains(SportsFollowSyncRecord.identity(kind: .competition, displayName: $0))
                    } ?? false
                    guard followedTeam || followedCompetition else { continue }
                }

                let groupID = competition.map {
                    SportsFollowSyncRecord.identity(kind: .competition, displayName: $0)
                } ?? "sports:other"

                if eventsByGroupID[groupID] == nil {
                    orderedGroupIDs.append(groupID)
                    if let competition {
                        titlesByGroupID[groupID] = competition
                    }
                }
                eventsByGroupID[groupID, default: []].append(event)
            }

            return orderedGroupIDs.compactMap { groupID in
                guard let events = eventsByGroupID[groupID] else { return nil }
                return SportsHubEventGroup(id: groupID, title: titlesByGroupID[groupID], events: events)
            }
        }

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
        public var catalogCountChanges: [DashboardCatalogCountChange] = []
        public var activeRefreshID: UUID?
        public var activeMovieCategoryShelvesRequestID: UUID?
        public var movieCategoryPolicyRevision: UInt64 = 0
        public var activeAutomaticRefreshProfileID: UUID?
        public var activeAutomaticRefreshPlaylistID: UUID?
        public var activeAutomaticRefreshTargets: Set<PrimaryCatalog> = []
        public var activeEPGRefreshID: UUID?
        public var activeProfileScope: ProfileContextSnapshot?
        public var activePersonalizationRefreshID: UUID?
        public var isPersonalizationEnabled = false
        public var lastSportsHubVisibility: Bool?
        public var deferInitialRemoteRefresh = false

        public var favoriteItems: [FavoriteItem] = []
        public var favoriteMediaOrderSnapshots: [String: FavoriteChannelOrderSnapshot] = [:]
        public var favoriteMediaOrderRequestID: UUID?
        public var favoriteSeriesSortMode: FavoriteSeriesSortMode = .existingOrder
        public var favoriteSeriesEpisodeDatesByPlaylist: [UUID: [String: FavoriteSeriesEpisodeDateCacheEntry]] = [:]
        public var favoriteSeriesSortLoadRequestID: UUID?
        public var favoriteSeriesSortRequestID: UUID?
        public var isLoadingFavoriteSeriesSortDates = false
        public var favoriteSeriesSortDidFail = false
        public var favoriteSeriesUnwatchedEpisodeCounts: [String: Int] = [:]
        public var watchHistoryItems: [WatchHistoryItem] = []
        public var hiddenMediaEntries: [HiddenMediaEntry] = []

        public var favoriteIDs: Set<FavoriteIdentity> {
            Set(favoriteItems.map(FavoriteIdentity.init))
        }

        public var hasCompleteFavoriteSeriesEpisodeDates: Bool {
            favoriteItems
                .filter { $0.type.lowercased() == "series" }
                .allSatisfy { favorite in
                    guard let playlistID = favorite.playlistID else { return true }
                    return favoriteSeriesEpisodeDatesByPlaylist[playlistID]?[favorite.id] != nil
                }
        }

        public var favoriteItemsByType: [String: [FavoriteItem]] {
            var grouped = favoriteItems.reduce(into: [String: [FavoriteItem]]()) { result, item in
                result[item.type.lowercased(), default: []].append(item)
            }
            for type in ["vod", "series"] {
                if let items = grouped[type] {
                    grouped[type] = orderedMediaFavorites(items, type: type)
                }
            }
            return grouped
        }

        public var favoriteMoveAvailability: [FavoriteIdentity: Set<Int>] {
            guard activeProfileScope?.profileID != nil else { return [:] }
            var availability: [FavoriteIdentity: Set<Int>] = [:]
            for type in ["vod", "series"] {
                if type == "series", favoriteSeriesSortMode == .newestEpisode {
                    continue
                }
                var grouped: [UUID: [FavoriteItem]] = [:]
                for item in favoriteItemsByType[type] ?? [] {
                    guard let playlistID = item.playlistID else { continue }
                    grouped[playlistID, default: []].append(item)
                }
                for items in grouped.values {
                    for index in items.indices {
                        var offsets: Set<Int> = []
                        if index > 0 {
                            offsets.insert(-1)
                        }
                        if items.indices.contains(index + 1) {
                            offsets.insert(1)
                        }
                        availability[items[index].scopedIdentity] = offsets
                    }
                }
            }
            return availability
        }

        public func canMoveFavorite(_ favorite: FavoriteItem, offset: Int) -> Bool {
            guard offset == -1 || offset == 1,
                  favorite.type.lowercased() == "vod" || favorite.type.lowercased() == "series",
                  !(favorite.type.lowercased() == "series" && favoriteSeriesSortMode == .newestEpisode),
                  let playlistID = favorite.playlistID,
                  activeProfileScope?.profileID != nil
            else { return false }
            let siblings = (favoriteItemsByType[favorite.type.lowercased()] ?? []).filter {
                $0.playlistID == playlistID
            }
            guard let index = siblings.firstIndex(where: { $0.id == favorite.id }) else { return false }
            return siblings.indices.contains(index + offset)
        }

        private func orderedMediaFavorites(_ items: [FavoriteItem], type: String) -> [FavoriteItem] {
            let shouldSortSeriesByNewestEpisode = type == "series"
                && favoriteSeriesSortMode == .newestEpisode
                && hasCompleteFavoriteSeriesEpisodeDates
            var playlistOrder: [UUID: Int] = [:]
            for item in items {
                guard let playlistID = item.playlistID, playlistOrder[playlistID] == nil else { continue }
                playlistOrder[playlistID] = playlistOrder.count
            }

            var orderRanksByPlaylist: [UUID: [String: Int]] = [:]
            var itemsByPlaylist: [UUID: [FavoriteItem]] = [:]
            for item in items {
                guard let playlistID = item.playlistID else { continue }
                itemsByPlaylist[playlistID, default: []].append(item)
            }
            for (playlistID, group) in itemsByPlaylist {
                let scope = FavoriteMediaOrderScope(type: type, playlistID: playlistID)
                guard let snapshot = favoriteMediaOrderSnapshots[scope.storageKey],
                      snapshot.mode == .manual
                else { continue }
                let favoriteIDs = Set(group.map(\.id))
                let providerIDs = group
                    .sorted { favoriteProviderOrder($0, $1) }
                    .map(\.id)
                let normalizedIDs = FavoriteChannelSortMode.normalizedManualIDs(
                    favoriteIDs: favoriteIDs,
                    providerIDs: providerIDs,
                    storedIDs: snapshot.orderedIDs
                )
                orderRanksByPlaylist[playlistID] = Dictionary(
                    normalizedIDs.enumerated().map { ($0.element, $0.offset) },
                    uniquingKeysWith: { first, _ in first }
                )
            }

            return items.sorted { lhs, rhs in
                if lhs.playlistID != rhs.playlistID {
                    switch (lhs.playlistID, rhs.playlistID) {
                    case let (left?, right?):
                        let leftOrder = playlistOrder[left] ?? Int.max
                        let rightOrder = playlistOrder[right] ?? Int.max
                        if leftOrder != rightOrder {
                            return leftOrder < rightOrder
                        }
                    case (_?, nil): return true
                    case (nil, _?): return false
                    case (nil, nil): break
                    }
                }
                if shouldSortSeriesByNewestEpisode,
                   let playlistID = lhs.playlistID, playlistID == rhs.playlistID
                {
                    let leftDate = favoriteSeriesEpisodeDatesByPlaylist[playlistID]?[lhs.id]?.latestEpisodeDate
                    let rightDate = favoriteSeriesEpisodeDatesByPlaylist[playlistID]?[rhs.id]?.latestEpisodeDate
                    switch (leftDate, rightDate) {
                    case let (left?, right?) where left != right:
                        return left > right
                    case (_?, nil): return true
                    case (nil, _?): return false
                    default: break
                    }
                }
                if let playlistID = lhs.playlistID, playlistID == rhs.playlistID,
                   let ranks = orderRanksByPlaylist[playlistID]
                {
                    let leftRank = ranks[lhs.id] ?? Int.max
                    let rightRank = ranks[rhs.id] ?? Int.max
                    if leftRank != rightRank {
                        return leftRank < rightRank
                    }
                }
                return favoriteProviderOrder(lhs, rhs)
            }
        }

        private func favoriteProviderOrder(_ lhs: FavoriteItem, _ rhs: FavoriteItem) -> Bool {
            if lhs.addedAt != rhs.addedAt {
                return lhs.addedAt > rhs.addedAt
            }
            if lhs.title != rhs.title {
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            return lhs.id < rhs.id
        }

        public var continueWatchingItems: [WatchHistoryItem] {
            var seenItemIDs = Set<String>()
            var seenSeriesKeys = Set<String>()
            var deduplicated: [WatchHistoryItem] = []

            let sorted = watchHistoryItems.sorted { $0.lastWatchedAt > $1.lastWatchedAt }
            for item in sorted {
                let type = item.type.lowercased()
                let hiddenIdentity: HiddenMediaIdentity? = if type == "vod" {
                    HiddenMediaIdentity(type: "vod", playlistID: item.playlistID, mediaID: item.id)
                } else if type == "episode", let seriesID = item.seriesID {
                    HiddenMediaIdentity(type: "series", playlistID: item.playlistID, mediaID: seriesID)
                } else {
                    nil
                }
                if let hiddenIdentity, hiddenMediaEntries.contains(where: { $0.identity == hiddenIdentity }) {
                    continue
                }
                if item.duration > 0, item.progress / item.duration >= 0.90 {
                    continue
                }
                guard !seenItemIDs.contains(item.id) else { continue }

                if let seriesID = item.seriesID, !seriesID.isEmpty {
                    let seriesKey = "\(seriesID)|\(item.playlistID?.uuidString ?? "")"
                    guard !seenSeriesKeys.contains(seriesKey) else { continue }
                    seenSeriesKeys.insert(seriesKey)
                }

                seenItemIDs.insert(item.id)
                deduplicated.append(item)
            }
            return deduplicated
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
        case presentationPreferencesSynchronized(generation: UUID, sections: [HomeSectionConfig])
        case refreshTapped
        case dismissCatalogCountSummary
        case movieCategoryPoliciesUpdated
        case movieCategoryShelvesLoaded(playlistID: UUID, requestID: UUID, profileScope: ProfileContextSnapshot, collections: [ExploreCollection])
        case openManagePlaylistsTapped
        case loadRecentLiveChannels
        case loadSportsFollows
        case sportsFollowsLoaded(requestID: UUID, profileScope: ProfileContextSnapshot, records: [SportsFollowSyncRecord]?)
        case sportsFollowsRemoteUpdated(profileScope: ProfileContextSnapshot, records: [SportsFollowSyncRecord])
        case toggleSportsFollow(kind: SportsFollowKind, displayName: String)
        case sportsFollowMutationCompleted(id: String, requestID: UUID, profileScope: ProfileContextSnapshot, records: [SportsFollowSyncRecord])
        case sportsFollowMutationFailed(
            id: String,
            errorMessage: String?,
            requestID: UUID,
            profileScope: ProfileContextSnapshot
        )
        case recentLiveChannelsDidChange(profileID: String)
        case recentLiveChannelsLoaded(requestID: UUID, profileScope: ProfileContextSnapshot, entries: [RecentLiveChannel]?)
        case recentLiveChannelSelected(String)
        case removeRecentLiveChannel(String)
        case togglePinRecentLiveChannel(String)
        case recentLiveChannelMutationCompleted(id: String, requestID: UUID, profileScope: ProfileContextSnapshot)
        case loadFeaturedData(config: PlaylistConfig, playlistID: UUID?, hideAdult: Bool, loadEPGEvents: Bool, catalogsToRefresh: Set<PrimaryCatalog>, refreshID: UUID)
        case primaryCatalogLoaded(playlistID: UUID?, hideAdult: Bool, refreshID: UUID, profileScope: ProfileContextSnapshot, type: MediaModels.ItemType, items: [MediaModels.Item])
        case loadEPGEvents(config: PlaylistConfig, playlistID: UUID?, refreshID: UUID, channels: [MediaModels.Item])
        case loadLocalData
        case localDataLoaded(requestID: UUID, favorites: [FavoriteItem], history: [WatchHistoryItem], hiddenMedia: [HiddenMediaEntry], scope: ProfileContextSnapshot)
        case favoriteMediaOrdersLoaded(requestID: UUID, orders: [String: FavoriteChannelOrderSnapshot], scope: ProfileContextSnapshot)
        case favoriteSeriesSortStateLoaded(requestID: UUID, mode: FavoriteSeriesSortMode, episodeDates: [UUID: [String: FavoriteSeriesEpisodeDateCacheEntry]], scope: ProfileContextSnapshot)
        case setFavoriteSeriesSort(FavoriteSeriesSortMode)
        case favoriteSeriesSortDatesLoaded(requestID: UUID, mode: FavoriteSeriesSortMode, episodeDates: [UUID: [String: FavoriteSeriesEpisodeDateCacheEntry]], scope: ProfileContextSnapshot)
        case favoriteSeriesSortDatesFailed(requestID: UUID, scope: ProfileContextSnapshot)
        case localPersonalizationPreferencesChanged
        case localRecommendationsLoaded(playlistID: UUID?, refreshID: UUID, profileScope: ProfileContextSnapshot, recommendations: [MediaModels.Item], reasons: [String: SmartRecommendationEngine.Reason])
        case dataLoaded(playlistID: UUID?, hideAdult: Bool, refreshID: UUID, profileScope: ProfileContextSnapshot, movieCategoryPolicyRevision: UInt64, catalogsToRefresh: Set<PrimaryCatalog>, catalogCounts: DashboardCatalogCountSnapshot, loadEPGEvents: Bool, channels: [MediaModels.Item]?, epgCandidateChannels: [MediaModels.Item], epgSourceLoaded: Bool, vods: [MediaModels.Item]?, series: [MediaModels.Item]?, failedPrimaryCatalogs: Set<PrimaryCatalog>, actorMovieCandidates: [MediaModels.Item], actorSeriesCandidates: [MediaModels.Item], vodExploreCollections: [ExploreCollection]?, seriesExploreCollections: [ExploreCollection]?, yearExploreCollections: [ExploreCollection]?, homeCategoryCollections: [ExploreCollection]?)
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
        case moveFavorite(FavoriteItem, offset: Int)
        case historySelected(WatchHistoryItem)
        case restartHistorySelected(WatchHistoryItem)
        case deleteHistorySelected(WatchHistoryItem)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case presentHomeSettings(PlaylistConfig)
            case presentHomeCategoryPinManagement(playlistID: UUID?, profileScope: ProfileContextSnapshot?)
            case presentEPGChannelPicker(playlistID: UUID, event: EPGEvent)
            case didSelectChannel(MediaModels.Item, playlist: [MediaModels.Item]?)
            case didSelectVOD(MediaModels.Item)
            case didSelectSeries(MediaModels.Item)
            case playHistoryItem(WatchHistoryItem)
            case restartHistoryItem(WatchHistoryItem)
            case openManagePlaylists
        }
    }

    private nonisolated enum CancelID: Hashable, Sendable {
        case recentLiveChannels
        case recentLiveChannelsObserver
        case localData
        case favoriteMediaOrder
        case favoriteSeriesSortState
        case favoriteSeriesSortDates
        case watchHistoryObserver
        case hiddenMediaObserver
        case personalizationPreferencesObserver
        case localRecommendations
        case remoteData
        case actorRecommendations
        case actorFilmography
        case newEpisodeDiscovery
        case movieRatingDiscovery
        case awardDiscovery
        case presentationPreferences
        case presentationPreferenceObserver
        case sportsFollowLoad
        case sportsFollowObserver
        case sportsFollowMutations
        case movieCategoryShelves
    }

    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.recentChannelsClient) var recentChannelsClient
    @Dependency(\.favoriteChannelOrderClient) var favoriteChannelOrderClient
    @Dependency(\.favoriteSeriesSortClient) var favoriteSeriesSortClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.playlistRefreshScheduleClient) var playlistRefreshScheduleClient
    @Dependency(\.cloudSyncClient) var cloudSyncClient
    @Dependency(\.parentalControlClient) var parentalControlClient
    @Dependency(\.categoryNameRuleClient) var categoryNameRuleClient
    @Dependency(\.tmdbClient) var tmdbClient
    @Dependency(\.wikidataAwardClient) var wikidataAwardClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let playlistRepository = playlistRepository
        let settingsClient = settingsClient
        let playlistRefreshScheduleClient = playlistRefreshScheduleClient
        let cloudSyncClient = cloudSyncClient
        let tmdbClient = tmdbClient
        let wikidataAwardClient = wikidataAwardClient

        let profileContextClient = profileContextClient
        let recentChannelsClient = recentChannelsClient
        let favoriteChannelOrderClient = favoriteChannelOrderClient
        let favoriteSeriesSortClient = favoriteSeriesSortClient
        let parentalControlClient = parentalControlClient
        let categoryNameRuleClient = categoryNameRuleClient
        let databaseClient = databaseClient
        let iptvClient = iptvClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                state.isVisible = true
                let presentationPreferencesGeneration = UUID()
                state.presentationPreferencesGeneration = presentationPreferencesGeneration
                if let previousConfig = state.activePlaylistConfig,
                   previousConfig.playlistID != config.playlistID
                {
                    state.deferInitialRemoteRefresh = !config.automaticallyRefreshCatalogOnStartup
                } else if !config.automaticallyRefreshCatalogOnStartup {
                    state.deferInitialRemoteRefresh = true
                }
                state.activePlaylistConfig = config
                state.activePlaylistName = playlistRepository.getActivePlaylist()?.name ?? ""
                let localEffect: Effect<Action> = .send(.loadLocalData)
                let presentationPreferenceEffect: Effect<Action> = .run { send in
                    guard let sections = try? await cloudSyncClient.syncPresentationPreferences() else { return }
                    await send(.presentationPreferencesSynchronized(
                        generation: presentationPreferencesGeneration,
                        sections: sections
                    ))
                }
                .cancellable(id: CancelID.presentationPreferences, cancelInFlight: true)
                let presentationPreferenceObserverEffect: Effect<Action> = cloudSyncClient.isSyncEnabled()
                    ? .run { send in
                        for await sections in cloudSyncClient.observePresentationPreferenceChanges() {
                            await send(.presentationPreferencesSynchronized(
                                generation: presentationPreferencesGeneration,
                                sections: sections
                            ))
                        }
                    }
                    .cancellable(id: CancelID.presentationPreferenceObserver, cancelInFlight: true)
                    : .none
                let currentAdultHidden = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdult = settingsClient.isAdultContent
                let playlistID = playlistRepository.getActivePlaylistID()
                let profileScope = profileContextClient.snapshot()
                let sportsFollowObserverEffect: Effect<Action> = cloudSyncClient.isSyncEnabled()
                    ? .run { send in
                        for await records in cloudSyncClient.observeSportsFollows(profileScope.profileID) {
                            guard profileContextClient.snapshot() == profileScope else { return }
                            await send(.sportsFollowsRemoteUpdated(profileScope: profileScope, records: records))
                        }
                    }
                    .cancellable(id: CancelID.sportsFollowObserver, cancelInFlight: true)
                    : .none
                let profileChanged = state.activeProfileScope != profileScope
                let playlistChanged = state.activePlaylistID != playlistID
                if profileChanged || playlistChanged {
                    state.catalogCountChanges = []
                    for catalog in state.activeAutomaticRefreshTargets {
                        playlistRefreshScheduleClient.clearAutomaticRefreshAttempt(
                            state.activeAutomaticRefreshProfileID,
                            state.activeAutomaticRefreshPlaylistID,
                            catalog.refreshTarget
                        )
                    }
                    state.activeAutomaticRefreshProfileID = nil
                    state.activeAutomaticRefreshPlaylistID = nil
                    state.activeAutomaticRefreshTargets = []
                    state.activeRefreshID = nil
                    state.activeMovieCategoryShelvesRequestID = nil
                    state.activeEPGRefreshID = nil
                    state.isLoading = false
                }
                if profileChanged || playlistChanged {
                    TopShelfService.shared.updateTopShelfData(continueWatching: [], favoriteChannels: [], recentMovies: [])
                }
                let personalizationEnabled = LocalPersonalizationPreferences.recommendationsEnabled(
                    for: profileScope.profileID
                )
                state.isPersonalizationEnabled = personalizationEnabled
                if profileChanged || playlistChanged || !personalizationEnabled {
                    Self.clearPersonalizationState(&state)
                }
                if profileChanged {
                    state.favoriteMediaOrderSnapshots = [:]
                    state.favoriteMediaOrderRequestID = nil
                    state.favoriteSeriesSortMode = .existingOrder
                    state.favoriteSeriesEpisodeDatesByPlaylist = [:]
                    state.favoriteSeriesSortLoadRequestID = nil
                    state.favoriteSeriesSortRequestID = nil
                    state.isLoadingFavoriteSeriesSortDates = false
                    state.favoriteSeriesSortDidFail = false
                    state.recentLiveChannels = []
                    state.recentLiveChannelsRequestID = nil
                    state.pendingRecentLiveChannelMutationIDs = [:]
                    state.epgEvents = []
                    state.hasLoadedEPGEvents = false
                    state.followedSportsIDs = []
                    state.sportsFollowRecordsByID = [:]
                    state.pendingSportsFollowIDs = [:]
                    state.pendingSportsFollowValues = [:]
                    state.sportsFollowLoadRequestID = nil
                    state.epgCandidateChannels = []
                    state.epgCandidatePlaylistID = nil
                    state.epgCandidateSourceLoaded = false
                }
                state.activeProfileScope = profileScope
                let profileCancellationEffect: Effect<Action> = profileChanged
                    ? .merge(
                        .cancel(id: CancelID.localRecommendations),
                        .cancel(id: CancelID.actorRecommendations),
                        .cancel(id: CancelID.actorFilmography),
                        .cancel(id: CancelID.newEpisodeDiscovery),
                        .cancel(id: CancelID.favoriteSeriesSortState),
                        .cancel(id: CancelID.favoriteSeriesSortDates)
                    )
                    : .none
                let remoteDataCancellationEffect: Effect<Action> = profileChanged || playlistChanged
                    ? .merge(
                        .cancel(id: CancelID.remoteData),
                        .cancel(id: CancelID.movieCategoryShelves)
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
                }
                var catalogsToRefresh = Set<PrimaryCatalog>()
                var automaticallyClaimedCatalogs = Set<PrimaryCatalog>()
                if !state.deferInitialRemoteRefresh, config.automaticallyRefreshCatalogOnStartup {
                    let now = Date()
                    for catalog in PrimaryCatalog.allCases {
                        if catalog == .live, config.type == .plex || config.type == .emby {
                            continue
                        }
                        let target = catalog.refreshTarget
                        let interval = playlistRefreshScheduleClient.interval(
                            profileScope.profileID,
                            playlistID,
                            target,
                            target.defaultInterval
                        )
                        if playlistRefreshScheduleClient.claimAutomaticRefresh(
                            profileScope.profileID,
                            playlistID,
                            target,
                            interval,
                            now
                        ) {
                            catalogsToRefresh.insert(catalog)
                            automaticallyClaimedCatalogs.insert(catalog)
                        }
                    }
                }
                if preferencesChanged, !state.deferInitialRemoteRefresh {
                    catalogsToRefresh = Set(PrimaryCatalog.allCases.filter {
                        !($0 == .live && (config.type == .plex || config.type == .emby))
                    })
                }
                let needsEPGLoad = isSportsHubVisible && !state.hasLoadedEPGEvents
                let shouldLoadEPGEvents = needsEPGLoad
                state.isLoading = !catalogsToRefresh.isEmpty
                    && state.featuredChannels.isEmpty
                    && state.featuredVODs.isEmpty
                    && state.featuredSeries.isEmpty
                    && !state.deferInitialRemoteRefresh
                    && !catalogsToRefresh.isEmpty
                let shouldReload = !state.deferInitialRemoteRefresh
                    && (!catalogsToRefresh.isEmpty || shouldLoadEPGEvents)
                state.activePlaylistID = playlistID
                state.lastAdultHidden = currentAdultHidden
                state.lastSportsHubVisibility = isSportsHubVisible
                if !isSportsHubVisible {
                    state.epgEvents = []
                    state.hasLoadedEPGEvents = false
                }
                let remoteEffect: Effect<Action>
                if shouldReload {
                    let refreshID = UUID()
                    state.activeRefreshID = refreshID
                    state.activeAutomaticRefreshProfileID = automaticallyClaimedCatalogs.isEmpty
                        ? nil
                        : profileScope.profileID
                    state.activeAutomaticRefreshPlaylistID = automaticallyClaimedCatalogs.isEmpty
                        ? nil
                        : playlistID
                    state.activeAutomaticRefreshTargets = automaticallyClaimedCatalogs
                    state.activeEPGRefreshID = shouldLoadEPGEvents ? refreshID : nil
                    remoteEffect = .send(.loadFeaturedData(
                        config: config,
                        playlistID: playlistID,
                        hideAdult: currentAdultHidden,
                        loadEPGEvents: shouldLoadEPGEvents,
                        catalogsToRefresh: catalogsToRefresh,
                        refreshID: refreshID
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
                let hiddenMediaNotificationEffect: Effect<Action> = .run { send in
                    for await _ in NotificationCenter.default.notifications(named: .hiddenMediaDidChange) {
                        await send(.loadLocalData)
                    }
                }
                .cancellable(id: CancelID.hiddenMediaObserver, cancelInFlight: true)
                let recentChannelsNotificationEffect: Effect<Action> = .run { send in
                    for await notification in NotificationCenter.default.notifications(named: .recentChannelsDidChange) {
                        let changedProfileID = notification.userInfo?["profileID"] as? String ?? ""
                        await send(.recentLiveChannelsDidChange(profileID: changedProfileID))
                    }
                }
                .cancellable(id: CancelID.recentLiveChannelsObserver, cancelInFlight: true)
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
                    .send(.loadSportsFollows),
                    .send(.loadRecentLiveChannels),
                    presentationPreferenceEffect,
                    presentationPreferenceObserverEffect,
                    sportsFollowObserverEffect,
                    recentChannelsNotificationEffect,
                    .concatenate(remoteDataCancellationEffect, remoteEffect),
                    profileCancellationEffect,
                    notificationEffect,
                    hiddenMediaNotificationEffect,
                    personalizationNotificationEffect,
                    movieRatingEffect,
                    awardEffect
                )

            case .loadSportsFollows:
                guard state.isVisible else { return .none }
                let profileScope = profileContextClient.snapshot()
                let requestID = UUID()
                state.sportsFollowLoadRequestID = requestID
                return .run { send in
                    let records = try? await cloudSyncClient.loadSportsFollows(profileScope.profileID)
                    guard profileContextClient.snapshot() == profileScope else { return }
                    await send(.sportsFollowsLoaded(
                        requestID: requestID,
                        profileScope: profileScope,
                        records: records
                    ))
                }
                .cancellable(id: CancelID.sportsFollowLoad, cancelInFlight: true)

            case let .sportsFollowsLoaded(requestID, profileScope, records):
                guard state.sportsFollowLoadRequestID == requestID,
                      state.activeProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                state.sportsFollowLoadRequestID = nil
                if let records {
                    Self.applySportsFollowRecords(records, to: &state)
                }
                return .none

            case let .sportsFollowsRemoteUpdated(profileScope, records):
                guard state.isVisible,
                      state.activeProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                Self.applySportsFollowRecords(records, to: &state)
                return .none

            case let .toggleSportsFollow(kind, displayName):
                let profileScope = profileContextClient.snapshot()
                guard state.activeProfileScope == profileScope else { return .none }
                let id = SportsFollowSyncRecord.identity(kind: kind, displayName: displayName)
                guard !id.hasSuffix(":"), state.pendingSportsFollowIDs[id] == nil else { return .none }
                let wasFollowing = state.followedSportsIDs.contains(id)
                let isFollowing = !wasFollowing
                let requestID = UUID()
                state.pendingSportsFollowIDs[id] = requestID
                state.pendingSportsFollowValues[id] = isFollowing
                if isFollowing {
                    state.followedSportsIDs.insert(id)
                } else {
                    state.followedSportsIDs.remove(id)
                }
                return .run { send in
                    do {
                        let records = try await cloudSyncClient.setSportsFollow(
                            profileScope.profileID,
                            kind,
                            displayName,
                            isFollowing
                        )
                        guard profileContextClient.snapshot() == profileScope else { return }
                        await send(.sportsFollowMutationCompleted(
                            id: id,
                            requestID: requestID,
                            profileScope: profileScope,
                            records: records
                        ))
                    } catch {
                        guard profileContextClient.snapshot() == profileScope else { return }
                        let errorMessage: String? = switch error as? SportsFollowSyncError {
                        case .remoteStorageLimitExceeded:
                            AppStrings.Dashboard.sportsFollowSyncLimitExceeded
                        case .remoteStoreUnavailable:
                            AppStrings.Dashboard.sportsFollowSyncUnavailable
                        default:
                            nil
                        }
                        await send(.sportsFollowMutationFailed(
                            id: id,
                            errorMessage: errorMessage,
                            requestID: requestID,
                            profileScope: profileScope
                        ))
                    }
                }
                .cancellable(id: CancelID.sportsFollowMutations, cancelInFlight: false)

            case let .sportsFollowMutationCompleted(id, requestID, profileScope, records):
                guard state.activeProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope,
                      state.pendingSportsFollowIDs[id] == requestID else { return .none }
                state.pendingSportsFollowIDs[id] = nil
                state.pendingSportsFollowValues[id] = nil
                Self.applySportsFollowRecords(records, to: &state)
                return .none

            case let .sportsFollowMutationFailed(id, errorMessage, requestID, profileScope):
                guard state.activeProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope,
                      state.pendingSportsFollowIDs[id] == requestID else { return .none }
                state.pendingSportsFollowIDs[id] = nil
                state.pendingSportsFollowValues[id] = nil
                if let errorMessage {
                    state.errorMessage = errorMessage
                }
                Self.applySportsFollowRecords([], to: &state)
                return .none

            case let .presentationPreferencesSynchronized(generation, sections):
                guard state.isVisible,
                      state.presentationPreferencesGeneration == generation
                else { return .none }
                let wasSportsHubVisible = state.isSportsHubVisible
                state.homeSections = sections
                let isSportsHubVisible = sections.first { $0.type == .sportsHub }?.isVisible ?? true
                state.isSportsHubVisible = isSportsHubVisible
                state.lastSportsHubVisibility = isSportsHubVisible
                if !isSportsHubVisible {
                    state.epgEvents = []
                    state.hasLoadedEPGEvents = false
                    state.activeEPGRefreshID = nil
                    return .none
                }
                guard !wasSportsHubVisible,
                      !state.hasLoadedEPGEvents,
                      state.activeRefreshID == nil,
                      state.epgCandidatePlaylistID == state.activePlaylistID,
                      state.epgCandidateSourceLoaded,
                      let config = state.activePlaylistConfig,
                      let playlistID = state.activePlaylistID
                else { return .none }
                let refreshID = UUID()
                state.activeEPGRefreshID = refreshID
                return .send(.loadEPGEvents(
                    config: config,
                    playlistID: playlistID,
                    refreshID: refreshID,
                    channels: state.epgCandidateChannels
                ))

            case .refreshTapped:
                guard state.isVisible else { return .none }
                guard state.activeRefreshID == nil else { return .none }
                guard let config = state.activePlaylistConfig else { return .none }
                state.catalogCountChanges = []
                state.deferInitialRemoteRefresh = false
                let refreshID = UUID()
                state.activeRefreshID = refreshID
                state.activeEPGRefreshID = state.isSportsHubVisible ? refreshID : nil
                let catalogsToRefresh = Set(PrimaryCatalog.allCases.filter {
                    !($0 == .live && (config.type == .plex || config.type == .emby))
                })
                let loadAction = Action.loadFeaturedData(
                    config: config,
                    playlistID: state.activePlaylistID,
                    hideAdult: state.lastAdultHidden ?? settingsClient.hideAdultContent(),
                    loadEPGEvents: state.isSportsHubVisible,
                    catalogsToRefresh: catalogsToRefresh,
                    refreshID: refreshID
                )
                return .merge(.send(loadAction), .send(.loadRecentLiveChannels))

            case .dismissCatalogCountSummary:
                state.catalogCountChanges = []
                return .none

            case .movieCategoryPoliciesUpdated:
                guard let config = state.activePlaylistConfig,
                      let playlistID = state.activePlaylistID,
                      config.playlistID == playlistID
                else { return .none }
                state.movieCategoryPolicyRevision = state.movieCategoryPolicyRevision == .max
                    ? 0
                    : state.movieCategoryPolicyRevision + 1
                let requestID = UUID()
                state.activeMovieCategoryShelvesRequestID = requestID
                let profileScope = profileContextClient.snapshot()
                let hideAdult = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdultContent: @Sendable (String) -> Bool = settingsClient.isAdultContent
                let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                let blacklistedCategoryIDs = parentalControlClient.blacklistedCategoryIDs()
                let movieCollectionPrefix = "Filmler".localized
                return .run { send in
                    async let categories: [MediaModels.Category]? = try? await iptvClient.fetchVODCategories(config)
                    async let items: [MediaModels.Item]? = try? await iptvClient.fetchVODs(config, nil)
                    async let preferences: [CategoryPreferenceDTO]? = try? await databaseClient.fetchCategoryPreferences(
                        "vod",
                        CategoryPreferenceScope(profileID: profileScope.profileID, playlistID: playlistID)
                    )
                    let nameRules = await categoryNameRuleClient.load(profileScope.profileID, playlistID, "vod")
                    let (fetchedCategories, fetchedItems, loadedPreferences) = await (categories, items, preferences)
                    guard !Task.isCancelled else { return }
                    guard let fetchedCategories, let fetchedItems else {
                        await send(.movieCategoryShelvesLoaded(
                            playlistID: playlistID,
                            requestID: requestID,
                            profileScope: profileScope,
                            collections: []
                        ))
                        return
                    }
                    // If local visibility policy cannot be read, clear the shelves rather
                    // than risk showing a category the user has hidden or locked.
                    let collections = loadedPreferences.map { loadedPreferences in
                        Self.makeMovieCategoryCollections(
                            label: movieCollectionPrefix,
                            categories: fetchedCategories,
                            items: fetchedItems,
                            preferences: loadedPreferences,
                            nameRules: nameRules,
                            hideAdult: hideAdult,
                            isAdultContent: isAdultContent,
                            isKidsMode: isKidsMode,
                            blacklistedCategoryIDs: blacklistedCategoryIDs
                        )
                    } ?? []
                    await send(.movieCategoryShelvesLoaded(
                        playlistID: playlistID,
                        requestID: requestID,
                        profileScope: profileScope,
                        collections: collections
                    ))
                }
                .cancellable(id: CancelID.movieCategoryShelves, cancelInFlight: true)

            case let .movieCategoryShelvesLoaded(playlistID, requestID, profileScope, collections):
                guard state.activePlaylistID == playlistID,
                      state.activeProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope,
                      state.activeMovieCategoryShelvesRequestID == requestID
                else { return .none }
                state.activeMovieCategoryShelvesRequestID = nil
                state.exploreCollections.removeAll { $0.id.hasPrefix("movie-category:") }
                state.exploreCollections.append(contentsOf: collections)
                state.availableHomeCategoryCollections.removeAll { $0.id.hasPrefix("movie-category:") }
                state.availableHomeCategoryCollections.append(contentsOf: collections)
                return .none

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
                        alternateChannels: current.alternateChannels.filter { $0.id != channel.id },
                        isSportsFixture: current.isSportsFixture
                    )
                }
                return .none

            case .onDisappear:
                state.isVisible = false
                state.presentationPreferencesGeneration = nil
                state.sportsFollowLoadRequestID = nil
                for catalog in state.activeAutomaticRefreshTargets {
                    playlistRefreshScheduleClient.clearAutomaticRefreshAttempt(
                        state.activeAutomaticRefreshProfileID,
                        state.activeAutomaticRefreshPlaylistID,
                        catalog.refreshTarget
                    )
                }
                state.activeAutomaticRefreshProfileID = nil
                state.activeAutomaticRefreshPlaylistID = nil
                state.activeAutomaticRefreshTargets = []
                if state.activeEPGRefreshID != nil {
                    state.hasLoadedEPGEvents = false
                }
                state.activeRefreshID = nil
                state.activeMovieCategoryShelvesRequestID = nil
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
                state.recentLiveChannelsRequestID = nil
                state.favoriteMediaOrderRequestID = nil
                state.favoriteSeriesSortLoadRequestID = nil
                state.favoriteSeriesSortRequestID = nil
                state.isLoadingFavoriteSeriesSortDates = false
                return .merge(
                    .cancel(id: CancelID.remoteData),
                    .cancel(id: CancelID.movieCategoryShelves),
                    .cancel(id: CancelID.recentLiveChannels),
                    .cancel(id: CancelID.recentLiveChannelsObserver),
                    .cancel(id: CancelID.localData),
                    .cancel(id: CancelID.favoriteMediaOrder),
                    .cancel(id: CancelID.favoriteSeriesSortState),
                    .cancel(id: CancelID.favoriteSeriesSortDates),
                    .cancel(id: CancelID.actorRecommendations),
                    .cancel(id: CancelID.actorFilmography),
                    .cancel(id: CancelID.newEpisodeDiscovery),
                    .cancel(id: CancelID.movieRatingDiscovery),
                    .cancel(id: CancelID.awardDiscovery),
                    .cancel(id: CancelID.watchHistoryObserver),
                    .cancel(id: CancelID.personalizationPreferencesObserver),
                    .cancel(id: CancelID.presentationPreferences),
                    .cancel(id: CancelID.presentationPreferenceObserver),
                    .cancel(id: CancelID.sportsFollowLoad),
                    .cancel(id: CancelID.sportsFollowObserver),
                    .cancel(id: CancelID.hiddenMediaObserver),
                    .cancel(id: CancelID.localRecommendations)
                )

            case .openManagePlaylistsTapped:
                return .send(.delegate(.openManagePlaylists))

            case let .recentLiveChannelsDidChange(profileID):
                let currentProfileID = profileContextClient.snapshot().profileID?.uuidString ?? ""
                guard state.isVisible, profileID == currentProfileID else { return .none }
                return .send(.loadRecentLiveChannels)

            case .loadRecentLiveChannels:
                guard state.isVisible else { return .none }
                let profileScope = profileContextClient.snapshot()
                let requestID = UUID()
                state.recentLiveChannelsRequestID = requestID
                let hiddenChannelIDs = parentalControlClient.hiddenChannelIDs()
                let blacklistedCategoryIDs = parentalControlClient.blacklistedCategoryIDs()
                let hideAdult = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdultContent = settingsClient.isAdultContent
                return .run { send in
                    let playlists: [SavedPlaylist]
                    switch playlistRepository.readPlaylists() {
                    case let .loaded(savedPlaylists):
                        playlists = savedPlaylists.compactMap { playlist in
                            guard playlist.toPlaylistConfig() != nil else { return nil }
                            return playlist
                        }
                    case .notFound:
                        playlists = []
                    case .failed:
                        await send(.recentLiveChannelsLoaded(
                            requestID: requestID,
                            profileScope: profileScope,
                            entries: nil
                        ))
                        return
                    }

                    let loadedEntries = await withTaskGroup(of: [RecentLiveChannel].self) { group in
                        for (playlistOrder, playlist) in playlists.enumerated() {
                            group.addTask {
                                async let recentSnapshot = recentChannelsClient.fetchScopedRecentChannels(
                                    profileScope.profileID,
                                    playlist.id
                                )
                                async let pinnedIDs = recentChannelsClient.fetchPinnedChannelIDs(
                                    profileScope.profileID,
                                    playlist.id
                                )
                                let (snapshot, pinnedChannelIDs) = await (recentSnapshot, pinnedIDs)
                                guard !Task.isCancelled else { return [] }
                                let pinnedOrderByID = Dictionary(
                                    uniqueKeysWithValues: pinnedChannelIDs.enumerated().map { ($0.element, $0.offset) }
                                )
                                return snapshot.records.compactMap { record -> RecentLiveChannel? in
                                    guard !hiddenChannelIDs.contains(record.id),
                                          !(record.categoryID.map(blacklistedCategoryIDs.contains) ?? false),
                                          !hideAdult || !isAdultContent(record.title)
                                    else { return nil }
                                    let channel = MediaModels.Item(
                                        id: record.id,
                                        title: record.title,
                                        streamURL: record.streamURL,
                                        coverURL: record.coverURL,
                                        categoryID: record.categoryID ?? "",
                                        type: .live,
                                        epgChannelID: record.epgChannelID,
                                        tvArchive: record.tvArchive,
                                        userAgentOverride: playlist.userAgentOverride,
                                        playlistID: playlist.id
                                    )
                                    return RecentLiveChannel(
                                        channel: channel,
                                        playlistID: playlist.id,
                                        playlistName: playlist.name,
                                        lastWatchedAt: record.lastWatchedAt,
                                        pinnedOrder: pinnedOrderByID[record.id],
                                        playlistOrder: playlistOrder
                                    )
                                }
                            }
                        }

                        var entries: [RecentLiveChannel] = []
                        for await playlistEntries in group {
                            entries.append(contentsOf: playlistEntries)
                        }
                        return entries
                    }

                    guard !Task.isCancelled,
                          profileContextClient.snapshot() == profileScope
                    else { return }
                    let sortedEntries = loadedEntries.sorted { lhs, rhs in
                        if lhs.isPinned != rhs.isPinned {
                            return lhs.isPinned
                        }
                        if let lhsPinOrder = lhs.pinnedOrder,
                           let rhsPinOrder = rhs.pinnedOrder,
                           lhsPinOrder != rhsPinOrder
                        {
                            return lhsPinOrder < rhsPinOrder
                        }
                        if lhs.isPinned, lhs.playlistOrder != rhs.playlistOrder {
                            return lhs.playlistOrder < rhs.playlistOrder
                        }
                        if lhs.lastWatchedAt != rhs.lastWatchedAt {
                            return lhs.lastWatchedAt > rhs.lastWatchedAt
                        }
                        if lhs.playlistOrder != rhs.playlistOrder {
                            return lhs.playlistOrder < rhs.playlistOrder
                        }
                        return lhs.id < rhs.id
                    }
                    await send(.recentLiveChannelsLoaded(
                        requestID: requestID,
                        profileScope: profileScope,
                        entries: Array(sortedEntries.prefix(12))
                    ))
                }
                .cancellable(id: CancelID.recentLiveChannels, cancelInFlight: true)

            case let .recentLiveChannelsLoaded(requestID, profileScope, entries):
                guard state.recentLiveChannelsRequestID == requestID,
                      state.activeProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                state.recentLiveChannelsRequestID = nil
                guard let entries else { return .none }
                state.recentLiveChannels = entries
                return .none

            case let .recentLiveChannelSelected(id):
                guard let entry = state.recentLiveChannels.first(where: { $0.id == id }) else { return .none }
                let playlist = entry.playlistID == state.activePlaylistID ? state.featuredChannels : nil
                return .send(.delegate(.didSelectChannel(entry.channel, playlist: playlist)))

            case let .removeRecentLiveChannel(id):
                guard let entry = state.recentLiveChannels.first(where: { $0.id == id }),
                      state.pendingRecentLiveChannelMutationIDs[id] == nil
                else { return .none }
                let profileScope = profileContextClient.snapshot()
                guard state.activeProfileScope == profileScope else { return .none }
                let requestID = UUID()
                state.pendingRecentLiveChannelMutationIDs[id] = requestID
                return .run { send in
                    _ = await recentChannelsClient.removeScopedRecentChannel(
                        entry.channel.id,
                        profileScope.profileID,
                        entry.playlistID
                    )
                    guard profileContextClient.snapshot() == profileScope else { return }
                    await send(.recentLiveChannelMutationCompleted(
                        id: id,
                        requestID: requestID,
                        profileScope: profileScope
                    ))
                }

            case let .togglePinRecentLiveChannel(id):
                guard let entry = state.recentLiveChannels.first(where: { $0.id == id }),
                      state.pendingRecentLiveChannelMutationIDs[id] == nil
                else { return .none }
                let profileScope = profileContextClient.snapshot()
                guard state.activeProfileScope == profileScope else { return .none }
                let requestID = UUID()
                state.pendingRecentLiveChannelMutationIDs[id] = requestID
                return .run { send in
                    _ = await recentChannelsClient.togglePinnedChannel(
                        entry.channel.id,
                        profileScope.profileID,
                        entry.playlistID
                    )
                    guard profileContextClient.snapshot() == profileScope else { return }
                    await send(.recentLiveChannelMutationCompleted(
                        id: id,
                        requestID: requestID,
                        profileScope: profileScope
                    ))
                }

            case let .recentLiveChannelMutationCompleted(id, requestID, profileScope):
                guard profileContextClient.snapshot() == profileScope,
                      state.pendingRecentLiveChannelMutationIDs[id] == requestID
                else { return .none }
                state.pendingRecentLiveChannelMutationIDs.removeValue(forKey: id)
                return .none

            case .loadLocalData:
                guard state.isVisible else { return .none }
                let profileScope = profileContextClient.snapshot()
                let requestID = UUID()
                state.favoriteMediaOrderRequestID = requestID
                state.favoriteSeriesSortLoadRequestID = requestID
                return .run { send in
                    let favorites = await (try? databaseClient.fetchFavorites(profileScope)) ?? []
                    let history = await (try? databaseClient.fetchWatchHistory(profileScope)) ?? []
                    let hiddenMedia = await (try? databaseClient.fetchHiddenMediaItems(nil, profileScope)) ?? []
                    await send(.localDataLoaded(
                        requestID: requestID,
                        favorites: favorites,
                        history: history,
                        hiddenMedia: hiddenMedia,
                        scope: profileScope
                    ))
                }
                .cancellable(id: CancelID.localData, cancelInFlight: true)

            case .localPersonalizationPreferencesChanged:
                guard state.isVisible else { return .none }
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

            case let .localDataLoaded(requestID, favorites, history, hiddenMedia, scope):
                guard profileContextClient.snapshot() == scope,
                      state.activeProfileScope == scope,
                      state.favoriteMediaOrderRequestID == requestID
                else { return .none }
                state.favoriteSeriesUnwatchedEpisodeCounts = [:]
                state.favoriteItems = favorites
                state.watchHistoryItems = history
                state.hiddenMediaEntries = hiddenMedia
                let playlistIDs = Set(playlistRepository.getPlaylists().map(\.id) + favorites.compactMap(\.playlistID))
                let orderScopes = playlistIDs
                    .flatMap { playlistID in
                        ["vod", "series"].map { FavoriteMediaOrderScope(type: $0, playlistID: playlistID) }
                    }
                    .sorted { $0.storageKey < $1.storageKey }
                let orderClient = favoriteChannelOrderClient
                let seriesSortClient = favoriteSeriesSortClient
                let favoriteOrderLoadEffect: Effect<Action> = .run { send in
                    let orders = await withTaskGroup(of: FavoriteMediaOrderRecord.self) { group in
                        for orderScope in orderScopes {
                            group.addTask {
                                let snapshot = await orderClient.loadMediaFavorites(
                                    scope.profileID,
                                    orderScope.playlistID,
                                    orderScope.type
                                )
                                return FavoriteMediaOrderRecord(scope: orderScope, snapshot: snapshot)
                            }
                        }
                        var loaded: [FavoriteMediaOrderRecord] = []
                        for await order in group {
                            loaded.append(order)
                        }
                        return loaded
                    }
                    guard !Task.isCancelled else { return }
                    let snapshots = Dictionary(
                        orders.map { ($0.scope.storageKey, $0.snapshot) },
                        uniquingKeysWith: { _, latest in latest }
                    )
                    await send(.favoriteMediaOrdersLoaded(requestID: requestID, orders: snapshots, scope: scope))
                }
                .cancellable(id: CancelID.favoriteMediaOrder, cancelInFlight: true)
                let seriesPlaylistIDs = Set(favorites.compactMap { item in
                    item.type.lowercased() == "series" ? item.playlistID : nil
                })
                let favoriteSeriesSortStateLoadEffect: Effect<Action> = .run { send in
                    let mode = await seriesSortClient.loadMode(scope.profileID)
                    let episodeDates = await withTaskGroup(of: (UUID, [String: FavoriteSeriesEpisodeDateCacheEntry]).self) { group in
                        for playlistID in seriesPlaylistIDs {
                            group.addTask {
                                let entries = await seriesSortClient.loadEpisodeDates(scope.profileID, playlistID)
                                return (playlistID, entries)
                            }
                        }
                        var caches: [UUID: [String: FavoriteSeriesEpisodeDateCacheEntry]] = [:]
                        for await (playlistID, entries) in group {
                            caches[playlistID] = entries
                        }
                        return caches
                    }
                    guard !Task.isCancelled else { return }
                    await send(.favoriteSeriesSortStateLoaded(
                        requestID: requestID,
                        mode: mode,
                        episodeDates: episodeDates,
                        scope: scope
                    ))
                }
                .cancellable(id: CancelID.favoriteSeriesSortState, cancelInFlight: true)
                Self.syncTopShelf(
                    history: history,
                    favorites: favorites,
                    vods: state.featuredVODs,
                    profileID: scope.profileID,
                    hideAdult: state.lastAdultHidden ?? (settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()),
                    isAdultContent: settingsClient.isAdultContent,
                    hiddenChannelIDs: parentalControlClient.hiddenChannelIDs(),
                    blacklistedCategoryIDs: parentalControlClient.blacklistedCategoryIDs()
                )
                guard LocalPersonalizationPreferences.recommendationsEnabled(for: scope.profileID) else {
                    Self.clearPersonalizationState(&state)
                    return .merge(
                        favoriteOrderLoadEffect,
                        favoriteSeriesSortStateLoadEffect,
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
                else { return .merge(favoriteOrderLoadEffect, favoriteSeriesSortStateLoadEffect) }
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
                return .merge(favoriteOrderLoadEffect, localRecommendationsEffect, actorRecommendationEffect, newEpisodeEffect)

            case let .favoriteMediaOrdersLoaded(requestID, orders, scope):
                guard state.favoriteMediaOrderRequestID == requestID,
                      state.activeProfileScope == scope,
                      profileContextClient.snapshot() == scope
                else { return .none }
                state.favoriteMediaOrderRequestID = nil
                let (snapshots, saves) = Self.mergingFavoriteMediaOrders(
                    favorites: state.favoriteItems,
                    orders: orders,
                    currentSnapshots: state.favoriteMediaOrderSnapshots,
                    profileID: scope.profileID
                )
                state.favoriteMediaOrderSnapshots = snapshots
                guard !saves.isEmpty else { return .none }
                return .run { _ in
                    for save in saves {
                        await favoriteChannelOrderClient.saveMediaFavorites(
                            save.snapshot,
                            save.profileID,
                            save.scope.playlistID,
                            save.scope.type
                        )
                    }
                }

            case let .favoriteSeriesSortStateLoaded(requestID, mode, episodeDates, scope):
                guard state.favoriteSeriesSortLoadRequestID == requestID,
                      state.activeProfileScope == scope,
                      profileContextClient.snapshot() == scope
                else { return .none }
                state.favoriteSeriesSortLoadRequestID = nil
                state.favoriteSeriesSortMode = mode
                var currentSeriesIDsByPlaylist: [UUID: Set<String>] = [:]
                for favorite in state.favoriteItems where favorite.type.lowercased() == "series" {
                    guard let playlistID = favorite.playlistID else { continue }
                    currentSeriesIDsByPlaylist[playlistID, default: []].insert(favorite.id)
                }
                let currentEpisodeDates = episodeDates.reduce(into: [UUID: [String: FavoriteSeriesEpisodeDateCacheEntry]]()) {
                    result, entry in
                    let favoriteIDs = currentSeriesIDsByPlaylist[entry.key] ?? []
                    result[entry.key] = entry.value.filter { favoriteIDs.contains($0.key) }
                }
                state.favoriteSeriesEpisodeDatesByPlaylist = currentEpisodeDates
                state.favoriteSeriesSortDidFail = false
                let cacheCleanupEffect: Effect<Action> = episodeDates == currentEpisodeDates
                    ? .none
                    : .run { _ in
                        for (playlistID, entries) in currentEpisodeDates {
                            await favoriteSeriesSortClient.saveEpisodeDates(entries, scope.profileID, playlistID)
                        }
                    }
                let sortEffect: Effect<Action> = mode == .newestEpisode
                    ? .send(.setFavoriteSeriesSort(.newestEpisode))
                    : .none
                return .merge(cacheCleanupEffect, sortEffect)

            case let .setFavoriteSeriesSort(mode):
                guard let profileScope = state.activeProfileScope,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                state.favoriteSeriesSortLoadRequestID = nil
                if mode == .existingOrder {
                    state.favoriteSeriesSortMode = .existingOrder
                    state.favoriteSeriesSortRequestID = nil
                    state.isLoadingFavoriteSeriesSortDates = false
                    state.favoriteSeriesSortDidFail = false
                    return .merge(
                        .cancel(id: CancelID.favoriteSeriesSortState),
                        .cancel(id: CancelID.favoriteSeriesSortDates),
                        .run { _ in await favoriteSeriesSortClient.saveMode(.existingOrder, profileScope.profileID) }
                    )
                }
                guard state.isVisible else { return .none }
                let requestID = UUID()
                state.favoriteSeriesSortRequestID = requestID
                state.isLoadingFavoriteSeriesSortDates = true
                state.favoriteSeriesSortDidFail = false

                var seriesIDsByPlaylist: [UUID: Set<String>] = [:]
                for favorite in state.favoriteItems where favorite.type.lowercased() == "series" {
                    guard let playlistID = favorite.playlistID else { continue }
                    seriesIDsByPlaylist[playlistID, default: []].insert(favorite.id)
                }
                let playlistIDs = seriesIDsByPlaylist.keys.sorted { $0.uuidString < $1.uuidString }
                let configsByPlaylist = playlistRepository.getPlaylists().reduce(
                    into: [UUID: PlaylistConfig]()
                ) { result, savedPlaylist in
                    guard let config = savedPlaylist.toPlaylistConfig(),
                          let playlistID = config.playlistID
                    else { return }
                    result[playlistID] = config
                }
                let iptvClient = iptvClient
                let sortClient = favoriteSeriesSortClient
                let profileID = profileScope.profileID
                let cacheLifetime: TimeInterval = 24 * 60 * 60
                let fetchEffect: Effect<Action> = .run { send in
                    let now = Date()
                    var episodeDates = await withTaskGroup(of: (UUID, [String: FavoriteSeriesEpisodeDateCacheEntry]).self) { group in
                        for playlistID in playlistIDs {
                            group.addTask {
                                let entries = await sortClient.loadEpisodeDates(profileID, playlistID)
                                return (playlistID, entries)
                            }
                        }
                        var caches: [UUID: [String: FavoriteSeriesEpisodeDateCacheEntry]] = [:]
                        for await (playlistID, entries) in group {
                            let favoriteIDs = seriesIDsByPlaylist[playlistID] ?? []
                            caches[playlistID] = entries.filter { favoriteIDs.contains($0.key) }
                        }
                        return caches
                    }

                    var jobs: [FavoriteSeriesDateJob] = []
                    for playlistID in playlistIDs {
                        let cache = episodeDates[playlistID] ?? [:]
                        for seriesID in (seriesIDsByPlaylist[playlistID] ?? []).sorted() {
                            let cachedEntry = cache[seriesID]
                            let isFresh = cachedEntry.map {
                                $0.resolvedAt <= now && now.timeIntervalSince($0.resolvedAt) < cacheLifetime
                            } ?? false
                            if !isFresh {
                                guard let config = configsByPlaylist[playlistID] else {
                                    await send(.favoriteSeriesSortDatesFailed(requestID: requestID, scope: profileScope))
                                    return
                                }
                                jobs.append(FavoriteSeriesDateJob(
                                    playlistID: playlistID,
                                    seriesID: seriesID,
                                    config: config
                                ))
                            }
                        }
                    }

                    let fetchResult = await withTaskGroup(of: FavoriteSeriesDateFetchOutcome.self) { group in
                        var nextJobIndex = 0
                        var resolutions: [FavoriteSeriesDateResolution] = []
                        var failed = false
                        for _ in 0 ..< min(2, jobs.count) {
                            let job = jobs[nextJobIndex]
                            nextJobIndex += 1
                            group.addTask {
                                do {
                                    let result = try await iptvClient.fetchSeriesInfo(job.config, job.seriesID)
                                    let date = latestFavoriteEpisodeDate(in: result.episodes, asOf: now)
                                    return FavoriteSeriesDateFetchOutcome(
                                        resolution: FavoriteSeriesDateResolution(
                                            playlistID: job.playlistID,
                                            seriesID: job.seriesID,
                                            latestEpisodeDate: date
                                        ),
                                        failed: false
                                    )
                                } catch {
                                    return FavoriteSeriesDateFetchOutcome(resolution: nil, failed: true)
                                }
                            }
                        }
                        while let outcome = await group.next() {
                            guard !outcome.failed, let resolution = outcome.resolution else {
                                failed = true
                                group.cancelAll()
                                break
                            }
                            resolutions.append(resolution)
                            if nextJobIndex < jobs.count {
                                let job = jobs[nextJobIndex]
                                nextJobIndex += 1
                                group.addTask {
                                    do {
                                        let result = try await iptvClient.fetchSeriesInfo(job.config, job.seriesID)
                                        let date = latestFavoriteEpisodeDate(in: result.episodes, asOf: now)
                                        return FavoriteSeriesDateFetchOutcome(
                                            resolution: FavoriteSeriesDateResolution(
                                                playlistID: job.playlistID,
                                                seriesID: job.seriesID,
                                                latestEpisodeDate: date
                                            ),
                                            failed: false
                                        )
                                    } catch {
                                        return FavoriteSeriesDateFetchOutcome(resolution: nil, failed: true)
                                    }
                                }
                            }
                        }
                        return (resolutions, failed)
                    }
                    guard !Task.isCancelled, profileContextClient.snapshot() == profileScope else { return }
                    guard !fetchResult.1 else {
                        await send(.favoriteSeriesSortDatesFailed(requestID: requestID, scope: profileScope))
                        return
                    }
                    for resolution in fetchResult.0 {
                        episodeDates[resolution.playlistID, default: [:]][resolution.seriesID] =
                            FavoriteSeriesEpisodeDateCacheEntry(
                                latestEpisodeDate: resolution.latestEpisodeDate,
                                resolvedAt: now
                            )
                    }
                    for playlistID in playlistIDs {
                        guard !Task.isCancelled else { return }
                        await sortClient.saveEpisodeDates(episodeDates[playlistID] ?? [:], profileID, playlistID)
                    }
                    guard !Task.isCancelled, profileContextClient.snapshot() == profileScope else { return }
                    await send(.favoriteSeriesSortDatesLoaded(
                        requestID: requestID,
                        mode: .newestEpisode,
                        episodeDates: episodeDates,
                        scope: profileScope
                    ))
                }
                .cancellable(id: CancelID.favoriteSeriesSortDates, cancelInFlight: true)
                return .merge(.cancel(id: CancelID.favoriteSeriesSortState), fetchEffect)

            case let .favoriteSeriesSortDatesLoaded(requestID, mode, episodeDates, scope):
                guard state.favoriteSeriesSortRequestID == requestID,
                      state.activeProfileScope == scope,
                      profileContextClient.snapshot() == scope
                else { return .none }
                let everyFavoriteWasResolved = state.favoriteItems
                    .filter { $0.type.lowercased() == "series" }
                    .allSatisfy { favorite in
                        guard let playlistID = favorite.playlistID else { return true }
                        return episodeDates[playlistID]?[favorite.id] != nil
                    }
                guard everyFavoriteWasResolved else {
                    state.favoriteSeriesSortRequestID = nil
                    state.isLoadingFavoriteSeriesSortDates = false
                    state.favoriteSeriesSortDidFail = true
                    return .none
                }
                state.favoriteSeriesSortRequestID = nil
                state.isLoadingFavoriteSeriesSortDates = false
                state.favoriteSeriesSortMode = mode
                var currentSeriesIDsByPlaylist: [UUID: Set<String>] = [:]
                for favorite in state.favoriteItems where favorite.type.lowercased() == "series" {
                    guard let playlistID = favorite.playlistID else { continue }
                    currentSeriesIDsByPlaylist[playlistID, default: []].insert(favorite.id)
                }
                let currentEpisodeDates = episodeDates.reduce(into: [UUID: [String: FavoriteSeriesEpisodeDateCacheEntry]]()) {
                    result, entry in
                    let favoriteIDs = currentSeriesIDsByPlaylist[entry.key] ?? []
                    result[entry.key] = entry.value.filter { favoriteIDs.contains($0.key) }
                }
                state.favoriteSeriesEpisodeDatesByPlaylist = currentEpisodeDates
                state.favoriteSeriesSortDidFail = false
                return .run { _ in
                    await favoriteSeriesSortClient.saveMode(mode, scope.profileID)
                    for (playlistID, entries) in currentEpisodeDates {
                        await favoriteSeriesSortClient.saveEpisodeDates(entries, scope.profileID, playlistID)
                    }
                }

            case let .favoriteSeriesSortDatesFailed(requestID, scope):
                guard state.favoriteSeriesSortRequestID == requestID,
                      state.activeProfileScope == scope,
                      profileContextClient.snapshot() == scope
                else { return .none }
                state.favoriteSeriesSortRequestID = nil
                state.isLoadingFavoriteSeriesSortDates = false
                state.favoriteSeriesSortDidFail = true
                return .none

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

            case let .loadFeaturedData(config, playlistID, hideAdult, loadEPGEvents, catalogsToRefresh, refreshID):
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
                }
                state.isLoading = !catalogsToRefresh.isEmpty
                    && state.featuredChannels.isEmpty
                    && state.featuredVODs.isEmpty
                    && state.featuredSeries.isEmpty
                state.errorMessage = nil
                let isAdult = settingsClient.isAdultContent
                let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                let blacklistedCategoryIDs = parentalControlClient.blacklistedCategoryIDs()
                let manualEPGChannelMappings = state.manualEPGChannelMappings
                let movieCategoryPolicyRevision = state.movieCategoryPolicyRevision
                let movieCollectionPrefix = "Filmler".localized
                let seriesCollectionPrefix = "Diziler".localized
                let liveCollectionPrefix = "Canlı TV".localized
                let contentTypesToRefresh = Set(catalogsToRefresh.map(\.playlistContentType))
                let existingEPGCandidateChannels = state.epgCandidatePlaylistID == playlistID
                    && state.epgCandidateSourceLoaded
                    ? state.epgCandidateChannels
                    : state.featuredChannels
                let existingEPGSourceLoaded = (
                    state.epgCandidatePlaylistID == playlistID
                        && state.epgCandidateSourceLoaded
                ) || !state.featuredChannels.isEmpty
                let existingActorMovieCandidates = state.actorRecommendationMovieCandidates
                let existingActorSeriesCandidates = state.actorRecommendationSeriesCandidates
                let shouldRefreshLive = catalogsToRefresh.contains(.live)
                let shouldRefreshMovies = catalogsToRefresh.contains(.movies)
                let shouldRefreshSeries = catalogsToRefresh.contains(.series)
                let shouldFetchEPGCandidates = loadEPGEvents && existingEPGCandidateChannels.isEmpty
                let remoteEffect = Effect<Action>.run { send in
                    do {
                        if !contentTypesToRefresh.isEmpty {
                            try await iptvClient.refreshContents(config, contentTypesToRefresh) { _ in }
                        }
                        try Task.checkCancellation()
                    } catch {
                        throw error
                    }
                    async let liveCategories: [MediaModels.Category]? = shouldRefreshLive
                        ? try? await iptvClient.fetchLiveCategories(config)
                        : nil
                    async let vodCategories: [MediaModels.Category]? = shouldRefreshMovies
                        ? try? await iptvClient.fetchVODCategories(config)
                        : nil
                    async let vodCategoryPreferences: [CategoryPreferenceDTO]? = shouldRefreshMovies
                        ? try? await databaseClient.fetchCategoryPreferences(
                            "vod",
                            CategoryPreferenceScope(profileID: profileScope.profileID, playlistID: config.playlistID)
                        )
                        : nil
                    async let vodCategoryNameRules: [CategoryNameRule] = {
                        guard shouldRefreshMovies, let playlistID else { return [] }
                        return await categoryNameRuleClient.load(profileScope.profileID, playlistID, "vod")
                    }()
                    async let seriesCategories: [MediaModels.Category]? = shouldRefreshSeries
                        ? try? await iptvClient.fetchSeriesCategories(config)
                        : nil
                    let primaryCatalogs = await withTaskGroup(
                        of: DashboardPrimaryCatalogResult.self
                    ) { group -> (channels: [MediaModels.Item]?, vods: [MediaModels.Item]?, series: [MediaModels.Item]?) in
                        if shouldRefreshLive || shouldFetchEPGCandidates {
                            group.addTask {
                                await .live(try? iptvClient.fetchLiveChannels(config, nil))
                            }
                        }
                        if shouldRefreshMovies {
                            group.addTask {
                                await .movies(try? iptvClient.fetchVODs(config, nil))
                            }
                        }
                        if shouldRefreshSeries {
                            group.addTask {
                                await .series(try? iptvClient.fetchSeries(config, nil))
                            }
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
                    let catalogCounts = DashboardCatalogCountSnapshot(
                        live: fetchedChannels.map { items in
                            hideAdult ? items.reduce(into: 0) { count, item in
                                if !isAdult(item.title) {
                                    count += 1
                                }
                            } : items.count
                        },
                        movies: fetchedVODs.map { items in
                            hideAdult ? items.reduce(into: 0) { count, item in
                                if !isAdult(item.title) {
                                    count += 1
                                }
                            } : items.count
                        },
                        series: fetchedSeries.map { items in
                            hideAdult ? items.reduce(into: 0) { count, item in
                                if !isAdult(item.title) {
                                    count += 1
                                }
                            } : items.count
                        },
                        hidesAdultContent: hideAdult
                    )
                    let fetchedVODCategories = await vodCategories
                    let fetchedVODCategoryPreferences = await vodCategoryPreferences
                    let fetchedVODCategoryNameRules = await vodCategoryNameRules
                    let fetchedSeriesCategories = await seriesCategories
                    var failedPrimaryCatalogs = Set<PrimaryCatalog>()
                    if shouldRefreshLive, fetchedChannels == nil || fetchedLiveCategories == nil {
                        failedPrimaryCatalogs.insert(.live)
                    }
                    if shouldRefreshMovies, fetchedVODs == nil || fetchedVODCategories == nil {
                        failedPrimaryCatalogs.insert(.movies)
                    }
                    if shouldRefreshSeries, fetchedSeries == nil || fetchedSeriesCategories == nil {
                        failedPrimaryCatalogs.insert(.series)
                    }
                    guard !Task.isCancelled else { return }
                    let epgCandidateChannels = fetchedChannels.map { channels in
                        Array((hideAdult ? channels.filter { !isAdult($0.title) } : channels).prefix(200))
                    } ?? existingEPGCandidateChannels
                    let epgSourceLoaded = fetchedChannels != nil || existingEPGSourceLoaded
                    var channels: [MediaModels.Item]?
                    var vods: [MediaModels.Item]?
                    var series: [MediaModels.Item]?
                    var vodExploreCollections: [ExploreCollection]?
                    var seriesExploreCollections: [ExploreCollection]?
                    var yearExploreCollections: [ExploreCollection]?
                    var homeCategoryCollections: [ExploreCollection]?
                    let actorMovieCandidates = fetchedVODs.map {
                        hideAdult ? $0.filter { !isAdult($0.title) } : $0
                    } ?? existingActorMovieCandidates
                    let actorSeriesCandidates = fetchedSeries.map {
                        hideAdult ? $0.filter { !isAdult($0.title) } : $0
                    } ?? existingActorSeriesCandidates
                    if shouldRefreshLive, let fetchedChannels {
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
                        let movieCollections = fetchedVODCategoryPreferences.map { preferences in
                            Self.makeMovieCategoryCollections(
                                label: movieCollectionPrefix,
                                categories: fetchedVODCategories,
                                items: fetchedVODs,
                                preferences: preferences,
                                nameRules: fetchedVODCategoryNameRules,
                                hideAdult: hideAdult,
                                isAdultContent: isAdult,
                                isKidsMode: isKidsMode,
                                blacklistedCategoryIDs: blacklistedCategoryIDs
                            )
                        } ?? []
                        vodExploreCollections = movieCollections
                        homeCategoryCollections = (homeCategoryCollections ?? []) + movieCollections
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

                    if channels == nil, vods == nil, series == nil, !loadEPGEvents {
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
                            movieCategoryPolicyRevision: movieCategoryPolicyRevision,
                            catalogsToRefresh: catalogsToRefresh,
                            catalogCounts: catalogCounts,
                            loadEPGEvents: loadEPGEvents,
                            channels: channels,
                            epgCandidateChannels: epgCandidateChannels,
                            epgSourceLoaded: epgSourceLoaded,
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
                        guard epgSourceLoaded else {
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

            case let .dataLoaded(playlistID, hideAdult, refreshID, profileScope, movieCategoryPolicyRevision, catalogsToRefresh, catalogCounts, loadEPGEvents, channels, epgCandidateChannels, epgSourceLoaded, vods, series, failedPrimaryCatalogs, actorMovieCandidates, actorSeriesCandidates, vodExploreCollections, seriesExploreCollections, yearExploreCollections, homeCategoryCollections):
                guard
                    state.activePlaylistID == playlistID,
                    state.lastAdultHidden == hideAdult,
                    state.activeRefreshID == refreshID,
                    profileContextClient.snapshot() == profileScope,
                    state.activeProfileScope == profileScope
                else { return .none }
                let countSummaryCatalogs = Set(catalogsToRefresh.filter { !failedPrimaryCatalogs.contains($0) })
                state.catalogCountChanges = DashboardCatalogCountStore.update(
                    profileID: profileScope.profileID,
                    playlistID: playlistID,
                    eligibleCatalogs: countSummaryCatalogs,
                    currentCounts: catalogCounts
                )
                let shouldUpdateMovieCategoryShelves = movieCategoryPolicyRevision == state.movieCategoryPolicyRevision
                let personalizationEnabled = LocalPersonalizationPreferences.recommendationsEnabled(
                    for: profileScope.profileID
                )
                let refreshDate = Date()
                for catalog in catalogsToRefresh where !failedPrimaryCatalogs.contains(catalog) {
                    playlistRefreshScheduleClient.markSuccessfulRefresh(
                        profileScope.profileID,
                        playlistID,
                        catalog.refreshTarget,
                        refreshDate
                    )
                }
                state.isLoading = false
                state.hasLoadedRemoteData = true
                state.activeRefreshID = nil
                state.activeAutomaticRefreshProfileID = nil
                state.activeAutomaticRefreshPlaylistID = nil
                state.activeAutomaticRefreshTargets = []
                state.failedPrimaryCatalogs = failedPrimaryCatalogs
                if !catalogsToRefresh.isEmpty, failedPrimaryCatalogs.isEmpty {
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
                let epgEffect: Effect<Action>
                if loadEPGEvents,
                   state.isSportsHubVisible,
                   state.activeEPGRefreshID == nil,
                   epgSourceLoaded,
                   let config = state.activePlaylistConfig
                {
                    let epgRefreshID = UUID()
                    state.activeEPGRefreshID = epgRefreshID
                    epgEffect = .send(.loadEPGEvents(
                        config: config,
                        playlistID: playlistID,
                        refreshID: epgRefreshID,
                        channels: epgCandidateChannels
                    ))
                } else {
                    epgEffect = .none
                }
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
                if shouldUpdateMovieCategoryShelves, let vodExploreCollections {
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
                    if shouldUpdateMovieCategoryShelves, vodExploreCollections != nil {
                        merged.removeAll { $0.id.hasPrefix("movie-category:") }
                    }
                    if seriesExploreCollections != nil {
                        merged.removeAll { $0.id.hasPrefix("series-category:") }
                    }
                    for collection in homeCategoryCollections where shouldUpdateMovieCategoryShelves
                        || !collection.id.hasPrefix("movie-category:")
                    {
                        merged.removeAll { $0.id == collection.id }
                        merged.append(collection)
                    }
                    state.availableHomeCategoryCollections = merged
                }
                Self.syncTopShelf(
                    history: state.watchHistoryItems,
                    favorites: state.favoriteItems,
                    vods: state.featuredVODs,
                    profileID: state.activeProfileScope?.profileID,
                    hideAdult: state.lastAdultHidden ?? (settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()),
                    isAdultContent: settingsClient.isAdultContent,
                    hiddenChannelIDs: parentalControlClient.hiddenChannelIDs(),
                    blacklistedCategoryIDs: parentalControlClient.blacklistedCategoryIDs()
                )
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
                return .merge(cacheEffect, localDataEffect, movieRatingEffect, awardEffect, epgEffect)

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
                state.activeAutomaticRefreshProfileID = nil
                state.activeAutomaticRefreshPlaylistID = nil
                state.activeAutomaticRefreshTargets = []
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
                let addedFavorite: Bool
                if let index = state.favoriteItems.firstIndex(where: { $0.id == item.id && $0.type == type && $0.playlistID == playlistID }) {
                    state.favoriteItems.remove(at: index)
                    addedFavorite = false
                } else {
                    state.favoriteItems.insert(favItem, at: 0)
                    addedFavorite = true
                }
                let orderSave = Self.updatingManualFavoriteOrder(
                    state: &state,
                    type: type,
                    playlistID: playlistID,
                    profileID: profileScope.profileID
                )
                Self.syncTopShelf(
                    history: state.watchHistoryItems,
                    favorites: state.favoriteItems,
                    vods: state.featuredVODs,
                    profileID: profileScope.profileID,
                    hideAdult: state.lastAdultHidden ?? (settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()),
                    isAdultContent: settingsClient.isAdultContent,
                    hiddenChannelIDs: parentalControlClient.hiddenChannelIDs(),
                    blacklistedCategoryIDs: parentalControlClient.blacklistedCategoryIDs()
                )
                let databaseEffect: Effect<Action> = .run { _ in
                    _ = try? await databaseClient.toggleFavorite(favItem, profileScope)
                }
                let orderEffect: Effect<Action> = if let orderSave {
                    .run { _ in
                        await favoriteChannelOrderClient.saveMediaFavorites(
                            orderSave.snapshot,
                            orderSave.profileID,
                            orderSave.scope.playlistID,
                            orderSave.scope.type
                        )
                    }
                } else {
                    .none
                }
                var favoriteSeriesDateCacheSave: Effect<Action> = .none
                if type.lowercased() == "series", !addedFavorite, let playlistID {
                    var entries = state.favoriteSeriesEpisodeDatesByPlaylist[playlistID] ?? [:]
                    entries.removeValue(forKey: item.id)
                    state.favoriteSeriesEpisodeDatesByPlaylist[playlistID] = entries
                    favoriteSeriesDateCacheSave = .run { _ in
                        await favoriteSeriesSortClient.saveEpisodeDates(entries, profileScope.profileID, playlistID)
                    }
                }
                let refreshFavoriteSeriesSort: Effect<Action> = type.lowercased() == "series"
                    && addedFavorite
                    && state.favoriteSeriesSortMode == .newestEpisode
                    ? .send(.setFavoriteSeriesSort(.newestEpisode))
                    : .none
                return .merge(databaseEffect, orderEffect, refreshFavoriteSeriesSort, favoriteSeriesDateCacheSave)

            case let .deleteFavorite(fav):
                let profileScope = profileContextClient.snapshot()
                state.favoriteItems.removeAll { $0.id == fav.id && $0.type == fav.type && $0.playlistID == fav.playlistID }
                var dateCacheSave: Effect<Action> = .none
                if fav.type.lowercased() == "series", let playlistID = fav.playlistID {
                    var entries = state.favoriteSeriesEpisodeDatesByPlaylist[playlistID] ?? [:]
                    entries.removeValue(forKey: fav.id)
                    state.favoriteSeriesEpisodeDatesByPlaylist[playlistID] = entries
                    dateCacheSave = .run { _ in
                        await favoriteSeriesSortClient.saveEpisodeDates(entries, profileScope.profileID, playlistID)
                    }
                }
                let orderSave = Self.updatingManualFavoriteOrder(
                    state: &state,
                    type: fav.type,
                    playlistID: fav.playlistID,
                    profileID: profileScope.profileID
                )
                Self.syncTopShelf(
                    history: state.watchHistoryItems,
                    favorites: state.favoriteItems,
                    vods: state.featuredVODs,
                    profileID: profileScope.profileID,
                    hideAdult: state.lastAdultHidden ?? (settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()),
                    isAdultContent: settingsClient.isAdultContent,
                    hiddenChannelIDs: parentalControlClient.hiddenChannelIDs(),
                    blacklistedCategoryIDs: parentalControlClient.blacklistedCategoryIDs()
                )
                let databaseEffect: Effect<Action> = .run { _ in
                    _ = try? await databaseClient.toggleFavorite(fav, profileScope)
                }
                let orderEffect: Effect<Action> = if let orderSave {
                    .run { _ in
                        await favoriteChannelOrderClient.saveMediaFavorites(
                            orderSave.snapshot,
                            orderSave.profileID,
                            orderSave.scope.playlistID,
                            orderSave.scope.type
                        )
                    }
                } else {
                    .none
                }
                return .merge(databaseEffect, orderEffect, dateCacheSave)

            case let .moveFavorite(favorite, offset):
                guard state.canMoveFavorite(favorite, offset: offset),
                      let playlistID = favorite.playlistID,
                      let profileScope = state.activeProfileScope,
                      let profileID = profileScope.profileID,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                let type = favorite.type.lowercased()
                let scope = FavoriteMediaOrderScope(type: type, playlistID: playlistID)
                let scopedFavorites = state.favoriteItems.filter {
                    $0.type.lowercased() == type && $0.playlistID == playlistID
                }
                let providerIDs = scopedFavorites.sorted {
                    if $0.addedAt != $1.addedAt {
                        return $0.addedAt > $1.addedAt
                    }
                    if $0.title != $1.title {
                        return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                    }
                    return $0.id < $1.id
                }.map(\.id)
                let storedSnapshot = state.favoriteMediaOrderSnapshots[scope.storageKey]
                    ?? FavoriteChannelOrderSnapshot()
                var orderedIDs = FavoriteChannelSortMode.normalizedManualIDs(
                    favoriteIDs: Set(scopedFavorites.map(\.id)),
                    providerIDs: providerIDs,
                    storedIDs: storedSnapshot.mode == .manual ? storedSnapshot.orderedIDs : []
                )
                guard let index = orderedIDs.firstIndex(of: favorite.id),
                      orderedIDs.indices.contains(index + offset)
                else { return .none }
                orderedIDs.swapAt(index, index + offset)
                let updatedSnapshot = FavoriteChannelOrderSnapshot(
                    mode: .manual,
                    orderedIDs: orderedIDs,
                    revision: Self.nextFavoriteMediaOrderRevision(after: storedSnapshot.revision)
                )
                state.favoriteMediaOrderSnapshots[scope.storageKey] = updatedSnapshot
                return .run { _ in
                    await favoriteChannelOrderClient.saveMediaFavorites(
                        updatedSnapshot,
                        profileID,
                        playlistID,
                        type
                    )
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
                Self.syncTopShelf(
                    history: state.watchHistoryItems,
                    favorites: state.favoriteItems,
                    vods: state.featuredVODs,
                    profileID: profileScope.profileID,
                    hideAdult: state.lastAdultHidden ?? (settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()),
                    isAdultContent: settingsClient.isAdultContent,
                    hiddenChannelIDs: parentalControlClient.hiddenChannelIDs(),
                    blacklistedCategoryIDs: parentalControlClient.blacklistedCategoryIDs()
                )
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

    private static func mergingFavoriteMediaOrders(
        favorites: [FavoriteItem],
        orders: [String: FavoriteChannelOrderSnapshot],
        currentSnapshots: [String: FavoriteChannelOrderSnapshot],
        profileID: UUID?
    ) -> ([String: FavoriteChannelOrderSnapshot], [FavoriteMediaOrderSave]) {
        var snapshots: [String: FavoriteChannelOrderSnapshot] = [:]
        var saves: [FavoriteMediaOrderSave] = []

        for (snapshotKey, loadedSnapshot) in orders.sorted(by: { $0.key < $1.key }) {
            let components = snapshotKey.split(separator: ":", maxSplits: 1)
            guard components.count == 2,
                  let playlistID = UUID(uuidString: String(components[1]))
            else { continue }
            let scope = FavoriteMediaOrderScope(type: String(components[0]), playlistID: playlistID)
            var snapshot = currentSnapshots[snapshotKey].flatMap {
                $0.revision >= loadedSnapshot.revision ? $0 : nil
            } ?? loadedSnapshot
            if snapshot.mode == .manual {
                let scopedFavorites = favorites.filter {
                    $0.type.lowercased() == scope.type && $0.playlistID == scope.playlistID
                }
                let normalizedIDs = FavoriteChannelSortMode.normalizedManualIDs(
                    favoriteIDs: Set(scopedFavorites.map(\.id)),
                    providerIDs: scopedFavorites.sorted {
                        if $0.addedAt != $1.addedAt {
                            return $0.addedAt > $1.addedAt
                        }
                        if $0.title != $1.title {
                            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                        }
                        return $0.id < $1.id
                    }.map(\.id),
                    storedIDs: snapshot.orderedIDs
                )
                if normalizedIDs != snapshot.orderedIDs {
                    snapshot.orderedIDs = normalizedIDs
                    snapshot.revision = nextFavoriteMediaOrderRevision(after: snapshot.revision)
                    if let profileID {
                        saves.append(FavoriteMediaOrderSave(
                            profileID: profileID,
                            scope: scope,
                            snapshot: snapshot
                        ))
                    }
                }
            }
            snapshots[snapshotKey] = snapshot
        }
        return (snapshots, saves)
    }

    private static func updatingManualFavoriteOrder(
        state: inout State,
        type: String,
        playlistID: UUID?,
        profileID: UUID?
    ) -> FavoriteMediaOrderSave? {
        let mediaType = type.lowercased()
        guard mediaType == "vod" || mediaType == "series",
              let playlistID,
              let profileID
        else { return nil }
        let scope = FavoriteMediaOrderScope(type: mediaType, playlistID: playlistID)
        guard var snapshot = state.favoriteMediaOrderSnapshots[scope.storageKey],
              snapshot.mode == .manual
        else { return nil }

        let scopedFavorites = state.favoriteItems.filter {
            $0.type.lowercased() == mediaType && $0.playlistID == playlistID
        }
        let normalizedIDs = FavoriteChannelSortMode.normalizedManualIDs(
            favoriteIDs: Set(scopedFavorites.map(\.id)),
            providerIDs: scopedFavorites.sorted {
                if $0.addedAt != $1.addedAt {
                    return $0.addedAt > $1.addedAt
                }
                if $0.title != $1.title {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                return $0.id < $1.id
            }.map(\.id),
            storedIDs: snapshot.orderedIDs
        )
        guard normalizedIDs != snapshot.orderedIDs else { return nil }
        snapshot.orderedIDs = normalizedIDs
        snapshot.revision = nextFavoriteMediaOrderRevision(after: snapshot.revision)
        state.favoriteMediaOrderSnapshots[scope.storageKey] = snapshot
        return FavoriteMediaOrderSave(profileID: profileID, scope: scope, snapshot: snapshot)
    }

    private static func nextFavoriteMediaOrderRevision(after revision: UInt64) -> UInt64 {
        revision < UInt64(Int.max) ? revision + 1 : 1
    }

    private nonisolated static func makeMovieCategoryCollections(
        label: String,
        categories: [MediaModels.Category],
        items: [MediaModels.Item],
        preferences: [CategoryPreferenceDTO],
        nameRules: [CategoryNameRule],
        hideAdult: Bool,
        isAdultContent: (String) -> Bool,
        isKidsMode: Bool,
        blacklistedCategoryIDs: Set<String>
    ) -> [ExploreCollection] {
        let preferencesByID = Dictionary(preferences.map { ($0.categoryID, $0) }, uniquingKeysWith: { first, _ in first })
        let hiddenByNameRule = CategoryNameRuleMatcher.hiddenCategoryIDs(in: categories, rules: nameRules)
        let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]
        let visibleCategories = categories.filter { category in
            let preference = preferencesByID[category.id]
            guard !hiddenByNameRule.contains(category.id),
                  !(preference?.isHidden ?? false),
                  !(preference?.isLocked ?? false),
                  !blacklistedCategoryIDs.contains(category.id)
            else { return false }
            if hideAdult, isAdultContent(category.name) || isAdultContent(category.sourceName) {
                return false
            }
            if isKidsMode {
                let sourceName = category.sourceName.lowercased()
                return kidsKeywords.contains { sourceName.contains($0) }
            }
            return true
        }
        let visibleItems = hideAdult ? items.filter { !isAdultContent($0.title) } : items
        return makeCategoryCollections(
            prefix: "movie-category",
            label: label,
            categories: visibleCategories,
            items: visibleItems,
            minimumItems: 1,
            limit: Int.max
        )
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
        vods: [MediaModels.Item],
        profileID: UUID?,
        hideAdult: Bool,
        isAdultContent: @Sendable (String) -> Bool,
        hiddenChannelIDs: Set<String>,
        blacklistedCategoryIDs: Set<String>
    ) {
        let visibleHistory = hideAdult
            ? history.filter { !isAdultContent($0.title) && !isAdultContent($0.seriesTitle ?? "") }
            : history
        let visibleFavorites = favorites.filter { favorite in
            favorite.type != "live" || !hiddenChannelIDs.contains(favorite.id)
        }.filter { favorite in
            !hideAdult || !isAdultContent(favorite.title)
        }
        let visibleVODs = vods.filter { item in
            !blacklistedCategoryIDs.contains(item.categoryID)
                && (!hideAdult || !isAdultContent(item.title))
        }

        let continueWatching = visibleHistory.filter { item in
            item.duration <= 0 || item.progress / item.duration < 0.90
        }.prefix(10).map { item in
            let prog: Double? = if item.duration.isFinite, item.duration > 0, item.progress.isFinite {
                min(1, max(0, item.progress / item.duration))
            } else {
                nil
            }
            let link = TopShelfService.makeDeepLink(
                id: item.id,
                type: item.type,
                playlistID: item.playlistID,
                profileID: item.profileID ?? profileID,
                seriesID: item.seriesID,
                startPosition: prog
            )
            return TopShelfItemDTO(
                id: topShelfItemIdentifier(type: item.type, playlistID: item.playlistID, itemID: item.id),
                title: item.title,
                subtitle: item.seriesTitle,
                summary: topShelfContinueSummary(seriesTitle: item.seriesTitle, progress: prog),
                imageURL: safeTopShelfImageURL(item.coverURL),
                deepLinkURL: link,
                progress: prog,
                duration: item.duration > 0 ? item.duration : nil,
                isLive: false
            )
        }

        let favoriteChannels = visibleFavorites.filter { $0.type == "live" }.prefix(10).map { fav in
            let link = TopShelfService.makeDeepLink(
                id: fav.id,
                type: "live",
                playlistID: fav.playlistID,
                profileID: fav.profileID ?? profileID
            )
            return TopShelfItemDTO(
                id: topShelfItemIdentifier(type: "live", playlistID: fav.playlistID, itemID: fav.id),
                title: fav.title,
                subtitle: nil,
                summary: "Favori TV Kanalı",
                imageURL: safeTopShelfImageURL(fav.coverURL),
                deepLinkURL: link,
                progress: nil,
                duration: nil,
                isLive: true
            )
        }

        let recentMovies = visibleVODs.prefix(10).map { vod in
            let link = TopShelfService.makeDeepLink(
                id: vod.id,
                type: "vod",
                playlistID: vod.playlistID,
                profileID: profileID
            )
            return TopShelfItemDTO(
                id: topShelfItemIdentifier(type: "vod", playlistID: vod.playlistID, itemID: vod.id),
                title: vod.title,
                subtitle: nil,
                summary: topShelfMovieSummary(rating: vod.rating, releaseDate: vod.releaseDate, duration: vod.duration),
                imageURL: safeTopShelfImageURL(vod.coverURL?.absoluteString),
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

    private nonisolated static func safeTopShelfImageURL(_ value: String?) -> String? {
        guard let value,
              let components = URLComponents(string: value),
              components.scheme == "https" || components.scheme == "http",
              components.host != nil,
              components.user == nil,
              components.password == nil
        else { return nil }

        let sensitiveQueryNames: Set = [
            "username", "user", "password", "token", "access_token", "auth", "apikey", "api_key", "secret", "key", "sig", "signature",
        ]
        guard components.queryItems?.contains(where: { sensitiveQueryNames.contains($0.name.lowercased()) }) != true else {
            return nil
        }
        return value
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
                        let programs = try await iptvClient.fetchShortEPG(config, channel.id, epgID, 8)
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
                            let programs = try await iptvClient.fetchShortEPG(config, nextChannel.id, epgID, 8)
                            return (nextChannel, programs, true)
                        } catch {
                            return (nextChannel, [], false)
                        }
                    }
                }
            }

            let fixtureTitleKeys = Set(events.filter(\.isSportsFixture).map {
                FuzzySearchEngine.normalize($0.program.title)
            })
            let channelsByFixture = Dictionary(grouping: events.filter {
                fixtureTitleKeys.contains(FuzzySearchEngine.normalize($0.program.title))
            }) {
                FuzzySearchEngine.normalize($0.program.title)
            }
            let linkedEvents = events.map { event in
                let fixtureKey = fixtureMappingKey(title: event.program.title, startTime: event.program.startTime)
                let mappedChannel = manualChannelMappings[fixtureKey].flatMap { mappedID in
                    channels.first(where: { $0.id == mappedID })
                }
                let channel = mappedChannel ?? event.channel
                let matchingFixtureEvents = event.isSportsFixture
                    ? (channelsByFixture[FuzzySearchEngine.normalize(event.program.title)] ?? [])
                    : []
                let alternatives = matchingFixtureEvents
                    .map(\.channel)
                    .filter { $0.id != channel.id }
                    .reduce(into: [MediaModels.Item]()) { result, channel in
                        if !result.contains(where: { $0.id == channel.id }) {
                            result.append(channel)
                        }
                    }
                return EPGEvent(
                    channel: channel,
                    program: event.program,
                    alternateChannels: alternatives,
                    isSportsFixture: event.isSportsFixture
                )
            }
            return (linkedEvents.sorted { $0.program.startTime < $1.program.startTime }.prefix(16).map(\.self), succeeded)
        }
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

    private static func applySportsFollowRecords(
        _ records: [SportsFollowSyncRecord],
        to state: inout State
    ) {
        for record in records where record.isValid {
            if let current = state.sportsFollowRecordsByID[record.id] {
                if record.wins(over: current) {
                    state.sportsFollowRecordsByID[record.id] = record
                }
            } else {
                state.sportsFollowRecordsByID[record.id] = record
            }
        }

        var followedIDs = Set(state.sportsFollowRecordsByID.values.filter(\.isFollowing).map(\.id))
        for (id, isFollowing) in state.pendingSportsFollowValues {
            if isFollowing {
                followedIDs.insert(id)
            } else {
                followedIDs.remove(id)
            }
        }
        state.followedSportsIDs = followedIDs
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
                alternateChannels: event.alternateChannels.filter { $0.id != channel.id },
                isSportsFixture: event.isSportsFixture
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
