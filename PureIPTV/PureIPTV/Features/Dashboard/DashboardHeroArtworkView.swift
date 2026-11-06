import ComposableArchitecture
import SwiftUI

struct DashboardHeroArtworkView: View {
    let vod: MediaModels.Item
    let height: CGFloat

    @Dependency(\.tmdbClient) private var tmdbClient
    @Environment(\.displayScale) private var displayScale
    @State private var tmdbBackdropURL: URL?
    @ObservedObject private var cachedArtwork: TMDBTitleLogo

    init(vod: MediaModels.Item, height: CGFloat) {
        self.vod = vod
        self.height = height
        _cachedArtwork = ObservedObject(wrappedValue: TMDBTitleLogoCache.shared.logo(for: Self.cacheKey(for: vod)))
    }

    private static func cacheKey(for vod: MediaModels.Item) -> String {
        TMDBTitleLogoCache.key(for: vod, mediaType: vod.type == .series ? "tv" : "movie")
    }

    private var requestID: String {
        [vod.playlistID?.uuidString ?? "", vod.type.rawValue, vod.id, vod.title, vod.releaseDate ?? ""]
            .joined(separator: "|")
    }

    var body: some View {
        let resolvedBackdropURL = tmdbBackdropURL ?? TMDBImageURL.make(path: cachedArtwork.backdropPath, size: .w1280)
        ZStack {
            providerArtworkFallback

            if let resolvedBackdropURL {
                PlaylistAsyncImage(
                    url: resolvedBackdropURL,
                    userAgentOverride: vod.userAgentOverride,
                    playlistID: vod.playlistID,
                    downsamplingSize: backdropDownsamplingSize
                ) { phase in
                    if case let .success(image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: height)
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: resolvedBackdropURL)
        .onChange(of: cachedArtwork.backdropPath) { _, newPath in
            tmdbBackdropURL = TMDBImageURL.make(path: newPath, size: .w1280)
        }
        .task(id: requestID) {
            let cachedURL = TMDBImageURL.make(path: cachedArtwork.backdropPath, size: .w1280)
            tmdbBackdropURL = cachedURL

            let cacheKey = Self.cacheKey(for: vod)
            if cachedArtwork.path != nil || cachedArtwork.didResolveTitleAssets {
                return
            }

            guard let assets = await resolveTMDBHeroAssets() else { return }
            guard !Task.isCancelled else { return }
            TMDBTitleLogoCache.shared.insert(assets.logoPath, for: cacheKey)
            TMDBTitleLogoCache.shared.insertBackdrop(assets.backdropPath, for: cacheKey)
            if assets.didResolveImages {
                TMDBTitleLogoCache.shared.markTitleAssetsResolved(for: cacheKey)
            }
            if let path = assets.backdropPath {
                tmdbBackdropURL = TMDBImageURL.make(path: path, size: .w1280)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var providerArtworkFallback: some View {
        Group {
            if let coverURL = vod.coverURL {
                PlaylistAsyncImage(
                    url: coverURL,
                    userAgentOverride: vod.userAgentOverride,
                    playlistID: vod.playlistID,
                    downsamplingSize: backdropDownsamplingSize
                ) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 26)
                            .scaleEffect(1.12)
                    } else {
                        atmosphericFallback
                    }
                }
            } else {
                atmosphericFallback
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var backdropDownsamplingSize: CGSize {
        // Backdrops are 16:9; bound decoding to the requested TMDB w1280 asset and
        // the actual banner height so a 4K source is never decoded at original size.
        CGSize(
            width: min(1280, height * displayScale * 16 / 9),
            height: min(720, height * displayScale)
        )
    }

    private var atmosphericFallback: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.surfaceElevated, AppColors.background],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            RadialGradient(
                colors: [AppColors.primary.opacity(0.24), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: max(height, 1)
            )
        }
    }

    private func resolveTMDBHeroAssets() async -> TMDBHeroAssets? {
        do {
            let response: TMDBSearchResponseDTO
            let searchTitle = vod.title.cleanedForTMDBSearch()
            switch vod.type {
            case .vod:
                response = try await tmdbClient.searchMovie(searchTitle)
            case .series:
                response = try await tmdbClient.searchTV(searchTitle)
            case .live:
                return nil
            }

            guard !Task.isCancelled else { return nil }
            let match = TMDBSearchMatchSelector.bestMatch(
                in: response.results ?? [],
                providerTitle: vod.title,
                providerReleaseDate: vod.releaseDate
            )
            guard let match else {
                return TMDBHeroAssets(logoPath: nil, backdropPath: nil, didResolveImages: true)
            }

            do {
                switch vod.type {
                case .vod:
                    let images = try await tmdbClient.fetchMovieImages(match.id)
                    return TMDBHeroAssets(
                        logoPath: images.preferredTitleLogoPath,
                        backdropPath: match.backdropPath ?? images.backdrops?.first?.filePath,
                        didResolveImages: true
                    )
                case .series:
                    let images = try await tmdbClient.fetchTVImages(match.id)
                    return TMDBHeroAssets(
                        logoPath: images.preferredTitleLogoPath,
                        backdropPath: match.backdropPath ?? images.backdrops?.first?.filePath,
                        didResolveImages: true
                    )
                case .live:
                    return nil
                }
            } catch {
                return TMDBHeroAssets(
                    logoPath: nil,
                    backdropPath: match.backdropPath,
                    didResolveImages: false
                )
            }
        } catch {
            return nil
        }
    }
}

private struct TMDBHeroAssets {
    let logoPath: String?
    let backdropPath: String?
    let didResolveImages: Bool
}
