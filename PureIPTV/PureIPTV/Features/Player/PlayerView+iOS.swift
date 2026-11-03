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
        @State private var lastScrubThumbnailBucket: Int?

        // Aspect Ratio & Zoom State (Madde #14)
        @State private var pinchStartScale: CGFloat? = nil
        @State private var aspectDismissWorkItem: DispatchWorkItem? = nil
        @State private var controlsDismissWorkItem: DispatchWorkItem? = nil
        // Channel Zapping State (Madde #16 & #10)
        @State private var interactiveZappingDirection: ZappingDirection? = nil
        @State private var hasTriggeredZappingThresholdHaptic: Bool = false
        @State private var lastLiveCenterTapTime: Date? = nil

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

        private var isAnyHUDOrOverlayVisible: Bool {
            store.isTracksMenuVisible ||
                store.isInfoVisible ||
                store.isStreamHealthHUDVisible ||
                store.isAudioSyncHUDVisible ||
                store.isAudioEQHUDVisible ||
                store.isCatchupTimelineVisible ||
                store.isRecentChannelsHUDVisible ||
                store.isChannelListVisible ||
                store.isEPGVisible ||
                store.isChannelDialerVisible
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
                    HorizontalScrubHUDView(state: scrub, previewData: store.scrubThumbnailData)
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
                    PlayerControlsOverlayView_iOS(
                        store: store,
                        pipController: $pipController,
                        isDraggingSlider: $isDraggingSlider,
                        sliderDragValue: $sliderDragValue,
                        isAnyHUDOrOverlayVisible: isAnyHUDOrOverlayVisible,
                        onClose: {
                            cancelAllPendingWorkItems()
                            store.send(.closeTapped)
                        },
                        onMinimize: {
                            cancelAllPendingWorkItems()
                            store.send(.minimizeTapped)
                        },
                        onTriggerAspectFeedback: {
                            triggerAspectFeedback()
                        },
                        onResetControlsDismissTimer: {
                            resetControlsDismissTimer()
                        }
                    )
                }

                // Global Buffering Indicator (visible whether controls are active or hidden)
                if store.playerState == .buffering || store.playerState == .opening, store.errorMessage == nil, !store.isReconnecting {
                    PureLoadingView(size: .medium)
                        .padding(20)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: AppColors.cyan.opacity(0.25), radius: 16)
                }

                // Auto-Reconnecting Glass HUD Pill (Subtle, non-blocking notification pill)
                if store.isReconnecting {
                    HStack(spacing: 12) {
                        if store.isFallbackSwitching {
                            Image(systemName: "arrow.triangle.swap")
                                .font(AppFonts.bodyMedium.weight(.bold))
                                .foregroundStyle(AppColors.neonTeal)
                            Text(AppStrings.Player.switchingToBackup(store.fallbackStreamName ?? ""))
                                .font(AppFonts.bodySmall.weight(.semibold))
                                .foregroundColor(.white)
                        } else {
                            PureLoadingView(size: .small)
                            Text(AppStrings.Player.reconnecting(store.retryCount, max: store.maxReconnectAttempts))
                                .font(AppFonts.bodySmall.weight(.semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(store.isFallbackSwitching ? AppColors.neonTeal.opacity(0.4) : Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 20)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .zIndex(99)
                }

                // Global Error Overlay with Diagnostic Support (Madde #89)
                if let error = store.errorMessage, !store.isReconnecting {
                    let alternatePlaybackEngine: PlaybackEngine = store.playbackEngine == .vlc ? .avPlayer : .vlc
                    let canRequestXtreamOutputFormats = store.item.isLive
                        && store.item.config?.type == .xtream
                        && store.activeCatchupProgram == nil
                        && !store.isPlayingCatchup
                    let positionRecoveryHint = (!store.item.isLive || store.activeCatchupProgram != nil)
                        ? AppStrings.Player.playbackPositionMayBeRestored
                        : nil
                    Color.black.opacity(0.72)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)

                    PlayerFriendlyErrorView(
                        errorMessage: error,
                        onRetry: {
                            HapticManager.shared.trigger(.medium)
                            store.send(.retryPlayback)
                        },
                        onSwitchToBackup: store.backupStreamItem != nil ? {
                            HapticManager.shared.trigger(.medium)
                            store.send(.switchToBackupStream)
                        } : nil,
                        backupChannelName: store.backupStreamItem?.title,
                        onSwitchPlaybackEngine: store.canSwitchPlaybackEngine ? {
                            HapticManager.shared.trigger(.medium)
                            store.send(.switchPlaybackEngineFromError(alternatePlaybackEngine))
                        } : nil,
                        playbackEngineTitle: store.canSwitchPlaybackEngine
                            ? AppStrings.Player.tryPlaybackEngine(alternatePlaybackEngine.title)
                            : nil,
                        positionRecoveryHint: positionRecoveryHint,
                        onOpenSpeedTest: {
                            store.send(.speedTestTapped)
                        },
                        onRequestXtreamLiveOutputFormats: canRequestXtreamOutputFormats ? {
                            store.send(.requestXtreamLiveOutputFormats)
                        } : nil,
                        onSelectXtreamLiveOutputFormat: canRequestXtreamOutputFormats ? { format in
                            store.send(.selectXtreamLiveOutputFormat(format))
                        } : nil,
                        xtreamLiveOutputFormatOptions: store.xtreamLiveOutputFormatOptions,
                        didRequestXtreamLiveOutputFormats: store.didRequestXtreamLiveOutputFormats,
                        isLoadingXtreamLiveOutputFormats: store.isLoadingXtreamLiveOutputFormats,
                        xtreamLiveOutputFormatError: store.xtreamLiveOutputFormatError,
                        onDismiss: {
                            store.send(.closeTapped)
                        }
                    )
                    .padding(24)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
                }

                // HUDs and Overlays Manager (Extracted)
                PlayerHUDOverlayManagerView_iOS(
                    store: store,
                    interactiveZappingDirection: interactiveZappingDirection
                )

                // Audio & Subtitle Tracks Overlay
                if store.isTracksMenuVisible {
                    tracksMenuOverlay
                        .zIndex(101)
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
                    Button("") { store.send(.keyboardChannelUp) }
                        .keyboardShortcut(.upArrow, modifiers: [])
                    Button("") { store.send(.keyboardChannelDown) }
                        .keyboardShortcut(.downArrow, modifiers: [])
                    Button("") { store.send(.openChannelDialer) }
                        .keyboardShortcut("d", modifiers: [])
                    Button("") { store.send(.toggleAudioEQHUD) }
                        .keyboardShortcut("e", modifiers: [])
                    Button("") { store.send(.closeTapped) }
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .opacity(0.001)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
            }
            .allowsHitTesting(!store.isMinimized)
            .modifier(MediaServerPlaybackOptionsDialog(store: store))
            .onAppear {
                if store.isControlsVisible {
                    resetControlsDismissTimer()
                }
            }
            .onChange(of: store.isControlsVisible) { _, isVisible in
                if isVisible {
                    resetControlsDismissTimer()
                } else {
                    cancelControlsDismissTimer()
                }
            }
            .onChange(of: isDraggingSlider) { _, isDragging in
                if isDragging {
                    cancelControlsDismissTimer()
                } else {
                    resetControlsDismissTimer()
                }
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

        private func subtitleTrackMetadata(
            source: String,
            flag: String?,
            formattedLanguageName: String?,
            reportedLanguage: String?,
            formatDetail: String?
        ) -> String {
            var parts = ["\(AppStrings.Player.subtitleTrackSourceLabel): \(source)"]
            let reportedLanguage = reportedLanguage?.trimmingCharacters(in: .whitespacesAndNewlines)
            let languageName: String? = if flag != nil {
                formattedLanguageName
            } else if let reportedLanguage,
                      !reportedLanguage.isEmpty,
                      reportedLanguage.lowercased() != "und"
            {
                reportedLanguage
            } else {
                nil
            }
            if let languageName {
                parts.append("\(AppStrings.Player.subtitleSearchLanguage): \(languageName)")
            }
            if let formatDetail {
                parts.append("\(AppStrings.Player.subtitleSearchFormat): \(formatDetail)")
            }
            return parts.joined(separator: " · ")
        }

        private var tracksMenuOverlay: some View {
            ZStack {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        HapticManager.shared.trigger(.light)
                        store.send(.toggleTracksMenu, animation: .spring(response: 0.3, dampingFraction: 0.7))
                    }

                HStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 0) {
                        // Header Bar with Title and Close Button
                        HStack {
                            Label(AppStrings.Player.tracks, systemImage: "captions.bubble.fill")
                                .font(.headline.bold())
                                .foregroundColor(.white)

                            Spacer()

                            Button {
                                HapticManager.shared.trigger(.light)
                                store.send(.toggleTracksMenu, animation: .spring(response: 0.3, dampingFraction: 0.7))
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 10)

                        Divider().background(Color.white.opacity(0.2))

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
                                                .foregroundColor(AppColors.primary)
                                                .padding(.top, 2)
                                            }

                                            Button {
                                                HapticManager.shared.trigger(.light)
                                                store.send(.toggleTracksMenu)
                                                store.send(.setAudioEQHUDVisible(true), animation: .spring(response: 0.35, dampingFraction: 0.8))
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "waveform.badge.magnifyingglass")
                                                        .font(.caption2)
                                                    Text("Ses Ekolayzer & Diyalog (\(store.audioEQPreset.title))")
                                                        .font(.caption2.bold())
                                                }
                                                .foregroundColor(store.audioEQPreset.accentColor)
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
                                        .accessibilityAddTraits(isSubtitlesOff ? .isSelected : [])
                                        .padding(.vertical, 4)

                                        ForEach(store.subtitleTracks) { track in
                                            let formatted = TrackLanguageFormatter.formatSubtitle(trackName: track.name, reportedLanguage: track.language)
                                            let isSelected = store.selectedSubtitleTrack?.id == track.id
                                            let trimmedTrackName = track.name.trimmingCharacters(in: .whitespacesAndNewlines)
                                            let trackName = trimmedTrackName.isEmpty
                                                ? formatted.displayName
                                                : trimmedTrackName
                                            let source = store.externalSubtitleTrackIDs.contains(track.id)
                                                ? AppStrings.Player.subtitleTrackExternalFile
                                                : AppStrings.Player.subtitleTrackMediaStream
                                            let metadata = subtitleTrackMetadata(
                                                source: source,
                                                flag: formatted.flag,
                                                formattedLanguageName: formatted.languageName,
                                                reportedLanguage: track.language,
                                                formatDetail: formatted.formatDetail
                                            )
                                            let metadataContent = Text(metadata)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.65))
                                                .fixedSize(horizontal: false, vertical: true)
                                            Button(action: {
                                                HapticManager.shared.trigger(.light)
                                                store.send(.selectSubtitleTrack(track))
                                            }) {
                                                HStack(alignment: .top, spacing: 8) {
                                                    if let flag = formatted.flag {
                                                        Text(flag)
                                                            .font(.body)
                                                    }
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(trackName)
                                                            .font(.subheadline)
                                                            .fixedSize(horizontal: false, vertical: true)
                                                        metadataContent
                                                    }
                                                    Spacer()
                                                    if isSelected {
                                                        Image(systemName: "checkmark")
                                                            .font(.subheadline.bold())
                                                    }
                                                }
                                                .foregroundColor(isSelected ? .accentColor : .white)
                                            }
                                            .accessibilityLabel("\(trackName), \(metadata)")
                                            .accessibilityAddTraits(isSelected ? .isSelected : [])
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

                                if !store.item.isLive, store.playbackEngine == .vlc {
                                    Button {
                                        store.send(.subtitleSearchTapped)
                                    } label: {
                                        Label(AppStrings.Player.subtitleOnlineSearch, systemImage: "magnifyingglass")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(16)
                        }
                    }
                    .frame(maxWidth: 320, maxHeight: 380)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                    .padding(.trailing, 16)
                    .padding(.top, 64)
                    .padding(.bottom, 24)
                }
            }
            .transition(.scale(scale: 0.94).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: store.isTracksMenuVisible)
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
                if store.item.isLive, store.previousChannel != nil,
                   let last = lastLiveCenterTapTime,
                   Date().timeIntervalSince(last) < 0.35
                {
                    singleTapWorkItem?.cancel()
                    singleTapWorkItem = nil
                    lastLiveCenterTapTime = nil
                    HapticManager.shared.trigger(.medium)
                    store.send(.recallLastChannel)
                    return
                }
                lastLiveCenterTapTime = Date()

                singleTapWorkItem?.cancel()
                singleTapWorkItem = nil
                seekDismissWorkItem?.cancel()
                withAnimation(.easeOut(duration: 0.2)) {
                    smartSeekDirection = nil
                }
                activeSeekSide = nil
                cumulativeSeekSeconds = 0

                let work = DispatchWorkItem {
                    store.send(.toggleControls, animation: .spring(response: 0.3, dampingFraction: 0.7))
                    singleTapWorkItem = nil
                }
                singleTapWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26, execute: work)
                return
            }

            let tappedSide: ActiveSeekSide = isLeft ? .left : .right
            let seekStepSeconds = Int(store.skipIntervalSeconds)

            if let currentSide = activeSeekSide, currentSide == tappedSide {
                singleTapWorkItem?.cancel()
                singleTapWorkItem = nil
                seekDismissWorkItem?.cancel()

                if store.item.isLive && !store.isPlayingCatchup {
                    HapticManager.shared.trigger(.warning)
                    triggerLiveWarning()
                    return
                }

                cumulativeSeekSeconds += seekStepSeconds
                let offset = isLeft ? -Int64(seekStepSeconds) : Int64(seekStepSeconds)
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

                if store.item.isLive && !store.isPlayingCatchup {
                    HapticManager.shared.trigger(.warning)
                    triggerLiveWarning()
                    return
                }

                activeSeekSide = tappedSide
                cumulativeSeekSeconds = seekStepSeconds
                let offset = isLeft ? -Int64(seekStepSeconds) : Int64(seekStepSeconds)
                HapticManager.shared.trigger(.medium)

                if isLeft {
                    smartSeekDirection = .backward(seconds: seekStepSeconds)
                } else {
                    smartSeekDirection = .forward(seconds: seekStepSeconds)
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
                    lastScrubThumbnailBucket = nil
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
                        let item = store.reverseChannelZappingDirection ? store.previousChannelItem : store.nextChannelItem
                        let direction: ZappingDirection = store.reverseChannelZappingDirection ? .previous : .next
                        if let item {
                            store.send(.showZappingHUD(item: item, direction: direction))
                        }
                    }
                } else if translation.height > 30 {
                    if interactiveZappingDirection != .previous {
                        interactiveZappingDirection = .previous
                        let item = store.reverseChannelZappingDirection ? store.nextChannelItem : store.previousChannelItem
                        let direction: ZappingDirection = store.reverseChannelZappingDirection ? .next : .previous
                        if let item {
                            store.send(.showZappingHUD(item: item, direction: direction))
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
                    let thumbnailBucket = Int(targetSecs / 5)
                    if thumbnailBucket != lastScrubThumbnailBucket {
                        lastScrubThumbnailBucket = thumbnailBucket
                        store.send(.requestScrubThumbnail(.seconds(targetSecs)))
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
                    store.send(.cancelScrubThumbnail)
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
                        store.send(.channelUp)
                    } else {
                        store.send(.channelDown)
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
            lastScrubThumbnailBucket = nil
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

        private func resetControlsDismissTimer(duration: TimeInterval = 8.0) {
            controlsDismissWorkItem?.cancel()
            guard store.isControlsVisible, !isDraggingSlider, !isAnyHUDOrOverlayVisible else {
                controlsDismissWorkItem = nil
                return
            }
            let work = DispatchWorkItem {
                guard !isDraggingSlider, !isAnyHUDOrOverlayVisible, store.playerState == .playing else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    store.send(.hideControls)
                }
            }
            controlsDismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
        }

        private func cancelControlsDismissTimer() {
            controlsDismissWorkItem?.cancel()
            controlsDismissWorkItem = nil
        }

        private func cancelAllPendingWorkItems() {
            cancelControlsDismissTimer()
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

    private struct MediaServerPlaybackOptionsDialog: ViewModifier {
        @Bindable var store: StoreOf<PlayerFeature>

        func body(content: Content) -> some View {
            content.confirmationDialog(
                AppStrings.VODDetail.versionsAndQuality,
                isPresented: Binding(
                    get: { store.isMediaServerPlaybackOptionsPresented },
                    set: { isPresented in
                        if !isPresented, store.isMediaServerPlaybackOptionsPresented {
                            store.send(.cancelMediaServerPlaybackSourceSelection)
                        }
                    }
                )
            ) {
                ForEach(store.mediaServerPlaybackOptions) { option in
                    Button(option.displayLabel) {
                        store.send(.selectMediaServerPlaybackSource(option.id))
                    }
                }
                Button(AppStrings.Common.cancel, role: .cancel) {
                    store.send(.cancelMediaServerPlaybackSourceSelection)
                }
            } message: {
                Text(store.item.title)
            }
        }
    }

#endif
