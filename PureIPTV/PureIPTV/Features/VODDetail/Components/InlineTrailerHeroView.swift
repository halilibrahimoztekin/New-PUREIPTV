import SwiftUI

/// Static cinematic backdrop with an explicit trailer action on iOS and iPadOS.
public struct InlineTrailerHeroView: View {
    public let backdropURL: URL?
    public let userAgentOverride: String?
    public let trailerKey: String?
    public let onOpenTrailerSheet: () -> Void

    @State private var kenBurnsZoom: Bool = false

    public init(
        backdropURL: URL?,
        userAgentOverride: String? = nil,
        trailerKey: String?,
        onOpenTrailerSheet: @escaping () -> Void
    ) {
        self.backdropURL = backdropURL
        self.userAgentOverride = userAgentOverride
        self.trailerKey = trailerKey
        self.onOpenTrailerSheet = onOpenTrailerSheet
    }

    public var body: some View {
        staticBackdropView
            .frame(height: 260)
            .clipped()
    }

    private var staticBackdropView: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { proxy in
                if let url = backdropURL {
                    PlaylistAsyncImage(url: url, userAgentOverride: userAgentOverride) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: 260)
                                .scaleEffect(kenBurnsZoom ? 1.06 : 1.0)
                                .animation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true), value: kenBurnsZoom)
                                .clipped()
                                .onAppear {
                                    kenBurnsZoom = true
                                }
                        case .empty:
                            Rectangle().fill(Color(hex: "#1A1A24")).shimmeringPlaceholder(isLoading: true)
                        case .failure:
                            Rectangle().fill(Color(hex: "#1A1A24"))
                        @unknown default:
                            Rectangle().fill(Color(hex: "#1A1A24"))
                        }
                    }
                } else {
                    Rectangle().fill(Color(hex: "#1A1A24"))
                }
            }

            // Cinematic Vignette & Bottom Gradient Fading to Screen Background
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.35), location: 0),
                    .init(color: .clear, location: 0.35),
                    .init(color: Color(hex: "#0F0F13").opacity(0.75), location: 0.75),
                    .init(color: Color(hex: "#0F0F13"), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            #if !os(tvOS)
                // Trailer playback is an explicit user action and opens Safari.
                if trailerKey != nil {
                    Button {
                        HapticManager.shared.trigger(.medium)
                        onOpenTrailerSheet()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(AppStrings.VODDetail.watchTrailer)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                    .padding(.leading, 16)
                    .padding(.bottom, 16)
                }
            #endif
        }
    }
}
