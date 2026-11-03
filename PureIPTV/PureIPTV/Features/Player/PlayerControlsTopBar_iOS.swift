#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI
    import SwiftVLC

    // MARK: - Player Controls Top Bar (iOS)

    /// Dedicated subview for player top bar actions, title, and consolidated settings menu.
    /// Isolated to avoid re-rendering during periodic currentTime playback updates.
    public struct PlayerControlsTopBar_iOS: View {
        @Bindable var store: StoreOf<PlayerFeature>
        @Binding var pipController: PiPController?
        let onClose: () -> Void
        let onMinimize: () -> Void
        let onTriggerAspectFeedback: () -> Void

        public init(
            store: StoreOf<PlayerFeature>,
            pipController: Binding<PiPController?>,
            onClose: @escaping () -> Void,
            onMinimize: @escaping () -> Void,
            onTriggerAspectFeedback: @escaping () -> Void
        ) {
            self.store = store
            _pipController = pipController
            self.onClose = onClose
            self.onMinimize = onMinimize
            self.onTriggerAspectFeedback = onTriggerAspectFeedback
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    // Primary Window Controls (Close & Minimize)
                    HStack(spacing: 10) {
                        Button(action: {
                            HapticManager.shared.trigger(.light)
                            onClose()
                        }) {
                            Image(systemName: "xmark")
                                .font(AppFonts.captionBold)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                        }
                        .accessibilityLabel(AppStrings.Common.close)

                        Button(action: {
                            guard !store.isMinimized else { return }
                            HapticManager.shared.trigger(.medium)
                            onMinimize()
                        }) {
                            Image(systemName: "chevron.down")
                                .font(AppFonts.captionBold)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                        }
                        .disabled(store.isMinimized)
                        .accessibilityLabel("Küçült")
                    }

                    Spacer()

                    // Primary Quick Actions + Consolidated Settings Menu
                    HStack(spacing: 10) {
                        // Live Channels Drawer Button (Zapping)
                        if store.item.isLive, store.playlist != nil {
                            Button(action: {
                                HapticManager.shared.trigger(.light)
                                store.send(.toggleChannelList, animation: .spring(duration: 0.3, bounce: 0.2))
                            }) {
                                Image(systemName: "list.dash")
                                    .font(AppFonts.captionBold)
                                    .foregroundColor(AppColors.textPrimary)
                                    .frame(width: 38, height: 38)
                                    .background(
                                        store.isChannelListVisible
                                            ? AnyShapeStyle(AppColors.primary.opacity(0.85))
                                            : AnyShapeStyle(.ultraThinMaterial),
                                        in: Circle()
                                    )
                                    .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                            }
                            .accessibilityLabel(AppStrings.LiveTV.categories)
                        }

                        // EPG Quick Button
                        if store.item.isLive, store.item.epgChannelID != nil, !store.epgListings.isEmpty {
                            Button(action: {
                                HapticManager.shared.trigger(.light)
                                store.send(.toggleEPG, animation: .spring(duration: 0.3, bounce: 0.2))
                            }) {
                                Image(systemName: "list.bullet.rectangle")
                                    .font(AppFonts.captionBold)
                                    .foregroundColor(AppColors.textPrimary)
                                    .frame(width: 38, height: 38)
                                    .background(
                                        store.isEPGVisible
                                            ? AnyShapeStyle(AppColors.primary.opacity(0.85))
                                            : AnyShapeStyle(.ultraThinMaterial),
                                        in: Circle()
                                    )
                                    .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                            }
                            .accessibilityLabel(AppStrings.EPG.guide)
                        }

                        // Audio and Subtitle Tracks Menu
                        if !store.audioTracks.isEmpty || !store.subtitleTracks.isEmpty {
                            Button {
                                HapticManager.shared.trigger(.light)
                                store.send(.toggleTracksMenu, animation: .spring(duration: 0.3, bounce: 0.2))
                            } label: {
                                Image(systemName: "captions.bubble")
                                    .font(AppFonts.captionBold)
                                    .foregroundColor(AppColors.textPrimary)
                                    .frame(width: 38, height: 38)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                            }
                            .accessibilityLabel(AppStrings.Player.tracks)
                        }

                        // PiP Button
                        if store.playbackEngine == .vlc, pipController?.isPossible == true {
                            Button(action: {
                                HapticManager.shared.trigger(.light)
                                if store.isPiPActive {
                                    pipController?.stop()
                                } else {
                                    _ = pipController?.start()
                                }
                            }) {
                                Image(systemName: store.isPiPActive ? "pip.exit" : "pip.enter")
                                    .font(AppFonts.captionBold)
                                    .foregroundColor(AppColors.textPrimary)
                                    .frame(width: 38, height: 38)
                                    .background(
                                        store.isPiPActive
                                            ? AnyShapeStyle(AppColors.primary.opacity(0.85))
                                            : AnyShapeStyle(.ultraThinMaterial),
                                        in: Circle()
                                    )
                                    .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                            }
                            .accessibilityLabel("Resim içinde Resim")
                        }

                        // Screen Lock Button
                        Button(action: {
                            HapticManager.shared.trigger(.medium)
                            store.send(.toggleScreenLock)
                        }) {
                            Image(systemName: store.isScreenLocked ? "lock.fill" : "lock.open.fill")
                                .font(AppFonts.captionBold)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(width: 38, height: 38)
                                .background(
                                    store.isScreenLocked
                                        ? AnyShapeStyle(AppColors.primary.opacity(0.9))
                                        : AnyShapeStyle(.ultraThinMaterial),
                                    in: Circle()
                                )
                                .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
                        }
                        .accessibilityLabel(store.isScreenLocked ? "Ekran Kilidini Aç" : "Ekranı Kilitle")

                        // AirPlay Route Picker
                        AirPlayButton(size: 38)

                        // Consolidated Player Settings Menu
                        settingsMenu
                    }
                }

                // Channel / Movie Title
                Text(store.item.title)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
                    .padding(.leading, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }

        // MARK: - Consolidated Settings Menu

        private var settingsMenu: some View {
            Menu {
                let castCoordinator = GoogleCastPlaybackCoordinator.shared
                if castCoordinator.canCast(item: store.item, streamURL: store.activePlaybackURL) {
                    Button {
                        let castStore = store
                        let castItem = store.item
                        let canResumeLocally = store.playerState == .playing
                        let time = store.currentTime.components
                        let startingPosition = Double(time.seconds) + Double(time.attoseconds) / 1_000_000_000_000_000_000
                        castCoordinator.cast(
                            item: castItem,
                            streamURL: store.activePlaybackURL,
                            startingPosition: startingPosition,
                            onRemotePlaybackStarted: { [weak castStore] in
                                guard castStore?.item.id == castItem.id else { return }
                                castStore?.send(.pause)
                            },
                            onSessionEnded: { [weak castStore] in
                                guard canResumeLocally,
                                      castStore?.item.id == castItem.id,
                                      castStore?.playerState == .paused
                                else { return }
                                castStore?.send(.play)
                            }
                        )
                    } label: {
                        Label(AppStrings.VODDetail.cast, systemImage: "airplayvideo")
                    }
                }

                if store.canSwitchPlaybackEngine || store.canManagePlaybackEnginePreference {
                    Menu {
                        if store.canSwitchPlaybackEngine {
                            ForEach(PlaybackEngine.allCases, id: \.self) { engine in
                                Button {
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
                                        store.send(.saveCurrentPlaybackEnginePreference)
                                    }
                                    .disabled(store.isSwitchingPlaybackEngine)
                                }
                                if store.itemSpecificPlaybackEnginePreference != nil {
                                    Button(AppStrings.Player.useGeneralPlaybackEnginePreference) {
                                        store.send(.clearCurrentPlaybackEnginePreference)
                                    }
                                    .disabled(store.isSwitchingPlaybackEngine)
                                }
                            }
                        }
                    } label: {
                        Label("\(AppStrings.Player.playbackEngine): \(store.playbackEngine.title)", systemImage: "cpu")
                    }
                }

                // Playback Speed (VOD & Series)
                if store.canSetPlaybackRate {
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

                // Aspect Ratio / Zoom Mode
                Menu {
                    ForEach(VideoAspectRatioMode.allCases, id: \.self) { mode in
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.setVideoAspectRatioMode(mode))
                            onTriggerAspectFeedback()
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

                // Sleep Timer
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

                // Share Stream Link
                if store.item.config?.type != .plex, store.item.config?.type != .emby {
                    Menu {
                        ShareLink(
                            item: store.item.streamURL,
                            subject: Text(store.item.title),
                            message: Text("PureIPTV: \(store.item.title)")
                        ) {
                            Label(AppStrings.Player.share, systemImage: "square.and.arrow.up")
                        }

                        Button {
                            UIPasteboard.general.string = store.item.streamURL.absoluteString
                            HapticManager.shared.trigger(.success)
                        } label: {
                            Label("Bağlantıyı Kopyala", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Label(AppStrings.Player.share, systemImage: "square.and.arrow.up")
                    }
                }

                // Recent Channels Quick Dock
                if store.item.isLive {
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.toggleRecentChannelsHUD, animation: .spring(duration: 0.35, bounce: 0.2))
                    } label: {
                        Label(AppStrings.LiveTV.recentChannels, systemImage: "clock.arrow.circlepath")
                    }

                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.openChannelDialer, animation: .spring(duration: 0.35, bounce: 0.2))
                    } label: {
                        Label(AppStrings.LiveTV.channelDialerTitle, systemImage: "number.square.fill")
                    }
                }

                // Catchup / Timeshift TV Archive Timeline
                if store.item.tvArchive == 1 {
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.toggleCatchupTimeline, animation: .spring(duration: 0.35, bounce: 0.2))
                    } label: {
                        Label(AppStrings.Player.catchupTimelineTitle, systemImage: "calendar.badge.clock")
                    }
                }

                // Lip-Sync & Audio Delay Adjustment
                if store.playbackEngine == .vlc {
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.toggleAudioSyncHUD, animation: .spring(duration: 0.35, bounce: 0.2))
                    } label: {
                        Label(AppStrings.Player.lipSyncAdjustment, systemImage: "slider.horizontal.2.square")
                    }
                }

                // Live Stream Audio Equalizer & Dialogue Enhancer
                if store.playbackEngine == .vlc {
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.toggleAudioEQHUD, animation: .spring(duration: 0.35, bounce: 0.2))
                    } label: {
                        Label("Ses Ekolayzer & Diyalog (\(store.audioEQPreset.title))", systemImage: "waveform.badge.magnifyingglass")
                    }
                }

                // Stream Health Quality HUD
                Button {
                    HapticManager.shared.trigger(.light)
                    store.send(.toggleStreamHealthHUD, animation: .spring(duration: 0.35, bounce: 0.2))
                } label: {
                    Label(AppStrings.Player.streamHealthTitle, systemImage: "waveform.path.ecg")
                }

                // Technical Diagnostics (Nerd Stats)
                Button {
                    HapticManager.shared.trigger(.light)
                    store.send(.toggleInfo, animation: .spring(duration: 0.3, bounce: 0.2))
                } label: {
                    Label(store.isInfoVisible ? AppStrings.Player.hideTechnicalDetails : AppStrings.Player.technicalDetails, systemImage: "info.circle")
                }

                // SharePlay
                if store.item.config?.type != .plex, store.item.config?.type != .emby {
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.sharePlayTapped)
                    } label: {
                        Label("SharePlay", systemImage: "shareplay")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(AppFonts.captionBold)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1))
            }
            .accessibilityLabel(AppStrings.Common.more)
        }
    }
#endif
