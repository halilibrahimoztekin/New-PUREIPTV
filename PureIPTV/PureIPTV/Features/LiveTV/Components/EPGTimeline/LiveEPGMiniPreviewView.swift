import ComposableArchitecture
import SwiftUI
import SwiftVLC

// MARK: - LiveEPGMiniPreviewView

public struct LiveEPGMiniPreviewView: View {
    public let channel: MediaModels.Item
    public let isMuted: Bool
    public let isLoading: Bool
    public let errorMessage: String?
    public let onToggleMute: () -> Void
    public let onExpand: () -> Void
    public let onClose: () -> Void

    @Dependency(\.previewPlayerClient) private var previewPlayerClient
    @State private var isPulsing: Bool = false

    public init(
        channel: MediaModels.Item,
        isMuted: Bool = true,
        isLoading: Bool = false,
        errorMessage: String? = nil,
        onToggleMute: @escaping () -> Void,
        onExpand: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.channel = channel
        self.isMuted = isMuted
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onToggleMute = onToggleMute
        self.onExpand = onExpand
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                // Live Indicator
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                        .scaleEffect(isPulsing ? 1.25 : 0.85)
                        .opacity(isPulsing ? 1.0 : 0.6)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)

                    Text("CANLI ÖNİZLEME")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(Color.red)
                }

                // Audio Status Pill
                HStack(spacing: 3) {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(isMuted ? "SES KAPALI" : "SES AÇIK")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(isMuted ? Color.white.opacity(0.6) : Color(hex: "#0A84FF"))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    isMuted ? Color.white.opacity(0.08) : Color(hex: "#0A84FF").opacity(0.18),
                    in: Capsule()
                )

                Spacer(minLength: 0)

                // Action Controls
                HStack(spacing: 6) {
                    // Mute Button
                    Button(action: onToggleMute) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.plain)

                    // Expand to Fullscreen Button
                    Button(action: onExpand) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color(hex: "#0A84FF"), in: Circle())
                    }
                    .buttonStyle(.plain)

                    // Close Button
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Video Screen Area (16:9)
            ZStack {
                Color.black

                #if os(iOS)
                    if let player = previewPlayerClient.vlcPlayer() {
                        PiPVideoView(player, controller: .constant(nil))
                    } else {
                        videoPlaceholder
                    }
                #else
                    if let player = previewPlayerClient.vlcPlayer() {
                        VideoView(player)
                    } else {
                        videoPlaceholder
                    }
                #endif

                if isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                        PureLoadingView(size: .small, text: "Yükleniyor...")
                    }
                }

                if let error = errorMessage {
                    ZStack {
                        Color.black.opacity(0.7)
                        VStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.yellow)
                            Text(error)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 8)
                        }
                    }
                }
            }
            .frame(width: 260, height: 146)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            // Channel Info Footer
            HStack(spacing: 8) {
                // Logo
                Group {
                    if let coverURL = channel.coverURL {
                        PlaylistAsyncImage(url: coverURL, userAgentOverride: channel.userAgentOverride) { phase in
                            switch phase {
                            case let .success(img):
                                img.resizable().aspectRatio(contentMode: .fit)
                            default:
                                fallbackLogo
                            }
                        }
                    } else {
                        fallbackLogo
                    }
                }
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Title
                VStack(alignment: .leading, spacing: 1) {
                    Text(channel.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("Hızlı Geçiş İçin Dokunun")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 0)

                // Quality Badge
                qualityBadge(for: channel.title)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .frame(width: 280)
        .background(
            ZStack {
                Color(hex: "#0C0C10").opacity(0.92)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#0A84FF").opacity(0.65),
                            Color.white.opacity(0.2),
                            Color.purple.opacity(0.3),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.55), radius: 16, x: 0, y: 8)
        .onAppear {
            isPulsing = true
        }
    }

    private var fallbackLogo: some View {
        Image(systemName: "tv.fill")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.4))
    }

    private var videoPlaceholder: some View {
        ZStack {
            Color.black
            VStack(spacing: 6) {
                Image(systemName: "tv")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Önizleme Başlatılıyor")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func qualityBadge(for title: String) -> some View {
        let lower = title.lowercased()
        let text: String = {
            if lower.contains("4k") || lower.contains("uhd") {
                return "4K"
            }
            if lower.contains("fhd") || lower.contains("1080") {
                return "FHD"
            }
            if lower.contains("hevc") || lower.contains("h.265") {
                return "HEVC"
            }
            return "HD"
        }()

        return Text(text)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(hex: "#0A84FF"))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(hex: "#0A84FF").opacity(0.16), in: RoundedRectangle(cornerRadius: 4))
    }
}
