import ComposableArchitecture
import SwiftUI

public struct VODDetailView: View {
    let store: StoreOf<VODDetailFeature>

    public init(store: StoreOf<VODDetailFeature>) {
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
                .ignoresSafeArea(edges: .top)
            }
            .onAppear {
                store.send(.onAppear)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.send(.closeTapped)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.4)))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var headerView: some View {
        ZStack(alignment: .bottom) {
            // Background Blur
            GeometryReader { proxy in
                let cover = store.tmdbMovie?.backdropPath.map { "https://image.tmdb.org/t/p/w780\($0)" } ??
                    store.tmdbMovie?.posterPath.map { "https://image.tmdb.org/t/p/w780\($0)" } ??
                    store.vod.coverURL?.absoluteString

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
                    .opacity(0.6)
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
                let cover = store.tmdbMovie?.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" } ?? store.vod.coverURL?.absoluteString

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
                    Text(store.tmdbMovie?.title ?? store.vod.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Buttons
                    HStack(spacing: 12) {
                        Button {
                            store.send(.playTapped)
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Şimdi İzle")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }

                        Button {
                            // Favorite toggle action could go here
                        } label: {
                            Image(systemName: "heart")
                                .font(.system(size: 20))
                                .padding(10)
                                .background(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                .foregroundStyle(.white)
                        }
                    }

                    // Rating
                    if let rating = store.tmdbMovie?.voteAverage ?? store.info?.rating, rating > 0 {
                        HStack(spacing: 4) {
                            ForEach(0 ..< 5) { index in
                                Image(systemName: index < Int(rating / 2) ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                                    .font(.system(size: 12))
                            }
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.leading, 4)
                        }
                    }

                    // Year, Duration, Status
                    HStack(spacing: 8) {
                        if let date = store.tmdbMovie?.releaseDate ?? store.info?.releaseDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(String(date.prefix(4)))
                            }
                        }

                        if let runtime = store.tmdbMovie?.runtime {
                            Text(verbatim: "•")
                            Text("\(runtime / 60) saat \(runtime % 60) dakika")
                        } else if let duration = store.info?.duration {
                            Text(verbatim: "•")
                            Text(duration)
                        }

                        if let status = store.tmdbMovie?.status ?? store.info?.status {
                            Text(verbatim: "•")
                            Text(status)
                                .font(.system(size: 10, weight: .bold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 140) // Space for safe area and close button
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Genres
            let genres = store.tmdbMovie?.genres?.map { $0.name } ?? store.info?.genre?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            if !genres.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Türler")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(genres, id: \.self) { genre in
                                Text(genre)
                                    .font(.system(size: 14))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.horizontal, 24)
            }

            // Overview
            let plot = store.tmdbMovie?.overview ?? store.info?.plot
            if let plotText = plot, !plotText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    Text(plotText)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .lineSpacing(4)
                }
                .padding(.horizontal, 24)
            }

            // Production Countries
            if let countries = store.tmdbMovie?.productionCountries, !countries.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Yapım Ülkeleri")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(countries, id: \.iso3166_1) { country in
                                Text(country.name)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "#163450"))
                                    .foregroundStyle(Color(hex: "#66B2FF"))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.horizontal, 24)
            }

            // Production Companies
            if let companies = store.tmdbMovie?.productionCompanies, !companies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Yapım Şirketleri")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(companies, id: \.id) { company in
                            Text(company.name)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            // IMDB Button
            if let imdbId = store.tmdbMovie?.imdbId {
                Button {
                    if let url = URL(string: "https://www.imdb.com/title/\(imdbId)") {
                        #if os(iOS)
                            UIApplication.shared.open(url)
                        #endif
                    }
                } label: {
                    HStack {
                        Image(systemName: "link")
                        Text("IMDb'de Görüntüle")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#1A1A24"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }

            // Similar Content
            if let similar = store.tmdbMovie?.similar?.results, !similar.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Benzer İçerikler")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(similar, id: \.id) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    let cover = item.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" }
                                    if let urlString = cover, let url = URL(string: urlString) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case let .success(image):
                                                image.resizable().scaledToFill()
                                            default:
                                                Rectangle().fill(Color(hex: "#2A2A30"))
                                            }
                                        }
                                        .frame(width: 110, height: 160)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(alignment: .topTrailing) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                                .background(Circle().fill(Color.black))
                                                .padding(6)
                                        }
                                    }

                                    Text(item.title ?? item.name ?? "")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                        .frame(width: 110, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }

            Spacer().frame(height: 40)
        }
        .padding(.top, 16)
    }
}
