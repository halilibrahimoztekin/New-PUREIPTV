import ComposableArchitecture
import FactoryKit
import Foundation

private let smartGroupResolutionCancellationID = "LiveTVFeature.smartGroupResolution"
private let favoriteListResolutionCancellationID = "LiveTVFeature.favoriteListResolution"
private let favoriteOrderLoadCancellationID = "LiveTVFeature.favoriteOrderLoad"

private func nextLiveFavoriteOrderRevision(after current: UInt64) -> UInt64 {
    let timeRevision = UInt64(max(0, Date().timeIntervalSince1970 * 1_000_000))
    return max(current &+ 1, timeRevision)
}

public struct PendingNamedFavoriteBulk: Equatable, Sendable {
    public var id: UUID
    public var playlistID: UUID
    public var profileScope: ProfileContextSnapshot
    public var listID: UUID
    public var operation: BulkFavoriteOperation
    public var channelIDs: Set<String>
    public var updatedLists: [NamedFavoriteChannelList]
    public var revision: UInt64
    public var selectionGenerationID: UUID

    public init(id: UUID, playlistID: UUID, profileScope: ProfileContextSnapshot, listID: UUID,
                operation: BulkFavoriteOperation, channelIDs: Set<String>,
                updatedLists: [NamedFavoriteChannelList], revision: UInt64,
                selectionGenerationID: UUID)
    {
        self.id = id
        self.playlistID = playlistID
        self.profileScope = profileScope
        self.listID = listID
        self.operation = operation
        self.channelIDs = channelIDs
        self.updatedLists = updatedLists
        self.revision = revision
        self.selectionGenerationID = selectionGenerationID
    }
}

public struct UnavailableFavoriteChannel: Identifiable, Equatable, Sendable {
    public let channelID: String
    public let title: String
    public let coverURL: URL?
    public let playlistID: UUID
    public let profileID: UUID?
    public let streamURL: String?
    public let replacement: MediaModels.Item?

    public var id: String {
        let components = [profileID?.uuidString ?? "legacy", playlistID.uuidString, channelID]
        return "unavailable-favorite-v1|" + components.map { "\($0.utf8.count):\($0)" }.joined()
    }

    public var item: MediaModels.Item {
        MediaModels.Item(
            id: channelID,
            title: title,
            streamURL: nil,
            coverURL: coverURL,
            categoryID: "unavailable",
            type: .live
        )
    }

    public init(
        channelID: String,
        title: String,
        coverURL: URL?,
        playlistID: UUID,
        profileID: UUID?,
        streamURL: String? = nil,
        replacement: MediaModels.Item? = nil
    ) {
        self.channelID = channelID
        self.title = title
        self.coverURL = coverURL
        self.playlistID = playlistID
        self.profileID = profileID
        self.streamURL = streamURL
        self.replacement = replacement
    }
}

private func persistFavoriteLists(
    state: inout LiveTVFeature.State,
    client: FavoriteChannelListsClient,
    profileID: UUID,
    playlistID: UUID
) -> Effect<LiveTVFeature.Action> {
    state.favoriteListPersistenceRevision &+= 1
    let snapshot = FavoriteChannelListsSnapshot(
        lists: state.favoriteLists,
        revision: state.favoriteListPersistenceRevision
    )
    return .run { _ in
        _ = await client.save(snapshot, profileID, playlistID)
    }
}

// MARK: - LiveTVFeature

@Reducer
public struct LiveTVFeature {
    @ObservableState
    public struct State: Equatable {
        // Data
        public var categories: [MediaModels.Category] = []
        public var channelsByCategory: [String: [MediaModels.Item]] = [:]

        /// Server Info
        public var config: PlaylistConfig?

        // UI state
        public var selectedCategoryID: String?
        public var selectedChannel: MediaModels.Item?
        public var isLoadingCategories = false
        public var isLoadingChannels = false
        public var categoryContentRequestIDs: [String: UUID] = [:]
        public var categoryContentErrors: [String: String] = [:]
        public var isRefreshingContent = false
        public var activeContentRefreshID: UUID?
        public var refreshStage: M3URefreshStage?
        public var activeCategoryRequestID: UUID?
        public var refreshMessage: String?
        public var errorMessage: String?
        public var favoriteIDs: Set<String> = []
        public var hiddenChannelIDs: Set<String> = []
        public var categoryPreferences: [String: CategoryPreferenceDTO] = [:]
        public var unlockedCategoryIDs: Set<String> = []
        public var categoryUnlockRequestIDs: [String: UUID] = [:]
        public var categoryUnlockProfileScope: ProfileContextSnapshot?
        public var categoryUnlockPlaylistID: UUID?
        public var blacklistedCategoryIDs: Set<String> = []
        public var adultCategoryIDs: Set<String> = []
        public var parentalControlEnabled = false
        public var hideAdultContent = false
        public var smartChannelGroups: [SmartChannelGroup] = []
        public var smartGroupPlaylistID: UUID?
        public var smartGroupProfileScope: ProfileContextSnapshot?
        public var selectedSmartGroupID: String?
        public var smartGroupChannels: [MediaModels.Item] = []
        public var activeSmartGroupRequestID: UUID?
        public var activeSmartGroupLoadID: UUID?
        public var smartGroupPersistenceRevision: UInt64 = 0
        public var isLoadingSmartGroups = false
        public var favoriteLists: [NamedFavoriteChannelList] = []
        public var favoriteListPlaylistID: UUID?
        public var favoriteListProfileScope: ProfileContextSnapshot?
        public var favoriteListPersistenceRevision: UInt64 = 0
        public var favoriteListLoadRequestID: UUID?
        public var favoriteListPendingMutations: [FavoriteChannelListPendingMutation] = []
        public var isChannelSelectionMode = false
        public var selectedChannelIDs: Set<String> = []
        public var channelSelectionGenerationID: UUID?
        public var channelSelectionPlaylistID: UUID?
        public var channelSelectionProfileScope: ProfileContextSnapshot?
        public var activeBulkFavoriteRequestID: UUID?
        public var activeDefaultFavoriteRequestID: UUID?
        public var activeDefaultFavoritePlaylistID: UUID?
        public var activeDefaultFavoriteProfileScope: ProfileContextSnapshot?
        public var activeDefaultFavoriteSelectionGenerationID: UUID?
        public var pendingNamedFavoriteBulk: PendingNamedFavoriteBulk?
        public var bulkFavoriteNotice: String?
        public var activeFavoriteListRequestID: UUID?
        public var selectedFavoriteListID: UUID?
        public var isFavoriteListMode = false
        public var favoriteListResolvedChannels: [MediaModels.Item] = []
        public var favoriteSortMode: FavoriteChannelSortMode = .defaultOrder
        public var favoriteOrderIDs: [String] = []
        public var favoriteOrderRevision: UInt64 = 0
        public var favoriteOrderRequestID: UUID?
        public var unavailableFavoriteChannels: [UnavailableFavoriteChannel] = []
        public var favoriteRecoveryRequestIDs: [String: UUID] = [:]
        public var channelPresentationOverrides: [String: ChannelPresentationOverride] = [:]
        public var channelPresentationPlaylistID: UUID?
        public var channelPresentationProfileScope: ProfileContextSnapshot?
        public var channelPresentationLoadID: UUID?

        public var unavailableFavoriteChannelIDs: Set<String> {
            Set(unavailableFavoriteChannels.map(\.channelID))
        }

        public var selectedFavoriteListName: String {
            guard isFavoriteListMode else { return "" }
            guard let selectedFavoriteListID else { return AppStrings.Common.favorites }
            return favoriteLists.first(where: { $0.id == selectedFavoriteListID })?.name ?? AppStrings.Common.favorites
        }

        public var selectedFavoriteListChannelIDs: Set<String> {
            guard isFavoriteListMode else { return [] }
            guard let selectedFavoriteListID else { return favoriteIDs }
            return Set(favoriteLists.first(where: { $0.id == selectedFavoriteListID })?.channelIDs ?? [String]())
        }

        public var orderedFavoriteListChannels: [MediaModels.Item] {
            FavoriteChannelSortMode.orderedItems(
                favoriteListResolvedChannels,
                mode: favoriteSortMode,
                providerOrder: favoriteListResolvedChannels,
                manualIDs: favoriteOrderIDs
            )
        }

        public var selectedCurrentChannelIDs: Set<String> {
            let selectableChannels = isFavoriteListMode ? favoriteListResolvedChannels : currentChannels
            let visibleIDs = Set(selectableChannels.map(\.id))
            return selectedChannelIDs.intersection(visibleIDs)
        }

        public var isDefaultFavoriteRequestInProgressForSelection: Bool {
            guard let playlistID = channelSelectionPlaylistID,
                  activeDefaultFavoritePlaylistID == playlistID,
                  activeDefaultFavoriteProfileScope == channelSelectionProfileScope,
                  activeDefaultFavoriteRequestID != nil else { return false }
            return true
        }

        public var isNamedFavoriteRequestInProgressForSelection: Bool {
            guard let pending = pendingNamedFavoriteBulk,
                  pending.playlistID == channelSelectionPlaylistID,
                  pending.profileScope == channelSelectionProfileScope else { return false }
            return true
        }

        public mutating func resetChannelSelection() {
            isChannelSelectionMode = false
            selectedChannelIDs = []
            channelSelectionPlaylistID = nil
            channelSelectionProfileScope = nil
            channelSelectionGenerationID = nil
            favoriteListPendingMutations.removeAll { mutation in
                if case .bulk = mutation {
                    return true
                }
                return false
            }
            bulkFavoriteNotice = nil
            activeBulkFavoriteRequestID = nil
        }

        public var smartGroupSelectableCategories: [MediaModels.Category] {
            categories.filter { category in
                !blacklistedCategoryIDs.contains(category.id)
                    && (!hideAdultContent || !adultCategoryIDs.contains(category.id))
                    && (!(parentalControlEnabled && adultCategoryIDs.contains(category.id)) || unlockedCategoryIDs.contains(category.id))
                    && (!(categoryPreferences[category.id]?.isLocked ?? false) || unlockedCategoryIDs.contains(category.id))
            }
        }

        public var selectedChannelEPG: [EPGProgram] = []
        public var isLoadingChannelEPG: Bool = false

        public enum TabMode: String, CaseIterable, Equatable, Sendable {
            case channels = "Kanallar"
            case epg = "Yayın Akışı (EPG)"
        }

        public var selectedTabMode: TabMode = .channels

        @Presents public var categoryManagement: CategoryManagementFeature.State?
        @Presents public var epgGuide: EPGGuideFeature.State?
        @Presents public var epgTimeline: EPGTimelineFeature.State?
        @Presents public var parentalLock: ParentalLockFeature.State?
        @Presents public var multiView: MultiViewFeature.State?

        // Computed: channels for the currently selected category
        public var currentChannels: [MediaModels.Item] {
            if isFavoriteListMode {
                return orderedFavoriteListChannels.filter { !hiddenChannelIDs.contains($0.id) }
            }
            if selectedSmartGroupID != nil {
                return smartGroupChannels.filter {
                    !hiddenChannelIDs.contains($0.id)
                        && !blacklistedCategoryIDs.contains($0.categoryID)
                }
            }
            guard let id = selectedCategoryID else { return [] }
            let all = channelsByCategory[id] ?? []
            return all.filter {
                !hiddenChannelIDs.contains($0.id)
                    && !blacklistedCategoryIDs.contains($0.categoryID)
            }
        }

        public var displayChannels: [MediaModels.Item] {
            guard isFavoriteListMode else { return currentChannels }
            return currentChannels + unavailableFavoriteChannels.map(\.item)
        }

        mutating func syncEPGTimeline(
            channels: [MediaModels.Item],
            selectedCategoryID: String?,
            providerOrderChannels: [MediaModels.Item]? = nil
        ) {
            guard var timeline = epgTimeline else { return }
            timeline.channels = channels
            timeline.providerOrderChannels = providerOrderChannels ?? channels
            timeline.selectedCategoryID = selectedCategoryID
            epgTimeline = timeline
        }

        mutating func applyResolvedSmartGroupChannels(_ channels: [MediaModels.Item]) {
            let allowedCategoryIDs = Set(smartGroupSelectableCategories.map(\.id))
            var visibleChannels: [MediaModels.Item] = []
            visibleChannels.reserveCapacity(channels.count)
            for channel in channels {
                guard allowedCategoryIDs.contains(channel.categoryID),
                      !hiddenChannelIDs.contains(channel.id),
                      !blacklistedCategoryIDs.contains(channel.categoryID) else { continue }
                visibleChannels.append(channel)
            }

            smartGroupChannels = visibleChannels
            var resolvedByCategory: [String: [MediaModels.Item]] = [:]
            for channel in visibleChannels {
                resolvedByCategory[channel.categoryID, default: []].append(channel)
            }
            for (categoryID, categoryChannels) in resolvedByCategory {
                channelsByCategory[categoryID] = categoryChannels
            }

            syncEPGTimeline(channels: visibleChannels, selectedCategoryID: nil)
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case onDisappear
        case categoriesResponse(Result<[MediaModels.Category], Error>, preferences: [String: CategoryPreferenceDTO] = [:], requestID: UUID)
        case categorySelected(MediaModels.Category)
        case categoryUnlockExpired(categoryID: String, requestID: UUID)
        case smartGroupSelected(String)
        case smartGroupsLoaded(SmartChannelGroupSnapshot, playlistID: UUID?, profileScope: ProfileContextSnapshot, requestID: UUID)
        case smartGroupChannelsLoaded(groupID: String, playlistID: UUID?, profileScope: ProfileContextSnapshot, hideAdult: Bool, requestID: UUID, Result<[MediaModels.Item], Error>)
        case saveSmartChannelGroup(id: String?, name: String, categoryIDs: [String])
        case deleteSmartChannelGroup(String)
        case favoriteListsLoaded(FavoriteChannelListsSnapshot, playlistID: UUID?, profileScope: ProfileContextSnapshot, requestID: UUID)
        case favoriteListSelected(UUID?)
        case clearFavoriteListSelection
        case favoriteListChannelsLoaded(listID: UUID?, playlistID: UUID?, profileScope: ProfileContextSnapshot, requestID: UUID, membershipIDs: Set<String>, unavailableFavorites: [UnavailableFavoriteChannel]?, Result<[MediaModels.Item], Error>)
        case favoriteOrderLoaded(FavoriteChannelOrderSnapshot, listID: UUID?, playlistID: UUID?, profileScope: ProfileContextSnapshot, requestID: UUID)
        case setFavoriteSortMode(FavoriteChannelSortMode)
        case moveFavoriteChannel(channelID: String, offset: Int)
        case saveNamedFavoriteList(id: UUID?, name: String)
        case deleteNamedFavoriteList(UUID)
        case moveNamedFavoriteList(id: UUID, offset: Int)
        case toggleNamedFavorite(MediaModels.Item, listID: UUID)
        case enterChannelSelectionMode
        case toggleChannelSelection(MediaModels.Item)
        case selectAllCurrentChannels
        case clearChannelSelection
        case exitChannelSelectionMode
        case hideSelectedChannels
        case dismissBulkFavoriteNotice
        case bulkFavoriteAction(targetListID: UUID?, operation: BulkFavoriteOperation)
        case applyBulkNamedFavoriteList(channelIDs: Set<String>, listID: UUID, operation: BulkFavoriteOperation, playlistID: UUID, profileScope: ProfileContextSnapshot, generationID: UUID)
        case namedFavoriteBulkSaveCompleted(requestID: UUID, playlistID: UUID, profileScope: ProfileContextSnapshot, didSave: Bool)
        case bulkFavoriteCompleted(requestID: UUID, targetListID: UUID?, operation: BulkFavoriteOperation, playlistID: UUID, profileScope: ProfileContextSnapshot, selectionGenerationID: UUID, channelIDs: Set<String>, Result<Bool, Error>)
        case fetchCategoryContent(requestID: UUID, config: PlaylistConfig, categoryID: String)
        case retryCategoryContent(categoryID: String)
        case channelsResponse(requestID: UUID, config: PlaylistConfig, categoryID: String, Result<[MediaModels.Item], Error>)
        case channelPresentationOverridesLoaded([String: ChannelPresentationOverride], playlistID: UUID, profileScope: ProfileContextSnapshot, requestID: UUID)
        case saveChannelPresentationOverride(channelID: String, name: String, number: Int?, playlistID: UUID, profileScope: ProfileContextSnapshot)
        case channelSelected(MediaModels.Item)
        case selectChannelPreview(MediaModels.Item)
        case channelEPGResponse(Result<[EPGProgram], Error>)
        case toggleFavorite(MediaModels.Item)
        case recoverUnavailableFavorite(channelID: String, replacement: MediaModels.Item)
        case unavailableFavoriteRecoveryCompleted(
            channelID: String,
            replacement: MediaModels.Item,
            playlistID: UUID,
            profileScope: ProfileContextSnapshot,
            requestID: UUID,
            succeeded: Bool
        )
        case favoritesLoaded(Set<String>, playlistID: UUID?, ProfileContextSnapshot)
        case hideChannel(MediaModels.Item)
        case unhideAllChannels
        case sendToMultiView(MediaModels.Item)
        case openChannelEPG(MediaModels.Item)
        case openChannelGuide(MediaModels.Item)
        case dismissError
        case reloadCategories(config: PlaylistConfig)
        case refreshContentTapped
        case cancelContentRefresh
        case cancelRefreshForBackground
        case contentRefreshProgress(requestID: UUID, stage: M3URefreshStage)
        case contentRefreshSucceeded(requestID: UUID, config: PlaylistConfig)
        case contentRefreshFailed(requestID: UUID, config: PlaylistConfig, message: String)
        case reloadPreferences
        case editCategoriesTapped
        case epgGuideTapped
        case categoryManagement(PresentationAction<CategoryManagementFeature.Action>)
        case epgGuide(PresentationAction<EPGGuideFeature.Action>)
        case epgTimeline(PresentationAction<EPGTimelineFeature.Action>)
        case parentalLock(PresentationAction<ParentalLockFeature.Action>)
        case multiView(PresentationAction<MultiViewFeature.Action>)
        case openMultiViewTapped
        case openEPGTimelineTapped
        case setTabMode(State.TabMode)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item, playlist: [MediaModels.Item]?)
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.hapticClient) var hapticClient
    @Dependency(\.parentalControlClient) var parentalControlClient
    @Dependency(\.smartChannelGroupClient) var smartChannelGroupClient
    @Dependency(\.favoriteChannelListsClient) var favoriteChannelListsClient
    @Dependency(\.favoriteChannelOrderClient) var favoriteChannelOrderClient
    @Dependency(\.channelPresentationOverrideClient) var channelPresentationOverrideClient
    @Dependency(\.previewPlayerClient) var previewPlayerClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let parentalControlClient = parentalControlClient
        let smartChannelGroupClient = smartChannelGroupClient
        let favoriteChannelListsClient = favoriteChannelListsClient
        let channelPresentationOverrideClient = channelPresentationOverrideClient
        let databaseClient = databaseClient

        let profileContextClient = profileContextClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                let configChanged = state.config != config
                let playlistChanged = state.config?.playlistID != config.playlistID
                let profileScope = profileContextClient.snapshot()
                let categoryAccessScopeChanged = state.categoryUnlockPlaylistID != config.playlistID
                    || state.categoryUnlockProfileScope != profileScope
                if categoryAccessScopeChanged {
                    state.unlockedCategoryIDs = []
                    state.categoryUnlockRequestIDs = [:]
                    state.selectedCategoryID = nil
                    state.selectedChannel = nil
                    state.selectedSmartGroupID = nil
                    state.smartGroupChannels = []
                    if var timeline = state.epgTimeline {
                        timeline.channels = []
                        timeline.providerOrderChannels = []
                        timeline.selectedCategoryID = nil
                        state.epgTimeline = timeline
                    }
                }
                state.categoryUnlockPlaylistID = config.playlistID
                state.categoryUnlockProfileScope = profileScope
                if configChanged {
                    state.categoryContentRequestIDs = [:]
                    state.categoryContentErrors = [:]
                    state.isLoadingChannels = false
                }
                state.config = config
                let presentationScopeChanged = state.channelPresentationPlaylistID != config.playlistID
                    || state.channelPresentationProfileScope != profileScope
                if presentationScopeChanged {
                    state.channelPresentationOverrides = [:]
                    state.channelPresentationPlaylistID = config.playlistID
                    state.channelPresentationProfileScope = profileScope
                }
                let presentationLoadID = UUID()
                state.channelPresentationLoadID = presentationLoadID
                let presentationOverridesLoad: Effect<Action>
                if let playlistID = config.playlistID {
                    presentationOverridesLoad = .run { send in
                        let values = await channelPresentationOverrideClient.load(profileScope.profileID, playlistID)
                        await send(.channelPresentationOverridesLoaded(values, playlistID: playlistID, profileScope: profileScope, requestID: presentationLoadID))
                    }
                } else {
                    state.channelPresentationLoadID = nil
                    presentationOverridesLoad = .none
                }
                if playlistChanged {
                    state.resetChannelSelection()
                    state.unavailableFavoriteChannels = []
                    state.categories = []
                    state.channelsByCategory = [:]
                    state.selectedCategoryID = nil
                    state.selectedChannel = nil
                }
                if state.channelSelectionPlaylistID != config.playlistID
                    || state.channelSelectionProfileScope != profileScope
                {
                    state.resetChannelSelection()
                }
                if state.activeDefaultFavoritePlaylistID != config.playlistID
                    || state.activeDefaultFavoriteProfileScope != profileScope
                {
                    state.activeDefaultFavoriteRequestID = nil
                    state.activeDefaultFavoritePlaylistID = nil
                    state.activeDefaultFavoriteProfileScope = nil
                    state.activeDefaultFavoriteSelectionGenerationID = nil
                }
                state.hiddenChannelIDs = parentalControlClient.hiddenChannelIDs()
                state.blacklistedCategoryIDs = parentalControlClient.blacklistedCategoryIDs()
                state.parentalControlEnabled = settingsClient.isParentalControlEnabled()
                state.hideAdultContent = settingsClient.hideAdultContent()
                let selectedGroupToRefresh = state.selectedSmartGroupID
                let scopeChanged = state.smartGroupPlaylistID != config.playlistID
                    || state.smartGroupProfileScope != profileScope
                if scopeChanged {
                    state.smartChannelGroups = []
                    state.selectedSmartGroupID = nil
                    state.smartGroupChannels = []
                    state.activeSmartGroupRequestID = nil
                    state.isLoadingChannels = false
                    state.selectedChannel = nil
                    state.smartGroupPlaylistID = config.playlistID
                    state.smartGroupProfileScope = profileScope
                    if !playlistChanged {
                        state.selectedCategoryID = nil
                        state.channelsByCategory = [:]
                    }
                }
                let favoriteListScopeChanged = state.favoriteListPlaylistID != config.playlistID
                    || state.favoriteListProfileScope != profileScope
                let cancelPreviousFavoriteListResolution: Effect<Action> = favoriteListScopeChanged
                    ? .cancel(id: favoriteListResolutionCancellationID)
                    : .none
                if favoriteListScopeChanged {
                    state.pendingNamedFavoriteBulk = nil
                    state.favoriteLists = []
                    state.favoriteListResolvedChannels = []
                    state.unavailableFavoriteChannels = []
                    state.favoriteListPendingMutations = []
                    state.selectedFavoriteListID = nil
                    state.isFavoriteListMode = false
                    state.activeFavoriteListRequestID = nil
                    state.favoriteListPlaylistID = config.playlistID
                    state.favoriteListProfileScope = profileScope
                }
                let groupLoadID = UUID()
                state.activeSmartGroupLoadID = groupLoadID
                state.isLoadingSmartGroups = true
                let cancelPreviousGroupResolution: Effect<Action> = scopeChanged
                    ? .cancel(id: smartGroupResolutionCancellationID)
                    : .none
                let groupLoadEffect: Effect<Action> = if let profileID = profileScope.profileID, let playlistID = config.playlistID {
                    .run { send in
                        let snapshot = await smartChannelGroupClient.load(profileID, playlistID)
                        await send(.smartGroupsLoaded(snapshot, playlistID: config.playlistID, profileScope: profileScope, requestID: groupLoadID))
                    }
                } else {
                    .send(.smartGroupsLoaded(SmartChannelGroupSnapshot(groups: [], revision: 0), playlistID: config.playlistID, profileScope: profileScope, requestID: groupLoadID))
                }

                let favoriteListLoadID = UUID()
                state.favoriteListLoadRequestID = favoriteListLoadID
                let favoriteListsEffect: Effect<Action> = if let profileID = profileScope.profileID, let playlistID = config.playlistID {
                    .run { send in
                        let snapshot = await favoriteChannelListsClient.load(profileID, playlistID)
                        await send(.favoriteListsLoaded(snapshot, playlistID: config.playlistID,
                                                        profileScope: profileScope, requestID: favoriteListLoadID))
                    }
                } else {
                    .send(.favoriteListsLoaded(FavoriteChannelListsSnapshot(), playlistID: config.playlistID,
                                               profileScope: profileScope, requestID: favoriteListLoadID))
                }

                let loadFavorites: Effect<Action> = .run { send in
                    let favs = await (try? databaseClient.fetchFavoritesByType("live", profileScope)) ?? []
                    let visible = favs.filter { $0.playlistID == config.playlistID && config.playlistID != nil }
                    await send(.favoritesLoaded(Set(visible.map(\.id)), playlistID: config.playlistID, profileScope))
                }

                let refreshSelectedGroup: Effect<Action>
                if !scopeChanged, !state.categories.isEmpty, let selectedGroupToRefresh {
                    // Policy inputs can change while LiveTV is off-screen. Clear the old
                    // result synchronously so it cannot be rendered under the new policy.
                    state.smartGroupChannels = []
                    state.selectedChannel = nil
                    refreshSelectedGroup = .send(.smartGroupSelected(selectedGroupToRefresh))
                } else {
                    refreshSelectedGroup = .none
                }
                let refreshSelectedFavoriteList: Effect<Action>
                if !favoriteListScopeChanged, state.isFavoriteListMode {
                    state.favoriteListResolvedChannels = []
                    state.activeFavoriteListRequestID = nil
                    state.isLoadingChannels = false
                    refreshSelectedFavoriteList = .send(.favoriteListSelected(state.selectedFavoriteListID))
                } else {
                    refreshSelectedFavoriteList = .none
                }

                guard !state.isLoadingCategories else { return .merge(loadFavorites, groupLoadEffect, favoriteListsEffect, presentationOverridesLoad, cancelPreviousGroupResolution, cancelPreviousFavoriteListResolution, refreshSelectedGroup, refreshSelectedFavoriteList) }
                guard state.categories.isEmpty else { return .merge(loadFavorites, groupLoadEffect, favoriteListsEffect, presentationOverridesLoad, cancelPreviousGroupResolution, cancelPreviousFavoriteListResolution, refreshSelectedGroup, refreshSelectedFavoriteList) } // Prevent re-fetching on view re-appear

                return .merge(loadFavorites, groupLoadEffect, favoriteListsEffect, presentationOverridesLoad, cancelPreviousGroupResolution, cancelPreviousFavoriteListResolution, refreshSelectedGroup, refreshSelectedFavoriteList, .send(.reloadCategories(config: config)))

            case let .channelPresentationOverridesLoaded(values, playlistID, profileScope, requestID):
                guard state.config?.playlistID == playlistID,
                      state.channelPresentationPlaylistID == playlistID,
                      state.channelPresentationLoadID == requestID,
                      state.channelPresentationProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope else { return .none }
                state.channelPresentationLoadID = nil
                state.channelPresentationOverrides = values
                return .none

            case let .saveChannelPresentationOverride(channelID, name, number, playlistID, profileScope):
                guard state.config?.playlistID == playlistID,
                      state.channelPresentationPlaylistID == playlistID,
                      state.channelPresentationProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope else { return .none }
                state.channelPresentationLoadID = nil
                let value = ChannelPresentationOverride(name: name, number: number)
                if value.name == nil, value.number == nil {
                    state.channelPresentationOverrides.removeValue(forKey: channelID)
                } else {
                    state.channelPresentationOverrides[channelID] = value
                }
                return .run { _ in
                    await channelPresentationOverrideClient.save(value, channelID, profileScope.profileID, playlistID)
                }

            case .onDisappear:
                state.isRefreshingContent = false
                state.activeContentRefreshID = nil
                state.refreshStage = nil
                state.activeCategoryRequestID = nil
                state.categoryContentRequestIDs = [:]
                state.activeSmartGroupRequestID = nil
                state.isLoadingChannels = false
                state.activeFavoriteListRequestID = nil
                state.favoriteOrderRequestID = nil
                state.resetChannelSelection()
                return .merge(
                    .cancel(id: smartGroupResolutionCancellationID),
                    .cancel(id: favoriteListResolutionCancellationID),
                    .cancel(id: favoriteOrderLoadCancellationID),
                    .cancel(id: "LiveTVFeature.refreshContent")
                )

            case let .reloadCategories(config):
                let requestID = UUID()
                state.activeCategoryRequestID = requestID
                state.isLoadingCategories = state.categories.isEmpty
                state.errorMessage = nil

                state.config = config
                let existingPreferences = state.categoryPreferences
                let hideAdult = settingsClient.hideAdultContent()
                let isAdultContent = settingsClient.isAdultContent

                return .run { send in
                    async let categoriesResult = Result { try await iptvClient.fetchLiveCategories(config) }
                    async let prefsResult = Result { try await databaseClient.fetchCategoryPreferences(CategoryManagementFeature.State.CategoryType.live.rawValue) }

                    let categories = try await categoriesResult.get()
                    // Keep the currently applied policy if persistence is
                    // temporarily unavailable; an empty fallback would make
                    // hidden and reordered categories appear to reset.
                    let prefs = await (try? prefsResult.get()) ?? Array(existingPreferences.values)

                    var dict: [String: CategoryPreferenceDTO] = [:]
                    for pref in prefs {
                        dict[pref.categoryID] = pref
                    }

                    // Filter and sort

                    let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                    let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]

                    var finalCategories = categories.enumerated().filter { _, category in
                        if hideAdult, isAdultContent(category.name) {
                            return false
                        }

                        if dict[category.id]?.isHidden ?? false {
                            return false
                        }

                        if isKidsMode {
                            let nameLower = category.name.lowercased()
                            return kidsKeywords.contains { nameLower.contains($0) }
                        }

                        return true
                    }
                    finalCategories.sort { lhs, rhs in
                        let orderA = dict[lhs.element.id]?.orderIndex
                        let orderB = dict[rhs.element.id]?.orderIndex
                        switch (orderA, orderB) {
                        case let (a?, b?) where a != b: return a < b
                        case (_?, nil): return true
                        case (nil, _?): return false
                        default: return lhs.offset < rhs.offset
                        }
                    }

                    await send(.categoriesResponse(.success(finalCategories.map(\.element)), preferences: dict, requestID: requestID))
                } catch: { error, send in
                    await send(.categoriesResponse(.failure(error), preferences: [:], requestID: requestID))
                }

            case .reloadPreferences:
                let requestID = UUID()
                state.activeCategoryRequestID = requestID
                let currentCats = state.categories
                let hideAdult = settingsClient.hideAdultContent()
                let isAdultContent = settingsClient.isAdultContent
                return .run { send in
                    let prefs: [CategoryPreferenceDTO]
                    do {
                        prefs = try await databaseClient.fetchCategoryPreferences(CategoryManagementFeature.State.CategoryType.live.rawValue)
                    } catch {
                        return
                    }
                    var dict: [String: CategoryPreferenceDTO] = [:]
                    for pref in prefs {
                        dict[pref.categoryID] = pref
                    }

                    let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                    let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]

                    var finalCategories = currentCats.enumerated().filter { _, category in
                        if hideAdult, isAdultContent(category.name) {
                            return false
                        }

                        if dict[category.id]?.isHidden ?? false {
                            return false
                        }

                        if isKidsMode {
                            let nameLower = category.name.lowercased()
                            return kidsKeywords.contains { nameLower.contains($0) }
                        }

                        return true
                    }
                    finalCategories.sort { lhs, rhs in
                        let orderA = dict[lhs.element.id]?.orderIndex
                        let orderB = dict[rhs.element.id]?.orderIndex
                        switch (orderA, orderB) {
                        case let (a?, b?) where a != b: return a < b
                        case (_?, nil): return true
                        case (nil, _?): return false
                        default: return lhs.offset < rhs.offset
                        }
                    }

                    await send(.categoriesResponse(.success(finalCategories.map(\.element)), preferences: dict, requestID: requestID))
                }

            case .refreshContentTapped:
                guard !state.isRefreshingContent,
                      !state.isLoadingCategories,
                      !state.isFavoriteListMode,
                      state.selectedSmartGroupID == nil,
                      state.selectedCategoryID != nil,
                      let config = state.config,
                      config.type == .m3u
                else { return .none }
                let requestID = UUID()
                state.activeContentRefreshID = requestID
                state.isRefreshingContent = true
                state.refreshStage = .downloading
                state.refreshMessage = nil
                return .run { send in
                    do {
                        try await iptvClient.refreshContent(config, .live) { stage in
                            await send(.contentRefreshProgress(requestID: requestID, stage: stage))
                        }
                        await send(.contentRefreshSucceeded(requestID: requestID, config: config))
                    } catch is CancellationError {
                        return
                    } catch {
                        await send(.contentRefreshFailed(requestID: requestID, config: config, message: error.localizedDescription))
                    }
                }.cancellable(id: "LiveTVFeature.refreshContent", cancelInFlight: true)

            case .cancelRefreshForBackground:
                return .merge(
                    .send(.cancelContentRefresh),
                    .send(.epgTimeline(.presented(.cancelEPGSync)))
                )

            case .cancelContentRefresh:
                guard state.isRefreshingContent, state.refreshStage?.canCancel == true else { return .none }
                state.isRefreshingContent = false
                state.activeContentRefreshID = nil
                state.refreshStage = nil
                state.refreshMessage = "Yenileme iptal edildi; mevcut katalog korundu."
                return .cancel(id: "LiveTVFeature.refreshContent")

            case let .contentRefreshProgress(requestID, stage):
                guard state.activeContentRefreshID == requestID else { return .none }
                state.refreshStage = stage
                return .none

            case let .contentRefreshSucceeded(requestID, config):
                guard state.activeContentRefreshID == requestID else { return .none }
                guard state.config == config,
                      !state.isFavoriteListMode,
                      state.selectedSmartGroupID == nil,
                      state.selectedCategoryID != nil
                else {
                    state.activeContentRefreshID = nil
                    state.isRefreshingContent = false
                    state.refreshStage = nil
                    return .none
                }
                state.refreshStage = .loadingCategories
                return .send(.reloadCategories(config: config))

            case let .contentRefreshFailed(requestID, config, message):
                guard state.activeContentRefreshID == requestID else { return .none }
                state.activeContentRefreshID = nil
                state.isRefreshingContent = false
                state.refreshStage = nil
                guard state.config == config else { return .none }
                state.refreshMessage = "Yenileme başarısız; mevcut canlı yayın kataloğu korundu. \(message)"
                return .none

            case let .categoriesResponse(.success(categories), preferences, requestID):
                guard state.activeCategoryRequestID == requestID else { return .none }
                state.activeCategoryRequestID = nil
                if state.refreshStage == .loadingCategories {
                    state.activeContentRefreshID = nil
                    state.isRefreshingContent = false
                    state.refreshStage = nil
                    state.channelsByCategory.removeAll(keepingCapacity: true)
                }
                state.isLoadingCategories = false
                state.categoryPreferences = preferences
                state.categories = categories
                state.adultCategoryIDs = Set(categories.compactMap { settingsClient.isAdultContent($0.name) ? $0.id : nil })
                if let groupID = state.selectedSmartGroupID {
                    state.smartGroupChannels = []
                    state.selectedChannel = nil
                    state.activeSmartGroupRequestID = nil
                    state.isLoadingChannels = false
                    return .send(.smartGroupSelected(groupID))
                }
                if state.isFavoriteListMode {
                    state.favoriteListResolvedChannels = []
                    state.activeFavoriteListRequestID = nil
                    state.isLoadingChannels = false
                    return .send(.favoriteListSelected(state.selectedFavoriteListID))
                }
                // Auto-select first category if current selection is invalid or nil
                if let currentID = state.selectedCategoryID, let current = categories.first(where: { $0.id == currentID }) {
                    return .send(.categorySelected(current))
                } else if let first = categories.first {
                    state.selectedCategoryID = first.id
                    return .send(.categorySelected(first))
                }
                return .none

            case let .categoriesResponse(.failure(error), _, requestID):
                guard state.activeCategoryRequestID == requestID else { return .none }
                state.activeCategoryRequestID = nil
                state.isLoadingCategories = false
                if state.refreshStage == .loadingCategories {
                    state.activeContentRefreshID = nil
                    state.isRefreshingContent = false
                    state.refreshStage = nil
                    state.refreshMessage = "Kategoriler yenilenemedi; ekrandaki son iyi katalog korundu."
                }
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .categorySelected(category):
                state.resetChannelSelection()
                let isLocked = state.categoryPreferences[category.id]?.isLocked ?? false
                let isAdult = settingsClient.isAdultContent(category.name)
                let requiresPIN = (isLocked || isAdult) && settingsClient.isParentalControlEnabled()

                if requiresPIN, !state.unlockedCategoryIDs.contains(category.id) {
                    state.parentalLock = ParentalLockFeature.State(category: category)
                    return .none
                }

                state.selectedSmartGroupID = nil
                state.activeSmartGroupRequestID = nil
                state.smartGroupChannels = []
                state.isLoadingChannels = false
                state.selectedCategoryID = category.id
                state.isFavoriteListMode = false
                state.selectedFavoriteListID = nil
                state.favoriteListResolvedChannels = []
                state.activeFavoriteListRequestID = nil
                let cancelGroupResolution = Effect<Action>.cancel(id: smartGroupResolutionCancellationID)
                let cancelFavoriteListResolution = Effect<Action>.cancel(id: favoriteListResolutionCancellationID)
                if var timeline = state.epgTimeline {
                    timeline.favoriteListID = nil
                    timeline.favoriteIDs = state.favoriteIDs
                    timeline.favoriteLoadRequestID = nil
                    timeline.channels = state.currentChannels
                    timeline.providerOrderChannels = state.currentChannels
                    timeline.selectedCategoryID = category.id
                    state.epgTimeline = timeline
                }
                // If channels are already cached, skip fetching
                if state.channelsByCategory[category.id] != nil {
                    return .merge(cancelGroupResolution, cancelFavoriteListResolution, .run { _ in await hapticClient.selection() })
                }
                if state.categoryContentRequestIDs[category.id] != nil {
                    state.isLoadingChannels = true
                    return .merge(cancelGroupResolution, cancelFavoriteListResolution, .run { _ in await hapticClient.selection() })
                }
                if state.categoryContentErrors[category.id] != nil {
                    return .merge(cancelGroupResolution, cancelFavoriteListResolution, .run { _ in await hapticClient.selection() })
                }
                guard let config = state.config else { return .merge(cancelGroupResolution, cancelFavoriteListResolution) }

                let requestID = UUID()
                state.categoryContentRequestIDs[category.id] = requestID
                state.isLoadingChannels = true
                let categoryID = category.id

                return .merge(
                    cancelGroupResolution,
                    cancelFavoriteListResolution,
                    .run { _ in await hapticClient.selection() },
                    .send(.fetchCategoryContent(requestID: requestID, config: config, categoryID: categoryID))
                )

            case let .retryCategoryContent(categoryID):
                guard state.selectedCategoryID == categoryID,
                      state.selectedSmartGroupID == nil,
                      !state.isFavoriteListMode,
                      let config = state.config
                else { return .none }
                guard state.categoryContentRequestIDs[categoryID] == nil else { return .none }
                let requestID = UUID()
                state.categoryContentRequestIDs[categoryID] = requestID
                state.categoryContentErrors.removeValue(forKey: categoryID)
                state.isLoadingChannels = true
                return .send(.fetchCategoryContent(requestID: requestID, config: config, categoryID: categoryID))

            case let .fetchCategoryContent(requestID, config, categoryID):
                guard state.categoryContentRequestIDs[categoryID] == requestID,
                      state.config == config
                else { return .none }
                return .run { send in
                    let result = await Result { try await iptvClient.fetchLiveChannels(config, categoryID) }
                    await send(.channelsResponse(requestID: requestID, config: config, categoryID: categoryID, result))
                }

            case let .smartGroupsLoaded(snapshot, playlistID, profileScope, requestID):
                guard state.activeSmartGroupLoadID == requestID,
                      state.smartGroupPlaylistID == playlistID,
                      state.smartGroupProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope else { return .none }
                state.smartChannelGroups = snapshot.groups
                state.smartGroupPersistenceRevision = snapshot.revision
                state.activeSmartGroupLoadID = nil
                state.isLoadingSmartGroups = false
                return .none

            case let .smartGroupSelected(groupID):
                guard state.smartGroupProfileScope == profileContextClient.snapshot(),
                      state.smartGroupPlaylistID == state.config?.playlistID else { return .none }
                guard let group = state.smartChannelGroups.first(where: { $0.id == groupID }),
                      let config = state.config else { return .none }
                if state.parentalControlEnabled,
                   let restrictedCategory = state.categories.first(where: { category in
                       group.categoryIDs.contains(category.id)
                           && (state.adultCategoryIDs.contains(category.id)
                               || (state.categoryPreferences[category.id]?.isLocked ?? false))
                           && !state.unlockedCategoryIDs.contains(category.id)
                   })
                {
                    state.parentalLock = ParentalLockFeature.State(category: restrictedCategory)
                    return .none
                }
                state.resetChannelSelection()
                state.selectedSmartGroupID = groupID
                state.selectedCategoryID = nil
                state.selectedChannel = nil
                state.isFavoriteListMode = false
                state.selectedFavoriteListID = nil
                state.favoriteListResolvedChannels = []
                state.activeFavoriteListRequestID = nil
                if var timeline = state.epgTimeline {
                    timeline.favoriteListID = nil
                    timeline.favoriteIDs = state.favoriteIDs
                    timeline.favoriteLoadRequestID = nil
                    timeline.favoriteOrderIDs = []
                    state.epgTimeline = timeline
                }
                state.smartGroupChannels = []
                let requestID = UUID()
                state.activeSmartGroupRequestID = requestID
                state.isLoadingChannels = true
                let allowedCategoryIDs = Set(state.smartGroupSelectableCategories.map(\.id))
                let categoryIDs = group.categoryIDs.filter { allowedCategoryIDs.contains($0) }
                let cachedChannels = state.channelsByCategory
                let playlistID = config.playlistID
                let profileScope = profileContextClient.snapshot()
                let hideAdult = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdult = settingsClient.isAdultContent
                let hiddenChannelIDs = state.hiddenChannelIDs
                let blacklistedCategoryIDs = state.blacklistedCategoryIDs
                return .run { send in
                    do {
                        var combined: [MediaModels.Item] = []
                        var seen = Set<String>()
                        for categoryID in categoryIDs {
                            guard !Task.isCancelled else { return }
                            let channels: [MediaModels.Item] = if let cached = cachedChannels[categoryID] {
                                cached
                            } else {
                                try await iptvClient.fetchLiveChannels(config, categoryID)
                            }
                            guard !Task.isCancelled else { return }
                            for channel in channels {
                                let scopedID = "\(playlistID?.uuidString ?? "")|\(channel.id)"
                                guard channel.categoryID == categoryID,
                                      !hiddenChannelIDs.contains(channel.id),
                                      !blacklistedCategoryIDs.contains(channel.categoryID),
                                      !hideAdult || !isAdult(channel.title),
                                      seen.insert(scopedID).inserted else { continue }
                                combined.append(channel)
                            }
                        }
                        guard !Task.isCancelled else { return }
                        await send(.smartGroupChannelsLoaded(groupID: groupID, playlistID: playlistID,
                                                             profileScope: profileScope, hideAdult: hideAdult, requestID: requestID, .success(combined)))
                    } catch {
                        guard !Task.isCancelled else { return }
                        await send(.smartGroupChannelsLoaded(groupID: groupID, playlistID: playlistID,
                                                             profileScope: profileScope, hideAdult: hideAdult, requestID: requestID, .failure(error)))
                    }
                }
                .cancellable(id: smartGroupResolutionCancellationID, cancelInFlight: true)

            case let .smartGroupChannelsLoaded(groupID, playlistID, profileScope, hideAdult, requestID, result):
                guard state.activeSmartGroupRequestID == requestID,
                      state.selectedSmartGroupID == groupID,
                      state.config?.playlistID == playlistID,
                      profileContextClient.snapshot() == profileScope,
                      (settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()) == hideAdult
                else { return .none }
                state.isLoadingChannels = false
                state.activeSmartGroupRequestID = nil
                switch result {
                case let .success(channels):
                    state.applyResolvedSmartGroupChannels(channels)
                case let .failure(error):
                    state.smartGroupChannels = []
                    state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                }
                return .none

            case let .favoriteListsLoaded(snapshot, playlistID, profileScope, requestID):
                guard state.favoriteListLoadRequestID == requestID,
                      state.favoriteListPlaylistID == playlistID,
                      state.favoriteListProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope else { return .none }
                state.favoriteListLoadRequestID = nil
                if snapshot.revision >= state.favoriteListPersistenceRevision {
                    state.favoriteLists = Array(snapshot.lists.prefix(20))
                    state.favoriteListPersistenceRevision = snapshot.revision
                }
                let pendingMutations = state.favoriteListPendingMutations
                state.favoriteListPendingMutations = []
                if state.isFavoriteListMode || !pendingMutations.isEmpty {
                    let selectedListID = state.selectedFavoriteListID
                    let shouldSelectList = state.isFavoriteListMode
                    return .run { send in
                        for mutation in pendingMutations {
                            switch mutation {
                            case let .save(id, name):
                                await send(.saveNamedFavoriteList(id: id, name: name))
                            case let .delete(id):
                                await send(.deleteNamedFavoriteList(id))
                            case let .move(id, offset):
                                await send(.moveNamedFavoriteList(id: id, offset: offset))
                            case let .toggle(channel, listID):
                                await send(.toggleNamedFavorite(channel, listID: listID))
                            case let .bulk(channelIDs, listID, operation, generationID):
                                if let playlistID {
                                    await send(.applyBulkNamedFavoriteList(
                                        channelIDs: Set(channelIDs),
                                        listID: listID,
                                        operation: operation,
                                        playlistID: playlistID,
                                        profileScope: profileScope,
                                        generationID: generationID
                                    ))
                                }
                            }
                        }
                        if shouldSelectList {
                            await send(.favoriteListSelected(selectedListID))
                        }
                    }
                }
                return .none

            case let .favoriteListSelected(listID):
                guard state.favoriteListProfileScope == profileContextClient.snapshot(),
                      state.favoriteListPlaylistID == state.config?.playlistID,
                      let config = state.config else { return .none }
                if let listID, !state.favoriteLists.contains(where: { $0.id == listID }) {
                    return .none
                }
                let hasPendingBulkSelection = state.isChannelSelectionMode
                    && state.activeBulkFavoriteRequestID == state.channelSelectionGenerationID
                    && state.channelSelectionPlaylistID == state.config?.playlistID
                    && state.channelSelectionProfileScope == profileContextClient.snapshot()
                if !hasPendingBulkSelection {
                    state.resetChannelSelection()
                }
                state.isFavoriteListMode = true
                state.selectedFavoriteListID = listID
                state.favoriteListResolvedChannels = []
                state.favoriteSortMode = .defaultOrder
                state.favoriteOrderIDs = []
                state.favoriteOrderRevision = 0
                let favoriteOrderRequestID = UUID()
                state.favoriteOrderRequestID = favoriteOrderRequestID
                state.unavailableFavoriteChannels = []
                state.selectedSmartGroupID = nil
                state.smartGroupChannels = []
                state.selectedCategoryID = nil
                state.selectedChannel = nil
                if var timeline = state.epgTimeline {
                    timeline.favoriteListID = listID
                    timeline.favoriteIDs = state.selectedFavoriteListChannelIDs
                    timeline.favoriteLoadRequestID = nil
                    timeline.favoriteOrderIDs = []
                    timeline.channels = []
                    timeline.providerOrderChannels = []
                    timeline.selectedCategoryID = nil
                    state.epgTimeline = timeline
                }
                let requestID = UUID()
                state.activeFavoriteListRequestID = requestID
                state.isLoadingChannels = true
                let membershipIDs = state.selectedFavoriteListChannelIDs
                let playlistID = config.playlistID
                let profileScope = profileContextClient.snapshot()
                let hiddenIDs = state.hiddenChannelIDs
                let allowedCategoryIDs = Set(state.smartGroupSelectableCategories.map(\.id))
                let hideAdult = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdult = settingsClient.isAdultContent
                let canShowUnavailableFavorites = listID == nil
                    && playlistID != nil
                    && profileScope.profileID != nil
                    && !state.parentalControlEnabled
                    && !state.hideAdultContent
                    && !UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                    && state.blacklistedCategoryIDs.isEmpty
                    && state.categoryPreferences.values.allSatisfy { !$0.isHidden && !$0.isLocked }
                let cancelOtherResolutions = Effect<Action>.merge(
                    .cancel(id: smartGroupResolutionCancellationID),
                    .cancel(id: favoriteListResolutionCancellationID)
                )
                let resolve: Effect<Action> = .run { send in
                    do {
                        let channels = try await iptvClient.fetchLiveChannels(config, nil)
                        guard !Task.isCancelled else { return }
                        let favoriteRecords = canShowUnavailableFavorites
                            ? try? await databaseClient.fetchFavoritesByType("live", profileScope)
                            : nil
                        guard !Task.isCancelled else { return }
                        var resolved: [MediaModels.Item] = []
                        var seenIDs = Set<String>()
                        for channel in channels {
                            guard membershipIDs.contains(channel.id),
                                  allowedCategoryIDs.contains(channel.categoryID),
                                  !hiddenIDs.contains(channel.id),
                                  !hideAdult || !isAdult(channel.title),
                                  seenIDs.insert(channel.id).inserted else { continue }
                            resolved.append(channel)
                        }
                        let providerChannelIDs = Set(channels.map(\.id))
                        let replacementCandidates = channels.filter { channel in
                            allowedCategoryIDs.contains(channel.categoryID)
                                && !hiddenIDs.contains(channel.id)
                                && (!hideAdult || !isAdult(channel.title))
                        }
                        var channelsByStreamURL: [String: [MediaModels.Item]] = [:]
                        for channel in replacementCandidates {
                            guard let streamURL = channel.streamURL?.absoluteString else { continue }
                            channelsByStreamURL[streamURL, default: []].append(channel)
                        }
                        var seenUnavailableFavoriteIDs: Set<String> = []
                        let unavailableFavorites = favoriteRecords?.compactMap { favorite -> UnavailableFavoriteChannel? in
                            guard let playlistID,
                                  favorite.playlistID == playlistID,
                                  membershipIDs.contains(favorite.id),
                                  !providerChannelIDs.contains(favorite.id),
                                  !hiddenIDs.contains(favorite.id) else { return nil }
                            let replacement = favorite.streamURL.flatMap { streamURL -> MediaModels.Item? in
                                guard let candidates = channelsByStreamURL[streamURL],
                                      candidates.count == 1,
                                      candidates[0].id != favorite.id else { return nil }
                                return candidates[0]
                            }
                            let unavailableFavorite = UnavailableFavoriteChannel(
                                channelID: favorite.id,
                                title: favorite.title,
                                coverURL: favorite.coverURL.flatMap { URL(string: $0) },
                                playlistID: playlistID,
                                profileID: favorite.profileID,
                                streamURL: favorite.streamURL,
                                replacement: replacement
                            )
                            return seenUnavailableFavoriteIDs.insert(unavailableFavorite.id).inserted
                                ? unavailableFavorite
                                : nil
                        }
                        guard !Task.isCancelled else { return }
                        await send(.favoriteListChannelsLoaded(listID: listID, playlistID: playlistID,
                                                               profileScope: profileScope, requestID: requestID, membershipIDs: membershipIDs,
                                                               unavailableFavorites: unavailableFavorites, .success(resolved)))
                    } catch {
                        guard !Task.isCancelled else { return }
                        await send(.favoriteListChannelsLoaded(listID: listID, playlistID: playlistID,
                                                               profileScope: profileScope, requestID: requestID, membershipIDs: membershipIDs,
                                                               unavailableFavorites: nil, .failure(error)))
                    }
                }
                .cancellable(id: favoriteListResolutionCancellationID, cancelInFlight: true)
                let orderClient = favoriteChannelOrderClient
                let loadOrder: Effect<Action> = .run { send in
                    let snapshot = await orderClient.load(profileScope.profileID, playlistID, listID)
                    guard !Task.isCancelled else { return }
                    await send(.favoriteOrderLoaded(
                        snapshot,
                        listID: listID,
                        playlistID: playlistID,
                        profileScope: profileScope,
                        requestID: favoriteOrderRequestID
                    ))
                }
                .cancellable(id: favoriteOrderLoadCancellationID, cancelInFlight: true)
                let reloadTimeline: Effect<Action> = state.epgTimeline == nil
                    ? .none
                    : .send(.epgTimeline(.presented(.loadFavorites)))
                return .merge(
                    cancelOtherResolutions,
                    resolve,
                    loadOrder,
                    reloadTimeline
                )

            case .clearFavoriteListSelection:
                state.resetChannelSelection()
                state.isFavoriteListMode = false
                state.selectedFavoriteListID = nil
                state.favoriteListResolvedChannels = []
                state.favoriteOrderRequestID = nil
                state.unavailableFavoriteChannels = []
                state.activeFavoriteListRequestID = nil
                state.isLoadingChannels = false
                let cancel = Effect<Action>.cancel(id: favoriteListResolutionCancellationID)
                let cancelOrder = Effect<Action>.cancel(id: favoriteOrderLoadCancellationID)
                guard let category = state.categories.first else { return .merge(cancel, cancelOrder) }
                return .merge(cancel, cancelOrder, .send(.categorySelected(category)))

            case let .favoriteListChannelsLoaded(listID, playlistID, profileScope, requestID, membershipIDs, unavailableFavorites, result):
                guard state.activeFavoriteListRequestID == requestID,
                      state.isFavoriteListMode,
                      state.selectedFavoriteListID == listID,
                      state.selectedFavoriteListChannelIDs == membershipIDs,
                      state.config?.playlistID == playlistID,
                      profileContextClient.snapshot() == profileScope else { return .none }
                state.activeFavoriteListRequestID = nil
                state.isLoadingChannels = false
                if let unavailableFavorites {
                    state.unavailableFavoriteChannels = unavailableFavorites
                }
                switch result {
                case let .success(channels):
                    let eligibleCategoryIDs = Set(state.smartGroupSelectableCategories.map(\.id))
                    let hideAdult = state.hideAdultContent || state.parentalControlEnabled
                    state.favoriteListResolvedChannels = channels.filter {
                        membershipIDs.contains($0.id)
                            && eligibleCategoryIDs.contains($0.categoryID)
                            && !state.hiddenChannelIDs.contains($0.id)
                            && (!hideAdult || !settingsClient.isAdultContent($0.title))
                    }
                    var updatedOrder: FavoriteChannelOrderSnapshot?
                    if state.favoriteOrderRequestID == nil {
                        let normalizedIDs = FavoriteChannelSortMode.normalizedManualIDs(
                            favoriteIDs: membershipIDs,
                            providerIDs: state.favoriteListResolvedChannels.map(\.id),
                            storedIDs: state.favoriteOrderIDs
                        )
                        let orderChanged = normalizedIDs != state.favoriteOrderIDs
                        state.favoriteOrderIDs = normalizedIDs
                        if orderChanged, let playlistID {
                            let order = FavoriteChannelOrderSnapshot(
                                mode: state.favoriteSortMode,
                                orderedIDs: normalizedIDs,
                                revision: nextLiveFavoriteOrderRevision(after: state.favoriteOrderRevision)
                            )
                            state.favoriteOrderRevision = order.revision
                            updatedOrder = order
                        }
                    }
                    state.syncEPGTimeline(
                        channels: state.currentChannels,
                        selectedCategoryID: nil,
                        providerOrderChannels: state.favoriteListResolvedChannels
                    )
                    if let updatedOrder, let playlistID {
                        let orderClient = favoriteChannelOrderClient
                        let profileID = profileScope.profileID
                        let listID = state.selectedFavoriteListID
                        return .run { _ in
                            await orderClient.save(updatedOrder, profileID, playlistID, listID)
                        }
                    }
                case let .failure(error):
                    state.favoriteListResolvedChannels = []
                    state.syncEPGTimeline(channels: [], selectedCategoryID: nil)
                    state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                }
                return .none

            case let .favoriteOrderLoaded(snapshot, listID, playlistID, profileScope, requestID):
                guard state.favoriteOrderRequestID == requestID,
                      state.isFavoriteListMode,
                      state.selectedFavoriteListID == listID,
                      state.config?.playlistID == playlistID,
                      profileContextClient.snapshot() == profileScope else { return .none }
                state.favoriteOrderRequestID = nil
                let normalizedIDs = FavoriteChannelSortMode.normalizedManualIDs(
                    favoriteIDs: state.selectedFavoriteListChannelIDs,
                    providerIDs: state.favoriteListResolvedChannels.map(\.id),
                    storedIDs: snapshot.orderedIDs
                )
                state.favoriteSortMode = snapshot.mode
                state.favoriteOrderIDs = normalizedIDs
                state.favoriteOrderRevision = snapshot.revision
                state.syncEPGTimeline(
                    channels: state.currentChannels,
                    selectedCategoryID: nil,
                    providerOrderChannels: state.favoriteListResolvedChannels
                )
                guard normalizedIDs != snapshot.orderedIDs,
                      !state.isLoadingChannels,
                      let playlistID else { return .none }
                let order = FavoriteChannelOrderSnapshot(
                    mode: snapshot.mode,
                    orderedIDs: normalizedIDs,
                    revision: nextLiveFavoriteOrderRevision(after: snapshot.revision)
                )
                state.favoriteOrderRevision = order.revision
                let orderClient = favoriteChannelOrderClient
                let profileID = profileScope.profileID
                return .run { _ in
                    await orderClient.save(order, profileID, playlistID, listID)
                }

            case let .setFavoriteSortMode(mode):
                guard state.isFavoriteListMode, let playlistID = state.config?.playlistID else { return .none }
                state.favoriteOrderRequestID = nil
                let order = FavoriteChannelOrderSnapshot(
                    mode: mode,
                    orderedIDs: FavoriteChannelSortMode.normalizedManualIDs(
                        favoriteIDs: state.selectedFavoriteListChannelIDs,
                        providerIDs: state.favoriteListResolvedChannels.map(\.id),
                        storedIDs: state.favoriteOrderIDs
                    ),
                    revision: nextLiveFavoriteOrderRevision(after: state.favoriteOrderRevision)
                )
                state.favoriteSortMode = mode
                state.favoriteOrderIDs = order.orderedIDs
                state.favoriteOrderRevision = order.revision
                state.syncEPGTimeline(
                    channels: state.currentChannels,
                    selectedCategoryID: nil,
                    providerOrderChannels: state.favoriteListResolvedChannels
                )
                if var timeline = state.epgTimeline,
                   timeline.config.playlistID == playlistID,
                   timeline.favoriteListID == state.selectedFavoriteListID
                {
                    timeline.favoriteSortMode = mode
                    timeline.favoriteOrderIDs = order.orderedIDs
                    timeline.favoriteOrderRevision = order.revision
                    state.epgTimeline = timeline
                }
                let orderClient = favoriteChannelOrderClient
                let profileID = profileContextClient.snapshot().profileID
                let listID = state.selectedFavoriteListID
                return .concatenate(
                    .cancel(id: favoriteOrderLoadCancellationID),
                    .run { _ in
                        await orderClient.save(order, profileID, playlistID, listID)
                    }
                )

            case let .moveFavoriteChannel(channelID, offset):
                guard state.isFavoriteListMode,
                      state.favoriteSortMode == .manual,
                      let playlistID = state.config?.playlistID else { return .none }
                state.favoriteOrderRequestID = nil
                let orderedIDs = FavoriteChannelSortMode.normalizedManualIDs(
                    favoriteIDs: state.selectedFavoriteListChannelIDs,
                    providerIDs: state.favoriteListResolvedChannels.map(\.id),
                    storedIDs: state.favoriteOrderIDs
                )
                let visibleIDs = state.currentChannels.map(\.id)
                guard let visibleIndex = visibleIDs.firstIndex(of: channelID) else { return .none }
                let visibleDestination = visibleIndex + offset
                guard visibleIDs.indices.contains(visibleDestination),
                      let source = orderedIDs.firstIndex(of: channelID),
                      let destination = orderedIDs.firstIndex(of: visibleIDs[visibleDestination]) else { return .none }
                var reorderedIDs = orderedIDs
                reorderedIDs.swapAt(source, destination)
                let order = FavoriteChannelOrderSnapshot(
                    mode: .manual,
                    orderedIDs: reorderedIDs,
                    revision: nextLiveFavoriteOrderRevision(after: state.favoriteOrderRevision)
                )
                state.favoriteOrderIDs = reorderedIDs
                state.favoriteOrderRevision = order.revision
                state.syncEPGTimeline(
                    channels: state.currentChannels,
                    selectedCategoryID: nil,
                    providerOrderChannels: state.favoriteListResolvedChannels
                )
                if var timeline = state.epgTimeline,
                   timeline.config.playlistID == playlistID,
                   timeline.favoriteListID == state.selectedFavoriteListID
                {
                    timeline.favoriteSortMode = .manual
                    timeline.favoriteOrderIDs = reorderedIDs
                    timeline.favoriteOrderRevision = order.revision
                    state.epgTimeline = timeline
                }
                let orderClient = favoriteChannelOrderClient
                let profileID = profileContextClient.snapshot().profileID
                let listID = state.selectedFavoriteListID
                return .concatenate(
                    .cancel(id: favoriteOrderLoadCancellationID),
                    .run { _ in
                        await orderClient.save(order, profileID, playlistID, listID)
                    }
                )

            case let .saveNamedFavoriteList(id, rawName):
                guard state.pendingNamedFavoriteBulk == nil else { return .none }
                let profileScope = profileContextClient.snapshot()
                guard profileScope == state.favoriteListProfileScope,
                      let profileID = profileScope.profileID,
                      let playlistID = state.config?.playlistID else { return .none }
                if state.favoriteListLoadRequestID != nil {
                    state.favoriteListPendingMutations.append(.save(id: id, name: rawName))
                    return .none
                }
                let name = String(rawName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                guard !name.isEmpty else { return .none }
                if let duplicate = state.favoriteLists.first(where: {
                    $0.id != id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
                }), duplicate.id != id {
                    return .none
                }
                if id == nil, state.favoriteLists.count >= 20 {
                    return .none
                }
                if let id, let index = state.favoriteLists.firstIndex(where: { $0.id == id }) {
                    state.favoriteLists[index].name = name
                } else {
                    state.favoriteLists.append(NamedFavoriteChannelList(name: name))
                }
                return persistFavoriteLists(state: &state, client: favoriteChannelListsClient, profileID: profileID, playlistID: playlistID)

            case let .deleteNamedFavoriteList(listID):
                guard state.pendingNamedFavoriteBulk == nil else { return .none }
                let profileScope = profileContextClient.snapshot()
                guard profileScope == state.favoriteListProfileScope,
                      let profileID = profileScope.profileID,
                      let playlistID = state.config?.playlistID else { return .none }
                if state.favoriteListLoadRequestID != nil {
                    state.favoriteListPendingMutations.append(.delete(listID))
                    return .none
                }
                state.favoriteLists.removeAll { $0.id == listID }
                let wasSelected = state.selectedFavoriteListID == listID
                if wasSelected {
                    state.isFavoriteListMode = false
                    state.selectedFavoriteListID = nil
                    state.favoriteListResolvedChannels = []
                    state.activeFavoriteListRequestID = nil
                    state.isLoadingChannels = false
                }
                let save = persistFavoriteLists(state: &state, client: favoriteChannelListsClient, profileID: profileID, playlistID: playlistID)
                let cancel: Effect<Action> = wasSelected ? .cancel(id: favoriteListResolutionCancellationID) : .none
                if wasSelected, let category = state.categories.first {
                    return .merge(save, cancel, .send(.categorySelected(category)))
                }
                if wasSelected, var timeline = state.epgTimeline {
                    timeline.favoriteListID = nil
                    timeline.favoriteIDs = state.favoriteIDs
                    timeline.favoriteLoadRequestID = nil
                    timeline.favoriteOrderIDs = []
                    state.epgTimeline = timeline
                }
                return .merge(save, cancel)

            case let .moveNamedFavoriteList(listID, offset):
                guard state.pendingNamedFavoriteBulk == nil, offset == -1 || offset == 1 else { return .none }
                let profileScope = profileContextClient.snapshot()
                guard profileScope == state.favoriteListProfileScope,
                      let profileID = profileScope.profileID,
                      let playlistID = state.config?.playlistID else { return .none }
                if state.favoriteListLoadRequestID != nil {
                    state.favoriteListPendingMutations.append(.move(id: listID, offset: offset))
                    return .none
                }
                guard let index = state.favoriteLists.firstIndex(where: { $0.id == listID }) else { return .none }
                let destination = index + offset
                guard state.favoriteLists.indices.contains(destination) else { return .none }
                state.favoriteLists.swapAt(index, destination)
                return persistFavoriteLists(state: &state, client: favoriteChannelListsClient, profileID: profileID, playlistID: playlistID)

            case let .toggleNamedFavorite(channel, listID):
                guard state.pendingNamedFavoriteBulk == nil else { return .none }
                let profileScope = profileContextClient.snapshot()
                guard profileScope == state.favoriteListProfileScope,
                      let profileID = profileScope.profileID,
                      let playlistID = state.config?.playlistID,
                      state.smartGroupSelectableCategories.contains(where: { $0.id == channel.categoryID }),
                      !state.hiddenChannelIDs.contains(channel.id) else { return .none }
                guard channel.id.utf8.count <= NamedFavoriteChannelList.maximumChannelIDByteCount else {
                    state.bulkFavoriteNotice = AppStrings.LiveTV.favoriteListChannelIDTooLong
                    return .none
                }
                if state.favoriteListLoadRequestID != nil {
                    state.favoriteListPendingMutations.append(.toggle(channel: channel, listID: listID))
                    return .none
                }
                guard let index = state.favoriteLists.firstIndex(where: { $0.id == listID }) else { return .none }
                var list = state.favoriteLists[index]
                if let memberIndex = list.channelIDs.firstIndex(of: channel.id) {
                    list.channelIDs.remove(at: memberIndex)
                    state.favoriteListResolvedChannels.removeAll { $0.id == channel.id }
                } else {
                    guard list.channelIDs.count < 2000 else { return .none }
                    list.channelIDs.append(channel.id)
                    if state.isFavoriteListMode, state.selectedFavoriteListID == listID {
                        state.favoriteListResolvedChannels.append(channel)
                    }
                }
                state.favoriteLists[index] = list
                if var timeline = state.epgTimeline,
                   state.isFavoriteListMode,
                   state.selectedFavoriteListID == listID
                {
                    timeline.favoriteIDs = Set(list.channelIDs)
                    timeline.favoriteListID = listID
                    timeline.favoriteLoadRequestID = nil
                    timeline.channels = state.currentChannels
                    timeline.providerOrderChannels = state.currentChannels
                    state.epgTimeline = timeline
                }
                return persistFavoriteLists(state: &state, client: favoriteChannelListsClient, profileID: profileID, playlistID: playlistID)

            case .enterChannelSelectionMode:
                guard let playlistID = state.config?.playlistID else { return .none }
                let scope = profileContextClient.snapshot()
                state.isChannelSelectionMode = true
                state.selectedChannelIDs = []
                state.channelSelectionPlaylistID = playlistID
                state.channelSelectionProfileScope = scope
                state.channelSelectionGenerationID = UUID()
                state.bulkFavoriteNotice = nil
                return .none

            case let .toggleChannelSelection(channel):
                guard state.isChannelSelectionMode,
                      state.channelSelectionPlaylistID == state.config?.playlistID,
                      state.channelSelectionProfileScope == profileContextClient.snapshot(),
                      !state.unavailableFavoriteChannelIDs.contains(channel.id),
                      state.currentChannels.contains(where: { $0.id == channel.id }) else { return .none }
                if !state.selectedChannelIDs.insert(channel.id).inserted {
                    state.selectedChannelIDs.remove(channel.id)
                }
                return .none

            case .selectAllCurrentChannels:
                guard state.isChannelSelectionMode,
                      state.channelSelectionPlaylistID == state.config?.playlistID,
                      state.channelSelectionProfileScope == profileContextClient.snapshot() else { return .none }
                state.selectedChannelIDs = Set(state.currentChannels
                    .filter { !state.unavailableFavoriteChannelIDs.contains($0.id) }
                    .map(\.id))
                return .none

            case .clearChannelSelection:
                state.selectedChannelIDs = []
                return .none

            case .exitChannelSelectionMode:
                state.resetChannelSelection()
                return .none

            case .hideSelectedChannels:
                guard
                    state.isChannelSelectionMode,
                    let playlistID = state.config?.playlistID,
                    state.channelSelectionPlaylistID == playlistID,
                    let profileScope = state.channelSelectionProfileScope,
                    profileScope == profileContextClient.snapshot()
                else {
                    state.resetChannelSelection()
                    return .none
                }
                let selectedIDs = state.selectedCurrentChannelIDs
                let selectedChannels = state.currentChannels.filter { selectedIDs.contains($0.id) }
                guard !selectedChannels.isEmpty else { return .none }

                let hiddenItems = selectedChannels.map {
                    HiddenItemDTO(id: $0.id, title: $0.title, type: .channel)
                }
                state.hiddenChannelIDs.formUnion(hiddenItems.map(\.id))
                state.selectedChannelIDs.subtract(hiddenItems.map(\.id))
                state.syncEPGTimeline(channels: state.currentChannels, selectedCategoryID: state.selectedCategoryID)
                return .run { _ in
                    parentalControlClient.hideChannels(hiddenItems)
                    await hapticClient.notification(.success)
                }

            case .dismissBulkFavoriteNotice:
                state.bulkFavoriteNotice = nil
                return .none

            case let .bulkFavoriteAction(targetListID, operation):
                guard state.isChannelSelectionMode,
                      let playlistID = state.config?.playlistID,
                      state.channelSelectionPlaylistID == playlistID,
                      let profileScope = state.channelSelectionProfileScope,
                      profileScope == profileContextClient.snapshot()
                else {
                    state.resetChannelSelection()
                    return .none
                }
                let ids = state.selectedCurrentChannelIDs
                guard !ids.isEmpty else { return .none }
                if targetListID == nil,
                   state.activeDefaultFavoriteRequestID != nil,
                   state.activeDefaultFavoritePlaylistID == playlistID,
                   state.activeDefaultFavoriteProfileScope == profileScope
                {
                    return .none
                }
                guard let generationID = state.channelSelectionGenerationID else { return .none }
                if let targetListID {
                    guard state.pendingNamedFavoriteBulk == nil else { return .none }
                    if state.favoriteListLoadRequestID != nil {
                        guard state.activeBulkFavoriteRequestID == nil else { return .none }
                        state.favoriteListPendingMutations.append(.bulk(
                            channelIDs: Array(ids), listID: targetListID, operation: operation,
                            generationID: generationID
                        ))
                        state.activeBulkFavoriteRequestID = generationID
                        return .none
                    }
                    guard state.favoriteLists.contains(where: { $0.id == targetListID }) else { return .none }
                    return .send(.applyBulkNamedFavoriteList(
                        channelIDs: ids,
                        listID: targetListID,
                        operation: operation,
                        playlistID: playlistID,
                        profileScope: profileScope,
                        generationID: generationID
                    ))
                }

                guard let configPlaylistID = state.config?.playlistID else { return .none }
                let selectedItems = state.currentChannels.filter { ids.contains($0.id) }
                let favoriteItems = selectedItems.map { channel in
                    FavoriteItem(
                        id: channel.id,
                        type: "live",
                        title: channel.title,
                        coverURL: channel.coverURL?.absoluteString,
                        streamURL: channel.streamURL?.absoluteString,
                        playlistID: configPlaylistID
                    )
                }
                let requestID = UUID()
                state.activeBulkFavoriteRequestID = requestID
                state.activeDefaultFavoriteRequestID = requestID
                state.activeDefaultFavoritePlaylistID = configPlaylistID
                state.activeDefaultFavoriteProfileScope = profileScope
                state.activeDefaultFavoriteSelectionGenerationID = generationID
                state.bulkFavoriteNotice = nil
                return .run { send in
                    do {
                        let result = try await databaseClient.setFavorites(
                            favoriteItems,
                            operation == .add,
                            profileScope
                        )
                        await send(.bulkFavoriteCompleted(
                            requestID: requestID,
                            targetListID: nil,
                            operation: operation,
                            playlistID: configPlaylistID,
                            profileScope: profileScope,
                            selectionGenerationID: generationID,
                            channelIDs: ids,
                            .success(result)
                        ))
                    } catch {
                        await send(.bulkFavoriteCompleted(
                            requestID: requestID,
                            targetListID: nil,
                            operation: operation,
                            playlistID: configPlaylistID,
                            profileScope: profileScope,
                            selectionGenerationID: generationID,
                            channelIDs: ids,
                            .failure(error)
                        ))
                    }
                }

            case let .applyBulkNamedFavoriteList(channelIDs, listID, operation, playlistID, profileScope, generationID):
                guard state.config?.playlistID == playlistID,
                      state.favoriteListPlaylistID == playlistID,
                      state.favoriteListProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope,
                      state.isChannelSelectionMode,
                      state.channelSelectionGenerationID == generationID,
                      state.activeBulkFavoriteRequestID == nil || state.activeBulkFavoriteRequestID == generationID,
                      let profileID = profileScope.profileID,
                      let listIndex = state.favoriteLists.firstIndex(where: { $0.id == listID })
                else {
                    if state.channelSelectionGenerationID == generationID {
                        state.activeBulkFavoriteRequestID = nil
                        state.bulkFavoriteNotice = AppStrings.LiveTV.bulkFavoritesFailed
                    }
                    return .none
                }
                var updatedLists = state.favoriteLists
                var list = updatedLists[listIndex]
                let eligibleIDs = Set(state.currentChannels.map(\.id))
                let requestedIDs = channelIDs.intersection(eligibleIDs)
                guard !requestedIDs.isEmpty,
                      requestedIDs == channelIDs,
                      channelIDs.allSatisfy({ $0.utf8.count <= NamedFavoriteChannelList.maximumChannelIDByteCount })
                else {
                    state.activeBulkFavoriteRequestID = nil
                    state.bulkFavoriteNotice = AppStrings.LiveTV.bulkFavoritesFailed
                    return .none
                }
                if operation == .add {
                    let additions = requestedIDs.subtracting(list.channelIDs)
                    guard list.channelIDs.count + additions.count <= 2000 else {
                        state.activeBulkFavoriteRequestID = nil
                        state.bulkFavoriteNotice = AppStrings.LiveTV.favoriteListCapacityReached
                        return .none
                    }
                    for channel in state.currentChannels where additions.contains(channel.id) {
                        list.channelIDs.append(channel.id)
                    }
                } else {
                    list.channelIDs.removeAll { requestedIDs.contains($0) }
                }
                updatedLists[listIndex] = list
                let revision = state.favoriteListPersistenceRevision &+ 1
                let snapshot = FavoriteChannelListsSnapshot(
                    lists: updatedLists,
                    revision: revision
                )
                let requestID = UUID()
                state.pendingNamedFavoriteBulk = PendingNamedFavoriteBulk(
                    id: requestID,
                    playlistID: playlistID,
                    profileScope: profileScope,
                    listID: listID,
                    operation: operation,
                    channelIDs: channelIDs,
                    updatedLists: updatedLists,
                    revision: revision,
                    selectionGenerationID: generationID
                )
                state.activeBulkFavoriteRequestID = requestID
                return .run { send in
                    let didSave = await favoriteChannelListsClient.save(snapshot, profileID, playlistID)
                    await send(.namedFavoriteBulkSaveCompleted(
                        requestID: requestID,
                        playlistID: playlistID,
                        profileScope: profileScope,
                        didSave: didSave
                    ))
                }

            case let .namedFavoriteBulkSaveCompleted(requestID, playlistID, profileScope, didSave):
                guard let pending = state.pendingNamedFavoriteBulk,
                      pending.id == requestID,
                      pending.playlistID == playlistID,
                      pending.profileScope == profileScope,
                      state.config?.playlistID == playlistID,
                      state.favoriteListPlaylistID == playlistID,
                      state.favoriteListProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope else { return .none }
                state.pendingNamedFavoriteBulk = nil
                if state.activeBulkFavoriteRequestID == requestID {
                    state.activeBulkFavoriteRequestID = nil
                }
                guard didSave,
                      state.favoriteListPersistenceRevision <= pending.revision
                else {
                    if state.channelSelectionGenerationID == pending.selectionGenerationID {
                        state.bulkFavoriteNotice = AppStrings.LiveTV.bulkFavoritesFailed
                    }
                    return .none
                }
                state.favoriteLists = pending.updatedLists
                state.favoriteListPersistenceRevision = pending.revision
                if state.isFavoriteListMode, state.selectedFavoriteListID == pending.listID,
                   pending.operation == .remove
                {
                    state.favoriteListResolvedChannels.removeAll { pending.channelIDs.contains($0.id) }
                }
                if var timeline = state.epgTimeline,
                   timeline.config.playlistID == playlistID,
                   timeline.favoriteListID == pending.listID
                {
                    timeline.favoriteIDs = Set(pending.updatedLists.first(where: { $0.id == pending.listID })?.channelIDs ?? [])
                    timeline.favoriteOrderIDs = pending.updatedLists.first(where: { $0.id == pending.listID })?.channelIDs ?? []
                    timeline.channels = state.currentChannels
                    timeline.providerOrderChannels = state.currentChannels
                    state.epgTimeline = timeline
                }
                let sameSelection = state.isChannelSelectionMode
                    && state.channelSelectionGenerationID == pending.selectionGenerationID
                    && state.channelSelectionPlaylistID == playlistID
                    && state.channelSelectionProfileScope == profileScope
                if sameSelection {
                    state.resetChannelSelection()
                    state.bulkFavoriteNotice = pending.operation == .add
                        ? AppStrings.LiveTV.bulkFavoritesAdded
                        : AppStrings.LiveTV.bulkFavoritesRemoved
                }
                if state.isFavoriteListMode, state.selectedFavoriteListID == pending.listID {
                    return .send(.favoriteListSelected(pending.listID))
                }
                return .none

            case let .bulkFavoriteCompleted(requestID, targetListID, operation, playlistID, profileScope, selectionGenerationID, channelIDs, result):
                if targetListID == nil {
                    guard state.activeDefaultFavoriteRequestID == requestID,
                          state.activeDefaultFavoritePlaylistID == playlistID,
                          state.activeDefaultFavoriteProfileScope == profileScope,
                          state.activeDefaultFavoriteSelectionGenerationID == selectionGenerationID,
                          state.config?.playlistID == playlistID,
                          profileContextClient.snapshot() == profileScope else { return .none }
                    state.activeDefaultFavoriteRequestID = nil
                    state.activeDefaultFavoritePlaylistID = nil
                    state.activeDefaultFavoriteProfileScope = nil
                    state.activeDefaultFavoriteSelectionGenerationID = nil
                    if state.activeBulkFavoriteRequestID == requestID {
                        state.activeBulkFavoriteRequestID = nil
                    }
                } else {
                    guard state.activeBulkFavoriteRequestID == requestID,
                          state.config?.playlistID == playlistID,
                          state.channelSelectionPlaylistID == playlistID,
                          state.channelSelectionProfileScope == profileScope,
                          profileContextClient.snapshot() == profileScope else { return .none }
                    state.activeBulkFavoriteRequestID = nil
                }
                let hasMatchingSelection = state.isChannelSelectionMode
                    && state.channelSelectionPlaylistID == playlistID
                    && state.channelSelectionProfileScope == profileScope
                let selectionGenerationMatches = targetListID != nil
                    || (state.channelSelectionGenerationID == selectionGenerationID
                        && state.selectedChannelIDs == channelIDs)
                let orderSource = state.epgTimeline?.config.playlistID == playlistID
                    ? state.epgTimeline?.providerOrderChannels ?? state.currentChannels
                    : state.currentChannels
                let changedIDsInProviderOrder = orderSource.map(\.id).filter { channelIDs.contains($0) }
                switch result {
                case .success(true):
                    if operation == .add {
                        state.favoriteIDs.formUnion(channelIDs)
                    } else {
                        state.favoriteIDs.subtract(channelIDs)
                    }
                    if var timeline = state.epgTimeline,
                       timeline.config.playlistID == playlistID,
                       timeline.favoriteListID == nil
                    {
                        timeline.defaultFavoriteIDs = state.favoriteIDs
                        timeline.favoriteIDs = state.favoriteIDs
                        if operation == .remove {
                            timeline.favoriteOrderIDs.removeAll { channelIDs.contains($0) }
                        }
                        state.epgTimeline = timeline
                    }
                    if state.isFavoriteListMode, state.selectedFavoriteListID == nil {
                        let visibleChannels = state.favoriteListResolvedChannels
                        state.favoriteListResolvedChannels = visibleChannels.filter { state.favoriteIDs.contains($0.id) }
                        state.syncEPGTimeline(channels: state.favoriteListResolvedChannels, selectedCategoryID: nil)
                    }
                    if hasMatchingSelection, selectionGenerationMatches {
                        state.selectedChannelIDs = []
                        state.bulkFavoriteNotice = operation == .add
                            ? AppStrings.LiveTV.bulkFavoritesAdded
                            : AppStrings.LiveTV.bulkFavoritesRemoved
                    }
                    if targetListID == nil,
                       state.epgTimeline?.config.playlistID == playlistID
                    {
                        return .send(.epgTimeline(.presented(.bulkDefaultFavoritesChanged(
                            defaultIDs: state.favoriteIDs,
                            changedIDsInProviderOrder: changedIDsInProviderOrder,
                            operation: operation
                        ))))
                    }
                case .success(false):
                    if hasMatchingSelection, selectionGenerationMatches {
                        state.bulkFavoriteNotice = AppStrings.LiveTV.bulkFavoritesFailed
                    }
                case .failure:
                    if hasMatchingSelection, selectionGenerationMatches {
                        state.bulkFavoriteNotice = AppStrings.LiveTV.bulkFavoritesFailed
                    }
                }
                return .none

            case let .saveSmartChannelGroup(id, name, categoryIDs):
                guard !state.isLoadingSmartGroups else { return .none }
                let profileScope = profileContextClient.snapshot()
                guard profileScope == state.smartGroupProfileScope,
                      let profileID = profileScope.profileID,
                      let playlistID = state.config?.playlistID else { return .none }
                let normalizedName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(48))
                var uniqueCategoryIDs: [String] = []
                for categoryID in categoryIDs where uniqueCategoryIDs.count < SmartChannelGroup.maximumCategoryCount
                    && !uniqueCategoryIDs.contains(categoryID)
                {
                    uniqueCategoryIDs.append(categoryID)
                }
                guard !normalizedName.isEmpty, !uniqueCategoryIDs.isEmpty else { return .none }
                let allowedCategoryIDs = Set(state.smartGroupSelectableCategories.map(\.id))
                let existingGroup: SmartChannelGroup? = if let id {
                    state.smartChannelGroups.first { group in group.id == id }
                } else {
                    nil
                }
                let existingCategoryIDArray = existingGroup?.categoryIDs ?? [String]()
                let existingCategoryIDs = Set<String>(existingCategoryIDArray)
                var containsOnlyAllowedCategories = true
                for categoryID in uniqueCategoryIDs {
                    if !allowedCategoryIDs.contains(categoryID), !existingCategoryIDs.contains(categoryID) {
                        containsOnlyAllowedCategories = false
                        break
                    }
                }
                guard containsOnlyAllowedCategories else { return .none }
                let group = SmartChannelGroup(id: id ?? UUID().uuidString, name: normalizedName, categoryIDs: uniqueCategoryIDs)
                if let index = state.smartChannelGroups.firstIndex(where: { $0.id == group.id }) {
                    state.smartChannelGroups[index] = group
                } else {
                    state.smartChannelGroups.append(group)
                }
                state.smartGroupPersistenceRevision &+= 1
                state.activeSmartGroupLoadID = nil
                let groups = state.smartChannelGroups
                let revision = state.smartGroupPersistenceRevision
                let saveEffect = Effect<Action>.run { _ in
                    await smartChannelGroupClient.save(groups, profileID, playlistID, revision)
                }
                if state.selectedSmartGroupID == group.id {
                    return .merge(saveEffect, .send(.smartGroupSelected(group.id)))
                }
                return saveEffect

            case let .deleteSmartChannelGroup(groupID):
                let profileScope = profileContextClient.snapshot()
                guard profileScope == state.smartGroupProfileScope,
                      let profileID = profileScope.profileID,
                      let playlistID = state.config?.playlistID else { return .none }
                let wasSelected = state.selectedSmartGroupID == groupID
                state.smartChannelGroups.removeAll { $0.id == groupID }
                if wasSelected {
                    state.selectedSmartGroupID = nil
                    state.smartGroupChannels = []
                    state.activeSmartGroupRequestID = nil
                    state.isLoadingChannels = false
                }
                state.smartGroupPersistenceRevision &+= 1
                let groups = state.smartChannelGroups
                let revision = state.smartGroupPersistenceRevision
                let saveEffect = Effect<Action>.run { _ in
                    await smartChannelGroupClient.save(groups, profileID, playlistID, revision)
                }
                let cancelEffect: Effect<Action> = wasSelected
                    ? .cancel(id: smartGroupResolutionCancellationID)
                    : .none
                if let firstCategory = state.categories.first, state.selectedCategoryID == nil {
                    return .merge(cancelEffect, saveEffect, .send(.categorySelected(firstCategory)))
                }
                return .merge(cancelEffect, saveEffect)

            case let .channelsResponse(requestID, config, categoryID, .success(channels)):
                guard state.categoryContentRequestIDs[categoryID] == requestID,
                      state.config == config
                else { return .none }
                state.categoryContentRequestIDs.removeValue(forKey: categoryID)
                if state.selectedCategoryID == categoryID,
                   state.selectedSmartGroupID == nil,
                   !state.isFavoriteListMode
                {
                    state.isLoadingChannels = false
                }
                state.categoryContentErrors.removeValue(forKey: categoryID)
                state.channelsByCategory[categoryID] = channels
                if state.selectedTabMode == .epg, let epg = state.epgTimeline, epg.channels.isEmpty {
                    state.epgTimeline?.channels = channels
                }
                return .none

            case let .channelsResponse(requestID, config, categoryID, .failure(error)):
                guard state.categoryContentRequestIDs[categoryID] == requestID,
                      state.config == config
                else { return .none }
                state.categoryContentRequestIDs.removeValue(forKey: categoryID)
                if state.selectedCategoryID == categoryID,
                   state.selectedSmartGroupID == nil,
                   !state.isFavoriteListMode
                {
                    state.isLoadingChannels = false
                }
                state.categoryContentErrors[categoryID] = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .channelSelected(channel):
                guard !state.unavailableFavoriteChannelIDs.contains(channel.id) else { return .none }
                state.selectedChannel = channel
                return .merge(
                    .run { _ in await hapticClient.impact(.light) },
                    .send(.delegate(.didSelectChannel(channel, playlist: state.currentChannels)))
                )

            case let .selectChannelPreview(channel):
                guard !state.unavailableFavoriteChannelIDs.contains(channel.id) else { return .none }
                state.selectedChannel = channel
                state.selectedChannelEPG = []
                guard let config = state.config, let epgID = channel.epgChannelID else {
                    return .run { _ in await hapticClient.impact(.light) }
                }
                state.isLoadingChannelEPG = true
                return .merge(
                    .run { _ in await hapticClient.impact(.light) },
                    .run { send in
                        await send(.channelEPGResponse(Result {
                            try await iptvClient.fetchShortEPG(config, epgID, 12)
                        }))
                    }
                )

            case let .channelEPGResponse(.success(listings)):
                state.isLoadingChannelEPG = false
                state.selectedChannelEPG = listings
                return .none

            case .channelEPGResponse(.failure):
                state.isLoadingChannelEPG = false
                return .none

            case let .favoritesLoaded(favIDs, playlistID, scope):
                guard profileContextClient.snapshot() == scope,
                      state.config?.playlistID == playlistID else { return .none }
                state.favoriteIDs = favIDs
                if state.isFavoriteListMode, state.selectedFavoriteListID == nil {
                    return .send(.favoriteListSelected(nil))
                }
                return .none

            case let .toggleFavorite(item):
                let profileScope = profileContextClient.snapshot()
                let playlistID = state.config?.playlistID
                let favItem = FavoriteItem(
                    id: item.id,
                    type: "live",
                    title: item.title,
                    coverURL: item.coverURL?.absoluteString,
                    streamURL: item.streamURL?.absoluteString,
                    playlistID: playlistID
                )
                let isCurrentlyFav = state.favoriteIDs.contains(item.id)
                if isCurrentlyFav {
                    state.favoriteIDs.remove(item.id)
                    state.unavailableFavoriteChannels.removeAll { $0.channelID == item.id }
                } else {
                    state.favoriteIDs.insert(item.id)
                }
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(favItem, profileScope)
                    await hapticClient.notification(.success)
                }

            case let .recoverUnavailableFavorite(channelID, replacement):
                guard state.isFavoriteListMode,
                      state.selectedFavoriteListID == nil,
                      let playlistID = state.config?.playlistID,
                      let unavailable = state.unavailableFavoriteChannels.first(where: {
                          $0.channelID == channelID && $0.playlistID == playlistID
                      }),
                      unavailable.replacement == replacement,
                      replacement.id != channelID,
                      replacement.streamURL?.absoluteString == unavailable.streamURL,
                      state.favoriteRecoveryRequestIDs[channelID] == nil else { return .none }

                let requestID = UUID()
                state.favoriteRecoveryRequestIDs[channelID] = requestID
                let profileScope = profileContextClient.snapshot()
                let oldFavorite = FavoriteItem(
                    id: unavailable.channelID,
                    type: "live",
                    title: unavailable.title,
                    coverURL: unavailable.coverURL?.absoluteString,
                    streamURL: unavailable.streamURL,
                    playlistID: playlistID
                )
                let newFavorite = FavoriteItem(
                    id: replacement.id,
                    type: "live",
                    title: replacement.title,
                    coverURL: replacement.coverURL?.absoluteString,
                    streamURL: replacement.streamURL?.absoluteString,
                    playlistID: playlistID
                )
                return .run { send in
                    do {
                        let replacementIsFavorite = try await databaseClient.isFavorite(
                            replacement.id, "live", playlistID, profileScope
                        )
                        if !replacementIsFavorite {
                            let wasAdded = try await databaseClient.toggleFavorite(newFavorite, profileScope)
                            guard wasAdded else {
                                await send(.unavailableFavoriteRecoveryCompleted(
                                    channelID: channelID,
                                    replacement: replacement,
                                    playlistID: playlistID,
                                    profileScope: profileScope,
                                    requestID: requestID,
                                    succeeded: false
                                ))
                                return
                            }
                        }

                        let oldIsFavorite = try await databaseClient.isFavorite(
                            channelID, "live", playlistID, profileScope
                        )
                        if oldIsFavorite {
                            let remainedFavorite = try await databaseClient.toggleFavorite(oldFavorite, profileScope)
                            guard !remainedFavorite else {
                                await send(.unavailableFavoriteRecoveryCompleted(
                                    channelID: channelID,
                                    replacement: replacement,
                                    playlistID: playlistID,
                                    profileScope: profileScope,
                                    requestID: requestID,
                                    succeeded: false
                                ))
                                return
                            }
                        }

                        await send(.unavailableFavoriteRecoveryCompleted(
                            channelID: channelID,
                            replacement: replacement,
                            playlistID: playlistID,
                            profileScope: profileScope,
                            requestID: requestID,
                            succeeded: true
                        ))
                    } catch {
                        await send(.unavailableFavoriteRecoveryCompleted(
                            channelID: channelID,
                            replacement: replacement,
                            playlistID: playlistID,
                            profileScope: profileScope,
                            requestID: requestID,
                            succeeded: false
                        ))
                    }
                }

            case let .unavailableFavoriteRecoveryCompleted(channelID, replacement, playlistID, profileScope, requestID, succeeded):
                guard state.favoriteRecoveryRequestIDs[channelID] == requestID else { return .none }
                state.favoriteRecoveryRequestIDs.removeValue(forKey: channelID)
                guard state.config?.playlistID == playlistID,
                      state.isFavoriteListMode,
                      state.selectedFavoriteListID == nil,
                      profileContextClient.snapshot() == profileScope else { return .none }
                guard succeeded else {
                    state.bulkFavoriteNotice = AppStrings.LiveTV.favoriteRecoveryFailed
                    return .none
                }

                state.favoriteIDs.remove(channelID)
                state.favoriteIDs.insert(replacement.id)
                state.unavailableFavoriteChannels.removeAll { $0.channelID == channelID }
                if let index = state.favoriteListResolvedChannels.firstIndex(where: { $0.id == channelID }) {
                    state.favoriteListResolvedChannels[index] = replacement
                } else if !state.favoriteListResolvedChannels.contains(where: { $0.id == replacement.id }) {
                    state.favoriteListResolvedChannels.append(replacement)
                }
                let mappedOrderIDs = state.favoriteOrderIDs.map { $0 == channelID ? replacement.id : $0 }
                state.favoriteOrderIDs = FavoriteChannelSortMode.normalizedManualIDs(
                    favoriteIDs: state.favoriteIDs,
                    providerIDs: state.favoriteListResolvedChannels.map(\.id),
                    storedIDs: mappedOrderIDs
                )
                state.favoriteOrderRevision = nextLiveFavoriteOrderRevision(after: state.favoriteOrderRevision)
                let updatedOrder = FavoriteChannelOrderSnapshot(
                    mode: state.favoriteSortMode,
                    orderedIDs: state.favoriteOrderIDs,
                    revision: state.favoriteOrderRevision
                )
                state.syncEPGTimeline(
                    channels: state.favoriteListResolvedChannels,
                    selectedCategoryID: nil,
                    providerOrderChannels: state.favoriteListResolvedChannels
                )
                if var timeline = state.epgTimeline,
                   timeline.config.playlistID == playlistID,
                   timeline.favoriteListID == nil
                {
                    timeline.defaultFavoriteIDs = state.favoriteIDs
                    timeline.favoriteIDs = state.favoriteIDs
                    timeline.favoriteOrderIDs = state.favoriteOrderIDs
                    timeline.favoriteOrderRevision = state.favoriteOrderRevision
                    state.epgTimeline = timeline
                }
                state.bulkFavoriteNotice = AppStrings.LiveTV.favoriteRecoverySucceeded
                let orderClient = favoriteChannelOrderClient
                let profileID = profileScope.profileID
                return .run { _ in
                    await orderClient.save(updatedOrder, profileID, playlistID, nil)
                }

            case let .hideChannel(channel):
                guard !state.unavailableFavoriteChannelIDs.contains(channel.id) else { return .none }
                state.hiddenChannelIDs.insert(channel.id)
                return .run { _ in
                    parentalControlClient.hideChannel(channel.id, channel.title)
                    await hapticClient.notification(.warning)
                }

            case .unhideAllChannels:
                state.hiddenChannelIDs.removeAll()
                return .run { _ in
                    parentalControlClient.unhideAllChannels()
                    await hapticClient.notification(.success)
                }

            case let .sendToMultiView(channel):
                guard !state.unavailableFavoriteChannelIDs.contains(channel.id), channel.streamURL != nil else { return .none }
                var mvState = MultiViewFeature.State(channels: state.currentChannels, config: state.config)
                if !mvState.slots.isEmpty {
                    mvState.slots[0].item = channel
                }
                state.multiView = mvState
                return .run { _ in
                    await hapticClient.notification(.success)
                }

            case let .openChannelEPG(channel):
                guard !state.unavailableFavoriteChannelIDs.contains(channel.id) else { return .none }
                if let config = state.config {
                    let reordered = [channel] + state.currentChannels.filter { $0.id != channel.id }
                    state.epgTimeline = EPGTimelineFeature.State(
                        config: config,
                        channels: reordered,
                        providerOrderChannels: state.currentChannels,
                        categories: state.categories,
                        selectedCategoryID: channel.categoryID,
                        favoriteIDs: state.selectedFavoriteListChannelIDs.isEmpty && !state.isFavoriteListMode
                            ? state.favoriteIDs
                            : state.selectedFavoriteListChannelIDs,
                        favoriteListID: state.isFavoriteListMode ? state.selectedFavoriteListID : nil
                    )
                    state.selectedTabMode = .epg
                }
                return .none

            case let .openChannelGuide(channel):
                guard !state.unavailableFavoriteChannelIDs.contains(channel.id) else { return .none }
                if let config = state.config {
                    state.epgGuide = EPGGuideFeature.State(
                        config: config,
                        channels: state.currentChannels,
                        initialChannel: channel
                    )
                }
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .editCategoriesTapped:
                if let config = state.config {
                    state.categoryManagement = CategoryManagementFeature.State(config: config, type: .live)
                }
                return .none

            case .categoryManagement(.presented(.delegate(.categoriesUpdated))):
                return .send(.reloadPreferences)

            case .categoryManagement(.presented(.delegate(.m3uMappingsUpdated))):
                guard let config = state.config else { return .none }
                state.categories = []
                state.channelsByCategory = [:]
                state.selectedCategoryID = nil
                state.selectedChannel = nil
                return .send(.reloadCategories(config: config))

            case .categoryManagement(.presented(.delegate(.close))):
                state.categoryManagement = nil
                return .none

            case .categoryManagement:
                return .none

            case .epgGuideTapped:
                if let config = state.config, !state.currentChannels.isEmpty {
                    state.epgGuide = EPGGuideFeature.State(
                        config: config,
                        channels: state.currentChannels,
                        initialChannel: state.selectedChannel
                    )
                }
                return .none

            case .epgGuide(.presented(.delegate(.close))):
                state.epgGuide = nil
                return .none

            case let .epgGuide(.presented(.delegate(.playChannel(channel)))):
                state.epgGuide = nil
                return .send(.channelSelected(channel))

            case .epgGuide(.dismiss):
                return .run { [previewPlayerClient] _ in
                    await previewPlayerClient.stopPreview()
                }

            case .epgGuide:
                return .none

            case .openEPGTimelineTapped:
                return .send(.setTabMode(.epg))

            case let .setTabMode(mode):
                state.selectedTabMode = mode
                if mode == .epg, state.epgTimeline == nil {
                    if let config = state.config {
                        var allLoadedChannels = state.categories.flatMap { state.channelsByCategory[$0.id] ?? [] }
                        var seenChannelIDs = Set(allLoadedChannels.map(\.id))
                        for categoryID in state.channelsByCategory.keys.sorted() {
                            for channel in state.channelsByCategory[categoryID] ?? [] where seenChannelIDs.insert(channel.id).inserted {
                                allLoadedChannels.append(channel)
                            }
                        }
                        let channelsToUse = state.selectedSmartGroupID != nil
                            ? state.currentChannels
                            : (allLoadedChannels.isEmpty ? state.currentChannels : allLoadedChannels)
                        state.epgTimeline = EPGTimelineFeature.State(
                            config: config,
                            channels: channelsToUse,
                            providerOrderChannels: channelsToUse,
                            categories: state.categories,
                            selectedCategoryID: state.selectedCategoryID,
                            favoriteIDs: state.isFavoriteListMode ? state.selectedFavoriteListChannelIDs : state.favoriteIDs,
                            favoriteListID: state.isFavoriteListMode ? state.selectedFavoriteListID : nil
                        )
                    }
                } else if mode == .epg, state.epgTimeline != nil {
                    let channels = state.currentChannels
                    let selectedCategoryID = state.selectedSmartGroupID == nil ? state.selectedCategoryID : nil
                    state.syncEPGTimeline(channels: channels, selectedCategoryID: selectedCategoryID)
                }
                return .run { _ in await hapticClient.impact(.light) }

            case .epgTimeline(.presented(.delegate(.close))):
                state.epgTimeline = nil
                state.selectedTabMode = .channels
                return .none

            case let .epgTimeline(.presented(.delegate(.playChannel(channel)))):
                return .send(.channelSelected(channel))

            case let .epgTimeline(.presented(.delegate(.channelLogoOverrideChanged(channelID, playlistID, url)))):
                guard state.config?.playlistID == playlistID else { return .none }
                for categoryID in Array(state.channelsByCategory.keys) {
                    state.channelsByCategory[categoryID] = state.channelsByCategory[categoryID]?.map { channel in
                        channel.id == channelID ? channel.replacingLogoURLOverride(url) : channel
                    }
                }
                if state.selectedChannel?.id == channelID {
                    state.selectedChannel = state.selectedChannel?.replacingLogoURLOverride(url)
                }
                return .none

            case .epgTimeline:
                return .none

            case let .parentalLock(.presented(.delegate(.didUnlock(category, item)))):
                state.parentalLock = nil
                if let category {
                    let requestID = UUID()
                    let unlockedCategoryID = category.id
                    state.unlockedCategoryIDs.insert(unlockedCategoryID)
                    state.categoryUnlockRequestIDs[unlockedCategoryID] = requestID
                    let expirationEffect: Effect<Action> = .run { send in
                        try? await Task.sleep(nanoseconds: parentalCategoryUnlockDurationNanoseconds)
                        guard !Task.isCancelled else { return }
                        await send(.categoryUnlockExpired(categoryID: unlockedCategoryID, requestID: requestID))
                    }
                    .cancellable(id: "LiveTVFeature.categoryUnlock.\(unlockedCategoryID)", cancelInFlight: true)
                    state.selectedSmartGroupID = nil
                    state.activeSmartGroupRequestID = nil
                    state.smartGroupChannels = []
                    state.isLoadingChannels = false
                    // Proceed with category selection bypass
                    state.selectedCategoryID = category.id
                    state.isFavoriteListMode = false
                    state.selectedFavoriteListID = nil
                    state.favoriteListResolvedChannels = []
                    state.activeFavoriteListRequestID = nil
                    if var timeline = state.epgTimeline {
                        timeline.favoriteListID = nil
                        timeline.favoriteIDs = state.favoriteIDs
                        timeline.favoriteLoadRequestID = nil
                        timeline.channels = state.currentChannels
                        timeline.providerOrderChannels = state.currentChannels
                        timeline.selectedCategoryID = category.id
                        state.epgTimeline = timeline
                    }
                    let cancelGroupResolution = Effect<Action>.cancel(id: smartGroupResolutionCancellationID)
                    if state.channelsByCategory[category.id] != nil {
                        return .merge(cancelGroupResolution, expirationEffect)
                    }
                    guard let config = state.config else { return .merge(cancelGroupResolution, expirationEffect) }
                    state.isLoadingChannels = true
                    let categoryID = category.id
                    let contentRequestID = UUID()
                    state.categoryContentRequestIDs[categoryID] = contentRequestID
                    state.categoryContentErrors.removeValue(forKey: categoryID)
                    return .merge(
                        cancelGroupResolution,
                        expirationEffect,
                        .send(.fetchCategoryContent(requestID: contentRequestID, config: config, categoryID: categoryID))
                    )
                } else if let item {
                    state.selectedChannel = item
                    return .send(.delegate(.didSelectChannel(item, playlist: state.currentChannels)))
                }
                return .none

            case let .categoryUnlockExpired(categoryID, requestID):
                guard state.categoryUnlockRequestIDs[categoryID] == requestID else { return .none }
                state.categoryUnlockRequestIDs.removeValue(forKey: categoryID)
                state.unlockedCategoryIDs.remove(categoryID)
                state.channelsByCategory.removeValue(forKey: categoryID)
                state.favoriteListResolvedChannels.removeAll { $0.categoryID == categoryID }
                let selectedGroupContainsExpiredCategory = state.smartChannelGroups
                    .first(where: { $0.id == state.selectedSmartGroupID })?
                    .categoryIDs.contains(categoryID) == true
                if state.selectedCategoryID == categoryID || selectedGroupContainsExpiredCategory {
                    state.selectedCategoryID = nil
                    state.selectedSmartGroupID = nil
                    state.smartGroupChannels = []
                    if let category = state.categories.first(where: { $0.id == categoryID }) {
                        state.parentalLock = ParentalLockFeature.State(category: category)
                    }
                }
                if state.selectedChannel?.categoryID == categoryID {
                    state.selectedChannel = nil
                }
                if var timeline = state.epgTimeline, timeline.selectedCategoryID == categoryID {
                    timeline.channels = []
                    timeline.providerOrderChannels = []
                    timeline.selectedCategoryID = nil
                    state.epgTimeline = timeline
                }
                if var multiView = state.multiView {
                    multiView.channels.removeAll { $0.categoryID == categoryID }
                    for index in multiView.slots.indices where multiView.slots[index].item?.categoryID == categoryID {
                        multiView.slots[index].item = nil
                        multiView.slots[index].instanceID = UUID()
                    }
                    state.multiView = multiView
                }
                return .none

            case .parentalLock(.presented(.delegate(.didCancel))):
                state.parentalLock = nil
                return .none

            case .parentalLock:
                return .none

            case .openMultiViewTapped:
                state.multiView = MultiViewFeature.State(channels: state.currentChannels, config: state.config)
                return .none

            case .multiView(.presented(.delegate(.close))):
                state.multiView = nil
                return .none

            case .multiView:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$categoryManagement, action: \.categoryManagement) {
            CategoryManagementFeature()
        }
        .ifLet(\.$epgGuide, action: \.epgGuide) {
            EPGGuideFeature()
        }
        .ifLet(\.$epgTimeline, action: \.epgTimeline) {
            EPGTimelineFeature()
        }
        .ifLet(\.$parentalLock, action: \.parentalLock) {
            ParentalLockFeature()
        }
        .ifLet(\.$multiView, action: \.multiView) {
            MultiViewFeature()
        }
    }
}
