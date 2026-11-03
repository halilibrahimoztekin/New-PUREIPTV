import ComposableArchitecture
import SwiftUI

// MARK: - Edge-Swipe Channel & Category Sidebar Drawer (Madde #9)

public struct PlayerSidebarDrawer: View {
    @Bindable var store: StoreOf<PlayerFeature>
    let onClose: () -> Void

    @State private var selectedFilter: ChannelCategoryFilter = .all
    @State private var searchQuery: String = ""
    @FocusState private var focusedItemID: String?
    @FocusState private var focusedFilterID: String?
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
                            Color.black.opacity(0.88)
                        #else
                            Rectangle()
                                .fill(.ultraThinMaterial)
                            Color.black.opacity(0.55)
                        #endif
                    }
                )
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1),
                    alignment: .trailing
                )
            #if os(tvOS)
                .focusSection()
            #endif

            // Tap-outside overlay to dismiss
            Color.black.opacity(0.001)
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
            headerView(channelCount: channels.count)

            // Search Bar
            searchBarView

            // Filter Tabs (Smart Category Filter Chips)
            filterTabsView

            Divider()
                .background(Color.white.opacity(0.12))

            // Channel List or Empty State
            if channels.isEmpty {
                emptyStateView
            } else {
                channelsListView(channels: channels)
            }
        }
    }

    // MARK: - Header

    private func headerView(channelCount: Int) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(selectedFilter.accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: selectedFilter.icon)
                #if os(tvOS)
                    .font(.system(size: 22, weight: .bold))
                #else
                    .font(.system(size: 18, weight: .bold))
                #endif
                    .foregroundStyle(selectedFilter.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.LiveTV.channelsTitle)
                #if os(tvOS)
                    .font(.system(size: 24, weight: .bold))
                #else
                    .font(.headline.weight(.bold))
                #endif
                    .foregroundStyle(.white)

                let count = channelCount
                HStack(spacing: 6) {
                    Text("\(count) " + "Kanal".localized)
                        .foregroundStyle(.white.opacity(0.6))

                    if selectedFilter != .all {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.4))
                        Text(selectedFilter.title)
                            .foregroundStyle(selectedFilter.accentColor)
                            .fontWeight(.semibold)
                    }
                }
                #if os(tvOS)
                .font(.system(size: 15, weight: .medium))
                #else
                .font(.caption)
                #endif
            }

            Spacer()

            // Cleaner & Sort Controls (Madde #12 & #16)
            HStack(spacing: 8) {
                cleanerToggleButton
                sortMenuButton
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                #if os(tvOS)
                    .font(.system(size: 28))
                #else
                    .font(.title3)
                #endif
                    .foregroundStyle(.white.opacity(0.75))
            }
            #if os(tvOS)
            .buttonStyle(TVCircleButtonStyle())
            #else
            .buttonStyle(.plain)
            #endif
        }
        #if os(tvOS)
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 14)
        #else
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 12)
        #endif
    }

    // MARK: - Sort Menu Button (Madde #12)

    private var sortMenuButton: some View {
        Menu {
            Section(AppStrings.LiveTV.sortTitle) {
                ForEach(ChannelSortOption.allCases) { option in
                    Button {
                        #if !os(tvOS)
                            HapticManager.shared.trigger(.light)
                        #endif
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            store.send(.setChannelSortOption(option))
                        }
                    } label: {
                        HStack {
                            Label(option.title, systemImage: option.icon)
                            if store.channelSortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: store.channelSortOption.icon)
                #if os(tvOS)
                    .font(.system(size: 16, weight: .bold))
                #else
                    .font(.system(size: 12, weight: .bold))
                #endif
                    .foregroundStyle(store.channelSortOption.accentColor)

                Text(store.channelSortOption.title)
                #if os(tvOS)
                    .font(.system(size: 15, weight: .semibold))
                #else
                    .font(.caption.weight(.semibold))
                #endif
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            #if os(tvOS)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            #else
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            #endif
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(store.channelSortOption.accentColor.opacity(0.35), lineWidth: 1)
            )
        }
        #if os(tvOS)
        .buttonStyle(TVSortOptionButtonStyle(accentColor: store.channelSortOption.accentColor))
        #else
        .buttonStyle(.plain)
        #endif
    }

    // MARK: - Cleaner Toggle Button (Madde #16)

    private var cleanerToggleButton: some View {
        Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                store.send(.toggleChannelNameCleaning)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: store.isChannelNameCleaningEnabled ? "wand.and.stars" : "wand.and.stars.inverse")
                #if os(tvOS)
                    .font(AppFonts.caption.bold())
                #else
                    .font(AppFonts.caption.bold())
                #endif
                    .foregroundStyle(store.isChannelNameCleaningEnabled ? AppColors.warningGold : AppColors.textSecondary.opacity(0.5))

                #if !os(tvOS)
                    Text(store.isChannelNameCleaningEnabled ? "Sade" : "Ham")
                        .font(AppFonts.caption.bold())
                        .foregroundStyle(store.isChannelNameCleaningEnabled ? AppColors.warningGold : AppColors.textSecondary.opacity(0.6))
                #endif
            }
            #if os(tvOS)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            #else
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            #endif
            .background(
                Capsule()
                    .fill(store.isChannelNameCleaningEnabled ? AppColors.warningGold.opacity(0.15) : AppColors.borderSubtle)
            )
            .overlay(
                Capsule()
                    .stroke(store.isChannelNameCleaningEnabled ? AppColors.warningGold.opacity(0.4) : AppColors.borderMedium, lineWidth: 1)
            )
        }
        #if os(tvOS)
        .buttonStyle(TVCleanerButtonStyle(isActive: store.isChannelNameCleaningEnabled))
        #else
        .buttonStyle(.plain)
        #endif
    }

    // MARK: - Search Bar

    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.55))
            #if os(tvOS)
                .font(.system(size: 22))
            #else
                .font(.system(size: 15))
            #endif

            TextField(AppStrings.Search.channelSearchPlaceholder, text: $searchQuery)
            #if os(tvOS)
                .font(.system(size: 20, weight: .medium))
            #else
                .font(.system(size: 14, weight: .medium))
            #endif
                .foregroundStyle(.white)
                .tint(selectedFilter.accentColor)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                    #if os(tvOS)
                        .font(.system(size: 20))
                    #else
                        .font(.system(size: 15))
                    #endif
                }
                #if os(tvOS)
                .buttonStyle(TVCircleButtonStyle())
                #else
                .buttonStyle(.plain)
                #endif
            }
        }
        #if os(tvOS)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 32)
        .padding(.bottom, 14)
        #else
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        #endif
    }

    // MARK: - Filter Tabs (Smart Category Filter Chips)

    private struct FilterChipItem: Identifiable, Equatable {
        let filter: ChannelCategoryFilter
        let count: Int
        var id: String {
            filter.id
        }
    }

    private var filterTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilterChipItems) { chip in
                    filterChipView(filter: chip.filter, count: chip.count)
                        .id(chip.id)
                }
            }
            #if os(tvOS)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
            .focusSection()
            #else
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            #endif
        }
    }

    @ViewBuilder
    private func filterChipView(filter: ChannelCategoryFilter, count: Int) -> some View {
        let isSelected = selectedFilter == filter

        Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
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
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : filter.accentColor)

                Text(filter.title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)

                // Channel Count Badge
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .white : .white.opacity(0.75))
            .background(
                Capsule()
                    .fill(isSelected ? filter.accentColor : Color.white.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.white.opacity(0.5) : filter.accentColor.opacity(0.25),
                        lineWidth: 1
                    )
            )
        }
        #if os(tvOS)
        .buttonStyle(TVCategoryFilterChipButtonStyle(isSelected: isSelected, accentColor: filter.accentColor))
        .focused($focusedFilterID, equals: filter.id)
        #else
        .buttonStyle(.plain)
        #endif
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
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(selectedFilter.accentColor)
            }

            VStack(spacing: 6) {
                Text(AppStrings.LiveTV.noChannels)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(AppStrings.LiveTV.noChannelsMatchingFilter)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.6))
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
                        .font(.system(size: 13, weight: .bold))
                    Text(AppStrings.LiveTV.clearFilter)
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.12), in: Capsule())
                .foregroundStyle(.white)
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

    // MARK: - Channels List

    private func channelsListView(channels: [PlayerFeature.PlayableItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(channels.enumerated()), id: \.element.id) { index, item in
                        channelRow(item: item, index: index + 1)
                            .id(item.id)
                    }
                }
                #if os(tvOS)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                #else
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                #endif
            }
            .onAppear {
                guard let restorationID = preferredChannelFocusID else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    guard focusedItemID == restorationID,
                          channels.contains(where: { $0.id == restorationID })
                    else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(restorationID, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Channel Row

    @ViewBuilder
    private func channelRow(item: PlayerFeature.PlayableItem, index: Int) -> some View {
        let isCurrent = item.id == store.item.id
        let isPrevious = item.id == store.previousChannel?.id
        let metadata = item.cleanedMetadata
        let displayTitle = store.isChannelNameCleaningEnabled ? item.cleanTitle : item.title
        let hasCatchup = (item.tvArchive ?? 0) > 0

        Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.medium)
            #endif
            store.send(.selectChannel(item))
        } label: {
            HStack(spacing: 12) {
                // Index Number
                Text("\(index)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 32, alignment: .trailing)

                // Channel Logo
                channelLogo(item: item)

                // Channel Title & Category
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayTitle)
                    #if os(tvOS)
                        .font(.system(size: 19, weight: isCurrent ? .bold : .medium))
                    #else
                        .font(.subheadline.weight(isCurrent ? .bold : .regular))
                    #endif
                        .foregroundStyle(isCurrent ? AppColors.primary : AppColors.textPrimary)
                    #if os(tvOS)
                        .lineLimit(showTwoLineChannelTitles ? 2 : 1)
                    #else
                        .lineLimit(1)
                    #endif
                        .accessibilityLabel(item.title)

                    HStack(spacing: 5) {
                        if let cat = item.categoryID, !cat.isEmpty {
                            Text(cat)
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                                .lineLimit(1)
                        } else if let epgID = item.epgChannelID {
                            Text(epgID)
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                                .lineLimit(1)
                        }

                        // Country Badge
                        if let country = metadata.detectedCountry {
                            Text(country)
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary.opacity(0.8))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(AppColors.borderMedium)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

                        // Quality Badge
                        if let q = metadata.detectedQuality {
                            Text(q.rawValue)
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: q.badgeColorHex))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(hex: q.badgeColorHex).opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

                        // HEVC Badge
                        if metadata.isHEVC {
                            Text("HEVC")
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.premium)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(AppColors.premium.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

                        // Catchup Archive Indicator
                        if hasCatchup {
                            HStack(spacing: 2) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 8, weight: .bold))
                                Text("ARŞİV")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundStyle(AppColors.warningGold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppColors.warningGold.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        }

                        // Watch Count Badge (Madde #12)
                        if store.channelSortOption == .mostWatched, let count = store.channelWatchCounts[item.id], count > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 8, weight: .bold))
                                Text("\(count)x")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundStyle(AppColors.warning)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppColors.warning.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }

                Spacer()

                // State Badges
                if isCurrent {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(AppColors.success)
                            .frame(width: 7, height: 7)
                        Text(AppStrings.Player.liveLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.success)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.success.opacity(0.18))
                    .clipShape(Capsule())
                } else if isPrevious {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .bold))
                        Text(AppStrings.Player.recallLastChannel)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .foregroundStyle(AppColors.warning)
                    .background(AppColors.warning.opacity(0.18))
                    .clipShape(Capsule())
                }
            }
            #if os(tvOS)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            #else
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            #endif
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrent ? AppColors.primary.opacity(0.18) : AppColors.borderSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isCurrent ? AppColors.primary.opacity(0.6) : AppColors.divider,
                        lineWidth: 1
                    )
            )
        }
        #if os(tvOS)
        .tvFocusEffect()
        #else
        .buttonStyle(.plain)
        #endif
        .focused($focusedItemID, equals: item.id)
        .accessibilityLabel(item.title)
        .contextMenu {
            Button(role: .destructive) {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.warning)
                #endif
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    store.send(.hideChannel(id: item.id, title: item.title))
                }
            } label: {
                Label("Kanalı Gizle", systemImage: "eye.slash.fill")
            }
        }
    }

    // MARK: - Channel Logo

    @ViewBuilder
    private func channelLogo(item: PlayerFeature.PlayableItem) -> some View {
        Group {
            if let coverURL = item.coverURL {
                PlaylistAsyncImage(url: coverURL, fallbackURL: item.fallbackCoverURL, userAgentOverride: item.userAgentOverride, playlistID: item.config?.playlistID) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .empty:
                        PureLoadingView(size: .small)
                    case .failure:
                        fallbackLogo
                    @unknown default:
                        fallbackLogo
                    }
                }
            } else {
                fallbackLogo
            }
        }
        #if os(tvOS)
        .frame(width: 48, height: 48)
        #else
        .frame(width: 38, height: 38)
        #endif
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
        )
    }

    private var fallbackLogo: some View {
        Image(systemName: "tv")
            .font(.system(size: 16))
            .foregroundStyle(.white.opacity(0.5))
    }

    // MARK: - Filter Logic & Counts

    private var availableFilterChipItems: [FilterChipItem] {
        guard let list = store.playlist, !list.isEmpty else {
            return [FilterChipItem(filter: .all, count: 1)]
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

        var result: [FilterChipItem] = [
            FilterChipItem(filter: .all, count: list.count),
        ]

        if altCount > 0 {
            result.append(FilterChipItem(filter: .alternatives, count: altCount))
        }

        if !store.zappingHistory.isEmpty {
            result.append(FilterChipItem(filter: .history, count: store.zappingHistory.count))
        }

        if sportsCount > 0 {
            result.append(FilterChipItem(filter: .sports, count: sportsCount))
        }
        if newsCount > 0 {
            result.append(FilterChipItem(filter: .news, count: newsCount))
        }
        if cinemaCount > 0 {
            result.append(FilterChipItem(filter: .cinema, count: cinemaCount))
        }
        if docCount > 0 {
            result.append(FilterChipItem(filter: .documentaries, count: docCount))
        }
        if kidsCount > 0 {
            result.append(FilterChipItem(filter: .kids, count: kidsCount))
        }
        if uhdCount > 0 {
            result.append(FilterChipItem(filter: .ultraHD4K, count: uhdCount))
        }
        if musicCount > 0 {
            result.append(FilterChipItem(filter: .music, count: musicCount))
        }

        for cat in orderedCustomCategories {
            if let count = customCategoryCounts[cat], count > 0 {
                result.append(FilterChipItem(filter: .custom(cat), count: count))
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

    /// Returns the first eligible match in provider playlist order. Availability
    /// is intentionally determined by normal playback and retry behavior; no
    /// network probe is issued before selecting this candidate.
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

// MARK: - tvOS Category Filter Chip Button Style

#if os(tvOS)
    private struct TVCategoryFilterChipButtonStyle: ButtonStyle {
        let isSelected: Bool
        let accentColor: Color

        func makeBody(configuration: Configuration) -> some View {
            TVCategoryFilterChipBody(configuration: configuration, isSelected: isSelected, accentColor: accentColor)
        }

        private struct TVCategoryFilterChipBody: View {
            let configuration: Configuration
            let isSelected: Bool
            let accentColor: Color
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .scaleEffect(isFocused ? 1.08 : 1.0)
                    .brightness(isFocused ? 0.15 : 0.0)
                    .shadow(
                        color: isFocused ? accentColor.opacity(0.65) : .clear,
                        radius: isFocused ? 10 : 0,
                        x: 0,
                        y: 0
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
                    .tvHighContrastFocusOutline(isFocused: isFocused, shape: .capsule)
            }
        }
    }

    private struct TVSortOptionButtonStyle: ButtonStyle {
        let accentColor: Color

        func makeBody(configuration: Configuration) -> some View {
            TVSortOptionBody(configuration: configuration, accentColor: accentColor)
        }

        private struct TVSortOptionBody: View {
            let configuration: Configuration
            let accentColor: Color
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .scaleEffect(isFocused ? 1.08 : 1.0)
                    .brightness(isFocused ? 0.2 : 0.0)
                    .shadow(
                        color: isFocused ? accentColor.opacity(0.8) : .clear,
                        radius: isFocused ? 10 : 0,
                        x: 0,
                        y: 0
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
                    .tvHighContrastFocusOutline(isFocused: isFocused, shape: .roundedRectangle(cornerRadius: 12))
            }
        }
    }

    private struct TVCleanerButtonStyle: ButtonStyle {
        let isActive: Bool

        func makeBody(configuration: Configuration) -> some View {
            TVCleanerBody(configuration: configuration, isActive: isActive)
        }

        private struct TVCleanerBody: View {
            let configuration: Configuration
            let isActive: Bool
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .scaleEffect(isFocused ? 1.08 : 1.0)
                    .brightness(isFocused ? 0.25 : 0.0)
                    .shadow(
                        color: isFocused ? (isActive ? AppColors.warningGold.opacity(0.8) : Color.white.opacity(0.5)) : .clear,
                        radius: isFocused ? 10 : 0,
                        x: 0,
                        y: 0
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
                    .tvHighContrastFocusOutline(isFocused: isFocused, shape: .roundedRectangle(cornerRadius: 12))
            }
        }
    }
#endif
