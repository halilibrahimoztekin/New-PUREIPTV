#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS Dashboard View

    public struct DashboardView_tvOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        let config: PlaylistConfig
        @State private var isHomeSettingsPresented = false
        @State private var isCategoryManagementPresented = false

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
                DynamicMeshBackgroundView(
                    imageURL: store.featuredVODs.first?.coverURL,
                    titleSeed: store.featuredVODs.first?.title ?? "PureIPTV"
                )

                if store.isLoading {
                    tvLoadingView
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 50) {
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
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    .font(.system(size: 18, weight: .semibold))
                                }
                                .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                                .accessibilityLabel(AppStrings.Common.retry)
                                Button {
                                    isCategoryManagementPresented = true
                                } label: {
                                    Label(AppStrings.Dashboard.manageHomeCategories, systemImage: "pin")
                                        .font(.system(size: 20, weight: .semibold))
                                }
                                .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                                Button {
                                    isHomeSettingsPresented = true
                                } label: {
                                    Label("Ana Ekranı Düzenle", systemImage: "slider.horizontal.3")
                                        .font(.system(size: 20, weight: .semibold))
                                }
                                .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                                Button {
                                    store.send(.openManagePlaylistsTapped)
                                } label: {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 12, height: 12)
                                        Text(store.activePlaylistName.isEmpty ? AppStrings.PlaylistMgmt.accountManagement : store.activePlaylistName)
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Color(hex: "#0A84FF"))
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                            }
                            .padding(.horizontal, 60)
                            .padding(.top, 20)

                            ForEach(store.homeSections.filter(\.isVisible)) { section in
                                homeSectionView(section)
                            }
                        }
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: store.isLoading)
                    }
                    .focusSection()
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
        }

        @ViewBuilder
        private func homeSectionView(_ section: HomeSectionConfig) -> some View {
            let isHeroVisible = store.homeSections.contains { $0.type == .hero && $0.isVisible }
            let newMovieItems = Array(store.featuredVODs.dropFirst(isHeroVisible ? 1 : 0))
            switch section.type {
            case .hero:
                if let heroVOD = store.featuredVODs.first {
                    TVHeroBanner(vod: heroVOD) { store.send(.vodSelected(heroVOD)) }
                        .focusGuideBoundary()
                }
            case .continueWatching:
                if !store.continueWatchingItems.isEmpty {
                    TVShelfSection(title: AppStrings.Dashboard.continueWatching) {
                        ForEach(store.continueWatchingItems) { item in
                            ResumeWatchingCardView(item: item, userAgentOverride: config.userAgentOverride,
                                                   onResume: { store.send(.historySelected(item)) },
                                                   onRestart: { store.send(.restartHistorySelected(item)) },
                                                   onDelete: { store.send(.deleteHistorySelected(item)) })
                        }
                    }
                }
            case .favorites:
                if !store.favoriteItems.isEmpty {
                    TVShelfSection(title: AppStrings.Dashboard.myFavorites) {
                        ForEach(store.favoriteItems) { item in
                            TVFavoriteMediaCard(
                                item: item,
                                userAgentOverride: config.userAgentOverride,
                                unwatchedEpisodeCount: item.playlistID == store.activePlaylistID
                                    ? store.favoriteSeriesUnwatchedEpisodeCounts[item.id]
                                    : nil
                            ) {
                                store.send(.favoriteSelected(item))
                            }
                            .frame(width: item.type.lowercased() == "live" ? 340 : 220)
                            .contextMenu {
                                Button { store.send(.favoriteSelected(item)) } label: {
                                    Label(AppStrings.Common.watchNow, systemImage: "play.fill")
                                }
                                Button(role: .destructive) { store.send(.deleteFavorite(item)) } label: {
                                    Label(AppStrings.Common.removeFromFavorites, systemImage: "trash")
                                }
                            }
                        }
                    }
                }
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
                                        store.favoriteIDs.contains(FavoriteIdentity(type: "live", playlistID: store.activePlaylistID, id: channel.id))
                                            ? AppStrings.Common.removeFromFavorites : AppStrings.Common.addToFavorites,
                                        systemImage: store.favoriteIDs.contains(FavoriteIdentity(type: "live", playlistID: store.activePlaylistID, id: channel.id)) ? "heart.slash" : "heart"
                                    )
                                }
                                Button { store.send(.channelSelected(channel)) } label: {
                                    Label(AppStrings.Common.watchNow, systemImage: "play.fill")
                                }
                            }
                        }
                    }
                }
            case .sportsHub:
                if store.isSportsHubVisible, !store.epgEvents.isEmpty {
                    TVShelfSection(title: AppStrings.Dashboard.epgPrograms) {
                        ForEach(store.epgEvents) { event in
                            DashboardEPGEventCard(event: event) { store.send(.channelSelected($0)) }
                                .frame(width: 380)
                        }
                    }
                }
            case .recommendations:
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
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.76))
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
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.76))
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
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.76))
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
                                TVVODCard(vod: entry.item, isSelected: false) { store.send(.vodSelected(entry.item)) }.frame(width: 220)
                                Text(String(format: AppStrings.Dashboard.awardRecognitionCount, entry.recognitionCount))
                                    .font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.76)).lineLimit(1)
                            }
                        }
                    }
                }
                if !store.awardNomineeMovies.isEmpty {
                    TVShelfSection(title: AppStrings.Dashboard.awardNomineeMovies) {
                        ForEach(store.awardNomineeMovies) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                TVVODCard(vod: entry.item, isSelected: false) { store.send(.vodSelected(entry.item)) }.frame(width: 220)
                                Text(String(format: AppStrings.Dashboard.awardNominationCount, entry.recognitionCount))
                                    .font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.76)).lineLimit(1)
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
                                    AsyncImage(url: actor.profilePath.flatMap {
                                        URL(string: "https://image.tmdb.org/t/p/w185\($0)")
                                    }) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Text(String(actor.name.prefix(1)))
                                            .font(.largeTitle.bold())
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(Color.white.opacity(0.14))
                                    }
                                    .frame(width: 132, height: 132)
                                    .clipShape(Circle())

                                    Text(actor.name)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .frame(width: 160, height: 48, alignment: .top)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.card)
                            .accessibilityLabel(Text(actor.name))
                        }
                    }
                }
                if store.isLoadingActorFilmography {
                    ProgressView(AppStrings.Common.loading)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                }
                if store.hasLoadedSelectedActorFilmography, store.selectedActorCollections.isEmpty {
                    Text(AppStrings.Dashboard.actorFilmographyUnavailable)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))
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
                                                store.favoriteIDs.contains(FavoriteIdentity(type: "vod", playlistID: store.activePlaylistID, id: vod.id))
                                                    ? AppStrings.Common.removeFromFavorites : AppStrings.Common.addToFavorites,
                                                systemImage: store.favoriteIDs.contains(FavoriteIdentity(type: "vod", playlistID: store.activePlaylistID, id: vod.id)) ? "heart.slash" : "heart"
                                            )
                                        }
                                        Button { store.send(.vodSelected(vod)) } label: {
                                            Label("Detayları Gör", systemImage: "info.circle")
                                        }
                                    }
                                if let reason = store.recommendationReasons[vod.id] {
                                    Text(reason.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.78))
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 220, alignment: .leading)
                        }
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
            case .recentlyAddedVOD:
                if !newMovieItems.isEmpty {
                    TVShelfSection(title: AppStrings.Dashboard.newMovies) {
                        ForEach(newMovieItems) { vod in
                            TVVODCard(vod: vod, isSelected: false) { store.send(.vodSelected(vod)) }
                                .frame(width: 220)
                                .contextMenu {
                                    Button { store.send(.toggleFavorite(item: vod, type: "vod")) } label: {
                                        Label(
                                            store.favoriteIDs.contains(FavoriteIdentity(type: "vod", playlistID: store.activePlaylistID, id: vod.id))
                                                ? AppStrings.Common.removeFromFavorites : AppStrings.Common.addToFavorites,
                                            systemImage: store.favoriteIDs.contains(FavoriteIdentity(type: "vod", playlistID: store.activePlaylistID, id: vod.id)) ? "heart.slash" : "heart"
                                        )
                                    }
                                    Button { store.send(.vodSelected(vod)) } label: {
                                        Label("Detayları Gör", systemImage: "info.circle")
                                    }
                                }
                        }
                    }
                }
            case .trendingSeries:
                if !store.featuredSeries.isEmpty {
                    TVShelfSection(title: AppStrings.Dashboard.newSeries) {
                        ForEach(store.featuredSeries) { series in
                            TVSeriesCard(series: series, isSelected: false) { store.send(.seriesSelected(series)) }
                                .frame(width: 220)
                                .contextMenu {
                                    Button { store.send(.toggleFavorite(item: series, type: "series")) } label: {
                                        Label(
                                            store.favoriteIDs.contains(FavoriteIdentity(type: "series", playlistID: store.activePlaylistID, id: series.id))
                                                ? AppStrings.Common.removeFromFavorites : AppStrings.Common.addToFavorites,
                                            systemImage: store.favoriteIDs.contains(FavoriteIdentity(type: "series", playlistID: store.activePlaylistID, id: series.id)) ? "heart.slash" : "heart"
                                        )
                                    }
                                    Button { store.send(.seriesSelected(series)) } label: {
                                        Label("Bölümleri Gör", systemImage: "list.number")
                                    }
                                }
                        }
                    }
                }
            case .discoverCollections:
                ForEach(store.visibleExploreCollections) { collection in
                    homeCategorySection(collection)
                }
            }
        }

        private func homeCategorySection(_ collection: DashboardFeature.ExploreCollection) -> some View {
            let isPinned = store.pinnedHomeCategoryIDs.contains(collection.id)
            let canPin = collection.id.hasPrefix("live-category:") || collection.id.hasPrefix("movie-category:") || collection.id.hasPrefix("series-category:")
            return VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 18) {
                    Text(collection.title)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                    if canPin {
                        Button {
                            store.send(.toggleHomeCategoryPin(collection.id))
                        } label: {
                            Label(
                                isPinned ? AppStrings.Dashboard.unpinHomeCategory : AppStrings.Dashboard.pinHomeCategory,
                                systemImage: isPinned ? "pin.slash.fill" : "pin.fill"
                            )
                        }
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
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
                .padding(.horizontal, 60)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 40) {
                        ForEach(collection.items) { item in
                            if item.type == .live {
                                TVChannelCard(channel: item, isSelected: false) { store.send(.channelSelected(item)) }
                                    .frame(width: 340)
                            } else if item.type == .series {
                                TVSeriesCard(series: item, isSelected: false) { store.send(.seriesSelected(item)) }
                                    .frame(width: 220)
                            } else {
                                TVVODCard(vod: item, isSelected: false) { store.send(.vodSelected(item)) }
                                    .frame(width: 220)
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 40)
                }
                .focusSection()
                .focusGuideBoundary()
            }
        }

        private var tvLoadingView: some View {
            PureLoadingView(size: .large, text: AppStrings.Common.loadingAlt)
                .transition(.opacity)
        }
    }

    // MARK: - TV Hero Banner

    private struct TVHeroBanner: View {
        let vod: MediaModels.Item
        let onTap: () -> Void

        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Button(action: onTap) {
                ZStack(alignment: .bottomLeading) {
                    if let url = vod.coverURL {
                        KFImage.url(url, cacheKey: PlaylistArtworkRequest.cacheKey(for: url, userAgentOverride: vod.userAgentOverride))
                            .requestModifier { request in
                                UserAgentManager.applyHeaders(to: &request, override: vod.userAgentOverride)
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 600)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(hex: "#1F1F23"))
                            .frame(height: 600)
                    }

                    // Premium Gradient
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.0), location: 0.0),
                            .init(color: .black.opacity(0.5), location: 0.6),
                            .init(color: .black.opacity(0.95), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Content
                    VStack(alignment: .leading, spacing: 16) {
                        Text(vod.title)
                            .font(.system(size: 52, weight: .bold))
                            .tracking(-1.0) // Optical sizing fix for tvOS large text
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)

                        if let rating = vod.rating, rating > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill").foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                            }
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                            Text(AppStrings.Common.watchNow)
                        }
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                    }
                    .padding(60)
                }
            }
            .buttonStyle(.card)
        }
    }

    // MARK: - TV Shelf Section

    private struct TVShelfSection<Content: View>: View {
        let title: String
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.system(size: 38, weight: .bold)) // 10-foot UI size
                    .foregroundStyle(.white)
                    .padding(.horizontal, 60)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 40) {
                        content()
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 40)
                }
                .focusSection()
                .focusGuideBoundary()
            }
        }
    }

    // MARK: - TV Watch History Card

    private struct TVWatchHistoryCard: View {
        let item: WatchHistoryItem
        let userAgentOverride: String?
        let onTap: () -> Void

        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack(alignment: .bottomLeading) {
                        if let urlString = item.coverURL, let url = URL(string: urlString) {
                            KFImage.url(url, cacheKey: PlaylistArtworkRequest.cacheKey(for: url, userAgentOverride: userAgentOverride))
                                .requestModifier { request in
                                    UserAgentManager.applyHeaders(to: &request, override: userAgentOverride)
                                }
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 320, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(hex: "#1F1F23"))
                                .frame(width: 320, height: 180)
                        }

                        // Progress bar
                        let progressPercent = item.duration > 0 ? max(0, min(1, item.progress / item.duration)) : 0
                        VStack {
                            Spacer()
                            GeometryReader { proxy in
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
                    }

                    Text(item.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(width: 320, alignment: .leading)

                    if let seriesTitle = item.seriesTitle {
                        Text(seriesTitle)
                            .font(.system(size: 16))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .lineLimit(1)
                            .frame(width: 320, alignment: .leading)
                    }
                }
            }
            .buttonStyle(.card)
        }
    }

#endif
