import SwiftUI

/// Displays a TMDB title logo when available and keeps the localized title readable as fallback.
struct TMDBTitleLogoView: View {
    let path: String?
    let backdropPath: String?
    let title: String
    let maxWidth: CGFloat
    let height: CGFloat
    let fallbackFont: Font
    let userAgentOverride: String?
    let playlistID: UUID?
    var cacheKey: String?

    @Environment(\.displayScale) private var displayScale
    @ObservedObject private var cachedLogo: TMDBTitleLogo

    init(
        path: String?,
        backdropPath: String? = nil,
        title: String,
        maxWidth: CGFloat,
        height: CGFloat,
        fallbackFont: Font,
        userAgentOverride: String?,
        playlistID: UUID?,
        cacheKey: String? = nil
    ) {
        self.path = path
        self.backdropPath = backdropPath
        self.title = title
        self.maxWidth = maxWidth
        self.height = height
        self.fallbackFont = fallbackFont
        self.userAgentOverride = userAgentOverride
        self.playlistID = playlistID
        self.cacheKey = cacheKey
        _cachedLogo = ObservedObject(wrappedValue: TMDBTitleLogoCache.shared.logo(for: cacheKey))
    }

    var body: some View {
        let resolvedPath = path ?? cachedLogo.path
        GeometryReader { geometry in
            Group {
                if let url = TMDBImageURL.make(path: resolvedPath, size: .w500) {
                    PlaylistAsyncImage(
                        url: url,
                        userAgentOverride: userAgentOverride,
                        playlistID: playlistID,
                        downsamplingSize: CGSize(
                            width: max(geometry.size.width * displayScale, 1),
                            height: max(geometry.size.height * displayScale, 1)
                        )
                    ) { phase in
                        if case let .success(image) = phase {
                            image
                                .resizable()
                                .scaledToFit()
                        } else {
                            fallbackTitle
                        }
                    }
                } else {
                    fallbackTitle
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityLabel(title)
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
        .frame(height: height, alignment: .leading)
        .onChange(of: path) { _, newPath in
            TMDBTitleLogoCache.shared.insert(newPath, for: cacheKey)
        }
        .onChange(of: backdropPath) { _, newPath in
            TMDBTitleLogoCache.shared.insertBackdrop(newPath, for: cacheKey)
        }
        .onAppear {
            TMDBTitleLogoCache.shared.insert(path, for: cacheKey)
            TMDBTitleLogoCache.shared.insertBackdrop(backdropPath, for: cacheKey)
        }
    }

    private var fallbackTitle: some View {
        Text(title)
            .font(fallbackFont)
            .foregroundStyle(AppColors.textPrimary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: maxWidth, maxHeight: .infinity, alignment: .leading)
    }
}
