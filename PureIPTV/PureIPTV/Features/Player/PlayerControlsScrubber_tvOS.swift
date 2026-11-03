#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS Player Controls Scrubber (Fluid Scrubber & Continuous Seeking)

    /// Dedicated, isolated scrubber component for tvOS player controls.
    /// High-frequency playback position updates only invalidate this view, preserving parent layout stability.
    @available(tvOS 16.0, *)
    public struct PlayerControlsScrubber_tvOS: View {
        @Bindable var store: StoreOf<PlayerFeature>
        @FocusState.Binding var focusedField: TVPlayerFocusableField?
        @Binding var isScrubbing: Bool
        let onInteraction: () -> Void

        @Environment(\.isFocused) private var isFocused
        @State private var scrubValue: Double = 0.0
        @State private var lastMoveTime: Date = .init()
        @State private var consecutiveMoveCount: Int = 0
        @State private var commitTask: Task<Void, Never>?

        public init(
            store: StoreOf<PlayerFeature>,
            focusedField: FocusState<TVPlayerFocusableField?>.Binding,
            isScrubbing: Binding<Bool>,
            onInteraction: @escaping () -> Void
        ) {
            self.store = store
            _focusedField = focusedField
            _isScrubbing = isScrubbing
            self.onInteraction = onInteraction
        }

        public var body: some View {
            let durationDouble = Double(store.totalTime.components.seconds)
            let isLive = store.item.isLive && !store.isPlayingCatchup

            if isLive {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppColors.statusLive)
                        .frame(width: 8, height: 8)
                    Text(AppStrings.Player.liveBroadcast)
                        .font(AppFonts.titleSmall)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.8))
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
                                    .stroke(AppColors.textPrimary.opacity(0.24), lineWidth: 1)
                            }
                            .accessibilityHidden(true)
                    }

                    // Scrubber Bar & Timestamps
                    HStack(spacing: 16) {
                        Text(formatTime(currentDisplaySeconds))
                            .font(AppFonts.headlineMedium)
                            .foregroundStyle((isFocused || isScrubbing) ? AppColors.accent : AppColors.textPrimary.opacity(0.85))
                            .scaleEffect(isScrubbing ? 1.05 : 1.0)
                            .animation(.easeOut(duration: 0.15), value: isScrubbing)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                // Track background
                                RoundedRectangle(cornerRadius: isFocused ? 7 : 4)
                                    .fill(isFocused ? AppColors.textPrimary.opacity(0.35) : AppColors.textPrimary.opacity(0.2))
                                    .frame(height: isFocused ? 14 : 8)

                                // Active progress fill
                                RoundedRectangle(cornerRadius: isFocused ? 7 : 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.primary, AppColors.accent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: proxy.size.width * clampedProgress, height: isFocused ? 14 : 8)

                                // Glowing thumb indicator
                                if isFocused || isScrubbing {
                                    Circle()
                                        .fill(AppColors.textPrimary)
                                        .frame(width: isScrubbing ? 26 : 22, height: isScrubbing ? 26 : 22)
                                        .shadow(color: AppColors.primary.opacity(0.9), radius: 10, x: 0, y: 0)
                                        .position(x: proxy.size.width * clampedProgress, y: proxy.size.height / 2)
                                }
                            }
                            .frame(height: isFocused ? 14 : 8)
                            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        }
                        .frame(height: isFocused ? 24 : 12)

                        Text(formatTime(durationDouble))
                            .font(AppFonts.headlineMedium)
                            .foregroundStyle(isFocused ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.6))
                    }

                    // Scrubber Fluid Navigation Hint / Time Badge
                    if isFocused {
                        HStack(spacing: 12) {
                            if isScrubbing {
                                HStack(spacing: 6) {
                                    Image(systemName: "hand.tap.fill")
                                    Text(AppStrings.Player.scrubInstruction)
                                }
                                .font(AppFonts.bodyBold)
                                .foregroundStyle(AppColors.accent)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text(AppStrings.Common.back)
                                }
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textSecondary)

                                Text("•")
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))

                                Text(AppStrings.Player.scrubSwipe)
                                    .font(AppFonts.bodyBold)
                                    .foregroundStyle(AppColors.accent)

                                Text("•")
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))

                                HStack(spacing: 4) {
                                    Text(AppStrings.Onboarding.next)
                                    Image(systemName: "chevron.right")
                                }
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isFocused ? AppColors.textPrimary.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isFocused ? AppColors.textPrimary.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
                .scaleEffect(isFocused ? 1.02 : 1.0)
                .focusable(true)
                .focused($focusedField, equals: .scrubber)
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
#endif
