import ComposableArchitecture
import Factory
import SwiftUI
import SwiftVLC

public struct PlayerView: View {
    @Bindable var store: StoreOf<PlayerFeature>

    public init(store: StoreOf<PlayerFeature>) {
        self.store = store
    }

    @Injected(\.playerClient) private var playerClient

    public var body: some View {
        ZStack {
            VideoView(playerClient.vlcPlayer())
                .ignoresSafeArea()
                .onTapGesture {
                    store.send(.toggleControls)
                }

            // UI Overlay
            #if os(tvOS)
                PlayerView_tvOS(store: store)
            #else
                PlayerView_iOS(store: store)
            #endif
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            store.send(.onAppear)
        }
    }
}
