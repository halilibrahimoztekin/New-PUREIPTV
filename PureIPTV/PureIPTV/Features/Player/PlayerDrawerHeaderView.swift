import ComposableArchitecture
import SwiftUI

// MARK: - Player Drawer Header View

/// Header view for the player sidebar drawer with channel count,
/// cleaner toggle, sort options, and close action.
struct PlayerDrawerHeaderView: View {
    @Bindable var store: StoreOf<PlayerFeature>
    let selectedFilter: ChannelCategoryFilter
    let channelCount: Int
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(selectedFilter.accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: selectedFilter.icon)
                    .font(AppFonts.titleSmall.weight(.bold))
                    .foregroundStyle(selectedFilter.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.LiveTV.channelsTitle)
                    .font(AppFonts.headline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: 6) {
                    Text("\(channelCount) " + "Kanal".localized)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.7))

                    if selectedFilter != .all {
                        Text("•")
                            .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                        Text(selectedFilter.title)
                            .foregroundStyle(selectedFilter.accentColor)
                            .fontWeight(.semibold)
                    }
                }
                .font(AppFonts.caption)
            }

            Spacer()

            // Cleaner & Sort Controls
            HStack(spacing: 8) {
                cleanerToggleButton
                sortMenuButton
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(AppFonts.titleSmall)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.75))
            }
            #if os(tvOS)
            .buttonStyle(TVCircleButtonStyle())
            #else
            .buttonStyle(.plain)
            #endif
        }
        #if os(tvOS)
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 14)
        #else
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 12)
        #endif
    }

    // MARK: - Sort Menu Button

    private var sortMenuButton: some View {
        Menu {
            Section(AppStrings.LiveTV.sortTitle) {
                ForEach(ChannelSortOption.allCases) { option in
                    Button {
                        #if !os(tvOS)
                            HapticManager.shared.trigger(.light)
                        #endif
                        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                            store.send(.setChannelSortOption(option))
                        }
                    } label: {
                        HStack {
                            Label(option.title, systemImage: option.icon)
                            if store.channelSortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: store.channelSortOption.icon)
                    .font(AppFonts.captionSmall.weight(.bold))
                    .foregroundStyle(store.channelSortOption.accentColor)

                Text(store.channelSortOption.title)
                    .font(AppFonts.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(AppFonts.captionSmall)
                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))
            }
            #if os(tvOS)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppColors.surfaceSecondary, in: Capsule())
            .overlay(Capsule().stroke(store.channelSortOption.accentColor.opacity(0.35), lineWidth: 1))
            .buttonStyle(TVSortOptionButtonStyle(accentColor: store.channelSortOption.accentColor))
            #else
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .liquidGlass(shape: .capsule, tint: store.channelSortOption.accentColor, isInteractive: true)
            .buttonStyle(.plain)
            #endif
        }
    }

    // MARK: - Cleaner Toggle Button

    private var cleanerToggleButton: some View {
        Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                store.send(.toggleChannelNameCleaning)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: store.isChannelNameCleaningEnabled ? "wand.and.stars" : "wand.and.stars.inverse")
                    .font(AppFonts.caption.bold())
                    .foregroundStyle(store.isChannelNameCleaningEnabled ? AppColors.warningGold : AppColors.textSecondary.opacity(0.5))

                #if !os(tvOS)
                    Text(store.isChannelNameCleaningEnabled ? "Sade" : "Ham")
                        .font(AppFonts.caption.bold())
                        .foregroundStyle(store.isChannelNameCleaningEnabled ? AppColors.warningGold : AppColors.textSecondary.opacity(0.6))
                #endif
            }
            #if os(tvOS)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(store.isChannelNameCleaningEnabled ? AppColors.warningGold.opacity(0.15) : AppColors.surfaceSecondary, in: Capsule())
            .overlay(Capsule().stroke(store.isChannelNameCleaningEnabled ? AppColors.warningGold.opacity(0.4) : AppColors.borderMedium, lineWidth: 1))
            .buttonStyle(TVCleanerButtonStyle(isActive: store.isChannelNameCleaningEnabled))
            #else
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .liquidGlass(shape: .capsule, tint: store.isChannelNameCleaningEnabled ? AppColors.warningGold : nil, isInteractive: true)
            .buttonStyle(.plain)
            #endif
        }
    }
}
