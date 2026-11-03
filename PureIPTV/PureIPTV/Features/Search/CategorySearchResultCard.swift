import SwiftUI

public struct CategorySearchResultCard: View {
    public let result: CategorySearchResultItem
    public let queryTerms: [String]
    public let showPlaylistBadge: Bool
    public let isSelected: Bool
    public let onTap: () -> Void

    #if os(tvOS)
        @Environment(\.isFocused) private var isFocused
    #endif

    public init(
        result: CategorySearchResultItem,
        queryTerms: [String] = [],
        showPlaylistBadge: Bool = false,
        isSelected: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.result = result
        self.queryTerms = queryTerms
        self.showPlaylistBadge = showPlaylistBadge
        self.isSelected = isSelected
        self.onTap = onTap
    }

    private var cardCornerRadius: CGFloat {
        #if os(tvOS)
            return 20
        #else
            return 16
        #endif
    }

    private var activeBorderColor: Color {
        #if os(tvOS)
            if isFocused {
                return result.typeColor
            }
        #endif
        if isSelected {
            return result.typeColor
        }
        return AppColors.borderSubtle
    }

    private var activeBorderWidth: CGFloat {
        #if os(tvOS)
            return isFocused ? 2.5 : 1
        #else
            return isSelected ? 1.5 : 1
        #endif
    }

    public var body: some View {
        Button(action: {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
            onTap()
        }) {
            HStack(spacing: 14) {
                // Type Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(result.typeColor.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(result.typeColor.opacity(0.35), lineWidth: 1)
                        )

                    Image(systemName: result.typeIcon)
                        .font(AppFonts.titleSmall.weight(.semibold))
                        .foregroundStyle(result.typeColor)
                }
                .frame(width: 44, height: 44)

                // Category Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(result.typeTitle)
                            .font(AppFonts.captionSmall.weight(.bold))
                            .foregroundStyle(result.typeColor)
                            .textCase(.uppercase)

                        if showPlaylistBadge {
                            Text("·")
                                .font(AppFonts.captionSmall)
                                .foregroundStyle(AppColors.textMuted)

                            Text(result.playlistBadge.playlistName)
                                .font(AppFonts.captionSmall.weight(.medium))
                                .foregroundStyle(AppColors.textMuted)
                                .lineLimit(1)
                        }
                    }

                    highlightedSearchText(result.category.name, queryTerms: queryTerms)
                        .font(AppFonts.bodyMedium.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(result.formattedItemCount)
                        .font(AppFonts.captionMedium)
                        .foregroundStyle(AppColors.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Trailing Arrow Accessory
                Image(systemName: "chevron.right")
                    .font(AppFonts.captionMedium.weight(.semibold))
                    .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(AppColors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .stroke(activeBorderColor, lineWidth: activeBorderWidth)
                    )
            )
            #if os(tvOS)
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(
                color: isFocused ? result.typeColor.opacity(0.55) : Color.black.opacity(0.4),
                radius: isFocused ? 18 : 6,
                x: 0,
                y: isFocused ? 6 : 2
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
            #else
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
            #endif
        }
        .buttonStyle(.plain)
    }
}
