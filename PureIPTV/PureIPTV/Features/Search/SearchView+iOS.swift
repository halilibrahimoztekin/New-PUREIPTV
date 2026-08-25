#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SearchView_iOS: View {
        @Bindable var store: StoreOf<SearchFeature>
        let serverURL: String
        let username: String
        let password: String

        /// Columns for grids
        private let channelColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 155, maximum: 200), spacing: 12),
        ]
        private let mediaColumns: [GridItem] = [
            GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 12),
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
                    } else if store.hasLoaded && store.searchQuery.isEmpty {
                        emptyStateView("Aramaya Başlayın", icon: "magnifyingglass")
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

                TextField("Kanal, film veya dizi ara...", text: $store.searchQuery.sending(\.queryChanged))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

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
                            Text(filter.rawValue)
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
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
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
                        resultSection(title: "Canlı TV", count: live.count) {
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
                        resultSection(title: "Filmler", count: vods.count) {
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
                        resultSection(title: "Diziler", count: seriesList.count) {
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

        private func resultSection<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("\(count) sonuç")
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
                Text("Arama altyapısı hazırlanıyor...\n(Bu işlem ilk girişte birkaç saniye sürebilir)")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.7))
                Spacer()
            }
            .padding()
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
