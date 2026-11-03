#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Dashboard Hero Banner View (iOS)

    public struct DashboardHeroBannerView_iOS: View {
        let vod: MediaModels.Item
        let onTap: () -> Void

        public init(vod: MediaModels.Item, onTap: @escaping () -> Void) {
            self.vod = vod
            self.onTap = onTap
        }

        public var body: some View {
            Button(action: onTap) {
                ZStack(alignment: .bottomLeading) {
                    DashboardHeroArtworkView(vod: vod, height: 520)

                    // Premium Gradients for readability and fade
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.0), location: 0.3),
                            .init(color: .black.opacity(0.6), location: 0.7),
                            .init(color: .black, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.7), location: 0.0),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    // Content
                    VStack(alignment: .leading, spacing: 12) {
                        Text(vod.title)
                            .font(AppFonts.displayLarge)
                            .lineSpacing(-2)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 4)

                        // Tags (Rating, Year, etc.)
                        HStack(spacing: 12) {
                            if let rating = vod.rating, rating > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill").foregroundColor(AppColors.warningGold)
                                    Text(String(format: "%.1f", rating))
                                        .fontWeight(.bold)
                                }
                            }

                            Text(AppStrings.Dashboard.hdBadge)
                                .font(AppFonts.captionSmall.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.5), lineWidth: 1))

                            Text(AppStrings.Dashboard.movieBadge)
                                .fontWeight(.semibold)
                        }
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textSecondary)

                        // Action Buttons using Liquid Glass Design System
                        LiquidGlassContainer(spacing: 16) {
                            HStack(spacing: 16) {
                                LiquidGlassActionButton(
                                    AppStrings.Common.watchNow,
                                    icon: "play.fill",
                                    style: .primary,
                                    action: onTap
                                )

                                LiquidGlassActionButton(
                                    AppStrings.Dashboard.details,
                                    icon: "info.circle",
                                    style: .secondary,
                                    action: onTap
                                )
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                }
            }
            .buttonStyle(.fluidScale)
        }
    }
#endif
