#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SeriesDetailView_iOS: View {
        let store: StoreOf<SeriesDetailFeature>
        let onPresentSynopsis: (String) -> Void

        public init(
            store: StoreOf<SeriesDetailFeature>,
            onPresentSynopsis: @escaping (String) -> Void = { _ in }
        ) {
            self.store = store
            self.onPresentSynopsis = onPresentSynopsis
        }

        public var body: some View {
            ZStack(alignment: .top) {
                AppColors.surfaceDark.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            headerView
                            contentView
                        }
                    }
                    .task(id: store.pendingEpisodeReveal?.id) {
                        guard let request = store.pendingEpisodeReveal else { return }
                        await Task.yield()
                        guard !Task.isCancelled,
                              store.pendingEpisodeReveal?.id == request.id,
                              store.selectedSeasonNumber == request.seasonNumber
                        else { return }
                        proxy.scrollTo(request.episodeID, anchor: .center)
                        await Task.yield()
                        guard !Task.isCancelled,
                              store.pendingEpisodeReveal?.id == request.id,
                              store.selectedSeasonNumber == request.seasonNumber
                        else { return }
                        store.send(.episodeRevealHandled(request.id))
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onDisappear {
                store.send(.viewDidDisappear)
            }
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: 8) {
                    if store.canManageTMDBMatch {
                        Button { store.send(.showTMDBMatchPicker) } label: {
                            Label(AppStrings.TMDBMatchPicker.title, systemImage: "film")
                                .font(AppFonts.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .liquidGlass(shape: .capsule, isInteractive: true)
                        }
                    }

                    if store.canManagePresentation {
                        Button { store.send(.editPresentationTapped) } label: {
                            Label(AppStrings.MediaPresentation.edit, systemImage: "pencil")
                                .font(AppFonts.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .liquidGlass(shape: .capsule, isInteractive: true)
                        }
                        .disabled(!store.isPresentationOverrideLoaded)
                        .accessibilityHint(AppStrings.MediaPresentation.localOnlyDescription)
                    }
                }
                .padding(.top, 12)
                .padding(.trailing, 16)
            }
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.closeTapped)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(AppFonts.bodyMedium.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(8)
                            .liquidGlass(shape: .circle, isInteractive: true)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Reload or Sync Action
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(AppFonts.bodyMedium.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(8)
                            .liquidGlass(shape: .circle, isInteractive: true)
                    }
                }
            }
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

        private var headerView: some View {
            ZStack(alignment: .bottom) {
                // Background Blur
                GeometryReader { proxy in
                    let cover = store.tmdbTV?.backdropPath.map { "https://image.tmdb.org/t/p/w1280\($0)" } ??
                        store.series.presentationOverride?.posterURL?.absoluteString ??
                        store.tmdbTV?.posterPath.map { "https://image.tmdb.org/t/p/w780\($0)" } ??
                        store.series.coverURL?.absoluteString

                    if let urlString = cover, let url = URL(string: urlString) {
                        PlaylistAsyncImage(url: url, userAgentOverride: store.config.userAgentOverride, playlistID: store.config.playlistID) { phase in
                            switch phase {
                            case let .success(image):
                                image.resizable().scaledToFill()
                            default:
                                Rectangle().fill(AppColors.surfaceTertiary)
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .blur(radius: 40)
                        .opacity(0.4)
                    } else {
                        Rectangle().fill(AppColors.surfaceTertiary)
                    }
                }

                // Gradient Overlay
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: AppColors.surfaceDark, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Content (Poster + Info side by side, plus Action Section)
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom, spacing: 16) {
                        // Poster
                        let cover = store.series.presentationOverride?.posterURL?.absoluteString ??
                            store.tmdbTV?.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" } ?? store.series.coverURL?.absoluteString

                        if let urlString = cover, let url = URL(string: urlString) {
                            PlaylistAsyncImage(url: url, userAgentOverride: store.config.userAgentOverride, playlistID: store.config.playlistID) { phase in
                                switch phase {
                                case let .success(image):
                                    image.resizable().scaledToFill()
                                case .empty:
                                    Rectangle().fill(AppColors.surfaceElevated).shimmeringPlaceholder(isLoading: true)
                                case .failure:
                                    Rectangle().fill(AppColors.surfaceElevated)
                                @unknown default:
                                    Rectangle().fill(AppColors.surfaceElevated)
                                }
                            }
                            .frame(width: 120, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: AppColors.oledBlack.opacity(0.5), radius: 10, x: 0, y: 5)
                        } else if store.isTMDBLoading {
                            Rectangle()
                                .fill(AppColors.surfaceElevated)
                                .frame(width: 120, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shimmeringPlaceholder(isLoading: true)
                        }

                        // Info block
                        VStack(alignment: .leading, spacing: 10) {
                            Text(store.series.presentationOverride?.title ?? store.tmdbTV?.name ?? store.series.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)

                            // Rating and Status
                            HStack(spacing: 8) {
                                if let year = store.series.presentationOverride?.year {
                                    Text(String(year))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.75))
                                } else if let releaseDate = store.tmdbTV?.firstAirDate ?? store.info?.releaseDate ?? store.series.releaseDate, !releaseDate.isEmpty {
                                    Text(String(releaseDate.prefix(4)))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.75))
                                }

                                if let rating = store.tmdbTV?.voteAverage ?? store.info?.rating, rating > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                            .font(.system(size: 12))
                                        Text(String(format: "%.1f", rating))
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }

                                if let status = store.tmdbTV?.status ?? store.info?.status {
                                    Text(status)
                                        .font(.system(size: 10, weight: .bold))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.1))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Zero-Friction Action Section (Don't Make Me Think)
                    actionSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 20)
            }
        }

        // MARK: - Action Section (Zero-Friction "Don't Make Me Think")

        private var actionSection: some View {
            VStack(spacing: 12) {
                // 1. Primary Full-Width CTA
                if let history = store.historyItem, history.duration > 0 {
                    Button {
                        HapticManager.shared.trigger(.medium)
                        store.send(.resumeTapped)
                    } label: {
                        HStack(spacing: 10) {
                            CircularProgressRing(
                                progress: WatchProgressFormatter.progressRatio(progress: history.progress, duration: history.duration),
                                lineWidth: 2.5,
                                size: 22,
                                gradientColors: [AppColors.neonTeal, AppColors.textPrimary],
                                trackColor: AppColors.borderStrong
                            ) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(AppColors.textPrimary)
                            }

                            Text(AppStrings.SeriesDetail.continueWatching)
                                .font(AppFonts.bodyLarge.weight(.semibold))

                            let percent = WatchProgressFormatter.percentage(progress: history.progress, duration: history.duration)
                            Text("%\(percent)")
                                .font(AppFonts.caption.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(AppColors.borderStrong, in: Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: AppColors.primary.opacity(0.35), radius: 8, y: 3)
                    }
                } else {
                    Button {
                        HapticManager.shared.trigger(.medium)
                        if let firstEp = store.currentEpisodes.first {
                            store.send(.episodeSelected(firstEp))
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(AppFonts.bodyLarge.bold())
                            Text(AppStrings.SeriesDetail.watch)
                                .font(AppFonts.bodyLarge.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: AppColors.primary.opacity(0.35), radius: 8, y: 3)
                    }
                }

                // 2. Secondary Symmetrical Action Row (Zero-Scroll Above-the-Fold)
                LiquidGlassContainer(spacing: 8) {
                    if store.currentEpisodeRevealTarget != nil {
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.revealCurrentEpisodeTapped)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "dot.scope")
                                    .font(.system(size: 16, weight: .medium))
                                Text(AppStrings.SeriesDetail.currentEpisode)
                                    .font(AppFonts.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .liquidGlass(shape: .roundedRectangle(cornerRadius: 10), isInteractive: true)
                            .foregroundStyle(AppColors.textPrimary)
                        }
                    }

                    if let history = store.historyItem, history.duration > 0 {
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.restartTapped)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .medium))
                                Text(AppStrings.SeriesDetail.restart)
                                    .font(AppFonts.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .liquidGlass(shape: .roundedRectangle(cornerRadius: 10), isInteractive: true)
                            .foregroundStyle(AppColors.textPrimary)
                        }
                    }

                    if store.resolvedTrailerKey != nil {
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.trailerTapped)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "film.fill")
                                    .font(.system(size: 16, weight: .medium))
                                Text(AppStrings.VODDetail.trailer)
                                    .font(AppFonts.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .liquidGlass(shape: .roundedRectangle(cornerRadius: 10), isInteractive: true)
                            .foregroundStyle(AppColors.textPrimary)
                        }
                    }

                    Button {
                        HapticManager.shared.trigger(.medium)
                        store.send(.toggleFavorite)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: store.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(store.isFavorite ? AppColors.destructive : AppColors.textPrimary)
                            Text(store.isFavorite ? AppStrings.Common.favorited : AppStrings.Common.favorite)
                                .font(AppFonts.caption)
                                .foregroundStyle(store.isFavorite ? AppColors.destructive : AppColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .liquidGlass(shape: .roundedRectangle(cornerRadius: 10), tint: store.isFavorite ? AppColors.destructive.opacity(0.15) : nil, isInteractive: true)
                    }
                }
            }
        }

        private var contentView: some View {
            VStack(alignment: .leading, spacing: 24) {
                // Description
                let plot = store.tmdbTV?.overview ?? store.info?.plot
                if let plotText = plot, !plotText.isEmpty {
                    ExpandableSynopsisView(
                        text: plotText,
                        font: .system(size: 15),
                        lineLimit: 5,
                        onPresent: { onPresentSynopsis(plotText) }
                    )
                    .padding(.horizontal, 24)
                } else if store.isTMDBLoading || store.isLoading {
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)).frame(height: 14)
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)).frame(height: 14)
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)).frame(width: 220, height: 14)
                    }
                    .shimmeringPlaceholder(isLoading: true)
                    .padding(.horizontal, 24)
                }

                if !store.awardRecognitions.isEmpty {
                    AwardRecognitionMetadataView(recognitions: store.awardRecognitions)
                        .padding(.horizontal, 24)
                }

                WatchAvailabilitySection(
                    countryCode: store.watchAvailabilityCountryCode,
                    availability: store.watchAvailability,
                    updatedAt: store.watchAvailabilityLoadedAt,
                    isLoading: store.isWatchAvailabilityLoading,
                    failed: store.watchAvailabilityFailed,
                    onSelectCountry: { store.send(.watchAvailabilityCountrySelected($0)) },
                    onRetry: { store.send(.retryWatchAvailability) }
                )
                .padding(.horizontal, 24)

                // Seasons Header
                if !store.seasons.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(AppStrings.SeriesDetail.seasons)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)

                        SeasonPickerPillsView(
                            seasons: store.seasons,
                            selectedSeasonNumber: store.selectedSeasonNumber,
                            allEpisodes: store.allEpisodes,
                            onSelectSeason: { seasonNum in
                                store.send(.seasonSelected(seasonNum))
                            }
                        )
                        .padding(.horizontal, 24)
                    }
                } else if store.isLoading {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(AppStrings.SeriesDetail.seasons)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)

                        HStack(spacing: 10) {
                            ForEach(0 ..< 4, id: \.self) { _ in
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 90, height: 36)
                                    .shimmeringPlaceholder(isLoading: true)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                // Next Up Episode Auto-Cue Banner
                if let nextEp = store.nextUpEpisode {
                    VStack(alignment: .leading, spacing: 10) {
                        NextUpEpisodeBannerView(
                            episode: nextEp,
                            userAgentOverride: store.config.userAgentOverride,
                            playlistID: store.config.playlistID,
                            seriesTitle: store.series.displayTitle,
                            progressItem: store.episodeProgressMap[nextEp.id],
                            onPlay: {
                                store.send(.playNextEpisodeTapped)
                            }
                        )
                        .padding(.horizontal, 24)
                    }
                }

                if let diagnostics = store.info?.seriesCatalogDiagnostics, !diagnostics.isEmpty {
                    SeriesEpisodeCatalogDiagnosticsView(diagnostics: diagnostics)
                        .padding(.horizontal, 24)
                }

                // Episodes List & Grid Toggle
                if !store.currentEpisodes.isEmpty || store.canShuffleSeries {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(AppStrings.SeriesDetail.episodes)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)

                            Spacer()

                            if !store.currentEpisodes.isEmpty {
                                Text("\(store.currentEpisodes.count) \(AppStrings.SeriesDetail.episodeCount)")
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(Color.white.opacity(0.6))

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
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)

                        VStack(spacing: 12) {
                            ForEach(0 ..< 3, id: \.self) { _ in
                                HStack(spacing: 14) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 130, height: 75)
                                    VStack(alignment: .leading, spacing: 8) {
                                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)).frame(height: 16)
                                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)).frame(width: 120, height: 12)
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

                Spacer().frame(height: 40)
            }
        }
    }
#endif
