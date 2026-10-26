import ComposableArchitecture
import FactoryKit
import Foundation
import SwiftUI

// MARK: - SearchFeature / GlobalSearchFeature

/// Cancel ID must be fully Sendable and non-isolated to avoid
/// main-actor isolation conflicts with the @Reducer macro.
private let searchCancelID = "SearchFeature.search"
private let searchCatalogLoadCancelID = "SearchFeature.catalogLoad"
private let searchMultiPlaylistLoadCancelID = "SearchFeature.multiPlaylistLoad"
private let searchEPGCancelID = "SearchFeature.searchEPG"
private let searchPeopleCancelID = "SearchFeature.searchPeople"
private let searchProgramsCancelID = "SearchFeature.searchPrograms"

@Reducer
public struct SearchFeature: Sendable {
    public enum SearchFilter: String, CaseIterable, Equatable, Sendable {
        case all = "Tümü"
        case live = "Canlı TV"
        case vod = "Filmler"
        case series = "Diziler"
        case uhd4k = "4K / UHD"
        case epgMatches = "EPG Programları"
        case people = "Kişiler"
        case programs = "Programlar"

        public var title: String {
            switch self {
            case .all: AppStrings.Search.all
            case .live: AppStrings.Search.liveTV
            case .vod: AppStrings.Search.movies
            case .series: AppStrings.Search.series
            case .uhd4k: AppStrings.Search.filter4K
            case .epgMatches: AppStrings.Search.filterEPG
            case .people: AppStrings.Search.people
            case .programs: AppStrings.Search.programs
            }
        }

        public var icon: String {
            switch self {
            case .all: "square.grid.2x2.fill"
            case .live: "tv.fill"
            case .vod: "film.fill"
            case .series: "play.tv.fill"
            case .uhd4k: "sparkles.tv.fill"
            case .epgMatches: "clock.badge.checkmark.fill"
            case .people: "person.crop.rectangle.stack.fill"
            case .programs: "list.bullet.rectangle.fill"
            }
        }

        public var badgeColorHex: String {
            switch self {
            case .all: "#0A84FF" // System Blue
            case .live: "#0A84FF" // Electric Blue
            case .vod: "#BF5AF2" // Cinema Violet
            case .series: "#FF9F0A" // Sunset Amber
            case .uhd4k: "#FFD60A" // Radiant Gold
            case .epgMatches: "#30D158" // Stadium Green
            case .people: "#FF375F"
            case .programs: "#64D2FF"
            }
        }

        public var badgeColor: Color {
            Color(hex: badgeColorHex)
        }
    }

    public struct QuickSearchTag: Identifiable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let icon: String
        public let hexColor: String

        public init(id: String, title: String, icon: String, hexColor: String) {
            self.id = id
            self.title = title
            self.icon = icon
            self.hexColor = hexColor
        }

        public static let defaults: [QuickSearchTag] = [
            QuickSearchTag(id: "spor", title: "Spor", icon: "sportscourt.fill", hexColor: "#FF9500"),
            QuickSearchTag(id: "sinema", title: "Sinema", icon: "film.fill", hexColor: "#FF3B30"),
            QuickSearchTag(id: "haber", title: "Haber", icon: "newspaper.fill", hexColor: "#0A84FF"),
            QuickSearchTag(id: "belgesel", title: "Belgesel", icon: "globe.europe.africa.fill", hexColor: "#30D158"),
            QuickSearchTag(id: "cocuk", title: "Çocuk", icon: "sparkles.tv.fill", hexColor: "#FFD60A"),
            QuickSearchTag(id: "muzik", title: "Müzik", icon: "music.note", hexColor: "#BF5AF2"),
            QuickSearchTag(id: "4k", title: "4K / UHD", icon: "4k.tv.fill", hexColor: "#64D2FF"),
            QuickSearchTag(id: "aksiyon", title: "Aksiyon", icon: "flame.fill", hexColor: "#FF453A"),
            QuickSearchTag(id: "komedi", title: "Komedi", icon: "face.smiling.fill", hexColor: "#63E6BE"),
            QuickSearchTag(id: "dizi", title: "Dizi", icon: "play.tv.fill", hexColor: "#5E5CE6"),
        ]
    }

    public struct PersonCreditResult: Identifiable, Equatable, Sendable {
        public let personID: Int
        public let personName: String
        public let portraitURL: URL?
        public let result: GlobalSearchResultItem
        public var id: String {
            "\(personID)|\(result.playlistBadge.id)|\(result.item.id)"
        }
    }

    public struct ProgramResult: Identifiable, Equatable, Sendable {
        public let program: EPGProgram
        public let result: GlobalSearchResultItem
        public var id: String {
            "\(program.id)|\(result.playlistBadge.id)"
        }
    }

    @ObservableState
    public struct State: Equatable {
        // Data sources (everything fetched once)
        public var allChannels: [MediaModels.Item] = []
        public var allVODs: [MediaModels.Item] = []
        public var allSeries: [MediaModels.Item] = []

        // Multi-Playlist Cross-Indexing
        public var savedPlaylists: [SavedPlaylist] = []
        public var selectedPlaylistID: UUID?
        public var indexedChannels: [GlobalSearchResultItem] = []
        public var indexedVODs: [GlobalSearchResultItem] = []
        public var indexedSeries: [GlobalSearchResultItem] = []

        // Search state
        public var searchQuery: String = ""
        public var focusedResultID: String?
        public var debouncedQuery: String = ""
        public var filter: SearchFilter = .all
        public var recentSearches: [SearchHistoryItem] = []
        public var quickTags: [QuickSearchTag] = QuickSearchTag.defaults

        // UI state
        public var isLoading = false
        public var primaryCatalogLoadRequestID: UUID?
        public var multiPlaylistLoadRequestID: UUID?
        public var isSearching = false
        public var isPeopleSearchLoading = false
        public var isProgramsSearchLoading = false
        public var hasLoaded = false
        public var errorMessage: String?
        public var reminderFailureMessage: String?
        public var lastLoadedConfig: PlaylistConfig?
        public var lastAdultHidden: Bool?

        // Stored Results (for backward compatibility)
        public var liveResults: [MediaModels.Item] = []
        public var vodResults: [MediaModels.Item] = []
        public var seriesResults: [MediaModels.Item] = []
        public var favoriteIDs: Set<FavoriteIdentity> = []
        public var scheduledReminderIDs: Set<String> = []
        public var pendingReminderRequestIDs: [String: UUID] = [:]
        public var reminderLoadRequestID: UUID?

        // Enriched Multi-Playlist Results
        public var enrichedLiveResults: [GlobalSearchResultItem] = []
        public var enrichedVODResults: [GlobalSearchResultItem] = []
        public var enrichedSeriesResults: [GlobalSearchResultItem] = []
        public var peopleResults: [PersonCreditResult] = []
        public var programResults: [ProgramResult] = []
        public var activePeopleSearchRequestID: UUID?
        public var activeProgramsSearchRequestID: UUID?
        public var activeSearchRequestID: UUID?
        public var filterCounts: [SearchFilter: Int] = [:]
        public var baseAllResultsCount = 0

        public var playlistIDsByBadgeID: [String: UUID] {
            var identifiers: [String: UUID] = [:]
            for (index, playlist) in savedPlaylists.enumerated() {
                guard let config = playlist.toPlaylistConfig() else { continue }
                identifiers[UnifiedPlaylistManager.shared.badge(for: config, index: index).id] = playlist.id
            }
            if let config = lastLoadedConfig, let playlistID = config.playlistID {
                identifiers[UnifiedPlaylistManager.shared.badge(for: config).id] = playlistID
                identifiers[EPGReminderIdentifier.playlistIdentity(for: config)] = playlistID
                identifiers["default"] = playlistID
            }
            return identifiers
        }

        public var playlistIdentitiesByBadgeID: [String: String] {
            var identities: [String: String] = [:]
            for (index, playlist) in savedPlaylists.enumerated() {
                guard let config = playlist.toPlaylistConfig() else { continue }
                let badge = UnifiedPlaylistManager.shared.badge(for: config, index: index)
                identities[badge.id] = EPGReminderIdentifier.playlistIdentity(for: config)
            }
            if let config = lastLoadedConfig {
                identities[UnifiedPlaylistManager.shared.badge(for: config).id] = EPGReminderIdentifier.playlistIdentity(for: config)
            }
            return identities
        }

        public mutating func updateAllResultsCount() {
            filterCounts[.all] = baseAllResultsCount + peopleResults.count + programResults.count
        }

        public var totalResultsCount: Int {
            switch filter {
            case .people:
                return peopleResults.count
            case .programs:
                return programResults.count
            case .all:
                let liveCount = enrichedLiveResults.isEmpty ? liveResults.count : enrichedLiveResults.count
                let vodCount = enrichedVODResults.isEmpty ? vodResults.count : enrichedVODResults.count
                let seriesCount = enrichedSeriesResults.isEmpty ? seriesResults.count : enrichedSeriesResults.count
                return liveCount + vodCount + seriesCount + peopleResults.count + programResults.count
            default:
                if !enrichedLiveResults.isEmpty || !enrichedVODResults.isEmpty || !enrichedSeriesResults.isEmpty {
                    return enrichedLiveResults.count + enrichedVODResults.count + enrichedSeriesResults.count
                }
                return liveResults.count + vodResults.count + seriesResults.count
            }
        }

        public var isCurrentScopeSearching: Bool {
            switch filter {
            case .people: isPeopleSearchLoading
            case .programs: isProgramsSearchLoading
            default: false
            }
        }

        public mutating func updateResults() {
            let query = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                liveResults = []
                vodResults = []
                seriesResults = []
                enrichedLiveResults = []
                enrichedVODResults = []
                enrichedSeriesResults = []
                peopleResults = []
                programResults = []
                filterCounts = [:]
                baseAllResultsCount = 0
                return
            }

            let defaultBadge = PlaylistSourceBadge(
                id: lastLoadedConfig.map(EPGReminderIdentifier.playlistIdentity(for:)) ?? "default",
                playlistName: lastLoadedConfig?.serverURL?.host ?? "Varsayılan",
                colorHex: "#0A84FF"
            )

            let chSource = !indexedChannels.isEmpty ? indexedChannels : allChannels.map {
                GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge)
            }
            let voSource = !indexedVODs.isEmpty ? indexedVODs : allVODs.map {
                GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge)
            }
            let seSource = !indexedSeries.isEmpty ? indexedSeries : allSeries.map {
                GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge)
            }

            let output = GlobalSearchEngine.search(
                query: query,
                filter: filter,
                selectedPlaylistID: selectedPlaylistID,
                channels: chSource,
                vods: voSource,
                series: seSource,
                limitPerCategory: 100
            )

            enrichedLiveResults = output.live
            enrichedVODResults = output.vods
            enrichedSeriesResults = output.series
            filterCounts = output.counts
            baseAllResultsCount = output.counts[.all, default: 0]
            updateAllResultsCount()

            liveResults = output.live.map(\.item)
            vodResults = output.vods.map(\.item)
            seriesResults = output.series.map(\.item)
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case loadSavedPlaylistsResponse([SavedPlaylist])
        case loadRecentSearchesResponse([SearchHistoryItem])
        case loadAllDataResponse(
            requestID: UUID,
            config: PlaylistConfig,
            result: Result<(channels: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item]), Error>
        )
        case loadPlaylistsDataResponse(
            requestID: UUID,
            config: PlaylistConfig,
            list: [(badge: PlaylistSourceBadge, channels: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item])]
        )
        case queryChanged(String)
        case performSearch(String)
        case searchCompleted(query: String, filter: SearchFilter, live: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item])
        case searchEnrichedCompleted(requestID: UUID, query: String, filter: SearchFilter, playlistID: UUID?, output: GlobalSearchEngine.SearchResultOutput)
        case liveEPGEnriched(query: String, filter: SearchFilter, playlistID: UUID?, results: [GlobalSearchResultItem])
        case peopleSearchCompleted(requestID: UUID, query: String, filter: SearchFilter, playlistID: UUID?, results: [PersonCreditResult])
        case programsSearchCompleted(requestID: UUID, query: String, filter: SearchFilter, playlistID: UUID?, results: [ProgramResult])
        case filterChanged(SearchFilter)
        case selectPlaylistFilter(UUID?)
        case resetCache
        case channelSelected(MediaModels.Item)
        case vodSelected(MediaModels.Item)
        case seriesSelected(MediaModels.Item)
        case focusedResultChanged(String)
        case personCreditSelected(PersonCreditResult)
        case programSelected(ProgramResult)
        case clearHistoryTapped
        case recentSearchTapped(String)
        case tagSelected(QuickSearchTag)
        case loadFavoritesResponse([FavoriteItem], ProfileContextSnapshot)
        case loadReminders
        case remindersLoaded(requestID: UUID, Set<String>)
        case toggleReminder(EPGProgram, MediaModels.Item, reminderID: String, playlistIdentity: String)
        case reminderToggleResponse(programID: String, legacyProgramID: String, requestID: UUID, isScheduled: Bool)
        case reminderSchedulingFailed
        case clearReminderFailure
        case toggleFavorite(item: MediaModels.Item, type: String, playlistID: UUID?)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item, playlist: [MediaModels.Item]?)
            case didSelectVOD(MediaModels.Item)
            case didSelectSeries(MediaModels.Item)
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.continuousClock) var clock
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.parentalControlClient) var parentalControlClient
    @Dependency(\.reminderClient) var reminderClient
    @Dependency(\.tmdbClient) var tmdbClient
    @Dependency(\.customEPGMappingClient) var customEPGMappingClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let playlistRepository = playlistRepository
        let settingsClient = settingsClient
        let parentalControlClient = parentalControlClient
        let reminderClient = reminderClient
        let tmdbClient = tmdbClient
        let customEPGMappingClient = customEPGMappingClient

        let profileContextClient = profileContextClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                let playlists = playlistRepository.getPlaylists()
                state.savedPlaylists = playlists

                let loadHistory: Effect<Action> = .run { send in
                    let history = await (try? databaseClient.fetchSearchHistory()) ?? []
                    await send(.loadRecentSearchesResponse(history))
                }

                let profileScope = profileContextClient.snapshot()
                let loadFavs: Effect<Action> = .run { send in
                    let favs = await (try? databaseClient.fetchFavorites(profileScope)) ?? []
                    await send(.loadFavoritesResponse(favs, profileScope))
                }

                let currentAdultHidden = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                if state.lastLoadedConfig != config || state.lastAdultHidden != currentAdultHidden {
                    state.hasLoaded = false
                    state.isLoading = false
                    state.primaryCatalogLoadRequestID = nil
                    state.multiPlaylistLoadRequestID = nil
                    state.allChannels = []
                    state.allVODs = []
                    state.allSeries = []
                    state.indexedChannels = []
                    state.indexedVODs = []
                    state.indexedSeries = []
                    state.liveResults = []
                    state.vodResults = []
                    state.seriesResults = []
                    state.enrichedLiveResults = []
                    state.enrichedVODResults = []
                    state.enrichedSeriesResults = []
                    state.peopleResults = []
                    state.programResults = []
                    state.activePeopleSearchRequestID = nil
                    state.activeProgramsSearchRequestID = nil
                    state.activeSearchRequestID = nil
                    state.filterCounts = [:]
                    state.baseAllResultsCount = 0
                    state.searchQuery = ""
                    state.debouncedQuery = ""
                    state.isSearching = false
                    state.isPeopleSearchLoading = false
                    state.isProgramsSearchLoading = false
                    state.lastLoadedConfig = config
                    state.lastAdultHidden = currentAdultHidden
                }

                guard !state.hasLoaded, !state.isLoading else {
                    return .merge(loadHistory, loadFavs, .send(.loadReminders))
                }
                state.isLoading = true
                state.errorMessage = nil
                let primaryRequestID = UUID()
                let multiPlaylistRequestID = playlists.count > 1 ? UUID() : nil
                state.primaryCatalogLoadRequestID = primaryRequestID
                state.multiPlaylistLoadRequestID = multiPlaylistRequestID

                // Concurrently fetch active playlist plus other playlists if multiple exist
                let primaryFetch: Effect<Action> = .run { send in
                    async let channelsReq = try? iptvClient.fetchLiveChannels(config, nil)
                    let vods: [MediaModels.Item]?
                    let series: [MediaModels.Item]?
                    if config.type == .plex || config.type == .emby {
                        // Authenticated media servers are searched on demand instead of loading
                        // their entire libraries into the global search index.
                        vods = []
                        series = []
                    } else {
                        async let vodsReq = try? iptvClient.fetchVODs(config, nil)
                        async let seriesReq = try? iptvClient.fetchSeries(config, nil)
                        (vods, series) = await (vodsReq, seriesReq)
                    }
                    let channels = await channelsReq

                    if channels == nil, vods == nil, series == nil {
                        await send(.loadAllDataResponse(
                            requestID: primaryRequestID,
                            config: config,
                            result: .failure(NetworkError.invalidResponse)
                        ))
                    } else {
                        await send(.loadAllDataResponse(
                            requestID: primaryRequestID,
                            config: config,
                            result: .success((
                                channels: channels ?? [],
                                vods: vods ?? [],
                                series: series ?? []
                            ))
                        ))
                    }
                }

                let multiPlaylistFetch: Effect<Action> = if let multiPlaylistRequestID {
                    .run { send in
                        var list: [(badge: PlaylistSourceBadge, channels: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item])] = []
                        for (index, p) in playlists.enumerated() {
                            guard let pConfig = p.toPlaylistConfig() else { continue }
                            let badge = UnifiedPlaylistManager.shared.badge(for: pConfig, index: index)
                            async let channelsReq = try? iptvClient.fetchLiveChannels(pConfig, nil)
                            let vods: [MediaModels.Item]?
                            let series: [MediaModels.Item]?
                            if pConfig.type == .plex || pConfig.type == .emby {
                                vods = []
                                series = []
                            } else {
                                async let vodsReq = try? iptvClient.fetchVODs(pConfig, nil)
                                async let seriesReq = try? iptvClient.fetchSeries(pConfig, nil)
                                (vods, series) = await (vodsReq, seriesReq)
                            }
                            let channels = await channelsReq
                            list.append((badge: badge, channels: channels ?? [], vods: vods ?? [], series: series ?? []))
                        }
                        await send(.loadPlaylistsDataResponse(
                            requestID: multiPlaylistRequestID,
                            config: config,
                            list: list
                        ))
                    }
                } else {
                    .none
                }

                return .concatenate(
                    .cancel(id: searchCatalogLoadCancelID),
                    .cancel(id: searchMultiPlaylistLoadCancelID),
                    .merge(
                        loadHistory,
                        loadFavs,
                        primaryFetch.cancellable(id: searchCatalogLoadCancelID, cancelInFlight: true),
                        multiPlaylistFetch.cancellable(id: searchMultiPlaylistLoadCancelID, cancelInFlight: true),
                        .send(.loadReminders)
                    )
                )

            case let .loadSavedPlaylistsResponse(playlists):
                state.savedPlaylists = playlists
                return .none

            case let .loadRecentSearchesResponse(history):
                state.recentSearches = history
                return .none

            case let .loadAllDataResponse(requestID, responseConfig, .success(data)):
                guard state.primaryCatalogLoadRequestID == requestID,
                      state.lastLoadedConfig == responseConfig
                else { return .none }
                state.primaryCatalogLoadRequestID = nil
                state.isLoading = false
                state.hasLoaded = true
                let hiddenIDs = parentalControlClient.hiddenChannelIDs()
                let blacklistedCats = parentalControlClient.blacklistedCategoryIDs()
                let hideAdult = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdult = settingsClient.isAdultContent

                state.allChannels = data.channels.filter { ch in
                    if hiddenIDs.contains(ch.id) {
                        return false
                    }
                    if blacklistedCats.contains(ch.categoryID) {
                        return false
                    }
                    if hideAdult, isAdult(ch.title) {
                        return false
                    }
                    return true
                }
                state.allVODs = hideAdult ? data.vods.filter { !isAdult($0.title) } : data.vods
                state.allSeries = hideAdult ? data.series.filter { !isAdult($0.title) } : data.series

                // Create initial default indexed items if no multi-playlist items yet
                if state.indexedChannels.isEmpty {
                    let defaultBadge = PlaylistSourceBadge(
                        id: state.lastLoadedConfig.map(EPGReminderIdentifier.playlistIdentity(for:)) ?? "default",
                        playlistName: state.lastLoadedConfig?.serverURL?.host ?? "Varsayılan",
                        colorHex: "#0A84FF"
                    )
                    state.indexedChannels = state.allChannels.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                    state.indexedVODs = state.allVODs.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                    state.indexedSeries = state.allSeries.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                }

                if !state.debouncedQuery.isEmpty {
                    return .send(.performSearch(state.debouncedQuery))
                }
                return .none

            case let .loadAllDataResponse(requestID, responseConfig, .failure(error)):
                guard state.primaryCatalogLoadRequestID == requestID,
                      state.lastLoadedConfig == responseConfig
                else { return .none }
                state.primaryCatalogLoadRequestID = nil
                state.isLoading = false
                state.errorMessage = AppStrings.Errors.searchFailed(desc: error.localizedDescription)
                return .none

            case let .loadPlaylistsDataResponse(requestID, responseConfig, list):
                guard state.multiPlaylistLoadRequestID == requestID,
                      state.lastLoadedConfig == responseConfig
                else { return .none }
                state.multiPlaylistLoadRequestID = nil
                let hiddenIDs = parentalControlClient.hiddenChannelIDs()
                let blacklistedCats = parentalControlClient.blacklistedCategoryIDs()
                let hideAdult = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdult = settingsClient.isAdultContent

                var allIndexedCh: [GlobalSearchResultItem] = []
                var allIndexedVo: [GlobalSearchResultItem] = []
                var allIndexedSe: [GlobalSearchResultItem] = []

                for item in list {
                    let chs = item.channels.filter { ch in
                        if hiddenIDs.contains(ch.id) {
                            return false
                        }
                        if blacklistedCats.contains(ch.categoryID) {
                            return false
                        }
                        if hideAdult, isAdult(ch.title) {
                            return false
                        }
                        return true
                    }
                    let vos = hideAdult ? item.vods.filter { !isAdult($0.title) } : item.vods
                    let ses = hideAdult ? item.series.filter { !isAdult($0.title) } : item.series

                    allIndexedCh.append(contentsOf: chs.map { GlobalSearchResultItem(item: $0, playlistBadge: item.badge) })
                    allIndexedVo.append(contentsOf: vos.map { GlobalSearchResultItem(item: $0, playlistBadge: item.badge) })
                    allIndexedSe.append(contentsOf: ses.map { GlobalSearchResultItem(item: $0, playlistBadge: item.badge) })
                }

                state.indexedChannels = allIndexedCh
                state.indexedVODs = allIndexedVo
                state.indexedSeries = allIndexedSe

                if !state.debouncedQuery.isEmpty {
                    return .send(.performSearch(state.debouncedQuery))
                }
                return .none

            case let .queryChanged(query):
                state.searchQuery = query
                state.activePeopleSearchRequestID = nil
                state.activeProgramsSearchRequestID = nil
                state.activeSearchRequestID = nil
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    state.debouncedQuery = ""
                    state.isSearching = false
                    state.isPeopleSearchLoading = false
                    state.isProgramsSearchLoading = false
                    state.liveResults = []
                    state.vodResults = []
                    state.seriesResults = []
                    state.enrichedLiveResults = []
                    state.enrichedVODResults = []
                    state.enrichedSeriesResults = []
                    state.peopleResults = []
                    state.programResults = []
                    state.activePeopleSearchRequestID = nil
                    state.activeProgramsSearchRequestID = nil
                    state.activeSearchRequestID = nil
                    state.filterCounts = [:]
                    state.baseAllResultsCount = 0
                    return .merge(
                        .cancel(id: searchCancelID),
                        .cancel(id: searchEPGCancelID),
                        .cancel(id: searchPeopleCancelID),
                        .cancel(id: searchProgramsCancelID)
                    )
                }

                state.isSearching = true
                state.isPeopleSearchLoading = trimmed.count >= 2
                state.isProgramsSearchLoading = true
                let debounceEffect: Effect<Action> = .run { send in
                    try await clock.sleep(for: .milliseconds(250))
                    await send(.performSearch(query))
                }
                .cancellable(id: searchCancelID, cancelInFlight: true)
                return .merge(.cancel(id: searchEPGCancelID), .cancel(id: searchPeopleCancelID), .cancel(id: searchProgramsCancelID), debounceEffect)

            case let .performSearch(query):
                state.debouncedQuery = query
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    state.isSearching = false
                    state.isPeopleSearchLoading = false
                    state.isProgramsSearchLoading = false
                    state.liveResults = []
                    state.vodResults = []
                    state.seriesResults = []
                    state.enrichedLiveResults = []
                    state.enrichedVODResults = []
                    state.enrichedSeriesResults = []
                    state.peopleResults = []
                    state.programResults = []
                    state.activePeopleSearchRequestID = nil
                    state.activeProgramsSearchRequestID = nil
                    state.activeSearchRequestID = nil
                    state.filterCounts = [:]
                    state.baseAllResultsCount = 0
                    return .merge(
                        .cancel(id: searchCancelID),
                        .cancel(id: searchEPGCancelID),
                        .cancel(id: searchPeopleCancelID),
                        .cancel(id: searchProgramsCancelID)
                    )
                }

                state.isSearching = true
                let filter = state.filter
                let selectedPID = state.selectedPlaylistID
                let searchRequestID = UUID()
                let peopleRequestID = UUID()
                let programsRequestID = UUID()
                state.activeSearchRequestID = searchRequestID
                state.activePeopleSearchRequestID = peopleRequestID
                state.activeProgramsSearchRequestID = programsRequestID
                state.isPeopleSearchLoading = trimmed.count >= 2
                state.isProgramsSearchLoading = true

                // These two supplemental scopes have independent cancellation so
                // a slow metadata request cannot hold up the local catalogue search.
                state.peopleResults = []
                state.programResults = []

                let channels: [GlobalSearchResultItem]
                let vods: [GlobalSearchResultItem]
                let series: [GlobalSearchResultItem]

                if !state.indexedChannels.isEmpty || !state.indexedVODs.isEmpty || !state.indexedSeries.isEmpty {
                    channels = state.indexedChannels
                    vods = state.indexedVODs
                    series = state.indexedSeries
                } else {
                    let defaultBadge = PlaylistSourceBadge(
                        id: state.lastLoadedConfig.map(EPGReminderIdentifier.playlistIdentity(for:)) ?? "default",
                        playlistName: state.lastLoadedConfig?.serverURL?.host ?? "Varsayılan",
                        colorHex: "#0A84FF"
                    )
                    channels = state.allChannels.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                    vods = state.allVODs.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                    series = state.allSeries.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                }

                var configsByBadgeID: [String: (config: PlaylistConfig, badge: PlaylistSourceBadge)] = [:]
                let primaryBadge = PlaylistSourceBadge(
                    id: state.lastLoadedConfig.map(EPGReminderIdentifier.playlistIdentity(for:)) ?? "default",
                    playlistName: state.lastLoadedConfig?.serverURL?.host ?? "Varsayılan",
                    colorHex: "#0A84FF"
                )
                if let primaryConfig = state.lastLoadedConfig {
                    configsByBadgeID[primaryBadge.id] = (primaryConfig, primaryBadge)
                }
                for (index, playlist) in state.savedPlaylists.enumerated() {
                    guard let config = playlist.toPlaylistConfig() else { continue }
                    let badge = UnifiedPlaylistManager.shared.badge(for: config, index: index)
                    configsByBadgeID[badge.id] = (config, badge)
                }
                let scopedConfigs = Array(configsByBadgeID.values
                    .filter { selectedPID == nil || $0.badge.id == selectedPID?.uuidString }
                    .sorted { $0.badge.id < $1.badge.id })
                let adultFilteringEnabled = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdultContent = settingsClient.isAdultContent
                let blacklistedCategoryIDs = parentalControlClient.blacklistedCategoryIDs()

                let searchEffect: Effect<Action> = .run { send in
                    guard !Task.isCancelled else { return }
                    var remoteVODs: [GlobalSearchResultItem] = []
                    var remoteSeries: [GlobalSearchResultItem] = []
                    if filter == .all || filter == .vod || filter == .series || filter == .uhd4k {
                        for source in scopedConfigs where source.config.type == .plex || source.config.type == .emby {
                            guard !Task.isCancelled else { return }
                            guard let results = try? await iptvClient.searchMediaServer(source.config, trimmed) else { continue }
                            for item in results.vods where !item.categoryID.isEmpty
                                && !blacklistedCategoryIDs.contains(item.categoryID)
                                && (!adultFilteringEnabled || !isAdultContent(item.title))
                            {
                                remoteVODs.append(GlobalSearchResultItem(item: item, playlistBadge: source.badge))
                            }
                            for item in results.series where !item.categoryID.isEmpty
                                && !blacklistedCategoryIDs.contains(item.categoryID)
                                && (!adultFilteringEnabled || !isAdultContent(item.title))
                            {
                                remoteSeries.append(GlobalSearchResultItem(item: item, playlistBadge: source.badge))
                            }
                        }
                    }
                    let knownVODIDs = Set(vods.map { "\($0.playlistBadge.id)_\($0.item.id)" })
                    let knownSeriesIDs = Set(series.map { "\($0.playlistBadge.id)_\($0.item.id)" })
                    remoteVODs.removeAll { knownVODIDs.contains("\($0.playlistBadge.id)_\($0.item.id)") }
                    remoteSeries.removeAll { knownSeriesIDs.contains("\($0.playlistBadge.id)_\($0.item.id)") }
                    guard !Task.isCancelled else { return }
                    let output = GlobalSearchEngine.search(
                        query: trimmed,
                        filter: filter,
                        selectedPlaylistID: selectedPID,
                        channels: channels,
                        vods: vods + remoteVODs,
                        series: series + remoteSeries,
                        limitPerCategory: 100,
                        isCancelled: { Task.isCancelled }
                    )
                    guard !Task.isCancelled else { return }
                    await send(.searchEnrichedCompleted(requestID: searchRequestID, query: query, filter: filter, playlistID: selectedPID, output: output))
                }
                .cancellable(id: searchCancelID, cancelInFlight: true)
                let catalog = (vods + series).filter {
                    selectedPID == nil || $0.playlistBadge.id == selectedPID?.uuidString
                }
                let allLiveChannels = state.allChannels
                let personSearchEffect: Effect<Action> = .run { send in
                    guard trimmed.count >= 2, !Task.isCancelled else {
                        await send(.peopleSearchCompleted(requestID: peopleRequestID, query: query, filter: filter, playlistID: selectedPID, results: []))
                        return
                    }
                    guard let response = try? await tmdbClient.searchPeople(trimmed) else {
                        guard !Task.isCancelled else { return }
                        await send(.peopleSearchCompleted(requestID: peopleRequestID, query: query, filter: filter, playlistID: selectedPID, results: []))
                        return
                    }
                    guard !Task.isCancelled else { return }
                    let catalogByNormalizedTitle = Dictionary(grouping: catalog, by: { FuzzySearchEngine.normalize($0.item.title) })
                    var seen = Set<String>()
                    var matches: [PersonCreditResult] = []
                    for person in Array(response.results ?? []).prefix(30) {
                        guard !Task.isCancelled, let name = person.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { continue }
                        let portraitURL = person.profilePath.flatMap { URL(string: "https://image.tmdb.org/t/p/w185/\($0.trimmingCharacters(in: CharacterSet(charactersIn: "/")))") }
                        for credit in person.knownFor ?? [] {
                            let creditTitles = [credit.title, credit.originalTitle, credit.name, credit.originalName]
                                .compactMap(\.self)
                                .map(FuzzySearchEngine.normalize)
                                .filter { !$0.isEmpty }
                            var playable: [GlobalSearchResultItem] = []
                            var seenCandidates = Set<String>()
                            let expectedType: MediaModels.ItemType? = switch credit.mediaType?.lowercased() {
                            case "movie": .vod
                            case "tv": .series
                            default: nil
                            }
                            let creditYear = (credit.releaseDate ?? credit.firstAirDate).flatMap { Int($0.prefix(4)) }
                            for title in creditTitles {
                                for result in catalogByNormalizedTitle[title] ?? [] {
                                    let key = "\(result.playlistBadge.id)|\(result.item.id)"
                                    guard seenCandidates.insert(key).inserted else { continue }
                                    if let expectedType {
                                        guard result.item.type == expectedType else { continue }
                                    }
                                    if let creditYear {
                                        guard Int((result.item.releaseDate ?? "").prefix(4)) == creditYear else { continue }
                                    }
                                    playable.append(result)
                                }
                            }
                            if expectedType == nil || creditYear == nil {
                                let distinctTitles = Set(playable.map {
                                    "\($0.item.type.rawValue)|\(FuzzySearchEngine.normalize($0.item.title))|\(($0.item.releaseDate ?? "").prefix(4))"
                                })
                                guard distinctTitles.count == 1 else { continue }
                            }
                            for result in playable where seen.insert("\(person.id)|\(result.playlistBadge.id)|\(result.item.id)").inserted {
                                matches.append(PersonCreditResult(personID: person.id, personName: name, portraitURL: portraitURL, result: result))
                                if matches.count >= 80 {
                                    break
                                }
                            }
                            if matches.count >= 80 {
                                break
                            }
                        }
                        if matches.count >= 80 {
                            break
                        }
                    }
                    guard !Task.isCancelled else { return }
                    await send(.peopleSearchCompleted(requestID: peopleRequestID, query: query, filter: filter, playlistID: selectedPID, results: matches))
                }
                .cancellable(id: searchPeopleCancelID, cancelInFlight: true)

                let channelsByBadgeID = Dictionary(grouping: channels, by: { $0.playlistBadge.id })
                let programsEffect: Effect<Action> = .run { send in
                    var matches: [ProgramResult] = []
                    var seen = Set<String>()
                    for source in scopedConfigs {
                        guard !Task.isCancelled else { return }
                        let sourceChannels = channelsByBadgeID[source.badge.id]?.map(\.item)
                            ?? (source.badge.id == primaryBadge.id ? allLiveChannels : [])
                        let found: [CachedEPGProgramMatch] = if source.config.type == .m3u {
                            await iptvClient.searchCachedEPGPrograms(source.config, trimmed, sourceChannels, 100 - matches.count)
                        } else {
                            await customEPGMappingClient.searchCachedPrograms(trimmed, sourceChannels, 100 - matches.count)
                        }
                        for match in found {
                            let result = GlobalSearchResultItem(item: match.channel, playlistBadge: source.badge, matchedEPGTitle: match.program.title, matchedEPGProgram: match.program)
                            if seen.insert("\(match.program.id)|\(source.badge.id)").inserted {
                                matches.append(ProgramResult(program: match.program, result: result))
                            }
                            if matches.count >= 100 {
                                break
                            }
                        }
                        if matches.count >= 100 {
                            break
                        }
                    }
                    guard !Task.isCancelled else { return }
                    await send(.programsSearchCompleted(requestID: programsRequestID, query: query, filter: filter, playlistID: selectedPID, results: matches))
                }
                .cancellable(id: searchProgramsCancelID, cancelInFlight: true)
                return .merge(.cancel(id: searchEPGCancelID), searchEffect, personSearchEffect, programsEffect)

            case let .searchCompleted(query, filter, live, vods, series):
                guard state.debouncedQuery == query, state.filter == filter else { return .none }
                state.isSearching = false
                state.liveResults = live
                state.vodResults = vods
                state.seriesResults = series
                return .none

            case let .searchEnrichedCompleted(requestID, query, filter, playlistID, output):
                guard state.activeSearchRequestID == requestID, state.debouncedQuery == query, state.filter == filter, state.selectedPlaylistID == playlistID else { return .none }
                state.activeSearchRequestID = nil
                state.isSearching = false
                state.enrichedLiveResults = output.live
                state.enrichedVODResults = output.vods
                state.enrichedSeriesResults = output.series
                state.filterCounts = output.counts
                state.baseAllResultsCount = output.counts[.all, default: 0]

                // Maintain backward compatibility
                state.liveResults = output.live.map(\.item)
                state.vodResults = output.vods.map(\.item)
                state.seriesResults = output.series.map(\.item)
                state.filterCounts[.people] = state.peopleResults.count
                state.filterCounts[.programs] = state.programResults.count
                state.updateAllResultsCount()
                guard let primaryConfig = state.lastLoadedConfig, !output.live.isEmpty else { return .none }
                var playlistConfigs: [String: PlaylistConfig] = [:]
                let primaryBadgeID = EPGReminderIdentifier.playlistIdentity(for: primaryConfig)
                playlistConfigs[primaryBadgeID] = primaryConfig
                for (index, playlist) in state.savedPlaylists.enumerated() {
                    guard let config = playlist.toPlaylistConfig() else { continue }
                    let badge = UnifiedPlaylistManager.shared.badge(for: config, index: index)
                    playlistConfigs[badge.id] = config
                }
                let channelResults = Array(output.live.prefix(6))
                let selectedPlaylistID = state.selectedPlaylistID
                return .run { send in
                    var programByResultID: [String: EPGProgram] = [:]
                    // M3U channels share one XMLTV feed. Fetch serially so concurrent
                    // cache misses cannot each download and parse the whole guide.
                    for result in channelResults {
                        guard !Task.isCancelled else { return }
                        guard let config = playlistConfigs[result.playlistBadge.id] else { continue }
                        let programs = await (try? iptvClient.fetchShortEPG(config, result.item.id, 4)) ?? []
                        let now = Date()
                        let selectedProgram = programs
                            .filter { $0.startTime > now }
                            .sorted { $0.startTime < $1.startTime }
                            .first
                            ?? programs.first(where: \.isPlayingNow)
                            ?? programs.first(where: { $0.endTime > now })
                        if let selectedProgram {
                            programByResultID[result.id] = selectedProgram
                        }
                    }
                    guard !Task.isCancelled else { return }
                    let results = output.live.map { result -> GlobalSearchResultItem in
                        guard let program = programByResultID[result.id] else { return result }
                        return GlobalSearchResultItem(
                            item: result.item,
                            playlistBadge: result.playlistBadge,
                            is4K: result.is4K,
                            matchedEPGTitle: program.title,
                            matchedEPGProgram: program,
                            score: result.score
                        )
                    }
                    await send(.liveEPGEnriched(
                        query: query,
                        filter: filter,
                        playlistID: selectedPlaylistID,
                        results: results
                    ))
                }
                .cancellable(id: searchEPGCancelID, cancelInFlight: true)

            case let .liveEPGEnriched(query, filter, playlistID, results):
                guard
                    state.debouncedQuery == query,
                    state.filter == filter,
                    state.selectedPlaylistID == playlistID
                else { return .none }
                state.enrichedLiveResults = results
                return .none

            case let .peopleSearchCompleted(requestID, query, filter, playlistID, results):
                guard state.activePeopleSearchRequestID == requestID, state.debouncedQuery == query, state.filter == filter, state.selectedPlaylistID == playlistID else { return .none }
                state.activePeopleSearchRequestID = nil
                state.isPeopleSearchLoading = false
                state.peopleResults = results
                state.filterCounts[.people] = results.count
                state.updateAllResultsCount()
                return .none

            case let .programsSearchCompleted(requestID, query, filter, playlistID, results):
                guard state.activeProgramsSearchRequestID == requestID, state.debouncedQuery == query, state.filter == filter, state.selectedPlaylistID == playlistID else { return .none }
                state.activeProgramsSearchRequestID = nil
                state.isProgramsSearchLoading = false
                state.programResults = results
                state.filterCounts[.programs] = results.count
                state.updateAllResultsCount()
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

            case let .toggleReminder(program, channel, reminderID, playlistIdentity):
                guard state.pendingReminderRequestIDs[reminderID] == nil else { return .none }
                state.reminderFailureMessage = nil
                state.reminderLoadRequestID = nil
                let requestID = UUID()
                state.pendingReminderRequestIDs[reminderID] = requestID
                if state.scheduledReminderIDs.contains(reminderID)
                    || state.scheduledReminderIDs.contains(program.id)
                {
                    state.scheduledReminderIDs.remove(reminderID)
                    state.scheduledReminderIDs.remove(program.id)
                    return .run { send in
                        await reminderClient.removeReminder(reminderID)
                        if program.id != reminderID {
                            await reminderClient.removeReminder(program.id)
                        }
                        await send(.reminderToggleResponse(
                            programID: reminderID,
                            legacyProgramID: program.id,
                            requestID: requestID,
                            isScheduled: false
                        ))
                    }
                }
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
                            await send(.reminderToggleResponse(programID: reminderID, legacyProgramID: program.id, requestID: requestID, isScheduled: false))
                            await send(.reminderSchedulingFailed)
                            return
                        }
                        try await reminderClient.scheduleReminder(namespacedProgram, channel, 5, playlistIdentity)
                        let ids = await reminderClient.getScheduledReminderIDs()
                        await send(.reminderToggleResponse(
                            programID: reminderID,
                            legacyProgramID: program.id,
                            requestID: requestID,
                            isScheduled: ids.contains(reminderID)
                        ))
                    } catch {
                        await send(.reminderToggleResponse(programID: reminderID, legacyProgramID: program.id, requestID: requestID, isScheduled: false))
                        await send(.reminderSchedulingFailed)
                    }
                }

            case let .reminderToggleResponse(programID, legacyProgramID, requestID, isScheduled):
                guard state.pendingReminderRequestIDs[programID] == requestID else { return .none }
                state.pendingReminderRequestIDs.removeValue(forKey: programID)
                if isScheduled {
                    state.scheduledReminderIDs.insert(programID)
                } else {
                    state.scheduledReminderIDs.remove(programID)
                    state.scheduledReminderIDs.remove(legacyProgramID)
                }
                return .none

            case .reminderSchedulingFailed:
                state.reminderFailureMessage = AppStrings.Player.reminderSchedulingFailed
                return .run { send in
                    try? await Task.sleep(for: .seconds(4))
                    await send(.clearReminderFailure)
                }

            case .clearReminderFailure:
                state.reminderFailureMessage = nil
                return .none

            case let .filterChanged(filter):
                state.filter = filter
                if !state.debouncedQuery.isEmpty {
                    return .send(.performSearch(state.debouncedQuery))
                }
                return .none

            case let .selectPlaylistFilter(playlistID):
                state.selectedPlaylistID = playlistID
                if !state.debouncedQuery.isEmpty {
                    return .send(.performSearch(state.debouncedQuery))
                }
                return .none

            case .resetCache:
                state.hasLoaded = false
                state.isLoading = false
                state.primaryCatalogLoadRequestID = nil
                state.multiPlaylistLoadRequestID = nil
                state.isSearching = false
                state.allChannels = []
                state.allVODs = []
                state.allSeries = []
                state.indexedChannels = []
                state.indexedVODs = []
                state.indexedSeries = []
                state.liveResults = []
                state.vodResults = []
                state.seriesResults = []
                state.enrichedLiveResults = []
                state.enrichedVODResults = []
                state.enrichedSeriesResults = []
                state.peopleResults = []
                state.programResults = []
                state.filterCounts[.people] = 0
                state.filterCounts[.programs] = 0
                state.filterCounts = [:]
                state.baseAllResultsCount = 0
                state.searchQuery = ""
                state.debouncedQuery = ""
                state.lastLoadedConfig = nil
                state.selectedPlaylistID = nil
                return .merge(
                    .cancel(id: searchCatalogLoadCancelID),
                    .cancel(id: searchMultiPlaylistLoadCancelID),
                    .cancel(id: searchCancelID),
                    .cancel(id: searchEPGCancelID),
                    .cancel(id: searchPeopleCancelID),
                    .cancel(id: searchProgramsCancelID)
                )

            case let .channelSelected(channel):
                let query = state.debouncedQuery
                return .run { send in
                    if !query.isEmpty {
                        _ = try? await databaseClient.saveSearchHistory(query)
                    }
                    await send(.delegate(.didSelectChannel(channel, playlist: nil)))
                }

            case let .focusedResultChanged(id):
                state.focusedResultID = id
                return .none

            case let .vodSelected(vod):
                let query = state.debouncedQuery
                return .run { send in
                    if !query.isEmpty {
                        _ = try? await databaseClient.saveSearchHistory(query)
                    }
                    await send(.delegate(.didSelectVOD(vod)))
                }

            case let .seriesSelected(series):
                let query = state.debouncedQuery
                return .run { send in
                    if !query.isEmpty {
                        _ = try? await databaseClient.saveSearchHistory(query)
                    }
                    await send(.delegate(.didSelectSeries(series)))
                }

            case let .personCreditSelected(personCredit):
                let item = personCredit.result.item
                let query = state.debouncedQuery
                return .run { send in
                    if !query.isEmpty {
                        _ = try? await databaseClient.saveSearchHistory(query)
                    }
                    if item.type == .series {
                        await send(.delegate(.didSelectSeries(item)))
                    } else {
                        await send(.delegate(.didSelectVOD(item)))
                    }
                }

            case let .programSelected(programResult):
                let result = programResult.result
                let channelPlaylist = state.indexedChannels
                    .filter { $0.playlistBadge.id == result.playlistBadge.id }
                    .map(\.item)
                let fallback = state.allChannels
                let playlist = channelPlaylist.isEmpty ? (fallback.isEmpty ? [result.item] : fallback) : channelPlaylist
                let query = state.debouncedQuery
                return .run { send in
                    if !query.isEmpty {
                        _ = try? await databaseClient.saveSearchHistory(query)
                    }
                    await send(.delegate(.didSelectChannel(result.item, playlist: playlist)))
                }

            case .clearHistoryTapped:
                state.recentSearches = []
                return .run { _ in
                    _ = try? await databaseClient.clearSearchHistory()
                }

            case let .recentSearchTapped(query):
                state.searchQuery = query
                state.debouncedQuery = query
                return .send(.performSearch(query))

            case let .tagSelected(tag):
                state.searchQuery = tag.title
                state.debouncedQuery = tag.title
                return .send(.performSearch(tag.title))

            case let .loadFavoritesResponse(favs, scope):
                guard profileContextClient.snapshot() == scope else { return .none }
                state.favoriteIDs = Set(favs.map(FavoriteIdentity.init))
                return .none

            case let .toggleFavorite(item, type, playlistID):
                let profileScope = profileContextClient.snapshot()
                let favItem = FavoriteItem(
                    id: item.id,
                    type: type,
                    title: item.title,
                    coverURL: item.coverURL?.absoluteString,
                    streamURL: item.streamURL?.absoluteString,
                    playlistID: playlistID
                )
                let identity = FavoriteIdentity(favItem)
                if state.favoriteIDs.contains(identity) {
                    state.favoriteIDs.remove(identity)
                } else {
                    state.favoriteIDs.insert(identity)
                }
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(favItem, profileScope)
                }

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - GlobalSearchFeature Alias

public typealias GlobalSearchFeature = SearchFeature
