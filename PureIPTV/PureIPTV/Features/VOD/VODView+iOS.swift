#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - iOS VOD View

    public struct VODView_iOS: View {
        @Bindable var store: StoreOf<VODFeature>
        let config: PlaylistConfig
        let onSearch: (() -> Void)?

        /// Adaptive sizing keeps posters large; standard iPhone widths fit two columns.
        private let columns: [GridItem] = [
            GridItem(.adaptive(minimum: 148, maximum: 210), spacing: 14),
        ]
        @State private var categorySearchQuery = ""
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        public init(store: StoreOf<VODFeature>, config: PlaylistConfig, onSearch: (() -> Void)? = nil) {
            self.store = store
            self.config = config
            self.onSearch = onSearch
        }

        public init(store: StoreOf<VODFeature>, serverURL: String, username: String, password: String, onSearch: (() -> Void)? = nil) {
            self.store = store
            self.onSearch = onSearch
            if (username.isEmpty && password.isEmpty) || serverURL.lowercased().contains(".m3u") {
                config = PlaylistConfig(type: .m3u, m3uURL: URL(string: serverURL))
            } else {
                config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
            }
        }

        public var body: some View {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Header Actions ─────────────────────────────────
                    HStack {
                        Text(AppStrings.VOD.title)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(2)

                        Spacer()

                        LiquidGlassContainer(spacing: 8) {
                            HStack(spacing: 8) {
                                if [PlaylistType.m3u, .plex, .emby].contains(config.type) {
                                    Button {
                                        store.send(.refreshContentTapped)
                                    } label: {
                                        if store.isRefreshingContent {
                                            ProgressView()
                                                .frame(width: 34, height: 34)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(AppFonts.bodySmall)
                                                .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                                                .frame(width: 34, height: 34)
                                        }
                                    }
                                    .liquidGlass(shape: .circle, isInteractive: true)
                                    .buttonStyle(.plain)
                                    .disabled(store.isRefreshingContent || store.isLoadingCategories)
                                    .accessibilityLabel("Filmleri yenile")
                                }

                                Button {
                                    store.send(.editCategoriesTapped)
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(AppFonts.titleSmall)
                                        .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                                        .frame(width: 34, height: 34)
                                }
                                .liquidGlass(shape: .circle, isInteractive: true)
                                .buttonStyle(.plain)
                                .accessibilityLabel(AppStrings.CategoryMgmt.manageTitle(for: AppStrings.VOD.title))

                                if let onSearch {
                                    Button(action: onSearch) {
                                        Image(systemName: "magnifyingglass")
                                            .font(AppFonts.titleSmall)
                                            .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                                            .frame(width: 34, height: 34)
                                    }
                                    .liquidGlass(shape: .circle, isInteractive: true)
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(AppStrings.Search.searchPlaceholder)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                    if let refreshMessage = store.refreshMessage {
                        Text(refreshMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                    }

                    // ── Category horizontal scroll ─────────────────────
                    categoryBar
                        .padding(.bottom, 6)

                    categorySortMenu

                    // ── Audio & Subtitle Language Filter Bar ───────────
                    MediaLanguageFilterBar(
                        availableFilters: store.availableLanguageFilters,
                        selectedFilter: store.selectedLanguageFilter,
                        counts: store.languageFilterCounts
                    ) { filter in
                        store.send(.setLanguageFilter(filter))
                    }
                    .padding(.bottom, 10)

                    OriginalLanguageFilterBar(
                        availableCodes: store.availableOriginalLanguageCodes,
                        selectedCode: store.selectedOriginalLanguageCode,
                        counts: store.originalLanguageCounts
                    ) { code in
                        store.send(.setOriginalLanguageFilter(code))
                    }
                    .padding(.bottom, 8)

                    // VOD grid
                    if store.isLoadingCategories {
                        loadingView
                    } else if store.categories.isEmpty {
                        emptyView
                    } else {
                        vodGrid
                    }
                }
            }
            .task {
                // VOD's on-appear reducer synchronously updates catalog state.
                // Run it as a view task so that work is not dispatched while
                // SwiftUI is processing its appearance update group.
                await store.send(.onAppear(config: config)).finish()
            }
            .onChange(of: config.playlistID) { _, _ in
                categorySearchQuery = ""
            }
        }

        // MARK: – Category Bar

        private var filteredCategories: [MediaModels.Category] {
            let query = categorySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return store.categories }
            return store.categories.filter { $0.name.localizedStandardContains(query) }
        }

        private var categoryBar: some View {
            let categories = filteredCategories
            return VStack(spacing: 8) {
                if !store.categories.isEmpty {
                    CategorySearchField(text: $categorySearchQuery) {
                        if let firstMatch = categories.first {
                            store.send(.categorySelected(firstMatch))
                        }
                    }
                    .padding(.horizontal, 16)

                    ScrollViewReader { proxy in
                        Group {
                            if categories.isEmpty {
                                Text(AppStrings.Common.categoryNotFound)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                                    .padding(.horizontal, 16)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(categories) { category in
                                            CategoryPill(
                                                name: category.name,
                                                isSelected: store.selectedCategoryID == category.id
                                            ) {
                                                store.send(.categorySelected(category))
                                            }
                                            .id(category.id)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .onChange(of: categorySearchQuery) { _, _ in
                            guard let firstMatchID = categories.first?.id else { return }
                            if reduceMotion {
                                proxy.scrollTo(firstMatchID, anchor: .center)
                            } else {
                                withAnimation { proxy.scrollTo(firstMatchID, anchor: .center) }
                            }
                        }
                        .onChange(of: store.selectedCategoryID) { _, selectedID in
                            guard let selectedID,
                                  categories.contains(where: { $0.id == selectedID })
                            else { return }
                            if reduceMotion {
                                proxy.scrollTo(selectedID, anchor: .center)
                            } else {
                                withAnimation { proxy.scrollTo(selectedID, anchor: .center) }
                            }
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private var categorySortMenu: some View {
            if let category = store.categories.first(where: { $0.id == store.selectedCategoryID }) {
                HStack {
                    Spacer(minLength: 0)
                    CategoryContentSortMenu(
                        selection: store.lastSortMethod,
                        categoryName: category.name,
                        hasCategoryOverride: store.isCategorySortOverridden,
                        onSelect: { store.send(.setCategorySortMethod($0)) },
                        onReset: { store.send(.resetCategorySortMethod) }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }

        // MARK: – VOD Grid

        private var vodGrid: some View {
            ScrollView {
                if store.isLoadingVODs, store.currentVODs.isEmpty {
                    loadingView
                } else if store.currentVODs.isEmpty {
                    if let categoryID = store.selectedCategoryID,
                       let error = store.categoryContentErrors[categoryID]
                    {
                        RetryableSectionEmptyState(message: error) {
                            store.send(.retryCategoryContent(categoryID: categoryID))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    } else {
                        VStack(spacing: 14) {
                            if !store.rawVODs.isEmpty, store.selectedLanguageFilter != .all || store.selectedOriginalLanguageCode != nil {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 38))
                                    .foregroundStyle(AppColors.primary.opacity(0.8))
                                Text(AppStrings.MediaFilter.noMatchingResults)
                                    .font(AppFonts.bodyMedium)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                Button {
                                    store.send(.setLanguageFilter(.all))
                                    store.send(.setOriginalLanguageFilter(nil))
                                } label: {
                                    Text(AppStrings.MediaFilter.all)
                                        .font(AppFonts.captionSmall.weight(.bold))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 8)
                                        .background(AppColors.primary, in: Capsule())
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                .padding(.top, 4)
                            } else {
                                Image(systemName: "film")
                                    .font(.system(size: 36))
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                                Text(AppStrings.VOD.emptyCategoryMovies)
                                    .font(AppFonts.bodyMedium)
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    }
                } else {
                    VStack(spacing: 14) {
                        if let categoryID = store.selectedCategoryID,
                           let error = store.categoryContentErrors[categoryID]
                        {
                            RetryableSectionEmptyState(message: error) {
                                store.send(.retryCategoryContent(categoryID: categoryID))
                            }
                        }
                        if store.isLoadingVODs {
                            PureLoadingView(size: .small)
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(store.currentVODs) { vod in
                                VODCardView(
                                    vod: vod,
                                    isSelected: store.selectedVOD?.id == vod.id
                                ) {
                                    store.send(.vodSelected(vod))
                                }
                                .contextMenu {
                                    Button {
                                        store.send(.hideMedia(vod))
                                    } label: {
                                        Label(AppStrings.Common.hideMediaItem, systemImage: "eye.slash")
                                    }

                                    Button {
                                        store.send(.toggleFavorite(vod))
                                    } label: {
                                        if store.favoriteIDs.contains(vod.id) {
                                            Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                                        } else {
                                            Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
            }
        }

        // MARK: – Loading & Empty

        private var loadingView: some View {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0 ..< 12, id: \.self) { _ in
                    VODCardView(
                        vod: .placeholder,
                        isSelected: false
                    ) {}
                        .shimmeringPlaceholder(isLoading: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }

        @ViewBuilder
        private var emptyView: some View {
            if let errorMessage = store.errorMessage {
                RetryableSectionEmptyState(message: errorMessage) {
                    store.send(.reloadCategories(config: config))
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                    Text(AppStrings.Common.categoryNotFound)
                        .font(AppFonts.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Category Pill

    private struct CategoryPill: View {
        let name: String
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            LiquidGlassPill(
                title: name,
                isSelected: isSelected,
                tint: AppColors.primary
            ) {
                HapticManager.shared.trigger(.light)
                action()
            }
        }
    }
#endif
