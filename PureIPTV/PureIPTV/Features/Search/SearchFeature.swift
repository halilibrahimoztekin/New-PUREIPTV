import ComposableArchitecture
import FactoryKit
import Foundation

// MARK: - SearchFeature

@Reducer
public struct SearchFeature {
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
        public var filter: SearchFilter = .all

        // UI state
        public var isLoading = false
        public var hasLoaded = false
        public var errorMessage: String?

        /// Computed Results
        public var liveResults: [MediaModels.Item] {
            if searchQuery.isEmpty {
                return []
            }
            if filter != .all, filter != .live {
                return []
            }
            return allChannels.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        }

        public var vodResults: [MediaModels.Item] {
            if searchQuery.isEmpty {
                return []
            }
            if filter != .all, filter != .vod {
                return []
            }
            return allVODs.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        }

        public var seriesResults: [MediaModels.Item] {
            if searchQuery.isEmpty {
                return []
            }
            if filter != .all, filter != .series {
                return []
            }
            return allSeries.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
        }

        public var totalResultsCount: Int {
            liveResults.count + vodResults.count + seriesResults.count
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case loadAllDataResponse(Result<(channels: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item]), Error>)
        case queryChanged(String)
        case filterChanged(SearchFilter)
        case channelSelected(MediaModels.Item)
        case vodSelected(MediaModels.Item)
        case seriesSelected(MediaModels.Item)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item, playlist: [MediaModels.Item]?)
            case didSelectVOD(MediaModels.Item)
            case didSelectSeries(MediaModels.Item)
        }
    }

    @Injected(\.iptvClient) var iptvClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = self.iptvClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                guard !state.hasLoaded, !state.isLoading else { return .none }
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    async let channelsReq = try? iptvClient.fetchLiveChannels(config, nil)
                    async let vodsReq = try? iptvClient.fetchVODs(config, nil)
                    async let seriesReq = try? iptvClient.fetchSeries(config, nil)

                    // Fetch all concurrently
                    let (channels, vods, series) = await (channelsReq, vodsReq, seriesReq)

                    if channels == nil && vods == nil && series == nil {
                        await send(.loadAllDataResponse(.failure(NetworkError.invalidResponse)))
                    } else {
                        await send(.loadAllDataResponse(.success((
                            channels: channels ?? [],
                            vods: vods ?? [],
                            series: series ?? []
                        ))))
                    }
                }

            case let .loadAllDataResponse(.success(data)):
                state.isLoading = false
                state.hasLoaded = true
                state.allChannels = data.channels
                state.allVODs = data.vods
                state.allSeries = data.series
                return .none

            case let .loadAllDataResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = String(localized: "Arama verileri yüklenemedi: \(error.localizedDescription)")
                return .none

            case let .queryChanged(query):
                state.searchQuery = query
                return .none

            case let .filterChanged(filter):
                state.filter = filter
                return .none

            case let .channelSelected(channel):
                switch channel.type {
                case .live:
                    return .send(.delegate(.didSelectChannel(channel, playlist: state.liveResults)))
                case .vod:
                    return .send(.delegate(.didSelectVOD(channel)))
                case .series:
                    return .send(.delegate(.didSelectSeries(channel)))
                }

            case let .vodSelected(vod):
                return .send(.delegate(.didSelectVOD(vod)))

            case let .seriesSelected(series):
                return .send(.delegate(.didSelectSeries(series)))

            case .delegate:
                return .none
            }
        }
    }
}
