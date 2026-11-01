import Kingfisher
import SwiftUI
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// AsyncImage-compatible phases backed by a request that includes the
/// playlist's User-Agent and a cache key scoped to that value.
struct PlaylistAsyncImage<Content: View>: View {
    let url: URL?
    let fallbackURL: URL?
    let userAgentOverride: String?
    let playlistID: UUID?
    let downsamplingSize: CGSize?
    let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase = .empty
    @State private var activeURL: URL?
    @State private var activeRequestID = UUID()

    init(
        url: URL?,
        fallbackURL: URL? = nil,
        userAgentOverride: String?,
        playlistID: UUID? = nil,
        downsamplingSize: CGSize? = nil,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.fallbackURL = fallbackURL
        self.userAgentOverride = userAgentOverride
        self.playlistID = playlistID
        self.downsamplingSize = downsamplingSize
        self.content = content
        _activeURL = State(initialValue: url ?? fallbackURL)
    }

    var body: some View {
        let requestID = activeRequestID
        ZStack {
            if let requestURL = activeURL {
                imageLoader(for: requestURL, requestID: requestID)
            }

            content(phase)
        }
        .onChange(of: url) { _, _ in
            resetRequest()
        }
        .onChange(of: fallbackURL) { _, _ in
            resetRequest()
        }
        .onChange(of: userAgentOverride) { _, _ in
            resetRequest()
        }
        .onChange(of: playlistID) { _, _ in
            resetRequest()
        }
    }

    @ViewBuilder
    private func imageLoader(for requestURL: URL, requestID: UUID) -> some View {
        let image = if let downsamplingSize {
            KFImage.url(
                requestURL,
                cacheKey: PlaylistArtworkRequest.cacheKey(for: requestURL, userAgentOverride: userAgentOverride, playlistID: playlistID)
            )
            .downsampling(size: downsamplingSize)
        } else {
            KFImage.url(
                requestURL,
                cacheKey: PlaylistArtworkRequest.cacheKey(for: requestURL, userAgentOverride: userAgentOverride, playlistID: playlistID)
            )
        }
        image
            .requestModifier { request in
                PlaylistArtworkRequest.applyHeaders(to: &request, userAgentOverride: userAgentOverride, playlistID: playlistID)
            }
            .onSuccess { result in
                guard activeRequestID == requestID else { return }
                #if canImport(UIKit)
                    phase = .success(Image(uiImage: result.image))
                #elseif canImport(AppKit)
                    phase = .success(Image(nsImage: result.image))
                #endif
            }
            .onFailure { error in
                guard activeRequestID == requestID else { return }
                if let primaryURL = url,
                   requestURL == primaryURL,
                   let fallbackURL,
                   fallbackURL != requestURL
                {
                    activeRequestID = UUID()
                    activeURL = fallbackURL
                    phase = .empty
                } else {
                    phase = .failure(error)
                }
            }
            .resizable()
            .frame(width: 1, height: 1)
            .opacity(0)
            .accessibilityHidden(true)
    }

    private func resetRequest() {
        activeRequestID = UUID()
        activeURL = url ?? fallbackURL
        phase = .empty
    }
}
