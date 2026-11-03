#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Live TV iPad Channel List (Column 2)

    /// Middle column for iPad split view displaying channels list,
    /// search, sort options, and multi-selection controls with design tokens.
    struct LiveTVChannelList_iPad: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        @Binding var channelSearchQuery: String

        private var filteredChannels: [MediaModels.Item] {
            let base = store.displayChannels
            let query = channelSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty {
                return base
            }
            return base.filter { $0.title.localizedCaseInsensitiveContains(query) }
        }

        var body: some View {
            VStack(spacing: 0) {
                headerView
                searchBarView
                Divider().background(AppColors.borderSubtle)

                if store.isLoadingChannels {
                    Spacer()
                    PureLoadingView(size: .medium)
                    Spacer()
                } else if filteredChannels.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tv.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                        Text(AppStrings.LiveTV.noChannels)
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                    }
                    Spacer()
                } else {
                    channelsScrollView
                }
            }
            .frame(width: 340)
            .background(AppColors.surfaceContainer)
        }

        // MARK: - Header View

        private var headerView: some View {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.categories.first(where: { $0.id == store.selectedCategoryID })?.name ?? AppStrings.LiveTV.channelsTitle)
                        .font(AppFonts.titleSmall.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text("\(filteredChannels.count) \(AppStrings.LiveTV.channelsTitle.lowercased())")
                        .font(AppFonts.captionSmall)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                }

                Button {
                    store.send(store.isChannelSelectionMode ? .exitChannelSelectionMode : .enterChannelSelectionMode)
                } label: {
                    Label(
                        store.isChannelSelectionMode ? AppStrings.LiveTV.cancelChannelSelection : AppStrings.LiveTV.selectChannels,
                        systemImage: store.isChannelSelectionMode ? "xmark" : "checklist"
                    )
                    .font(AppFonts.captionSemibold)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.primary)

                Spacer()

                LiquidGlassContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        LiveTVChannelSortMenu(store: store)

                        Button {
                            store.send(.openMultiViewTapped)
                        } label: {
                            Image(systemName: "square.split.2x2.fill")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                                .frame(width: 30, height: 30)
                        }
                        .liquidGlass(shape: .circle, isInteractive: true)
                        .buttonStyle(.plain)

                        Button {
                            store.send(.openEPGTimelineTapped)
                        } label: {
                            Image(systemName: "calendar.day.timeline.left")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                                .frame(width: 30, height: 30)
                        }
                        .liquidGlass(shape: .circle, isInteractive: true)
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }

        // MARK: - Search Bar

        private var searchBarView: some View {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                    .font(AppFonts.caption)
                TextField(AppStrings.Search.searchPlaceholder, text: $channelSearchQuery)
                    .font(AppFonts.bodySmall)
                    .foregroundStyle(AppColors.textPrimary)
                if !channelSearchQuery.isEmpty {
                    Button { channelSearchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                            .font(AppFonts.caption)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppColors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }

        // MARK: - Channels Scroll View

        private var channelsScrollView: some View {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredChannels) { channel in
                        channelRow(channel: channel)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }

        // MARK: - Channel Row

        private func channelRow(channel: MediaModels.Item) -> some View {
            let isSelected = store.selectedChannel?.id == channel.id
            let isBulkSelected = store.selectedCurrentChannelIDs.contains(channel.id)
            let isUnavailable = store.unavailableFavoriteChannelIDs.contains(channel.id)

            return Button {
                if store.isChannelSelectionMode {
                    store.send(.toggleChannelSelection(channel))
                } else {
                    store.send(.selectChannelPreview(channel))
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppColors.surfaceSecondary)
                            .frame(width: 44, height: 44)

                        if let coverURL = channel.displayLogoURL {
                            PlaylistAsyncImage(url: coverURL, fallbackURL: channel.coverURL, userAgentOverride: channel.userAgentOverride, playlistID: channel.playlistID) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFit()
                                } else {
                                    Image(systemName: "tv").foregroundStyle(AppColors.textSecondary.opacity(0.4))
                                }
                            }
                            .frame(width: 38, height: 38)
                        } else {
                            Image(systemName: "tv")
                                .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            if let number = store.channelPresentationOverrides[channel.id]?.number {
                                Text(String(number))
                                    .font(AppFonts.captionSmall.weight(.bold).monospacedDigit())
                                    .foregroundStyle(AppColors.sky)
                            }
                            Text(store.channelPresentationOverrides[channel.id]?.name ?? channel.title)
                                .font(isSelected ? AppFonts.bodySmall.weight(.bold) : AppFonts.bodySmall.weight(.medium))
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 6) {
                            if store.favoriteIDs.contains(channel.id) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppColors.destructive)
                            }

                            Text(AppStrings.LiveTV.title)
                                .font(AppFonts.captionSmall)
                                .foregroundStyle(AppColors.textSecondary.opacity(0.6))

                            if isUnavailable {
                                Text(AppStrings.LiveTV.unavailableFavoriteChannel)
                                    .font(AppFonts.captionSmall.weight(.semibold))
                                    .foregroundStyle(AppColors.warning)
                            }
                        }
                    }

                    Spacer()

                    if store.isChannelSelectionMode, !isUnavailable {
                        Image(systemName: isBulkSelected ? "checkmark.circle.fill" : "circle")
                            .font(AppFonts.titleSmall)
                            .foregroundStyle(isBulkSelected ? AppColors.primary : AppColors.textSecondary.opacity(0.7))
                            .accessibilityHidden(true)
                    }

                    Button {
                        HapticManager.shared.trigger(.medium)
                        store.send(store.isChannelSelectionMode ? .toggleChannelSelection(channel) : .channelSelected(channel))
                    } label: {
                        Image(systemName: isUnavailable ? "tv.slash.fill" : "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(isSelected ? AppColors.primary : AppColors.textSecondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel([store.channelPresentationOverrides[channel.id]?.number.map(String.init), store.channelPresentationOverrides[channel.id]?.name ?? channel.title].compactMap(\.self).joined(separator: ", "))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected ? AppColors.primary.opacity(0.18) : AppColors.surfaceSecondary.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                channelContextMenu(for: channel, isUnavailable: isUnavailable)
            }
        }

        // MARK: - Context Menu

        @ViewBuilder
        private func channelContextMenu(for channel: MediaModels.Item, isUnavailable: Bool) -> some View {
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
    }
#endif
