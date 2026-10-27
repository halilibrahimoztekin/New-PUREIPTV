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
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
        @State private var pipController: PiPController?
    #endif

    public var body: some View {
        ZStack {
            if store.playbackEngine == .avPlayer {
                AVPlayerSurfaceView(player: playerClient.avPlayer())
                    .ignoresSafeArea()
                    .onTapGesture { store.send(.toggleControls) }
            } else {
                #if os(iOS)
                    PiPVideoView(playerClient.vlcPlayer(), controller: $pipController)
                        .ignoresSafeArea()
                        .scaleEffect(x: store.videoAspectRatioMode == .stretch ? 1.15 : store.videoZoomScale,
                                     y: store.videoAspectRatioMode == .stretch ? 1.0 : store.videoZoomScale)
                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: store.videoZoomScale)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.videoAspectRatioMode)
                        .onTapGesture { store.send(.toggleControls) }
                #else
                    VideoView(playerClient.vlcPlayer())
                        .ignoresSafeArea()
                        .scaleEffect(x: store.videoAspectRatioMode == .stretch ? 1.15 : store.videoZoomScale,
                                     y: store.videoAspectRatioMode == .stretch ? 1.0 : store.videoZoomScale)
                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: store.videoZoomScale)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.videoAspectRatioMode)
                #endif
            }

            // UI Overlay
            #if os(tvOS)
                PlayerView_tvOS(store: store)
            #else
                PlayerView_iOS(store: store, pipController: $pipController)
            #endif

            VStack(spacing: 8) {
                if store.vodSeekFailureRequestID != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.82), in: Capsule())
                        .accessibilityLabel(String(format: AppStrings.Common.error, locale: Locale.current, arguments: [""]))
                        .accessibilityAddTraits(.isStaticText)
                }

                if store.isHighFrameRateVOD,
                   store.firstPresentedFrameFeedbackRequestID != nil,
                   let sourceFrameRate = store.mediaInfo?.reportedFrameRate,
                   let firstFrameLatency = store.firstPresentedFrameLatencySeconds
                {
                    let frameRateText = sourceFrameRate.formatted(.number.precision(.fractionLength(0 ... 2)))
                    let latencyText = firstFrameLatency.formatted(.number.precision(.fractionLength(2)))
                    HStack(spacing: 7) {
                        Image(systemName: "film")
                        Text("\(frameRateText) fps")
                        Image(systemName: "clock")
                        Text("\(latencyText) s")
                    }
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.82), in: Capsule())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(AppStrings.Player.technicalDetails)
                    .accessibilityValue("\(frameRateText) fps · \(latencyText) s")
                    .accessibilityAddTraits(.isStaticText)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 120)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.2), value: store.vodSeekFailureRequestID)
            .animation(.easeInOut(duration: 0.2), value: store.firstPresentedFrameFeedbackRequestID)

            if let message = store.playbackEngineError {
                VStack {
                    Text(message)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.78), in: Capsule())
                        .padding(.top, 24)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
            }
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
        #if os(tvOS)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .background else { return }
            store.send(.closeTapped)
        }
        #endif
    }
}
