import ComposableArchitecture
import FactoryKit
import SwiftUI
import SwiftVLC

public struct DockedMiniPlayerView: View {
    @Bindable var store: StoreOf<PlayerFeature>
    public let onExpand: () -> Void
    public let onClose: () -> Void

    @Injected(\.playerClient) private var playerClient
    @State private var dragOffset: CGSize = .zero

    public init(
        store: StoreOf<PlayerFeature>,
        onExpand: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.store = store
        self.onExpand = onExpand
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Video Preview Box
            ZStack {
                #if os(iOS)
                    PiPVideoView(playerClient.vlcPlayer(), controller: .constant(nil))
                #else
                    VideoView(playerClient.vlcPlayer())
                #endif
            }
            .frame(width: 96, height: 54)
            .cornerRadius(10)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            )

            // Metadata Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if store.item.isLive {
                        Circle()
                            .fill(AppColors.live)
                            .frame(width: 6, height: 6)
                        Text(AppStrings.Player.liveLabel)
                            .font(AppFonts.captionSmall.weight(.heavy))
                            .foregroundStyle(AppColors.live)
                    } else {
                        Text(AppStrings.Player.miniPlayer.uppercased())
                            .font(AppFonts.captionSmall.weight(.bold))
                            .foregroundStyle(AppColors.primary)
                    }
                }

                Text(store.item.title)
                    .font(AppFonts.bodyMedium.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                if let subtitle = store.item.seriesTitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppFonts.captionSmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Control Buttons
            HStack(spacing: 10) {
                // Play / Pause Button
                Button(action: {
                    HapticManager.shared.trigger(.light)
                    if store.playerState == .playing {
                        store.send(.pause)
                    } else {
                        store.send(.play)
                    }
                }) {
                    if store.isReconnecting {
                        PureLoadingView(size: .small)
                            .frame(width: 36, height: 36)
                            .background(AppColors.surfaceSecondary, in: Circle())
                    } else {
                        Image(systemName: store.playerState == .playing ? "pause.fill" : "play.fill")
                            .font(AppFonts.titleSmall.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.surfaceSecondary, in: Circle())
                    }
                }
                .buttonStyle(.plain)

                // Close Button
                Button(action: {
                    HapticManager.shared.trigger(.medium)
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .font(AppFonts.captionBold)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(AppColors.surfaceSecondary.opacity(0.6), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [AppColors.borderSubtle.opacity(0.8), AppColors.borderSubtle.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: AppColors.background.opacity(0.4), radius: 16, x: 0, y: 8)
        )
        .offset(dragOffset)
        #if os(iOS)
            .gesture(dismissDragGesture)
        #endif
            .onTapGesture {
                HapticManager.shared.trigger(.light)
                onExpand()
            }
    }

    #if os(iOS)
        private var dismissDragGesture: some Gesture {
            DragGesture()
                .onChanged { value in
                    let translation = value.translation
                    if translation.height > 0 || translation.width > 0 {
                        dragOffset = CGSize(width: max(0, translation.width), height: max(0, translation.height))
                    }
                }
                .onEnded { value in
                    if value.translation.height > 60 || value.translation.width > 80 {
                        HapticManager.shared.trigger(.medium)
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = CGSize(width: 0, height: 200)
                        }
                        onClose()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            dragOffset = .zero
                        }
                    }
                }
        }
    #endif
}
