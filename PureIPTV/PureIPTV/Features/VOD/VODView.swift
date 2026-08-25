import ComposableArchitecture
import SwiftUI

public struct VODView: View {
    let store: StoreOf<VODFeature>
    let serverURL: String
    let username: String
    let password: String

    public init(store: StoreOf<VODFeature>, serverURL: String, username: String, password: String) {
        self.store = store
        self.serverURL = serverURL
        self.username = username
        self.password = password
    }

    public var body: some View {
        #if os(tvOS)
            // VODView_tvOS(store: store, serverURL: serverURL, username: username, password: password)
            Color.black // Placeholder for tvOS
        #else
            VODView_iOS(store: store, serverURL: serverURL, username: username, password: password)
        #endif
    }
}
