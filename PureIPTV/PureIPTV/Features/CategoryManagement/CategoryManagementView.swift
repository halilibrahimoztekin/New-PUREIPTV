import ComposableArchitecture
import SwiftUI

public struct CategoryManagementView: View {
    @Bindable var store: StoreOf<CategoryManagementFeature>

    @FocusState private var focusedItemID: String?
    @FocusState private var focusedFilterMode: CategoryManagementFeature.State.FilterMode?

    public init(store: StoreOf<CategoryManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0F0F13").ignoresSafeArea()

                if store.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.accentColor)
                            .scaleEffect(1.2)
                        Text(AppStrings.Common.loading)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if store.categories.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text(AppStrings.CategoryMgmt.noCategoriesFound)
                            .font(.headline)
                            .foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppStrings.Common.save) {
                            store.send(.saveTapped)
                        }
                        .fontWeight(.bold)
                        .foregroundColor(store.hasUnsavedChanges ? Color.accentColor : .secondary)
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
        }
    }

    // MARK: - Main Content View

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header Controls: Search, Filters & Bulk Actions
            headerControlsSection

            Divider()
                .overlay(Color.white.opacity(0.08))

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

            #if os(iOS)
                // Search Bar (iOS)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15))

                    TextField(AppStrings.CategoryMgmt.searchPlaceholder, text: $store.searchQuery.sending(\.setSearchQuery))
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .autocorrectionDisabled()

                    if !store.searchQuery.isEmpty {
                        Button {
                            store.send(.setSearchQuery(""))
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 16)
            #endif

            // Summary & Filter Modes
            HStack {
                // Active count badge
                Text(AppStrings.CategoryMgmt.visibleCountInfo(visible: store.visibleCount, total: store.totalCount))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

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
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    isSelected ? Color.accentColor : Color.white.opacity(0.08),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        #if os(tvOS)
                            .focused($focusedFilterMode, equals: mode)
                            .scaleEffect(focusedFilterMode == mode ? 1.08 : 1.0)
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)

                // Hide All Button
                Button {
                    #if !os(tvOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    store.send(.hideAllTapped)
                } label: {
                    Label(AppStrings.CategoryMgmt.hideAll, systemImage: "eye.slash.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)

                // Invert Button
                Button {
                    #if !os(tvOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    store.send(.invertVisibilityTapped)
                } label: {
                    Label(AppStrings.CategoryMgmt.invert, systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.14), in: Capsule())
                }
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.cyan.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                // Reset Order Button
                Button {
                    #if !os(tvOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    store.send(.resetOrderTapped)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
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
                        .font(.system(size: 15))
                        .foregroundColor(isLocked ? .orange : (isHidden ? .secondary.opacity(0.5) : Color.accentColor))

                    Text(category.name)
                        .font(.system(size: 15, weight: isHidden ? .regular : .semibold))
                        .foregroundColor(isHidden ? .secondary : .white)

                    Spacer()

                    // Lock / PIN Protect Button
                    Button {
                        #if !os(tvOS)
                            HapticManager.shared.trigger(.light)
                        #endif
                        store.send(.toggleLock(categoryID: category.id))
                    } label: {
                        Image(systemName: isLocked ? "lock.fill" : "lock.open")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isLocked ? .orange : .secondary.opacity(0.7))
                            .padding(6)
                            .background(
                                (isLocked ? Color.orange : Color.white).opacity(0.12),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)

                    // Toggle Button
                    Button {
                        #if !os(tvOS)
                            HapticManager.shared.trigger(.light)
                        #endif
                        store.send(.toggleVisibility(categoryID: category.id))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 14))
                            Text(isHidden ? AppStrings.CategoryMgmt.filterHidden : AppStrings.CategoryMgmt.filterVisible)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(isHidden ? .red : .green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (isHidden ? Color.red : Color.green).opacity(0.12),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke((isHidden ? Color.red : Color.green).opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 2)
                #if os(tvOS)
                    .focused($focusedItemID, equals: category.id)
                    .scaleEffect(focusedItemID == category.id ? 1.03 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: focusedItemID)
                #endif
                    .listRowBackground(Color(hex: "#16161D"))
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
