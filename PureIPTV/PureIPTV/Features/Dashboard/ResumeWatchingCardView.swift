import SwiftUI

public struct ResumeWatchingCardView: View {
    public let item: WatchHistoryItem
    public let onResume: () -> Void
    public let onRestart: () -> Void
    public let onDelete: () -> Void
    public let userAgentOverride: String?

    @State private var isHovered: Bool = false

    public init(
        item: WatchHistoryItem,
        userAgentOverride: String? = nil,
        onResume: @escaping () -> Void,
        onRestart: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.userAgentOverride = userAgentOverride
        self.onResume = onResume
        self.onRestart = onRestart
        self.onDelete = onDelete
    }

    private var ratio: Double {
        WatchProgressFormatter.progressRatio(progress: item.progress, duration: item.duration)
    }

    private var percent: Int {
        WatchProgressFormatter.percentage(progress: item.progress, duration: item.duration)
    }

    private var remainingText: String {
        WatchProgressFormatter.formattedRemainingTime(progress: item.progress, duration: item.duration)
    }

    private var relativeTime: String {
        WatchProgressFormatter.relativeDateFormatted(item.lastWatchedAt)
    }

    public var body: some View {
        Button(action: onResume) {
            VStack(alignment: .leading, spacing: 10) {
                // Card Media Artwork Container
                ZStack {
                    // Artwork / Poster
                    if let urlString = item.coverURL, let url = URL(string: urlString) {
                        PlaylistAsyncImage(url: url, userAgentOverride: userAgentOverride, playlistID: item.playlistID) { phase in
                            switch phase {
                            case let .success(img):
                                img.resizable()
                                    .scaledToFill()
                            default:
                                fallbackCover
                            }
                        }
                    } else {
                        fallbackCover
                    }

                    // Multi-stop cinematic gradient scrim
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.6), location: 0.0),
                            .init(color: Color.black.opacity(0.0), location: 0.4),
                            .init(color: Color.black.opacity(0.2), location: 0.65),
                            .init(color: Color.black.opacity(0.85), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Top Bar Elements: Type Pill & Remaining Time Pill
                    VStack {
                        HStack {
                            // Type Pill (Film / Dizi)
                            Text(item.type == "episode" ? "DİZİ" : "FİLM")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.55), in: Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.8))

                            Spacer()

                            // Remaining Time Pill
                            if !remainingText.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 8.5))
                                    Text(remainingText)
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                                .shadow(color: Color.black.opacity(0.4), radius: 4)
                            }
                        }
                        .padding(10)

                        Spacer()

                        // Center Floating Play Button with Integrated Circular Progress Ring
                        ZStack {
                            // Circular Glass Background
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                                .shadow(color: Color.black.opacity(0.5), radius: 8, y: 3)

                            // Glowing Progress Ring
                            CircularProgressRing(
                                progress: ratio,
                                lineWidth: 3.0,
                                size: 44,
                                gradientColors: [Color(hex: "#00F5D4"), Color(hex: "#0A84FF")],
                                trackColor: Color.white.opacity(0.2)
                            ) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(x: 1.5)
                            }
                        }
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)

                        Spacer()

                        // Bottom Linear Progress Bar
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                // Background track
                                Capsule()
                                    .fill(Color.white.opacity(0.25))
                                    .frame(height: 3.5)

                                // Active progress fill with cyan/blue gradient
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#00F5D4"), Color(hex: "#0A84FF")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: proxy.size.width * CGFloat(ratio), height: 3.5)
                                    .shadow(color: Color(hex: "#00F5D4").opacity(0.6), radius: 3)
                            }
                        }
                        .frame(height: 3.5)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }
                }
                #if os(tvOS)
                .frame(width: 320, height: 180)
                #else
                .frame(width: 220, height: 124)
                #endif
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

                // Metadata Section
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    #if os(tvOS)
                        .frame(width: 320, alignment: .leading)
                    #else
                        .frame(width: 220, alignment: .leading)
                    #endif

                    HStack(spacing: 6) {
                        if let seriesTitle = item.seriesTitle, !seriesTitle.isEmpty {
                            Text(seriesTitle)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(Color(hex: "#00F5D4"))
                                .lineLimit(1)

                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                        }

                        Text("%\(percent)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#0A84FF"))

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))

                        Text(relativeTime)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    #if os(tvOS)
                    .frame(width: 320, alignment: .leading)
                    #else
                    .frame(width: 220, alignment: .leading)
                    #endif
                }
            }
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.fluidScale)
        #endif
        .contextMenu {
            Button {
                #if os(iOS)
                    HapticManager.shared.trigger(.medium)
                #endif
                onResume()
            } label: {
                Label("Kaldığın Yerden Devam Et (%\(percent))", systemImage: "play.fill")
            }

            Button {
                #if os(iOS)
                    HapticManager.shared.trigger(.light)
                #endif
                onRestart()
            } label: {
                Label("Baştan Başlat", systemImage: "arrow.counterclockwise")
            }

            Divider()

            Button(role: .destructive) {
                #if os(iOS)
                    HapticManager.shared.trigger(.warning)
                #endif
                onDelete()
            } label: {
                Label("İzleme Geçmişinden Kaldır", systemImage: "trash")
            }
        }
    }

    private var fallbackCover: some View {
        ZStack {
            Color(hex: "#16161A")
            Image(systemName: "film")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.2))
        }
    }
}
