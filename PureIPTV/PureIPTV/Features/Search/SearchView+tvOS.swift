#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SearchView_tvOS: View {
        @Bindable var store: StoreOf<SearchFeature>
        let config: PlaylistConfig
        @FocusState private var focusedTarget: SearchFocusTarget?
        @AccessibilityFocusState private var accessibilityFocusedTarget: SearchFocusTarget?
        @State private var shouldFocusResultsWhenAvailable = false
        @State private var requestedFocusResultID: String?
        @State private var focusRequestSequence = UUID()
        @State private var resultsScrollPosition = ScrollPosition(idType: String.self)

        private enum SearchFocusTarget: Hashable {
            case search
            case clearQuery
            case playlist(UUID?)
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

        public init(store: StoreOf<SearchFeature>, config: PlaylistConfig) {
            self.store = store
            self.config = config
        }

        public init(store: StoreOf<SearchFeature>, serverURL: String, username: String, password: String) {
            self.store = store
            if (username.isEmpty && password.isEmpty) || serverURL.lowercased().contains(".m3u") {
                config = PlaylistConfig(type: .m3u, m3uURL: URL(string: serverURL))
            } else {
                config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
            }
        }

        public var body: some View {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 28) {
                    // Search Bar
                    searchBar
                        .padding(.horizontal, 60)
                        .padding(.top, 40)

                    // Multi-Playlist Filter Bar (if multiple playlists exist)
                    if store.savedPlaylists.count > 1 {
                        playlistFilterBar
                            .padding(.horizontal, 60)
                    }

                    // Instant Filter Badges Bar
                    filterBar
                        .padding(.bottom, 12)

                    // Results or Discovery State
                    if store.isLoading {
                        loadingView
                    } else if let error = store.errorMessage {
                        errorView(error)
                    } else if store.hasLoaded, store.searchQuery.isEmpty {
                        emptySearchDiscoveryView
                    } else if store.isSearching || store.isCurrentScopeSearching, store.totalResultsCount == 0 {
                        searchingView
                    } else if store.totalResultsCount == 0 {
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
                store.send(.onAppear(config: config))
                if store.focusedResultID != nil {
                    Task { @MainActor in
                        await Task.yield()
                        focusFirstResult()
                    }
                }
            }
            .onChange(of: focusedTarget) { _, target in
                if case let .result(id) = target, isResultVisible(id) {
                    store.send(.focusedResultChanged(id))
                }
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
        }

        // MARK: – UI Components

        private var searchBar: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))
                    .font(.system(size: 32))

                TextField(AppStrings.Search.searchPlaceholder, text: $store.searchQuery.sending(\.queryChanged))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 32))
                    .focused($focusedTarget, equals: .search)
                    .accessibilityFocused($accessibilityFocusedTarget, equals: .search)
                    .submitLabel(.search)
                    .onSubmit(focusFirstResult)

                if store.isSearching || store.isCurrentScopeSearching {
                    PureLoadingView(size: .small)
                        .padding(.trailing, 10)
                }

                if !store.searchQuery.isEmpty {
                    Button {
                        shouldFocusResultsWhenAvailable = false
                        requestedFocusResultID = nil
                        focusedTarget = .search
                        accessibilityFocusedTarget = .search
                        store.send(.queryChanged(""))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))
                            .font(.system(size: 28))
                            .padding(6)
                    }
                    .buttonStyle(TVCircleButtonStyle())
                    .focused($focusedTarget, equals: .clearQuery)
                    .accessibilityFocused($accessibilityFocusedTarget, equals: .clearQuery)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#1F1F23"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 2)
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

        // MARK: - Results Scroll View

        private var resultsScrollView: some View {
            ScrollView {
                VStack(spacing: 60) {
                    // 1. Live Channels Section
                    let live = store.enrichedLiveResults.isEmpty ? store.liveResults.map {
                        GlobalSearchResultItem(
                            item: $0,
                            playlistBadge: PlaylistSourceBadge(id: "default", playlistName: "Varsayılan", colorHex: "#0A84FF")
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
                                    .contextMenu {
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
                            playlistBadge: PlaylistSourceBadge(id: "default", playlistName: "Varsayılan", colorHex: "#BF5AF2")
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
                                    .contextMenu {
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
                            playlistBadge: PlaylistSourceBadge(id: "default", playlistName: "Varsayılan", colorHex: "#FF9F0A")
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
                                    .contextMenu {
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
                                                        Color(hex: "#25252B")
                                                        Image(systemName: "person.fill").font(.system(size: 38)).foregroundStyle(Color(hex: "#9B9BA5"))
                                                    }
                                                }
                                            }
                                            .frame(width: 112, height: 156)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            VStack(alignment: .leading, spacing: 10) {
                                                Text(credit.personName).font(.system(size: 24, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                                                Text(credit.result.item.title).font(.system(size: 20)).foregroundStyle(Color(hex: "#C0C6D6")).lineLimit(2)
                                                Text(credit.result.item.type == .series ? AppStrings.Search.series : AppStrings.Search.movies)
                                                    .font(.system(size: 17, weight: .medium)).foregroundStyle(Color(hex: "#64D2FF"))
                                            }
                                            Spacer(minLength: 0)
                                            Image(systemName: "play.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(Color(hex: "#0A84FF"))
                                        }
                                        .padding(18)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(hex: "#18181D"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    }
                                    .buttonStyle(.card)
                                    .id(credit.id)
                                    .focused($focusedTarget, equals: .result(credit.id))
                                    .accessibilityFocused($accessibilityFocusedTarget, equals: .result(credit.id))
                                    .accessibilityLabel("\(credit.personName), \(credit.result.item.title)")
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
                                    ProgramSearchResultCard(program: match.program, channel: match.result.item, playlistName: store.savedPlaylists.count > 1 ? match.result.playlistBadge.playlistName : nil) {
                                        store.send(.programSelected(match))
                                    }
                                    .id(match.id)
                                    .focused($focusedTarget, equals: .result(match.id))
                                    .accessibilityFocused($accessibilityFocusedTarget, equals: .result(match.id))
                                }
                            }
                            .scrollTargetLayout()
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 60)
                .scrollTargetLayout()
            }
            .scrollPosition($resultsScrollPosition, anchor: .center)
            .focusSection()
            .onChange(of: focusedTarget) { _, target in
                guard case let .result(id) = target else { return }
                resultsScrollPosition.scrollTo(id: id, anchor: .center)
            }
            .onChange(of: store.focusedResultID) { _, id in
                guard let id else { return }
                resultsScrollPosition.scrollTo(id: id, anchor: .center)
            }
            .onChange(of: focusRequestSequence) { _, requestID in
                guard let id = requestedFocusResultID, isResultVisible(id) else {
                    requestedFocusResultID = nil
                    return
                }
                resultsScrollPosition.scrollTo(id: id, anchor: .center)
                Task { @MainActor in
                    await Task.yield()
                    guard focusRequestSequence == requestID,
                          requestedFocusResultID == id,
                          isResultVisible(id)
                    else { return }
                    focusedTarget = .result(id)
                    accessibilityFocusedTarget = .result(id)
                    requestedFocusResultID = nil
                }
            }
            .onAppear {
                guard !isSearchOrFilterControlFocused,
                      let id = restoredResultID
                      ?? requestedFocusResultID.flatMap({ isResultVisible($0) ? $0 : nil })
                      ?? firstResultID
                else { return }
                resultsScrollPosition.scrollTo(id: id, anchor: .center)
                Task { @MainActor in
                    await Task.yield()
                    guard isResultVisible(id),
                          requestedFocusResultID == id || restoredResultID == id || firstResultID == id
                    else { return }
                    focusedTarget = .result(id)
                    accessibilityFocusedTarget = .result(id)
                    if requestedFocusResultID == id {
                        requestedFocusResultID = nil
                    }
                }
            }
        }

        // MARK: - Discovery & Empty Views

        private var emptySearchDiscoveryView: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 48) {
                    // Recent Searches (if available)
                    if !store.recentSearches.isEmpty {
                        VStack(alignment: .leading, spacing: 24) {
                            HStack {
                                Label(AppStrings.Search.recentSearches, systemImage: "clock.arrow.circlepath")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Button {
                                    store.send(.clearHistoryTapped)
                                } label: {
                                    Text(AppStrings.Search.clear)
                                        .font(.system(size: 20, weight: .semibold))
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
                                                .font(.system(size: 24))
                                                .foregroundColor(Color(hex: "#C0C6D6").opacity(0.5))
                                            Text(item.query)
                                                .font(.system(size: 28))
                                                .foregroundColor(Color(hex: "#E4E1E7"))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 24))
                                                .foregroundColor(Color(hex: "#C0C6D6").opacity(0.3))
                                        }
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 20)
                                        .background(Color(hex: "#1F1F23").opacity(0.5))
                                    }
                                    .buttonStyle(TVCategoryRowButtonStyle(accentColor: Color(hex: "#0A84FF"), isSelected: false))

                                    if item.id != store.recentSearches.prefix(5).last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.05))
                                            .padding(.leading, 70)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(hex: "#1F1F23"))
                            )
                        }
                    }

                    // Quick Discovery Categories & Tags
                    VStack(alignment: .leading, spacing: 28) {
                        Label(AppStrings.Search.quickTags, systemImage: "sparkles")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 30)], spacing: 30) {
                            ForEach(store.quickTags) { tag in
                                Button {
                                    store.send(.tagSelected(tag))
                                } label: {
                                    HStack(spacing: 20) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color(hex: tag.hexColor).opacity(0.2))
                                                .frame(width: 56, height: 56)
                                            Image(systemName: tag.icon)
                                                .font(.system(size: 28, weight: .semibold))
                                                .foregroundColor(Color(hex: tag.hexColor))
                                        }

                                        Text(tag.title)
                                            .font(.system(size: 26, weight: .semibold))
                                            .foregroundColor(.white)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(Color(hex: "#C0C6D6").opacity(0.4))
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 20)
                                }
                                .buttonStyle(TVCategoryRowButtonStyle(accentColor: Color(hex: tag.hexColor), isSelected: false))
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
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(count) \(AppStrings.Common.results)")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))
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
            shouldFocusResultsWhenAvailable = false
            requestedFocusResultID = resultID
            focusRequestSequence = UUID()
        }

        private func selectFilter(_ filter: SearchFeature.SearchFilter) {
            shouldFocusResultsWhenAvailable = false
            requestedFocusResultID = nil
            focusedTarget = .filter(filter)
            accessibilityFocusedTarget = .filter(filter)
            store.send(.filterChanged(filter))
        }

        private func selectPlaylistFilter(_ playlistID: UUID?) {
            shouldFocusResultsWhenAvailable = false
            requestedFocusResultID = nil
            focusedTarget = .playlist(playlistID)
            accessibilityFocusedTarget = .playlist(playlistID)
            store.send(.selectPlaylistFilter(playlistID))
        }

        private var isSearchOrFilterControlFocused: Bool {
            guard let focusedTarget else { return false }
            return switch focusedTarget {
            case .search, .clearQuery, .playlist(_), .filter: true
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
            let fallbackBadge = PlaylistSourceBadge(id: "default", playlistName: "Varsayılan", colorHex: "#0A84FF")
            let liveIDs = store.enrichedLiveResults.isEmpty
                ? store.liveResults.map { GlobalSearchResultItem(item: $0, playlistBadge: fallbackBadge).id }
                : store.enrichedLiveResults.map(\.id)
            let vodIDs = store.enrichedVODResults.isEmpty
                ? store.vodResults.map { GlobalSearchResultItem(item: $0, playlistBadge: fallbackBadge).id }
                : store.enrichedVODResults.map(\.id)
            let seriesIDs = store.enrichedSeriesResults.isEmpty
                ? store.seriesResults.map { GlobalSearchResultItem(item: $0, playlistBadge: fallbackBadge).id }
                : store.enrichedSeriesResults.map(\.id)
            return switch store.filter {
            case .all:
                liveIDs
                    + vodIDs
                    + seriesIDs
                    + store.peopleResults.map(\.id)
                    + store.programResults.map(\.id)
            case .uhd4k:
                liveIDs + vodIDs + seriesIDs
            case .live, .epgMatches:
                liveIDs
            case .vod:
                vodIDs
            case .series:
                seriesIDs
            case .people:
                store.peopleResults.map(\.id)
            case .programs:
                store.programResults.map(\.id)
            }
        }

        private var firstResultID: String? {
            visibleResultIDs.first
        }

        private func fallbackResultID(from items: [MediaModels.Item]) -> String? {
            guard let item = items.first else { return nil }
            let badge = PlaylistSourceBadge(id: "default", playlistName: "Varsayılan", colorHex: "#0A84FF")
            return GlobalSearchResultItem(item: item, playlistBadge: badge).id
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
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.3))
                Text(message)
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func errorView(_ error: String) -> some View {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 80))
                    .foregroundStyle(.red.opacity(0.7))
                Text(error)
                    .font(.system(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.7))
                    .padding(.horizontal, 60)
                Spacer()
            }
        }
    }
#endif
