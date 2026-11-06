import SwiftUI

/// Loads a portrait poster through the playlist-aware image pipeline and decodes
/// only enough pixels for the card's rendered size.
struct PlaylistPosterArtworkView<Placeholder: View>: View {
    let url: URL?
    let userAgentOverride: String?
    let playlistID: UUID?
    @ViewBuilder let placeholder: () -> Placeholder

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            PlaylistAsyncImage(
                url: url,
                userAgentOverride: userAgentOverride,
                playlistID: playlistID,
                downsamplingSize: CGSize(
                    width: max(geometry.size.width * displayScale, 1),
                    height: max(geometry.size.height * displayScale, 1)
                )
            ) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholder()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
