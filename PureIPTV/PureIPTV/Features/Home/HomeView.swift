import ComposableArchitecture
import SwiftUI

// MARK: - Home Platform Router

// iPhone → HomeView_iOS (bottom tab bar)
// iPad   → HomeView_iPad (NavigationSplitView sidebar)
// tvOS   → HomeView_tvOS (top TabView)

public struct HomeView: View {
    let store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            #if os(tvOS)
                HomeView_tvOS(store: store)
            #else
                // Detect iPhone vs iPad at runtime
                if UIDevice.current.userInterfaceIdiom == .pad {
                    HomeView_iPad(store: store)
                } else {
                    HomeView_iOS(store: store)
                }
            #endif
        }
        .overlay(alignment: .topTrailing) {
            #if os(tvOS)
                let buttonSize: CGFloat = 56
                let iconSize: CGFloat = 22
                let topPadding: CGFloat = 20
                let trailingPadding: CGFloat = 56
            #else
                let buttonSize: CGFloat = 44
                let iconSize: CGFloat = 17
                let topPadding: CGFloat = 8
                let trailingPadding: CGFloat = 16
            #endif
            Button {
                #if os(iOS)
                    HapticManager.shared.trigger(.light)
                #endif
                store.send(.delegate(.presentSearch))
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(Color(hex: "#E4E1E7"))
                    .frame(width: buttonSize, height: buttonSize)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppStrings.Search.searchPlaceholder) // [VERIFY] Confirm localized wording identifies the global search action.
            .padding(.top, topPadding)
            .padding(.trailing, trailingPadding)
        }
    }
}
