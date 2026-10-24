#if os(iOS)
    import ComposableArchitecture
    import FactoryKit
    import SwiftUI

    public struct DashboardView_iOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        let config: PlaylistConfig
        @State private var isHomeSettingsPresented = false

        public init(store: StoreOf<DashboardFeature>, config: PlaylistConfig) {
            self.store = store
            self.config = config
        }

        public init(store: StoreOf<DashboardFeature>, serverURL: String, username: String, password: String) {
            self.store = store
            if (username.isEmpty && password.isEmpty) || serverURL.lowercased().contains(".m3u") {
                config = PlaylistConfig(type: .m3u, m3uURL: URL(string: serverURL))
            } else {
                config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
            }
        }

        public var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Top Switcher Bar
                        HStack(spacing: 8) {
                            Text(AppStrings.Dashboard.title)
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Spacer()

                            VPNStatusBadge(compact: true)

                            Button {
                                isHomeSettingsPresented = true
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color(hex: "#0A84FF"))
                                    .frame(width: 44, height: 44)
                                    .background(Color(hex: "#1F1F23"), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Ana Ekranı Düzenle")

                            Button {
                                store.send(.openManagePlaylistsTapped)
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text(store.activePlaylistName.isEmpty ? AppStrings.PlaylistMgmt.accountManagement : store.activePlaylistName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(Color(hex: "#0A84FF"))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#1F1F23"))
                                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        if store.isLoading {
                            loadingView
                        } else if let error = store.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                        } else {
                            ForEach(store.homeSections.filter(\.isVisible)) { section in
                                homeSectionView(section)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .onAppear {
                store.send(.onAppear(config: config))
            }
            .onDisappear {
                store.send(.onDisappear)
            }
            .sheet(isPresented: $isHomeSettingsPresented, onDismiss: {
                store.send(.onAppear(config: config))
            }) {
                ModularHomeSettingsView()
            }
        }

        @ViewBuilder
        private func homeSectionView(_ section: HomeSectionConfig) -> some View {
            let isHeroVisible = store.homeSections.contains { $0.type == .hero && $0.isVisible }
            let newMovieItems = Array(store.featuredVODs.dropFirst(isHeroVisible ? 1 : 0))
            switch section.type {
            case .hero:
                if let heroVOD = store.featuredVODs.first {
                    HeroBannerView(vod: heroVOD) { store.send(.vodSelected(heroVOD)) }
                        .padding(.bottom, 8)
                }
            case .continueWatching:
                if !store.continueWatchingItems.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.continueWatching, items: store.continueWatchingItems) { item in
                        ResumeWatchingCardView(item: item, userAgentOverride: config.userAgentOverride,
                                               onResume: { store.send(.historySelected(item)) },
                                               onRestart: { store.send(.restartHistorySelected(item)) },
                                               onDelete: { store.send(.deleteHistorySelected(item)) })
                    }
                }
            case .favorites:
                if !store.favoriteItems.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.myFavorites, items: store.favoriteItems) { item in
                        FavoriteCardView(item: item, userAgentOverride: config.userAgentOverride) {
                            store.send(.favoriteSelected(item))
                        }
                        .frame(width: 140)
                    }
                }
            case .featuredLiveTV:
                if !store.featuredChannels.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.featuredLiveTV, items: store.featuredChannels) { channel in
                        ChannelCardView(channel: channel, isSelected: false) { store.send(.channelSelected(channel)) }
                            .frame(width: 240)
                    }
                }
            case .sportsHub:
                if store.isSportsHubVisible, !store.epgEvents.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.epgPrograms, items: store.epgEvents) { event in
                        DashboardEPGEventCard(event: event) { store.send(.channelSelected(event.channel)) }
                            .frame(width: 260)
                    }
                }
            case .recommendations:
                if !store.recommendedVODs.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.recommendedForYou, items: store.recommendedVODs) { vod in
                        VODCardView(vod: vod, isSelected: false) { store.send(.vodSelected(vod)) }
                            .frame(width: 140)
                    }
                }
            case .recentlyAddedVOD:
                if !newMovieItems.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.newMovies, items: newMovieItems) { vod in
                        VODCardView(vod: vod, isSelected: false) { store.send(.vodSelected(vod)) }
                            .frame(width: 140)
                    }
                }
            case .trendingSeries:
                if !store.featuredSeries.isEmpty {
                    featuredSection(title: AppStrings.Dashboard.newSeries, items: store.featuredSeries) { series in
                        SeriesCardView(series: series, isSelected: false) { store.send(.seriesSelected(series)) }
                            .frame(width: 140)
                    }
                }
            case .discoverCollections:
                ForEach(store.exploreCollections) { collection in
                    featuredSection(title: collection.title, items: collection.items) { item in
                        if item.type == .series {
                            SeriesCardView(series: item, isSelected: false) { store.send(.seriesSelected(item)) }
                                .frame(width: 140)
                        } else {
                            VODCardView(vod: item, isSelected: false) { store.send(.vodSelected(item)) }
                                .frame(width: 140)
                        }
                    }
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
                    Text(AppStrings.Common.loading)
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
                    Text(AppStrings.Common.loading)
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
                        PlaylistAsyncImage(url: url, userAgentOverride: vod.userAgentOverride) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color(hex: "#0F0F13").shimmeringPlaceholder(isLoading: true)
                            }
                        }
                        .frame(height: 520)
                        .clipped()
                    } else {
                        Color(hex: "#0F0F13").frame(height: 520)
                    }

                    // Premium Gradients for readability and fade
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.0), location: 0.3),
                            .init(color: .black.opacity(0.6), location: 0.7),
                            .init(color: .black, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.7), location: 0.0),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    // Content
                    VStack(alignment: .leading, spacing: 12) {
                        Text(vod.title)
                            .font(.system(size: 34, weight: .heavy, design: .default))
                            .lineSpacing(-2)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 4)

                        // Tags (Rating, Year, etc.)
                        HStack(spacing: 12) {
                            if let rating = vod.rating, rating > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill").foregroundColor(Color(hex: "#FFD700"))
                                    Text(String(format: "%.1f", rating))
                                        .fontWeight(.bold)
                                }
                            }

                            Text(AppStrings.Dashboard.hdBadge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.5), lineWidth: 1))

                            Text(AppStrings.Dashboard.movieBadge)
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.8))

                        // Action Buttons
                        HStack(spacing: 16) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(AppStrings.Common.watchNow)
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 4)

                            HStack {
                                Image(systemName: "info.circle")
                                Text(AppStrings.Dashboard.details)
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.2))
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                }
            }
            .buttonStyle(.fluidScale)
        }
    }

    struct FavoriteCardView: View {
        let item: FavoriteItem
        let userAgentOverride: String?
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    if let urlString = item.coverURL, let url = URL(string: urlString) {
                        PlaylistAsyncImage(url: url, userAgentOverride: userAgentOverride) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
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
        let userAgentOverride: String?
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .bottomLeading) {
                        if let urlString = item.coverURL, let url = URL(string: urlString) {
                            PlaylistAsyncImage(url: url, userAgentOverride: userAgentOverride) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
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
