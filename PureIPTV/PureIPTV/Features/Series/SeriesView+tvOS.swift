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
                    .frame(width: 280)

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
                VStack(spacing: 4) {
                    HStack {
                        Text("Diziler")
                            .font(.system(size: 26, weight: .bold))
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
                    Text("Diziler yükleniyor…")
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
                    Text("Dizi bulunamadı")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 30)],
                        spacing: 30
                    ) {
                        ForEach(store.currentSeries) { series in
                            Button {
                                store.send(.seriesSelected(series))
                            } label: {
                                SeriesCardView(series: series, isSelected: store.selectedSeries?.id == series.id) {}
                            }
                            .buttonStyle(.card)
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

        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Button(action: action) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isSelected ? Color(hex: "#30D158") : Color.clear)
                        .frame(width: 4, height: 26)

                    Text(category.name)
                        .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(
                            isSelected
                                ? Color(hex: "#E4E1E7")
                                : Color(hex: "#C0C6D6").opacity(0.6)
                        )
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isFocused || isSelected ? Color(hex: "#30D158").opacity(0.12) : Color.clear)
                )
                .scaleEffect(isFocused ? 1.02 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
            }
            .buttonStyle(.plain)
        }
    }
#endif
