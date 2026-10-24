import ComposableArchitecture
import FactoryKit
import Foundation

private func nextFavoriteChannelOrderRevision(after current: UInt64) -> UInt64 {
    let timeRevision = UInt64(max(0, Date().timeIntervalSince1970 * 1_000_000))
    return max(current &+ 1, timeRevision)
}

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
        public var providerOrderChannels: [MediaModels.Item] = []
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
        public var pendingReminderRequestIDs: [String: UUID] = [:]
        public var reminderLoadRequestID: UUID?
        public var favoriteIDs: Set<String> = []
        public var isFavoritesOnly: Bool = false
        public var favoriteSortMode: FavoriteChannelSortMode = .defaultOrder
        public var favoriteOrderIDs: [String] = []
        public var favoriteOrderRevision: UInt64 = 0
        public var favoriteLoadRequestID: UUID?
        public var channelLogoOverrideRequestIDs: [String: UUID] = [:]
        public var isSyncingEPG: Bool = false
        public var lastSyncTimestamp: Date?
        public var successfulEPGChannelCount = 0
        public var failedEPGChannelCount = 0
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
                result = FavoriteChannelSortMode.orderedItems(
                    result,
                    mode: favoriteSortMode,
                    providerOrder: providerOrderChannels.isEmpty ? channels : providerOrderChannels,
                    manualIDs: favoriteOrderIDs
                )
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
            providerOrderChannels: [MediaModels.Item] = [],
            categories: [MediaModels.Category] = [],
            selectedCategoryID: String? = nil,
            selectedDate: Date = .init(),
            favoriteIDs: Set<String> = []
        ) {
            self.config = config
            self.channels = channels
            self.providerOrderChannels = providerOrderChannels
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
        case remindersLoaded(requestID: UUID, Set<String>)
        case toggleReminder(EPGProgram, MediaModels.Item)
        case reminderScheduleResponse(programID: String, legacyProgramID: String, requestID: UUID, isScheduled: Bool)
        case toggleFavorite(MediaModels.Item)
        case saveChannelLogoOverride(channelID: String, rawValue: String?)
        case channelLogoOverrideSaved(
            channelID: String,
            playlistID: UUID,
            requestID: UUID,
            url: URL?
        )
        case logoOverridePropagated(channelID: String, playlistID: UUID, url: URL?)
        case toggleFavoritesOnly
        case loadFavorites
        case favoritesLoaded(requestID: UUID, ids: Set<String>, order: FavoriteChannelOrderSnapshot, playlistID: UUID, scope: ProfileContextSnapshot)
        case setFavoriteSortMode(FavoriteChannelSortMode)
        case moveFavorite(channelID: String, offset: Int)
        case updateCurrentTime
        case refreshEPGTapped
        case performSync(forced: Bool)
        case syncEPGCacheRefreshFailed
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
            case channelLogoOverrideChanged(channelID: String, playlistID: UUID, url: URL?)
        }
    }

    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.reminderClient) var reminderClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.previewPlayerClient) var previewPlayerClient
    @Injected(\.playerClient) var playerClient
    @Dependency(\.customEPGMappingClient) var customEPGMappingClient
    @Dependency(\.channelLogoOverrideClient) var channelLogoOverrideClient
    @Dependency(\.favoriteChannelOrderClient) var favoriteChannelOrderClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let profileContextClient = profileContextClient

        Reduce { state, action in
            switch action {
            case .onAppear:
                if state.lastSyncTimestamp == nil {
                    state.lastSyncTimestamp = settingsClient.getLastEPGRefreshDate(state.config.playlistID)
                }
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
                state.successfulEPGChannelCount = 0
                state.failedEPGChannelCount = 0

                let channelsToPrewarm = Array(state.filteredChannels.prefix(20))
                state.syncPendingEPGChannels = Set(channelsToPrewarm.map(\.id))
                guard !channelsToPrewarm.isEmpty else {
                    return .merge(
                        .cancel(id: EPGTimelineCancelID.clearSyncStatusMessage),
                        .send(.syncCompleted(Date()))
                    )
                }

                let config = state.config
                return .merge(
                    .cancel(id: EPGTimelineCancelID.clearSyncStatusMessage),
                    .run { [iptvClient] send in
                        do {
                            try await iptvClient.refreshEPGCache(config)
                        } catch {
                            guard !Task.isCancelled else { return }
                            await send(.syncEPGCacheRefreshFailed)
                            return
                        }
                        for ch in channelsToPrewarm {
                            await send(.refreshEPG(streamID: ch.id))
                        }
                    }
                )

            case .syncEPGCacheRefreshFailed:
                guard state.isSyncingEPG else { return .none }
                state.syncPendingEPGChannels = []
                state.failedEPGChannelCount = max(1, state.failedEPGChannelCount)
                return .send(.syncCompleted(Date()))

            case let .syncCompleted(date):
                guard state.isSyncingEPG else { return .none }
                state.isSyncingEPG = false
                state.syncPendingEPGChannels = []
                if state.successfulEPGChannelCount > 0 {
                    state.lastSyncTimestamp = date
                    settingsClient.setLastEPGRefreshDate(state.config.playlistID, date)
                }
                if state.failedEPGChannelCount > 0 {
                    state.syncStatusMessage = state.successfulEPGChannelCount > 0
                        ? AppStrings.Player.epgPartiallyUpdated(failedChannels: state.failedEPGChannelCount)
                        : AppStrings.Player.epgRefreshFailed
                } else if state.successfulEPGChannelCount > 0 {
                    state.syncStatusMessage = AppStrings.Player.epgUpdated
                } else {
                    state.syncStatusMessage = AppStrings.Player.epgNoChannelsToRefresh
                }
                return .run { [clock] send in
                    try? await clock.sleep(for: .seconds(3))
                    await send(.clearSyncStatusMessage)
                }
                .cancellable(id: EPGTimelineCancelID.clearSyncStatusMessage, cancelInFlight: true)

            case .clearSyncStatusMessage:
                state.syncStatusMessage = nil
                return .none

            case .loadReminders:
                let requestID = UUID()
                state.reminderLoadRequestID = requestID
                return .run { send in
                    let ids = await reminderClient.getScheduledReminderIDs()
                    await send(.remindersLoaded(requestID: requestID, ids))
                }

            case let .remindersLoaded(requestID, ids):
                guard state.reminderLoadRequestID == requestID else { return .none }
                state.reminderLoadRequestID = nil
                var reconciledIDs = ids
                for programID in state.pendingReminderRequestIDs.keys {
                    if state.scheduledReminderIDs.contains(programID) {
                        reconciledIDs.insert(programID)
                    } else {
                        reconciledIDs.remove(programID)
                    }
                }
                state.scheduledReminderIDs = reconciledIDs
                return .none

            case .loadFavorites:
                guard let playlistID = state.config.playlistID else {
                    state.favoriteLoadRequestID = nil
                    state.favoriteIDs = []
                    state.favoriteSortMode = .defaultOrder
                    state.favoriteOrderIDs = []
                    state.favoriteOrderRevision = 0
                    return .none
                }
                let profileScope = profileContextClient.snapshot()
                let requestID = UUID()
                state.favoriteLoadRequestID = requestID
                let orderClient = favoriteChannelOrderClient
                return .run { send in
                    guard let favs = try? await databaseClient.fetchFavoritesByType("live", profileScope) else { return }
                    let visible = favs.filter { $0.playlistID == playlistID }
                    let order = await orderClient.load(profileScope.profileID, playlistID)
                    await send(.favoritesLoaded(
                        requestID: requestID,
                        ids: Set(visible.map(\.id)),
                        order: order,
                        playlistID: playlistID,
                        scope: profileScope
                    ))
                }

            case let .favoritesLoaded(requestID, ids, storedOrder, playlistID, scope):
                guard
                    state.favoriteLoadRequestID == requestID,
                    profileContextClient.snapshot() == scope,
                    state.config.playlistID == playlistID
                else { return .none }
                state.favoriteLoadRequestID = nil
                state.favoriteIDs = ids
                let providerIDs = (state.providerOrderChannels.isEmpty ? state.channels : state.providerOrderChannels).map(\.id)
                let normalizedIDs = FavoriteChannelSortMode.normalizedManualIDs(
                    favoriteIDs: ids,
                    providerIDs: providerIDs,
                    storedIDs: storedOrder.orderedIDs
                )
                let changed = normalizedIDs != storedOrder.orderedIDs
                state.favoriteSortMode = storedOrder.mode
                state.favoriteOrderIDs = normalizedIDs
                state.favoriteOrderRevision = storedOrder.revision
                guard changed else { return .none }
                state.favoriteOrderRevision = nextFavoriteChannelOrderRevision(after: storedOrder.revision)
                let order = FavoriteChannelOrderSnapshot(
                    mode: storedOrder.mode,
                    orderedIDs: normalizedIDs,
                    revision: state.favoriteOrderRevision
                )
                let profileID = scope.profileID
                let orderClient = favoriteChannelOrderClient
                return .run { _ in
                    await orderClient.save(order, profileID, playlistID)
                }

            case let .setFavoriteSortMode(mode):
                state.favoriteLoadRequestID = nil
                guard let playlistID = state.config.playlistID else { return .none }
                state.favoriteSortMode = mode
                let order = FavoriteChannelOrderSnapshot(
                    mode: mode,
                    orderedIDs: FavoriteChannelSortMode.normalizedManualIDs(
                        favoriteIDs: state.favoriteIDs,
                        providerIDs: (state.providerOrderChannels.isEmpty ? state.channels : state.providerOrderChannels).map(\.id),
                        storedIDs: state.favoriteOrderIDs
                    ),
                    revision: nextFavoriteChannelOrderRevision(after: state.favoriteOrderRevision)
                )
                state.favoriteOrderIDs = order.orderedIDs
                state.favoriteOrderRevision = order.revision
                let scope = profileContextClient.snapshot()
                let orderClient = favoriteChannelOrderClient
                return .run { _ in
                    await orderClient.save(order, scope.profileID, playlistID)
                }

            case let .moveFavorite(channelID, offset):
                state.favoriteLoadRequestID = nil
                guard state.favoriteSortMode == .manual, let playlistID = state.config.playlistID else { return .none }
                let orderedIDs = FavoriteChannelSortMode.normalizedManualIDs(
                    favoriteIDs: state.favoriteIDs,
                    providerIDs: (state.providerOrderChannels.isEmpty ? state.channels : state.providerOrderChannels).map(\.id),
                    storedIDs: state.favoriteOrderIDs
                )
                guard let index = orderedIDs.firstIndex(of: channelID) else { return .none }
                let destination = index + offset
                guard orderedIDs.indices.contains(destination) else { return .none }
                var reordered = orderedIDs
                reordered.swapAt(index, destination)
                state.favoriteOrderIDs = reordered
                let order = FavoriteChannelOrderSnapshot(
                    mode: .manual,
                    orderedIDs: reordered,
                    revision: nextFavoriteChannelOrderRevision(after: state.favoriteOrderRevision)
                )
                state.favoriteOrderRevision = order.revision
                let scope = profileContextClient.snapshot()
                let orderClient = favoriteChannelOrderClient
                return .run { _ in
                    await orderClient.save(order, scope.profileID, playlistID)
                }

            case let .toggleFavorite(channel):
                state.favoriteLoadRequestID = nil
                guard let playlistID = state.config.playlistID else { return .none }
                let isFav = state.favoriteIDs.contains(channel.id)
                if isFav {
                    state.favoriteIDs.remove(channel.id)
                    state.favoriteOrderIDs.removeAll { $0 == channel.id }
                } else {
                    state.favoriteIDs.insert(channel.id)
                    state.favoriteOrderIDs.append(channel.id)
                }
                let profileScope = profileContextClient.snapshot()
                let order = FavoriteChannelOrderSnapshot(
                    mode: state.favoriteSortMode,
                    orderedIDs: FavoriteChannelSortMode.normalizedManualIDs(
                        favoriteIDs: state.favoriteIDs,
                        providerIDs: (state.providerOrderChannels.isEmpty ? state.channels : state.providerOrderChannels).map(\.id),
                        storedIDs: state.favoriteOrderIDs
                    ),
                    revision: nextFavoriteChannelOrderRevision(after: state.favoriteOrderRevision)
                )
                state.favoriteOrderIDs = order.orderedIDs
                state.favoriteOrderRevision = order.revision
                let favItem = FavoriteItem(
                    id: channel.id,
                    type: "live",
                    title: channel.title,
                    coverURL: channel.coverURL?.absoluteString,
                    streamURL: channel.streamURL?.absoluteString,
                    playlistID: state.config.playlistID
                )
                let orderClient = favoriteChannelOrderClient
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(favItem, profileScope)
                    await orderClient.save(order, profileScope.profileID, playlistID)
                }

            case let .saveChannelLogoOverride(channelID, rawValue):
                guard
                    let playlistID = state.config.playlistID,
                    state.channels.contains(where: { $0.id == channelID && $0.type == .live })
                else { return .none }
                let overrideURL: URL?
                if let rawValue {
                    guard let validated = ChannelLogoOverrideURL.validatedURL(from: rawValue) else { return .none }
                    overrideURL = validated
                } else {
                    overrideURL = nil
                }
                let requestID = UUID()
                state.channelLogoOverrideRequestIDs[channelID] = requestID
                let channelLogoOverrideClient = channelLogoOverrideClient
                return .run { send in
                    let storedURL = await channelLogoOverrideClient.setOverride(playlistID, channelID, rawValue)
                    await send(.channelLogoOverrideSaved(
                        channelID: channelID,
                        playlistID: playlistID,
                        requestID: requestID,
                        url: overrideURL == nil ? nil : storedURL
                    ))
                }

            case let .channelLogoOverrideSaved(channelID, playlistID, requestID, url):
                guard
                    state.channelLogoOverrideRequestIDs[channelID] == requestID,
                    state.config.playlistID == playlistID
                else { return .none }
                state.channelLogoOverrideRequestIDs[channelID] = nil
                state.channels = state.channels.map { channel in
                    channel.id == channelID ? channel.replacingLogoURLOverride(url) : channel
                }
                if state.activePreviewChannel?.id == channelID {
                    state.activePreviewChannel = state.activePreviewChannel?.replacingLogoURLOverride(url)
                }
                if state.selectedProgramChannel?.id == channelID {
                    state.selectedProgramChannel = state.selectedProgramChannel?.replacingLogoURLOverride(url)
                }
                return .send(.logoOverridePropagated(channelID: channelID, playlistID: playlistID, url: url))

            case let .logoOverridePropagated(channelID, playlistID, url):
                return .send(.delegate(.channelLogoOverrideChanged(
                    channelID: channelID,
                    playlistID: playlistID,
                    url: url
                )))

            case .toggleFavoritesOnly:
                state.isFavoritesOnly.toggle()
                let channelsToPrewarm = Array(state.filteredChannels.prefix(15))
                return .run { send in
                    for ch in channelsToPrewarm {
                        await send(.fetchEPG(streamID: ch.id))
                    }
                }

            case let .toggleReminder(program, channel):
                let reminderID = EPGReminderIdentifier.make(
                    config: state.config,
                    channelID: channel.id,
                    programID: program.id
                )
                guard state.pendingReminderRequestIDs[reminderID] == nil else { return .none }
                state.reminderLoadRequestID = nil
                let requestID = UUID()
                state.pendingReminderRequestIDs[reminderID] = requestID
                let isScheduled = state.scheduledReminderIDs.contains(reminderID)
                    || state.scheduledReminderIDs.contains(program.id)
                if isScheduled {
                    state.scheduledReminderIDs.remove(reminderID)
                    state.scheduledReminderIDs.remove(program.id)
                    return .run { send in
                        await reminderClient.removeReminder(reminderID)
                        if program.id != reminderID {
                            await reminderClient.removeReminder(program.id)
                        }
                        await send(.reminderScheduleResponse(
                            programID: reminderID,
                            legacyProgramID: program.id,
                            requestID: requestID,
                            isScheduled: false
                        ))
                    }
                } else {
                    let namespacedProgram = EPGProgram(
                        id: reminderID,
                        title: program.title,
                        description: program.description,
                        startTime: program.startTime,
                        endTime: program.endTime,
                        isPlayingNow: program.isPlayingNow
                    )
                    return .run { send in
                        do {
                            guard try await reminderClient.requestAuthorization() else {
                                await send(.reminderScheduleResponse(
                                    programID: reminderID,
                                    legacyProgramID: program.id,
                                    requestID: requestID,
                                    isScheduled: false
                                ))
                                return
                            }
                            try await reminderClient.scheduleReminder(namespacedProgram, channel, 5)
                            let scheduledIDs = await reminderClient.getScheduledReminderIDs()
                            await send(.reminderScheduleResponse(
                                programID: reminderID,
                                legacyProgramID: program.id,
                                requestID: requestID,
                                isScheduled: scheduledIDs.contains(reminderID)
                            ))
                        } catch {
                            await send(.reminderScheduleResponse(
                                programID: reminderID,
                                legacyProgramID: program.id,
                                requestID: requestID,
                                isScheduled: false
                            ))
                        }
                    }
                }

            case let .reminderScheduleResponse(programID, legacyProgramID, requestID, isScheduled):
                guard state.pendingReminderRequestIDs[programID] == requestID else { return .none }
                state.pendingReminderRequestIDs.removeValue(forKey: programID)
                if isScheduled {
                    state.scheduledReminderIDs.insert(programID)
                } else {
                    state.scheduledReminderIDs.remove(programID)
                    state.scheduledReminderIDs.remove(legacyProgramID)
                }
                return .none

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
                if responseCompletedSyncChannel {
                    state.successfulEPGChannelCount += 1
                }
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
                if responseCompletedSyncChannel {
                    state.failedEPGChannelCount += 1
                }
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
                            logoURLOverride: channel.logoURLOverride,
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
