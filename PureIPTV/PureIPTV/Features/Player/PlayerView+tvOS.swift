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
                .onMoveCommand { _ in
                    showMask()
                }
                .onContinuousHover { _ in
                    showMask()
                }
        }

        // MARK: - Controller View (KSPlayer Layout)

        private func controllerView(playerWidth _: Double) -> some View {
            VStack(spacing: 16) {
                Spacer()

                // Top part of controls: Title + Action Buttons
                VideoControllerView(store: store, onInteraction: {
                    resetIdleTimer()
                })

                // Bottom part of controls: Interactive Fluid Scrubber + Time Display
                if isMaskShow {
                    VideoTimeShowView(store: store, onInteraction: {
                        resetIdleTimer()
                    })
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
                                    Text(AppStrings.Player.off)
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
            let isLive = durationDouble <= 0

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

            switch direction {
            case .left:
                scrubValue = max(0.0, scrubValue - stepFraction)
            case .right:
                scrubValue = min(1.0, scrubValue + stepFraction)
            default:
                break
            }

            // Debounce automatic seek after user pauses movement
            commitTask?.cancel()
            commitTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                if !Task.isCancelled {
                    commitSeek()
                }
            }
        }

        private func commitSeek() {
            commitTask?.cancel()
            commitTask = nil
            if isScrubbing {
                store.send(.seek(scrubValue))
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
#endif
