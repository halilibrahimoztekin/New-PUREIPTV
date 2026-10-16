import ComposableArchitecture
import SwiftUI

public struct SearchView: View {
    let store: StoreOf<SearchFeature>
    let config: PlaylistConfig

    public init(store: StoreOf<SearchFeature>, config: PlaylistConfig) {
        self.store = store
        self.config = config
    }

    public init(store: StoreOf<SearchFeature>, serverURL: String, username: String, password: String) {
        self.store = store
        if (username.isEmpty && password.isEmpty) || serverURL.lowercased().contains(".m3u") {
            config = PlaylistConfig(type: .m3u, m3uURL: URL(string: serverURL))
        } else {
            config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
        }
    }

    public var body: some View {
        #if os(tvOS)
            SearchView_tvOS(store: store, config: config)
        #else
            SearchView_iOS(store: store, config: config)
        #endif
    }
}
