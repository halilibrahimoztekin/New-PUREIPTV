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
}
