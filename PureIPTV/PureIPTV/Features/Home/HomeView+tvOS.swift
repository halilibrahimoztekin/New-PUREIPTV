#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS Home View

    // Uses TabView with top-positioned tab bar (tvOS default).
    // Tab bar automatically hides during full-screen playback.
    // All tab content is focusable via the Focus Engine.

    public struct HomeView_tvOS: View {
        @Bindable var store: StoreOf<HomeFeature>

        public init(store: StoreOf<HomeFeature>) {
            self.store = store
        }

        public var body: some View {
            TabView(selection: Binding(
                get: { store.selectedTab },
                set: { store.send(.tabSelected($0)) }
            )) {
                ForEach(store.visibleTabs, id: \.self) { tab in
                    TVTabContentView(tab: tab, store: store)
                        .tabItem {
                            Label(tab.rawValue, systemImage: store.selectedTab == tab ? tab.selectedIcon : tab.icon)
                        }
                        .tag(tab)
                }
            }
        }
    }

    // MARK: - TV Tab Content Placeholder

    private struct TVTabPlaceholder: View {
        let tab: HomeTab

        @FocusState private var isFocused: Bool

        var body: some View {
            ZStack {
                AppColors.oledBlack.ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: tab.selectedIcon)
                        .font(AppFonts.displayLarge.weight(.semibold))
                        .foregroundStyle(tabColor)
                        .scaleEffect(isFocused ? 1.08 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)

                    Text(tab.rawValue)
                        .font(AppFonts.displayMedium.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(AppStrings.Common.comingSoon)
                        .font(AppFonts.titleLarge)
                        .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.5))
                }
                .focusable()
                .focused($isFocused)
            }
        }

        private var tabColor: Color {
            switch tab {
            case .dashboard: AppColors.amber
            case .liveTV: AppColors.live
            case .movies: AppColors.premium
            case .series: AppColors.success
            case .search: AppColors.primary
            case .downloads: AppColors.cyan
            case .settings: AppColors.onSurfaceVariant
            }
        }
    }

    private struct TVTabContentView: View {
        let tab: HomeTab
        @Bindable var store: StoreOf<HomeFeature>

        var body: some View {
            switch tab {
            case .dashboard:
                DashboardView_tvOS(
                    store: store.scope(state: \.dashboard, action: \.dashboard),
                    config: store.config
                )
            case .liveTV:
                LiveTVView(
                    store: store.scope(state: \.liveTV, action: \.liveTV),
                    config: store.liveTVSourceConfig
                )
            case .movies:
                VODView(
                    store: store.scope(state: \.vod, action: \.vod),
                    config: store.moviesSourceConfig
                )
            case .series:
                SeriesView(
                    store: store.scope(state: \.series, action: \.series),
                    config: store.seriesSourceConfig
                )
            case .search:
                SearchView_tvOS(
                    store: store.scope(state: \.search, action: \.search),
                    config: store.config
                )
            case .downloads:
                DownloadsView(
                    store: store.scope(state: \.downloads, action: \.downloads)
                )
            case .settings:
                SettingsView(
                    store: store.scope(state: \.settings, action: \.settings)
                )
            }
        }
    }

    #Preview("Home tvOS") {
        HomeView_tvOS(
            store: Store(initialState: HomeFeature.State(config: PlaylistConfig(type: .xtream, serverURL: URL(string: "http://example.com") ?? URL(fileURLWithPath: "/"), username: "demo", password: "pwd"))) {
                HomeFeature()
            }
        )
    }
#endif
