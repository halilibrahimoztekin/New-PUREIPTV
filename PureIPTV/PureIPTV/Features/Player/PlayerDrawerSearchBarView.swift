import ComposableArchitecture
import SwiftUI

// MARK: - Player Drawer Search Bar View

/// Dedicated search bar for the player sidebar drawer with clear action
/// and tokenized styling.
struct PlayerDrawerSearchBarView: View {
    @Binding var searchQuery: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.textSecondary.opacity(0.6))
            #if os(tvOS)
                .font(AppFonts.titleSmall)
            #else
                .font(AppFonts.bodyMedium)
            #endif

            TextField(AppStrings.Search.channelSearchPlaceholder, text: $searchQuery)
            #if os(tvOS)
                .font(AppFonts.titleSmall.weight(.medium))
            #else
                .font(AppFonts.bodyMedium.weight(.medium))
            #endif
                .foregroundStyle(AppColors.textPrimary)
                .tint(accentColor)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                    #if os(tvOS)
                        .font(AppFonts.titleSmall)
                    #else
                        .font(AppFonts.bodyMedium)
                    #endif
                }
                #if os(tvOS)
                .buttonStyle(TVCircleButtonStyle())
                #else
                .buttonStyle(.plain)
                #endif
            }
        }
        #if os(tvOS)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 32)
        .padding(.bottom, 14)
        #else
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        #endif
    }
}
