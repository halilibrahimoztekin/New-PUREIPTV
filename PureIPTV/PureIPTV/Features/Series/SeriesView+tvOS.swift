#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS Series View

    /// Modularized, high-performance Series catalog view for tvOS.
    /// Deconstructed into isolated `categoryColumn`, `SeriesFilterBar_tvOS`, and `SeriesGrid_tvOS`.
    public struct SeriesView_tvOS: View {
        @Bindable var store: StoreOf<SeriesFeature>
        let config: PlaylistConfig

        @FocusState private var focusedCategory: String?
        @FocusState private var focusedSeriesID: String?
        @State private var categorySearchQuery = ""

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
                    .fill(AppColors.borderSubtle)
                    .frame(width: 1)
                    .frame(width: 24)

                // ── Right: Series Area ──────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    SeriesFilterBar_tvOS(store: store)
                    SeriesGrid_tvOS(store: store, focusedSeriesID: $focusedSeriesID)
                }
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
                                            Image(systemName: "arrow.clockwise")
                                                .font(AppFonts.titleSmall)
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
                                    .font(AppFonts.titleSmall)
                                    .padding(8)
                            }
                            .buttonStyle(TVCircleButtonStyle())
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 48)
                        .padding(.bottom, 16)

                        if let refreshMessage = store.refreshMessage {
                            Text(refreshMessage)
                                .font(AppFonts.footnote)
                                .foregroundStyle(AppColors.destructive)
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
                                    .font(AppFonts.caption)
                                    .foregroundStyle(AppColors.textSecondary)
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
                        .fill(isSelected ? AppColors.success : AppColors.background.opacity(0))
                        .frame(width: 4, height: 26)

                    Text(category.name)
                        .font(AppFonts.titleSmall)
                        .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.7))
                        .lineLimit(1)

                    Spacer()

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(AppFonts.bodyMedium)
                            .foregroundColor(AppColors.warning.opacity(0.85))
                    }
                }
            }
            .buttonStyle(TVCategoryRowButtonStyle(accentColor: AppColors.success, isSelected: isSelected))
        }
    }
#endif
