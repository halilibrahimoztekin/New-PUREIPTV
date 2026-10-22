import ComposableArchitecture
import FactoryKit
import Foundation

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
            guard let id = selectedCategoryID else { return [] }
            let all = channelsByCategory[id] ?? []
            return all.filter { !hiddenChannelIDs.contains($0.id) }
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case categoriesResponse(Result<[MediaModels.Category], Error>, preferences: [String: CategoryPreferenceDTO] = [:])
        case categorySelected(MediaModels.Category)
        case channelsResponse(categoryID: String, Result<[MediaModels.Item], Error>)
        case channelSelected(MediaModels.Item)
        case selectChannelPreview(MediaModels.Item)
        case channelEPGResponse(Result<[EPGProgram], Error>)
        case toggleFavorite(MediaModels.Item)
        case favoritesLoaded(Set<String>)
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
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.hapticClient) var hapticClient
    @Dependency(\.parentalControlClient) var parentalControlClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let parentalControlClient = parentalControlClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                state.hiddenChannelIDs = parentalControlClient.hiddenChannelIDs()

                let loadFavorites: Effect<Action> = .run { send in
                    let favs = await (try? databaseClient.fetchFavoritesByType("live")) ?? []
                    await send(.favoritesLoaded(Set(favs.map(\.id))))
                }

                guard !state.isLoadingCategories else { return loadFavorites }
                guard state.categories.isEmpty else { return loadFavorites } // Prevent re-fetching on view re-appear

                return .merge(loadFavorites, .send(.reloadCategories(config: config)))

            case let .reloadCategories(config):
                state.isLoadingCategories = true
                state.errorMessage = nil

                state.config = config
                let hideAdult = settingsClient.hideAdultContent()
                let isAdultContent = settingsClient.isAdultContent

                return .run { send in
                    async let categoriesResult = Result { try await iptvClient.fetchLiveCategories(config) }
                    async let prefsResult = Result { try await databaseClient.fetchCategoryPreferences(CategoryManagementFeature.State.CategoryType.live.rawValue) }

                    let categories = await (try? categoriesResult.get()) ?? []
                    let prefs = await (try? prefsResult.get()) ?? []

                    var dict: [String: CategoryPreferenceDTO] = [:]
                    for pref in prefs {
                        dict[pref.categoryID] = pref
                    }

                    // Filter and sort

                    let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                    let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]

                    var finalCategories = categories.filter { category in
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
                    finalCategories.sort { a, b in
                        let orderA = dict[a.id]?.orderIndex ?? Int.max
                        let orderB = dict[b.id]?.orderIndex ?? Int.max
                        if orderA == orderB {
                            return a.name < b.name
                        }
                        return orderA < orderB
                    }

                    await send(.categoriesResponse(.success(finalCategories), preferences: dict))
                } catch: { error, send in
                    await send(.categoriesResponse(.failure(error), preferences: [:]))
                }

            case .reloadPreferences:
                let currentCats = state.categories
                let hideAdult = settingsClient.hideAdultContent()
                let isAdultContent = settingsClient.isAdultContent
                return .run { send in
                    let prefs = await (try? databaseClient.fetchCategoryPreferences(CategoryManagementFeature.State.CategoryType.live.rawValue)) ?? []
                    var dict: [String: CategoryPreferenceDTO] = [:]
                    for pref in prefs {
                        dict[pref.categoryID] = pref
                    }

                    let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                    let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]

                    var finalCategories = currentCats.filter { category in
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
                    finalCategories.sort { a, b in
                        let orderA = dict[a.id]?.orderIndex ?? Int.max
                        let orderB = dict[b.id]?.orderIndex ?? Int.max
                        if orderA == orderB {
                            return a.name < b.name
                        }
                        return orderA < orderB
                    }

                    await send(.categoriesResponse(.success(finalCategories), preferences: dict))
                }

            case let .categoriesResponse(.success(categories), preferences):
                state.isLoadingCategories = false
                state.categoryPreferences = preferences
                state.categories = categories
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

                state.selectedCategoryID = category.id
                // If channels are already cached, skip fetching
                if state.channelsByCategory[category.id] != nil {
                    return .run { _ in await hapticClient.selection() }
                }
                guard let config = state.config else { return .none }

                state.isLoadingChannels = true
                let categoryID = category.id

                return .run { send in
                    await hapticClient.selection()
                    await send(.channelsResponse(
                        categoryID: categoryID,
                        Result { try await iptvClient.fetchLiveChannels(config, categoryID) }
                    ))
                }

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

            case let .favoritesLoaded(favIDs):
                state.favoriteIDs = favIDs
                return .none

            case let .toggleFavorite(item):
                let favItem = FavoriteItem(
                    id: item.id,
                    type: "live",
                    title: item.title,
                    coverURL: item.coverURL?.absoluteString,
                    streamURL: item.streamURL?.absoluteString
                )
                let isCurrentlyFav = state.favoriteIDs.contains(item.id)
                if isCurrentlyFav {
                    state.favoriteIDs.remove(item.id)
                } else {
                    state.favoriteIDs.insert(item.id)
                }
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(favItem)
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
                var mvState = MultiViewFeature.State(channels: state.currentChannels)
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
                        let allLoadedChannels = Array(state.channelsByCategory.values.joined())
                        let channelsToUse = allLoadedChannels.isEmpty ? state.currentChannels : allLoadedChannels
                        state.epgTimeline = EPGTimelineFeature.State(
                            config: config,
                            channels: channelsToUse,
                            categories: state.categories,
                            selectedCategoryID: state.selectedCategoryID,
                            favoriteIDs: state.favoriteIDs
                        )
                    }
                }
                return .run { _ in await hapticClient.impact(.light) }

            case .epgTimeline(.presented(.delegate(.close))):
                state.epgTimeline = nil
                state.selectedTabMode = .channels
                return .none

            case let .epgTimeline(.presented(.delegate(.playChannel(channel)))):
                return .send(.channelSelected(channel))

            case .epgTimeline:
                return .none

            case let .parentalLock(.presented(.delegate(.didUnlock(category, item)))):
                state.parentalLock = nil
                if let category {
                    state.unlockedCategoryIDs.insert(category.id)
                    // Proceed with category selection bypass
                    state.selectedCategoryID = category.id
                    if state.channelsByCategory[category.id] != nil {
                        return .none
                    }
                    guard let config = state.config else { return .none }
                    state.isLoadingChannels = true
                    let categoryID = category.id
                    return .run { send in
                        await send(.channelsResponse(
                            categoryID: categoryID,
                            Result { try await iptvClient.fetchLiveChannels(config, categoryID) }
                        ))
                    }
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
                state.multiView = MultiViewFeature.State(channels: state.currentChannels)
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
