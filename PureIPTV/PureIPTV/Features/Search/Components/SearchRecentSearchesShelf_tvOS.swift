#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SearchRecentSearchesShelf_tvOS: View {
        let store: StoreOf<SearchFeature>

        public init(store: StoreOf<SearchFeature>) {
            self.store = store
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 48) {
                if !store.pinnedSearchQueries.isEmpty {
                    pinnedSearchesSection
                }

                if !store.recentSearches.isEmpty {
                    recentSearchesSection
                }

                quickTagsSection
            }
        }

        private var pinnedSearchesSection: some View {
            VStack(alignment: .leading, spacing: 24) {
                Label(AppStrings.Search.pinnedSearches, systemImage: "pin.fill")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.textPrimary)
                Text(AppStrings.Search.pinnedSearchesDescription)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.textSecondary)

                VStack(spacing: 14) {
                    ForEach(store.pinnedSearchQueries, id: \.self) { query in
                        HStack(spacing: 16) {
                            Button {
                                store.send(.recentSearchTapped(query))
                            } label: {
                                HStack(spacing: 20) {
                                    Image(systemName: "pin.fill")
                                        .font(AppFonts.title)
                                        .foregroundColor(AppColors.primary)
                                    Text(query)
                                        .font(AppFonts.displayMedium)
                                        .foregroundColor(AppColors.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(AppFonts.titleSmall.weight(.semibold))
                                        .foregroundColor(AppColors.onSurfaceVariant.opacity(0.4))
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 18)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(TVCapsuleButtonStyle())
                            .accessibilityHint(AppStrings.Search.runPinnedSearchHint)

                            Button {
                                store.send(.togglePinnedSearch(query))
                            } label: {
                                Image(systemName: "pin.slash")
                                    .font(AppFonts.titleSmall.weight(.semibold))
                                    .foregroundColor(AppColors.onSurfaceVariant.opacity(0.75))
                                    .frame(width: 56, height: 56)
                            }
                            .buttonStyle(TVCircleButtonStyle())
                            .accessibilityLabel(AppStrings.Search.unpinSearch)
                        }
                    }
                }
            }
        }

        private var recentSearchesSection: some View {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Label(AppStrings.Search.recentSearches, systemImage: "clock.arrow.circlepath")
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Button {
                        store.send(.clearHistoryTapped)
                    } label: {
                        Text(AppStrings.Search.clear)
                            .font(AppFonts.titleSmall.weight(.semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(TVCapsuleButtonStyle())
                }

                VStack(spacing: 0) {
                    ForEach(store.recentSearches.prefix(5), id: \.id) { item in
                        Button {
                            store.send(.recentSearchTapped(item.query))
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .font(AppFonts.title)
                                    .foregroundColor(AppColors.onSurfaceVariant.opacity(0.5))
                                Text(item.query)
                                    .font(AppFonts.displayMedium)
                                    .foregroundColor(AppColors.onSurface)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(AppFonts.title)
                                    .foregroundColor(AppColors.onSurfaceVariant.opacity(0.3))
                            }
                            .padding(.horizontal, 30)
                            .padding(.vertical, 20)
                            .background(AppColors.surfaceSecondary.opacity(0.5))
                        }
                        .buttonStyle(TVCategoryRowButtonStyle(accentColor: AppColors.primary, isSelected: false))

                        if item.id != store.recentSearches.prefix(5).last?.id {
                            Divider()
                                .background(AppColors.borderSubtle)
                                .padding(.leading, 70)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.surfaceSecondary)
                )
            }
        }

        private var quickTagsSection: some View {
            VStack(alignment: .leading, spacing: 28) {
                Label(AppStrings.Search.quickTags, systemImage: "sparkles")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.textPrimary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 30)], spacing: 30) {
                    ForEach(store.quickTags) { tag in
                        Button {
                            store.send(.tagSelected(tag))
                        } label: {
                            HStack(spacing: 20) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(tag.color.opacity(0.2))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: tag.icon)
                                        .font(AppFonts.displayMedium.weight(.semibold))
                                        .foregroundColor(tag.color)
                                }

                                Text(tag.title)
                                    .font(AppFonts.title.weight(.semibold))
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(AppFonts.titleSmall.weight(.semibold))
                                    .foregroundColor(AppColors.onSurfaceVariant.opacity(0.4))
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                        }
                        .buttonStyle(TVCategoryRowButtonStyle(accentColor: tag.color, isSelected: false))
                    }
                }
            }
        }
    }
#endif
