import ComposableArchitecture
import SwiftUI

public struct VODView: View {
    let store: StoreOf<VODFeature>
    let config: PlaylistConfig

    public init(store: StoreOf<VODFeature>, config: PlaylistConfig) {
        self.store = store
        self.config = config
    }

    public init(store: StoreOf<VODFeature>, serverURL: String, username: String, password: String) {
        self.store = store
        config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
    }

    public var body: some View {
        #if os(tvOS)
            VODView_tvOS(store: store, config: config)
        #else
            VODView_iOS(store: store, config: config)
        #endif
    }
}
