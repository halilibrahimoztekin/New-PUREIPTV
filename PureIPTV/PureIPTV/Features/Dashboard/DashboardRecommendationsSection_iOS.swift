#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Dashboard Recommendations & Discoveries (iOS)

    public struct DashboardRecommendationsSection_iOS: View {
        @Bindable var store: StoreOf<DashboardFeature>

        public init(store: StoreOf<DashboardFeature>) {
            self.store = store
        }

        public var body: some View {
            VStack(spacing: 24) {
                if !store.newEpisodeSeries.isEmpty {
                    newEpisodeDiscoverySection
                }
                if !store.mostRatedMovies.isEmpty {
                    featuredShelf(title: AppStrings.Dashboard.mostRatedMovies, items: store.mostRatedMovies) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            VODCardView(vod: entry.item, isSelected: false) {
                                store.send(.vodSelected(entry.item))
                            }
                            Text(String(format: AppStrings.Dashboard.mostVotesSummary, entry.voteCount, entry.voteAverage))
                                .font(AppFonts.captionSmall.weight(.medium))
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                }
                if !store.highestRatedMovies.isEmpty {
                    featuredShelf(title: AppStrings.Dashboard.highestRatedMovies, items: store.highestRatedMovies) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            VODCardView(vod: entry.item, isSelected: false) {
                                store.send(.vodSelected(entry.item))
                            }
                            Text(String(format: AppStrings.Dashboard.ratingVotesSummary, entry.voteAverage, entry.voteCount))
                                .font(AppFonts.captionSmall.weight(.medium))
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                }
                if !store.awardWinningMovies.isEmpty {
                    featuredShelf(title: AppStrings.Dashboard.awardWinningMovies, items: store.awardWinningMovies) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            VODCardView(vod: entry.item, isSelected: false) { store.send(.vodSelected(entry.item)) }
                            Text(String(format: AppStrings.Dashboard.awardRecognitionCount, entry.recognitionCount))
                                .font(AppFonts.captionSmall.weight(.medium))
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                }
                if !store.awardNomineeMovies.isEmpty {
                    featuredShelf(title: AppStrings.Dashboard.awardNomineeMovies, items: store.awardNomineeMovies) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            VODCardView(vod: entry.item, isSelected: false) { store.send(.vodSelected(entry.item)) }
                            Text(String(format: AppStrings.Dashboard.awardNominationCount, entry.recognitionCount))
                                .font(AppFonts.captionSmall.weight(.medium))
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                }
                if !store.mostWatchedActors.isEmpty {
                    actorDiscoverySection
                }
                if store.isLoadingActorFilmography {
                    ProgressView(AppStrings.Common.loading)
                        .tint(AppColors.textPrimary)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }
                if !store.recommendedVODs.isEmpty {
                    featuredShelf(title: AppStrings.Dashboard.recommendedForYou, items: store.recommendedVODs) { vod in
                        VStack(alignment: .leading, spacing: 6) {
                            VODCardView(vod: vod, isSelected: false) { store.send(.vodSelected(vod)) }
                            if let reason = store.recommendationReasons[vod.id] {
                                Text(reason.title)
                                    .font(AppFonts.captionSmall.weight(.medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                }
                if store.isPersonalizationEnabled, !store.hasPersonalizedContent {
                    if store.isLoadingPersonalizedContent {
                        ProgressView(AppStrings.Common.loading)
                            .tint(AppColors.textPrimary)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    } else if store.hasLoadedRemoteData {
                        HStack(spacing: 12) {
                            Label(AppStrings.Dashboard.recommendedForYou, systemImage: "sparkles")
                                .foregroundStyle(AppColors.textSecondary)
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
                    featuredShelf(title: title, items: collection.items) { item in
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
                    featuredShelf(title: title, items: collection.items) { item in
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
                        .font(AppFonts.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 16)
                }
            }
            .onScrollVisibilityChange(threshold: 0.5) { isVisible in
                guard isVisible else { return }
                store.send(.recommendationsSectionBecameVisible)
            }
        }

        private func featuredShelf<T: Identifiable>(
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

        private var actorDiscoverySection: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.mostWatchedActors.first?.source == .popularFallback
                    ? AppStrings.Dashboard.popularActors
                    : AppStrings.Dashboard.mostWatchedActors)
                    .font(AppFonts.headline)
                    .foregroundStyle(AppColors.textPrimary)
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
                                            .font(AppFonts.headline)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(Color.white.opacity(0.14))
                                    }
                                    .frame(width: 82, height: 82)
                                    .clipShape(Circle())

                                    Text(actor.name)
                                        .font(AppFonts.captionSmall.weight(.medium))
                                        .foregroundStyle(AppColors.textPrimary)
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
                    .font(AppFonts.headline)
                    .foregroundStyle(AppColors.textPrimary)
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
                                    .font(AppFonts.captionSmall.weight(.medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .lineLimit(1)
                                    .frame(width: 140, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
#endif
