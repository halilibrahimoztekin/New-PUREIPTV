#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS Series Detail View

    public struct SeriesDetailView_tvOS: View {
        @Bindable var store: StoreOf<SeriesDetailFeature>

        public init(store: StoreOf<SeriesDetailFeature>) {
            self.store = store
        }

        public var body: some View {
            ZStack {
                Color(hex: "#0F0F13").ignoresSafeArea()

                if store.isLoading {
                    loadingView
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            headerView
                            contentView
                        }
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
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
                    KFImage(url)
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
                        KFImage(url)
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
                                Text("\(store.seasons.count) \(AppStrings.Common.season)")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }
                        }

                        // Action Buttons
                        HStack(spacing: 20) {
                            if let history = store.historyItem, history.duration > 0 {
                                TVHeaderActionButton(title: AppStrings.SeriesDetail.continueWatching, icon: "play.fill", isPrimary: true) {
                                    store.send(.resumeTapped)
                                }
                            } else {
                                TVHeaderActionButton(title: AppStrings.SeriesDetail.watch, icon: "play.fill", isPrimary: true) {
                                    if let firstEp = store.currentEpisodes.first {
                                        store.send(.episodeSelected(firstEp))
                                    }
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
                    Text(plotText)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .lineSpacing(6)
                        .padding(.horizontal, 80)
                        .lineLimit(4)
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
                                    TVSeasonButton(
                                        season: season,
                                        isSelected: store.selectedSeasonNumber == season.seasonNumber
                                    ) {
                                        store.send(.seasonSelected(season.seasonNumber))
                                    }
                                }
                            }
                            .padding(.horizontal, 80)
                            .padding(.vertical, 8)
                        }
                    }
                }

                // Episodes
                if !store.currentEpisodes.isEmpty {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Text(AppStrings.SeriesDetail.episodes)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(store.currentEpisodes.count) \(AppStrings.SeriesDetail.episodeCount)")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        .padding(.horizontal, 80)

                        LazyVStack(spacing: 20) {
                            ForEach(store.currentEpisodes) { episode in
                                TVEpisodeRow(episode: episode) {
                                    store.send(.episodeSelected(episode))
                                }
                            }
                        }
                        .padding(.horizontal, 80)
                    }
                }

                Spacer().frame(height: 80)
            }
        }

        // MARK: – Loading

        private var loadingView: some View {
            VStack(spacing: 32) {
                ProgressView()
                    .tint(Color(hex: "#0A84FF"))
                    .scaleEffect(2.0)
                Text(AppStrings.SeriesDetail.loading)
                    .font(.system(size: 28))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
            }
        }
    }

    // MARK: - TV Episode Row (Smooth Focus without White Card Flash)

    private struct TVEpisodeRow: View {
        let episode: DetailModels.Episode
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(alignment: .top, spacing: 24) {
                    // Thumbnail
                    Group {
                        if let url = episode.coverURL {
                            KFImage(url)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle().fill(Color(hex: "#2A2A30"))
                        }
                    }
                    .frame(width: 240, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(episode.title)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .lineLimit(2)

                        HStack(spacing: 16) {
                            Text("S\(String(format: "%02d", episode.season))E\(String(format: "%02d", episode.episodeNum))")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(hex: "#0A84FF"))

                            if let rating = episode.rating, rating > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                                    Text(String(format: "%.1f", rating)).foregroundStyle(.white)
                                }
                                .font(.system(size: 16))
                            }

                            if let duration = episode.duration {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                    Text(duration)
                                }
                                .font(.system(size: 16))
                                .foregroundStyle(Color.white.opacity(0.6))
                            }
                        }

                        if let plot = episode.plot, !plot.isEmpty {
                            Text(plot)
                                .font(.system(size: 18))
                                .foregroundStyle(Color.white.opacity(0.65))
                                .lineLimit(2)
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(TVEpisodeCardButtonStyle())
        }
    }

    // MARK: - TV Season Button

    private struct TVSeasonButton: View {
        let season: DetailModels.Season
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(season.name)
                    .font(.system(size: 22, weight: isSelected ? .bold : .semibold))
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
