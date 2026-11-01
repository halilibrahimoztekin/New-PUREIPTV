#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SearchView_iOS: View {
        @Bindable var store: StoreOf<SearchFeature>
        @FocusState private var isSearchFieldFocused: Bool
        let config: PlaylistConfig
        let onClose: (() -> Void)?

        /// Columns for grids
        private let channelColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 155, maximum: 200), spacing: 12),
        ]
        private let mediaColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 12),
        ]
        private let personColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 190, maximum: 300), spacing: 12),
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

                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 10)

                    // Multi-Playlist Filter Bar (if multiple playlists exist)
                    if store.savedPlaylists.count > 1, store.filter != .downloads {
                        playlistFilterBar
                            .padding(.bottom, 8)
                    }

                    if store.filter != .downloads {
                        contentScopeBar
                            .padding(.bottom, 8)
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
                store.send(.onAppear(config: config))
            }
            .defaultFocus($isSearchFieldFocused, true)
            // Dismiss keyboard when scrolling or tapping outside
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                    .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))

                TextField(AppStrings.Search.searchPlaceholder, text: $store.searchQuery.sending(\.queryChanged))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFieldFocused)

                if store.isSearching || store.isCurrentScopeSearching {
                    PureLoadingView(size: .small)
                        .padding(.trailing, 4)
                }

                if !store.searchQuery.isEmpty {
                    Button(action: {
                        HapticManager.shared.trigger(.light)
                        store.send(.queryChanged(""))
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))
                    }
                }

                if !store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.togglePinnedSearch(store.searchQuery))
                    } label: {
                        Image(systemName: store.isCurrentSearchPinned ? "pin.slash.fill" : "pin")
                            .foregroundColor(Color(hex: "#C0C6D6").opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(store.isCurrentSearchPinned ? AppStrings.Search.unpinSearch : AppStrings.Search.pinSearch)
                    .accessibilityHint(AppStrings.Search.togglePinnedSearchHint)
                }

                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color(hex: "#C0C6D6").opacity(0.75))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppStrings.Common.close)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#1F1F23"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }

        // MARK: - Multi-Playlist Filter Bar

        private var playlistFilterBar: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Global All Playlists Chip
                    let isGlobalSelected = store.selectedPlaylistID == nil
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.selectPlaylistFilter(nil))
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "globe.europe.africa.fill")
                                .font(.system(size: 11))
                            Text(AppStrings.Search.allPlaylistsShort)
                                .font(.system(size: 12, weight: isGlobalSelected ? .bold : .medium))
                        }
                        .foregroundStyle(isGlobalSelected ? .white : Color(hex: "#C0C6D6").opacity(0.75))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5.5)
                        .background(
                            Capsule()
                                .fill(isGlobalSelected ? Color(hex: "#0A84FF").opacity(0.28) : Color(hex: "#18181D"))
                                .overlay(
                                    Capsule()
                                        .stroke(isGlobalSelected ? Color(hex: "#0A84FF") : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isGlobalSelected ? .isSelected : [])

                    // Individual Saved Playlists
                    ForEach(Array(store.savedPlaylists.enumerated()), id: \.element.id) { index, playlist in
                        let isSelected = store.selectedPlaylistID == playlist.id
                        let badge = playlist.toPlaylistConfig().map {
                            UnifiedPlaylistManager.shared.badge(for: $0, index: index)
                        } ?? PlaylistSourceBadge(id: playlist.id.uuidString, playlistName: playlist.name, colorHex: "#0A84FF")

                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.selectPlaylistFilter(playlist.id))
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(badge.color)
                                    .frame(width: 6, height: 6)
                                Text(playlist.name)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            }
                            .foregroundStyle(isSelected ? .white : Color(hex: "#C0C6D6").opacity(0.75))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5.5)
                            .background(
                                Capsule()
                                    .fill(isSelected ? badge.color.opacity(0.28) : Color(hex: "#18181D"))
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? badge.color : Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }
        }

        // MARK: - Instant Filter Badges Bar

        private var filterBar: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SearchFeature.SearchFilter.allCases, id: \.self) { filter in
                        let isSelected = store.filter == filter
                        let count = store.filterCounts[filter]

                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.filterChanged(filter))
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: filter.icon)
                                    .font(.system(size: 11, weight: .semibold))

                                Text(filter.title)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))

                                if let count, count > 0 {
                                    Text("(\(count))")
                                        .font(.system(size: 11, weight: .bold))
                                        .opacity(isSelected ? 0.95 : 0.6)
                                }
                            }
                            .foregroundStyle(isSelected ? .white : Color(hex: "#C0C6D6").opacity(0.75))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(isSelected ? filter.badgeColor : Color(hex: "#1F1F23"))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(isSelected ? 0.25 : 0.08), lineWidth: 1)
                                    )
                            )
                            .shadow(
                                color: isSelected ? filter.badgeColor.opacity(0.4) : .clear,
                                radius: 6,
                                x: 0,
                                y: 2
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                    }
                }
                .padding(.horizontal, 16)
            }
        }

        private var contentScopeBar: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SearchFeature.SearchContentScope.allCases, id: \.self) { scope in
                        let isSelected = store.searchContentScope == scope
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.searchContentScopeChanged(scope))
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: scope.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(scope.title)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            }
                            .foregroundStyle(isSelected ? .white : Color(hex: "#C0C6D6").opacity(0.75))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color(hex: "#0A84FF").opacity(0.28) : Color(hex: "#1F1F23"))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(isSelected ? 0.25 : 0.08), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }
        }

        // MARK: - Results Scroll View

        private var resultsScrollView: some View {
            ScrollView {
                VStack(spacing: 24) {
                    if store.filter == .downloads {
                        downloadedMediaResultsSection
                    } else {
                        if store.searchQuery.isEmpty || store.searchContentScope == .all {
                            curatedPlaylistSection
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
                                LazyVGrid(columns: channelColumns, spacing: 12) {
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
                                        .contextMenu {
                                            curatedPlaylistContextMenuItem(for: result)

                                            if let program = result.matchedEPGProgram, program.startTime > Date() {
                                                Button {
                                                    store.send(.toggleReminder(program, result.item, reminderID: result.reminderID(for: program), playlistIdentity: store.playlistIdentitiesByBadgeID[result.playlistBadge.id] ?? ""))
                                                } label: {
                                                    Label(
                                                        store.scheduledReminderIDs.contains(result.reminderID(for: program))
                                                            || store.scheduledReminderIDs.contains(program.id)
                                                            ? AppStrings.Player.removeReminder
                                                            : AppStrings.Player.setReminder,
                                                        systemImage: (store.scheduledReminderIDs.contains(result.reminderID(for: program))
                                                            || store.scheduledReminderIDs.contains(program.id))
                                                            ? "bell.slash.fill"
                                                            : "bell.fill"
                                                    )
                                                }
                                                .disabled(store.pendingReminderRequestIDs[result.reminderID(for: program)] != nil)
                                            }

                                            Button {
                                                store.send(.toggleFavorite(item: result.item, type: "live", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID))
                                            } label: {
                                                Label(
                                                    store.favoriteIDs.contains(FavoriteIdentity(type: "live", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID, id: result.item.id))
                                                        ? AppStrings.Common.removeFromFavorites
                                                        : AppStrings.Common.addToFavorites,
                                                    systemImage: store.favoriteIDs.contains(FavoriteIdentity(type: "live", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID, id: result.item.id)) ? "heart.slash" : "heart"
                                                )
                                            }

                                            Button {
                                                store.send(.channelSelected(result.item))
                                            } label: {
                                                Label(AppStrings.Common.watchNow, systemImage: "play.fill")
                                            }
                                        }
                                    }
                                }
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
                                LazyVGrid(columns: mediaColumns, spacing: 12) {
                                    ForEach(vods) { result in
                                        GlobalSearchResultCard(
                                            result: result,
                                            isSelected: false,
                                            showPlaylistBadge: store.savedPlaylists.count > 1
                                        ) {
                                            store.send(.vodSelected(result.item))
                                        }
                                        .contextMenu {
                                            curatedPlaylistContextMenuItem(for: result)

                                            Button {
                                                store.send(.toggleFavorite(item: result.item, type: "vod", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID))
                                            } label: {
                                                Label(
                                                    store.favoriteIDs.contains(FavoriteIdentity(type: "vod", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID, id: result.item.id))
                                                        ? AppStrings.Common.removeFromFavorites
                                                        : AppStrings.Common.addToFavorites,
                                                    systemImage: store.favoriteIDs.contains(FavoriteIdentity(type: "vod", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID, id: result.item.id)) ? "heart.slash" : "heart"
                                                )
                                            }

                                            Button {
                                                store.send(.vodSelected(result.item))
                                            } label: {
                                                Label(AppStrings.Common.watchNow, systemImage: "play.fill")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 3. Series Section
                        let seriesList = store.enrichedSeriesResults.isEmpty ? store.seriesResults.map {
                            GlobalSearchResultItem(
                                item: $0,
                                playlistBadge: store.fallbackSourceBadge
                            )
                        } : store.enrichedSeriesResults

                        if !seriesList.isEmpty {
                            resultSection(title: AppStrings.Search.series, count: seriesList.count) {
                                LazyVGrid(columns: mediaColumns, spacing: 12) {
                                    ForEach(seriesList) { result in
                                        GlobalSearchResultCard(
                                            result: result,
                                            isSelected: false,
                                            showPlaylistBadge: store.savedPlaylists.count > 1
                                        ) {
                                            store.send(.seriesSelected(result.item))
                                        }
                                        .contextMenu {
                                            curatedPlaylistContextMenuItem(for: result)

                                            Button {
                                                store.send(.toggleFavorite(item: result.item, type: "series", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID))
                                            } label: {
                                                Label(
                                                    store.favoriteIDs.contains(FavoriteIdentity(type: "series", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID, id: result.item.id))
                                                        ? AppStrings.Common.removeFromFavorites
                                                        : AppStrings.Common.addToFavorites,
                                                    systemImage: store.favoriteIDs.contains(FavoriteIdentity(type: "series", playlistID: store.playlistIDsByBadgeID[result.playlistBadge.id] ?? store.selectedPlaylistID, id: result.item.id)) ? "heart.slash" : "heart"
                                                )
                                            }

                                            Button {
                                                store.send(.seriesSelected(result.item))
                                            } label: {
                                                Label(AppStrings.Common.watchNow, systemImage: "play.fill")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if store.filter == .all || store.filter == .people, !store.peopleResults.isEmpty {
                            resultSection(title: AppStrings.Search.people, count: store.peopleResults.count) {
                                LazyVGrid(columns: personColumns, spacing: 12) {
                                    ForEach(store.peopleResults) { credit in
                                        Button {
                                            HapticManager.shared.trigger(.light)
                                            store.send(.personCreditSelected(credit))
                                        } label: {
                                            HStack(spacing: 12) {
                                                AsyncImage(url: credit.portraitURL) { phase in
                                                    if let image = phase.image {
                                                        image.resizable().scaledToFill()
                                                    } else {
                                                        ZStack {
                                                            Color(hex: "#25252B")
                                                            Image(systemName: "person.fill").foregroundStyle(Color(hex: "#9B9BA5"))
                                                        }
                                                    }
                                                }
                                                .frame(width: 64, height: 88)
                                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                                VStack(alignment: .leading, spacing: 6) {
                                                    highlightedSearchText(credit.personName, queryTerms: store.debouncedQuery.split(whereSeparator: \.isWhitespace).map(String.init))
                                                        .font(.body.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                                                    Text("\(AppStrings.Search.people) · \(store.debouncedQuery)")
                                                        .font(.caption2.weight(.medium))
                                                        .foregroundStyle(Color(hex: "#FFD60A"))
                                                        .lineLimit(1)
                                                    Text(credit.result.item.displayTitle).font(.subheadline).foregroundStyle(Color(hex: "#C0C6D6")).lineLimit(2)
                                                    Text(credit.result.item.type == .series ? AppStrings.Search.series : AppStrings.Search.movies)
                                                        .font(.caption.weight(.medium)).foregroundStyle(Color(hex: "#64D2FF"))
                                                    if store.selectedPlaylistID == nil, store.savedPlaylists.count > 1 {
                                                        Text(credit.result.playlistBadge.playlistName)
                                                            .font(.caption2).foregroundStyle(Color(hex: "#9B9BA5")).lineLimit(1)
                                                    }
                                                }
                                                Spacer(minLength: 0)
                                                Image(systemName: "play.fill").font(.caption.weight(.bold)).foregroundStyle(Color(hex: "#0A84FF"))
                                            }
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(hex: "#18181D"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("\(credit.personName), \(credit.result.item.displayTitle), \(credit.result.item.type == .series ? AppStrings.Search.series : AppStrings.Search.movies), \(AppStrings.Search.people), \(store.debouncedQuery), \(credit.result.playlistBadge.playlistName)")
                                        .accessibilityHint(AppStrings.Common.watchNow)
                                    }
                                }
                            }
                        }

                        if store.filter == .all || store.filter == .programs, !store.programResults.isEmpty {
                            resultSection(title: AppStrings.Search.programs, count: store.programResults.count) {
                                LazyVGrid(columns: channelColumns, spacing: 12) {
                                    ForEach(store.programResults) { match in
                                        ProgramSearchResultCard(program: match.program, channel: match.result.item, playlistName: store.savedPlaylists.count > 1 ? match.result.playlistBadge.playlistName : nil, query: store.debouncedQuery) {
                                            store.send(.programSelected(match))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }

        private var downloadedMediaResultsSection: some View {
            resultSection(title: AppStrings.Downloads.completedDownloads, count: store.downloadedMediaResults.count) {
                LazyVGrid(columns: mediaColumns, spacing: 12) {
                    ForEach(store.downloadedMediaResults) { item in
                        Button {
                            store.send(.offlineMediaSelected(item))
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundStyle(Color(hex: "#30D158"))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                    if let episode = item.episodeMetadata {
                                        Text("\(episode.seriesTitle) · S\(episode.seasonNumber) E\(episode.episodeNumber)")
                                            .font(.caption)
                                            .foregroundStyle(Color(hex: "#C0C6D6"))
                                            .lineLimit(1)
                                    }
                                    Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                                        .font(.caption2)
                                        .foregroundStyle(Color(hex: "#9B9BA5"))
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "play.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color(hex: "#0A84FF"))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "#18181D"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.title)
                        .accessibilityHint(AppStrings.Common.watchNow)
                    }
                }
            }
        }

        @ViewBuilder
        private var curatedPlaylistSection: some View {
            let results = store.curatedPlaylistResults
            let unavailable = store.unavailableCuratedPlaylistEntries
            if !results.isEmpty || !unavailable.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(AppStrings.Search.myCollection, systemImage: "rectangle.stack.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(results.count + unavailable.count)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(results) { result in
                                GlobalSearchResultCard(result: result, isSelected: false, showPlaylistBadge: true) {
                                    selectCuratedResult(result)
                                }
                                .frame(width: result.item.type == .live ? 210 : 145)
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
            return VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Button {
                        store.send(.removeCuratedPlaylistItem(entry.id))
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppStrings.Common.delete)
                }
                Text(entry.titleSnapshot)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(sourceDetails)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 145, height: 150, alignment: .leading)
            .background(Color(hex: "#18181D"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            VStack(alignment: .leading, spacing: 14) {
                Label(AppStrings.Search.pinnedSearches, systemImage: "pin.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(AppStrings.Search.pinnedSearchesDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    ForEach(store.pinnedSearchQueries, id: \.self) { query in
                        HStack(spacing: 8) {
                            Button {
                                HapticManager.shared.trigger(.light)
                                store.send(.recentSearchTapped(query))
                            } label: {
                                HStack {
                                    Image(systemName: "pin.fill")
                                        .foregroundColor(Color(hex: "#0A84FF"))
                                        .font(.system(size: 14))
                                    Text(query)
                                        .font(.system(size: 15))
                                        .foregroundColor(Color(hex: "#E4E1E7"))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#C0C6D6").opacity(0.3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(AppStrings.Search.runPinnedSearchHint)

                            Button {
                                store.send(.togglePinnedSearch(query))
                            } label: {
                                Image(systemName: "pin.slash")
                                    .foregroundColor(Color(hex: "#C0C6D6").opacity(0.7))
                                    .frame(width: 40, height: 40)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(AppStrings.Search.unpinSearch)
                        }

                        if query != store.pinnedSearchQueries.last {
                            Divider()
                                .background(Color.white.opacity(0.05))
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "#1F1F23"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
            }
        }

        private var emptySearchDiscoveryView: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    curatedPlaylistSection

                    if !store.pinnedSearchQueries.isEmpty {
                        pinnedSearchesSection
                    }

                    // Recent Searches Section
                    if !store.recentSearches.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label(AppStrings.Search.recentSearches, systemImage: "clock.arrow.circlepath")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Button {
                                    HapticManager.shared.trigger(.light)
                                    store.send(.clearHistoryTapped)
                                } label: {
                                    Text(AppStrings.Search.clear)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(hex: "#0A84FF"))
                                }
                            }

                            VStack(spacing: 0) {
                                ForEach(store.recentSearches.prefix(6), id: \.id) { item in
                                    Button {
                                        HapticManager.shared.trigger(.light)
                                        store.send(.recentSearchTapped(item.query))
                                    } label: {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(Color(hex: "#C0C6D6").opacity(0.5))
                                                .font(.system(size: 14))
                                            Text(item.query)
                                                .font(.system(size: 15))
                                                .foregroundColor(Color(hex: "#E4E1E7"))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(hex: "#C0C6D6").opacity(0.3))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(hex: "#1F1F23").opacity(0.5))
                                    }
                                    .buttonStyle(.plain)

                                    if item.id != store.recentSearches.prefix(6).last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.05))
                                            .padding(.leading, 40)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "#1F1F23"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                        }
                    }

                    // Quick Discovery Categories & Tags
                    VStack(alignment: .leading, spacing: 14) {
                        Label(AppStrings.Search.quickTags, systemImage: "sparkles")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 200), spacing: 12)], spacing: 12) {
                            ForEach(store.quickTags) { tag in
                                Button {
                                    HapticManager.shared.trigger(.light)
                                    store.send(.tagSelected(tag))
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color(hex: tag.hexColor).opacity(0.18))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: tag.icon)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(Color(hex: tag.hexColor))
                                        }

                                        Text(tag.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.3))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color(hex: "#18181D"))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }

        private func resultSection(title: String, count: Int, @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("\(count) \(AppStrings.Common.results)")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))
                        .padding(.bottom, 2)
                }
                content()
            }
        }

        private var loadingView: some View {
            VStack(spacing: 16) {
                Spacer()
                PureLoadingView(size: .large, text: AppStrings.Search.loadingMessage)
                Spacer()
            }
            .padding()
        }

        private var searchingView: some View {
            VStack(spacing: 14) {
                Spacer()
                PureLoadingView(size: .medium, text: AppStrings.Common.loading)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func emptyStateView(_ message: String, icon: String) -> some View {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.3))
                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                if let suggestion = store.searchRecoverySuggestion {
                    Button {
                        applySearchRecovery(suggestion)
                    } label: {
                        Text(suggestion.title)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#0A84FF"))
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
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.red.opacity(0.7))
                Text(error)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.7))
                    .padding(.horizontal, 24)
                Spacer()
            }
        }
    }
#endif
