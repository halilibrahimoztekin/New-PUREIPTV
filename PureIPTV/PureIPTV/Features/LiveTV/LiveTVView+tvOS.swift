#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS Live TV View

    // Layout: Left column = categories, right area = channel shelf rows.
    // Focus Engine: Categories list and channel cards are fully focusable.
    // Focused channel card scales up 1.1x with Electric Blue glow.

    public struct LiveTVView_tvOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        let serverURL: String
        let username: String
        let password: String

        @FocusState private var focusedCategory: String?

        public init(store: StoreOf<LiveTVFeature>, serverURL: String, username: String, password: String) {
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

                // ── Right: Channel shelf ──────────────────────────────
                channelArea
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
                    // Header
                    HStack {
                        Text("Kategoriler")
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
                            TVCategoryRow(
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

        // MARK: – Channel Area

        @ViewBuilder
        private var channelArea: some View {
            if store.isLoadingChannels {
                VStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(hex: "#0A84FF"))
                        .scaleEffect(1.5)
                    Text("Kanallar yükleniyor…")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.currentChannels.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                    Text("Kanal bulunamadı")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Channel grid
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 260, maximum: 320), spacing: 24)],
                        spacing: 24
                    ) {
                        ForEach(store.currentChannels) { channel in
                            TVChannelCard(
                                channel: channel,
                                isSelected: store.selectedChannel?.id == channel.id
                            ) {
                                store.send(.channelSelected(channel))
                            }
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 48)
                }
            }
        }
    }

    // MARK: - TV Category Row

    private struct TVCategoryRow: View {
        let category: MediaModels.Category
        let isSelected: Bool
        let action: () -> Void

        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Button(action: action) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isSelected ? Color(hex: "#0A84FF") : Color.clear)
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
                        .fill(isFocused || isSelected ? Color(hex: "#0A84FF").opacity(0.12) : Color.clear)
                )
                .scaleEffect(isFocused ? 1.02 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - TV Channel Card

    private struct TVChannelCard: View {
        let channel: MediaModels.Item
        let isSelected: Bool
        let action: () -> Void

        @Environment(\.isFocused) private var isFocused

        var body: some View {
            Button(action: action) {
                ZStack(alignment: .bottomLeading) {
                    // Card background
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "#1F1F23"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    isFocused
                                        ? Color(hex: "#0A84FF")
                                        : isSelected ? Color(hex: "#0A84FF").opacity(0.4) : Color.white.opacity(0.07),
                                    lineWidth: isFocused ? 3 : 1
                                )
                        )

                    // Logo
                    if let logoURL = channel.logoURL {
                        AsyncImage(url: logoURL) { image in
                            image.resizable().aspectRatio(contentMode: .fit).frame(maxWidth: 90, maxHeight: 60)
                        } placeholder: {
                            Image(systemName: "tv.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.2))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Image(systemName: "tv.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.2))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Bottom gradient
                    LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Name + badge
                    HStack(alignment: .center, spacing: 8) {
                        Text(channel.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: "#E4E1E7"))
                            .lineLimit(1)
                        Spacer()
                        LiveBadge()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .shadow(color: isFocused ? Color(hex: "#0A84FF").opacity(0.5) : .clear, radius: 16, x: 0, y: 4)
                .scaleEffect(isFocused ? 1.08 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
            }
            .buttonStyle(.plain)
        }
    }

    #Preview("Live TV tvOS") {
        LiveTVView_tvOS(
            store: Store(initialState: LiveTVFeature.State()) {
                LiveTVFeature()
            },
            serverURL: "http://example.com",
            username: "demo",
            password: "demo"
        )
    }
#endif
