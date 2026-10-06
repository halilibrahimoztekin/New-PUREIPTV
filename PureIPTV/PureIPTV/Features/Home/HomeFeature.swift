import ComposableArchitecture
import Foundation

// MARK: - Home Tab

public enum HomeTab: String, CaseIterable, Equatable {
    case dashboard = "Keşfet"
    case liveTV = "Canlı TV"
    case movies = "Filmler"
    case series = "Diziler"
    case search = "Ara"
    case settings = "Ayarlar"

    public var icon: String {
        switch self {
        case .dashboard: "house"
        case .liveTV: "tv"
        case .movies: "film"
        case .series: "rectangle.stack"
        case .search: "magnifyingglass"
        case .settings: "gearshape"
        }
    }

    public var selectedIcon: String {
        switch self {
        case .dashboard: "house.fill"
        case .liveTV: "tv.fill"
        case .movies: "film.fill"
        case .series: "rectangle.stack.fill"
        case .search: "magnifyingglass"
        case .settings: "gearshape.fill"
        }
    }
}

// MARK: - HomeFeature

@Reducer
public struct HomeFeature {
    @ObservableState
    public struct State: Equatable {
        public var selectedTab: HomeTab = .dashboard
        public var config: PlaylistConfig

        public var serverURL: String {
            config.serverURL?.absoluteString ?? config.m3uURL?.absoluteString ?? ""
        }

        public var username: String {
            config.username ?? ""
        }

        public var password: String {
            config.password ?? ""
        }

        /// Child feature states
        public var dashboard = DashboardFeature.State()
        public var liveTV = LiveTVFeature.State()
        public var vod = VODFeature.State()
        public var series = SeriesFeature.State()
        public var search = SearchFeature.State()
        public var settings = SettingsFeature.State()

        public init(config: PlaylistConfig) {
            self.config = config
        }
    }

    public enum Action {
        case tabSelected(HomeTab)
        case dashboard(DashboardFeature.Action)
        case liveTV(LiveTVFeature.Action)
        case vod(VODFeature.Action)
        case series(SeriesFeature.Action)
        case search(SearchFeature.Action)
        case settings(SettingsFeature.Action)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item, playlist: [MediaModels.Item]?)
            case didSelectVOD(MediaModels.Item)
            case didSelectSeries(MediaModels.Item)
            case playHistoryItem(WatchHistoryItem)
            case openManagePlaylists
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Scope(state: \.dashboard, action: \.dashboard) {
            DashboardFeature()
        }
        Scope(state: \.liveTV, action: \.liveTV) {
            LiveTVFeature()
        }
        Scope(state: \.vod, action: \.vod) {
            VODFeature()
        }
        Scope(state: \.series, action: \.series) {
            SeriesFeature()
        }
        Scope(state: \.search, action: \.search) {
            SearchFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }

        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case let .dashboard(.delegate(.didSelectChannel(channel, playlist))):
                return .send(.delegate(.didSelectChannel(channel, playlist: playlist)))

            case let .dashboard(.delegate(.didSelectVOD(vod))):
                return .send(.delegate(.didSelectVOD(vod)))

            case let .dashboard(.delegate(.didSelectSeries(series))):
                return .send(.delegate(.didSelectSeries(series)))

            case let .dashboard(.delegate(.playHistoryItem(item))):
                return .send(.delegate(.playHistoryItem(item)))

            case .dashboard:
                return .none

            case let .liveTV(.delegate(.didSelectChannel(channel, playlist))):
                return .send(.delegate(.didSelectChannel(channel, playlist: playlist)))

            case .liveTV:
                return .none

            case let .vod(.delegate(.didSelectVOD(vod))):
                return .send(.delegate(.didSelectVOD(vod)))

            case .vod:
                return .none

            case let .series(.delegate(.didSelectSeries(series))):
                return .send(.delegate(.didSelectSeries(series)))

            case .series:
                return .none

            case let .search(.delegate(.didSelectChannel(channel, playlist))):
                return .send(.delegate(.didSelectChannel(channel, playlist: playlist)))

            case let .search(.delegate(.didSelectVOD(vod))):
                return .send(.delegate(.didSelectVOD(vod)))

            case let .search(.delegate(.didSelectSeries(series))):
                return .send(.delegate(.didSelectSeries(series)))

            case .search:
                return .none

            case .settings(.delegate(.openManagePlaylists)):
                return .send(.delegate(.openManagePlaylists))

            case .settings:
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
