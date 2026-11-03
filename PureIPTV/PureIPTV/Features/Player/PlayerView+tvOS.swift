#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI
    import SwiftVLC
    import UIKit

    enum TVPlayerRemoteAction: String, CaseIterable, Identifiable {
        case channelUp
        case channelDown
        case openChannelList
        case openGuide
        case showChannelInfo
        case recallLastChannel
        case showControls

        static let defaultUpAction = Self.channelUp
        static let defaultDownAction = Self.channelDown
        static let defaultLeftAction = Self.openChannelList
        static let defaultRightAction = Self.recallLastChannel

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .channelUp: AppStrings.Player.nextChannel
            case .channelDown: AppStrings.Player.previousChannel
            case .openChannelList: AppStrings.Common.channels
            case .openGuide: AppStrings.Player.epg
            case .showChannelInfo: AppStrings.Player.channelInfo
            case .recallLastChannel: AppStrings.Player.recallLastChannel
            case .showControls: AppStrings.Player.showControls
            }
        }
    }

    // MARK: - tvOS Player View (KSPlayer Architecture)

    @available(tvOS 16.0, *)
    public struct PlayerView_tvOS: View {
        @Bindable var store: StoreOf<PlayerFeature>

        @AppStorage("com.pureiptv.tvOSPlayerRemoteUpAction") private var remoteUpAction = TVPlayerRemoteAction.defaultUpAction.rawValue
        @AppStorage("com.pureiptv.tvOSPlayerRemoteDownAction") private var remoteDownAction = TVPlayerRemoteAction.defaultDownAction.rawValue
        @AppStorage("com.pureiptv.tvOSPlayerRemoteLeftAction") private var remoteLeftAction = TVPlayerRemoteAction.defaultLeftAction.rawValue
        @AppStorage("com.pureiptv.tvOSPlayerRemoteRightAction") private var remoteRightAction = TVPlayerRemoteAction.defaultRightAction.rawValue

        @FocusState private var focusableField: TVPlayerFocusableField?
        @State private var isMaskShow: Bool = true
        @State private var idleTimer: Timer?
        @State private var isScrubbing: Bool = false
        @State private var focusBeforeEPG: TVPlayerFocusableField?
        @State private var focusBeforeMediaServerSourcePicker: TVPlayerFocusableField?

        public init(store: StoreOf<PlayerFeature>) {
            self.store = store
        }

        public var body: some View {
            ZStack {
                GeometryReader { proxy in
                    playView

                    // OLED Dimmer & Anti-Burn-in Protection
                    OLEDDimmerOverlay(
                        dimLevel: store.oledDimLevel,
                        isDeepDimmed: store.isDeepDimmed
                    )

                    if isMaskShow || isUpNextCardVisible {
                        controllerView(playerHeight: proxy.size.height)
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .zIndex(isUpNextCardVisible ? 96 : 0)
                    }

                    // Buffering Indicator
                    if store.playerState == .buffering || store.playerState == .opening, store.errorMessage == nil, !store.isReconnecting {
                        VStack(spacing: 20) {
                            PureLoadingView(size: .large, text: AppStrings.Common.loading)
                        }
                        .padding(36)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                        .shadow(color: AppColors.cyan.opacity(0.2), radius: 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Auto-Reconnecting Glass HUD Pill for tvOS
                    if store.isReconnecting {
                        HStack(spacing: 16) {
                            if store.isFallbackSwitching {
                                Image(systemName: "arrow.triangle.swap")
                                    .font(AppFonts.titleSmall.weight(.bold))
                                    .foregroundStyle(AppColors.neonTeal)
                                Text(AppStrings.Player.switchingToBackup(store.fallbackStreamName ?? ""))
                                    .font(AppFonts.titleSmall.weight(.semibold))
                                    .foregroundColor(.white)
                            } else {
                                PureLoadingView(size: .small)
                                Text(AppStrings.Player.reconnecting(store.retryCount, max: store.maxReconnectAttempts))
                                    .font(AppFonts.titleSmall.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(store.isFallbackSwitching ? AppColors.neonTeal.opacity(0.4) : Color.white.opacity(0.2), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 6)
                        .padding(.top, 40)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .zIndex(99)
                    }

                    // Error Overlay (Madde #89)
                    if let errorMessage = store.errorMessage, !store.isReconnecting {
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
                            errorMessage: errorMessage,
                            onRetry: {
                                store.send(.retryPlayback)
                            },
                            onSwitchToBackup: store.backupStreamItem != nil ? {
                                store.send(.switchToBackupStream)
                            } : nil,
                            backupChannelName: store.backupStreamItem?.title,
                            onSwitchPlaybackEngine: store.canSwitchPlaybackEngine ? {
                                store.send(.switchPlaybackEngineFromError(alternatePlaybackEngine))
                            } : nil,
                            playbackEngineTitle: store.canSwitchPlaybackEngine
                                ? AppStrings.Player.tryPlaybackEngine(alternatePlaybackEngine.title)
                                : nil,
                            positionRecoveryHint: positionRecoveryHint,
                            onOpenSpeedTest: nil,
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
                        .padding(48)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(100)
                    }

                    // Channel Zapping HUD Overlay (Madde #16)
                    if store.isZappingHUDVisible, let zappingItem = store.zappingHUDItem {
                        let direction = store.zappingHUDDirection ?? .next
                        VStack {
                            ChannelZappingHUDView(
                                item: zappingItem,
                                direction: direction,
                                currentIndex: store.currentChannelIndex,
                                totalChannels: store.playlist?.count,
                                isCommitted: store.item.id == zappingItem.id,
                                currentProgram: store.item.id == zappingItem.id ? store.currentEPGProgram : nil,
                                nextProgram: store.item.id == zappingItem.id ? store.nextEPGProgram : nil,
                                isCleaningEnabled: store.isChannelNameCleaningEnabled
                            )
                            .padding(.top, 60)
                            Spacer()
                        }
                        .transition(.move(edge: direction == .next ? .top : .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isZappingHUDVisible)
                        .zIndex(85)
                    }

                    // Aspect Ratio & Zoom HUD Feedback (Madde #14 / #49)
                    if store.isAspectFeedbackVisible {
                        AspectScaleHUDView(
                            mode: store.videoAspectRatioMode,
                            scale: store.videoZoomScale
                        )
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: store.isAspectFeedbackVisible)
                        .zIndex(90)
                    }

                    // Dynamic Range Indicator HUD (HDR / Dolby Vision / SDR) (Madde #20)
                    if store.isDynamicRangeHUDVisible, let drInfo = store.dynamicRangeInfo {
                        VStack {
                            HStack {
                                Spacer()
                                DynamicRangeHUDView(info: drInfo)
                                    .padding(.top, 48)
                                    .padding(.trailing, 60)
                            }
                            Spacer()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isDynamicRangeHUDVisible)
                        .zIndex(96)
                    }

                    // Auto Frame Rate & Match Dynamic Range HUD Toast (Madde #21)
                    if store.isAFRToastVisible, let afrResult = store.afrMatchResult {
                        VStack {
                            HStack {
                                Spacer()
                                AFRToastView(result: afrResult)
                                    .padding(.top, 48)
                                    .padding(.trailing, 60)
                            }
                            Spacer()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isAFRToastVisible)
                        .zIndex(97)
                    }

                    // EPG Overlay
                    if store.isEPGVisible {
                        VStack {
                            Spacer()
                            PlayerEPGTimelineView(
                                programs: store.epgBrowseListings,
                                currentPosition: store.position,
                                hasArchive: store.epgBrowseChannel?.tvArchive == 1,
                                channels: store.liveChannels,
                                selectedChannel: store.epgBrowseChannel,
                                playingChannelID: store.item.id,
                                isLoading: store.isEPGBrowseLoading || store.isEPGLoading,
                                canSelectPrograms: store.epgBrowseChannel?.id == store.item.id,
                                selectedPreviewCorner: store.epgPreviewCorner,
                                onSelectPreviewCorner: { corner in
                                    store.send(.setEPGPreviewCorner(corner))
                                },
                                onClose: {
                                    store.send(.toggleEPG, animation: .spring(response: 0.3, dampingFraction: 0.7))
                                    resetIdleTimer()
                                },
                                onBrowseChannel: { channel in
                                    store.send(.selectEPGBrowseChannel(channel))
                                },
                                onReturnToPlayingChannel: {
                                    store.send(.returnToPlayingChannelInEPG)
                                },
                                onWatchChannel: {
                                    store.send(.watchEPGBrowseChannel)
                                },
                                onSelect: { program in
                                    store.send(.playArchive(program))
                                    resetIdleTimer()
                                }
                            )
                            .padding(.horizontal, 60)
                            .padding(.bottom, 60)
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: PlayerEPGGuidePanelHeightPreferenceKey.self,
                                        value: geometry.size.height
                                    )
                                }
                            }
                            .opacity(store.isDeepDimmed ? 0.35 : 1.0)
                            .animation(.easeInOut(duration: 0.35), value: store.isDeepDimmed)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // On-Screen Display (OSD) Channel Info Card (Madde #95)
                    if store.isChannelOSDVisible, store.item.isLive, !store.isEPGVisible, !store.isRecentChannelsHUDVisible, !isMaskShow {
                        VStack {
                            Spacer()
                            ChannelInfoOSDView(
                                item: store.item,
                                channelIndex: store.currentChannelIndex,
                                totalChannels: store.playlist?.count,
                                currentProgram: store.currentEPGProgram,
                                nextProgram: store.nextEPGProgram,
                                isCleaningEnabled: store.isChannelNameCleaningEnabled,
                                dynamicRange: store.videoDynamicRange,
                                playlistName: store.sourcePlaylistName
                            )
                            .padding(.horizontal, 60)
                            .padding(.bottom, 60)
                            .opacity(store.isDeepDimmed ? 0.35 : 1.0)
                            .animation(.easeInOut(duration: 0.35), value: store.isDeepDimmed)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: store.isChannelOSDVisible)
                        .zIndex(80)
                    }

                    // Recent Channels Carousel HUD (Quick-Zap Dock)
                    if store.isRecentChannelsHUDVisible {
                        VStack {
                            Spacer()
                            RecentChannelsHUDView(store: store) {
                                store.send(.setRecentChannelsHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                                resetIdleTimer()
                            }
                            .padding(.horizontal, 48)
                            .padding(.bottom, 48)
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
                                resetIdleTimer()
                            }
                            .padding(.horizontal, 48)
                            .padding(.bottom, 48)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isAudioSyncHUDVisible)
                        .zIndex(99)
                    }

                    // Live Stream Audio Equalizer & Dialogue Enhancer HUD (Madde #14)
                    if store.isAudioEQHUDVisible {
                        VStack {
                            Spacer()
                            AudioEQHUDView(store: store) {
                                store.send(.setAudioEQHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                                resetIdleTimer()
                            }
                            .padding(.horizontal, 48)
                            .padding(.bottom, 48)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isAudioEQHUDVisible)
                        .zIndex(100)
                    }

                    // Catchup / Archive Timeline Visual Scrubber Overlay (Feature #4)
                    if store.isCatchupTimelineVisible {
                        VStack {
                            Spacer()
                            CatchupTimelineScrubberView(
                                store: store,
                                onClose: {
                                    store.send(.setCatchupTimelineVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                                    resetIdleTimer()
                                }
                            )
                            .padding(.horizontal, 48)
                            .padding(.bottom, 48)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isCatchupTimelineVisible)
                        .zIndex(99)
                    }

                    if let message = store.catchupSeekFailureMessage {
                        VStack {
                            Text(message)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .background(.ultraThinMaterial, in: Capsule())
                            Spacer()
                        }
                        .padding(.top, 72)
                        .padding(.horizontal, 48)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(101)
                    }

                    // Edge-Swipe Channel Sidebar Drawer
                    if store.isChannelListVisible {
                        PlayerSidebarDrawer(store: store) {
                            store.send(.toggleChannelList, animation: .spring(response: 0.32, dampingFraction: 0.8))
                            resetIdleTimer()
                        }
                        .zIndex(100)
                    }

                    // Track Selection HUD Overlay (Madde #34)
                    if store.isTrackHUDVisible, let message = store.trackHUDMessage {
                        VStack {
                            TrackHUDView(
                                message: message,
                                iconName: store.trackHUDIcon ?? "waveform.circle.fill"
                            )
                            .padding(.top, 60)

                            Spacer()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isTrackHUDVisible)
                        .zIndex(99)
                    }

                    // Stream Health & Network Jitter HUD (Feature #3)
                    if store.isStreamHealthHUDVisible {
                        VStack {
                            HStack {
                                StreamHealthHUDView(
                                    store: store,
                                    onClose: {
                                        store.send(.setStreamHealthHUDVisible(false))
                                        resetIdleTimer()
                                    }
                                )
                                .padding(.leading, 80)
                                .padding(.top, 60)

                                Spacer()
                            }
                            Spacer()
                        }
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: store.isStreamHealthHUDVisible)
                        .zIndex(112)
                    }

                    // Nerd Stats Technical Diagnostics Overlay (Madde #33)
                    if store.isShowingStats {
                        VStack {
                            HStack {
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
                                    streamHealthMetrics: store.streamHealthMetrics,
                                    serverPlaybackStatus: store.mediaServerPlaybackStatus,
                                    onClose: {
                                        store.send(.toggleStats, animation: .spring(response: 0.32, dampingFraction: 0.8))
                                        resetIdleTimer()
                                    }
                                )
                                .padding(.leading, 80)
                                .padding(.top, 60)

                                Spacer()
                            }
                            Spacer()
                        }
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: store.isShowingStats)
                        .zIndex(110)
                    }

                    // Sleep Timer Smooth Fading Notification (Feature #6)
                    if store.isSleepFadingActive {
                        VStack {
                            HStack(spacing: 12) {
                                Image(systemName: "moon.stars.fill")
                                    .font(AppFonts.titleSmall)
                                    .foregroundStyle(AppColors.premium)
                                Text(AppStrings.Player.sleepTimerFading)
                                    .font(AppFonts.titleSmall.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .background(AppColors.surface.opacity(0.85))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.premium.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: AppColors.premium.opacity(0.35), radius: 14, x: 0, y: 6)
                            .padding(.top, 50)

                            Spacer()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.4), value: store.isSleepFadingActive)
                        .zIndex(120)
                    }

                    // Instant Previous Channel Quick-Recall HUD (Madde #10)
                    if store.isRecallHUDVisible, let prev = store.recalledChannelItem {
                        VStack {
                            PreviousChannelRecallHUDView(item: prev) {
                                store.send(.hideRecallHUD)
                            }
                            .padding(.top, 50)

                            Spacer()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isRecallHUDVisible)
                        .zIndex(130)
                    }

                    // Direct Channel Number Dialing HUD (Madde #11)
                    if store.isChannelDialerVisible {
                        DirectChannelDialHUDView(store: store) {
                            store.send(.setChannelDialerVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                            resetIdleTimer()
                        }
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isChannelDialerVisible)
                        .zIndex(140)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .tint(.white)
            .modifier(MediaServerPlaybackOptionsDialog(store: store))
            .onPlayPauseCommand {
                store.send(.userInteracted)
                if store.playerState == .playing {
                    store.send(.pause)
                } else {
                    store.send(.play)
                }
                showMask()
            }
            .onExitCommand {
                store.send(.userInteracted)
                if store.isMediaServerPlaybackOptionsPresented {
                    store.send(.cancelMediaServerPlaybackSourceSelection)
                } else if store.isUpNextVisible {
                    dismissUpNextAndRestoreFocus()
                } else if store.isChannelDialerVisible {
                    store.send(.setChannelDialerVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                    resetIdleTimer()
                } else if store.isAudioEQHUDVisible {
                    store.send(.setAudioEQHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                    resetIdleTimer()
                } else if store.isCatchupTimelineVisible {
                    store.send(.setCatchupTimelineVisible(false))
                    resetIdleTimer()
                } else if store.isAudioSyncHUDVisible {
                    store.send(.setAudioSyncHUDVisible(false))
                    resetIdleTimer()
                } else if store.isRecentChannelsHUDVisible {
                    store.send(.setRecentChannelsHUDVisible(false))
                    resetIdleTimer()
                } else if store.isStreamHealthHUDVisible {
                    store.send(.setStreamHealthHUDVisible(false))
                    resetIdleTimer()
                } else if store.isShowingStats {
                    store.send(.toggleStats, animation: .spring(response: 0.32, dampingFraction: 0.8))
                    resetIdleTimer()
                } else if store.isChannelOSDVisible {
                    store.send(.hideChannelOSD)
                    resetIdleTimer()
                } else if store.isChannelListVisible {
                    store.send(.toggleChannelList, animation: .spring(response: 0.32, dampingFraction: 0.8))
                    resetIdleTimer()
                } else if store.isEPGVisible {
                    store.send(.toggleEPG, animation: .spring(response: 0.3, dampingFraction: 0.7))
                    resetIdleTimer()
                } else if store.errorMessage != nil {
                    store.send(.closeTapped)
                } else if isMaskShow {
                    hideMask()
                } else {
                    store.send(.closeTapped)
                }
            }
            .onAppear {
                showMask()
            }
            .onChange(of: store.isEPGVisible) { _, isVisible in
                if isVisible {
                    focusBeforeEPG = focusableField
                } else if let focusBeforeEPG {
                    focusableField = focusBeforeEPG
                    self.focusBeforeEPG = nil
                }
            }
            .onChange(of: store.item.id) { previousItemID, currentItemID in
                guard previousItemID != currentItemID, store.item.isLive else { return }
                hideMask()
            }
            .onChange(of: store.isMediaServerPlaybackOptionsPresented) { _, isVisible in
                if isVisible {
                    focusBeforeMediaServerSourcePicker = focusableField
                } else if let focusBeforeMediaServerSourcePicker {
                    focusableField = focusBeforeMediaServerSourcePicker
                    self.focusBeforeMediaServerSourcePicker = nil
                }
            }
            .onChange(of: focusableField) { _, newField in
                guard newField != nil, newField != .play else { return }
                resetIdleTimer()
            }
            .onDisappear {
                idleTimer?.invalidate()
            }
        }

        // MARK: - Play View (Captures Remote Navigation & Clicks when controls are hidden)

        private var playView: some View {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .focusable(!isMaskShow)
                .focused($focusableField, equals: .play)
                .onTapGesture {
                    store.send(.userInteracted)
                    showMask()
                }
                .onMoveCommand { direction in
                    store.send(.userInteracted)
                    let rawAction: String = switch direction {
                    case .up: remoteUpAction
                    case .down: remoteDownAction
                    case .left: remoteLeftAction
                    case .right: remoteRightAction
                    @unknown default: TVPlayerRemoteAction.showControls.rawValue
                    }
                    performRemoteAction(rawAction)
                }
                .onContinuousHover { _ in
                    store.send(.userInteracted)
                    showMask()
                }
        }

        private func performRemoteAction(_ rawValue: String) {
            guard let action = TVPlayerRemoteAction(rawValue: rawValue) else {
                showMask()
                return
            }
            guard store.item.isLive else {
                showMask()
                return
            }

            switch action {
            case .channelUp:
                guard store.playlist != nil else { showMask(); return }
                store.send(.channelUp)
            case .channelDown:
                store.send(.channelDownOrRecentChannels, animation: .spring(response: 0.35, dampingFraction: 0.8))
            case .openChannelList:
                guard store.playlist != nil else { showMask(); return }
                store.send(.setChannelListVisible(true), animation: .spring(response: 0.32, dampingFraction: 0.8))
            case .openGuide:
                store.send(.toggleEPG, animation: .spring(response: 0.3, dampingFraction: 0.7))
            case .showChannelInfo:
                store.send(.showChannelOSD)
            case .recallLastChannel:
                guard store.previousChannel != nil else { showMask(); return }
                store.send(.recallLastChannel)
            case .showControls:
                showMask()
            }
        }

        private func dismissUpNextAndRestoreFocus() {
            store.send(.dismissUpNext)
            focusableField = isMaskShow ? .playPause : .play
            resetIdleTimer()
        }

        private var isUpNextCardVisible: Bool {
            !store.item.isLive && store.isUpNextVisible && store.nextEpisodeItem != nil
        }

        @ViewBuilder
        private var upNextCountdownCard: some View {
            if isUpNextCardVisible, let nextItem = store.nextEpisodeItem {
                UpNextCountdownOverlayView(
                    item: nextItem,
                    countdownSeconds: store.upNextCountdownSeconds,
                    totalSeconds: store.upNextInitialSeconds,
                    onPlayNow: {
                        store.send(.playNextEpisode)
                        resetIdleTimer()
                    },
                    onDismiss: {
                        dismissUpNextAndRestoreFocus()
                    }
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 60)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(96)
            }
        }

        // MARK: - Controller View (KSPlayer Layout)

        private func controllerView(playerHeight: CGFloat) -> some View {
            VStack(spacing: 16) {
                Spacer()

                // Top part of controls: Title + Action Buttons
                if isMaskShow {
                    PlayerControlsTopBar_tvOS(
                        store: store,
                        focusedField: $focusableField,
                        onInteraction: { resetIdleTimer() },
                        onSubtitleSearch: { store.send(.subtitleSearchTapped) }
                    )
                    .padding(.horizontal, 80)
                    .accessibilityHidden(store.errorMessage != nil && !store.isReconnecting)
                    .opacity(store.isDeepDimmed ? 0.35 : 1)
                }

                // Keep Up Next in the controls stack so it sits above the scrubber.
                upNextCountdownCard

                // Bottom part of controls: Interactive Fluid Scrubber + Time Display
                if isMaskShow {
                    PlayerControlsScrubber_tvOS(
                        store: store,
                        focusedField: $focusableField,
                        isScrubbing: $isScrubbing,
                        onInteraction: {
                            resetIdleTimer()
                        }
                    )
                    .padding(.horizontal, 80)
                    .accessibilityHidden(store.errorMessage != nil && !store.isReconnecting)
                    .opacity(store.isDeepDimmed ? 0.35 : 1)
                }
            }
            .padding(.bottom, isMaskShow ? 60 : max(180, playerHeight * 0.2))
            .background {
                if isMaskShow {
                    overlayGradient
                        .opacity(store.isDeepDimmed ? 0.35 : 1)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: store.isDeepDimmed)
        }

        // MARK: - Overlay Gradient (KSPlayer Design)

        private let overlayGradient = LinearGradient(
            stops: [
                Gradient.Stop(color: .black.opacity(0), location: 0.0),
                Gradient.Stop(color: .black.opacity(0.4), location: 0.3),
                Gradient.Stop(color: .black.opacity(0.85), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        // MARK: - Timer & Visibility Helpers

        private func showMask() {
            store.send(.userInteracted)
            withAnimation(.easeInOut(duration: 0.25)) {
                isMaskShow = true
            }
            focusableField = .playPause
            resetIdleTimer()
        }

        private func hideMask() {
            withAnimation(.easeInOut(duration: 0.25)) {
                isMaskShow = false
            }
            focusableField = .play
            idleTimer?.invalidate()
        }

        private func resetIdleTimer(duration: TimeInterval = 18.0) {
            store.send(.userInteracted)
            idleTimer?.invalidate()
            idleTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                Task { @MainActor in
                    if !keepsControllerVisibleWhileOpen {
                        hideMask()
                    }
                }
            }
        }

        private var keepsControllerVisibleWhileOpen: Bool {
            isScrubbing
                || store.isUpNextVisible
                || store.isChannelDialerVisible
                || store.isAudioEQHUDVisible
                || store.isCatchupTimelineVisible
                || store.isAudioSyncHUDVisible
                || store.isRecentChannelsHUDVisible
                || store.isStreamHealthHUDVisible
                || store.isShowingStats
                || store.isChannelListVisible
                || store.isEPGVisible
                || store.isMediaServerPlaybackOptionsPresented
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
