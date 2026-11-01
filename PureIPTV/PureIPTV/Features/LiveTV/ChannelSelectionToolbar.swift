import ComposableArchitecture
import SwiftUI

struct ChannelSelectionToolbar: View {
    let store: StoreOf<LiveTVFeature>

    private var isProcessingBulkAction: Bool {
        store.activeBulkFavoriteRequestID != nil
            || store.isDefaultFavoriteRequestInProgressForSelection
    }

    private var hasSelection: Bool {
        !store.selectedCurrentChannelIDs.isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            if isProcessingBulkAction {
                Label(AppStrings.Common.loading, systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote)
                    .accessibilityAddTraits(.updatesFrequently)
            } else if let notice = store.bulkFavoriteNotice {
                Text(notice)
                    .font(.footnote)
            }
            #if os(tvOS)
                ScrollView(.horizontal, showsIndicators: true) {
                    bulkActionButtons
                        .padding(.horizontal, 2)
                }
            #else
                compactPhoneToolbar
            #endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }

    private var selectedChannelCountLabel: some View {
        Text(AppStrings.LiveTV.selectedChannelCount(store.selectedCurrentChannelIDs.count))
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var bulkActionButtons: some View {
        HStack(spacing: 12) {
            selectedChannelCountLabel

            Button(AppStrings.LiveTV.selectAllChannels) {
                store.send(.selectAllCurrentChannels)
            }
            Button(AppStrings.LiveTV.clearChannelSelection) {
                store.send(.clearChannelSelection)
            }
            favoriteActionButtons

            if !store.favoriteLists.isEmpty {
                favoriteListMenus
            }

            Button(AppStrings.LiveTV.cancelChannelSelection) {
                store.send(.exitChannelSelectionMode)
            }
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var favoriteActionButtons: some View {
        Button {
            guard !isProcessingBulkAction, hasSelection else { return }
            store.send(.bulkFavoriteAction(targetListID: nil, operation: .add))
        } label: {
            HStack(spacing: 8) {
                Text(AppStrings.LiveTV.addSelectedToFavorites)
                if isProcessingBulkAction {
                    ProgressView().controlSize(.small)
                }
            }
        }
        #if os(tvOS)
        .disabled(!hasSelection)
        .opacity(hasSelection && !isProcessingBulkAction ? 1 : 0.55)
        #else
        .disabled(isProcessingBulkAction || !hasSelection)
        #endif
        .accessibilityValue(isProcessingBulkAction ? AppStrings.Common.loading : "")

        Button {
            guard !isProcessingBulkAction, hasSelection else { return }
            store.send(.bulkFavoriteAction(targetListID: nil, operation: .remove))
        } label: {
            HStack(spacing: 8) {
                Text(AppStrings.LiveTV.removeSelectedFromFavorites)
                if isProcessingBulkAction {
                    ProgressView().controlSize(.small)
                }
            }
        }
        #if os(tvOS)
        .disabled(!hasSelection)
        .opacity(hasSelection && !isProcessingBulkAction ? 1 : 0.55)
        #else
        .disabled(isProcessingBulkAction || !hasSelection)
        #endif
        .accessibilityValue(isProcessingBulkAction ? AppStrings.Common.loading : "")

        Button(role: .destructive) {
            guard !isProcessingBulkAction, hasSelection else { return }
            store.send(.requestHideSelectedChannelsConfirmation)
        } label: {
            HStack(spacing: 8) {
                Label(AppStrings.LiveTV.hideSelectedChannels, systemImage: "eye.slash")
                if isProcessingBulkAction {
                    ProgressView().controlSize(.small)
                }
            }
        }
        #if os(tvOS)
        .disabled(!hasSelection)
        .opacity(hasSelection && !isProcessingBulkAction ? 1 : 0.55)
        #else
        .disabled(isProcessingBulkAction || !hasSelection)
        #endif
        .accessibilityValue(isProcessingBulkAction ? AppStrings.Common.loading : "")
    }

    @ViewBuilder
    private var favoriteListMenus: some View {
        Menu {
            ForEach(store.favoriteLists) { list in
                Button(list.name) {
                    guard !isProcessingBulkAction, hasSelection else { return }
                    store.send(.bulkFavoriteAction(targetListID: list.id, operation: .add))
                }
                .disabled(isProcessingBulkAction || !hasSelection)
            }
        } label: {
            HStack(spacing: 8) {
                Text(AppStrings.LiveTV.addSelectedToList)
                if isProcessingBulkAction {
                    ProgressView().controlSize(.small)
                }
            }
        }
        #if os(tvOS)
        .disabled(!hasSelection)
        .opacity(hasSelection && !isProcessingBulkAction ? 1 : 0.55)
        #else
        .disabled(isProcessingBulkAction || !hasSelection)
        #endif
        .accessibilityValue(isProcessingBulkAction ? AppStrings.Common.loading : "")

        Menu {
            ForEach(store.favoriteLists) { list in
                Button(list.name) {
                    guard !isProcessingBulkAction, hasSelection else { return }
                    store.send(.bulkFavoriteAction(targetListID: list.id, operation: .remove))
                }
                .disabled(isProcessingBulkAction || !hasSelection)
            }
        } label: {
            HStack(spacing: 8) {
                Text(AppStrings.LiveTV.removeSelectedFromList)
                if isProcessingBulkAction {
                    ProgressView().controlSize(.small)
                }
            }
        }
        #if os(tvOS)
        .disabled(!hasSelection)
        .opacity(hasSelection && !isProcessingBulkAction ? 1 : 0.55)
        #else
        .disabled(isProcessingBulkAction || !hasSelection)
        #endif
        .accessibilityValue(isProcessingBulkAction ? AppStrings.Common.loading : "")
    }

    private var compactPhoneToolbar: some View {
        HStack(spacing: 10) {
            selectedChannelCountLabel
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                guard !isProcessingBulkAction, hasSelection else { return }
                store.send(.bulkFavoriteAction(targetListID: nil, operation: .add))
            } label: {
                Image(systemName: "heart.fill")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .disabled(isProcessingBulkAction || !hasSelection)
            .accessibilityLabel(AppStrings.LiveTV.addSelectedToFavorites)

            Button(role: .destructive) {
                guard !isProcessingBulkAction, hasSelection else { return }
                store.send(.requestHideSelectedChannelsConfirmation)
            } label: {
                Image(systemName: "eye.slash")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .disabled(isProcessingBulkAction || !hasSelection)
            .accessibilityLabel(AppStrings.LiveTV.hideSelectedChannels)

            Menu {
                Button(AppStrings.LiveTV.selectAllChannels) {
                    store.send(.selectAllCurrentChannels)
                }
                Button(AppStrings.LiveTV.clearChannelSelection) {
                    store.send(.clearChannelSelection)
                }
                Button(AppStrings.LiveTV.removeSelectedFromFavorites) {
                    guard !isProcessingBulkAction, hasSelection else { return }
                    store.send(.bulkFavoriteAction(targetListID: nil, operation: .remove))
                }
                .disabled(isProcessingBulkAction || !hasSelection)

                if !store.favoriteLists.isEmpty {
                    Section(AppStrings.LiveTV.addSelectedToList) {
                        ForEach(store.favoriteLists) { list in
                            Button(list.name) {
                                guard !isProcessingBulkAction, hasSelection else { return }
                                store.send(.bulkFavoriteAction(targetListID: list.id, operation: .add))
                            }
                            .disabled(isProcessingBulkAction || !hasSelection)
                        }
                    }
                    Section(AppStrings.LiveTV.removeSelectedFromList) {
                        ForEach(store.favoriteLists) { list in
                            Button(list.name) {
                                guard !isProcessingBulkAction, hasSelection else { return }
                                store.send(.bulkFavoriteAction(targetListID: list.id, operation: .remove))
                            }
                            .disabled(isProcessingBulkAction || !hasSelection)
                        }
                    }
                }

                Button(AppStrings.LiveTV.cancelChannelSelection) {
                    store.send(.exitChannelSelectionMode)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(AppStrings.Common.more)
        }
        .padding(.horizontal, 2)
    }
}

struct LiveTVChannelSortMenu: View {
    let store: StoreOf<LiveTVFeature>

    var body: some View {
        if !store.isFavoriteListMode,
           store.selectedSmartGroupID == nil,
           store.selectedCategoryID != nil,
           !store.isChannelSelectionMode
        {
            Menu {
                Section(AppStrings.LiveTV.sortTitle) {
                    ForEach(LiveTVChannelSortOption.allCases) { option in
                        Button {
                            store.send(.setChannelSortOption(option))
                        } label: {
                            HStack {
                                Label(option.title, systemImage: option.icon)
                                if store.channelSortOption == option {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                Group {
                    if store.isLoadingChannelSortEPG {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: store.channelSortOption.icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.08), in: Circle())
            }
            .accessibilityLabel(AppStrings.LiveTV.sortTitle)
            .accessibilityValue(store.isLoadingChannelSortEPG
                ? AppStrings.LiveTV.sortPreparingEPG
                : store.channelSortOption.title)
        }
    }
}
