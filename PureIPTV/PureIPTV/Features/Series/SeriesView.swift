import ComposableArchitecture
import SwiftUI

public struct SeriesView: View {
    let store: StoreOf<SeriesFeature>
    let serverURL: String
    let username: String
    let password: String

    public init(store: StoreOf<SeriesFeature>, serverURL: String, username: String, password: String) {
        self.store = store
        self.serverURL = serverURL
        self.username = username
        self.password = password
    }

    public var body: some View {
        #if os(tvOS)
            SeriesView_tvOS(store: store, serverURL: serverURL, username: username, password: password)
        #else
            SeriesView_iOS(store: store, serverURL: serverURL, username: username, password: password)
        #endif
    }
}
