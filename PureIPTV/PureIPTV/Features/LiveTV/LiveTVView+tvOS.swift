#if os(tvOS)
    import ComposableArchitecture
    import Kingfisher
    import SwiftUI

    // MARK: - tvOS Live TV View

    /// tvOS Live TV Screen coordinator decomposed into dedicated subviews with narrow invalidation boundaries.
    /// Layout: Left column = categories drawer (LiveTVCategoryDrawer_tvOS), right area = channel shelf (LiveTVChannelGrid_tvOS).
    /// Focus Engine: Categories list and channel cards are fully focusable with Electric Blue glow.
    public struct LiveTVView_tvOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        let config: PlaylistConfig
        @Environment(\.scenePhase) private var scenePhase
        @FocusState private var focusedCategory: String?
        @FocusState private var focusedChannelID: String?
        @AppStorage(LiveTVFocusPreferenceKeys.favoriteChannelWrapAround) private var isFavoriteWrapAroundFocusEnabled = false

        @State private var currentScrubLetter: String = ""
        @State private var isScrubOverlayVisible: Bool = false
        @State private var hideScrubTask: Task<Void, Never>?
        @State private var selectionRestoreChannelID: String?
        @State private var selectionFocusRestoreGeneration = 0
        @State private var categorySearchQuery = ""

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
                // ── Left: Category Drawer (Decomposed Subview) ────────
                LiveTVCategoryDrawer_tvOS(
                    store: store,
                    config: config,
                    focusedCategory: $focusedCategory,
                    categorySearchQuery: $categorySearchQuery,
                    onEnterChannelSelection: {
                        selectionRestoreChannelID = focusedChannelID
                            ?? store.selectedChannel?.id
                            ?? store.displayChannels.first?.id
                        store.send(.enterChannelSelectionMode)
                    }
                )
                .frame(width: 280)
                .focusSection()

                // ── Divider ──────────────────────────────────────────
                Rectangle()
                    .fill(AppColors.divider)
                    .frame(width: 1)
                    .frame(width: 24)

                // ── Right: Channel Shelf Grid (Decomposed Subview) ───
                LiveTVChannelGrid_tvOS(
                    store: store,
                    focusedChannelID: $focusedChannelID,
                    currentScrubLetter: $currentScrubLetter,
                    isScrubOverlayVisible: $isScrubOverlayVisible,
                    isFavoriteWrapAroundFocusEnabled: isFavoriteWrapAroundFocusEnabled,
                    onFocusChanged: handleFocusChange
                )
                .focusSection()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if store.isChannelSelectionMode {
                    ChannelSelectionToolbar(store: store)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !store.isChannelSelectionMode, let notice = store.bulkFavoriteNotice {
                    FavoriteListNoticeBanner(message: notice) {
                        store.send(.dismissBulkFavoriteNotice)
                    }
                }
            }
            .background(
                DynamicMeshBackgroundView(
                    imageURL: focusedChannel?.displayLogoURL,
                    titleSeed: focusedChannel?.title ?? "LiveTV",
                    userAgentOverride: focusedChannel?.userAgentOverride,
                    playlistID: focusedChannel?.playlistID
                )
            )
            .onAppear {
                store.send(.onAppear(config: config))
            }
            .onChange(of: config.playlistID) { _, _ in
                categorySearchQuery = ""
            }
            .onDisappear {
                store.send(.onDisappear)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    store.send(.cancelRefreshForBackground)
                }
            }
            .onChange(of: store.isChannelSelectionMode) { _, isSelecting in
                selectionFocusRestoreGeneration &+= 1
                let restoreGeneration = selectionFocusRestoreGeneration
                guard !isSelecting, let selectionRestoreChannelID else { return }
                let restoreID = selectionRestoreChannelID
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard selectionFocusRestoreGeneration == restoreGeneration,
                          !store.isChannelSelectionMode,
                          self.selectionRestoreChannelID == restoreID else { return }
                    let visibleChannels = store.displayChannels
                    if let focusedChannelID,
                       visibleChannels.contains(where: { $0.id == focusedChannelID })
                    {
                        self.selectionRestoreChannelID = nil
                        return
                    }
                    guard focusedCategory == nil else {
                        self.selectionRestoreChannelID = nil
                        return
                    }
                    focusedChannelID = visibleChannels.contains(where: { $0.id == restoreID })
                        ? restoreID
                        : visibleChannels.first?.id
                    self.selectionRestoreChannelID = nil
                }
            }
            .onChange(of: store.hiddenChannelIDs.count) { _, _ in
                guard let focusedChannelID,
                      !store.displayChannels.contains(where: { $0.id == focusedChannelID })
                else { return }
                self.focusedChannelID = store.displayChannels.first?.id
            }
        }

        private var focusedChannel: MediaModels.Item? {
            if let focusedChannelID {
                return store.displayChannels.first(where: { $0.id == focusedChannelID })
            }
            return store.selectedChannel ?? store.displayChannels.first
        }

        private func handleFocusChange(_ newID: String?) {
            guard let newID else { return }
            TVFocusMemory.shared.recordChannel(newID, in: store.selectedCategoryID)
            guard let ch = store.displayChannels.first(where: { $0.id == newID }) else { return }
            PrebufferingManager.shared.prepareChannel(
                url: ch.streamURL,
                userAgentOverride: ch.userAgentOverride
            )
            let firstChar = String(ch.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
            if !firstChar.isEmpty, firstChar != currentScrubLetter {
                currentScrubLetter = firstChar
                withAnimation(.spring(duration: 0.25, bounce: 0.2)) {
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
