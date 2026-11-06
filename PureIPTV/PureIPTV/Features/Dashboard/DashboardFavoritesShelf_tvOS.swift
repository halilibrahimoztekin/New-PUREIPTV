#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS Dashboard Favorites Shelf Section

    /// Modular shelf component for favorite channels, movies, and series on tvOS.
    /// Supports Siri Remote long-press context menus for TV remote reordering and instant playback.
    public struct DashboardFavoritesShelf_tvOS: View {
        public let store: StoreOf<DashboardFeature>
        public let config: PlaylistConfig

        public init(store: StoreOf<DashboardFeature>, config: PlaylistConfig) {
            self.store = store
            self.config = config
        }

        public var body: some View {
            let favorites = store.favoriteItemsByType
            let availability = store.favoriteMoveAvailability

            VStack(alignment: .leading, spacing: 50) {
                if let items = favorites["live"], !items.isEmpty {
                    shelfSection(items, title: AppStrings.Dashboard.favoriteLiveTV, cardWidth: 340, moveAvailability: availability)
                }

                if let items = favorites["vod"], !items.isEmpty {
                    shelfSection(items, title: AppStrings.Dashboard.favoriteMovies, cardWidth: 220, moveAvailability: availability)
                }

                if let items = favorites["series"], !items.isEmpty {
                    favoriteSeriesShelf(items, moveAvailability: availability)
                }

                let categorizedTypes = Set(["live", "vod", "series"])
                let otherFavorites = favorites.filter { !categorizedTypes.contains($0.key) }.values.flatMap(\.self)
                if !otherFavorites.isEmpty {
                    shelfSection(otherFavorites, title: AppStrings.Dashboard.myFavorites, cardWidth: 220, moveAvailability: availability)
                }
            }
        }

        // MARK: - Generic Shelf Section

        private func shelfSection(
            _ items: [FavoriteItem],
            title: String,
            cardWidth: CGFloat,
            moveAvailability: [FavoriteIdentity: Set<Int>]
        ) -> some View {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(AppFonts.displayMedium)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 60)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 40) {
                        ForEach(items, id: \.scopedIdentity) { item in
                            favoriteMediaCard(item, cardWidth: cardWidth, moveOffsets: moveAvailability[item.scopedIdentity] ?? [])
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 40)
                }
                .focusSection()
                .focusEffectDisabled()
            }
        }

        // MARK: - Series Shelf with Sort Menu

        private func favoriteSeriesShelf(
            _ items: [FavoriteItem],
            moveAvailability: [FavoriteIdentity: Set<Int>]
        ) -> some View {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 28) {
                    Text(AppStrings.Dashboard.favoriteSeries)
                        .font(AppFonts.displayMedium)
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer(minLength: 12)

                    favoriteSeriesSortMenu
                }
                .padding(.horizontal, 60)

                if store.favoriteSeriesSortDidFail {
                    Text(AppStrings.Dashboard.favoriteSeriesDatesLoadFailed)
                        .font(AppFonts.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 60)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 40) {
                        ForEach(items, id: \.scopedIdentity) { item in
                            favoriteMediaCard(item, cardWidth: 220, moveOffsets: moveAvailability[item.scopedIdentity] ?? [])
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 40)
                }
                .focusSection()
                .focusEffectDisabled()
            }
        }

        // MARK: - Series Sort Menu

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
                .font(AppFonts.titleSmall)
            }
            .buttonStyle(.bordered)
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

        // MARK: - Favorite Media Card with Context Menu

        private func favoriteMediaCard(_ item: FavoriteItem, cardWidth: CGFloat, moveOffsets: Set<Int>) -> some View {
            let mediaType = item.type.lowercased()
            let canReorder = mediaType == "vod"
                || (mediaType == "series" && store.favoriteSeriesSortMode != .newestEpisode)

            return TVFavoriteMediaCard(
                item: item,
                userAgentOverride: config.userAgentOverride,
                unwatchedEpisodeCount: item.playlistID == store.activePlaylistID
                    ? store.favoriteSeriesUnwatchedEpisodeCounts[item.id]
                    : nil
            ) {
                store.send(.favoriteSelected(item))
            }
            .frame(width: cardWidth)
            .contextMenu {
                if canReorder, item.playlistID != nil {
                    Button { store.send(.moveFavorite(item, offset: -1)) } label: {
                        Label(AppStrings.Favorites.moveUp, systemImage: "arrow.left")
                    }
                    .disabled(!moveOffsets.contains(-1))

                    Button { store.send(.moveFavorite(item, offset: 1)) } label: {
                        Label(AppStrings.Favorites.moveDown, systemImage: "arrow.right")
                    }
                    .disabled(!moveOffsets.contains(1))
                }
                Button { store.send(.favoriteSelected(item)) } label: {
                    Label(AppStrings.Common.watchNow, systemImage: "play.fill")
                }
                Button(role: .destructive) { store.send(.deleteFavorite(item)) } label: {
                    Label(AppStrings.Common.removeFromFavorites, systemImage: "trash")
                }
            }
        }
    }
#endif
