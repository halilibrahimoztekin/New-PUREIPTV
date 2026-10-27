import SwiftUI

/// Hero backdrop view for VOD detail supporting seamless muted inline trailer auto-play (Madde #46).
public struct InlineTrailerHeroView: View {
    public let backdropURL: URL?
    public let userAgentOverride: String?
    public let trailerKey: String?
    public let isAutoPlayActive: Bool
    public let isMuted: Bool
    public let onToggleMute: () -> Void
    public let onExpandTrailer: () -> Void
    public let onOpenTrailerSheet: () -> Void

    @State private var kenBurnsZoom: Bool = false
    #if os(iOS)
        @State private var inlineTrailerFailure: TrailerPlaybackFailure?
        @State private var inlineTrailerRetryAttempt = 0
    #endif

    public init(
        backdropURL: URL?,
        userAgentOverride: String? = nil,
        trailerKey: String?,
        isAutoPlayActive: Bool,
        isMuted: Bool,
        onToggleMute: @escaping () -> Void,
        onExpandTrailer: @escaping () -> Void,
        onOpenTrailerSheet: @escaping () -> Void
    ) {
        self.backdropURL = backdropURL
        self.userAgentOverride = userAgentOverride
        self.trailerKey = trailerKey
        self.isAutoPlayActive = isAutoPlayActive
        self.isMuted = isMuted
        self.onToggleMute = onToggleMute
        self.onExpandTrailer = onExpandTrailer
        self.onOpenTrailerSheet = onOpenTrailerSheet
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            #if os(iOS)
                if isAutoPlayActive, let key = trailerKey, inlineTrailerFailure == nil {
                    // Inline Video Trailer
                    ZStack(alignment: .bottomTrailing) {
                        TrailerWebView(
                            videoKey: key,
                            isMuted: isMuted,
                            showControls: false,
                            retryAttempt: inlineTrailerRetryAttempt,
                            onPlaybackFailure: { inlineTrailerFailure = $0 }
                        )
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .clipped()

                        // Dark Scrim Vignette on top/bottom
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.35), location: 0),
                                .init(color: .clear, location: 0.25),
                                .init(color: Color(hex: "#0F0F13").opacity(0.8), location: 0.8),
                                .init(color: Color(hex: "#0F0F13"), location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .allowsHitTesting(false)

                        // Floating Glass Controls (Mute / Unmute & Fullscreen)
                        HStack(spacing: 8) {
                            Button(action: {
                                HapticManager.shared.trigger(.light)
                                onToggleMute()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(isMuted ? AppStrings.VODDetail.unmuteTrailer : AppStrings.VODDetail.muteTrailer)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                            }

                            Button(action: {
                                HapticManager.shared.trigger(.medium)
                                onExpandTrailer()
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(7)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                    .transition(.opacity)
                } else {
                    ZStack {
                        staticBackdropView

                        if isAutoPlayActive, let inlineTrailerFailure {
                            TrailerPlaybackFailureOverlay(failure: inlineTrailerFailure) {
                                self.inlineTrailerFailure = nil
                                inlineTrailerRetryAttempt += 1
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            #else
                // tvOS Backdrop with Ken Burns Dynamic Zoom
                staticBackdropView
            #endif
        }
        .frame(height: 260)
        .clipped()
        .animation(.easeInOut(duration: 0.4), value: isAutoPlayActive)
        #if os(iOS)
            .onChange(of: trailerKey) { _, _ in
                inlineTrailerFailure = nil
                inlineTrailerRetryAttempt = 0
            }
            .onChange(of: isAutoPlayActive) { _, isActive in
                if isActive {
                    inlineTrailerFailure = nil
                    inlineTrailerRetryAttempt = 0
                }
            }
        #endif
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

            // Watch Trailer Action floating on backdrop if trailer available
            if trailerKey != nil {
                Button {
                    #if !os(tvOS)
                        HapticManager.shared.trigger(.medium)
                    #endif
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
        }
    }
}
