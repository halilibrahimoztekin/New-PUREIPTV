import ComposableArchitecture
import FactoryKit
import Foundation

@Reducer
public struct EPGGuideFeature {
    @ObservableState
    public struct State: Equatable {
        public let config: PlaylistConfig
        public let channels: [MediaModels.Item]

        public var selectedChannel: MediaModels.Item?
        public var epgListings: [EPGProgram] = []
        public var isLoadingEPG = false
        public var errorMessage: String?

        public init(config: PlaylistConfig, channels: [MediaModels.Item], initialChannel: MediaModels.Item?) {
            self.config = config
            self.channels = channels
            selectedChannel = initialChannel ?? channels.first
        }
    }

    public enum Action {
        case onAppear
        case selectChannel(MediaModels.Item)
        case epgResponse(Result<[EPGProgram], Error>)
        case closeTapped
        case playTapped(MediaModels.Item)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close
            case playChannel(MediaModels.Item)
        }
    }

    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if let channel = state.selectedChannel {
                    return .send(.selectChannel(channel))
                }
                return .none

            case let .selectChannel(channel):
                state.selectedChannel = channel
                state.isLoadingEPG = true
                state.errorMessage = nil
                state.epgListings = []

                let config = state.config
                let streamID = channel.id

                return .run { send in
                    await send(.epgResponse(
                        Result { try await iptvClient.fetchShortEPG(config, streamID, 20) }
                    ))
                }

            case let .epgResponse(.success(listings)):
                state.isLoadingEPG = false
                state.epgListings = listings
                return .none

            case let .epgResponse(.failure(error)):
                state.isLoadingEPG = false
                state.errorMessage = error.localizedDescription
                return .none

            case .closeTapped:
                return .run { _ in
                    @Dependency(\.dismiss) var dismiss
                    await dismiss()
                }

            case let .playTapped(channel):
                return .send(.delegate(.playChannel(channel)))

            case .delegate:
                return .none
            }
        }
    }
}
