#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SeriesDetailView_iOS: View {
        let store: StoreOf<SeriesDetailFeature>

        public init(store: StoreOf<SeriesDetailFeature>) {
            self.store = store
        }

        public var body: some View {
            NavigationStack {
                ZStack(alignment: .top) {
                    Color(hex: "#0F0F13").ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 0) {
                            headerView
                            contentView
                        }
                    }
                }
                .onAppear {
                    store.send(.onAppear)
                }
                #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            store.send(.closeTapped)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            // Reload or Sync Action
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .sheet(
                    isPresented: Binding(
                        get: { store.isTrailerPresented },
                        set: { isPresented in
                            if !isPresented {
                                store.send(.dismissTrailer)
                            }
                        }
                    )
                ) {
                    if let key = store.trailerVideoKey, let title = store.trailerTitle {
                        trailerPlayerSheet(videoKey: key, title: title)
                    }
                }
            }
        }

        private var headerView: some View {
            ZStack(alignment: .bottom) {
                // Background Blur
                GeometryReader { proxy in
                    let cover = store.tmdbTV?.backdropPath.map { "https://image.tmdb.org/t/p/w780\($0)" } ??
                        store.tmdbTV?.posterPath.map { "https://image.tmdb.org/t/p/w780\($0)" } ??
                        store.series.coverURL?.absoluteString

                    if let urlString = cover, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case let .success(image):
                                image.resizable().scaledToFill()
                            default:
                                Rectangle().fill(Color(hex: "#1A1A24"))
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .blur(radius: 40)
                        .opacity(0.4)
                    } else {
                        Rectangle().fill(Color(hex: "#1A1A24"))
                    }
                }

                // Gradient Overlay
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color(hex: "#0F0F13"), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Content (Poster + Info side by side, plus Action Section)
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom, spacing: 16) {
                        // Poster
                        let cover = store.tmdbTV?.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" } ?? store.series.coverURL?.absoluteString

                        if let urlString = cover, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case let .success(image):
                                    image.resizable().scaledToFill()
                                case .empty:
                                    Rectangle().fill(Color(hex: "#2A2A30")).shimmeringPlaceholder(isLoading: true)
                                case .failure:
                                    Rectangle().fill(Color(hex: "#2A2A30"))
                                @unknown default:
                                    Rectangle().fill(Color(hex: "#2A2A30"))
                                }
                            }
                            .frame(width: 120, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                        } else if store.isTMDBLoading {
                            Rectangle()
                                .fill(Color(hex: "#2A2A30"))
                                .frame(width: 120, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shimmeringPlaceholder(isLoading: true)
                        }

                        // Info block
                        VStack(alignment: .leading, spacing: 10) {
                            Text(store.tmdbTV?.name ?? store.series.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)

                            // Rating and Status
                            HStack(spacing: 8) {
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
            .redacted(reason: store.isLoading ? .placeholder : [])
            .shimmeringPlaceholder(isLoading: store.isLoading)
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
                                gradientColors: [Color(hex: "#00F5D4"), Color.white],
                                trackColor: Color.white.opacity(0.3)
                            ) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                            Text(AppStrings.SeriesDetail.continueWatching)
                                .font(.system(size: 16, weight: .semibold))

                            let percent = WatchProgressFormatter.percentage(progress: history.progress, duration: history.duration)
                            Text("%\(percent)")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.2), in: Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#0A84FF"), Color(hex: "#0055B3")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color(hex: "#0A84FF").opacity(0.35), radius: 8, y: 3)
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
                                .font(.system(size: 16, weight: .bold))
                            Text(AppStrings.SeriesDetail.watch)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#0A84FF"), Color(hex: "#0055B3")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color(hex: "#0A84FF").opacity(0.35), radius: 8, y: 3)
                    }
                }

                // 2. Secondary Symmetrical Action Row (Zero-Scroll Above-the-Fold)
                HStack(spacing: 8) {
                    if let history = store.historyItem, history.duration > 0 {
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.restartTapped)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .medium))
                                Text(AppStrings.SeriesDetail.restart)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                            .foregroundStyle(.white)
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
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                            .foregroundStyle(.white)
                        }
                    }

                    Button {
                        HapticManager.shared.trigger(.medium)
                        store.send(.toggleFavorite)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: store.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(store.isFavorite ? Color.red : Color.white)
                            Text(store.isFavorite ? AppStrings.Common.favorited : AppStrings.Common.favorite)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(store.isFavorite ? Color.red : Color.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            store.isFavorite ? Color.red.opacity(0.15) : Color.white.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(store.isFavorite ? Color.red.opacity(0.3) : Color.white.opacity(0.15), lineWidth: 0.8))
                    }
                }
            }
        }

        private var contentView: some View {
            VStack(alignment: .leading, spacing: 24) {
                // Description
                let plot = store.tmdbTV?.overview ?? store.info?.plot
                if let plotText = plot, !plotText.isEmpty {
                    Text(plotText)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                } else if store.isTMDBLoading {
                    VStack(spacing: 8) {
                        Text("")
                        Text("")
                        Text("")
                    }
                    .shimmeringPlaceholder(isLoading: true)
                    .padding(.horizontal, 24)
                }

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
                }

                // Next Up Episode Auto-Cue Banner
                if let nextEp = store.nextUpEpisode {
                    VStack(alignment: .leading, spacing: 10) {
                        NextUpEpisodeBannerView(
                            episode: nextEp,
                            seriesTitle: store.series.title,
                            progressItem: store.episodeProgressMap[nextEp.id],
                            onPlay: {
                                store.send(.playNextEpisodeTapped)
                            }
                        )
                        .padding(.horizontal, 24)
                    }
                }

                // Episodes List & Grid Toggle
                if !store.currentEpisodes.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(AppStrings.SeriesDetail.episodes)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)

                            Spacer()

                            Text("\(store.currentEpisodes.count) \(AppStrings.SeriesDetail.episodeCount)")
                                .font(.system(size: 13.5))
                                .foregroundStyle(Color.white.opacity(0.6))

                            // Layout Toggle Button (List vs Grid)
                            Button {
                                HapticManager.shared.trigger(.light)
                                store.send(.toggleLayoutMode)
                            } label: {
                                Image(systemName: store.episodeLayoutMode == .list ? "square.grid.2x2" : "rectangle.grid.1x2")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color(hex: "#1A1A24"), in: Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 24)

                        if store.episodeLayoutMode == .list {
                            LazyVStack(spacing: 12) {
                                ForEach(store.currentEpisodes) { episode in
                                    EpisodeCardView(
                                        episode: episode,
                                        progressItem: store.episodeProgressMap[episode.id],
                                        isDownloaded: store.downloadedEpisodes[episode.id] == true,
                                        layoutMode: .list,
                                        onPlay: {
                                            store.send(.episodeSelected(episode))
                                        },
                                        onDownload: {
                                            store.send(.downloadEpisode(episode))
                                        }
                                    )
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
                                ForEach(store.currentEpisodes) { episode in
                                    EpisodeCardView(
                                        episode: episode,
                                        progressItem: store.episodeProgressMap[episode.id],
                                        isDownloaded: store.downloadedEpisodes[episode.id] == true,
                                        layoutMode: .grid,
                                        onPlay: {
                                            store.send(.episodeSelected(episode))
                                        },
                                        onDownload: {
                                            store.send(.downloadEpisode(episode))
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }

                Spacer().frame(height: 40)
            }
            .redacted(reason: store.isLoading ? .placeholder : [])
            .shimmeringPlaceholder(isLoading: store.isLoading)
        }

        // MARK: - In-App Trailer Player Sheet

        private func trailerPlayerSheet(videoKey: String, title: String) -> some View {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        TrailerWebView(videoKey: videoKey)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .shadow(color: .black.opacity(0.8), radius: 10, y: 5)

                        Spacer()
                    }
                    .padding(.top, 16)
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(AppStrings.Common.close) {
                            store.send(.dismissTrailer)
                        }
                        .foregroundColor(.white)
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
#endif
