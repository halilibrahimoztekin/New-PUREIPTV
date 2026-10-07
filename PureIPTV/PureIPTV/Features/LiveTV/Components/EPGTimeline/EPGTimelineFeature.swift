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
        case programTapped(EPGProgram, MediaModels.Item)
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
    @Dependency(\.dismiss) var dismiss

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
                
            case let .programTapped(program, channel):
                if program.endTime < Date(), channel.tvArchive == 1 {
                    let config = state.config
                    guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return .none }
                    let startUnix = Int(program.startTime.timeIntervalSince1970)
                    let durationMins = max(1, Int(program.endTime.timeIntervalSince(program.startTime) / 60))
                    
                    var components = URLComponents(url: serverURL.appendingPathComponent("streaming/timeshift.php"), resolvingAgainstBaseURL: false)
                    components?.queryItems = [
                        URLQueryItem(name: "username", value: username),
                        URLQueryItem(name: "password", value: password),
                        URLQueryItem(name: "stream", value: channel.id),
                        URLQueryItem(name: "start", value: String(startUnix)),
                        URLQueryItem(name: "duration", value: String(durationMins))
                    ]
                    
                    if let finalURL = components?.url {
                        let catchupItem = MediaModels.Item(
                            id: "\(channel.id)_catchup_\(startUnix)",
                            title: "\(channel.title) (Tekrar: \(program.title))",
                            streamURL: finalURL,
                            coverURL: channel.coverURL,
                            categoryID: channel.categoryID,
                            type: .live,
                            epgChannelID: channel.epgChannelID
                        )
                        return .send(.delegate(.playChannel(catchupItem)))
                    }
                }
                return .none

            case .closeTapped:
                return .run { _ in
                    @Dependency(\.dismiss) var dismiss
                    await dismiss()
                }

            case .delegate:
                return .none
            }
        }
    }
}
