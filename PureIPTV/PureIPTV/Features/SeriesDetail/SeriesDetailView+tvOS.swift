#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS Series Detail View

    public struct SeriesDetailView_tvOS: View {
        @Bindable var store: StoreOf<SeriesDetailFeature>
        let onPresentSynopsis: (String) -> Void
        @FocusState private var focusedEpisodeID: String?

        public init(
            store: StoreOf<SeriesDetailFeature>,
            onPresentSynopsis: @escaping (String) -> Void = { _ in }
        ) {
            self.store = store
            self.onPresentSynopsis = onPresentSynopsis
        }

        public var body: some View {
            ZStack {
                Color(hex: "#0F0F13").ignoresSafeArea()

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
                        do {
                            try await Task.sleep(for: .milliseconds(120))
                        } catch {
                            return
                        }
                        guard !Task.isCancelled,
                              store.pendingEpisodeReveal?.id == request.id,
                              store.selectedSeasonNumber == request.seasonNumber
                        else { return }
                        focusedEpisodeID = request.episodeID
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
            .onExitCommand {
                store.send(.closeTapped)
            }
            .overlay(alignment: .topTrailing) {
                if store.canManageTMDBMatch {
                    Button { store.send(.showTMDBMatchPicker) } label: {
                        Label(AppStrings.TMDBMatchPicker.title, systemImage: "film")
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 15)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.top, 28)
                    .padding(.trailing, 36)
                }
            }
        }

        // MARK: – Header

        private var headerView: some View {
            ZStack(alignment: .bottomLeading) {
                // Background Blur
                let cover = store.tmdbTV?.backdropPath.map { "https://image.tmdb.org/t/p/w1280\($0)" }
                    ?? store.tmdbTV?.posterPath.map { "https://image.tmdb.org/t/p/w780\($0)" }
                    ?? store.series.coverURL?.absoluteString

                if let urlString = cover, let url = URL(string: urlString) {
                    KFImage.url(url, cacheKey: PlaylistArtworkRequest.cacheKey(for: url, userAgentOverride: store.config.userAgentOverride, playlistID: store.config.playlistID))
                        .requestModifier { request in
                            PlaylistArtworkRequest.applyHeaders(to: &request, userAgentOverride: store.config.userAgentOverride, playlistID: store.config.playlistID)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 650)
                        .clipped()
                        .blur(radius: 30)
                        .opacity(0.35)
                } else {
                    Rectangle()
                        .fill(Color(hex: "#1A1A24"))
                        .frame(height: 650)
                }

                // Gradient
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color(hex: "#0F0F13"), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 650)

                // Content
                HStack(alignment: .bottom, spacing: 40) {
                    // Poster
                    let posterURL = store.tmdbTV?.posterPath.map { "https://image.tmdb.org/t/p/w500\($0)" } ?? store.series.coverURL?.absoluteString

                    if let urlString = posterURL, let url = URL(string: urlString) {
                        KFImage.url(url, cacheKey: PlaylistArtworkRequest.cacheKey(for: url, userAgentOverride: store.config.userAgentOverride, playlistID: store.config.playlistID))
                            .requestModifier { request in
                                PlaylistArtworkRequest.applyHeaders(to: &request, userAgentOverride: store.config.userAgentOverride, playlistID: store.config.playlistID)
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 240, height: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 10)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 20) {
                        Text(store.tmdbTV?.name ?? store.series.title)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        // Rating + Status
                        HStack(spacing: 16) {
                            if let rating = store.tmdbTV?.voteAverage ?? store.info?.rating, rating > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.system(size: 18))
                                    Text(String(format: "%.1f", rating))
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }

                            if let status = store.tmdbTV?.status ?? store.info?.status {
                                Text(status)
                                    .font(.system(size: 16, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.15))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }

                            if !store.seasons.isEmpty {
                                HStack(spacing: 4) {
                                    Text("\(store.seasons.count)")
                                    Text(AppStrings.Common.season)
                                }
                                .font(.system(size: 18))
                                .foregroundStyle(Color.white.opacity(0.7))
                            }
                        }

                        // Action Buttons
                        HStack(spacing: 20) {
                            if let history = store.historyItem, history.duration > 0 {
                                let ratio = WatchProgressFormatter.progressRatio(progress: history.progress, duration: history.duration)
                                let percent = WatchProgressFormatter.percentage(progress: history.progress, duration: history.duration)

                                Button {
                                    store.send(.resumeTapped)
                                } label: {
                                    HStack(spacing: 12) {
                                        CircularProgressRing(
                                            progress: ratio,
                                            lineWidth: 3.5,
                                            size: 26,
                                            gradientColors: [Color(hex: "#00F5D4"), Color.white],
                                            trackColor: Color.white.opacity(0.3)
                                        ) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                        }

                                        Text("\(AppStrings.SeriesDetail.continueWatching) (%\(percent))")
                                            .font(.system(size: 22, weight: .bold))
                                    }
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(TVCapsuleButtonStyle(isPrimary: true, isSelected: false))

                                TVHeaderActionButton(title: AppStrings.SeriesDetail.restart, icon: "arrow.counterclockwise", isPrimary: false) {
                                    store.send(.restartTapped)
                                }
                            } else {
                                TVHeaderActionButton(title: AppStrings.SeriesDetail.watch, icon: "play.fill", isPrimary: true) {
                                    if let nextEp = store.nextUpEpisode {
                                        store.send(.episodeSelected(nextEp))
                                    } else if let firstEp = store.currentEpisodes.first {
                                        store.send(.episodeSelected(firstEp))
                                    }
                                }
                            }

                            if store.currentEpisodeRevealTarget != nil {
                                TVHeaderActionButton(
                                    title: AppStrings.SeriesDetail.currentEpisode,
                                    icon: "dot.scope",
                                    isPrimary: false
                                ) {
                                    store.send(.revealCurrentEpisodeTapped)
                                }
                            }

                            TVHeaderFavoriteButton(isFavorite: store.isFavorite) {
                                store.send(.toggleFavorite)
                            }

                        }
                    }
                }
                .padding(.horizontal, 80)
                .padding(.bottom, 60)
            }
            .frame(height: 650)
        }

        // MARK: – Content

        private var contentView: some View {
            VStack(alignment: .leading, spacing: 40) {
                // Description
                let plot = store.tmdbTV?.overview ?? store.info?.plot
                if let plotText = plot, !plotText.isEmpty {
                    ExpandableSynopsisView(
                        text: plotText,
                        font: .system(size: 22),
                        lineLimit: 4,
                        onPresent: { onPresentSynopsis(plotText) }
                    )
                    .padding(.horizontal, 80)
                } else if store.isLoading || store.isTMDBLoading {
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.12))
                            .frame(maxWidth: .infinity, maxHeight: 20)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.12))
                            .frame(maxWidth: .infinity, maxHeight: 20)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 400, height: 20)
                    }
                    .padding(.horizontal, 80)
                    .shimmeringPlaceholder(isLoading: true)
                }

                if !store.awardRecognitions.isEmpty {
                    AwardRecognitionMetadataView(recognitions: store.awardRecognitions)
                        .padding(.horizontal, 80)
                }

                // Next Up Episode Auto-Cue Banner (if available)
                if let nextEp = store.nextUpEpisode {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(AppStrings.SeriesDetail.nextEpisode)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)

                        NextUpEpisodeBannerView(
                            episode: nextEp,
                            userAgentOverride: store.config.userAgentOverride,
                            playlistID: store.config.playlistID,
                            seriesTitle: store.series.title,
                            progressItem: store.episodeProgressMap[nextEp.id]
                        ) {
                            store.send(.playNextEpisodeTapped)
                        }
                    }
                    .padding(.horizontal, 80)
                }

                // Seasons
                if !store.seasons.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(AppStrings.SeriesDetail.seasons)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 80)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(store.seasons) { season in
                                    let count = store.allEpisodes[String(season.seasonNumber)]?.count ?? season.episodeCount ?? 0
                                    TVSeasonButton(
                                        season: season,
                                        episodeCount: count,
                                        isSelected: store.selectedSeasonNumber == season.seasonNumber
                                    ) {
                                        store.send(.seasonSelected(season.seasonNumber))
                                    }
                                }
                            }
                            .padding(.horizontal, 80)
                            .padding(.vertical, 8)
                        }
                        .focusSection()
                    }
                } else if store.isLoading {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(AppStrings.SeriesDetail.seasons)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 80)

                        HStack(spacing: 16) {
                            ForEach(0 ..< 4, id: \.self) { _ in
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 140, height: 50)
                            }
                        }
                        .padding(.horizontal, 80)
                        .shimmeringPlaceholder(isLoading: true)
                    }
                }

                // Episodes
                if !store.currentEpisodes.isEmpty || store.canShuffleSeries {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Text(AppStrings.SeriesDetail.episodes)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            HStack(spacing: 20) {
                                if !store.currentEpisodes.isEmpty {
                                    HStack(spacing: 4) {
                                        Text("\(store.currentEpisodes.count)")
                                        Text(AppStrings.SeriesDetail.episodeCount)
                                    }
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.white.opacity(0.6))
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
                                        Label(AppStrings.SeriesDetail.shuffleEpisodes, systemImage: "shuffle")
                                            .font(.system(size: 18, weight: .semibold))
                                            .padding(.horizontal, 18)
                                            .padding(.vertical, 10)
                                    }
                                    .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                                }

                                if !store.currentEpisodes.isEmpty {
                                    Button {
                                        store.send(.toggleLayoutMode)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: store.episodeLayoutMode == .list ? "square.grid.2x2" : "list.bullet")
                                            Text(store.episodeLayoutMode == .list ? AppStrings.SeriesDetail.gridView : AppStrings.SeriesDetail.listView)
                                        }
                                        .font(.system(size: 18, weight: .semibold))
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                                }
                            }
                        }
                        .padding(.horizontal, 80)

                        if store.currentEpisodes.isEmpty {
                            EmptyView()
                        } else if store.episodeLayoutMode == .list {
                            LazyVStack(spacing: 20) {
                                ForEach(store.currentEpisodes) { episode in
                                    TVEpisodeRow(
                                        episode: episode,
                                        progressItem: store.episodeProgressMap[episode.id],
                                        userAgentOverride: store.config.userAgentOverride,
                                        playlistID: store.config.playlistID,
                                        focusedEpisodeID: $focusedEpisodeID,
                                        onMarkUnwatched: { store.send(.markEpisodeUnwatched(episode.id)) }
                                    ) {
                                        store.send(.episodeSelected(episode))
                                    }
                                    .id(episode.id)
                                }
                            }
                            .padding(.horizontal, 80)
                            .focusSection()
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 32), GridItem(.flexible(), spacing: 32)], spacing: 32) {
                                ForEach(store.currentEpisodes) { episode in
                                    TVEpisodeGridCard(
                                        episode: episode,
                                        progressItem: store.episodeProgressMap[episode.id],
                                        userAgentOverride: store.config.userAgentOverride,
                                        playlistID: store.config.playlistID,
                                        focusedEpisodeID: $focusedEpisodeID,
                                        onMarkUnwatched: { store.send(.markEpisodeUnwatched(episode.id)) }
                                    ) {
                                        store.send(.episodeSelected(episode))
                                    }
                                    .id(episode.id)
                                }
                            }
                            .padding(.horizontal, 80)
                            .focusSection()
                        }
                    }
                } else if store.isLoading {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(AppStrings.SeriesDetail.episodes)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 80)

                        LazyVStack(spacing: 20) {
                            ForEach(0 ..< 3, id: \.self) { _ in
                                HStack(spacing: 28) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 260, height: 150)
                                    VStack(alignment: .leading, spacing: 12) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white.opacity(0.12))
                                            .frame(width: 280, height: 24)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white.opacity(0.12))
                                            .frame(width: 140, height: 18)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white.opacity(0.12))
                                            .frame(maxWidth: .infinity, maxHeight: 18)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                            }
                        }
                        .padding(.horizontal, 80)
                        .shimmeringPlaceholder(isLoading: true)
                    }
                }

                Spacer().frame(height: 80)
            }
        }
    }

    // MARK: - TV Episode Row (Smooth Focus without White Card Flash)

    private struct TVEpisodeRow: View {
        let episode: DetailModels.Episode
        let progressItem: WatchHistoryItem?
        let userAgentOverride: String?
        let playlistID: UUID?
        @FocusState.Binding var focusedEpisodeID: String?
        var onMarkUnwatched: () -> Void = {}
        let action: () -> Void

        private var ratio: Double {
            guard let p = progressItem, p.duration > 0 else { return 0.0 }
            return WatchProgressFormatter.progressRatio(progress: p.progress, duration: p.duration)
        }

        private var percent: Int {
            guard let p = progressItem, p.duration > 0 else { return 0 }
            return WatchProgressFormatter.percentage(progress: p.progress, duration: p.duration)
        }

        private var isWatched: Bool {
            ratio >= 0.90
        }

        private var isInProgress: Bool {
            ratio > 0.02 && ratio < 0.90
        }

        var body: some View {
            Button {
                action()
            } label: {
                HStack(alignment: .top, spacing: 28) {
                    // Thumbnail
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let url = episode.coverURL {
                                KFImage.url(url, cacheKey: PlaylistArtworkRequest.cacheKey(for: url, userAgentOverride: userAgentOverride, playlistID: playlistID))
                                    .requestModifier { request in
                                        PlaylistArtworkRequest.applyHeaders(to: &request, userAgentOverride: userAgentOverride, playlistID: playlistID)
                                    }
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color(hex: "#2A2A30"))
                            }
                        }
                        .frame(width: 260, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        if isWatched {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                Text(AppStrings.SeriesDetail.watched)
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#00BA88"), in: Capsule())
                            .padding(10)
                        } else if isInProgress {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.3)).frame(height: 5)
                                    Capsule().fill(Color(hex: "#00F5D4")).frame(width: proxy.size.width * CGFloat(ratio), height: 5)
                                }
                            }
                            .frame(height: 5)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                        }
                    }
                    .frame(width: 260, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Info
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(episode.title)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .lineLimit(2)

                            Spacer()

                            if isInProgress {
                                Text("%\(percent) \(AppStrings.SeriesDetail.watched.lowercased())")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color(hex: "#00F5D4"))
                            }
                        }

                        HStack(spacing: 18) {
                            Text("S\(String(format: "%02d", episode.season))E\(String(format: "%02d", episode.episodeNum))")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color(hex: "#0A84FF"))

                            if let rating = episode.rating, rating > 0 {
                                HStack(spacing: 5) {
                                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                                    Text(String(format: "%.1f", rating)).foregroundStyle(.white)
                                }
                                .font(.system(size: 18))
                            }

                            if let duration = episode.duration {
                                HStack(spacing: 5) {
                                    Image(systemName: "clock")
                                    Text(duration)
                                }
                                .font(.system(size: 18))
                                .foregroundStyle(Color.white.opacity(0.6))
                            }
                        }

                        if let plot = episode.plot, !plot.isEmpty {
                            Text(plot)
                                .font(.system(size: 20))
                                .foregroundStyle(Color.white.opacity(0.7))
                                .lineLimit(3)
                                .lineSpacing(4)
                        }
                    }

                    Spacer()
                }
                .padding(12)
            }
            .buttonStyle(TVEpisodeCardButtonStyle())
            .focused($focusedEpisodeID, equals: episode.id)
            .contextMenu {
                if isWatched {
                    Button(action: onMarkUnwatched) {
                        Label(AppStrings.SeriesDetail.markAsUnwatched, systemImage: "eye.slash")
                    }
                }
            }
        }
    }

    // MARK: - TV Episode Grid Card

    private struct TVEpisodeGridCard: View {
        let episode: DetailModels.Episode
        let progressItem: WatchHistoryItem?
        let userAgentOverride: String?
        let playlistID: UUID?
        @FocusState.Binding var focusedEpisodeID: String?
        var onMarkUnwatched: () -> Void = {}
        let action: () -> Void

        private var ratio: Double {
            guard let p = progressItem, p.duration > 0 else { return 0.0 }
            return WatchProgressFormatter.progressRatio(progress: p.progress, duration: p.duration)
        }

        private var percent: Int {
            guard let p = progressItem, p.duration > 0 else { return 0 }
            return WatchProgressFormatter.percentage(progress: p.progress, duration: p.duration)
        }

        private var isWatched: Bool {
            ratio >= 0.90
        }

        private var isInProgress: Bool {
            ratio > 0.02 && ratio < 0.90
        }

        var body: some View {
            Button {
                action()
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let url = episode.coverURL {
                                KFImage.url(url, cacheKey: PlaylistArtworkRequest.cacheKey(for: url, userAgentOverride: userAgentOverride, playlistID: playlistID))
                                    .requestModifier { request in
                                        PlaylistArtworkRequest.applyHeaders(to: &request, userAgentOverride: userAgentOverride, playlistID: playlistID)
                                    }
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color(hex: "#2A2A30"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        if isWatched {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                Text(AppStrings.SeriesDetail.watched)
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#00BA88"), in: Capsule())
                            .padding(12)
                        } else if isInProgress {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.3)).frame(height: 5)
                                    Capsule().fill(Color(hex: "#00F5D4")).frame(width: proxy.size.width * CGFloat(ratio), height: 5)
                                }
                            }
                            .frame(height: 5)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                        }
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(episode.title)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            Text("S\(String(format: "%02d", episode.season))E\(String(format: "%02d", episode.episodeNum))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(hex: "#0A84FF"))
                        }

                        if isInProgress {
                            Text("%\(percent) \(AppStrings.SeriesDetail.watched.lowercased())")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(hex: "#00F5D4"))
                        } else if let duration = episode.duration {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text(duration)
                            }
                            .font(.system(size: 16))
                            .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(12)
            }
            .tvFocusEffect()
            .focused($focusedEpisodeID, equals: episode.id)
            .contextMenu {
                if isWatched {
                    Button(action: onMarkUnwatched) {
                        Label(AppStrings.SeriesDetail.markAsUnwatched, systemImage: "eye.slash")
                    }
                }
            }
        }
    }

    // MARK: - TV Season Button

    private struct TVSeasonButton: View {
        let season: DetailModels.Season
        let episodeCount: Int
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Text(season.name)
                        .font(.system(size: 22, weight: isSelected ? .bold : .semibold))
                    Text("(\(episodeCount))")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: isSelected))
        }
    }

    // MARK: - TV Header Action Button

    private struct TVHeaderActionButton: View {
        let title: String
        let icon: String
        let isPrimary: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                    Text(title)
                }
                .font(.system(size: 22, weight: .bold))
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
            }
            .buttonStyle(TVCapsuleButtonStyle(isPrimary: isPrimary, isSelected: false))
        }
    }

    // MARK: - TV Header Favorite Button

    private struct TVHeaderFavoriteButton: View {
        let isFavorite: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 26))
                    .padding(14)
                    .foregroundStyle(isFavorite ? Color.red : Color.white)
            }
            .buttonStyle(TVCircleButtonStyle(isFavorite: isFavorite))
        }
    }
#endif
