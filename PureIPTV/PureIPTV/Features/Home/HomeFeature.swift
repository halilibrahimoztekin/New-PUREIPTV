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
        case .dashboard: return "house"
        case .liveTV: return "tv"
        case .movies: return "film"
        case .series: return "rectangle.stack"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape"
        }
    }

    public var selectedIcon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .liveTV: return "tv.fill"
        case .movies: return "film.fill"
        case .series: return "rectangle.stack.fill"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - HomeFeature

@Reducer
public struct HomeFeature {
    @ObservableState
    public struct State: Equatable {
        public var selectedTab: HomeTab = .dashboard
        public var serverURL: String
        public var username: String
        public var password: String

        /// Child feature states
        public var dashboard = DashboardFeature.State()
        public var liveTV = LiveTVFeature.State()
        public var vod = VODFeature.State()
        public var series = SeriesFeature.State()
        public var search = SearchFeature.State()
        public var settings = SettingsFeature.State()

        public init(serverURL: String, username: String, password: String) {
            self.serverURL = serverURL
            self.username = username
            self.password = password
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

            case .settings:
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
