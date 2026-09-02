#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SearchView_tvOS: View {
        @Bindable var store: StoreOf<SearchFeature>
        let serverURL: String
        let username: String
        let password: String

        /// Columns for grids (wider for tvOS)
        private let channelColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 40),
        ]
        private let mediaColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 40),
        ]

        public init(store: StoreOf<SearchFeature>, serverURL: String, username: String, password: String) {
            self.store = store
            self.serverURL = serverURL
            self.username = username
            self.password = password
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
                        if store.recentSearches.isEmpty {
                            emptyStateView("Aramaya Başlayın", icon: "magnifyingglass")
                        } else {
                            recentSearchesView
                        }
                    } else if store.totalResultsCount == 0 {
                        emptyStateView("Sonuç Bulunamadı", icon: "doc.text.magnifyingglass")
                    } else {
                        resultsScrollView
                    }
                }
            }
            .onAppear {
                if let url = URL(string: serverURL) {
                    store.send(.onAppear(config: PlaylistConfig(type: .xtream, serverURL: url, username: username, password: password)))
                }
            }
        }

        // MARK: – UI Components

        private var searchBar: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))
                    .font(.system(size: 32))

                TextField("Kanal, film veya dizi ara...", text: $store.searchQuery.sending(\.queryChanged))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 32))

                if !store.searchQuery.isEmpty {
                    Button(action: { store.send(.queryChanged("")) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: "#C0C6D6").opacity(0.6))
                            .font(.system(size: 32))
                    }
                    .buttonStyle(.plain)
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
                            Text(filter.rawValue)
                                .font(.system(size: 24, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? .white : Color(hex: "#C0C6D6").opacity(0.7))
                                .padding(.horizontal, 30)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color(hex: "#0A84FF") : Color(hex: "#1F1F23"))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(isSelected ? 0 : 0.1), lineWidth: 2)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
                        resultSection(title: "Canlı TV", count: live.count) {
                            LazyVGrid(columns: channelColumns, spacing: 40) {
                                ForEach(live) { channel in
                                    Button {
                                        store.send(.channelSelected(channel))
                                    } label: {
                                        ChannelCardView(channel: channel, isSelected: false) {}
                                    }
                                    .buttonStyle(.card)
                                }
                            }
                        }
                    }

                    let vods = store.vodResults
                    if !vods.isEmpty {
                        resultSection(title: "Filmler", count: vods.count) {
                            LazyVGrid(columns: mediaColumns, spacing: 40) {
                                ForEach(vods) { vod in
                                    Button {
                                        store.send(.vodSelected(vod))
                                    } label: {
                                        VODCardView(vod: vod, isSelected: false) {}
                                    }
                                    .buttonStyle(.card)
                                }
                            }
                        }
                    }

                    let seriesList = store.seriesResults
                    if !seriesList.isEmpty {
                        resultSection(title: "Diziler", count: seriesList.count) {
                            LazyVGrid(columns: mediaColumns, spacing: 40) {
                                ForEach(seriesList) { series in
                                    Button {
                                        store.send(.seriesSelected(series))
                                    } label: {
                                        SeriesCardView(series: series, isSelected: false) {}
                                    }
                                    .buttonStyle(.card)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 60)
            }
        }

        private var recentSearchesView: some View {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Son Aramalar")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        store.send(.clearHistoryTapped)
                    } label: {
                        Text("Temizle")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#0A84FF"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 60)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.recentSearches, id: \.id) { item in
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
                            .buttonStyle(.plain)

                            if item.id != store.recentSearches.last?.id {
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
                    .padding(.horizontal, 60)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }

        private func resultSection(title: String, count: Int, @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .bottom) {
                    Text(title)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(count) sonuç")
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
                ProgressView()
                    .tint(Color(hex: "#0A84FF"))
                    .scaleEffect(2.0)
                Text("Arama altyapısı hazırlanıyor...\n(Bu işlem ilk girişte birkaç saniye sürebilir)")
                    .font(.system(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.7))
                Spacer()
            }
            .padding()
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
