import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
public struct CategoryManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public let config: PlaylistConfig
        public var type: CategoryType
        public var isLoading = false
        public var categories: [MediaModels.Category] = []
        public var categoryPreferences: [String: CategoryPreferenceDTO] = [:] // key: categoryID
        public var hasUnsavedChanges = false

        public enum CategoryType: String, Equatable, CaseIterable {
            case live
            case vod
            case series

            var title: String {
                switch self {
                case .live: return "Live TV"
                case .vod: return "Movies"
                case .series: return "Series"
                }
            }
        }

        public init(config: PlaylistConfig, type: CategoryType) {
            self.config = config
            self.type = type
        }
    }

    public enum Action {
        case onAppear
        case loadData
        case categoriesResponse(Result<[MediaModels.Category], Error>)
        case preferencesLoaded([CategoryPreferenceDTO])
        case toggleVisibility(categoryID: String)
        case moveCategory(from: IndexSet, to: Int)
        case saveTapped
        case saveResponse(Result<Void, Error>)
        case closeTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close
            case categoriesUpdated
        }
    }

    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.loadData)

            case .loadData:
                state.isLoading = true
                let config = state.config
                let type = state.type
                return .run { send in
                    // Fetch categories
                    async let categoriesResult: Result<[MediaModels.Category], Error> = Result {
                        switch type {
                        case .live: return try await iptvClient.fetchLiveCategories(config)
                        case .vod: return try await iptvClient.fetchVODCategories(config)
                        case .series: return try await iptvClient.fetchSeriesCategories(config)
                        }
                    }
                    // Fetch preferences
                    async let prefs = try? await databaseClient.fetchCategoryPreferences(type.rawValue)

                    let cats = await categoriesResult
                    let p = await prefs ?? []
                    await send(.preferencesLoaded(p))
                    await send(.categoriesResponse(cats))
                }

            case let .preferencesLoaded(prefs):
                var dict: [String: CategoryPreferenceDTO] = [:]
                for pref in prefs {
                    dict[pref.categoryID] = pref
                }
                state.categoryPreferences = dict
                return .none

            case let .categoriesResponse(.success(categories)):
                state.isLoading = false

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

            case .categoriesResponse(.failure):
                state.isLoading = false
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
