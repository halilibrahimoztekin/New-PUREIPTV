import ComposableArchitecture
import SwiftUI

public struct CategoryManagementView: View {
    @Bindable var store: StoreOf<CategoryManagementFeature>

    @FocusState private var focusedItemID: String?
    @State private var editingCategory: MediaModels.Category?

    public init(store: StoreOf<CategoryManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                if store.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(AppColors.primary)
                            .scaleEffect(1.2)
                        Text(AppStrings.Common.loading)
                            .font(AppFonts.bodySmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                } else if store.categories.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(AppFonts.custom(size: 44, weight: .regular))
                            .foregroundStyle(AppColors.textSecondary)
                        Text(AppStrings.CategoryMgmt.noCategoriesFound)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                } else {
                    mainContentView
                }
            }
            .navigationTitle(AppStrings.CategoryMgmt.manageTitle(for: store.type.title))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.cancel) {
                            store.send(.closeTapped)
                        }
                        .foregroundStyle(AppColors.textSecondary)
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppStrings.Common.save) {
                            store.send(.saveTapped)
                        }
                        .font(AppFonts.button)
                        .foregroundStyle(store.hasUnsavedChanges ? AppColors.primary : AppColors.textSecondary)
                        .disabled(!store.hasUnsavedChanges)
                    }
                }
            #if os(tvOS)
                .onExitCommand {
                    store.send(.closeTapped)
                }
            #endif
                .onAppear {
                    store.send(.onAppear)
                }
                .sheet(item: $editingCategory) { category in
                    CategoryNameEditorView(
                        sourceName: category.sourceName,
                        currentName: category.name,
                        onSave: { name in
                            store.send(.setCategoryNameOverride(categoryID: category.id, name: name))
                        },
                        onClose: { editingCategory = nil }
                    )
                }
                .sheet(isPresented: $store.isCategoryNameRulesPresented, onDismiss: {
                    store.send(.cancelCategoryNameRulesTapped)
                }) {
                    CategoryNameRulesView(store: store)
                }
        }
    }

    // MARK: - Main Content View

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header Controls: Search, Filters & Bulk Actions
            headerControlsSection

            Divider()
                .overlay(AppColors.divider)

            // Categories List
            categoryListView
        }
    }

    // MARK: - Header Controls Section

    private var headerControlsSection: some View {
        VStack(spacing: 12) {
            if store.config.type == .m3u, store.type == .live {
                Button {
                    store.send(.m3uCategoryMappingTapped)
                } label: {
                    Label(AppStrings.M3UCategoryMapping.title, systemImage: "tag")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 16)
            }

            if store.config.playlistID != nil {
                Button {
                    store.send(.categoryNameRulesTapped)
                } label: {
                    Label(AppStrings.CategoryMgmt.nameRulesTitle, systemImage: "text.magnifyingglass")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 16)
            }

            #if os(iOS)
                // Search Bar (iOS)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppColors.textSecondary)
                        .font(AppFonts.bodyMedium)

                    TextField(AppStrings.CategoryMgmt.searchPlaceholder, text: $store.searchQuery.sending(\.setSearchQuery))
                        .font(AppFonts.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary)
                        .autocorrectionDisabled()

                    if !store.searchQuery.isEmpty {
                        Button {
                            store.send(.setSearchQuery(""))
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppColors.textSecondary)
                                .font(AppFonts.caption)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.surfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 16)
            #endif

            // Summary & Filter Modes
            HStack {
                // Active count badge
                Text(AppStrings.CategoryMgmt.visibleCountInfo(visible: store.visibleCount, total: store.totalCount))
                    .font(AppFonts.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                // Filter Segment Pills
                HStack(spacing: 6) {
                    ForEach(CategoryManagementFeature.State.FilterMode.allCases, id: \.self) { mode in
                        let isSelected = store.filterMode == mode
                        Button {
                            #if !os(tvOS)
                                HapticManager.shared.trigger(.light)
                            #endif
                            store.send(.setFilterMode(mode))
                        } label: {
                            Text(modeTitleWithBadge(mode))
                                .font(isSelected ? AppFonts.captionBold : AppFonts.captionMedium)
                                .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    isSelected ? AppColors.primary : AppColors.surfaceElevated,
                                    in: Capsule()
                                )
                        }
                        #if os(tvOS)
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: isSelected))
                        #else
                        .buttonStyle(.plain)
                        #endif
                    }
                }
            }
            .padding(.horizontal, 16)

            // Bulk Actions Bar
            HStack(spacing: 8) {
                // Show All Button
                Button {
                    #if !os(tvOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    store.send(.showAllTapped)
                } label: {
                    Label(AppStrings.CategoryMgmt.showAll, systemImage: "eye.fill")
                        .font(AppFonts.captionSemibold)
                        .foregroundStyle(AppColors.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.success.opacity(0.14), in: Capsule())
                }
                #if os(tvOS)
                .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                #else
                .buttonStyle(.plain)
                #endif

                // Hide All Button
                Button {
                    #if !os(tvOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    store.send(.hideAllTapped)
                } label: {
                    Label(AppStrings.CategoryMgmt.hideAll, systemImage: "eye.slash.fill")
                        .font(AppFonts.captionSemibold)
                        .foregroundStyle(AppColors.destructive)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.destructive.opacity(0.14), in: Capsule())
                }
                #if os(tvOS)
                .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                #else
                .buttonStyle(.plain)
                #endif

                // Invert Button
                Button {
                    #if !os(tvOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    store.send(.invertVisibilityTapped)
                } label: {
                    Label(AppStrings.CategoryMgmt.invert, systemImage: "arrow.triangle.2.circlepath")
                        .font(AppFonts.captionSemibold)
                        .foregroundStyle(AppColors.warning)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.warning.opacity(0.14), in: Capsule())
                }
                #if os(tvOS)
                .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                #endif
                // Country Presets (Madde #52)
                Menu {
                    Button("Sadece Türkiye (TR) Gruplarını Bırak") {
                        store.send(.bulkKeepOnlyPrefixes(["tr", "türk", "turk", "turkey"]))
                    }
                    Button("Sadece TR / UK / US Gruplarını Bırak") {
                        store.send(.bulkKeepOnlyPrefixes(["tr", "türk", "turk", "uk", "us", "usa"]))
                    }
                } label: {
                    Label("Hızlı Ülke Filtresi", systemImage: "globe")
                        .font(AppFonts.captionSemibold)
                        .foregroundStyle(AppColors.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.cyan.opacity(0.14), in: Capsule())
                }
                #if os(tvOS)
                .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                #else
                .buttonStyle(.plain)
                #endif

                Spacer()

                // Reset Order Button
                Button {
                    #if !os(tvOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    store.send(.resetOrderTapped)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(AppFonts.captionSemibold)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(6)
                        .background(AppColors.surfaceElevated, in: Circle())
                }
                #if os(tvOS)
                .buttonStyle(TVCircleButtonStyle())
                #else
                .buttonStyle(.plain)
                #endif
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .padding(.top, 10)
    }

    private func modeTitleWithBadge(_ mode: CategoryManagementFeature.State.FilterMode) -> String {
        switch mode {
        case .all:
            "\(mode.title) (\(store.totalCount))"
        case .visible:
            "\(mode.title) (\(store.visibleCount))"
        case .hidden:
            "\(mode.title) (\(store.hiddenCount))"
        }
    }

    // MARK: - Category List View

    private var categoryListView: some View {
        List {
            ForEach(store.filteredCategories) { category in
                let isHidden = store.categoryPreferences[category.id]?.isHidden ?? false
                let isLocked = store.categoryPreferences[category.id]?.isLocked ?? false

                HStack(spacing: 12) {
                    // Category icon & name
                    Image(systemName: isLocked ? "lock.fill" : (isHidden ? "folder.badge.minus" : "folder.fill"))
                        .font(AppFonts.titleSmall)
                        .foregroundStyle(isLocked ? AppColors.warning : (isHidden ? AppColors.textTertiary : AppColors.primary))

                    Text(category.name)
                        .font(isHidden ? AppFonts.bodySmall : AppFonts.bodyMedium)
                        .foregroundStyle(isHidden ? AppColors.textSecondary : AppColors.textPrimary)

                    Button {
                        editingCategory = category
                    } label: {
                        Image(systemName: "pencil")
                            .font(AppFonts.captionSemibold)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(6)
                            .background(AppColors.surfaceElevated, in: Circle())
                    }
                    #if os(tvOS)
                    .buttonStyle(TVCircleButtonStyle())
                    #else
                    .buttonStyle(.plain)
                    #endif
                    .accessibilityLabel(AppStrings.CategoryMgmt.editCategoryName)

                    Spacer()

                    // Lock / PIN Protect Button
                    Button {
                        #if !os(tvOS)
                            HapticManager.shared.trigger(.light)
                        #endif
                        store.send(.toggleLock(categoryID: category.id))
                    } label: {
                        Image(systemName: isLocked ? "lock.fill" : "lock.open")
                            .font(AppFonts.captionSemibold)
                            .foregroundStyle(isLocked ? AppColors.warning : AppColors.textSecondary)
                            .padding(6)
                            .background(
                                (isLocked ? AppColors.warning : AppColors.surfaceElevated).opacity(0.12),
                                in: Circle()
                            )
                    }
                    #if os(tvOS)
                    .buttonStyle(TVCircleButtonStyle())
                    #else
                    .buttonStyle(.plain)
                    #endif
                    .accessibilityLabel(isLocked ? AppStrings.CategoryMgmt.unlockCategory : AppStrings.CategoryMgmt.lockCategory)

                    // Toggle Button
                    Button {
                        #if !os(tvOS)
                            HapticManager.shared.trigger(.light)
                        #endif
                        store.send(.toggleVisibility(categoryID: category.id))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                                .font(AppFonts.caption)
                            Text(isHidden ? AppStrings.CategoryMgmt.filterHidden : AppStrings.CategoryMgmt.filterVisible)
                                .font(AppFonts.captionSemibold)
                        }
                        .foregroundStyle(isHidden ? AppColors.destructive : AppColors.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (isHidden ? AppColors.destructive : AppColors.success).opacity(0.12),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke((isHidden ? AppColors.destructive : AppColors.success).opacity(0.3), lineWidth: 1)
                        )
                    }
                    #if os(tvOS)
                    .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                    #else
                    .buttonStyle(.plain)
                    #endif
                }
                .contentShape(Rectangle())
                .padding(.vertical, 2)
                #if os(tvOS)
                    .focused($focusedItemID, equals: category.id)
                    .scaleEffect(focusedItemID == category.id ? 1.03 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: focusedItemID)
                #endif
                    .listRowBackground(AppColors.surfaceSecondary)
                #if os(tvOS)
                    .contextMenu {
                        if store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           store.filterMode == .all,
                           let categoryIndex = store.categories.firstIndex(where: { $0.id == category.id })
                        {
                            if categoryIndex > 0 {
                                Button(AppStrings.CategoryMgmt.moveCategoryUp, systemImage: "arrow.up") {
                                    store.send(.moveCategory(from: IndexSet(integer: categoryIndex), to: categoryIndex - 1))
                                }
                            }
                            if categoryIndex < store.categories.count - 1 {
                                Button(AppStrings.CategoryMgmt.moveCategoryDown, systemImage: "arrow.down") {
                                    store.send(.moveCategory(from: IndexSet(integer: categoryIndex), to: categoryIndex + 1))
                                }
                            }
                        }
                    }
                #endif
            }
            .onMove { source, destination in
                store.send(.moveCategory(from: source, to: destination))
            }
        }
        .listStyle(.plain)
        #if !os(tvOS)
            .scrollContentBackground(.hidden)
        #endif
        #if os(iOS)
        .environment(\.editMode, .constant(store.searchQuery.isEmpty && store.filterMode == .all ? .active : .inactive))
        #endif
    }
}
