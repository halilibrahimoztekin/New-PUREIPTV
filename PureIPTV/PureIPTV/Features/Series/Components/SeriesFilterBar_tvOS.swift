#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS Series Filter Bar

    /// Dedicated, isolated filter bar for tvOS Series catalog.
    /// Manages series category title display, sorting menus, audio language filters, and original language chips.
    public struct SeriesFilterBar_tvOS: View {
        @Bindable var store: StoreOf<SeriesFeature>

        public init(store: StoreOf<SeriesFeature>) {
            self.store = store
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                if !store.categories.isEmpty {
                    HStack(alignment: .center) {
                        if let cat = store.categories.first(where: { $0.id == store.selectedCategoryID }) {
                            Text(cat.name)
                                .font(AppFonts.displaySmall)
                                .foregroundStyle(AppColors.textPrimary)
                        }

                        Spacer()

                        if let category = store.categories.first(where: { $0.id == store.selectedCategoryID }) {
                            CategoryContentSortMenu(
                                selection: store.lastSortMethod,
                                categoryName: category.name,
                                hasCategoryOverride: store.isCategorySortOverridden,
                                onSelect: { store.send(.setCategorySortMethod($0)) },
                                onReset: { store.send(.resetCategorySortMethod) }
                            )
                        }

                        MediaLanguageFilterBar(
                            availableFilters: store.availableLanguageFilters,
                            selectedFilter: store.selectedLanguageFilter,
                            counts: store.languageFilterCounts
                        ) { filter in
                            store.send(.setLanguageFilter(filter))
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.top, 40)
                    .padding(.bottom, 12)
                }

                OriginalLanguageFilterBar(
                    availableCodes: store.availableOriginalLanguageCodes,
                    selectedCode: store.selectedOriginalLanguageCode,
                    counts: store.originalLanguageCounts
                ) { code in
                    store.send(.setOriginalLanguageFilter(code))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 8)
            }
        }
    }
#endif
