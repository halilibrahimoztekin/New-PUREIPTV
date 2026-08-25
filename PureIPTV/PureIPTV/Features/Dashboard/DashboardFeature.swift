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
        public var errorMessage: String?

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case loadFeaturedData(config: PlaylistConfig)
        case dataLoaded(channels: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item])
        case dataFailed(Error)
        case channelSelected(MediaModels.Item)
        case vodSelected(MediaModels.Item)
        case seriesSelected(MediaModels.Item)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item)
            case didSelectVOD(MediaModels.Item)
            case didSelectSeries(MediaModels.Item)
        }
    }

    @Dependency(\.iptvClient) var iptvClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                guard state.featuredChannels.isEmpty, state.featuredVODs.isEmpty, state.featuredSeries.isEmpty else { return .none }
                return .send(.loadFeaturedData(config: config))

            case let .loadFeaturedData(config):
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    // Fetch categories to get some content
                    async let liveCategories = try? iptvClient.fetchLiveCategories(config)
                    async let vodCategories = try? iptvClient.fetchVODCategories(config)
                    async let seriesCategories = try? iptvClient.fetchSeriesCategories(config)

                    let liveCat = await liveCategories
                    let vodCat = await vodCategories
                    let seriesCat = await seriesCategories

                    var channels: [MediaModels.Item] = []
                    var vods: [MediaModels.Item] = []
                    var series: [MediaModels.Item] = []

                    if let firstLiveCat = liveCat?.first {
                        if let streamList = try? await iptvClient.fetchLiveChannels(config, firstLiveCat.id) {
                            channels = Array(streamList.prefix(10))
                        }
                    }
                    if let firstVodCat = vodCat?.first {
                        if let streamList = try? await iptvClient.fetchVODs(config, firstVodCat.id) {
                            vods = Array(streamList.prefix(10))
                        }
                    }
                    if let firstSeriesCat = seriesCat?.first {
                        if let streamList = try? await iptvClient.fetchSeries(config, firstSeriesCat.id) {
                            series = Array(streamList.prefix(10))
                        }
                    }

                    await send(.dataLoaded(channels: channels, vods: vods, series: series))
                } catch: { error, send in
                    await send(.dataFailed(error))
                }

            case let .dataLoaded(channels, vods, series):
                state.isLoading = false
                state.featuredChannels = channels
                state.featuredVODs = vods
                state.featuredSeries = series
                return .none

            case let .dataFailed(error):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case let .channelSelected(channel):
                return .send(.delegate(.didSelectChannel(channel)))

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
