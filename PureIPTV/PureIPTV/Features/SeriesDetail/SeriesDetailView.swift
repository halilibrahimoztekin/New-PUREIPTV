import ComposableArchitecture
import SwiftUI

public struct SeriesDetailView: View {
    let store: StoreOf<SeriesDetailFeature>
    @State private var hasDisappeared = false

    public init(store: StoreOf<SeriesDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        #if os(tvOS)
            SeriesDetailView_tvOS(store: store)
                .onAppear { hasDisappeared = false }
                .onDisappear {
                    guard !hasDisappeared else { return }
                    hasDisappeared = true
                    store.send(.viewDidDisappear)
                }
        #else
            SeriesDetailView_iOS(store: store)
                .onAppear { hasDisappeared = false }
                .onDisappear {
                    guard !hasDisappeared else { return }
                    hasDisappeared = true
                    store.send(.viewDidDisappear)
                }
        #endif
    }
}
