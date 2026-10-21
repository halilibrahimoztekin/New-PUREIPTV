import ComposableArchitecture
import FactoryKit
import Foundation
import SwiftUI

// MARK: - SearchFeature / GlobalSearchFeature

/// Cancel ID must be fully Sendable and non-isolated to avoid
/// main-actor isolation conflicts with the @Reducer macro.
private let searchCancelID = "SearchFeature.search"

@Reducer
public struct SearchFeature: Sendable {
    public enum SearchFilter: String, CaseIterable, Equatable, Sendable {
        case all = "Tümü"
        case live = "Canlı TV"
        case vod = "Filmler"
        case series = "Diziler"
        case uhd4k = "4K / UHD"
        case epgMatches = "EPG Programları"

        public var title: String {
            switch self {
            case .all: AppStrings.Search.all
            case .live: AppStrings.Search.liveTV
            case .vod: AppStrings.Search.movies
            case .series: AppStrings.Search.series
            case .uhd4k: AppStrings.Search.filter4K
            case .epgMatches: AppStrings.Search.filterEPG
            }
        }

        public var icon: String {
            switch self {
            case .all: "square.grid.2x2.fill"
            case .live: "tv.fill"
            case .vod: "film.fill"
            case .series: "play.tv.fill"
            case .uhd4k: "sparkles.tv.fill"
            case .epgMatches: "clock.badge.checkmark.fill"
            }
        }

        public var badgeColorHex: String {
            switch self {
            case .all: "#0A84FF" // System Blue
            case .live: "#0A84FF" // Electric Blue
            case .vod: "#BF5AF2" // Cinema Violet
            case .series: "#FF9F0A" // Sunset Amber
            case .uhd4k: "#FFD60A" // Radiant Gold
            case .epgMatches: "#30D158" // Stadium Green
            }
        }

        public var badgeColor: Color {
            Color(hex: badgeColorHex)
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

        // Multi-Playlist Cross-Indexing
        public var savedPlaylists: [SavedPlaylist] = []
        public var selectedPlaylistID: UUID?
        public var indexedChannels: [GlobalSearchResultItem] = []
        public var indexedVODs: [GlobalSearchResultItem] = []
        public var indexedSeries: [GlobalSearchResultItem] = []

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

        // Stored Results (for backward compatibility)
        public var liveResults: [MediaModels.Item] = []
        public var vodResults: [MediaModels.Item] = []
        public var seriesResults: [MediaModels.Item] = []
        public var favoriteIDs: Set<String> = []

        // Enriched Multi-Playlist Results
        public var enrichedLiveResults: [GlobalSearchResultItem] = []
        public var enrichedVODResults: [GlobalSearchResultItem] = []
        public var enrichedSeriesResults: [GlobalSearchResultItem] = []
        public var filterCounts: [SearchFilter: Int] = [:]

        public var totalResultsCount: Int {
            if !enrichedLiveResults.isEmpty || !enrichedVODResults.isEmpty || !enrichedSeriesResults.isEmpty {
                return enrichedLiveResults.count + enrichedVODResults.count + enrichedSeriesResults.count
            }
            return liveResults.count + vodResults.count + seriesResults.count
        }

        public mutating func updateResults() {
            let query = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                liveResults = []
                vodResults = []
                seriesResults = []
                enrichedLiveResults = []
                enrichedVODResults = []
                enrichedSeriesResults = []
                filterCounts = [:]
                return
            }

            let defaultBadge = PlaylistSourceBadge(
                id: lastLoadedConfig?.serverURL?.absoluteString ?? "default",
                playlistName: lastLoadedConfig?.serverURL?.host ?? "Varsayılan",
                colorHex: "#0A84FF"
            )

            let chSource = !indexedChannels.isEmpty ? indexedChannels : allChannels.map {
                GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge)
            }
            let voSource = !indexedVODs.isEmpty ? indexedVODs : allVODs.map {
                GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge)
            }
            let seSource = !indexedSeries.isEmpty ? indexedSeries : allSeries.map {
                GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge)
            }

            let output = GlobalSearchEngine.search(
                query: query,
                filter: filter,
                selectedPlaylistID: selectedPlaylistID,
                channels: chSource,
                vods: voSource,
                series: seSource,
                limitPerCategory: 100
            )

            enrichedLiveResults = output.live
            enrichedVODResults = output.vods
            enrichedSeriesResults = output.series
            filterCounts = output.counts

            liveResults = output.live.map(\.item)
            vodResults = output.vods.map(\.item)
            seriesResults = output.series.map(\.item)
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case loadSavedPlaylistsResponse([SavedPlaylist])
        case loadRecentSearchesResponse([SearchHistoryItem])
        case loadAllDataResponse(Result<(channels: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item]), Error>)
        case loadPlaylistsDataResponse([(badge: PlaylistSourceBadge, channels: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item])])
        case queryChanged(String)
        case performSearch(String)
        case searchCompleted(query: String, filter: SearchFilter, live: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item])
        case searchEnrichedCompleted(query: String, filter: SearchFilter, output: GlobalSearchEngine.SearchResultOutput)
        case filterChanged(SearchFilter)
        case selectPlaylistFilter(UUID?)
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
    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.continuousClock) var clock
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.settingsClient) var settingsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let playlistRepository = playlistRepository
        let settingsClient = settingsClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                let playlists = playlistRepository.getPlaylists()
                state.savedPlaylists = playlists

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
                    state.indexedChannels = []
                    state.indexedVODs = []
                    state.indexedSeries = []
                    state.liveResults = []
                    state.vodResults = []
                    state.seriesResults = []
                    state.enrichedLiveResults = []
                    state.enrichedVODResults = []
                    state.enrichedSeriesResults = []
                    state.filterCounts = [:]
                    state.searchQuery = ""
                    state.debouncedQuery = ""
                    state.isSearching = false
                    state.lastLoadedConfig = config
                    state.lastAdultHidden = currentAdultHidden
                }

                guard !state.hasLoaded, !state.isLoading else { return .merge(loadHistory, loadFavs) }
                state.isLoading = true
                state.errorMessage = nil

                // Concurrently fetch active playlist plus other playlists if multiple exist
                let primaryFetch: Effect<Action> = .run { send in
                    async let channelsReq = try? iptvClient.fetchLiveChannels(config, nil)
                    async let vodsReq = try? iptvClient.fetchVODs(config, nil)
                    async let seriesReq = try? iptvClient.fetchSeries(config, nil)

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
                }

                let multiPlaylistFetch: Effect<Action> = if playlists.count > 1 {
                    .run { send in
                        var list: [(badge: PlaylistSourceBadge, channels: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item])] = []
                        for (index, p) in playlists.enumerated() {
                            guard let pConfig = p.toPlaylistConfig() else { continue }
                            let badge = UnifiedPlaylistManager.shared.badge(for: pConfig, index: index)
                            async let channelsReq = try? iptvClient.fetchLiveChannels(pConfig, nil)
                            async let vodsReq = try? iptvClient.fetchVODs(pConfig, nil)
                            async let seriesReq = try? iptvClient.fetchSeries(pConfig, nil)
                            let (ch, vo, se) = await (channelsReq, vodsReq, seriesReq)
                            list.append((badge: badge, channels: ch ?? [], vods: vo ?? [], series: se ?? []))
                        }
                        await send(.loadPlaylistsDataResponse(list))
                    }
                } else {
                    .none
                }

                return .merge(loadHistory, loadFavs, primaryFetch, multiPlaylistFetch)

            case let .loadSavedPlaylistsResponse(playlists):
                state.savedPlaylists = playlists
                return .none

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

                // Create initial default indexed items if no multi-playlist items yet
                if state.indexedChannels.isEmpty {
                    let defaultBadge = PlaylistSourceBadge(
                        id: state.lastLoadedConfig?.serverURL?.absoluteString ?? "default",
                        playlistName: state.lastLoadedConfig?.serverURL?.host ?? "Varsayılan",
                        colorHex: "#0A84FF"
                    )
                    state.indexedChannels = state.allChannels.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                    state.indexedVODs = state.allVODs.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                    state.indexedSeries = state.allSeries.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                }

                if !state.debouncedQuery.isEmpty {
                    return .send(.performSearch(state.debouncedQuery))
                }
                return .none

            case let .loadAllDataResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = AppStrings.Errors.searchFailed(desc: error.localizedDescription)
                return .none

            case let .loadPlaylistsDataResponse(list):
                let hideAdult = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdult = settingsClient.isAdultContent

                var allIndexedCh: [GlobalSearchResultItem] = []
                var allIndexedVo: [GlobalSearchResultItem] = []
                var allIndexedSe: [GlobalSearchResultItem] = []

                for item in list {
                    let chs = hideAdult ? item.channels.filter { !isAdult($0.title) } : item.channels
                    let vos = hideAdult ? item.vods.filter { !isAdult($0.title) } : item.vods
                    let ses = hideAdult ? item.series.filter { !isAdult($0.title) } : item.series

                    allIndexedCh.append(contentsOf: chs.map { GlobalSearchResultItem(item: $0, playlistBadge: item.badge) })
                    allIndexedVo.append(contentsOf: vos.map { GlobalSearchResultItem(item: $0, playlistBadge: item.badge) })
                    allIndexedSe.append(contentsOf: ses.map { GlobalSearchResultItem(item: $0, playlistBadge: item.badge) })
                }

                state.indexedChannels = allIndexedCh
                state.indexedVODs = allIndexedVo
                state.indexedSeries = allIndexedSe

                if !state.debouncedQuery.isEmpty {
                    return .send(.performSearch(state.debouncedQuery))
                }
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
                    state.enrichedLiveResults = []
                    state.enrichedVODResults = []
                    state.enrichedSeriesResults = []
                    state.filterCounts = [:]
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
                    state.enrichedLiveResults = []
                    state.enrichedVODResults = []
                    state.enrichedSeriesResults = []
                    state.filterCounts = [:]
                    return .none
                }

                state.isSearching = true
                let filter = state.filter
                let selectedPID = state.selectedPlaylistID

                let channels: [GlobalSearchResultItem]
                let vods: [GlobalSearchResultItem]
                let series: [GlobalSearchResultItem]

                if !state.indexedChannels.isEmpty || !state.indexedVODs.isEmpty || !state.indexedSeries.isEmpty {
                    channels = state.indexedChannels
                    vods = state.indexedVODs
                    series = state.indexedSeries
                } else {
                    let defaultBadge = PlaylistSourceBadge(
                        id: state.lastLoadedConfig?.serverURL?.absoluteString ?? "default",
                        playlistName: state.lastLoadedConfig?.serverURL?.host ?? "Varsayılan",
                        colorHex: "#0A84FF"
                    )
                    channels = state.allChannels.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                    vods = state.allVODs.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                    series = state.allSeries.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                }

                return .run { send in
                    guard !Task.isCancelled else { return }
                    let output = GlobalSearchEngine.search(
                        query: trimmed,
                        filter: filter,
                        selectedPlaylistID: selectedPID,
                        channels: channels,
                        vods: vods,
                        series: series,
                        limitPerCategory: 100
                    )
                    guard !Task.isCancelled else { return }
                    await send(.searchEnrichedCompleted(query: query, filter: filter, output: output))
                }
                .cancellable(id: searchCancelID, cancelInFlight: true)

            case let .searchCompleted(query, filter, live, vods, series):
                guard state.debouncedQuery == query, state.filter == filter else { return .none }
                state.isSearching = false
                state.liveResults = live
                state.vodResults = vods
                state.seriesResults = series
                return .none

            case let .searchEnrichedCompleted(query, filter, output):
                guard state.debouncedQuery == query, state.filter == filter else { return .none }
                state.isSearching = false
                state.enrichedLiveResults = output.live
                state.enrichedVODResults = output.vods
                state.enrichedSeriesResults = output.series
                state.filterCounts = output.counts

                // Maintain backward compatibility
                state.liveResults = output.live.map(\.item)
                state.vodResults = output.vods.map(\.item)
                state.seriesResults = output.series.map(\.item)
                return .none

            case let .filterChanged(filter):
                state.filter = filter
                if !state.debouncedQuery.isEmpty {
                    return .send(.performSearch(state.debouncedQuery))
                }
                return .none

            case let .selectPlaylistFilter(playlistID):
                state.selectedPlaylistID = playlistID
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
                state.indexedChannels = []
                state.indexedVODs = []
                state.indexedSeries = []
                state.liveResults = []
                state.vodResults = []
                state.seriesResults = []
                state.enrichedLiveResults = []
                state.enrichedVODResults = []
                state.enrichedSeriesResults = []
                state.filterCounts = [:]
                state.searchQuery = ""
                state.debouncedQuery = ""
                state.lastLoadedConfig = nil
                state.selectedPlaylistID = nil
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

// MARK: - GlobalSearchFeature Alias

public typealias GlobalSearchFeature = SearchFeature
