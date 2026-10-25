import ComposableArchitecture
import SwiftUI

public struct EPGTimelineView: View {
    @Bindable var store: StoreOf<EPGTimelineFeature>

    // Dimensions
    #if os(tvOS)
        private let hourWidth: CGFloat = 340
        private let standardRowHeight: CGFloat = 78
        private let compactRowHeight: CGFloat = 58
        private let standardChannelColumnWidth: CGFloat = 170
        private let compactChannelColumnWidth: CGFloat = 190
        private let timeHeaderHeight: CGFloat = 46
    #else
        private let hourWidth: CGFloat = 240
        private let standardRowHeight: CGFloat = 64
        private let compactRowHeight: CGFloat = 48
        private let standardChannelColumnWidth: CGFloat = 115
        private let compactChannelColumnWidth: CGFloat = 132
        private let timeHeaderHeight: CGFloat = 42
    #endif

    @AppStorage("epgTimelineCompactMode") private var isCompactMode = false

    private var rowHeight: CGFloat {
        isCompactMode ? compactRowHeight : standardRowHeight
    }

    private var channelColumnWidth: CGFloat {
        isCompactMode ? compactChannelColumnWidth : standardChannelColumnWidth
    }

    private let totalHoursCount: Int = 24
    private let pastHoursAnchor: Int = 4

    // Horizontal Scroll State
    @State private var horizontalOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var isUserDragging: Bool = false
    @State private var hasCenteredOnNow: Bool = false
    @State private var shimmerPhase: CGFloat = 0
    @State private var logoEditorChannel: MediaModels.Item?
    @State private var logoURLDraft = ""
    #if os(tvOS)
        @State private var restoringProgramFocusID: String?
    #endif

    // Focus state for tvOS
    #if os(tvOS)
        @FocusState private var focusedProgramId: String?
        @FocusState private var focusedChannelId: String?
        @FocusState private var focusedProgramCategoryTitle: String?
    #endif

    public init(store: StoreOf<EPGTimelineFeature>) {
        self.store = store
    }

    private var timelineStart: Date {
        let calendar = Calendar.current
        if store.isViewingToday {
            let now = store.currentTime
            let startOfHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            return calendar.date(byAdding: .hour, value: -pastHoursAnchor, to: startOfHour) ?? now
        } else {
            return calendar.startOfDay(for: store.selectedDate)
        }
    }

    private var totalTimelineWidth: CGFloat {
        CGFloat(totalHoursCount) * hourWidth
    }

    private var currentNowOffset: CGFloat {
        let secondsFromStart = store.currentTime.timeIntervalSince(timelineStart)
        return (CGFloat(secondsFromStart) / 3600.0) * hourWidth
    }

    public var body: some View {
        GeometryReader { geo in
            let availableGridWidth = max(100, geo.size.width - channelColumnWidth)

            ZStack(alignment: .bottomTrailing) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    epgHeaderBar

                    // Search bar on iOS
                    #if !os(tvOS)
                        searchBarView
                    #endif

                    // Date Selector Row (Catch-Up Archive Calendar)
                    dateSelectorRow(availableWidth: availableGridWidth)

                    // Category filter chips
                    if !store.availableCategories.isEmpty {
                        categoryFilterRow
                    }

                    if !store.availableProgramCategories.isEmpty || store.selectedProgramCategory != nil {
                        programCategoryFilterRow
                    }

                    // Sync Status Badge
                    if let msg = store.syncStatusMessage {
                        syncStatusBadge(message: msg)
                    }

                    // Synchronized Header Row
                    headerRow(availableWidth: availableGridWidth)
                        .zIndex(10)

                    Divider().background(Color.white.opacity(0.12))

                    // Virtualized Dual-Axis Grid Body
                    if store.filteredChannels.isEmpty {
                        emptyStateView
                    } else {
                        channelGridScrollView(availableWidth: availableGridWidth, containerHeight: geo.size.height)
                    }
                }

                // Floating Action Button: Jump to Now (today) or Return to Today (past archive)
                if store.isViewingToday {
                    if abs(horizontalOffset - targetCenteredNowOffset(availableWidth: availableGridWidth)) > 160 {
                        jumpToNowButton(availableWidth: availableGridWidth)
                            .padding(.trailing, 20)
                            .padding(.bottom, 24)
                            .transition(.scale.combined(with: .opacity))
                    }
                } else {
                    returnToTodayButton(availableWidth: availableGridWidth)
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                        .transition(.scale.combined(with: .opacity))
                }

                // PiP-in-EPG Mini Preview Floating Card (Madde #25)
                if let previewChannel = store.activePreviewChannel {
                    VStack {
                        pipInEPGCard(channel: previewChannel)
                            .padding(.top, 48)
                            .padding(.trailing, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
                if let savedOffset = store.savedHorizontalOffset {
                    let maxOffset = max(0, totalTimelineWidth - availableGridWidth)
                    horizontalOffset = min(maxOffset, max(0, savedOffset))
                } else if !hasCenteredOnNow {
                    hasCenteredOnNow = true
                    let target = targetCenteredNowOffset(availableWidth: availableGridWidth)
                    horizontalOffset = target
                }
                #if os(tvOS)
                    restoringProgramFocusID = store.savedFocusedProgramID
                    focusedProgramId = store.savedFocusedProgramID
                    focusedChannelId = store.savedFocusedProgramID == nil ? store.savedFocusedChannelID : nil
                #endif
                // Prewarm first 15 channels EPG data
                for channel in store.filteredChannels.prefix(15) {
                    store.send(.fetchEPG(streamID: channel.id))
                }
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.0
                }
            }
            .onDisappear {
                #if os(tvOS)
                    store.send(.onDisappear(
                        horizontalOffset: horizontalOffset,
                        focusedProgramID: focusedProgramId ?? store.savedFocusedProgramID,
                        focusedChannelID: focusedChannelId ?? store.savedFocusedChannelID
                    ))
                #else
                    store.send(.onDisappear(
                        horizontalOffset: horizontalOffset,
                        focusedProgramID: nil,
                        focusedChannelID: nil
                    ))
                #endif
            }
        }
        .sheet(isPresented: Binding(
            get: { store.selectedProgramDetail != nil },
            set: {
                if !$0 {
                    store.send(.dismissProgramDetails)
                }
            }
        )) {
            if let program = store.selectedProgramDetail, let channel = store.selectedProgramChannel {
                programDetailSheet(program: program, channel: channel)
                #if os(tvOS)
                    .onExitCommand {
                        store.send(.dismissProgramDetails)
                    }
                #endif
            }
        }
        .sheet(item: $logoEditorChannel) { channel in
            channelLogoEditorSheet(for: channel)
        }
        #if os(tvOS)
        .onExitCommand {
            if store.selectedProgramDetail != nil {
                store.send(.dismissProgramDetails)
            } else {
                store.send(.closeTapped)
            }
        }
        #endif
    }

    // MARK: - Header Bar

    private var epgHeaderBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                HapticManager.shared.trigger(.light)
                store.send(.closeTapped)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                    Text(AppStrings.Common.close)
                        .font(.subheadline)
                }
                .foregroundColor(.white)
            }
            #if os(tvOS)
            .buttonStyle(.bordered)
            #else
            .buttonStyle(.plain)
            #endif

            Button {
                isCompactMode.toggle()
            } label: {
                Image(systemName: isCompactMode ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
            }
            .accessibilityLabel(isCompactMode ? AppStrings.LiveTV.standardEPGView : AppStrings.LiveTV.compactEPGView)
            #if os(tvOS)
                .buttonStyle(.bordered)
            #else
                .buttonStyle(.plain)
            #endif

            Spacer()

            Text(AppStrings.Player.timeline)
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button(action: {
                guard !store.isSyncingEPG else { return }
                HapticManager.shared.trigger(.light)
                store.send(.refreshEPGTapped)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .rotationEffect(.degrees(store.isSyncingEPG ? 360 : 0))
                        .animation(
                            store.isSyncingEPG
                                ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false)
                                : .default,
                            value: store.isSyncingEPG
                        )
                    #if os(tvOS)
                        Text(AppStrings.Player.refreshEPG)
                    #endif
                }
                .foregroundColor(.white)
            }
            #if os(tvOS)
            .buttonStyle(.bordered)
            #else
            .buttonStyle(.plain)
            #endif
            .opacity(store.isSyncingEPG ? 0.6 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.85))
    }

    // MARK: - Search Bar

    #if !os(tvOS)
        private var searchBarView: some View {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.caption)

                TextField(AppStrings.Player.searchChannelOrProgram, text: Binding(
                    get: { store.searchQuery },
                    set: { store.send(.updateSearchQuery($0)) }
                ))
                .font(.caption)
                .foregroundColor(.white)

                if !store.searchQuery.isEmpty {
                    Button {
                        store.send(.updateSearchQuery(""))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
        }
    #endif

    // MARK: - Sync Status Badge

    private func syncStatusBadge(message: String) -> some View {
        HStack(spacing: 6) {
            if store.isSyncingEPG {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                    .scaleEffect(0.65)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption2)
            }

            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)

            if let lastSync = store.lastSyncFormatted, !store.isSyncingEPG {
                Text("• \(AppStrings.Player.lastSynced(lastSync))")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1), in: Capsule())
        .overlay(Capsule().stroke(Color.cyan.opacity(0.25), lineWidth: 0.8))
        .padding(.vertical, 2)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Date Selector Row (Catch-Up Archive Calendar)

    private func dateSelectorRow(availableWidth: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.availableDates, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: store.selectedDate)
                    let isToday = Calendar.current.isDateInToday(date)
                    let isYesterday = Calendar.current.isDateInYesterday(date)

                    let title: String = if isToday {
                        AppStrings.Player.today
                    } else if isYesterday {
                        AppStrings.Player.yesterday
                    } else {
                        formatDay(date)
                    }

                    Button {
                        HapticManager.shared.trigger(.light)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            if isToday {
                                horizontalOffset = targetCenteredNowOffset(availableWidth: availableWidth)
                            } else {
                                horizontalOffset = 0
                            }
                        }
                        store.send(.selectDate(date))
                    } label: {
                        HStack(spacing: 5) {
                            if !isToday {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(isSelected ? .white : .purple)
                            } else {
                                Circle()
                                    .fill(isSelected ? Color.white : Color.accentColor)
                                    .frame(width: 5, height: 5)
                            }

                            Text(title)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isSelected ? (isToday ? Color.accentColor : Color.purple) : Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }

    // MARK: - Category Filter Chips

    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All Categories Chip
                categoryChip(
                    title: AppStrings.Player.allCategories,
                    isSelected: store.selectedCategoryID == nil && !store.isFavoritesOnly,
                    onTap: {
                        if store.isFavoritesOnly {
                            store.send(.toggleFavoritesOnly)
                        }
                        store.send(.selectCategory(nil))
                    }
                )

                // Favorites Only Filter Chip
                categoryChip(
                    title: "⭐ \(AppStrings.Common.favorites)",
                    isSelected: store.isFavoritesOnly,
                    onTap: {
                        store.send(.toggleFavoritesOnly)
                    }
                )

                // Individual Category Chips
                ForEach(store.availableCategories) { cat in
                    categoryChip(
                        title: cat.name,
                        isSelected: store.selectedCategoryID == cat.id && !store.isFavoritesOnly,
                        onTap: {
                            if store.isFavoritesOnly {
                                store.send(.toggleFavoritesOnly)
                            }
                            store.send(.selectCategory(cat.id))
                        }
                    )
                }

                if store.isFavoritesOnly {
                    Picker(AppStrings.LiveTV.sortTitle, selection: Binding(
                        get: { store.favoriteSortMode },
                        set: { store.send(.setFavoriteSortMode($0)) }
                    )) {
                        ForEach(FavoriteChannelSortMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityHint(AppStrings.Favorites.orderingDescription)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }

    private var programCategoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text(AppStrings.LiveTV.categories)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .accessibilityAddTraits(.isHeader)

                programCategoryChip(
                    title: AppStrings.Player.allCategories,
                    isSelected: store.selectedProgramCategory == nil,
                    selection: nil
                )
                ForEach(store.availableProgramCategories, id: \.self) { category in
                    programCategoryChip(
                        title: category,
                        isSelected: store.selectedProgramCategory == category,
                        selection: category
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .accessibilityLabel(AppStrings.LiveTV.categories)
        #if os(tvOS)
            .focusSection()
        #endif
    }

    private func programCategoryChip(title: String, isSelected: Bool, selection: String?) -> some View {
        #if os(tvOS)
            let isFocused = focusedProgramCategoryTitle == title
        #else
            let isFocused = false
        #endif
        return Button {
            HapticManager.shared.trigger(.light)
            store.send(.selectProgramCategory(selection))
        } label: {
            Text(title)
                .font(.caption.weight(isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? Color.purple : Color.white.opacity(0.08)))
                .overlay(
                    Capsule().stroke(
                        isFocused ? Color.white : (isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.06)),
                        lineWidth: isFocused ? 2 : 1
                    )
                )
                .scaleEffect(isFocused ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? AppStrings.LiveTV.selected : AppStrings.LiveTV.notSelected)
        #if os(tvOS)
            .focused($focusedProgramCategoryTitle, equals: title)
        #endif
    }

    private func categoryChip(title: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.trigger(.light)
            onTap()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header Row

    private func headerRow(availableWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Pinned Top-Left Corner
            HStack(spacing: 6) {
                Image(systemName: "tv.fill")
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
                Text(AppStrings.Common.channels)
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            .frame(width: channelColumnWidth, height: timeHeaderHeight)
            .background(Color(hex: "#161619"))
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )

            // Horizontally Synchronized Time Scale
            ZStack(alignment: .leading) {
                Color(hex: "#1A1A1E")

                HStack(spacing: 0) {
                    ForEach(0 ..< totalHoursCount, id: \.self) { i in
                        let hourDate = Calendar.current.date(byAdding: .hour, value: i, to: timelineStart) ?? timelineStart
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatTime(hourDate))
                                    .font(.caption2.monospacedDigit())
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.85))

                                Text(formatDay(hourDate))
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.leading, 8)

                            Spacer()

                            // Half-hour tick
                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 1, height: 12)
                                .offset(x: -hourWidth / 2)

                            // Hour divider line
                            Rectangle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 1, height: timeHeaderHeight)
                        }
                        .frame(width: hourWidth, height: timeHeaderHeight)
                    }
                }
                .offset(x: -horizontalOffset)

                // Current Time Glowing Badge in Header (only when viewing today)
                if store.isViewingToday {
                    let nowX = currentNowOffset - horizontalOffset
                    if nowX >= 0, nowX <= availableWidth {
                        LiveTimeIndicatorView(height: timeHeaderHeight, showTopBadge: true)
                            .offset(x: nowX)
                    }
                }
            }
            .frame(width: availableWidth, height: timeHeaderHeight)
            .clipped()
        }
        .frame(height: timeHeaderHeight)
        .background(Color(hex: "#121215"))
    }

    // MARK: - Virtualized Body

    private func channelGridScrollView(availableWidth: CGFloat, containerHeight _: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 2) {
                ForEach(store.filteredChannels) { channel in
                    HStack(spacing: 0) {
                        // 100% Pinned Left Channel Cell
                        stickyChannelCell(channel)
                            .frame(width: channelColumnWidth, height: rowHeight)

                        // Synchronized Program Strip
                        ZStack(alignment: .leading) {
                            Color(hex: "#101014")

                            programsRow(for: channel)
                                .offset(x: -horizontalOffset)

                            // Live Current Time Vertical Laser Line Indicator (only when viewing today)
                            if store.isViewingToday {
                                let nowX = currentNowOffset - horizontalOffset
                                if nowX >= 0, nowX <= availableWidth {
                                    LiveTimeIndicatorView(height: rowHeight, showTopBadge: false)
                                        .offset(x: nowX)
                                        .zIndex(50)
                                }
                            }
                        }
                        .frame(width: availableWidth, height: rowHeight)
                        .clipped()
                    }
                    .frame(height: rowHeight)
                    .onAppear {
                        // On-demand fetch as user scrolls vertically
                        store.send(.fetchEPG(streamID: channel.id))
                    }
                }
            }
        }
        #if os(tvOS)
        .focusSection()
        #endif
        #if !os(tvOS)
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { val in
                    if !isUserDragging {
                        isUserDragging = true
                        dragStartOffset = horizontalOffset
                    }
                    let maxOffset = max(0, totalTimelineWidth - availableWidth)
                    let newOffset = dragStartOffset - val.translation.width
                    horizontalOffset = max(0, min(maxOffset, newOffset))
                }
                .onEnded { val in
                    isUserDragging = false
                    let maxOffset = max(0, totalTimelineWidth - availableWidth)
                    let projectedOffset = horizontalOffset - (val.predictedEndTranslation.width - val.translation.width) * 0.4
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        horizontalOffset = max(0, min(maxOffset, projectedOffset))
                    }
                }
        )
        #endif
    }

    // MARK: - Sticky Channel Cell

    private func stickyChannelCell(_ channel: MediaModels.Item) -> some View {
        let isFav = store.defaultFavoriteIDs.contains(channel.id)
        let favoriteIndex = store.filteredChannels.firstIndex(where: { $0.id == channel.id }) ?? 0
        let favoriteCount = store.filteredChannels.count

        return Button {
            HapticManager.shared.trigger(.medium)
            store.send(.channelTapped(channel))
        } label: {
            HStack(spacing: 8) {
                // Channel Logo
                if let url = channel.displayLogoURL {
                    PlaylistAsyncImage(url: url, userAgentOverride: channel.userAgentOverride) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "tv")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .frame(width: isCompactMode ? 42 : 32, height: isCompactMode ? 42 : 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "tv")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: isCompactMode ? 42 : 32, height: isCompactMode ? 42 : 32)
                }

                // Title & Badges
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        if isFav {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.yellow)
                        }

                        if store.epgLoadFailures.contains(channel.id) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.orange)
                                .accessibilityLabel(AppStrings.Player.epgRefreshFailed)
                        }

                        Text(channel.title)
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .lineLimit(isCompactMode ? 1 : 2)
                            .truncationMode(.tail)
                    }

                    if channel.tvArchive == 1 {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 8, weight: .bold))
                            Text(AppStrings.Player.catchUp)
                                .font(.system(size: 8, weight: .bold))
                            if let days = channel.tvArchiveDuration, days > 0 {
                                Text(AppStrings.Player.catchUpArchiveDays(days))
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                        .foregroundColor(.purple)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            AppStrings.Player.catchUpDescription(archiveDays: channel.tvArchiveDuration)
                        )
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(width: channelColumnWidth, height: rowHeight)
            .background(Color(hex: "#151518"))
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        #if os(tvOS)
            .focused($focusedChannelId, equals: channel.id)
            .onChange(of: focusedChannelId) { _, newID in
                guard newID == channel.id else { return }
                focusedProgramId = nil
                store.send(.saveNavigationState(
                    horizontalOffset: horizontalOffset,
                    focusedProgramID: nil,
                    focusedChannelID: channel.id
                ))
            }
        #endif
            .contextMenu {
                if store.recentChannelIDs.contains(channel.id) {
                    Button(role: .destructive) {
                        store.send(.removeRecentChannel(channel))
                    } label: {
                        Label(AppStrings.Player.removeRecentChannel, systemImage: "clock.badge.xmark")
                    }
                    .disabled(store.pendingRecentChannelRemovalIDs[channel.id] != nil)
                    .accessibilityLabel(AppStrings.Player.removeRecentChannel)
                }

                if store.epgLoadFailures.contains(channel.id) {
                    Button(AppStrings.Common.retry) {
                        store.send(.refreshEPG(streamID: channel.id))
                    }
                }

                Button {
                    HapticManager.shared.trigger(.medium)
                    store.send(.toggleFavorite(channel))
                } label: {
                    Label(
                        isFav ? AppStrings.Common.removeFromFavorites : AppStrings.Common.addToFavorites,
                        systemImage: isFav ? "star.slash.fill" : "star.fill"
                    )
                }

                if store.isFavoritesOnly, store.favoriteSortMode == .manual, store.searchQuery.isEmpty {
                    if favoriteIndex > 0 {
                        Button {
                            store.send(.moveFavorite(channelID: channel.id, offset: -1))
                        } label: {
                            Label(AppStrings.Favorites.moveUp, systemImage: "arrow.up")
                        }
                    }
                    if favoriteIndex + 1 < favoriteCount {
                        Button {
                            store.send(.moveFavorite(channelID: channel.id, offset: 1))
                        } label: {
                            Label(AppStrings.Favorites.moveDown, systemImage: "arrow.down")
                        }
                    }
                }

                Button {
                    HapticManager.shared.trigger(.light)
                    store.send(.togglePiPPreview(channel))
                } label: {
                    Label("Canlı Mini Önizleme", systemImage: "pip.enter")
                }

                Button {
                    logoURLDraft = channel.logoURLOverride?.absoluteString ?? ""
                    logoEditorChannel = channel
                } label: {
                    Label(AppStrings.LiveTV.editChannelLogo, systemImage: "photo")
                }
            }
    }

    private func channelLogoEditorSheet(for channel: MediaModels.Item) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/logo.png", text: $logoURLDraft)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #endif
                    Text(AppStrings.LiveTV.channelLogoURLHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !logoURLDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       ChannelLogoOverrideURL.validatedURL(from: logoURLDraft) == nil
                    {
                        Text(AppStrings.LiveTV.invalidChannelLogoURL)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text(AppStrings.LiveTV.channelLogoURL)
                }

                Section {
                    Button(AppStrings.LiveTV.resetChannelLogo, role: .destructive) {
                        store.send(.saveChannelLogoOverride(channelID: channel.id, rawValue: nil))
                        logoEditorChannel = nil
                    }
                }
            }
            .navigationTitle(AppStrings.LiveTV.editChannelLogo)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.Common.cancel) { logoEditorChannel = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.Common.save) {
                        guard ChannelLogoOverrideURL.validatedURL(from: logoURLDraft) != nil else { return }
                        store.send(.saveChannelLogoOverride(channelID: channel.id, rawValue: logoURLDraft))
                        logoEditorChannel = nil
                    }
                    .disabled(ChannelLogoOverrideURL.validatedURL(from: logoURLDraft) == nil)
                }
            }
        }
    }

    // MARK: - Programs Strip

    private func programsRow(for channel: MediaModels.Item) -> some View {
        ZStack(alignment: .leading) {
            if store.epgLoadFailures.contains(channel.id), store.epgData[channel.id]?.isEmpty != false {
                epgLoadFailureRow(channel)
            } else if store.isLoading[channel.id] == true, store.epgData[channel.id] == nil {
                shimmerLoadingRow
            } else {
                let programs = resolvedPrograms(for: channel)
                ForEach(programs) { program in
                    let startOffset = program.startTime.timeIntervalSince(timelineStart)
                    let duration = program.endTime.timeIntervalSince(program.startTime)

                    let width = max(30, (duration / 3600.0) * Double(hourWidth))
                    let xPos = (startOffset / 3600.0) * Double(hourWidth)

                    // Render only within reasonable bounds around total timeline
                    if width > 0, xPos + width > 0, xPos < Double(totalTimelineWidth) {
                        programBlock(program: program, channel: channel, width: CGFloat(width))
                            .offset(x: CGFloat(xPos))
                    }
                }
            }
        }
        .frame(width: totalTimelineWidth, height: rowHeight)
    }

    private func epgLoadFailureRow(_ channel: MediaModels.Item) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(AppStrings.Player.epgRefreshFailed)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)

            Button(AppStrings.Common.retry) {
                store.send(.refreshEPG(streamID: channel.id))
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: totalTimelineWidth, height: rowHeight, alignment: .leading)
        .offset(x: horizontalOffset)
    }

    // MARK: - Shimmer Placeholder Row

    private var shimmerLoadingRow: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< 6, id: \.self) { idx in
                let widths: [CGFloat] = [180, 260, 210, 320, 240, 280]
                let cardWidth = widths[idx % widths.count]

                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        )

                    GeometryReader { g in
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 80)
                        .offset(x: shimmerPhase * g.size.width * 1.5 - 40)
                    }
                    .clipped()
                }
                .frame(width: cardWidth, height: rowHeight - 12)
            }
        }
        .padding(.horizontal, 4)
        .frame(width: totalTimelineWidth, alignment: .leading)
    }

    // MARK: - Honest Program Resolving (No fabricated/fake data)

    private func resolvedPrograms(for channel: MediaModels.Item) -> [EPGProgram] {
        let calendar = Calendar.current
        let timelineEnd = calendar.date(byAdding: .hour, value: totalHoursCount, to: timelineStart) ?? timelineStart.addingTimeInterval(TimeInterval(totalHoursCount * 3600))
        let now = store.currentTime

        guard let rawPrograms = store.epgData[channel.id], !rawPrograms.isEmpty else {
            // Channel has no EPG data from provider: Return honest "Yayın Akışı Yok"
            return [
                EPGProgram(
                    id: "empty_\(channel.id)_\(Int(timelineStart.timeIntervalSince1970))",
                    title: "\(channel.title) - Yayın Akışı Yok",
                    description: "Bu kanal için IPTV sağlayıcısı tarafından yayın akışı programı iletilmemiştir.",
                    startTime: timelineStart,
                    endTime: timelineEnd,
                    isPlayingNow: timelineStart <= now && timelineEnd > now
                ),
            ]
        }

        // Channel has EPG data: Sort by startTime and bridge any empty intervals > 10 mins
        let sorted = rawPrograms.sorted { $0.startTime < $1.startTime }
        var bridged: [EPGProgram] = []
        var cursor = timelineStart

        for prog in sorted {
            if prog.endTime <= timelineStart {
                continue
            }
            if prog.startTime >= timelineEnd {
                break
            }

            if prog.startTime.timeIntervalSince(cursor) > 600 {
                let gapEnd = prog.startTime
                let gapProg = EPGProgram(
                    id: "gap_\(channel.id)_\(Int(cursor.timeIntervalSince1970))",
                    title: "Program Bilgisi Yok",
                    description: "Belirtilen saat aralığında yayın bilgisi bulunmuyor.",
                    startTime: cursor,
                    endTime: gapEnd,
                    isPlayingNow: cursor <= now && gapEnd > now
                )
                bridged.append(gapProg)
            }

            bridged.append(prog)
            cursor = max(cursor, prog.endTime)
        }

        if timelineEnd.timeIntervalSince(cursor) > 600 {
            let gapProg = EPGProgram(
                id: "gap_\(channel.id)_\(Int(cursor.timeIntervalSince1970))",
                title: "Program Bilgisi Yok",
                description: "Yayın akışı bilgisi mevcut değil.",
                startTime: cursor,
                endTime: timelineEnd,
                isPlayingNow: cursor <= now && timelineEnd > now
            )
            bridged.append(gapProg)
        }

        return bridged
    }

    // MARK: - Program Block

    private func programBlock(program: EPGProgram, channel: MediaModels.Item, width: CGFloat) -> some View {
        let isNow = program.isPlayingNow
        let isCatchUp = program.endTime < Date() && channel.tvArchive == 1
        let isFuture = program.startTime > Date()
        let reminderID = EPGReminderIdentifier.make(config: store.config, channelID: channel.id, programID: program.id)
        let isScheduled = store.scheduledReminderIDs.contains(reminderID)
            || store.scheduledReminderIDs.contains(program.id)
        let isReminderPending = store.pendingReminderRequestIDs[reminderID] != nil
        let isSearchMatch = isProgramMatchingSearch(program)
        let isFallback = program.id.hasPrefix("fallback_") || program.id.hasPrefix("gap_")
        var accessibilitySummaryParts = [channel.title, program.title]
        accessibilitySummaryParts.append("\(formatTime(program.startTime)) – \(formatTime(program.endTime))")
        if isNow {
            accessibilitySummaryParts.append(AppStrings.Player.liveLabelNormal)
        } else if isCatchUp {
            accessibilitySummaryParts.append(AppStrings.Player.catchUp)
        } else if isFuture {
            accessibilitySummaryParts.append(AppStrings.Player.upcoming)
        } else {
            accessibilitySummaryParts.append(AppStrings.Player.completed)
        }
        if isReminderPending {
            accessibilitySummaryParts.append(AppStrings.Player.reminderScheduling)
        } else if isScheduled {
            accessibilitySummaryParts.append(AppStrings.Player.reminderSet)
        }
        if !program.description.isEmpty {
            accessibilitySummaryParts.append(String(program.description.prefix(240)))
        }
        let accessibilityHint = isNow
            ? AppStrings.EPG.watch
            : (isCatchUp ? AppStrings.Player.watchCatchUp : AppStrings.Player.programDetails)

        let genre = genrePastelColor(for: program)
        var cardBackgroundColor: Color = if isSearchMatch {
            .cyan.opacity(0.18)
        } else if isNow {
            Color.accentColor.opacity(0.22)
        } else if isCatchUp {
            .purple.opacity(0.15)
        } else if isScheduled {
            .yellow.opacity(0.12)
        } else if isFallback {
            .white.opacity(0.035)
        } else {
            genre.background
        }

        var cardBorderColor: Color = if isSearchMatch {
            .cyan
        } else if isNow {
            Color.accentColor.opacity(0.8)
        } else if isCatchUp {
            .purple.opacity(0.4)
        } else if isScheduled {
            .yellow.opacity(0.5)
        } else if isFallback {
            .white.opacity(0.04)
        } else {
            .white.opacity(0.08)
        }
        var cardBorderLineWidth: CGFloat = (isSearchMatch || isNow) ? 1.5 : 1
        let titleFontSize: CGFloat
        let titleFontWeight: Font.Weight
        let timeFontSize: CGFloat
        #if os(tvOS)
            let isFocused = focusedProgramId == program.id
            titleFontSize = isFocused && width >= 140 ? 14 : (isCompactMode ? 10 : 11)
            titleFontWeight = isFocused || isNow || isSearchMatch ? .bold : .medium
            timeFontSize = isFocused && width >= 120 ? 11 : 9.5
            if isFocused {
                cardBackgroundColor = .white.opacity(0.22)
                cardBorderColor = .white
                cardBorderLineWidth = 3
            }
        #else
            titleFontSize = isCompactMode ? 10 : 11
            titleFontWeight = isNow || isSearchMatch ? .bold : .medium
            timeFontSize = 9.5
        #endif

        return Button {
            HapticManager.shared.trigger(.light)
            if isNow {
                store.send(.channelTapped(channel))
            } else if isCatchUp {
                store.send(.programTapped(program, channel))
            } else {
                store.send(.showProgramDetails(program, channel))
            }
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Card Background (Madde #28: Renk Kodlu EPG Kategorileri)
                RoundedRectangle(cornerRadius: 6)
                    .fill(cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(genre.border.opacity(genre.badgeText != nil ? 0.5 : 0.0), lineWidth: 1)
                    )

                // Live Progress bar fill for on-air program
                if isNow {
                    let totalSecs = max(60, program.endTime.timeIntervalSince(program.startTime))
                    let elapsed = max(0, min(totalSecs, store.currentTime.timeIntervalSince(program.startTime)))
                    let progressFraction = elapsed / totalSecs

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.35))
                        .frame(width: max(0, width * CGFloat(progressFraction)))
                }

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        if let badge = genre.badgeText {
                            Text(badge)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(genre.border)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(genre.border.opacity(0.15), in: Capsule())
                        }

                        if isNow {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 5, height: 5)
                            Text(AppStrings.Player.liveLabel)
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundColor(.red)
                        } else if isCatchUp {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.purple)
                        }

                        if isScheduled {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.yellow)
                        }

                        if isSearchMatch {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.cyan)
                        }

                        if isFallback, !isNow {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.white.opacity(0.45))
                        }

                        Text(program.title)
                            .font(.system(size: titleFontSize, weight: titleFontWeight))
                            .foregroundColor(isSearchMatch ? .cyan : .white)
                            .lineLimit(1)
                    }

                    if !isCompactMode {
                        Text("\(formatTime(program.startTime)) - \(formatTime(program.endTime))")
                            .font(.system(size: timeFontSize).monospacedDigit())
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(width: width - 3, height: rowHeight - 6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        cardBorderColor,
                        lineWidth: cardBorderLineWidth
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummaryParts.joined(separator: ". ")))
        .accessibilityHint(Text(accessibilityHint))
        .contextMenu {
            #if os(iOS)
                if isFuture {
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.toggleReminder(program, channel))
                    } label: {
                        Label(
                            isReminderPending
                                ? AppStrings.Player.reminderScheduling
                                : (isScheduled ? AppStrings.Player.removeReminder : AppStrings.Player.setReminder),
                            systemImage: isReminderPending ? "ellipsis.circle" : (isScheduled ? "bell.slash.fill" : "bell.fill")
                        )
                    }
                    .disabled(isReminderPending)
                }
            #endif
            Button {
                HapticManager.shared.trigger(.light)
                store.send(.toggleFavorite(channel))
            } label: {
                let isFav = store.defaultFavoriteIDs.contains(channel.id)
                Label(
                    isFav ? AppStrings.Common.removeFromFavorites : AppStrings.Common.addToFavorites,
                    systemImage: isFav ? "star.slash.fill" : "star.fill"
                )
            }
            Button {
                store.send(.showProgramDetails(program, channel))
            } label: {
                Label(AppStrings.Player.programDetails, systemImage: "info.circle")
            }
        }
        #if os(tvOS)
        .focused($focusedProgramId, equals: program.id)
        .onChange(of: focusedProgramId) { _, newId in
            if newId == program.id {
                if restoringProgramFocusID == newId {
                    restoringProgramFocusID = nil
                    return
                }
                restoringProgramFocusID = nil
                focusedChannelId = nil
                let targetX = (program.startTime.timeIntervalSince(timelineStart) / 3600.0) * hourWidth - 200
                withAnimation(.easeInOut(duration: 0.25)) {
                    horizontalOffset = max(0, min(totalTimelineWidth - 800, targetX))
                }
                store.send(.saveNavigationState(
                    horizontalOffset: horizontalOffset,
                    focusedProgramID: program.id,
                    focusedChannelID: channel.id
                ))
            }
        }
        #endif
    }

    // MARK: - Floating Action Buttons

    private func jumpToNowButton(availableWidth: CGFloat) -> some View {
        Button {
            HapticManager.shared.trigger(.medium)
            let target = targetCenteredNowOffset(availableWidth: availableWidth)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                horizontalOffset = target
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Text(AppStrings.Player.jumpToNow)
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.accentColor)
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .shadow(color: Color.accentColor.opacity(0.5), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    private func returnToTodayButton(availableWidth: CGFloat) -> some View {
        Button {
            HapticManager.shared.trigger(.medium)
            store.send(.selectDate(Date()))
            let target = targetCenteredNowOffset(availableWidth: availableWidth)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                horizontalOffset = target
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Text(AppStrings.Player.returnToToday)
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.purple)
                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .shadow(color: Color.purple.opacity(0.5), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Program Detail Sheet & Live Preview Window

    private func programDetailSheet(program: EPGProgram, channel: MediaModels.Item) -> some View {
        let isNow = program.isPlayingNow
        let isCatchUp = program.endTime < Date() && channel.tvArchive == 1
        let isFuture = program.startTime > Date()
        let reminderID = EPGReminderIdentifier.make(config: store.config, channelID: channel.id, programID: program.id)
        let isScheduled = store.scheduledReminderIDs.contains(reminderID)
            || store.scheduledReminderIDs.contains(program.id)
        let isReminderPending = store.pendingReminderRequestIDs[reminderID] != nil

        let totalSecs = max(60, program.endTime.timeIntervalSince(program.startTime))
        let elapsed = max(0, min(totalSecs, store.currentTime.timeIntervalSince(program.startTime)))
        let progressFraction = elapsed / totalSecs
        let percentInt = Int(progressFraction * 100)

        return VStack(spacing: 0) {
            // Sheet Header with Channel Info & Close Button
            HStack {
                HStack(spacing: 10) {
                    if let url = channel.displayLogoURL {
                        PlaylistAsyncImage(url: url, userAgentOverride: channel.userAgentOverride) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFit()
                            } else {
                                Image(systemName: "tv.fill")
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(channel.title)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if !channel.categoryID.isEmpty {
                            Text(channel.categoryID)
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Button {
                    store.send(.dismissProgramDetails)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 16:9 Interactive Mini Preview Card
                    previewCardView(program: program, channel: channel, isNow: isNow, isCatchUp: isCatchUp, isFuture: isFuture, progressFraction: progressFraction)

                    // Title & Status Badges
                    VStack(alignment: .leading, spacing: 8) {
                        Text(program.title)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Label("\(formatTime(program.startTime)) - \(formatTime(program.endTime))", systemImage: "clock")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.85))

                            let durationMins = Int(totalSecs / 60)
                            Label("\(durationMins) \(AppStrings.Common.minAbbr)", systemImage: "hourglass")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.85))

                            if isNow {
                                Text("%\(percentInt) \(AppStrings.Player.completed)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.18), in: Capsule())
                            } else if isCatchUp {
                                Label(AppStrings.Player.catchUp, systemImage: "clock.arrow.circlepath")
                                    .font(.caption2.bold())
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.18), in: Capsule())
                            }
                        }
                    }

                    // Progress bar for active program
                    if isNow {
                        VStack(alignment: .leading, spacing: 4) {
                            GeometryReader { pGeo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(height: 5)
                                    Capsule()
                                        .fill(LinearGradient(colors: [.accentColor, .cyan], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: max(0, pGeo.size.width * CGFloat(progressFraction)), height: 5)
                                }
                            }
                            .frame(height: 5)

                            HStack {
                                Text(formatTime(program.startTime))
                                Spacer()
                                Text(formatTime(program.endTime))
                            }
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundColor(.white.opacity(0.45))
                        }
                    }

                    // Program Description
                    if !program.description.isEmpty {
                        Text(program.description)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Action Buttons Bar
                    actionButtonsBar(
                        program: program,
                        channel: channel,
                        isNow: isNow,
                        isCatchUp: isCatchUp,
                        isFuture: isFuture,
                        isScheduled: isScheduled,
                        isReminderPending: isReminderPending
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(Color(hex: "#141418").ignoresSafeArea())
        #if os(iOS)
            .presentationDetents([.fraction(0.58), .large])
            .presentationDragIndicator(.visible)
        #endif
    }

    private func previewCardView(program: EPGProgram, channel: MediaModels.Item, isNow: Bool, isCatchUp: Bool, isFuture _: Bool, progressFraction: Double) -> some View {
        Button {
            HapticManager.shared.trigger(.medium)
            store.send(.dismissProgramDetails)
            if isNow {
                store.send(.channelTapped(channel))
            } else if isCatchUp {
                store.send(.programTapped(program, channel))
            }
        } label: {
            ZStack {
                // Glass Gradient Backdrop
                LinearGradient(
                    colors: isNow ? [Color.accentColor.opacity(0.3), Color.black.opacity(0.8)] : (isCatchUp ? [Color.purple.opacity(0.3), Color.black.opacity(0.8)] : [Color.white.opacity(0.08), Color.black.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Blurred channel artwork backdrop if available
                if let url = channel.displayLogoURL {
                    PlaylistAsyncImage(url: url, userAgentOverride: channel.userAgentOverride) { phase in
                        if let img = phase.image {
                            img.resizable()
                                .aspectRatio(contentMode: .fill)
                                .opacity(0.18)
                                .blur(radius: 12)
                        }
                    }
                }

                // Center Play Action Trigger
                if isNow || isCatchUp {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: isNow ? "play.fill" : "clock.arrow.circlepath")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 8)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: "calendar.badge.clock")
                                .font(.title3.bold())
                                .foregroundColor(.yellow)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 8)
                }

                // Top Floating Status Pill
                VStack {
                    HStack {
                        if isNow {
                            HStack(spacing: 5) {
                                Circle().fill(Color.red).frame(width: 6, height: 6)
                                Text(AppStrings.Player.liveLabel)
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6), in: Capsule())
                            .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1))
                        } else if isCatchUp {
                            HStack(spacing: 5) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text(AppStrings.Player.catchUp)
                            }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6), in: Capsule())
                            .overlay(Capsule().stroke(Color.purple.opacity(0.4), lineWidth: 1))
                        }

                        Spacer()

                        // Stream Quality Tag
                        Text("1080p HD")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(12)

                    Spacer()

                    // Bottom progress indicator in preview card
                    if isNow {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.white.opacity(0.15))
                                Rectangle().fill(Color.accentColor).frame(width: max(0, g.size.width * CGFloat(progressFraction)))
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func actionButtonsBar(
        program: EPGProgram,
        channel: MediaModels.Item,
        isNow: Bool,
        isCatchUp: Bool,
        isFuture: Bool,
        isScheduled: Bool,
        isReminderPending: Bool
    ) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if isNow {
                    Button {
                        HapticManager.shared.trigger(.medium)
                        store.send(.dismissProgramDetails)
                        store.send(.channelTapped(channel))
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text(AppStrings.Player.liveBroadcast)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    }
                } else if isCatchUp {
                    Button {
                        HapticManager.shared.trigger(.medium)
                        store.send(.dismissProgramDetails)
                        store.send(.programTapped(program, channel))
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text(AppStrings.Player.watchCatchUp)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.purple, in: RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    #if os(iOS)
                        if isFuture {
                            Button {
                                HapticManager.shared.trigger(.medium)
                                store.send(.toggleReminder(program, channel))
                            } label: {
                                HStack {
                                    Image(systemName: isReminderPending ? "ellipsis.circle" : (isScheduled ? "bell.slash.fill" : "bell.fill"))
                                    Text(isReminderPending
                                        ? AppStrings.Player.reminderScheduling
                                        : (isScheduled ? AppStrings.Player.removeReminder : AppStrings.Player.setReminder))
                                }
                                .font(.headline)
                                .foregroundColor(isScheduled ? .white : .black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isScheduled ? Color.red.opacity(0.85) : Color.yellow, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(isReminderPending)
                        }
                    #endif
                }
            }

            // Secondary Quick Actions: "Kanalı Aç" and "Paylaş"
            HStack(spacing: 12) {
                if !isNow {
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.dismissProgramDetails)
                        store.send(.channelTapped(channel))
                    } label: {
                        HStack {
                            Image(systemName: "tv")
                            Text(AppStrings.Player.openChannel)
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                #if os(iOS)
                    ShareLink(item: "\(program.title) - \(channel.title)") {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(AppStrings.Player.share)
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                #endif

                #if os(tvOS)
                    Button {
                        store.send(.dismissProgramDetails)
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                            Text(AppStrings.Common.close)
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.card)
                #endif
            }
        }
    }

    // MARK: - Helpers

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tv.slash")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
            Text(AppStrings.LiveTV.noChannels)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func targetCenteredNowOffset(availableWidth: CGFloat) -> CGFloat {
        let maxOffset = max(0, totalTimelineWidth - availableWidth)
        let centered = currentNowOffset - availableWidth * 0.35
        return max(0, min(maxOffset, centered))
    }

    private func isProgramMatchingSearch(_ program: EPGProgram) -> Bool {
        let query = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return false }
        return program.title.localizedCaseInsensitiveContains(query) ||
            program.description.localizedCaseInsensitiveContains(query)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: date)
    }

    // MARK: - Renk Kodlu EPG Kategorileri (Madde #28)

    private func genrePastelColor(for program: EPGProgram) -> (background: Color, border: Color, badgeText: String?) {
        let text = (program.title + " " + program.description).lowercased()
        if text.contains("spor") || text.contains("sport") || text.contains("futbol") || text.contains("basket") || text.contains("lig") || text.contains("match") {
            return (Color.orange.opacity(0.18), Color.orange.opacity(0.5), "SPOR")
        } else if text.contains("haber") || text.contains("news") || text.contains("bülten") || text.contains("gündem") {
            return (Color.blue.opacity(0.18), Color.blue.opacity(0.5), "HABER")
        } else if text.contains("sinema") || text.contains("film") || text.contains("movie") || text.contains("dizi") || text.contains("cinema") {
            return (Color.purple.opacity(0.18), Color.purple.opacity(0.5), "SİNEMA")
        } else if text.contains("çocuk") || text.contains("cocuk") || text.contains("cartoon") || text.contains("animasyon") || text.contains("kids") {
            return (Color.yellow.opacity(0.18), Color.yellow.opacity(0.5), "ÇOCUK")
        } else {
            return (Color.white.opacity(0.06), Color.white.opacity(0.12), nil)
        }
    }

    // MARK: - PiP-in-EPG Canlı Mini Önizleme (Madde #25)

    private func pipInEPGCard(channel: MediaModels.Item) -> some View {
        LiveEPGMiniPreviewView(
            channel: channel,
            isMuted: store.isPreviewMuted,
            isLoading: store.isPreviewLoading,
            errorMessage: store.previewErrorMessage,
            onToggleMute: {
                store.send(.togglePreviewMute)
            },
            onExpand: {
                store.send(.expandPreviewToFullscreen)
            },
            onClose: {
                store.send(.closePiPPreview)
            }
        )
    }
}
