import ComposableArchitecture
import Foundation

// MARK: - Home Tab

public enum HomeTab: String, CaseIterable, Equatable {
    case dashboard = "Keşfet"
    case liveTV = "Canlı TV"
    case movies = "Filmler"
    case series = "Diziler"
    case search = "Ara"
    case downloads = "İndirilenler"
    case settings = "Ayarlar"

    public var icon: String {
        switch self {
        case .dashboard: "house"
        case .liveTV: "tv"
        case .movies: "film"
        case .series: "rectangle.stack"
        case .search: "magnifyingglass"
        case .downloads: "arrow.down.circle"
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
        case .downloads: "arrow.down.circle.fill"
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
        public var liveTVOnlyNavigation = false

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
        public var downloads = DownloadsFeature.State()
        public var settings = SettingsFeature.State()

        public var visibleTabs: [HomeTab] {
            if liveTVOnlyNavigation {
                return [.liveTV, .settings]
            }
            guard settings.hideEmptyContentTabs else { return HomeTab.allCases }
            return HomeTab.allCases.filter { tab in
                switch tab {
                case .liveTV:
                    !dashboard.hasResolvedLiveCatalog || dashboard.hasLiveContent
                case .movies:
                    !dashboard.hasResolvedMovieCatalog || dashboard.hasMovieContent
                case .series:
                    !dashboard.hasResolvedSeriesCatalog || dashboard.hasSeriesContent
                default:
                    true
                }
            }
        }

        public init(config: PlaylistConfig, deferDashboardRefresh: Bool = false) {
            self.config = config
            dashboard.deferInitialRemoteRefresh = deferDashboardRefresh

            @Dependency(\.settingsClient) var settingsClient
            let tabString = settingsClient.defaultStartupTab()
            liveTVOnlyNavigation = settingsClient.liveTVOnlyNavigation()
            if let tab = HomeTab(rawValue: tabString) {
                selectedTab = tab
            }
            if liveTVOnlyNavigation, selectedTab != .settings {
                selectedTab = .liveTV
            }
            settings.hideEmptyContentTabs = settingsClient.hideEmptyContentTabs()
        }
    }

    public enum Action {
        case tabSelected(HomeTab)
        case dashboard(DashboardFeature.Action)
        case liveTV(LiveTVFeature.Action)
        case vod(VODFeature.Action)
        case series(SeriesFeature.Action)
        case search(SearchFeature.Action)
        case downloads(DownloadsFeature.Action)
        case settings(SettingsFeature.Action)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item, playlist: [MediaModels.Item]?)
            case didSelectVOD(MediaModels.Item)
            case didSelectSeries(MediaModels.Item)
            case playHistoryItem(WatchHistoryItem)
            case restartHistoryItem(WatchHistoryItem)
            case openManagePlaylists
            case switchProfile
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
        Scope(state: \.downloads, action: \.downloads) {
            DownloadsFeature()
        }

        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                guard state.visibleTabs.contains(tab) else { return .none }
                state.selectedTab = tab
                if tab == .movies {
                    return .send(.vod(.applySortIfChanged))
                } else if tab == .series {
                    return .send(.series(.applySortIfChanged))
                }
                return .none

            case let .dashboard(.delegate(.didSelectChannel(channel, playlist))):
                return .send(.delegate(.didSelectChannel(channel, playlist: playlist)))

            case let .dashboard(.delegate(.didSelectVOD(vod))):
                return .send(.delegate(.didSelectVOD(vod)))

            case let .dashboard(.delegate(.didSelectSeries(series))):
                return .send(.delegate(.didSelectSeries(series)))

            case let .dashboard(.delegate(.playHistoryItem(item))):
                return .send(.delegate(.playHistoryItem(item)))

            case let .dashboard(.delegate(.restartHistoryItem(item))):
                return .send(.delegate(.restartHistoryItem(item)))

            case .dashboard(.delegate(.openManagePlaylists)):
                return .send(.delegate(.openManagePlaylists))

            case let .settings(.setLiveTVOnlyNavigation(enabled)):
                state.liveTVOnlyNavigation = enabled
                if enabled, state.selectedTab != .settings {
                    state.selectedTab = .liveTV
                }
                return .none

            case .dashboard:
                if !state.visibleTabs.contains(state.selectedTab) {
                    state.selectedTab = .dashboard
                }
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

            case let .downloads(.delegate(.playOfflineMedia(item))):
                return .send(.delegate(.playHistoryItem(WatchHistoryItem(id: item.id, type: "vod", title: item.title, coverURL: item.coverURL, streamURL: item.localFilePath, progress: 0, duration: 0))))

            case .downloads:
                return .none

            case .settings(.delegate(.openManagePlaylists)):
                return .send(.delegate(.openManagePlaylists))

            case .settings(.delegate(.switchProfile)):
                return .send(.delegate(.switchProfile))

            case .settings:
                if !state.visibleTabs.contains(state.selectedTab) {
                    state.selectedTab = .dashboard
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
