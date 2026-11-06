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
            GeometryReader { geometry in
                let bannerWidth = geometry.size.width
                let contentWidth = max(0, bannerWidth - 48)

                Button(action: onTap) {
                    ZStack(alignment: .bottomLeading) {
                        DashboardHeroArtworkView(vod: vod, height: 520)
                            .frame(width: bannerWidth)

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
                        .frame(width: bannerWidth, height: 520)

                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.7), location: 0.0),
                                .init(color: .clear, location: 1.0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: bannerWidth, height: 520)

                        // Keep the loaded logo inside the screen's finite width. An unbounded
                        // logo frame can make the whole Button label overflow horizontally.
                        VStack(alignment: .leading, spacing: 12) {
                            TMDBTitleLogoView(
                                path: nil,
                                title: vod.displayTitle,
                                maxWidth: contentWidth,
                                height: 88,
                                fallbackFont: AppFonts.displayLarge,
                                userAgentOverride: vod.userAgentOverride,
                                playlistID: vod.playlistID,
                                cacheKey: vod.presentationOverride?.title == nil
                                    ? TMDBTitleLogoCache.key(for: vod, mediaType: vod.type == .series ? "tv" : "movie")
                                    : nil
                            )

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
                        .frame(width: contentWidth, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    .frame(width: bannerWidth, height: 520, alignment: .bottomLeading)
                }
                .buttonStyle(.fluidScale)
                .frame(width: bannerWidth, height: 520)
            }
            .frame(height: 520)
        }
    }
#endif
