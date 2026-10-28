import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
public struct CategoryManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let config: PlaylistConfig
        public var type: CategoryType
        public var isLoading = false
        public var loadRequestID: UUID?
        public var categories: [MediaModels.Category] = []
        public var originalCategories: [MediaModels.Category] = []
        public var categoryPreferences: [String: CategoryPreferenceDTO] = [:] // key: categoryID
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
        case preferencesLoaded(requestID: UUID, [CategoryPreferenceDTO])
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
            case m3uMappingsUpdated
            case presentM3UCategoryMapping(presentationID: UUID)
        }
    }

    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient

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
                    async let prefs = try? await databaseClient.fetchCategoryPreferences(type.rawValue)

                    let cats = await categoriesResult
                    let p = await prefs ?? []
                    await send(.preferencesLoaded(requestID: requestID, p))
                    await send(.categoriesResponse(requestID: requestID, cats))
                }

            case let .preferencesLoaded(requestID, prefs):
                guard state.loadRequestID == requestID, !state.hasUnsavedChanges else { return .none }
                var dict: [String: CategoryPreferenceDTO] = [:]
                for pref in prefs {
                    dict[pref.categoryID] = pref
                }
                state.categoryPreferences = dict
                return .none

            case let .categoriesResponse(requestID, .success(categories)):
                guard state.loadRequestID == requestID else { return .none }
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
                guard state.loadRequestID == requestID else { return .none }
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
                return .run { send in
                    do {
                        try await databaseClient.saveCategoryPreferences(prefs)
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
