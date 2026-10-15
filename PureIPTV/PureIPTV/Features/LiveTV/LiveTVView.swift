import ComposableArchitecture
import SwiftUI

// MARK: - LiveTV Platform Router

public struct LiveTVView: View {
    let store: StoreOf<LiveTVFeature>
    let config: PlaylistConfig

    public init(store: StoreOf<LiveTVFeature>, config: PlaylistConfig) {
        self.store = store
        self.config = config
    }

    public init(store: StoreOf<LiveTVFeature>, serverURL: String, username: String, password: String) {
        self.store = store
        config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
    }

    public var body: some View {
        #if os(tvOS)
            LiveTVView_tvOS(store: store, config: config)
        #else
            LiveTVView_iOS(store: store, config: config)
        #endif
    }
}
