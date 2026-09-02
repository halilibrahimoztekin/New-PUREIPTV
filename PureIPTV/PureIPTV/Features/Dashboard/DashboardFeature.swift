import ComposableArchitecture
import Foundation

@Reducer
public struct DashboardFeature {
    @ObservableState
    public struct State: Equatable {
        public var isLoading: Bool = false
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
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item, playlist: [MediaModels.Item]?)
            case didSelectVOD(MediaModels.Item)
            case didSelectSeries(MediaModels.Item)
            case playHistoryItem(WatchHistoryItem)
        }
    }

    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                let localEffect: Effect<Action> = .send(.loadLocalData)
                let remoteEffect: Effect<Action> = (state.featuredChannels.isEmpty && state.featuredVODs.isEmpty && state.featuredSeries.isEmpty)
                    ? .send(.loadFeaturedData(config: config))
                    : .none
                return .merge(localEffect, remoteEffect)

            case .loadLocalData:
                return .run { send in
                    let favorites = await (try? databaseClient.fetchFavorites()) ?? []
                    let history = await (try? databaseClient.fetchWatchHistory()) ?? []
                    await send(.localDataLoaded(favorites: favorites, history: history))
                }

            case let .localDataLoaded(favorites, history):
                state.favoriteItems = favorites
                state.watchHistoryItems = history
                return .none

            case let .loadFeaturedData(config):
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    // Fetch categories to get some content
                    async let liveCategories = try? iptvClient.fetchLiveCategories(config)
                    async let vodCategories = try? iptvClient.fetchVODCategories(config)
                    async let seriesCategories = try? iptvClient.fetchSeriesCategories(config)

                    let liveCat = await liveCategories
                    _ = await vodCategories
                    _ = await seriesCategories

                    var channels: [MediaModels.Item] = []
                    var vods: [MediaModels.Item] = []
                    var series: [MediaModels.Item] = []

                    if let firstLiveCat = liveCat?.first {
                        if let streamList = try? await iptvClient.fetchLiveChannels(config, firstLiveCat.id) {
                            channels = Array(streamList.prefix(10))
                        }
                    }

                    // Fetch ALL VODs and Series to get global "Recently Added"
                    if let allVODs = try? await iptvClient.fetchVODs(config, nil) {
                        let sorted = allVODs.sorted { ($0.addedDate ?? Date.distantPast) > ($1.addedDate ?? Date.distantPast) }
                        vods = Array(sorted.prefix(10))
                    }

                    if let allSeries = try? await iptvClient.fetchSeries(config, nil) {
                        let sorted = allSeries.sorted { ($0.addedDate ?? Date.distantPast) > ($1.addedDate ?? Date.distantPast) }
                        series = Array(sorted.prefix(10))
                    }

                    // Smart Recommendations: Get favorites/history and filter
                    let history = await (try? databaseClient.fetchWatchHistory()) ?? []
                    var recommendations: [MediaModels.Item] = []

                    if let allVODs = try? await iptvClient.fetchVODs(config, nil) {
                        let sorted = allVODs.sorted { ($0.addedDate ?? Date.distantPast) > ($1.addedDate ?? Date.distantPast) }
                        vods = Array(sorted.prefix(10))

                        // Recommendations logic: simple random sample or based on matching categories if history exists
                        let vodHistory = history.filter { $0.type == "vod" }
                        if !vodHistory.isEmpty {
                            // Mock logic for recommendations
                            let shuffled = allVODs.shuffled()
                            recommendations = Array(shuffled.prefix(10))
                        } else {
                            recommendations = Array(sorted.dropFirst(10).prefix(10))
                        }
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

            case .delegate:
                return .none
            }
        }
    }
}
