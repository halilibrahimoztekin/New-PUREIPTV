import ComposableArchitecture
import Foundation

// MARK: - MultiView Layout Modes

public enum MultiViewLayoutMode: String, CaseIterable, Equatable, Sendable, Identifiable {
    case showcase1Plus3 = "1+3" // 1 Large Main + 3 Right Sub-views (Showcase)
    case grid2x2 = "2x2" // 2x2 Equal Quad Grid
    case dual1Plus1 = "1+1" // Side-by-side Dual Split

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .showcase1Plus3: AppStrings.MultiView.layoutShowcase
        case .grid2x2: AppStrings.MultiView.layoutGrid
        case .dual1Plus1: AppStrings.MultiView.layoutDual
        }
    }

    public var iconName: String {
        switch self {
        case .showcase1Plus3: "rectangle.righthalf.inset.filled"
        case .grid2x2: "square.grid.2x2"
        case .dual1Plus1: "rectangle.split.2x1"
        }
    }

    public var requiredSlotCount: Int {
        switch self {
        case .showcase1Plus3, .grid2x2: 4
        case .dual1Plus1: 2
        }
    }
}

// MARK: - MultiView Slot Model

public struct MultiViewSlot: Equatable, Identifiable {
    public let id: Int
    public var item: MediaModels.Item?
    public var aspectRatioMode: VideoAspectRatioMode = .fit
    public var isLoading: Bool = false
    public var errorMessage: String?

    /// UUID to differentiate instances even when item changes
    public var instanceID: UUID = .init()

    public init(id: Int, item: MediaModels.Item? = nil) {
        self.id = id
        self.item = item
    }
}

// MARK: - MultiView Reducer

@Reducer
public struct MultiViewFeature {
    private enum CancelID {
        static let sources = "MultiViewFeature.sources"
        static let episodes = "MultiViewFeature.episodes"
    }

    @ObservableState
    public struct State: Equatable {
        public var presentationID: UUID
        public var layoutMode: MultiViewLayoutMode = .showcase1Plus3
        public var layoutSize: Int = 4 // 2 or 4 simultaneous streams
        public var primarySlotID: Int = 0

        public var slots: [MultiViewSlot] = [
            MultiViewSlot(id: 0),
            MultiViewSlot(id: 1),
            MultiViewSlot(id: 2),
            MultiViewSlot(id: 3),
        ]

        public var activeAudioSlotID: Int? = 0

        // PiP & Fullscreen
        public var focusedSlotID: Int?
        public var isPiPActive: Bool = false

        // Playlist selection
        public var isSelectingChannelForSlotID: Int?
        public var channels: [MediaModels.Item] = []
        public var vodItems: [MediaModels.Item] = []
        public var seriesItems: [MediaModels.Item] = []
        public var episodeItems: [MediaModels.Item] = []
        public var selectedSeriesID: String?
        public var config: PlaylistConfig?
        public var isLoadingSources = false
        public var isLoadingEpisodes = false
        public var sourceRequestID: UUID?
        public var episodeRequestID: UUID?
        public var loadedSourceProfileScope: ProfileContextSnapshot?
        public var restrictedLiveCategoryIDs: Set<String> = []

        public init(
            channels: [MediaModels.Item] = [],
            config: PlaylistConfig? = nil,
            presentationID: UUID = UUID()
        ) {
            self.presentationID = presentationID
            self.channels = channels
            self.config = config
        }
    }

    public enum Action {
        case onAppear
        case onDisappear
        case sourcesLoaded(requestID: UUID, profileScope: ProfileContextSnapshot, vods: [MediaModels.Item], series: [MediaModels.Item])
        case loadEpisodes(MediaModels.Item)
        case episodesLoaded(requestID: UUID, profileScope: ProfileContextSnapshot, seriesID: String, episodes: [MediaModels.Item])
        case backFromEpisodes
        case setLayoutMode(MultiViewLayoutMode)
        case setAspectRatioMode(slotID: Int, mode: VideoAspectRatioMode)
        case swapToPrimary(slotID: Int)
        case setAudioActive(slotID: Int)
        case toggleAudioMute
        case selectChannelTapped(slotID: Int)
        case channelSelected(MediaModels.Item)
        case channelSelectionDismissed
        case removeChannelTapped(slotID: Int)
        case retrySlotTapped(slotID: Int)
        case changeLayout(Int)
        case toggleFullscreen(slotID: Int)
        case togglePiP
        case restrictCategory(String)

        case delegate(Delegate)
        public enum Delegate: Equatable {
            case close
        }
    }

    public init() {}

    @Dependency(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.parentalControlClient) var parentalControlClient
    @Dependency(\.settingsClient) var settingsClient

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let databaseClient = databaseClient
        let profileContextClient = profileContextClient
        let parentalControlClient = parentalControlClient
        let settingsClient = settingsClient
        Reduce { state, action in
            switch action {
            case .onAppear:
                if let loadedScope = state.loadedSourceProfileScope,
                   loadedScope != profileContextClient.snapshot()
                {
                    state.vodItems = []
                    state.seriesItems = []
                    state.episodeItems = []
                    state.loadedSourceProfileScope = nil
                    state.selectedSeriesID = nil
                }
                guard let config = state.config, !state.isLoadingSources, state.vodItems.isEmpty, state.seriesItems.isEmpty else { return .none }
                let requestID = UUID()
                let profileScope = profileContextClient.snapshot()
                let blacklistedCategoryIDs = parentalControlClient.blacklistedCategoryIDs()
                let parentalControlEnabled = settingsClient.isParentalControlEnabled()
                let hideAdultContent = settingsClient.hideAdultContent()
                let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                let isAdultContent = settingsClient.isAdultContent
                state.sourceRequestID = requestID
                state.isLoadingSources = true
                return .run { send in
                    async let vodResult = try? await iptvClient.fetchVODs(config, nil)
                    async let seriesResult = try? await iptvClient.fetchSeries(config, nil)
                    async let vodCategoriesResult = try? await iptvClient.fetchVODCategories(config)
                    async let seriesCategoriesResult = try? await iptvClient.fetchSeriesCategories(config)
                    async let vodPreferencesResult = try? await databaseClient.fetchCategoryPreferences("vod")
                    async let seriesPreferencesResult = try? await databaseClient.fetchCategoryPreferences("series")
                    async let historyResult = try? await databaseClient.fetchWatchHistory(profileScope)
                    let vods = await vodResult ?? []
                    let series = await seriesResult ?? []
                    let vodCategories = await vodCategoriesResult
                    let seriesCategories = await seriesCategoriesResult
                    let vodPreferences = await vodPreferencesResult
                    let seriesPreferences = await seriesPreferencesResult
                    let history = await historyResult ?? []
                    let playlistID = config.playlistID
                    let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]
                    let vodPreferenceByID = Dictionary((vodPreferences ?? []).map { ($0.categoryID, $0) }, uniquingKeysWith: { first, _ in first })
                    let seriesPreferenceByID = Dictionary((seriesPreferences ?? []).map { ($0.categoryID, $0) }, uniquingKeysWith: { first, _ in first })
                    let allowedVODCategoryIDs: Set<String> = if let vodCategories, vodPreferences != nil {
                        Set(vodCategories.compactMap { category -> String? in
                            let preference = vodPreferenceByID[category.id]
                            let name = category.name.lowercased()
                            let allowedForKids = !isKidsMode || kidsKeywords.contains { name.contains($0) }
                            let isRestricted = (parentalControlEnabled && (preference?.isLocked ?? false))
                                || ((hideAdultContent || isKidsMode) && isAdultContent(category.name))
                            guard
                                allowedForKids,
                                !isRestricted,
                                !(preference?.isHidden ?? false),
                                !blacklistedCategoryIDs.contains(category.id)
                            else { return nil }
                            return category.id
                        })
                    } else {
                        []
                    }
                    let allowedSeriesCategoryIDs: Set<String> = if let seriesCategories, seriesPreferences != nil {
                        Set(seriesCategories.compactMap { category -> String? in
                            let preference = seriesPreferenceByID[category.id]
                            let name = category.name.lowercased()
                            let allowedForKids = !isKidsMode || kidsKeywords.contains { name.contains($0) }
                            let isRestricted = (parentalControlEnabled && (preference?.isLocked ?? false))
                                || ((hideAdultContent || isKidsMode) && isAdultContent(category.name))
                            guard
                                allowedForKids,
                                !isRestricted,
                                !(preference?.isHidden ?? false),
                                !blacklistedCategoryIDs.contains(category.id)
                            else { return nil }
                            return category.id
                        })
                    } else {
                        []
                    }
                    let progressByID = Dictionary(
                        history
                            .filter { $0.type == "vod" && $0.removedAt == nil && $0.playlistID == playlistID && $0.duration > 0 }
                            .map { ($0.id, min(1, max(0, $0.progress / $0.duration))) },
                        uniquingKeysWith: { first, _ in first }
                    )
                    let resumedVODs = vods
                        .filter { $0.streamURL != nil && allowedVODCategoryIDs.contains($0.categoryID) }
                        .prefix(500)
                        .map { item in
                            item.replacingResumePosition(progressByID[item.id])
                        }
                    let permittedSeries = series
                        .filter { allowedSeriesCategoryIDs.contains($0.categoryID) }
                        .prefix(250)
                    await send(.sourcesLoaded(
                        requestID: requestID,
                        profileScope: profileScope,
                        vods: resumedVODs,
                        series: Array(permittedSeries)
                    ))
                }
                .cancellable(id: CancelID.sources, cancelInFlight: true)

            case .onDisappear:
                state.sourceRequestID = nil
                state.episodeRequestID = nil
                state.isLoadingSources = false
                state.isLoadingEpisodes = false
                state.isPiPActive = false
                return .merge(
                    .cancel(id: CancelID.sources),
                    .cancel(id: CancelID.episodes)
                )

            case let .sourcesLoaded(requestID, profileScope, vods, series):
                guard state.sourceRequestID == requestID else { return .none }
                guard profileContextClient.snapshot() == profileScope else {
                    state.sourceRequestID = nil
                    state.isLoadingSources = false
                    state.vodItems = []
                    state.seriesItems = []
                    state.loadedSourceProfileScope = nil
                    return .send(.onAppear)
                }
                state.sourceRequestID = nil
                state.isLoadingSources = false
                state.vodItems = vods
                state.seriesItems = series
                state.loadedSourceProfileScope = profileScope
                return .none

            case let .loadEpisodes(series):
                guard let config = state.config else { return .none }
                guard series.type == .series, series.streamURL == nil else { return .none }
                let requestID = UUID()
                let profileScope = profileContextClient.snapshot()
                state.selectedSeriesID = series.id
                state.episodeItems = []
                state.episodeRequestID = requestID
                state.isLoadingEpisodes = true
                return .run { send in
                    async let detailResult = try? await iptvClient.fetchSeriesInfo(config, series.id)
                    async let historyResult = try? await databaseClient.fetchSeriesEpisodesWatchHistory(
                        series.id,
                        config.playlistID,
                        profileScope
                    )
                    let details = await detailResult
                    let history = await historyResult ?? []
                    let progressByID = Dictionary(
                        history.filter { $0.type == "episode" && $0.removedAt == nil && $0.duration > 0 }
                            .map { ($0.id, min(1, max(0, $0.progress / $0.duration))) },
                        uniquingKeysWith: { first, _ in first }
                    )
                    let episodeList = Array((details?.episodes ?? []).prefix(500))
                    let episodes = episodeList.map { episode in
                        MediaModels.Item(
                            id: episode.id,
                            title: "\(series.title) · S\(episode.season) E\(episode.episodeNum) · \(episode.title)",
                            streamURL: episode.streamURL,
                            coverURL: episode.coverURL ?? series.coverURL,
                            categoryID: series.categoryID,
                            type: .series,
                            duration: episode.duration,
                            userAgentOverride: config.userAgentOverride,
                            seriesID: series.id,
                            resumePosition: progressByID[episode.id]
                        )
                    }
                    await send(.episodesLoaded(
                        requestID: requestID,
                        profileScope: profileScope,
                        seriesID: series.id,
                        episodes: episodes
                    ))
                }
                .cancellable(id: CancelID.episodes, cancelInFlight: true)

            case let .episodesLoaded(requestID, profileScope, seriesID, episodes):
                guard state.episodeRequestID == requestID, state.selectedSeriesID == seriesID else { return .none }
                guard profileContextClient.snapshot() == profileScope else {
                    state.episodeRequestID = nil
                    state.isLoadingEpisodes = false
                    return .none
                }
                state.episodeRequestID = nil
                state.isLoadingEpisodes = false
                state.episodeItems = episodes
                return .none

            case .backFromEpisodes:
                state.selectedSeriesID = nil
                state.episodeItems = []
                state.episodeRequestID = nil
                state.isLoadingEpisodes = false
                return .cancel(id: CancelID.episodes)

            case let .setLayoutMode(mode):
                state.layoutMode = mode
                state.layoutSize = mode.requiredSlotCount
                while state.slots.count < mode.requiredSlotCount {
                    state.slots.append(MultiViewSlot(id: state.slots.count))
                }
                return .none

            case let .setAspectRatioMode(slotID, mode):
                guard let index = state.slots.firstIndex(where: { $0.id == slotID }),
                      state.slots[index].item != nil
                else { return .none }
                state.slots[index].aspectRatioMode = mode
                return .none

            case let .swapToPrimary(slotID):
                guard slotID != state.primarySlotID else { return .none }
                guard let primaryIndex = state.slots.firstIndex(where: { $0.id == state.primarySlotID }),
                      let targetIndex = state.slots.firstIndex(where: { $0.id == slotID })
                else {
                    return .none
                }

                // Swap items between primary and target slots
                let tempItem = state.slots[primaryIndex].item
                let tempAspectRatioMode = state.slots[primaryIndex].aspectRatioMode
                state.slots[primaryIndex].item = state.slots[targetIndex].item
                state.slots[primaryIndex].aspectRatioMode = state.slots[targetIndex].aspectRatioMode
                state.slots[primaryIndex].instanceID = UUID()
                state.slots[targetIndex].item = tempItem
                state.slots[targetIndex].aspectRatioMode = tempAspectRatioMode
                state.slots[targetIndex].instanceID = UUID()

                // Immediately switch audio focus to primary showcase screen
                state.activeAudioSlotID = state.primarySlotID
                return .none

            case let .setAudioActive(slotID):
                state.activeAudioSlotID = slotID
                return .none

            case .toggleAudioMute:
                if state.activeAudioSlotID != nil {
                    state.activeAudioSlotID = nil
                } else {
                    state.activeAudioSlotID = state.primarySlotID
                }
                return .none

            case let .selectChannelTapped(slotID):
                state.isSelectingChannelForSlotID = slotID
                return .none

            case let .channelSelected(item):
                guard let slotID = state.isSelectingChannelForSlotID else { return .none }
                guard item.type != .live || !state.restrictedLiveCategoryIDs.contains(item.categoryID) else {
                    state.isSelectingChannelForSlotID = nil
                    state.selectedSeriesID = nil
                    state.episodeItems = []
                    state.episodeRequestID = nil
                    state.isLoadingEpisodes = false
                    return .cancel(id: CancelID.episodes)
                }
                if item.type != .live,
                   state.loadedSourceProfileScope != profileContextClient.snapshot()
                {
                    state.vodItems = []
                    state.seriesItems = []
                    state.episodeItems = []
                    state.loadedSourceProfileScope = nil
                    state.selectedSeriesID = nil
                    state.episodeRequestID = nil
                    state.isLoadingEpisodes = false
                    return .merge(
                        .cancel(id: CancelID.episodes),
                        .send(.onAppear)
                    )
                }
                if let index = state.slots.firstIndex(where: { $0.id == slotID }) {
                    state.slots[index].item = item
                    state.slots[index].aspectRatioMode = .fit
                    state.slots[index].instanceID = UUID() // Force new player

                    // If no audio is active, make this one active
                    let hasActiveAudioItem = state.activeAudioSlotID.flatMap { activeID in
                        state.slots.first(where: { $0.id == activeID })?.item
                    } != nil
                    if !hasActiveAudioItem {
                        state.activeAudioSlotID = slotID
                    }
                }
                state.isSelectingChannelForSlotID = nil
                state.selectedSeriesID = nil
                state.episodeItems = []
                state.episodeRequestID = nil
                state.isLoadingEpisodes = false
                return .cancel(id: CancelID.episodes)

            case .channelSelectionDismissed:
                state.isSelectingChannelForSlotID = nil
                state.selectedSeriesID = nil
                state.episodeItems = []
                state.episodeRequestID = nil
                state.isLoadingEpisodes = false
                return .cancel(id: CancelID.episodes)

            case let .removeChannelTapped(slotID):
                if let index = state.slots.firstIndex(where: { $0.id == slotID }) {
                    state.slots[index].item = nil
                    state.slots[index].aspectRatioMode = .fit
                    state.slots[index].instanceID = UUID()
                }
                if state.activeAudioSlotID == slotID {
                    state.activeAudioSlotID = state.slots.first(where: { $0.item != nil })?.id
                }
                return .none

            case let .retrySlotTapped(slotID):
                guard let index = state.slots.firstIndex(where: { $0.id == slotID }), state.slots[index].item != nil else {
                    return .none
                }
                state.slots[index].errorMessage = nil
                state.slots[index].instanceID = UUID()
                return .none

            case let .changeLayout(size):
                let boundedSize = min(4, max(2, size))
                state.layoutSize = boundedSize
                if boundedSize == 2 {
                    state.layoutMode = .dual1Plus1
                } else if boundedSize == 4 {
                    state.layoutMode = .grid2x2
                }
                // Adjust slots count
                if state.slots.count < boundedSize {
                    let diff = boundedSize - state.slots.count
                    let startID = state.slots.count
                    for i in 0 ..< diff {
                        state.slots.append(MultiViewSlot(id: startID + i))
                    }
                } else if state.slots.count > boundedSize {
                    state.slots = Array(state.slots.prefix(boundedSize))
                    if let active = state.activeAudioSlotID, active >= boundedSize {
                        state.activeAudioSlotID = 0
                    }
                }
                return .none

            case let .toggleFullscreen(slotID):
                if state.focusedSlotID == slotID {
                    state.focusedSlotID = nil // Exit fullscreen
                } else {
                    state.focusedSlotID = slotID // Enter fullscreen
                    state.activeAudioSlotID = slotID
                }
                return .none

            case .togglePiP:
                state.isPiPActive.toggle()
                return .none

            case let .restrictCategory(categoryID):
                state.restrictedLiveCategoryIDs.insert(categoryID)
                state.channels.removeAll { $0.categoryID == categoryID }
                var removedSlotIDs = Set<Int>()
                for index in state.slots.indices
                    where state.slots[index].item?.type == .live && state.slots[index].item?.categoryID == categoryID
                {
                    removedSlotIDs.insert(state.slots[index].id)
                    state.slots[index].item = nil
                    state.slots[index].isLoading = false
                    state.slots[index].errorMessage = nil
                    state.slots[index].instanceID = UUID()
                }
                if let focusedSlotID = state.focusedSlotID, removedSlotIDs.contains(focusedSlotID) {
                    state.focusedSlotID = nil
                }
                if let activeAudioSlotID = state.activeAudioSlotID, removedSlotIDs.contains(activeAudioSlotID) {
                    state.activeAudioSlotID = state.slots.first(where: { $0.item != nil })?.id
                    state.isPiPActive = false
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
