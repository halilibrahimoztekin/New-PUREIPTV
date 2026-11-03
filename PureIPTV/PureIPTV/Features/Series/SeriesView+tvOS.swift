#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS Series View

    public struct SeriesView_tvOS: View {
        @Bindable var store: StoreOf<SeriesFeature>
        let config: PlaylistConfig

        @FocusState private var focusedCategory: String?
        @FocusState private var focusedSeriesID: String?

        @State private var currentScrubLetter: String = ""
        @State private var isScrubOverlayVisible: Bool = false
        @State private var hideScrubTask: Task<Void, Never>?
        @State private var categorySearchQuery = ""
        @State private var posterPrefetchController = TVPosterPrefetchController()

        public init(store: StoreOf<SeriesFeature>, config: PlaylistConfig) {
            self.store = store
            self.config = config
        }

        public init(store: StoreOf<SeriesFeature>, serverURL: String, username: String, password: String) {
            self.store = store
            if (username.isEmpty && password.isEmpty) || serverURL.lowercased().contains(".m3u") {
                config = PlaylistConfig(type: .m3u, m3uURL: URL(string: serverURL))
            } else {
                config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
            }
        }

        public var body: some View {
            HStack(spacing: 0) {
                // ── Left: Category list ───────────────────────────────
                categoryColumn
                    .frame(width: 300)
                    .focusSection()

                // ── Divider ──────────────────────────────────────────
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
                    .frame(width: 24)

                // ── Right: Series grid ──────────────────────────────────
                seriesArea
                    .focusSection()
            }
            .background(
                DynamicMeshBackgroundView(
                    imageURL: focusedSeries?.coverURL,
                    titleSeed: focusedSeries?.title ?? "Series",
                    imageRequestDebounceNanoseconds: 150_000_000,
                    userAgentOverride: focusedSeries?.userAgentOverride,
                    playlistID: focusedSeries?.playlistID
                )
            )
            .onAppear {
                store.send(.onAppear(config: config))
            }
            .onChange(of: config.playlistID) { _, _ in
                categorySearchQuery = ""
            }
            .onDisappear {
                posterPrefetchController.cancel()
            }
        }

        private var focusedSeries: MediaModels.Item? {
            if let focusedSeriesID {
                return store.currentSeries.first(where: { $0.id == focusedSeriesID })
            }
            return store.selectedSeries ?? store.currentSeries.first
        }

        private var filteredCategories: [MediaModels.Category] {
            let query = categorySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return store.categories }
            return store.categories.filter { $0.name.localizedStandardContains(query) }
        }

        private func restoredSeriesFocusID(preferred: String?, categoryID: String?) -> String? {
            let visibleIDs = Set(store.currentSeries.map(\.id))
            let rememberedID = TVFocusMemory.shared.lastSeries(in: categoryID, fallback: nil)
            if let rememberedID, visibleIDs.contains(rememberedID) {
                return rememberedID
            }
            if let preferred, visibleIDs.contains(preferred) {
                return preferred
            }
            return store.currentSeries.first?.id
        }

        // MARK: – Category Column

        private var categoryColumn: some View {
            ScrollViewReader { catProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        HStack {
                            Text(AppStrings.Series.title)
                                .font(AppFonts.displayMedium)
                                .foregroundStyle(AppColors.onSurface)
                            Spacer()
                            if [PlaylistType.m3u, .plex, .emby].contains(config.type) {
                                Button {
                                    guard !store.isRefreshingContent, !store.isLoadingCategories else { return }
                                    store.send(.refreshContentTapped)
                                } label: {
                                    Group {
                                        if store.isRefreshingContent {
                                            ProgressView()
                                        } else {
                                            Image(systemName: "arrow.clockwise").font(.system(size: 18))
                                        }
                                    }
                                    .padding(8)
                                }
                                .buttonStyle(TVCircleButtonStyle())
                                .accessibilityLabel("Dizileri yenile")
                            }

                            Button {
                                store.send(.editCategoriesTapped)
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 18))
                                    .padding(8)
                            }
                            .buttonStyle(TVCircleButtonStyle())
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 48)
                        .padding(.bottom, 16)

                        if let refreshMessage = store.refreshMessage {
                            Text(refreshMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 24)
                        }

                        if store.isLoadingCategories {
                            PureLoadingView(size: .small)
                                .padding(.top, 40)
                        } else if store.categories.isEmpty, let errorMessage = store.errorMessage {
                            RetryableSectionEmptyState(message: errorMessage) {
                                store.send(.reloadCategories(config: config))
                            }
                            .frame(height: 280)
                        } else {
                            let categories = filteredCategories
                            if !store.categories.isEmpty {
                                CategorySearchField(text: $categorySearchQuery) {
                                    if let firstMatch = categories.first {
                                        store.send(.categorySelected(firstMatch))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 10)
                            }

                            if !store.categories.isEmpty, categories.isEmpty {
                                Text(AppStrings.Common.categoryNotFound)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                            }

                            ForEach(categories) { category in
                                TVSeriesCategoryRow(
                                    category: category,
                                    isSelected: store.selectedCategoryID == category.id,
                                    isLocked: store.categoryPreferences[category.id]?.isLocked ?? false
                                ) {
                                    store.send(.categorySelected(category))
                                }
                                .padding(.horizontal, 16)
                                .focused($focusedCategory, equals: category.id)
                                .id(category.id)
                            }
                        }
                    }
                    .padding(.bottom, 48)
                }
                .background(AppColors.surface)
                .onChange(of: store.selectedCategoryID) { _, newCatID in
                    if let newCatID {
                        if !filteredCategories.contains(where: { $0.id == newCatID }) {
                            categorySearchQuery = ""
                        }
                        focusedCategory = newCatID
                        TVFocusMemory.shared.lastSelectedSeriesCategoryID = newCatID
                        withAnimation { catProxy.scrollTo(newCatID, anchor: .center) }
                    }
                }
                .onChange(of: focusedCategory) { _, newCatID in
                    if let newCatID {
                        TVFocusMemory.shared.lastSelectedSeriesCategoryID = newCatID
                    }
                }
                .onAppear {
                    let targetCatID = store.selectedCategoryID ?? TVFocusMemory.shared.lastSelectedSeriesCategoryID ?? store.categories.first?.id
                    if let targetCatID {
                        focusedCategory = targetCatID
                        withAnimation { catProxy.scrollTo(targetCatID, anchor: .center) }
                    }
                }
            }
        }

        // MARK: – Series Area

        private var seriesArea: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header Bar with Title & MediaLanguageFilterBar
                if !store.categories.isEmpty {
                    HStack(alignment: .center) {
                        if let cat = store.categories.first(where: { $0.id == store.selectedCategoryID }) {
                            Text(cat.name)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color.white)
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

                // Grid or Empty State
                if store.isLoadingSeries, store.currentSeries.isEmpty {
                    VStack {
                        PureLoadingView(size: .large, text: AppStrings.Series.loadingSeries)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.currentSeries.isEmpty {
                    if let categoryID = store.selectedCategoryID,
                       let error = store.categoryContentErrors[categoryID]
                    {
                        RetryableSectionEmptyState(message: error) {
                            store.send(.retryCategoryContent(categoryID: categoryID))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 20) {
                            if !store.rawSeries.isEmpty, store.selectedLanguageFilter != .all || store.selectedOriginalLanguageCode != nil {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 64))
                                    .foregroundStyle(AppColors.primary.opacity(0.8))
                                Text(AppStrings.MediaFilter.noMatchingResults)
                                    .font(AppFonts.title)
                                    .foregroundStyle(AppColors.textPrimary.opacity(0.8))

                                Button {
                                    store.send(.setLanguageFilter(.all))
                                    store.send(.setOriginalLanguageFilter(nil))
                                } label: {
                                    Text(AppStrings.MediaFilter.all)
                                        .font(AppFonts.titleSmall)
                                        .padding(.horizontal, 28)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(TVCapsuleButtonStyle(isPrimary: true, isSelected: false))
                                .padding(.top, 12)
                            } else {
                                Image(systemName: "tv")
                                    .font(.system(size: 60))
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.25))
                                Text(AppStrings.Series.noSeries)
                                    .font(AppFonts.displayMedium)
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollViewReader { seriesProxy in
                        ScrollView {
                            if let categoryID = store.selectedCategoryID,
                               let error = store.categoryContentErrors[categoryID]
                            {
                                RetryableSectionEmptyState(message: error) {
                                    store.send(.retryCategoryContent(categoryID: categoryID))
                                }
                            }
                            if store.isLoadingSeries {
                                PureLoadingView(size: .small)
                            }
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 32)],
                                spacing: 32
                            ) {
                                ForEach(store.currentSeries) { series in
                                    TVSeriesCard(
                                        series: series,
                                        isSelected: store.selectedSeries?.id == series.id
                                    ) {
                                        store.send(.seriesSelected(series))
                                    }
                                    .focused($focusedSeriesID, equals: series.id)
                                    .id(series.id)
                                    .contextMenu {
                                        Button {
                                            store.send(.hideMedia(series))
                                        } label: {
                                            Label(AppStrings.Common.hideMediaItem, systemImage: "eye.slash")
                                        }

                                        Button {
                                            store.send(.toggleFavorite(series))
                                        } label: {
                                            if store.favoriteIDs.contains(series.id) {
                                                Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                                            } else {
                                                Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                                            }
                                        }

                                        Button {
                                            store.send(.seriesSelected(series))
                                        } label: {
                                            Label("Bölümleri & Sezonları Gör", systemImage: "list.number")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 48)
                            .padding(.vertical, 32)
                        }
                        .onChange(of: store.selectedSeries) { _, newSeries in
                            guard let seriesID = newSeries?.id,
                                  store.currentSeries.contains(where: { $0.id == seriesID })
                            else { return }
                            TVFocusMemory.shared.recordSeries(seriesID, in: store.selectedCategoryID)
                            focusedSeriesID = seriesID
                            withAnimation { seriesProxy.scrollTo(seriesID, anchor: .center) }
                        }
                        .onChange(of: store.lastSortMethod) { _, _ in
                            let categoryID = store.selectedCategoryID
                            let targetID = restoredSeriesFocusID(preferred: focusedSeriesID, categoryID: categoryID)
                            guard let targetID else { return }
                            focusedSeriesID = targetID
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                guard store.selectedCategoryID == categoryID,
                                      focusedSeriesID == targetID,
                                      store.currentSeries.contains(where: { $0.id == targetID })
                                else { return }
                                withAnimation { seriesProxy.scrollTo(targetID, anchor: .center) }
                            }
                        }
                        .onChange(of: store.selectedCategoryID) { _, newCatID in
                            let targetID = restoredSeriesFocusID(preferred: nil, categoryID: newCatID)
                            if let targetID {
                                focusedSeriesID = targetID
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    guard store.selectedCategoryID == newCatID,
                                          focusedSeriesID == targetID,
                                          store.currentSeries.contains(where: { $0.id == targetID })
                                    else { return }
                                    withAnimation { seriesProxy.scrollTo(targetID, anchor: .center) }
                                }
                            }
                        }
                        .onAppear {
                            let categoryID = store.selectedCategoryID
                            let targetID = restoredSeriesFocusID(preferred: store.selectedSeries?.id, categoryID: categoryID)
                            if let targetID {
                                focusedSeriesID = targetID
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    guard store.selectedCategoryID == categoryID,
                                          focusedSeriesID == targetID,
                                          store.currentSeries.contains(where: { $0.id == targetID })
                                    else { return }
                                    withAnimation { seriesProxy.scrollTo(targetID, anchor: .center) }
                                }
                            }
                        }
                        .onChange(of: focusedSeriesID) { _, newID in
                            posterPrefetchController.schedule(focusedID: newID, items: store.currentSeries)
                            guard let newID else { return }
                            guard let series = store.currentSeries.first(where: { $0.id == newID }) else { return }
                            TVFocusMemory.shared.recordSeries(newID, in: store.selectedCategoryID)
                            let firstChar = MediaLibraryDerivedData.alphabetLetter(for: series.title)
                            if firstChar != currentScrubLetter {
                                currentScrubLetter = firstChar
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    isScrubOverlayVisible = true
                                }
                                hideScrubTask?.cancel()
                                hideScrubTask = Task {
                                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                                    guard !Task.isCancelled else { return }
                                    await MainActor.run {
                                        withAnimation(.easeOut(duration: 0.35)) {
                                            isScrubOverlayVisible = false
                                        }
                                    }
                                }
                            }
                        }
                        .overlay(
                            TVAlphabetScrubberOverlay(
                                currentLetter: currentScrubLetter,
                                isVisible: isScrubOverlayVisible,
                                availableLetters: store.availableLetters
                            )
                        )
                    }
                }
            }
        }
    }

    // MARK: - TV Series Category Row

    private struct TVSeriesCategoryRow: View {
        let category: MediaModels.Category
        let isSelected: Bool
        let isLocked: Bool
        let action: () -> Void

        init(category: MediaModels.Category, isSelected: Bool, isLocked: Bool = false, action: @escaping () -> Void) {
            self.category = category
            self.isSelected = isSelected
            self.isLocked = isLocked
            self.action = action
        }

        var body: some View {
            Button(action: action) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isSelected ? AppColors.success : Color.clear)
                        .frame(width: 4, height: 26)

                    Text(category.name)
                        .font(AppFonts.titleSmall)
                        .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.7))
                        .lineLimit(1)

                    Spacer()

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.warning.opacity(0.85))
                    }
                }
            }
            .buttonStyle(TVCategoryRowButtonStyle(accentColor: AppColors.success, isSelected: isSelected))
        }
    }

#endif
