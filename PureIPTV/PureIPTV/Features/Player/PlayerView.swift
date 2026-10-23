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
            switch newPhase {
            case .background:
                store.send(.appMovedToBackground)
                if store.backgroundPlaybackMode == .pip,
                   store.isAutoPiPEnabled,
                   pipController?.isPossible == true,
                   store.playerState == .playing
                {
                    store.send(.pipStarted)
                    _ = pipController?.start()
                }
            case .active:
                store.send(.appMovedToForeground)
            default:
                break
            }
        }
        .onChange(of: store.shouldTriggerPiP) { _, shouldTrigger in
            if shouldTrigger {
                store.send(.resetPiPTrigger)
                if store.isPiPActive {
                    pipController?.stop()
                } else if pipController?.isPossible == true {
                    store.send(.pipStarted)
                    _ = pipController?.start()
                }
            }
        }
        .task(id: ObjectIdentifier(pipController as AnyObject? ?? NSObject())) {
            // PiP event akışını dinle
            guard let controller = pipController else { return }
            for await event in controller.pipEvents {
                switch event {
                case .willStart:
                    store.send(.pipStarted)
                    store.send(.onPiPStatusChanged(isActive: true))
                case let .didStop(reason):
                    store.send(.onPiPStatusChanged(isActive: false))
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
        #elseif os(tvOS)
        .onChange(of: store.shouldTriggerPiP) { _, shouldTrigger in
            if shouldTrigger {
                store.send(.resetPiPTrigger)
                store.send(.minimizeTapped)
            }
        }
        #endif
    }
}
