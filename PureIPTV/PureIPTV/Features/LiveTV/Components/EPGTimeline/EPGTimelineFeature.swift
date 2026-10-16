import ComposableArchitecture
import Foundation

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
        case epgResponse(streamID: String, Result<[EPGProgram], Error>)
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
        case togglePiPPreview(MediaModels.Item?)
        case closePiPPreview

        case delegate(Delegate)
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

                // Invalidate active channel EPG cache to force re-fetch
                state.epgData.removeAll()
                state.isLoading.removeAll()

                let channelsToPrewarm = Array(state.filteredChannels.prefix(20))
                return .run { [clock] send in
                    await iptvClient.clearEPGCache()
                    for ch in channelsToPrewarm {
                        await send(.fetchEPG(streamID: ch.id))
                    }
                    try? await clock.sleep(for: .milliseconds(700))
                    await send(.syncCompleted(Date()))
                    try? await clock.sleep(for: .seconds(3))
                    await send(.clearSyncStatusMessage)
                }

            case let .syncCompleted(date):
                state.isSyncingEPG = false
                state.lastSyncTimestamp = date
                state.syncStatusMessage = AppStrings.Player.epgUpdated
                return .none

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
                        return .send(.delegate(.playChannel(catchupItem)))
                    }
                }
                return .none

            case .closeTapped:
                return .merge(
                    .send(.delegate(.close)),
                    .run { _ in
                        @Dependency(\.dismiss) var dismiss
                        await dismiss()
                    }
                )

            case let .togglePiPPreview(channel):
                if state.activePreviewChannel?.id == channel?.id {
                    state.activePreviewChannel = nil
                    state.isPiPActive = false
                } else {
                    state.activePreviewChannel = channel
                    state.isPiPActive = channel != nil
                }
                return .none

            case .closePiPPreview:
                state.activePreviewChannel = nil
                state.isPiPActive = false
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
