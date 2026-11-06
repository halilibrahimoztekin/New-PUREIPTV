#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - iOS Live TV View

    /// Coordinator view for Live TV on iOS.
    /// Decomposed into dedicated, isolated subviews with narrow invalidation boundaries.
    public struct LiveTVView_iOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        let config: PlaylistConfig
        let onSearch: (() -> Void)?

        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Environment(\.scenePhase) private var scenePhase
        @State private var categorySearchQuery = ""

        public init(store: StoreOf<LiveTVFeature>, config: PlaylistConfig, onSearch: (() -> Void)? = nil) {
            self.store = store
            self.config = config
            self.onSearch = onSearch
        }

        public init(store: StoreOf<LiveTVFeature>, serverURL: String, username: String, password: String, onSearch: (() -> Void)? = nil) {
            self.store = store
            self.onSearch = onSearch
            if (username.isEmpty && password.isEmpty) || serverURL.lowercased().contains(".m3u") {
                config = PlaylistConfig(type: .m3u, m3uURL: URL(string: serverURL))
            } else {
                config = PlaylistConfig(type: .xtream, serverURL: URL(string: serverURL), username: username, password: password)
            }
        }

        public var body: some View {
            Group {
                if horizontalSizeClass == .regular {
                    LiveTVSplitView_iPad(store: store, config: config)
                } else {
                    phoneLayout
                }
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
        }

        private var phoneLayout: some View {
            ZStack(alignment: .top) {
                AppColors.oledBlack.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Bar Actions (Liquid Glass)
                    LiveTVHeaderBar_iOS(store: store, config: config, onSearch: onSearch)

                    // Mode Switcher (Kanallar / Yayın Akışı)
                    LiveTVModePicker_iOS(store: store)
                        .frame(height: 44)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)

                    if store.selectedTabMode == .channels {
                        // Smart Group horizontal bar
                        if !store.smartChannelGroups.isEmpty {
                            LiveTVSmartGroupBar_iOS(store: store)
                                .frame(height: 44)
                                .padding(.bottom, 8)
                        }

                        // Favorite lists switcher
                        FavoriteChannelListSwitcher(store: store)
                            .frame(height: 44)
                            .padding(.bottom, 8)

                        // Category search & pills
                        LiveTVCategoryBar_iOS(store: store, categorySearchQuery: $categorySearchQuery)
                            .padding(.bottom, 12)

                        // Channel grid
                        if store.isLoadingCategories {
                            loadingView
                        } else if store.categories.isEmpty {
                            emptyView
                        } else {
                            LiveTVChannelGrid_iOS(store: store, config: config)
                        }
                    } else {
                        // Embedded EPG Timeline
                        if let epgStore = store.scope(state: \.epgTimeline, action: \.epgTimeline.presented) {
                            EPGTimelineView(store: epgStore)
                        } else {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(AppColors.primary)
                                Text(AppStrings.Player.syncing)
                                    .font(AppFonts.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onAppear {
                                store.send(.openEPGTimelineTapped)
                            }
                        }
                    }
                }
            }
        }

        private var loadingView: some View {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 200), spacing: 12)], spacing: 12) {
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
            .padding(.bottom, 120)
        }

        @ViewBuilder
        private var emptyView: some View {
            if let errorMessage = store.errorMessage {
                RetryableSectionEmptyState(message: errorMessage) {
                    store.send(.reloadCategories(config: config))
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                    Text(AppStrings.Common.categoryNotFound)
                        .font(AppFonts.bodyLarge)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
#endif
