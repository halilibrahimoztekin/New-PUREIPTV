#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS Live TV View

    // Layout: Left column = categories, right area = channel shelf rows.
    // Focus Engine: Categories list and channel cards are fully focusable.
    // Focused channel card scales up 1.1x with Electric Blue glow.

    public struct LiveTVView_tvOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        let config: PlaylistConfig

        @FocusState private var focusedCategory: String?
        @FocusState private var focusedChannelID: String?

        @State private var currentScrubLetter: String = ""
        @State private var isScrubOverlayVisible: Bool = false
        @State private var hideScrubTask: Task<Void, Never>?

        public init(store: StoreOf<LiveTVFeature>, config: PlaylistConfig) {
            self.store = store
            self.config = config
        }

        public init(store: StoreOf<LiveTVFeature>, serverURL: String, username: String, password: String) {
            self.store = store
            if (username.isEmpty && password.isEmpty) || serverURL.lowercased().contains(".m3u") {
                config = PlaylistConfig(type: .m3u, m3uURL: URL(string: serverURL))
            } else {
                config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
            }
        }

        public var body: some View {
            HStack(spacing: 0) {
                // ── Left: Category list ───────────────────────────────
                categoryColumn
                    .frame(width: 280)
                    .focusSection()
                    .focusGuideBoundary()

                // ── Divider with Focus Guide Bridge ───────────────────
                ZStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)
                    TVFocusGuideBridge()
                        .frame(width: 24)
                }

                // ── Right: Channel shelf ──────────────────────────────
                channelArea
                    .focusSection()
                    .focusGuideBoundary()
            }
            .background(
                DynamicMeshBackgroundView(
                    imageURL: focusedChannel?.coverURL,
                    titleSeed: focusedChannel?.title ?? "LiveTV"
                )
            )
            .onAppear {
                store.send(.onAppear(config: config))
            }
            .sheet(item: $store.scope(state: \.parentalLock, action: \.parentalLock)) { store in
                ParentalLockView(store: store)
            }
            .sheet(item: $store.scope(state: \.categoryManagement, action: \.categoryManagement)) { store in
                CategoryManagementView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.epgTimeline, action: \.epgTimeline)) { store in
                EPGTimelineView(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.epgGuide, action: \.epgGuide)) { store in
                EPGGuideView_tvOS(store: store)
            }
            .fullScreenCover(item: $store.scope(state: \.multiView, action: \.multiView)) { store in
                MultiView(store: store)
            }
        }

        private var focusedChannel: MediaModels.Item? {
            if let focusedChannelID {
                return store.currentChannels.first(where: { $0.id == focusedChannelID })
            }
            return store.selectedChannel ?? store.currentChannels.first
        }

        // MARK: – Category Column

        private var categoryColumn: some View {
            ScrollViewReader { catProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        // Header
                        HStack {
                            Text(AppStrings.LiveTV.categories)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Color(hex: "#E4E1E7"))
                            Spacer()
                            HStack(spacing: 8) {
                                Button {
                                    store.send(.editCategoriesTapped)
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 18))
                                        .padding(8)
                                }
                                .buttonStyle(TVCircleButtonStyle())

                                Button {
                                    store.send(.openEPGTimelineTapped)
                                } label: {
                                    Image(systemName: "calendar.day.timeline.left")
                                        .font(.system(size: 20))
                                        .padding(8)
                                }
                                .buttonStyle(TVCircleButtonStyle())

                                Button {
                                    store.send(.epgGuideTapped)
                                } label: {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 20))
                                        .padding(8)
                                }
                                .buttonStyle(TVCircleButtonStyle())
                            }
                            .padding(.trailing, 8)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 48)
                        .padding(.bottom, 16)

                        if store.isLoadingCategories {
                            PureLoadingView(size: .small)
                                .padding(.top, 40)
                        } else if store.categories.isEmpty, let errorMessage = store.errorMessage {
                            RetryableSectionEmptyState(message: errorMessage) {
                                store.send(.reloadCategories(config: config))
                            }
                            .frame(height: 280)
                        } else {
                            ForEach(store.categories) { category in
                                TVCategoryRow(
                                    category: category,
                                    isSelected: store.selectedCategoryID == category.id,
                                    isLocked: store.categoryPreferences[category.id]?.isLocked ?? false
                                ) {
                                    store.send(.categorySelected(category))
                                }
                                .padding(.horizontal, 16)
                                .focused($focusedCategory, equals: category.id)
                                .id(category.id)
                            }
                        }
                    }
                    .padding(.bottom, 48)
                }
                .background(Color(hex: "#0C0C10"))
                .onChange(of: store.selectedCategoryID) { _, newCatID in
                    if let newCatID {
                        focusedCategory = newCatID
                        TVFocusMemory.shared.lastSelectedLiveCategoryID = newCatID
                        withAnimation { catProxy.scrollTo(newCatID, anchor: .center) }
                    }
                }
                .onChange(of: focusedCategory) { _, newCatID in
                    if let newCatID {
                        TVFocusMemory.shared.lastSelectedLiveCategoryID = newCatID
                    }
                }
                .onAppear {
                    let targetCatID = store.selectedCategoryID ?? TVFocusMemory.shared.lastSelectedLiveCategoryID ?? store.categories.first?.id
                    if let targetCatID {
                        focusedCategory = targetCatID
                        withAnimation { catProxy.scrollTo(targetCatID, anchor: .center) }
                    }
                }
            }
        }

        // MARK: – Channel Area

        @ViewBuilder
        private var channelArea: some View {
            if store.isLoadingChannels {
                VStack {
                    PureLoadingView(size: .large, text: AppStrings.LiveTV.loadingChannels)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.currentChannels.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                    Text(AppStrings.LiveTV.noChannels)
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                channelScrollView
            }
        }

        private var channelScrollView: some View {
            ScrollViewReader { channelProxy in
                ScrollView {
                    channelGrid
                }
                .onChange(of: store.selectedChannel) { _, newChannel in
                    if let channelID = newChannel?.id {
                        TVFocusMemory.shared.recordChannel(channelID, in: store.selectedCategoryID)
                        focusedChannelID = channelID
                        withAnimation { channelProxy.scrollTo(channelID, anchor: .center) }
                    }
                }
                .onChange(of: store.selectedCategoryID) { _, newCatID in
                    let targetID = TVFocusMemory.shared.lastChannel(
                        in: newCatID,
                        fallback: store.currentChannels.first?.id
                    )
                    if let targetID {
                        focusedChannelID = targetID
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation { channelProxy.scrollTo(targetID, anchor: .center) }
                        }
                    }
                }
                .onAppear {
                    let targetID = TVFocusMemory.shared.lastChannel(
                        in: store.selectedCategoryID,
                        fallback: store.selectedChannel?.id ?? store.currentChannels.first?.id
                    )
                    if let targetID {
                        focusedChannelID = targetID
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation { channelProxy.scrollTo(targetID, anchor: .center) }
                        }
                    }
                }
                .onChange(of: focusedChannelID) { _, newID in
                    handleFocusChange(newID)
                }
                .overlay(
                    TVAlphabetScrubberOverlay(
                        currentLetter: currentScrubLetter,
                        isVisible: isScrubOverlayVisible,
                        availableLetters: Set(store.currentChannels.compactMap {
                            let c = String($0.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
                            return ("A" ... "Z").contains(c) ? c : "#"
                        })
                    )
                )
            }
        }

        private var channelGrid: some View {
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
                    .focused($focusedChannelID, equals: channel.id)
                    .id(channel.id)
                    .contextMenu {
                        channelContextMenu(for: channel)
                    }
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 48)
        }

        private func handleFocusChange(_ newID: String?) {
            guard let newID else { return }
            TVFocusMemory.shared.recordChannel(newID, in: store.selectedCategoryID)
            guard let ch = store.currentChannels.first(where: { $0.id == newID }) else { return }
            PrebufferingManager.shared.prepareChannel(
                url: ch.streamURL,
                userAgentOverride: ch.userAgentOverride
            )
            let firstChar = String(ch.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
            if !firstChar.isEmpty, firstChar != currentScrubLetter {
                currentScrubLetter = firstChar
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isScrubOverlayVisible = true
                }
                hideScrubTask?.cancel()
                hideScrubTask = Task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.35)) {
                            isScrubOverlayVisible = false
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private func channelContextMenu(for channel: MediaModels.Item) -> some View {
            Button {
                store.send(.toggleFavorite(channel))
            } label: {
                if store.favoriteIDs.contains(channel.id) {
                    Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                } else {
                    Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                }
            }

            Button {
                store.send(.sendToMultiView(channel))
            } label: {
                Label(AppStrings.LiveTV.sendToMultiView, systemImage: "square.grid.2x2")
            }

            Button {
                store.send(.openChannelGuide(channel))
            } label: {
                Label(AppStrings.LiveTV.channelGuide, systemImage: "calendar.badge.clock")
            }

            Button {
                store.send(.openChannelEPG(channel))
            } label: {
                Label("Zaman Çizelgesi (Timeline)".localized, systemImage: "calendar.day.timeline.left")
            }

            Button(role: .destructive) {
                store.send(.hideChannel(channel))
            } label: {
                Label(AppStrings.LiveTV.hideChannel, systemImage: "eye.slash")
            }
        }
    }

    // MARK: - TV Category Row

    private struct TVCategoryRow: View {
        let category: MediaModels.Category
        let isSelected: Bool
        let isLocked: Bool
        let action: () -> Void

        init(category: MediaModels.Category, isSelected: Bool, isLocked: Bool = false, action: @escaping () -> Void) {
            self.category = category
            self.isSelected = isSelected
            self.isLocked = isLocked
            self.action = action
        }

        var body: some View {
            Button(action: action) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isSelected ? Color(hex: "#0A84FF") : Color.clear)
                        .frame(width: 4, height: 26)

                    Text(category.name)
                        .font(.system(size: 22, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? Color.white : Color(hex: "#C0C6D6").opacity(0.7))
                        .lineLimit(1)

                    Spacer()

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange.opacity(0.85))
                    }
                }
            }
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
