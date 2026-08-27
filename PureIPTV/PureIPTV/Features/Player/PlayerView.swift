import ComposableArchitecture
import FactoryKit
import SwiftUI
import SwiftVLC

public struct PlayerView: View {
    @Bindable var store: StoreOf<PlayerFeature>

    public init(store: StoreOf<PlayerFeature>) {
        self.store = store
    }

    @Injected(\.playerClient) private var playerClient
    #if os(iOS)
        @State private var pipController: PiPController?
    #endif

    public var body: some View {
        ZStack {
            #if os(iOS)
                PiPVideoView(playerClient.vlcPlayer(), controller: $pipController)
                    .ignoresSafeArea()
                    .onTapGesture {
                        store.send(.toggleControls)
                    }
            #else
                VideoView(playerClient.vlcPlayer())
                    .ignoresSafeArea()
                    .onTapGesture {
                        store.send(.toggleControls)
                    }
            #endif

            // UI Overlay
            #if os(tvOS)
                PlayerView_tvOS(store: store)
            #else
                PlayerView_iOS(store: store, pipController: $pipController)
            #endif
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            store.send(.onAppear)
        }
    }
}
