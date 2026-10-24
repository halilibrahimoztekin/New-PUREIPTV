import ComposableArchitecture
import FactoryKit
import Foundation

private let smartGroupResolutionCancellationID = "LiveTVFeature.smartGroupResolution"

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
        public var errorMessage: String?
        public var favoriteIDs: Set<String> = []
        public var hiddenChannelIDs: Set<String> = []
        public var categoryPreferences: [String: CategoryPreferenceDTO] = [:]
        public var unlockedCategoryIDs: Set<String> = []
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

        mutating func syncEPGTimeline(channels: [MediaModels.Item], selectedCategoryID: String?) {
            guard var timeline = epgTimeline else { return }
            timeline.channels = channels
            timeline.providerOrderChannels = channels
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
        case categoriesResponse(Result<[MediaModels.Category], Error>, preferences: [String: CategoryPreferenceDTO] = [:])
        case categorySelected(MediaModels.Category)
        case smartGroupSelected(String)
        case smartGroupsLoaded(SmartChannelGroupSnapshot, playlistID: UUID?, profileScope: ProfileContextSnapshot, requestID: UUID)
        case smartGroupChannelsLoaded(groupID: String, playlistID: UUID?, profileScope: ProfileContextSnapshot, hideAdult: Bool, requestID: UUID, Result<[MediaModels.Item], Error>)
        case saveSmartChannelGroup(id: String?, name: String, categoryIDs: [String])
        case deleteSmartChannelGroup(String)
        case channelsResponse(categoryID: String, Result<[MediaModels.Item], Error>)
        case channelSelected(MediaModels.Item)
        case selectChannelPreview(MediaModels.Item)
        case channelEPGResponse(Result<[EPGProgram], Error>)
        case toggleFavorite(MediaModels.Item)
        case favoritesLoaded(Set<String>, ProfileContextSnapshot)
        case hideChannel(MediaModels.Item)
        case unhideAllChannels
        case sendToMultiView(MediaModels.Item)
        case openChannelEPG(MediaModels.Item)
        case openChannelGuide(MediaModels.Item)
        case dismissError
        case reloadCategories(config: PlaylistConfig)
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

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let parentalControlClient = parentalControlClient
        let smartChannelGroupClient = smartChannelGroupClient

        let profileContextClient = profileContextClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                let playlistChanged = state.config?.playlistID != config.playlistID
                let profileScope = profileContextClient.snapshot()
                state.config = config
                if playlistChanged {
                    state.categories = []
                    state.channelsByCategory = [:]
                    state.selectedCategoryID = nil
                    state.selectedChannel = nil
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

                let loadFavorites: Effect<Action> = .run { send in
                    let favs = await (try? databaseClient.fetchFavoritesByType("live", profileScope)) ?? []
                    let visible = favs.filter { $0.playlistID == config.playlistID && config.playlistID != nil }
                    await send(.favoritesLoaded(Set(visible.map(\.id)), profileScope))
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

                guard !state.isLoadingCategories else { return .merge(loadFavorites, groupLoadEffect, cancelPreviousGroupResolution, refreshSelectedGroup) }
                guard state.categories.isEmpty else { return .merge(loadFavorites, groupLoadEffect, cancelPreviousGroupResolution, refreshSelectedGroup) } // Prevent re-fetching on view re-appear

                return .merge(loadFavorites, groupLoadEffect, cancelPreviousGroupResolution, refreshSelectedGroup, .send(.reloadCategories(config: config)))

            case .onDisappear:
                state.activeSmartGroupRequestID = nil
                state.isLoadingChannels = false
                return .cancel(id: smartGroupResolutionCancellationID)

            case let .reloadCategories(config):
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

                    await send(.categoriesResponse(.success(finalCategories.map(\.element)), preferences: dict))
                } catch: { error, send in
                    await send(.categoriesResponse(.failure(error), preferences: [:]))
                }

            case .reloadPreferences:
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

                    await send(.categoriesResponse(.success(finalCategories.map(\.element)), preferences: dict))
                }

            case let .categoriesResponse(.success(categories), preferences):
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
                // Auto-select first category if current selection is invalid or nil
                if let currentID = state.selectedCategoryID, let current = categories.first(where: { $0.id == currentID }) {
                    return .send(.categorySelected(current))
                } else if let first = categories.first {
                    state.selectedCategoryID = first.id
                    return .send(.categorySelected(first))
                }
                return .none

            case let .categoriesResponse(.failure(error), _):
                state.isLoadingCategories = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .categorySelected(category):
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
                let cancelGroupResolution = Effect<Action>.cancel(id: smartGroupResolutionCancellationID)
                // If channels are already cached, skip fetching
                if state.channelsByCategory[category.id] != nil {
                    return .merge(cancelGroupResolution, .run { _ in await hapticClient.selection() })
                }
                guard let config = state.config else { return cancelGroupResolution }

                state.isLoadingChannels = true
                let categoryID = category.id

                return .merge(
                    cancelGroupResolution,
                    .run { send in
                        await hapticClient.selection()
                        await send(.channelsResponse(
                            categoryID: categoryID,
                            Result { try await iptvClient.fetchLiveChannels(config, categoryID) }
                        ))
                    }
                )

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
                state.selectedSmartGroupID = groupID
                state.selectedCategoryID = nil
                state.selectedChannel = nil
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

            case let .channelsResponse(categoryID, .success(channels)):
                state.isLoadingChannels = false
                state.channelsByCategory[categoryID] = channels
                if state.selectedTabMode == .epg, let epg = state.epgTimeline, epg.channels.isEmpty {
                    state.epgTimeline?.channels = channels
                }
                return .none

            case let .channelsResponse(_, .failure(error)):
                state.isLoadingChannels = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .channelSelected(channel):
                state.selectedChannel = channel
                return .merge(
                    .run { _ in await hapticClient.impact(.light) },
                    .send(.delegate(.didSelectChannel(channel, playlist: state.currentChannels)))
                )

            case let .selectChannelPreview(channel):
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

            case let .favoritesLoaded(favIDs, scope):
                guard profileContextClient.snapshot() == scope else { return .none }
                state.favoriteIDs = favIDs
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
                } else {
                    state.favoriteIDs.insert(item.id)
                }
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(favItem, profileScope)
                    await hapticClient.notification(.success)
                }

            case let .hideChannel(channel):
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
                var mvState = MultiViewFeature.State(channels: state.currentChannels, config: state.config)
                if !mvState.slots.isEmpty {
                    mvState.slots[0].item = channel
                }
                state.multiView = mvState
                return .run { _ in
                    await hapticClient.notification(.success)
                }

            case let .openChannelEPG(channel):
                if let config = state.config {
                    let reordered = [channel] + state.currentChannels.filter { $0.id != channel.id }
                    state.epgTimeline = EPGTimelineFeature.State(
                        config: config,
                        channels: reordered,
                        providerOrderChannels: state.currentChannels,
                        categories: state.categories,
                        selectedCategoryID: channel.categoryID,
                        favoriteIDs: state.favoriteIDs
                    )
                    state.selectedTabMode = .epg
                }
                return .none

            case let .openChannelGuide(channel):
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
                            favoriteIDs: state.favoriteIDs
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
                    state.unlockedCategoryIDs.insert(category.id)
                    state.selectedSmartGroupID = nil
                    state.activeSmartGroupRequestID = nil
                    state.smartGroupChannels = []
                    state.isLoadingChannels = false
                    // Proceed with category selection bypass
                    state.selectedCategoryID = category.id
                    let cancelGroupResolution = Effect<Action>.cancel(id: smartGroupResolutionCancellationID)
                    if state.channelsByCategory[category.id] != nil {
                        return cancelGroupResolution
                    }
                    guard let config = state.config else { return cancelGroupResolution }
                    state.isLoadingChannels = true
                    let categoryID = category.id
                    return .merge(
                        cancelGroupResolution,
                        .run { send in
                            await send(.channelsResponse(
                                categoryID: categoryID,
                                Result { try await iptvClient.fetchLiveChannels(config, categoryID) }
                            ))
                        }
                    )
                } else if let item {
                    state.selectedChannel = item
                    return .send(.delegate(.didSelectChannel(item, playlist: state.currentChannels)))
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
