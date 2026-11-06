#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS Dashboard View

    public struct DashboardView_tvOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        @Environment(\.displayScale) private var displayScale
        let config: PlaylistConfig
        @State private var isShowingFollowedSportsEvents = false

        public init(store: StoreOf<DashboardFeature>, config: PlaylistConfig) {
            self.store = store
            self.config = config
        }

        public init(store: StoreOf<DashboardFeature>, serverURL: String, username: String, password: String) {
            self.store = store
            if (username.isEmpty && password.isEmpty) || serverURL.lowercased().contains(".m3u") {
                config = PlaylistConfig(type: .m3u, m3uURL: URL(string: serverURL))
            } else {
                config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
            }
        }

        public var body: some View {
            let favoriteIDs = store.favoriteIDs
            let isHeroVisible = store.homeSections.contains { $0.type == .hero && $0.isVisible }
            let newMovieItems = store.featuredVODs.dropFirst(isHeroVisible ? 1 : 0)
            ZStack {
                DynamicMeshBackgroundView(
                    imageURL: store.featuredVODs.first?.coverURL,
                    titleSeed: store.featuredVODs.first?.title ?? "PureIPTV",
                    userAgentOverride: store.featuredVODs.first?.userAgentOverride,
                    playlistID: store.featuredVODs.first?.playlistID
                )

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 50) {
                        // Top Bar: Active Playlist Fast Switcher
                        HStack(spacing: 20) {
                            Spacer()
                            VPNStatusBadge(compact: false)
                            Button {
                                store.send(.refreshTapped)
                            } label: {
                                Label {
                                    if let refreshedAt = store.lastRemoteRefreshAt {
                                        Text(refreshedAt, style: .relative)
                                    } else {
                                        Text(AppStrings.Common.retry)
                                    }
                                } icon: {
                                    if store.activeRefreshID != nil {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                }
                                .font(AppFonts.captionBold)
                            }
                            .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                            .accessibilityLabel(AppStrings.Common.retry)
                            .accessibilityValue(store.activeRefreshID == nil ? "" : AppStrings.Common.loading)
                            Button {
                                store.send(.delegate(.presentHomeCategoryPinManagement(
                                    playlistID: store.activePlaylistID,
                                    profileScope: store.activeProfileScope
                                )))
                            } label: {
                                Label(AppStrings.Dashboard.manageHomeCategories, systemImage: "pin")
                                    .font(AppFonts.button)
                            }
                            .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                            Button {
                                store.send(.delegate(.presentHomeSettings(config)))
                            } label: {
                                Label("Ana Ekranı Düzenle", systemImage: "slider.horizontal.3")
                                    .font(AppFonts.button)
                            }
                            .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                            Button {
                                store.send(.openManagePlaylistsTapped)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(AppColors.success)
                                        .frame(width: 12, height: 12)
                                    Text(store.activePlaylistName.isEmpty ? AppStrings.PlaylistMgmt.accountManagement : store.activePlaylistName)
                                        .font(AppFonts.titleSmall)
                                        .foregroundStyle(AppColors.textPrimary)
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(AppFonts.bodyMedium)
                                        .foregroundStyle(AppColors.primary)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                        }
                        .padding(.horizontal, 60)
                        .padding(.top, 20)

                        if !store.catalogCountChanges.isEmpty {
                            DashboardCatalogCountSummaryView(
                                changes: store.catalogCountChanges,
                                onDismiss: { store.send(.dismissCatalogCountSummary) }
                            )
                            .padding(.horizontal, 60)
                        }

                        if store.isLoading {
                            tvLoadingView
                                .frame(maxWidth: .infinity)
                                .animation(.easeInOut(duration: 0.2), value: store.isLoading)
                        }
                        if let error = store.errorMessage {
                            HStack(spacing: 18) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppColors.warning)
                                Text(error)
                                    .font(AppFonts.titleSmall)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    store.send(.refreshTapped)
                                } label: {
                                    Label(AppStrings.Common.retry, systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(TVCapsuleButtonStyle(isPrimary: true, isSelected: false))
                                .accessibilityValue(store.activeRefreshID == nil ? "" : AppStrings.Common.loading)
                            }
                            .padding(.horizontal, 60)
                        }

                        ForEach(store.homeSections.filter(\.isVisible)) { section in
                            homeSectionView(
                                section,
                                favoriteIDs: favoriteIDs,
                                isHeroVisible: isHeroVisible,
                                newMovieItems: newMovieItems
                            )
                        }
                    }
                    .padding(.bottom, 80)
                }
                .focusSection()
            }
            .onAppear {
                store.send(.onAppear(config: config))
            }
            .onDisappear {
                store.send(.onDisappear)
            }
        }

        @ViewBuilder
        private func homeSectionView(
            _ section: HomeSectionConfig,
            favoriteIDs: Set<FavoriteIdentity>,
            isHeroVisible _: Bool,
            newMovieItems: ArraySlice<MediaModels.Item>
        ) -> some View {
            switch section.type {
            case .hero:
                if let heroVOD = store.featuredVODs.first {
                    DashboardHeroBannerView_tvOS(vod: heroVOD) { store.send(.vodSelected(heroVOD)) }
                        .focusSection()
                }
            case .continueWatching:
                let continueWatching = store.continueWatchingItems
                if !continueWatching.isEmpty {
                    TVShelfSection(title: AppStrings.Dashboard.continueWatching) {
                        ForEach(continueWatching, id: \.compositeID) { item in
                            ResumeWatchingCardView(item: item, userAgentOverride: config.userAgentOverride,
                                                   onResume: { store.send(.historySelected(item)) },
                                                   onRestart: { store.send(.restartHistorySelected(item)) },
                                                   onDelete: { store.send(.deleteHistorySelected(item)) })
                        }
                    }
                }
            case .favorites:
                DashboardFavoritesShelf_tvOS(store: store, config: config)
            case .featuredLiveTV:
                if !store.featuredChannels.isEmpty {
                    TVShelfSection(title: AppStrings.Dashboard.featuredLiveTV) {
                        ForEach(store.featuredChannels) { channel in
                            TVChannelCard(channel: channel, isSelected: false) {
                                store.send(.channelSelected(channel))
                            }
                            .frame(width: 340)
                            .contextMenu {
                                Button { store.send(.toggleFavorite(item: channel, type: "live")) } label: {
                                    Label(
                                        favoriteIDs.contains(FavoriteIdentity(type: "live", playlistID: store.activePlaylistID, id: channel.id))
                                            ? AppStrings.Common.removeFromFavorites : AppStrings.Common.addToFavorites,
                                        systemImage: favoriteIDs.contains(FavoriteIdentity(type: "live", playlistID: store.activePlaylistID, id: channel.id)) ? "heart.slash" : "heart"
                                    )
                                }
                                Button { store.send(.channelSelected(channel)) } label: {
                                    Label(AppStrings.Common.watchNow, systemImage: "play.fill")
                                }
                            }
                        }
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
                    TVShelfSection(title: AppStrings.LiveTV.recentChannels) {
                        ForEach(store.recentLiveChannels) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                TVChannelCard(channel: entry.channel, isSelected: false) {
                                    store.send(.recentLiveChannelSelected(entry.id))
                                }
                                .frame(width: 340)
                                .accessibilityLabel("\(entry.channel.title), \(entry.playlistName)")
                                .accessibilityHint(AppStrings.Common.watchNow)

                                Text(entry.playlistName)
                                    .font(AppFonts.caption)
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.82))
                                    .lineLimit(1)
                                    .padding(.horizontal, 4)
                                    .accessibilityHidden(true)
                            }
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
                        }
                    }
                }
            case .sportsHub:
                if store.isSportsHubVisible, !store.sportsHubEvents.isEmpty {
                    DashboardSportsHubShelf_tvOS(
                        store: store,
                        isShowingFollowedSportsEvents: $isShowingFollowedSportsEvents
                    )
                }
            case .recommendations:
                DashboardPersonalizationSection_tvOS(
                    store: store,
                    favoriteIDs: favoriteIDs,
                    config: config,
                    displayScale: displayScale
                )
            case .recentlyAddedVOD:
                if !newMovieItems.isEmpty {
                    TVShelfSection(title: AppStrings.Dashboard.newMovies) {
                        ForEach(newMovieItems) { vod in
                            TVVODCard(vod: vod, isSelected: false) { store.send(.vodSelected(vod)) }
                                .frame(width: 220)
                                .contextMenu {
                                    Button { store.send(.toggleFavorite(item: vod, type: "vod")) } label: {
                                        Label(
                                            favoriteIDs.contains(FavoriteIdentity(type: "vod", playlistID: store.activePlaylistID, id: vod.id))
                                                ? AppStrings.Common.removeFromFavorites : AppStrings.Common.addToFavorites,
                                            systemImage: favoriteIDs.contains(FavoriteIdentity(type: "vod", playlistID: store.activePlaylistID, id: vod.id)) ? "heart.slash" : "heart"
                                        )
                                    }
                                    Button { store.send(.vodSelected(vod)) } label: {
                                        Label("Detayları Gör", systemImage: "info.circle")
                                    }
                                }
                        }
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
                    TVShelfSection(title: AppStrings.Dashboard.newSeries) {
                        ForEach(store.featuredSeries) { series in
                            TVSeriesCard(series: series, isSelected: false) { store.send(.seriesSelected(series)) }
                                .frame(width: 220)
                                .contextMenu {
                                    Button { store.send(.toggleFavorite(item: series, type: "series")) } label: {
                                        Label(
                                            favoriteIDs.contains(FavoriteIdentity(type: "series", playlistID: store.activePlaylistID, id: series.id))
                                                ? AppStrings.Common.removeFromFavorites : AppStrings.Common.addToFavorites,
                                            systemImage: favoriteIDs.contains(FavoriteIdentity(type: "series", playlistID: store.activePlaylistID, id: series.id)) ? "heart.slash" : "heart"
                                        )
                                    }
                                    Button { store.send(.seriesSelected(series)) } label: {
                                        Label("Bölümleri Gör", systemImage: "list.number")
                                    }
                                }
                        }
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
                    DashboardQuickCategoriesShelf_tvOS(collection: collection, store: store)
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
                .frame(height: 300)
            } else if !hasContent, store.activeRefreshID != nil, !store.isLoading {
                ProgressView(AppStrings.Common.loading)
                    .font(AppFonts.titleSmall)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 40)
            }
        }

        private var tvLoadingView: some View {
            PureLoadingView(size: .large, text: AppStrings.Common.loadingAlt)
                .transition(.opacity)
        }
    }

    private struct DashboardPersonalizationSection_tvOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        let favoriteIDs: Set<FavoriteIdentity>
        let config: PlaylistConfig
        let displayScale: CGFloat

        var body: some View {
            Color.clear
                .frame(height: 1)
                .onScrollVisibilityChange(threshold: 0.5) { isVisible in
                    guard isVisible else { return }
                    store.send(.recommendationsSectionBecameVisible)
                }
            if !store.newEpisodeSeries.isEmpty {
                TVShelfSection(title: AppStrings.Dashboard.newEpisodesForYou) {
                    ForEach(store.newEpisodeSeries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            TVSeriesCard(series: entry.series, isSelected: false) {
                                store.send(.seriesSelected(entry.series))
                            }
                            .frame(width: 220)
                            Text(String(format: AppStrings.Dashboard.newEpisodeCardSummary,
                                        entry.latestSeason,
                                        entry.latestEpisodeNumber,
                                        entry.newEpisodeCount))
                                .font(AppFonts.captionMedium)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                                .frame(width: 220, alignment: .leading)
                        }
                    }
                }
            }
            if !store.mostRatedMovies.isEmpty {
                TVShelfSection(title: AppStrings.Dashboard.mostRatedMovies) {
                    ForEach(store.mostRatedMovies) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            TVVODCard(vod: entry.item, isSelected: false) {
                                store.send(.vodSelected(entry.item))
                            }
                            .frame(width: 220)
                            Text(String(format: AppStrings.Dashboard.mostVotesSummary, entry.voteCount, entry.voteAverage))
                                .font(AppFonts.captionMedium)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                                .frame(width: 220, alignment: .leading)
                        }
                    }
                }
            }
            if !store.highestRatedMovies.isEmpty {
                TVShelfSection(title: AppStrings.Dashboard.highestRatedMovies) {
                    ForEach(store.highestRatedMovies) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            TVVODCard(vod: entry.item, isSelected: false) {
                                store.send(.vodSelected(entry.item))
                            }
                            .frame(width: 220)
                            Text(String(format: AppStrings.Dashboard.ratingVotesSummary, entry.voteAverage, entry.voteCount))
                                .font(AppFonts.captionMedium)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                                .frame(width: 220, alignment: .leading)
                        }
                    }
                }
            }
            if !store.awardWinningMovies.isEmpty {
                TVShelfSection(title: AppStrings.Dashboard.awardWinningMovies) {
                    ForEach(store.awardWinningMovies) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            TVVODCard(vod: entry.item, isSelected: false) { store.send(.vodSelected(entry.item)) }
                                .frame(width: 220)
                            Text(String(format: AppStrings.Dashboard.awardRecognitionCount, entry.recognitionCount))
                                .font(AppFonts.captionMedium)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            if !store.awardNomineeMovies.isEmpty {
                TVShelfSection(title: AppStrings.Dashboard.awardNomineeMovies) {
                    ForEach(store.awardNomineeMovies) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            TVVODCard(vod: entry.item, isSelected: false) { store.send(.vodSelected(entry.item)) }
                                .frame(width: 220)
                            Text(String(format: AppStrings.Dashboard.awardNominationCount, entry.recognitionCount))
                                .font(AppFonts.captionMedium)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            if !store.mostWatchedActors.isEmpty {
                TVShelfSection(title: store.mostWatchedActors.first?.source == .popularFallback
                    ? AppStrings.Dashboard.popularActors
                    : AppStrings.Dashboard.mostWatchedActors)
                {
                    ForEach(store.mostWatchedActors) { actor in
                        Button { store.send(.actorSelected(id: actor.id, name: actor.name)) } label: {
                            VStack(spacing: 10) {
                                PlaylistAsyncImage(
                                    url: actor.profilePath.flatMap { TMDBImageURL.make(path: $0, size: .w185) },
                                    userAgentOverride: nil,
                                    playlistID: config.playlistID,
                                    downsamplingSize: CGSize(width: 132 * displayScale, height: 132 * displayScale)
                                ) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Text(String(actor.name.prefix(1)))
                                            .font(AppFonts.titleLarge)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(AppColors.surfaceElevated)
                                    }
                                }
                                .frame(width: 132, height: 132)
                                .clipShape(Circle())

                                Text(actor.name)
                                    .font(AppFonts.titleSmall)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 160, height: 48, alignment: .top)
                            }
                            .contentShape(Rectangle())
                        }
                        .tvFocusEffect()
                        .accessibilityLabel(Text(actor.name))
                    }
                }
            }
            if store.isLoadingActorFilmography {
                ProgressView(AppStrings.Common.loading)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 40)
            }
            if store.hasLoadedSelectedActorFilmography, store.selectedActorCollections.isEmpty {
                Text(AppStrings.Dashboard.actorFilmographyUnavailable)
                    .font(AppFonts.bodyMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 40)
            }
            if !store.recommendedVODs.isEmpty {
                TVShelfSection(title: AppStrings.Dashboard.recommendedForYou) {
                    ForEach(store.recommendedVODs) { vod in
                        VStack(alignment: .leading, spacing: 8) {
                            TVVODCard(vod: vod, isSelected: false) { store.send(.vodSelected(vod)) }
                                .frame(width: 220)
                                .contextMenu {
                                    Button { store.send(.toggleFavorite(item: vod, type: "vod")) } label: {
                                        Label(
                                            favoriteIDs.contains(FavoriteIdentity(type: "vod", playlistID: store.activePlaylistID, id: vod.id))
                                                ? AppStrings.Common.removeFromFavorites : AppStrings.Common.addToFavorites,
                                            systemImage: favoriteIDs.contains(FavoriteIdentity(type: "vod", playlistID: store.activePlaylistID, id: vod.id)) ? "heart.slash" : "heart"
                                        )
                                    }
                                    Button { store.send(.vodSelected(vod)) } label: {
                                        Label("Detayları Gör", systemImage: "info.circle")
                                    }
                                }
                            if let reason = store.recommendationReasons[vod.id] {
                                Text(reason.title)
                                    .font(AppFonts.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 220, alignment: .leading)
                    }
                }
            }
            if store.isPersonalizationEnabled, !store.hasPersonalizedContent {
                if store.isLoadingPersonalizedContent {
                    ProgressView(AppStrings.Common.loading)
                        .font(AppFonts.titleSmall)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 40)
                } else if store.hasLoadedRemoteData {
                    HStack(spacing: 22) {
                        Label(AppStrings.Dashboard.recommendedForYou, systemImage: "sparkles")
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textSecondary)
                        Button {
                            store.send(.refreshTapped)
                        } label: {
                            Label(AppStrings.Common.retry, systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: true, isSelected: false))
                        .accessibilityValue(store.activeRefreshID == nil ? "" : AppStrings.Common.loading)
                    }
                    .padding(.horizontal, 40)
                }
            }
            ForEach(store.actorRecommendationCollections) { collection in
                let title = String(format: AppStrings.Dashboard.actorRecommendationTitle,
                                   collection.actorName,
                                   collection.sourceTitle,
                                   collection.kind.title)
                TVShelfSection(title: title) {
                    ForEach(collection.items) { item in
                        if collection.kind == .movie {
                            TVVODCard(vod: item, isSelected: false) { store.send(.vodSelected(item)) }
                                .frame(width: 220)
                        } else {
                            TVSeriesCard(series: item, isSelected: false) { store.send(.seriesSelected(item)) }
                                .frame(width: 220)
                        }
                    }
                }
            }
            ForEach(store.selectedActorCollections) { collection in
                TVShelfSection(title: "\(store.selectedActorName ?? collection.actorName) • \(collection.kind.title)") {
                    ForEach(collection.items) { item in
                        if collection.kind == .movie {
                            TVVODCard(vod: item, isSelected: false) { store.send(.vodSelected(item)) }
                                .frame(width: 220)
                        } else {
                            TVSeriesCard(series: item, isSelected: false) { store.send(.seriesSelected(item)) }
                                .frame(width: 220)
                        }
                    }
                }
            }
        }
    }

    // MARK: - TV Shelf Section

    private struct TVShelfSection<Content: View>: View {
        let title: String
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(AppFonts.displayMedium)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 60)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 40) {
                        content()
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 40)
                }
                .focusSection()
            }
        }
    }

#endif
