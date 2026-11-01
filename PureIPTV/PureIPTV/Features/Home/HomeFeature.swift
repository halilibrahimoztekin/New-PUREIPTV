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
        public var liveTVSourceConfig: PlaylistConfig
        public var moviesSourceConfig: PlaylistConfig
        public var seriesSourceConfig: PlaylistConfig
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
            let navigationTabs = HomeTab.allCases.filter { $0 != .search }
            guard settings.hideEmptyContentTabs else { return navigationTabs }
            return navigationTabs.filter { tab in
                switch tab {
                case .liveTV:
                    if liveTVSourceConfig.playlistID != config.playlistID {
                        guard liveTV.config == liveTVSourceConfig else { return true }
                        return !liveTV.hasResolvedCategories || !liveTV.categories.isEmpty
                    }
                    return !dashboard.hasResolvedLiveCatalog || dashboard.hasLiveContent
                case .movies:
                    if moviesSourceConfig.playlistID != config.playlistID {
                        guard vod.config == moviesSourceConfig else { return true }
                        return !vod.hasResolvedCategories || !vod.categories.isEmpty
                    }
                    return !dashboard.hasResolvedMovieCatalog || dashboard.hasMovieContent
                case .series:
                    if seriesSourceConfig.playlistID != config.playlistID {
                        guard series.config == seriesSourceConfig else { return true }
                        return !series.hasResolvedCategories || !series.categories.isEmpty
                    }
                    return !dashboard.hasResolvedSeriesCatalog || dashboard.hasSeriesContent
                default:
                    return true
                }
            }
        }

        fileprivate mutating func normalizeSelectedTab() {
            guard !visibleTabs.contains(selectedTab) else { return }
            let fallback: HomeTab = liveTVOnlyNavigation ? .liveTV : .dashboard
            selectedTab = visibleTabs.contains(fallback) ? fallback : (visibleTabs.first ?? fallback)
        }

        public init(
            config: PlaylistConfig,
            deferDashboardRefresh: Bool = false,
            contentSourceConfigs: PlaylistContentSourceConfigs? = nil
        ) {
            self.config = config
            liveTVSourceConfig = contentSourceConfigs?.liveTV ?? config
            moviesSourceConfig = contentSourceConfigs?.movies ?? config
            seriesSourceConfig = contentSourceConfigs?.series ?? config
            dashboard.deferInitialRemoteRefresh = deferDashboardRefresh || !config.automaticallyRefreshCatalogOnStartup

            @Dependency(\.settingsClient) var settingsClient
            @Dependency(\.profileContextClient) var profileContextClient
            let profileID = profileContextClient.snapshot().profileID
            let tabString = settingsClient.defaultStartupTabForProfile(profileID)
            liveTVOnlyNavigation = settingsClient.liveTVOnlyNavigation()
            if let tab = HomeTab(rawValue: tabString) {
                selectedTab = tab
            }
            if selectedTab == .search {
                selectedTab = .dashboard
            }
            if liveTVOnlyNavigation, selectedTab != .settings {
                selectedTab = .liveTV
            }
            settings.hideEmptyContentTabs = settingsClient.hideEmptyContentTabs()
            normalizeSelectedTab()
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
        case contentSourceConfigsUpdated(PlaylistContentSourceConfigs)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item, playlist: [MediaModels.Item]?)
            case presentEPGGuide(EPGGuideFeature.State)
            case presentEPGTimeline(EPGTimelineFeature.State)
            case presentMultiView(MultiViewFeature.State)
            case restrictMultiViewCategory(String)
            case presentCategoryManagement(CategoryManagementFeature.State)
            case presentParentalLock(ParentalLockFeature.State)
            case restrictMultiViewCategoryAndPresentParentalLock(categoryID: String, state: ParentalLockFeature.State)
            case presentVODCategoryManagement(CategoryManagementFeature.State)
            case presentSeriesCategoryManagement(CategoryManagementFeature.State)
            case presentVODParentalLock(ParentalLockFeature.State, closeVODDetailsOnExpiry: Bool)
            case presentSeriesParentalLock(ParentalLockFeature.State)
            case presentSmartGroupManager
            case presentFavoriteListManagement
            case presentChannelPresentationEditor(channel: MediaModels.Item, playlistID: UUID, profileScope: ProfileContextSnapshot)
            case didSelectVOD(MediaModels.Item)
            case didSelectSeries(MediaModels.Item)
            case playHistoryItem(WatchHistoryItem)
            case restartHistoryItem(WatchHistoryItem)
            case playOfflineMedia(OfflineMediaSnapshot, episodeQueue: [OfflineMediaSnapshot])
            case openManagePlaylists
            case switchProfile
            case presentSearch
            case presentHiddenMediaManagement
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
            case let .contentSourceConfigsUpdated(configs):
                let liveTVChanged = state.liveTVSourceConfig != configs.liveTV
                let moviesChanged = state.moviesSourceConfig != configs.movies
                let seriesChanged = state.seriesSourceConfig != configs.series
                let liveTVNeedsSamePlaylistReload = liveTVChanged
                    && state.liveTVSourceConfig.playlistID == configs.liveTV.playlistID
                    && (!state.liveTV.categories.isEmpty || state.liveTV.isLoadingCategories)
                let moviesNeedSamePlaylistReload = moviesChanged
                    && state.moviesSourceConfig.playlistID == configs.movies.playlistID
                    && (!state.vod.categories.isEmpty || state.vod.isLoadingCategories)
                let seriesNeedsSamePlaylistReload = seriesChanged
                    && state.seriesSourceConfig.playlistID == configs.series.playlistID
                    && (!state.series.categories.isEmpty || state.series.isLoadingCategories)
                state.liveTVSourceConfig = configs.liveTV
                state.moviesSourceConfig = configs.movies
                state.seriesSourceConfig = configs.series
                if !state.visibleTabs.contains(state.selectedTab) {
                    state.normalizeSelectedTab()
                }
                let liveTVEffect: Effect<Action> = if liveTVChanged {
                    if liveTVNeedsSamePlaylistReload {
                        .concatenate(
                            .send(.liveTV(.onAppear(config: configs.liveTV))),
                            .send(.liveTV(.reloadCategories(config: configs.liveTV)))
                        )
                    } else {
                        .send(.liveTV(.onAppear(config: configs.liveTV)))
                    }
                } else {
                    .none
                }
                let moviesEffect: Effect<Action> = if moviesChanged {
                    if moviesNeedSamePlaylistReload {
                        .concatenate(
                            .send(.vod(.onAppear(config: configs.movies))),
                            .send(.vod(.reloadCategories(config: configs.movies)))
                        )
                    } else {
                        .send(.vod(.onAppear(config: configs.movies)))
                    }
                } else {
                    .none
                }
                let seriesEffect: Effect<Action> = if seriesChanged {
                    if seriesNeedsSamePlaylistReload {
                        .concatenate(
                            .send(.series(.onAppear(config: configs.series))),
                            .send(.series(.reloadCategories(config: configs.series)))
                        )
                    } else {
                        .send(.series(.onAppear(config: configs.series)))
                    }
                } else {
                    .none
                }
                return .merge(
                    liveTVEffect,
                    moviesEffect,
                    seriesEffect
                )

            case .liveTV(.categoriesResponse(.success(_), _, _, _)),
                 .vod(.categoriesResponse(_, _, .success(_), _, _)),
                 .series(.categoriesResponse(_, _, .success(_), _, _)),
                 .vod(.categoriesPreferencesLoaded(_, _, _, _)),
                 .series(.categoriesPreferencesLoaded(_, _, _, _)):
                state.normalizeSelectedTab()
                return .none

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
                state.normalizeSelectedTab()
                return .none

            case let .liveTV(.delegate(.didSelectChannel(channel, playlist))):
                return .send(.delegate(.didSelectChannel(channel, playlist: playlist)))

            case let .liveTV(.delegate(.presentEPGGuide(guideState))):
                return .send(.delegate(.presentEPGGuide(guideState)))

            case let .liveTV(.delegate(.presentEPGTimeline(timelineState))):
                return .send(.delegate(.presentEPGTimeline(timelineState)))

            case let .liveTV(.delegate(.presentMultiView(multiViewState))):
                return .send(.delegate(.presentMultiView(multiViewState)))

            case let .liveTV(.delegate(.restrictMultiViewCategory(categoryID))):
                return .send(.delegate(.restrictMultiViewCategory(categoryID)))

            case let .liveTV(.delegate(.presentCategoryManagement(categoryState))):
                return .send(.delegate(.presentCategoryManagement(categoryState)))

            case let .liveTV(.delegate(.presentParentalLock(parentalLockState))):
                return .send(.delegate(.presentParentalLock(parentalLockState)))

            case let .liveTV(.delegate(.restrictMultiViewCategoryAndPresentParentalLock(categoryID, parentalLockState))):
                return .send(.delegate(.restrictMultiViewCategoryAndPresentParentalLock(
                    categoryID: categoryID,
                    state: parentalLockState
                )))

            case .liveTV(.delegate(.presentSmartGroupManager)):
                return .send(.delegate(.presentSmartGroupManager))

            case .liveTV(.delegate(.presentFavoriteListManagement)):
                return .send(.delegate(.presentFavoriteListManagement))

            case let .liveTV(.delegate(.presentChannelPresentationEditor(channel, playlistID, profileScope))):
                return .send(.delegate(.presentChannelPresentationEditor(
                    channel: channel,
                    playlistID: playlistID,
                    profileScope: profileScope
                )))

            case .liveTV:
                state.normalizeSelectedTab()
                return .none

            case let .vod(.delegate(.didSelectVOD(vod))):
                return .send(.delegate(.didSelectVOD(vod)))

            case let .vod(.delegate(.presentCategoryManagement(categoryState))):
                return .send(.delegate(.presentVODCategoryManagement(categoryState)))

            case let .vod(.delegate(.presentParentalLock(parentalLockState, closeVODDetailsOnExpiry))):
                return .send(.delegate(.presentVODParentalLock(
                    parentalLockState,
                    closeVODDetailsOnExpiry: closeVODDetailsOnExpiry
                )))

            case .vod:
                state.normalizeSelectedTab()
                return .none

            case let .series(.delegate(.didSelectSeries(series))):
                return .send(.delegate(.didSelectSeries(series)))

            case let .series(.delegate(.presentCategoryManagement(categoryState))):
                return .send(.delegate(.presentSeriesCategoryManagement(categoryState)))

            case let .series(.delegate(.presentParentalLock(parentalLockState))):
                return .send(.delegate(.presentSeriesParentalLock(parentalLockState)))

            case .series:
                state.normalizeSelectedTab()
                return .none

            case let .search(.delegate(.didSelectChannel(channel, playlist))):
                return .send(.delegate(.didSelectChannel(channel, playlist: playlist)))

            case let .search(.delegate(.didSelectVOD(vod))):
                return .send(.delegate(.didSelectVOD(vod)))

            case let .search(.delegate(.didSelectSeries(series))):
                return .send(.delegate(.didSelectSeries(series)))

            case let .search(.delegate(.playOfflineMedia(item, episodeQueue))):
                return .send(.delegate(.playOfflineMedia(item, episodeQueue: episodeQueue)))

            case .search:
                return .none

            case let .downloads(.delegate(.playOfflineMedia(item, episodeQueue))):
                return .send(.delegate(.playOfflineMedia(item, episodeQueue: episodeQueue)))

            case .downloads:
                return .none

            case .settings(.delegate(.openManagePlaylists)):
                return .send(.delegate(.openManagePlaylists))

            case .settings(.delegate(.presentUserHiddenMediaManagement)):
                return .send(.delegate(.presentHiddenMediaManagement))

            case .settings(.delegate(.switchProfile)):
                return .send(.delegate(.switchProfile))

            case .settings:
                state.normalizeSelectedTab()
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
