import ComposableArchitecture
import Foundation
import SwiftUI

private func loadCategoryNameOverrides(
    client: CategoryNameOverrideClient,
    playlistID: UUID?,
    mediaType: String
) async -> [String: String] {
    guard let playlistID else { return [:] }
    return await client.load(playlistID, mediaType)
}

@Reducer
public struct CategoryManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public enum Parent: Equatable {
            case liveTV(routeIndex: Int)
            case vod(routeIndex: Int)
            case series(routeIndex: Int)
        }

        public let presentationID: UUID
        public let config: PlaylistConfig
        public var type: CategoryType
        public var parent: Parent?
        public var isLoading = false
        public var loadRequestID: UUID?
        public var categories: [MediaModels.Category] = []
        public var originalCategories: [MediaModels.Category] = []
        public var categoryPreferences: [String: CategoryPreferenceDTO] = [:] // key: categoryID
        public var categoryNameOverrides: [String: String] = [:]
        public var profileScope: ProfileContextSnapshot?
        public var categoryNameRules: [CategoryNameRule] = []
        public var draftCategoryNameRules: [CategoryNameRule] = []
        public var isCategoryNameRulesPresented = false
        public var hasCategoryNameRuleChanges = false
        public var isSavingCategoryNameRules = false
        public var categoryNameRuleSaveFailed = false
        public var hasUnsavedChanges = false
        public var searchQuery: String = ""
        public var filterMode: FilterMode = .all

        public enum FilterMode: String, Equatable, CaseIterable, Sendable {
            case all
            case visible
            case hidden

            public var title: String {
                switch self {
                case .all: AppStrings.CategoryMgmt.filterAll
                case .visible: AppStrings.CategoryMgmt.filterVisible
                case .hidden: AppStrings.CategoryMgmt.filterHidden
                }
            }
        }

        public enum CategoryType: String, Equatable, CaseIterable, Sendable {
            case live
            case vod
            case series

            var title: String {
                switch self {
                case .live: AppStrings.Common.liveTV
                case .vod: AppStrings.VOD.title
                case .series: AppStrings.Series.title
                }
            }
        }

        public var totalCount: Int {
            categories.count
        }

        public var visibleCount: Int {
            categories.filter { !(categoryPreferences[$0.id]?.isHidden ?? false) }.count
        }

        public var hiddenCount: Int {
            categories.filter { categoryPreferences[$0.id]?.isHidden ?? false }.count
        }

        public var filteredCategories: [MediaModels.Category] {
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            return categories.filter { category in
                if !query.isEmpty, !category.name.localizedCaseInsensitiveContains(query) {
                    return false
                }
                let isHidden = categoryPreferences[category.id]?.isHidden ?? false
                switch filterMode {
                case .all: return true
                case .visible: return !isHidden
                case .hidden: return isHidden
                }
            }
        }

        public init(config: PlaylistConfig, type: CategoryType, presentationID: UUID = UUID()) {
            self.presentationID = presentationID
            self.config = config
            self.type = type
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case loadData
        case categoriesResponse(requestID: UUID, Result<[MediaModels.Category], Error>)
        case preferencesLoaded(requestID: UUID, profileScope: ProfileContextSnapshot, [CategoryPreferenceDTO])
        case categoryNameOverridesLoaded(requestID: UUID, [String: String])
        case categoryNameRulesLoaded(requestID: UUID, profileScope: ProfileContextSnapshot, [CategoryNameRule])
        case setCategoryNameOverride(categoryID: String, name: String)
        case categoryNameRulesTapped
        case addCategoryNameRuleTapped
        case setCategoryNameRulePattern(id: UUID, pattern: String)
        case setCategoryNameRuleMode(id: UUID, mode: CategoryNameRule.MatchMode)
        case toggleCategoryNameRule(id: UUID)
        case removeCategoryNameRule(id: UUID)
        case cancelCategoryNameRulesTapped
        case saveCategoryNameRulesTapped
        case categoryNameRulesSaveResponse(success: Bool, rules: [CategoryNameRule])
        case toggleVisibility(categoryID: String)
        case toggleLock(categoryID: String)
        case moveCategory(from: IndexSet, to: Int)
        case setSearchQuery(String)
        case setFilterMode(State.FilterMode)
        case showAllTapped
        case hideAllTapped
        case invertVisibilityTapped
        case bulkKeepOnlyPrefixes([String])
        case resetOrderTapped
        case saveTapped
        case saveResponse(Result<Void, Error>)
        case m3uCategoryMappingTapped
        case m3uCategoryMappingsUpdated
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close
            case categoriesUpdated
            case categoryNameRulesUpdated
            case m3uMappingsUpdated
            case presentM3UCategoryMapping(presentationID: UUID)
        }
    }

    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.categoryNameOverrideClient) var categoryNameOverrideClient
    @Dependency(\.categoryNameRuleClient) var categoryNameRuleClient
    @Dependency(\.profileContextClient) var profileContextClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .send(.loadData)

            case .loadData:
                state.isLoading = true
                let config = state.config
                let type = state.type
                let profileScope = profileContextClient.snapshot()
                state.profileScope = profileScope
                let categoryNameOverrideClient = categoryNameOverrideClient
                let categoryNameRuleClient = categoryNameRuleClient
                let requestID = UUID()
                state.loadRequestID = requestID
                return .run { send in
                    // Fetch categories
                    async let categoriesResult: Result<[MediaModels.Category], Error> = Result {
                        switch type {
                        case .live: try await iptvClient.fetchLiveCategories(config)
                        case .vod: try await iptvClient.fetchVODCategories(config)
                        case .series: try await iptvClient.fetchSeriesCategories(config)
                        }
                    }
                    // Fetch preferences
                    async let prefs = try? await databaseClient.fetchCategoryPreferences(
                        type.rawValue,
                        CategoryPreferenceScope(profileID: profileScope.profileID, playlistID: config.playlistID)
                    )
                    async let nameOverrides = loadCategoryNameOverrides(
                        client: categoryNameOverrideClient,
                        playlistID: config.playlistID,
                        mediaType: type.rawValue
                    )
                    async let nameRules: [CategoryNameRule] = {
                        guard let playlistID = config.playlistID else { return [] }
                        return await categoryNameRuleClient.load(profileScope.profileID, playlistID, type.rawValue)
                    }()

                    let cats = await categoriesResult
                    let p = await prefs ?? []
                    let names = await nameOverrides
                    let rules = await nameRules
                    await send(.preferencesLoaded(requestID: requestID, profileScope: profileScope, p))
                    await send(.categoryNameOverridesLoaded(requestID: requestID, names))
                    await send(.categoryNameRulesLoaded(requestID: requestID, profileScope: profileScope, rules))
                    await send(.categoriesResponse(requestID: requestID, cats))
                }

            case let .preferencesLoaded(requestID, profileScope, prefs):
                guard state.loadRequestID == requestID,
                      state.profileScope == profileScope,
                      profileContextClient.snapshot() == profileScope,
                      !state.hasUnsavedChanges
                else { return .none }
                var dict: [String: CategoryPreferenceDTO] = [:]
                for pref in prefs {
                    dict[pref.categoryID] = pref
                }
                state.categoryPreferences = dict
                return .none

            case let .categoryNameOverridesLoaded(requestID, overrides):
                guard state.loadRequestID == requestID, !state.hasUnsavedChanges else { return .none }
                state.categoryNameOverrides = overrides
                return .none

            case let .categoryNameRulesLoaded(requestID, profileScope, rules):
                guard state.loadRequestID == requestID,
                      state.profileScope == profileScope,
                      !state.hasCategoryNameRuleChanges else { return .none }
                state.categoryNameRules = rules
                state.draftCategoryNameRules = rules
                return .none

            case .categoryNameRulesTapped:
                guard state.config.playlistID != nil else { return .none }
                state.draftCategoryNameRules = state.categoryNameRules
                state.hasCategoryNameRuleChanges = false
                state.categoryNameRuleSaveFailed = false
                state.isCategoryNameRulesPresented = true
                return .none

            case .addCategoryNameRuleTapped:
                guard state.draftCategoryNameRules.count < 100 else { return .none }
                state.draftCategoryNameRules.append(CategoryNameRule())
                state.hasCategoryNameRuleChanges = true
                state.categoryNameRuleSaveFailed = false
                return .none

            case let .setCategoryNameRulePattern(id, pattern):
                guard let index = state.draftCategoryNameRules.firstIndex(where: { $0.id == id }) else { return .none }
                state.draftCategoryNameRules[index].pattern = String(pattern.prefix(256))
                state.hasCategoryNameRuleChanges = true
                state.categoryNameRuleSaveFailed = false
                return .none

            case let .setCategoryNameRuleMode(id, mode):
                guard let index = state.draftCategoryNameRules.firstIndex(where: { $0.id == id }) else { return .none }
                state.draftCategoryNameRules[index].mode = mode
                state.hasCategoryNameRuleChanges = true
                state.categoryNameRuleSaveFailed = false
                return .none

            case let .toggleCategoryNameRule(id):
                guard let index = state.draftCategoryNameRules.firstIndex(where: { $0.id == id }) else { return .none }
                state.draftCategoryNameRules[index].isEnabled.toggle()
                state.hasCategoryNameRuleChanges = true
                state.categoryNameRuleSaveFailed = false
                return .none

            case let .removeCategoryNameRule(id):
                state.draftCategoryNameRules.removeAll { $0.id == id }
                state.hasCategoryNameRuleChanges = true
                state.categoryNameRuleSaveFailed = false
                return .none

            case .cancelCategoryNameRulesTapped:
                state.draftCategoryNameRules = state.categoryNameRules
                state.hasCategoryNameRuleChanges = false
                state.categoryNameRuleSaveFailed = false
                state.isCategoryNameRulesPresented = false
                return .none

            case .saveCategoryNameRulesTapped:
                guard !state.isSavingCategoryNameRules,
                      let profileScope = state.profileScope,
                      let playlistID = state.config.playlistID else { return .none }
                state.isSavingCategoryNameRules = true
                state.categoryNameRuleSaveFailed = false
                let rules = state.draftCategoryNameRules
                let mediaType = state.type.rawValue
                let client = categoryNameRuleClient
                let profileContextClient = profileContextClient
                return .run { send in
                    let success = await client.save(rules, profileScope.profileID, playlistID, mediaType)
                    guard profileContextClient.snapshot() == profileScope else { return }
                    await send(.categoryNameRulesSaveResponse(success: success, rules: rules))
                }

            case let .categoryNameRulesSaveResponse(success, rules):
                state.isSavingCategoryNameRules = false
                guard success else {
                    state.categoryNameRuleSaveFailed = true
                    return .none
                }
                state.categoryNameRules = rules
                state.draftCategoryNameRules = rules
                state.hasCategoryNameRuleChanges = false
                state.isCategoryNameRulesPresented = false
                return .send(.delegate(.categoryNameRulesUpdated))

            case let .setCategoryNameOverride(categoryID, name):
                guard let index = state.categories.firstIndex(where: { $0.id == categoryID }) else { return .none }
                let category = state.categories[index]
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedName = String(trimmedName.prefix(80))
                if normalizedName.isEmpty || normalizedName == category.sourceName {
                    state.categoryNameOverrides.removeValue(forKey: categoryID)
                } else {
                    state.categoryNameOverrides[categoryID] = normalizedName
                }
                let displayName = state.categoryNameOverrides[categoryID] ?? category.sourceName
                let updatedCategory = MediaModels.Category(
                    id: category.id,
                    name: displayName,
                    sourceName: category.sourceName
                )
                state.categories[index] = updatedCategory
                if let originalIndex = state.originalCategories.firstIndex(where: { $0.id == categoryID }) {
                    state.originalCategories[originalIndex] = updatedCategory
                }
                state.hasUnsavedChanges = true
                return .none

            case let .categoriesResponse(requestID, .success(categories)):
                guard state.loadRequestID == requestID,
                      let profileScope = state.profileScope,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                state.isLoading = false
                state.originalCategories = categories

                // Sort categories based on preferences
                var sortedCategories = categories
                let dict = state.categoryPreferences

                sortedCategories.sort { a, b in
                    let orderA = dict[a.id]?.orderIndex ?? Int.max
                    let orderB = dict[b.id]?.orderIndex ?? Int.max
                    if orderA == orderB {
                        return a.name < b.name
                    }
                    return orderA < orderB
                }

                state.categories = sortedCategories
                return .none

            case let .categoriesResponse(requestID, .failure):
                guard state.loadRequestID == requestID,
                      let profileScope = state.profileScope,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                state.isLoading = false
                return .none

            case let .setSearchQuery(query):
                state.searchQuery = query
                return .none

            case let .setFilterMode(mode):
                state.filterMode = mode
                return .none

            case let .toggleVisibility(categoryID):
                state.hasUnsavedChanges = true
                if let pref = state.categoryPreferences[categoryID] {
                    var updated = pref
                    updated.isHidden.toggle()
                    state.categoryPreferences[categoryID] = updated
                } else {
                    let pref = CategoryPreferenceDTO(
                        id: "\(state.type.rawValue)_\(categoryID)",
                        type: state.type.rawValue,
                        categoryID: categoryID,
                        isHidden: true,
                        orderIndex: Int.max
                    )
                    state.categoryPreferences[categoryID] = pref
                }
                return .none

            case let .toggleLock(categoryID):
                state.hasUnsavedChanges = true
                if let pref = state.categoryPreferences[categoryID] {
                    var updated = pref
                    updated.isLocked.toggle()
                    state.categoryPreferences[categoryID] = updated
                } else {
                    let pref = CategoryPreferenceDTO(
                        id: "\(state.type.rawValue)_\(categoryID)",
                        type: state.type.rawValue,
                        categoryID: categoryID,
                        isHidden: false,
                        isLocked: true,
                        orderIndex: Int.max
                    )
                    state.categoryPreferences[categoryID] = pref
                }
                return .none

            case .showAllTapped:
                state.hasUnsavedChanges = true
                let targetCategories = state.filteredCategories
                for category in targetCategories {
                    if let pref = state.categoryPreferences[category.id] {
                        var updated = pref
                        updated.isHidden = false
                        state.categoryPreferences[category.id] = updated
                    } else {
                        let pref = CategoryPreferenceDTO(
                            id: "\(state.type.rawValue)_\(category.id)",
                            type: state.type.rawValue,
                            categoryID: category.id,
                            isHidden: false,
                            orderIndex: Int.max
                        )
                        state.categoryPreferences[category.id] = pref
                    }
                }
                return .none

            case .hideAllTapped:
                state.hasUnsavedChanges = true
                let targetCategories = state.filteredCategories
                for category in targetCategories {
                    if let pref = state.categoryPreferences[category.id] {
                        var updated = pref
                        updated.isHidden = true
                        state.categoryPreferences[category.id] = updated
                    } else {
                        let pref = CategoryPreferenceDTO(
                            id: "\(state.type.rawValue)_\(category.id)",
                            type: state.type.rawValue,
                            categoryID: category.id,
                            isHidden: true,
                            orderIndex: Int.max
                        )
                        state.categoryPreferences[category.id] = pref
                    }
                }
                return .none

            case .invertVisibilityTapped:
                state.hasUnsavedChanges = true
                let targetCategories = state.filteredCategories
                for category in targetCategories {
                    if let pref = state.categoryPreferences[category.id] {
                        var updated = pref
                        updated.isHidden.toggle()
                        state.categoryPreferences[category.id] = updated
                    } else {
                        let pref = CategoryPreferenceDTO(
                            id: "\(state.type.rawValue)_\(category.id)",
                            type: state.type.rawValue,
                            categoryID: category.id,
                            isHidden: true,
                            orderIndex: Int.max
                        )
                        state.categoryPreferences[category.id] = pref
                    }
                }
                return .none

            case let .bulkKeepOnlyPrefixes(prefixes):
                state.hasUnsavedChanges = true
                let lowerPrefixes = prefixes.map { $0.lowercased() }
                for category in state.categories {
                    let catName = category.name.lowercased()
                    let shouldKeep = lowerPrefixes.contains { catName.contains($0) }
                    let newHidden = !shouldKeep
                    if let pref = state.categoryPreferences[category.id] {
                        var updated = pref
                        updated.isHidden = newHidden
                        state.categoryPreferences[category.id] = updated
                    } else {
                        let pref = CategoryPreferenceDTO(
                            id: "\(state.type.rawValue)_\(category.id)",
                            type: state.type.rawValue,
                            categoryID: category.id,
                            isHidden: newHidden,
                            orderIndex: Int.max
                        )
                        state.categoryPreferences[category.id] = pref
                    }
                }
                return .none

            case .resetOrderTapped:
                state.hasUnsavedChanges = true
                state.categories = state.originalCategories
                for (index, category) in state.categories.enumerated() {
                    if let pref = state.categoryPreferences[category.id] {
                        var updated = pref
                        updated.orderIndex = index
                        state.categoryPreferences[category.id] = updated
                    }
                }
                return .none

            case let .moveCategory(source, destination):
                state.hasUnsavedChanges = true
                state.categories.move(fromOffsets: source, toOffset: destination)

                // Update order index based on new array
                for (index, category) in state.categories.enumerated() {
                    if let pref = state.categoryPreferences[category.id] {
                        var updated = pref
                        updated.orderIndex = index
                        state.categoryPreferences[category.id] = updated
                    } else {
                        let pref = CategoryPreferenceDTO(
                            id: "\(state.type.rawValue)_\(category.id)",
                            type: state.type.rawValue,
                            categoryID: category.id,
                            isHidden: false,
                            orderIndex: index
                        )
                        state.categoryPreferences[category.id] = pref
                    }
                }
                return .none

            case .saveTapped:
                let prefs = Array(state.categoryPreferences.values)
                let nameOverrides = state.categoryNameOverrides
                let playlistID = state.config.playlistID
                let mediaType = state.type.rawValue
                let preferenceScope = CategoryPreferenceScope(
                    profileID: state.profileScope?.profileID,
                    playlistID: playlistID
                )
                let profileScope = state.profileScope ?? profileContextClient.snapshot()
                let profileContextClient = profileContextClient
                let categoryNameOverrideClient = categoryNameOverrideClient
                return .run { send in
                    guard profileContextClient.snapshot() == profileScope else { return }
                    do {
                        try await databaseClient.saveCategoryPreferences(prefs, preferenceScope)
                        if let playlistID {
                            await categoryNameOverrideClient.save(nameOverrides, playlistID, mediaType)
                        }
                        await send(.saveResponse(.success(())))
                    } catch {
                        await send(.saveResponse(.failure(error)))
                    }
                }

            case .m3uCategoryMappingTapped:
                guard state.config.type == .m3u, state.type == .live else { return .none }
                return .send(.delegate(.presentM3UCategoryMapping(presentationID: state.presentationID)))

            case .m3uCategoryMappingsUpdated:
                return .merge(
                    .send(.delegate(.m3uMappingsUpdated)),
                    .send(.loadData)
                )

            case .saveResponse(.success):
                state.hasUnsavedChanges = false
                return .run { send in
                    await send(.delegate(.categoriesUpdated))
                    await send(.delegate(.close))
                }

            case let .saveResponse(.failure(error)):
                print("Failed to save category preferences: \(error)")
                return .none

            case .closeTapped:
                return .send(.delegate(.close))

            case .delegate:
                return .none
            }
        }
    }
}
