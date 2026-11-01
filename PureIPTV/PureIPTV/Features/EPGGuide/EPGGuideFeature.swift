import ComposableArchitecture
import FactoryKit
import Foundation
import SwiftVLC

private nonisolated enum EPGGuideCancelID: Hashable, Sendable {
    case epgRequest
    case epgSourceIdentity
    case previewDebounce
    case previewPlayback
    case playbackHandoff
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
        public var epgSourceIdentity: EPGSourceIdentity?
        public var epgSourceRequestID: UUID?

        public var epgFreshnessLabel: String {
            let label: String
            if epgSourceIdentity == nil {
                label = lastEPGRefreshFailureDate == nil
                    ? AppStrings.Player.epgFreshnessUnknown
                    : AppStrings.Player.epgLastRefreshIssue
            } else if let lastEPGRefreshDate {
                let age = max(0, Date().timeIntervalSince(lastEPGRefreshDate))
                if let failureDate = lastEPGRefreshFailureDate, failureDate >= lastEPGRefreshDate {
                    label = AppStrings.Player.epgLastRefreshIssue + " · " + AppStrings.Player.epgDataAge(age)
                } else if age >= 86400 {
                    label = AppStrings.Player.epgDataStale + " · " + AppStrings.Player.epgDataAge(age)
                } else {
                    label = AppStrings.Player.epgDataAge(age)
                }
            } else {
                label = lastEPGRefreshFailureDate == nil
                    ? AppStrings.Player.epgFreshnessUnknown
                    : AppStrings.Player.epgLastRefreshIssue
            }
            return label + " · " + AppStrings.Player.epgThisDevice
        }

        // Live EPG Preview (Madde #25)
        public var activePreviewChannel: MediaModels.Item?
        public var isPreviewMuted: Bool = true
        public var isPreviewPlaying: Bool = false
        #if os(tvOS)
            public var isAutoPreviewEnabled: Bool = true
        #else
            public var isAutoPreviewEnabled: Bool = false
        #endif
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

    @CasePathable
    public enum Action {
        case onAppear
        case onDisappear
        case selectChannel(MediaModels.Item)
        case epgResponse(channelID: String, requestID: UUID, sourceFingerprint: String?, Result<[EPGProgram], Error>)
        case epgSourceIdentityLoaded(requestID: UUID, identity: EPGSourceIdentity?)
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
            case playChannel(MediaModels.Item, focusChannelID: String, presentationID: UUID)
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
                state.lastEPGRefreshDate = nil
                state.lastEPGRefreshFailureDate = nil
                state.epgSourceIdentity = nil
                let sourceRequestID = UUID()
                state.epgSourceRequestID = sourceRequestID
                let config = state.config
                let sourceEffect = Effect<Action>.run { [iptvClient] send in
                    let identity = await iptvClient.resolveEPGSourceIdentity(config)
                    guard !Task.isCancelled else { return }
                    await send(.epgSourceIdentityLoaded(requestID: sourceRequestID, identity: identity))
                }
                .cancellable(id: EPGGuideCancelID.epgSourceIdentity, cancelInFlight: true)
                if let channel = state.selectedChannel {
                    if state.loadedEPGChannelID == channel.id, state.errorMessage == nil {
                        return .merge(sourceEffect, .send(.channelFocused(channel)))
                    }
                    return .merge(sourceEffect, .send(.selectChannel(channel)))
                }
                return sourceEffect

            case .onDisappear:
                state.isVisible = false
                state.epgSourceRequestID = nil
                state.epgRequestID = nil
                state.isLoadingEPG = false
                state.previewGeneration &+= 1
                state.activePreviewChannel = nil
                state.isPreviewPlaying = false
                return .merge(
                    .cancel(id: EPGGuideCancelID.epgRequest),
                    .cancel(id: EPGGuideCancelID.epgSourceIdentity),
                    .cancel(id: EPGGuideCancelID.previewDebounce),
                    .cancel(id: EPGGuideCancelID.previewPlayback),
                    .cancel(id: EPGGuideCancelID.playbackHandoff),
                    .run { [previewPlayerClient, ownerID = state.presentationID] _ in
                        await previewPlayerClient.stopPreviewOwned(ownerID)
                    }
                )

            case let .selectChannel(channel):
                guard state.isVisible else { return .none }
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
                let sourceRequestID = state.epgSourceRequestID
                let sourceFingerprint = state.epgSourceIdentity?.fingerprint

                let epgEffect: Effect<Action> = .run { [iptvClient] send in
                    let result = await Result {
                        try await iptvClient.fetchShortEPG(config, streamID, channel.epgChannelID, 20)
                    }
                    guard !Task.isCancelled else { return }
                    if let sourceRequestID {
                        let identity = await iptvClient.resolveEPGSourceIdentity(config)
                        guard !Task.isCancelled else { return }
                        await send(.epgSourceIdentityLoaded(requestID: sourceRequestID, identity: identity))
                    }
                    await send(.epgResponse(
                        channelID: streamID,
                        requestID: requestID,
                        sourceFingerprint: sourceFingerprint,
                        result
                    ))
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
                guard state.isVisible else { return .none }
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
                guard state.isVisible,
                      state.isAutoPreviewEnabled,
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

            case let .epgSourceIdentityLoaded(requestID, identity):
                guard state.isVisible, state.epgSourceRequestID == requestID else { return .none }
                state.epgSourceIdentity = identity
                guard let identity else {
                    state.lastEPGRefreshDate = nil
                    state.lastEPGRefreshFailureDate = nil
                    return .none
                }
                let status = settingsClient.resolveEPGRefreshStatus(state.config.playlistID, identity.fingerprint)
                state.lastEPGRefreshDate = status.lastSuccessDate
                state.lastEPGRefreshFailureDate = status.lastFailureDate
                guard status.sourceChanged else { return .none }
                state.epgListings = []
                state.loadedEPGChannelID = nil
                state.errorMessage = nil
                guard !state.isLoadingEPG, let channel = state.selectedChannel else { return .none }
                return .send(.selectChannel(channel))

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

            case let .epgResponse(channelID, requestID, sourceFingerprint, .success(listings)):
                guard state.isVisible,
                      state.selectedChannel?.id == channelID,
                      state.epgRequestID == requestID
                else { return .none }
                guard sourceFingerprint == state.epgSourceIdentity?.fingerprint else {
                    state.epgRequestID = nil
                    state.isLoadingEPG = false
                    state.epgListings = []
                    state.loadedEPGChannelID = nil
                    guard let channel = state.selectedChannel else { return .none }
                    return .send(.selectChannel(channel))
                }
                state.epgRequestID = nil
                state.isLoadingEPG = false
                state.epgListings = listings
                state.loadedEPGChannelID = channelID
                return .none

            case let .epgResponse(channelID, requestID, sourceFingerprint, .failure(error)):
                guard state.isVisible,
                      state.selectedChannel?.id == channelID,
                      state.epgRequestID == requestID
                else { return .none }
                guard sourceFingerprint == state.epgSourceIdentity?.fingerprint else {
                    state.epgRequestID = nil
                    state.isLoadingEPG = false
                    state.epgListings = []
                    state.loadedEPGChannelID = nil
                    guard let channel = state.selectedChannel else { return .none }
                    return .send(.selectChannel(channel))
                }
                state.epgRequestID = nil
                state.isLoadingEPG = false
                state.errorMessage = error.localizedDescription
                return .none

            case .closeTapped:
                guard state.isVisible else { return .none }
                state.isVisible = false
                state.epgSourceRequestID = nil
                state.epgRequestID = nil
                state.isLoadingEPG = false
                state.previewGeneration &+= 1
                return .concatenate(
                    .cancel(id: EPGGuideCancelID.epgRequest),
                    .cancel(id: EPGGuideCancelID.epgSourceIdentity),
                    .cancel(id: EPGGuideCancelID.previewDebounce),
                    .cancel(id: EPGGuideCancelID.previewPlayback),
                    .cancel(id: EPGGuideCancelID.playbackHandoff),
                    .send(.delegate(.close))
                )

            case let .playTapped(channel):
                guard state.isVisible, channel.streamURL != nil else { return .none }
                state.isVisible = false
                state.epgSourceRequestID = nil
                state.epgRequestID = nil
                state.isLoadingEPG = false
                state.previewGeneration &+= 1
                let startsMuted = settingsClient.startMuted()
                let presentationID = state.presentationID
                let ownerID = state.presentationID
                let playbackEffect = Effect<Action>.run { [previewPlayerClient, playerClient, ownerID, presentationID] send in
                    guard !Task.isCancelled else { return }
                    var promotedHandoff: PreviewPlayerHandoff?
                    if let streamURL = channel.streamURL,
                       let handoff = await previewPlayerClient.takePreviewForPromotion(channel.id, streamURL)
                    {
                        let promotion = await MainActor.run { () -> PreviewPlayerHandoff? in
                            guard !Task.isCancelled else {
                                handoff.player.stop()
                                return nil
                            }
                            playerClient.adoptPreviewPlayer(handoff.player, handoff.streamURL, startsMuted, ownerID)
                            return handoff
                        }
                        guard let promotion else { return }
                        promotedHandoff = promotion
                    } else {
                        guard !Task.isCancelled else { return }
                        await previewPlayerClient.stopPreviewOwned(ownerID)
                    }
                    guard !Task.isCancelled else {
                        if let promotedHandoff {
                            await MainActor.run {
                                playerClient.discardPreviewPromotion(promotedHandoff.player, promotedHandoff.streamURL, ownerID)
                            }
                        }
                        return
                    }
                    // Once the delegate is sent, Guide disappearance is the expected
                    // route transition. Let the Player consume the promotion.
                    await send(.delegate(.playChannel(
                        channel,
                        focusChannelID: channel.id,
                        presentationID: presentationID
                    )))
                }
                .cancellable(id: EPGGuideCancelID.playbackHandoff, cancelInFlight: true)
                return .concatenate(
                    .cancel(id: EPGGuideCancelID.epgRequest),
                    .cancel(id: EPGGuideCancelID.epgSourceIdentity),
                    .cancel(id: EPGGuideCancelID.previewDebounce),
                    .cancel(id: EPGGuideCancelID.previewPlayback),
                    playbackEffect
                )

            case let .playCatchUp(program, channel):
                guard state.isVisible else { return .none }
                let config = state.config
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return .none }
                let catchupTimeShiftHours = customEPGMappingClient.getCatchupTimeShift(
                    channel.id,
                    channel.playlistID ?? config.playlistID
                )
                let archiveStart = program.startTime.addingTimeInterval(TimeInterval(catchupTimeShiftHours * 3600))
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
                    state.isVisible = false
                    state.epgSourceRequestID = nil
                    state.previewGeneration &+= 1
                    state.epgRequestID = nil
                    state.isLoadingEPG = false
                    let catchupItem = MediaModels.Item(
                        id: "\(channel.id)_catchup_\(startUnix)",
                        title: "\(channel.title) (Tekrar: \(program.title))",
                        streamURL: finalURL,
                        coverURL: channel.coverURL,
                        logoURLOverride: channel.logoURLOverride,
                        logoOverrideStorageKey: channel.logoOverrideStorageKey,
                        categoryID: channel.categoryID,
                        type: .live,
                        epgChannelID: channel.epgChannelID,
                        userAgentOverride: channel.userAgentOverride
                    )
                    let presentationID = state.presentationID
                    let ownerID = state.presentationID
                    let playbackEffect = Effect<Action>.run { [previewPlayerClient, ownerID, presentationID] send in
                        guard !Task.isCancelled else { return }
                        await previewPlayerClient.stopPreviewOwned(ownerID)
                        guard !Task.isCancelled else { return }
                        await send(.delegate(.playChannel(
                            catchupItem,
                            focusChannelID: channel.id,
                            presentationID: presentationID
                        )))
                    }
                    .cancellable(id: EPGGuideCancelID.playbackHandoff, cancelInFlight: true)
                    return .concatenate(
                        .cancel(id: EPGGuideCancelID.epgRequest),
                        .cancel(id: EPGGuideCancelID.epgSourceIdentity),
                        .cancel(id: EPGGuideCancelID.previewDebounce),
                        .cancel(id: EPGGuideCancelID.previewPlayback),
                        playbackEffect
                    )
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
