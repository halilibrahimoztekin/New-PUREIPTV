import ComposableArchitecture
import SwiftUI

// MARK: - Edge-Swipe Channel & Category Sidebar Drawer (Madde #9)

/// Modularized, high-performance edge drawer for in-player channel switching.
/// Coordinates header controls, filter chips, fast fuzzy search, and optimized channel rows.
public struct PlayerSidebarDrawer: View {
    @Bindable var store: StoreOf<PlayerFeature>
    let onClose: () -> Void

    @State private var selectedFilter: ChannelCategoryFilter = .all
    @State private var searchQuery: String = ""
    @FocusState private var focusedItemID: String?
    #if os(tvOS)
        @AppStorage("com.pureiptv.tvOSChannelTitlesTwoLines") private var showTwoLineChannelTitles = false
    #endif

    public init(store: StoreOf<PlayerFeature>, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 0) {
            drawerContent
            #if os(tvOS)
                .frame(width: 580)
            #else
                .frame(width: min(370, UIScreen.main.bounds.width * 0.85))
            #endif
                .frame(maxHeight: .infinity)
                .background(
                    ZStack {
                        #if os(tvOS)
                            AppColors.oledBlack.opacity(0.88)
                        #else
                            Rectangle()
                                .fill(.ultraThinMaterial)
                            AppColors.oledBlack.opacity(0.55)
                        #endif
                    }
                )
                .overlay(
                    Rectangle()
                        .fill(AppColors.divider)
                        .frame(width: 1),
                    alignment: .trailing
                )
            #if os(tvOS)
                .focusSection()
            #endif

            // Tap-outside overlay to dismiss
            AppColors.oledBlack.opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    onClose()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .transition(.move(edge: .leading).combined(with: .opacity))
        .onAppear {
            focusedItemID = preferredChannelFocusID
        }
        .onChange(of: focusedItemID) { _, newID in
            if let newID, let ch = store.playlist?.first(where: { $0.id == newID }) {
                PrebufferingManager.shared.prepareChannel(
                    url: ch.streamURL,
                    userAgentOverride: ch.userAgentOverride
                )
            }
        }
        #if os(tvOS)
        .onExitCommand {
            onClose()
        }
        #endif
    }

    // MARK: - Drawer Content

    private var drawerContent: some View {
        let channels = filteredChannels
        return VStack(spacing: 0) {
            // Header
            PlayerDrawerHeaderView(
                store: store,
                selectedFilter: selectedFilter,
                channelCount: channels.count,
                onClose: onClose
            )

            // Search Bar
            PlayerDrawerSearchBarView(
                searchQuery: $searchQuery,
                accentColor: selectedFilter.accentColor
            )

            // Filter Tabs (Smart Category Filter Chips)
            PlayerDrawerFilterBar(
                chips: availableFilterChipItems,
                selectedFilter: $selectedFilter,
                onSelect: { filter in
                    handleFilterSelection(filter)
                }
            )

            Divider()
                .background(AppColors.divider)

            // Channel List or Empty State
            if channels.isEmpty {
                emptyStateView
            } else {
                channelsListView(channels: channels)
            }
        }
    }

    private func handleFilterSelection(_ filter: ChannelCategoryFilter) {
        if filter == .alternatives,
           store.autoSelectFirstAlternativeSource,
           let firstSource = firstAlternativeSource
        {
            store.send(.selectChannel(firstSource))
            return
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
            selectedFilter = filter
        }
    }

    // MARK: - Channels List

    private func channelsListView(channels: [PlayerFeature.PlayableItem]) -> some View {
        PlayerDrawerContentList(
            channels: channels,
            currentItemID: store.item.id,
            previousChannelID: store.previousChannel?.id,
            isCleaningEnabled: store.isChannelNameCleaningEnabled,
            channelSortOption: store.channelSortOption,
            channelWatchCounts: store.channelWatchCounts,
            showTwoLineTitles: {
                #if os(tvOS)
                    return showTwoLineChannelTitles
                #else
                    return false
                #endif
            }(),
            preferredFocusID: preferredChannelFocusID,
            focusedItemID: $focusedItemID,
            onSelect: { item in
                #if !os(tvOS)
                    HapticManager.shared.trigger(.medium)
                #endif
                store.send(.selectChannel(item))
            },
            onHide: { id, title in
                #if !os(tvOS)
                    HapticManager.shared.trigger(.warning)
                #endif
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    store.send(.hideChannel(id: id, title: title))
                }
            }
        )
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(selectedFilter.accentColor.opacity(0.15))
                    .frame(width: 72, height: 72)

                Image(systemName: "sparkle.magnifyingglass")
                    .font(AppFonts.displayMedium)
                    .foregroundStyle(selectedFilter.accentColor)
            }

            VStack(spacing: 6) {
                Text(AppStrings.LiveTV.noChannels)
                    .font(AppFonts.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(AppStrings.LiveTV.noChannelsMatchingFilter)
                    .font(AppFonts.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                    .padding(.horizontal, 32)
            }

            Button {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.medium)
                #endif
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedFilter = .all
                    searchQuery = ""
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(AppFonts.captionSmall.weight(.bold))
                    Text(AppStrings.LiveTV.clearFilter)
                        .font(AppFonts.bodySmall.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(AppColors.surfaceSecondary, in: Capsule())
                .foregroundStyle(AppColors.textPrimary)
            }
            #if os(tvOS)
            .tvFocusEffect()
            #else
            .buttonStyle(.plain)
            #endif

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filter Items Generator

    private var availableFilterChipItems: [PlayerDrawerFilterBar.FilterChipItem] {
        guard let list = store.playlist, !list.isEmpty else {
            return [PlayerDrawerFilterBar.FilterChipItem(filter: .all, count: 1)]
        }

        var altCount = 0
        var sportsCount = 0
        var newsCount = 0
        var cinemaCount = 0
        var docCount = 0
        var kidsCount = 0
        var uhdCount = 0
        var musicCount = 0

        var customCategoryCounts: [String: Int] = [:]
        var orderedCustomCategories: [String] = []

        let currentItemID = store.item.id
        let currentItemTitle = store.item.title

        for channel in list {
            if channel.isLive, channel.id != currentItemID, PlayerFeature.areAlternativeSources(channel.title, currentItemTitle) {
                altCount += 1
            }
            if ChannelCategoryFilter.sports.matches(title: channel.title, categoryID: channel.categoryID) {
                sportsCount += 1
            }
            if ChannelCategoryFilter.news.matches(title: channel.title, categoryID: channel.categoryID) {
                newsCount += 1
            }
            if ChannelCategoryFilter.cinema.matches(title: channel.title, categoryID: channel.categoryID) {
                cinemaCount += 1
            }
            if ChannelCategoryFilter.documentaries.matches(title: channel.title, categoryID: channel.categoryID) {
                docCount += 1
            }
            if ChannelCategoryFilter.kids.matches(title: channel.title, categoryID: channel.categoryID) {
                kidsCount += 1
            }
            if ChannelCategoryFilter.ultraHD4K.matches(title: channel.title, categoryID: channel.categoryID) {
                uhdCount += 1
            }
            if ChannelCategoryFilter.music.matches(title: channel.title, categoryID: channel.categoryID) {
                musicCount += 1
            }

            if let cat = channel.categoryID, !cat.isEmpty {
                if customCategoryCounts[cat] == nil {
                    if orderedCustomCategories.count < 15 {
                        orderedCustomCategories.append(cat)
                    }
                }
                customCategoryCounts[cat, default: 0] += 1
            }
        }

        var result: [PlayerDrawerFilterBar.FilterChipItem] = [
            PlayerDrawerFilterBar.FilterChipItem(filter: .all, count: list.count),
        ]

        if altCount > 0 {
            result.append(PlayerDrawerFilterBar.FilterChipItem(filter: .alternatives, count: altCount))
        }

        if !store.zappingHistory.isEmpty {
            result.append(PlayerDrawerFilterBar.FilterChipItem(filter: .history, count: store.zappingHistory.count))
        }

        if sportsCount > 0 {
            result.append(PlayerDrawerFilterBar.FilterChipItem(filter: .sports, count: sportsCount))
        }
        if newsCount > 0 {
            result.append(PlayerDrawerFilterBar.FilterChipItem(filter: .news, count: newsCount))
        }
        if cinemaCount > 0 {
            result.append(PlayerDrawerFilterBar.FilterChipItem(filter: .cinema, count: cinemaCount))
        }
        if docCount > 0 {
            result.append(PlayerDrawerFilterBar.FilterChipItem(filter: .documentaries, count: docCount))
        }
        if kidsCount > 0 {
            result.append(PlayerDrawerFilterBar.FilterChipItem(filter: .kids, count: kidsCount))
        }
        if uhdCount > 0 {
            result.append(PlayerDrawerFilterBar.FilterChipItem(filter: .ultraHD4K, count: uhdCount))
        }
        if musicCount > 0 {
            result.append(PlayerDrawerFilterBar.FilterChipItem(filter: .music, count: musicCount))
        }

        for cat in orderedCustomCategories {
            if let count = customCategoryCounts[cat], count > 0 {
                result.append(PlayerDrawerFilterBar.FilterChipItem(filter: .custom(cat), count: count))
            }
        }

        return result
    }

    private var filteredChannels: [PlayerFeature.PlayableItem] {
        let rawList: [PlayerFeature.PlayableItem] = switch selectedFilter {
        case .all:
            store.playlist ?? [store.item]
        case .history:
            store.zappingHistory
        case .alternatives:
            (store.playlist ?? []).filter {
                $0.isLive && $0.id != store.item.id
                    && PlayerFeature.areAlternativeSources($0.title, store.item.title)
            }
        default:
            (store.playlist ?? [store.item]).filter {
                selectedFilter.matches(title: $0.title, categoryID: $0.categoryID)
            }
        }

        // Filter out hidden channels and blacklisted categories (Madde #19)
        let baseList = rawList.filter {
            !store.hiddenChannelIDs.contains($0.id) &&
                !store.blacklistedCategoryIDs.contains($0.categoryID ?? "")
        }

        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return store.channelSortOption.sort(
                items: baseList,
                playlist: store.playlist,
                idKeyPath: \.id,
                titleKeyPath: \.title,
                watchCounts: store.channelWatchCounts,
                recentIDs: store.recentChannels.map(\.id)
            )
        } else {
            return FuzzySearchEngine.search(baseList, titleKeyPath: \.title, query: trimmed, limit: 120)
        }
    }

    private var preferredChannelFocusID: String? {
        let channels = filteredChannels
        return channels.first(where: { $0.id == store.item.id })?.id ?? channels.first?.id
    }

    private var firstAlternativeSource: PlayerFeature.PlayableItem? {
        (store.playlist ?? []).first { candidate in
            candidate.isLive
                && candidate.id != store.item.id
                && !store.hiddenChannelIDs.contains(candidate.id)
                && !store.blacklistedCategoryIDs.contains(candidate.categoryID ?? "")
                && PlayerFeature.areAlternativeSources(candidate.title, store.item.title)
        }
    }
}
