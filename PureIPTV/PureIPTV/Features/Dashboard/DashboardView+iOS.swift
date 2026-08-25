#if os(iOS)
    import ComposableArchitecture
    import Factory
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

                            if !store.featuredChannels.isEmpty {
                                featuredSection(title: "Canlı TV (Önerilen)", items: store.featuredChannels) { channel in
                                    ChannelCardView(channel: channel, isSelected: false) {
                                        store.send(.channelSelected(channel))
                                    }
                                    .frame(width: 240)
                                }
                            }

                            if store.featuredVODs.count > 1 {
                                featuredSection(title: "Yeni Filmler", items: Array(store.featuredVODs.dropFirst())) { vod in
                                    VODCardView(vod: vod, isSelected: false) {
                                        store.send(.vodSelected(vod))
                                    }
                                    .frame(width: 140)
                                }
                            }

                            if !store.featuredSeries.isEmpty {
                                featuredSection(title: "Popüler Diziler", items: store.featuredSeries) { series in
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

        private func featuredSection<T: Identifiable, Content: View>(
            title: String,
            items: [T],
            @ViewBuilder content: @escaping (T) -> Content
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

                    // Gradient
                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text(vod.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)

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
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .buttonStyle(.plain)
        }
    }
#endif
