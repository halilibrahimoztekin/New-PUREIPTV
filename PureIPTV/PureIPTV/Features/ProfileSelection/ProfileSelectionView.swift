import ComposableArchitecture
import SwiftUI

public struct ProfileSelectionView: View {
    @Bindable var store: StoreOf<ProfileSelectionFeature>

    public init(store: StoreOf<ProfileSelectionFeature>) {
        self.store = store
    }

    public var body: some View {
        #if os(tvOS)
            ProfileSelectionView_tvOS(store: store)
        #else
            ProfileSelectionView_iOS(store: store)
        #endif
    }
}
