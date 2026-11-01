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

        @FocusState private var focusableField: FocusableField?
        @State private var isMaskShow: Bool = true
        @State private var idleTimer: Timer?
        @State private var focusBeforeEPG: FocusableField?
        @State private var focusBeforeMediaServerSourcePicker: FocusableField?

        fileprivate enum FocusableField: Hashable {
            case play
            case controller
        }

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
                        .shadow(color: Color(hex: "#00D2FF").opacity(0.2), radius: 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Auto-Reconnecting Glass HUD Pill for tvOS
                    if store.isReconnecting {
                        HStack(spacing: 16) {
                            if store.isFallbackSwitching {
                                Image(systemName: "arrow.triangle.swap")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Color(hex: "#00F5D4"))
                                Text(AppStrings.Player.switchingToBackup(store.fallbackStreamName ?? ""))
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            } else {
                                PureLoadingView(size: .small)
                                Text(AppStrings.Player.reconnecting(store.retryCount, max: store.maxReconnectAttempts))
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(store.isFallbackSwitching ? Color(hex: "#00F5D4").opacity(0.4) : Color.white.opacity(0.2), lineWidth: 1.5)
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

                    // Trakt.tv Scrobble Toast HUD (Madde #17)
                    if store.isTraktScrobbleHUDVisible {
                        VStack {
                            HStack {
                                Spacer()
                                TraktScrobbleHUDView(
                                    message: store.traktScrobbleHUDMessage,
                                    isSuccess: true,
                                    progressPercent: store.traktScrobbleHUDPercent
                                )
                                .padding(.top, 48)
                                .padding(.trailing, 60)
                            }
                            Spacer()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isTraktScrobbleHUDVisible)
                        .zIndex(95)
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
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color(hex: "#BF5AF2"))
                                Text(AppStrings.Player.sleepTimerFading)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .background(Color(hex: "#0C0C10").opacity(0.85))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#BF5AF2").opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: Color(hex: "#BF5AF2").opacity(0.35), radius: 14, x: 0, y: 6)
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
            focusableField = isMaskShow ? .controller : .play
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
                    VideoControllerView(
                        store: store,
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
                    VideoTimeShowView(store: store, onInteraction: {
                        resetIdleTimer()
                    })
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
            .focused($focusableField, equals: .controller)
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
            focusableField = .controller
            resetIdleTimer()
        }

        private func hideMask() {
            withAnimation(.easeInOut(duration: 0.25)) {
                isMaskShow = false
            }
            focusableField = .play
            idleTimer?.invalidate()
        }

        private func resetIdleTimer() {
            store.send(.userInteracted)
            idleTimer?.invalidate()
            idleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                Task { @MainActor in
                    if !keepsControllerVisibleWhileOpen {
                        hideMask()
                    }
                }
            }
        }

        private var keepsControllerVisibleWhileOpen: Bool {
            store.isUpNextVisible
                || store.isChannelDialerVisible
                || store.isAudioEQHUDVisible
                || store.isCatchupTimelineVisible
                || store.isAudioSyncHUDVisible
                || store.isRecentChannelsHUDVisible
                || store.isStreamHealthHUDVisible
                || store.isShowingStats
                || store.isChannelListVisible
                || store.isEPGVisible
        }
    }

    // MARK: - Video Controller View (Header & Action Buttons)

    @available(tvOS 16.0, *)
    private struct VideoControllerView: View {
        @Bindable var store: StoreOf<PlayerFeature>
        let onInteraction: () -> Void
        let onSubtitleSearch: () -> Void

        var body: some View {
            HStack(alignment: .center, spacing: 16) {
                // Title & Live Badge
                HStack(spacing: 12) {
                    Text(store.item.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .layoutPriority(3)

                    if store.isPlayingCatchup {
                        Button {
                            onInteraction()
                            store.send(.returnToLiveStream)
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text(AppStrings.Player.returnToLive)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(PlayerCapsuleButtonStyle())
                    } else if store.item.isLive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text(AppStrings.Player.liveLabel)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }

                if let recordingStatusMessage = store.recordingStatusMessage {
                    Text(recordingStatusMessage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                if store.playerState == .buffering {
                    PureLoadingView(size: .small)
                        .padding(.leading, 8)
                }

                Spacer()
                    .layoutPriority(2)

                // Compact transport controls, track selection, and contextual menus.
                HStack(spacing: 18) {
                    if store.totalTime > .zero || store.position > 0 || !store.item.isLive {
                        Button {
                            onInteraction()
                            store.send(.restartPlayback)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 22, weight: .semibold))
                        }
                        .buttonStyle(PlayerCircleButtonStyle(size: 56))
                    }

                    if !store.item.isLive || store.isPlayingCatchup {
                        Button {
                            onInteraction()
                            store.send(.jumpBackward)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "gobackward")
                                Text(store.activeSkipInterval.compactTitle)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .font(.system(size: 22, weight: .semibold))
                        }
                        .buttonStyle(PlayerCircleButtonStyle(size: 56))
                        .accessibilityLabel(AppStrings.Player.skipBackwardBy(store.activeSkipInterval.compactTitle))
                    }

                    if store.canReplayWithSubtitles {
                        Button {
                            onInteraction()
                            store.send(.replayWithSubtitles)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "gobackward.10")
                                Image(systemName: "captions.bubble")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .font(.system(size: 20, weight: .semibold))
                        }
                        .buttonStyle(PlayerCircleButtonStyle(size: 56))
                        .accessibilityLabel(AppStrings.Player.replayWithSubtitles)
                        .accessibilityHint(AppStrings.Player.replayWithSubtitlesHint)
                    }

                    Button {
                        onInteraction()
                        if store.playerState == .playing {
                            store.send(.pause)
                        } else {
                            store.send(.play)
                        }
                    } label: {
                        Image(systemName: store.playerState == .error ? "play.slash.fill" : (store.playerState == .playing ? "pause.fill" : "play.fill"))
                            .font(.system(size: 28, weight: .bold))
                    }
                    .buttonStyle(PlayerCircleButtonStyle(size: 64))
                    .accessibilityLabel(store.playerState == .playing ? AppStrings.Player.pausePlayback : AppStrings.Common.play)

                    if !store.item.isLive || store.isPlayingCatchup {
                        Button {
                            onInteraction()
                            store.send(.jumpForward)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "goforward")
                                Text(store.activeSkipInterval.compactTitle)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .font(.system(size: 22, weight: .semibold))
                        }
                        .buttonStyle(PlayerCircleButtonStyle(size: 56))
                        .accessibilityLabel(AppStrings.Player.skipForwardBy(store.activeSkipInterval.compactTitle))
                    }

                    if !store.item.isLive {
                        PlayerSkipMarkersControls(store: store, onInteraction: onInteraction)
                    }

                    if store.item.isLive {
                        Menu {
                            if store.playerState == .playing {
                                Button {
                                    guard !store.isRecordingStartPending,
                                          !store.isRecordingStopPending
                                    else { return }
                                    onInteraction()
                                    store.send(.toggleRecordingTapped)
                                } label: {
                                    Label(
                                        store.isRecording ? AppStrings.Player.stopRecording : AppStrings.Player.startRecording,
                                        systemImage: store.isRecording ? "stop.circle.fill" : "record.circle"
                                    )
                                }
                            }

                            if let previousChannel = store.previousChannel {
                                Button {
                                    onInteraction()
                                    store.send(.recallLastChannel)
                                } label: {
                                    Label(previousChannel.title, systemImage: "arrow.uturn.backward.circle")
                                }
                            }

                            if store.playlist != nil {
                                Button {
                                    onInteraction()
                                    store.send(.toggleChannelList, animation: .spring(response: 0.32, dampingFraction: 0.8))
                                } label: {
                                    Label(AppStrings.LiveTV.channelsTitle, systemImage: "sidebar.leading")
                                }
                            }

                            if store.item.isLive {
                                Button {
                                    onInteraction()
                                    store.send(.toggleEPG, animation: .spring(response: 0.3, dampingFraction: 0.7))
                                } label: {
                                    Label(AppStrings.LiveTV.channelGuide, systemImage: "list.bullet.rectangle")
                                }
                            }

                            Button {
                                onInteraction()
                                store.send(.toggleRecentChannelsHUD, animation: .spring(response: 0.35, dampingFraction: 0.8))
                            } label: {
                                Label(AppStrings.LiveTV.recentChannels, systemImage: "clock.arrow.circlepath")
                            }

                            if store.playlist != nil {
                                Button {
                                    onInteraction()
                                    store.send(.openChannelDialer, animation: .spring(response: 0.35, dampingFraction: 0.8))
                                } label: {
                                    Label(AppStrings.LiveTV.channelDialerTitle, systemImage: "number.square.fill")
                                }
                            }
                        } label: {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .font(.system(size: 24))
                        }
                        .buttonStyle(PlayerCircleButtonStyle(size: 56))
                        .accessibilityLabel(AppStrings.LiveTV.title)
                    }

                    if !store.audioTracks.isEmpty || !store.subtitleTracks.isEmpty || (!store.item.isLive && store.playbackEngine == .vlc) {
                        Menu {
                            if !store.audioTracks.isEmpty {
                                Section(AppStrings.Player.audioTracks) {
                                    ForEach(store.audioTracks) { track in
                                        let formatted = TrackLanguageFormatter.format(trackName: track.name, isSubtitle: false)
                                        Button {
                                            onInteraction()
                                            store.send(.selectAudioTrack(track))
                                        } label: {
                                            HStack {
                                                Text(formatted.titleWithFlag)
                                                if store.selectedAudioTrack?.id == track.id {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            if !store.subtitleTracks.isEmpty || (!store.item.isLive && store.playbackEngine == .vlc) {
                                Section(AppStrings.Player.subtitles) {
                                    Button {
                                        onInteraction()
                                        store.send(.selectSubtitleTrack(nil))
                                    } label: {
                                        HStack {
                                            Text(AppStrings.Player.off)
                                            if store.selectedSubtitleTrack == nil {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    .accessibilityAddTraits(store.selectedSubtitleTrack == nil ? .isSelected : [])

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
                                        let reportedLanguage = track.language?.trimmingCharacters(in: .whitespacesAndNewlines)
                                        let languageName: String? = if formatted.flag != nil {
                                            formatted.languageName
                                        } else if let reportedLanguage, !reportedLanguage.isEmpty, reportedLanguage.lowercased() != "und" {
                                            reportedLanguage
                                        } else {
                                            nil
                                        }
                                        let sourceMetadata = "\(AppStrings.Player.subtitleTrackSourceLabel): \(source)"
                                        let languageMetadata = languageName.map {
                                            "\(AppStrings.Player.subtitleSearchLanguage): \($0)"
                                        }
                                        let formatMetadata = formatted.formatDetail.map {
                                            "\(AppStrings.Player.subtitleSearchFormat): \($0)"
                                        }
                                        let metadataParts: [String?] = [sourceMetadata, languageMetadata, formatMetadata]
                                        let metadata = metadataParts.compactMap(\.self).joined(separator: " · ")
                                        Button {
                                            onInteraction()
                                            store.send(.selectSubtitleTrack(track))
                                        } label: {
                                            HStack(spacing: 12) {
                                                if let flag = formatted.flag {
                                                    Text(flag)
                                                }
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(trackName)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                    Text(metadata)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(2)
                                                }
                                                if isSelected {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                            .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .accessibilityLabel("\(trackName), \(metadata)")
                                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                                    }

                                    if !store.item.isLive, store.playbackEngine == .vlc {
                                        Button(AppStrings.Player.subtitleOnlineSearch) {
                                            onInteraction()
                                            onSubtitleSearch()
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "captions.bubble.fill")
                                .font(.system(size: 26))
                        }
                        .buttonStyle(PlayerCircleButtonStyle(size: 56))
                        .accessibilityLabel(AppStrings.Player.tracks)
                    }

                    Menu {
                        if store.canSetPlaybackRate {
                            Section(AppStrings.Player.playbackSpeed) {
                                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                                    Button {
                                        onInteraction()
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
                            }
                        }

                        Section(AppStrings.MultiView.aspectRatioControl) {
                            ForEach(VideoAspectRatioMode.allCases, id: \.self) { mode in
                                Button {
                                    onInteraction()
                                    store.send(.setVideoAspectRatioMode(mode))
                                } label: {
                                    HStack {
                                        Text(mode.title)
                                        if store.videoAspectRatioMode == mode {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }

                        if store.canSwitchPlaybackEngine {
                            Section(AppStrings.Player.playbackEngine) {
                                ForEach(PlaybackEngine.allCases, id: \.self) { engine in
                                    Button {
                                        guard !store.isSwitchingPlaybackEngine, engine != store.playbackEngine else { return }
                                        onInteraction()
                                        store.send(.switchPlaybackEngine(engine))
                                    } label: {
                                        if engine == store.playbackEngine {
                                            Label(engine.title, systemImage: "checkmark")
                                        } else {
                                            Text(engine.title)
                                        }
                                    }
                                    .disabled(store.isSwitchingPlaybackEngine || engine == store.playbackEngine)
                                }
                            }
                        }

                        if store.canManagePlaybackEnginePreference {
                            Section(AppStrings.Player.itemPlaybackEnginePreference) {
                                if let preference = store.itemSpecificPlaybackEnginePreference {
                                    Label(
                                        AppStrings.Player.itemPlaybackEnginePreferenceValue(preference.title),
                                        systemImage: "checkmark"
                                    )
                                }
                                if store.canSwitchPlaybackEngine,
                                   store.itemSpecificPlaybackEnginePreference != store.playbackEngine
                                {
                                    Button(AppStrings.Player.saveCurrentPlaybackEngineForItem) {
                                        onInteraction()
                                        store.send(.saveCurrentPlaybackEnginePreference)
                                    }
                                    .disabled(store.isSwitchingPlaybackEngine)
                                }
                                if store.itemSpecificPlaybackEnginePreference != nil {
                                    Button(AppStrings.Player.useGeneralPlaybackEnginePreference) {
                                        onInteraction()
                                        store.send(.clearCurrentPlaybackEnginePreference)
                                    }
                                    .disabled(store.isSwitchingPlaybackEngine)
                                }
                            }
                        }

                        if store.playbackEngine == .vlc {
                            Section(AppStrings.Player.deinterlace) {
                                ForEach(DeinterlaceMode.allCases, id: \.self) { mode in
                                    Button {
                                        onInteraction()
                                        store.send(.setDeinterlaceMode(mode))
                                    } label: {
                                        if store.isDeinterlaceModeKnown, mode == store.deinterlaceMode {
                                            Label(mode.title, systemImage: "checkmark")
                                        } else {
                                            Text(mode.title)
                                        }
                                    }
                                }
                            }

                            Section("Ses") {
                                Button {
                                    onInteraction()
                                    store.send(.toggleAudioEQHUD, animation: .spring(response: 0.35, dampingFraction: 0.8))
                                } label: {
                                    Label("Ses Ekolayzer & Diyalog (\(store.audioEQPreset.title))", systemImage: "waveform.badge.magnifyingglass")
                                }

                                Button {
                                    onInteraction()
                                    store.send(.toggleAudioSyncHUD, animation: .spring(response: 0.35, dampingFraction: 0.8))
                                } label: {
                                    Label(AppStrings.Player.lipSyncAdjustment, systemImage: "slider.horizontal.2.square")
                                }

                                ForEach([-500, -250, 0, 250, 500], id: \.self) { adjustment in
                                    Button {
                                        onInteraction()
                                        store.send(.setAudioDelay(adjustment == 0 ? 0 : store.audioDelay + adjustment))
                                    } label: {
                                        Text(adjustment == 0 ? AppStrings.Player.resetAudioDelay : (adjustment > 0 ? "+\(adjustment) ms" : "\(adjustment) ms"))
                                    }
                                }
                            }

                            Button {
                                onInteraction()
                                store.send(.toggleStreamHealthHUD, animation: .spring(response: 0.32, dampingFraction: 0.8))
                            } label: {
                                Label(AppStrings.Player.streamHealthTitle, systemImage: "waveform.path.ecg")
                            }

                            Button {
                                onInteraction()
                                store.send(.toggleStats, animation: .spring(response: 0.32, dampingFraction: 0.8))
                            } label: {
                                Label(AppStrings.Player.technicalDetails, systemImage: "chart.xyaxis.line")
                            }

                            Button {
                                onInteraction()
                                store.send(.togglePiP, animation: .spring(response: 0.35, dampingFraction: 0.8))
                            } label: {
                                Label(AppStrings.Player.pictureInPicture, systemImage: store.isPiPActive || store.isMinimized ? "pip.exit" : "pip.enter")
                            }
                        }

                        if store.selectedSubtitleTrack != nil {
                            Section(AppStrings.Player.subtitleSync) {
                                ForEach([-500, -250, 0, 250, 500], id: \.self) { adjustment in
                                    Button {
                                        onInteraction()
                                        store.send(.setSubtitleDelay(adjustment == 0 ? 0 : store.subtitleDelay + adjustment))
                                    } label: {
                                        Text(adjustment == 0 ? AppStrings.Player.resetSubtitleDelay : (adjustment > 0 ? "+\(adjustment) ms" : "\(adjustment) ms"))
                                    }
                                }
                            }
                        }

                        if store.playbackEngine == .vlc, store.item.tvArchive == 1 {
                            Button {
                                onInteraction()
                                store.send(.toggleCatchupTimeline, animation: .spring(response: 0.35, dampingFraction: 0.8))
                            } label: {
                                Label(AppStrings.Player.catchupTimelineTitle, systemImage: "calendar.badge.clock")
                            }
                        }

                        Menu {
                            Button(AppStrings.Player.sleepTimerDisabled) {
                                onInteraction()
                                store.send(.setSleepTimer(nil))
                            }
                            ForEach([15, 30, 45, 60, 90], id: \.self) { mins in
                                Button("\(mins) \(AppStrings.Common.minAbbr)") {
                                    onInteraction()
                                    store.send(.setSleepTimer(mins))
                                }
                            }
                        } label: {
                            Label(
                                store.sleepTimerSeconds != nil ? "\(store.sleepTimerSeconds! / 60) \(AppStrings.Common.minAbbr)" : AppStrings.Player.sleepTimer,
                                systemImage: "moon.stars"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .buttonStyle(PlayerCircleButtonStyle(size: 56))
                    .accessibilityLabel(AppStrings.Common.more)
                }
                .modifier(HorizontalActionsScrollModifier())
            }
        }
    }

    private struct HorizontalActionsScrollModifier: ViewModifier {
        func body(content: Content) -> some View {
            ScrollView(.horizontal, showsIndicators: false) {
                content
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: 1040, alignment: .trailing)
            .focusSection()
        }
    }

    // MARK: - Custom Glass Focus Button Style for tvOS

    @available(tvOS 16.0, *)
    private struct PlayerCircleButtonStyle: ButtonStyle {
        var size: CGFloat = 56

        func makeBody(configuration: Configuration) -> some View {
            PlayerCircleButtonBody(configuration: configuration, size: size)
        }

        private struct PlayerCircleButtonBody: View {
            let configuration: Configuration
            let size: CGFloat
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .foregroundStyle(isFocused ? .white : Color.white.opacity(0.85))
                    .frame(width: size, height: size)
                    .background(
                        Circle()
                            .fill(isFocused ? Color.white.opacity(0.35) : Color.white.opacity(0.12))
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                isFocused ? Color.white.opacity(0.9) : Color.white.opacity(0.15),
                                lineWidth: isFocused ? 2.5 : 1
                            )
                    )
                    .shadow(
                        color: isFocused ? Color(hex: "#0A84FF").opacity(0.55) : Color.clear,
                        radius: 12,
                        x: 0,
                        y: 0
                    )
                    .scaleEffect(isFocused ? 1.15 : (configuration.isPressed ? 0.94 : 1.0))
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
                    .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
                    .tvHighContrastFocusOutline(isFocused: isFocused, shape: .circle)
            }
        }
    }

    @available(tvOS 16.0, *)
    private struct PlayerCapsuleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            PlayerCapsuleButtonBody(configuration: configuration)
        }

        private struct PlayerCapsuleButtonBody: View {
            let configuration: Configuration
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .foregroundStyle(isFocused ? .white : Color.white.opacity(0.85))
                    .background(
                        Capsule()
                            .fill(isFocused ? Color.white.opacity(0.35) : Color.white.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isFocused ? Color.white.opacity(0.9) : Color.white.opacity(0.15),
                                lineWidth: isFocused ? 2.5 : 1
                            )
                    )
                    .shadow(
                        color: isFocused ? Color(hex: "#0A84FF").opacity(0.55) : Color.clear,
                        radius: 12,
                        x: 0,
                        y: 0
                    )
                    .scaleEffect(isFocused ? 1.08 : (configuration.isPressed ? 0.95 : 1.0))
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
                    .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
                    .tvHighContrastFocusOutline(isFocused: isFocused, shape: .capsule)
            }
        }
    }

    // MARK: - Video Time Show View (Fluid Scrubber & Continuous Seeking)

    @available(tvOS 16.0, *)
    private struct VideoTimeShowView: View {
        @Bindable var store: StoreOf<PlayerFeature>
        let onInteraction: () -> Void

        @Environment(\.isFocused) private var isFocused
        @State private var isScrubbing: Bool = false
        @State private var scrubValue: Double = 0.0
        @State private var lastMoveTime: Date = .init()
        @State private var consecutiveMoveCount: Int = 0
        @State private var commitTask: Task<Void, Never>?

        var body: some View {
            let durationDouble = Double(store.totalTime.components.seconds)
            let isLive = store.item.isLive && !store.isPlayingCatchup

            if isLive {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(AppStrings.Player.liveBroadcast)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                let currentDisplayPos = isScrubbing ? scrubValue : store.position
                let clampedProgress = min(max(currentDisplayPos, 0), 1)
                let currentDisplaySeconds = isScrubbing ? (durationDouble * clampedProgress) : Double(store.currentTime.components.seconds)

                VStack(spacing: 8) {
                    if isScrubbing, let data = store.scrubThumbnailData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 320, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.white.opacity(0.24), lineWidth: 1)
                            }
                            .accessibilityHidden(true)
                    }
                    // Scrubber Bar & Timestamps
                    HStack(spacing: 16) {
                        Text(formatTime(currentDisplaySeconds))
                            .font(.system(size: isFocused ? 20 : 18, weight: (isFocused || isScrubbing) ? .bold : .medium, design: .monospaced))
                            .foregroundStyle((isFocused || isScrubbing) ? Color(hex: "#5AC8FA") : .white.opacity(0.85))
                            .scaleEffect(isScrubbing ? 1.05 : 1.0)
                            .animation(.easeOut(duration: 0.15), value: isScrubbing)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                // Track background
                                RoundedRectangle(cornerRadius: isFocused ? 7 : 4)
                                    .fill(isFocused ? Color.white.opacity(0.35) : Color.white.opacity(0.2))
                                    .frame(height: isFocused ? 14 : 8)

                                // Active progress fill
                                RoundedRectangle(cornerRadius: isFocused ? 7 : 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#0A84FF"), Color(hex: "#5AC8FA")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: proxy.size.width * clampedProgress, height: isFocused ? 14 : 8)

                                // Glowing thumb indicator
                                if isFocused || isScrubbing {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: isScrubbing ? 26 : 22, height: isScrubbing ? 26 : 22)
                                        .shadow(color: Color(hex: "#0A84FF").opacity(0.9), radius: 10, x: 0, y: 0)
                                        .position(x: proxy.size.width * clampedProgress, y: proxy.size.height / 2)
                                }
                            }
                            .frame(height: isFocused ? 14 : 8)
                            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        }
                        .frame(height: isFocused ? 24 : 12)

                        Text(formatTime(durationDouble))
                            .font(.system(size: isFocused ? 20 : 18, weight: isFocused ? .bold : .medium, design: .monospaced))
                            .foregroundStyle(isFocused ? .white : Color.white.opacity(0.6))
                    }

                    // Scrubber Fluid Navigation Hint / Time Badge
                    if isFocused {
                        HStack(spacing: 12) {
                            if isScrubbing {
                                HStack(spacing: 6) {
                                    Image(systemName: "hand.tap.fill")
                                    Text(AppStrings.Player.scrubInstruction)
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color(hex: "#5AC8FA"))
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text(AppStrings.Common.back)
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))

                                Text("•")
                                    .foregroundStyle(.white.opacity(0.4))

                                Text(AppStrings.Player.scrubSwipe)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color(hex: "#5AC8FA"))

                                Text("•")
                                    .foregroundStyle(.white.opacity(0.4))

                                HStack(spacing: 4) {
                                    Text(AppStrings.Onboarding.next)
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isFocused ? Color.white.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isFocused ? Color.white.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
                .scaleEffect(isFocused ? 1.02 : 1.0)
                .focusable(true)
                .onMoveCommand { direction in
                    onInteraction()
                    handleMove(direction: direction, duration: durationDouble)
                }
                .onTapGesture {
                    onInteraction()
                    commitSeek()
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isScrubbing)
                .onChange(of: isFocused) { _, focused in
                    if !focused, isScrubbing {
                        commitSeek()
                    }
                }
            }
        }

        private func handleMove(direction: MoveCommandDirection, duration: Double) {
            guard duration > 0 else { return }

            let directionMultiplier: Double
            switch direction {
            case .left:
                directionMultiplier = -1
            case .right:
                directionMultiplier = 1
            case .up, .down:
                // Vertical movement belongs to focus navigation, not the scrubber.
                return
            @unknown default:
                return
            }

            let now = Date()
            if now.timeIntervalSince(lastMoveTime) < 0.35 {
                consecutiveMoveCount += 1
            } else {
                consecutiveMoveCount = 1
            }
            lastMoveTime = now

            // Adaptive step calculation: starts fine (5s), dynamically accelerates on rapid movement
            let baseStep: Double = duration > 3600 ? 10.0 : 5.0
            let multiplier: Double = min(Double(consecutiveMoveCount), 8.0)
            let stepSeconds = baseStep * multiplier
            let stepFraction = stepSeconds / duration

            if !isScrubbing {
                isScrubbing = true
                scrubValue = store.position
            }

            scrubValue = min(1.0, max(0.0, scrubValue + (stepFraction * directionMultiplier)))
            store.send(.requestScrubThumbnail(.seconds(duration * scrubValue)))

            // Debounce automatic seek after user pauses movement
            commitTask?.cancel()
            let shouldShowCatchupPreview = store.isPlayingCatchup
            commitTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }

                if shouldShowCatchupPreview {
                    let clock = ContinuousClock()
                    let deadline = clock.now.advanced(by: .seconds(3.3))
                    while store.scrubThumbnailRequestID != nil, clock.now < deadline {
                        try? await Task.sleep(for: .milliseconds(50))
                        guard !Task.isCancelled else { return }
                    }

                    if store.scrubThumbnailData != nil {
                        try? await Task.sleep(for: .milliseconds(350))
                        guard !Task.isCancelled else { return }
                    }
                }

                commitSeek()
            }
        }

        private func commitSeek() {
            commitTask?.cancel()
            commitTask = nil
            if isScrubbing {
                store.send(.seek(scrubValue))
                store.send(.cancelScrubThumbnail)
                isScrubbing = false
                consecutiveMoveCount = 0
            }
        }

        private func formatTime(_ seconds: Double) -> String {
            guard seconds.isFinite, seconds >= 0 else { return "00:00" }
            let hrs = Int(seconds) / 3600
            let mins = (Int(seconds) % 3600) / 60
            let secs = Int(seconds) % 60
            if hrs > 0 {
                return String(format: "%d:%02d:%02d", hrs, mins, secs)
            }
            return String(format: "%02d:%02d", mins, secs)
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
