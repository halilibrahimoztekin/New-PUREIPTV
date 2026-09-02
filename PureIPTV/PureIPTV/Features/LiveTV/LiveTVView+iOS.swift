#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - iOS Live TV View

    // Layout: Horizontal category pills at top, channel grid below.
    // iPad: Same layout, more grid columns due to larger screen.

    public struct LiveTVView_iOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        let serverURL: String
        let username: String
        let password: String

        private let columns: [GridItem] = [
            GridItem(.adaptive(minimum: 155, maximum: 200), spacing: 12),
        ]

        public init(store: StoreOf<LiveTVFeature>, serverURL: String, username: String, password: String) {
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
                        Text("Canlı TV")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Spacer()

                        HStack(spacing: 12) {
                            Button {
                                store.send(.epgGuideTapped)
                            } label: {
                                Image(systemName: "list.bullet.rectangle.portrait")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.9))
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color(hex: "#1F1F23")))
                            }

                            Button {
                                store.send(.openMultiViewTapped)
                            } label: {
                                Image(systemName: "square.split.2x2.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.9))
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color(hex: "#1F1F23")))
                            }

                            Button {
                                store.send(.openEPGTimelineTapped)
                            } label: {
                                Image(systemName: "calendar.day.timeline.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.9))
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Color(hex: "#1F1F23")))
                            }

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
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                    // ── Category horizontal scroll ─────────────────────
                    categoryBar
                        .padding(.bottom, 12)

                    // ── Channel grid ───────────────────────────────────
                    if store.isLoadingCategories {
                        loadingView
                    } else if store.categories.isEmpty {
                        emptyView
                    } else {
                        channelGrid
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
            .fullScreenCover(item: $store.scope(state: \.epgGuide, action: \.epgGuide)) { store in
                EPGGuideView_iOS(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.epgTimeline, action: \.epgTimeline)) { store in
                EPGTimelineView(store: store)
            }
            .sheet(item: $store.scope(state: \.parentalLock, action: \.parentalLock)) { store in
                ParentalLockView(store: store)
                    .presentationDetents([.height(300)])
            }
            .fullScreenCover(item: $store.scope(state: \.multiView, action: \.multiView)) { store in
                MultiView(store: store)
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

        // MARK: – Channel Grid

        private var channelGrid: some View {
            ScrollView {
                if store.isLoadingChannels {
                    loadingView
                } else if store.currentChannels.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tv.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.3))
                        Text("Bu kategoride kanal bulunamadı")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.currentChannels) { channel in
                            ChannelCardView(
                                channel: channel,
                                isSelected: store.selectedChannel?.id == channel.id
                            ) {
                                store.send(.channelSelected(channel))
                            }
                            .contextMenu {
                                Button {
                                    store.send(.toggleFavorite(channel))
                                } label: {
                                    if store.favoriteIDs.contains(channel.id) {
                                        Label("Favorilerden Çıkar", systemImage: "heart.slash")
                                    } else {
                                        Label("Favorilere Ekle", systemImage: "heart")
                                    }
                                }
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
                    ChannelCardView(
                        channel: .placeholder,
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
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
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
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color(hex: "#1F1F23") : Color(hex: "#C0C6D6"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(isSelected ? Color(hex: "#0A84FF") : Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }

    #Preview("Live TV iOS") {
        LiveTVView_iOS(
            store: Store(initialState: LiveTVFeature.State()) {
                LiveTVFeature()
            },
            serverURL: "http://example.com",
            username: "demo",
            password: "demo"
        )
    }
#endif
