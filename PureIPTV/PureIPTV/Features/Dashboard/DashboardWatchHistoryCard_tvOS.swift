#if os(tvOS)
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS Watch History Card

    /// Watch history card with resume progress bar optimized for tvOS 10-foot viewing.
    public struct DashboardWatchHistoryCard_tvOS: View {
        public let item: WatchHistoryItem
        public let userAgentOverride: String?
        public let onTap: () -> Void

        @Environment(\.isFocused) private var isFocused

        public init(item: WatchHistoryItem, userAgentOverride: String?, onTap: @escaping () -> Void) {
            self.item = item
            self.userAgentOverride = userAgentOverride
            self.onTap = onTap
        }

        public var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack(alignment: .bottomLeading) {
                        if let urlString = item.coverURL, let url = URL(string: urlString) {
                            KFImage.url(url, cacheKey: PlaylistArtworkRequest.cacheKey(for: url, userAgentOverride: userAgentOverride, playlistID: item.playlistID))
                                .requestModifier { request in
                                    PlaylistArtworkRequest.applyHeaders(to: &request, userAgentOverride: userAgentOverride, playlistID: item.playlistID)
                                }
                                .downsampling(size: CGSize(width: 320, height: 180))
                                .cancelOnDisappear(true)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 320, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppColors.surfaceSecondary)
                                .frame(width: 320, height: 180)
                        }

                        // Progress bar with Electric Blue
                        let progressPercent = item.duration > 0 ? max(0, min(1, item.progress / item.duration)) : 0
                        VStack {
                            Spacer()
                            GeometryReader { proxy in
                                Rectangle()
                                    .fill(AppColors.borderSubtle)
                                    .frame(height: 4)
                                    .overlay(alignment: .leading) {
                                        Rectangle()
                                            .fill(AppColors.primary)
                                            .frame(width: proxy.size.width * CGFloat(progressPercent), height: 4)
                                    }
                            }
                            .frame(height: 4)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                        }
                    }

                    Text(item.title)
                        .font(AppFonts.titleSmall)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .frame(width: 320, alignment: .leading)

                    if let seriesTitle = item.seriesTitle {
                        Text(seriesTitle)
                            .font(AppFonts.bodyMedium)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                            .frame(width: 320, alignment: .leading)
                    }
                }
            }
            .buttonStyle(TVGridCardButtonStyle(cornerRadius: 16))
        }
    }
#endif
