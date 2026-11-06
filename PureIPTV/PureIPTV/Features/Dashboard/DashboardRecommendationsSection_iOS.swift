#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Dashboard Recommendations & Discoveries (iOS)

    public struct DashboardRecommendationsSection_iOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        @Environment(\.displayScale) private var displayScale

        public init(store: StoreOf<DashboardFeature>) {
            self.store = store
        }

        public var body: some View {
            // The dashboard already owns vertical laziness. A nested LazyVStack
            // makes the outer stack estimate this section's height while its
            // conditional shelves arrive asynchronously; use a regular VStack
            // for stable row geometry. Each shelf still lazily creates its cards
            // through its horizontal LazyHStack.
            VStack(spacing: 24) {
                localPersonalizationShelf
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
        }

        private var localPersonalizationShelf: some View {
            Group {
                if !store.recommendedVODs.isEmpty {
                    featuredShelf(title: AppStrings.Dashboard.recommendedForYou, items: store.recommendedVODs) { vod in
                        VStack(alignment: .leading, spacing: 6) {
                            VODCardView(vod: vod, isSelected: false) { store.send(.vodSelected(vod)) }
                            if let reason = store.recommendationReasons[vod.id] {
                                Text(reason.title)
                                    .font(AppFonts.captionSmall.weight(.medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .lineLimit(1)
                                    .frame(height: 14, alignment: .leading)
                            } else {
                                Color.clear
                                    .frame(height: 14)
                            }
                        }
                        .frame(width: 140, alignment: .leading)
                    }
                } else if store.isPersonalizationEnabled,
                          !store.hasPersonalizedContent,
                          store.isLoadingPersonalizedContent || !store.hasLoadedLocalData
                {
                    personalizationLoadingShelf
                } else if store.isPersonalizationEnabled,
                          !store.hasPersonalizedContent,
                          store.hasLoadedRemoteData
                {
                    resolvedEmptyPersonalizationShelf(canRetry: true)
                } else if store.isPersonalizationEnabled,
                          store.hasLoadedLocalData,
                          store.hasPersonalizedContent
                {
                    // Keep the loading shelf's footprint when secondary shelves
                    // exist but local movie recommendations resolved empty. If we
                    // remove it here, every following shelf jumps up by ~230 pt.
                    resolvedEmptyPersonalizationShelf(canRetry: false)
                }
            }
            .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                guard isVisible else { return }
                store.send(.recommendationsSectionBecameVisible)
            }
        }

        private func resolvedEmptyPersonalizationShelf(canRetry: Bool) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(AppStrings.Dashboard.recommendedForYou)
                    .font(AppFonts.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 16)

                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(AppFonts.titleMedium)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(AppStrings.Dashboard.noPersonalizedMovies)
                        .font(AppFonts.bodySmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    if canRetry {
                        Button {
                            store.send(.retryPersonalizationTapped)
                        } label: {
                            Label(AppStrings.Common.retry, systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            store.activeRefreshID != nil
                                || store.isLoadingPersonalizedContent
                                || !store.hasLoadedLocalData
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                // Match the poster + reason height used by the loading shelf so
                // resolving to an empty local result doesn't shift later rows.
                .frame(height: 230)
                .padding(.horizontal, 16)
            }
        }

        private var personalizationLoadingShelf: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(AppStrings.Dashboard.recommendedForYou)
                    .font(AppFonts.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(0 ..< 5, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppColors.surfaceSecondary)
                                    .frame(width: 140, height: 210)
                                    .shimmeringPlaceholder(isLoading: true)

                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(AppColors.surfaceSecondary)
                                    .frame(width: 88, height: 14)
                                    .shimmeringPlaceholder(isLoading: true)
                            }
                            .frame(width: 140, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 16)
                }
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
                                    PlaylistAsyncImage(
                                        url: actor.profilePath.flatMap { TMDBImageURL.make(path: $0, size: .w185) },
                                        userAgentOverride: nil,
                                        downsamplingSize: CGSize(width: 82 * displayScale, height: 82 * displayScale)
                                    ) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            Text(String(actor.name.prefix(1)))
                                                .font(AppFonts.headline)
                                                .foregroundStyle(AppColors.textPrimary)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .background(Color.white.opacity(0.14))
                                        }
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
