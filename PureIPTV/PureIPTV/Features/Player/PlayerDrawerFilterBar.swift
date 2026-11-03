import ComposableArchitecture
import SwiftUI

// MARK: - Player Drawer Filter Bar View

/// Horizontal filter tabs with smart category chips and Liquid Glass pills.
struct PlayerDrawerFilterBar: View {
    struct FilterChipItem: Identifiable, Equatable {
        let filter: ChannelCategoryFilter
        let count: Int
        var id: String {
            filter.id
        }

        init(filter: ChannelCategoryFilter, count: Int) {
            self.filter = filter
            self.count = count
        }
    }

    let chips: [FilterChipItem]
    @Binding var selectedFilter: ChannelCategoryFilter
    let onSelect: (ChannelCategoryFilter) -> Void

    var body: some View {
        LiquidGlassContainer(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips) { chip in
                        chipButton(filter: chip.filter, count: chip.count)
                            .id(chip.id)
                    }
                }
                #if os(tvOS)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
                .focusSection()
                #else
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                #endif
            }
        }
    }

    @ViewBuilder
    private func chipButton(filter: ChannelCategoryFilter, count: Int) -> some View {
        let isSelected = selectedFilter == filter

        #if os(tvOS)
            Button {
                onSelect(filter)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: filter.icon)
                        .font(AppFonts.captionSmall.weight(.semibold))
                        .foregroundStyle(isSelected ? AppColors.textPrimary : filter.accentColor)

                    Text(filter.title)
                        .font(AppFonts.bodySmall.weight(isSelected ? .bold : .medium))
                        .lineLimit(1)

                    Text("\(count)")
                        .font(AppFonts.captionSmall.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                        )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.75))
                .background(
                    Capsule()
                        .fill(isSelected ? filter.accentColor : AppColors.surfaceSecondary)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.white.opacity(0.5) : filter.accentColor.opacity(0.25),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(TVCategoryFilterChipButtonStyle(isSelected: isSelected, accentColor: filter.accentColor))
        #else
            LiquidGlassPill(
                title: filter.title,
                icon: filter.icon,
                isSelected: isSelected,
                badgeCount: count,
                tint: filter.accentColor
            ) {
                HapticManager.shared.trigger(.light)
                onSelect(filter)
            }
        #endif
    }
}
