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

        // Live EPG Preview (Madde #25)
        public var activePreviewChannel: MediaModels.Item?
        public var isPreviewMuted: Bool = true
        public var isPreviewPlaying: Bool = false
        public var isAutoPreviewEnabled: Bool = true

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
        case playCatchUp(EPGProgram, MediaModels.Item)
        case channelFocused(MediaModels.Item?)
        case startPreviewDebounce(MediaModels.Item)
        case previewPlaybackStarted(String)
        case togglePreviewMute
        case stopPreview
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case close
            case playChannel(MediaModels.Item)
        }
    }

    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.previewPlayerClient) var previewPlayerClient
    @Dependency(\.continuousClock) var clock

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

                enum CancelID: Hashable {
                    case previewDebounce
                }

                let epgEffect: Effect<Action> = .run { send in
                    await send(.epgResponse(
                        Result { try await iptvClient.fetchShortEPG(config, streamID, 20) }
                    ))
                }

                let previewEffect: Effect<Action> = state.isAutoPreviewEnabled ? .run { [clock] send in
                    try await clock.sleep(for: .milliseconds(400))
                    await send(.startPreviewDebounce(channel))
                }.cancellable(id: CancelID.previewDebounce, cancelInFlight: true) : .none

                return .merge(epgEffect, previewEffect)

            case let .channelFocused(channel):
                guard let channel, state.isAutoPreviewEnabled else { return .none }
                if state.activePreviewChannel?.id == channel.id, state.isPreviewPlaying {
                    return .none
                }
                enum CancelID: Hashable {
                    case previewDebounce
                }
                return .run { [clock] send in
                    try await clock.sleep(for: .milliseconds(400))
                    await send(.startPreviewDebounce(channel))
                }
                .cancellable(id: CancelID.previewDebounce, cancelInFlight: true)

            case let .startPreviewDebounce(channel):
                state.activePreviewChannel = channel
                state.isPreviewPlaying = true
                return .run { [previewPlayerClient] send in
                    try? await previewPlayerClient.playPreview(channel)
                    await send(.previewPlaybackStarted(channel.id))
                }

            case .previewPlaybackStarted:
                return .none

            case .togglePreviewMute:
                state.isPreviewMuted.toggle()
                let isMuted = state.isPreviewMuted
                return .run { [previewPlayerClient] _ in
                    await previewPlayerClient.setMuted(isMuted)
                }

            case .stopPreview:
                state.activePreviewChannel = nil
                state.isPreviewPlaying = false
                return .run { [previewPlayerClient] _ in
                    await previewPlayerClient.stopPreview()
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
                return .merge(
                    .run { [previewPlayerClient] _ in
                        await previewPlayerClient.stopPreview()
                    },
                    .send(.delegate(.close)),
                    .run { _ in
                        @Dependency(\.dismiss) var dismiss
                        await dismiss()
                    }
                )

            case let .playTapped(channel):
                return .merge(
                    .run { [previewPlayerClient] _ in
                        await previewPlayerClient.stopPreview()
                    },
                    .send(.delegate(.playChannel(channel)))
                )

            case let .playCatchUp(program, channel):
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
                    URLQueryItem(name: "duration", value: String(durationMins)),
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
                    return .merge(
                        .run { [previewPlayerClient] _ in
                            await previewPlayerClient.stopPreview()
                        },
                        .send(.delegate(.playChannel(catchupItem)))
                    )
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
