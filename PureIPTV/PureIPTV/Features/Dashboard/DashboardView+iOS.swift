#if os(iOS)
    import ComposableArchitecture
    import FactoryKit
    import SwiftUI

    public struct DashboardView_iOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        let config: PlaylistConfig
        let onSearch: (() -> Void)?
        @State private var isShowingFollowedSportsEvents = false

        public init(store: StoreOf<DashboardFeature>, config: PlaylistConfig, onSearch: (() -> Void)? = nil) {
            self.store = store
            self.config = config
            self.onSearch = onSearch
        }

        public init(store: StoreOf<DashboardFeature>, serverURL: String, username: String, password: String, onSearch: (() -> Void)? = nil) {
            self.store = store
            self.onSearch = onSearch
            if (username.isEmpty && password.isEmpty) || serverURL.lowercased().contains(".m3u") {
                config = PlaylistConfig(type: .m3u, m3uURL: URL(string: serverURL))
            } else {
                config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
            }
        }

        public var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Top Header & Switcher Bar
                        VStack(spacing: 10) {
                            // Row 1: Title + Action Icons
                            HStack(spacing: 6) {
                                Text(AppStrings.Dashboard.title)
                                    .font(AppFonts.headline)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .layoutPriority(1)

                                Spacer()

                                Button {
                                    store.send(.refreshTapped)
                                } label: {
                                    HStack(spacing: 4) {
                                        if store.activeRefreshID != nil {
                                            ProgressView()
                                                .tint(AppColors.primary)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                        }
                                        if let refreshedAt = store.lastRemoteRefreshAt {
                                            Text(refreshedAt, style: .relative)
                                        } else {
                                            Text(AppStrings.Common.retry)
                                        }
                                    }
                                    .font(AppFonts.captionSemibold)
                                    .foregroundStyle(AppColors.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(AppColors.surfaceSecondary, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(store.activeRefreshID != nil)
                                .accessibilityLabel(AppStrings.Common.retry)

                                Button {
                                    store.send(.delegate(.presentHomeCategoryPinManagement(
                                        playlistID: store.activePlaylistID,
                                        profileScope: store.activeProfileScope
                                    )))
                                } label: {
                                    Image(systemName: "pin")
                                        .font(AppFonts.titleSmall)
                                        .foregroundStyle(AppColors.primary)
                                        .frame(width: 34, height: 34)
                                        .background(AppColors.surfaceSecondary, in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(AppStrings.Dashboard.manageHomeCategories)
                                .accessibilityHint(AppStrings.Dashboard.pinnedCategoryHint)

                                Button {
                                    store.send(.delegate(.presentHomeSettings(config)))
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(AppFonts.titleSmall)
                                        .foregroundStyle(AppColors.primary)
                                        .frame(width: 34, height: 34)
                                        .background(AppColors.surfaceSecondary, in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Ana Ekranı Düzenle")

                                if let onSearch {
                                    Button(action: onSearch) {
                                        Image(systemName: "magnifyingglass")
                                            .font(AppFonts.titleSmall)
                                            .foregroundStyle(AppColors.primary)
                                            .frame(width: 34, height: 34)
                                            .background(AppColors.surfaceSecondary, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(AppStrings.Search.searchPlaceholder)
                                }
                            }

                            // Row 2: Active Playlist Switcher Pill & VPN Status
                            HStack(spacing: 8) {
                                Button {
                                    store.send(.openManagePlaylistsTapped)
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(AppColors.success)
                                            .frame(width: 8, height: 8)
                                        Text(store.activePlaylistName.isEmpty ? AppStrings.PlaylistMgmt.accountManagement : store.activePlaylistName)
                                            .font(AppFonts.titleSmall)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .lineLimit(1)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(AppFonts.captionSmall)
                                            .foregroundStyle(AppColors.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(AppColors.surfaceSecondary)
                                            .overlay(Capsule().stroke(AppColors.borderMedium, lineWidth: 1))
                                    )
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                VPNStatusBadge(compact: true)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        if !store.catalogCountChanges.isEmpty {
                            DashboardCatalogCountSummaryView(
                                changes: store.catalogCountChanges,
                                onDismiss: { store.send(.dismissCatalogCountSummary) }
                            )
                            .padding(.horizontal, 16)
                        }

                        if store.isLoading {
                            loadingView
                        }
                        if let error = store.errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .font(.callout)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    store.send(.refreshTapped)
                                } label: {
                                    Label(AppStrings.Common.retry, systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.bordered)
                                .disabled(store.activeRefreshID != nil)
                            }
                            .padding(.horizontal, 16)
                        }
                        ForEach(store.homeSections.filter(\.isVisible)) { section in
                            homeSectionView(section)
                        }
                    }
                    .padding(.bottom, 96)
                }
            }
            .onAppear {
                store.send(.onAppear(config: config))
            }
            .onDisappear {
                store.send(.onDisappear)
            }
        }

        @ViewBuilder
        private func homeSectionView(_ section: HomeSectionConfig) -> some View {
            let isHeroVisible = store.homeSections.contains { $0.type == .hero && $0.isVisible }
            let newMovieItems = Array(store.featuredVODs.dropFirst(isHeroVisible ? 1 : 0))
            switch section.type {
            case .hero:
                if let heroVOD = store.featuredVODs.first {
                    HeroBannerView(vod: heroVOD) { store.send(.vodSelected(heroVOD)) }
                        .padding(.bottom, 8)
                }
            case .continueWatching:
                let continueWatching = store.continueWatchingItems
                if !continueWatching.isEmpty {
                    continueWatchingSection(continueWatching)
                }
            case .favorites:
                let favorites = store.favoriteItemsByType
                let availability = store.favoriteMoveAvailability
                if let items = favorites["live"], !items.isEmpty {
                    favoriteSection(items, title: AppStrings.Dashboard.favoriteLiveTV, moveAvailability: availability)
                }
                if let items = favorites["vod"], !items.isEmpty {
                    favoriteSection(items, title: AppStrings.Dashboard.favoriteMovies, moveAvailability: availability)
                }
                if let items = favorites["series"], !items.isEmpty {
                    favoriteSection(items, title: AppStrings.Dashboard.favoriteSeries, showsSeriesSortControl: true, moveAvailability: availability)
                }
                let categorizedTypes = Set(["live", "vod", "series"])
                let otherFavorites = favorites.filter { !categorizedTypes.contains($0.key) }.values.flatMap(\.self)
                if !otherFavorites.isEmpty {
                    favoriteSection(otherFavorites, title: AppStrings.Dashboard.myFavorites, moveAvailability: availability)
                }
            case .featuredLiveTV:
                if !store.featuredChannels.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.featuredLiveTV, items: store.featuredChannels) { channel in
                        ChannelCardView(channel: channel, isSelected: false) { store.send(.channelSelected(channel)) }
                            .frame(width: 240)
                    }
                }
                primaryCatalogFeedback(
                    catalog: .live,
                    message: AppStrings.LiveTV.noChannels,
                    hasContent: !store.featuredChannels.isEmpty,
                    isResolved: store.hasResolvedLiveCatalog
                )
            case .recentLiveTV:
                if !store.recentLiveChannels.isEmpty {
                    featuredSection(
                        title: AppStrings.LiveTV.recentChannels,
                        items: store.recentLiveChannels
                    ) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            ChannelCardView(channel: entry.channel, isSelected: false) {
                                store.send(.recentLiveChannelSelected(entry.id))
                            }
                            .accessibilityLabel("\(entry.channel.title), \(entry.playlistName)")
                            .accessibilityHint(AppStrings.Common.watchNow)
                            Text(entry.playlistName)
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textSecondary.opacity(0.8))
                                .lineLimit(1)
                                .accessibilityHidden(true)
                        }
                        .frame(width: 240, alignment: .leading)
                        .contextMenu {
                            Button {
                                store.send(.recentLiveChannelSelected(entry.id))
                            } label: {
                                Label(AppStrings.Common.watchNow, systemImage: "play.fill")
                            }
                            Button {
                                store.send(.togglePinRecentLiveChannel(entry.id))
                            } label: {
                                Label(
                                    entry.isPinned ? AppStrings.LiveTV.unpinRecentChannel : AppStrings.LiveTV.pinRecentChannel,
                                    systemImage: entry.isPinned ? "pin.slash" : "pin"
                                )
                            }
                            Button(role: .destructive) {
                                store.send(.removeRecentLiveChannel(entry.id))
                            } label: {
                                Label(AppStrings.Player.removeRecentChannel, systemImage: "clock.badge.xmark")
                            }
                        }
                        .disabled(store.pendingRecentLiveChannelMutationIDs[entry.id] != nil)
                    }
                }
            case .sportsHub:
                if store.isSportsHubVisible, !store.sportsHubEvents.isEmpty {
                    sportsHubSection
                }
            case .recommendations:
                if !store.newEpisodeSeries.isEmpty {
                    newEpisodeDiscoverySection
                }
                if !store.mostRatedMovies.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.mostRatedMovies, items: store.mostRatedMovies) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            VODCardView(vod: entry.item, isSelected: false) {
                                store.send(.vodSelected(entry.item))
                            }
                            Text(String(format: AppStrings.Dashboard.mostVotesSummary, entry.voteCount, entry.voteAverage))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.76))
                                .lineLimit(1)
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                }
                if !store.highestRatedMovies.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.highestRatedMovies, items: store.highestRatedMovies) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            VODCardView(vod: entry.item, isSelected: false) {
                                store.send(.vodSelected(entry.item))
                            }
                            Text(String(format: AppStrings.Dashboard.ratingVotesSummary, entry.voteAverage, entry.voteCount))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.76))
                                .lineLimit(1)
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                }
                if !store.awardWinningMovies.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.awardWinningMovies, items: store.awardWinningMovies) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            VODCardView(vod: entry.item, isSelected: false) { store.send(.vodSelected(entry.item)) }
                            Text(String(format: AppStrings.Dashboard.awardRecognitionCount, entry.recognitionCount))
                                .font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.76)).lineLimit(1)
                        }.frame(width: 140, alignment: .leading)
                    }
                }
                if !store.awardNomineeMovies.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.awardNomineeMovies, items: store.awardNomineeMovies) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            VODCardView(vod: entry.item, isSelected: false) { store.send(.vodSelected(entry.item)) }
                            Text(String(format: AppStrings.Dashboard.awardNominationCount, entry.recognitionCount))
                                .font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.76)).lineLimit(1)
                        }.frame(width: 140, alignment: .leading)
                    }
                }
                if !store.mostWatchedActors.isEmpty {
                    actorDiscoverySection
                }
                if store.isLoadingActorFilmography {
                    ProgressView(AppStrings.Common.loading)
                        .tint(.white)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }
                if !store.recommendedVODs.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.recommendedForYou, items: store.recommendedVODs) { vod in
                        VStack(alignment: .leading, spacing: 6) {
                            VODCardView(vod: vod, isSelected: false) { store.send(.vodSelected(vod)) }
                            if let reason = store.recommendationReasons[vod.id] {
                                Text(reason.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                }
                if store.isPersonalizationEnabled, !store.hasPersonalizedContent {
                    if store.isLoadingPersonalizedContent {
                        ProgressView(AppStrings.Common.loading)
                            .tint(.white)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    } else if store.hasLoadedRemoteData {
                        HStack(spacing: 12) {
                            Label(AppStrings.Dashboard.recommendedForYou, systemImage: "sparkles")
                                .foregroundStyle(.white.opacity(0.78))
                            Spacer()
                            Button {
                                store.send(.refreshTapped)
                            } label: {
                                Label(AppStrings.Common.retry, systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(store.activeRefreshID != nil)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                ForEach(store.actorRecommendationCollections) { collection in
                    let title = String(format: AppStrings.Dashboard.actorRecommendationTitle,
                                       collection.actorName,
                                       collection.sourceTitle,
                                       collection.kind.title)
                    featuredSection(title: title, items: collection.items) { item in
                        if collection.kind == .movie {
                            VODCardView(vod: item, isSelected: false) { store.send(.vodSelected(item)) }
                                .frame(width: 140)
                        } else {
                            SeriesCardView(series: item, isSelected: false) { store.send(.seriesSelected(item)) }
                                .frame(width: 140)
                        }
                    }
                }
                ForEach(store.selectedActorCollections) { collection in
                    let title = "\(store.selectedActorName ?? collection.actorName) • \(collection.kind.title)"
                    featuredSection(title: title, items: collection.items) { item in
                        if collection.kind == .movie {
                            VODCardView(vod: item, isSelected: false) { store.send(.vodSelected(item)) }
                                .frame(width: 140)
                        } else {
                            SeriesCardView(series: item, isSelected: false) { store.send(.seriesSelected(item)) }
                                .frame(width: 140)
                        }
                    }
                }
                if store.hasLoadedSelectedActorFilmography, store.selectedActorCollections.isEmpty {
                    Text(AppStrings.Dashboard.actorFilmographyUnavailable)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 16)
                }
            case .recentlyAddedVOD:
                if !newMovieItems.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.newMovies, items: newMovieItems) { vod in
                        VODCardView(vod: vod, isSelected: false) { store.send(.vodSelected(vod)) }
                            .frame(width: 140)
                    }
                }
                primaryCatalogFeedback(
                    catalog: .movies,
                    message: AppStrings.VOD.noMovies,
                    hasContent: !store.featuredVODs.isEmpty,
                    isResolved: store.hasResolvedMovieCatalog
                )
            case .trendingSeries:
                if !store.featuredSeries.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.newSeries, items: store.featuredSeries) { series in
                        SeriesCardView(series: series, isSelected: false) { store.send(.seriesSelected(series)) }
                            .frame(width: 140)
                    }
                }
                primaryCatalogFeedback(
                    catalog: .series,
                    message: AppStrings.Series.noSeries,
                    hasContent: !store.featuredSeries.isEmpty,
                    isResolved: store.hasResolvedSeriesCatalog
                )
            case .discoverCollections:
                ForEach(store.visibleExploreCollections) { collection in
                    homeCategorySection(collection)
                }
            }
        }

        @ViewBuilder
        private func primaryCatalogFeedback(
            catalog: DashboardFeature.PrimaryCatalog,
            message: String,
            hasContent: Bool,
            isResolved: Bool
        ) -> some View {
            if !hasContent, store.failedPrimaryCatalogs.contains(catalog) || isResolved {
                RetryableSectionEmptyState(message: message) {
                    store.send(.refreshTapped)
                }
                .frame(height: 210)
            } else if !hasContent, store.activeRefreshID != nil, !store.isLoading {
                ProgressView(AppStrings.Common.loading)
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }
        }

        private func homeCategorySection(_ collection: DashboardFeature.ExploreCollection) -> some View {
            let isPinned = store.pinnedHomeCategoryIDs.contains(collection.id)
            let canPin = collection.id.hasPrefix("live-category:") || collection.id.hasPrefix("movie-category:") || collection.id.hasPrefix("series-category:")
            return VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(collection.title)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()
                    if canPin {
                        Button {
                            store.send(.toggleHomeCategoryPin(collection.id))
                        } label: {
                            Image(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
                                .font(.body.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isPinned ? AppStrings.Dashboard.unpinHomeCategory : AppStrings.Dashboard.pinHomeCategory)
                        .accessibilityHint(AppStrings.Dashboard.pinnedCategoryHint)
                        .contextMenu {
                            if isPinned, let index = store.pinnedHomeCategoryIDs.firstIndex(of: collection.id) {
                                if index > 0 {
                                    Button {
                                        store.send(.moveHomeCategoryPin(collection.id, -1))
                                    } label: {
                                        Label(AppStrings.Dashboard.movePinnedCategoryUp, systemImage: "arrow.up")
                                    }
                                }
                                if index + 1 < store.pinnedHomeCategoryIDs.count {
                                    Button {
                                        store.send(.moveHomeCategoryPin(collection.id, 1))
                                    } label: {
                                        Label(AppStrings.Dashboard.movePinnedCategoryDown, systemImage: "arrow.down")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(collection.items) { item in
                            if item.type == .live {
                                ChannelCardView(channel: item, isSelected: false) { store.send(.channelSelected(item)) }
                                    .frame(width: 240)
                            } else if item.type == .series {
                                SeriesCardView(series: item, isSelected: false) { store.send(.seriesSelected(item)) }
                                    .frame(width: 140)
                            } else {
                                VODCardView(vod: item, isSelected: false) { store.send(.vodSelected(item)) }
                                    .frame(width: 140)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }

        private func featuredSection<T: Identifiable>(
            title: String,
            items: [T],
            @ViewBuilder content: @escaping (T) -> some View
        ) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(items) { item in
                            content(item)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }

        private var sportsHubEventGroupsForDisplay: [DashboardFeature.SportsHubEventGroup] {
            isShowingFollowedSportsEvents ? store.followedSportsHubEventGroups : store.sportsHubEventGroups
        }

        private var sportsHubSection: some View {
            let eventGroups = sportsHubEventGroupsForDisplay
            return VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(AppStrings.Dashboard.epgPrograms)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    if !store.followedSportsIDs.isEmpty || isShowingFollowedSportsEvents {
                        Button {
                            isShowingFollowedSportsEvents.toggle()
                        } label: {
                            Label(
                                isShowingFollowedSportsEvents
                                    ? AppStrings.Dashboard.showAllSportsEvents
                                    : AppStrings.Dashboard.showFollowedSportsEvents,
                                systemImage: isShowingFollowedSportsEvents ? "line.3.horizontal.decrease.circle.fill" : "star"
                            )
                        }
                        .buttonStyle(.bordered)
                        .tint(isShowingFollowedSportsEvents ? .yellow : .white)
                        .padding(.trailing, 16)
                    }
                }
                .padding(.leading, 16)

                if eventGroups.isEmpty {
                    Text(AppStrings.Dashboard.noFollowedSportsEvents)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(eventGroups) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(group.title ?? AppStrings.Dashboard.otherSportsMatches)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.78))
                                    .accessibilityAddTraits(.isHeader)
                                    .padding(.horizontal, 16)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 16) {
                                        ForEach(group.events) { event in
                                            DashboardEPGEventCard(
                                                event: event,
                                                followedSportsIDs: store.followedSportsIDs,
                                                pendingSportsFollowIDs: Set(store.pendingSportsFollowIDs.keys),
                                                onToggleSportsFollow: { kind, name in
                                                    store.send(.toggleSportsFollow(kind: kind, displayName: name))
                                                },
                                                onSelectChannel: { store.send(.channelSelected($0)) },
                                                onChooseChannel: {
                                                    guard let playlistID = store.activePlaylistID else { return }
                                                    store.send(.delegate(.presentEPGChannelPicker(playlistID: playlistID, event: event)))
                                                }
                                            )
                                            .frame(width: 260)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
            }
        }

        private func continueWatchingSection(_ items: [WatchHistoryItem]) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(AppStrings.Dashboard.continueWatching)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(items, id: \.compositeID) { item in
                            ResumeWatchingCardView(
                                item: item,
                                userAgentOverride: config.userAgentOverride,
                                onResume: { store.send(.historySelected(item)) },
                                onRestart: { store.send(.restartHistorySelected(item)) },
                                onDelete: { store.send(.deleteHistorySelected(item)) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }

        private func favoriteSection(
            _ items: [FavoriteItem],
            title: String,
            showsSeriesSortControl: Bool = false,
            moveAvailability: [FavoriteIdentity: Set<Int>]
        ) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if showsSeriesSortControl {
                        favoriteSeriesSortMenu
                    }
                }
                .padding(.horizontal, 16)

                if showsSeriesSortControl, store.favoriteSeriesSortDidFail {
                    Text(AppStrings.Dashboard.favoriteSeriesDatesLoadFailed)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(items, id: \.scopedIdentity) { item in
                            favoriteCard(item, moveOffsets: moveAvailability[item.scopedIdentity] ?? [])
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }

        private var favoriteSeriesSortMenu: some View {
            Menu {
                Button {
                    store.send(.setFavoriteSeriesSort(.newestEpisode))
                } label: {
                    Label(
                        AppStrings.Dashboard.newestEpisodeDate,
                        systemImage: store.favoriteSeriesSortMode == .newestEpisode ? "checkmark" : "calendar"
                    )
                }
                Button {
                    store.send(.setFavoriteSeriesSort(.existingOrder))
                } label: {
                    Label(
                        AppStrings.Dashboard.existingFavoriteOrder,
                        systemImage: store.favoriteSeriesSortMode == .existingOrder ? "checkmark" : "list.number"
                    )
                }
            } label: {
                Label(
                    store.isLoadingFavoriteSeriesSortDates
                        ? AppStrings.Dashboard.loadingFavoriteSeriesDates
                        : AppStrings.Dashboard.sortFavoriteSeries,
                    systemImage: store.isLoadingFavoriteSeriesSortDates ? "hourglass" : "arrow.up.arrow.down"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            }
            .accessibilityLabel(
                store.isLoadingFavoriteSeriesSortDates
                    ? AppStrings.Dashboard.loadingFavoriteSeriesDates
                    : AppStrings.Dashboard.sortFavoriteSeries
            )
            .accessibilityValue(
                store.favoriteSeriesSortMode == .newestEpisode
                    ? AppStrings.Dashboard.newestEpisodeDate
                    : AppStrings.Dashboard.existingFavoriteOrder
            )
        }

        @ViewBuilder
        private func favoriteCard(_ item: FavoriteItem, moveOffsets: Set<Int>) -> some View {
            let canMoveEarlier = moveOffsets.contains(-1)
            let canMoveLater = moveOffsets.contains(1)
            let mediaType = item.type.lowercased()
            let canReorder = mediaType == "vod"
                || (mediaType == "series" && store.favoriteSeriesSortMode != .newestEpisode)
            let card = FavoriteCardView(
                item: item,
                userAgentOverride: config.userAgentOverride,
                unwatchedEpisodeCount: item.playlistID == store.activePlaylistID
                    ? store.favoriteSeriesUnwatchedEpisodeCounts[item.id]
                    : nil
            ) {
                store.send(.favoriteSelected(item))
            }
            .frame(width: 140)
            .contextMenu {
                if canReorder, item.playlistID != nil {
                    Button {
                        store.send(.moveFavorite(item, offset: -1))
                    } label: {
                        Label(AppStrings.Favorites.moveUp, systemImage: "arrow.left")
                    }
                    .disabled(!canMoveEarlier)

                    Button {
                        store.send(.moveFavorite(item, offset: 1))
                    } label: {
                        Label(AppStrings.Favorites.moveDown, systemImage: "arrow.right")
                    }
                    .disabled(!canMoveLater)
                }
                Button(role: .destructive) {
                    store.send(.deleteFavorite(item))
                } label: {
                    Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                }
            }

            if canMoveEarlier, canMoveLater {
                card
                    .accessibilityAction(named: Text(AppStrings.Favorites.moveUp)) {
                        store.send(.moveFavorite(item, offset: -1))
                    }
                    .accessibilityAction(named: Text(AppStrings.Favorites.moveDown)) {
                        store.send(.moveFavorite(item, offset: 1))
                    }
            } else if canMoveEarlier {
                card.accessibilityAction(named: Text(AppStrings.Favorites.moveUp)) {
                    store.send(.moveFavorite(item, offset: -1))
                }
            } else if canMoveLater {
                card.accessibilityAction(named: Text(AppStrings.Favorites.moveDown)) {
                    store.send(.moveFavorite(item, offset: 1))
                }
            } else {
                card
            }
        }

        private var actorDiscoverySection: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.mostWatchedActors.first?.source == .popularFallback
                    ? AppStrings.Dashboard.popularActors
                    : AppStrings.Dashboard.mostWatchedActors)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(store.mostWatchedActors) { actor in
                            Button { store.send(.actorSelected(id: actor.id, name: actor.name)) } label: {
                                VStack(spacing: 8) {
                                    AsyncImage(url: actor.profilePath.flatMap {
                                        URL(string: "https://image.tmdb.org/t/p/w185\($0)")
                                    }) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Text(String(actor.name.prefix(1)))
                                            .font(.title2.bold())
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(Color.white.opacity(0.14))
                                    }
                                    .frame(width: 82, height: 82)
                                    .clipShape(Circle())

                                    Text(actor.name)
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(width: 96, height: 34, alignment: .top)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(actor.name))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }

        private var newEpisodeDiscoverySection: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(AppStrings.Dashboard.newEpisodesForYou)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(store.newEpisodeSeries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                SeriesCardView(series: entry.series, isSelected: false) {
                                    store.send(.seriesSelected(entry.series))
                                }
                                .frame(width: 140)
                                Text(String(format: AppStrings.Dashboard.newEpisodeCardSummary,
                                            entry.latestSeason,
                                            entry.latestEpisodeNumber,
                                            entry.newEpisodeCount))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.76))
                                    .lineLimit(1)
                                    .frame(width: 140, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }

        private var loadingView: some View {
            VStack(spacing: 24) {
                // Skeleton for Channels
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppStrings.Common.loading)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .shimmeringPlaceholder(isLoading: true)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0 ..< 5, id: \.self) { _ in
                                ChannelCardView(channel: .placeholder, isSelected: false) {}
                                    .frame(width: 240)
                                    .shimmeringPlaceholder(isLoading: true)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Skeleton for VODs
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppStrings.Common.loading)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .shimmeringPlaceholder(isLoading: true)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0 ..< 5, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppColors.surfaceSecondary)
                                    .frame(width: 140, height: 210)
                                    .shimmeringPlaceholder(isLoading: true)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    struct HeroBannerView: View {
        let vod: MediaModels.Item
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                ZStack(alignment: .bottomLeading) {
                    DashboardHeroArtworkView(vod: vod, height: 520)

                    // Premium Gradients for readability and fade
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.0), location: 0.3),
                            .init(color: .black.opacity(0.6), location: 0.7),
                            .init(color: .black, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.7), location: 0.0),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    // Content
                    VStack(alignment: .leading, spacing: 12) {
                        Text(vod.title)
                            .font(.system(size: 34, weight: .heavy, design: .default))
                            .lineSpacing(-2)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 4)

                        // Tags (Rating, Year, etc.)
                        HStack(spacing: 12) {
                            if let rating = vod.rating, rating > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill").foregroundColor(AppColors.warningGold)
                                    Text(String(format: "%.1f", rating))
                                        .fontWeight(.bold)
                                }
                            }

                            Text(AppStrings.Dashboard.hdBadge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.5), lineWidth: 1))

                            Text(AppStrings.Dashboard.movieBadge)
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.8))

                        // Action Buttons
                        HStack(spacing: 16) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(AppStrings.Common.watchNow)
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 4)

                            HStack {
                                Image(systemName: "info.circle")
                                Text(AppStrings.Dashboard.details)
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.2))
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                }
            }
            .buttonStyle(.fluidScale)
        }
    }

    struct FavoriteCardView: View {
        let item: FavoriteItem
        let userAgentOverride: String?
        var unwatchedEpisodeCount: Int?
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    if let urlString = item.coverURL, let url = URL(string: urlString) {
                        PlaylistAsyncImage(url: url, userAgentOverride: userAgentOverride, playlistID: item.playlistID) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Rectangle().fill(AppColors.surfaceSecondary)
                            }
                        }
                        .frame(width: 140, height: item.type == "live" ? 90 : 210)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(AppColors.destructive)
                                .padding(8)
                        }
                    } else {
                        Rectangle()
                            .fill(AppColors.surfaceSecondary)
                            .frame(width: 140, height: item.type == "live" ? 90 : 210)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Text(item.title)
                        .font(AppFonts.captionSemibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                }
                .overlay(alignment: .topLeading) {
                    if item.type.caseInsensitiveCompare("series") == .orderedSame,
                       let unwatchedEpisodeCount, unwatchedEpisodeCount > 0
                    {
                        Text("\(unwatchedEpisodeCount)")
                            .font(AppFonts.captionSmall)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(AppColors.live, in: Capsule())
                            .accessibilityLabel(Text(AppStrings.Dashboard.unwatchedEpisodeCount(unwatchedEpisodeCount)))
                    }
                }
            }
            .buttonStyle(.fluidScale)
        }
    }

    struct WatchHistoryCardView: View {
        let item: WatchHistoryItem
        let userAgentOverride: String?
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .bottomLeading) {
                        if let urlString = item.coverURL, let url = URL(string: urlString) {
                            PlaylistAsyncImage(url: url, userAgentOverride: userAgentOverride, playlistID: item.playlistID) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Rectangle().fill(AppColors.surfaceSecondary)
                                }
                            }
                            .frame(width: 200, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Rectangle()
                                .fill(AppColors.surfaceSecondary)
                                .frame(width: 200, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Progress Bar overlay
                        GeometryReader { proxy in
                            let progressPercent = max(0, min(1, item.progress / item.duration))
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 4)
                                .overlay(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.red)
                                        .frame(width: proxy.size.width * CGFloat(progressPercent), height: 4)
                                }
                        }
                        .frame(height: 4)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }

                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let seriesTitle = item.seriesTitle {
                        Text(seriesTitle)
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.fluidScale)
        }
    }
#endif
