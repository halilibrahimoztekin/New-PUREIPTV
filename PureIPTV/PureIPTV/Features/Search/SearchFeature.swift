import ComposableArchitecture
import FactoryKit
import Foundation

// MARK: - SearchFeature

/// Cancel ID must be fully Sendable and non-isolated to avoid
/// main-actor isolation conflicts with the @Reducer macro.
private let searchCancelID = "SearchFeature.search"

@Reducer
public struct SearchFeature: Sendable {
    public enum SearchFilter: String, CaseIterable, Equatable {
        case all = "Tümü"
        case live = "Canlı TV"
        case vod = "Filmler"
        case series = "Diziler"

        public var title: String {
            switch self {
            case .all: AppStrings.Search.all
            case .live: AppStrings.Search.liveTV
            case .vod: AppStrings.Search.movies
            case .series: AppStrings.Search.series
            }
        }
    }

    public struct QuickSearchTag: Identifiable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let icon: String
        public let hexColor: String

        public init(id: String, title: String, icon: String, hexColor: String) {
            self.id = id
            self.title = title
            self.icon = icon
            self.hexColor = hexColor
        }

        public static let defaults: [QuickSearchTag] = [
            QuickSearchTag(id: "spor", title: "Spor", icon: "sportscourt.fill", hexColor: "#FF9500"),
            QuickSearchTag(id: "sinema", title: "Sinema", icon: "film.fill", hexColor: "#FF3B30"),
            QuickSearchTag(id: "haber", title: "Haber", icon: "newspaper.fill", hexColor: "#0A84FF"),
            QuickSearchTag(id: "belgesel", title: "Belgesel", icon: "globe.europe.africa.fill", hexColor: "#30D158"),
            QuickSearchTag(id: "cocuk", title: "Çocuk", icon: "sparkles.tv.fill", hexColor: "#FFD60A"),
            QuickSearchTag(id: "muzik", title: "Müzik", icon: "music.note", hexColor: "#BF5AF2"),
            QuickSearchTag(id: "4k", title: "4K / UHD", icon: "4k.tv.fill", hexColor: "#64D2FF"),
            QuickSearchTag(id: "aksiyon", title: "Aksiyon", icon: "flame.fill", hexColor: "#FF453A"),
            QuickSearchTag(id: "komedi", title: "Komedi", icon: "face.smiling.fill", hexColor: "#63E6BE"),
            QuickSearchTag(id: "dizi", title: "Dizi", icon: "play.tv.fill", hexColor: "#5E5CE6"),
        ]
    }

    @ObservableState
    public struct State: Equatable {
        // Data sources (everything fetched once)
        public var allChannels: [MediaModels.Item] = []
        public var allVODs: [MediaModels.Item] = []
        public var allSeries: [MediaModels.Item] = []

        // Search state
        public var searchQuery: String = ""
        public var debouncedQuery: String = ""
        public var filter: SearchFilter = .all
        public var recentSearches: [SearchHistoryItem] = []
        public var quickTags: [QuickSearchTag] = QuickSearchTag.defaults

        // UI state
        public var isLoading = false
        public var isSearching = false
        public var hasLoaded = false
        public var errorMessage: String?
        public var lastLoadedConfig: PlaylistConfig?
        public var lastAdultHidden: Bool?

        /// Stored Results (avoid recomputing over 50,000 items on every view render)
        public var liveResults: [MediaModels.Item] = []
        public var vodResults: [MediaModels.Item] = []
        public var seriesResults: [MediaModels.Item] = []
        public var favoriteIDs: Set<String> = []

        public var totalResultsCount: Int {
            liveResults.count + vodResults.count + seriesResults.count
        }

        public mutating func updateResults() {
            let query = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                liveResults = []
                vodResults = []
                seriesResults = []
                return
            }

            if filter == .all || filter == .live {
                liveResults = FuzzySearchEngine.searchItems(allChannels, query: query, limit: 100)
            } else {
                liveResults = []
            }

            if filter == .all || filter == .vod {
                vodResults = FuzzySearchEngine.searchItems(allVODs, query: query, limit: 80)
            } else {
                vodResults = []
            }

            if filter == .all || filter == .series {
                seriesResults = FuzzySearchEngine.searchItems(allSeries, query: query, limit: 80)
            } else {
                seriesResults = []
            }
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case loadRecentSearchesResponse([SearchHistoryItem])
        case loadAllDataResponse(Result<(channels: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item]), Error>)
        case queryChanged(String)
        case performSearch(String)
        case searchCompleted(query: String, filter: SearchFilter, live: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item])
        case filterChanged(SearchFilter)
        case resetCache
        case channelSelected(MediaModels.Item)
        case vodSelected(MediaModels.Item)
        case seriesSelected(MediaModels.Item)
        case clearHistoryTapped
        case recentSearchTapped(String)
        case tagSelected(QuickSearchTag)
        case loadFavoritesResponse([FavoriteItem])
        case toggleFavorite(item: MediaModels.Item, type: String)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item, playlist: [MediaModels.Item]?)
            case didSelectVOD(MediaModels.Item)
            case didSelectSeries(MediaModels.Item)
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.settingsClient) var settingsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let settingsClient = settingsClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                let loadHistory: Effect<Action> = .run { send in
                    let history = await (try? databaseClient.fetchSearchHistory()) ?? []
                    await send(.loadRecentSearchesResponse(history))
                }

                let loadFavs: Effect<Action> = .run { send in
                    let favs = await (try? databaseClient.fetchFavorites()) ?? []
                    await send(.loadFavoritesResponse(favs))
                }

                let currentAdultHidden = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                if state.lastLoadedConfig != config || state.lastAdultHidden != currentAdultHidden {
                    state.hasLoaded = false
                    state.allChannels = []
                    state.allVODs = []
                    state.allSeries = []
                    state.liveResults = []
                    state.vodResults = []
                    state.seriesResults = []
                    state.searchQuery = ""
                    state.debouncedQuery = ""
                    state.isSearching = false
                    state.lastLoadedConfig = config
                    state.lastAdultHidden = currentAdultHidden
                }

                guard !state.hasLoaded, !state.isLoading else { return .merge(loadHistory, loadFavs) }
                state.isLoading = true
                state.errorMessage = nil

                return .merge(loadHistory, loadFavs, .run { send in
                    async let channelsReq = try? iptvClient.fetchLiveChannels(config, nil)
                    async let vodsReq = try? iptvClient.fetchVODs(config, nil)
                    async let seriesReq = try? iptvClient.fetchSeries(config, nil)

                    // Fetch all concurrently
                    let (channels, vods, series) = await (channelsReq, vodsReq, seriesReq)

                    if channels == nil, vods == nil, series == nil {
                        await send(.loadAllDataResponse(.failure(NetworkError.invalidResponse)))
                    } else {
                        await send(.loadAllDataResponse(.success((
                            channels: channels ?? [],
                            vods: vods ?? [],
                            series: series ?? []
                        ))))
                    }
                })

            case let .loadRecentSearchesResponse(history):
                state.recentSearches = history
                return .none

            case let .loadAllDataResponse(.success(data)):
                state.isLoading = false
                state.hasLoaded = true
                let hideAdult = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdult = settingsClient.isAdultContent
                state.allChannels = hideAdult ? data.channels.filter { !isAdult($0.title) } : data.channels
                state.allVODs = hideAdult ? data.vods.filter { !isAdult($0.title) } : data.vods
                state.allSeries = hideAdult ? data.series.filter { !isAdult($0.title) } : data.series
                if !state.debouncedQuery.isEmpty {
                    return .send(.performSearch(state.debouncedQuery))
                }
                return .none

            case let .loadAllDataResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = AppStrings.Errors.searchFailed(desc: error.localizedDescription)
                return .none

            case let .queryChanged(query):
                state.searchQuery = query
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    state.debouncedQuery = ""
                    state.isSearching = false
                    state.liveResults = []
                    state.vodResults = []
                    state.seriesResults = []
                    return .cancel(id: searchCancelID)
                }

                state.isSearching = true
                return .run { send in
                    try await clock.sleep(for: .milliseconds(250))
                    await send(.performSearch(query))
                }
                .cancellable(id: searchCancelID, cancelInFlight: true)

            case let .performSearch(query):
                state.debouncedQuery = query
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    state.isSearching = false
                    state.liveResults = []
                    state.vodResults = []
                    state.seriesResults = []
                    return .none
                }

                state.isSearching = true
                let channels = state.allChannels
                let vods = state.allVODs
                let series = state.allSeries
                let filter = state.filter

                return .run { send in
                    guard !Task.isCancelled else { return }

                    let liveMatches: [MediaModels.Item] = if filter == .all || filter == .live {
                        FuzzySearchEngine.searchItems(channels, query: trimmed, limit: 100)
                    } else {
                        []
                    }
                    guard !Task.isCancelled else { return }

                    let vodMatches: [MediaModels.Item] = if filter == .all || filter == .vod {
                        FuzzySearchEngine.searchItems(vods, query: trimmed, limit: 80)
                    } else {
                        []
                    }
                    guard !Task.isCancelled else { return }

                    let seriesMatches: [MediaModels.Item] = if filter == .all || filter == .series {
                        FuzzySearchEngine.searchItems(series, query: trimmed, limit: 80)
                    } else {
                        []
                    }
                    guard !Task.isCancelled else { return }

                    await send(.searchCompleted(
                        query: query,
                        filter: filter,
                        live: liveMatches,
                        vods: vodMatches,
                        series: seriesMatches
                    ))
                }
                .cancellable(id: searchCancelID, cancelInFlight: true)

            case let .searchCompleted(query, filter, live, vods, series):
                // Verify that query and filter are still the latest requested
                guard state.debouncedQuery == query, state.filter == filter else {
                    return .none
                }
                state.isSearching = false
                state.liveResults = live
                state.vodResults = vods
                state.seriesResults = series
                return .none

            case let .filterChanged(filter):
                state.filter = filter
                if !state.debouncedQuery.isEmpty {
                    return .send(.performSearch(state.debouncedQuery))
                }
                return .none

            case .resetCache:
                state.hasLoaded = false
                state.isLoading = false
                state.isSearching = false
                state.allChannels = []
                state.allVODs = []
                state.allSeries = []
                state.liveResults = []
                state.vodResults = []
                state.seriesResults = []
                state.searchQuery = ""
                state.debouncedQuery = ""
                state.lastLoadedConfig = nil
                return .cancel(id: searchCancelID)

            case let .channelSelected(channel):
                let query = state.debouncedQuery
                return .run { send in
                    if !query.isEmpty {
                        _ = try? await databaseClient.saveSearchHistory(query)
                    }
                    await send(.delegate(.didSelectChannel(channel, playlist: nil)))
                }

            case let .vodSelected(vod):
                let query = state.debouncedQuery
                return .run { send in
                    if !query.isEmpty {
                        _ = try? await databaseClient.saveSearchHistory(query)
                    }
                    await send(.delegate(.didSelectVOD(vod)))
                }

            case let .seriesSelected(series):
                let query = state.debouncedQuery
                return .run { send in
                    if !query.isEmpty {
                        _ = try? await databaseClient.saveSearchHistory(query)
                    }
                    await send(.delegate(.didSelectSeries(series)))
                }

            case .clearHistoryTapped:
                state.recentSearches = []
                return .run { _ in
                    _ = try? await databaseClient.clearSearchHistory()
                }

            case let .recentSearchTapped(query):
                state.searchQuery = query
                state.debouncedQuery = query
                return .send(.performSearch(query))

            case let .tagSelected(tag):
                state.searchQuery = tag.title
                state.debouncedQuery = tag.title
                return .send(.performSearch(tag.title))

            case let .loadFavoritesResponse(favs):
                state.favoriteIDs = Set(favs.map(\.id))
                return .none

            case let .toggleFavorite(item, type):
                let favItem = FavoriteItem(
                    id: item.id,
                    type: type,
                    title: item.title,
                    coverURL: item.coverURL?.absoluteString,
                    streamURL: item.streamURL?.absoluteString
                )
                if state.favoriteIDs.contains(item.id) {
                    state.favoriteIDs.remove(item.id)
                } else {
                    state.favoriteIDs.insert(item.id)
                }
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(favItem)
                }

            case .delegate:
                return .none
            }
        }
    }
}
