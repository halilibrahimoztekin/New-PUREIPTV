#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SearchHistorySectionView_iOS: View {
        let store: StoreOf<SearchFeature>

        public init(store: StoreOf<SearchFeature>) {
            self.store = store
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                if !store.pinnedSearchQueries.isEmpty {
                    pinnedSearchesSection
                }

                if !store.recentSearches.isEmpty {
                    recentSearchesSection
                }
            }
        }

        private var pinnedSearchesSection: some View {
            VStack(alignment: .leading, spacing: 14) {
                Label(AppStrings.Search.pinnedSearches, systemImage: "pin.fill")
                    .font(AppFonts.bodyLarge.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(AppStrings.Search.pinnedSearchesDescription)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.textSecondary)

                VStack(spacing: 0) {
                    ForEach(store.pinnedSearchQueries, id: \.self) { query in
                        HStack(spacing: 8) {
                            Button {
                                HapticManager.shared.trigger(.light)
                                store.send(.recentSearchTapped(query))
                            } label: {
                                HStack {
                                    Image(systemName: "pin.fill")
                                        .foregroundColor(AppColors.primary)
                                        .font(AppFonts.caption.weight(.semibold))
                                    Text(query)
                                        .font(AppFonts.bodyMedium)
                                        .foregroundColor(AppColors.onSurface)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(AppFonts.captionSmall)
                                        .foregroundColor(AppColors.onSurfaceVariant.opacity(0.3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(AppStrings.Search.runPinnedSearchHint)

                            Button {
                                store.send(.togglePinnedSearch(query))
                            } label: {
                                Image(systemName: "pin.slash")
                                    .foregroundColor(AppColors.onSurfaceVariant.opacity(0.7))
                                    .frame(width: 40, height: 40)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(AppStrings.Search.unpinSearch)
                        }

                        if query != store.pinnedSearchQueries.last {
                            Divider()
                                .background(AppColors.borderSubtle)
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppColors.borderSubtle, lineWidth: 1)
                        )
                )
            }
        }

        private var recentSearchesSection: some View {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(AppStrings.Search.recentSearches, systemImage: "clock.arrow.circlepath")
                        .font(AppFonts.bodyLarge.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.clearHistoryTapped)
                    } label: {
                        Text(AppStrings.Search.clear)
                            .font(AppFonts.bodySmall.weight(.medium))
                            .foregroundColor(AppColors.primary)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(store.recentSearches.prefix(6), id: \.id) { item in
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.recentSearchTapped(item.query))
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(AppColors.onSurfaceVariant.opacity(0.5))
                                    .font(AppFonts.caption.weight(.semibold))
                                Text(item.query)
                                    .font(AppFonts.bodyMedium)
                                    .foregroundColor(AppColors.onSurface)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(AppFonts.captionSmall)
                                    .foregroundColor(AppColors.onSurfaceVariant.opacity(0.3))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(AppColors.surfaceSecondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)

                        if item.id != store.recentSearches.prefix(6).last?.id {
                            Divider()
                                .background(AppColors.borderSubtle)
                                .padding(.leading, 40)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppColors.borderSubtle, lineWidth: 1)
                        )
                )
            }
        }
    }
#endif
