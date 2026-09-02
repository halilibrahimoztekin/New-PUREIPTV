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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#1F1F23"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isSelected
                                    ? Color(hex: "#0A84FF").opacity(0.7)
                                    : Color.white.opacity(0.06),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )

                // Poster
                if let posterURL = vod.coverURL {
                    KFImage(posterURL)
                        .placeholder {
                            VODPosterPlaceholder()
                        }
                        .downsampling(size: CGSize(width: 300, height: 450))
                        .cacheOriginalImage()
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    VODPosterPlaceholder()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Bottom gradient overlay
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.8)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Title + Rating
                VStack(alignment: .leading, spacing: 4) {
                    Text(vod.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)

                    if let rating = vod.rating, rating > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(hex: "#C0C6D6"))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
            .aspectRatio(2 / 3, contentMode: .fit)
        }
        .buttonStyle(.fluidScale)
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
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shimmeringPlaceholder(isLoading: true)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
