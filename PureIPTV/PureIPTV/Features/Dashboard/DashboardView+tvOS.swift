#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS Dashboard View

    public struct DashboardView_tvOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        let serverURL: String
        let username: String
        let password: String

        public init(store: StoreOf<DashboardFeature>, serverURL: String, username: String, password: String) {
            self.store = store
            self.serverURL = serverURL
            self.username = username
            self.password = password
        }

        public var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                if store.isLoading {
                    tvLoadingView
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 60) {
                            // Hero Banner
                            if let heroVOD = store.featuredVODs.first {
                                TVHeroBanner(vod: heroVOD) {
                                    store.send(.vodSelected(heroVOD))
                                }
                            }

                            // Continue Watching
                            if !store.watchHistoryItems.isEmpty {
                                TVShelfSection(title: "Kaldığın Yerden İzle") {
                                    ForEach(store.watchHistoryItems) { hist in
                                        TVWatchHistoryCard(item: hist) {
                                            store.send(.historySelected(hist))
                                        }
                                    }
                                }
                            }

                            // Favorites
                            if !store.favoriteItems.isEmpty {
                                TVShelfSection(title: "Favorilerim") {
                                    ForEach(store.favoriteItems) { fav in
                                        TVFavoriteCard(item: fav) {
                                            store.send(.favoriteSelected(fav))
                                        }
                                    }
                                }
                            }

                            // Live TV
                            if !store.featuredChannels.isEmpty {
                                TVShelfSection(title: "Canlı TV (Önerilen)") {
                                    ForEach(store.featuredChannels) { channel in
                                        Button {
                                            store.send(.channelSelected(channel))
                                        } label: {
                                            ChannelCardView(channel: channel, isSelected: false) {}
                                        }
                                        .buttonStyle(.card)
                                        .frame(width: 360)
                                    }
                                }
                            }

                            // New Movies
                            if store.featuredVODs.count > 1 {
                                TVShelfSection(title: "Yeni Eklenen Filmler") {
                                    ForEach(Array(store.featuredVODs.dropFirst())) { vod in
                                        Button {
                                            store.send(.vodSelected(vod))
                                        } label: {
                                            VODCardView(vod: vod, isSelected: false) {}
                                        }
                                        .buttonStyle(.card)
                                        .frame(width: 220)
                                    }
                                }
                            }

                            // New Series
                            if !store.featuredSeries.isEmpty {
                                TVShelfSection(title: "Yeni Eklenen Diziler") {
                                    ForEach(store.featuredSeries) { series in
                                        Button {
                                            store.send(.seriesSelected(series))
                                        } label: {
                                            SeriesCardView(series: series, isSelected: false) {}
                                        }
                                        .buttonStyle(.card)
                                        .frame(width: 220)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
            }
            .onAppear {
                if let url = URL(string: serverURL) {
                    store.send(.onAppear(config: PlaylistConfig(type: .xtream, serverURL: url, username: username, password: password)))
                }
            }
        }

        private var tvLoadingView: some View {
            VStack(spacing: 32) {
                ProgressView()
                    .tint(Color(hex: "#0A84FF"))
                    .scaleEffect(2.0)
                Text("Yükleniyor…")
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
            }
        }
    }

    // MARK: - TV Hero Banner

    private struct TVHeroBanner: View {
        let vod: MediaModels.Item
        let onTap: () -> Void

        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Button(action: onTap) {
                ZStack(alignment: .bottomLeading) {
                    if let url = vod.coverURL {
                        KFImage(url)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 600)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(hex: "#1F1F23"))
                            .frame(height: 600)
                    }

                    // Gradient
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.9)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    // Content
                    VStack(alignment: .leading, spacing: 16) {
                        Text(vod.title)
                            .font(.system(size: 52, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 4)

                        if let rating = vod.rating, rating > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill").foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                            }
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                            Text("Hemen İzle")
                        }
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .padding(60)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .shadow(color: isFocused ? Color(hex: "#0A84FF").opacity(0.4) : .clear, radius: 20, x: 0, y: 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        }
    }

    // MARK: - TV Shelf Section

    private struct TVShelfSection<Content: View>: View {
        let title: String
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: 24) {
                Text(title)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 60)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 40) {
                        content()
                    }
                    .padding(.horizontal, 60)
                }
            }
        }
    }

    // MARK: - TV Watch History Card

    private struct TVWatchHistoryCard: View {
        let item: WatchHistoryItem
        let onTap: () -> Void

        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack(alignment: .bottomLeading) {
                        if let urlString = item.coverURL, let url = URL(string: urlString) {
                            KFImage(url)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 320, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(hex: "#1F1F23"))
                                .frame(width: 320, height: 180)
                        }

                        // Progress bar
                        let progressPercent = item.duration > 0 ? max(0, min(1, item.progress / item.duration)) : 0
                        VStack {
                            Spacer()
                            GeometryReader { proxy in
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 4)
                                    .overlay(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.red)
                                            .frame(width: proxy.size.width * CGFloat(progressPercent), height: 4)
                                    }
                            }
                            .frame(height: 4)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                        }
                    }

                    Text(item.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(width: 320, alignment: .leading)

                    if let seriesTitle = item.seriesTitle {
                        Text(seriesTitle)
                            .font(.system(size: 16))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .lineLimit(1)
                            .frame(width: 320, alignment: .leading)
                    }
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .shadow(color: isFocused ? Color(hex: "#0A84FF").opacity(0.5) : .clear, radius: 14, x: 0, y: 4)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
        }
    }

    // MARK: - TV Favorite Card

    private struct TVFavoriteCard: View {
        let item: FavoriteItem
        let onTap: () -> Void

        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 12) {
                    if let urlString = item.coverURL, let url = URL(string: urlString) {
                        KFImage(url)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 220, height: item.type == "live" ? 140 : 330)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                    .font(.system(size: 20))
                                    .padding(10)
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "#1F1F23"))
                            .frame(width: 220, height: item.type == "live" ? 140 : 330)
                    }

                    Text(item.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(width: 220, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .shadow(color: isFocused ? Color(hex: "#0A84FF").opacity(0.5) : .clear, radius: 14, x: 0, y: 4)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
        }
    }
#endif
