#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS VOD Movie Grid Component

    /// High-performance, virtualized movie poster grid for tvOS.
    /// Incorporates alphabetical scrubber navigation, focus restoration, Kingfisher prefetching, and context actions.
    public struct VODMovieGrid_tvOS: View {
        @Bindable var store: StoreOf<VODFeature>
        @FocusState.Binding var focusedVODID: String?

        @State private var currentScrubLetter: String = ""
        @State private var isScrubOverlayVisible: Bool = false
        @State private var hideScrubTask: Task<Void, Never>?
        @State private var posterPrefetchController = TVPosterPrefetchController()

        public init(store: StoreOf<VODFeature>, focusedVODID: FocusState<String?>.Binding) {
            self.store = store
            _focusedVODID = focusedVODID
        }

        public var body: some View {
            Group {
                if store.isLoadingVODs, store.currentVODs.isEmpty {
                    VStack {
                        PureLoadingView(size: .large, text: AppStrings.VOD.loadingMovies)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.currentVODs.isEmpty {
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
                    if !store.rawVODs.isEmpty, store.selectedLanguageFilter != .all || store.selectedOriginalLanguageCode != nil {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(AppFonts.displayLarge)
                            .foregroundStyle(AppColors.primary.opacity(0.8))
                        Text(AppStrings.MediaFilter.noMatchingResults)
                            .font(AppFonts.titleLarge)
                            .foregroundStyle(AppColors.textPrimary.opacity(0.8))

                        Button {
                            store.send(.setLanguageFilter(.all))
                            store.send(.setOriginalLanguageFilter(nil))
                        } label: {
                            Text(AppStrings.MediaFilter.all)
                                .font(AppFonts.titleMedium)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: true, isSelected: false))
                        .padding(.top, 12)
                    } else {
                        Image(systemName: "film")
                            .font(AppFonts.displayLarge)
                            .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.25))
                        Text(AppStrings.VOD.noMovies)
                            .font(AppFonts.titleLarge)
                            .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.4))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        // MARK: - Grid View

        private var gridView: some View {
            ScrollViewReader { vodProxy in
                ScrollView {
                    gridContent
                }
                .onChange(of: store.selectedVOD) { _, newVOD in
                    guard let vodID = newVOD?.id,
                          store.currentVODs.contains(where: { $0.id == vodID })
                    else { return }
                    TVFocusMemory.shared.recordVOD(vodID, in: store.selectedCategoryID)
                    focusedVODID = vodID
                    withAnimation { vodProxy.scrollTo(vodID, anchor: .center) }
                }
                .onChange(of: store.lastSortMethod) { _, _ in
                    handleSortChange(vodProxy: vodProxy)
                }
                .onChange(of: store.selectedCategoryID) { _, newCatID in
                    handleCategoryChange(newCatID: newCatID, vodProxy: vodProxy)
                }
                .onAppear {
                    handleInitialAppearance(vodProxy: vodProxy)
                }
                .onChange(of: focusedVODID) { _, newID in
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
            .focusEffectDisabled()
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
            if store.isLoadingVODs {
                PureLoadingView(size: .small)
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 32)],
                spacing: 32
            ) {
                ForEach(store.currentVODs) { vod in
                    vodCardItem(vod: vod)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 32)
        }

        private func handleSortChange(vodProxy: ScrollViewProxy) {
            let categoryID = store.selectedCategoryID
            let targetID = restoredVODFocusID(preferred: focusedVODID, categoryID: categoryID)
            guard let targetID else { return }
            focusedVODID = targetID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard store.selectedCategoryID == categoryID,
                      focusedVODID == targetID,
                      store.currentVODs.contains(where: { $0.id == targetID })
                else { return }
                withAnimation { vodProxy.scrollTo(targetID, anchor: .center) }
            }
        }

        private func handleCategoryChange(newCatID: String?, vodProxy: ScrollViewProxy) {
            let targetID = restoredVODFocusID(preferred: nil, categoryID: newCatID)
            if let targetID {
                focusedVODID = targetID
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard store.selectedCategoryID == newCatID,
                          focusedVODID == targetID,
                          store.currentVODs.contains(where: { $0.id == targetID })
                    else { return }
                    withAnimation { vodProxy.scrollTo(targetID, anchor: .center) }
                }
            }
        }

        private func handleInitialAppearance(vodProxy: ScrollViewProxy) {
            let categoryID = store.selectedCategoryID
            let targetID = restoredVODFocusID(preferred: store.selectedVOD?.id, categoryID: categoryID)
            if let targetID {
                focusedVODID = targetID
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard store.selectedCategoryID == categoryID,
                          focusedVODID == targetID,
                          store.currentVODs.contains(where: { $0.id == targetID })
                    else { return }
                    withAnimation { vodProxy.scrollTo(targetID, anchor: .center) }
                }
            }
        }

        private func handleFocusedIDChange(newID: String?) {
            posterPrefetchController.schedule(focusedID: newID, items: store.currentVODs)
            guard let newID else { return }
            guard let vod = store.currentVODs.first(where: { $0.id == newID }) else { return }
            TVFocusMemory.shared.recordVOD(newID, in: store.selectedCategoryID)
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

        private func restoredVODFocusID(preferred: String?, categoryID: String?) -> String? {
            let visibleIDs = Set(store.currentVODs.map(\.id))
            let rememberedID = TVFocusMemory.shared.lastVOD(in: categoryID, fallback: nil)
            if let rememberedID, visibleIDs.contains(rememberedID) {
                return rememberedID
            }
            if let preferred, visibleIDs.contains(preferred) {
                return preferred
            }
            return store.currentVODs.first?.id
        }

        private func vodCardItem(vod: MediaModels.Item) -> some View {
            TVVODCard(
                vod: vod,
                isSelected: store.selectedVOD?.id == vod.id
            ) {
                store.send(.vodSelected(vod))
            }
            .focused($focusedVODID, equals: vod.id)
            .id(vod.id)
            .contextMenu {
                vodContextMenu(vod: vod)
            }
        }

        @ViewBuilder
        private func vodContextMenu(vod: MediaModels.Item) -> some View {
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

            Button {
                store.send(.vodSelected(vod))
            } label: {
                Label("Detayları Gör", systemImage: "info.circle")
            }
        }
    }
#endif
