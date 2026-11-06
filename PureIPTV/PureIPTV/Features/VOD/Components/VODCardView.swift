import Shimmer
import SwiftUI

public struct VODCardView: View {
    let vod: MediaModels.Item
    let isSelected: Bool
    var onTap: (() -> Void)?

    public init(vod: MediaModels.Item, isSelected: Bool = false, onTap: (() -> Void)? = nil) {
        self.vod = vod
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            HapticManager.shared.trigger(.light)
            onTap?()
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Background
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isSelected
                                    ? AppColors.primary.opacity(0.8)
                                    : AppColors.borderSubtle,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                // Poster
                if let posterURL = vod.displayCoverURL {
                    PlaylistPosterArtworkView(
                        url: posterURL,
                        userAgentOverride: vod.userAgentOverride,
                        playlistID: vod.playlistID
                    ) {
                        VODPosterPlaceholder()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    VODPosterPlaceholder()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Bottom gradient overlay
                LinearGradient(
                    colors: [Color.clear, AppColors.oledBlack.opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Language / Audio Badge
                if let tag = MediaLanguageDetector.primaryTag(from: vod.title) {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 3) {
                                Image(systemName: tag.systemIcon)
                                    .font(AppFonts.captionSmall.weight(.bold))
                                Text(tag.label)
                                    .font(AppFonts.captionSmall.weight(.heavy))
                            }
                            .foregroundColor(tag.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppColors.oledBlack.opacity(0.75), in: Capsule())
                            .overlay(Capsule().stroke(tag.color.opacity(0.6), lineWidth: 0.8))
                            .shadow(color: AppColors.oledBlack.opacity(0.5), radius: 3, y: 1)
                            .padding(8)
                        }
                        Spacer()
                    }
                }

                // Title + Rating
                VStack(alignment: .leading, spacing: 4) {
                    TMDBTitleLogoView(
                        path: nil,
                        title: vod.displayTitle,
                        maxWidth: .infinity,
                        height: 50,
                        fallbackFont: cardTitleFont,
                        userAgentOverride: vod.userAgentOverride,
                        playlistID: vod.playlistID,
                        cacheKey: vod.presentationOverride?.title == nil
                            ? TMDBTitleLogoCache.key(for: vod, mediaType: "movie")
                            : nil
                    )

                    if let rating = vod.rating, rating > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                            #if os(tvOS)
                                .font(AppFonts.caption)
                            #else
                                .font(AppFonts.captionSmall)
                            #endif
                                .foregroundColor(AppColors.warningGold)
                            Text(String(format: "%.1f", rating))
                            #if os(tvOS)
                                .font(AppFonts.bodySmall.weight(.semibold))
                            #else
                                .font(AppFonts.captionSemibold)
                            #endif
                                .foregroundStyle(AppColors.onSurfaceVariant)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.oledBlack.opacity(0.88))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppColors.textPrimary.opacity(0.08), lineWidth: 0.7)
                        }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
            .aspectRatio(2 / 3, contentMode: .fit)
        }
        #if os(tvOS)
        .buttonStyle(TVGridCardButtonStyle(cornerRadius: 16))
        #else
        .buttonStyle(.fluidScale)
        #endif
        .shadow(
            color: isSelected ? AppColors.primary.opacity(0.3) : .clear,
            radius: 8, x: 0, y: 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var cardTitleFont: Font {
        #if os(tvOS)
            AppFonts.titleLarge
        #else
            .system(size: 15, weight: .semibold)
        #endif
    }
}

private struct VODPosterPlaceholder: View {
    var body: some View {
        ZStack {
            AppColors.surfaceElevated
            Image(systemName: "film")
                .font(AppFonts.displayMedium.weight(.light))
                .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shimmeringPlaceholder(isLoading: true)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
