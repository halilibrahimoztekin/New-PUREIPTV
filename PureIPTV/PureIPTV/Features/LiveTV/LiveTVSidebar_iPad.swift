#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Live TV iPad Sidebar (Column 1)

    /// Sidebar column for iPad split view displaying category management,
    /// search, and category list with Liquid Glass elements and tokenized colors.
    struct LiveTVSidebar_iPad: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        let config: PlaylistConfig
        @Binding var categorySearchQuery: String

        private var filteredCategories: [MediaModels.Category] {
            let query = categorySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return store.categories }
            return store.categories.filter { $0.name.localizedStandardContains(query) }
        }

        var body: some View {
            VStack(spacing: 0) {
                headerView
                refreshFeedbackView
                FavoriteChannelListSwitcher(store: store)
                    .padding(.bottom, 6)
                searchFieldView
                categoryListView
            }
            .frame(width: 260)
            .background(AppColors.backgroundSubtle)
        }

        // MARK: - Header View

        private var headerView: some View {
            HStack(spacing: 8) {
                Text(AppStrings.LiveTV.categories)
                    .font(AppFonts.titleSmall.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                LiquidGlassContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        if config.type == .m3u {
                            Button {
                                store.send(store.isRefreshingContent ? .cancelContentRefresh : .refreshContentTapped)
                            } label: {
                                if store.isRefreshingContent, store.refreshStage?.canCancel != true {
                                    ProgressView()
                                        .frame(width: 28, height: 28)
                                } else {
                                    Image(systemName: store.isRefreshingContent ? "xmark" : "arrow.clockwise")
                                        .font(AppFonts.caption)
                                        .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                                        .frame(width: 28, height: 28)
                                }
                            }
                            .liquidGlass(shape: .circle, isInteractive: true)
                            .buttonStyle(.plain)
                            .disabled((store.isRefreshingContent && store.refreshStage?.canCancel != true) || store.isLoadingCategories || store.isChannelSelectionMode || store.isFavoriteListMode || store.selectedSmartGroupID != nil)
                            .accessibilityLabel(store.isRefreshingContent ? "Yenilemeyi iptal et" : "Canlı kanalları yenile")
                        }

                        Button {
                            store.send(.smartGroupManagerTapped)
                        } label: {
                            Image(systemName: "square.stack.3d.up")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                                .frame(width: 28, height: 28)
                        }
                        .liquidGlass(shape: .circle, isInteractive: true)
                        .buttonStyle(.plain)
                        .accessibilityLabel(AppStrings.LiveTV.smartGroups)
                        .accessibilityHint(AppStrings.LiveTV.smartGroupPrivacyHint)
                    }
                }

                Text("\(store.categories.count)")
                    .font(AppFonts.captionSmall.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.surfaceSecondary, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }

        // MARK: - Refresh Feedback

        @ViewBuilder
        private var refreshFeedbackView: some View {
            if let refreshStage = store.refreshStage {
                Label(refreshStage.title, systemImage: "arrow.triangle.2.circlepath")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.textSecondary.opacity(0.85))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
            if let refreshMessage = store.refreshMessage {
                Text(refreshMessage)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppColors.destructive)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
        }

        // MARK: - Search Field

        private var searchFieldView: some View {
            CategorySearchField(text: $categorySearchQuery)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }

        // MARK: - Category List

        private var categoryListView: some View {
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(filteredCategories) { category in
                        let isSelected = store.selectedCategoryID == category.id
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.categorySelected(category))
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isSelected ? "folder.fill" : "folder")
                                    .font(AppFonts.bodySmall)
                                    .foregroundStyle(isSelected ? AppColors.primary : AppColors.textSecondary.opacity(0.7))

                                Text(category.name)
                                    .font(isSelected ? AppFonts.bodySmall.weight(.bold) : AppFonts.bodySmall)
                                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.85))
                                    .lineLimit(1)

                                Spacer()

                                if let count = store.channelsByCategory[category.id]?.count {
                                    Text("\(count)")
                                        .font(AppFonts.captionSmall.monospacedDigit())
                                        .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.6))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            isSelected ? AppColors.primary.opacity(0.35) : AppColors.surfaceSecondary,
                                            in: Capsule()
                                        )
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                isSelected ? AppColors.primary.opacity(0.2) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }
#endif
