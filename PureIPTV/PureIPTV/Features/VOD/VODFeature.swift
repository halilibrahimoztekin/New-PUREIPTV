import ComposableArchitecture
import FactoryKit
import Foundation

// MARK: - VODFeature

@Reducer
public struct VODFeature {
    @ObservableState
    public struct State: Equatable {
        // Data
        public var categories: [MediaModels.Category] = []
        public var vodsByCategory: [String: [MediaModels.Item]] = [:]

        /// Server Info
        public var config: PlaylistConfig?

        // UI state
        public var selectedCategoryID: String?
        public var selectedVOD: MediaModels.Item?
        public var isLoadingCategories = false
        public var isLoadingVODs = false
        public var errorMessage: String?
        public var favoriteIDs: Set<String> = []
        public var lastSortMethod: SortMethod = .defaultOrder
        public var categoryPreferences: [String: CategoryPreferenceDTO] = [:]
        public var unlockedCategoryIDs: Set<String> = []

        @Presents public var categoryManagement: CategoryManagementFeature.State?
        @Presents public var parentalLock: ParentalLockFeature.State?

        /// Language & Audio Filter
        public var selectedLanguageFilter: MediaLanguageFilter = .all

        public var rawVODs: [MediaModels.Item] {
            guard let id = selectedCategoryID else { return [] }
            return vodsByCategory[id] ?? []
        }

        public var availableLanguageFilters: [MediaLanguageFilter] {
            MediaLanguageDetector.availableFilters(for: rawVODs)
        }

        public var languageFilterCounts: [MediaLanguageFilter: Int] {
            var counts: [MediaLanguageFilter: Int] = [:]
            for filter in MediaLanguageFilter.allCases {
                counts[filter] = MediaLanguageDetector.count(for: filter, in: rawVODs)
            }
            return counts
        }

        // Computed: vods for the currently selected category and language filter
        public var currentVODs: [MediaModels.Item] {
            let filtered = rawVODs.filter { MediaLanguageDetector.matches(title: $0.title, filter: selectedLanguageFilter) }

            switch lastSortMethod {
            case .alphabetical:
                return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .rating:
                return filtered.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
            case .dateAdded:
                return filtered.sorted { ($0.addedDate ?? .distantPast) > ($1.addedDate ?? .distantPast) }
            case .defaultOrder:
                return filtered
            }
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case categoriesResponse(Result<[MediaModels.Category], Error>, preferences: [String: CategoryPreferenceDTO] = [:])
        case categorySelected(MediaModels.Category)
        case vodsResponse(categoryID: String, Result<[MediaModels.Item], Error>)
        case vodSelected(MediaModels.Item)
        case setLanguageFilter(MediaLanguageFilter)
        case toggleFavorite(MediaModels.Item)
        case favoritesLoaded(Set<String>, ProfileContextSnapshot)
        case dismissError
        case reloadCategories(config: PlaylistConfig)
        case reloadPreferences
        case applySortIfChanged
        case editCategoriesTapped
        case categoryManagement(PresentationAction<CategoryManagementFeature.Action>)
        case parentalLock(PresentationAction<ParentalLockFeature.Action>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectVOD(MediaModels.Item)
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.hapticClient) var hapticClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient

        let profileContextClient = profileContextClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                let profileScope = profileContextClient.snapshot()
                state.lastSortMethod = settingsClient.getVODSortMethod()
                let loadFavorites: Effect<Action> = .run { send in
                    let favs = await (try? databaseClient.fetchFavoritesByType("vod", profileScope)) ?? []
                    let visible = favs.filter { $0.playlistID == config.playlistID || $0.playlistID == nil }
                    await send(.favoritesLoaded(Set(visible.map(\.id)), profileScope))
                }

                guard !state.isLoadingCategories else { return loadFavorites }
                guard state.categories.isEmpty else { return loadFavorites }

                return .merge(loadFavorites, .send(.reloadCategories(config: config)))

            case let .reloadCategories(config):
                state.isLoadingCategories = state.categories.isEmpty
                state.errorMessage = nil
                state.config = config
                let existingPreferences = state.categoryPreferences
                let hideAdult = settingsClient.hideAdultContent()
                let isAdultContent = settingsClient.isAdultContent
                return .run { send in
                    async let categoriesResult = Result { try await iptvClient.fetchVODCategories(config) }
                    async let prefsResult = Result { try await databaseClient.fetchCategoryPreferences(CategoryManagementFeature.State.CategoryType.vod.rawValue) }

                    let categories = try await categoriesResult.get()
                    // Retain the last applied category policy during a
                    // transient persistence read failure.
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
                        prefs = try await databaseClient.fetchCategoryPreferences(CategoryManagementFeature.State.CategoryType.vod.rawValue)
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

            case .applySortIfChanged:
                let currentMethod = settingsClient.getVODSortMethod()
                if state.lastSortMethod != currentMethod {
                    state.lastSortMethod = currentMethod
                }
                return .none

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
                if !state.availableLanguageFilters.contains(state.selectedLanguageFilter) {
                    state.selectedLanguageFilter = .all
                }
                if state.vodsByCategory[category.id] != nil {
                    return .run { _ in await hapticClient.selection() }
                }
                guard let config = state.config else { return .none }

                state.isLoadingVODs = true
                let categoryID = category.id

                return .run { send in
                    await hapticClient.selection()
                    await send(.vodsResponse(
                        categoryID: categoryID,
                        Result { try await iptvClient.fetchVODs(config, categoryID) }
                    ))
                }

            case let .setLanguageFilter(filter):
                state.selectedLanguageFilter = filter
                return .run { _ in await hapticClient.selection() }

            case let .vodsResponse(categoryID, .success(vods)):
                state.isLoadingVODs = false
                state.vodsByCategory[categoryID] = vods
                return .none

            case let .vodsResponse(_, .failure(error)):
                state.isLoadingVODs = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .vodSelected(vod):
                state.selectedVOD = vod
                return .merge(
                    .run { _ in await hapticClient.impact(.light) },
                    .send(.delegate(.didSelectVOD(vod)))
                )

            case let .favoritesLoaded(favIDs, scope):
                guard profileContextClient.snapshot() == scope else { return .none }
                state.favoriteIDs = favIDs
                return .none

            case let .toggleFavorite(item):
                let profileScope = profileContextClient.snapshot()
                let playlistID = state.config?.playlistID
                let favItem = FavoriteItem(
                    id: item.id,
                    type: "vod",
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

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .editCategoriesTapped:
                if let config = state.config {
                    state.categoryManagement = CategoryManagementFeature.State(config: config, type: .vod)
                }
                return .none

            case .categoryManagement(.presented(.delegate(.categoriesUpdated))):
                return .send(.reloadPreferences)

            case .categoryManagement(.presented(.delegate(.close))):
                state.categoryManagement = nil
                return .none

            case .categoryManagement:
                return .none

            case let .parentalLock(.presented(.delegate(.didUnlock(category, item)))):
                state.parentalLock = nil
                if let category {
                    state.unlockedCategoryIDs.insert(category.id)
                    state.selectedCategoryID = category.id
                    if state.vodsByCategory[category.id] != nil {
                        return .none
                    }
                    guard let config = state.config else { return .none }
                    state.isLoadingVODs = true
                    let categoryID = category.id
                    return .run { send in
                        await send(.vodsResponse(
                            categoryID: categoryID,
                            Result { try await iptvClient.fetchVODs(config, categoryID) }
                        ))
                    }
                } else if let item {
                    state.selectedVOD = item
                    return .send(.delegate(.didSelectVOD(item)))
                }
                return .none

            case .parentalLock(.presented(.delegate(.didCancel))):
                state.parentalLock = nil
                return .none

            case .parentalLock:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$categoryManagement, action: \.categoryManagement) {
            CategoryManagementFeature()
        }
        .ifLet(\.$parentalLock, action: \.parentalLock) {
            ParentalLockFeature()
        }
    }
}
