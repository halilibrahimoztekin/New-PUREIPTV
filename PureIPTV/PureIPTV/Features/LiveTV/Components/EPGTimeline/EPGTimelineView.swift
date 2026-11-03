import ComposableArchitecture
import SwiftUI

public struct EPGTimelineView: View {
    @Bindable var store: StoreOf<EPGTimelineFeature>
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @AppStorage(LiveTVArtworkSource.storageKey) private var liveTVArtworkSourceRawValue = LiveTVArtworkSource.epgProgram.rawValue
    #if os(tvOS)
        @AppStorage(EPGTimelinePreferenceKeys.hideChannelsWithoutPrograms) private var hideChannelsWithoutPrograms = false
        @State private var lastFocusedChannelID: String?
    #endif

    private var liveTVArtworkSource: LiveTVArtworkSource {
        LiveTVArtworkSource(rawValue: liveTVArtworkSourceRawValue) ?? .epgProgram
    }

    private var displayedChannels: [MediaModels.Item] {
        #if os(tvOS)
            let channels = store.filteredChannels
            let query = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard hideChannelsWithoutPrograms,
                  query.isEmpty,
                  !store.isSyncingEPG,
                  !(store.isFavoritesOnly && store.favoriteSortMode == .manual) else { return channels }
            if let failureDate = store.lastSyncFailureTimestamp,
               store.lastSyncTimestamp.map({ failureDate >= $0 }) ?? true
            {
                return channels
            }

            return channels.filter { channel in
                guard let programs = store.epgData[channel.id], programs.isEmpty,
                      !store.epgLoadFailures.contains(channel.id),
                      store.isLoading[channel.id] != true else { return true }
                return false
            }
        #else
            store.filteredChannels
        #endif
    }

    #if os(tvOS)
        private var displayedChannelIDs: [String] {
            displayedChannels.map(\.id)
        }
    #endif

    private var rowHeight: CGFloat {
        isCompactMode ? compactRowHeight : standardRowHeight
    }

    private var channelColumnWidth: CGFloat {
        isCompactMode ? compactChannelColumnWidth : standardChannelColumnWidth
    }

    private var hasLoadingEPGPlaceholder: Bool {
        store.epgRequestIDs.keys.contains { channelID in
            store.isLoading[channelID] == true
                && store.epgData[channelID] == nil
                && !store.epgLoadFailures.contains(channelID)
        }
    }

    private let totalHoursCount: Int = 24
    private let pastHoursAnchor: Int = 4

    // Horizontal Scroll State
    @State private var horizontalOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var isUserDragging: Bool = false
    @State private var hasCenteredOnNow: Bool = false
    @State private var shimmerPhase: CGFloat = 0
    @State private var navigationStepHours = 1
    @State private var lastSearchNavigationKey: String?
    @State private var pendingSearchChannelID: String?
    @State private var showingEPGDiagnostics = false
    #if os(tvOS)
        @State private var restoringProgramFocusID: String?
        @State private var pendingFocusRestoreChannelID: String?
        @State private var focusedProgramTimeAnchor: Date?
        @State private var verticalChannelTimeReturnArmed = false
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
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    epgHeaderBar

                    epgFreshnessBadge

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
                    if store.isAutomaticEPGRefreshDeferred {
                        syncStatusBadge(message: AppStrings.Settings.epgAutoRefreshDeferredMessage)
                    } else if let msg = store.syncStatusMessage {
                        syncStatusBadge(message: msg)
                    }

                    // Synchronized Header Row
                    headerRow(availableWidth: availableGridWidth)
                        .zIndex(10)

                    Divider().background(AppColors.borderMedium)

                    // Virtualized Dual-Axis Grid Body
                    if displayedChannels.isEmpty {
                        emptyStateView
                    } else {
                        channelGridScrollView(availableWidth: availableGridWidth, containerHeight: geo.size.height)
                    }

                    HStack {
                        Spacer(minLength: 0)
                        timeNavigationControls(availableWidth: availableGridWidth)
                    }
                    .padding(.trailing, 20)
                    .padding(.vertical, 10)
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
                    focusedProgramTimeAnchor = nil
                    verticalChannelTimeReturnArmed = false
                    focusedProgramId = nil
                    if let savedChannelID = store.savedFocusedChannelID {
                        restoringProgramFocusID = store.savedFocusedProgramID
                        pendingFocusRestoreChannelID = savedChannelID
                        focusedChannelId = nil
                    } else {
                        restoringProgramFocusID = nil
                        pendingFocusRestoreChannelID = nil
                        focusedChannelId = displayedChannels.first?.id
                    }
                #endif
                // Prewarm first 15 channels EPG data
                for channel in store.filteredChannels.prefix(15) {
                    store.send(.fetchEPG(streamID: channel.id))
                }
                updateShimmerAnimation()
            }
            .onChange(of: availableGridWidth) { _, width in
                horizontalOffset = min(max(0, totalTimelineWidth - width), max(0, horizontalOffset))
            }
            .onChange(of: hasLoadingEPGPlaceholder) { _, _ in
                updateShimmerAnimation()
            }
            .onChange(of: reduceMotion) { _, _ in
                updateShimmerAnimation()
            }
            #if os(tvOS)
            .onChange(of: focusedChannelId) { _, channelID in
                if let channelID {
                    lastFocusedChannelID = channelID
                }
                let channel = channelID.flatMap { focusedID in
                    store.channels.first { $0.id == focusedID }
                }
                store.send(.channelFocused(channel))
            }
            .onChange(of: displayedChannelIDs) { oldIDs, newIDs in
                reconcileChannelFocus(previousIDs: oldIDs, currentIDs: newIDs)
            }
            #endif
            .onDisappear {
                stopShimmerAnimation()
                #if os(tvOS)
                    store.send(.onDisappear(
                        horizontalOffset: horizontalOffset,
                        focusedProgramID: focusedProgramId ?? store.savedFocusedProgramID,
                        focusedChannelID: focusedChannelId ?? store.savedFocusedChannelID
                    ))
                    pendingFocusRestoreChannelID = nil
                    restoringProgramFocusID = nil
                #else
                    store.send(.onDisappear(
                        horizontalOffset: horizontalOffset,
                        focusedProgramID: nil,
                        focusedChannelID: nil
                    ))
                #endif
            }
            .onChange(of: store.searchQuery) { _, query in
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lastSearchNavigationKey = nil
                    pendingSearchChannelID = nil
                }
                navigateToSearchMatch(query, availableWidth: availableGridWidth)
            }
            .onChange(of: store.epgData) { _, _ in
                navigateToSearchMatch(store.searchQuery, availableWidth: availableGridWidth)
                #if os(tvOS)
                    restoreSavedFocusIfAvailable()
                #endif
            }
            .alert(AppStrings.Player.epgDiagnosticsTitle, isPresented: $showingEPGDiagnostics) {
                Button(AppStrings.Common.close, role: .cancel) {}
            } message: {
                Text(store.epgDiagnosticsText)
            }
            #if os(tvOS)
            .onChange(of: store.channels.count) { _, _ in
                restoreSavedFocusIfAvailable()
            }
            #endif
        }
        #if os(tvOS)
        .onExitCommand {
            store.send(.closeTapped)
        }
        #endif
    }

    private func updateShimmerAnimation() {
        guard !reduceMotion, hasLoadingEPGPlaceholder else {
            stopShimmerAnimation()
            return
        }
        guard shimmerPhase == 0 else { return }
        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
            shimmerPhase = 1.0
        }
    }

    private func stopShimmerAnimation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            shimmerPhase = 0
        }
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
                HapticManager.shared.trigger(.light)
                store.send(store.isSyncingEPG ? .cancelEPGSync : .refreshEPGTapped)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: store.isSyncingEPG ? "xmark" : "arrow.triangle.2.circlepath")
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
            .accessibilityLabel(store.isSyncingEPG ? "Rehber yenilemesini iptal et" : AppStrings.Player.refreshEPG)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColors.background.opacity(0.85))
    }

    // MARK: - Search Bar

    #if !os(tvOS)
        private var searchBarView: some View {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textTertiary)
                    .font(AppFonts.caption)

                TextField(AppStrings.Player.searchChannelOrProgram, text: Binding(
                    get: { store.searchQuery },
                    set: { store.send(.updateSearchQuery($0)) }
                ))
                .font(AppFonts.caption)
                .foregroundColor(AppColors.textPrimary)

                if !store.searchQuery.isEmpty {
                    Button {
                        store.send(.updateSearchQuery(""))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                            .font(AppFonts.caption)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
        }
    #endif

    // MARK: - Sync Status Badge

    private var epgFreshnessBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: store.lastSyncFailureTimestamp.map { $0 >= (store.lastSyncTimestamp ?? .distantPast) } == true
                    ? "exclamationmark.triangle.fill"
                    : (store.epgSourceIdentity == nil || store.lastSyncTimestamp == nil
                        ? "questionmark.circle"
                        : (store.lastSyncTimestamp.map { store.currentTime.timeIntervalSince($0) >= 86400 } == true
                            ? "clock.fill" : "checkmark.circle.fill")))
                    .foregroundColor(store.lastSyncFailureTimestamp.map { $0 >= (store.lastSyncTimestamp ?? .distantPast) } == true
                        ? AppColors.warning
                        : (store.epgSourceIdentity == nil || store.lastSyncTimestamp == nil
                            ? AppColors.textTertiary
                            : (store.lastSyncTimestamp.map { store.currentTime.timeIntervalSince($0) >= 86400 } == true
                                ? AppColors.warningGold : AppColors.success)))
                Text(store.epgFreshnessLabel)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                if store.isSyncingEPG {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: AppColors.cyan)).scaleEffect(0.6)
                }
                Button {
                    showingEPGDiagnostics = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(AppFonts.bodyMedium)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppStrings.Player.epgDiagnosticsTitle)
            }

            if let retryAt = store.providerCooldownFormatted {
                Label(AppStrings.Player.epgProviderCooldownUntil(retryAt), systemImage: "clock.fill")
                    .font(AppFonts.captionMedium)
                    .foregroundStyle(AppColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func syncStatusBadge(message: String) -> some View {
        HStack(spacing: 6) {
            if store.isSyncingEPG {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.cyan))
                    .scaleEffect(0.65)
            } else if store.isProviderRateLimited {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.warning)
                    .font(AppFonts.captionSmall)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                    .font(AppFonts.captionSmall)
            }

            Text(message)
                .font(AppFonts.captionMedium)
                .foregroundColor(AppColors.textPrimary)

            if let lastSync = store.lastSyncFormatted, !store.isSyncingEPG {
                Text("• \(AppStrings.Player.lastSynced(lastSync))")
                    .font(AppFonts.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(AppColors.surfaceSecondary, in: Capsule())
        .overlay(Capsule().stroke(AppColors.cyan.opacity(0.25), lineWidth: 0.8))
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
                        #if os(tvOS)
                            focusedProgramTimeAnchor = nil
                            verticalChannelTimeReturnArmed = false
                        #endif
                        store.send(.selectDate(date))
                    } label: {
                        HStack(spacing: 5) {
                            if !isToday {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(AppFonts.captionSmall.weight(.bold))
                                    .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.purpleAccent)
                            } else {
                                Circle()
                                    .fill(isSelected ? AppColors.textPrimary : AppColors.accent)
                                    .frame(width: 5, height: 5)
                            }

                            Text(title)
                                .font(isSelected ? AppFonts.captionBold : AppFonts.captionMedium)
                                .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isSelected ? (isToday ? AppColors.accent : AppColors.purpleAccent) : AppColors.surfaceSecondary)
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? AppColors.borderStrong : AppColors.borderSubtle, lineWidth: 1)
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
                .font(isSelected ? AppFonts.captionBold : AppFonts.captionMedium)
                .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? AppColors.purpleAccent : AppColors.surfaceSecondary))
                .overlay(
                    Capsule().stroke(
                        isFocused ? AppColors.textPrimary : (isSelected ? AppColors.borderStrong : AppColors.borderSubtle),
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
                .font(isSelected ? AppFonts.captionBold : AppFonts.captionMedium)
                .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.accent : AppColors.surfaceSecondary)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? AppColors.borderStrong : AppColors.borderSubtle, lineWidth: 1)
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
                    .font(AppFonts.captionBold)
                    .foregroundColor(AppColors.accent)
                Text(AppStrings.Common.channels)
                    .font(AppFonts.captionBold)
                    .foregroundColor(AppColors.textPrimary)
            }
            .frame(width: channelColumnWidth, height: timeHeaderHeight)
            .background(AppColors.surfaceSecondary)
            .overlay(
                Rectangle()
                    .stroke(AppColors.borderSubtle, lineWidth: 0.5)
            )

            // Horizontally Synchronized Time Scale
            ZStack(alignment: .leading) {
                AppColors.surfaceElevated

                HStack(spacing: 0) {
                    ForEach(0 ..< totalHoursCount, id: \.self) { i in
                        let hourDate = Calendar.current.date(byAdding: .hour, value: i, to: timelineStart) ?? timelineStart
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatTime(hourDate))
                                    .font(AppFonts.captionSmall.monospacedDigit())
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textSecondary)

                                Text(formatDay(hourDate))
                                    .font(AppFonts.captionSmall)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.leading, 8)

                            Spacer()

                            // Half-hour tick
                            Rectangle()
                                .fill(AppColors.borderMedium)
                                .frame(width: 1, height: 12)
                                .offset(x: -hourWidth / 2)

                            // Hour divider line
                            Rectangle()
                                .fill(AppColors.borderStrong)
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
        .background(AppColors.surfaceSecondary)
    }

    // MARK: - Virtualized Body

    private func channelGridScrollView(availableWidth: CGFloat, containerHeight _: CGFloat) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    ForEach(displayedChannels) { channel in
                        HStack(spacing: 0) {
                            // 100% Pinned Left Channel Cell
                            stickyChannelCell(channel, timelineViewportWidth: availableWidth)
                                .frame(width: channelColumnWidth, height: rowHeight)

                            // Synchronized Program Strip
                            ZStack(alignment: .leading) {
                                AppColors.surfaceSecondary

                                programsRow(for: channel, viewportWidth: availableWidth)
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
                        .id(channel.id)
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
            .onChange(of: pendingSearchChannelID) { _, channelID in
                guard let channelID else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    scrollProxy.scrollTo(channelID, anchor: .center)
                }
            }
            #if os(tvOS)
            .onChange(of: pendingFocusRestoreChannelID) { _, channelID in
                guard let channelID else { return }
                scrollProxy.scrollTo(channelID, anchor: .center)
                restoreSavedFocusIfAvailable()
            }
            #endif
        }
    }

    // MARK: - Sticky Channel Cell

    private func stickyChannelCell(_ channel: MediaModels.Item, timelineViewportWidth: CGFloat) -> some View {
        let isFav = store.defaultFavoriteIDs.contains(channel.id)
        let favoriteIndex = displayedChannels.firstIndex(where: { $0.id == channel.id }) ?? 0
        let favoriteCount = displayedChannels.count

        return Button {
            HapticManager.shared.trigger(.medium)
            store.send(.channelTapped(channel))
        } label: {
            HStack(spacing: 8) {
                // Channel Logo
                if let url = channel.displayLogoURL {
                    PlaylistAsyncImage(url: url, fallbackURL: channel.coverURL, userAgentOverride: channel.userAgentOverride, playlistID: channel.playlistID) { phase in
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
                                .font(AppFonts.captionSmall.weight(.bold))
                                .foregroundColor(AppColors.warningGold)
                        }

                        if store.epgLoadFailures.contains(channel.id) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(AppFonts.captionSmall.weight(.bold))
                                .foregroundStyle(AppColors.warning)
                                .accessibilityLabel(AppStrings.Player.epgRefreshFailed)
                        }

                        Text(channel.title)
                        #if os(tvOS)
                            .font(isCompactMode ? AppFonts.captionBold : AppFonts.bodyBold)
                        #else
                            .font(AppFonts.captionBold)
                        #endif
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(isCompactMode ? 1 : 2)
                            .truncationMode(.tail)
                    }

                    if channel.tvArchive == 1 {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(AppFonts.captionSmall.weight(.bold))
                            Text(AppStrings.Player.catchUp)
                                .font(AppFonts.captionSmall.weight(.bold))
                            if let days = channel.tvArchiveDuration, days > 0 {
                                Text(AppStrings.Player.catchUpArchiveDays(days))
                                    .font(AppFonts.captionSmall.weight(.bold))
                            }
                        }
                        .foregroundColor(AppColors.purpleAccent)
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
            .background(AppColors.surfaceSecondary)
            .overlay(
                Rectangle()
                    .stroke(AppColors.borderSubtle, lineWidth: 0.5)
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
            .onMoveCommand { direction in
                switch direction {
                case .up, .down:
                    verticalChannelTimeReturnArmed = focusedProgramTimeAnchor != nil
                case .right:
                    guard verticalChannelTimeReturnArmed,
                          let focusedProgramTimeAnchor else { return }
                    verticalChannelTimeReturnArmed = false
                    restoreProgramFocus(
                        in: channel,
                        nearest: focusedProgramTimeAnchor,
                        viewportWidth: timelineViewportWidth
                    )
                case .left:
                    verticalChannelTimeReturnArmed = false
                @unknown default:
                    verticalChannelTimeReturnArmed = false
                }
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
                    store.send(.editChannelLogo(channel))
                } label: {
                    Label(AppStrings.LiveTV.editChannelLogo, systemImage: "photo")
                }
            }
    }

    // MARK: - Programs Strip

    private func programsRow(for channel: MediaModels.Item, viewportWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            if store.epgLoadFailures.contains(channel.id), store.epgData[channel.id]?.isEmpty != false {
                epgLoadFailureRow(channel)
            } else if store.isLoading[channel.id] == true, store.epgData[channel.id] == nil {
                shimmerLoadingRow
            } else {
                let programs = resolvedPrograms(for: channel)
                let minVisibleX = Double(horizontalOffset) - 300
                let maxVisibleX = Double(horizontalOffset + viewportWidth) + 300
                ForEach(programs) { program in
                    let startOffset = program.startTime.timeIntervalSince(timelineStart)
                    let duration = program.endTime.timeIntervalSince(program.startTime)

                    let width = max(30, (duration / 3600.0) * Double(hourWidth))
                    let xPos = (startOffset / 3600.0) * Double(hourWidth)

                    #if os(tvOS)
                        let isProgramFocused = focusedProgramId == program.id
                    #else
                        let isProgramFocused = false
                    #endif

                    // Virtualize horizontally: Only render items within the visible viewport buffer (or if focused on tvOS)
                    if width > 0, (xPos + width >= minVisibleX && xPos <= maxVisibleX) || isProgramFocused {
                        programBlock(program: program, channel: channel, width: CGFloat(width), viewportWidth: viewportWidth)
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
                .foregroundStyle(AppColors.warning)
                .accessibilityHidden(true)

            Text(AppStrings.Player.epgRefreshFailed)
                .font(AppFonts.captionSemibold)
                .foregroundStyle(AppColors.textPrimary)

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
                        .fill(AppColors.glassPlate)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppColors.borderSubtle, lineWidth: 0.8)
                        )

                    GeometryReader { g in
                        LinearGradient(
                            colors: [
                                AppColors.glassPlate.opacity(0.0),
                                AppColors.glassPlate.opacity(0.12),
                                AppColors.glassPlate.opacity(0.0),
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

        // Channel programs are sorted once when their response enters feature state.
        // Bridge any empty intervals > 10 mins without sorting again during rendering.
        var bridged: [EPGProgram] = []
        var cursor = timelineStart

        for prog in rawPrograms {
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

    private func programBlock(program: EPGProgram, channel: MediaModels.Item, width: CGFloat, viewportWidth: CGFloat) -> some View {
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
            AppColors.cyan.opacity(0.18)
        } else if isNow {
            AppColors.accent.opacity(0.22)
        } else if isCatchUp {
            AppColors.purpleAccent.opacity(0.15)
        } else if isScheduled {
            AppColors.warningGold.opacity(0.12)
        } else if isFallback {
            AppColors.glassPlate
        } else {
            genre.background
        }

        var cardBorderColor: Color = if isSearchMatch {
            AppColors.cyan
        } else if isNow {
            AppColors.accent.opacity(0.8)
        } else if isCatchUp {
            AppColors.purpleAccent.opacity(0.4)
        } else if isScheduled {
            AppColors.warningGold.opacity(0.5)
        } else if isFallback {
            AppColors.borderSubtle
        } else {
            AppColors.borderMedium
        }
        var cardBorderLineWidth: CGFloat = (isSearchMatch || isNow) ? 1.5 : 1
        let titleFont: Font
        let timeFont: Font
        let badgeFont: Font
        let statusFont: Font
        #if os(tvOS)
            let isFocused = focusedProgramId == program.id
            titleFont = if isFocused {
                width >= 180 ? AppFonts.titleLarge : (width >= 100 ? AppFonts.titleMedium : AppFonts.titleSmall)
            } else {
                width >= 220 ? AppFonts.titleMedium : (width >= 120 ? AppFonts.titleSmall : AppFonts.bodyMedium)
            }
            timeFont = width >= 140 ? AppFonts.captionMedium : AppFonts.captionSmall
            badgeFont = AppFonts.captionBold
            statusFont = AppFonts.captionBold
            if isFocused {
                cardBackgroundColor = AppColors.surfaceElevated
                cardBorderColor = AppColors.textPrimary
                cardBorderLineWidth = 3
            }
        #else
            titleFont = isCompactMode ? AppFonts.captionSmall.weight(.bold) : (isNow || isSearchMatch ? AppFonts.captionBold : AppFonts.captionMedium)
            timeFont = AppFonts.captionSmall
            badgeFont = AppFonts.captionSmall.weight(.bold)
            statusFont = AppFonts.captionSmall.weight(.heavy)
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
                        .fill(AppColors.accent.opacity(0.35))
                        .frame(width: max(0, width * CGFloat(progressFraction)))
                }

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        if let badge = genre.badgeText {
                            Text(badge)
                                .font(badgeFont)
                                .foregroundColor(genre.border)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(genre.border.opacity(0.15), in: Capsule())
                        }

                        if isNow {
                            Circle()
                                .fill(AppColors.live)
                                .frame(width: 6, height: 6)
                            Text(AppStrings.Player.liveLabel)
                                .font(statusFont)
                                .foregroundColor(AppColors.live)
                        } else if isCatchUp {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(badgeFont)
                                .foregroundColor(AppColors.purpleAccent)
                        }

                        if isScheduled {
                            Image(systemName: "bell.fill")
                                .font(badgeFont)
                                .foregroundColor(AppColors.warningGold)
                        }

                        if isSearchMatch {
                            Image(systemName: "magnifyingglass")
                                .font(badgeFont)
                                .foregroundColor(AppColors.cyan)
                        }

                        if isFallback, !isNow {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(badgeFont)
                                .foregroundColor(AppColors.textTertiary)
                        }

                        Text(program.title)
                            .font(titleFont)
                            .foregroundColor(isSearchMatch ? AppColors.cyan : AppColors.textPrimary)
                            .lineLimit(1)
                    }

                    if !isCompactMode {
                        Text("\(formatTime(program.startTime)) - \(formatTime(program.endTime))")
                            .font(timeFont.monospacedDigit())
                            .foregroundColor(AppColors.textSecondary)
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
        .onMoveCommand { direction in
            switch direction {
            case .up, .down:
                if isCatchUp {
                    focusedProgramTimeAnchor = program.startTime.addingTimeInterval(
                        program.endTime.timeIntervalSince(program.startTime) / 2
                    )
                    verticalChannelTimeReturnArmed = true
                } else {
                    focusedProgramTimeAnchor = nil
                    verticalChannelTimeReturnArmed = false
                }
            case .left, .right:
                verticalChannelTimeReturnArmed = false
            @unknown default:
                verticalChannelTimeReturnArmed = false
            }
        }
        .onChange(of: focusedProgramId) { _, newId in
            if newId == program.id {
                if isCatchUp {
                    focusedProgramTimeAnchor = program.startTime.addingTimeInterval(
                        program.endTime.timeIntervalSince(program.startTime) / 2
                    )
                } else {
                    focusedProgramTimeAnchor = nil
                    verticalChannelTimeReturnArmed = false
                }
                if restoringProgramFocusID == newId {
                    restoringProgramFocusID = nil
                    return
                }
                restoringProgramFocusID = nil
                focusedChannelId = nil
                let targetOffset = horizontalOffsetRevealing(program, width: width, viewportWidth: viewportWidth)
                if abs(horizontalOffset - targetOffset) > 1 {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        horizontalOffset = targetOffset
                    }
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

    private func horizontalOffsetRevealing(_ program: EPGProgram, width: CGFloat, viewportWidth: CGFloat) -> CGFloat {
        let start = CGFloat(program.startTime.timeIntervalSince(timelineStart) / 3600) * hourWidth
        let visibleStart = max(0, start)
        let visibleEnd = min(totalTimelineWidth, start + width)
        let inset = min(24, viewportWidth / 8)
        var target = horizontalOffset
        if visibleEnd - visibleStart >= viewportWidth - 2 * inset {
            if visibleStart > horizontalOffset + inset {
                target = visibleStart - inset
            } else if visibleEnd < horizontalOffset + viewportWidth - inset {
                target = visibleEnd - viewportWidth + inset
            }
        } else {
            if visibleStart < horizontalOffset + inset {
                target = visibleStart - inset
            } else if visibleEnd > horizontalOffset + viewportWidth - inset {
                target = visibleEnd - viewportWidth + inset
            }
        }
        return min(max(0, totalTimelineWidth - viewportWidth), max(0, target))
    }

    #if os(tvOS)
        private func restoreProgramFocus(in channel: MediaModels.Item, nearest anchor: Date, viewportWidth: CGFloat) {
            let isShowingLoadingPlaceholder = store.isLoading[channel.id] == true && store.epgData[channel.id] == nil
            let isShowingFailurePlaceholder = store.epgLoadFailures.contains(channel.id)
                && store.epgData[channel.id]?.isEmpty != false
            guard !isShowingLoadingPlaceholder, !isShowingFailurePlaceholder else { return }

            guard let program = resolvedPrograms(for: channel).min(by: { lhs, rhs in
                distance(from: anchor, to: lhs) < distance(from: anchor, to: rhs)
            }) else { return }

            let duration = program.endTime.timeIntervalSince(program.startTime)
            let width = max(30, CGFloat(duration / 3600) * hourWidth)
            let targetOffset = horizontalOffsetRevealing(program, width: width, viewportWidth: viewportWidth)
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                horizontalOffset = targetOffset
            }

            Task { @MainActor in
                await Task.yield()
                guard focusedChannelId == channel.id,
                      displayedChannels.contains(where: { $0.id == channel.id }),
                      resolvedPrograms(for: channel).contains(where: { $0.id == program.id }) else { return }
                focusedProgramId = program.id
            }
        }

        private func distance(from anchor: Date, to program: EPGProgram) -> TimeInterval {
            if anchor < program.startTime {
                return program.startTime.timeIntervalSince(anchor)
            }
            if anchor > program.endTime {
                return anchor.timeIntervalSince(program.endTime)
            }
            return 0
        }
    #endif

    // MARK: - Floating Action Buttons

    private func jumpToNowButton(availableWidth: CGFloat) -> some View {
        Button {
            HapticManager.shared.trigger(.medium)
            #if os(tvOS)
                focusedProgramTimeAnchor = nil
                verticalChannelTimeReturnArmed = false
            #endif
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
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(AppColors.accent)
                    .overlay(Capsule().stroke(AppColors.borderStrong, lineWidth: 1))
                    .shadow(color: AppColors.accent.opacity(0.5), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    private func returnToTodayButton(availableWidth: CGFloat) -> some View {
        Button {
            HapticManager.shared.trigger(.medium)
            #if os(tvOS)
                focusedProgramTimeAnchor = nil
                verticalChannelTimeReturnArmed = false
            #endif
            let now = Date()
            store.send(.selectDate(now))
            let target = targetHorizontalOffset(for: now, availableWidth: availableWidth)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                horizontalOffset = target
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(AppFonts.captionBold)
                    .foregroundColor(AppColors.textPrimary)
                Text(AppStrings.Player.returnToToday)
                    .font(AppFonts.captionBold)
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(AppColors.purpleAccent)
                    .overlay(Capsule().stroke(AppColors.borderStrong, lineWidth: 1))
                    .shadow(color: AppColors.purpleAccent.opacity(0.5), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Program Detail Sheet & Live Preview Window

    func programDetailSheet(program: EPGProgram, channel: MediaModels.Item) -> some View {
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
                        PlaylistAsyncImage(url: url, fallbackURL: channel.coverURL, userAgentOverride: channel.userAgentOverride, playlistID: channel.playlistID) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFit()
                            } else {
                                Image(systemName: "tv.fill")
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .background(AppColors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 6))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(channel.title)
                            .font(AppFonts.headline)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)

                        if !channel.categoryID.isEmpty {
                            Text(channel.categoryID)
                                .font(AppFonts.captionSmall)
                                .foregroundColor(AppColors.accent)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Button {
                    store.send(.dismissProgramDetails)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppFonts.titleLarge)
                        .foregroundColor(AppColors.textSecondary)
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
                            .font(AppFonts.titleLarge)
                            .foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Label("\(formatTime(program.startTime)) - \(formatTime(program.endTime))", systemImage: "clock")
                                .font(AppFonts.captionBold)
                                .foregroundColor(AppColors.textSecondary)

                            let durationMins = Int(totalSecs / 60)
                            Label("\(durationMins) \(AppStrings.Common.minAbbr)", systemImage: "hourglass")
                                .font(AppFonts.captionBold)
                                .foregroundColor(AppColors.textSecondary)

                            if isNow {
                                Text("%\(percentInt) \(AppStrings.Player.completed)")
                                    .font(AppFonts.captionBold)
                                    .foregroundColor(AppColors.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.accent.opacity(0.18), in: Capsule())
                            } else if isCatchUp {
                                Label(AppStrings.Player.catchUp, systemImage: "clock.arrow.circlepath")
                                    .font(AppFonts.captionBold)
                                    .foregroundColor(AppColors.purpleAccent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.purpleAccent.opacity(0.18), in: Capsule())
                            }
                        }
                    }

                    // Progress bar for active program
                    if isNow {
                        VStack(alignment: .leading, spacing: 4) {
                            GeometryReader { pGeo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(AppColors.borderMedium)
                                        .frame(height: 5)
                                    Capsule()
                                        .fill(LinearGradient(colors: [AppColors.accent, AppColors.cyan], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: max(0, pGeo.size.width * CGFloat(progressFraction)), height: 5)
                                }
                            }
                            .frame(height: 5)

                            HStack {
                                Text(formatTime(program.startTime))
                                Spacer()
                                Text(formatTime(program.endTime))
                            }
                            .font(AppFonts.captionSmall.monospacedDigit())
                            .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    // Program Description
                    if !program.description.isEmpty {
                        Text(program.description)
                            .font(AppFonts.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
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
        .background(AppColors.surfaceSecondary.ignoresSafeArea())
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
                    colors: isNow ? [AppColors.accent.opacity(0.3), AppColors.background.opacity(0.8)] : (isCatchUp ? [AppColors.purpleAccent.opacity(0.3), AppColors.background.opacity(0.8)] : [AppColors.surfaceSecondary, AppColors.background.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                let artworkURL = liveTVArtworkSource.primaryArtworkURL(for: program, channel: channel)
                let isProgramArtwork = liveTVArtworkSource == .epgProgram &&
                    channel.logoURLOverride == nil && program.artworkURL != nil
                if artworkURL != nil || channel.coverURL != nil {
                    PlaylistAsyncImage(
                        url: artworkURL,
                        fallbackURL: channel.coverURL,
                        userAgentOverride: channel.userAgentOverride,
                        playlistID: channel.playlistID,
                        downsamplingSize: CGSize(width: 640, height: 360)
                    ) { phase in
                        if let img = phase.image {
                            img.resizable()
                                .aspectRatio(contentMode: .fill)
                                .opacity(isProgramArtwork ? 0.38 : 0.18)
                                .blur(radius: isProgramArtwork ? 2 : 12)
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
                                .font(AppFonts.titleLarge)
                                .foregroundColor(AppColors.textPrimary)
                        )
                        .shadow(color: AppColors.background.opacity(0.4), radius: 8)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: "calendar.badge.clock")
                                .font(AppFonts.titleLarge)
                                .foregroundColor(AppColors.warningGold)
                        )
                        .shadow(color: AppColors.background.opacity(0.4), radius: 8)
                }

                // Top Floating Status Pill
                VStack {
                    HStack {
                        if isNow {
                            HStack(spacing: 5) {
                                Circle().fill(AppColors.live).frame(width: 6, height: 6)
                                Text(AppStrings.Player.liveLabel)
                                    .font(AppFonts.captionSmall.weight(.heavy))
                                    .foregroundColor(AppColors.live)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.background.opacity(0.6), in: Capsule())
                            .overlay(Capsule().stroke(AppColors.live.opacity(0.4), lineWidth: 1))
                        } else if isCatchUp {
                            HStack(spacing: 5) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text(AppStrings.Player.catchUp)
                            }
                            .font(AppFonts.captionSmall.weight(.bold))
                            .foregroundColor(AppColors.purpleAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.background.opacity(0.6), in: Capsule())
                            .overlay(Capsule().stroke(AppColors.purpleAccent.opacity(0.4), lineWidth: 1))
                        }

                        Spacer()

                        // Stream Quality Tag
                        Text("1080p HD")
                            .font(AppFonts.captionSmall.weight(.bold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppColors.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(12)

                    Spacer()

                    // Bottom progress indicator in preview card
                    if isNow {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(AppColors.borderMedium)
                                Rectangle().fill(AppColors.accent).frame(width: max(0, g.size.width * CGFloat(progressFraction)))
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
                    .stroke(AppColors.borderMedium, lineWidth: 1)
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
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 12))
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
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.purpleAccent, in: RoundedRectangle(cornerRadius: 12))
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
                                .font(AppFonts.headline)
                                .foregroundColor(isScheduled ? AppColors.textPrimary : AppColors.background)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isScheduled ? AppColors.live.opacity(0.85) : AppColors.warningGold, in: RoundedRectangle(cornerRadius: 12))
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
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                #if os(iOS)
                    ShareLink(item: "\(program.title) - \(channel.title)") {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(AppStrings.Player.share)
                        }
                        .font(AppFonts.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10))
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
                        .font(AppFonts.bodyBold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .tvFocusEffect(shape: .capsule)
                #endif
            }
        }
    }

    // MARK: - Helpers

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tv.slash")
                .font(AppFonts.displayLarge)
                .foregroundColor(AppColors.textTertiary)
            Text(store.filteredChannels.isEmpty ? AppStrings.LiveTV.noChannels : AppStrings.EPG.noData)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func targetCenteredNowOffset(availableWidth: CGFloat) -> CGFloat {
        targetHorizontalOffset(for: store.currentTime, availableWidth: availableWidth)
    }

    private func targetHorizontalOffset(for date: Date, availableWidth: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let anchor: Date
        if calendar.isDateInToday(date) {
            let hour = calendar.dateInterval(of: .hour, for: date)?.start ?? date
            anchor = calendar.date(byAdding: .hour, value: -pastHoursAnchor, to: hour) ?? hour
        } else {
            anchor = calendar.startOfDay(for: date)
        }
        let target = CGFloat(date.timeIntervalSince(anchor) / 3600) * hourWidth - availableWidth * 0.35
        let maxOffset = max(0, totalTimelineWidth - availableWidth)
        return max(0, min(maxOffset, target))
    }

    private func timeNavigationControls(availableWidth: CGFloat) -> some View {
        let maxOffset = max(0, totalTimelineWidth - availableWidth)
        let canMoveBackward = horizontalOffset > 0
        let canMoveForward = horizontalOffset < maxOffset

        return HStack(spacing: 8) {
            Button {
                guard canMoveBackward else { return }
                shiftTimeline(byHours: -navigationStepHours, availableWidth: availableWidth)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.bold())
                    .frame(minWidth: 38, minHeight: 38)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(AppStrings.Settings.timeShiftHours(-navigationStepHours))
            .opacity(canMoveBackward ? 1 : 0.45)

            Menu {
                ForEach([1, 2, 3, 6], id: \.self) { hours in
                    Button(AppStrings.Settings.timeShiftHours(hours)) {
                        navigationStepHours = hours
                    }
                }
            } label: {
                Text(AppStrings.Settings.timeShiftHours(navigationStepHours))
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .frame(minHeight: 38)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(AppStrings.Settings.timeShift)

            Button {
                guard canMoveForward else { return }
                shiftTimeline(byHours: navigationStepHours, availableWidth: availableWidth)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .frame(minWidth: 38, minHeight: 38)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(AppStrings.Settings.timeShiftHours(navigationStepHours))
            .opacity(canMoveForward ? 1 : 0.45)

            if store.isViewingToday {
                if abs(horizontalOffset - targetCenteredNowOffset(availableWidth: availableWidth)) > 160 {
                    jumpToNowButton(availableWidth: availableWidth)
                }
            } else {
                returnToTodayButton(availableWidth: availableWidth)
            }
        }
        .padding(8)
        .background(AppColors.backgroundSubtle.opacity(0.85), in: Capsule())
        #if os(tvOS)
            .focusSection()
        #endif
    }

    private func shiftTimeline(byHours hours: Int, availableWidth: CGFloat) {
        HapticManager.shared.trigger(.light)
        #if os(tvOS)
            focusedProgramTimeAnchor = nil
            verticalChannelTimeReturnArmed = false
        #endif
        let maxOffset = max(0, totalTimelineWidth - availableWidth)
        let target = horizontalOffset + CGFloat(hours) * hourWidth
        withAnimation(.easeInOut(duration: 0.25)) {
            horizontalOffset = max(0, min(maxOffset, target))
        }
    }

    private func navigateToSearchMatch(_ query: String, availableWidth: CGFloat) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        let matches = store.filteredChannels.flatMap { channel in
            (store.epgData[channel.id] ?? []).compactMap { program -> (MediaModels.Item, EPGProgram)? in
                guard program.title.localizedCaseInsensitiveContains(query)
                    || program.description.localizedCaseInsensitiveContains(query) else { return nil }
                return (channel, program)
            }
        }
        guard let match = matches.min(by: { lhs, rhs in
            abs(lhs.1.startTime.timeIntervalSince(store.currentTime))
                < abs(rhs.1.startTime.timeIntervalSince(store.currentTime))
        }) else { return }

        let startMilliseconds = Int64(match.1.startTime.timeIntervalSince1970 * 1000)
        let endMilliseconds = Int64(match.1.endTime.timeIntervalSince1970 * 1000)
        let key = "\(query)|\(match.0.id)|\(match.1.id)|\(startMilliseconds)|\(endMilliseconds)"
        guard key != lastSearchNavigationKey else { return }
        lastSearchNavigationKey = key
        if !Calendar.current.isDate(match.1.startTime, inSameDayAs: store.selectedDate) {
            store.send(.selectDate(match.1.startTime))
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: match.1.startTime)
        let timelineAnchor: Date
        if calendar.isDateInToday(match.1.startTime) {
            let currentHour = calendar.dateInterval(of: .hour, for: store.currentTime)?.start ?? store.currentTime
            timelineAnchor = calendar.date(byAdding: .hour, value: -pastHoursAnchor, to: currentHour) ?? currentHour
        } else {
            timelineAnchor = dayStart
        }
        let targetX = CGFloat(match.1.startTime.timeIntervalSince(timelineAnchor) / 3600) * hourWidth
            - availableWidth * 0.2
        let maxOffset = max(0, totalTimelineWidth - availableWidth)
        withAnimation(.easeInOut(duration: 0.3)) {
            horizontalOffset = min(maxOffset, max(0, targetX))
        }
        pendingSearchChannelID = match.0.id
        #if os(tvOS)
            pendingFocusRestoreChannelID = nil
            restoringProgramFocusID = nil
            focusedChannelId = nil
            focusedProgramId = match.1.id
        #endif
    }

    #if os(tvOS)
        private func reconcileChannelFocus(previousIDs: [String], currentIDs: [String]) {
            guard pendingFocusRestoreChannelID == nil, focusedProgramId == nil else { return }
            guard !currentIDs.isEmpty else {
                focusedChannelId = nil
                return
            }
            if let focusedChannelId, currentIDs.contains(focusedChannelId) {
                return
            }
            if let lastFocusedChannelID, currentIDs.contains(lastFocusedChannelID) {
                focusedChannelId = lastFocusedChannelID
                return
            }

            let previousIndex = lastFocusedChannelID.flatMap { previousIDs.firstIndex(of: $0) } ?? 0
            let replacementID = currentIDs[min(previousIndex, currentIDs.count - 1)]
            lastFocusedChannelID = replacementID
            focusedChannelId = replacementID
        }

        private func restoreSavedFocusIfAvailable() {
            guard let channelID = pendingFocusRestoreChannelID else { return }
            guard !displayedChannels.isEmpty else { return }
            guard displayedChannels.contains(where: { $0.id == channelID }) else {
                restoringProgramFocusID = nil
                pendingFocusRestoreChannelID = displayedChannels.first?.id
                return
            }

            guard let programID = restoringProgramFocusID else {
                Task { @MainActor in
                    await Task.yield()
                    guard pendingFocusRestoreChannelID == channelID,
                          restoringProgramFocusID == nil,
                          displayedChannels.contains(where: { $0.id == channelID }) else { return }
                    focusedChannelId = channelID
                    pendingFocusRestoreChannelID = nil
                }
                return
            }

            guard let programs = store.epgData[channelID] else { return }
            guard programs.contains(where: { $0.id == programID }) else {
                guard store.isLoading[channelID] != true else { return }
                restoringProgramFocusID = nil
                Task { @MainActor in
                    await Task.yield()
                    guard pendingFocusRestoreChannelID == channelID,
                          restoringProgramFocusID == nil,
                          displayedChannels.contains(where: { $0.id == channelID }) else { return }
                    focusedChannelId = channelID
                    pendingFocusRestoreChannelID = nil
                }
                return
            }

            Task { @MainActor in
                await Task.yield()
                guard pendingFocusRestoreChannelID == channelID,
                      restoringProgramFocusID == programID,
                      store.epgData[channelID]?.contains(where: { $0.id == programID }) == true else { return }
                focusedProgramId = programID
                pendingFocusRestoreChannelID = nil
            }
        }
    #endif

    private func isProgramMatchingSearch(_ program: EPGProgram) -> Bool {
        let query = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return false }
        return program.title.localizedCaseInsensitiveContains(query) ||
            program.description.localizedCaseInsensitiveContains(query)
    }

    private func formatTime(_ date: Date) -> String {
        LocalTimePresentation.string(from: date, locale: locale)
    }

    private func formatDay(_ date: Date) -> String {
        AppFormatters.dayShort(date)
    }

    // MARK: - Renk Kodlu EPG Kategorileri (Madde #28)

    private func genrePastelColor(for program: EPGProgram) -> (background: Color, border: Color, badgeText: String?) {
        let text = (program.title + " " + program.description).lowercased()
        if text.contains("spor") || text.contains("sport") || text.contains("futbol") || text.contains("basket") || text.contains("lig") || text.contains("match") {
            return (AppColors.amber.opacity(0.18), AppColors.amber.opacity(0.5), "SPOR")
        } else if text.contains("haber") || text.contains("news") || text.contains("bülten") || text.contains("gündem") {
            return (AppColors.primary.opacity(0.18), AppColors.primary.opacity(0.5), "HABER")
        } else if text.contains("sinema") || text.contains("film") || text.contains("movie") || text.contains("dizi") || text.contains("cinema") {
            return (AppColors.purpleAccent.opacity(0.18), AppColors.purpleAccent.opacity(0.5), "SİNEMA")
        } else if text.contains("çocuk") || text.contains("cocuk") || text.contains("cartoon") || text.contains("animasyon") || text.contains("kids") {
            return (AppColors.warningGold.opacity(0.18), AppColors.warningGold.opacity(0.5), "ÇOCUK")
        } else {
            return (AppColors.surfaceSecondary, AppColors.borderSubtle, nil)
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

struct EPGTimelineChannelLogoEditorForm: View {
    @Binding var logoURLDraft: String
    let onSave: (String?) -> Void
    let onClose: () -> Void

    private var canSaveLogo: Bool {
        ChannelLogoOverrideURL.validatedURL(from: logoURLDraft) != nil
    }

    var body: some View {
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
                        onClose()
                        onSave(nil)
                    }
                }
            }
            .navigationTitle(AppStrings.LiveTV.editChannelLogo)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.Common.cancel, action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.Common.save) {
                        guard canSaveLogo else { return }
                        onClose()
                        onSave(logoURLDraft)
                    }
                    .opacity(canSaveLogo ? 1 : 0.5)
                    .accessibilityHint(canSaveLogo ? "" : AppStrings.LiveTV.invalidChannelLogoURL)
                }
            }
        }
    }
}
