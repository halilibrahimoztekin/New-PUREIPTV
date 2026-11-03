import ComposableArchitecture
import SwiftUI

// MARK: - Player Drawer Channel Row

/// Dedicated, high-performance row for channels in the player sidebar drawer.
/// Optimized with explicit parameters to prevent list-wide invalidation.
struct PlayerDrawerChannelRow: View {
    let item: PlayerFeature.PlayableItem
    let index: Int
    let isCurrent: Bool
    let isPrevious: Bool
    let isCleaningEnabled: Bool
    let channelSortOption: ChannelSortOption
    let watchCount: Int?
    let showTwoLineTitles: Bool
    let onSelect: () -> Void
    let onHide: () -> Void

    var body: some View {
        let metadata = item.cleanedMetadata
        let displayTitle = isCleaningEnabled ? item.cleanTitle : item.title
        let hasCatchup = (item.tvArchive ?? 0) > 0

        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                // Index Number
                Text("\(index)")
                    .font(AppFonts.captionSmall.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                    .frame(width: 32, alignment: .trailing)

                // Channel Logo
                channelLogo

                // Channel Title & Metadata Badges
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayTitle)
                    #if os(tvOS)
                        .font(AppFonts.titleSmall.weight(isCurrent ? .bold : .medium))
                    #else
                        .font(AppFonts.bodySmall.weight(isCurrent ? .bold : .regular))
                    #endif
                        .foregroundStyle(isCurrent ? AppColors.primary : AppColors.textPrimary)
                    #if os(tvOS)
                        .lineLimit(showTwoLineTitles ? 2 : 1)
                    #else
                        .lineLimit(1)
                    #endif
                        .accessibilityLabel(item.title)

                    metadataBadges(metadata: metadata, hasCatchup: hasCatchup)
                }

                Spacer()

                // State Badges (Current Live / Recall Previous)
                stateBadges
            }
            #if os(tvOS)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            #else
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            #endif
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isCurrent ? AppColors.primary.opacity(0.18) : AppColors.borderSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isCurrent ? AppColors.primary.opacity(0.6) : AppColors.divider,
                        lineWidth: 1
                    )
            )
        }
        #if os(tvOS)
        .tvFocusEffect()
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel(item.title)
        .contextMenu {
            Button(role: .destructive) {
                onHide()
            } label: {
                Label("Kanalı Gizle", systemImage: "eye.slash.fill")
            }
        }
    }

    // MARK: - Metadata Badges

    private func metadataBadges(metadata: CleanedChannelMetadata, hasCatchup: Bool) -> some View {
        HStack(spacing: 5) {
            if let cat = item.categoryID, !cat.isEmpty {
                Text(cat)
                    .font(AppFonts.captionSmall)
                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                    .lineLimit(1)
            } else if let epgID = item.epgChannelID {
                Text(epgID)
                    .font(AppFonts.captionSmall)
                    .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                    .lineLimit(1)
            }

            // Country Badge
            if let country = metadata.detectedCountry {
                Text(country)
                    .font(AppFonts.captionSmall.weight(.heavy))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.8))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(AppColors.borderMedium)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }

            // Quality Badge
            if let q = metadata.detectedQuality {
                Text(q.rawValue)
                    .font(AppFonts.captionSmall.weight(.heavy))
                    .foregroundStyle(q.badgeColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(q.badgeColor.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }

            // HEVC Badge
            if metadata.isHEVC {
                Text("HEVC")
                    .font(AppFonts.captionSmall.weight(.heavy))
                    .foregroundStyle(AppColors.premium)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(AppColors.premium.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }

            // Catchup Archive Indicator
            if hasCatchup {
                HStack(spacing: 2) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(AppFonts.captionSmall.weight(.bold))
                    Text("ARŞİV")
                        .font(AppFonts.captionSmall.weight(.bold))
                }
                .foregroundStyle(AppColors.warningGold)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(AppColors.warningGold.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }

            // Watch Count Badge
            if channelSortOption == .mostWatched, let count = watchCount, count > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(AppFonts.captionSmall.weight(.bold))
                    Text("\(count)x")
                        .font(AppFonts.captionSmall.weight(.bold))
                }
                .foregroundStyle(AppColors.warning)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(AppColors.warning.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
        }
    }

    // MARK: - State Badges

    @ViewBuilder
    private var stateBadges: some View {
        if isCurrent {
            HStack(spacing: 5) {
                Circle()
                    .fill(AppColors.success)
                    .frame(width: 7, height: 7)
                Text(AppStrings.Player.liveLabel)
                    .font(AppFonts.captionSmall.weight(.bold))
                    .foregroundStyle(AppColors.success)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppColors.success.opacity(0.18))
            .clipShape(Capsule())
        } else if isPrevious {
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(AppFonts.captionSmall.weight(.bold))
                Text(AppStrings.Player.recallLastChannel)
                    .font(AppFonts.captionSmall.weight(.bold))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(AppColors.warning)
            .background(AppColors.warning.opacity(0.18))
            .clipShape(Capsule())
        }
    }

    // MARK: - Channel Logo

    private var channelLogo: some View {
        Group {
            if let coverURL = item.coverURL {
                PlaylistAsyncImage(url: coverURL, fallbackURL: item.fallbackCoverURL, userAgentOverride: item.userAgentOverride, playlistID: item.config?.playlistID) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .empty:
                        PureLoadingView(size: .small)
                    case .failure:
                        fallbackLogo
                    @unknown default:
                        fallbackLogo
                    }
                }
            } else {
                fallbackLogo
            }
        }
        #if os(tvOS)
        .frame(width: 48, height: 48)
        #else
        .frame(width: 38, height: 38)
        #endif
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.borderMedium, lineWidth: 0.8)
        )
    }

    private var fallbackLogo: some View {
        Image(systemName: "tv")
            .font(AppFonts.bodySmall)
            .foregroundStyle(AppColors.textSecondary.opacity(0.5))
    }
}
