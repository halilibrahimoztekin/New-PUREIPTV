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

        public var favoriteItems: [FavoriteItem] = []
        public var watchHistoryItems: [WatchHistoryItem] = []

        public var errorMessage: String?

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case openManagePlaylistsTapped
        case loadFeaturedData(config: PlaylistConfig)
        case loadLocalData
        case localDataLoaded(favorites: [FavoriteItem], history: [WatchHistoryItem])
        case dataLoaded(channels: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item], recommendations: [MediaModels.Item])
        case dataFailed(Error)
        case channelSelected(MediaModels.Item)
        case vodSelected(MediaModels.Item)
        case seriesSelected(MediaModels.Item)

        // Navigation from local items
        case favoriteSelected(FavoriteItem)
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

    public init() {}

    public var body: some Reducer<State, Action> {
        let playlistRepository = playlistRepository

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                state.activePlaylistName = playlistRepository.getActivePlaylist()?.name ?? ""
                let localEffect: Effect<Action> = .send(.loadLocalData)
                let remoteEffect: Effect<Action> = (state.featuredChannels.isEmpty && state.featuredVODs.isEmpty && state.featuredSeries.isEmpty)
                    ? .send(.loadFeaturedData(config: config))
                    : .none
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

            case let .loadFeaturedData(config):
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    async let liveStreams = try? iptvClient.fetchLiveChannels(config, nil)
                    async let allVODs = try? iptvClient.fetchVODs(config, nil)
                    async let allSeries = try? iptvClient.fetchSeries(config, nil)
                    let history = await (try? databaseClient.fetchWatchHistory()) ?? []

                    var channels: [MediaModels.Item] = []
                    var vods: [MediaModels.Item] = []
                    var series: [MediaModels.Item] = []
                    var recommendations: [MediaModels.Item] = []

                    if let fetchedChannels = await liveStreams {
                        channels = Array(fetchedChannels.prefix(10))
                    }

                    if let fetchedVODs = await allVODs {
                        let sorted = fetchedVODs.sorted { ($0.addedDate ?? Date.distantPast) > ($1.addedDate ?? Date.distantPast) }
                        vods = Array(sorted.prefix(10))

                        let vodHistory = history.filter { $0.type == "vod" }
                        if !vodHistory.isEmpty {
                            let shuffled = fetchedVODs.shuffled()
                            recommendations = Array(shuffled.prefix(10))
                        } else {
                            recommendations = Array(sorted.dropFirst(10).prefix(10))
                        }
                    }

                    if let fetchedSeries = await allSeries {
                        let sorted = fetchedSeries.sorted { ($0.addedDate ?? Date.distantPast) > ($1.addedDate ?? Date.distantPast) }
                        series = Array(sorted.prefix(10))
                    }

                    await send(.dataLoaded(channels: channels, vods: vods, series: series, recommendations: recommendations))
                } catch: { error, send in
                    await send(.dataFailed(error))
                }

            case let .dataLoaded(channels, vods, series, recommendations):
                state.isLoading = false
                state.featuredChannels = channels
                state.featuredVODs = vods
                state.featuredSeries = series
                state.recommendedVODs = recommendations
                Self.syncTopShelf(history: state.watchHistoryItems, favorites: state.favoriteItems, vods: vods)
                return .none

            case let .dataFailed(error):
                state.isLoading = false
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
        let continueWatching = history.prefix(10).map { item in
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
