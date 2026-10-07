import ComposableArchitecture
import SwiftUI

public struct SeriesDetailView: View {
    let store: StoreOf<SeriesDetailFeature>

    public init(store: StoreOf<SeriesDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        #if os(tvOS)
            SeriesDetailView_tvOS(store: store)
                .onDisappear { store.send(.viewDidDisappear) }
        #else
            SeriesDetailView_iOS(store: store)
                .onDisappear { store.send(.viewDidDisappear) }
        #endif
    }
}
