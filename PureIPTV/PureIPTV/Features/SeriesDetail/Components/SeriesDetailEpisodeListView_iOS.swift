#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SeriesDetailEpisodeListView_iOS: View {
        let store: StoreOf<SeriesDetailFeature>

        public init(store: StoreOf<SeriesDetailFeature>) {
            self.store = store
        }

        private var episodeSortMenu: some View {
            Menu {
                Section(AppStrings.Settings.contentSorting) {
                    Button {
                        store.send(.episodeSortOrderSelected(.oldestFirst))
                    } label: {
                        if store.episodeSortOrder == .oldestFirst {
                            Label(AppStrings.SeriesDetail.oldestEpisodesFirst, systemImage: "checkmark")
                        } else {
                            Text(AppStrings.SeriesDetail.oldestEpisodesFirst)
                        }
                    }

                    Button {
                        store.send(.episodeSortOrderSelected(.newestFirst))
                    } label: {
                        if store.episodeSortOrder == .newestFirst {
                            Label(AppStrings.SeriesDetail.newestEpisodesFirst, systemImage: "checkmark")
                        } else {
                            Text(AppStrings.SeriesDetail.newestEpisodesFirst)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(AppFonts.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .liquidGlass(shape: .circle, isInteractive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppStrings.Settings.contentSorting)
            .accessibilityValue(store.episodeSortOrder.title)
        }

        public var body: some View {
            if !store.currentEpisodes.isEmpty || store.canShuffleSeries {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(AppStrings.SeriesDetail.episodes)
                            .font(AppFonts.titleLarge)
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()

                        if !store.currentEpisodes.isEmpty {
                            Text("\(store.currentEpisodes.count) \(AppStrings.SeriesDetail.episodeCount)")
                                .font(AppFonts.captionMedium)
                                .foregroundStyle(AppColors.textTertiary)

                            episodeSortMenu
                        }

                        if store.canShuffleEpisodes {
                            Menu {
                                if store.canShuffleSelectedSeason {
                                    Button {
                                        store.send(.shuffleEpisodesTapped(.selectedSeason))
                                    } label: {
                                        Label(AppStrings.SeriesDetail.shuffleSeason, systemImage: "shuffle")
                                    }
                                }

                                if store.canShuffleSeries {
                                    Button {
                                        store.send(.shuffleEpisodesTapped(.series))
                                    } label: {
                                        Label(AppStrings.SeriesDetail.shuffleSeries, systemImage: "shuffle")
                                    }
                                }
                            } label: {
                                Image(systemName: "shuffle")
                                    .font(AppFonts.caption.weight(.semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                    .padding(8)
                                    .liquidGlass(shape: .circle, isInteractive: true)
                            }
                            .accessibilityLabel(AppStrings.SeriesDetail.shuffleEpisodes)
                        }

                        if !store.currentEpisodes.isEmpty {
                            // Layout Toggle Button (List vs Grid)
                            Button {
                                HapticManager.shared.trigger(.light)
                                store.send(.toggleLayoutMode)
                            } label: {
                                Image(systemName: store.episodeLayoutMode == .list ? "square.grid.2x2" : "rectangle.grid.1x2")
                                    .font(AppFonts.caption.weight(.semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                    .padding(8)
                                    .liquidGlass(shape: .circle, isInteractive: true)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    if store.episodeLayoutMode == .list {
                        LazyVStack(spacing: 12) {
                            ForEach(store.displayEpisodes) { episode in
                                EpisodeCardView(
                                    episode: episode,
                                    userAgentOverride: store.config.userAgentOverride,
                                    playlistID: store.config.playlistID,
                                    progressItem: store.episodeProgressMap[episode.id],
                                    isDownloaded: store.downloadedEpisodes[episode.id] == true,
                                    isDeleting: store.deletingEpisodeIDs.contains(episode.id),
                                    layoutMode: .list,
                                    onPlay: {
                                        store.send(.episodeSelected(episode))
                                    },
                                    onDownload: {
                                        store.send(.downloadEpisode(episode))
                                    },
                                    onMarkUnwatched: {
                                        store.send(.markEpisodeUnwatched(episode.id))
                                    }
                                )
                                .id(episode.id)
                            }
                        }
                        .padding(.horizontal, 24)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14),
                            ],
                            spacing: 14
                        ) {
                            ForEach(store.displayEpisodes) { episode in
                                EpisodeCardView(
                                    episode: episode,
                                    userAgentOverride: store.config.userAgentOverride,
                                    playlistID: store.config.playlistID,
                                    progressItem: store.episodeProgressMap[episode.id],
                                    isDownloaded: store.downloadedEpisodes[episode.id] == true,
                                    isDeleting: store.deletingEpisodeIDs.contains(episode.id),
                                    layoutMode: .grid,
                                    onPlay: {
                                        store.send(.episodeSelected(episode))
                                    },
                                    onDownload: {
                                        store.send(.downloadEpisode(episode))
                                    },
                                    onMarkUnwatched: {
                                        store.send(.markEpisodeUnwatched(episode.id))
                                    }
                                )
                                .id(episode.id)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            } else if store.isLoading {
                VStack(alignment: .leading, spacing: 16) {
                    Text(AppStrings.SeriesDetail.episodes)
                        .font(AppFonts.titleLarge)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        ForEach(0 ..< 3, id: \.self) { _ in
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.borderMedium)
                                    .frame(width: 130, height: 75)
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 4).fill(AppColors.borderMedium).frame(height: 16)
                                    RoundedRectangle(cornerRadius: 4).fill(AppColors.borderMedium).frame(width: 120, height: 12)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(AppColors.surfaceTertiary, in: RoundedRectangle(cornerRadius: 14))
                            .shimmeringPlaceholder(isLoading: true)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
#endif
