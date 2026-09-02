#if os(iOS)
    import ComposableArchitecture
    import FactoryKit
    import SwiftUI

    public struct DashboardView_iOS: View {
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

                ScrollView {
                    VStack(spacing: 24) {
                        if store.isLoading {
                            loadingView
                        } else if let error = store.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                        } else {
                            // Hero Banner
                            if let heroVOD = store.featuredVODs.first {
                                HeroBannerView(vod: heroVOD) {
                                    store.send(.vodSelected(heroVOD))
                                }
                                .padding(.bottom, 16)
                            }

                            if !store.watchHistoryItems.isEmpty {
                                featuredSection(title: "Kaldığın Yerden İzle", items: store.watchHistoryItems) { hist in
                                    WatchHistoryCardView(item: hist) {
                                        store.send(.historySelected(hist))
                                    }
                                    .frame(width: 200)
                                }
                            }

                            if !store.favoriteItems.isEmpty {
                                featuredSection(title: "Favorilerim", items: store.favoriteItems) { fav in
                                    FavoriteCardView(item: fav) {
                                        store.send(.favoriteSelected(fav))
                                    }
                                    .frame(width: 140)
                                }
                            }

                            if !store.featuredChannels.isEmpty {
                                featuredSection(title: "Canlı TV (Önerilen)", items: store.featuredChannels) { channel in
                                    ChannelCardView(channel: channel, isSelected: false) {
                                        store.send(.channelSelected(channel))
                                    }
                                    .frame(width: 240)
                                }
                            }

                            if store.featuredVODs.count > 1 {
                                featuredSection(title: "Yeni Eklenen Filmler", items: Array(store.featuredVODs.dropFirst())) { vod in
                                    VODCardView(vod: vod, isSelected: false) {
                                        store.send(.vodSelected(vod))
                                    }
                                    .frame(width: 140)
                                }
                            }

                            if !store.featuredSeries.isEmpty {
                                featuredSection(title: "Yeni Eklenen Diziler", items: store.featuredSeries) { series in
                                    SeriesCardView(series: series, isSelected: false) {
                                        store.send(.seriesSelected(series))
                                    }
                                    .frame(width: 140)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .onAppear {
                if let url = URL(string: serverURL) {
                    store.send(.onAppear(config: PlaylistConfig(type: .xtream, serverURL: url, username: username, password: password)))
                }
            }
        }

        private func featuredSection<T: Identifiable>(
            title: String,
            items: [T],
            @ViewBuilder content: @escaping (T) -> some View
        ) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
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

        private var loadingView: some View {
            VStack(spacing: 24) {
                // Skeleton for Channels
                VStack(alignment: .leading, spacing: 12) {
                    Text("Yükleniyor...")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .shimmeringPlaceholder(isLoading: true)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0 ..< 5, id: \.self) { _ in
                                ChannelCardView(channel: .placeholder, isSelected: false) {}
                                    .frame(width: 240)
                                    .shimmeringPlaceholder(isLoading: true)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // Skeleton for VODs
                VStack(alignment: .leading, spacing: 12) {
                    Text("Yükleniyor...")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .shimmeringPlaceholder(isLoading: true)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0 ..< 5, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "#1F1F23"))
                                    .frame(width: 140, height: 210)
                                    .shimmeringPlaceholder(isLoading: true)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    struct HeroBannerView: View {
        let vod: MediaModels.Item
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                ZStack(alignment: .bottomLeading) {
                    // Poster/Backdrop
                    if let url = vod.coverURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(hex: "#1F1F23").shimmeringPlaceholder(isLoading: true)
                        }
                        .frame(height: 450)
                        .clipped()
                    } else {
                        Color(hex: "#1F1F23").frame(height: 450)
                    }

                    // Premium Gradient
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.0), location: 0.0),
                            .init(color: .black.opacity(0.4), location: 0.6),
                            .init(color: .black.opacity(0.9), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text(vod.title)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-0.5) // Optical sizing fix for large text
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3)

                        if let rating = vod.rating, rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill").foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        }

                        HStack {
                            Image(systemName: "play.fill")
                            Text("Hemen İzle")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .buttonStyle(.fluidScale)
        }
    }

    struct FavoriteCardView: View {
        let item: FavoriteItem
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    if let urlString = item.coverURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case let .success(image):
                                image.resizable().scaledToFill()
                            default:
                                Rectangle().fill(Color(hex: "#1F1F23"))
                            }
                        }
                        .frame(width: 140, height: item.type == "live" ? 90 : 210)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                                .padding(8)
                        }
                    } else {
                        Rectangle()
                            .fill(Color(hex: "#1F1F23"))
                            .frame(width: 140, height: item.type == "live" ? 90 : 210)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.fluidScale)
        }
    }

    struct WatchHistoryCardView: View {
        let item: WatchHistoryItem
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .bottomLeading) {
                        if let urlString = item.coverURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case let .success(image):
                                    image.resizable().scaledToFill()
                                default:
                                    Rectangle().fill(Color(hex: "#1F1F23"))
                                }
                            }
                            .frame(width: 200, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Rectangle()
                                .fill(Color(hex: "#1F1F23"))
                                .frame(width: 200, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Progress Bar overlay
                        GeometryReader { proxy in
                            let progressPercent = max(0, min(1, item.progress / item.duration))
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

                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let seriesTitle = item.seriesTitle {
                        Text(seriesTitle)
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.fluidScale)
        }
    }
#endif
