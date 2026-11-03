import SwiftUI

// MARK: - Previous Channel Recall HUD View (Madde #10)

public struct PreviousChannelRecallHUDView: View {
    let item: PlayerFeature.PlayableItem
    let onDismiss: () -> Void

    public init(item: PlayerFeature.PlayableItem, onDismiss: @escaping () -> Void) {
        self.item = item
        self.onDismiss = onDismiss
    }

    public var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 14) {
                // Return Icon & Cover
                ZStack {
                    channelCoverView

                    // Floating Utun Icon Badge
                    Circle()
                        .fill(AppColors.warning)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "arrow.uturn.backward")
                                .font(AppFonts.captionSmall)
                                .foregroundStyle(.black)
                        )
                        .offset(x: 16, y: 16)
                }

                // Channel Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(AppStrings.Player.recalledTitle.uppercased())
                            .font(AppFonts.captionBold)
                            .foregroundStyle(AppColors.warning)

                        Text("•")
                            .font(AppFonts.captionSmall)
                            .foregroundStyle(AppColors.textTertiary)

                        Text(AppStrings.Player.quickRecallBadge)
                            .font(AppFonts.captionSmall)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(AppColors.warning.opacity(0.2))
                            .foregroundStyle(AppColors.warning)
                            .clipShape(Capsule())
                    }

                    Text(item.title)
                        .font(AppFonts.titleSmall)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    if let cat = item.categoryID, !cat.isEmpty {
                        Text(cat)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                // Return Arrow Indicator
                Image(systemName: "arrow.left.arrow.right")
                #if os(tvOS)
                    .font(.system(size: 18, weight: .bold))
                #else
                    .font(.system(size: 14, weight: .bold))
                #endif
                    .foregroundStyle(.white.opacity(0.6))
            }
            #if os(tvOS)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: 520)
            #else
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: 380)
            #endif
            .background(
                ZStack {
                    #if os(tvOS)
                        Color.black.opacity(0.85)
                    #else
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                        AppColors.oledBlack.opacity(0.55)
                    #endif
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppColors.amber.opacity(0.6),
                                AppColors.borderSubtle,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: AppColors.amber.opacity(0.3), radius: 16, x: 0, y: 6)
            .shadow(color: AppColors.oledBlack.opacity(0.6), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Channel Cover

    @ViewBuilder
    private var channelCoverView: some View {
        Group {
            if let coverURL = item.coverURL {
                PlaylistAsyncImage(url: coverURL, fallbackURL: item.fallbackCoverURL, userAgentOverride: item.userAgentOverride, playlistID: item.config?.playlistID) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .empty:
                        PureLoadingView(size: .small)
                    case .failure:
                        fallbackIcon
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        #if os(tvOS)
        .frame(width: 48, height: 48)
        #else
        .frame(width: 40, height: 40)
        #endif
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
        )
    }

    private var fallbackIcon: some View {
        Image(systemName: "tv")
            .font(.system(size: 18))
            .foregroundStyle(.white.opacity(0.6))
    }
}
