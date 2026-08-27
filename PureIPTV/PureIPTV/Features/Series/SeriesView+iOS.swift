#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - iOS Series View

    public struct SeriesView_iOS: View {
        @Bindable var store: StoreOf<SeriesFeature>
        let serverURL: String
        let username: String
        let password: String

        /// For Series, we usually show 3 columns on iPhone
        private let columns: [GridItem] = [
            GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 12),
        ]

        public init(store: StoreOf<SeriesFeature>, serverURL: String, username: String, password: String) {
            self.store = store
            self.serverURL = serverURL
            self.username = username
            self.password = password
        }

        public var body: some View {
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Header Actions ─────────────────────────────────
                    HStack {
                        Text("Diziler")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            store.send(.editCategoriesTapped)
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color(hex: "#1F1F23")))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                    // ── Category horizontal scroll ─────────────────────
                    categoryBar
                        .padding(.bottom, 12)

                    // Series grid
                    if store.isLoadingCategories {
                        loadingView
                    } else if store.categories.isEmpty {
                        emptyView
                    } else {
                        seriesGrid
                    }
                }
            }
            .onAppear {
                if let url = URL(string: serverURL) {
                    store.send(.onAppear(config: PlaylistConfig(type: .xtream, serverURL: url, username: username, password: password)))
                }
            }
            .sheet(item: $store.scope(state: \.categoryManagement, action: \.categoryManagement)) { store in
                CategoryManagementView(store: store)
            }
            .sheet(item: $store.scope(state: \.parentalLock, action: \.parentalLock)) { store in
                ParentalLockView(store: store)
                    .presentationDetents([.height(300)])
            }
        }

        // MARK: – Category Bar

        private var categoryBar: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.categories) { category in
                        CategoryPill(
                            name: category.name,
                            isSelected: store.selectedCategoryID == category.id
                        ) {
                            store.send(.categorySelected(category))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }

        // MARK: – Series Grid

        private var seriesGrid: some View {
            ScrollView {
                if store.isLoadingSeries {
                    loadingView
                } else if store.currentSeries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 36))
                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.3))
                        Text("Bu kategoride dizi bulunamadı")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.currentSeries) { series in
                            SeriesCardView(
                                series: series,
                                isSelected: store.selectedSeries?.id == series.id
                            ) {
                                store.send(.seriesSelected(series))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }

        // MARK: – Loading & Empty

        private var loadingView: some View {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0 ..< 12, id: \.self) { _ in
                    SeriesCardView(
                        series: .placeholder,
                        isSelected: false
                    ) {}
                        .shimmeringPlaceholder(isLoading: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }

        private var emptyView: some View {
            VStack(spacing: 12) {
                Image(systemName: "rectangle.stack.badge.minus")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.3))
                Text("Kategori bulunamadı")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Category Pill

    private struct CategoryPill: View {
        let name: String
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button {
                HapticManager.shared.trigger(.light)
                action()
            } label: {
                Text(name)
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
#endif
