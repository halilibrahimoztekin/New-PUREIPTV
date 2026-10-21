#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI
    import SwiftVLC

    public struct PlayerView_iOS: View {
        @Bindable var store: StoreOf<PlayerFeature>
        @Binding var pipController: PiPController?
        @State private var isDraggingSlider: Bool = false
        @State private var sliderDragValue: Double = 0.0
        @Environment(\.scenePhase) private var scenePhase

        // Smart Double-Tap Seek State
        @State private var smartSeekDirection: SmartSeekDirection? = nil
        @State private var isLiveWarningVisible: Bool = false
        @State private var seekDismissWorkItem: DispatchWorkItem? = nil
        @State private var singleTapWorkItem: DispatchWorkItem? = nil
        @State private var cumulativeSeekSeconds: Int = 0
        @State private var activeSeekSide: ActiveSeekSide? = nil

        // Vertical Drag OSD State (Madde #12)
        @State private var activeVerticalOSD: VerticalOSDType? = nil
        @State private var dragGestureMode: DragGestureMode? = nil
        @State private var dragInitialBrightness: Double = 1.0
        @State private var dragInitialVolume: Double = 100.0
        @State private var lastHapticThreshold: Int = -1
        @State private var osdDismissWorkItem: DispatchWorkItem? = nil

        // Horizontal Scrubbing State (Madde #13)
        @State private var horizontalScrubState: HorizontalScrubState? = nil
        @State private var dragInitialScrubPosition: Double = 0.0
        @State private var lastScrubHapticInterval: Int = -1

        // Aspect Ratio & Zoom State (Madde #14)
        @State private var pinchStartScale: CGFloat? = nil
        @State private var aspectDismissWorkItem: DispatchWorkItem? = nil
        @State private var isShowingSpeedTest: Bool = false

        // Channel Zapping State (Madde #16)
        @State private var interactiveZappingDirection: ZappingDirection? = nil
        @State private var hasTriggeredZappingThresholdHaptic: Bool = false

        private enum ActiveSeekSide {
            case left
            case right
        }

        private enum DragGestureMode {
            case brightness
            case volume
            case horizontal
            case miniEPG
            case channelZapping
            case swipeToMiniPlayer
        }

        public var body: some View {
            ZStack {
                // Gesture Areas
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    handleTap(at: value.location, in: geo.size)
                                }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 15)
                                .onChanged { value in
                                    singleTapWorkItem?.cancel()
                                    store.send(.userInteracted)
                                    handleDragChanged(value: value, geo: geo)
                                }
                                .onEnded { value in
                                    handleDragEnded(value: value)
                                }
                        )
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { scale in
                                    if store.isScreenLocked {
                                        store.send(.showLockPill)
                                        return
                                    }
                                    singleTapWorkItem?.cancel()
                                    store.send(.userInteracted)
                                    if pinchStartScale == nil {
                                        pinchStartScale = store.videoZoomScale
                                    }
                                    let base = pinchStartScale ?? 1.0
                                    let targetScale = max(1.0, min(3.0, base * scale))
                                    store.send(.setVideoZoomScale(targetScale))
                                    triggerAspectFeedback()
                                }
                                .onEnded { _ in
                                    guard !store.isScreenLocked else { return }
                                    pinchStartScale = nil
                                    if store.videoZoomScale <= 1.05 {
                                        store.send(.setVideoAspectRatioMode(.fit))
                                        HapticManager.shared.trigger(.light)
                                    } else if store.videoZoomScale >= 2.95 {
                                        HapticManager.shared.trigger(.medium)
                                    }
                                    triggerAspectFeedback()
                                }
                        )
                }

                // Smart Double-Tap Seek Ripple & Chevrons Overlay
                SmartDoubleTapSeekOverlay(
                    direction: smartSeekDirection,
                    isLiveWarning: isLiveWarningVisible
                )

                // Vertical Drag Volume & Brightness OSD Overlay (Madde #12)
                if let osd = activeVerticalOSD {
                    HStack {
                        if !osd.isVolume {
                            VerticalControlOSDView(osdType: osd)
                                .padding(.leading, 36)
                            Spacer()
                        } else {
                            Spacer()
                            VerticalControlOSDView(osdType: osd)
                                .padding(.trailing, 36)
                        }
                    }
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: activeVerticalOSD)
                }

                // Horizontal Pan Scrubbing HUD Overlay (Madde #13)
                if let scrub = horizontalScrubState {
                    HorizontalScrubHUDView(state: scrub)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: scrub)
                }

                // Aspect Ratio & Pinch-to-Zoom HUD Overlay (Madde #14)
                if store.isAspectFeedbackVisible {
                    AspectScaleHUDView(
                        mode: store.videoAspectRatioMode,
                        scale: store.videoZoomScale
                    )
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: store.isAspectFeedbackVisible)
                }

                // OLED & Dark Room Dimming Overlay
                OLEDDimmerOverlay(
                    dimLevel: store.oledDimLevel,
                    isDeepDimmed: store.isDeepDimmed
                )

                if store.isDeepDimmed {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            store.send(.userInteracted)
                        }
                }

                if store.isControlsVisible {
                    VStack {
                        // Top Bar
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center) {
                                // Primary Window Controls (Close & Minimize)
                                HStack(spacing: 10) {
                                    Button(action: {
                                        cancelAllPendingWorkItems()
                                        HapticManager.shared.trigger(.light)
                                        store.send(.closeTapped)
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 40, height: 40)
                                            .background(.ultraThinMaterial, in: Circle())
                                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                    }

                                    Button(action: {
                                        guard !store.isMinimized else { return }
                                        cancelAllPendingWorkItems()
                                        HapticManager.shared.trigger(.medium)
                                        store.send(.minimizeTapped)
                                    }) {
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 40, height: 40)
                                            .background(.ultraThinMaterial, in: Circle())
                                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                    }
                                    .disabled(store.isMinimized)
                                }

                                Spacer()

                                // Primary Quick Actions + Consolidated Settings Menu
                                HStack(spacing: 10) {
                                    // Live Channels Drawer Button (Zapping)
                                    if store.playlist != nil {
                                        Button(action: {
                                            HapticManager.shared.trigger(.light)
                                            store.send(.toggleChannelList, animation: .spring(response: 0.3, dampingFraction: 0.7))
                                        }) {
                                            Image(systemName: "list.dash")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)
                                                .frame(width: 38, height: 38)
                                                .background(store.isChannelListVisible ? AnyShapeStyle(Color.accentColor.opacity(0.85)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                                                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                        }
                                    }

                                    // EPG Quick Button (if program data is present)
                                    if let _ = store.item.epgChannelID, !store.epgListings.isEmpty {
                                        Button(action: {
                                            HapticManager.shared.trigger(.light)
                                            store.send(.toggleEPG, animation: .spring(response: 0.3, dampingFraction: 0.7))
                                        }) {
                                            Image(systemName: "list.bullet.rectangle")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)
                                                .frame(width: 38, height: 38)
                                                .background(store.isEPGVisible ? AnyShapeStyle(Color.accentColor.opacity(0.85)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                                                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                        }
                                    }

                                    // PiP Button
                                    if pipController?.isPossible == true {
                                        Button(action: {
                                            HapticManager.shared.trigger(.light)
                                            if store.isPiPActive {
                                                pipController?.stop()
                                            } else {
                                                _ = pipController?.start()
                                            }
                                        }) {
                                            Image(systemName: store.isPiPActive ? "pip.exit" : "pip.enter")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)
                                                .frame(width: 38, height: 38)
                                                .background(store.isPiPActive ? AnyShapeStyle(Color.accentColor.opacity(0.85)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                                                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                        }
                                    }

                                    // Screen Lock Button (Prevent accidental touches)
                                    Button(action: {
                                        HapticManager.shared.trigger(.medium)
                                        store.send(.toggleScreenLock)
                                    }) {
                                        Image(systemName: store.isScreenLocked ? "lock.fill" : "lock.open.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 38, height: 38)
                                            .background(store.isScreenLocked ? AnyShapeStyle(Color.accentColor.opacity(0.9)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                    }

                                    // Consolidated Player Settings Menu (Zero Friction - Don't Make Me Think)
                                    Menu {
                                        // 1. Tracks (Audio & Subtitles)
                                        Button {
                                            HapticManager.shared.trigger(.light)
                                            store.send(.toggleTracksMenu, animation: .spring(response: 0.3, dampingFraction: 0.7))
                                        } label: {
                                            Label(AppStrings.Player.tracks, systemImage: "captions.bubble")
                                        }

                                        // 2. Playback Speed (VOD & Series)
                                        if !store.item.isLive {
                                            Menu {
                                                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                                                    Button {
                                                        HapticManager.shared.trigger(.light)
                                                        store.send(.setPlaybackRate(Float(speed)))
                                                    } label: {
                                                        HStack {
                                                            Text(speed == 1.0 ? AppStrings.Player.normalSpeed : String(format: "%.2fx", speed))
                                                            if abs(Double(store.playbackRate) - speed) < 0.01 {
                                                                Image(systemName: "checkmark")
                                                            }
                                                        }
                                                    }
                                                }
                                            } label: {
                                                Label("\(AppStrings.Player.playbackSpeed) (\(String(format: "%.2gx", store.playbackRate)))", systemImage: "gauge.with.dots.needle.50percent")
                                            }
                                        }

                                        // 3. Aspect Ratio / Zoom Mode
                                        Menu {
                                            ForEach(VideoAspectRatioMode.allCases, id: \.self) { mode in
                                                Button {
                                                    HapticManager.shared.trigger(.light)
                                                    store.send(.setVideoAspectRatioMode(mode))
                                                    triggerAspectFeedback()
                                                } label: {
                                                    HStack {
                                                        Text(mode.title)
                                                        if store.videoAspectRatioMode == mode {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                        } label: {
                                            Label(store.videoAspectRatioMode.title, systemImage: store.videoAspectRatioMode.systemIcon)
                                        }

                                        // 4. Sleep Timer
                                        Menu {
                                            Button(AppStrings.Player.sleepTimerDisabled) {
                                                store.send(.setSleepTimer(nil))
                                            }
                                            ForEach([15, 30, 45, 60, 90], id: \.self) { mins in
                                                Button("\(mins) \(AppStrings.Common.minAbbr)") {
                                                    store.send(.setSleepTimer(mins))
                                                }
                                            }
                                        } label: {
                                            Label(store.sleepTimerSeconds != nil ? "\(store.sleepTimerSeconds! / 60) \(AppStrings.Common.minAbbr)" : AppStrings.Player.sleepTimer, systemImage: "moon.stars")
                                        }

                                        // 5. External Player Launcher
                                        Menu {
                                            ForEach(ExternalPlayer.allCases) { player in
                                                Button {
                                                    store.send(.openInExternalPlayer(player))
                                                } label: {
                                                    Label(player.rawValue, systemImage: player.iconName)
                                                }
                                            }
                                        } label: {
                                            Label(AppStrings.Player.openInExternalPlayer, systemImage: "arrow.up.right.video")
                                        }

                                        // 6. Recent Channels Quick Dock
                                        if store.item.isLive {
                                            Button {
                                                HapticManager.shared.trigger(.light)
                                                store.send(.toggleRecentChannelsHUD, animation: .spring(response: 0.35, dampingFraction: 0.8))
                                            } label: {
                                                Label(AppStrings.LiveTV.recentChannels, systemImage: "clock.arrow.circlepath")
                                            }
                                        }

                                        // 7. Lip-Sync & Audio Delay Fine Adjustment
                                        Button {
                                            HapticManager.shared.trigger(.light)
                                            store.send(.toggleAudioSyncHUD, animation: .spring(response: 0.35, dampingFraction: 0.8))
                                        } label: {
                                            Label(AppStrings.Player.lipSyncAdjustment, systemImage: "slider.horizontal.2.square")
                                        }

                                        // 8. Technical Diagnostics (Nerd Stats)
                                        Button {
                                            HapticManager.shared.trigger(.light)
                                            store.send(.toggleInfo, animation: .spring(response: 0.3, dampingFraction: 0.7))
                                        } label: {
                                            Label(store.isInfoVisible ? AppStrings.Player.hideTechnicalDetails : AppStrings.Player.technicalDetails, systemImage: "info.circle")
                                        }

                                        // 8. SharePlay
                                        Button {
                                            HapticManager.shared.trigger(.light)
                                            store.send(.sharePlayTapped)
                                        } label: {
                                            Label("SharePlay", systemImage: "shareplay")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 38, height: 38)
                                            .background(.ultraThinMaterial, in: Circle())
                                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                                    }
                                }
                            }

                            Text(store.item.title)
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .truncationMode(.tail)
                                .padding(.leading, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()

                        // Overlays (Info / Tracks)
                        ZStack(alignment: .topTrailing) {
                            if store.isInfoVisible {
                                HStack {
                                    Spacer()
                                    NerdStatsHUDView(
                                        item: store.item,
                                        mediaInfo: store.mediaInfo,
                                        playerState: store.playerState,
                                        audioDelay: store.audioDelay,
                                        subtitleDelay: store.subtitleDelay,
                                        playbackRate: store.playbackRate,
                                        aspectRatioMode: store.videoAspectRatioMode,
                                        selectedAudioTrack: store.selectedAudioTrack,
                                        selectedSubtitleTrack: store.selectedSubtitleTrack,
                                        currentAudioRoute: store.currentAudioRoute,
                                        playerStats: store.playerStats,
                                        onClose: {
                                            store.send(.toggleInfo, animation: .spring(response: 0.3, dampingFraction: 0.7))
                                        }
                                    )
                                    .padding(.trailing, 16)
                                }
                                .transition(.scale(scale: 0.92).combined(with: .opacity))
                            }

                            if store.isTracksMenuVisible {
                                tracksMenuOverlay
                            }
                        }

                        Spacer()

                        // Center Controls
                        HStack(spacing: 28) {
                            // Restart Button (Baştan Başlat)
                            if store.totalTime > .zero || store.position > 0 || !store.item.isLive {
                                Button(action: {
                                    HapticManager.shared.trigger(.medium)
                                    store.send(.restartPlayback)
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(14)
                                        .background(.ultraThinMaterial, in: Circle())
                                }
                            }

                            // Jump Backward
                            Button(action: { HapticManager.shared.trigger(.light); store.send(.jumpBackward) }) {
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(.ultraThinMaterial, in: Circle())
                            }

                            // Play/Pause
                            Button(action: {
                                if store.playerState == .playing {
                                    store.send(.pause)
                                } else {
                                    store.send(.play)
                                }
                            }) {
                                Image(systemName: store.playerState == .playing ? "pause.fill" : "play.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                                    .padding(22)
                                    .background(.ultraThinMaterial, in: Circle())
                            }

                            // Jump Forward
                            Button(action: { HapticManager.shared.trigger(.light); store.send(.jumpForward) }) {
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }

                        Spacer()

                        // Bottom Bar (Timeline or Live Controls)
                        VStack {
                            // Timeline (only show if total time is valid, meaning it's not a live stream)
                            if store.totalTime > .zero || !store.item.isLive {
                                HStack(spacing: 12) {
                                    // Calculate the display time based on dragging status
                                    let currentDisplayPosition = isDraggingSlider ? sliderDragValue : store.position
                                    let currentDisplayDuration = isDraggingSlider
                                        ? Duration.seconds(Double(store.totalTime.components.seconds) * currentDisplayPosition)
                                        : store.currentTime

                                    Text(formatDuration(currentDisplayDuration))
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.white)

                                    Slider(
                                        value: Binding(
                                            get: { currentDisplayPosition },
                                            set: { newValue in
                                                sliderDragValue = newValue
                                            }
                                        ),
                                        in: 0 ... 1,
                                        onEditingChanged: { editing in
                                            Task { @MainActor in
                                                isDraggingSlider = editing
                                                if !editing {
                                                    store.send(.seek(sliderDragValue))
                                                }
                                            }
                                        }
                                    )
                                    .tint(.accentColor)

                                    Text(formatDuration(store.totalTime))
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal)
                            } else if store.item.isLive {
                                // Live TV Quick Zapping & Recall Bar
                                HStack {
                                    if let prev = store.previousChannel {
                                        Button(action: {
                                            HapticManager.shared.trigger(.medium)
                                            store.send(.recallLastChannel)
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                                    .font(.title3)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text(AppStrings.Player.recallLastChannel)
                                                        .font(.caption2)
                                                        .foregroundColor(.white.opacity(0.8))
                                                    Text(prev.title)
                                                        .font(.subheadline.bold())
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(.ultraThinMaterial, in: Capsule())
                                        }
                                    }

                                    Spacer()

                                    if store.playlist != nil {
                                        HStack(spacing: 12) {
                                            // Category Jump (Madde #97)
                                            Button(action: {
                                                HapticManager.shared.trigger(.light)
                                                store.send(.jumpToPreviousCategory)
                                            }) {
                                                Image(systemName: "chevron.left.2")
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.white)
                                                    .padding(10)
                                                    .background(.ultraThinMaterial, in: Circle())
                                            }

                                            Button(action: {
                                                HapticManager.shared.trigger(.light)
                                                store.send(.previousChannel)
                                            }) {
                                                Image(systemName: "chevron.up")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .padding(10)
                                                    .background(.ultraThinMaterial, in: Circle())
                                            }

                                            Button(action: {
                                                HapticManager.shared.trigger(.light)
                                                store.send(.nextChannel)
                                            }) {
                                                Image(systemName: "chevron.down")
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .padding(10)
                                                    .background(.ultraThinMaterial, in: Circle())
                                            }

                                            // Recent Channels Quick Dock Button
                                            Button(action: {
                                                HapticManager.shared.trigger(.light)
                                                store.send(.toggleRecentChannelsHUD, animation: .spring(response: 0.35, dampingFraction: 0.8))
                                            }) {
                                                Image(systemName: "clock.arrow.circlepath")
                                                    .font(.headline)
                                                    .foregroundColor(store.isRecentChannelsHUDVisible ? Color(hex: "#0A84FF") : .white)
                                                    .padding(10)
                                                    .background(.ultraThinMaterial, in: Circle())
                                            }

                                            // Category Jump (Madde #97)
                                            Button(action: {
                                                HapticManager.shared.trigger(.light)
                                                store.send(.jumpToNextCategory)
                                            }) {
                                                Image(systemName: "chevron.right.2")
                                                    .font(.subheadline.bold())
                                                    .foregroundColor(.white)
                                                    .padding(10)
                                                    .background(.ultraThinMaterial, in: Circle())
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 24)
                        .padding(.top, 8)
                    }
                    .background(
                        Color.black.opacity(0.4)
                            .onTapGesture {
                                store.send(.toggleControls, animation: .spring(response: 0.3, dampingFraction: 0.7))
                            }
                    )
                    .opacity(store.isDeepDimmed ? 0.35 : 1.0)
                    .animation(.easeInOut(duration: 0.35), value: store.isDeepDimmed)
                    .transition(.opacity)
                }

                // Global Buffering Indicator (visible whether controls are active or hidden)
                if store.playerState == .buffering || store.playerState == .opening, store.errorMessage == nil, !store.isReconnecting {
                    PureLoadingView(size: .medium)
                        .padding(20)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: Color(hex: "#00D2FF").opacity(0.25), radius: 16)
                }

                // Auto-Reconnecting Glass HUD Pill (Subtle, non-blocking notification pill)
                if store.isReconnecting {
                    HStack(spacing: 12) {
                        PureLoadingView(size: .small)
                        Text(AppStrings.Player.reconnecting(store.retryCount, max: store.maxReconnectAttempts))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 20)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .zIndex(99)
                }

                // Global Error Overlay with Diagnostic Support (Madde #89)
                if let error = store.errorMessage, !store.isReconnecting {
                    PlayerFriendlyErrorView(
                        errorMessage: error,
                        onRetry: {
                            HapticManager.shared.trigger(.medium)
                            store.send(.retryPlayback)
                        },
                        onOpenSpeedTest: {
                            isShowingSpeedTest = true
                        },
                        onDismiss: {
                            store.send(.closeTapped)
                        }
                    )
                    .padding(24)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
                }

                // Gesture Feedback Overlay
                if let feedback = store.gestureFeedback {
                    Text(feedback)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.gestureFeedback)
                }

                // Channel Zapping HUD Overlay (Madde #16)
                if store.isZappingHUDVisible, let zappingItem = store.zappingHUDItem {
                    let direction = store.zappingHUDDirection ?? interactiveZappingDirection ?? .next
                    VStack {
                        ChannelZappingHUDView(
                            item: zappingItem,
                            direction: direction,
                            currentIndex: store.currentChannelIndex,
                            totalChannels: store.playlist?.count,
                            isCommitted: store.item.id == zappingItem.id
                        )
                        .padding(.top, 36)
                        Spacer()
                    }
                    .transition(.move(edge: direction == .next ? .top : .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isZappingHUDVisible)
                    .zIndex(85)
                }

                // Mini EPG Overlay (Madde #15: Swipe Down / Up for Mini EPG)
                if store.isEPGVisible {
                    ZStack(alignment: .bottom) {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture {
                                HapticManager.shared.trigger(.light)
                                store.send(.toggleEPG, animation: .spring(response: 0.35, dampingFraction: 0.75))
                            }

                        PlayerEPGTimelineView(
                            programs: store.epgListings,
                            currentPosition: store.position,
                            hasArchive: store.item.tvArchive == 1,
                            onClose: {
                                HapticManager.shared.trigger(.light)
                                store.send(.toggleEPG, animation: .spring(response: 0.35, dampingFraction: 0.75))
                            },
                            onSelect: { program in
                                store.send(.playArchive(program))
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .transition(.opacity)
                    .zIndex(90)
                }

                // Channel Info OSD Card (Madde #95)
                if store.isChannelOSDVisible, store.item.isLive, !store.isEPGVisible, !store.isRecentChannelsHUDVisible, !store.isControlsVisible {
                    VStack {
                        Spacer()
                        ChannelInfoOSDView(
                            item: store.item,
                            channelIndex: store.currentChannelIndex,
                            totalChannels: store.playlist?.count,
                            currentProgram: store.currentEPGProgram,
                            nextProgram: store.nextEPGProgram
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isChannelOSDVisible)
                    .zIndex(80)
                }

                // Recent Channels Carousel HUD (Quick-Zap Dock)
                if store.isRecentChannelsHUDVisible {
                    VStack {
                        Spacer()
                        RecentChannelsHUDView(store: store) {
                            store.send(.setRecentChannelsHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isRecentChannelsHUDVisible)
                    .zIndex(98)
                }

                // Lip-Sync & Subtitle Sync HUD
                if store.isAudioSyncHUDVisible {
                    VStack {
                        Spacer()
                        AudioSyncHUDView(store: store) {
                            store.send(.setAudioSyncHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isAudioSyncHUDVisible)
                    .zIndex(99)
                }

                // Edge-Swipe Channel Sidebar Drawer
                if store.isChannelListVisible {
                    PlayerSidebarDrawer(store: store) {
                        store.send(.toggleChannelList, animation: .spring(response: 0.32, dampingFraction: 0.8))
                    }
                    .zIndex(100)
                }

                // Touch / Screen Lock Pill Overlay (Madde #19)
                TouchLockOverlayView(
                    isLocked: store.isScreenLocked,
                    isPillVisible: store.isLockPillVisible,
                    onUnlock: {
                        store.send(.toggleScreenLock)
                    }
                )
                .zIndex(105)

                // Audio Route HUD Feedback (Madde #20)
                if store.isAudioRouteHUDVisible {
                    VStack {
                        AudioRouteHUDView(
                            routeInfo: store.currentAudioRoute,
                            isPlaying: store.playerState == .playing
                        )
                        .padding(.top, 40)

                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isAudioRouteHUDVisible)
                    .zIndex(98)
                }

                // Track Selection HUD Overlay (Madde #34)
                if store.isTrackHUDVisible, let message = store.trackHUDMessage {
                    VStack {
                        TrackHUDView(
                            message: message,
                            iconName: store.trackHUDIcon ?? "waveform.circle.fill"
                        )
                        .padding(.top, 40)

                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isTrackHUDVisible)
                    .zIndex(99)
                }

                // Up Next Episode Countdown Overlay (Madde #42 / #48)
                if store.isUpNextVisible, let nextItem = store.nextEpisodeItem {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            UpNextCountdownOverlayView(
                                item: nextItem,
                                countdownSeconds: store.upNextCountdownSeconds,
                                totalSeconds: store.upNextInitialSeconds,
                                onPlayNow: {
                                    store.send(.playNextEpisode)
                                },
                                onDismiss: {
                                    store.send(.dismissUpNext)
                                }
                            )
                            .padding(.trailing, 24)
                            .padding(.bottom, 28)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isUpNextVisible)
                    .zIndex(96)
                }

                // MARK: - Keyboard Shortcuts (Madde #68: iPad Magic Keyboard)

                Group {
                    Button("") { store.send(store.playerState == .playing ? .pause : .play) }
                        .keyboardShortcut(.space, modifiers: [])
                    Button("") { store.send(.toggleAspectRatioMode) }
                        .keyboardShortcut("f", modifiers: [])
                    Button("") { store.send(.jumpBackward) }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                    Button("") { store.send(.jumpForward) }
                        .keyboardShortcut(.rightArrow, modifiers: [])
                    Button("") { store.send(.previousChannel) }
                        .keyboardShortcut(.upArrow, modifiers: [])
                    Button("") { store.send(.nextChannel) }
                        .keyboardShortcut(.downArrow, modifiers: [])
                    Button("") { store.send(.closeTapped) }
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .opacity(0.001)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
            }
            .allowsHitTesting(!store.isMinimized)
            .sheet(isPresented: $isShowingSpeedTest) {
                StreamSpeedTestView()
            }
            .onDisappear {
                cancelAllPendingWorkItems()
            }
        }

        private func formatDuration(_ duration: Duration) -> String {
            let totalSeconds = Int(duration.components.seconds)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60

            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }

        private var tracksMenuOverlay: some View {
            HStack {
                Spacer()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !store.audioTracks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(AppStrings.Player.audioTracks, systemImage: "waveform.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                ForEach(store.audioTracks) { track in
                                    let formatted = TrackLanguageFormatter.format(trackName: track.name, isSubtitle: false)
                                    let isSelected = store.selectedAudioTrack?.id == track.id
                                    Button(action: {
                                        HapticManager.shared.trigger(.light)
                                        store.send(.selectAudioTrack(track))
                                    }) {
                                        HStack(spacing: 8) {
                                            if let flag = formatted.flag {
                                                Text(flag)
                                                    .font(.body)
                                            }
                                            Text(formatted.displayName)
                                                .font(.subheadline)
                                            if let detail = formatted.formatDetail {
                                                Text(detail)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white.opacity(0.85))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.white.opacity(0.18), in: Capsule())
                                            }
                                            Spacer()
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.subheadline.bold())
                                            }
                                        }
                                        .foregroundColor(isSelected ? .accentColor : .white)
                                    }
                                    .padding(.vertical, 4)
                                }

                                Divider().background(Color.white.opacity(0.2))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(AppStrings.Player.audioSync)
                                        .font(.caption.bold())
                                        .foregroundColor(.white.opacity(0.8))
                                    HStack(spacing: 8) {
                                        Button("-250ms") {
                                            HapticManager.shared.trigger(.light)
                                            store.send(.setAudioDelay(store.audioDelay - 250))
                                        }
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.15), in: Capsule())

                                        Button(AppStrings.Player.resetAudioDelay) {
                                            HapticManager.shared.trigger(.light)
                                            store.send(.setAudioDelay(0))
                                        }
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.15), in: Capsule())

                                        Button("+250ms") {
                                            HapticManager.shared.trigger(.light)
                                            store.send(.setAudioDelay(store.audioDelay + 250))
                                        }
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.15), in: Capsule())

                                        Spacer()
                                        Text(AppStrings.Player.audioDelayMs(store.audioDelay))
                                            .font(.caption2.monospacedDigit())
                                            .foregroundColor(.accentColor)
                                    }

                                    Button {
                                        HapticManager.shared.trigger(.light)
                                        store.send(.toggleTracksMenu)
                                        store.send(.setAudioSyncHUDVisible(true), animation: .spring(response: 0.35, dampingFraction: 0.8))
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "slider.horizontal.2.square")
                                                .font(.caption2)
                                            Text(AppStrings.Player.lipSyncAdjustment)
                                                .font(.caption2.bold())
                                        }
                                        .foregroundColor(Color(hex: "#0A84FF"))
                                        .padding(.top, 2)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }

                        if !store.subtitleTracks.isEmpty {
                            if !store.audioTracks.isEmpty {
                                Divider().background(Color.white.opacity(0.3))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Label(AppStrings.Player.subtitles, systemImage: "captions.bubble.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                let isSubtitlesOff = store.selectedSubtitleTrack == nil || store.subtitleTracks.isEmpty || (store.selectedSubtitleTrack?.id == "-1")

                                Button(action: {
                                    HapticManager.shared.trigger(.light)
                                    store.send(.selectSubtitleTrack(nil))
                                }) {
                                    HStack {
                                        Text(AppStrings.Player.off)
                                            .font(.subheadline)
                                        Spacer()
                                        if isSubtitlesOff {
                                            Image(systemName: "checkmark")
                                                .font(.subheadline.bold())
                                        }
                                    }
                                    .foregroundColor(isSubtitlesOff ? .accentColor : .white)
                                }
                                .padding(.vertical, 4)

                                ForEach(store.subtitleTracks) { track in
                                    let formatted = TrackLanguageFormatter.format(trackName: track.name, isSubtitle: true)
                                    let isSelected = store.selectedSubtitleTrack?.id == track.id
                                    Button(action: {
                                        HapticManager.shared.trigger(.light)
                                        store.send(.selectSubtitleTrack(track))
                                    }) {
                                        HStack(spacing: 8) {
                                            if let flag = formatted.flag {
                                                Text(flag)
                                                    .font(.body)
                                            }
                                            Text(formatted.displayName)
                                                .font(.subheadline)
                                            if let detail = formatted.formatDetail {
                                                Text(detail)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white.opacity(0.85))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.white.opacity(0.18), in: Capsule())
                                            }
                                            Spacer()
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.subheadline.bold())
                                            }
                                        }
                                        .foregroundColor(isSelected ? .accentColor : .white)
                                    }
                                    .padding(.vertical, 4)
                                }

                                if store.selectedSubtitleTrack != nil, !isSubtitlesOff {
                                    Divider().background(Color.white.opacity(0.2))
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(AppStrings.Player.subtitleSync)
                                            .font(.caption.bold())
                                            .foregroundColor(.white.opacity(0.8))
                                        HStack(spacing: 8) {
                                            Button("-250ms") {
                                                HapticManager.shared.trigger(.light)
                                                store.send(.setSubtitleDelay(store.subtitleDelay - 250))
                                            }
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.15), in: Capsule())

                                            Button(AppStrings.Player.resetSubtitleDelay) {
                                                HapticManager.shared.trigger(.light)
                                                store.send(.setSubtitleDelay(0))
                                            }
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.15), in: Capsule())

                                            Button("+250ms") {
                                                HapticManager.shared.trigger(.light)
                                                store.send(.setSubtitleDelay(store.subtitleDelay + 250))
                                            }
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.15), in: Capsule())

                                            Spacer()
                                            Text(AppStrings.Player.subtitleDelayMs(store.subtitleDelay))
                                                .font(.caption2.monospacedDigit())
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }

                        if store.audioTracks.isEmpty, store.subtitleTracks.isEmpty {
                            Text(AppStrings.Player.noOptions)
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: 320, maxHeight: 340)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.trailing, 16)
            }
        }

        // MARK: - Smart Double-Tap Seek Handlers

        private func handleTap(at location: CGPoint, in size: CGSize) {
            if store.isScreenLocked {
                store.send(.showLockPill)
                return
            }
            store.send(.userInteracted)
            let width = size.width
            let leftBoundary = width * 0.40
            let rightBoundary = width * 0.60

            let isLeft = location.x < leftBoundary
            let isRight = location.x > rightBoundary
            let isCenter = !isLeft && !isRight

            if isCenter {
                singleTapWorkItem?.cancel()
                singleTapWorkItem = nil
                seekDismissWorkItem?.cancel()
                withAnimation(.easeOut(duration: 0.2)) {
                    smartSeekDirection = nil
                }
                activeSeekSide = nil
                cumulativeSeekSeconds = 0

                store.send(.toggleControls, animation: .spring(response: 0.3, dampingFraction: 0.7))
                return
            }

            let tappedSide: ActiveSeekSide = isLeft ? .left : .right

            if let currentSide = activeSeekSide, currentSide == tappedSide {
                singleTapWorkItem?.cancel()
                singleTapWorkItem = nil
                seekDismissWorkItem?.cancel()

                if isRight && store.item.isLive {
                    HapticManager.shared.trigger(.warning)
                    triggerLiveWarning()
                    return
                }

                cumulativeSeekSeconds += 10
                let offset: Int64 = isLeft ? -10 : 10
                HapticManager.shared.trigger(.light)

                if isLeft {
                    smartSeekDirection = .backward(seconds: cumulativeSeekSeconds)
                } else {
                    smartSeekDirection = .forward(seconds: cumulativeSeekSeconds)
                }

                store.send(.jumpBySeconds(offset))
                scheduleSeekDismissal()
            } else if activeSeekSide == nil, singleTapWorkItem != nil {
                singleTapWorkItem?.cancel()
                singleTapWorkItem = nil

                if isRight && store.item.isLive {
                    HapticManager.shared.trigger(.warning)
                    triggerLiveWarning()
                    return
                }

                activeSeekSide = tappedSide
                cumulativeSeekSeconds = 10
                let offset: Int64 = isLeft ? -10 : 10
                HapticManager.shared.trigger(.medium)

                if isLeft {
                    smartSeekDirection = .backward(seconds: 10)
                } else {
                    smartSeekDirection = .forward(seconds: 10)
                }

                store.send(.jumpBySeconds(offset))
                scheduleSeekDismissal()
            } else {
                singleTapWorkItem?.cancel()
                activeSeekSide = nil

                let work = DispatchWorkItem {
                    store.send(.toggleControls, animation: .spring(response: 0.3, dampingFraction: 0.7))
                    singleTapWorkItem = nil
                    activeSeekSide = nil
                    cumulativeSeekSeconds = 0
                }
                singleTapWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26, execute: work)
            }
        }

        private func scheduleSeekDismissal() {
            seekDismissWorkItem?.cancel()
            let work = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.25)) {
                    smartSeekDirection = nil
                }
                activeSeekSide = nil
                cumulativeSeekSeconds = 0
                seekDismissWorkItem = nil
            }
            seekDismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
        }

        private func triggerLiveWarning() {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isLiveWarningVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.25)) {
                    isLiveWarningVisible = false
                }
            }
        }

        // MARK: - Vertical Drag (Volume & Brightness) Handlers

        private func handleDragChanged(value: DragGesture.Value, geo: GeometryProxy) {
            if store.isScreenLocked {
                store.send(.showLockPill)
                return
            }
            let translation = value.translation
            let startLocation = value.startLocation
            let width = geo.size.width
            let height = geo.size.height

            if dragGestureMode == nil {
                if !store.isMinimized, startLocation.y < 90, translation.height > 20, abs(translation.height) >= abs(translation.width) {
                    dragGestureMode = .swipeToMiniPlayer
                } else if abs(translation.height) >= abs(translation.width) {
                    if store.item.isLive, startLocation.x >= width * 0.25, startLocation.x <= width * 0.75 {
                        if startLocation.y < height * 0.35 {
                            dragGestureMode = .miniEPG
                        } else {
                            dragGestureMode = .channelZapping
                            hasTriggeredZappingThresholdHaptic = false
                        }
                    } else if startLocation.x < width * 0.5 {
                        dragGestureMode = .brightness
                        #if !os(tvOS)
                            dragInitialBrightness = Double(UIScreen.main.brightness)
                        #else
                            dragInitialBrightness = store.brightness
                        #endif
                        lastHapticThreshold = Int(round(dragInitialBrightness * 10))
                        activeVerticalOSD = .brightness(dragInitialBrightness)
                        osdDismissWorkItem?.cancel()
                    } else {
                        dragGestureMode = .volume
                        dragInitialVolume = Double(store.volume)
                        lastHapticThreshold = Int(round(dragInitialVolume / 10))
                        activeVerticalOSD = .volume(store.volume)
                        osdDismissWorkItem?.cancel()
                    }
                } else {
                    dragGestureMode = .horizontal
                    dragInitialScrubPosition = store.position
                    lastScrubHapticInterval = -1
                }
            }

            switch dragGestureMode {
            case .swipeToMiniPlayer:
                break

            case .miniEPG:
                break

            case .channelZapping:
                if translation.height < -30 {
                    if interactiveZappingDirection != .next {
                        interactiveZappingDirection = .next
                        if let nextItem = store.nextChannelItem {
                            store.send(.showZappingHUD(item: nextItem, direction: .next))
                        }
                    }
                } else if translation.height > 30 {
                    if interactiveZappingDirection != .previous {
                        interactiveZappingDirection = .previous
                        if let prevItem = store.previousChannelItem {
                            store.send(.showZappingHUD(item: prevItem, direction: .previous))
                        }
                    }
                } else {
                    interactiveZappingDirection = nil
                    if !store.isZappingHUDVisible || store.zappingHUDItem?.id != store.item.id {
                        store.send(.hideZappingHUD)
                    }
                }

                let isPastThreshold = abs(translation.height) >= 60
                if isPastThreshold, !hasTriggeredZappingThresholdHaptic {
                    hasTriggeredZappingThresholdHaptic = true
                    HapticManager.shared.trigger(.medium)
                } else if !isPastThreshold, hasTriggeredZappingThresholdHaptic {
                    hasTriggeredZappingThresholdHaptic = false
                    HapticManager.shared.trigger(.light)
                }

            case .brightness:
                let sensitivity = max(150.0, height * 0.55)
                let delta = -Double(translation.height / sensitivity)
                let newBrightness = max(0.01, min(1.0, dragInitialBrightness + delta))

                #if !os(tvOS)
                    UIScreen.main.brightness = CGFloat(newBrightness)
                #endif
                store.send(.setBrightness(newBrightness))
                activeVerticalOSD = .brightness(newBrightness)

                let step = Int(round(newBrightness * 10))
                if step != lastHapticThreshold {
                    lastHapticThreshold = step
                    if step == 0 || step == 10 {
                        HapticManager.shared.trigger(.medium)
                    } else {
                        HapticManager.shared.trigger(.light)
                    }
                }

            case .volume:
                let sensitivity = max(150.0, height * 0.55)
                let delta = -Double(translation.height / sensitivity)
                let newVolume = max(0, min(100, Int32(round(dragInitialVolume + delta * 100))))

                store.send(.setVolume(newVolume))
                activeVerticalOSD = .volume(newVolume)

                let step = Int(newVolume / 10)
                if step != lastHapticThreshold {
                    lastHapticThreshold = step
                    if newVolume == 0 || newVolume == 100 {
                        HapticManager.shared.trigger(.medium)
                    } else {
                        HapticManager.shared.trigger(.light)
                    }
                }

            case .horizontal:
                if store.totalTime > .zero || !store.item.isLive {
                    let totalSeconds = Double(store.totalTime.components.seconds)
                    let sensitivity = max(150.0, width * 0.95)
                    let progressDelta = Double(translation.width / sensitivity)
                    let targetPos = max(0.0, min(1.0, dragInitialScrubPosition + progressDelta))
                    let targetSecs = targetPos * totalSeconds
                    let initialSecs = dragInitialScrubPosition * totalSeconds
                    let offsetSecs = Int(targetSecs - initialSecs)

                    let scrub = HorizontalScrubState(
                        targetTime: Duration.seconds(targetSecs),
                        totalTime: store.totalTime,
                        offsetSeconds: offsetSecs,
                        targetPosition: targetPos,
                        initialPosition: dragInitialScrubPosition
                    )
                    withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.85)) {
                        horizontalScrubState = scrub
                    }

                    // Haptic pulse when crossing 30-second milestone intervals
                    let interval = abs(offsetSecs) / 30
                    if interval != lastScrubHapticInterval {
                        lastScrubHapticInterval = interval
                        HapticManager.shared.trigger(.light)
                    }
                } else {
                    store.send(.dragGestureChanged(
                        translation: translation,
                        screenWidth: width,
                        screenHeight: height,
                        startLocation: startLocation
                    ))
                }

            case .none:
                break
            }
        }

        private func handleDragEnded(value: DragGesture.Value) {
            if store.isScreenLocked {
                dragGestureMode = nil
                return
            }
            let translation = value.translation
            if dragGestureMode == .brightness || dragGestureMode == .volume {
                osdDismissWorkItem?.cancel()
                let work = DispatchWorkItem {
                    withAnimation(.easeOut(duration: 0.35)) {
                        activeVerticalOSD = nil
                    }
                    osdDismissWorkItem = nil
                }
                osdDismissWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
            } else if dragGestureMode == .horizontal {
                if let scrub = horizontalScrubState {
                    HapticManager.shared.trigger(.medium)
                    store.send(.seek(scrub.targetPosition))
                    withAnimation(.easeOut(duration: 0.25)) {
                        horizontalScrubState = nil
                    }
                } else {
                    store.send(.dragGestureEnded)
                }
            } else if dragGestureMode == .miniEPG {
                if abs(translation.height) > 40 {
                    HapticManager.shared.trigger(.medium)
                    store.send(.toggleEPG, animation: .spring(response: 0.35, dampingFraction: 0.75))
                    if store.epgListings.isEmpty {
                        store.send(.fetchEPG)
                    }
                }
            } else if dragGestureMode == .channelZapping {
                if abs(translation.height) >= 60 {
                    HapticManager.shared.trigger(.heavy)
                    if translation.height < 0 {
                        store.send(.nextChannel)
                    } else {
                        store.send(.previousChannel)
                    }
                } else {
                    store.send(.hideZappingHUD)
                }
                interactiveZappingDirection = nil
                hasTriggeredZappingThresholdHaptic = false
            } else if dragGestureMode == .swipeToMiniPlayer {
                if !store.isMinimized, translation.height > 60 {
                    cancelAllPendingWorkItems()
                    HapticManager.shared.trigger(.medium)
                    store.send(.minimizeTapped)
                }
            }
            dragGestureMode = nil
            lastHapticThreshold = -1
            lastScrubHapticInterval = -1
        }

        private func triggerAspectFeedback() {
            aspectDismissWorkItem?.cancel()
            let work = DispatchWorkItem {
                store.send(.hideAspectFeedback, animation: .easeOut(duration: 0.3))
                aspectDismissWorkItem = nil
            }
            aspectDismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
        }

        private func cancelAllPendingWorkItems() {
            singleTapWorkItem?.cancel()
            singleTapWorkItem = nil
            seekDismissWorkItem?.cancel()
            seekDismissWorkItem = nil
            osdDismissWorkItem?.cancel()
            osdDismissWorkItem = nil
            aspectDismissWorkItem?.cancel()
            aspectDismissWorkItem = nil
        }
    }

    private struct InfoRow: View {
        let title: String
        let value: String

        var body: some View {
            HStack {
                Text("\(title):")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption)
                Text(value)
                    .foregroundColor(.white)
                    .font(.caption.bold())
            }
        }
    }

#endif
