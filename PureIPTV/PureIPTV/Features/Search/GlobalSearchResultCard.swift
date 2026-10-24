import Kingfisher
import SwiftUI

// MARK: - Global Search Result Card

public struct GlobalSearchResultCard: View {
    public let result: GlobalSearchResultItem
    public let isSelected: Bool
    public let showPlaylistBadge: Bool
    public let isReminderScheduled: Bool
    public let isReminderPending: Bool
    public let onTap: () -> Void

    #if os(tvOS)
        @Environment(\.isFocused) private var isFocused
    #endif

    public init(
        result: GlobalSearchResultItem,
        isSelected: Bool = false,
        showPlaylistBadge: Bool = true,
        isReminderScheduled: Bool = false,
        isReminderPending: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.result = result
        self.isSelected = isSelected
        self.showPlaylistBadge = showPlaylistBadge
        self.isReminderScheduled = isReminderScheduled
        self.isReminderPending = isReminderPending
        self.onTap = onTap
    }

    private var isChannel: Bool {
        result.item.type == .live
    }

    private var aspectRatio: CGFloat {
        isChannel ? (16 / 9) : (2 / 3)
    }

    public var body: some View {
        Button(action: {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
            onTap()
        }) {
            ZStack(alignment: .bottomLeading) {
                // Background & Border
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(Color(hex: "#16161A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .stroke(
                                activeBorderColor,
                                lineWidth: activeBorderWidth
                            )
                    )

                // Poster / Channel Image
                mediaCoverImage

                // Gradient Vignette
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.1),
                        Color.clear,
                        Color.black.opacity(0.88),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Top Badge Overlays
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 6) {
                        contentTypeBadge

                        Spacer()

                        if result.is4K {
                            uhdBadge
                        }

                        if showPlaylistBadge {
                            playlistSourceBadge
                        }
                    }
                    .padding(badgePadding)

                    Spacer()

                    // Bottom Metadata & Title
                    bottomMetadata
                        .padding(contentPadding)
                }
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            #if os(tvOS)
                .scaleEffect(isFocused ? 1.06 : 1.0)
                .shadow(
                    color: isFocused ? result.contentTypeColor.opacity(0.6) : Color.black.opacity(0.4),
                    radius: isFocused ? 20 : 8,
                    x: 0,
                    y: isFocused ? 8 : 4
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
            #else
                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
            #endif
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var mediaCoverImage: some View {
        if let url = result.item.coverURL {
            KFImage.url(url, cacheKey: PlaylistArtworkRequest.cacheKey(for: url, userAgentOverride: result.item.userAgentOverride))
                .requestModifier { request in
                    UserAgentManager.applyHeaders(to: &request, override: result.item.userAgentOverride)
                }
                .placeholder {
                    placeholderBackground
                }
                .downsampling(size: isChannel ? CGSize(width: 320, height: 180) : CGSize(width: 240, height: 360))
                .cacheOriginalImage()
                .resizable()
                .aspectRatio(contentMode: isChannel ? .fit : .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(isChannel ? 16 : 0)
        } else {
            placeholderBackground
        }
    }

    private var placeholderBackground: some View {
        ZStack {
            Color(hex: "#1C1C20")
            Image(systemName: result.contentTypeIcon)
                .font(.system(size: isChannel ? 28 : 36, weight: .light))
                .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.2))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: result.contentTypeIcon)
                .font(.system(size: badgeIconSize, weight: .semibold))
            Text(result.contentTypeTitle)
                .font(.system(size: badgeFontSize, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(
            Capsule()
                .fill(result.contentTypeColor.opacity(0.92))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                )
        )
        .shadow(color: result.contentTypeColor.opacity(0.4), radius: 4, x: 0, y: 2)
    }

    private var uhdBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles.tv.fill")
                .font(.system(size: badgeIconSize, weight: .bold))
            Text("4K UHD")
                .font(.system(size: badgeFontSize, weight: .black))
        }
        .foregroundStyle(Color(hex: "#101014"))
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FFD60A"), Color(hex: "#FF9F0A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color(hex: "#FFD60A").opacity(0.4), radius: 5, x: 0, y: 2)
    }

    private var playlistSourceBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(result.playlistBadge.color)
                .frame(width: 5, height: 5)
            Text(result.playlistBadge.playlistName)
                .font(.system(size: badgeFontSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.65))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
        )
    }

    private var bottomMetadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.item.title)
                .font(.system(size: titleFontSize, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(isChannel ? 1 : 2)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)

            if let epg = result.matchedEPGTitle {
                HStack(spacing: 4) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(hex: "#30D158"))
                    Text(epg)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "#30D158"))
                        .lineLimit(1)
                    if isReminderPending {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(hex: "#FFD60A"))
                            .accessibilityLabel(AppStrings.Player.reminderScheduling)
                    } else if isReminderScheduled {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(hex: "#FFD60A"))
                            .accessibilityLabel(AppStrings.Player.reminderSet)
                    }
                }
            } else if !isChannel {
                HStack(spacing: 6) {
                    if let rating = result.item.rating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: "#FFD60A"))
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }

                    if let year = result.item.releaseDate, !year.isEmpty {
                        Text(year.prefix(4))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    if let duration = result.item.duration, !duration.isEmpty {
                        Text(duration)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - Scaled Geometry Helpers

    private var cardCornerRadius: CGFloat {
        #if os(tvOS)
            18
        #else
            14
        #endif
    }

    private var badgePadding: CGFloat {
        #if os(tvOS)
            12
        #else
            8
        #endif
    }

    private var contentPadding: CGFloat {
        #if os(tvOS)
            14
        #else
            9
        #endif
    }

    private var badgeFontSize: CGFloat {
        #if os(tvOS)
            13
        #else
            10
        #endif
    }

    private var badgeIconSize: CGFloat {
        #if os(tvOS)
            12
        #else
            9
        #endif
    }

    private var titleFontSize: CGFloat {
        #if os(tvOS)
            16
        #else
            12
        #endif
    }

    private var activeBorderColor: Color {
        #if os(tvOS)
            if isFocused {
                return result.contentTypeColor
            }
        #endif
        if isSelected {
            return Color(hex: "#0A84FF")
        }
        return Color.white.opacity(0.08)
    }

    private var activeBorderWidth: CGFloat {
        #if os(tvOS)
            if isFocused {
                return 3
            }
        #endif
        return isSelected ? 2 : 1
    }
}
