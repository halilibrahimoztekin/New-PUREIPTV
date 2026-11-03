#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS Series Grid Component

    /// High-performance, virtualized series poster grid for tvOS.
    /// Incorporates alphabetical scrubber navigation, focus restoration, Kingfisher prefetching, and context actions.
    public struct SeriesGrid_tvOS: View {
        @Bindable var store: StoreOf<SeriesFeature>
        @FocusState.Binding var focusedSeriesID: String?

        @State private var currentScrubLetter: String = ""
        @State private var isScrubOverlayVisible: Bool = false
        @State private var hideScrubTask: Task<Void, Never>?
        @State private var posterPrefetchController = TVPosterPrefetchController()

        public init(store: StoreOf<SeriesFeature>, focusedSeriesID: FocusState<String?>.Binding) {
            self.store = store
            _focusedSeriesID = focusedSeriesID
        }

        public var body: some View {
            Group {
                if store.isLoadingSeries, store.currentSeries.isEmpty {
                    VStack {
                        PureLoadingView(size: .large, text: AppStrings.Series.loadingSeries)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.currentSeries.isEmpty {
                    emptyStateView
                } else {
                    gridView
                }
            }
            .onDisappear {
                posterPrefetchController.cancel()
            }
        }

        // MARK: - Empty State

        @ViewBuilder
        private var emptyStateView: some View {
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
                            .font(AppFonts.displayLarge)
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
                            .font(AppFonts.displayLarge)
                            .foregroundStyle(AppColors.textSecondary.opacity(0.25))
                        Text(AppStrings.Series.noSeries)
                            .font(AppFonts.displayMedium)
                            .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        // MARK: - Grid View

        private var gridView: some View {
            ScrollViewReader { seriesProxy in
                ScrollView {
                    gridContent
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
                    handleSortChange(seriesProxy: seriesProxy)
                }
                .onChange(of: store.selectedCategoryID) { _, newCatID in
                    handleCategoryChange(newCatID: newCatID, seriesProxy: seriesProxy)
                }
                .onAppear {
                    handleInitialAppearance(seriesProxy: seriesProxy)
                }
                .onChange(of: focusedSeriesID) { _, newID in
                    handleFocusedIDChange(newID: newID)
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

        @ViewBuilder
        private var gridContent: some View {
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
                    seriesCardItem(series: series)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 32)
        }

        private func handleSortChange(seriesProxy: ScrollViewProxy) {
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

        private func handleCategoryChange(newCatID: String?, seriesProxy: ScrollViewProxy) {
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

        private func handleInitialAppearance(seriesProxy: ScrollViewProxy) {
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

        private func handleFocusedIDChange(newID: String?) {
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

        private func seriesCardItem(series: MediaModels.Item) -> some View {
            TVSeriesCard(
                series: series,
                isSelected: store.selectedSeries?.id == series.id
            ) {
                store.send(.seriesSelected(series))
            }
            .focused($focusedSeriesID, equals: series.id)
            .id(series.id)
            .contextMenu {
                seriesContextMenu(series: series)
            }
        }

        @ViewBuilder
        private func seriesContextMenu(series: MediaModels.Item) -> some View {
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
#endif
