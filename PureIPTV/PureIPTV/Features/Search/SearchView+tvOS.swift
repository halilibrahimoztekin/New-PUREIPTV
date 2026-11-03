#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SearchView_tvOS: View {
        @Bindable var store: StoreOf<SearchFeature>
        let config: PlaylistConfig
        let onClose: (() -> Void)?
        @FocusState private var focusedTarget: SearchFocusTarget?
        @AccessibilityFocusState private var accessibilityFocusedTarget: SearchFocusTarget?
        @State private var shouldFocusResultsWhenAvailable = false
        @State private var requestedFocusResultID: String?
        @State private var focusRequestSequence = UUID()
        @State private var resultsScrollPosition = ScrollPosition(idType: String.self)
        @State private var isViewVisible = false
        @State private var shouldRestoreScopeFocus = false
        @State private var renderedResultIDs: Set<String> = []

        private enum SearchFocusTarget: Hashable {
            case search
            case clearQuery
            case pinSearch
            case playlist(UUID?)
            case contentScope(SearchFeature.SearchContentScope)
            case filter(SearchFeature.SearchFilter)
            case result(String)
        }

        /// Columns for grids (wider for tvOS 10-foot UI)
        private let channelColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 40),
        ]
        private let mediaColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 40),
        ]
        private let personColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 360, maximum: 480), spacing: 40),
        ]
        private let categoryColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 340, maximum: 480), spacing: 40),
        ]

        public init(store: StoreOf<SearchFeature>, config: PlaylistConfig, onClose: (() -> Void)? = nil) {
            self.store = store
            self.config = config
            self.onClose = onClose
        }

        public init(store: StoreOf<SearchFeature>, serverURL: String, username: String, password: String) {
            self.store = store
            if (username.isEmpty && password.isEmpty) || serverURL.lowercased().contains(".m3u") {
                config = PlaylistConfig(type: .m3u, m3uURL: URL(string: serverURL))
            } else {
                config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
            }
            onClose = nil
        }

        public var body: some View {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 28) {
                    // Search Bar
                    searchBar
                        .padding(.horizontal, 80)
                        .padding(.top, 40)

                    // Multi-Playlist Filter Bar (if multiple playlists exist)
                    if store.savedPlaylists.count > 1, store.filter != .downloads {
                        playlistFilterBar
                            .padding(.horizontal, 80)
                    }

                    if store.filter != .downloads {
                        contentScopeBar
                    }

                    // Instant Filter Badges Bar
                    filterBar
                        .padding(.bottom, 12)

                    // Results or Discovery State
                    if store.isLoading, store.filter != .downloads {
                        loadingView
                    } else if let error = store.errorMessage, store.filter != .downloads {
                        errorView(error)
                    } else if store.hasLoaded, store.searchQuery.isEmpty, store.filter != .downloads {
                        emptySearchDiscoveryView
                    } else if store.isSearching || store.isCurrentScopeSearching, store.totalResultsCount == 0 {
                        searchingView
                    } else if store.totalResultsCount == 0, store.filter == .downloads
                        || (!store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.searchContentScope != .all)
                        || !store.hasVisibleCuratedPlaylistItems
                    {
                        emptyStateView(AppStrings.Search.noResults, icon: "doc.text.magnifyingglass")
                    } else {
                        resultsScrollView
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let message = store.reminderFailureMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.red.opacity(0.9), in: Capsule())
                        .padding(.bottom, 20)
                }
            }
            .onAppear {
                isViewVisible = true
                store.send(.onAppear(config: config))
            }
            .defaultFocus($focusedTarget, .search)
            .onExitCommand {
                onClose?()
            }
            .onDisappear {
                isViewVisible = false
                cancelPendingResultFocus()
                renderedResultIDs = []
            }
            .onChange(of: store.searchQuery) { _, _ in
                shouldRestoreScopeFocus = false
                cancelPendingResultFocus()
            }
            .onChange(of: focusedTarget) { _, target in
                if shouldFocusResultsWhenAvailable {
                    cancelPendingResultFocus()
                } else if let requestedFocusResultID, target != .result(requestedFocusResultID) {
                    cancelPendingResultFocus()
                }
                guard case let .result(id) = target, isResultVisible(id) else { return }
                if shouldRestoreScopeFocus {
                    shouldRestoreScopeFocus = false
                    if let savedID = restoredResultID, savedID != id {
                        requestResultFocus(savedID)
                        return
                    }
                }
                store.send(.focusedResultChanged(id))
            }
            .onChange(of: store.totalResultsCount) { _, count in
                guard shouldFocusResultsWhenAvailable else { return }
                if count > 0 {
                    focusFirstResult()
                } else if !store.isSearching, !store.isCurrentScopeSearching {
                    shouldFocusResultsWhenAvailable = false
                }
            }
            .onChange(of: store.isSearching) { _, isSearching in
                guard !isSearching, shouldFocusResultsWhenAvailable else { return }
                focusFirstResult()
            }
            .onChange(of: store.isCurrentScopeSearching) { _, isSearching in
                guard !isSearching, shouldFocusResultsWhenAvailable else { return }
                focusFirstResult()
            }
            .alert(
                AppStrings.Search.pinnedSearchLimitTitle,
                isPresented: Binding(
                    get: { store.isPinnedSearchLimitAlertPresented },
                    set: { isPresented in
                        if !isPresented, store.isPinnedSearchLimitAlertPresented {
                            store.send(.pinnedSearchLimitAlertDismissed)
                        }
                    }
                )
            ) {
                Button(AppStrings.Common.ok, role: .cancel) {}
            } message: {
                Text(AppStrings.Search.pinnedSearchLimitMessage)
            }
        }

        // MARK: – UI Components

        private var searchBar: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.onSurfaceVariant.opacity(0.6))
                    .font(AppFonts.headline)

                TextField(AppStrings.Search.searchPlaceholder, text: $store.searchQuery.sending(\.queryChanged))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(AppFonts.headline)
                    .focused($focusedTarget, equals: .search)
                    .accessibilityFocused($accessibilityFocusedTarget, equals: .search)
                    .submitLabel(.search)
                    .onSubmit(focusFirstResult)

                if store.isSearching || store.isCurrentScopeSearching {
                    PureLoadingView(size: .small)
                        .padding(.trailing, 10)
                }

                if !store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        cancelPendingResultFocus()
                        focusedTarget = .search
                        accessibilityFocusedTarget = .search
                        store.send(.queryChanged(""))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.onSurfaceVariant.opacity(0.6))
                            .font(AppFonts.title)
                            .padding(6)
                    }
                    .buttonStyle(TVCircleButtonStyle())
                    .focused($focusedTarget, equals: .clearQuery)
                    .accessibilityFocused($accessibilityFocusedTarget, equals: .clearQuery)
                }

                if !store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        store.send(.togglePinnedSearch(store.searchQuery))
                    } label: {
                        Image(systemName: store.isCurrentSearchPinned ? "pin.slash.fill" : "pin")
                            .foregroundColor(AppColors.onSurfaceVariant.opacity(0.75))
                            .font(AppFonts.title)
                            .padding(6)
                    }
                    .buttonStyle(TVCircleButtonStyle())
                    .focused($focusedTarget, equals: .pinSearch)
                    .accessibilityFocused($accessibilityFocusedTarget, equals: .pinSearch)
                    .accessibilityLabel(store.isCurrentSearchPinned ? AppStrings.Search.unpinSearch : AppStrings.Search.pinSearch)
                    .accessibilityHint(AppStrings.Search.togglePinnedSearchHint)
                }

                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.onSurfaceVariant.opacity(0.75))
                            .font(AppFonts.title)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(TVCircleButtonStyle())
                    .accessibilityLabel(AppStrings.Common.close)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColors.borderSubtle, lineWidth: 2)
                    )
            )
        }

        // MARK: - Multi-Playlist Filter Bar

        private var playlistFilterBar: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    let isGlobalSelected = store.selectedPlaylistID == nil

                    Button {
                        selectPlaylistFilter(nil)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "globe.europe.africa.fill")
                                .font(.system(size: 18))
                            Text(AppStrings.Search.allPlaylistsShort)
                                .font(.system(size: 20, weight: isGlobalSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: isGlobalSelected))
                    .focused($focusedTarget, equals: .playlist(nil))
                    .accessibilityFocused($accessibilityFocusedTarget, equals: .playlist(nil))
                    .accessibilityAddTraits(isGlobalSelected ? .isSelected : [])

                    ForEach(Array(store.savedPlaylists.enumerated()), id: \.element.id) { index, playlist in
                        let isSelected = store.selectedPlaylistID == playlist.id
                        let badge = playlist.toPlaylistConfig().map {
                            UnifiedPlaylistManager.shared.badge(for: $0, index: index)
                        } ?? PlaylistSourceBadge(id: playlist.id.uuidString, playlistName: playlist.name, colorHex: "#0A84FF")

                        Button {
                            selectPlaylistFilter(playlist.id)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(badge.color)
                                    .frame(width: 10, height: 10)
                                Text(playlist.name)
                                    .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: isSelected))
                        .focused($focusedTarget, equals: .playlist(playlist.id))
                        .accessibilityFocused($accessibilityFocusedTarget, equals: .playlist(playlist.id))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .focusSection()
        }

        // MARK: - Instant Filter Badges Bar

        private var filterBar: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(SearchFeature.SearchFilter.allCases, id: \.self) { filter in
                        let isSelected = store.filter == filter
                        let count = store.filterCounts[filter]

                        Button {
                            selectFilter(filter)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: filter.icon)
                                    .font(.system(size: 20))

                                Text(filter.title)
                                    .font(.system(size: 22, weight: isSelected ? .bold : .medium))

                                if let count, count > 0 {
                                    Text("(\(count))")
                                        .font(.system(size: 18, weight: .bold))
                                        .opacity(isSelected ? 0.95 : 0.6)
                                }
                            }
                            .padding(.horizontal, 26)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: isSelected))
                        .focused($focusedTarget, equals: .filter(filter))
                        .accessibilityFocused($accessibilityFocusedTarget, equals: .filter(filter))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 60)
            }
            .focusSection()
        }

        private var contentScopeBar: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(SearchFeature.SearchContentScope.allCases, id: \.self) { scope in
                        let isSelected = store.searchContentScope == scope
                        Button {
                            selectContentScope(scope)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: scope.icon)
                                    .font(.system(size: 20))
                                Text(scope.title)
                                    .font(.system(size: 22, weight: isSelected ? .bold : .medium))
                            }
                            .padding(.horizontal, 26)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: isSelected))
                        .focused($focusedTarget, equals: .contentScope(scope))
                        .accessibilityFocused($accessibilityFocusedTarget, equals: .contentScope(scope))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 60)
            }
            .focusSection()
        }

        // MARK: - Results Scroll View

        private var resultsScrollView: some View {
            ScrollView {
                VStack(spacing: 60) {
                    if store.filter == .downloads {
                        downloadedMediaResultsSection
                    } else {
                        if store.searchQuery.isEmpty || store.searchContentScope == .all {
                            curatedPlaylistSection
                        }

                        // 0. Categories Section
                        if store.filter == .all || store.filter == .categories, !store.categoryResults.isEmpty {
                            resultSection(title: AppStrings.Search.categories, count: store.categoryResults.count) {
                                LazyVGrid(columns: categoryColumns, spacing: 40) {
                                    ForEach(store.categoryResults) { result in
                                        CategorySearchResultCard(
                                            result: result,
                                            queryTerms: store.debouncedQuery.split(whereSeparator: \.isWhitespace).map(String.init),
                                            showPlaylistBadge: store.savedPlaylists.count > 1,
                                            isSelected: false
                                        ) {
                                            store.send(.categorySelected(result))
                                        }
                                        .id(result.id)
                                        .focused($focusedTarget, equals: .result(result.id))
                                        .accessibilityFocused($accessibilityFocusedTarget, equals: .result(result.id))
                                        .onAppear {
                                            renderedResultIDs.insert(result.id)
                                            focusRenderedResultIfRequested(result.id, requestID: focusRequestSequence)
                                        }
                                        .onDisappear { renderedResultIDs.remove(result.id) }
                                    }
                                }
                                .scrollTargetLayout()
                            }
                        }

                        // 1. Live Channels Section
                        let live = store.enrichedLiveResults.isEmpty ? store.liveResults.map {
                            GlobalSearchResultItem(
                                item: $0,
                                playlistBadge: store.fallbackSourceBadge
                            )
                        } : store.enrichedLiveResults

                        if !live.isEmpty {
                            resultSection(title: AppStrings.Search.liveTV, count: live.count) {
                                LazyVGrid(columns: channelColumns, spacing: 40) {
                                    ForEach(live) { result in
                                        GlobalSearchResultCard(
                                            result: result,
                                            isSelected: false,
                                            showPlaylistBadge: store.savedPlaylists.count > 1,
                                            isReminderScheduled: result.matchedEPGProgram.map {
                                                store.scheduledReminderIDs.contains(result.reminderID(for: $0))
                                                    || store.scheduledReminderIDs.contains($0.id)
                                            } ?? false,
                                            isReminderPending: result.matchedEPGProgram.map {
                                                store.pendingReminderRequestIDs[result.reminderID(for: $0)] != nil
                                            } ?? false
                                        ) {
                                            store.send(.channelSelected(result.item))
                                        }
                                        .id(result.id)
                                        .focused($focusedTarget, equals: .result(result.id))
                                        .accessibilityFocused($accessibilityFocusedTarget, equals: .result(result.id))
                                        .onAppear {
                                            renderedResultIDs.insert(result.id)
                                            focusRenderedResultIfRequested(result.id, requestID: focusRequestSequence)
                                        }
                                        .onDisappear { renderedResultIDs.remove(result.id) }
                                        .contextMenu {
                                            curatedPlaylistContextMenuItem(for: result)

                                            Button {
                                                store.send(.toggleFavorite(item: result.item, type: "live", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID))
                                            } label: {
                                                if store.favoriteIDs.contains(FavoriteIdentity(type: "live", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID, id: result.item.id)) {
                                                    Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                                                } else {
                                                    Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                                                }
                                            }

                                            Button {
                                                store.send(.channelSelected(result.item))
                                            } label: {
                                                Label(AppStrings.Common.watchNow, systemImage: "play.fill")
                                            }
                                        }
                                    }
                                }
                                .scrollTargetLayout()
                            }
                        }

                        // 2. Movies (VOD) Section
                        let vods = store.enrichedVODResults.isEmpty ? store.vodResults.map {
                            GlobalSearchResultItem(
                                item: $0,
                                playlistBadge: store.fallbackSourceBadge
                            )
                        } : store.enrichedVODResults

                        if !vods.isEmpty {
                            resultSection(title: AppStrings.Search.movies, count: vods.count) {
                                LazyVGrid(columns: mediaColumns, spacing: 40) {
                                    ForEach(vods) { result in
                                        GlobalSearchResultCard(
                                            result: result,
                                            isSelected: false,
                                            showPlaylistBadge: store.savedPlaylists.count > 1
                                        ) {
                                            store.send(.vodSelected(result.item))
                                        }
                                        .id(result.id)
                                        .focused($focusedTarget, equals: .result(result.id))
                                        .accessibilityFocused($accessibilityFocusedTarget, equals: .result(result.id))
                                        .onAppear {
                                            renderedResultIDs.insert(result.id)
                                            focusRenderedResultIfRequested(result.id, requestID: focusRequestSequence)
                                        }
                                        .onDisappear { renderedResultIDs.remove(result.id) }
                                        .contextMenu {
                                            curatedPlaylistContextMenuItem(for: result)

                                            Button {
                                                store.send(.toggleFavorite(item: result.item, type: "vod", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID))
                                            } label: {
                                                if store.favoriteIDs.contains(FavoriteIdentity(type: "vod", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID, id: result.item.id)) {
                                                    Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                                                } else {
                                                    Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                                                }
                                            }

                                            Button {
                                                store.send(.vodSelected(result.item))
                                            } label: {
                                                Label("Detayları Gör", systemImage: "info.circle")
                                            }
                                        }
                                    }
                                }
                                .scrollTargetLayout()
                            }
                        }

                        // 3. Series Section
                        let series = store.enrichedSeriesResults.isEmpty ? store.seriesResults.map {
                            GlobalSearchResultItem(
                                item: $0,
                                playlistBadge: store.fallbackSourceBadge
                            )
                        } : store.enrichedSeriesResults

                        if !series.isEmpty {
                            resultSection(title: AppStrings.Search.series, count: series.count) {
                                LazyVGrid(columns: mediaColumns, spacing: 40) {
                                    ForEach(series) { result in
                                        GlobalSearchResultCard(
                                            result: result,
                                            isSelected: false,
                                            showPlaylistBadge: store.savedPlaylists.count > 1
                                        ) {
                                            store.send(.seriesSelected(result.item))
                                        }
                                        .id(result.id)
                                        .focused($focusedTarget, equals: .result(result.id))
                                        .accessibilityFocused($accessibilityFocusedTarget, equals: .result(result.id))
                                        .onAppear {
                                            renderedResultIDs.insert(result.id)
                                            focusRenderedResultIfRequested(result.id, requestID: focusRequestSequence)
                                        }
                                        .onDisappear { renderedResultIDs.remove(result.id) }
                                        .contextMenu {
                                            curatedPlaylistContextMenuItem(for: result)

                                            Button {
                                                store.send(.toggleFavorite(item: result.item, type: "series", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID))
                                            } label: {
                                                if store.favoriteIDs.contains(FavoriteIdentity(type: "series", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID, id: result.item.id)) {
                                                    Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                                                } else {
                                                    Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                                                }
                                            }

                                            Button {
                                                store.send(.seriesSelected(result.item))
                                            } label: {
                                                Label("Bölümleri Gör", systemImage: "list.number")
                                            }
                                        }
                                    }
                                }
                                .scrollTargetLayout()
                            }
                        }

                        if store.filter == .all || store.filter == .people, !store.peopleResults.isEmpty {
                            resultSection(title: AppStrings.Search.people, count: store.peopleResults.count) {
                                LazyVGrid(columns: personColumns, spacing: 28) {
                                    ForEach(store.peopleResults) { credit in
                                        Button {
                                            store.send(.personCreditSelected(credit))
                                        } label: {
                                            HStack(spacing: 18) {
                                                AsyncImage(url: credit.portraitURL) { phase in
                                                    if let image = phase.image {
                                                        image.resizable().scaledToFill()
                                                    } else {
                                                        ZStack {
                                                            AppColors.surfaceElevated
                                                            Image(systemName: "person.fill").font(AppFonts.displayMedium).foregroundStyle(AppColors.textMuted)
                                                        }
                                                    }
                                                }
                                                .frame(width: 112, height: 156)
                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                                VStack(alignment: .leading, spacing: 10) {
                                                    highlightedSearchText(credit.personName, queryTerms: store.debouncedQuery.split(whereSeparator: \.isWhitespace).map(String.init))
                                                        .font(AppFonts.headline).foregroundStyle(.white).lineLimit(2)
                                                    Text("\(AppStrings.Search.people) · \(store.debouncedQuery)")
                                                        .font(AppFonts.caption.weight(.medium))
                                                        .foregroundStyle(AppColors.warningGold)
                                                        .lineLimit(1)
                                                    Text(credit.result.item.displayTitle).font(AppFonts.title).foregroundStyle(AppColors.onSurfaceVariant).lineLimit(2)
                                                    Text(credit.result.item.type == .series ? AppStrings.Search.series : AppStrings.Search.movies)
                                                        .font(AppFonts.bodyLarge.weight(.medium)).foregroundStyle(AppColors.sky)
                                                    if store.selectedPlaylistID == nil, store.savedPlaylists.count > 1 {
                                                        Text(credit.result.playlistBadge.playlistName)
                                                            .font(AppFonts.bodyMedium).foregroundStyle(AppColors.textMuted).lineLimit(1)
                                                    }
                                                }
                                                Spacer(minLength: 0)
                                                Image(systemName: "play.fill").font(AppFonts.bodyBold).foregroundStyle(AppColors.primary)
                                            }
                                            .padding(18)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(AppColors.surfaceContainer, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        }
                                        .tvFocusEffect(shape: .roundedRectangle(cornerRadius: 18))
                                        .id(credit.id)
                                        .focused($focusedTarget, equals: .result(credit.id))
                                        .accessibilityFocused($accessibilityFocusedTarget, equals: .result(credit.id))
                                        .onAppear {
                                            renderedResultIDs.insert(credit.id)
                                            focusRenderedResultIfRequested(credit.id, requestID: focusRequestSequence)
                                        }
                                        .onDisappear { renderedResultIDs.remove(credit.id) }
                                        .accessibilityLabel("\(credit.personName), \(credit.result.item.displayTitle), \(credit.result.item.type == .series ? AppStrings.Search.series : AppStrings.Search.movies), \(AppStrings.Search.people), \(store.debouncedQuery), \(credit.result.playlistBadge.playlistName)")
                                        .accessibilityHint(AppStrings.Common.watchNow)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                        }

                        if store.filter == .all || store.filter == .programs, !store.programResults.isEmpty {
                            resultSection(title: AppStrings.Search.programs, count: store.programResults.count) {
                                LazyVGrid(columns: channelColumns, spacing: 40) {
                                    ForEach(store.programResults) { match in
                                        ProgramSearchResultCard(program: match.program, channel: match.result.item, playlistName: store.savedPlaylists.count > 1 ? match.result.playlistBadge.playlistName : nil, query: store.debouncedQuery) {
                                            store.send(.programSelected(match))
                                        }
                                        .id(match.id)
                                        .focused($focusedTarget, equals: .result(match.id))
                                        .accessibilityFocused($accessibilityFocusedTarget, equals: .result(match.id))
                                        .onAppear {
                                            renderedResultIDs.insert(match.id)
                                            focusRenderedResultIfRequested(match.id, requestID: focusRequestSequence)
                                        }
                                        .onDisappear { renderedResultIDs.remove(match.id) }
                                    }
                                }
                                .scrollTargetLayout()
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 60)
                .scrollTargetLayout()
            }
            .scrollPosition($resultsScrollPosition, anchor: .center)
            .focusSection()
            .onChange(of: focusRequestSequence) { _, requestID in
                guard isViewVisible, let id = requestedFocusResultID, isResultVisible(id) else {
                    requestedFocusResultID = nil
                    return
                }
                resultsScrollPosition.scrollTo(id: id, anchor: .center)
                focusRenderedResultIfRequested(id, requestID: requestID)
            }
            .task {
                let sequence = focusRequestSequence
                let origin = focusedTarget
                await Task.yield()
                guard !Task.isCancelled, isViewVisible,
                      focusRequestSequence == sequence, focusedTarget == origin
                else { return }
                if let id = requestedFocusResultID, isResultVisible(id) {
                    requestResultFocus(id)
                } else if !isSearchOrFilterControlFocused {
                    focusFirstResult()
                }
            }
        }

        private var downloadedMediaResultsSection: some View {
            resultSection(title: AppStrings.Downloads.completedDownloads, count: store.downloadedMediaResults.count) {
                LazyVGrid(columns: mediaColumns, spacing: 32) {
                    ForEach(store.downloadedMediaResults) { item in
                        Button {
                            store.send(.offlineMediaSelected(item))
                        } label: {
                            HStack(spacing: 20) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 42, weight: .medium))
                                    .foregroundStyle(AppColors.success)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(item.title)
                                        .font(AppFonts.headline)
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                    if let episode = item.episodeMetadata {
                                        Text("\(episode.seriesTitle) · S\(episode.seasonNumber) E\(episode.episodeNumber)")
                                            .font(AppFonts.titleSmall)
                                            .foregroundStyle(AppColors.onSurfaceVariant)
                                            .lineLimit(1)
                                    }
                                    Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                                        .font(AppFonts.caption)
                                        .foregroundStyle(AppColors.textMuted)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "play.fill")
                                    .font(AppFonts.bodyBold)
                                    .foregroundStyle(AppColors.primary)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.surfaceContainer, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .id(item.id)
                        .focused($focusedTarget, equals: .result(item.id))
                        .accessibilityFocused($accessibilityFocusedTarget, equals: .result(item.id))
                        .onAppear {
                            renderedResultIDs.insert(item.id)
                            focusRenderedResultIfRequested(item.id, requestID: focusRequestSequence)
                        }
                        .onDisappear { renderedResultIDs.remove(item.id) }
                        .accessibilityLabel(item.title)
                        .accessibilityHint(AppStrings.Common.watchNow)
                    }
                }
                .scrollTargetLayout()
            }
        }

        @ViewBuilder
        private var curatedPlaylistSection: some View {
            let results = store.curatedPlaylistResults
            let unavailable = store.unavailableCuratedPlaylistEntries
            if !results.isEmpty || !unavailable.isEmpty {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label(AppStrings.Search.myCollection, systemImage: "rectangle.stack.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(results.count + unavailable.count)")
                            .font(.system(size: 22, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 30) {
                            ForEach(results) { result in
                                GlobalSearchResultCard(result: result, isSelected: false, showPlaylistBadge: true) {
                                    selectCuratedResult(result)
                                }
                                .frame(width: result.item.type == .live ? 340 : 230)
                                .contextMenu {
                                    Button {
                                        store.send(.toggleCuratedPlaylistItem(result))
                                    } label: {
                                        Label(AppStrings.LiveTV.removeSelectedFromList, systemImage: "bookmark.slash")
                                    }
                                }
                            }

                            ForEach(unavailable) { entry in
                                unavailableCuratedCard(entry)
                            }
                        }
                    }
                }
                .focusSection()
            }
        }

        private func selectCuratedResult(_ result: GlobalSearchResultItem) {
            switch result.item.type {
            case .live: store.send(.channelSelected(result.item))
            case .vod: store.send(.vodSelected(result.item))
            case .series: store.send(.seriesSelected(result.item))
            }
        }

        private func unavailableCuratedCard(_ entry: CuratedPlaylistEntry) -> some View {
            let sourceDetails = entry.categoryID.isEmpty
                ? entry.playlistNameSnapshot
                : "\(entry.playlistNameSnapshot) · \(entry.categoryID)"
            return VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Button {
                        store.send(.removeCuratedPlaylistItem(entry.id))
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(TVCircleButtonStyle())
                    .accessibilityLabel(AppStrings.Common.delete)
                }
                Text(entry.titleSnapshot)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(sourceDetails)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(width: 260, height: 210, alignment: .leading)
            .background(AppColors.surfaceContainer, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }

        @ViewBuilder
        private func curatedPlaylistContextMenuItem(for result: GlobalSearchResultItem) -> some View {
            if store.withState({ $0.canToggleCuratedPlaylist(result) }) {
                let isSaved = store.withState { $0.isInCuratedPlaylist(result) }
                Button {
                    store.send(.toggleCuratedPlaylistItem(result))
                } label: {
                    Label(
                        isSaved ? AppStrings.LiveTV.removeSelectedFromList : AppStrings.LiveTV.addSelectedToList,
                        systemImage: isSaved ? "bookmark.slash" : "bookmark"
                    )
                }
            }
        }

        // MARK: - Discovery & Empty Views

        private var pinnedSearchesSection: some View {
            VStack(alignment: .leading, spacing: 24) {
                Label(AppStrings.Search.pinnedSearches, systemImage: "pin.fill")
                    .font(AppFonts.headline)
                    .foregroundColor(.white)
                Text(AppStrings.Search.pinnedSearchesDescription)
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)

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
                                        .foregroundColor(.white)
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

        private var allCategoriesDiscoverySection: some View {
            let categories = store.scopedDiscoveryCategories
            return VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Label(AppStrings.Search.allCategories, systemImage: "folder.fill")
                        .font(AppFonts.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(categories.count)")
                        .font(AppFonts.title.monospacedDigit())
                        .foregroundColor(AppColors.onSurfaceVariant)
                }

                LazyVGrid(columns: categoryColumns, spacing: 40) {
                    ForEach(categories) { result in
                        CategorySearchResultCard(
                            result: result,
                            queryTerms: [],
                            showPlaylistBadge: store.savedPlaylists.count > 1,
                            isSelected: false
                        ) {
                            store.send(.categorySelected(result))
                        }
                        .id(result.id)
                        .focused($focusedTarget, equals: .result(result.id))
                        .accessibilityFocused($accessibilityFocusedTarget, equals: .result(result.id))
                        .onAppear {
                            renderedResultIDs.insert(result.id)
                            focusRenderedResultIfRequested(result.id, requestID: focusRequestSequence)
                        }
                        .onDisappear { renderedResultIDs.remove(result.id) }
                    }
                }
            }
        }

        private var emptySearchDiscoveryView: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 48) {
                    if store.filter == .categories {
                        allCategoriesDiscoverySection
                    } else {
                        curatedPlaylistSection

                        if !store.pinnedSearchQueries.isEmpty {
                            pinnedSearchesSection
                        }

                        // Recent Searches (if available)
                        if !store.recentSearches.isEmpty {
                            VStack(alignment: .leading, spacing: 24) {
                                HStack {
                                    Label(AppStrings.Search.recentSearches, systemImage: "clock.arrow.circlepath")
                                        .font(AppFonts.headline)
                                        .foregroundColor(.white)
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
                                                .background(Color.white.opacity(0.05))
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

                        // Quick Discovery Categories & Tags
                        VStack(alignment: .leading, spacing: 28) {
                            Label(AppStrings.Search.quickTags, systemImage: "sparkles")
                                .font(AppFonts.headline)
                                .foregroundColor(.white)

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
                .padding(.horizontal, 60)
                .padding(.bottom, 60)
            }
        }

        private func resultSection(title: String, count: Int, @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .bottom) {
                    Text(title)
                        .font(AppFonts.displayMedium)
                        .foregroundColor(.white)
                    Text("\(count) \(AppStrings.Common.results)")
                        .font(AppFonts.bodyLarge)
                        .foregroundColor(AppColors.onSurfaceVariant.opacity(0.6))
                        .padding(.bottom, 4)
                }
                content()
            }
        }

        private func focusFirstResult() {
            guard !store.isSearching, !store.isCurrentScopeSearching else {
                shouldFocusResultsWhenAvailable = true
                return
            }
            guard let resultID = restoredResultID ?? firstResultID else {
                shouldFocusResultsWhenAvailable = false
                requestedFocusResultID = nil
                return
            }
            requestResultFocus(resultID)
        }

        private func requestResultFocus(_ id: String) {
            guard isViewVisible, isResultVisible(id) else { return }
            shouldFocusResultsWhenAvailable = false
            requestedFocusResultID = id
            focusRequestSequence = UUID()
        }

        private func focusRenderedResultIfRequested(_ id: String, requestID: UUID) {
            guard isViewVisible, requestedFocusResultID == id, renderedResultIDs.contains(id) else { return }
            let origin = focusedTarget
            Task { @MainActor in
                await Task.yield()
                guard isViewVisible,
                      focusRequestSequence == requestID,
                      requestedFocusResultID == id,
                      renderedResultIDs.contains(id),
                      focusedTarget == origin || focusedTarget == .result(id),
                      isResultVisible(id)
                else { return }
                requestedFocusResultID = nil
                focusedTarget = .result(id)
                accessibilityFocusedTarget = .result(id)
            }
        }

        private func cancelPendingResultFocus() {
            shouldFocusResultsWhenAvailable = false
            requestedFocusResultID = nil
            focusRequestSequence = UUID()
        }

        private func selectFilter(_ filter: SearchFeature.SearchFilter) {
            cancelPendingResultFocus()
            shouldRestoreScopeFocus = store.filter != filter
            focusedTarget = .filter(filter)
            accessibilityFocusedTarget = .filter(filter)
            store.send(.filterChanged(filter))
        }

        private func selectPlaylistFilter(_ playlistID: UUID?) {
            cancelPendingResultFocus()
            shouldRestoreScopeFocus = store.selectedPlaylistID != playlistID
            focusedTarget = .playlist(playlistID)
            accessibilityFocusedTarget = .playlist(playlistID)
            store.send(.selectPlaylistFilter(playlistID))
        }

        private func selectContentScope(_ scope: SearchFeature.SearchContentScope) {
            cancelPendingResultFocus()
            shouldRestoreScopeFocus = store.searchContentScope != scope
            focusedTarget = .contentScope(scope)
            accessibilityFocusedTarget = .contentScope(scope)
            store.send(.searchContentScopeChanged(scope))
        }

        private var isSearchOrFilterControlFocused: Bool {
            guard let focusedTarget else { return false }
            return switch focusedTarget {
            case .search, .clearQuery, .pinSearch, .playlist(_), .contentScope, .filter: true
            case .result: false
            }
        }

        private var restoredResultID: String? {
            guard let savedID = store.focusedResultID else { return nil }
            return isResultVisible(savedID) ? savedID : nil
        }

        private func isResultVisible(_ resultID: String) -> Bool {
            visibleResultIDs.contains(resultID)
        }

        private var visibleResultIDs: [String] {
            store.visibleResultIDs
        }

        private var firstResultID: String? {
            visibleResultIDs.first
        }

        private var loadingView: some View {
            VStack(spacing: 32) {
                Spacer()
                PureLoadingView(size: .large, text: AppStrings.Search.loadingMessage)
                Spacer()
            }
            .padding()
        }

        private var searchingView: some View {
            VStack(spacing: 24) {
                Spacer()
                PureLoadingView(size: .large, text: AppStrings.Common.loading)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func emptyStateView(_ message: String, icon: String) -> some View {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.3))
                Text(message)
                    .font(AppFonts.headline)
                    .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.5))
                if let suggestion = store.searchRecoverySuggestion {
                    Button {
                        applySearchRecovery(suggestion)
                    } label: {
                        Text(suggestion.title)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.primary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func applySearchRecovery(_ suggestion: SearchFeature.SearchRecoverySuggestion) {
            switch suggestion {
            case .allContentTypes:
                store.send(.filterChanged(.all))
            case .allPlaylists:
                store.send(.selectPlaylistFilter(nil))
            }
        }

        private func errorView(_ error: String) -> some View {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 80))
                    .foregroundStyle(.red.opacity(0.7))
                Text(error)
                    .font(AppFonts.displayMedium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.7))
                    .padding(.horizontal, 60)
                Spacer()
            }
        }
    }
#endif
