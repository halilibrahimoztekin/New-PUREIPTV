import ComposableArchitecture
import FactoryKit
import Foundation

@Reducer
public struct DashboardFeature {
    @ObservableState
    public struct State: Equatable {
        public var isLoading: Bool = false
        public var activePlaylistName: String = ""
        public var featuredChannels: [MediaModels.Item] = []
        public var featuredVODs: [MediaModels.Item] = []
        public var featuredSeries: [MediaModels.Item] = []
        public var recommendedVODs: [MediaModels.Item] = []
        public var hasLoadedRemoteData = false
        public var activePlaylistID: UUID?
        public var lastRemoteRefreshAt: Date?
        public var activeRefreshID: UUID?

        public var favoriteItems: [FavoriteItem] = []
        public var watchHistoryItems: [WatchHistoryItem] = []

        public var favoriteIDs: Set<String> {
            Set(favoriteItems.map(\.id))
        }

        public var continueWatchingItems: [WatchHistoryItem] {
            watchHistoryItems.filter { item in
                guard item.duration > 0 else { return true }
                return item.progress / item.duration < 0.90
            }
        }

        public var errorMessage: String?
        public var lastAdultHidden: Bool?

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case openManagePlaylistsTapped
        case loadFeaturedData(config: PlaylistConfig, playlistID: UUID?, hideAdult: Bool, refreshID: UUID)
        case loadLocalData
        case localDataLoaded(favorites: [FavoriteItem], history: [WatchHistoryItem])
        case dataLoaded(playlistID: UUID?, hideAdult: Bool, refreshID: UUID, channels: [MediaModels.Item]?, vods: [MediaModels.Item]?, series: [MediaModels.Item]?, recommendations: [MediaModels.Item]?)
        case dataFailed(playlistID: UUID?, hideAdult: Bool, refreshID: UUID, Error)
        case channelSelected(MediaModels.Item)
        case vodSelected(MediaModels.Item)
        case seriesSelected(MediaModels.Item)

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
    }

    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.settingsClient) var settingsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let playlistRepository = playlistRepository
        let settingsClient = settingsClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                state.activePlaylistName = playlistRepository.getActivePlaylist()?.name ?? ""
                let localEffect: Effect<Action> = .send(.loadLocalData)
                let currentAdultHidden = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdult = settingsClient.isAdultContent
                let playlistID = playlistRepository.getActivePlaylistID()
                let playlistChanged = state.activePlaylistID != playlistID
                let preferencesChanged = state.lastAdultHidden.map { $0 != currentAdultHidden } ?? false
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
                    state.recommendedVODs = snapshot?.recommendations.compactMap(\.mediaItem).filter {
                        !currentAdultHidden || !isAdult($0.title)
                    } ?? []
                    state.isLoading = snapshot == nil
                }
                let shouldReload = !state.hasLoadedRemoteData
                    || playlistChanged
                    || preferencesChanged
                    || (state.lastRemoteRefreshAt.map { Date().timeIntervalSince($0) >= 15 * 60 } ?? true)
                    || (state.featuredChannels.isEmpty && state.featuredVODs.isEmpty && state.featuredSeries.isEmpty)
                state.activePlaylistID = playlistID
                state.lastAdultHidden = currentAdultHidden
                let remoteEffect: Effect<Action>
                if shouldReload {
                    let refreshID = UUID()
                    state.activeRefreshID = refreshID
                    remoteEffect = .send(.loadFeaturedData(
                        config: config,
                        playlistID: playlistID,
                        hideAdult: currentAdultHidden,
                        refreshID: refreshID
                    ))
                } else {
                    remoteEffect = .none
                }
                let notificationEffect: Effect<Action> = .run { send in
                    for await _ in NotificationCenter.default.notifications(named: .watchHistoryDidChange) {
                        await send(.loadLocalData)
                    }
                }
                .cancellable(id: CancelID.watchHistoryObserver, cancelInFlight: true)
                return .merge(localEffect, remoteEffect, notificationEffect)

            case .openManagePlaylistsTapped:
                return .send(.delegate(.openManagePlaylists))

            case .loadLocalData:
                return .run { send in
                    let favorites = await (try? databaseClient.fetchFavorites()) ?? []
                    let history = await (try? databaseClient.fetchWatchHistory()) ?? []
                    await send(.localDataLoaded(favorites: favorites, history: history))
                }

            case let .localDataLoaded(favorites, history):
                state.favoriteItems = favorites
                state.watchHistoryItems = history
                Self.syncTopShelf(history: history, favorites: favorites, vods: state.featuredVODs)
                return .none

            case let .loadFeaturedData(config, playlistID, hideAdult, refreshID):
                state.isLoading = state.featuredChannels.isEmpty
                    && state.featuredVODs.isEmpty
                    && state.featuredSeries.isEmpty
                state.errorMessage = nil
                let isAdult = settingsClient.isAdultContent
                return .run { send in
                    async let liveStreams = try? iptvClient.fetchLiveChannels(config, nil)
                    async let allVODs = try? iptvClient.fetchVODs(config, nil)
                    async let allSeries = try? iptvClient.fetchSeries(config, nil)
                    async let historyReq = (try? databaseClient.fetchWatchHistory()) ?? []
                    async let favoritesReq = (try? databaseClient.fetchFavorites()) ?? []

                    let history = await historyReq
                    let favorites = await favoritesReq

                    let fetchedChannels = await liveStreams
                    let fetchedVODs = await allVODs
                    let fetchedSeries = await allSeries
                    var channels: [MediaModels.Item]?
                    var vods: [MediaModels.Item]?
                    var series: [MediaModels.Item]?
                    var recommendations: [MediaModels.Item]?

                    if let fetchedChannels {
                        let filtered = hideAdult ? fetchedChannels.filter { !isAdult($0.title) } : fetchedChannels
                        channels = Array(filtered.prefix(10))
                    }

                    if let fetchedVODs {
                        let safeVODs = hideAdult ? fetchedVODs.filter { !isAdult($0.title) } : fetchedVODs
                        let sorted = safeVODs.sorted { ($0.addedDate ?? Date.distantPast) > ($1.addedDate ?? Date.distantPast) }
                        vods = Array(sorted.prefix(10))

                        // Smart Content-based and collaborative recommendations (Madde #8 & #42)
                        recommendations = SmartRecommendationEngine.recommendVODs(
                            from: safeVODs,
                            history: history,
                            favorites: favorites,
                            limit: 12
                        )
                    }

                    if let fetchedSeries {
                        let safeSeries = hideAdult ? fetchedSeries.filter { !isAdult($0.title) } : fetchedSeries
                        let sorted = safeSeries.sorted { ($0.addedDate ?? Date.distantPast) > ($1.addedDate ?? Date.distantPast) }
                        series = Array(sorted.prefix(10))
                    }

                    if channels == nil, vods == nil, series == nil {
                        await send(.dataFailed(
                            playlistID: playlistID,
                            hideAdult: hideAdult,
                            refreshID: refreshID,
                            URLError(.cannotLoadFromNetwork)
                        ))
                    } else {
                        await send(.dataLoaded(
                            playlistID: playlistID,
                            hideAdult: hideAdult,
                            refreshID: refreshID,
                            channels: channels,
                            vods: vods,
                            series: series,
                            recommendations: recommendations
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

            case let .dataLoaded(playlistID, hideAdult, refreshID, channels, vods, series, recommendations):
                guard
                    state.activePlaylistID == playlistID,
                    state.lastAdultHidden == hideAdult,
                    state.activeRefreshID == refreshID
                else { return .none }
                state.isLoading = false
                state.hasLoadedRemoteData = true
                state.lastRemoteRefreshAt = Date()
                state.activeRefreshID = nil
                if let channels {
                    state.featuredChannels = channels
                }
                if let vods {
                    state.featuredVODs = vods
                }
                if let series {
                    state.featuredSeries = series
                }
                if let recommendations {
                    state.recommendedVODs = recommendations
                }
                Self.syncTopShelf(history: state.watchHistoryItems, favorites: state.favoriteItems, vods: state.featuredVODs)
                let cachedChannels = state.featuredChannels
                let cachedVODs = state.featuredVODs
                let cachedSeries = state.featuredSeries
                let cachedRecommendations = state.recommendedVODs
                return .run { _ in
                    await DashboardFeaturedCache.save(
                        playlistID: playlistID,
                        hideAdult: hideAdult,
                        channels: cachedChannels,
                        vods: cachedVODs,
                        series: cachedSeries,
                        recommendations: cachedRecommendations
                    )
                }

            case let .dataFailed(playlistID, hideAdult, refreshID, error):
                guard
                    state.activePlaylistID == playlistID,
                    state.lastAdultHidden == hideAdult,
                    state.activeRefreshID == refreshID
                else { return .none }
                state.isLoading = false
                state.activeRefreshID = nil
                state.errorMessage = state.featuredChannels.isEmpty
                    && state.featuredVODs.isEmpty
                    && state.featuredSeries.isEmpty
                    ? error.localizedDescription
                    : nil
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
                let favItem = FavoriteItem(
                    id: item.id,
                    type: type,
                    title: item.title,
                    coverURL: item.coverURL?.absoluteString,
                    streamURL: item.streamURL?.absoluteString
                )
                if let index = state.favoriteItems.firstIndex(where: { $0.id == item.id }) {
                    state.favoriteItems.remove(at: index)
                } else {
                    state.favoriteItems.insert(favItem, at: 0)
                }
                Self.syncTopShelf(history: state.watchHistoryItems, favorites: state.favoriteItems, vods: state.featuredVODs)
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(favItem)
                }

            case let .deleteFavorite(fav):
                state.favoriteItems.removeAll { $0.id == fav.id }
                Self.syncTopShelf(history: state.watchHistoryItems, favorites: state.favoriteItems, vods: state.featuredVODs)
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(fav)
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
                state.watchHistoryItems.removeAll { $0.id == hist.id }
                Self.syncTopShelf(history: state.watchHistoryItems, favorites: state.favoriteItems, vods: state.featuredVODs)
                return .run { [id = hist.id] _ in
                    try? await databaseClient.deleteWatchProgress(id)
                }

            case .delegate:
                return .none
            }
        }
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
                id: item.id,
                title: item.title,
                subtitle: item.seriesTitle,
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
                id: fav.id,
                title: fav.title,
                subtitle: nil,
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
                id: vod.id,
                title: vod.title,
                subtitle: nil,
                imageURL: vod.coverURL?.absoluteString,
                deepLinkURL: link,
                progress: nil,
                duration: nil,
                isLive: false
            )
        }

        TopShelfService.shared.updateTopShelfData(
            continueWatching: Array(continueWatching),
            favoriteChannels: Array(favoriteChannels),
            recentMovies: Array(recentMovies)
        )
    }
}
