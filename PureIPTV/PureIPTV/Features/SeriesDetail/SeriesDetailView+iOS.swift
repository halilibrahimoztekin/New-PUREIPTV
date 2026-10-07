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

            // Content (Poster + Info side by side)
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
                VStack(alignment: .leading, spacing: 12) {
                    Text(store.tmdbTV?.name ?? store.series.title)
                        .font(.system(size: 26, weight: .bold))
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

                    HStack(spacing: 12) {
                        // Play / Resume Button
                        if let history = store.historyItem, history.duration > 0 {
                            let progressMins = Int(history.progress / 60)
                            let durationMins = Int(history.duration / 60)

                            VStack(alignment: .leading, spacing: 4) {
                                Button {
                                    store.send(.resumeTapped)
                                } label: {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text("Devam Et")
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.red)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                }

                                Text("\(progressMins) dk / \(durationMins) dk izlendi")
                                    .font(.caption)
                                    .foregroundStyle(Color.white.opacity(0.7))
                                    .padding(.leading, 4)
                            }
                        } else {
                            Button {
                                // Play the first available episode
                                if let firstEp = store.currentEpisodes.first {
                                    store.send(.episodeSelected(firstEp))
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("İzle")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }
                        }

                        // Favorite Button
                        Button {
                            store.send(.toggleFavorite)
                        } label: {
                            Image(systemName: store.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 20))
                                .padding(8)
                                .background(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        .background(Circle().fill(store.isFavorite ? Color.red.opacity(0.2) : Color.clear))
                                )
                                .foregroundStyle(store.isFavorite ? .red : .white)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 24)
        }
        .redacted(reason: store.isLoading ? .placeholder : [])
        .shimmeringPlaceholder(isLoading: store.isLoading)
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
                    Text("placeholder text line 1...")
                    Text("placeholder text line 2...")
                    Text("placeholder text line 3...")
                }
                .shimmeringPlaceholder(isLoading: true)
                .padding(.horizontal, 24)
            }

            // Seasons Header
            if !store.seasons.isEmpty {
                Text("Sezonlar")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.seasons) { season in
                            let isSelected = store.selectedSeasonNumber == season.seasonNumber
                            Button {
                                store.send(.seasonSelected(season.seasonNumber))
                            } label: {
                                Text(season.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? Color.red : Color(hex: "#1A1A24"))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            // Episodes List
            if !store.currentEpisodes.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("episodes")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(store.currentEpisodes.count) bölüm")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .padding(.horizontal, 24)

                    LazyVStack(spacing: 16) {
                        ForEach(store.currentEpisodes) { episode in
                            episodeCard(episode)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            Spacer().frame(height: 40)
        }
        .redacted(reason: store.isLoading ? .placeholder : [])
        .shimmeringPlaceholder(isLoading: store.isLoading)
    }

    private func episodeCard(_ episode: DetailModels.Episode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                // Episode Image
                Group {
                    if let url = episode.coverURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case let .success(image):
                                image.resizable().scaledToFill()
                            default:
                                Rectangle().fill(Color(hex: "#2A2A30"))
                            }
                        }
                    } else {
                        Rectangle().fill(Color(hex: "#2A2A30"))
                    }
                }
                .frame(width: 140, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Episode Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(episode.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        if let rating = episode.rating, rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill").foregroundStyle(.yellow)
                                Text(String(format: "%.1f", rating)).foregroundStyle(.white)
                            }
                        }

                        if let duration = episode.duration {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text(duration)
                            }
                            .foregroundStyle(Color.white.opacity(0.6))
                        }
                    }
                    .font(.system(size: 12))

                    // Buttons row
                    HStack {
                        Button {
                            store.send(.episodeSelected(episode))
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("İzle")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }

                        Spacer()

                        let isDownloaded = store.downloadedEpisodes[episode.id] == true
                        Button {
                            store.send(.downloadEpisode(episode))
                        } label: {
                            Image(systemName: isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
                                .font(.system(size: 16))
                                .padding(8)
                                .background(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1).background(Circle().fill(isDownloaded ? Color.green.opacity(0.2) : Color.clear)))
                                .foregroundStyle(isDownloaded ? .green : .white)
                        }
                    }
                }
            }

            if let plot = episode.plot, !plot.isEmpty {
                Text(plot)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(16)
        .background(Color(hex: "#1A1A24"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
