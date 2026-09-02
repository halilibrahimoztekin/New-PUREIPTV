import ComposableArchitecture
import Foundation

@Reducer
public struct EPGTimelineFeature {
    @ObservableState
    public struct State: Equatable {
        public var config: PlaylistConfig
        public var channels: [MediaModels.Item]
        public var epgData: [String: [EPGProgram]] = [:] // streamID -> programs
        public var isLoading: [String: Bool] = [:]

        public var currentTime: Date = .init()

        public init(config: PlaylistConfig, channels: [MediaModels.Item]) {
            self.config = config
            self.channels = channels
        }
    }

    public enum Action {
        case onAppear
        case fetchEPG(streamID: String)
        case epgResponse(streamID: String, Result<[EPGProgram], Error>)
        case channelTapped(MediaModels.Item)
        case updateCurrentTime
        case closeTapped

        case delegate(Delegate)
        public enum Delegate: Equatable {
            case close
            case playChannel(MediaModels.Item)
        }
    }

    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Start a timer to update current time every minute
                return .run { [clock] send in
                    for await _ in clock.timer(interval: .seconds(60)) {
                        await send(.updateCurrentTime)
                    }
                }

            case .updateCurrentTime:
                state.currentTime = Date()
                return .none

            case let .fetchEPG(streamID):
                if state.isLoading[streamID] == true || state.epgData[streamID] != nil {
                    return .none
                }
                state.isLoading[streamID] = true
                let config = state.config
                return .run { send in
                    await send(.epgResponse(streamID: streamID, Result {
                        try await iptvClient.fetchShortEPG(config, streamID, 20)
                    }))
                }

            case let .epgResponse(streamID, .success(programs)):
                state.isLoading[streamID] = false
                state.epgData[streamID] = programs
                return .none

            case let .epgResponse(streamID, .failure):
                state.isLoading[streamID] = false
                // Optional: Store an empty array to prevent retrying constantly
                state.epgData[streamID] = []
                return .none

            case let .channelTapped(channel):
                return .send(.delegate(.playChannel(channel)))

            case .closeTapped:
                return .send(.delegate(.close))

            case .delegate:
                return .none
            }
        }
    }
}
