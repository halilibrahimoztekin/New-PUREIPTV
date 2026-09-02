#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI
    import SwiftVLC

    // MARK: - tvOS Player View (KSPlayer Architecture)

    @available(tvOS 16.0, *)
    public struct PlayerView_tvOS: View {
        @Bindable var store: StoreOf<PlayerFeature>

        @FocusState private var focusableField: FocusableField?
        @State private var isMaskShow: Bool = true
        @State private var idleTimer: Timer?

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

                    controllerView(playerWidth: proxy.size.width)
                        .ignoresSafeArea()

                    // EPG Overlay
                    if store.isEPGVisible {
                        VStack {
                            Spacer()
                            PlayerEPGTimelineView(
                                programs: store.epgListings,
                                currentPosition: store.position,
                                onClose: {
                                    store.send(.toggleEPG, animation: .spring(response: 0.3, dampingFraction: 0.7))
                                    resetIdleTimer()
                                },
                                onSelect: { program in
                                    store.send(.playArchive(program))
                                    resetIdleTimer()
                                }
                            )
                            .padding(.horizontal, 60)
                            .padding(.bottom, 60)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .preferredColorScheme(.dark)
            .tint(.white)
            .onPlayPauseCommand {
                if store.playerState == .playing {
                    store.send(.pause)
                } else {
                    store.send(.play)
                }
                showMask()
            }
            .onExitCommand {
                if store.isEPGVisible {
                    store.send(.toggleEPG, animation: .spring(response: 0.3, dampingFraction: 0.7))
                    resetIdleTimer()
                } else if isMaskShow {
                    hideMask()
                } else {
                    store.send(.closeTapped)
                }
            }
            .onAppear {
                showMask()
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
                    showMask()
                }
                .onMoveCommand { direction in
                    switch direction {
                    case .left:
                        store.send(.jumpBackward)
                        showMask()
                    case .right:
                        store.send(.jumpForward)
                        showMask()
                    case .up, .down:
                        showMask()
                    @unknown default:
                        showMask()
                    }
                }
        }

        // MARK: - Controller View (KSPlayer Layout)

        private func controllerView(playerWidth _: Double) -> some View {
            VStack(spacing: 20) {
                Spacer()

                // Top part of controls: Title + Action Buttons
                VideoControllerView(store: store, onInteraction: {
                    resetIdleTimer()
                })

                // Bottom part of controls: Scrubber + Time Display
                if isMaskShow {
                    VideoTimeShowView(store: store)
                        .onAppear {
                            focusableField = .controller
                        }
                        .onDisappear {
                            focusableField = .play
                        }
                }
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 60)
            .background(overlayGradient)
            .focused($focusableField, equals: .controller)
            .opacity(isMaskShow ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: isMaskShow)
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
            idleTimer?.invalidate()
            idleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                Task { @MainActor in
                    if !store.isEPGVisible {
                        hideMask()
                    }
                }
            }
        }
    }

    // MARK: - Video Controller View (Header & Action Buttons)

    @available(tvOS 16.0, *)
    private struct VideoControllerView: View {
        @Bindable var store: StoreOf<PlayerFeature>
        let onInteraction: () -> Void

        var body: some View {
            HStack(alignment: .center, spacing: 16) {
                // Title & Live Badge
                HStack(spacing: 12) {
                    Text(store.item.title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .layoutPriority(3)

                    if store.item.epgChannelID != nil {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("CANLI")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }

                if store.playerState == .buffering {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .padding(.leading, 8)
                }

                Spacer()
                    .layoutPriority(2)

                // Buttons Group (KSPlayer Style with Custom Smooth Glass Highlight)
                HStack(spacing: 18) {
                    // Jump Backward
                    Button {
                        onInteraction()
                        store.send(.jumpBackward)
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .buttonStyle(PlayerCircleButtonStyle(size: 56))

                    // Play / Pause
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

                    // Jump Forward
                    Button {
                        onInteraction()
                        store.send(.jumpForward)
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    .buttonStyle(PlayerCircleButtonStyle(size: 56))

                    // Audio Tracks
                    if !store.audioTracks.isEmpty {
                        Menu {
                            ForEach(store.audioTracks) { track in
                                Button {
                                    onInteraction()
                                    store.send(.selectAudioTrack(track))
                                } label: {
                                    HStack {
                                        Text(track.name)
                                        if store.selectedAudioTrack?.id == track.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 26))
                        }
                        .buttonStyle(PlayerCircleButtonStyle(size: 56))
                    }

                    // Subtitle Tracks
                    if !store.subtitleTracks.isEmpty {
                        Menu {
                            Button {
                                onInteraction()
                                store.send(.selectSubtitleTrack(nil))
                            } label: {
                                HStack {
                                    Text("Kapalı")
                                    if store.selectedSubtitleTrack == nil {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            ForEach(store.subtitleTracks) { track in
                                Button {
                                    onInteraction()
                                    store.send(.selectSubtitleTrack(track))
                                } label: {
                                    HStack {
                                        Text(track.name)
                                        if store.selectedSubtitleTrack?.id == track.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "captions.bubble.fill")
                                .font(.system(size: 26))
                        }
                        .buttonStyle(PlayerCircleButtonStyle(size: 56))
                    }

                    // EPG Button (Live TV)
                    if let _ = store.item.epgChannelID, !store.epgListings.isEmpty {
                        Button {
                            onInteraction()
                            store.send(.toggleEPG, animation: .spring(response: 0.3, dampingFraction: 0.7))
                        } label: {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 24))
                        }
                        .buttonStyle(PlayerCircleButtonStyle(size: 56))
                    }
                }
            }
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
            }
        }
    }

    // MARK: - Video Time Show View (Scrubber & Duration)

    @available(tvOS 16.0, *)
    private struct VideoTimeShowView: View {
        @Bindable var store: StoreOf<PlayerFeature>

        var body: some View {
            let durationDouble = Double(store.totalTime.components.seconds)
            let currentDouble = Double(store.currentTime.components.seconds)

            HStack(spacing: 16) {
                Text(formatTime(currentDouble))
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)

                GeometryReader { proxy in
                    let progress = durationDouble > 0 ? CGFloat(store.position / durationDouble) : 0

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "#0A84FF"))
                            .frame(width: proxy.size.width * min(max(progress, 0), 1), height: 8)
                    }
                    .frame(height: 8)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                .frame(height: 8)

                Text(formatTime(durationDouble))
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .font(.system(.title3))
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
#endif
