#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - iOS Home View

    // Uses UITabBarController-style TabView with custom styled tab bar.
    // iPhone: Bottom tab bar | iPad: Handled by HomeView+iPad.swift

    public struct HomeView_iOS: View {
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
                    tabContent(for: tab)
                        .tabItem {
                            Label(tab.rawValue, systemImage: store.selectedTab == tab ? tab.selectedIcon : tab.icon)
                        }
                        .tag(tab)
                }
            }
            .tint(Color(hex: "#0A84FF"))
            .onAppear {
                // Style the tab bar for glassmorphism
                let appearance = UITabBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
                appearance.backgroundColor = UIColor(Color.black.opacity(0.3))

                // Separator line
                let separatorColor = UIColor(Color.white.opacity(0.08))
                appearance.shadowColor = separatorColor

                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }

        @ViewBuilder
        private func tabContent(for tab: HomeTab) -> some View {
            switch tab {
            case .dashboard:
                DashboardView_iOS(
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
                SearchView(
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
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            }
        }
    }

    // MARK: - Tab Placeholder

    private struct TabPlaceholder: View {
        let tab: HomeTab
        let icon: String
        let color: Color

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(color)

                    Text(tab.rawValue)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "#E4E1E7"))

                    Text(AppStrings.Common.comingSoon)
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                }
            }
            .navigationTitle(tab.rawValue)
        }
    }

    #Preview("Home iOS") {
        HomeView_iOS(
            store: Store(initialState: HomeFeature.State(config: PlaylistConfig(type: .xtream, serverURL: URL(string: "http://example.com")!, username: "demo", password: "pwd"))) {
                HomeFeature()
            }
        )
    }
#endif
