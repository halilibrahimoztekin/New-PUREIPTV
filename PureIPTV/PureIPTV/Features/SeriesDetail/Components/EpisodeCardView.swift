import SwiftUI

public struct EpisodeCardView: View {
    public let episode: DetailModels.Episode
    public let progressItem: WatchHistoryItem?
    public let isDownloaded: Bool
    public let layoutMode: SeriesDetailFeature.State.EpisodeLayoutMode
    public let onPlay: () -> Void
    public let onDownload: () -> Void

    public init(
        episode: DetailModels.Episode,
        progressItem: WatchHistoryItem?,
        isDownloaded: Bool,
        layoutMode: SeriesDetailFeature.State.EpisodeLayoutMode = .list,
        onPlay: @escaping () -> Void,
        onDownload: @escaping () -> Void
    ) {
        self.episode = episode
        self.progressItem = progressItem
        self.isDownloaded = isDownloaded
        self.layoutMode = layoutMode
        self.onPlay = onPlay
        self.onDownload = onDownload
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
        if layoutMode == .list {
            listView
        } else {
            gridView
        }
    }

    // MARK: - List Layout

    private var listView: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    // Thumbnail Container
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let url = episode.coverURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case let .success(img):
                                        img.resizable().scaledToFill()
                                    default:
                                        Color(hex: "#1A1A24")
                                    }
                                }
                            } else {
                                Color(hex: "#1A1A24")
                            }
                        }
                        .frame(width: 135, height: 76)
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
                                    .font(.system(size: 10))
                                Text(AppStrings.SeriesDetail.watched)
                                    .font(.system(size: 9.5, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color(hex: "#00BA88"), in: Capsule())
                            .padding(6)
                        } else if isInProgress {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(height: 3)
                                    Capsule()
                                        .fill(Color(hex: "#00F5D4"))
                                        .frame(width: proxy.size.width * CGFloat(ratio), height: 3)
                                }
                            }
                            .frame(height: 3)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 6)
                        }
                    }
                    .frame(width: 135, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    // Episode Details
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Text(episode.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Text("S\(String(format: "%02d", episode.season))E\(String(format: "%02d", episode.episodeNum))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#0A84FF"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#0A84FF").opacity(0.15), in: Capsule())
                        }

                        HStack(spacing: 12) {
                            if let rating = episode.rating, rating > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", rating))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }

                            if let duration = episode.duration {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text(duration)
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.white.opacity(0.6))
                            }

                            if isInProgress {
                                Text("%\(percent) izlendi")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(hex: "#00F5D4"))
                            }
                        }

                        if let plot = episode.plot, !plot.isEmpty {
                            Text(plot)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(2)
                                .lineSpacing(2)
                        }
                    }
                }

                // Action Bar: Play & Download
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(isInProgress ? AppStrings.SeriesDetail.continueWatching : AppStrings.SeriesDetail.watch)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        isInProgress
                            ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#00F5D4"), Color(hex: "#0A84FF")], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.white.opacity(0.18))
                    )
                    .clipShape(Capsule())

                    Spacer()

                    Button(action: onDownload) {
                        Image(systemName: isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .font(.system(size: 15))
                            .foregroundColor(isDownloaded ? Color(hex: "#00F5D4") : .white.opacity(0.7))
                            .padding(6)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(hex: "#16161D"))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.fluidScale)
        #endif
    }

    // MARK: - Grid Layout (2-Column Compact)

    private var gridView: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 8) {
                // Artwork Container
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let url = episode.coverURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case let .success(img):
                                    img.resizable().scaledToFill()
                                default:
                                    Color(hex: "#1A1A24")
                                }
                            }
                        } else {
                            Color(hex: "#1A1A24")
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
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.65), in: Capsule())

                            Spacer()

                            if isWatched {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#00BA88"))
                                    .padding(4)
                                    .background(Color.black.opacity(0.65), in: Circle())
                            } else if let dur = episode.duration {
                                Text(dur)
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
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
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(radius: 4)

                        Spacer()

                        // Bottom In-Progress Bar
                        if isInProgress {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.3)).frame(height: 3)
                                    Capsule().fill(Color(hex: "#00F5D4")).frame(width: proxy.size.width * CGFloat(ratio), height: 3)
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
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if isInProgress {
                        Text("%\(percent) tamamlandı")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(Color(hex: "#00F5D4"))
                    } else if isWatched {
                        Text(AppStrings.SeriesDetail.watched)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(Color(hex: "#00BA88"))
                    } else if let rating = episode.rating, rating > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating)).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.fluidScale)
        #endif
    }
}
