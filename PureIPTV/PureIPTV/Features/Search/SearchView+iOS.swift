#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SearchView_iOS: View {
        @Bindable var store: StoreOf<SearchFeature>
        let config: PlaylistConfig

        /// Columns for grids
        private let channelColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 155, maximum: 200), spacing: 12),
        ]
        private let mediaColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 12),
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

                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    // Filters
                    filterBar
                        .padding(.bottom, 12)

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
            // Dismiss keyboard when scrolling
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }

        // MARK: – UI Components

        private var searchBar: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))

                TextField(AppStrings.Search.searchPlaceholder, text: $store.searchQuery.sending(\.queryChanged))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if store.isSearching {
                    ProgressView()
                        .tint(Color(hex: "#0A84FF"))
                        .scaleEffect(0.8)
                        .padding(.trailing, 4)
                }

                if !store.searchQuery.isEmpty {
                    Button(action: { store.send(.queryChanged("")) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#1F1F23"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }

        private var filterBar: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SearchFeature.SearchFilter.allCases, id: \.self) { filter in
                        let isSelected = store.filter == filter
                        Button {
                            store.send(.filterChanged(filter))
                        } label: {
                            Text(filter.title)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? .white : Color(hex: "#C0C6D6").opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color(hex: "#0A84FF") : Color(hex: "#1F1F23"))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                    }
                }
                .padding(.horizontal, 16)
            }
        }

        private var resultsScrollView: some View {
            ScrollView {
                VStack(spacing: 24) {
                    let live = store.liveResults
                    if !live.isEmpty {
                        resultSection(title: AppStrings.Search.liveTV, count: live.count) {
                            LazyVGrid(columns: channelColumns, spacing: 12) {
                                ForEach(live) { channel in
                                    ChannelCardView(channel: channel) {
                                        store.send(.channelSelected(channel))
                                    }
                                }
                            }
                        }
                    }

                    let vods = store.vodResults
                    if !vods.isEmpty {
                        resultSection(title: AppStrings.Search.movies, count: vods.count) {
                            LazyVGrid(columns: mediaColumns, spacing: 12) {
                                ForEach(vods) { vod in
                                    VODCardView(vod: vod) {
                                        store.send(.vodSelected(vod))
                                    }
                                }
                            }
                        }
                    }

                    let seriesList = store.seriesResults
                    if !seriesList.isEmpty {
                        resultSection(title: AppStrings.Search.series, count: seriesList.count) {
                            LazyVGrid(columns: mediaColumns, spacing: 12) {
                                ForEach(seriesList) { series in
                                    SeriesCardView(series: series) {
                                        store.send(.seriesSelected(series))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }

        private var emptySearchDiscoveryView: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Recent Searches Section
                    if !store.recentSearches.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label(AppStrings.Search.recentSearches, systemImage: "clock.arrow.circlepath")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Button {
                                    store.send(.clearHistoryTapped)
                                } label: {
                                    Text(AppStrings.Search.clear)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color(hex: "#0A84FF"))
                                }
                            }

                            VStack(spacing: 0) {
                                ForEach(store.recentSearches.prefix(6), id: \.id) { item in
                                    Button {
                                        store.send(.recentSearchTapped(item.query))
                                    } label: {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(Color(hex: "#C0C6D6").opacity(0.5))
                                                .font(.system(size: 14))
                                            Text(item.query)
                                                .font(.system(size: 15))
                                                .foregroundColor(Color(hex: "#E4E1E7"))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(hex: "#C0C6D6").opacity(0.3))
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(hex: "#1F1F23").opacity(0.5))
                                    }
                                    .buttonStyle(.plain)

                                    if item.id != store.recentSearches.prefix(6).last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.05))
                                            .padding(.leading, 40)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "#1F1F23"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                        }
                    }

                    // Quick Discovery Categories & Tags
                    VStack(alignment: .leading, spacing: 14) {
                        Label(AppStrings.Search.quickTags, systemImage: "sparkles")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 200), spacing: 12)], spacing: 12) {
                            ForEach(store.quickTags) { tag in
                                Button {
                                    store.send(.tagSelected(tag))
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color(hex: tag.hexColor).opacity(0.18))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: tag.icon)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(Color(hex: tag.hexColor))
                                        }

                                        Text(tag.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.3))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color(hex: "#18181D"))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }

        private func resultSection(title: String, count: Int, @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("\(count) \(AppStrings.Common.results)")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))
                        .padding(.bottom, 2)
                }
                content()
            }
        }

        private var loadingView: some View {
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .tint(Color(hex: "#0A84FF"))
                    .scaleEffect(1.2)
                Text(AppStrings.Search.loadingMessage)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.7))
                Spacer()
            }
            .padding()
        }

        private var searchingView: some View {
            VStack(spacing: 14) {
                Spacer()
                ProgressView()
                    .tint(Color(hex: "#0A84FF"))
                    .scaleEffect(1.1)
                Text(AppStrings.Common.loading)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.6))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func emptyStateView(_ message: String, icon: String) -> some View {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.3))
                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func errorView(_ error: String) -> some View {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.red.opacity(0.7))
                Text(error)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.7))
                    .padding(.horizontal, 24)
                Spacer()
            }
        }
    }
#endif
