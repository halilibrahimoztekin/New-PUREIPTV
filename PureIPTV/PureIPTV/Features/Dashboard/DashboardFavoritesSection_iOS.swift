#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Dashboard Favorites Shelf & Sorting (iOS)

    public struct DashboardFavoritesSection_iOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        let config: PlaylistConfig

        public init(store: StoreOf<DashboardFeature>, config: PlaylistConfig) {
            self.store = store
            self.config = config
        }

        public var body: some View {
            let favorites = store.favoriteItemsByType
            let availability = store.favoriteMoveAvailability

            VStack(spacing: 24) {
                if let items = favorites["live"], !items.isEmpty {
                    favoriteShelf(items, title: AppStrings.Dashboard.favoriteLiveTV, moveAvailability: availability)
                }
                if let items = favorites["vod"], !items.isEmpty {
                    favoriteShelf(items, title: AppStrings.Dashboard.favoriteMovies, moveAvailability: availability)
                }
                if let items = favorites["series"], !items.isEmpty {
                    favoriteShelf(items, title: AppStrings.Dashboard.favoriteSeries, showsSeriesSortControl: true, moveAvailability: availability)
                }
                let categorizedTypes = Set(["live", "vod", "series"])
                let otherFavorites = favorites.filter { !categorizedTypes.contains($0.key) }.values.flatMap(\.self)
                if !otherFavorites.isEmpty {
                    favoriteShelf(otherFavorites, title: AppStrings.Dashboard.myFavorites, moveAvailability: availability)
                }
            }
        }

        private func favoriteShelf(
            _ items: [FavoriteItem],
            title: String,
            showsSeriesSortControl: Bool = false,
            moveAvailability: [FavoriteIdentity: Set<Int>]
        ) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text(title)
                        .font(AppFonts.headline)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if showsSeriesSortControl {
                        favoriteSeriesSortMenu
                    }
                }
                .padding(.horizontal, 16)

                if showsSeriesSortControl, store.favoriteSeriesSortDidFail {
                    Text(AppStrings.Dashboard.favoriteSeriesDatesLoadFailed)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.textSecondary)
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
                .font(AppFonts.captionSemibold)
                .foregroundStyle(AppColors.textPrimary)
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
            let card = DashboardFavoriteCardView(
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
    }

    // MARK: - Dashboard Favorite Card View

    public struct DashboardFavoriteCardView: View {
        let item: FavoriteItem
        let userAgentOverride: String?
        var unwatchedEpisodeCount: Int?
        let onTap: () -> Void

        public init(
            item: FavoriteItem,
            userAgentOverride: String?,
            unwatchedEpisodeCount: Int? = nil,
            onTap: @escaping () -> Void
        ) {
            self.item = item
            self.userAgentOverride = userAgentOverride
            self.unwatchedEpisodeCount = unwatchedEpisodeCount
            self.onTap = onTap
        }

        public var body: some View {
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
#endif
