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
                    titleSeed: focusedSeries?.title ?? "Series"
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

                        if store.isLoadingCategories {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color(hex: "#0A84FF"))
                                .padding(.top, 40)
                        } else {
                            ForEach(store.categories) { category in
                                TVSeriesCategoryRow(
                                    category: category,
                                    isSelected: store.selectedCategoryID == category.id
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
                        withAnimation { catProxy.scrollTo(newCatID, anchor: .center) }
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

                // Grid or Empty State
                if store.isLoadingSeries {
                    VStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color(hex: "#0A84FF"))
                            .scaleEffect(1.5)
                        Text(AppStrings.Series.loadingSeries)
                            .font(.system(size: 24))
                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                            .padding(.top, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.currentSeries.isEmpty {
                    VStack(spacing: 20) {
                        if !store.rawSeries.isEmpty, store.selectedLanguageFilter != .all {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 64))
                                .foregroundStyle(Color(hex: "#0A84FF").opacity(0.8))
                            Text(AppStrings.MediaFilter.noMatchingResults)
                                .font(.system(size: 26))
                                .foregroundStyle(Color.white.opacity(0.8))

                            Button {
                                store.send(.setLanguageFilter(.all))
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
                                    }
                                }
                            }
                            .padding(.horizontal, 48)
                            .padding(.vertical, 32)
                        }
                        .onChange(of: store.selectedSeries) { _, newSeries in
                            if let seriesID = newSeries?.id {
                                focusedSeriesID = seriesID
                                withAnimation { seriesProxy.scrollTo(seriesID, anchor: .center) }
                            }
                        }
                        .onAppear {
                            if let lastSelectedID = store.selectedSeries?.id {
                                focusedSeriesID = lastSelectedID
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation { seriesProxy.scrollTo(lastSelectedID, anchor: .center) }
                                }
                            }
                        }
                        .onChange(of: focusedSeriesID) { _, newID in
                            guard let newID, let series = store.currentSeries.first(where: { $0.id == newID }) else { return }
                            let firstChar = String(series.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
                            if !firstChar.isEmpty, firstChar != currentScrubLetter {
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
                                isVisible: isScrubOverlayVisible
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
        let action: () -> Void

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
                }
            }
            .buttonStyle(TVCategoryRowButtonStyle(accentColor: Color(hex: "#30D158"), isSelected: isSelected))
        }
    }

    // MARK: - TV Series Parallax Card

    private struct TVSeriesCard: View {
        let series: MediaModels.Item
        let isSelected: Bool
        let action: () -> Void

        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Button(action: action) {
                TVParallaxCardContainer(
                    isFocused: isFocused,
                    isSelected: isSelected,
                    cornerRadius: 16,
                    accentColor: Color(hex: "#30D158")
                ) {
                    // Layer 1: Background Poster
                    ZStack {
                        if let posterURL = series.coverURL {
                            KFImage(posterURL)
                                .placeholder {
                                    ZStack {
                                        Color(hex: "#2C2C30")
                                        Image(systemName: "tv")
                                            .font(.system(size: 38))
                                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                                    }
                                }
                                .downsampling(size: CGSize(width: 300, height: 450))
                                .cacheOriginalImage()
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                Color(hex: "#2C2C30")
                                Image(systemName: "tv")
                                    .font(.system(size: 38))
                                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                            }
                        }

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.85)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                } floatingContent: {
                    // Layer 3: Floating Language Badge & Title
                    VStack(alignment: .leading, spacing: 6) {
                        if let tag = MediaLanguageDetector.primaryTag(from: series.title) {
                            HStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: tag.systemIcon)
                                        .font(.system(size: 11, weight: .bold))
                                    Text(tag.label)
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                }
                                .foregroundColor(tag.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.8), in: Capsule())
                                .overlay(Capsule().stroke(tag.color.opacity(0.7), lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.6), radius: 4, y: 1)
                                .padding(10)
                            }
                        }

                        Spacer()
                        Text(series.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.8), radius: 6, x: 0, y: 2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
                .aspectRatio(2 / 3, contentMode: .fit)
            }
            .buttonStyle(.plain)
        }
    }
#endif
