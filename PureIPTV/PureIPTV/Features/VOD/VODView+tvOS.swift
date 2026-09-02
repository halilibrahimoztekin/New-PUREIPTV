#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS VOD View

    // Layout: Left column = categories, right area = VOD poster grid.
    // Focus Engine: Categories list and VOD cards are fully focusable.

    public struct VODView_tvOS: View {
        @Bindable var store: StoreOf<VODFeature>
        let serverURL: String
        let username: String
        let password: String

        @FocusState private var focusedCategory: String?

        public init(store: StoreOf<VODFeature>, serverURL: String, username: String, password: String) {
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

                // ── Right: VOD grid ──────────────────────────────────
                vodArea
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
                        Text("Filmler")
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
                            TVVODCategoryRow(
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

        // MARK: – VOD Area

        @ViewBuilder
        private var vodArea: some View {
            if store.isLoadingVODs {
                VStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(hex: "#0A84FF"))
                        .scaleEffect(1.5)
                    Text("Filmler yükleniyor…")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.currentVODs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "film")
                        .font(.system(size: 60))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                    Text("Film bulunamadı")
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
                        ForEach(store.currentVODs) { vod in
                            Button {
                                store.send(.vodSelected(vod))
                            } label: {
                                VODCardView(vod: vod, isSelected: store.selectedVOD?.id == vod.id) {}
                            }
                            .buttonStyle(.card)
                            .contextMenu {
                                Button {
                                    store.send(.toggleFavorite(vod))
                                } label: {
                                    if store.favoriteIDs.contains(vod.id) {
                                        Label("Favorilerden Çıkar", systemImage: "heart.slash")
                                    } else {
                                        Label("Favorilere Ekle", systemImage: "heart")
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

    // MARK: - TV VOD Category Row

    private struct TVVODCategoryRow: View {
        let category: MediaModels.Category
        let isSelected: Bool
        let action: () -> Void

        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Button(action: action) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isSelected ? Color(hex: "#BF5AF2") : Color.clear)
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
                        .fill(isFocused || isSelected ? Color(hex: "#BF5AF2").opacity(0.12) : Color.clear)
                )
                .scaleEffect(isFocused ? 1.02 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
            }
            .buttonStyle(.plain)
        }
    }
#endif
