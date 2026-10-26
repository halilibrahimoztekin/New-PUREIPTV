import SwiftUI

public struct NextUpEpisodeBannerView: View {
    public let episode: DetailModels.Episode
    public let userAgentOverride: String?
    public let playlistID: UUID?
    public let seriesTitle: String
    public let progressItem: WatchHistoryItem?
    public let onPlay: () -> Void

    public init(
        episode: DetailModels.Episode,
        userAgentOverride: String? = nil,
        playlistID: UUID? = nil,
        seriesTitle: String,
        progressItem: WatchHistoryItem?,
        onPlay: @escaping () -> Void
    ) {
        self.episode = episode
        self.userAgentOverride = userAgentOverride
        self.playlistID = playlistID
        self.seriesTitle = seriesTitle
        self.progressItem = progressItem
        self.onPlay = onPlay
    }

    private var ratio: Double {
        guard let p = progressItem, p.duration > 0 else { return 0.0 }
        return WatchProgressFormatter.progressRatio(progress: p.progress, duration: p.duration)
    }

    private var percent: Int {
        guard let p = progressItem, p.duration > 0 else { return 0 }
        return WatchProgressFormatter.percentage(progress: p.progress, duration: p.duration)
    }

    private var isInProgress: Bool {
        ratio > 0.02 && ratio < 0.90
    }

    public var body: some View {
        Button(action: onPlay) {
            ZStack(alignment: .bottomLeading) {
                // Background Artwork with Blur and Gradient Scrim
                ZStack {
                    if let url = episode.coverURL {
                        PlaylistAsyncImage(url: url, userAgentOverride: userAgentOverride, playlistID: playlistID) { phase in
                            switch phase {
                            case let .success(img):
                                img.resizable()
                                    .scaledToFill()
                            default:
                                Color(hex: "#1A1A24")
                            }
                        }
                    } else {
                        Color(hex: "#1A1A24")
                    }

                    // Multi-stop darkening gradient scrim
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.35), location: 0.0),
                            .init(color: Color.black.opacity(0.65), location: 0.5),
                            .init(color: Color.black.opacity(0.95), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                // Foreground Content
                VStack(alignment: .leading, spacing: 10) {
                    // Header Badge & Season/Episode Tag
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#00F5D4"))
                            Text(AppStrings.SeriesDetail.nextEpisode.uppercased())
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "#00F5D4"))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#00F5D4").opacity(0.18), in: Capsule())
                        .overlay(Capsule().stroke(Color(hex: "#00F5D4").opacity(0.4), lineWidth: 1))

                        Spacer()

                        Text("S\(String(format: "%02d", episode.season)) · E\(String(format: "%02d", episode.episodeNum))")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                    }

                    Spacer()

                    // Episode Title & Synopsis
                    VStack(alignment: .leading, spacing: 4) {
                        Text(episode.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if let plot = episode.plot, !plot.isEmpty {
                            Text(plot)
                                .font(.system(size: 12.5))
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(2)
                                .lineSpacing(2)
                        }
                    }

                    // Progress Bar if in-progress
                    if isInProgress {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 3.5)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#00F5D4"), Color(hex: "#0A84FF")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: proxy.size.width * CGFloat(ratio), height: 3.5)
                            }
                        }
                        .frame(height: 3.5)
                    }

                    // CTA Play Button Row
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            if isInProgress {
                                CircularProgressRing(
                                    progress: ratio,
                                    lineWidth: 2.5,
                                    size: 18,
                                    gradientColors: [Color(hex: "#00F5D4"), Color.white],
                                    trackColor: Color.white.opacity(0.3)
                                ) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12, weight: .bold))
                            }

                            Text(isInProgress ? "\(AppStrings.SeriesDetail.continueWatching) (%\(percent))" : AppStrings.SeriesDetail.playNextEpisode)
                                .font(.system(size: 13.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#0A84FF"), Color(hex: "#0066CC")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "#0A84FF").opacity(0.4), radius: 6, y: 2)

                        if let duration = episode.duration {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                Text(duration)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()
                    }
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 185)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#00F5D4").opacity(0.4), Color.white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.45), radius: 10, y: 4)
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.fluidScale)
        #endif
    }
}
