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
                ForEach(store.visibleTabs, id: \.self) { tab in
                    RetainedLazyTabContent(isSelected: store.selectedTab == tab) {
                        tabContent(for: tab)
                    }
                    .tabItem {
                        Label(tab.rawValue, systemImage: store.selectedTab == tab ? tab.selectedIcon : tab.icon)
                    }
                    .tag(tab)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                // Style the tab bar for glassmorphism
                let appearance = UITabBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
                appearance.backgroundColor = UIColor(AppColors.surface.opacity(0.85))

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
                    config: store.config,
                    onSearch: { store.send(.delegate(.presentSearch)) }
                )
            case .liveTV:
                LiveTVView(
                    store: store.scope(state: \.liveTV, action: \.liveTV),
                    config: store.liveTVSourceConfig,
                    onSearch: { store.send(.delegate(.presentSearch)) }
                )
            case .movies:
                VODView(
                    store: store.scope(state: \.vod, action: \.vod),
                    config: store.moviesSourceConfig,
                    onSearch: { store.send(.delegate(.presentSearch)) }
                )
            case .series:
                SeriesView(
                    store: store.scope(state: \.series, action: \.series),
                    config: store.seriesSourceConfig,
                    onSearch: { store.send(.delegate(.presentSearch)) }
                )
            case .search:
                SearchView(
                    store: store.scope(state: \.search, action: \.search),
                    config: store.config
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

    /// Defers the cost of constructing each tab until the user first selects it,
    /// then retains its view state for subsequent tab switches.
    private struct RetainedLazyTabContent<Content: View>: View {
        let isSelected: Bool
        let content: () -> Content
        @State private var hasLoaded = false

        init(isSelected: Bool, @ViewBuilder content: @escaping () -> Content) {
            self.isSelected = isSelected
            self.content = content
        }

        var body: some View {
            Group {
                if hasLoaded || isSelected {
                    content()
                } else {
                    Color.clear
                }
            }
            .onAppear {
                if isSelected {
                    hasLoaded = true
                }
            }
            .onChange(of: isSelected) { _, selected in
                if selected {
                    hasLoaded = true
                }
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
                AppColors.oledBlack.ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(AppFonts.displayMedium.weight(.semibold))
                        .foregroundStyle(color)

                    Text(tab.rawValue)
                        .font(AppFonts.titleMedium)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(AppStrings.Common.comingSoon)
                        .font(AppFonts.bodyMedium)
                        .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.5))
                }
            }
            .navigationTitle(tab.rawValue)
        }
    }

    #Preview("Home iOS") {
        HomeView_iOS(
            store: Store(initialState: HomeFeature.State(config: PlaylistConfig(type: .xtream, serverURL: URL(string: "http://example.com") ?? URL(fileURLWithPath: "/"), username: "demo", password: "pwd"))) {
                HomeFeature()
            }
        )
    }
#endif
