import ComposableArchitecture
import SwiftUI

public struct SearchView: View {
    let store: StoreOf<SearchFeature>
    let serverURL: String
    let username: String
    let password: String

    public init(store: StoreOf<SearchFeature>, serverURL: String, username: String, password: String) {
        self.store = store
        self.serverURL = serverURL
        self.username = username
        self.password = password
    }

    public var body: some View {
        #if os(tvOS)
            Color.black // Placeholder for tvOS
        #else
            SearchView_iOS(store: store, serverURL: serverURL, username: username, password: password)
        #endif
    }
}
