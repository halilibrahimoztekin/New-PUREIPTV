import SwiftUI

public struct NextUpEpisodeBannerView: View {
    public let episode: DetailModels.Episode
    public let userAgentOverride: String?
    public let playlistID: UUID?
    public let seriesTitle: String
    public let progressItem: WatchHistoryItem?
    public let onPlay: () -> Void
    @Environment(\.displayScale) private var displayScale

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

    private var artworkDownsamplingSize: CGSize {
        #if os(tvOS)
            CGSize(width: 1280, height: 720)
        #else
            CGSize(width: 1280, height: 720 * displayScale / 3)
        #endif
    }

    public var body: some View {
        Button(action: onPlay) {
            ZStack(alignment: .bottomLeading) {
                // Background Artwork with Blur and Gradient Scrim
                ZStack {
                    if let url = episode.coverURL {
                        PlaylistAsyncImage(
                            url: url,
                            userAgentOverride: userAgentOverride,
                            playlistID: playlistID,
                            downsamplingSize: artworkDownsamplingSize
                        ) { phase in
                            switch phase {
                            case let .success(img):
                                img.resizable()
                                    .scaledToFill()
                            default:
                                AppColors.surfaceTertiary
                            }
                        }
                    } else {
                        AppColors.surfaceTertiary
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
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(AppFonts.captionSmall)
                                .foregroundColor(AppColors.neonTeal)
                            Text(AppStrings.SeriesDetail.nextEpisode.uppercased())
                                .font(AppFonts.captionSmall)
                                .foregroundColor(AppColors.neonTeal)
                        }
                        #if os(tvOS)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        #else
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        #endif
                        .background(AppColors.neonTeal.opacity(0.18), in: Capsule())
                        .overlay(Capsule().stroke(AppColors.neonTeal.opacity(0.4), lineWidth: 1))

                        Spacer()

                        Text("S\(String(format: "%02d", episode.season)) · E\(String(format: "%02d", episode.episodeNum))")
                            .font(AppFonts.captionSmall)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundColor(AppColors.textPrimary.opacity(0.85))
                            .background(.ultraThinMaterial, in: Capsule())
                    }

                    Spacer()

                    // Episode Title & Synopsis
                    VStack(alignment: .leading, spacing: 4) {
                        Text(episode.title)
                            .font(AppFonts.title)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)

                        if let plot = episode.plot, !plot.isEmpty {
                            Text(plot)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(2)
                                .lineSpacing(2)
                        }
                    }

                    // Progress Bar if in-progress
                    if isInProgress {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppColors.textPrimary.opacity(0.2))
                                    .frame(height: 4)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.neonTeal, AppColors.primary],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: proxy.size.width * CGFloat(ratio), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }

                    // CTA Play Button Row
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            if isInProgress {
                                CircularProgressRing(
                                    progress: ratio,
                                    lineWidth: 2.5,
                                    size: 20,
                                    gradientColors: [AppColors.neonTeal, AppColors.textPrimary],
                                    trackColor: AppColors.textPrimary.opacity(0.3)
                                ) {
                                    Image(systemName: "play.fill")
                                        .font(AppFonts.captionSmall)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            } else {
                                Image(systemName: "play.fill")
                                    .font(AppFonts.bodyBold)
                            }

                            Text(isInProgress ? "\(AppStrings.SeriesDetail.continueWatching) (%\(percent))" : AppStrings.SeriesDetail.playNextEpisode)
                                .font(AppFonts.bodyBold)
                        }
                        .foregroundColor(AppColors.textPrimary)
                        #if os(tvOS)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                        #else
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        #endif
                            .background(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.primary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: AppColors.primary.opacity(0.4), radius: 6, y: 2)

                        if let duration = episode.duration {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(AppFonts.captionSmall)
                                Text(duration)
                                    .font(AppFonts.captionSmall)
                            }
                            .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()
                    }
                }
                #if os(tvOS)
                .padding(22)
                #else
                .padding(14)
                #endif
            }
            .frame(maxWidth: .infinity)
            #if os(tvOS)
                .frame(height: 240)
            #else
                .frame(height: 185)
            #endif
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [AppColors.neonTeal.opacity(0.4), AppColors.borderMedium],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: Color.black.opacity(0.45), radius: 10, y: 4)
        }
        #if os(tvOS)
        .buttonStyle(TVGridCardButtonStyle(cornerRadius: 18))
        #else
        .buttonStyle(.fluidScale)
        #endif
    }
}
