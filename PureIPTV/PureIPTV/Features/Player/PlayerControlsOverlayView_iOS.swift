#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI
    import SwiftVLC

    public struct PlayerControlsOverlayView_iOS: View {
        @Bindable var store: StoreOf<PlayerFeature>
        @Binding var pipController: PiPController?
        @Binding var isDraggingSlider: Bool
        @Binding var sliderDragValue: Double
        let isAnyHUDOrOverlayVisible: Bool
        let onClose: () -> Void
        let onMinimize: () -> Void
        let onTriggerAspectFeedback: () -> Void
        let onResetControlsDismissTimer: () -> Void

        public init(
            store: StoreOf<PlayerFeature>,
            pipController: Binding<PiPController?>,
            isDraggingSlider: Binding<Bool>,
            sliderDragValue: Binding<Double>,
            isAnyHUDOrOverlayVisible: Bool,
            onClose: @escaping () -> Void,
            onMinimize: @escaping () -> Void,
            onTriggerAspectFeedback: @escaping () -> Void,
            onResetControlsDismissTimer: @escaping () -> Void
        ) {
            self.store = store
            _pipController = pipController
            _isDraggingSlider = isDraggingSlider
            _sliderDragValue = sliderDragValue
            self.isAnyHUDOrOverlayVisible = isAnyHUDOrOverlayVisible
            self.onClose = onClose
            self.onMinimize = onMinimize
            self.onTriggerAspectFeedback = onTriggerAspectFeedback
            self.onResetControlsDismissTimer = onResetControlsDismissTimer
        }

        public var body: some View {
            VStack {
                // Top Bar Subview
                PlayerControlsTopBar_iOS(
                    store: store,
                    pipController: $pipController,
                    onClose: onClose,
                    onMinimize: onMinimize,
                    onTriggerAspectFeedback: onTriggerAspectFeedback
                )

                Spacer()

                // Transport & Live TV Actions Subview
                PlayerControlsBottomBar_iOS(
                    store: store,
                    isAnyHUDOrOverlayVisible: isAnyHUDOrOverlayVisible
                )

                // Timeline Scrubber Subview (Isolated for high-frequency updates)
                if store.totalTime > .zero || !store.item.isLive {
                    PlayerControlsScrubber_iOS(
                        store: store,
                        isDraggingSlider: $isDraggingSlider,
                        sliderDragValue: $sliderDragValue
                    )
                }
            }
            .padding(.bottom, 24)
            .padding(.top, 8)
            .opacity(isAnyHUDOrOverlayVisible ? 0 : 1)
            .allowsHitTesting(!isAnyHUDOrOverlayVisible)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isAnyHUDOrOverlayVisible)
            .simultaneousGesture(
                TapGesture().onEnded {
                    onResetControlsDismissTimer()
                }
            )
            .background(
                AppColors.background.opacity(0.4)
                    .onTapGesture {
                        store.send(.toggleControls, animation: .spring(response: 0.3, dampingFraction: 0.7))
                    }
            )
            .opacity(store.isDeepDimmed ? 0.35 : 1.0)
            .animation(.easeInOut(duration: 0.35), value: store.isDeepDimmed)
            .transition(.opacity)
        }
    }
#endif
