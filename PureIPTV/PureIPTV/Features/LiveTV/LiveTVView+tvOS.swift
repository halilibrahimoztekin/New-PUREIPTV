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
                // ── Left: Category list ───────────────────────────────
                categoryColumn
                    .frame(width: 280)
                    .focusSection()

                // ── Divider ──────────────────────────────────────────
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
                    .frame(width: 24)

                // ── Right: Channel shelf ──────────────────────────────
                channelArea
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

        private var filteredCategories: [MediaModels.Category] {
            let query = categorySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return store.categories }
            return store.categories.filter { $0.name.localizedStandardContains(query) }
        }

        // MARK: – Category Column

        private var categoryColumn: some View {
            ScrollViewReader { catProxy in
                let itemCountsByCategory = store.visibleChannelCountsByCategory
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        // Header actions occupy separate rows so the 280 pt category
                        // column never squeezes six focus targets beside its title.
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(AppStrings.LiveTV.categories)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(Color(hex: "#E4E1E7"))
                                Spacer(minLength: 8)
                                Menu {
                                    Section(AppStrings.LiveTV.categoryOrderTitle) {
                                        ForEach(LiveTVCategoryOrder.allCases, id: \.self) { order in
                                            Button {
                                                store.send(.setCategoryOrder(order))
                                            } label: {
                                                if store.categoryOrder == order {
                                                    Label(order.title, systemImage: "checkmark")
                                                } else {
                                                    Text(order.title)
                                                }
                                            }
                                        }
                                    }

                                    Button {
                                        store.send(.smartGroupManagerTapped)
                                    } label: {
                                        Label(AppStrings.LiveTV.smartGroups, systemImage: "square.stack.3d.up")
                                    }
                                    .accessibilityHint(AppStrings.LiveTV.smartGroupPrivacyHint)

                                    Button {
                                        store.send(.editCategoriesTapped)
                                    } label: {
                                        Label(
                                            AppStrings.CategoryMgmt.manageTitle(for: AppStrings.LiveTV.categories),
                                            systemImage: "slider.horizontal.3"
                                        )
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(TVCircleButtonStyle())
                                .accessibilityLabel(AppStrings.Common.more)
                            }

                            HStack(spacing: 8) {
                                if config.type == .m3u {
                                    Button {
                                        guard !((store.isRefreshingContent && store.refreshStage?.canCancel != true)
                                            || store.isLoadingCategories
                                            || store.isChannelSelectionMode
                                            || store.isFavoriteListMode
                                            || store.selectedSmartGroupID != nil)
                                        else { return }
                                        store.send(store.isRefreshingContent ? .cancelContentRefresh : .refreshContentTapped)
                                    } label: {
                                        Group {
                                            if store.isRefreshingContent, store.refreshStage?.canCancel != true {
                                                ProgressView()
                                            } else {
                                                Image(systemName: store.isRefreshingContent ? "xmark" : "arrow.clockwise")
                                            }
                                        }
                                        .font(.system(size: 18))
                                        .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(TVCircleButtonStyle())
                                    .accessibilityLabel(store.isRefreshingContent ? "Yenilemeyi iptal et" : "Canlı kanalları yenile")
                                }

                                Button {
                                    if store.isChannelSelectionMode {
                                        store.send(.exitChannelSelectionMode)
                                    } else {
                                        selectionRestoreChannelID = focusedChannelID
                                            ?? store.selectedChannel?.id
                                            ?? store.displayChannels.first?.id
                                        store.send(.enterChannelSelectionMode)
                                    }
                                } label: {
                                    Image(systemName: store.isChannelSelectionMode ? "xmark" : "checklist")
                                        .font(.system(size: 18))
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(TVCircleButtonStyle())
                                .accessibilityLabel(store.isChannelSelectionMode ? AppStrings.LiveTV.cancelChannelSelection : AppStrings.LiveTV.selectChannels)

                                Button {
                                    store.send(.openEPGTimelineTapped)
                                } label: {
                                    Image(systemName: "calendar.day.timeline.left")
                                        .font(.system(size: 20))
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(TVCircleButtonStyle())
                                .accessibilityLabel(AppStrings.LiveTV.channelGuide)

                                Button {
                                    store.send(.epgGuideTapped)
                                } label: {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 20))
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(TVCircleButtonStyle())
                                .accessibilityLabel(AppStrings.EPG.guide)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 48)
                        .padding(.bottom, 16)

                        if let refreshStage = store.refreshStage {
                            Label(refreshStage.title, systemImage: "arrow.triangle.2.circlepath")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        if let refreshMessage = store.refreshMessage {
                            Text(refreshMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 24)
                        }

                        if store.isLoadingCategories {
                            PureLoadingView(size: .small)
                                .padding(.top, 40)
                        } else if store.categories.isEmpty, let errorMessage = store.errorMessage {
                            RetryableSectionEmptyState(message: errorMessage) {
                                store.send(.reloadCategories(config: config))
                            }
                            .frame(height: 280)
                        } else {
                            ForEach(store.smartChannelGroups) { group in
                                TVCategoryRow(
                                    category: MediaModels.Category(id: "smart-group:\(group.id)", name: group.name),
                                    isSelected: store.selectedSmartGroupID == group.id,
                                    isLocked: false
                                ) {
                                    store.send(.smartGroupSelected(group.id))
                                }
                                .padding(.horizontal, 16)
                                .focused($focusedCategory, equals: "smart-group:\(group.id)")
                                .id("smart-group:\(group.id)")
                            }
                            if !store.categories.isEmpty {
                                CategorySearchField(text: $categorySearchQuery) {
                                    if let firstMatch = filteredCategories.first {
                                        store.send(.categorySelected(firstMatch))
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                            }
                            if !store.categories.isEmpty, filteredCategories.isEmpty {
                                Text(AppStrings.Common.categoryNotFound)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                            }
                            ForEach(filteredCategories) { category in
                                categoryRow(for: category, itemCount: itemCountsByCategory[category.id])
                            }
                        }
                    }
                    .padding(.bottom, 48)
                }
                .background(Color(hex: "#0C0C10"))
                .focusSection()
                .onChange(of: store.selectedCategoryID) { _, newCatID in
                    if let newCatID {
                        if !filteredCategories.contains(where: { $0.id == newCatID }) {
                            categorySearchQuery = ""
                        }
                        focusedCategory = newCatID
                        TVFocusMemory.shared.lastSelectedLiveCategoryID = newCatID
                        withAnimation { catProxy.scrollTo(newCatID, anchor: .center) }
                    }
                }
                .onChange(of: store.selectedSmartGroupID) { _, newGroupID in
                    if let newGroupID {
                        let focusID = "smart-group:\(newGroupID)"
                        focusedCategory = focusID
                        withAnimation { catProxy.scrollTo(focusID, anchor: .center) }
                    }
                }
                .onChange(of: focusedCategory) { _, newCatID in
                    if let newCatID, !newCatID.hasPrefix("smart-group:") {
                        TVFocusMemory.shared.lastSelectedLiveCategoryID = newCatID
                    }
                }
                .onAppear {
                    let targetCatID = store.selectedSmartGroupID.map { "smart-group:\($0)" }
                        ?? store.selectedCategoryID
                        ?? TVFocusMemory.shared.lastSelectedLiveCategoryID.flatMap { remembered in
                            store.categories.contains(where: { $0.id == remembered }) ? remembered : nil
                        }
                        ?? store.categories.first?.id
                    if let targetCatID {
                        focusedCategory = targetCatID
                        withAnimation { catProxy.scrollTo(targetCatID, anchor: .center) }
                    }
                }
            }
        }

        private func categoryRow(for category: MediaModels.Category, itemCount: Int?) -> some View {
            let isSelected = store.selectedCategoryID == category.id
            let isLocked = store.categoryPreferences[category.id]?.isLocked ?? false
            return TVCategoryRow(
                category: category,
                isSelected: isSelected,
                isLocked: isLocked,
                itemCount: itemCount
            ) {
                store.send(.categorySelectedAndOpenEPGGuide(category))
            }
            .padding(.horizontal, 16)
            .focused($focusedCategory, equals: category.id)
            .id(category.id)
        }

        private var categoryQuickJumpMenu: some View {
            Menu {
                ForEach(store.categories) { category in
                    let isSelected = store.selectedCategoryID == category.id
                        && store.selectedSmartGroupID == nil
                        && !store.isFavoriteListMode
                    let isLocked = store.categoryPreferences[category.id]?.isLocked ?? false

                    Button {
                        guard !isSelected else { return }
                        store.send(.categorySelected(category))
                    } label: {
                        HStack(spacing: 12) {
                            Text(category.name)
                            Spacer()
                            if isLocked {
                                Image(systemName: "lock.fill")
                            } else if isSelected {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .accessibilityLabel(category.name)
                    .accessibilityValue(isLocked ? AppStrings.LiveTV.categoryLockedStatus : "")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            } label: {
                Label(AppStrings.LiveTV.categoryQuickJump, systemImage: "square.grid.2x2")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
            .accessibilityLabel(AppStrings.LiveTV.categoryQuickJump)
            .tvFocusEffect(shape: .capsule)
        }

        // MARK: – Channel Area

        private var channelArea: some View {
            VStack(spacing: 0) {
                FavoriteChannelListSwitcher(store: store)
                    .padding(.top, 8)
                HStack {
                    Spacer()
                    if !store.isChannelSelectionMode {
                        if !store.categories.isEmpty {
                            categoryQuickJumpMenu
                        }
                        LiveTVChannelSortMenu(store: store)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .focusSection()
                if store.isLoadingChannels, store.displayChannels.isEmpty {
                    PureLoadingView(size: .large, text: AppStrings.LiveTV.loadingChannels)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.displayChannels.isEmpty {
                    if store.selectedSmartGroupID == nil,
                       !store.isFavoriteListMode,
                       let categoryID = store.selectedCategoryID,
                       let error = store.categoryContentErrors[categoryID]
                    {
                        RetryableSectionEmptyState(message: error) {
                            store.send(.retryCategoryContent(categoryID: categoryID))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                .font(.system(size: 60))
                                .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                            Text(AppStrings.LiveTV.noChannels)
                                .font(.system(size: 28))
                                .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.4))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    channelScrollView
                }
            }
        }

        private var channelScrollView: some View {
            ScrollViewReader { channelProxy in
                ScrollView {
                    VStack(spacing: 16) {
                        if store.selectedSmartGroupID == nil,
                           !store.isFavoriteListMode,
                           let categoryID = store.selectedCategoryID,
                           let error = store.categoryContentErrors[categoryID]
                        {
                            RetryableSectionEmptyState(message: error) {
                                store.send(.retryCategoryContent(categoryID: categoryID))
                            }
                        }
                        if store.isLoadingChannels {
                            PureLoadingView(size: .small)
                        }
                        channelGrid(channelProxy: channelProxy)
                    }
                }
                .onChange(of: store.selectedChannel) { _, newChannel in
                    if let channelID = newChannel?.id {
                        TVFocusMemory.shared.recordChannel(channelID, in: store.selectedCategoryID)
                        focusedChannelID = channelID
                        withAnimation { channelProxy.scrollTo(channelID, anchor: .center) }
                    }
                }
                .onChange(of: store.channelFocusRestoreRevision) { _, _ in
                    guard let channelID = store.selectedChannel?.id,
                          store.displayChannels.contains(where: { $0.id == channelID }),
                          focusedChannelID != channelID else { return }
                    TVFocusMemory.shared.recordChannel(channelID, in: store.selectedCategoryID)
                    focusedChannelID = channelID
                    withAnimation { channelProxy.scrollTo(channelID, anchor: .center) }
                }
                .onChange(of: store.selectedCategoryID) { _, newCatID in
                    let targetID = TVFocusMemory.shared.lastChannel(
                        in: newCatID,
                        fallback: store.displayChannels.first?.id
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
                        fallback: store.selectedChannel?.id ?? store.displayChannels.first?.id
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
                        availableLetters: Set(store.displayChannels.compactMap {
                            let c = String($0.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
                            return ("A" ... "Z").contains(c) ? c : "#"
                        })
                    )
                )
            }
        }

        private func channelGrid(channelProxy: ScrollViewProxy) -> some View {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260, maximum: 320), spacing: 24)],
                spacing: 24
            ) {
                let channels = store.displayChannels
                let manualOrderableCount = store.isFavoriteListMode
                    && store.favoriteSortMode == .manual
                    && !store.isChannelSelectionMode
                    ? channels.count - store.unavailableFavoriteChannels.count
                    : 0
                ForEach(Array(channels.enumerated()), id: \.element.id) { entry in
                    favoriteChannelCard(
                        entry.element,
                        at: entry.offset,
                        in: channels,
                        manualOrderableCount: manualOrderableCount,
                        channelProxy: channelProxy
                    )
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 48)
        }

        @ViewBuilder
        private func favoriteChannelCard(
            _ channel: MediaModels.Item,
            at index: Int,
            in channels: [MediaModels.Item],
            manualOrderableCount: Int,
            channelProxy: ScrollViewProxy
        ) -> some View {
            let isUnavailable = store.unavailableFavoriteChannelIDs.contains(channel.id)
            let manualOrderIndex = !isUnavailable && index < manualOrderableCount ? index : nil
            let canRepeatManualOrder = manualOrderableCount > 1 && manualOrderIndex != nil
            let card = TVChannelCard(
                channel: channel,
                isSelected: store.selectedChannel?.id == channel.id,
                presentationName: store.channelPresentationOverrides[channel.id]?.name,
                presentationNumber: store.channelPresentationOverrides[channel.id]?.number,
                sequenceNumber: store.selectedCategoryID != nil
                    && store.selectedSmartGroupID == nil
                    && !store.isFavoriteListMode
                    ? index + 1
                    : nil
            ) {
                store.send(store.isChannelSelectionMode ? .toggleChannelSelection(channel) : .channelSelected(channel))
            }
            .overlay(alignment: .topLeading) {
                if isUnavailable {
                    Text(AppStrings.LiveTV.unavailableFavoriteChannel)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.76), in: Capsule())
                        .padding(12)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .topTrailing) {
                if store.isChannelSelectionMode {
                    Image(systemName: store.selectedCurrentChannelIDs.contains(channel.id) ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(store.selectedCurrentChannelIDs.contains(channel.id) ? Color.accentColor : .white)
                        .padding(12)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityValue(isUnavailable
                ? AppStrings.LiveTV.unavailableFavoriteChannel
                : (store.isChannelSelectionMode
                    ? (store.selectedCurrentChannelIDs.contains(channel.id) ? AppStrings.LiveTV.selected : AppStrings.LiveTV.notSelected)
                    : ""))
            .accessibilityHint(isUnavailable
                ? AppStrings.LiveTV.unavailableFavoriteChannelHint
                : (store.isChannelSelectionMode
                    ? (store.selectedCurrentChannelIDs.contains(channel.id)
                        ? AppStrings.LiveTV.deselectChannelAccessibilityHint
                        : AppStrings.LiveTV.selectChannelAccessibilityHint)
                    : (canRepeatManualOrder ? AppStrings.Favorites.directionalReorderHint : "")))
            .accessibilityAddTraits(store.isChannelSelectionMode && !isUnavailable && store.selectedCurrentChannelIDs.contains(channel.id) ? .isSelected : [])
            .focused($focusedChannelID, equals: channel.id)
            .id(channel.id)
            .contextMenu {
                channelContextMenu(for: channel)
            }

            let canWrapFocus = isFavoriteWrapAroundFocusEnabled
                && store.isFavoriteListMode
                && store.favoriteSortMode != .manual
                && !store.isChannelSelectionMode
                && channels.count > 1
            if canRepeatManualOrder, let manualOrderIndex {
                card.onMoveCommand { direction in
                    switch direction {
                    case .up where manualOrderIndex > 0:
                        store.send(.moveFavoriteChannel(channelID: channel.id, offset: -1))
                    case .down where manualOrderIndex + 1 < manualOrderableCount:
                        store.send(.moveFavoriteChannel(channelID: channel.id, offset: 1))
                    default:
                        break
                    }
                }
            } else if canWrapFocus, index == 0, let lastChannelID = channels.last?.id {
                card.onMoveCommand { direction in
                    guard direction == .up else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        channelProxy.scrollTo(lastChannelID, anchor: .center)
                    }
                    focusedChannelID = lastChannelID
                }
            } else if canWrapFocus, index == channels.count - 1, let firstChannelID = channels.first?.id {
                card.onMoveCommand { direction in
                    guard direction == .down else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        channelProxy.scrollTo(firstChannelID, anchor: .center)
                    }
                    focusedChannelID = firstChannelID
                }
            } else {
                card
            }
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
            let isUnavailable = store.unavailableFavoriteChannelIDs.contains(channel.id)
            if isUnavailable,
               let unavailable = store.unavailableFavoriteChannels.first(where: { $0.channelID == channel.id }),
               let replacement = unavailable.replacement
            {
                Button {
                    store.send(.recoverUnavailableFavorite(channelID: channel.id, replacement: replacement))
                } label: {
                    Label(AppStrings.LiveTV.reattachFavorite(to: replacement.title), systemImage: "arrow.triangle.2.circlepath")
                }
            }

            Button {
                store.send(.toggleFavorite(channel))
            } label: {
                if store.favoriteIDs.contains(channel.id) {
                    Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                } else {
                    Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                }
            }

            FavoriteChannelManualOrderActions(store: store, channelID: channel.id)

            if !isUnavailable {
                RecentChannelExclusionMenuAction(store: store, channelID: channel.id)

                Button {
                    guard let playlistID = store.channelPresentationPlaylistID,
                          let profileScope = store.channelPresentationProfileScope else { return }
                    store.send(.openChannelPresentationEditor(
                        channel: channel, playlistID: playlistID, profileScope: profileScope
                    ))
                } label: {
                    Label(AppStrings.LiveTV.editChannelPresentation, systemImage: "character.cursor.ibeam")
                }

                if !store.favoriteLists.isEmpty {
                    Menu(AppStrings.LiveTV.addToFavoriteList) {
                        ForEach(store.favoriteLists) { list in
                            Button {
                                store.send(.toggleNamedFavorite(channel, listID: list.id))
                            } label: {
                                Label(list.name, systemImage: list.channelIDs.contains(channel.id) ? "checkmark.circle.fill" : "circle")
                            }
                        }
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
    }

    // MARK: - TV Category Row

    private struct TVCategoryRow: View {
        let category: MediaModels.Category
        let isSelected: Bool
        let isLocked: Bool
        let itemCount: Int?
        let action: () -> Void

        init(
            category: MediaModels.Category,
            isSelected: Bool,
            isLocked: Bool = false,
            itemCount: Int? = nil,
            action: @escaping () -> Void
        ) {
            self.category = category
            self.isSelected = isSelected
            self.isLocked = isLocked
            self.itemCount = itemCount
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

                    if let itemCount {
                        Text("\(itemCount)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(isSelected ? .white : Color(hex: "#C0C6D6").opacity(0.72))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                isSelected ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.08),
                                in: Capsule()
                            )
                    }

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
