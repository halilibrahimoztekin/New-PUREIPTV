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
    @Environment(\.layoutDirection) private var layoutDirection
    #if os(tvOS)
        @State private var epgGuidePanelHeight: CGFloat = 0
    #endif
    #if os(iOS)
        @State private var pipController: PiPController?
    #endif

    private var videoZoomScale: CGFloat {
        store.videoAspectRatioMode == .zoom ? store.videoZoomScale : 1.0
    }

    private var videoScaleX: CGFloat {
        store.videoAspectRatioMode == .stretch ? 1.15 : videoZoomScale
    }

    private var videoScaleY: CGFloat {
        store.videoAspectRatioMode == .stretch ? 1.0 : videoZoomScale
    }

    private var liveVideoStallBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.yellow)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(AppStrings.Player.liveVideoStallTitle)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
                Text(AppStrings.Player.liveVideoStallMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: 520, alignment: .leading)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.yellow.opacity(0.42), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppStrings.Player.liveVideoStallTitle)
        .accessibilityValue(AppStrings.Player.liveVideoStallMessage)
        .accessibilityAddTraits(.isStaticText)
    }

    public var body: some View {
        ZStack {
            videoSurface

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

                if store.isLiveVideoStallDetected {
                    liveVideoStallBanner
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 120)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.2), value: store.vodSeekFailureRequestID)
            .animation(.easeInOut(duration: 0.2), value: store.firstPresentedFrameFeedbackRequestID)
            .animation(.easeInOut(duration: 0.2), value: store.isLiveVideoStallDetected)

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
            applyVLCAspectRatio(for: store.videoAspectRatioMode)
        }
        .onChange(of: store.videoAspectRatioMode) { _, mode in
            applyVLCAspectRatio(for: mode)
        }
        .onChange(of: store.playbackEngine) { _, _ in
            applyVLCAspectRatio(for: store.videoAspectRatioMode)
        }
        .onDisappear {
            if !store.isMinimized, !store.isPiPActive {
                store.send(.onDisappear)
            }
        }
        #if os(tvOS)
        .onPreferenceChange(PlayerEPGGuidePanelHeightPreferenceKey.self) { panelHeight in
            let panelHeight = max(0, panelHeight)
            guard abs(epgGuidePanelHeight - panelHeight) > 1 else { return }
            epgGuidePanelHeight = panelHeight
        }
        #endif
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

    @ViewBuilder
    private var videoSurface: some View {
        #if os(tvOS)
            GeometryReader { geometry in
                let isEPGMiniPlayer = store.isEPGVisible && store.item.isLive
                let width = isEPGMiniPlayer ? min(geometry.size.width * 0.34, 480) : geometry.size.width
                let height = isEPGMiniPlayer ? width * 9 / 16 : geometry.size.height
                let previewCorner = store.epgPreviewCorner
                let alignsToLeading = (previewCorner.isLeft && layoutDirection == .leftToRight)
                    || (!previewCorner.isLeft && layoutDirection == .rightToLeft)
                let horizontalAlignment: HorizontalAlignment = alignsToLeading ? .leading : .trailing
                let verticalAlignment: VerticalAlignment = previewCorner.isTop ? .top : .bottom
                let alignment = Alignment(horizontal: horizontalAlignment, vertical: verticalAlignment)

                ZStack(alignment: alignment) {
                    Color.black

                    videoContent
                        .frame(width: width, height: height)
                        .scaleEffect(x: videoScaleX, y: videoScaleY)
                        .clipShape(RoundedRectangle(
                            cornerRadius: isEPGMiniPlayer ? 16 : 0,
                            style: .continuous
                        ))
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: isEPGMiniPlayer ? 16 : 0,
                                style: .continuous
                            )
                            .stroke(Color.white.opacity(isEPGMiniPlayer ? 0.22 : 0), lineWidth: 1)
                        }
                        .overlay(alignment: .bottomLeading) {
                            if isEPGMiniPlayer {
                                Text(store.item.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.72), in: Capsule())
                                    .padding(10)
                            }
                        }
                        .padding(.vertical, isEPGMiniPlayer ? 56 : 0)
                        .padding(.horizontal, isEPGMiniPlayer ? 72 : 0)
                        .padding(
                            .bottom,
                            isEPGMiniPlayer && !previewCorner.isTop ? epgGuidePanelHeight + 24 : 0
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(isEPGMiniPlayer)
                .allowsHitTesting(!isEPGMiniPlayer)
                .focusable(false)
            }
            .background(Color.black.ignoresSafeArea())
            .ignoresSafeArea()
        #else
            fullScreenVideoSurface
        #endif
    }

    @ViewBuilder
    private var videoContent: some View {
        if store.playbackEngine == .avPlayer {
            AVPlayerSurfaceView(
                player: playerClient.avPlayer(),
                aspectRatioMode: store.videoAspectRatioMode,
                forceSDROutput: store.isForceSDROutputEnabled
            )
            .onTapGesture { store.send(.toggleControls) }
        } else {
            #if os(iOS)
                PiPVideoView(playerClient.vlcPlayer(), controller: $pipController)
                    .onTapGesture { store.send(.toggleControls) }
            #else
                VideoView(playerClient.vlcPlayer())
            #endif
        }
    }

    private var fullScreenVideoSurface: some View {
        videoContent
            .ignoresSafeArea()
            .scaleEffect(x: videoScaleX, y: videoScaleY)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: store.videoZoomScale)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.videoAspectRatioMode)
    }

    private func applyVLCAspectRatio(for mode: VideoAspectRatioMode) {
        guard store.playbackEngine != .avPlayer else { return }
        playerClient.vlcPlayer().aspectRatio = mode == .fill || mode == .zoom ? .fill : .default
    }
}
