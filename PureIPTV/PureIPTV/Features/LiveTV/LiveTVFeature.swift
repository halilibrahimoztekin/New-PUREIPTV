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

        @Presents public var categoryManagement: CategoryManagementFeature.State?
        @Presents public var epgGuide: EPGGuideFeature.State?
        @Presents public var epgTimeline: EPGTimelineFeature.State?
        @Presents public var parentalLock: ParentalLockFeature.State?
        @Presents public var multiView: MultiViewFeature.State?

        // Computed: channels for the currently selected category
        public var currentChannels: [MediaModels.Item] {
            guard let id = selectedCategoryID else { return [] }
            return channelsByCategory[id] ?? []
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case categoriesResponse(Result<[MediaModels.Category], Error>)
        case categorySelected(MediaModels.Category)
        case channelsResponse(categoryID: String, Result<[MediaModels.Item], Error>)
        case channelSelected(MediaModels.Item)
        case toggleFavorite(MediaModels.Item)
        case favoritesLoaded(Set<String>)
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
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item, playlist: [MediaModels.Item]?)
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.hapticClient) var hapticClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
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

                    let hideAdult = settingsClient.hideAdultContent()
                    var finalCategories = categories.filter { category in
                        if hideAdult, settingsClient.isAdultContent(category.name) {
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

                    await send(.categoriesResponse(.success(finalCategories)))
                } catch: { error, send in
                    await send(.categoriesResponse(.failure(error)))
                }

            case .reloadPreferences:
                let currentCats = state.categories
                return .run { send in
                    let prefs = await (try? databaseClient.fetchCategoryPreferences(CategoryManagementFeature.State.CategoryType.live.rawValue)) ?? []
                    var dict: [String: CategoryPreferenceDTO] = [:]
                    for pref in prefs {
                        dict[pref.categoryID] = pref
                    }

                    let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                    let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]

                    let hideAdult = settingsClient.hideAdultContent()
                    var finalCategories = currentCats.filter { category in
                        if hideAdult, settingsClient.isAdultContent(category.name) {
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

                    await send(.categoriesResponse(.success(finalCategories)))
                }

            case let .categoriesResponse(.success(categories)):
                state.isLoadingCategories = false
                state.categories = categories
                // Auto-select first category
                if let first = categories.first {
                    state.selectedCategoryID = first.id
                    return .send(.categorySelected(first))
                }
                return .none

            case let .categoriesResponse(.failure(error)):
                state.isLoadingCategories = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .categorySelected(category):
                if settingsClient.isParentalControlEnabled(), settingsClient.isAdultContent(category.name) {
                    // Check if already unlocked? For MVP, just prompt always or we can use a session variable.
                    // For now, always prompt on category select if adult.
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
                if let config = state.config, !state.currentChannels.isEmpty {
                    state.epgTimeline = EPGTimelineFeature.State(config: config, channels: state.currentChannels)
                }
                return .none

            case .epgTimeline(.presented(.delegate(.close))):
                state.epgTimeline = nil
                return .none

            case let .epgTimeline(.presented(.delegate(.playChannel(channel)))):
                state.epgTimeline = nil
                return .send(.channelSelected(channel))

            case .epgTimeline:
                return .none

            case let .parentalLock(.presented(.delegate(.didUnlock(category, item)))):
                state.parentalLock = nil
                if let category {
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
