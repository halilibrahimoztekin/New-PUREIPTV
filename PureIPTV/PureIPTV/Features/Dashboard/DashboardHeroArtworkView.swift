import ComposableArchitecture
import SwiftUI

struct DashboardHeroArtworkView: View {
    let vod: MediaModels.Item
    let height: CGFloat

    @Dependency(\.tmdbClient) private var tmdbClient
    @State private var tmdbBackdropURL: URL?

    private var requestID: String {
        [vod.playlistID?.uuidString ?? "", vod.type.rawValue, vod.id, vod.title, vod.releaseDate ?? ""]
            .joined(separator: "|")
    }

    var body: some View {
        ZStack {
            providerArtworkFallback

            if let tmdbBackdropURL {
                AsyncImage(url: tmdbBackdropURL) { phase in
                    if let image = phase.image {
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
        .animation(.easeInOut(duration: 0.25), value: tmdbBackdropURL)
        .task(id: requestID) {
            tmdbBackdropURL = nil
            let resolvedURL = await resolveTMDBBackdropURL()
            guard !Task.isCancelled else { return }
            tmdbBackdropURL = resolvedURL
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
                    playlistID: vod.playlistID
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

    private var atmosphericFallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#273247"), Color(hex: "#0F0F13")],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            RadialGradient(
                colors: [Color(hex: "#0A84FF").opacity(0.24), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: max(height, 1)
            )
        }
    }

    private func resolveTMDBBackdropURL() async -> URL? {
        do {
            let response: TMDBSearchResponseDTO
            switch vod.type {
            case .vod:
                response = try await tmdbClient.searchMovie(vod.title)
            case .series:
                response = try await tmdbClient.searchTV(vod.title)
            case .live:
                return nil
            }

            guard !Task.isCancelled else { return nil }
            let targetTitle = normalized(vod.title)
            guard !targetTitle.isEmpty else { return nil }
            let targetYear = yearPrefix(vod.releaseDate)

            let result = response.results?.first { candidate in
                guard let backdropPath = candidate.backdropPath, !backdropPath.isEmpty else { return false }
                let titles = [candidate.title, candidate.name, candidate.originalTitle, candidate.originalName]
                    .compactMap { $0 }
                guard titles.contains(where: { normalized($0) == targetTitle }) else { return false }

                guard let targetYear,
                      let candidateYear = yearPrefix(candidate.releaseDate ?? candidate.firstAirDate)
                else { return true }
                return targetYear == candidateYear
            }

            guard let path = result?.backdropPath else { return nil }
            return URL(string: "https://image.tmdb.org/t/p/w1280\(path)")
        } catch {
            return nil
        }
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .filter { $0.isLetter || $0.isNumber }
    }

    private func yearPrefix(_ value: String?) -> String? {
        guard let value else { return nil }
        let year = String(value.prefix(4))
        return year.count == 4 && year.allSatisfy(\.isNumber) ? year : nil
    }
}
