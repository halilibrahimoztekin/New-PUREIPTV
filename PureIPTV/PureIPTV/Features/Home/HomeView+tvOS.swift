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
                    TVTabContent(tab: tab)
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

    private struct TVTabContent: View {
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

                    Text("Yakında geliyor…")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                }
                .focusable()
                .focused($isFocused)
            }
        }

        private var tabColor: Color {
            switch tab {
            case .dashboard: return Color(hex: "#FF9500")
            case .liveTV: return Color(hex: "#FF453A")
            case .movies: return Color(hex: "#BF5AF2")
            case .series: return Color(hex: "#30D158")
            case .search: return Color(hex: "#0A84FF")
            case .settings: return Color(hex: "#C0C6D6")
            }
        }
    }

    #Preview("Home tvOS") {
        HomeView_tvOS(
            store: Store(initialState: HomeFeature.State(serverURL: "http://example.com", username: "demo", password: "demo")) {
                HomeFeature()
            }
        )
    }
#endif
