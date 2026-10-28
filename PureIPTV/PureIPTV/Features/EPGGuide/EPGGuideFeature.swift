import ComposableArchitecture
import FactoryKit
import Foundation

private nonisolated enum EPGGuideCancelID: Hashable, Sendable {
    case epgRequest
    case previewDebounce
    case previewPlayback
}

@Reducer
public struct EPGGuideFeature {
    @ObservableState
    public struct State: Equatable {
        public let presentationID: UUID
        public let config: PlaylistConfig
        public let channels: [MediaModels.Item]

        public var selectedChannel: MediaModels.Item?
        public var epgListings: [EPGProgram] = []
        public var isLoadingEPG = false
        public var epgRequestID: UUID?
        public var loadedEPGChannelID: String?
        public var isVisible = false
        public var errorMessage: String?
        public var lastEPGRefreshDate: Date?
        public var lastEPGRefreshFailureDate: Date?

        public var epgFreshnessLabel: String {
            guard let lastEPGRefreshDate else {
                return lastEPGRefreshFailureDate == nil
                    ? AppStrings.Player.epgFreshnessUnknown
                    : AppStrings.Player.epgLastRefreshIssue
            }
            let age = max(0, Date().timeIntervalSince(lastEPGRefreshDate))
            let value = if age < 3600 {
                "\(max(1, Int(age / 60))) dk"
            } else if age < 86400 {
                "\(Int(age / 3600)) sa"
            } else {
                "\(Int(age / 86400)) gün"
            }
            if let failureDate = lastEPGRefreshFailureDate, failureDate >= lastEPGRefreshDate {
                return AppStrings.Player.epgLastRefreshIssue + " · " + AppStrings.Player.epgDataAge(value)
            }
            if age >= 86400 {
                return AppStrings.Player.epgDataStale + " · " + AppStrings.Player.epgDataAge(value)
            }
            return AppStrings.Player.epgDataAge(value)
        }

        // Live EPG Preview (Madde #25)
        public var activePreviewChannel: MediaModels.Item?
        public var isPreviewMuted: Bool = true
        public var isPreviewPlaying: Bool = false
        public var isAutoPreviewEnabled: Bool = true
        public var previewGeneration: Int = 0

        public init(
            config: PlaylistConfig,
            channels: [MediaModels.Item],
            initialChannel: MediaModels.Item?,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.config = config
            self.channels = channels
            selectedChannel = initialChannel ?? channels.first
        }
    }

    public enum Action {
        case onAppear
        case onDisappear
        case selectChannel(MediaModels.Item)
        case epgResponse(channelID: String, requestID: UUID, Result<[EPGProgram], Error>)
        case closeTapped
        case playTapped(MediaModels.Item)
        case playCatchUp(EPGProgram, MediaModels.Item)
        case channelFocused(MediaModels.Item?)
        case startPreviewDebounce(MediaModels.Item, generation: Int)
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
    @Dependency(\.customEPGMappingClient) var customEPGMappingClient
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.previewPlayerClient) var previewPlayerClient
    @Dependency(\.settingsClient) var settingsClient
    @Injected(\.playerClient) var playerClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isVisible else { return .none }
                state.isVisible = true
                state.lastEPGRefreshDate = settingsClient.getLastEPGRefreshDate(state.config.playlistID)
                state.lastEPGRefreshFailureDate = settingsClient.getLastEPGRefreshFailureDate(state.config.playlistID)
                if let channel = state.selectedChannel {
                    if state.loadedEPGChannelID == channel.id, state.errorMessage == nil {
                        return .send(.channelFocused(channel))
                    }
                    return .send(.selectChannel(channel))
                }
                return .none

            case .onDisappear:
                state.isVisible = false
                state.epgRequestID = nil
                state.isLoadingEPG = false
                state.previewGeneration &+= 1
                state.activePreviewChannel = nil
                state.isPreviewPlaying = false
                return .merge(
                    .cancel(id: EPGGuideCancelID.epgRequest),
                    .cancel(id: EPGGuideCancelID.previewDebounce),
                    .cancel(id: EPGGuideCancelID.previewPlayback),
                    .run { [previewPlayerClient, ownerID = state.presentationID] _ in
                        await previewPlayerClient.stopPreviewOwned(ownerID)
                    }
                )

            case let .selectChannel(channel):
                if state.selectedChannel?.id != channel.id {
                    state.epgListings = []
                    state.loadedEPGChannelID = nil
                }
                state.selectedChannel = channel
                state.isLoadingEPG = true
                state.errorMessage = nil
                let requestID = UUID()
                state.epgRequestID = requestID
                state.previewGeneration &+= 1
                let previewGeneration = state.previewGeneration

                let config = state.config
                let streamID = channel.id

                let epgEffect: Effect<Action> = .run { [iptvClient] send in
                    let result = await Result { try await iptvClient.fetchShortEPG(config, streamID, 20) }
                    guard !Task.isCancelled else { return }
                    await send(.epgResponse(channelID: streamID, requestID: requestID, result))
                }
                .cancellable(id: EPGGuideCancelID.epgRequest, cancelInFlight: true)

                let previewEffect: Effect<Action> = state.isAutoPreviewEnabled ? .run { [clock] send in
                    try await clock.sleep(for: .milliseconds(400))
                    await send(.startPreviewDebounce(channel, generation: previewGeneration))
                }.cancellable(id: EPGGuideCancelID.previewDebounce, cancelInFlight: true) : .none

                return .concatenate(
                    .cancel(id: EPGGuideCancelID.previewDebounce),
                    .cancel(id: EPGGuideCancelID.previewPlayback),
                    .merge(epgEffect, previewEffect)
                )

            case let .channelFocused(channel):
                guard let channel else {
                    state.previewGeneration &+= 1
                    return .cancel(id: EPGGuideCancelID.previewDebounce)
                }
                state.previewGeneration &+= 1
                let previewGeneration = state.previewGeneration
                guard state.isAutoPreviewEnabled else { return .cancel(id: EPGGuideCancelID.previewDebounce) }
                if state.activePreviewChannel?.id == channel.id, state.isPreviewPlaying {
                    return .none
                }
                return .concatenate(
                    .cancel(id: EPGGuideCancelID.previewDebounce),
                    .cancel(id: EPGGuideCancelID.previewPlayback),
                    .run { [clock] send in
                        try await clock.sleep(for: .milliseconds(400))
                        await send(.startPreviewDebounce(channel, generation: previewGeneration))
                    }
                    .cancellable(id: EPGGuideCancelID.previewDebounce, cancelInFlight: true)
                )

            case let .startPreviewDebounce(channel, generation):
                guard state.isAutoPreviewEnabled,
                      state.previewGeneration == generation,
                      state.selectedChannel?.id == channel.id
                else { return .none }
                state.activePreviewChannel = channel
                state.isPreviewPlaying = true
                let playbackID = UUID()
                return .concatenate(
                    .cancel(id: EPGGuideCancelID.previewPlayback),
                    .run { [previewPlayerClient, ownerID = state.presentationID, playbackID] send in
                        do {
                            try await previewPlayerClient.playPreviewOwned(channel, ownerID, playbackID)
                            await send(.previewPlaybackStarted(channel.id))
                        } catch {
                            guard !Task.isCancelled else { return }
                        }
                    }
                    .cancellable(id: EPGGuideCancelID.previewPlayback, cancelInFlight: true)
                )

            case .previewPlaybackStarted:
                return .none

            case .togglePreviewMute:
                state.isPreviewMuted.toggle()
                let isMuted = state.isPreviewMuted
                return .run { [previewPlayerClient] _ in
                    await previewPlayerClient.setMuted(isMuted)
                }

            case .stopPreview:
                state.previewGeneration &+= 1
                state.activePreviewChannel = nil
                state.isPreviewPlaying = false
                return .concatenate(
                    .cancel(id: EPGGuideCancelID.previewDebounce),
                    .cancel(id: EPGGuideCancelID.previewPlayback),
                    .run { [previewPlayerClient, ownerID = state.presentationID] _ in
                        await previewPlayerClient.stopPreviewOwned(ownerID)
                    }
                )

            case let .epgResponse(channelID, requestID, .success(listings)):
                guard state.selectedChannel?.id == channelID, state.epgRequestID == requestID else { return .none }
                state.epgRequestID = nil
                state.isLoadingEPG = false
                state.epgListings = listings
                state.loadedEPGChannelID = channelID
                return .none

            case let .epgResponse(channelID, requestID, .failure(error)):
                guard state.selectedChannel?.id == channelID, state.epgRequestID == requestID else { return .none }
                state.epgRequestID = nil
                state.isLoadingEPG = false
                state.errorMessage = error.localizedDescription
                return .none

            case .closeTapped:
                state.epgRequestID = nil
                state.isLoadingEPG = false
                state.previewGeneration &+= 1
                return .concatenate(
                    .cancel(id: EPGGuideCancelID.epgRequest),
                    .cancel(id: EPGGuideCancelID.previewDebounce),
                    .cancel(id: EPGGuideCancelID.previewPlayback),
                    .send(.delegate(.close))
                )

            case let .playTapped(channel):
                state.epgRequestID = nil
                state.isLoadingEPG = false
                state.previewGeneration &+= 1
                let startsMuted = settingsClient.startMuted()
                return .concatenate(
                    .cancel(id: EPGGuideCancelID.epgRequest),
                    .cancel(id: EPGGuideCancelID.previewDebounce),
                    .cancel(id: EPGGuideCancelID.previewPlayback),
                    .run { [previewPlayerClient, playerClient, ownerID = state.presentationID] send in
                        if let streamURL = channel.streamURL,
                           let handoff = await previewPlayerClient.takePreviewForPromotion(channel.id, streamURL)
                        {
                            await playerClient.adoptPreviewPlayer(handoff.player, handoff.streamURL, startsMuted)
                        } else {
                            await previewPlayerClient.stopPreviewOwned(ownerID)
                        }
                        await send(.delegate(.playChannel(channel)))
                    }
                )

            case let .playCatchUp(program, channel):
                let config = state.config
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return .none }
                state.previewGeneration &+= 1
                let archiveStart = program.startTime.addingTimeInterval(
                    TimeInterval(customEPGMappingClient.getCatchupTimeShift(channel.id) * 3600)
                )
                let startUnix = Int(archiveStart.timeIntervalSince1970)
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
                    state.epgRequestID = nil
                    state.isLoadingEPG = false
                    let catchupItem = MediaModels.Item(
                        id: "\(channel.id)_catchup_\(startUnix)",
                        title: "\(channel.title) (Tekrar: \(program.title))",
                        streamURL: finalURL,
                        coverURL: channel.coverURL,
                        logoURLOverride: channel.logoURLOverride,
                        categoryID: channel.categoryID,
                        type: .live,
                        epgChannelID: channel.epgChannelID,
                        userAgentOverride: channel.userAgentOverride
                    )
                    return .concatenate(
                        .cancel(id: EPGGuideCancelID.epgRequest),
                        .cancel(id: EPGGuideCancelID.previewDebounce),
                        .cancel(id: EPGGuideCancelID.previewPlayback),
                        .run { [previewPlayerClient, ownerID = state.presentationID] _ in
                            await previewPlayerClient.stopPreviewOwned(ownerID)
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
