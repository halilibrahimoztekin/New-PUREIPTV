#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Live TV Channel Grid (tvOS)

    /// Dedicated subview for tvOS Live TV channel shelf and grid.
    /// Manages focus navigation, wrap-around scrolling, context menus, and manual ordering.
    public struct LiveTVChannelGrid_tvOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        var focusedChannelID: FocusState<String?>.Binding
        @Binding var currentScrubLetter: String
        @Binding var isScrubOverlayVisible: Bool
        let isFavoriteWrapAroundFocusEnabled: Bool
        let onFocusChanged: (String?) -> Void

        public init(
            store: StoreOf<LiveTVFeature>,
            focusedChannelID: FocusState<String?>.Binding,
            currentScrubLetter: Binding<String>,
            isScrubOverlayVisible: Binding<Bool>,
            isFavoriteWrapAroundFocusEnabled: Bool,
            onFocusChanged: @escaping (String?) -> Void
        ) {
            self.store = store
            self.focusedChannelID = focusedChannelID
            _currentScrubLetter = currentScrubLetter
            _isScrubOverlayVisible = isScrubOverlayVisible
            self.isFavoriteWrapAroundFocusEnabled = isFavoriteWrapAroundFocusEnabled
            self.onFocusChanged = onFocusChanged
        }

        public var body: some View {
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
                    emptyOrErrorState
                } else {
                    channelScrollView
                }
            }
        }

        // MARK: - Empty / Error State

        @ViewBuilder
        private var emptyOrErrorState: some View {
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
                        .font(AppFonts.displayLarge)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.35))
                    Text(AppStrings.LiveTV.noChannels)
                        .font(AppFonts.headline)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        // MARK: - Category Quick Jump Menu

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
                    .font(AppFonts.captionBold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(AppColors.glassPlate, in: Capsule())
            }
            .accessibilityLabel(AppStrings.LiveTV.categoryQuickJump)
            .tvFocusEffect(shape: .capsule)
        }

        // MARK: - Channel Scroll View

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
                        focusedChannelID.wrappedValue = channelID
                        withAnimation { channelProxy.scrollTo(channelID, anchor: .center) }
                    }
                }
                .onChange(of: store.channelFocusRestoreRevision) { _, _ in
                    guard let channelID = store.selectedChannel?.id,
                          store.displayChannels.contains(where: { $0.id == channelID }),
                          focusedChannelID.wrappedValue != channelID else { return }
                    TVFocusMemory.shared.recordChannel(channelID, in: store.selectedCategoryID)
                    focusedChannelID.wrappedValue = channelID
                    withAnimation { channelProxy.scrollTo(channelID, anchor: .center) }
                }
                .onChange(of: store.selectedCategoryID) { _, newCatID in
                    let targetID = TVFocusMemory.shared.lastChannel(
                        in: newCatID,
                        fallback: store.displayChannels.first?.id
                    )
                    if let targetID {
                        focusedChannelID.wrappedValue = targetID
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
                        focusedChannelID.wrappedValue = targetID
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation { channelProxy.scrollTo(targetID, anchor: .center) }
                        }
                    }
                }
                .onChange(of: focusedChannelID.wrappedValue) { _, newID in
                    onFocusChanged(newID)
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

        // MARK: - Channel Grid

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

        // MARK: - Channel Card with tvOS Focus & Manual Order

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
                        .font(AppFonts.captionBold)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.oledBlack.opacity(0.85), in: Capsule())
                        .padding(12)
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .topTrailing) {
                if store.isChannelSelectionMode {
                    Image(systemName: store.selectedCurrentChannelIDs.contains(channel.id) ? "checkmark.circle.fill" : "circle")
                        .font(AppFonts.title)
                        .foregroundStyle(store.selectedCurrentChannelIDs.contains(channel.id) ? AppColors.primary : AppColors.textPrimary)
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
            .focused(focusedChannelID, equals: channel.id)
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
                    focusedChannelID.wrappedValue = lastChannelID
                }
            } else if canWrapFocus, index == channels.count - 1, let firstChannelID = channels.first?.id {
                card.onMoveCommand { direction in
                    guard direction == .down else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        channelProxy.scrollTo(firstChannelID, anchor: .center)
                    }
                    focusedChannelID.wrappedValue = firstChannelID
                }
            } else {
                card
            }
        }

        // MARK: - Channel Context Menu

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
#endif
