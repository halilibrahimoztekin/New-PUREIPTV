#if os(iOS)
    import ComposableArchitecture
    import FactoryKit
    import SwiftUI

    public struct DashboardView_iOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        let config: PlaylistConfig
        @State private var isHomeSettingsPresented = false
        @State private var isCategoryManagementPresented = false
        @State private var eventForChannelMapping: DashboardFeature.EPGEvent?
        @State private var playlistIDForChannelMapping: UUID?

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
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Top Switcher Bar
                        HStack(spacing: 8) {
                            Text(AppStrings.Dashboard.title)
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Spacer()

                            VPNStatusBadge(compact: true)

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
                                            .tint(Color(hex: "#0A84FF"))
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: "#0A84FF"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#1F1F23"), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(store.activeRefreshID != nil)
                            .accessibilityLabel(AppStrings.Common.retry)

                            Button {
                                isCategoryManagementPresented = true
                            } label: {
                                Image(systemName: "pin")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color(hex: "#0A84FF"))
                                    .frame(width: 44, height: 44)
                                    .background(Color(hex: "#1F1F23"), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(AppStrings.Dashboard.manageHomeCategories)
                            .accessibilityHint(AppStrings.Dashboard.pinnedCategoryHint)

                            Button {
                                isHomeSettingsPresented = true
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color(hex: "#0A84FF"))
                                    .frame(width: 44, height: 44)
                                    .background(Color(hex: "#1F1F23"), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Ana Ekranı Düzenle")

                            Button {
                                store.send(.openManagePlaylistsTapped)
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text(store.activePlaylistName.isEmpty ? AppStrings.PlaylistMgmt.accountManagement : store.activePlaylistName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(Color(hex: "#0A84FF"))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#1F1F23"))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

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
                    .padding(.bottom, 24)
                }
            }
            .onAppear {
                store.send(.onAppear(config: config))
            }
            .onDisappear {
                store.send(.onDisappear)
            }
            .sheet(isPresented: $isHomeSettingsPresented, onDismiss: {
                store.send(.onAppear(config: config))
            }) {
                ModularHomeSettingsView()
            }
            .sheet(isPresented: $isCategoryManagementPresented) {
                HomeCategoryPinManagementView(store: store)
            }
            .sheet(item: $eventForChannelMapping, onDismiss: {
                playlistIDForChannelMapping = nil
            }) { event in
                DashboardEPGChannelPicker(channels: store.epgCandidateChannels) { channel in
                    guard let playlistID = playlistIDForChannelMapping else { return }
                    store.send(.mapEPGEventToChannel(playlistID: playlistID, event: event, channelID: channel.id))
                }
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
                if !store.continueWatchingItems.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.continueWatching, items: store.continueWatchingItems) { item in
                        ResumeWatchingCardView(item: item, userAgentOverride: config.userAgentOverride,
                                               onResume: { store.send(.historySelected(item)) },
                                               onRestart: { store.send(.restartHistorySelected(item)) },
                                               onDelete: { store.send(.deleteHistorySelected(item)) })
                    }
                }
            case .favorites:
                let favorites = store.favoriteItemsByType
                if let items = favorites["live"], !items.isEmpty {
                    favoriteSection(items, title: AppStrings.Dashboard.favoriteLiveTV)
                }
                if let items = favorites["vod"], !items.isEmpty {
                    favoriteSection(items, title: AppStrings.Dashboard.favoriteMovies)
                }
                if let items = favorites["series"], !items.isEmpty {
                    favoriteSection(items, title: AppStrings.Dashboard.favoriteSeries)
                }
                let categorizedTypes = Set(["live", "vod", "series"])
                let otherFavorites = favorites.filter { !categorizedTypes.contains($0.key) }.values.flatMap(\.self)
                if !otherFavorites.isEmpty {
                    favoriteSection(otherFavorites, title: AppStrings.Dashboard.myFavorites)
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
            case .sportsHub:
                if store.isSportsHubVisible, !store.epgEvents.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.epgPrograms, items: store.epgEvents) { event in
                        DashboardEPGEventCard(
                            event: event,
                            onSelectChannel: { store.send(.channelSelected($0)) },
                            onChooseChannel: {
                                guard let playlistID = store.activePlaylistID else { return }
                                playlistIDForChannelMapping = playlistID
                                eventForChannelMapping = event
                            }
                        )
                        .frame(width: 260)
                    }
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

        private func favoriteSection(_ items: [FavoriteItem], title: String) -> some View {
            featuredSection(title: title, items: items) { item in
                FavoriteCardView(
                    item: item,
                    userAgentOverride: config.userAgentOverride,
                    unwatchedEpisodeCount: item.playlistID == store.activePlaylistID
                        ? store.favoriteSeriesUnwatchedEpisodeCounts[item.id]
                        : nil
                ) {
                    store.send(.favoriteSelected(item))
                }
                .frame(width: 140)
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
                                    .fill(Color(hex: "#1F1F23"))
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
                    // Poster/Backdrop
                    if let url = vod.coverURL {
                        PlaylistAsyncImage(url: url, userAgentOverride: vod.userAgentOverride, playlistID: vod.playlistID) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color(hex: "#0F0F13").shimmeringPlaceholder(isLoading: true)
                            }
                        }
                        .frame(height: 520)
                        .clipped()
                    } else {
                        Color(hex: "#0F0F13").frame(height: 520)
                    }

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
                                    Image(systemName: "star.fill").foregroundColor(Color(hex: "#FFD700"))
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
                                Rectangle().fill(Color(hex: "#1F1F23"))
                            }
                        }
                        .frame(width: 140, height: item.type == "live" ? 90 : 210)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                                .padding(8)
                        }
                    } else {
                        Rectangle()
                            .fill(Color(hex: "#1F1F23"))
                            .frame(width: 140, height: item.type == "live" ? 90 : 210)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .overlay(alignment: .topLeading) {
                    if item.type.caseInsensitiveCompare("series") == .orderedSame,
                       let unwatchedEpisodeCount, unwatchedEpisodeCount > 0
                    {
                        Text("\(unwatchedEpisodeCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(hex: "#FF453A"), in: Capsule())
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
                                    Rectangle().fill(Color(hex: "#1F1F23"))
                                }
                            }
                            .frame(width: 200, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Rectangle()
                                .fill(Color(hex: "#1F1F23"))
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
