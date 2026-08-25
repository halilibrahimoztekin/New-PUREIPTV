import ComposableArchitecture
import SwiftUI

public struct SeriesDetailView: View {
    let store: StoreOf<SeriesDetailFeature>

    public init(store: StoreOf<SeriesDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        #if os(tvOS)
            Color.black // Placeholder for tvOS
        #else
            SeriesDetailView_iOS(store: store)
        #endif
    }
}
