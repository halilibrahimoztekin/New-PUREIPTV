import ComposableArchitecture
import SwiftUI

public struct DownloadsView: View {
    @Bindable var store: StoreOf<DownloadsFeature>

    public init(store: StoreOf<DownloadsFeature>) {
        self.store = store
    }

    public var body: some View {
        #if os(tvOS)
            DownloadsView_tvOS(store: store)
        #else
            DownloadsView_iOS(store: store)
        #endif
    }
}
