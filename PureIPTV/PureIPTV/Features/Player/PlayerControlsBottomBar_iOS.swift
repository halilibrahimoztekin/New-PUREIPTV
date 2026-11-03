#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI
    import SwiftVLC

    // MARK: - Player Controls Bottom Bar (iOS)

    /// Dedicated subview for center playback transport controls and bottom Live TV action bar.
    public struct PlayerControlsBottomBar_iOS: View {
        @Bindable var store: StoreOf<PlayerFeature>
        let isAnyHUDOrOverlayVisible: Bool

        public init(
            store: StoreOf<PlayerFeature>,
            isAnyHUDOrOverlayVisible: Bool
        ) {
            self.store = store
            self.isAnyHUDOrOverlayVisible = isAnyHUDOrOverlayVisible
        }

        public var body: some View {
            VStack {
                // Center Transport Controls
                HStack(spacing: 28) {
                    // Restart Button
                    if store.totalTime > .zero || store.position > 0 || !store.item.isLive {
                        Button(action: {
                            HapticManager.shared.trigger(.medium)
                            store.send(.restartPlayback)
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(AppFonts.headline)
                                .foregroundColor(AppColors.textPrimary)
                                .padding(14)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                        }
                        .accessibilityLabel("Baştan Başlat")
                    }

                    // Jump Backward
                    if !store.item.isLive || store.isPlayingCatchup {
                        Button(action: {
                            HapticManager.shared.trigger(.light)
                            store.send(.jumpBackward)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "gobackward")
                                    .font(AppFonts.headline)
                                Text(store.activeSkipInterval.compactTitle)
                                    .font(AppFonts.captionBold)
                            }
                            .foregroundColor(AppColors.textPrimary)
                            .padding(16)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                        }
                        .accessibilityLabel(AppStrings.Player.skipBackwardBy(store.activeSkipInterval.compactTitle))
                    }

                    // Play / Pause Button
                    Button(action: {
                        if store.playerState == .playing {
                            store.send(.pause)
                        } else {
                            store.send(.play)
                        }
                    }) {
                        Image(systemName: store.playerState == .playing ? "pause.fill" : "play.fill")
                            .font(AppFonts.displayLarge)
                            .foregroundColor(AppColors.textPrimary)
                            .padding(22)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(AppColors.borderStrong, lineWidth: 1.5))
                    }
                    .accessibilityLabel(store.playerState == .playing ? AppStrings.Player.pausePlayback : AppStrings.Common.play)

                    // Jump Forward
                    if !store.item.isLive || store.isPlayingCatchup {
                        Button(action: {
                            HapticManager.shared.trigger(.light)
                            store.send(.jumpForward)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "goforward")
                                    .font(AppFonts.headline)
                                Text(store.activeSkipInterval.compactTitle)
                                    .font(AppFonts.captionBold)
                            }
                            .foregroundColor(AppColors.textPrimary)
                            .padding(16)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                        }
                        .accessibilityLabel(AppStrings.Player.skipForwardBy(store.activeSkipInterval.compactTitle))
                    }
                }
                .opacity(isAnyHUDOrOverlayVisible ? 0 : 1)
                .allowsHitTesting(!isAnyHUDOrOverlayVisible)
                .animation(.spring(duration: 0.28, bounce: 0.2), value: isAnyHUDOrOverlayVisible)

                Spacer()

                // Live TV Quick Zapping & Recall Bar (for Live streams)
                if store.item.isLive {
                    liveBottomBar
                }
            }
        }

        // MARK: - Live TV Bottom Actions

        private var liveBottomBar: some View {
            HStack {
                // Recording Button
                Button {
                    HapticManager.shared.trigger(.medium)
                    store.send(.toggleRecordingTapped)
                } label: {
                    Image(systemName: store.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(AppFonts.title)
                        .foregroundStyle(AppColors.live)
                }
                .accessibilityLabel(store.isRecording ? AppStrings.Player.stopRecording : AppStrings.Player.startRecording)
                .disabled(store.playerState != .playing || store.isRecordingStartPending || store.isRecordingStopPending)

                if store.isRecording {
                    Label(AppStrings.Player.recordingInProgress, systemImage: "record.circle.fill")
                        .font(AppFonts.captionBold)
                        .foregroundStyle(AppColors.live)
                }

                if store.isPlayingCatchup {
                    Button(action: {
                        HapticManager.shared.trigger(.medium)
                        store.send(.returnToLiveStream)
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppColors.live)
                                .frame(width: 8, height: 8)
                            Text(AppStrings.Player.returnToLive)
                                .font(AppFonts.captionBold)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColors.live.opacity(0.85), in: Capsule())
                    }
                } else if let prev = store.previousChannel {
                    Button(action: {
                        HapticManager.shared.trigger(.medium)
                        store.send(.recallLastChannel)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(AppFonts.titleSmall)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(AppStrings.Player.recallLastChannel)
                                    .font(AppFonts.captionSmall)
                                    .foregroundColor(AppColors.textSecondary)
                                Text(prev.title)
                                    .font(AppFonts.captionBold)
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(AppColors.borderMedium, lineWidth: 1))
                    }
                }

                Spacer()

                if let recordingStatusMessage = store.recordingStatusMessage {
                    Text(recordingStatusMessage)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.textPrimary)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                if store.playlist != nil {
                    channelNavigationButtons
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }

        // MARK: - Channel Navigation Quick Buttons

        private var channelNavigationButtons: some View {
            HStack(spacing: 12) {
                // Category Jump Backward
                Button(action: {
                    HapticManager.shared.trigger(.light)
                    store.send(.jumpToPreviousCategory)
                }) {
                    Image(systemName: "chevron.left.2")
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                }
                .accessibilityLabel("Önceki Kategori")

                // Previous Channel
                Button(action: {
                    HapticManager.shared.trigger(.light)
                    store.send(.previousChannel)
                }) {
                    Image(systemName: "chevron.up")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                }
                .accessibilityLabel("Önceki Kanal")

                // Next Channel
                Button(action: {
                    HapticManager.shared.trigger(.light)
                    store.send(.nextChannel)
                }) {
                    Image(systemName: "chevron.down")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                }
                .accessibilityLabel("Sonraki Kanal")

                // Recent Channels Quick Dock Button
                Button(action: {
                    HapticManager.shared.trigger(.light)
                    store.send(.toggleRecentChannelsHUD, animation: .spring(duration: 0.35, bounce: 0.2))
                }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(AppFonts.headline)
                        .foregroundColor(store.isRecentChannelsHUDVisible ? AppColors.primary : AppColors.textPrimary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                }
                .accessibilityLabel(AppStrings.LiveTV.recentChannels)

                // Channel Dialer Button
                Button(action: {
                    HapticManager.shared.trigger(.light)
                    store.send(.openChannelDialer, animation: .spring(duration: 0.35, bounce: 0.2))
                }) {
                    Image(systemName: "number.square.fill")
                        .font(AppFonts.headline)
                        .foregroundColor(store.isChannelDialerVisible ? AppColors.warningGold : AppColors.textPrimary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                }
                .accessibilityLabel(AppStrings.LiveTV.channelDialerTitle)

                // Category Jump Forward
                Button(action: {
                    HapticManager.shared.trigger(.light)
                    store.send(.jumpToNextCategory)
                }) {
                    Image(systemName: "chevron.right.2")
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                }
                .accessibilityLabel("Sonraki Kategori")
            }
        }
    }
#endif
