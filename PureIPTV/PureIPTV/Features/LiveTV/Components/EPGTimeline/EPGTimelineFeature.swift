import ComposableArchitecture
import FactoryKit
import Foundation

private nonisolated enum EPGTimelineCancelID: Hashable, Sendable {
    case request(String)
    case clearSyncStatusMessage
}

@Reducer
public struct EPGTimelineFeature {
    @ObservableState
    public struct State: Equatable {
        public var config: PlaylistConfig
        public var channels: [MediaModels.Item]
        public var categories: [MediaModels.Category]
        public var selectedCategoryID: String?
        public var epgData: [String: [EPGProgram]] = [:] // streamID -> programs
        public var isLoading: [String: Bool] = [:]
        public var epgRequestIDs: [String: UUID] = [:]
        public var syncPendingEPGChannels: Set<String> = []

        public var currentTime: Date = .init()
        public var selectedDate: Date = .init()
        public var searchQuery: String = ""
        public var selectedProgramDetail: EPGProgram?
        public var selectedProgramChannel: MediaModels.Item?
        public var scheduledReminderIDs: Set<String> = []
        public var favoriteIDs: Set<String> = []
        public var isFavoritesOnly: Bool = false
        public var isSyncingEPG: Bool = false
        public var lastSyncTimestamp: Date?
        public var syncStatusMessage: String?

        // PiP-in-EPG Live Mini-Preview (Madde #25)
        public var activePreviewChannel: MediaModels.Item?
        public var isPiPActive: Bool = false
        public var isPreviewMuted: Bool = true
        public var isPreviewLoading: Bool = false
        public var previewErrorMessage: String?
        public var focusedChannelID: String?
        public var isAutoPreviewOnFocusEnabled: Bool = true

        public var lastSyncFormatted: String? {
            guard let lastSyncTimestamp else { return nil }
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: lastSyncTimestamp)
        }

        public var isViewingToday: Bool {
            Calendar.current.isDateInToday(selectedDate)
        }

        public var availableDates: [Date] {
            let calendar = Calendar.current
            let now = Date()
            return (0 ... 6).compactMap { dayOffset in
                calendar.date(byAdding: .day, value: -dayOffset, to: now)
            }
        }

        public var availableCategories: [MediaModels.Category] {
            if !categories.isEmpty {
                return categories
            }
            // Auto-extract categories from channels if categories list wasn't explicitly supplied
            let distinctIDs = Array(Set(channels.map(\.categoryID))).sorted()
            return distinctIDs.map { MediaModels.Category(id: $0, name: $0) }
        }

        public var filteredChannels: [MediaModels.Item] {
            var result = channels

            if isFavoritesOnly {
                result = result.filter { favoriteIDs.contains($0.id) }
            } else if let selectedCategoryID, !selectedCategoryID.isEmpty {
                result = result.filter { $0.categoryID == selectedCategoryID }
            }

            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                result = result.filter { channel in
                    if channel.title.localizedCaseInsensitiveContains(query) {
                        return true
                    }
                    if let programs = epgData[channel.id] {
                        return programs.contains { prog in
                            prog.title.localizedCaseInsensitiveContains(query) ||
                                prog.description.localizedCaseInsensitiveContains(query)
                        }
                    }
                    return false
                }
            }

            // Pin favorite channels to the top when not searching or filtering by favorites
            if query.isEmpty, !isFavoritesOnly {
                return result.sorted { a, b in
                    let aFav = favoriteIDs.contains(a.id)
                    let bFav = favoriteIDs.contains(b.id)
                    if aFav != bFav {
                        return aFav && !bFav
                    }
                    return false
                }
            }

            return result
        }

        public func isProgramMatchingSearch(_ program: EPGProgram) -> Bool {
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return false }
            return program.title.localizedCaseInsensitiveContains(query) ||
                program.description.localizedCaseInsensitiveContains(query)
        }

        public init(
            config: PlaylistConfig,
            channels: [MediaModels.Item],
            categories: [MediaModels.Category] = [],
            selectedCategoryID: String? = nil,
            selectedDate: Date = .init(),
            favoriteIDs: Set<String> = []
        ) {
            self.config = config
            self.channels = channels
            self.categories = categories
            self.selectedCategoryID = selectedCategoryID
            self.selectedDate = selectedDate
            self.favoriteIDs = favoriteIDs
        }
    }

    public enum Action {
        case onAppear
        case fetchEPG(streamID: String)
        case refreshEPG(streamID: String)
        case epgResponse(streamID: String, requestID: UUID, Result<[EPGProgram], Error>)
        case channelTapped(MediaModels.Item)
        case programTapped(EPGProgram, MediaModels.Item)
        case showProgramDetails(EPGProgram, MediaModels.Item)
        case dismissProgramDetails
        case selectCategory(String?)
        case selectDate(Date)
        case updateSearchQuery(String)
        case loadReminders
        case remindersLoaded(Set<String>)
        case toggleReminder(EPGProgram, MediaModels.Item)
        case toggleFavorite(MediaModels.Item)
        case toggleFavoritesOnly
        case loadFavorites
        case favoritesLoaded(Set<String>)
        case updateCurrentTime
        case refreshEPGTapped
        case performSync(forced: Bool)
        case syncCompleted(Date)
        case clearSyncStatusMessage
        case closeTapped
        case channelFocused(MediaModels.Item?)
        case startPreviewDebounce(MediaModels.Item)
        case previewStarted(channelID: String)
        case previewFailed(channelID: String, message: String)
        case togglePreviewMute
        case setPreviewMuted(Bool)
        case expandPreviewToFullscreen
        case togglePiPPreview(MediaModels.Item?)
        case closePiPPreview

        case delegate(Delegate)
        @CasePathable
        public enum Delegate: Equatable {
            case close
            case playChannel(MediaModels.Item)
        }
    }

    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.reminderClient) var reminderClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.previewPlayerClient) var previewPlayerClient
    @Injected(\.playerClient) var playerClient
    @Dependency(\.customEPGMappingClient) var customEPGMappingClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let shouldAutoSync = settingsClient.autoUpdateEPG()
                var effects: [Effect<Action>] = [
                    .send(.loadReminders),
                    .send(.loadFavorites),
                    .run { [clock] send in
                        for await _ in clock.timer(interval: .seconds(60)) {
                            await send(.updateCurrentTime)
                        }
                    },
                ]
                if shouldAutoSync {
                    if state.lastSyncTimestamp == nil || Date().timeIntervalSince(state.lastSyncTimestamp ?? .distantPast) > 4 * 3600 {
                        effects.append(.send(.performSync(forced: false)))
                    }
                }
                return .merge(effects)

            case .refreshEPGTapped:
                return .send(.performSync(forced: true))

            case .performSync:
                guard !state.isSyncingEPG else { return .none }
                state.isSyncingEPG = true
                state.syncStatusMessage = AppStrings.Player.syncing

                let channelsToPrewarm = Array(state.filteredChannels.prefix(20))
                state.syncPendingEPGChannels = Set(channelsToPrewarm.map(\.id))
                guard !channelsToPrewarm.isEmpty else {
                    return .merge(
                        .cancel(id: EPGTimelineCancelID.clearSyncStatusMessage),
                        .send(.syncCompleted(Date()))
                    )
                }

                return .merge(
                    .cancel(id: EPGTimelineCancelID.clearSyncStatusMessage),
                    .run { send in
                        await iptvClient.clearEPGCache()
                        for ch in channelsToPrewarm {
                            await send(.refreshEPG(streamID: ch.id))
                        }
                    }
                )

            case let .syncCompleted(date):
                guard state.isSyncingEPG else { return .none }
                state.isSyncingEPG = false
                state.lastSyncTimestamp = date
                state.syncPendingEPGChannels = []
                state.syncStatusMessage = AppStrings.Player.epgUpdated
                return .run { [clock] send in
                    try? await clock.sleep(for: .seconds(3))
                    await send(.clearSyncStatusMessage)
                }
                .cancellable(id: EPGTimelineCancelID.clearSyncStatusMessage, cancelInFlight: true)

            case .clearSyncStatusMessage:
                state.syncStatusMessage = nil
                return .none

            case .loadReminders:
                return .run { send in
                    let ids = await reminderClient.getScheduledReminderIDs()
                    await send(.remindersLoaded(ids))
                }

            case let .remindersLoaded(ids):
                state.scheduledReminderIDs = ids
                return .none

            case .loadFavorites:
                return .run { send in
                    if let favs = try? await databaseClient.fetchFavoritesByType("live") {
                        await send(.favoritesLoaded(Set(favs.map(\.id))))
                    }
                }

            case let .favoritesLoaded(ids):
                state.favoriteIDs = ids
                return .none

            case let .toggleFavorite(channel):
                let isFav = state.favoriteIDs.contains(channel.id)
                if isFav {
                    state.favoriteIDs.remove(channel.id)
                } else {
                    state.favoriteIDs.insert(channel.id)
                }
                let favItem = FavoriteItem(
                    id: channel.id,
                    type: "live",
                    title: channel.title,
                    coverURL: channel.coverURL?.absoluteString,
                    streamURL: channel.streamURL?.absoluteString
                )
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(favItem)
                }

            case .toggleFavoritesOnly:
                state.isFavoritesOnly.toggle()
                let channelsToPrewarm = Array(state.filteredChannels.prefix(15))
                return .run { send in
                    for ch in channelsToPrewarm {
                        await send(.fetchEPG(streamID: ch.id))
                    }
                }

            case let .toggleReminder(program, channel):
                let isScheduled = state.scheduledReminderIDs.contains(program.id)
                if isScheduled {
                    state.scheduledReminderIDs.remove(program.id)
                    return .run { _ in
                        await reminderClient.removeReminder(program.id)
                    }
                } else {
                    state.scheduledReminderIDs.insert(program.id)
                    return .run { _ in
                        _ = try? await reminderClient.requestAuthorization()
                        try? await reminderClient.scheduleReminder(program, channel, 5)
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
                let requestID = UUID()
                state.epgRequestIDs[streamID] = requestID
                return .run { send in
                    await send(.epgResponse(streamID: streamID, requestID: requestID, Result {
                        try await iptvClient.fetchShortEPG(config, streamID, 20)
                    }))
                }
                .cancellable(id: EPGTimelineCancelID.request(streamID), cancelInFlight: true)

            case let .refreshEPG(streamID):
                state.isLoading[streamID] = true
                let config = state.config
                let requestID = UUID()
                state.epgRequestIDs[streamID] = requestID
                return .run { send in
                    await send(.epgResponse(streamID: streamID, requestID: requestID, Result {
                        try await iptvClient.fetchShortEPG(config, streamID, 20)
                    }))
                }
                .cancellable(id: EPGTimelineCancelID.request(streamID), cancelInFlight: true)

            case let .epgResponse(streamID, requestID, .success(programs)):
                guard state.epgRequestIDs[streamID] == requestID else { return .none }
                state.epgRequestIDs[streamID] = nil
                state.isLoading[streamID] = false
                state.epgData[streamID] = programs
                let responseCompletedSyncChannel = state.syncPendingEPGChannels.remove(streamID) != nil
                if responseCompletedSyncChannel, state.isSyncingEPG, state.syncPendingEPGChannels.isEmpty {
                    return .send(.syncCompleted(Date()))
                }
                return .none

            case let .epgResponse(streamID, requestID, .failure):
                guard state.epgRequestIDs[streamID] == requestID else { return .none }
                state.epgRequestIDs[streamID] = nil
                state.isLoading[streamID] = false
                // Retain the last successful guide while refresh is failing.
                if state.epgData[streamID] == nil {
                    state.epgData[streamID] = []
                }
                let responseCompletedSyncChannel = state.syncPendingEPGChannels.remove(streamID) != nil
                if responseCompletedSyncChannel, state.isSyncingEPG, state.syncPendingEPGChannels.isEmpty {
                    return .send(.syncCompleted(Date()))
                }
                return .none

            case let .showProgramDetails(program, channel):
                state.selectedProgramDetail = program
                state.selectedProgramChannel = channel
                return .none

            case .dismissProgramDetails:
                state.selectedProgramDetail = nil
                state.selectedProgramChannel = nil
                return .none

            case let .selectCategory(categoryID):
                state.selectedCategoryID = categoryID
                let channelsToPrewarm = Array(state.filteredChannels.prefix(15))
                return .run { send in
                    for ch in channelsToPrewarm {
                        await send(.fetchEPG(streamID: ch.id))
                    }
                }

            case let .selectDate(date):
                state.selectedDate = date
                let channelsToPrewarm = Array(state.filteredChannels.prefix(15))
                return .run { send in
                    for ch in channelsToPrewarm {
                        await send(.fetchEPG(streamID: ch.id))
                    }
                }

            case let .updateSearchQuery(query):
                state.searchQuery = query
                let channelsToPrewarm = Array(state.filteredChannels.prefix(15))
                return .run { send in
                    for ch in channelsToPrewarm {
                        await send(.fetchEPG(streamID: ch.id))
                    }
                }

            case let .programTapped(program, channel):
                if program.endTime < Date(), channel.tvArchive == 1 {
                    let config = state.config
                    guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return .none }
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
                        let catchupItem = MediaModels.Item(
                            id: "\(channel.id)_catchup_\(startUnix)",
                            title: "\(channel.title) (Tekrar: \(program.title))",
                            streamURL: finalURL,
                            coverURL: channel.coverURL,
                            categoryID: channel.categoryID,
                            type: .live,
                            epgChannelID: channel.epgChannelID,
                            userAgentOverride: channel.userAgentOverride
                        )
                        return .concatenate(
                            .run { [previewPlayerClient] _ in
                                await previewPlayerClient.stopPreview()
                            },
                            .send(.delegate(.playChannel(catchupItem)))
                        )
                    }
                }
                return .none

            case let .channelTapped(channel):
                state.activePreviewChannel = nil
                state.isPiPActive = false
                state.isPreviewLoading = false
                state.previewErrorMessage = nil
                let startsMuted = settingsClient.startMuted()
                return .run { [previewPlayerClient, playerClient] send in
                    if let streamURL = channel.streamURL,
                       let handoff = await previewPlayerClient.takePreviewForPromotion(channel.id, streamURL)
                    {
                        await playerClient.adoptPreviewPlayer(handoff.player, handoff.streamURL, startsMuted)
                    } else {
                        await previewPlayerClient.stopPreview()
                    }
                    await send(.delegate(.playChannel(channel)))
                }

            case .closeTapped:
                return .concatenate(
                    .run { [previewPlayerClient] _ in
                        await previewPlayerClient.stopPreview()
                    },
                    .send(.delegate(.close))
                )

            case let .channelFocused(channel):
                state.focusedChannelID = channel?.id
                guard state.isAutoPreviewOnFocusEnabled, let channel else {
                    return .none
                }
                if state.activePreviewChannel?.id == channel.id, state.isPiPActive {
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
                state.isPiPActive = true
                state.isPreviewLoading = true
                state.previewErrorMessage = nil

                return .run { [previewPlayerClient] send in
                    do {
                        try await previewPlayerClient.playPreview(channel)
                        await send(.previewStarted(channelID: channel.id))
                    } catch {
                        await send(.previewFailed(channelID: channel.id, message: error.localizedDescription))
                    }
                }

            case .previewStarted:
                state.isPreviewLoading = false
                state.previewErrorMessage = nil
                return .none

            case let .previewFailed(_, message):
                state.isPreviewLoading = false
                state.previewErrorMessage = message
                return .none

            case .togglePreviewMute:
                state.isPreviewMuted.toggle()
                let isMuted = state.isPreviewMuted
                return .run { [previewPlayerClient] _ in
                    await previewPlayerClient.setMuted(isMuted)
                }

            case let .setPreviewMuted(isMuted):
                state.isPreviewMuted = isMuted
                return .run { [previewPlayerClient] _ in
                    await previewPlayerClient.setMuted(isMuted)
                }

            case .expandPreviewToFullscreen:
                guard let channel = state.activePreviewChannel else { return .none }
                state.activePreviewChannel = nil
                state.isPiPActive = false
                guard let streamURL = channel.streamURL else { return .none }
                let startsMuted = settingsClient.startMuted()
                return .run { [previewPlayerClient, playerClient] send in
                    if let handoff = await previewPlayerClient.takePreviewForPromotion(channel.id, streamURL) {
                        await playerClient.adoptPreviewPlayer(handoff.player, handoff.streamURL, startsMuted)
                    } else {
                        await previewPlayerClient.stopPreview()
                    }
                    await send(.delegate(.playChannel(channel)))
                }

            case let .togglePiPPreview(channel):
                if state.activePreviewChannel?.id == channel?.id, state.isPiPActive {
                    state.activePreviewChannel = nil
                    state.isPiPActive = false
                    state.isPreviewLoading = false
                    return .run { [previewPlayerClient] _ in
                        await previewPlayerClient.stopPreview()
                    }
                } else if let channel {
                    return .send(.startPreviewDebounce(channel))
                } else {
                    return .send(.closePiPPreview)
                }

            case .closePiPPreview:
                state.activePreviewChannel = nil
                state.isPiPActive = false
                state.isPreviewLoading = false
                state.previewErrorMessage = nil
                return .run { [previewPlayerClient] _ in
                    await previewPlayerClient.stopPreview()
                }

            case .delegate:
                return .none
            }
        }
    }
}
