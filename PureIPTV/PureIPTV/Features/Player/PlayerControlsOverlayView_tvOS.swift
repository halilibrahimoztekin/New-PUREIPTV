#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct PlayerControlsOverlayView_tvOS: View {
        @Bindable var store: StoreOf<PlayerFeature>
        @FocusState.Binding var focusableField: TVPlayerFocusableField?
        @Binding var isScrubbing: Bool
        let isMaskShow: Bool
        let isUpNextCardVisible: Bool
        let playerHeight: CGFloat
        let onInteraction: () -> Void
        let onSubtitleSearch: () -> Void
        let onDismissUpNext: () -> Void
        let onPlayUpNext: () -> Void

        public init(
            store: StoreOf<PlayerFeature>,
            focusableField: FocusState<TVPlayerFocusableField?>.Binding,
            isScrubbing: Binding<Bool>,
            isMaskShow: Bool,
            isUpNextCardVisible: Bool,
            playerHeight: CGFloat,
            onInteraction: @escaping () -> Void,
            onSubtitleSearch: @escaping () -> Void,
            onDismissUpNext: @escaping () -> Void,
            onPlayUpNext: @escaping () -> Void
        ) {
            self.store = store
            _focusableField = focusableField
            _isScrubbing = isScrubbing
            self.isMaskShow = isMaskShow
            self.isUpNextCardVisible = isUpNextCardVisible
            self.playerHeight = playerHeight
            self.onInteraction = onInteraction
            self.onSubtitleSearch = onSubtitleSearch
            self.onDismissUpNext = onDismissUpNext
            self.onPlayUpNext = onPlayUpNext
        }

        @ViewBuilder
        private var upNextCountdownCard: some View {
            if !store.item.isLive, store.isUpNextVisible, let nextItem = store.nextEpisodeItem {
                HStack {
                    Spacer()
                    UpNextCountdownOverlayView(
                        item: nextItem,
                        countdownSeconds: store.upNextCountdownSeconds,
                        totalSeconds: store.upNextInitialSeconds,
                        onPlayNow: onPlayUpNext,
                        onDismiss: onDismissUpNext
                    )
                    .padding(.trailing, 80)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.spring(response: 0.38, dampingFraction: 0.8), value: store.isUpNextVisible)
            }
        }

        private let overlayGradient = LinearGradient(
            stops: [
                Gradient.Stop(color: AppColors.background.opacity(0), location: 0.0),
                Gradient.Stop(color: AppColors.background.opacity(0.4), location: 0.3),
                Gradient.Stop(color: AppColors.background.opacity(0.85), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        public var body: some View {
            VStack(spacing: 16) {
                Spacer()

                // Top part of controls: Title + Action Buttons
                if isMaskShow {
                    PlayerControlsTopBar_tvOS(
                        store: store,
                        focusedField: $focusableField,
                        onInteraction: onInteraction,
                        onSubtitleSearch: onSubtitleSearch
                    )
                    .padding(.horizontal, 80)
                    .accessibilityHidden(store.errorMessage != nil && !store.isReconnecting)
                    .opacity(store.isDeepDimmed ? 0.35 : 1)
                }

                // Keep Up Next in the controls stack so it sits above the scrubber.
                upNextCountdownCard

                // Bottom part of controls: Interactive Fluid Scrubber + Time Display
                if isMaskShow {
                    PlayerControlsScrubber_tvOS(
                        store: store,
                        focusedField: $focusableField,
                        isScrubbing: $isScrubbing,
                        onInteraction: onInteraction
                    )
                    .padding(.horizontal, 80)
                    .accessibilityHidden(store.errorMessage != nil && !store.isReconnecting)
                    .opacity(store.isDeepDimmed ? 0.35 : 1)
                }
            }
            .padding(.bottom, isMaskShow ? 60 : max(180, playerHeight * 0.2))
            .background {
                if isMaskShow {
                    overlayGradient
                        .opacity(store.isDeepDimmed ? 0.35 : 1)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: store.isDeepDimmed)
        }
    }
#endif
