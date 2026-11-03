#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Live TV Channel Grid (iOS)

    /// Decomposed grid of live channels with context menu actions,
    /// selection overlays, and sufficient bottom inset to clear the floating tab bar.
    struct LiveTVChannelGrid_iOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        let config: PlaylistConfig

        private let columns: [GridItem] = [
            GridItem(.adaptive(minimum: 155, maximum: 200), spacing: 12),
        ]

        var body: some View {
            ScrollView {
                if store.isLoadingChannels, store.displayChannels.isEmpty {
                    loadingShimmerView
                } else if store.displayChannels.isEmpty {
                    emptyStateView
                } else {
                    channelsContent
                }
            }
        }

        // MARK: - Channels Content

        private var channelsContent: some View {
            VStack(spacing: 14) {
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

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.displayChannels) { channel in
                        channelItemView(channel)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }

        // MARK: - Single Channel Item

        @ViewBuilder
        private func channelItemView(_ channel: MediaModels.Item) -> some View {
            let isUnavailable = store.unavailableFavoriteChannelIDs.contains(channel.id)
            let isSelected = store.selectedChannel?.id == channel.id
            let isMarked = store.selectedCurrentChannelIDs.contains(channel.id)

            ChannelCardView(
                channel: channel,
                isSelected: isSelected,
                presentationName: store.channelPresentationOverrides[channel.id]?.name,
                presentationNumber: store.channelPresentationOverrides[channel.id]?.number,
                selectionMode: store.isChannelSelectionMode,
                isMarkedForBulkAction: isMarked
            ) {
                store.send(store.isChannelSelectionMode ? .toggleChannelSelection(channel) : .channelSelected(channel))
            }
            .overlay(alignment: .topLeading) {
                if isUnavailable {
                    Text(AppStrings.LiveTV.unavailableFavoriteChannel)
                        .font(AppFonts.captionSmall.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.72), in: Capsule())
                        .padding(10)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityValue(isUnavailable
                ? AppStrings.LiveTV.unavailableFavoriteChannel
                : (store.isChannelSelectionMode
                    ? (isMarked ? AppStrings.LiveTV.selected : AppStrings.LiveTV.notSelected)
                    : ""))
            .accessibilityHint(isUnavailable ? AppStrings.LiveTV.unavailableFavoriteChannelHint : "")
            .overlay(alignment: .topTrailing) {
                if store.isChannelSelectionMode, !isUnavailable {
                    Image(systemName: isMarked ? "checkmark.circle.fill" : "circle")
                        .font(AppFonts.titleSmall)
                        .foregroundStyle(isMarked ? AppColors.primary : AppColors.textPrimary)
                        .padding(10)
                        .accessibilityHidden(true)
                }
            }
            .contextMenu {
                channelContextMenu(for: channel, isUnavailable: isUnavailable)
            }
        }

        // MARK: - Context Menu

        @ViewBuilder
        private func channelContextMenu(for channel: MediaModels.Item, isUnavailable: Bool) -> some View {
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
                                Label(list.name,
                                      systemImage: list.channelIDs.contains(channel.id) ? "checkmark.circle.fill" : "circle")
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
                    store.send(.openChannelEPG(channel))
                } label: {
                    Label(AppStrings.LiveTV.channelGuide, systemImage: "calendar.badge.clock")
                }

                Button(role: .destructive) {
                    store.send(.hideChannel(channel))
                } label: {
                    Label(AppStrings.LiveTV.hideChannel, systemImage: "eye.slash")
                }
            }
        }

        // MARK: - Empty & Loading States

        private var loadingShimmerView: some View {
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
            .padding(.bottom, 120)
        }

        @ViewBuilder
        private var emptyStateView: some View {
            if store.selectedSmartGroupID == nil,
               !store.isFavoriteListMode,
               let categoryID = store.selectedCategoryID,
               let error = store.categoryContentErrors[categoryID]
            {
                RetryableSectionEmptyState(message: error) {
                    store.send(.retryCategoryContent(categoryID: categoryID))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                .padding(.bottom, 120)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "tv.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                    Text(AppStrings.LiveTV.emptyCategoryLive)
                        .font(AppFonts.bodyMedium)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                .padding(.bottom, 120)
            }
        }
    }
#endif
