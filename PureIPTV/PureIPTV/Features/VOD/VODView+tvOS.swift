#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS VOD View

    // Layout: Left column = categories, right area = VOD poster grid.
    // Focus Engine: Categories list and VOD cards are fully focusable with smooth glass styling.

    public struct VODView_tvOS: View {
        @Bindable var store: StoreOf<VODFeature>
        let config: PlaylistConfig

        @FocusState private var focusedCategory: String?
        @FocusState private var focusedVODID: String?

        @State private var currentScrubLetter: String = ""
        @State private var isScrubOverlayVisible: Bool = false
        @State private var hideScrubTask: Task<Void, Never>?

        public init(store: StoreOf<VODFeature>, config: PlaylistConfig) {
            self.store = store
            self.config = config
        }

        public init(store: StoreOf<VODFeature>, serverURL: String, username: String, password: String) {
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

                // ── Right: VOD grid ──────────────────────────────────
                vodArea
                    .focusSection()
                    .focusGuideBoundary()
            }
            .background(
                DynamicMeshBackgroundView(
                    imageURL: focusedVOD?.coverURL,
                    titleSeed: focusedVOD?.title ?? "VOD",
                    imageRequestDebounceNanoseconds: 150_000_000
                )
            )
            .onAppear {
                store.send(.onAppear(config: config))
            }
        }

        private var focusedVOD: MediaModels.Item? {
            if let focusedVODID {
                return store.currentVODs.first(where: { $0.id == focusedVODID })
            }
            return store.selectedVOD ?? store.currentVODs.first
        }

        // MARK: – Category Column

        private var categoryColumn: some View {
            ScrollViewReader { catProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        HStack {
                            Text(AppStrings.VOD.title)
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
                                .accessibilityLabel("Filmleri yenile")
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
                                TVVODCategoryRow(
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
                        TVFocusMemory.shared.lastSelectedVODCategoryID = newCatID
                        withAnimation { catProxy.scrollTo(newCatID, anchor: .center) }
                    }
                }
                .onChange(of: focusedCategory) { _, newCatID in
                    if let newCatID {
                        TVFocusMemory.shared.lastSelectedVODCategoryID = newCatID
                    }
                }
                .onAppear {
                    let targetCatID = store.selectedCategoryID ?? TVFocusMemory.shared.lastSelectedVODCategoryID ?? store.categories.first?.id
                    if let targetCatID {
                        focusedCategory = targetCatID
                        withAnimation { catProxy.scrollTo(targetCatID, anchor: .center) }
                    }
                }
            }
        }

        // MARK: – VOD Area

        private var vodArea: some View {
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
                if store.isLoadingVODs, store.currentVODs.isEmpty {
                    VStack {
                        PureLoadingView(size: .large, text: AppStrings.VOD.loadingMovies)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.currentVODs.isEmpty {
                    if let categoryID = store.selectedCategoryID,
                       let error = store.categoryContentErrors[categoryID]
                    {
                        RetryableSectionEmptyState(message: error) {
                            store.send(.retryCategoryContent(categoryID: categoryID))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 20) {
                            if !store.rawVODs.isEmpty, store.selectedLanguageFilter != .all || store.selectedOriginalLanguageCode != nil {
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
                                Image(systemName: "film")
                                    .font(.system(size: 60))
                                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                                Text(AppStrings.VOD.noMovies)
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.4))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollViewReader { vodProxy in
                        ScrollView {
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
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 32)],
                                spacing: 32
                            ) {
                                ForEach(store.currentVODs) { vod in
                                    TVVODCard(
                                        vod: vod,
                                        isSelected: store.selectedVOD?.id == vod.id
                                    ) {
                                        store.send(.vodSelected(vod))
                                    }
                                    .focused($focusedVODID, equals: vod.id)
                                    .id(vod.id)
                                    .contextMenu {
                                        Button {
                                            store.send(.toggleFavorite(vod))
                                        } label: {
                                            if store.favoriteIDs.contains(vod.id) {
                                                Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                                            } else {
                                                Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                                            }
                                        }

                                        Button {
                                            store.send(.vodSelected(vod))
                                        } label: {
                                            Label("Detayları Gör", systemImage: "info.circle")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 48)
                            .padding(.vertical, 32)
                        }
                        .onChange(of: store.selectedVOD) { _, newVOD in
                            if let vodID = newVOD?.id {
                                TVFocusMemory.shared.recordVOD(vodID, in: store.selectedCategoryID)
                                focusedVODID = vodID
                                withAnimation { vodProxy.scrollTo(vodID, anchor: .center) }
                            }
                        }
                        .onChange(of: store.selectedCategoryID) { _, newCatID in
                            let targetID = TVFocusMemory.shared.lastVOD(
                                in: newCatID,
                                fallback: store.currentVODs.first?.id
                            )
                            if let targetID {
                                focusedVODID = targetID
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation { vodProxy.scrollTo(targetID, anchor: .center) }
                                }
                            }
                        }
                        .onAppear {
                            let targetID = TVFocusMemory.shared.lastVOD(
                                in: store.selectedCategoryID,
                                fallback: store.selectedVOD?.id ?? store.currentVODs.first?.id
                            )
                            if let targetID {
                                focusedVODID = targetID
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation { vodProxy.scrollTo(targetID, anchor: .center) }
                                }
                            }
                        }
                        .onChange(of: focusedVODID) { _, newID in
                            guard let newID else { return }
                            TVFocusMemory.shared.recordVOD(newID, in: store.selectedCategoryID)
                            guard let vod = store.currentVODs.first(where: { $0.id == newID }) else { return }
                            let firstChar = MediaLibraryDerivedData.alphabetLetter(for: vod.title)
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

    // MARK: - TV VOD Category Row

    private struct TVVODCategoryRow: View {
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
                        .fill(isSelected ? Color(hex: "#BF5AF2") : Color.clear)
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
            .buttonStyle(TVCategoryRowButtonStyle(accentColor: Color(hex: "#BF5AF2"), isSelected: isSelected))
        }
    }

#endif
