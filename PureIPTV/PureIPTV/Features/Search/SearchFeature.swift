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

        // UI state
        public var isLoading = false
        public var hasLoaded = false
        public var errorMessage: String?

        /// Computed Results
        public var liveResults: [MediaModels.Item] {
            if debouncedQuery.isEmpty {
                return []
            }
            if filter != .all, filter != .live {
                return []
            }
            return allChannels.filter { $0.title.localizedCaseInsensitiveContains(debouncedQuery) }
        }

        public var vodResults: [MediaModels.Item] {
            if debouncedQuery.isEmpty {
                return []
            }
            if filter != .all, filter != .vod {
                return []
            }
            return allVODs.filter { $0.title.localizedCaseInsensitiveContains(debouncedQuery) }
        }

        public var seriesResults: [MediaModels.Item] {
            if debouncedQuery.isEmpty {
                return []
            }
            if filter != .all, filter != .series {
                return []
            }
            return allSeries.filter { $0.title.localizedCaseInsensitiveContains(debouncedQuery) }
        }

        public var totalResultsCount: Int {
            liveResults.count + vodResults.count + seriesResults.count
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case loadRecentSearchesResponse([SearchHistoryItem])
        case loadAllDataResponse(Result<(channels: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item]), Error>)
        case queryChanged(String)
        case performSearch(String)
        case filterChanged(SearchFilter)
        case channelSelected(MediaModels.Item)
        case vodSelected(MediaModels.Item)
        case seriesSelected(MediaModels.Item)
        case clearHistoryTapped
        case recentSearchTapped(String)
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

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                let loadHistory: Effect<Action> = .run { send in
                    let history = await (try? databaseClient.fetchSearchHistory()) ?? []
                    await send(.loadRecentSearchesResponse(history))
                }

                guard !state.hasLoaded, !state.isLoading else { return loadHistory }
                state.isLoading = true
                state.errorMessage = nil

                return .merge(loadHistory, .run { send in
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
                state.allChannels = data.channels
                state.allVODs = data.vods
                state.allSeries = data.series
                return .none

            case let .loadAllDataResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = AppStrings.Errors.searchFailed(desc: error.localizedDescription)
                return .none

            case let .queryChanged(query):
                state.searchQuery = query
                return .run { send in
                    try await clock.sleep(for: .milliseconds(300))
                    await send(.performSearch(query))
                }
                .cancellable(id: searchCancelID, cancelInFlight: true)

            case let .performSearch(query):
                state.debouncedQuery = query
                return .none

            case let .filterChanged(filter):
                state.filter = filter
                return .none

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
                return .send(.queryChanged(query))

            case .delegate:
                return .none
            }
        }
    }
}
