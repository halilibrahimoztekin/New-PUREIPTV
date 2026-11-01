import ComposableArchitecture
import FactoryKit
import Foundation
import SwiftVLC

public enum EPGTimelinePreferenceKeys {
    public static let hideChannelsWithoutPrograms = "com.pureiptv.tvOSHideEPGChannelsWithoutPrograms"
}

private func nextFavoriteChannelOrderRevision(after current: UInt64) -> UInt64 {
    let timeRevision = UInt64(max(0, Date().timeIntervalSince1970 * 1_000_000))
    return max(current &+ 1, timeRevision)
}

private nonisolated enum EPGTimelineCancelID: Hashable, Sendable {
    case syncEPG
    case request(String)
    case clearSyncStatusMessage
    case clockTimer
    case epgSourceIdentity
    case previewDebounce
    case previewPlayback
    case playbackHandoff
    case loadReminders
    case loadFavorites
    case loadRecentChannels
}

private func epgTimelinePlaybackHandoffEffect(
    channel: MediaModels.Item,
    ownerID: UUID,
    presentationID: UUID,
    startsMuted: Bool,
    previewPlayerClient: PreviewPlayerClient,
    playerClient: PlayerClient
) -> Effect<EPGTimelineFeature.Action> {
    Effect<EPGTimelineFeature.Action>.run { [previewPlayerClient, playerClient] send in
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

        await send(.delegate(.playChannel(channel, presentationID: presentationID)))
    }
    .cancellable(id: EPGTimelineCancelID.playbackHandoff, cancelInFlight: true)
}

private func discardEPGResponseFromPreviousSource(
    state: inout EPGTimelineFeature.State,
    streamID: String
) -> Effect<EPGTimelineFeature.Action> {
    let activeStreamIDs = Array(state.epgRequestIDs.keys)
    state.epgData = [:]
    state.epgLoadFailures = []
    state.epgAutomaticRetryCounts = [:]
    state.epgAutomaticRetryAfter = [:]
    state.epgRequestIDs = [:]
    state.isLoading = [:]
    let requestCancellations: [Effect<EPGTimelineFeature.Action>] = activeStreamIDs.map {
        .cancel(id: EPGTimelineCancelID.request($0))
    }

    guard state.isSyncingEPG else {
        return .merge(requestCancellations + [.send(.fetchEPG(streamID: streamID))])
    }

    state.isSyncingEPG = false
    state.activeEPGSyncID = nil
    state.lastCompletedEPGSyncID = nil
    state.syncPendingEPGChannels = []
    state.successfulEPGChannelCount = 0
    state.failedEPGChannelCount = 0
    state.syncStatusMessage = nil

    return .merge(
        [.cancel(id: EPGTimelineCancelID.syncEPG), .cancel(id: EPGTimelineCancelID.clearSyncStatusMessage)]
            + requestCancellations
            + [.send(.performSync(forced: true))]
    )
}

private func epgRetryDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private func epgProviderRateLimitMessage(retryAfter: Date?) -> String {
    guard let retryAfter else { return AppStrings.Player.epgProviderRateLimitedWithoutDate }
    return AppStrings.Player.epgProviderCooldownUntil(epgRetryDateText(retryAfter))
}

@Reducer
public struct EPGTimelineFeature {
    @ObservableState
    public struct State: Equatable {
        public var presentationID: UUID
        public var config: PlaylistConfig
        public var channels: [MediaModels.Item]
        public var providerOrderChannels: [MediaModels.Item] = []
        public var categories: [MediaModels.Category]
        public var selectedCategoryID: String?
        public var epgData: [String: [EPGProgram]] = [:] // streamID -> programs
        public var isLoading: [String: Bool] = [:]
        public var epgLoadFailures: Set<String> = []
        // Repeated row appearances use a per-channel backoff instead of request bursts.
        public var epgAutomaticRetryCounts: [String: Int] = [:]
        public var epgAutomaticRetryAfter: [String: Date] = [:]
        public var epgRequestIDs: [String: UUID] = [:]
        public var syncPendingEPGChannels: Set<String> = []
        public var activeEPGSyncID: UUID?
        public var activeEPGRefreshProfileID: UUID?
        public var activeEPGAutomaticRefresh = false
        public var pendingAutomaticEPGRefreshProfileID: UUID?
        public var isAutomaticEPGRefreshDeferred = false
        public var isEPGNetworkCostCheckPending = false
        public var epgNetworkCostCheckRequestID: UUID?
        public var pendingEPGPrewarmAfterNetworkCostCheck = false
        public var isEPGRefreshManuallyAuthorizedOnConstrainedNetwork = false
        public var lastCompletedEPGSyncID: UUID?

        public var currentTime: Date = .init()
        public var selectedDate: Date = .init()
        public var availableProgramCategories: [String] = []
        public var savedHorizontalOffset: CGFloat?
        public var savedFocusedProgramID: String?
        public var savedFocusedChannelID: String?
        public var selectedProgramCategory: String?
        public var searchQuery: String = ""
        public var selectedProgramDetail: EPGProgram?
        public var selectedProgramChannel: MediaModels.Item?
        public var selectedProgramDetailRequestID: UUID?
        public var scheduledReminderIDs: Set<String> = []
        public var pendingReminderRequestIDs: [String: UUID] = [:]
        public var reminderLoadRequestID: UUID?
        public var favoriteIDs: Set<String> = []
        public var defaultFavoriteIDs: Set<String> = []
        public var favoriteListID: UUID?
        public var isFavoritesOnly: Bool = false
        public var favoriteSortMode: FavoriteChannelSortMode = .defaultOrder
        public var favoriteOrderIDs: [String] = []
        public var favoriteOrderRevision: UInt64 = 0
        public var favoriteLoadRequestID: UUID?
        public var channelLogoOverrideRequestIDs: [String: UUID] = [:]
        public var isSyncingEPG: Bool = false
        public var lastSyncTimestamp: Date?
        public var lastSyncFailureTimestamp: Date?
        public var epgSourceIdentity: EPGSourceIdentity?
        public var epgSourceRequestID: UUID?
        public var providerCooldownUntil: Date?
        public var isProviderRateLimited = false
        public var isVisible = false
        public var successfulEPGChannelCount = 0
        public var failedEPGChannelCount = 0
        public var syncStatusMessage: String?
        public var recentChannelIDs: Set<String> = []
        public var recentChannelSnapshotRevision: UInt64 = 0
        public var recentChannelSnapshotPlaylistID: UUID?
        public var recentChannelSnapshotProfileScope: ProfileContextSnapshot?
        public var recentChannelLoadRequestID: UUID?
        public var pendingRecentChannelRemovalIDs: [String: UUID] = [:]

        // PiP-in-EPG Live Mini-Preview (Madde #25)
        public var activePreviewChannel: MediaModels.Item?
        public var isPiPActive: Bool = false
        public var isPreviewMuted: Bool = true
        public var isPreviewLoading: Bool = false
        public var previewErrorMessage: String?
        public var previewPlaybackID: UUID?
        public var focusedChannelID: String?

        public var lastSyncFormatted: String? {
            guard let lastSyncTimestamp else { return nil }
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: lastSyncTimestamp)
        }

        public var providerCooldownFormatted: String? {
            guard let providerCooldownUntil, providerCooldownUntil > currentTime else { return nil }
            return epgRetryDateText(providerCooldownUntil)
        }

        public var epgFreshnessLabel: String {
            let label: String
            if epgSourceIdentity == nil {
                label = lastSyncFailureTimestamp == nil
                    ? AppStrings.Player.epgFreshnessUnknown
                    : AppStrings.Player.epgLastRefreshIssue
            } else if let lastSyncTimestamp {
                let age = max(0, currentTime.timeIntervalSince(lastSyncTimestamp))
                if let lastSyncFailureTimestamp, lastSyncFailureTimestamp >= lastSyncTimestamp {
                    label = AppStrings.Player.epgLastRefreshIssue + " · " + AppStrings.Player.epgDataAge(age)
                } else if age >= 86400 {
                    label = AppStrings.Player.epgDataStale + " · " + AppStrings.Player.epgDataAge(age)
                } else {
                    label = AppStrings.Player.epgDataAge(age)
                }
            } else {
                label = lastSyncFailureTimestamp == nil
                    ? AppStrings.Player.epgFreshnessUnknown
                    : AppStrings.Player.epgLastRefreshIssue
            }
            return label + " · " + AppStrings.Player.epgThisDevice
        }

        public var epgDiagnosticsText: String {
            let playlistID = config.playlistID?.uuidString ?? "—"
            let source = epgSourceIdentity?.displayLabel ?? "—"
            let lastSuccess = lastSyncTimestamp?.formatted(date: .abbreviated, time: .shortened)
                ?? "—"
            let lastFailure = lastSyncFailureTimestamp?.formatted(date: .abbreviated, time: .shortened)
                ?? "—"
            return AppStrings.Player.epgDiagnosticsMessage(
                playlistID: playlistID,
                source: source,
                lastSuccess: lastSuccess,
                lastFailure: lastFailure
            )
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

            if let selectedProgramCategory {
                let day = Calendar.current.dateInterval(of: .day, for: selectedDate)
                result = result.filter { channel in
                    // EPG is fetched lazily as rows appear. Keep unknown channels
                    // and failed channels visible so they can retry; exclude only
                    // channels whose loaded guide is known not to match this filter.
                    if epgLoadFailures.contains(channel.id) {
                        return true
                    }
                    guard let programs = epgData[channel.id] else { return true }
                    guard let day else { return false }
                    return programs.contains { program in
                        program.startTime < day.end
                            && program.endTime > day.start
                            && program.categories.contains {
                                $0.localizedCaseInsensitiveCompare(selectedProgramCategory) == .orderedSame
                            }
                    }
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

        mutating func rebuildAvailableProgramCategories() {
            guard let day = Calendar.current.dateInterval(of: .day, for: selectedDate) else {
                availableProgramCategories = []
                return
            }
            let values = epgData.values.flatMap(\.self).filter {
                $0.startTime < day.end && $0.endTime > day.start
            }.flatMap(\.categories).compactMap { category -> String? in
                let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            let sorted = values.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            availableProgramCategories = sorted.reduce(into: [String]()) { unique, category in
                if !unique.contains(where: { $0.localizedCaseInsensitiveCompare(category) == .orderedSame }) {
                    unique.append(category)
                }
            }
        }

        public init(
            config: PlaylistConfig,
            channels: [MediaModels.Item],
            providerOrderChannels: [MediaModels.Item] = [],
            categories: [MediaModels.Category] = [],
            selectedCategoryID: String? = nil,
            selectedDate: Date = .init(),
            favoriteIDs: Set<String> = [],
            favoriteListID: UUID? = nil,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.config = config
            self.channels = channels
            self.providerOrderChannels = providerOrderChannels
            self.categories = categories
            self.selectedCategoryID = selectedCategoryID
            self.selectedDate = selectedDate
            self.favoriteIDs = favoriteIDs
            self.favoriteListID = favoriteListID
        }
    }

    public enum Action {
        case onAppear
        case onDisappear(horizontalOffset: CGFloat, focusedProgramID: String?, focusedChannelID: String?)
        case saveNavigationState(horizontalOffset: CGFloat, focusedProgramID: String?, focusedChannelID: String?)
        case loadRecentChannels
        case recentChannelsLoaded(requestID: UUID, ids: Set<String>, revision: UInt64, playlistID: UUID, profileScope: ProfileContextSnapshot)
        case removeRecentChannel(MediaModels.Item)
        case recentChannelRemoved(channelID: String, requestID: UUID, ids: Set<String>, revision: UInt64, playlistID: UUID, profileScope: ProfileContextSnapshot)
        case fetchEPG(streamID: String)
        case refreshEPG(streamID: String)
        case epgResponse(streamID: String, requestID: UUID, sourceFingerprint: String?, Result<[EPGProgram], Error>)
        case channelTapped(MediaModels.Item)
        case programTapped(EPGProgram, MediaModels.Item)
        case showProgramDetails(EPGProgram, MediaModels.Item)
        case dismissProgramDetails
        case dismissProgramDetailsIfCurrent(UUID)
        case selectCategory(String?)
        case selectProgramCategory(String?)
        case selectDate(Date)
        case updateSearchQuery(String)
        case loadReminders
        case remindersLoaded(requestID: UUID, Set<String>)
        case toggleReminder(EPGProgram, MediaModels.Item)
        case reminderScheduleResponse(programID: String, legacyProgramID: String, requestID: UUID, isScheduled: Bool)
        case reminderSchedulingFailed
        case toggleFavorite(MediaModels.Item)
        case bulkDefaultFavoritesChanged(defaultIDs: Set<String>, changedIDsInProviderOrder: [String], operation: BulkFavoriteOperation)
        case editChannelLogo(MediaModels.Item)
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
        case favoritesLoaded(requestID: UUID, ids: Set<String>, defaultIDs: Set<String>, order: FavoriteChannelOrderSnapshot, playlistID: UUID, scope: ProfileContextSnapshot)
        case setFavoriteSortMode(FavoriteChannelSortMode)
        case moveFavorite(channelID: String, offset: Int)
        case updateCurrentTime
        case refreshEPGTapped
        case performSync(forced: Bool)
        case networkPathCostLoaded(requestID: UUID, isConstrainedOrExpensive: Bool)
        case epgSourceIdentityLoaded(requestID: UUID, identity: EPGSourceIdentity?)
        case syncEPGCacheRefreshFailed(syncID: UUID, error: NetworkError?)
        case syncEPGSourceRefreshed(syncID: UUID, channels: [MediaModels.Item], requestIDs: [String: UUID])
        case cancelEPGSync
        case syncCompleted(syncID: UUID, date: Date)
        case clearSyncStatusMessage(syncID: UUID)
        case closeTapped
        case channelFocused(MediaModels.Item?)
        case focusedPreviewDelayElapsed(MediaModels.Item)
        case startPreviewDebounce(MediaModels.Item)
        case previewStarted(channelID: String, playbackID: UUID)
        case previewFailed(channelID: String, playbackID: UUID, message: String)
        case togglePreviewMute
        case setPreviewMuted(Bool)
        case expandPreviewToFullscreen
        case togglePiPPreview(MediaModels.Item?)
        case closePiPPreview

        case delegate(Delegate)
        @CasePathable
        public enum Delegate: Equatable {
            case close
            case playChannel(MediaModels.Item, presentationID: UUID)
            case channelLogoOverrideChanged(channelID: String, playlistID: UUID, url: URL?)
            case presentProgramDetails(
                timelinePresentationID: UUID,
                detailRequestID: UUID,
                program: EPGProgram,
                channel: MediaModels.Item
            )
            case presentChannelLogoEditor(timelinePresentationID: UUID, channelID: String)
        }
    }

    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.reminderClient) var reminderClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.recentChannelsClient) var recentChannelsClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.playlistRefreshScheduleClient) var playlistRefreshScheduleClient
    @Dependency(\.networkPathStatusClient) var networkPathStatusClient
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
        let playlistRefreshScheduleClient = playlistRefreshScheduleClient
        let networkPathStatusClient = networkPathStatusClient

        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isVisible else { return .none }
                state.isVisible = true
                state.lastSyncTimestamp = nil
                state.lastSyncFailureTimestamp = nil
                state.epgSourceIdentity = nil
                state.isAutomaticEPGRefreshDeferred = false
                state.isEPGNetworkCostCheckPending = false
                state.epgNetworkCostCheckRequestID = nil
                state.pendingEPGPrewarmAfterNetworkCostCheck = false
                state.isEPGRefreshManuallyAuthorizedOnConstrainedNetwork = false
                let sourceRequestID = UUID()
                state.epgSourceRequestID = sourceRequestID
                let config = state.config
                let shouldCheckNetworkCost = settingsClient.deferAutoEPGRefreshOnConstrainedNetwork()
                state.isEPGNetworkCostCheckPending = shouldCheckNetworkCost
                state.epgNetworkCostCheckRequestID = shouldCheckNetworkCost ? sourceRequestID : nil
                state.pendingEPGPrewarmAfterNetworkCostCheck = shouldCheckNetworkCost
                state.providerCooldownUntil = settingsClient.getEPGProviderCooldownUntil(state.config.playlistID)
                state.isProviderRateLimited = state.providerCooldownUntil.map { $0 > Date() } ?? false
                var effects: [Effect<Action>] = [
                    .send(.loadReminders),
                    .send(.loadFavorites),
                    .send(.loadRecentChannels),
                    .run { [clock] send in
                        for await _ in clock.timer(interval: .seconds(60)) {
                            await send(.updateCurrentTime)
                        }
                    }
                    .cancellable(id: EPGTimelineCancelID.clockTimer, cancelInFlight: true),
                    .run { [iptvClient, networkPathStatusClient] send in
                        let identity = await iptvClient.resolveEPGSourceIdentity(config)
                        guard !Task.isCancelled else { return }
                        if shouldCheckNetworkCost {
                            let isConstrainedOrExpensive = await networkPathStatusClient.currentPathIsConstrainedOrExpensive()
                            guard !Task.isCancelled else { return }
                            await send(.networkPathCostLoaded(
                                requestID: sourceRequestID,
                                isConstrainedOrExpensive: isConstrainedOrExpensive
                            ))
                        }
                        guard !Task.isCancelled else { return }
                        await send(.epgSourceIdentityLoaded(requestID: sourceRequestID, identity: identity))
                    }
                    .cancellable(id: EPGTimelineCancelID.epgSourceIdentity, cancelInFlight: true),
                ]
                return .merge(effects)

            case let .networkPathCostLoaded(requestID, isConstrainedOrExpensive):
                guard state.isVisible,
                      state.epgNetworkCostCheckRequestID == requestID
                else { return .none }
                state.epgNetworkCostCheckRequestID = nil
                state.isEPGNetworkCostCheckPending = false
                state.isAutomaticEPGRefreshDeferred = settingsClient.deferAutoEPGRefreshOnConstrainedNetwork()
                    && isConstrainedOrExpensive
                    && !state.isEPGRefreshManuallyAuthorizedOnConstrainedNetwork
                return .none

            case let .epgSourceIdentityLoaded(requestID, identity):
                guard state.isVisible, state.epgSourceRequestID == requestID else { return .none }
                guard !state.isEPGNetworkCostCheckPending else { return .none }
                state.epgSourceIdentity = identity
                let status = settingsClient.resolveEPGRefreshStatus(state.config.playlistID, identity?.fingerprint)
                state.lastSyncTimestamp = status.lastSuccessDate
                state.lastSyncFailureTimestamp = status.lastFailureDate
                guard identity != nil else {
                    let shouldResumePrewarm = state.pendingEPGPrewarmAfterNetworkCostCheck
                    state.pendingEPGPrewarmAfterNetworkCostCheck = false
                    guard shouldResumePrewarm,
                          !state.isAutomaticEPGRefreshDeferred,
                          !state.isEPGRefreshManuallyAuthorizedOnConstrainedNetwork
                    else { return .none }
                    return .merge(state.filteredChannels.prefix(15).map { .send(.fetchEPG(streamID: $0.id)) })
                }
                if status.sourceChanged {
                    state.epgData = [:]
                    state.epgLoadFailures = []
                    state.epgAutomaticRetryCounts = [:]
                    state.epgAutomaticRetryAfter = [:]
                }

                let profileID = profileContextClient.snapshot().profileID
                let defaultEPGInterval = settingsClient.autoUpdateEPG()
                    ? PlaylistRefreshInterval.epgInterval(for: settingsClient.epgAutoRefreshInterval())
                    : .disabled
                let isProviderCoolingDown = state.providerCooldownUntil.map { $0 > Date() } ?? false
                if !isProviderCoolingDown {
                    state.isProviderRateLimited = false
                }
                let refreshInterval = playlistRefreshScheduleClient.interval(
                    profileID,
                    state.config.playlistID,
                    .epg,
                    defaultEPGInterval
                )
                let automaticRefreshClaimed = !isProviderCoolingDown
                    && !state.isSyncingEPG
                    && !state.isAutomaticEPGRefreshDeferred
                    && !state.isEPGRefreshManuallyAuthorizedOnConstrainedNetwork
                    && state.config.playlistID != nil
                    && playlistRefreshScheduleClient.claimAutomaticRefresh(
                        profileID,
                        state.config.playlistID,
                        .epg,
                        refreshInterval,
                        Date()
                    )
                if automaticRefreshClaimed {
                    state.pendingAutomaticEPGRefreshProfileID = profileID
                }
                let autoSyncIsDue = automaticRefreshClaimed
                let failedVisibleChannelIDs = state.isProviderRateLimited || autoSyncIsDue || state.isAutomaticEPGRefreshDeferred
                    ? []
                    : state.filteredChannels.prefix(15).map(\.id).filter { state.epgLoadFailures.contains($0) }
                var effects: [Effect<Action>] = []
                if autoSyncIsDue {
                    effects.append(.send(.performSync(forced: false)))
                }
                effects.append(contentsOf: failedVisibleChannelIDs.map { .send(.fetchEPG(streamID: $0)) })
                let shouldResumePrewarm = state.pendingEPGPrewarmAfterNetworkCostCheck
                    && !state.isAutomaticEPGRefreshDeferred
                    && !state.isEPGRefreshManuallyAuthorizedOnConstrainedNetwork
                    && !autoSyncIsDue
                state.pendingEPGPrewarmAfterNetworkCostCheck = false
                if shouldResumePrewarm {
                    effects.append(contentsOf: state.filteredChannels.prefix(15).map { .send(.fetchEPG(streamID: $0.id)) })
                }
                return .merge(effects)

            case let .onDisappear(horizontalOffset, focusedProgramID, focusedChannelID):
                state.isVisible = false
                state.isAutomaticEPGRefreshDeferred = false
                state.isEPGNetworkCostCheckPending = false
                state.epgNetworkCostCheckRequestID = nil
                state.pendingEPGPrewarmAfterNetworkCostCheck = false
                state.isEPGRefreshManuallyAuthorizedOnConstrainedNetwork = false
                state.epgSourceRequestID = nil
                let automaticAttemptProfileID = state.activeEPGAutomaticRefresh
                    ? state.activeEPGRefreshProfileID
                    : state.pendingAutomaticEPGRefreshProfileID
                if let automaticAttemptProfileID {
                    settingsClient.setLastEPGAutoRefreshAttemptDate(state.config.playlistID, nil)
                    playlistRefreshScheduleClient.clearAutomaticRefreshAttempt(
                        automaticAttemptProfileID,
                        state.config.playlistID,
                        .epg
                    )
                }
                state.savedHorizontalOffset = horizontalOffset
                state.savedFocusedProgramID = focusedProgramID
                state.savedFocusedChannelID = focusedChannelID
                let shouldStopPreview = state.activePreviewChannel != nil || state.isPiPActive
                let previewOwnerID = state.presentationID
                let pendingChannelIDs = Array(state.epgRequestIDs.keys)
                state.isSyncingEPG = false
                state.activeEPGSyncID = nil
                state.activeEPGRefreshProfileID = nil
                state.activeEPGAutomaticRefresh = false
                state.pendingAutomaticEPGRefreshProfileID = nil
                state.lastCompletedEPGSyncID = nil
                state.syncPendingEPGChannels = []
                state.syncStatusMessage = nil
                for streamID in pendingChannelIDs {
                    state.epgRequestIDs[streamID] = nil
                    state.isLoading[streamID] = false
                }
                state.activePreviewChannel = nil
                state.isPiPActive = false
                state.isPreviewLoading = false
                state.previewErrorMessage = nil
                state.previewPlaybackID = nil
                state.focusedChannelID = nil
                state.reminderLoadRequestID = nil
                state.favoriteLoadRequestID = nil
                state.recentChannelLoadRequestID = nil
                var effects: [Effect<Action>] = [
                    .cancel(id: EPGTimelineCancelID.syncEPG),
                    .cancel(id: EPGTimelineCancelID.clearSyncStatusMessage),
                    .cancel(id: EPGTimelineCancelID.clockTimer),
                    .cancel(id: EPGTimelineCancelID.epgSourceIdentity),
                    .cancel(id: EPGTimelineCancelID.previewDebounce),
                    .cancel(id: EPGTimelineCancelID.previewPlayback),
                    .cancel(id: EPGTimelineCancelID.playbackHandoff),
                    .cancel(id: EPGTimelineCancelID.loadReminders),
                    .cancel(id: EPGTimelineCancelID.loadFavorites),
                    .cancel(id: EPGTimelineCancelID.loadRecentChannels),
                ]
                if shouldStopPreview {
                    effects.append(.run { [previewPlayerClient, previewOwnerID] _ in
                        await previewPlayerClient.stopPreviewOwned(previewOwnerID)
                    })
                }
                effects.append(contentsOf: pendingChannelIDs.map { .cancel(id: EPGTimelineCancelID.request($0)) })
                return .merge(effects)

            case let .saveNavigationState(horizontalOffset, focusedProgramID, focusedChannelID):
                state.savedHorizontalOffset = horizontalOffset
                state.savedFocusedProgramID = focusedProgramID
                state.savedFocusedChannelID = focusedChannelID
                return .none

            case .refreshEPGTapped:
                state.isAutomaticEPGRefreshDeferred = false
                state.isEPGNetworkCostCheckPending = false
                state.epgNetworkCostCheckRequestID = nil
                state.pendingEPGPrewarmAfterNetworkCostCheck = false
                state.isEPGRefreshManuallyAuthorizedOnConstrainedNetwork = true
                return .send(.performSync(forced: true))

            case .loadRecentChannels:
                guard let playlistID = state.config.playlistID else {
                    state.recentChannelIDs = []
                    state.recentChannelSnapshotRevision = 0
                    state.recentChannelSnapshotPlaylistID = nil
                    state.recentChannelSnapshotProfileScope = nil
                    state.recentChannelLoadRequestID = nil
                    state.pendingRecentChannelRemovalIDs = [:]
                    return .none
                }
                let requestID = UUID()
                state.recentChannelLoadRequestID = requestID
                let profileScope = profileContextClient.snapshot()
                if state.recentChannelSnapshotPlaylistID != playlistID
                    || state.recentChannelSnapshotProfileScope != profileScope
                {
                    state.recentChannelIDs = []
                    state.recentChannelSnapshotRevision = 0
                    state.pendingRecentChannelRemovalIDs = [:]
                    state.recentChannelSnapshotPlaylistID = playlistID
                    state.recentChannelSnapshotProfileScope = profileScope
                }
                let client = recentChannelsClient
                return .run { send in
                    let snapshot = await client.fetchScopedRecentChannels(profileScope.profileID, playlistID)
                    guard profileContextClient.snapshot() == profileScope else { return }
                    await send(.recentChannelsLoaded(
                        requestID: requestID,
                        ids: Set(snapshot.records.map(\.id)),
                        revision: snapshot.revision,
                        playlistID: playlistID,
                        profileScope: profileScope
                    ))
                }
                .cancellable(id: EPGTimelineCancelID.loadRecentChannels, cancelInFlight: true)

            case let .recentChannelsLoaded(requestID, ids, revision, playlistID, profileScope):
                guard
                    state.recentChannelLoadRequestID == requestID,
                    profileContextClient.snapshot() == profileScope,
                    state.config.playlistID == playlistID
                else { return .none }
                state.recentChannelLoadRequestID = nil
                guard revision >= state.recentChannelSnapshotRevision else {
                    return .send(.loadRecentChannels)
                }
                state.recentChannelIDs = ids
                state.recentChannelSnapshotRevision = revision
                return .none

            case let .removeRecentChannel(channel):
                guard let playlistID = state.config.playlistID,
                      state.recentChannelIDs.contains(channel.id),
                      state.pendingRecentChannelRemovalIDs[channel.id] == nil
                else { return .none }
                let profileScope = profileContextClient.snapshot()
                guard
                    state.recentChannelSnapshotPlaylistID == playlistID,
                    state.recentChannelSnapshotProfileScope == profileScope
                else { return .send(.loadRecentChannels) }
                let requestID = UUID()
                // Invalidate any older load before the removal. Its result may
                // predate this mutation and must never restore the removed ID.
                state.recentChannelLoadRequestID = nil
                state.pendingRecentChannelRemovalIDs[channel.id] = requestID
                let client = recentChannelsClient
                return .run { send in
                    let snapshot = await client.removeScopedRecentChannel(channel.id, profileScope.profileID, playlistID)
                    guard profileContextClient.snapshot() == profileScope else { return }
                    await send(.recentChannelRemoved(
                        channelID: channel.id,
                        requestID: requestID,
                        ids: Set(snapshot.records.map(\.id)),
                        revision: snapshot.revision,
                        playlistID: playlistID,
                        profileScope: profileScope
                    ))
                }

            case let .recentChannelRemoved(channelID, requestID, ids, revision, playlistID, profileScope):
                guard
                    state.pendingRecentChannelRemovalIDs[channelID] == requestID,
                    profileContextClient.snapshot() == profileScope,
                    state.config.playlistID == playlistID
                else { return .none }
                state.pendingRecentChannelRemovalIDs.removeValue(forKey: channelID)
                guard revision >= state.recentChannelSnapshotRevision else {
                    return .send(.loadRecentChannels)
                }
                state.recentChannelIDs = ids
                state.recentChannelSnapshotRevision = revision
                return .send(.loadRecentChannels)

            case let .performSync(forced):
                if forced,
                   state.isAutomaticEPGRefreshDeferred,
                   !state.isEPGRefreshManuallyAuthorizedOnConstrainedNetwork
                {
                    return .none
                }
                if forced {
                    state.isAutomaticEPGRefreshDeferred = false
                }
                let now = Date()
                guard state.isVisible else {
                    if !forced, let profileID = state.pendingAutomaticEPGRefreshProfileID {
                        playlistRefreshScheduleClient.clearAutomaticRefreshAttempt(
                            profileID,
                            state.config.playlistID,
                            .epg
                        )
                        state.pendingAutomaticEPGRefreshProfileID = nil
                    }
                    return .none
                }
                guard !state.isSyncingEPG else {
                    if !forced, let profileID = state.pendingAutomaticEPGRefreshProfileID {
                        playlistRefreshScheduleClient.clearAutomaticRefreshAttempt(
                            profileID,
                            state.config.playlistID,
                            .epg
                        )
                        state.pendingAutomaticEPGRefreshProfileID = nil
                    }
                    return .none
                }
                state.providerCooldownUntil = settingsClient.getEPGProviderCooldownUntil(state.config.playlistID)
                if let retryAfter = state.providerCooldownUntil, retryAfter > now {
                    state.isProviderRateLimited = true
                    state.syncStatusMessage = epgProviderRateLimitMessage(retryAfter: retryAfter)
                    if !forced, let profileID = state.pendingAutomaticEPGRefreshProfileID {
                        playlistRefreshScheduleClient.clearAutomaticRefreshAttempt(
                            profileID,
                            state.config.playlistID,
                            .epg
                        )
                        state.pendingAutomaticEPGRefreshProfileID = nil
                    }
                    return .none
                }
                if state.providerCooldownUntil != nil {
                    settingsClient.setEPGProviderCooldownUntil(state.config.playlistID, nil)
                    state.providerCooldownUntil = nil
                }
                state.isProviderRateLimited = false
                settingsClient.setLastEPGAutoRefreshAttemptDate(state.config.playlistID, now)
                let syncID = UUID()
                state.activeEPGSyncID = syncID
                state.activeEPGRefreshProfileID = forced
                    ? profileContextClient.snapshot().profileID
                    : state.pendingAutomaticEPGRefreshProfileID ?? profileContextClient.snapshot().profileID
                state.activeEPGAutomaticRefresh = !forced
                state.pendingAutomaticEPGRefreshProfileID = nil
                state.lastCompletedEPGSyncID = nil
                state.isSyncingEPG = true
                state.syncStatusMessage = "Rehber kaynağı yenileniyor…"
                state.successfulEPGChannelCount = 0
                state.failedEPGChannelCount = 0

                let channelsToPrewarm = Array(state.filteredChannels.prefix(20))
                state.syncPendingEPGChannels = Set(channelsToPrewarm.map(\.id))
                var requestIDs: [String: UUID] = [:]
                var requestCancellations: [Effect<Action>] = []
                for channel in channelsToPrewarm {
                    let requestID = UUID()
                    requestIDs[channel.id] = requestID
                    state.isLoading[channel.id] = true
                    state.epgRequestIDs[channel.id] = requestID
                    requestCancellations.append(.cancel(id: EPGTimelineCancelID.request(channel.id)))
                }
                guard !channelsToPrewarm.isEmpty else {
                    return .merge(
                        .cancel(id: EPGTimelineCancelID.clearSyncStatusMessage),
                        .send(.syncCompleted(syncID: syncID, date: Date()))
                    )
                }

                let config = state.config
                let sourceRequestID = state.epgSourceRequestID
                let refreshEffect = Effect<Action>.run { [iptvClient] send in
                    do {
                        try await iptvClient.refreshEPGCache(config)
                    } catch {
                        guard !Task.isCancelled else { return }
                        if let sourceRequestID {
                            let identity = await iptvClient.resolveEPGSourceIdentity(config)
                            guard !Task.isCancelled else { return }
                            await send(.epgSourceIdentityLoaded(requestID: sourceRequestID, identity: identity))
                        }
                        await send(.syncEPGCacheRefreshFailed(syncID: syncID, error: error as? NetworkError))
                        return
                    }
                    if let sourceRequestID {
                        let identity = await iptvClient.resolveEPGSourceIdentity(config)
                        guard !Task.isCancelled else { return }
                        await send(.epgSourceIdentityLoaded(requestID: sourceRequestID, identity: identity))
                    }
                    guard !Task.isCancelled else { return }
                    await send(.syncEPGSourceRefreshed(syncID: syncID, channels: channelsToPrewarm, requestIDs: requestIDs))
                }
                .cancellable(id: EPGTimelineCancelID.syncEPG, cancelInFlight: true)
                return .merge(requestCancellations + [
                    .cancel(id: EPGTimelineCancelID.clearSyncStatusMessage),
                    refreshEffect,
                ])

            case let .syncEPGSourceRefreshed(syncID, channels, requestIDs):
                guard state.isVisible, state.isSyncingEPG, state.activeEPGSyncID == syncID else { return .none }
                let pendingChannels = channels.filter {
                    state.syncPendingEPGChannels.contains($0.id)
                        && requestIDs[$0.id] != nil
                        && state.epgRequestIDs[$0.id] == requestIDs[$0.id]
                }
                guard !pendingChannels.isEmpty else {
                    for streamID in state.syncPendingEPGChannels {
                        guard let reservedID = requestIDs[streamID], state.epgRequestIDs[streamID] == reservedID else { continue }
                        state.epgRequestIDs[streamID] = nil
                        state.isLoading[streamID] = false
                    }
                    return .send(.syncCompleted(syncID: syncID, date: Date()))
                }
                // A successful source refresh invalidates previous empty responses
                // for every channel, including rows outside the prewarm window.
                let channelsWithEmptyEPG = state.epgData.compactMap { streamID, programs in
                    programs.isEmpty ? streamID : nil
                }
                for streamID in channelsWithEmptyEPG {
                    state.epgData[streamID] = nil
                }
                state.syncStatusMessage = "Programlar güncelleniyor (\(state.successfulEPGChannelCount + state.failedEPGChannelCount)/\(state.successfulEPGChannelCount + state.failedEPGChannelCount + state.syncPendingEPGChannels.count))…"
                var requestCancellations: [Effect<Action>] = []
                for channel in pendingChannels {
                    state.epgLoadFailures.remove(channel.id)
                    state.epgAutomaticRetryCounts[channel.id] = nil
                    state.epgAutomaticRetryAfter[channel.id] = nil
                    if state.epgData[channel.id]?.isEmpty == true {
                        state.epgData[channel.id] = nil
                    }
                    requestCancellations.append(.cancel(id: EPGTimelineCancelID.request(channel.id)))
                }
                let config = state.config
                let sourceFingerprint = state.epgSourceIdentity?.fingerprint
                let fetchEffect = Effect<Action>.run { [iptvClient] send in
                    for channel in pendingChannels {
                        guard !Task.isCancelled else { return }
                        guard let requestID = requestIDs[channel.id] else { continue }
                        let result: Result<[EPGProgram], Error>
                        do {
                            result = try await .success(
                                iptvClient.fetchShortEPG(config, channel.id, channel.epgChannelID, 20)
                            )
                        } catch {
                            result = .failure(error)
                        }
                        guard !Task.isCancelled else { return }
                        await send(.epgResponse(
                            streamID: channel.id,
                            requestID: requestID,
                            sourceFingerprint: sourceFingerprint,
                            result
                        ))
                        if case let .failure(error) = result,
                           let networkError = error as? NetworkError,
                           case .rateLimited = networkError
                        {
                            return
                        }
                    }
                }
                .cancellable(id: EPGTimelineCancelID.syncEPG, cancelInFlight: true)
                return .merge(requestCancellations + [.cancel(id: EPGTimelineCancelID.clearSyncStatusMessage), fetchEffect])

            case .cancelEPGSync:
                guard state.isSyncingEPG else { return .none }
                let streamIDs = Array(state.syncPendingEPGChannels)
                if state.activeEPGAutomaticRefresh {
                    settingsClient.setLastEPGAutoRefreshAttemptDate(state.config.playlistID, nil)
                    playlistRefreshScheduleClient.clearAutomaticRefreshAttempt(
                        state.activeEPGRefreshProfileID,
                        state.config.playlistID,
                        .epg
                    )
                }
                state.isSyncingEPG = false
                state.activeEPGSyncID = nil
                state.activeEPGRefreshProfileID = nil
                state.activeEPGAutomaticRefresh = false
                state.pendingAutomaticEPGRefreshProfileID = nil
                state.syncPendingEPGChannels = []
                state.syncStatusMessage = "Durduruldu; son iyi program verileri korundu."
                for streamID in streamIDs {
                    state.epgRequestIDs[streamID] = nil
                    state.isLoading[streamID] = false
                }
                return .merge([.cancel(id: EPGTimelineCancelID.syncEPG)] + streamIDs.map { .cancel(id: EPGTimelineCancelID.request($0)) })

            case let .syncEPGCacheRefreshFailed(syncID, error):
                guard state.isVisible, state.isSyncingEPG, state.activeEPGSyncID == syncID else { return .none }
                let reservedRequestIDs = state.syncPendingEPGChannels.compactMap { streamID -> (String, UUID)? in
                    guard let requestID = state.epgRequestIDs[streamID] else { return nil }
                    return (streamID, requestID)
                }
                if let error, case let .rateLimited(retryAfter) = error {
                    let activeRequestIDs = state.epgRequestIDs.map { ($0.key, $0.value) }
                    for (streamID, requestID) in activeRequestIDs where state.epgRequestIDs[streamID] == requestID {
                        state.epgRequestIDs[streamID] = nil
                        state.isLoading[streamID] = false
                    }
                    state.isSyncingEPG = false
                    state.activeEPGSyncID = nil
                    state.activeEPGRefreshProfileID = nil
                    state.activeEPGAutomaticRefresh = false
                    state.pendingAutomaticEPGRefreshProfileID = nil
                    state.syncPendingEPGChannels = []
                    let boundedRetryAfter = retryAfter ?? Date().addingTimeInterval(60)
                    state.providerCooldownUntil = boundedRetryAfter
                    state.isProviderRateLimited = true
                    settingsClient.setEPGProviderCooldownUntil(state.config.playlistID, boundedRetryAfter)
                    state.lastSyncFailureTimestamp = Date()
                    settingsClient.setLastEPGRefreshFailureDate(state.config.playlistID, state.lastSyncFailureTimestamp)
                    state.syncStatusMessage = epgProviderRateLimitMessage(retryAfter: boundedRetryAfter)
                    return .merge(
                        [.cancel(id: EPGTimelineCancelID.syncEPG)]
                            + activeRequestIDs.map { .cancel(id: EPGTimelineCancelID.request($0.0)) }
                    )
                }
                for (streamID, requestID) in reservedRequestIDs where state.epgRequestIDs[streamID] == requestID {
                    state.epgRequestIDs[streamID] = nil
                    state.isLoading[streamID] = false
                }
                state.syncPendingEPGChannels = []
                state.failedEPGChannelCount = max(1, state.failedEPGChannelCount)
                return .send(.syncCompleted(syncID: syncID, date: Date()))

            case let .syncCompleted(syncID, date):
                guard state.isSyncingEPG, state.activeEPGSyncID == syncID else { return .none }
                let refreshProfileID = state.activeEPGRefreshProfileID
                state.isSyncingEPG = false
                state.activeEPGSyncID = nil
                state.activeEPGRefreshProfileID = nil
                state.activeEPGAutomaticRefresh = false
                state.pendingAutomaticEPGRefreshProfileID = nil
                state.lastCompletedEPGSyncID = syncID
                state.syncPendingEPGChannels = []
                if state.successfulEPGChannelCount > 0, state.epgSourceIdentity != nil {
                    state.lastSyncTimestamp = date
                    settingsClient.setLastEPGRefreshDate(state.config.playlistID, date)
                }
                if state.failedEPGChannelCount > 0, state.epgSourceIdentity != nil {
                    state.lastSyncFailureTimestamp = date
                    settingsClient.setLastEPGRefreshFailureDate(state.config.playlistID, date)
                } else if state.failedEPGChannelCount == 0, state.successfulEPGChannelCount > 0, state.epgSourceIdentity != nil {
                    state.lastSyncFailureTimestamp = nil
                    settingsClient.setLastEPGRefreshFailureDate(state.config.playlistID, nil)
                    playlistRefreshScheduleClient.markSuccessfulRefresh(
                        refreshProfileID,
                        state.config.playlistID,
                        .epg,
                        date
                    )
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
                    await send(.clearSyncStatusMessage(syncID: syncID))
                }
                .cancellable(id: EPGTimelineCancelID.clearSyncStatusMessage, cancelInFlight: true)

            case let .clearSyncStatusMessage(syncID):
                guard !state.isSyncingEPG, state.lastCompletedEPGSyncID == syncID else { return .none }
                state.syncStatusMessage = nil
                state.lastCompletedEPGSyncID = nil
                return .none

            case .loadReminders:
                let requestID = UUID()
                state.reminderLoadRequestID = requestID
                return .run { send in
                    let ids = await reminderClient.getScheduledReminderIDs()
                    await send(.remindersLoaded(requestID: requestID, ids))
                }
                .cancellable(id: EPGTimelineCancelID.loadReminders, cancelInFlight: true)

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
                let favoriteListID = state.favoriteListID
                let currentFavoriteIDs = state.favoriteIDs
                return .run { send in
                    guard let favs = try? await databaseClient.fetchFavoritesByType("live", profileScope) else { return }
                    let defaultIDs = Set(favs.filter { $0.playlistID == playlistID }.map(\.id))
                    let favoriteIDs = favoriteListID == nil ? defaultIDs : currentFavoriteIDs
                    let order = await orderClient.load(profileScope.profileID, playlistID, favoriteListID)
                    await send(.favoritesLoaded(
                        requestID: requestID,
                        ids: favoriteIDs,
                        defaultIDs: defaultIDs,
                        order: order,
                        playlistID: playlistID,
                        scope: profileScope
                    ))
                }
                .cancellable(id: EPGTimelineCancelID.loadFavorites, cancelInFlight: true)

            case let .favoritesLoaded(requestID, ids, defaultIDs, storedOrder, playlistID, scope):
                guard
                    state.favoriteLoadRequestID == requestID,
                    profileContextClient.snapshot() == scope,
                    state.config.playlistID == playlistID
                else { return .none }
                state.favoriteLoadRequestID = nil
                state.favoriteIDs = ids
                state.defaultFavoriteIDs = defaultIDs
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
                let favoriteListID = state.favoriteListID
                return .run { _ in
                    await orderClient.save(order, profileID, playlistID, favoriteListID)
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
                let favoriteListID = state.favoriteListID
                return .run { _ in
                    await orderClient.save(order, scope.profileID, playlistID, favoriteListID)
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
                let favoriteListID = state.favoriteListID
                return .run { _ in
                    await orderClient.save(order, scope.profileID, playlistID, favoriteListID)
                }

            case let .toggleFavorite(channel):
                state.favoriteLoadRequestID = nil
                guard let playlistID = state.config.playlistID else { return .none }
                let isFav = state.defaultFavoriteIDs.contains(channel.id)
                if isFav {
                    state.defaultFavoriteIDs.remove(channel.id)
                } else {
                    state.defaultFavoriteIDs.insert(channel.id)
                }
                if state.favoriteListID == nil {
                    state.favoriteIDs = state.defaultFavoriteIDs
                }
                let profileScope = profileContextClient.snapshot()
                let order: FavoriteChannelOrderSnapshot?
                if state.favoriteListID == nil {
                    if isFav {
                        state.favoriteOrderIDs.removeAll { $0 == channel.id }
                    } else {
                        state.favoriteOrderIDs.append(channel.id)
                    }
                    let updatedOrder = FavoriteChannelOrderSnapshot(
                        mode: state.favoriteSortMode,
                        orderedIDs: FavoriteChannelSortMode.normalizedManualIDs(
                            favoriteIDs: state.defaultFavoriteIDs,
                            providerIDs: (state.providerOrderChannels.isEmpty ? state.channels : state.providerOrderChannels).map(\.id),
                            storedIDs: state.favoriteOrderIDs
                        ),
                        revision: nextFavoriteChannelOrderRevision(after: state.favoriteOrderRevision)
                    )
                    state.favoriteOrderIDs = updatedOrder.orderedIDs
                    state.favoriteOrderRevision = updatedOrder.revision
                    order = updatedOrder
                } else {
                    order = nil
                }
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
                    if let order {
                        await orderClient.save(order, profileScope.profileID, playlistID, nil)
                    }
                }

            case let .bulkDefaultFavoritesChanged(defaultIDs, changedIDsInProviderOrder, operation):
                guard let playlistID = state.config.playlistID else { return .none }
                state.defaultFavoriteIDs = defaultIDs
                guard state.favoriteListID == nil else { return .none }
                state.favoriteLoadRequestID = nil
                state.favoriteIDs = defaultIDs
                if operation == .add {
                    for id in changedIDsInProviderOrder where !state.favoriteOrderIDs.contains(id) {
                        state.favoriteOrderIDs.append(id)
                    }
                } else {
                    state.favoriteOrderIDs.removeAll { changedIDsInProviderOrder.contains($0) }
                }
                let providerIDs = (state.providerOrderChannels.isEmpty ? state.channels : state.providerOrderChannels).map(\.id)
                let normalizedIDs = FavoriteChannelSortMode.normalizedManualIDs(
                    favoriteIDs: defaultIDs,
                    providerIDs: providerIDs,
                    storedIDs: state.favoriteOrderIDs
                )
                state.favoriteOrderIDs = normalizedIDs
                let order = FavoriteChannelOrderSnapshot(
                    mode: state.favoriteSortMode,
                    orderedIDs: normalizedIDs,
                    revision: nextFavoriteChannelOrderRevision(after: state.favoriteOrderRevision)
                )
                state.favoriteOrderRevision = order.revision
                let scope = profileContextClient.snapshot()
                let orderClient = favoriteChannelOrderClient
                return .run { _ in
                    await orderClient.save(order, scope.profileID, playlistID, nil)
                }

            case let .editChannelLogo(channel):
                guard state.config.playlistID != nil,
                      let currentChannel = state.channels.first(where: { $0.id == channel.id && $0.type == .live })
                else { return .none }
                return .send(.delegate(.presentChannelLogoEditor(
                    timelinePresentationID: state.presentationID,
                    channelID: currentChannel.id
                )))

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
                let storageKey = state.channels.first(where: { $0.id == channelID })?.logoOverrideStorageKey ?? channelID
                state.channelLogoOverrideRequestIDs[channelID] = requestID
                let channelLogoOverrideClient = channelLogoOverrideClient
                return .run { send in
                    let storedURL = await channelLogoOverrideClient.setOverride(playlistID, storageKey, rawValue)
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
                    let playlistIdentity = EPGReminderIdentifier.playlistIdentity(for: state.config)
                    return .run { send in
                        do {
                            guard try await reminderClient.requestAuthorization() else {
                                await send(.reminderScheduleResponse(
                                    programID: reminderID,
                                    legacyProgramID: program.id,
                                    requestID: requestID,
                                    isScheduled: false
                                ))
                                await send(.reminderSchedulingFailed)
                                return
                            }
                            try await reminderClient.scheduleReminder(
                                namespacedProgram,
                                channel,
                                5,
                                playlistIdentity
                            )
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
                            await send(.reminderSchedulingFailed)
                        }
                    }
                }

            case .reminderSchedulingFailed:
                state.syncStatusMessage = AppStrings.Player.reminderSchedulingFailed
                return .none

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
                guard state.isVisible, state.isLoading[streamID] != true else { return .none }
                guard !state.isEPGNetworkCostCheckPending,
                      !state.isAutomaticEPGRefreshDeferred
                else { return .none }
                let cooldownUntil = settingsClient.getEPGProviderCooldownUntil(state.config.playlistID)
                    ?? state.providerCooldownUntil
                if state.isProviderRateLimited, cooldownUntil == nil {
                    return .none
                }
                if let cooldownUntil, cooldownUntil > Date() {
                    state.providerCooldownUntil = cooldownUntil
                    state.isProviderRateLimited = true
                    return .none
                }
                if state.isProviderRateLimited || state.providerCooldownUntil != nil {
                    settingsClient.setEPGProviderCooldownUntil(state.config.playlistID, nil)
                    state.providerCooldownUntil = nil
                    state.isProviderRateLimited = false
                }
                if state.epgData[streamID] != nil {
                    guard state.epgLoadFailures.contains(streamID),
                          state.epgAutomaticRetryAfter[streamID].map({ $0 <= Date() }) ?? true
                    else { return .none }
                }
                state.isLoading[streamID] = true
                let config = state.config
                let epgChannelID = state.channels.first(where: { $0.id == streamID })?.epgChannelID
                let requestID = UUID()
                state.epgRequestIDs[streamID] = requestID
                let sourceRequestID = state.epgSourceRequestID
                let sourceFingerprint = state.epgSourceIdentity?.fingerprint
                return .run { [iptvClient] send in
                    let result = await Result {
                        try await iptvClient.fetchShortEPG(config, streamID, epgChannelID, 20)
                    }
                    if let sourceRequestID {
                        let identity = await iptvClient.resolveEPGSourceIdentity(config)
                        guard !Task.isCancelled else { return }
                        await send(.epgSourceIdentityLoaded(requestID: sourceRequestID, identity: identity))
                    }
                    await send(.epgResponse(
                        streamID: streamID,
                        requestID: requestID,
                        sourceFingerprint: sourceFingerprint,
                        result
                    ))
                }
                .cancellable(id: EPGTimelineCancelID.request(streamID), cancelInFlight: true)

            case let .refreshEPG(streamID):
                guard state.isVisible, state.isLoading[streamID] != true else { return .none }
                let cooldownUntil = settingsClient.getEPGProviderCooldownUntil(state.config.playlistID)
                    ?? state.providerCooldownUntil
                if state.isProviderRateLimited, cooldownUntil == nil {
                    return .none
                }
                if let cooldownUntil, cooldownUntil > Date() {
                    state.providerCooldownUntil = cooldownUntil
                    state.isProviderRateLimited = true
                    return .none
                }
                if state.isProviderRateLimited || state.providerCooldownUntil != nil {
                    settingsClient.setEPGProviderCooldownUntil(state.config.playlistID, nil)
                    state.providerCooldownUntil = nil
                    state.isProviderRateLimited = false
                }
                state.isLoading[streamID] = true
                state.epgLoadFailures.remove(streamID)
                state.epgAutomaticRetryCounts[streamID] = nil
                state.epgAutomaticRetryAfter[streamID] = nil
                if state.epgData[streamID]?.isEmpty == true {
                    state.epgData[streamID] = nil
                }
                let config = state.config
                let epgChannelID = state.channels.first(where: { $0.id == streamID })?.epgChannelID
                let requestID = UUID()
                state.epgRequestIDs[streamID] = requestID
                let sourceRequestID = state.epgSourceRequestID
                let sourceFingerprint = state.epgSourceIdentity?.fingerprint
                return .run { [iptvClient] send in
                    let result = await Result {
                        try await iptvClient.fetchShortEPG(config, streamID, epgChannelID, 20)
                    }
                    if let sourceRequestID {
                        let identity = await iptvClient.resolveEPGSourceIdentity(config)
                        guard !Task.isCancelled else { return }
                        await send(.epgSourceIdentityLoaded(requestID: sourceRequestID, identity: identity))
                    }
                    await send(.epgResponse(
                        streamID: streamID,
                        requestID: requestID,
                        sourceFingerprint: sourceFingerprint,
                        result
                    ))
                }
                .cancellable(id: EPGTimelineCancelID.request(streamID), cancelInFlight: true)

            case let .epgResponse(streamID, requestID, sourceFingerprint, .success(programs)):
                guard state.epgRequestIDs[streamID] == requestID else { return .none }
                guard sourceFingerprint == state.epgSourceIdentity?.fingerprint else {
                    return discardEPGResponseFromPreviousSource(state: &state, streamID: streamID)
                }
                state.epgRequestIDs[streamID] = nil
                state.isLoading[streamID] = false
                // Normalize once when a response enters state. The timeline view
                // can be recomputed often while scrolling and should not sort each
                // channel's program list on every body evaluation.
                state.epgData[streamID] = programs.sorted { $0.startTime < $1.startTime }
                state.epgLoadFailures.remove(streamID)
                state.epgAutomaticRetryCounts[streamID] = nil
                state.epgAutomaticRetryAfter[streamID] = nil
                if let retryAfter = settingsClient.getEPGProviderCooldownUntil(state.config.playlistID), retryAfter > state.currentTime {
                    state.providerCooldownUntil = retryAfter
                    state.isProviderRateLimited = true
                }
                state.rebuildAvailableProgramCategories()
                let responseCompletedSyncChannel = state.syncPendingEPGChannels.remove(streamID) != nil
                if responseCompletedSyncChannel {
                    state.successfulEPGChannelCount += 1
                    state.syncStatusMessage = "Programlar güncelleniyor (\(state.successfulEPGChannelCount + state.failedEPGChannelCount)/\(state.successfulEPGChannelCount + state.failedEPGChannelCount + state.syncPendingEPGChannels.count))…"
                }
                if responseCompletedSyncChannel,
                   state.isSyncingEPG,
                   state.syncPendingEPGChannels.isEmpty,
                   let syncID = state.activeEPGSyncID
                {
                    return .send(.syncCompleted(syncID: syncID, date: Date()))
                }
                return .none

            case let .epgResponse(streamID, requestID, sourceFingerprint, .failure(error)):
                guard state.epgRequestIDs[streamID] == requestID else { return .none }
                guard sourceFingerprint == state.epgSourceIdentity?.fingerprint else {
                    return discardEPGResponseFromPreviousSource(state: &state, streamID: streamID)
                }
                state.epgRequestIDs[streamID] = nil
                state.isLoading[streamID] = false
                state.epgLoadFailures.insert(streamID)
                let failureCount = state.epgAutomaticRetryCounts[streamID, default: 0] + 1
                state.epgAutomaticRetryCounts[streamID] = failureCount
                let retryDelay: TimeInterval = switch failureCount {
                case 1: 15
                case 2: 30
                case 3: 300
                default: 300
                }
                state.epgAutomaticRetryAfter[streamID] = Date().addingTimeInterval(retryDelay)
                // Retain the last successful guide while refresh is failing.
                if state.epgData[streamID] == nil {
                    state.epgData[streamID] = []
                }
                if let networkError = error as? NetworkError,
                   case let .rateLimited(retryAfter) = networkError
                {
                    let boundedRetryAfter = retryAfter ?? Date().addingTimeInterval(60)
                    settingsClient.setEPGProviderCooldownUntil(state.config.playlistID, boundedRetryAfter)
                    state.providerCooldownUntil = boundedRetryAfter
                    state.isProviderRateLimited = true
                    state.lastSyncFailureTimestamp = Date()
                    settingsClient.setLastEPGRefreshFailureDate(state.config.playlistID, state.lastSyncFailureTimestamp)
                    state.syncStatusMessage = epgProviderRateLimitMessage(retryAfter: boundedRetryAfter)

                    let activeEPGStreamIDs = Array(state.epgRequestIDs.keys)
                    if state.syncPendingEPGChannels.contains(streamID) {
                        state.failedEPGChannelCount += 1
                    }
                    state.syncPendingEPGChannels = []
                    state.isSyncingEPG = false
                    state.activeEPGSyncID = nil
                    for activeID in activeEPGStreamIDs {
                        state.epgRequestIDs[activeID] = nil
                        state.isLoading[activeID] = false
                    }
                    return .merge(
                        [.cancel(id: EPGTimelineCancelID.syncEPG)]
                            + activeEPGStreamIDs.map { .cancel(id: EPGTimelineCancelID.request($0)) }
                    )
                }
                let responseCompletedSyncChannel = state.syncPendingEPGChannels.remove(streamID) != nil
                if responseCompletedSyncChannel {
                    state.failedEPGChannelCount += 1
                    state.syncStatusMessage = "Programlar güncelleniyor (\(state.successfulEPGChannelCount + state.failedEPGChannelCount)/\(state.successfulEPGChannelCount + state.failedEPGChannelCount + state.syncPendingEPGChannels.count))…"
                }
                if responseCompletedSyncChannel,
                   state.isSyncingEPG,
                   state.syncPendingEPGChannels.isEmpty,
                   let syncID = state.activeEPGSyncID
                {
                    return .send(.syncCompleted(syncID: syncID, date: Date()))
                }
                return .none

            case let .showProgramDetails(program, channel):
                let detailRequestID = UUID()
                state.selectedProgramDetail = program
                state.selectedProgramChannel = channel
                state.selectedProgramDetailRequestID = detailRequestID
                return .send(.delegate(.presentProgramDetails(
                    timelinePresentationID: state.presentationID,
                    detailRequestID: detailRequestID,
                    program: program,
                    channel: channel
                )))

            case .dismissProgramDetails:
                state.selectedProgramDetail = nil
                state.selectedProgramChannel = nil
                state.selectedProgramDetailRequestID = nil
                return .none

            case let .dismissProgramDetailsIfCurrent(detailRequestID):
                guard state.selectedProgramDetailRequestID == detailRequestID else { return .none }
                state.selectedProgramDetail = nil
                state.selectedProgramChannel = nil
                state.selectedProgramDetailRequestID = nil
                return .none

            case let .selectCategory(categoryID):
                state.selectedCategoryID = categoryID
                let channelsToPrewarm = Array(state.filteredChannels.prefix(15))
                return .run { send in
                    for ch in channelsToPrewarm {
                        await send(.fetchEPG(streamID: ch.id))
                    }
                }

            case let .selectProgramCategory(category):
                state.selectedProgramCategory = category
                return .none

            case let .selectDate(date):
                state.selectedDate = date
                state.rebuildAvailableProgramCategories()
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
                    let catchupTimeShiftHours = customEPGMappingClient.getCatchupTimeShift(
                        channel.id,
                        channel.playlistID ?? state.config.playlistID
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
                        state.focusedChannelID = nil
                        state.previewPlaybackID = nil
                        state.isVisible = false
                        state.epgSourceRequestID = nil
                        let previewOwnerID = state.presentationID
                        return .concatenate(
                            .cancel(id: EPGTimelineCancelID.epgSourceIdentity),
                            .cancel(id: EPGTimelineCancelID.previewDebounce),
                            .cancel(id: EPGTimelineCancelID.previewPlayback),
                            .cancel(id: EPGTimelineCancelID.playbackHandoff),
                            .run { [previewPlayerClient, previewOwnerID] _ in
                                await previewPlayerClient.stopPreviewOwned(previewOwnerID)
                            },
                            .send(.delegate(.playChannel(catchupItem, presentationID: state.presentationID)))
                        )
                    }
                }
                return .none

            case let .channelTapped(channel):
                guard state.isVisible, channel.streamURL != nil else { return .none }
                state.isVisible = false
                state.epgSourceRequestID = nil
                state.activePreviewChannel = nil
                state.isPiPActive = false
                state.isPreviewLoading = false
                state.previewErrorMessage = nil
                state.focusedChannelID = nil
                state.previewPlaybackID = nil
                let previewOwnerID = state.presentationID
                let presentationID = state.presentationID
                let startsMuted = settingsClient.startMuted()
                return .concatenate(
                    .cancel(id: EPGTimelineCancelID.epgSourceIdentity),
                    .cancel(id: EPGTimelineCancelID.previewDebounce),
                    .cancel(id: EPGTimelineCancelID.previewPlayback),
                    .cancel(id: EPGTimelineCancelID.playbackHandoff),
                    epgTimelinePlaybackHandoffEffect(
                        channel: channel,
                        ownerID: previewOwnerID,
                        presentationID: presentationID,
                        startsMuted: startsMuted,
                        previewPlayerClient: previewPlayerClient,
                        playerClient: playerClient
                    )
                )

            case .closeTapped:
                state.isVisible = false
                state.epgSourceRequestID = nil
                state.activePreviewChannel = nil
                state.isPiPActive = false
                state.isPreviewLoading = false
                state.previewErrorMessage = nil
                state.previewPlaybackID = nil
                let previewOwnerID = state.presentationID
                return .concatenate(
                    .cancel(id: EPGTimelineCancelID.epgSourceIdentity),
                    .cancel(id: EPGTimelineCancelID.previewDebounce),
                    .cancel(id: EPGTimelineCancelID.previewPlayback),
                    .cancel(id: EPGTimelineCancelID.playbackHandoff),
                    .run { [previewPlayerClient, previewOwnerID] _ in
                        await previewPlayerClient.stopPreviewOwned(previewOwnerID)
                    },
                    .send(.delegate(.close))
                )

            case let .channelFocused(channel):
                guard state.isVisible else { return .none }
                state.focusedChannelID = channel?.id
                guard let channel else {
                    return .cancel(id: EPGTimelineCancelID.previewDebounce)
                }
                let delay = settingsClient.epgPreviewDelay()
                guard delay != .off else {
                    return .cancel(id: EPGTimelineCancelID.previewDebounce)
                }
                if state.activePreviewChannel?.id == channel.id, state.isPiPActive {
                    return .none
                }

                return .run { [clock] send in
                    try await clock.sleep(for: .milliseconds(delay.rawValue))
                    await send(.focusedPreviewDelayElapsed(channel))
                }
                .cancellable(id: EPGTimelineCancelID.previewDebounce, cancelInFlight: true)

            case let .focusedPreviewDelayElapsed(channel):
                guard state.isVisible,
                      state.focusedChannelID == channel.id,
                      settingsClient.epgPreviewDelay() != .off
                else { return .none }
                guard state.activePreviewChannel?.id != channel.id || !state.isPiPActive else { return .none }
                return .send(.startPreviewDebounce(channel))

            case let .startPreviewDebounce(channel):
                guard state.isVisible else { return .none }
                state.activePreviewChannel = channel
                state.isPiPActive = true
                state.isPreviewLoading = true
                state.previewErrorMessage = nil
                let playbackID = UUID()
                let previewOwnerID = state.presentationID
                state.previewPlaybackID = playbackID

                return .run { [previewPlayerClient, previewOwnerID, playbackID] send in
                    do {
                        try await previewPlayerClient.playPreviewOwned(channel, previewOwnerID, playbackID)
                        await send(.previewStarted(channelID: channel.id, playbackID: playbackID))
                    } catch {
                        guard !Task.isCancelled else { return }
                        await send(.previewFailed(channelID: channel.id, playbackID: playbackID, message: error.localizedDescription))
                    }
                }
                .cancellable(id: EPGTimelineCancelID.previewPlayback, cancelInFlight: true)

            case let .previewStarted(channelID, playbackID):
                guard state.isVisible,
                      state.activePreviewChannel?.id == channelID,
                      state.previewPlaybackID == playbackID
                else { return .none }
                state.isPreviewLoading = false
                state.previewErrorMessage = nil
                return .none

            case let .previewFailed(channelID, playbackID, message):
                guard state.isVisible,
                      state.activePreviewChannel?.id == channelID,
                      state.previewPlaybackID == playbackID
                else { return .none }
                state.isPreviewLoading = false
                state.previewErrorMessage = message
                state.previewPlaybackID = nil
                return .none

            case .togglePreviewMute:
                guard state.isVisible else { return .none }
                state.isPreviewMuted.toggle()
                let isMuted = state.isPreviewMuted
                return .run { [previewPlayerClient] _ in
                    await previewPlayerClient.setMuted(isMuted)
                }

            case let .setPreviewMuted(isMuted):
                guard state.isVisible else { return .none }
                state.isPreviewMuted = isMuted
                return .run { [previewPlayerClient] _ in
                    await previewPlayerClient.setMuted(isMuted)
                }

            case .expandPreviewToFullscreen:
                guard state.isVisible else { return .none }
                guard let channel = state.activePreviewChannel else { return .none }
                guard channel.streamURL != nil else { return .none }
                state.isVisible = false
                state.epgSourceRequestID = nil
                state.activePreviewChannel = nil
                state.isPiPActive = false
                state.focusedChannelID = nil
                state.previewPlaybackID = nil
                let previewOwnerID = state.presentationID
                let presentationID = state.presentationID
                let startsMuted = settingsClient.startMuted()
                return .concatenate(
                    .cancel(id: EPGTimelineCancelID.epgSourceIdentity),
                    .cancel(id: EPGTimelineCancelID.previewDebounce),
                    .cancel(id: EPGTimelineCancelID.previewPlayback),
                    .cancel(id: EPGTimelineCancelID.playbackHandoff),
                    epgTimelinePlaybackHandoffEffect(
                        channel: channel,
                        ownerID: previewOwnerID,
                        presentationID: presentationID,
                        startsMuted: startsMuted,
                        previewPlayerClient: previewPlayerClient,
                        playerClient: playerClient
                    )
                )

            case let .togglePiPPreview(channel):
                guard state.isVisible else { return .none }
                if state.activePreviewChannel?.id == channel?.id, state.isPiPActive {
                    state.activePreviewChannel = nil
                    state.isPiPActive = false
                    state.isPreviewLoading = false
                    state.previewPlaybackID = nil
                    let previewOwnerID = state.presentationID
                    return .concatenate(
                        .cancel(id: EPGTimelineCancelID.previewDebounce),
                        .cancel(id: EPGTimelineCancelID.previewPlayback),
                        .run { [previewPlayerClient, previewOwnerID] _ in
                            await previewPlayerClient.stopPreviewOwned(previewOwnerID)
                        }
                    )
                } else if let channel {
                    return .concatenate(
                        .cancel(id: EPGTimelineCancelID.previewDebounce),
                        .send(.startPreviewDebounce(channel))
                    )
                } else {
                    return .send(.closePiPPreview)
                }

            case .closePiPPreview:
                state.activePreviewChannel = nil
                state.isPiPActive = false
                state.isPreviewLoading = false
                state.previewErrorMessage = nil
                state.previewPlaybackID = nil
                let previewOwnerID = state.presentationID
                return .concatenate(
                    .cancel(id: EPGTimelineCancelID.previewDebounce),
                    .cancel(id: EPGTimelineCancelID.previewPlayback),
                    .run { [previewPlayerClient, previewOwnerID] _ in
                        await previewPlayerClient.stopPreviewOwned(previewOwnerID)
                    }
                )

            case .delegate:
                return .none
            }
        }
    }
}
