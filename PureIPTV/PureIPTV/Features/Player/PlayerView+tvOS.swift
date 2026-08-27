#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI
    import SwiftVLC

    // MARK: - tvOS Player View

    // Enhanced tvOS player with:
    // - Siri Remote play/pause via Menu/PlayPause buttons
    // - Scrubber bar for VOD/Movie content
    // - Audio/Subtitle track selection
    // - Idle timer for auto-hiding controls
    // - EPG overlay for Live TV

    public struct PlayerView_tvOS: View {
        @Bindable var store: StoreOf<PlayerFeature>

        @State private var idleTimer: Timer?
        @State private var showControls = true

        public var body: some View {
            ZStack {
                // Video Layer (handled by PlayerContainerView in parent)
                Color.black.ignoresSafeArea()

                // Controls Overlay
                if showControls {
                    controlsOverlay
                        .transition(.opacity)
                }

                // Buffering indicator
                if store.playerState == .buffering {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2.0)
                }
            }
            .onPlayPauseCommand {
                if store.playerState == .playing {
                    store.send(.pause)
                } else {
                    store.send(.play)
                }
                resetIdleTimer()
            }
            .onMoveCommand { _ in
                showControls = true
                resetIdleTimer()
            }
            .onExitCommand {
                if showControls {
                    showControls = false
                } else {
                    store.send(.closeTapped)
                }
            }
            .onAppear {
                resetIdleTimer()
            }
            .onDisappear {
                idleTimer?.invalidate()
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showControls)
        }

        // MARK: – Controls Overlay

        private var controlsOverlay: some View {
            ZStack {
                // Dimming background
                Color.black.opacity(0.5).ignoresSafeArea()

                VStack {
                    // ── Top Bar ──────────────────────────────────
                    topBar
                        .padding(.horizontal, 60)
                        .padding(.top, 40)

                    Spacer()

                    // ── Center Controls ──────────────────────────
                    centerControls

                    Spacer()

                    // ── Bottom Bar (Scrubber) ────────────────────
                    bottomBar
                        .padding(.horizontal, 60)
                        .padding(.bottom, 40)
                }

                // ── EPG Overlay ──────────────────────────────────
                if store.isEPGVisible {
                    HStack {
                        Spacer()
                        EPGListView(
                            programs: store.epgListings,
                            currentPosition: store.position,
                            onClose: { store.send(.toggleEPG, animation: .easeInOut) }
                        )
                        .frame(width: 500)
                        .padding(.trailing, 60)
                    }
                }

                // ── Tracks Menu ──────────────────────────────────
                if store.isTracksMenuVisible {
                    tracksMenu
                }
            }
        }

        // MARK: – Top Bar

        private var topBar: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.item.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if store.item.epgChannelID != nil {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("CANLI")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 20) {
                    // EPG Button (Live TV only)
                    if let _ = store.item.epgChannelID, !store.epgListings.isEmpty {
                        Button {
                            store.send(.toggleEPG, animation: .easeInOut)
                        } label: {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(
                                    Circle()
                                        .fill(store.isEPGVisible ? Color.white.opacity(0.3) : Color.white.opacity(0.15))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // Tracks Button
                    if !store.audioTracks.isEmpty || !store.subtitleTracks.isEmpty {
                        Button {
                            store.send(.toggleTracksMenu, animation: .easeInOut)
                        } label: {
                            Image(systemName: "textformat.subscript")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(
                                    Circle()
                                        .fill(store.isTracksMenuVisible ? Color.white.opacity(0.3) : Color.white.opacity(0.15))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // Close Button
                    Button {
                        store.send(.closeTapped)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        // MARK: – Center Controls

        private var centerControls: some View {
            HStack(spacing: 60) {
                // Jump Backward
                Button {
                    store.send(.jumpBackward)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                // Play / Pause
                Button {
                    if store.playerState == .playing {
                        store.send(.pause)
                    } else {
                        store.send(.play)
                    }
                } label: {
                    Image(systemName: store.playerState == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                        .padding(28)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
                .buttonStyle(.plain)

                // Jump Forward
                Button {
                    store.send(.jumpForward)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }

        // MARK: – Bottom Bar (Scrubber)

        private var bottomBar: some View {
            VStack(spacing: 12) {
                let durationDouble = Double(store.totalTime.components.seconds)

                // Progress Bar
                GeometryReader { proxy in
                    let totalWidth = proxy.size.width
                    let progress = durationDouble > 0 ? CGFloat(store.position / durationDouble) : 0

                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 6)

                        // Filled
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "#0A84FF"))
                            .frame(width: totalWidth * progress, height: 6)
                    }
                }
                .frame(height: 6)

                // Time labels
                HStack {
                    Text(formatTime(Double(store.currentTime.components.seconds)))
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(formatTime(durationDouble))
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
        }

        // MARK: – Tracks Menu

        private var tracksMenu: some View {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Audio tracks
                    if !store.audioTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ses")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.top, 16)

                            ForEach(store.audioTracks) { track in
                                Button {
                                    store.send(.selectAudioTrack(track))
                                } label: {
                                    HStack {
                                        Text(track.name)
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        if track.isSelected {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color(hex: "#0A84FF"))
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Subtitle tracks
                    if !store.subtitleTracks.isEmpty {
                        Divider().background(Color.white.opacity(0.1)).padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Altyazı")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)

                            Button {
                                store.send(.selectSubtitleTrack(nil))
                            } label: {
                                HStack {
                                    Text("Kapalı")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    if !store.subtitleTracks.contains(where: { $0.isSelected }) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color(hex: "#0A84FF"))
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            ForEach(store.subtitleTracks) { track in
                                Button {
                                    store.send(.selectSubtitleTrack(track))
                                } label: {
                                    HStack {
                                        Text(track.name)
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        if track.isSelected {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color(hex: "#0A84FF"))
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(width: 400)
                .padding(.bottom, 100)
            }
        }

        // MARK: – Helpers

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

        private func resetIdleTimer() {
            showControls = true
            idleTimer?.invalidate()
            idleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                withAnimation {
                    showControls = false
                }
            }
        }
    }
#endif
