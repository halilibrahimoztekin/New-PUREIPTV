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
        @Environment(\.scenePhase) private var scenePhase
    #endif

    public var body: some View {
        ZStack {
            #if os(iOS)
                PiPVideoView(playerClient.vlcPlayer(), controller: $pipController)
                    .ignoresSafeArea()
                    .scaleEffect(
                        x: store.videoAspectRatioMode == .stretch ? 1.15 : store.videoZoomScale,
                        y: store.videoAspectRatioMode == .stretch ? 1.0 : store.videoZoomScale
                    )
                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: store.videoZoomScale)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.videoAspectRatioMode)
                    .onTapGesture {
                        store.send(.toggleControls)
                    }
            #else
                VideoView(playerClient.vlcPlayer())
                    .ignoresSafeArea()
                    .scaleEffect(
                        x: store.videoAspectRatioMode == .stretch ? 1.15 : store.videoZoomScale,
                        y: store.videoAspectRatioMode == .stretch ? 1.0 : store.videoZoomScale
                    )
                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: store.videoZoomScale)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.videoAspectRatioMode)
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
        .onDisappear {
            if !store.isMinimized, !store.isPiPActive {
                store.send(.onDisappear)
            }
        }
        #if os(iOS)
        .onChange(of: scenePhase) { _, newPhase in
            // Uygulama arka plana geçince PiP otomatik başlat
            if newPhase == .background, pipController?.isPossible == true, store.playerState == .playing {
                store.send(.pipStarted)
                _ = pipController?.start()
            }
        }
        .task(id: ObjectIdentifier(pipController as AnyObject? ?? NSObject())) {
            // PiP event akışını dinle
            guard let controller = pipController else { return }
            for await event in controller.pipEvents {
                switch event {
                case .willStart:
                    store.send(.pipStarted)
                case let .didStop(reason):
                    // Kullanıcı "Geri Dön" tıkladıysa full-screen'e restore et
                    if reason == .restoreRequested {
                        store.send(.pipRestoreUI)
                    } else {
                        store.send(.pipStopped)
                    }
                default:
                    break
                }
            }
        }
        #endif
    }
}
