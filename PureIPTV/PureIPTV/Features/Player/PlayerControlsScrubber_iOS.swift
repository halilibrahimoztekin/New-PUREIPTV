#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Player Controls Scrubber (iOS)

    /// Dedicated subview for playback scrubber and timeline.
    /// Narrow invalidation boundary: High-frequency time updates (250ms) only re-render this isolated component.
    public struct PlayerControlsScrubber_iOS: View {
        @Bindable var store: StoreOf<PlayerFeature>
        @Binding var isDraggingSlider: Bool
        @Binding var sliderDragValue: Double

        public init(
            store: StoreOf<PlayerFeature>,
            isDraggingSlider: Binding<Bool>,
            sliderDragValue: Binding<Double>
        ) {
            self.store = store
            _isDraggingSlider = isDraggingSlider
            _sliderDragValue = sliderDragValue
        }

        public var body: some View {
            VStack {
                HStack(spacing: 12) {
                    let currentDisplayPosition = isDraggingSlider ? sliderDragValue : store.position
                    let currentDisplayDuration = isDraggingSlider
                        ? Duration.seconds(Double(store.totalTime.components.seconds) * currentDisplayPosition)
                        : store.currentTime

                    Text(formatDuration(currentDisplayDuration))
                        .font(AppFonts.caption.monospacedDigit())
                        .foregroundColor(AppColors.textPrimary)

                    Slider(
                        value: Binding(
                            get: { currentDisplayPosition },
                            set: { newValue in
                                sliderDragValue = newValue
                            }
                        ),
                        in: 0 ... 1,
                        onEditingChanged: { editing in
                            Task { @MainActor in
                                isDraggingSlider = editing
                                if !editing {
                                    store.send(.seek(sliderDragValue))
                                }
                            }
                        }
                    )
                    .tint(AppColors.primary)

                    Text(formatDuration(store.totalTime))
                        .font(AppFonts.caption.monospacedDigit())
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.horizontal)

                PlayerSkipMarkersControls(store: store) {
                    HapticManager.shared.trigger(.light)
                }
                .frame(maxWidth: .infinity)
            }
        }

        private func formatDuration(_ duration: Duration) -> String {
            let totalSeconds = Int(duration.components.seconds)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60

            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }
    }
#endif
