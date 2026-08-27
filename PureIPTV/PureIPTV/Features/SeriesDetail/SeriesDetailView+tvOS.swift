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
                                Text("\(store.seasons.count) Sezon")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.white.opacity(0.7))
                            }
                        }

                        // Action Buttons
                        HStack(spacing: 20) {
                            if let history = store.historyItem, history.duration > 0 {
                                Button {
                                    store.send(.resumeTapped)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "play.fill")
                                        Text("Devam Et")
                                    }
                                    .font(.system(size: 22, weight: .bold))
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(Color.red)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    if let firstEp = store.currentEpisodes.first {
                                        store.send(.episodeSelected(firstEp))
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "play.fill")
                                        Text("İzle")
                                    }
                                    .font(.system(size: 22, weight: .bold))
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(Color.red)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                store.send(.toggleFavorite)
                            } label: {
                                Image(systemName: store.isFavorite ? "heart.fill" : "heart")
                                    .font(.system(size: 28))
                                    .padding(14)
                                    .background(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                            .background(Circle().fill(store.isFavorite ? Color.red.opacity(0.3) : Color.clear))
                                    )
                                    .foregroundStyle(store.isFavorite ? .red : .white)
                            }
                            .buttonStyle(.plain)
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
                        Text("Sezonlar")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 80)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(store.seasons) { season in
                                    let isSelected = store.selectedSeasonNumber == season.seasonNumber
                                    Button {
                                        store.send(.seasonSelected(season.seasonNumber))
                                    } label: {
                                        Text(season.name)
                                            .font(.system(size: 22, weight: .semibold))
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            .background(isSelected ? Color.red : Color(hex: "#1A1A24"))
                                            .foregroundStyle(.white)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 80)
                        }
                    }
                }

                // Episodes
                if !store.currentEpisodes.isEmpty {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Text("Bölümler")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(store.currentEpisodes.count) bölüm")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.white.opacity(0.6))
                        }
                        .padding(.horizontal, 80)

                        LazyVStack(spacing: 20) {
                            ForEach(store.currentEpisodes) { episode in
                                tvEpisodeCard(episode)
                            }
                        }
                        .padding(.horizontal, 80)
                    }
                }

                Spacer().frame(height: 80)
            }
        }

        // MARK: – Episode Card

        private func tvEpisodeCard(_ episode: DetailModels.Episode) -> some View {
            Button {
                store.send(.episodeSelected(episode))
            } label: {
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
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        HStack(spacing: 16) {
                            Text("S\(String(format: "%02d", episode.season))E\(String(format: "%02d", episode.episodeNum))")
                                .font(.system(size: 18, weight: .medium))
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
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "#1A1A24"))
                )
            }
            .buttonStyle(.plain)
        }

        // MARK: – Loading

        private var loadingView: some View {
            VStack(spacing: 32) {
                ProgressView()
                    .tint(Color(hex: "#0A84FF"))
                    .scaleEffect(2.0)
                Text("Dizi bilgileri yükleniyor…")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
            }
        }
    }
#endif
