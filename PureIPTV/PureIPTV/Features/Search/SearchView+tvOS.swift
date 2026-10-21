#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SearchView_tvOS: View {
        @Bindable var store: StoreOf<SearchFeature>
        let config: PlaylistConfig

        /// Columns for grids (wider for tvOS)
        private let channelColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 40),
        ]
        private let mediaColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 40),
        ]

        public init(store: StoreOf<SearchFeature>, config: PlaylistConfig) {
            self.store = store
            self.config = config
        }

        public init(store: StoreOf<SearchFeature>, serverURL: String, username: String, password: String) {
            self.store = store
            if (username.isEmpty && password.isEmpty) || serverURL.lowercased().contains(".m3u") {
                config = PlaylistConfig(type: .m3u, m3uURL: URL(string: serverURL))
            } else {
                config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
            }
        }

        public var body: some View {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 40) {
                    // Search Bar
                    searchBar
                        .padding(.horizontal, 60)
                        .padding(.top, 40)

                    // Filters
                    filterBar
                        .padding(.bottom, 20)

                    // Results
                    if store.isLoading {
                        loadingView
                    } else if let error = store.errorMessage {
                        errorView(error)
                    } else if store.hasLoaded, store.searchQuery.isEmpty {
                        emptySearchDiscoveryView
                    } else if store.isSearching, store.totalResultsCount == 0 {
                        searchingView
                    } else if store.totalResultsCount == 0 {
                        emptyStateView(AppStrings.Search.noResults, icon: "doc.text.magnifyingglass")
                    } else {
                        resultsScrollView
                    }
                }
            }
            .onAppear {
                store.send(.onAppear(config: config))
            }
        }

        // MARK: – UI Components

        private var searchBar: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))
                    .font(.system(size: 32))

                TextField(AppStrings.Search.searchPlaceholder, text: $store.searchQuery.sending(\.queryChanged))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 32))

                if store.isSearching {
                    PureLoadingView(size: .small)
                        .padding(.trailing, 10)
                }

                if !store.searchQuery.isEmpty {
                    Button(action: { store.send(.queryChanged("")) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))
                            .font(.system(size: 28))
                            .padding(6)
                    }
                    .buttonStyle(TVCircleButtonStyle())
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#1F1F23"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 2)
                    )
            )
        }

        private var filterBar: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(SearchFeature.SearchFilter.allCases, id: \.self) { filter in
                        let isSelected = store.filter == filter
                        Button {
                            store.send(.filterChanged(filter))
                        } label: {
                            Text(filter.title)
                                .font(.system(size: 24, weight: isSelected ? .bold : .medium))
                                .padding(.horizontal, 30)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: isSelected))
                    }
                }
                .padding(.horizontal, 60)
            }
        }

        private var resultsScrollView: some View {
            ScrollView {
                VStack(spacing: 60) {
                    let live = store.liveResults
                    if !live.isEmpty {
                        resultSection(title: AppStrings.Search.liveTV, count: live.count) {
                            LazyVGrid(columns: channelColumns, spacing: 40) {
                                ForEach(live) { channel in
                                    TVChannelCard(channel: channel, isSelected: false) {
                                        store.send(.channelSelected(channel))
                                    }
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
                    }

                    let vods = store.vodResults
                    if !vods.isEmpty {
                        resultSection(title: AppStrings.Search.movies, count: vods.count) {
                            LazyVGrid(columns: mediaColumns, spacing: 40) {
                                ForEach(vods) { vod in
                                    TVVODCard(vod: vod, isSelected: false) {
                                        store.send(.vodSelected(vod))
                                    }
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
                    }

                    let series = store.seriesResults
                    if !series.isEmpty {
                        resultSection(title: AppStrings.Search.series, count: series.count) {
                            LazyVGrid(columns: mediaColumns, spacing: 40) {
                                ForEach(series) { item in
                                    TVSeriesCard(series: item, isSelected: false) {
                                        store.send(.seriesSelected(item))
                                    }
                                    .contextMenu {
                                        Button {
                                            store.send(.toggleFavorite(item: item, type: "series"))
                                        } label: {
                                            if store.favoriteIDs.contains(item.id) {
                                                Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                                            } else {
                                                Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                                            }
                                        }

                                        Button {
                                            store.send(.seriesSelected(item))
                                        } label: {
                                            Label("Bölümleri Gör", systemImage: "list.number")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 60)
            }
        }

        private var emptySearchDiscoveryView: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 48) {
                    // Recent Searches (if available)
                    if !store.recentSearches.isEmpty {
                        VStack(alignment: .leading, spacing: 24) {
                            HStack {
                                Label(AppStrings.Search.recentSearches, systemImage: "clock.arrow.circlepath")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Button {
                                    store.send(.clearHistoryTapped)
                                } label: {
                                    Text(AppStrings.Search.clear)
                                        .font(.system(size: 20, weight: .semibold))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(TVCapsuleButtonStyle())
                            }

                            VStack(spacing: 0) {
                                ForEach(store.recentSearches.prefix(5), id: \.id) { item in
                                    Button {
                                        store.send(.recentSearchTapped(item.query))
                                    } label: {
                                        HStack {
                                            Image(systemName: "clock")
                                                .font(.system(size: 24))
                                                .foregroundColor(Color(hex: "#C0C6D6").opacity(0.5))
                                            Text(item.query)
                                                .font(.system(size: 28))
                                                .foregroundColor(Color(hex: "#E4E1E7"))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 24))
                                                .foregroundColor(Color(hex: "#C0C6D6").opacity(0.3))
                                        }
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 20)
                                        .background(Color(hex: "#1F1F23").opacity(0.5))
                                    }
                                    .buttonStyle(TVCategoryRowButtonStyle(accentColor: Color(hex: "#0A84FF"), isSelected: false))

                                    if item.id != store.recentSearches.prefix(5).last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.05))
                                            .padding(.leading, 70)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(hex: "#1F1F23"))
                            )
                        }
                    }

                    // Quick Discovery Categories & Tags
                    VStack(alignment: .leading, spacing: 28) {
                        Label(AppStrings.Search.quickTags, systemImage: "sparkles")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 30)], spacing: 30) {
                            ForEach(store.quickTags) { tag in
                                Button {
                                    store.send(.tagSelected(tag))
                                } label: {
                                    HStack(spacing: 20) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color(hex: tag.hexColor).opacity(0.2))
                                                .frame(width: 56, height: 56)
                                            Image(systemName: tag.icon)
                                                .font(.system(size: 28, weight: .semibold))
                                                .foregroundColor(Color(hex: tag.hexColor))
                                        }

                                        Text(tag.title)
                                            .font(.system(size: 26, weight: .semibold))
                                            .foregroundColor(.white)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(Color(hex: "#C0C6D6").opacity(0.4))
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 20)
                                }
                                .buttonStyle(TVCategoryRowButtonStyle(accentColor: Color(hex: tag.hexColor), isSelected: false))
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 60)
            }
        }

        private func resultSection(title: String, count: Int, @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .bottom) {
                    Text(title)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(count) \(AppStrings.Common.results)")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))
                        .padding(.bottom, 4)
                }
                content()
            }
        }

        private var loadingView: some View {
            VStack(spacing: 32) {
                Spacer()
                PureLoadingView(size: .large, text: AppStrings.Search.loadingMessage)
                Spacer()
            }
            .padding()
        }

        private var searchingView: some View {
            VStack(spacing: 24) {
                Spacer()
                PureLoadingView(size: .large, text: AppStrings.Common.loading)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func emptyStateView(_ message: String, icon: String) -> some View {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.3))
                Text(message)
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func errorView(_ error: String) -> some View {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 80))
                    .foregroundStyle(.red.opacity(0.7))
                Text(error)
                    .font(.system(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.7))
                    .padding(.horizontal, 60)
                Spacer()
            }
        }
    }
#endif
