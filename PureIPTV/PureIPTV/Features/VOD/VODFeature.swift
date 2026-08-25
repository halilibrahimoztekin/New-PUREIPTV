import ComposableArchitecture
import Factory
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

        // Computed: vods for the currently selected category
        public var currentVODs: [MediaModels.Item] {
            guard let id = selectedCategoryID else { return [] }
            return vodsByCategory[id] ?? []
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case categoriesResponse(Result<[MediaModels.Category], Error>)
        case categorySelected(MediaModels.Category)
        case vodsResponse(categoryID: String, Result<[MediaModels.Item], Error>)
        case vodSelected(MediaModels.Item)
        case dismissError
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectVOD(MediaModels.Item)
        }
    }

    @Injected(\.iptvClient) var iptvClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = self.iptvClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                guard !state.isLoadingCategories else { return .none }
                guard state.categories.isEmpty else { return .none }

                state.isLoadingCategories = true
                state.errorMessage = nil

                state.config = config

                return .run { send in
                    await send(.categoriesResponse(
                        Result { try await iptvClient.fetchVODCategories(config) }
                    ))
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
                return .send(.delegate(.didSelectVOD(vod)))

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
