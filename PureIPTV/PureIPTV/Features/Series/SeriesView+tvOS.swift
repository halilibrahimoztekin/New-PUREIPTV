#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS Series View

    public struct SeriesView_tvOS: View {
        @Bindable var store: StoreOf<SeriesFeature>
        let serverURL: String
        let username: String
        let password: String

        @FocusState private var focusedCategory: String?

        public init(store: StoreOf<SeriesFeature>, serverURL: String, username: String, password: String) {
            self.store = store
            self.serverURL = serverURL
            self.username = username
            self.password = password
        }

        public var body: some View {
            HStack(spacing: 0) {
                // ── Left: Category list ───────────────────────────────
                categoryColumn
                    .frame(width: 300)

                // ── Divider ───────────────────────────────────────────
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)

                // ── Right: Series grid ──────────────────────────────────
                seriesArea
            }
            .background(Color.black.ignoresSafeArea())
            .onAppear {
                if let url = URL(string: serverURL) {
                    store.send(.onAppear(config: PlaylistConfig(type: .xtream, serverURL: url, username: username, password: password)))
                }
            }
            .sheet(item: $store.scope(state: \.parentalLock, action: \.parentalLock)) { store in
                ParentalLockView(store: store)
            }
        }

        // MARK: – Category Column

        private var categoryColumn: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    HStack {
                        Text(AppStrings.Series.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(hex: "#E4E1E7"))
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 48)
                    .padding(.bottom, 16)

                    if store.isLoadingCategories {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color(hex: "#0A84FF"))
                            .padding(.top, 40)
                    } else {
                        ForEach(store.categories) { category in
                            TVSeriesCategoryRow(
                                category: category,
                                isSelected: store.selectedCategoryID == category.id
                            ) {
                                store.send(.categorySelected(category))
                            }
                            .padding(.horizontal, 16)
                            .focused($focusedCategory, equals: category.id)
                        }
                    }
                }
                .padding(.bottom, 48)
            }
            .background(Color(hex: "#0C0C10"))
        }

        // MARK: – Series Area

        @ViewBuilder
        private var seriesArea: some View {
            if store.isLoadingSeries {
                VStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(hex: "#0A84FF"))
                        .scaleEffect(1.5)
                    Text(AppStrings.Series.loadingSeries)
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.currentSeries.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "tv")
                        .font(.system(size: 60))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                    Text(AppStrings.Series.noSeries)
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 32)],
                        spacing: 32
                    ) {
                        ForEach(store.currentSeries) { series in
                            Button {
                                store.send(.seriesSelected(series))
                            } label: {
                                SeriesCardView(series: series, isSelected: store.selectedSeries?.id == series.id) {}
                            }
                            .buttonStyle(TVGridCardButtonStyle())
                            .contextMenu {
                                Button {
                                    store.send(.toggleFavorite(series))
                                } label: {
                                    if store.favoriteIDs.contains(series.id) {
                                        Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                                    } else {
                                        Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 48)
                }
            }
        }
    }

    // MARK: - TV Series Category Row

    private struct TVSeriesCategoryRow: View {
        let category: MediaModels.Category
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isSelected ? Color(hex: "#30D158") : Color.clear)
                        .frame(width: 4, height: 26)

                    Text(category.name)
                        .font(.system(size: 22, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? Color.white : Color(hex: "#C0C6D6").opacity(0.7))
                        .lineLimit(1)

                    Spacer()
                }
            }
            .buttonStyle(TVCategoryRowButtonStyle(accentColor: Color(hex: "#30D158"), isSelected: isSelected))
        }
    }
#endif
