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
        public var hasResolvedCategories = false
        public var activeCategoryRequestID: UUID?
        public var isLoadingVODs = false
        public var categoryContentRequestIDs: [String: UUID] = [:]
        public var categoryContentErrors: [String: String] = [:]
        public var isRefreshingContent = false
        public var activeContentRefreshID: UUID?
        public var refreshMessage: String?
        public var errorMessage: String?
        public var favoriteIDs: Set<String> = []
        public var hiddenMediaEntries: [HiddenMediaEntry] = []
        public var pendingHiddenMediaRequestIDs: [String: UUID] = [:]
        public var lastSortMethod: SortMethod = .defaultOrder
        public var isCategorySortOverridden = false
        public var categoryPreferences: [String: CategoryPreferenceDTO] = [:]
        public var categoryPreferenceScope: CategoryPreferenceScope?
        public private(set) var derivedData = MediaLibraryDerivedData()
        public var unlockedCategoryIDs: Set<String> = []
        public var categoryUnlockRequestIDs: [String: UUID] = [:]
        public var categoryUnlockProfileScope: ProfileContextSnapshot?
        public var categoryUnlockPlaylistID: UUID?

        /// Language & Audio Filter
        public var selectedLanguageFilter: MediaLanguageFilter = .all
        public var selectedOriginalLanguageCode: String?

        public var rawVODs: [MediaModels.Item] {
            guard let id = selectedCategoryID else { return [] }
            return (vodsByCategory[id] ?? []).filter { item in
                let identity = HiddenMediaIdentity(item: item, fallbackPlaylistID: config?.playlistID)
                return !hiddenMediaEntries.contains { $0.identity == identity }
            }
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
        case categoriesResponse(
            requestID: UUID,
            config: PlaylistConfig,
            result: Result<[MediaModels.Category], Error>,
            preferences: [String: CategoryPreferenceDTO] = [:],
            preferenceScope: CategoryPreferenceScope? = nil
        )
        case categoriesPreferencesLoaded(
            config: PlaylistConfig?,
            categories: [MediaModels.Category],
            preferences: [String: CategoryPreferenceDTO],
            preferenceScope: CategoryPreferenceScope? = nil
        )
        case categorySelected(MediaModels.Category)
        case categoryUnlockExpired(categoryID: String, requestID: UUID)
        case fetchCategoryContent(requestID: UUID, config: PlaylistConfig, categoryID: String)
        case retryCategoryContent(categoryID: String)
        case vodsResponse(requestID: UUID, config: PlaylistConfig, categoryID: String, Result<[MediaModels.Item], Error>)
        case presentationOverridesLoaded(playlistID: UUID, profileScope: ProfileContextSnapshot, overrides: [String: MediaPresentationOverride])
        case vodSelected(MediaModels.Item)
        case setLanguageFilter(MediaLanguageFilter)
        case setOriginalLanguageFilter(String?)
        case setCategorySortMethod(SortMethod)
        case resetCategorySortMethod
        case toggleFavorite(MediaModels.Item)
        case favoritesLoaded(Set<String>, ProfileContextSnapshot)
        case hiddenMediaLoaded([HiddenMediaEntry], ProfileContextSnapshot)
        case hideMedia(MediaModels.Item)
        case hiddenMediaSaveCompleted(requestID: UUID, entry: HiddenMediaEntry, profileScope: ProfileContextSnapshot, Result<Bool, Error>)
        case dismissError
        case reloadCategories(config: PlaylistConfig)
        case refreshContentTapped
        case contentRefreshSucceeded(requestID: UUID, config: PlaylistConfig)
        case contentRefreshFailed(requestID: UUID, config: PlaylistConfig, message: String)
        case reloadPreferences
        case applySortIfChanged
        case editCategoriesTapped
        case coordinatorParentalLockUnlocked(category: MediaModels.Category?, item: MediaModels.Item?)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectVOD(MediaModels.Item)
            case presentCategoryManagement(CategoryManagementFeature.State)
            case presentParentalLock(ParentalLockFeature.State, closeVODDetailsOnExpiry: Bool)
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.categoryNameRuleClient) var categoryNameRuleClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.hapticClient) var hapticClient
    @Dependency(\.mediaPresentationOverrideClient) var mediaPresentationOverrideClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient

        let profileContextClient = profileContextClient
        let mediaPresentationOverrideClient = mediaPresentationOverrideClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                let previousSelectedCategoryID = state.selectedCategoryID
                let previousLanguageFilter = state.selectedLanguageFilter
                let previousOriginalLanguageCode = state.selectedOriginalLanguageCode
                let previousSortMethod = state.lastSortMethod
                let configChanged = state.config != config
                let playlistChanged = state.config?.playlistID != config.playlistID
                if configChanged {
                    state.activeCategoryRequestID = nil
                    state.categoryContentRequestIDs = [:]
                    state.categoryContentErrors = [:]
                    state.hasResolvedCategories = false
                    state.isLoadingVODs = false
                }
                if playlistChanged {
                    state.categories = []
                    state.vodsByCategory = [:]
                    state.selectedCategoryID = nil
                    state.selectedVOD = nil
                    state.isLoadingCategories = false
                    state.hasResolvedCategories = false
                    state.errorMessage = nil
                }
                state.config = config
                let profileScope = profileContextClient.snapshot()
                let profileScopeChanged = state.categoryUnlockProfileScope != profileScope
                if profileScopeChanged {
                    // Category availability and pending content work belong to
                    // the active profile. Keep provider catalog caches, but
                    // strip the previous profile's presentation overrides.
                    state.activeCategoryRequestID = nil
                    state.categoryContentRequestIDs = [:]
                    state.categoryContentErrors = [:]
                    state.isLoadingCategories = false
                    state.isLoadingVODs = false
                    state.hasResolvedCategories = false
                    state.errorMessage = nil
                    state.categories = []
                    state.vodsByCategory = state.vodsByCategory.mapValues { items in
                        items.map { $0.replacingPresentationOverride(nil) }
                    }
                }
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
                let categorySortMethod = state.selectedCategoryID.flatMap { categoryID in
                    CategoryContentSortPreference.load(
                        profileID: profileScope.profileID,
                        playlistID: config.playlistID,
                        library: .movies,
                        categoryID: categoryID
                    )
                }
                state.isCategorySortOverridden = categorySortMethod != nil
                state.lastSortMethod = categorySortMethod ?? settingsClient.getVODSortMethod()
                if playlistChanged || profileScopeChanged
                    || previousSelectedCategoryID != state.selectedCategoryID
                    || previousLanguageFilter != state.selectedLanguageFilter
                    || previousOriginalLanguageCode != state.selectedOriginalLanguageCode
                    || previousSortMethod != state.lastSortMethod
                {
                    state.rebuildDerivedData()
                }
                let loadFavorites: Effect<Action> = .run { send in
                    let favs = await (try? databaseClient.fetchFavoritesByType("vod", profileScope)) ?? []
                    let visible = favs.filter { $0.playlistID == config.playlistID || $0.playlistID == nil }
                    await send(.favoritesLoaded(Set(visible.map(\.id)), profileScope))
                }
                let loadHiddenMedia: Effect<Action> = .run { send in
                    let entries = await (try? databaseClient.fetchHiddenMediaItems("vod", profileScope)) ?? []
                    await send(.hiddenMediaLoaded(entries, profileScope))
                }
                let loadPresentationOverrides: Effect<Action> = if let playlistID = config.playlistID {
                    .run { send in
                        let overrides = await mediaPresentationOverrideClient.load(profileScope.profileID, playlistID, .movie)
                        guard profileContextClient.snapshot() == profileScope else { return }
                        await send(.presentationOverridesLoaded(playlistID: playlistID, profileScope: profileScope, overrides: overrides))
                    }
                } else {
                    .none
                }
                let localEffects = Effect<Action>.merge(loadFavorites, loadHiddenMedia, loadPresentationOverrides)

                guard !state.isLoadingCategories else { return localEffects }
                guard state.categories.isEmpty else { return localEffects }

                return .merge(localEffects, .send(.reloadCategories(config: config)))

            case let .reloadCategories(config):
                let requestID = UUID()
                state.activeCategoryRequestID = requestID
                state.isLoadingCategories = state.categories.isEmpty
                state.errorMessage = nil
                state.config = config
                let profileScope = profileContextClient.snapshot()
                let preferenceScope = CategoryPreferenceScope(profileID: profileScope.profileID, playlistID: config.playlistID)
                let existingPreferences = state.categoryPreferenceScope == preferenceScope
                    ? state.categoryPreferences
                    : [:]
                let profileContextClient = profileContextClient
                let categoryNameRuleClient = categoryNameRuleClient
                let hideAdult = settingsClient.hideAdultContent()
                let isAdultContent = settingsClient.isAdultContent
                return .run { send in
                    async let categoriesResult = Result { try await iptvClient.fetchVODCategories(config) }
                    async let prefsResult = Result {
                        try await databaseClient.fetchCategoryPreferences(
                            CategoryManagementFeature.State.CategoryType.vod.rawValue,
                            preferenceScope
                        )
                    }
                    async let nameRules: [CategoryNameRule] = {
                        guard let playlistID = config.playlistID else { return [] }
                        return await categoryNameRuleClient.load(profileScope.profileID, playlistID, CategoryManagementFeature.State.CategoryType.vod.rawValue)
                    }()

                    let categories = try await categoriesResult.get()
                    // Retain the last applied category policy during a
                    // transient persistence read failure.
                    let prefs = await (try? prefsResult.get()) ?? Array(existingPreferences.values)
                    let loadedNameRules = await nameRules
                    guard profileContextClient.snapshot() == profileScope else { return }

                    var dict: [String: CategoryPreferenceDTO] = [:]
                    for pref in prefs {
                        dict[pref.categoryID] = pref
                    }

                    // Filter and sort

                    let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                    let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]
                    let ruleHiddenCategoryIDs = CategoryNameRuleMatcher.hiddenCategoryIDs(in: categories, rules: loadedNameRules)

                    var finalCategories = categories.enumerated().filter { _, category in
                        if ruleHiddenCategoryIDs.contains(category.id) {
                            return false
                        }
                        if hideAdult, isAdultContent(category.name) || isAdultContent(category.sourceName) {
                            return false
                        }

                        if dict[category.id]?.isHidden ?? false {
                            return false
                        }

                        if isKidsMode {
                            let nameLower = category.sourceName.lowercased()
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

                    await send(.categoriesResponse(
                        requestID: requestID,
                        config: config,
                        result: .success(finalCategories.map(\.element)),
                        preferences: dict,
                        preferenceScope: preferenceScope
                    ))
                } catch: { error, send in
                    await send(.categoriesResponse(
                        requestID: requestID,
                        config: config,
                        result: .failure(error),
                        preferences: [:],
                        preferenceScope: preferenceScope
                    ))
                }
                .cancellable(id: "VODFeature.reloadCategories", cancelInFlight: true)

            case .reloadPreferences:
                let currentCats = state.categories
                let config = state.config
                let profileScope = profileContextClient.snapshot()
                let preferenceScope = CategoryPreferenceScope(profileID: profileScope.profileID, playlistID: config?.playlistID)
                let profileContextClient = profileContextClient
                let hideAdult = settingsClient.hideAdultContent()
                let isAdultContent = settingsClient.isAdultContent
                return .run { send in
                    let prefs: [CategoryPreferenceDTO]
                    do {
                        prefs = try await databaseClient.fetchCategoryPreferences(
                            CategoryManagementFeature.State.CategoryType.vod.rawValue,
                            preferenceScope
                        )
                    } catch {
                        return
                    }
                    guard profileContextClient.snapshot() == profileScope else { return }
                    var dict: [String: CategoryPreferenceDTO] = [:]
                    for pref in prefs {
                        dict[pref.categoryID] = pref
                    }

                    let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                    let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]

                    var finalCategories = currentCats.enumerated().filter { _, category in
                        if hideAdult, isAdultContent(category.name) || isAdultContent(category.sourceName) {
                            return false
                        }

                        if dict[category.id]?.isHidden ?? false {
                            return false
                        }

                        if isKidsMode {
                            let nameLower = category.sourceName.lowercased()
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

                    await send(.categoriesPreferencesLoaded(
                        config: config,
                        categories: finalCategories.map(\.element),
                        preferences: dict,
                        preferenceScope: preferenceScope
                    ))
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
                let profileID = profileContextClient.snapshot().profileID
                let categorySortMethod = state.selectedCategoryID.flatMap { categoryID in
                    CategoryContentSortPreference.load(
                        profileID: profileID,
                        playlistID: state.config?.playlistID,
                        library: .movies,
                        categoryID: categoryID
                    )
                }
                let currentMethod = categorySortMethod ?? settingsClient.getVODSortMethod()
                if state.lastSortMethod != currentMethod || state.isCategorySortOverridden != (categorySortMethod != nil) {
                    state.lastSortMethod = currentMethod
                    state.isCategorySortOverridden = categorySortMethod != nil
                    state.rebuildDerivedData()
                }
                return .none

            case let .categoriesResponse(requestID, config, .success(categories), preferences, preferenceScope):
                guard state.activeCategoryRequestID == requestID,
                      state.config == config,
                      profileContextClient.snapshot().profileID == preferenceScope?.profileID
                else { return .none }
                state.activeCategoryRequestID = nil
                state.isLoadingCategories = false
                state.hasResolvedCategories = true
                state.categoryPreferences = preferences
                state.categoryPreferenceScope = preferenceScope
                state.categories = categories
                // Auto-select first category if current selection is invalid or nil
                if let currentID = state.selectedCategoryID, let current = categories.first(where: { $0.id == currentID }) {
                    return .send(.categorySelected(current))
                } else if let first = categories.first {
                    return .send(.categorySelected(first))
                }
                return .none

            case let .categoriesResponse(requestID, config, .failure(error), _, _):
                guard state.activeCategoryRequestID == requestID, state.config == config else { return .none }
                state.activeCategoryRequestID = nil
                state.isLoadingCategories = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .categoriesPreferencesLoaded(config, categories, preferences, preferenceScope):
                guard let config,
                      state.config == config,
                      state.activeCategoryRequestID == nil,
                      profileContextClient.snapshot().profileID == preferenceScope?.profileID
                else { return .none }
                state.categoryPreferences = preferences
                state.categoryPreferenceScope = preferenceScope
                state.categories = categories
                if let currentID = state.selectedCategoryID, let current = categories.first(where: { $0.id == currentID }) {
                    return .send(.categorySelected(current))
                } else if let first = categories.first {
                    return .send(.categorySelected(first))
                }
                return .none

            case let .categorySelected(category):
                let isLocked = state.categoryPreferences[category.id]?.isLocked ?? false
                let isAdult = settingsClient.isAdultContent(category.name) || settingsClient.isAdultContent(category.sourceName)
                let requiresPIN = (isLocked || isAdult) && settingsClient.isParentalControlEnabled()

                if requiresPIN, !state.unlockedCategoryIDs.contains(category.id) {
                    return .send(.delegate(.presentParentalLock(ParentalLockFeature.State(
                        category: category,
                        isCoordinatorRoute: true
                    ), closeVODDetailsOnExpiry: false)))
                }

                state.isLoadingVODs = false
                state.selectedCategoryID = category.id
                let categorySortMethod = CategoryContentSortPreference.load(
                    profileID: profileContextClient.snapshot().profileID,
                    playlistID: state.config?.playlistID,
                    library: .movies,
                    categoryID: category.id
                )
                state.isCategorySortOverridden = categorySortMethod != nil
                state.lastSortMethod = categorySortMethod ?? settingsClient.getVODSortMethod()
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
                let profileScope = profileContextClient.snapshot()
                return .run { send in
                    let result = await Result { try await iptvClient.fetchVODs(config, categoryID) }
                    guard case let .success(vods) = result, let playlistID = config.playlistID else {
                        await send(.vodsResponse(requestID: requestID, config: config, categoryID: categoryID, result))
                        return
                    }
                    let overrides = await mediaPresentationOverrideClient.load(profileScope.profileID, playlistID, .movie)
                    guard profileContextClient.snapshot() == profileScope else { return }
                    let resolved = vods.map { $0.replacingPresentationOverride(overrides[$0.id]) }
                    await send(.vodsResponse(requestID: requestID, config: config, categoryID: categoryID, .success(resolved)))
                }

            case let .presentationOverridesLoaded(playlistID, profileScope, overrides):
                guard state.config?.playlistID == playlistID,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                for categoryID in Array(state.vodsByCategory.keys) {
                    state.vodsByCategory[categoryID] = state.vodsByCategory[categoryID]?.map { item in
                        item.replacingPresentationOverride(overrides[item.id])
                    }
                }
                state.rebuildDerivedData()
                return .none

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

            case let .setCategorySortMethod(method):
                guard let categoryID = state.selectedCategoryID, let config = state.config else { return .none }
                guard state.lastSortMethod != method || !state.isCategorySortOverridden else { return .none }
                CategoryContentSortPreference.save(
                    method,
                    profileID: profileContextClient.snapshot().profileID,
                    playlistID: config.playlistID,
                    library: .movies,
                    categoryID: categoryID
                )
                state.lastSortMethod = method
                state.isCategorySortOverridden = true
                state.rebuildDerivedData()
                return .run { _ in await hapticClient.selection() }

            case .resetCategorySortMethod:
                guard let categoryID = state.selectedCategoryID, let config = state.config else { return .none }
                CategoryContentSortPreference.reset(
                    profileID: profileContextClient.snapshot().profileID,
                    playlistID: config.playlistID,
                    library: .movies,
                    categoryID: categoryID
                )
                state.lastSortMethod = settingsClient.getVODSortMethod()
                state.isCategorySortOverridden = false
                state.rebuildDerivedData()
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

            case let .hiddenMediaLoaded(entries, scope):
                guard profileContextClient.snapshot() == scope else { return .none }
                state.hiddenMediaEntries = entries
                state.rebuildDerivedData()
                return .none

            case let .hideMedia(item):
                guard item.type == .vod,
                      let config = state.config
                else { return .none }
                let entry = HiddenMediaEntry(item: item, fallbackPlaylistID: config.playlistID)
                guard state.pendingHiddenMediaRequestIDs[entry.id] == nil else { return .none }
                let requestID = UUID()
                let profileScope = profileContextClient.snapshot()
                state.pendingHiddenMediaRequestIDs[entry.id] = requestID
                return .run { send in
                    do {
                        let succeeded = try await databaseClient.setHiddenMediaItem(entry, true, profileScope)
                        await send(.hiddenMediaSaveCompleted(requestID: requestID, entry: entry, profileScope: profileScope, .success(succeeded)))
                    } catch {
                        await send(.hiddenMediaSaveCompleted(requestID: requestID, entry: entry, profileScope: profileScope, .failure(error)))
                    }
                }

            case let .hiddenMediaSaveCompleted(requestID, entry, scope, result):
                guard state.pendingHiddenMediaRequestIDs[entry.id] == requestID else { return .none }
                state.pendingHiddenMediaRequestIDs.removeValue(forKey: entry.id)
                guard profileContextClient.snapshot() == scope else { return .none }
                switch result {
                case .success(true):
                    state.hiddenMediaEntries.removeAll { $0.identity == entry.identity }
                    state.hiddenMediaEntries.append(entry)
                    if let selectedVOD = state.selectedVOD,
                       HiddenMediaIdentity(item: selectedVOD, fallbackPlaylistID: state.config?.playlistID) == entry.identity
                    {
                        state.selectedVOD = nil
                    }
                    state.rebuildDerivedData()
                case .success(false):
                    state.errorMessage = AppStrings.Errors.hiddenMediaSaveFailed
                case let .failure(error):
                    state.errorMessage = String(format: AppStrings.Common.error, locale: Locale.current, arguments: [error.localizedDescription])
                }
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
                    return .send(.delegate(.presentCategoryManagement(
                        CategoryManagementFeature.State(config: config, type: .vod)
                    )))
                }
                return .none

            case let .coordinatorParentalLockUnlocked(category, item):
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
                var expiredCategoryToPresent: MediaModels.Category?
                if state.selectedCategoryID == categoryID {
                    state.selectedCategoryID = nil
                    state.rebuildDerivedData()
                    expiredCategoryToPresent = state.categories.first(where: { $0.id == categoryID })
                }
                if state.selectedVOD?.categoryID == categoryID {
                    state.selectedVOD = nil
                }
                if let category = expiredCategoryToPresent {
                    return .send(.delegate(.presentParentalLock(
                        ParentalLockFeature.State(category: category, isCoordinatorRoute: true),
                        closeVODDetailsOnExpiry: true
                    )))
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
