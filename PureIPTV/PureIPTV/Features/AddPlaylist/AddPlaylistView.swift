import ComposableArchitecture
import SwiftUI

// MARK: - Platform Router

public struct AddPlaylistView: View {
    let store: StoreOf<AddPlaylistFeature>

    public init(store: StoreOf<AddPlaylistFeature>) {
        self.store = store
    }

    public var body: some View {
        #if os(tvOS)
            AddPlaylistView_tvOS(store: store)
        #else
            AddPlaylistView_iOS(store: store)
        #endif
    }
}
