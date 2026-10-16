#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS Dashboard View

    public struct DashboardView_tvOS: View {
        @Bindable var store: StoreOf<DashboardFeature>
        let config: PlaylistConfig

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
                DynamicMeshBackgroundView(
                    imageURL: store.featuredVODs.first?.coverURL,
                    titleSeed: store.featuredVODs.first?.title ?? "PureIPTV"
                )

                if store.isLoading {
                    tvLoadingView
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 50) {
                            // Top Bar: Active Playlist Fast Switcher
                            HStack {
                                Spacer()
                                Button {
                                    store.send(.openManagePlaylistsTapped)
                                } label: {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 12, height: 12)
                                        Text(store.activePlaylistName.isEmpty ? AppStrings.PlaylistMgmt.accountManagement : store.activePlaylistName)
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Color(hex: "#0A84FF"))
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                            }
                            .padding(.horizontal, 60)
                            .padding(.top, 20)

                            // Hero Banner with Focus Guide Boundary
                            if let heroVOD = store.featuredVODs.first {
                                TVHeroBanner(vod: heroVOD) {
                                    store.send(.vodSelected(heroVOD))
                                }
                                .focusGuideBoundary()
                            }

                            // Continue Watching
                            if !store.watchHistoryItems.isEmpty {
                                TVShelfSection(title: AppStrings.Dashboard.continueWatching) {
                                    ForEach(store.watchHistoryItems) { hist in
                                        ResumeWatchingCardView(
                                            item: hist,
                                            onResume: {
                                                store.send(.historySelected(hist))
                                            },
                                            onRestart: {
                                                store.send(.restartHistorySelected(hist))
                                            },
                                            onDelete: {
                                                store.send(.deleteHistorySelected(hist))
                                            }
                                        )
                                    }
                                }
                            }

                            // Favorites
                            if !store.favoriteItems.isEmpty {
                                TVShelfSection(title: AppStrings.Dashboard.myFavorites) {
                                    ForEach(store.favoriteItems) { fav in
                                        TVFavoriteMediaCard(item: fav) {
                                            store.send(.favoriteSelected(fav))
                                        }
                                        .frame(width: fav.type.lowercased() == "live" ? 340 : 220)
                                        .contextMenu {
                                            Button {
                                                store.send(.favoriteSelected(fav))
                                            } label: {
                                                Label(AppStrings.Common.watchNow, systemImage: "play.fill")
                                            }

                                            Button(role: .destructive) {
                                                store.send(.deleteFavorite(fav))
                                            } label: {
                                                Label(AppStrings.Common.removeFromFavorites, systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }

                            // Live TV
                            if !store.featuredChannels.isEmpty {
                                TVShelfSection(title: AppStrings.Dashboard.featuredLiveTV) {
                                    ForEach(store.featuredChannels) { channel in
                                        TVChannelCard(channel: channel, isSelected: false) {
                                            store.send(.channelSelected(channel))
                                        }
                                        .frame(width: 340)
                                        .contextMenu {
                                            Button {
                                                store.send(.toggleFavorite(item: channel, type: "live"))
                                            } label: {
                                                if store.favoriteIDs.contains(channel.id) {
                                                    Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                                                } else {
                                                    Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                                                }
                                            }

                                            Button {
                                                store.send(.channelSelected(channel))
                                            } label: {
                                                Label(AppStrings.Common.watchNow, systemImage: "play.fill")
                                            }
                                        }
                                    }
                                }
                            }

                            // New Movies
                            if store.featuredVODs.count > 1 {
                                TVShelfSection(title: AppStrings.Dashboard.newMovies) {
                                    ForEach(Array(store.featuredVODs.dropFirst())) { vod in
                                        TVVODCard(vod: vod, isSelected: false) {
                                            store.send(.vodSelected(vod))
                                        }
                                        .frame(width: 220)
                                        .contextMenu {
                                            Button {
                                                store.send(.toggleFavorite(item: vod, type: "vod"))
                                            } label: {
                                                if store.favoriteIDs.contains(vod.id) {
                                                    Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                                                } else {
                                                    Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                                                }
                                            }

                                            Button {
                                                store.send(.vodSelected(vod))
                                            } label: {
                                                Label("Detayları Gör", systemImage: "info.circle")
                                            }
                                        }
                                    }
                                }
                            }

                            // New Series
                            if !store.featuredSeries.isEmpty {
                                TVShelfSection(title: AppStrings.Dashboard.newSeries) {
                                    ForEach(store.featuredSeries) { series in
                                        TVSeriesCard(series: series, isSelected: false) {
                                            store.send(.seriesSelected(series))
                                        }
                                        .frame(width: 220)
                                        .contextMenu {
                                            Button {
                                                store.send(.toggleFavorite(item: series, type: "series"))
                                            } label: {
                                                if store.favoriteIDs.contains(series.id) {
                                                    Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                                                } else {
                                                    Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                                                }
                                            }

                                            Button {
                                                store.send(.seriesSelected(series))
                                            } label: {
                                                Label("Bölümleri Gör", systemImage: "list.number")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 80)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: store.isLoading)
                    }
                }
            }
            .onAppear {
                store.send(.onAppear(config: config))
            }
        }

        private var tvLoadingView: some View {
            VStack(spacing: 32) {
                ProgressView()
                    .tint(Color(hex: "#0A84FF"))
                    .scaleEffect(2.0)
                Text(AppStrings.Common.loadingAlt)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.6))
            }
            .transition(.opacity)
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

                    // Premium Gradient
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.0), location: 0.0),
                            .init(color: .black.opacity(0.5), location: 0.6),
                            .init(color: .black.opacity(0.95), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Content
                    VStack(alignment: .leading, spacing: 16) {
                        Text(vod.title)
                            .font(.system(size: 52, weight: .bold))
                            .tracking(-1.0) // Optical sizing fix for tvOS large text
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)

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
                            Text(AppStrings.Common.watchNow)
                        }
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                    }
                    .padding(60)
                }
            }
            .buttonStyle(.card)
        }
    }

    // MARK: - TV Shelf Section

    private struct TVShelfSection<Content: View>: View {
        let title: String
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.system(size: 38, weight: .bold)) // 10-foot UI size
                    .foregroundStyle(.white)
                    .padding(.horizontal, 60)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 40) {
                        content()
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 40)
                }
                .focusSection()
                .focusGuideBoundary()
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
            .buttonStyle(.card)
        }
    }

#endif
