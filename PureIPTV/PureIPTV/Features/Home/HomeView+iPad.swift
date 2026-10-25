#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - iPad Home View

    // Uses NavigationSplitView for a permanent sidebar on iPad.
    // macOS/visionOS also benefits from this layout via Designed for iPad compatibility.

    public struct HomeView_iPad: View {
        @Bindable var store: StoreOf<HomeFeature>

        public init(store: StoreOf<HomeFeature>) {
            self.store = store
        }

        public var body: some View {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 240)
                ZStack {
                    detailView
                        .id(store.selectedTab)
                        .transition(.opacity.combined(with: .scale(scale: 0.99)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.25), value: store.selectedTab)
            .toolbar(.hidden, for: .navigationBar)
        }

        // MARK: – Sidebar

        private var sidebar: some View {
            ZStack {
                // Dark sidebar background
                Color(hex: "#0C0C10").ignoresSafeArea()

                VStack(spacing: 0) {
                    // App brand header
                    sidebarHeader
                        .padding(.top, 24)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    // Nav items
                    ForEach(store.visibleTabs, id: \.self) { tab in
                        SidebarNavItem(
                            tab: tab,
                            isSelected: store.selectedTab == tab
                        ) {
                            store.send(.tabSelected(tab), animation: .easeInOut(duration: 0.25))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                    }

                    Spacer()

                    // Server info footer
                    sidebarFooter
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }

        private var sidebarHeader: some View {
            HStack(spacing: 10) {
                PureMaterialLogo(size: 36, showGlow: false)

                Text(AppStrings.Common.appName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#E4E1E7"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var sidebarFooter: some View {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "#30D158"))
                    .frame(width: 7, height: 7)

                Text(store.serverURL)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        // MARK: – Detail

        @ViewBuilder
        private var detailView: some View {
            switch store.selectedTab {
            case .dashboard:
                DashboardView_iOS(
                    store: store.scope(state: \.dashboard, action: \.dashboard),
                    config: store.config
                )
            case .liveTV:
                LiveTVView(
                    store: store.scope(state: \.liveTV, action: \.liveTV),
                    config: store.config
                )
            case .movies:
                VODView(
                    store: store.scope(state: \.vod, action: \.vod),
                    config: store.config
                )
            case .series:
                SeriesView(
                    store: store.scope(state: \.series, action: \.series),
                    config: store.config
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
                SettingsView(
                    store: store.scope(state: \.settings, action: \.settings)
                )
            }
        }
    }

    // MARK: - Sidebar Nav Item

    private struct SidebarNavItem: View {
        let tab: HomeTab
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color(hex: "#0A84FF") : Color(hex: "#C0C6D6").opacity(0.6))
                        .frame(width: 24)

                    Text(tab.rawValue)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color(hex: "#E4E1E7") : Color(hex: "#C0C6D6").opacity(0.7))

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color(hex: "#0A84FF").opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color(hex: "#0A84FF").opacity(0.2) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }

    #Preview("Home iPad") {
        HomeView_iPad(
            store: Store(initialState: HomeFeature.State(config: PlaylistConfig(type: .xtream, serverURL: URL(string: "http://example.com") ?? URL(fileURLWithPath: "/"), username: "demo", password: "pwd"))) {
                HomeFeature()
            }
        )
    }
#endif
