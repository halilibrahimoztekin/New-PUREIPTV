import Kingfisher
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
                    .fill(Color(hex: "#1F1F23"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isSelected
                                    ? Color(hex: "#0A84FF").opacity(0.8)
                                    : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                // Poster
                if let posterURL = vod.displayCoverURL {
                    KFImage.url(posterURL, cacheKey: PlaylistArtworkRequest.cacheKey(for: posterURL, userAgentOverride: vod.userAgentOverride, playlistID: vod.playlistID))
                        .requestModifier { request in
                            PlaylistArtworkRequest.applyHeaders(to: &request, userAgentOverride: vod.userAgentOverride, playlistID: vod.playlistID)
                        }
                        .placeholder {
                            VODPosterPlaceholder()
                        }
                        .downsampling(size: CGSize(width: 300, height: 450))
                        .cacheOriginalImage()
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    VODPosterPlaceholder()
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
                if let tag = MediaLanguageDetector.primaryTag(from: vod.title) {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 3) {
                                Image(systemName: tag.systemIcon)
                                    .font(.system(size: 9, weight: .bold))
                                Text(tag.label)
                                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
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
                    Text(vod.displayTitle)
                    #if os(tvOS)
                        .font(.system(size: 18, weight: .bold))
                    #else
                        .font(.system(size: 13, weight: .bold))
                    #endif
                        .foregroundStyle(Color.white)
                        .lineLimit(2)

                    if let rating = vod.rating, rating > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                            #if os(tvOS)
                                .font(.system(size: 13))
                            #else
                                .font(.system(size: 10))
                            #endif
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                            #if os(tvOS)
                                .font(.system(size: 15, weight: .semibold))
                            #else
                                .font(.system(size: 11, weight: .semibold))
                            #endif
                                .foregroundStyle(Color(hex: "#C0C6D6"))
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
            color: isSelected ? Color(hex: "#0A84FF").opacity(0.3) : .clear,
            radius: 8, x: 0, y: 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

private struct VODPosterPlaceholder: View {
    var body: some View {
        ZStack {
            Color(hex: "#2C2C30")
            Image(systemName: "film")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shimmeringPlaceholder(isLoading: true)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
