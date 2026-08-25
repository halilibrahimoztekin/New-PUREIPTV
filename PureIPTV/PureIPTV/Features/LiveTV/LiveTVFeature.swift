import ComposableArchitecture
import Factory
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
        case dismissError
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item)
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
                guard state.categories.isEmpty else { return .none } // Prevent re-fetching on view re-appear

                state.isLoadingCategories = true
                state.errorMessage = nil

                state.config = config

                return .run { send in
                    await send(.categoriesResponse(
                        Result { try await iptvClient.fetchLiveCategories(config) }
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
                // If channels are already cached, skip fetching
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
                return .send(.delegate(.didSelectChannel(channel)))

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
