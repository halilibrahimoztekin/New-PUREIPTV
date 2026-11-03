#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Live TV Category Drawer (tvOS)

    /// Dedicated subview for tvOS Live TV categories column.
    /// Provides narrow invalidation boundaries so channel list updates do not re-render the category tree.
    public struct LiveTVCategoryDrawer_tvOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        let config: PlaylistConfig
        var focusedCategory: FocusState<String?>.Binding
        @Binding var categorySearchQuery: String
        let onEnterChannelSelection: () -> Void

        public init(
            store: StoreOf<LiveTVFeature>,
            config: PlaylistConfig,
            focusedCategory: FocusState<String?>.Binding,
            categorySearchQuery: Binding<String>,
            onEnterChannelSelection: @escaping () -> Void
        ) {
            self.store = store
            self.config = config
            self.focusedCategory = focusedCategory
            _categorySearchQuery = categorySearchQuery
            self.onEnterChannelSelection = onEnterChannelSelection
        }

        private var filteredCategories: [MediaModels.Category] {
            let query = categorySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return store.categories }
            return store.categories.filter { $0.name.localizedStandardContains(query) }
        }

        public var body: some View {
            ScrollViewReader { catProxy in
                let itemCountsByCategory = store.visibleChannelCountsByCategory
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        headerSection

                        if let refreshStage = store.refreshStage {
                            Label(refreshStage.title, systemImage: "arrow.triangle.2.circlepath")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        if let refreshMessage = store.refreshMessage {
                            Text(refreshMessage)
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.destructive)
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
                            smartGroupsSection

                            let categories = filteredCategories
                            if !store.categories.isEmpty {
                                CategorySearchField(text: $categorySearchQuery) {
                                    if let firstMatch = categories.first {
                                        store.send(.categorySelected(firstMatch))
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                            }
                            if !store.categories.isEmpty, categories.isEmpty {
                                Text(AppStrings.Common.categoryNotFound)
                                    .font(AppFonts.caption)
                                    .foregroundStyle(AppColors.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                            }
                            ForEach(categories) { category in
                                categoryRow(for: category, itemCount: itemCountsByCategory[category.id])
                            }
                        }
                    }
                    .padding(.bottom, 48)
                }
                .background(AppColors.surface)
                .focusSection()
                .onChange(of: store.selectedCategoryID) { _, newCatID in
                    if let newCatID {
                        if !filteredCategories.contains(where: { $0.id == newCatID }) {
                            categorySearchQuery = ""
                        }
                        focusedCategory.wrappedValue = newCatID
                        TVFocusMemory.shared.lastSelectedLiveCategoryID = newCatID
                        withAnimation { catProxy.scrollTo(newCatID, anchor: .center) }
                    }
                }
                .onChange(of: store.selectedSmartGroupID) { _, newGroupID in
                    if let newGroupID {
                        let focusID = "smart-group:\(newGroupID)"
                        focusedCategory.wrappedValue = focusID
                        withAnimation { catProxy.scrollTo(focusID, anchor: .center) }
                    }
                }
                .onChange(of: focusedCategory.wrappedValue) { _, newCatID in
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
                        focusedCategory.wrappedValue = targetCatID
                        withAnimation { catProxy.scrollTo(targetCatID, anchor: .center) }
                    }
                }
            }
        }

        // MARK: - Header Actions Section

        private var headerSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(AppStrings.LiveTV.categories)
                        .font(AppFonts.headline)
                        .foregroundStyle(AppColors.textPrimary)
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
                            .font(AppFonts.title)
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
                            .font(AppFonts.titleSmall)
                            .frame(width: 44, height: 44)
                        }
                        .buttonStyle(TVCircleButtonStyle())
                        .accessibilityLabel(store.isRefreshingContent ? "Yenilemeyi iptal et" : "Canlı kanalları yenile")
                    }

                    Button {
                        if store.isChannelSelectionMode {
                            store.send(.exitChannelSelectionMode)
                        } else {
                            onEnterChannelSelection()
                        }
                    } label: {
                        Image(systemName: store.isChannelSelectionMode ? "xmark" : "checklist")
                            .font(AppFonts.titleSmall)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(TVCircleButtonStyle())
                    .accessibilityLabel(store.isChannelSelectionMode ? AppStrings.LiveTV.cancelChannelSelection : AppStrings.LiveTV.selectChannels)

                    Button {
                        store.send(.openEPGTimelineTapped)
                    } label: {
                        Image(systemName: "calendar.day.timeline.left")
                            .font(AppFonts.title)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(TVCircleButtonStyle())
                    .accessibilityLabel(AppStrings.LiveTV.channelGuide)

                    Button {
                        store.send(.epgGuideTapped)
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .font(AppFonts.title)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(TVCircleButtonStyle())
                    .accessibilityLabel(AppStrings.EPG.guide)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 16)
        }

        // MARK: - Smart Channel Groups

        private var smartGroupsSection: some View {
            ForEach(store.smartChannelGroups) { group in
                TVCategoryRow(
                    category: MediaModels.Category(id: "smart-group:\(group.id)", name: group.name),
                    isSelected: store.selectedSmartGroupID == group.id,
                    isLocked: false
                ) {
                    store.send(.smartGroupSelected(group.id))
                }
                .padding(.horizontal, 16)
                .focused(focusedCategory, equals: "smart-group:\(group.id)")
                .id("smart-group:\(group.id)")
            }
        }

        // MARK: - Category Row Wrapper

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
            .focused(focusedCategory, equals: category.id)
            .id(category.id)
        }
    }

    // MARK: - TV Category Row Component

    public struct TVCategoryRow: View {
        let category: MediaModels.Category
        let isSelected: Bool
        let isLocked: Bool
        let itemCount: Int?
        let action: () -> Void

        public init(
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

        public var body: some View {
            Button(action: action) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isSelected ? AppColors.primary : Color.clear)
                        .frame(width: 4, height: 26)

                    Text(category.name)
                        .font(isSelected ? AppFonts.titleSmall.weight(.bold) : AppFonts.titleSmall)
                        .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.85))
                        .lineLimit(1)

                    Spacer()

                    if let itemCount {
                        Text("\(itemCount)")
                            .font(AppFonts.captionSemibold.monospacedDigit())
                            .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.85))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                isSelected ? AppColors.primary.opacity(0.35) : AppColors.glassPlate,
                                in: Capsule()
                            )
                    }

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.warning)
                    }
                }
            }
        }
    }
#endif
