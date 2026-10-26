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
                    .focusGuideBoundary()

                // ── Divider with Focus Guide Bridge ───────────────────
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)
                    TVFocusGuideBridge()
                        .frame(width: 24)
                }

                // ── Right: Series grid ──────────────────────────────────
                seriesArea
                    .focusSection()
                    .focusGuideBoundary()
            }
            .background(
                DynamicMeshBackgroundView(
                    imageURL: focusedSeries?.coverURL,
                    titleSeed: focusedSeries?.title ?? "Series",
                    imageRequestDebounceNanoseconds: 150_000_000
                )
            )
            .onAppear {
                store.send(.onAppear(config: config))
            }
            .sheet(item: $store.scope(state: \.parentalLock, action: \.parentalLock)) { store in
                ParentalLockView(store: store)
            }
            .sheet(item: $store.scope(state: \.categoryManagement, action: \.categoryManagement)) { store in
                CategoryManagementView(store: store)
            }
        }

        private var focusedSeries: MediaModels.Item? {
            if let focusedSeriesID {
                return store.currentSeries.first(where: { $0.id == focusedSeriesID })
            }
            return store.selectedSeries ?? store.currentSeries.first
        }

        // MARK: – Category Column

        private var categoryColumn: some View {
            ScrollViewReader { catProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        HStack {
                            Text(AppStrings.Series.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color(hex: "#E4E1E7"))
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
                            ForEach(store.categories) { category in
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
                .background(Color(hex: "#0C0C10"))
                .onChange(of: store.selectedCategoryID) { _, newCatID in
                    if let newCatID {
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
                if store.isLoadingSeries {
                    VStack {
                        PureLoadingView(size: .large, text: AppStrings.Series.loadingSeries)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.currentSeries.isEmpty {
                    VStack(spacing: 20) {
                        if !store.rawSeries.isEmpty, store.selectedLanguageFilter != .all || store.selectedOriginalLanguageCode != nil {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 64))
                                .foregroundStyle(Color(hex: "#0A84FF").opacity(0.8))
                            Text(AppStrings.MediaFilter.noMatchingResults)
                                .font(.system(size: 26))
                                .foregroundStyle(Color.white.opacity(0.8))

                            Button {
                                store.send(.setLanguageFilter(.all))
                                store.send(.setOriginalLanguageFilter(nil))
                            } label: {
                                Text(AppStrings.MediaFilter.all)
                                    .font(.system(size: 20, weight: .bold))
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(TVCapsuleButtonStyle(isPrimary: true, isSelected: false))
                            .padding(.top, 12)
                        } else {
                            Image(systemName: "tv")
                                .font(.system(size: 60))
                                .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                            Text(AppStrings.Series.noSeries)
                                .font(.system(size: 28))
                                .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.4))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { seriesProxy in
                        ScrollView {
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
                            if let seriesID = newSeries?.id {
                                TVFocusMemory.shared.recordSeries(seriesID, in: store.selectedCategoryID)
                                focusedSeriesID = seriesID
                                withAnimation { seriesProxy.scrollTo(seriesID, anchor: .center) }
                            }
                        }
                        .onChange(of: store.selectedCategoryID) { _, newCatID in
                            let targetID = TVFocusMemory.shared.lastSeries(
                                in: newCatID,
                                fallback: store.currentSeries.first?.id
                            )
                            if let targetID {
                                focusedSeriesID = targetID
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation { seriesProxy.scrollTo(targetID, anchor: .center) }
                                }
                            }
                        }
                        .onAppear {
                            let targetID = TVFocusMemory.shared.lastSeries(
                                in: store.selectedCategoryID,
                                fallback: store.selectedSeries?.id ?? store.currentSeries.first?.id
                            )
                            if let targetID {
                                focusedSeriesID = targetID
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation { seriesProxy.scrollTo(targetID, anchor: .center) }
                                }
                            }
                        }
                        .onChange(of: focusedSeriesID) { _, newID in
                            guard let newID else { return }
                            TVFocusMemory.shared.recordSeries(newID, in: store.selectedCategoryID)
                            guard let series = store.currentSeries.first(where: { $0.id == newID }) else { return }
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
                        .fill(isSelected ? Color(hex: "#30D158") : Color.clear)
                        .frame(width: 4, height: 26)

                    Text(category.name)
                        .font(.system(size: 22, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? Color.white : Color(hex: "#C0C6D6").opacity(0.7))
                        .lineLimit(1)

                    Spacer()

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange.opacity(0.85))
                    }
                }
            }
            .buttonStyle(TVCategoryRowButtonStyle(accentColor: Color(hex: "#30D158"), isSelected: isSelected))
        }
    }

#endif
