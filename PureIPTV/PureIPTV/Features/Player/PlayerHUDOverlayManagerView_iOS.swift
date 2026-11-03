#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI
    import SwiftVLC

    public struct PlayerHUDOverlayManagerView_iOS: View {
        @Bindable var store: StoreOf<PlayerFeature>
        let interactiveZappingDirection: ZappingDirection?

        public init(
            store: StoreOf<PlayerFeature>,
            interactiveZappingDirection: ZappingDirection? = nil
        ) {
            self.store = store
            self.interactiveZappingDirection = interactiveZappingDirection
        }

        public var body: some View {
            ZStack {
                // Gesture Feedback Overlay
                if let feedback = store.gestureFeedback {
                    Text(feedback)
                        .font(AppFonts.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.gestureFeedback)
                }

                // Sleep Timer Fading Notification (Feature #6)
                if store.isSleepFadingActive {
                    VStack {
                        HStack(spacing: 8) {
                            Image(systemName: "moon.stars.fill")
                                .font(AppFonts.caption.weight(.semibold))
                                .foregroundStyle(AppColors.premium)
                            Text(AppStrings.Player.sleepTimerFading)
                                .font(AppFonts.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .background(AppColors.surface.opacity(0.85))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppColors.premium.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: AppColors.premium.opacity(0.3), radius: 8, x: 0, y: 3)
                        .padding(.top, 40)

                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.35), value: store.isSleepFadingActive)
                    .zIndex(105)
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
                            isCommitted: store.item.id == zappingItem.id,
                            currentProgram: store.item.id == zappingItem.id ? store.currentEPGProgram : nil,
                            nextProgram: store.item.id == zappingItem.id ? store.nextEPGProgram : nil,
                            isCleaningEnabled: store.isChannelNameCleaningEnabled
                        )
                        .padding(.top, 36)
                        Spacer()
                    }
                    .transition(.move(edge: direction == .next ? .top : .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isZappingHUDVisible)
                    .zIndex(85)
                }

                // Dynamic Range Indicator HUD (HDR / Dolby Vision / SDR) (Madde #20)
                if store.isDynamicRangeHUDVisible, let drInfo = store.dynamicRangeInfo {
                    VStack {
                        HStack {
                            Spacer()
                            DynamicRangeHUDView(info: drInfo)
                                .padding(.top, 40)
                                .padding(.trailing, 20)
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
                                .padding(.top, 40)
                                .padding(.trailing, 20)
                        }
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: store.isAFRToastVisible)
                    .zIndex(97)
                }

                // Mini EPG Overlay (Madde #15: Swipe Down / Up for Mini EPG)
                if store.isEPGVisible {
                    ZStack(alignment: .bottom) {
                        AppColors.background.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture {
                                HapticManager.shared.trigger(.light)
                                store.send(.toggleEPG, animation: .spring(response: 0.35, dampingFraction: 0.75))
                            }

                        PlayerEPGTimelineView(
                            programs: store.epgBrowseListings,
                            currentPosition: store.position,
                            hasArchive: store.epgBrowseChannel?.tvArchive == 1,
                            channels: store.liveChannels,
                            selectedChannel: store.epgBrowseChannel,
                            playingChannelID: store.item.id,
                            isLoading: store.isEPGBrowseLoading,
                            canSelectPrograms: store.epgBrowseChannel?.id == store.item.id,
                            onClose: {
                                HapticManager.shared.trigger(.light)
                                store.send(.toggleEPG, animation: .spring(response: 0.35, dampingFraction: 0.75))
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
                            nextProgram: store.nextEPGProgram,
                            isCleaningEnabled: store.isChannelNameCleaningEnabled,
                            dynamicRange: store.videoDynamicRange,
                            playlistName: store.sourcePlaylistName
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
                    ZStack {
                        AppColors.background.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                store.send(.setRecentChannelsHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                            }

                        VStack {
                            Spacer()
                            RecentChannelsHUDView(store: store) {
                                store.send(.setRecentChannelsHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isRecentChannelsHUDVisible)
                    .zIndex(98)
                }

                // Lip-Sync & Subtitle Sync HUD
                if store.isAudioSyncHUDVisible {
                    ZStack {
                        AppColors.background.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture {
                                store.send(.setAudioSyncHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                            }

                        AudioSyncHUDView(store: store) {
                            store.send(.setAudioSyncHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                        }
                        .padding(.horizontal, 16)
                    }
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isAudioSyncHUDVisible)
                    .zIndex(99)
                }

                // Live Stream Audio Equalizer & Dialogue Enhancer HUD (Madde #14)
                if store.isAudioEQHUDVisible {
                    ZStack {
                        AppColors.background.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture {
                                store.send(.setAudioEQHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                            }

                        AudioEQHUDView(store: store) {
                            store.send(.setAudioEQHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                        }
                        .padding(.horizontal, 16)
                    }
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isAudioEQHUDVisible)
                    .zIndex(100)
                }

                // Catchup / Archive Timeline Visual Scrubber Overlay (Feature #4)
                if store.isCatchupTimelineVisible {
                    ZStack {
                        AppColors.background.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                store.send(.setCatchupTimelineVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                            }

                        VStack {
                            Spacer()
                            CatchupTimelineScrubberView(
                                store: store,
                                onClose: {
                                    store.send(.setCatchupTimelineVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isCatchupTimelineVisible)
                    .zIndex(99)
                }

                if let message = store.catchupSeekFailureMessage {
                    VStack {
                        Text(message)
                            .font(AppFonts.captionMedium)
                            .foregroundStyle(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                    }
                    .padding(.top, 48)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(101)
                }

                // Stream Health & Buffer Diagnostics (Feature #3)
                if store.isStreamHealthHUDVisible {
                    ZStack {
                        AppColors.background.opacity(0.2)
                            .ignoresSafeArea()
                            .onTapGesture {
                                store.send(.setStreamHealthHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                            }

                        VStack {
                            HStack {
                                Spacer()
                                StreamHealthHUDView(
                                    store: store,
                                    onClose: {
                                        store.send(.setStreamHealthHUDVisible(false), animation: .spring(response: 0.35, dampingFraction: 0.8))
                                    }
                                )
                                .padding(.trailing, 16)
                                .padding(.top, 64)
                                .padding(.bottom, 24)
                            }
                            Spacer()
                        }
                    }
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isStreamHealthHUDVisible)
                    .zIndex(100)
                }

                // Technical Diagnostics (Nerd Stats)
                if store.isInfoVisible {
                    ZStack {
                        AppColors.background.opacity(0.2)
                            .ignoresSafeArea()
                            .onTapGesture {
                                store.send(.toggleInfo, animation: .spring(response: 0.3, dampingFraction: 0.7))
                            }

                        VStack {
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
                                    streamHealthMetrics: store.streamHealthMetrics,
                                    serverPlaybackStatus: store.mediaServerPlaybackStatus,
                                    onClose: {
                                        store.send(.toggleInfo, animation: .spring(response: 0.3, dampingFraction: 0.7))
                                    }
                                )
                                .padding(.trailing, 16)
                                .padding(.top, 64)
                                .padding(.bottom, 24)
                            }
                            Spacer()
                        }
                    }
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.isInfoVisible)
                    .zIndex(100)
                }

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
                if !store.item.isLive, store.isUpNextVisible, let nextItem = store.nextEpisodeItem {
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

                // Instant Previous Channel Quick-Recall HUD (Madde #10)
                if store.isRecallHUDVisible, let prev = store.recalledChannelItem {
                    VStack {
                        PreviousChannelRecallHUDView(item: prev) {
                            store.send(.hideRecallHUD)
                        }
                        .padding(.top, 24)

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
                        store.send(.userInteracted)
                    }
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isChannelDialerVisible)
                    .zIndex(140)
                }
            }
        }
    }
#endif
