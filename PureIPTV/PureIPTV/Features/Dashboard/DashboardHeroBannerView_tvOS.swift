#if os(tvOS)
    import SwiftUI

    // MARK: - tvOS Dashboard Hero Banner

    /// High-impact 10-foot hero banner for featured movies and premiere series on Apple TV.
    /// Utilizes Liquid Glass styling and native Siri Remote focus scale dynamics.
    public struct DashboardHeroBannerView_tvOS: View {
        public let vod: MediaModels.Item
        public let onTap: () -> Void

        @Environment(\.isFocused) private var isFocused

        public init(vod: MediaModels.Item, onTap: @escaping () -> Void) {
            self.vod = vod
            self.onTap = onTap
        }

        public var body: some View {
            Button(action: onTap) {
                ZStack(alignment: .bottomLeading) {
                    DashboardHeroArtworkView(vod: vod, height: 600)

                    // Premium Obsidian Gradient
                    LinearGradient(
                        stops: [
                            .init(color: AppColors.oledBlack.opacity(0.0), location: 0.0),
                            .init(color: AppColors.oledBlack.opacity(0.5), location: 0.6),
                            .init(color: AppColors.oledBlack.opacity(0.95), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Hero Metadata & Action Trigger
                    VStack(alignment: .leading, spacing: 16) {
                        Text(vod.title)
                            .font(AppFonts.displayLarge)
                            .tracking(-1.0)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(2)
                            .shadow(color: AppColors.oledBlack.opacity(0.6), radius: 8, x: 0, y: 4)

                        if let rating = vod.rating, rating > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(AppColors.warningGold)
                                Text(String(format: "%.1f", rating))
                            }
                            .font(AppFonts.title)
                            .foregroundStyle(AppColors.textPrimary)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                            Text(AppStrings.Common.watchNow)
                        }
                        .font(AppFonts.button)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .liquidGlass(shape: .capsule, surfaceColor: AppColors.oledBlack.opacity(0.4))
                    }
                    .padding(60)
                }
            }
            .tvFocusEffect()
        }
    }
#endif
