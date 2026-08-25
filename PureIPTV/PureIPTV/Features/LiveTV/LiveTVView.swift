import ComposableArchitecture
import SwiftUI

// MARK: - LiveTV Platform Router

public struct LiveTVView: View {
    let store: StoreOf<LiveTVFeature>
    let serverURL: String
    let username: String
    let password: String

    public init(store: StoreOf<LiveTVFeature>, serverURL: String, username: String, password: String) {
        self.store = store
        self.serverURL = serverURL
        self.username = username
        self.password = password
    }

    public var body: some View {
        #if os(tvOS)
            LiveTVView_tvOS(store: store, serverURL: serverURL, username: username, password: password)
        #else
            LiveTVView_iOS(store: store, serverURL: serverURL, username: username, password: password)
        #endif
    }
}
