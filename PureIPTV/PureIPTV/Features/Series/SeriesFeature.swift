import ComposableArchitecture
import Factory
import Foundation

// MARK: - SeriesFeature

@Reducer
public struct SeriesFeature {
    @ObservableState
    public struct State: Equatable {
        // Data
        public var categories: [MediaModels.Category] = []
        public var seriesByCategory: [String: [MediaModels.Item]] = [:]

        /// Server Info
        public var config: PlaylistConfig?

        // UI state
        public var selectedCategoryID: String?
        public var selectedSeries: MediaModels.Item?
        public var isLoadingCategories = false
        public var isLoadingSeries = false
        public var errorMessage: String?

        // Computed: series for the currently selected category
        public var currentSeries: [MediaModels.Item] {
            guard let id = selectedCategoryID else { return [] }
            return seriesByCategory[id] ?? []
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case categoriesResponse(Result<[MediaModels.Category], Error>)
        case categorySelected(MediaModels.Category)
        case seriesResponse(categoryID: String, Result<[MediaModels.Item], Error>)
        case seriesSelected(MediaModels.Item)
        case dismissError
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectSeries(MediaModels.Item)
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
                        Result { try await iptvClient.fetchSeriesCategories(config) }
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
                if state.seriesByCategory[category.id] != nil {
                    return .none
                }
                guard let config = state.config else { return .none }

                state.isLoadingSeries = true
                let categoryID = category.id

                return .run { send in
                    await send(.seriesResponse(
                        categoryID: categoryID,
                        Result { try await iptvClient.fetchSeries(config, categoryID) }
                    ))
                }

            case let .seriesResponse(categoryID, .success(series)):
                state.isLoadingSeries = false
                state.seriesByCategory[categoryID] = series
                return .none

            case let .seriesResponse(_, .failure(error)):
                state.isLoadingSeries = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .seriesSelected(series):
                state.selectedSeries = series
                return .send(.delegate(.didSelectSeries(series)))

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
