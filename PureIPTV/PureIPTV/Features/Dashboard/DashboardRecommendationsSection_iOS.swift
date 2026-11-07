#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Dashboard Recommendations & Discoveries (iOS)

    public struct DashboardRecommendationsSection_iOS: View {
        public enum Row: Hashable, Identifiable {
            case localPersonalization
            case newEpisodes
            case mostRatedMovies
            case highestRatedMovies
            case awardWinningMovies
            case awardNomineeMovies
            case mostWatchedActors
            case actorRecommendation(String)
            case selectedActorRecommendation(String)
            case selectedActorFilmographyLoading
            case selectedActorFilmographyEmpty

            public var id: String {
                switch self {
                case .localPersonalization: "local-personalization"
                case .newEpisodes: "new-episodes"
                case .mostRatedMovies: "most-rated-movies"
                case .highestRatedMovies: "highest-rated-movies"
                case .awardWinningMovies: "award-winning-movies"
                case .awardNomineeMovies: "award-nominee-movies"
                case .mostWatchedActors: "most-watched-actors"
                case let .actorRecommendation(id): "actor-recommendation-\(id)"
                case let .selectedActorRecommendation(id): "selected-actor-recommendation-\(id)"
                case .selectedActorFilmographyLoading: "selected-actor-filmography-loading"
                case .selectedActorFilmographyEmpty: "selected-actor-filmography-empty"
                }
            }
        }

        @Bindable var store: StoreOf<DashboardFeature>
        let row: Row
        @Environment(\.displayScale) private var displayScale

        public init(store: StoreOf<DashboardFeature>, row: Row) {
            self.store = store
            self.row = row
        }

        public static func rows(
            hasNewEpisodes: Bool,
            hasMostRatedMovies: Bool,
            hasHighestRatedMovies: Bool,
            hasAwardWinningMovies: Bool,
            hasAwardNomineeMovies: Bool,
            hasMostWatchedActors: Bool,
            actorRecommendationIDs: [String],
            selectedActorRecommendationIDs: [String],
            isLoadingActorFilmography: Bool,
            hasLoadedSelectedActorFilmography: Bool
        ) -> [Row] {
            var rows: [Row] = [.localPersonalization]
            if hasNewEpisodes {
                rows.append(.newEpisodes)
            }
            if hasMostRatedMovies {
                rows.append(.mostRatedMovies)
            }
            if hasHighestRatedMovies {
                rows.append(.highestRatedMovies)
            }
            if hasAwardWinningMovies {
                rows.append(.awardWinningMovies)
            }
            if hasAwardNomineeMovies {
                rows.append(.awardNomineeMovies)
            }
            if hasMostWatchedActors {
                rows.append(.mostWatchedActors)
            }
            rows.append(contentsOf: actorRecommendationIDs.map(Row.actorRecommendation))
            rows.append(contentsOf: selectedActorRecommendationIDs.map(Row.selectedActorRecommendation))
            if isLoadingActorFilmography {
                rows.append(.selectedActorFilmographyLoading)
            }
            if hasLoadedSelectedActorFilmography, selectedActorRecommendationIDs.isEmpty {
                rows.append(.selectedActorFilmographyEmpty)
            }
            return rows
        }

        public var body: some View {
            switch row {
            case .localPersonalization:
                localPersonalizationShelf
            case .newEpisodes:
                newEpisodeDiscoverySection
            case .mostRatedMovies:
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
            case .highestRatedMovies:
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
            case .awardWinningMovies:
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
            case .awardNomineeMovies:
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
            case .mostWatchedActors:
                actorDiscoverySection
            case let .actorRecommendation(id):
                if let collection = store.actorRecommendationCollections.first(where: { $0.id == id }) {
                    actorRecommendationShelf(collection, title: String(
                        format: AppStrings.Dashboard.actorRecommendationTitle,
                        collection.actorName,
                        collection.sourceTitle,
                        collection.kind.title
                    ))
                }
            case let .selectedActorRecommendation(id):
                if let collection = store.selectedActorCollections.first(where: { $0.id == id }) {
                    actorRecommendationShelf(
                        collection,
                        title: "\(store.selectedActorName ?? collection.actorName) • \(collection.kind.title)"
                    )
                }
            case .selectedActorFilmographyLoading:
                ProgressView(AppStrings.Common.loading)
                    .tint(AppColors.textPrimary)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            case .selectedActorFilmographyEmpty:
                Text(AppStrings.Dashboard.actorFilmographyUnavailable)
                    .font(AppFonts.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 16)
            }
        }

        private func actorRecommendationShelf(
            _ collection: ActorRecommendationEngine.Collection,
            title: String
        ) -> some View {
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

        private var localPersonalizationShelf: some View {
            VStack(spacing: 0) {
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
                if store.hasStartedPersonalizationForCurrentData,
                   !store.isLoadingPersonalizedContent || store.hasEnteredPersonalizationDiscoverySection
                {
                    Color.clear
                        .frame(height: 1)
                        .accessibilityHidden(true)
                        .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                            guard isVisible else { return }
                            store.send(.personalizationDiscoverySectionBecameVisible)
                        }
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
