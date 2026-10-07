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
                ForEach(HomeTab.allCases, id: \.self) { tab in
                    TVTabContentView(tab: tab, store: store)
                        .tabItem {
                            Label(tab.rawValue, systemImage: store.selectedTab == tab ? tab.selectedIcon : tab.icon)
                        }
                        .tag(tab)
                }
            }
            .tint(Color(hex: "#0A84FF"))
        }
    }

    // MARK: - TV Tab Content Placeholder

    private struct TVTabPlaceholder: View {
        let tab: HomeTab

        @FocusState private var isFocused: Bool

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: tab.selectedIcon)
                        .font(.system(size: 80, weight: .semibold))
                        .foregroundStyle(tabColor)
                        .scaleEffect(isFocused ? 1.08 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)

                    Text(tab.rawValue)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Color(hex: "#E4E1E7"))

                    Text(AppStrings.Common.comingSoon)
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                }
                .focusable()
                .focused($isFocused)
            }
        }

        private var tabColor: Color {
            switch tab {
            case .dashboard: Color(hex: "#FF9500")
            case .liveTV: Color(hex: "#FF453A")
            case .movies: Color(hex: "#BF5AF2")
            case .series: Color(hex: "#30D158")
            case .search: Color(hex: "#0A84FF")
            case .settings: Color(hex: "#C0C6D6")
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
                    serverURL: store.serverURL,
                    username: store.username,
                    password: store.password
                )
            case .liveTV:
                LiveTVView(
                    store: store.scope(state: \.liveTV, action: \.liveTV),
                    serverURL: store.serverURL,
                    username: store.username,
                    password: store.password
                )
            case .movies:
                VODView(
                    store: store.scope(state: \.vod, action: \.vod),
                    serverURL: store.serverURL,
                    username: store.username,
                    password: store.password
                )
            case .series:
                SeriesView(
                    store: store.scope(state: \.series, action: \.series),
                    serverURL: store.serverURL,
                    username: store.username,
                    password: store.password
                )
            case .search:
                SearchView_tvOS(
                    store: store.scope(state: \.search, action: \.search),
                    serverURL: store.serverURL,
                    username: store.username,
                    password: store.password
                )
            case .downloads:
                DownloadsView(
                    store: store.scope(state: \.downloads, action: \.downloads)
                )
            case .settings:
                TVTabPlaceholder(tab: tab)
            }
        }
    }

    #Preview("Home tvOS") {
        HomeView_tvOS(
            store: Store(initialState: HomeFeature.State(config: PlaylistConfig(type: .xtream, serverURL: URL(string: "http://example.com")!, username: "demo", password: "pwd"))) {
                HomeFeature()
            }
        )
    }
#endif
