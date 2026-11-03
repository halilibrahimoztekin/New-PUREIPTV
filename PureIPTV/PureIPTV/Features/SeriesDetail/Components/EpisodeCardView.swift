import SwiftUI

public struct EpisodeCardView: View {
    public let episode: DetailModels.Episode
    public let userAgentOverride: String?
    public let playlistID: UUID?
    public let progressItem: WatchHistoryItem?
    public let isDownloaded: Bool
    public let isDeleting: Bool
    public let layoutMode: SeriesDetailFeature.State.EpisodeLayoutMode
    public let onPlay: () -> Void
    public let onDownload: () -> Void
    public let onMarkUnwatched: () -> Void

    public init(
        episode: DetailModels.Episode,
        userAgentOverride: String? = nil,
        playlistID: UUID? = nil,
        progressItem: WatchHistoryItem?,
        isDownloaded: Bool,
        isDeleting: Bool = false,
        layoutMode: SeriesDetailFeature.State.EpisodeLayoutMode = .list,
        onPlay: @escaping () -> Void,
        onDownload: @escaping () -> Void,
        onMarkUnwatched: @escaping () -> Void = {}
    ) {
        self.episode = episode
        self.userAgentOverride = userAgentOverride
        self.playlistID = playlistID
        self.progressItem = progressItem
        self.isDownloaded = isDownloaded
        self.isDeleting = isDeleting
        self.layoutMode = layoutMode
        self.onPlay = onPlay
        self.onDownload = onDownload
        self.onMarkUnwatched = onMarkUnwatched
    }

    private var ratio: Double {
        guard let p = progressItem, p.duration > 0 else { return 0.0 }
        return WatchProgressFormatter.progressRatio(progress: p.progress, duration: p.duration)
    }

    private var percent: Int {
        guard let p = progressItem, p.duration > 0 else { return 0 }
        return WatchProgressFormatter.percentage(progress: p.progress, duration: p.duration)
    }

    private var isWatched: Bool {
        ratio >= 0.90
    }

    private var isInProgress: Bool {
        ratio > 0.02 && ratio < 0.90
    }

    public var body: some View {
        Group {
            if layoutMode == .list {
                listView
            } else {
                gridView
            }
        }
        .contextMenu {
            if isWatched {
                Button {
                    #if os(iOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    onMarkUnwatched()
                } label: {
                    Label(AppStrings.SeriesDetail.markAsUnwatched, systemImage: "eye.slash")
                }
            }
        }
    }

    // MARK: - List Layout

    private var listView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                // Thumbnail Container
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let url = episode.coverURL {
                            PlaylistAsyncImage(url: url, userAgentOverride: userAgentOverride, playlistID: playlistID) { phase in
                                switch phase {
                                case let .success(img):
                                    img.resizable().scaledToFill()
                                default:
                                    AppColors.surfaceTertiary
                                }
                            }
                        } else {
                            AppColors.surfaceTertiary
                        }
                    }
                    #if os(tvOS)
                    .frame(width: 240, height: 135)
                    #else
                    .frame(width: 135, height: 76)
                    #endif
                    .clipped()

                    // Dark gradient scrim
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Watched Badge or Progress Bar
                    if isWatched {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(AppFonts.captionSmall)
                            Text(AppStrings.SeriesDetail.watched)
                                .font(AppFonts.captionSmall)
                        }
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.success, in: Capsule())
                        .padding(8)
                    } else if isInProgress {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppColors.textPrimary.opacity(0.3))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(AppColors.neonTeal)
                                    .frame(width: proxy.size.width * CGFloat(ratio), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                }
                #if os(tvOS)
                .frame(width: 240, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                #else
                .frame(width: 135, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                #endif

                // Episode Details
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text(episode.title)
                        #if os(tvOS)
                            .font(.system(size: 22, weight: .semibold))
                        #else
                            .font(.system(size: 15, weight: .semibold))
                        #endif
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Spacer()

                        Text("S\(String(format: "%02d", episode.season))E\(String(format: "%02d", episode.episodeNum))")
                            .font(AppFonts.captionSmall)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundColor(AppColors.primary)
                            .background(AppColors.primary.opacity(0.15), in: Capsule())
                    }

                    HStack(spacing: 12) {
                        if let rating = episode.rating, rating > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(AppFonts.captionSmall)
                                    .foregroundColor(AppColors.warningGold)
                                Text(String(format: "%.1f", rating))
                                    .font(AppFonts.captionSmall)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }

                        if let duration = episode.duration {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(AppFonts.captionSmall)
                                Text(duration)
                                    .font(AppFonts.captionSmall)
                            }
                            .foregroundColor(AppColors.textSecondary)
                        }

                        if isInProgress {
                            Text("%\(percent) izlendi")
                                .font(AppFonts.captionSmall)
                                .foregroundColor(AppColors.neonTeal)
                        }
                    }

                    if let plot = episode.plot, !plot.isEmpty {
                        Text(plot)
                        #if os(tvOS)
                            .font(.system(size: 15))
                        #else
                            .font(.system(size: 12))
                        #endif
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(2)
                            .lineSpacing(2)
                    }
                }
            }

            // Action Bar: Play & Download
            HStack {
                Button(action: onPlay) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        #if os(tvOS)
                            .font(.system(size: 14, weight: .bold))
                        #else
                            .font(.system(size: 10, weight: .bold))
                        #endif
                        Text(isInProgress ? AppStrings.SeriesDetail.continueWatching : AppStrings.SeriesDetail.watch)
                        #if os(tvOS)
                            .font(.system(size: 16, weight: .bold))
                        #else
                            .font(.system(size: 12, weight: .bold))
                        #endif
                    }
                    .foregroundColor(.white)
                    #if os(tvOS)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    #else
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                    #endif
                        .background(
                            isInProgress
                                ? AnyShapeStyle(LinearGradient(colors: [AppColors.neonTeal, AppColors.primary], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(Color.white.opacity(0.18))
                        )
                        .clipShape(Capsule())
                }
                #if os(tvOS)
                .buttonStyle(TVCapsuleButtonStyle(isPrimary: true, isSelected: false))
                #else
                .buttonStyle(.fluidScale)
                #endif
                .accessibilityLabel("\(isInProgress ? AppStrings.SeriesDetail.continueWatching : AppStrings.SeriesDetail.watch): \(episode.title)")

                Spacer()

                Button(action: onDownload) {
                    Group {
                        if isDeleting {
                            ProgressView()
                                .tint(AppColors.neonTeal)
                        } else {
                            Image(systemName: isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
                                .font(.system(size: 15))
                                .foregroundColor(isDownloaded ? AppColors.neonTeal : AppColors.textPrimary.opacity(0.7))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
                .accessibilityLabel("\(isDownloaded ? AppStrings.Downloads.deleteDownloadTitle : AppStrings.Common.download): \(episode.title)")
                .accessibilityValue(isDeleting ? AppStrings.Common.loading : "")
            }
        }
        .padding(12)
        .background(AppColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Grid Layout (2-Column Compact)

    private var gridView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onPlay) {
                // Artwork Container
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let url = episode.coverURL {
                            PlaylistAsyncImage(url: url, userAgentOverride: userAgentOverride, playlistID: playlistID) { phase in
                                switch phase {
                                case let .success(img):
                                    img.resizable().scaledToFill()
                                default:
                                    AppColors.surfaceTertiary
                                }
                            }
                        } else {
                            AppColors.surfaceTertiary
                        }
                    }
                    .frame(height: 100)
                    .clipped()

                    // Gradient Scrim
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Top Season/Episode Tag
                    VStack {
                        HStack {
                            Text("E\(String(format: "%02d", episode.episodeNum))")
                                .font(AppFonts.captionSmall)
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.65), in: Capsule())

                            Spacer()

                            if isWatched {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(AppFonts.captionSmall)
                                    .foregroundColor(AppColors.success)
                                    .padding(4)
                                    .background(Color.black.opacity(0.65), in: Circle())
                            } else if let dur = episode.duration {
                                Text(dur)
                                    .font(AppFonts.captionSmall)
                                    .foregroundColor(AppColors.textPrimary.opacity(0.85))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.65), in: Capsule())
                            }
                        }
                        .padding(6)

                        Spacer()

                        // Center Play Icon
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(AppColors.textPrimary.opacity(0.9))
                            .shadow(radius: 4)

                        Spacer()

                        // Bottom In-Progress Bar
                        if isInProgress {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(AppColors.textPrimary.opacity(0.3)).frame(height: 3)
                                    Capsule().fill(AppColors.neonTeal).frame(width: proxy.size.width * CGFloat(ratio), height: 3)
                                }
                            }
                            .frame(height: 3)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 6)
                        }
                    }
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.borderSubtle, lineWidth: 1)
                )
            }
            #if os(tvOS)
            .tvFocusEffect()
            #else
            .buttonStyle(.fluidScale)
            #endif
            .accessibilityLabel("\(isInProgress ? AppStrings.SeriesDetail.continueWatching : AppStrings.SeriesDetail.watch): \(episode.title)")

            // Title & Subtitle
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    if isInProgress {
                        Text("%\(percent) tamamlandı")
                            .font(AppFonts.captionSmall)
                            .foregroundColor(AppColors.neonTeal)
                    } else if isWatched {
                        Text(AppStrings.SeriesDetail.watched)
                            .font(AppFonts.captionSmall)
                            .foregroundColor(AppColors.success)
                    } else if let rating = episode.rating, rating > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(AppFonts.captionSmall).foregroundColor(AppColors.warningGold)
                            Text(String(format: "%.1f", rating)).font(AppFonts.captionSmall).foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Spacer(minLength: 0)

                Button(action: onDownload) {
                    Group {
                        if isDeleting {
                            ProgressView()
                                .tint(AppColors.neonTeal)
                        } else {
                            Image(systemName: isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
                                .font(.system(size: 15))
                                .foregroundColor(isDownloaded ? AppColors.neonTeal : AppColors.textPrimary.opacity(0.7))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
                .accessibilityLabel("\(isDownloaded ? AppStrings.Downloads.deleteDownloadTitle : AppStrings.Common.download): \(episode.title)")
                .accessibilityValue(isDeleting ? AppStrings.Common.loading : "")
            }
        }
        .padding(12)
        .background(AppColors.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
