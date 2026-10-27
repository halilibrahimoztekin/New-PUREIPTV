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
        public var categoryContentRequestIDs: [String: UUID] = [:]
        public var categoryContentErrors: [String: String] = [:]
        public var isRefreshingContent = false
        public var activeContentRefreshID: UUID?
        public var refreshMessage: String?
        public var errorMessage: String?
        public var favoriteIDs: Set<String> = []
        public var lastSortMethod: SortMethod = .defaultOrder
        public var categoryPreferences: [String: CategoryPreferenceDTO] = [:]
        public private(set) var derivedData = MediaLibraryDerivedData()
        public var unlockedCategoryIDs: Set<String> = []
        public var categoryUnlockRequestIDs: [String: UUID] = [:]
        public var categoryUnlockProfileScope: ProfileContextSnapshot?
        public var categoryUnlockPlaylistID: UUID?

        @Presents public var categoryManagement: CategoryManagementFeature.State?
        @Presents public var parentalLock: ParentalLockFeature.State?

        /// Language & Audio Filter
        public var selectedLanguageFilter: MediaLanguageFilter = .all
        public var selectedOriginalLanguageCode: String?

        public var rawVODs: [MediaModels.Item] {
            guard let id = selectedCategoryID else { return [] }
            return vodsByCategory[id] ?? []
        }

        public var availableLanguageFilters: [MediaLanguageFilter] {
            derivedData.availableLanguageFilters
        }

        public var availableOriginalLanguageCodes: [String] {
            derivedData.availableOriginalLanguageCodes
        }

        public var originalLanguageCounts: [String: Int] {
            derivedData.originalLanguageCounts
        }

        public var languageFilterCounts: [MediaLanguageFilter: Int] {
            derivedData.languageFilterCounts
        }

        public var currentVODs: [MediaModels.Item] {
            derivedData.items
        }

        public var availableLetters: Set<String> {
            derivedData.availableLetters
        }

        public mutating func rebuildDerivedData() {
            derivedData.rebuild(
                from: rawVODs,
                languageFilter: selectedLanguageFilter,
                originalLanguageCode: selectedOriginalLanguageCode,
                sortMethod: lastSortMethod
            )
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case categoriesResponse(Result<[MediaModels.Category], Error>, preferences: [String: CategoryPreferenceDTO] = [:])
        case categorySelected(MediaModels.Category)
        case categoryUnlockExpired(categoryID: String, requestID: UUID)
        case fetchCategoryContent(requestID: UUID, config: PlaylistConfig, categoryID: String)
        case retryCategoryContent(categoryID: String)
        case vodsResponse(requestID: UUID, config: PlaylistConfig, categoryID: String, Result<[MediaModels.Item], Error>)
        case vodSelected(MediaModels.Item)
        case setLanguageFilter(MediaLanguageFilter)
        case setOriginalLanguageFilter(String?)
        case toggleFavorite(MediaModels.Item)
        case favoritesLoaded(Set<String>, ProfileContextSnapshot)
        case dismissError
        case reloadCategories(config: PlaylistConfig)
        case refreshContentTapped
        case contentRefreshSucceeded(requestID: UUID, config: PlaylistConfig)
        case contentRefreshFailed(requestID: UUID, config: PlaylistConfig, message: String)
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
                let configChanged = state.config != config
                let playlistChanged = state.config?.playlistID != config.playlistID
                if configChanged {
                    state.categoryContentRequestIDs = [:]
                    state.categoryContentErrors = [:]
                    state.isLoadingVODs = false
                }
                if playlistChanged {
                    state.categories = []
                    state.vodsByCategory = [:]
                    state.selectedCategoryID = nil
                    state.selectedVOD = nil
                    state.isLoadingCategories = false
                    state.errorMessage = nil
                }
                state.config = config
                let profileScope = profileContextClient.snapshot()
                let categoryAccessScopeChanged = state.categoryUnlockPlaylistID != config.playlistID
                    || state.categoryUnlockProfileScope != profileScope
                if categoryAccessScopeChanged {
                    state.unlockedCategoryIDs = []
                    state.categoryUnlockRequestIDs = [:]
                    state.selectedCategoryID = nil
                    state.selectedVOD = nil
                }
                state.categoryUnlockPlaylistID = config.playlistID
                state.categoryUnlockProfileScope = profileScope
                state.selectedOriginalLanguageCode = OriginalLanguageFilterPreference.load(
                    profileID: profileScope.profileID,
                    library: .movies
                )
                state.lastSortMethod = settingsClient.getVODSortMethod()
                state.rebuildDerivedData()
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

            case .refreshContentTapped:
                guard !state.isRefreshingContent,
                      !state.isLoadingCategories,
                      let config = state.config,
                      [PlaylistType.m3u, .plex, .emby].contains(config.type),
                      state.selectedCategoryID != nil
                else { return .none }
                let requestID = UUID()
                state.activeContentRefreshID = requestID
                state.isRefreshingContent = true
                state.refreshMessage = nil
                return .run { send in
                    do {
                        try await iptvClient.refreshContent(config, .movies) { _ in }
                        await send(.contentRefreshSucceeded(requestID: requestID, config: config))
                    } catch is CancellationError {
                        return
                    } catch {
                        await send(.contentRefreshFailed(requestID: requestID, config: config, message: error.localizedDescription))
                    }
                }.cancellable(id: "VODFeature.refreshContent", cancelInFlight: true)

            case let .contentRefreshSucceeded(requestID, config):
                guard state.activeContentRefreshID == requestID else { return .none }
                state.activeContentRefreshID = nil
                state.isRefreshingContent = false
                guard state.config == config, state.selectedCategoryID != nil else { return .none }
                state.vodsByCategory.removeAll(keepingCapacity: true)
                return .send(.reloadCategories(config: config))

            case let .contentRefreshFailed(requestID, config, message):
                guard state.activeContentRefreshID == requestID else { return .none }
                state.activeContentRefreshID = nil
                state.isRefreshingContent = false
                guard state.config == config else { return .none }
                state.refreshMessage = "Yenileme başarısız; mevcut film kataloğu korundu. \(message)"
                return .none

            case .applySortIfChanged:
                let currentMethod = settingsClient.getVODSortMethod()
                if state.lastSortMethod != currentMethod {
                    state.lastSortMethod = currentMethod
                    state.rebuildDerivedData()
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
                    state.rebuildDerivedData()
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

                state.isLoadingVODs = false
                state.selectedCategoryID = category.id
                state.rebuildDerivedData()
                if !state.availableLanguageFilters.contains(state.selectedLanguageFilter) {
                    state.selectedLanguageFilter = .all
                    state.rebuildDerivedData()
                }
                if state.vodsByCategory[category.id] != nil {
                    return .run { _ in await hapticClient.selection() }
                }
                if state.categoryContentRequestIDs[category.id] != nil {
                    state.isLoadingVODs = true
                    return .run { _ in await hapticClient.selection() }
                }
                if state.categoryContentErrors[category.id] != nil {
                    return .run { _ in await hapticClient.selection() }
                }
                guard let config = state.config else { return .none }

                let requestID = UUID()
                state.categoryContentRequestIDs[category.id] = requestID
                state.isLoadingVODs = true
                let categoryID = category.id
                return .merge(
                    .run { _ in await hapticClient.selection() },
                    .send(.fetchCategoryContent(requestID: requestID, config: config, categoryID: categoryID))
                )

            case let .retryCategoryContent(categoryID):
                guard state.selectedCategoryID == categoryID, let config = state.config else { return .none }
                guard state.categoryContentRequestIDs[categoryID] == nil else { return .none }
                let requestID = UUID()
                state.categoryContentRequestIDs[categoryID] = requestID
                state.categoryContentErrors.removeValue(forKey: categoryID)
                state.isLoadingVODs = true
                return .send(.fetchCategoryContent(requestID: requestID, config: config, categoryID: categoryID))

            case let .fetchCategoryContent(requestID, config, categoryID):
                guard state.categoryContentRequestIDs[categoryID] == requestID,
                      state.config == config
                else { return .none }
                return .run { send in
                    let result = await Result { try await iptvClient.fetchVODs(config, categoryID) }
                    await send(.vodsResponse(requestID: requestID, config: config, categoryID: categoryID, result))
                }

            case let .setLanguageFilter(filter):
                state.selectedLanguageFilter = filter
                state.rebuildDerivedData()
                return .run { _ in await hapticClient.selection() }

            case let .setOriginalLanguageFilter(code):
                let normalized = ISO639LanguageCode.normalize(code)
                state.selectedOriginalLanguageCode = normalized
                state.rebuildDerivedData()
                OriginalLanguageFilterPreference.save(normalized, profileID: profileContextClient.snapshot().profileID, library: .movies)
                return .run { _ in await hapticClient.selection() }

            case let .vodsResponse(requestID, config, categoryID, .success(vods)):
                guard state.categoryContentRequestIDs[categoryID] == requestID,
                      state.config == config
                else { return .none }
                state.categoryContentRequestIDs.removeValue(forKey: categoryID)
                if state.selectedCategoryID == categoryID {
                    state.isLoadingVODs = false
                }
                state.categoryContentErrors.removeValue(forKey: categoryID)
                state.vodsByCategory[categoryID] = vods
                if state.selectedCategoryID == categoryID {
                    state.rebuildDerivedData()
                }
                return .none

            case let .vodsResponse(requestID, config, categoryID, .failure(error)):
                guard state.categoryContentRequestIDs[categoryID] == requestID,
                      state.config == config
                else { return .none }
                state.categoryContentRequestIDs.removeValue(forKey: categoryID)
                if state.selectedCategoryID == categoryID {
                    state.isLoadingVODs = false
                }
                state.categoryContentErrors[categoryID] = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
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
                    let requestID = UUID()
                    let unlockedCategoryID = category.id
                    state.unlockedCategoryIDs.insert(unlockedCategoryID)
                    state.categoryUnlockRequestIDs[unlockedCategoryID] = requestID
                    let expirationEffect: Effect<Action> = .run { send in
                        try? await Task.sleep(nanoseconds: parentalCategoryUnlockDurationNanoseconds)
                        guard !Task.isCancelled else { return }
                        await send(.categoryUnlockExpired(categoryID: unlockedCategoryID, requestID: requestID))
                    }
                    .cancellable(id: "VODFeature.categoryUnlock.\(unlockedCategoryID)", cancelInFlight: true)
                    state.selectedCategoryID = category.id
                    state.rebuildDerivedData()
                    if !state.availableLanguageFilters.contains(state.selectedLanguageFilter) {
                        state.selectedLanguageFilter = .all
                        state.rebuildDerivedData()
                    }
                    if state.vodsByCategory[category.id] != nil {
                        return expirationEffect
                    }
                    guard let config = state.config else { return expirationEffect }
                    state.isLoadingVODs = true
                    let categoryID = category.id
                    let contentRequestID = UUID()
                    state.categoryContentRequestIDs[categoryID] = contentRequestID
                    state.categoryContentErrors.removeValue(forKey: categoryID)
                    return .merge(
                        expirationEffect,
                        .send(.fetchCategoryContent(requestID: contentRequestID, config: config, categoryID: categoryID))
                    )
                } else if let item {
                    state.selectedVOD = item
                    return .send(.delegate(.didSelectVOD(item)))
                }
                return .none

            case let .categoryUnlockExpired(categoryID, requestID):
                guard state.categoryUnlockRequestIDs[categoryID] == requestID else { return .none }
                state.categoryUnlockRequestIDs.removeValue(forKey: categoryID)
                state.unlockedCategoryIDs.remove(categoryID)
                if state.selectedCategoryID == categoryID {
                    state.selectedCategoryID = nil
                    state.rebuildDerivedData()
                    if let category = state.categories.first(where: { $0.id == categoryID }) {
                        state.parentalLock = ParentalLockFeature.State(category: category)
                    }
                }
                if state.selectedVOD?.categoryID == categoryID {
                    state.selectedVOD = nil
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
