#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Live TV Header Bar (iOS)

    /// Decomposed header bar for Live TV with Liquid Glass action container
    /// and strict adherence to AppColors and AppFonts tokens.
    struct LiveTVHeaderBar_iOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        let config: PlaylistConfig
        let onSearch: (() -> Void)?

        var body: some View {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(AppStrings.LiveTV.title)
                        .font(AppFonts.headline)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(2)

                    Spacer(minLength: 8)

                    LiquidGlassContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            if config.type == .m3u {
                                Button {
                                    store.send(store.isRefreshingContent ? .cancelContentRefresh : .refreshContentTapped)
                                } label: {
                                    if store.isRefreshingContent, store.refreshStage?.canCancel != true {
                                        ProgressView()
                                            .frame(width: 34, height: 34)
                                    } else {
                                        Image(systemName: store.isRefreshingContent ? "xmark" : "arrow.clockwise")
                                            .font(AppFonts.bodySmall)
                                            .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                                            .frame(width: 34, height: 34)
                                    }
                                }
                                .liquidGlass(shape: .circle, isInteractive: true)
                                .buttonStyle(.plain)
                                .disabled((store.isRefreshingContent && store.refreshStage?.canCancel != true) || store.isLoadingCategories || store.isChannelSelectionMode || store.isFavoriteListMode || store.selectedSmartGroupID != nil)
                                .accessibilityLabel(store.isRefreshingContent ? "Yenilemeyi iptal et" : "Canlı kanalları yenile")
                            }

                            Button {
                                store.send(store.isChannelSelectionMode ? .exitChannelSelectionMode : .enterChannelSelectionMode)
                            } label: {
                                Image(systemName: store.isChannelSelectionMode ? "xmark" : "checklist")
                                    .font(AppFonts.bodySmall)
                                    .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                                    .frame(width: 34, height: 34)
                            }
                            .liquidGlass(shape: .circle, isInteractive: true)
                            .buttonStyle(.plain)
                            .accessibilityLabel(store.isChannelSelectionMode ? AppStrings.LiveTV.cancelChannelSelection : AppStrings.LiveTV.selectChannels)

                            LiveTVChannelSortMenu(store: store)

                            Menu {
                                Button {
                                    store.send(.smartGroupManagerTapped)
                                } label: {
                                    Label(AppStrings.LiveTV.smartGroups, systemImage: "square.stack.3d.up")
                                }
                                .accessibilityHint(AppStrings.LiveTV.smartGroupPrivacyHint)

                                Button {
                                    HapticManager.shared.trigger(.light)
                                    store.send(.openMultiViewTapped)
                                } label: {
                                    Label(AppStrings.LiveTV.sendToMultiView, systemImage: "square.split.2x2.fill")
                                }

                                Button {
                                    HapticManager.shared.trigger(.light)
                                    store.send(.editCategoriesTapped)
                                } label: {
                                    Label(AppStrings.CategoryMgmt.manageTitle(for: AppStrings.LiveTV.categories), systemImage: "slider.horizontal.3")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(AppFonts.titleSmall)
                                    .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                                    .frame(width: 34, height: 34)
                            }
                            .liquidGlass(shape: .circle, isInteractive: true)
                            .buttonStyle(.plain)
                            .accessibilityLabel(AppStrings.Common.more)

                            if let onSearch {
                                Button(action: onSearch) {
                                    Image(systemName: "magnifyingglass")
                                        .font(AppFonts.titleSmall)
                                        .foregroundStyle(AppColors.textPrimary.opacity(0.9))
                                        .frame(width: 34, height: 34)
                                }
                                .liquidGlass(shape: .circle, isInteractive: true)
                                .buttonStyle(.plain)
                                .accessibilityLabel(AppStrings.Search.searchPlaceholder)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

                if let refreshStage = store.refreshStage {
                    Label(refreshStage.title, systemImage: "arrow.triangle.2.circlepath")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.85))
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let refreshMessage = store.refreshMessage {
                    Text(refreshMessage)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.destructive)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
#endif
