import ComposableArchitecture
import SwiftUI

public struct VODView: View {
    let store: StoreOf<VODFeature>
    let config: PlaylistConfig
    let onSearch: (() -> Void)?

    public init(store: StoreOf<VODFeature>, config: PlaylistConfig, onSearch: (() -> Void)? = nil) {
        self.store = store
        self.config = config
        self.onSearch = onSearch
    }

    public init(store: StoreOf<VODFeature>, serverURL: String, username: String, password: String, onSearch: (() -> Void)? = nil) {
        self.store = store
        self.onSearch = onSearch
        if (username.isEmpty && password.isEmpty) || serverURL.lowercased().contains(".m3u") {
            config = PlaylistConfig(type: .m3u, m3uURL: URL(string: serverURL))
        } else {
            config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
        }
    }

    public var body: some View {
        #if os(tvOS)
            VODView_tvOS(store: store, config: config)
        #else
            VODView_iOS(store: store, config: config, onSearch: onSearch)
        #endif
    }
}
