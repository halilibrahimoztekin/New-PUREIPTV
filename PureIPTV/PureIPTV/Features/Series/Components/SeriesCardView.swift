import Kingfisher
import Shimmer
import SwiftUI

public struct SeriesCardView: View {
    let series: MediaModels.Item
    let isSelected: Bool
    var onTap: (() -> Void)?

    public init(series: MediaModels.Item, isSelected: Bool = false, onTap: (() -> Void)? = nil) {
        self.series = series
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
                if let coverURL = series.displayCoverURL {
                    KFImage.url(coverURL, cacheKey: PlaylistArtworkRequest.cacheKey(for: coverURL, userAgentOverride: series.userAgentOverride, playlistID: series.playlistID))
                        .requestModifier { request in
                            PlaylistArtworkRequest.applyHeaders(to: &request, userAgentOverride: series.userAgentOverride, playlistID: series.playlistID)
                        }
                        .placeholder {
                            SeriesPosterPlaceholder()
                        }
                        .downsampling(size: CGSize(width: 300, height: 450))
                        .cacheOriginalImage()
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    SeriesPosterPlaceholder()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Bottom gradient overlay
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Language / Audio Badge
                if let tag = MediaLanguageDetector.primaryTag(from: series.title) {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 3) {
                                Image(systemName: tag.systemIcon)
                                    .font(AppFonts.captionSmall)
                                Text(tag.label)
                                    .font(AppFonts.captionSmall)
                            }
                            .foregroundColor(tag.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.75), in: Capsule())
                            .overlay(Capsule().stroke(tag.color.opacity(0.6), lineWidth: 0.8))
                            .shadow(color: Color.black.opacity(0.5), radius: 3, y: 1)
                            .padding(8)
                        }
                        Spacer()
                    }
                }

                // Title + Rating
                VStack(alignment: .leading, spacing: 4) {
                    Text(series.displayTitle)
                        .font(AppFonts.bodyBold)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)

                    if let rating = series.rating, rating > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(AppFonts.captionSmall)
                                .foregroundColor(AppColors.warningGold)
                            Text(String(format: "%.1f", rating))
                                .font(AppFonts.captionSmall)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
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
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
    }
}

private struct SeriesPosterPlaceholder: View {
    var body: some View {
        ZStack {
            AppColors.surfaceElevated
            Image(systemName: "rectangle.stack")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppColors.textSecondary.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shimmeringPlaceholder(isLoading: true)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
