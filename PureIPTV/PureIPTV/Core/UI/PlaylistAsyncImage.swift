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
    let userAgentOverride: String?
    let playlistID: UUID?
    let content: (AsyncImagePhase) -> Content
    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL?,
        userAgentOverride: String?,
        playlistID: UUID? = nil,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.userAgentOverride = userAgentOverride
        self.playlistID = playlistID
        self.content = content
    }

    var body: some View {
        ZStack {
            if let url {
                KFImage.url(
                    url,
                    cacheKey: PlaylistArtworkRequest.cacheKey(for: url, userAgentOverride: userAgentOverride, playlistID: playlistID)
                )
                .requestModifier { request in
                    PlaylistArtworkRequest.applyHeaders(to: &request, userAgentOverride: userAgentOverride, playlistID: playlistID)
                }
                .onSuccess { result in
                    #if canImport(UIKit)
                        phase = .success(Image(uiImage: result.image))
                    #elseif canImport(AppKit)
                        phase = .success(Image(nsImage: result.image))
                    #endif
                }
                .onFailure { error in
                    phase = .failure(error)
                }
                .resizable()
                .frame(width: 1, height: 1)
                .opacity(0)
                .accessibilityHidden(true)
            }

            content(phase)
        }
        .onChange(of: url) { _, _ in
            phase = .empty
        }
        .onChange(of: userAgentOverride) { _, _ in
            phase = .empty
        }
        .onChange(of: playlistID) { _, _ in
            phase = .empty
        }
    }
}
