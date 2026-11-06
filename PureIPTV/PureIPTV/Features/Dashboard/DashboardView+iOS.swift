#if os(iOS)
    import ComposableArchitecture
    import FactoryKit
    import SwiftUI

    // MARK: - Dashboard View (iOS)

    // Decomposed into dedicated, isolated subviews with narrow invalidation boundaries

    public struct DashboardView_iOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        let config: PlaylistConfig
        let onSearch: (() -> Void)?

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
                AppColors.oledBlack.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Top Header Bar with Liquid Glass actions
                        DashboardHeaderBar_iOS(store: store, config: config, onSearch: onSearch)

                        if !store.catalogCountChanges.isEmpty {
                            DashboardCatalogCountSummaryView(
                                changes: store.catalogCountChanges,
                                onDismiss: { store.send(.dismissCatalogCountSummary) }
                            )
                            .padding(.horizontal, 16)
                        }

                        if let error = store.errorMessage {
                            errorBanner(error)
                        }

                        ForEach(store.homeSections.filter(\.isVisible)) { section in
                            homeSectionView(section)
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
            .onAppear {
                store.send(.onAppear(config: config))
            }
            .onDisappear {
                store.send(.onDisappear)
            }
        }

        private func errorBanner(_ error: String) -> some View {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColors.warning)
                Text(error)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.textPrimary)
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

        @ViewBuilder
        private func homeSectionView(_ section: HomeSectionConfig) -> some View {
            switch section.type {
            case .hero:
                if let heroVOD = store.featuredVODs.first {
                    DashboardHeroBannerView_iOS(vod: heroVOD) {
                        store.send(.vodSelected(heroVOD))
                    }
                    .padding(.bottom, 8)
                } else if store.loadingPrimaryCatalogs.contains(.movies) {
                    heroLoadingPlaceholder
                }
            case .continueWatching:
                let continueWatching = store.continueWatchingItems
                if !continueWatching.isEmpty {
                    continueWatchingSection(continueWatching)
                }
            case .favorites:
                DashboardFavoritesSection_iOS(store: store, config: config)
            case .featuredLiveTV:
                if !store.featuredChannels.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.featuredLiveTV, items: store.featuredChannels) { channel in
                        ChannelCardView(channel: channel, isSelected: false) { store.send(.channelSelected(channel)) }
                            .frame(width: 240)
                    }
                } else if store.loadingPrimaryCatalogs.contains(.live) {
                    catalogLoadingShelf(title: AppStrings.Dashboard.featuredLiveTV, cardWidth: 240, cardHeight: 135)
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
                    DashboardSportsHubSection_iOS(store: store)
                }
            case .recommendations:
                DashboardRecommendationsSection_iOS(store: store)
            case .recentlyAddedVOD:
                let isHeroVisible = store.homeSections.contains { $0.type == .hero && $0.isVisible }
                let newMovieItems = Array(store.featuredVODs.dropFirst(isHeroVisible ? 1 : 0))
                if !newMovieItems.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.newMovies, items: newMovieItems) { vod in
                        VODCardView(vod: vod, isSelected: false) { store.send(.vodSelected(vod)) }
                            .frame(width: 140)
                    }
                } else if store.loadingPrimaryCatalogs.contains(.movies) {
                    catalogLoadingShelf(title: AppStrings.Dashboard.newMovies, cardWidth: 140, cardHeight: 210)
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
                } else if store.loadingPrimaryCatalogs.contains(.series) {
                    catalogLoadingShelf(title: AppStrings.Dashboard.newSeries, cardWidth: 140, cardHeight: 210)
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
            } else if !hasContent,
                      store.activeRefreshID != nil,
                      !store.isLoading,
                      !store.loadingPrimaryCatalogs.contains(catalog)
            {
                ProgressView(AppStrings.Common.loading)
                    .tint(AppColors.textPrimary)
                    .foregroundStyle(AppColors.textPrimary)
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
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.textPrimary)
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
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.textPrimary)
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

        private func continueWatchingSection(_ items: [WatchHistoryItem]) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(AppStrings.Dashboard.continueWatching)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.textPrimary)
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

        private var heroLoadingPlaceholder: some View {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(AppColors.surfaceSecondary)
                .overlay {
                    LinearGradient(
                        colors: [.clear, AppColors.oledBlack.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(maxWidth: .infinity)
                .frame(height: 520)
                .shimmeringPlaceholder(isLoading: true)
                .padding(.bottom, 8)
                .accessibilityLabel(AppStrings.Common.loading)
        }

        private func catalogLoadingShelf(title: String, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(0 ..< 5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppColors.surfaceSecondary)
                                .frame(width: cardWidth, height: cardHeight)
                                .shimmeringPlaceholder(isLoading: true)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Dashboard Header Bar (Dedicated Subview for Narrow Invalidation Boundary)

    struct DashboardHeaderBar_iOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        let config: PlaylistConfig
        let onSearch: (() -> Void)?

        var body: some View {
            VStack(spacing: 10) {
                // Row 1: Title + Action Icons
                HStack(spacing: 6) {
                    Text(AppStrings.Dashboard.title)
                        .font(AppFonts.headline)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(2)

                    Spacer(minLength: 8)

                    LiquidGlassContainer(spacing: 6) {
                        HStack(spacing: 6) {
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
                                            .lineLimit(1)
                                    } else {
                                        Text(AppStrings.Common.retry)
                                            .lineLimit(1)
                                    }
                                }
                                .font(AppFonts.captionSemibold)
                                .foregroundStyle(AppColors.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                            }
                            .liquidGlass(shape: .capsule, isInteractive: true)
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
                            }
                            .liquidGlass(shape: .circle, isInteractive: true)
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
                            }
                            .liquidGlass(shape: .circle, isInteractive: true)
                            .buttonStyle(.plain)
                            .accessibilityLabel("Ana Ekranı Düzenle")

                            if let onSearch {
                                Button(action: onSearch) {
                                    Image(systemName: "magnifyingglass")
                                        .font(AppFonts.titleSmall)
                                        .foregroundStyle(AppColors.primary)
                                        .frame(width: 34, height: 34)
                                }
                                .liquidGlass(shape: .circle, isInteractive: true)
                                .buttonStyle(.plain)
                                .accessibilityLabel(AppStrings.Search.searchPlaceholder)
                            }
                        }
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
                    }
                    .liquidGlass(shape: .capsule, isInteractive: true)
                    .buttonStyle(.plain)

                    Spacer(minLength: 8)

                    VPNStatusBadge(compact: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
#endif
