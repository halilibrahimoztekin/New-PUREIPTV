#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI
    import SwiftVLC

    // MARK: - tvOS Player Controls Top Bar (Header & Actions)

    /// Dedicated, isolated top bar component for tvOS player controls.
    /// Provides narrow invalidation boundaries so playback scrubber updates do not re-render menus and title header.
    @available(tvOS 16.0, *)
    public struct PlayerControlsTopBar_tvOS: View {
        @Bindable var store: StoreOf<PlayerFeature>
        @FocusState.Binding var focusedField: TVPlayerFocusableField?
        let onInteraction: () -> Void
        let onSubtitleSearch: () -> Void

        public init(
            store: StoreOf<PlayerFeature>,
            focusedField: FocusState<TVPlayerFocusableField?>.Binding,
            onInteraction: @escaping () -> Void,
            onSubtitleSearch: @escaping () -> Void
        ) {
            self.store = store
            _focusedField = focusedField
            self.onInteraction = onInteraction
            self.onSubtitleSearch = onSubtitleSearch
        }

        public var body: some View {
            HStack(alignment: .center, spacing: 20) {
                // Title, Series Subtitle & Live Badges
                titleHeaderSection

                Spacer(minLength: 24)

                // Sleek, fixed-size transport controls and contextual menus
                actionsSection
            }
        }

        // MARK: - Title Header Section

        private var titleHeaderSection: some View {
            VStack(alignment: .leading, spacing: 4) {
                if let seriesTitle = store.item.seriesTitle, !seriesTitle.isEmpty {
                    Text(seriesTitle)
                        .font(AppFonts.titleSmall)
                        .foregroundStyle(AppColors.accent)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    Text(store.item.title)
                        .font(AppFonts.displayMedium)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if store.isPlayingCatchup {
                        Button {
                            onInteraction()
                            store.send(.returnToLiveStream)
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(AppColors.statusLive)
                                    .frame(width: 8, height: 8)
                                Text(AppStrings.Player.returnToLive)
                                    .font(AppFonts.bodyBold)
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(AppColors.statusLive.opacity(0.85))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(TVPlayerCapsuleButtonStyle())
                    } else if store.item.isLive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppColors.statusLive)
                                .frame(width: 8, height: 8)
                            Text(AppStrings.Player.liveLabel)
                                .font(AppFonts.bodyBold)
                                .foregroundStyle(AppColors.statusLive)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.textPrimary.opacity(0.15))
                        .clipShape(Capsule())
                    }

                    if store.playerState == .buffering {
                        PureLoadingView(size: .small)
                            .padding(.leading, 4)
                    }
                }

                if let recordingStatusMessage = store.recordingStatusMessage {
                    Text(recordingStatusMessage)
                        .font(AppFonts.bodyBold)
                        .foregroundStyle(AppColors.statusLive)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        // MARK: - Actions Section

        private var actionsSection: some View {
            HStack(spacing: 18) {
                if store.totalTime > .zero || store.position > 0 || !store.item.isLive {
                    Button {
                        onInteraction()
                        store.send(.restartPlayback)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(AppFonts.headlineMedium)
                    }
                    .buttonStyle(TVPlayerCircleButtonStyle(size: 56))
                    .focused($focusedField, equals: .restart)
                }

                if !store.item.isLive || store.isPlayingCatchup {
                    Button {
                        onInteraction()
                        store.send(.jumpBackward)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gobackward")
                            Text(store.activeSkipInterval.compactTitle)
                                .font(AppFonts.captionSmall)
                        }
                        .font(AppFonts.headlineMedium)
                    }
                    .buttonStyle(TVPlayerCircleButtonStyle(size: 56))
                    .focused($focusedField, equals: .backward)
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
                                .font(AppFonts.body)
                        }
                        .font(AppFonts.titleSmall)
                    }
                    .buttonStyle(TVPlayerCircleButtonStyle(size: 56))
                    .focused($focusedField, equals: .replayWithSubtitles)
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
                        .font(AppFonts.displayMedium)
                }
                .buttonStyle(TVPlayerCircleButtonStyle(size: 64))
                .focused($focusedField, equals: .playPause)
                .accessibilityLabel(store.playerState == .playing ? AppStrings.Player.pausePlayback : AppStrings.Common.play)

                if !store.item.isLive || store.isPlayingCatchup {
                    Button {
                        onInteraction()
                        store.send(.jumpForward)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "goforward")
                            Text(store.activeSkipInterval.compactTitle)
                                .font(AppFonts.captionSmall)
                        }
                        .font(AppFonts.headlineMedium)
                    }
                    .buttonStyle(TVPlayerCircleButtonStyle(size: 56))
                    .focused($focusedField, equals: .forward)
                    .accessibilityLabel(AppStrings.Player.skipForwardBy(store.activeSkipInterval.compactTitle))
                }

                if !store.item.isLive {
                    PlayerSkipMarkersControls(store: store, onInteraction: onInteraction)
                }

                if store.item.isLive {
                    liveChannelsMenu
                }

                if !store.audioTracks.isEmpty || !store.subtitleTracks.isEmpty || (!store.item.isLive && store.playbackEngine == .vlc) {
                    audioSubtitleMenu
                }

                moreOptionsMenu
            }
            .fixedSize(horizontal: true, vertical: false)
            .focusSection()
        }

        // MARK: - Live Channels Menu

        private var liveChannelsMenu: some View {
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
                        store.send(.toggleChannelList, animation: .spring(duration: 0.32, bounce: 0.2))
                    } label: {
                        Label(AppStrings.LiveTV.channelsTitle, systemImage: "sidebar.leading")
                    }
                }

                if store.item.isLive {
                    Button {
                        onInteraction()
                        store.send(.toggleEPG, animation: .spring(duration: 0.3, bounce: 0.2))
                    } label: {
                        Label(AppStrings.LiveTV.channelGuide, systemImage: "list.bullet.rectangle")
                    }
                }

                Button {
                    onInteraction()
                    store.send(.toggleRecentChannelsHUD, animation: .spring(duration: 0.35, bounce: 0.2))
                } label: {
                    Label(AppStrings.LiveTV.recentChannels, systemImage: "clock.arrow.circlepath")
                }

                if store.playlist != nil {
                    Button {
                        onInteraction()
                        store.send(.openChannelDialer, animation: .spring(duration: 0.35, bounce: 0.2))
                    } label: {
                        Label(AppStrings.LiveTV.channelDialerTitle, systemImage: "number.square.fill")
                    }
                }
            } label: {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(AppFonts.headlineMedium)
            }
            .buttonStyle(TVPlayerCircleButtonStyle(size: 56))
            .focused($focusedField, equals: .liveChannelsMenu)
            .accessibilityLabel(AppStrings.LiveTV.title)
        }

        // MARK: - Audio & Subtitle Tracks Menu

        private var audioSubtitleMenu: some View {
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
                                            .font(AppFonts.caption)
                                            .foregroundStyle(AppColors.textSecondary)
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
                    .font(AppFonts.headlineMedium)
            }
            .buttonStyle(TVPlayerCircleButtonStyle(size: 56))
            .focused($focusedField, equals: .audioSubtitleMenu)
            .accessibilityLabel(AppStrings.Player.tracks)
        }

        // MARK: - More Options Menu

        private var moreOptionsMenu: some View {
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
                            store.send(.toggleAudioEQHUD, animation: .spring(duration: 0.35, bounce: 0.2))
                        } label: {
                            Label("Ses Ekolayzer & Diyalog (\(store.audioEQPreset.title))", systemImage: "waveform.badge.magnifyingglass")
                        }

                        Button {
                            onInteraction()
                            store.send(.toggleAudioSyncHUD, animation: .spring(duration: 0.35, bounce: 0.2))
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
                        store.send(.toggleStreamHealthHUD, animation: .spring(duration: 0.32, bounce: 0.2))
                    } label: {
                        Label(AppStrings.Player.streamHealthTitle, systemImage: "waveform.path.ecg")
                    }

                    Button {
                        onInteraction()
                        store.send(.toggleStats, animation: .spring(duration: 0.32, bounce: 0.2))
                    } label: {
                        Label(AppStrings.Player.technicalDetails, systemImage: "chart.xyaxis.line")
                    }

                    Button {
                        onInteraction()
                        store.send(.togglePiP, animation: .spring(duration: 0.35, bounce: 0.2))
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
                        store.send(.toggleCatchupTimeline, animation: .spring(duration: 0.35, bounce: 0.2))
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
                    .font(AppFonts.headlineMedium)
            }
            .buttonStyle(TVPlayerCircleButtonStyle(size: 56))
            .focused($focusedField, equals: .displayModeMenu)
            .accessibilityLabel(AppStrings.Common.more)
        }
    }
#endif
