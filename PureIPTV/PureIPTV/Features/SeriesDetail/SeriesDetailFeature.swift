import ComposableArchitecture
import FactoryKit
import Foundation
import OSLog

// MARK: - SeriesDetailFeature

@Reducer
public struct SeriesDetailFeature {
    public enum EpisodeShuffleScope: Equatable, Sendable {
        case selectedSeason
        case series
    }

    @ObservableState
    public struct State: Equatable {
        public enum EpisodeSortOrder: String, CaseIterable, Equatable, Sendable {
            case oldestFirst
            case newestFirst

            public var title: String {
                switch self {
                case .oldestFirst: AppStrings.SeriesDetail.oldestEpisodesFirst
                case .newestFirst: AppStrings.SeriesDetail.newestEpisodesFirst
                }
            }
        }

        public var series: MediaModels.Item
        public let config: PlaylistConfig

        // API Data
        public var info: DetailModels.Info?
        public var seasons: [DetailModels.Season] = []
        public var allEpisodes: [String: [DetailModels.Episode]] = [:] // Keyed by season number string
        public var watchAvailabilityCountryCode: String?
        public var watchAvailability: TMDBWatchProviderRegionDTO?
        public var watchAvailabilityResponse: TMDBWatchProvidersResponseDTO?
        public var watchAvailabilityLoadedAt: Date?
        public var watchAvailabilityLoadedMediaID: Int?
        public var watchAvailabilityRequestID: UUID?
        public var isWatchAvailabilityLoading = false
        public var watchAvailabilityFailed = false
        public var nextUpEpisode: DetailModels.Episode?
        public var tmdbTV: TMDBTVDetailsDTO?
        public var awardRecognitions: [WikidataAwardClient.Recognition] = []
        public var tmdbSearchResults: [TMDBMovieSearchResultDTO] = []
        public var selectedTMDBMatchID: Int?
        public var hasManualTMDBOverride = false
        public var didUserChangeTMDBMatch = false
        public var manualTMDBSearchRequestID: UUID?
        public var tmdbMatchPresentationRequestID: UUID?
        public var lastTMDBMatchWriteRevision: Date?
        public var isTMDBMatchPickerPresented = false
        public var presentationProfileScope: ProfileContextSnapshot?
        public var presentationOverrideRequestID: UUID?
        public var isPresentationOverrideLoaded = false
        public var isPresentationEditorPresented = false

        public var selectedSeasonNumber: Int?
        public var isLoading = false
        public var isTMDBLoading = false
        public var isFavorite = false
        public var downloadedEpisodes: [String: Bool] = [:]
        public var downloadedEpisodesRevision: UInt64 = 0
        public var deletedEpisodeRevisions: [String: UInt64] = [:]
        public var pendingDeleteEpisodeID: String?
        public var pendingDeleteEpisodeTitle: String?
        public var isConfirmingEpisodeDeletion = false
        public var deletingEpisodeIDs: Set<String> = []
        public var downloadErrorMessage: String?
        public var historyItem: WatchHistoryItem?
        public var episodeProgressMap: [String: WatchHistoryItem] = [:]
        public var hasUserSelectedSeason = false
        public var pendingEpisodeReveal: EpisodeRevealRequest?
        public var episodeLayoutMode: EpisodeLayoutMode = .list
        public var episodeSortOrder: EpisodeSortOrder = .oldestFirst
        public var errorMessage: String?

        public var autoPlayOnLoad: Bool = false
        public var canManageTMDBMatch: Bool {
            config.playlistID != nil
        }

        public var canManagePresentation: Bool {
            config.playlistID != nil
        }

        public var isTrailerPresented: Bool = false
        public var trailerVideoKey: String?
        public var trailerPresentationRequestID: UUID?

        public var resolvedTrailerKey: String? {
            if let videos = tmdbTV?.videos?.results {
                if let officialTrailer = videos.first(where: { ($0.type == "Trailer" || $0.type == "Teaser") && $0.site?.lowercased() == "youtube" }) {
                    return officialTrailer.key
                }
                if let firstVideo = videos.first(where: { $0.site?.lowercased() == "youtube" }) {
                    return firstVideo.key
                }
            }
            if let yt = info?.youtubeTrailer, !yt.isEmpty {
                if yt.contains("v=") {
                    return URLComponents(string: yt)?.queryItems?.first(where: { $0.name == "v" })?.value
                } else if yt.contains("youtu.be/") {
                    return yt.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first
                }
                return yt
            }
            return nil
        }

        public enum EpisodeLayoutMode: String, CaseIterable, Sendable, Equatable {
            case list
            case grid
        }

        /// Computed
        public var currentEpisodes: [DetailModels.Episode] {
            guard let seasonNum = selectedSeasonNumber else { return [] }
            return allEpisodes[String(seasonNum)] ?? []
        }

        public var displayEpisodes: [DetailModels.Episode] {
            switch episodeSortOrder {
            case .oldestFirst: currentEpisodes
            case .newestFirst: Array(currentEpisodes.reversed())
            }
        }

        public var sequentialPlaylistEpisodes: [DetailModels.Episode] {
            let all = SeriesEpisodeCatalogNormalizer.sorted(allEpisodes.values.flatMap(\.self))
            return all.isEmpty ? currentEpisodes : all
        }

        public var canShuffleSelectedSeason: Bool {
            currentEpisodes.count > 1
        }

        public var canShuffleSeries: Bool {
            sequentialPlaylistEpisodes.count > 1
        }

        public var canShuffleEpisodes: Bool {
            canShuffleSelectedSeason || canShuffleSeries
        }

        public var currentEpisodeRevealTarget: DetailModels.Episode? {
            guard let history = historyItem else { return nil }
            let episodes = SeriesEpisodeCatalogNormalizer.sorted(allEpisodes.values.flatMap(\.self))
            guard let index = episodes.firstIndex(where: { $0.id == history.id }) else { return nil }
            let isFinished = history.duration > 0 && (history.progress / history.duration) >= 0.90
            if isFinished, episodes.index(after: index) < episodes.endIndex {
                return episodes[episodes.index(after: index)]
            }
            return episodes[index]
        }

        public struct EpisodeRevealRequest: Equatable, Sendable {
            public let id: UUID
            public let episodeID: String
            public let seasonNumber: Int

            public init(id: UUID = UUID(), episodeID: String, seasonNumber: Int) {
                self.id = id
                self.episodeID = episodeID
                self.seasonNumber = seasonNumber
            }
        }

        public mutating func updateNextUpEpisode() {
            let allEps = SeriesEpisodeCatalogNormalizer.sorted(allEpisodes.values.flatMap(\.self))
            if let history = historyItem, let currentIndex = allEps.firstIndex(where: { $0.id == history.id }) {
                let isFinished = history.duration > 0 && (history.progress / history.duration) >= 0.90
                if isFinished {
                    let nextIndex = allEps.index(after: currentIndex)
                    if nextIndex < allEps.endIndex {
                        nextUpEpisode = allEps[nextIndex]
                        return
                    }
                } else {
                    nextUpEpisode = allEps[currentIndex]
                    return
                }
            }
            nextUpEpisode = currentEpisodes.first ?? allEps.first
        }

        public init(series: MediaModels.Item, config: PlaylistConfig, historyItem: WatchHistoryItem? = nil, autoPlayOnLoad: Bool = false) {
            self.series = series
            self.config = config
            self.historyItem = historyItem
            self.autoPlayOnLoad = autoPlayOnLoad
        }
    }

    public indirect enum Action {
        case onAppear
        case presentationOverrideLoaded(requestID: UUID, profileScope: ProfileContextSnapshot, override: MediaPresentationOverride?)
        case editPresentationTapped
        case dismissPresentationEditor
        case savePresentationOverride(MediaPresentationOverride?)
        case presentationOverrideSaved(requestID: UUID, profileScope: ProfileContextSnapshot)
        case infoResponse(Result<(info: DetailModels.Info, seasons: [DetailModels.Season], allEpisodes: [String: [DetailModels.Episode]]), Error>)
        case tmdbSearchResponse(Result<TMDBSearchResponseDTO, Error>)
        case tmdbDetailsResponse(Result<TMDBTVDetailsDTO, Error>)
        case watchAvailabilityCountrySelected(String?)
        case loadWatchAvailability(mediaID: Int)
        case watchAvailabilityResponse(requestID: UUID, mediaID: Int, result: Result<TMDBWatchProvidersResponseDTO, Error>)
        case retryWatchAvailability
        case awardRecognitionsResponse(tmdbID: Int, result: Result<[WikidataAwardClient.Recognition], Error>)
        case tmdbOverrideLoaded(Int?)
        case manualTMDBSearch(String)
        case manualTMDBSearchResponse(UUID, Result<TMDBSearchResponseDTO, Error>)
        case showTMDBMatchPicker
        case dismissTMDBMatchPicker
        case coordinatorDismissTMDBMatchPicker(requestID: UUID)
        case selectTMDBMatch(Int)
        case manualTMDBDetailsResponse(Int, Result<TMDBTVDetailsDTO, Error>)
        case clearTMDBMatchOverride
        case seasonSelected(Int)
        case revealCurrentEpisodeTapped
        case episodeRevealHandled(UUID)
        case episodeSelected(DetailModels.Episode)
        case shuffleEpisodesTapped(EpisodeShuffleScope)
        case toggleLayoutMode
        case episodeSortOrderSelected(State.EpisodeSortOrder)
        case playNextEpisodeTapped
        case tmdbTimeout
        case toggleFavorite
        case favoriteStatusLoaded(Bool, ProfileContextSnapshot)
        case downloadedEpisodesLoaded(revision: UInt64, episodes: [String: Bool])
        case episodeProgressLoaded([WatchHistoryItem], ProfileContextSnapshot)
        case markEpisodeUnwatched(String)
        case downloadEpisode(DetailModels.Episode)
        case cancelDownloadedEpisodeDeletion
        case downloadedEpisodeDeletionDialogDismissed
        case confirmDownloadedEpisodeDeletion
        case downloadedEpisodeDeletionResponse(id: String, succeeded: Bool)
        case dismissDownloadError
        case historyStatusLoaded(WatchHistoryItem?, ProfileContextSnapshot)
        case resumeTapped
        case restartTapped
        case trailerTapped
        case coordinatorDismissTrailer(requestID: UUID)
        case delegate(Delegate)
        case closeTapped
        case viewDidDisappear

        public enum Delegate: Equatable {
            case didSelectEpisode(PlayerFeature.PlayableItem, playlist: [PlayerFeature.PlayableItem]?)
            case presentTMDBMatchPicker(requestID: UUID)
            case presentTrailer(requestID: UUID)
            case close
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Injected(\.tmdbClient) var tmdbClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.cloudSyncClient) var cloudSyncClient
    @Dependency(\.tmdbMatchOverrideClient) var tmdbMatchOverrideClient
    @Dependency(\.downloadClient) var downloadClient
    @Dependency(\.wikidataAwardClient) var wikidataAwardClient
    @Dependency(\.mediaPresentationOverrideClient) var mediaPresentationOverrideClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.dismiss) var dismiss

    private nonisolated enum CancelID: Hashable, Sendable {
        case awardRecognitions
        case watchAvailability
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let tmdbClient = tmdbClient
        let profileContextClient = profileContextClient
        let cloudSyncClient = cloudSyncClient
        let tmdbMatchOverrideClient = tmdbMatchOverrideClient
        let wikidataAwardClient = wikidataAwardClient
        let mediaPresentationOverrideClient = mediaPresentationOverrideClient
        let settingsClient = settingsClient

        Reduce { state, action in
            switch action {
            case .onAppear:
                let savedWatchAvailabilityCountry = settingsClient.getWatchAvailabilityRegionCode()
                if state.watchAvailabilityCountryCode != savedWatchAvailabilityCountry {
                    state.watchAvailabilityFailed = false
                    if let mediaID = state.tmdbTV?.id,
                       state.watchAvailabilityLoadedMediaID == mediaID,
                       let response = state.watchAvailabilityResponse
                    {
                        state.watchAvailability = savedWatchAvailabilityCountry.flatMap { response.results?[$0] }
                        state.isWatchAvailabilityLoading = false
                    } else {
                        state.watchAvailability = nil
                    }
                }
                state.watchAvailabilityCountryCode = savedWatchAvailabilityCountry
                let existingAvailabilityEffect: Effect<Action> = if savedWatchAvailabilityCountry != nil,
                                                                    let mediaID = state.tmdbTV?.id
                {
                    .send(.loadWatchAvailability(mediaID: mediaID))
                } else {
                    .none
                }
                let profileScope = profileContextClient.snapshot()
                state.episodeSortOrder = SeriesEpisodeSortPreference.load(
                    profileID: profileScope.profileID,
                    playlistID: state.config.playlistID,
                    seriesID: state.series.id
                ) ?? .oldestFirst
                let seriesID = state.series.id
                let presentationRequestID = UUID()
                if state.presentationProfileScope != profileScope {
                    state.series = state.series.replacingPresentationOverride(nil)
                    state.isPresentationOverrideLoaded = false
                }
                state.presentationProfileScope = profileScope
                state.presentationOverrideRequestID = presentationRequestID
                let presentationOverrideEffect: Effect<Action> = if let playlistID = state.config.playlistID {
                    .run { send in
                        let overrides = await mediaPresentationOverrideClient.load(profileScope.profileID, playlistID, .series)
                        guard profileContextClient.snapshot() == profileScope else { return }
                        await send(.presentationOverrideLoaded(
                            requestID: presentationRequestID,
                            profileScope: profileScope,
                            override: overrides[seriesID]
                        ))
                    }
                } else {
                    .none
                }
                guard !state.isLoading, state.seasons.isEmpty else {
                    return .merge(presentationOverrideEffect, existingAvailabilityEffect)
                }
                state.isLoading = true
                state.isTMDBLoading = true
                state.errorMessage = nil

                let config = state.config
                let searchTitle = state.series.title.cleanedForTMDBSearch()
                let playlistID = config.playlistID
                let downloadedEpisodesRevision = state.downloadedEpisodesRevision

                print("Fetching Series Info and TMDB details for: \(searchTitle)")

                let infoEffect: Effect<Action> = .run { send in
                    do {
                        let result = try await iptvClient.fetchSeriesInfo(config, seriesID)
                        let episodes = result.episodes
                        let parsed = Dictionary(grouping: episodes, by: { String($0.season) })
                            .mapValues { SeriesEpisodeCatalogNormalizer.sorted($0) }
                        await send(.infoResponse(.success((info: result.info, seasons: result.seasons, allEpisodes: parsed))))
                    } catch {
                        await send(.infoResponse(.failure(error)))
                    }
                }

                let tmdbEffect: Effect<Action> = .run { send in
                    await send(.tmdbSearchResponse(
                        Result { try await tmdbClient.searchTV(searchTitle) }
                    ))
                }

                let timeoutEffect: Effect<Action> = .run { send in
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    await send(.tmdbTimeout)
                }

                let favoriteEffect: Effect<Action> = .run { [id = state.series.id] send in
                    let isFav = await (try? databaseClient.isFavorite(id, "series", playlistID, profileScope)) ?? false
                    await send(.favoriteStatusLoaded(isFav, profileScope))
                }

                let historyEffect: Effect<Action> = .run { [id = state.series.id] send in
                    let history = try? await databaseClient.getSeriesWatchProgress(id, playlistID, profileScope)
                    await send(.historyStatusLoaded(history, profileScope))
                }

                let downloadEffect: Effect<Action> = .run { send in
                    let downloaded = await (try? downloadClient.getDownloadedMedia()) ?? []
                    let dict = Dictionary(downloaded.filter(\.isAvailable).map { ($0.id, true) }, uniquingKeysWith: { current, _ in current })
                    await send(.downloadedEpisodesLoaded(revision: downloadedEpisodesRevision, episodes: dict))
                }

                let episodesHistoryEffect: Effect<Action> = .run { [id = state.series.id] send in
                    let items = await (try? databaseClient.fetchSeriesEpisodesWatchHistory(id, playlistID, profileScope)) ?? []
                    await send(.episodeProgressLoaded(items, profileScope))
                }

                let overrideEffect: Effect<Action> = if let playlistID {
                    .run { [itemID = state.series.id] send in
                        let override = await tmdbMatchOverrideClient.load(playlistID, .series, itemID, cloudSyncClient.isSyncEnabled())
                        await send(.tmdbOverrideLoaded(override))
                    }
                } else {
                    .none
                }

                return .merge(infoEffect, tmdbEffect, timeoutEffect, favoriteEffect, historyEffect, downloadEffect, episodesHistoryEffect, overrideEffect, presentationOverrideEffect, existingAvailabilityEffect)

            case let .watchAvailabilityCountrySelected(countryCode):
                guard countryCode == nil || TMDBWatchAvailabilityRegionCode.normalized(countryCode) != nil else { return .none }
                let normalizedCode = TMDBWatchAvailabilityRegionCode.normalized(countryCode)
                guard state.watchAvailabilityCountryCode != normalizedCode else { return .none }
                settingsClient.setWatchAvailabilityRegionCode(normalizedCode)
                state.watchAvailabilityCountryCode = normalizedCode
                state.watchAvailabilityFailed = false
                if let normalizedCode,
                   let mediaID = state.tmdbTV?.id,
                   state.watchAvailabilityLoadedMediaID == mediaID,
                   state.watchAvailabilityLoadedAt != nil,
                   let response = state.watchAvailabilityResponse
                {
                    state.watchAvailability = response.results?[normalizedCode]
                    state.isWatchAvailabilityLoading = false
                    return .none
                }
                state.watchAvailability = nil
                guard let normalizedCode, let mediaID = state.tmdbTV?.id else { return .none }
                return .send(.loadWatchAvailability(mediaID: mediaID))

            case let .loadWatchAvailability(mediaID):
                guard state.watchAvailabilityCountryCode != nil, state.tmdbTV?.id == mediaID else { return .none }
                if let loadedMediaID = state.watchAvailabilityLoadedMediaID, loadedMediaID != mediaID {
                    state.watchAvailabilityResponse = nil
                    state.watchAvailabilityLoadedAt = nil
                    state.watchAvailabilityLoadedMediaID = nil
                    state.watchAvailability = nil
                }
                if state.watchAvailabilityLoadedMediaID == mediaID,
                   state.watchAvailabilityLoadedAt != nil,
                   let response = state.watchAvailabilityResponse
                {
                    state.watchAvailability = state.watchAvailabilityCountryCode.flatMap { response.results?[$0] }
                    state.isWatchAvailabilityLoading = false
                    state.watchAvailabilityFailed = false
                    return .none
                }
                guard state.watchAvailabilityRequestID == nil else { return .none }
                let requestID = UUID()
                state.watchAvailabilityRequestID = requestID
                state.isWatchAvailabilityLoading = true
                state.watchAvailabilityFailed = false
                return Self.makeWatchAvailabilityRequest(
                    requestID: requestID,
                    mediaID: mediaID,
                    fetch: tmdbClient.fetchTVWatchProviders
                )

            case let .watchAvailabilityResponse(requestID, mediaID, .success(response)):
                guard state.watchAvailabilityRequestID == requestID,
                      state.tmdbTV?.id == mediaID else { return .none }
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                state.watchAvailabilityFailed = false
                state.watchAvailabilityResponse = response
                state.watchAvailability = state.watchAvailabilityCountryCode.flatMap { response.results?[$0] }
                state.watchAvailabilityLoadedAt = Date()
                state.watchAvailabilityLoadedMediaID = mediaID
                return .none

            case let .watchAvailabilityResponse(requestID, mediaID, .failure):
                guard state.watchAvailabilityRequestID == requestID,
                      state.tmdbTV?.id == mediaID else { return .none }
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                state.watchAvailabilityFailed = true
                state.watchAvailability = nil
                state.watchAvailabilityResponse = nil
                state.watchAvailabilityLoadedAt = nil
                state.watchAvailabilityLoadedMediaID = nil
                return .none

            case .retryWatchAvailability:
                guard state.watchAvailabilityCountryCode != nil,
                      let mediaID = state.tmdbTV?.id else { return .none }
                state.watchAvailabilityRequestID = nil
                state.watchAvailabilityResponse = nil
                state.watchAvailabilityLoadedAt = nil
                state.watchAvailabilityLoadedMediaID = nil
                state.isWatchAvailabilityLoading = false
                state.watchAvailabilityFailed = false
                return .send(.loadWatchAvailability(mediaID: mediaID))

            case let .presentationOverrideLoaded(requestID, profileScope, override):
                guard state.presentationOverrideRequestID == requestID,
                      state.presentationProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                state.series = state.series.replacingPresentationOverride(override)
                state.isPresentationOverrideLoaded = true
                return .none

            case .editPresentationTapped:
                guard state.canManagePresentation, state.isPresentationOverrideLoaded else { return .none }
                state.isPresentationEditorPresented = true
                return .none

            case .dismissPresentationEditor:
                state.isPresentationEditorPresented = false
                return .none

            case let .savePresentationOverride(override):
                guard let playlistID = state.config.playlistID,
                      let profileScope = state.presentationProfileScope,
                      profileContextClient.snapshot() == profileScope
                else {
                    state.isPresentationEditorPresented = false
                    return .none
                }
                let requestID = UUID()
                state.presentationOverrideRequestID = requestID
                state.series = state.series.replacingPresentationOverride(override)
                state.isPresentationOverrideLoaded = true
                state.isPresentationEditorPresented = false
                let mediaID = state.series.id
                return .run { send in
                    await mediaPresentationOverrideClient.save(override, mediaID, profileScope.profileID, playlistID, .series)
                    guard profileContextClient.snapshot() == profileScope else { return }
                    await send(.presentationOverrideSaved(requestID: requestID, profileScope: profileScope))
                }

            case let .presentationOverrideSaved(requestID, profileScope):
                guard state.presentationOverrideRequestID == requestID,
                      state.presentationProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                return .none

            case let .infoResponse(.success(result)):
                let previousSeason = state.selectedSeasonNumber
                state.info = result.info
                state.seasons = result.seasons
                state.allEpisodes = result.allEpisodes

                let availableSeasons = Set(
                    result.seasons.map(\.seasonNumber)
                        + result.allEpisodes.keys.compactMap(Int.init)
                )
                let historySeason = state.historyItem.flatMap { history in
                    result.allEpisodes.values.flatMap(\.self).first(where: { $0.id == history.id })?.season
                }
                if let previousSeason, availableSeasons.contains(previousSeason) {
                    state.selectedSeasonNumber = previousSeason
                } else if let historySeason {
                    state.selectedSeasonNumber = historySeason
                } else if let firstSeason = state.seasons.first {
                    state.selectedSeasonNumber = firstSeason.seasonNumber
                } else if let firstKey = state.allEpisodes.keys.sorted(by: { Int($0) ?? 0 < Int($1) ?? 0 }).first {
                    state.selectedSeasonNumber = Int(firstKey)
                }

                if !state.isTMDBLoading {
                    state.isLoading = false
                }

                state.updateNextUpEpisode()

                if state.autoPlayOnLoad {
                    state.autoPlayOnLoad = false
                    return .send(.resumeTapped)
                }

                return .none

            case let .tmdbSearchResponse(.success(response)):
                state.tmdbSearchResults = response.results ?? []
                guard !state.hasManualTMDBOverride else { return .none }
                if let firstResult = response.results?.first {
                    print("TMDB search found result for TV: \(firstResult.name ?? "") (ID: \(firstResult.id))")
                    return .run { send in
                        await send(.tmdbDetailsResponse(
                            Result { try await tmdbClient.fetchTVDetails(firstResult.id) }
                        ))
                    }
                } else {
                    print("TMDB search returned 0 results for TV")
                    state.isTMDBLoading = false
                    if !state.seasons.isEmpty {
                        state.isLoading = false
                    }
                    return .none
                }

            case let .tmdbDetailsResponse(.success(tvDetails)):
                guard !state.hasManualTMDBOverride else { return .none }
                print("TMDB details fetched for TV: \(tvDetails.name ?? "")")
                state.isTMDBLoading = false
                state.tmdbTV = tvDetails
                state.awardRecognitions = []
                if !state.seasons.isEmpty {
                    state.isLoading = false
                }
                let awardEffect = Effect<Action>.run { send in
                    await send(.awardRecognitionsResponse(
                        tmdbID: tvDetails.id,
                        result: Result { try await wikidataAwardClient.fetchRecognitions([tvDetails.id], .series) }
                    ))
                }
                .cancellable(id: CancelID.awardRecognitions, cancelInFlight: true)
                let availabilityEffect: Effect<Action> = if state.watchAvailabilityCountryCode != nil {
                    .send(.loadWatchAvailability(mediaID: tvDetails.id))
                } else {
                    .none
                }
                return .merge(awardEffect, availabilityEffect)

            case let .awardRecognitionsResponse(tmdbID, .success(recognitions)):
                guard state.tmdbTV?.id == tmdbID else { return .none }
                state.awardRecognitions = recognitions.filter { $0.tmdbID == tmdbID }
                return .none

            case let .awardRecognitionsResponse(tmdbID, .failure):
                guard state.tmdbTV?.id == tmdbID else { return .none }
                state.awardRecognitions = []
                return .none

            case let .tmdbSearchResponse(.failure(error)):
                guard !state.hasManualTMDBOverride else { return .none }
                print("TMDB search failed for TV: \(error.localizedDescription)")
                state.isTMDBLoading = false
                if !state.seasons.isEmpty {
                    state.isLoading = false
                }
                return .none

            case let .tmdbDetailsResponse(.failure(error)):
                guard !state.hasManualTMDBOverride else { return .none }
                print("TMDB fetch details failed for TV: \(error.localizedDescription)")
                state.isTMDBLoading = false
                state.tmdbTV = nil
                state.awardRecognitions = []
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                state.watchAvailabilityFailed = false
                state.watchAvailability = nil
                state.watchAvailabilityResponse = nil
                state.watchAvailabilityLoadedAt = nil
                state.watchAvailabilityLoadedMediaID = nil
                if !state.seasons.isEmpty {
                    state.isLoading = false
                }
                return .merge(.cancel(id: CancelID.awardRecognitions), .cancel(id: CancelID.watchAvailability))

            case let .tmdbOverrideLoaded(tmdbID):
                guard !state.didUserChangeTMDBMatch else { return .none }
                guard let tmdbID else { return .none }
                state.hasManualTMDBOverride = true
                state.didUserChangeTMDBMatch = true
                state.selectedTMDBMatchID = tmdbID
                state.isTMDBLoading = true
                state.watchAvailability = nil
                state.watchAvailabilityResponse = nil
                state.watchAvailabilityLoadedAt = nil
                state.watchAvailabilityLoadedMediaID = nil
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                return .merge(.cancel(id: CancelID.watchAvailability), .run { send in
                    await send(.manualTMDBDetailsResponse(tmdbID, Result { try await tmdbClient.fetchTVDetails(tmdbID) }))
                })

            case let .manualTMDBSearch(query):
                state.isTMDBMatchPickerPresented = true
                state.isTMDBLoading = true
                let requestID = UUID()
                state.manualTMDBSearchRequestID = requestID
                return .run { send in
                    await send(.manualTMDBSearchResponse(requestID, Result { try await tmdbClient.searchTV(query) }))
                }

            case let .manualTMDBSearchResponse(requestID, .success(response)):
                guard state.manualTMDBSearchRequestID == requestID else { return .none }
                state.manualTMDBSearchRequestID = nil
                state.tmdbSearchResults = response.results ?? []
                state.isTMDBLoading = false
                return .none

            case let .manualTMDBSearchResponse(requestID, .failure):
                guard state.manualTMDBSearchRequestID == requestID else { return .none }
                state.manualTMDBSearchRequestID = nil
                state.tmdbSearchResults = []
                state.isTMDBLoading = false
                return .none

            case .showTMDBMatchPicker:
                guard state.tmdbMatchPresentationRequestID == nil else { return .none }
                let requestID = UUID()
                state.tmdbMatchPresentationRequestID = requestID
                state.isTMDBMatchPickerPresented = true
                state.manualTMDBSearchRequestID = nil
                state.tmdbSearchResults = []
                return .send(.delegate(.presentTMDBMatchPicker(requestID: requestID)))

            case .dismissTMDBMatchPicker:
                state.isTMDBMatchPickerPresented = false
                state.manualTMDBSearchRequestID = nil
                state.tmdbMatchPresentationRequestID = nil
                return .none

            case let .coordinatorDismissTMDBMatchPicker(requestID):
                guard state.tmdbMatchPresentationRequestID == requestID else { return .none }
                state.isTMDBMatchPickerPresented = false
                state.manualTMDBSearchRequestID = nil
                state.tmdbMatchPresentationRequestID = nil
                return .none

            case let .selectTMDBMatch(tmdbID):
                guard state.canManageTMDBMatch, tmdbID > 0, let playlistID = state.config.playlistID else { return .none }
                state.hasManualTMDBOverride = true
                state.didUserChangeTMDBMatch = true
                state.selectedTMDBMatchID = tmdbID
                state.tmdbTV = nil
                state.awardRecognitions = []
                state.isTMDBLoading = true
                state.watchAvailability = nil
                state.watchAvailabilityResponse = nil
                state.watchAvailabilityLoadedAt = nil
                state.watchAvailabilityLoadedMediaID = nil
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                state.watchAvailabilityFailed = false
                let itemID = state.series.id
                let cloudSyncEnabled = cloudSyncClient.isSyncEnabled()
                let revision = max(Date(), (state.lastTMDBMatchWriteRevision ?? .distantPast).addingTimeInterval(0.001))
                state.lastTMDBMatchWriteRevision = revision
                return .merge(
                    .cancel(id: CancelID.awardRecognitions),
                    .cancel(id: CancelID.watchAvailability),
                    .run { _ in await tmdbMatchOverrideClient.save(tmdbID, playlistID, .series, itemID, cloudSyncEnabled, revision) },
                    .run { send in
                        await send(.manualTMDBDetailsResponse(tmdbID, Result { try await tmdbClient.fetchTVDetails(tmdbID) }))
                    }
                )

            case let .manualTMDBDetailsResponse(tmdbID, .success(details)):
                guard state.selectedTMDBMatchID == tmdbID else { return .none }
                state.tmdbTV = details
                state.awardRecognitions = []
                state.isTMDBLoading = false
                state.isLoading = false
                state.isTMDBMatchPickerPresented = false
                let awardEffect: Effect<Action> = .run { send in
                    await send(.awardRecognitionsResponse(
                        tmdbID: details.id,
                        result: Result { try await wikidataAwardClient.fetchRecognitions([details.id], .series) }
                    ))
                }
                .cancellable(id: CancelID.awardRecognitions, cancelInFlight: true)
                let availabilityEffect: Effect<Action> = if state.watchAvailabilityCountryCode != nil {
                    .send(.loadWatchAvailability(mediaID: details.id))
                } else {
                    .none
                }
                return .merge(awardEffect, availabilityEffect)

            case let .manualTMDBDetailsResponse(tmdbID, .failure):
                guard state.selectedTMDBMatchID == tmdbID else { return .none }
                state.isTMDBLoading = false
                state.tmdbTV = nil
                state.awardRecognitions = []
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                state.watchAvailabilityFailed = false
                state.watchAvailability = nil
                state.watchAvailabilityResponse = nil
                state.watchAvailabilityLoadedAt = nil
                state.watchAvailabilityLoadedMediaID = nil
                return .merge(.cancel(id: CancelID.awardRecognitions), .cancel(id: CancelID.watchAvailability))

            case .clearTMDBMatchOverride:
                guard let playlistID = state.config.playlistID else { return .none }
                let itemID = state.series.id
                let cloudSyncEnabled = cloudSyncClient.isSyncEnabled()
                let revision = max(Date(), (state.lastTMDBMatchWriteRevision ?? .distantPast).addingTimeInterval(0.001))
                state.lastTMDBMatchWriteRevision = revision
                state.hasManualTMDBOverride = false
                state.didUserChangeTMDBMatch = true
                state.selectedTMDBMatchID = nil
                state.tmdbTV = nil
                state.awardRecognitions = []
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                state.watchAvailabilityFailed = false
                state.watchAvailability = nil
                state.watchAvailabilityResponse = nil
                state.watchAvailabilityLoadedAt = nil
                state.watchAvailabilityLoadedMediaID = nil
                state.isTMDBMatchPickerPresented = false
                let query = state.series.title.cleanedForTMDBSearch()
                return .merge(
                    .cancel(id: CancelID.awardRecognitions),
                    .cancel(id: CancelID.watchAvailability),
                    .run { _ in await tmdbMatchOverrideClient.save(nil, playlistID, .series, itemID, cloudSyncEnabled, revision) },
                    .run { send in await send(.tmdbSearchResponse(Result { try await tmdbClient.searchTV(query) })) }
                )

            case .tmdbTimeout:
                print("TMDB loading timed out after 4 seconds")
                state.isTMDBLoading = false
                state.isLoading = false
                return .none

            case let .infoResponse(.failure(error)):
                state.isLoading = false
                state.isTMDBLoading = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .seasonSelected(seasonNum):
                state.selectedSeasonNumber = seasonNum
                state.hasUserSelectedSeason = true
                state.pendingEpisodeReveal = nil
                state.updateNextUpEpisode()
                return .none

            case .revealCurrentEpisodeTapped:
                guard let episode = state.currentEpisodeRevealTarget else { return .none }
                state.selectedSeasonNumber = episode.season
                state.pendingEpisodeReveal = State.EpisodeRevealRequest(
                    episodeID: episode.id,
                    seasonNumber: episode.season
                )
                return .none

            case let .episodeRevealHandled(requestID):
                guard state.pendingEpisodeReveal?.id == requestID else { return .none }
                state.pendingEpisodeReveal = nil
                return .none

            case .toggleLayoutMode:
                state.episodeLayoutMode = state.episodeLayoutMode == .list ? .grid : .list
                return .none

            case let .episodeSortOrderSelected(order):
                state.episodeSortOrder = order
                SeriesEpisodeSortPreference.save(
                    order,
                    profileID: profileContextClient.snapshot().profileID,
                    playlistID: state.config.playlistID,
                    seriesID: state.series.id
                )
                return .none

            case .playNextEpisodeTapped:
                if let nextEp = state.nextUpEpisode {
                    return .send(.episodeSelected(nextEp))
                }
                return .none

            case let .shuffleEpisodesTapped(scope):
                let episodes: [DetailModels.Episode] = switch scope {
                case .selectedSeason:
                    state.currentEpisodes
                case .series:
                    state.sequentialPlaylistEpisodes
                }
                guard episodes.count > 1 else { return .none }
                let playbackOrder = episodes.shuffled()
                guard let firstEpisode = playbackOrder.first else { return .none }
                return playEpisode(firstEpisode, playbackOrder: playbackOrder, state: &state)

            case let .episodeProgressLoaded(items, scope):
                guard profileContextClient.snapshot() == scope else { return .none }
                state.episodeProgressMap = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
                return .none

            case let .markEpisodeUnwatched(id):
                guard
                    let history = state.episodeProgressMap[id],
                    history.duration > 0,
                    history.progress / history.duration >= 0.90
                else { return .none }
                state.episodeProgressMap.removeValue(forKey: id)
                if state.historyItem?.id == id {
                    state.historyItem = nil
                }
                state.updateNextUpEpisode()
                let profileScope = profileContextClient.snapshot()
                let playlistID = state.config.playlistID
                return .run { _ in
                    try? await databaseClient.deleteWatchProgress(id, "episode", playlistID, profileScope)
                }

            case let .episodeSelected(episode):
                return playEpisode(episode, playbackOrder: nil, state: &state)

            case .resumeTapped:
                if state.isLoading || state.allEpisodes.isEmpty {
                    state.autoPlayOnLoad = true
                    return .none
                }

                guard let history = state.historyItem else {
                    return .send(.restartTapped)
                }

                // If episode was completed (>90%), automatically advance to next episode if available
                let isFinished = history.duration > 0 && (history.progress / history.duration) >= 0.90
                if isFinished, let nextEp = state.nextUpEpisode {
                    return .send(.episodeSelected(nextEp))
                }

                // Locate episode in allEpisodes to resolve accurate season and stream metadata
                let allEpsList = SeriesEpisodeCatalogNormalizer.sorted(state.allEpisodes.values.flatMap(\.self))
                let matchingEpisode = allEpsList.first(where: { $0.id == history.id })
                if let ep = matchingEpisode, state.selectedSeasonNumber != ep.season {
                    state.selectedSeasonNumber = ep.season
                }
                if matchingEpisode != nil {
                    state.hasUserSelectedSeason = true
                }
                state.pendingEpisodeReveal = nil

                var resolvedStreamURL = matchingEpisode?.streamURL ?? history.streamURL.flatMap { URL(string: $0) }
                if resolvedStreamURL == nil,
                   let serverURL = state.config.serverURL,
                   let username = state.config.username,
                   let password = state.config.password
                {
                    resolvedStreamURL = serverURL.appendingPathComponent("series/\(username)/\(password)/\(history.id).mp4")
                }

                guard let streamURL = resolvedStreamURL else {
                    return .send(.restartTapped)
                }

                let startPosition = history.duration > 0 ? (history.progress / history.duration) : 0.0
                let playable = PlayerFeature.PlayableItem(
                    id: history.id,
                    title: matchingEpisode?.title ?? history.title,
                    seriesTitle: state.series.title,
                    streamURL: streamURL,
                    coverURL: history.coverURL.flatMap { URL(string: $0) } ?? matchingEpisode?.coverURL ?? state.series.coverURL,
                    seriesID: state.series.id,
                    seasonNumber: matchingEpisode?.season,
                    episodeNumber: matchingEpisode?.episodeNum,
                    startPosition: startPosition,
                    initialDuration: history.duration > 0 ? history.duration : nil,
                    initialProgress: history.progress > 0 ? history.progress : nil,
                    config: state.config
                )
                let resumeEpisodes = state.sequentialPlaylistEpisodes
                let playlist = resumeEpisodes.isEmpty ? nil : resumeEpisodes.map { ep in
                    PlayerFeature.PlayableItem(
                        id: ep.id,
                        title: "\(state.series.title) - S\(String(format: "%02d", ep.season))E\(String(format: "%02d", ep.episodeNum))",
                        seriesTitle: state.series.title,
                        streamURL: ep.streamURL,
                        coverURL: ep.coverURL ?? state.series.coverURL,
                        seriesID: state.series.id,
                        seasonNumber: ep.season,
                        episodeNumber: ep.episodeNum,
                        config: state.config
                    )
                }
                return .send(.delegate(.didSelectEpisode(playable, playlist: playlist)))

            case .restartTapped:
                if state.isLoading || state.allEpisodes.isEmpty {
                    return .none
                }

                if let history = state.historyItem {
                    let allEpsList = SeriesEpisodeCatalogNormalizer.sorted(state.allEpisodes.values.flatMap(\.self))
                    let matchingEpisode = allEpsList.first(where: { $0.id == history.id })
                    if let ep = matchingEpisode, state.selectedSeasonNumber != ep.season {
                        state.selectedSeasonNumber = ep.season
                    }
                    if matchingEpisode != nil {
                        state.hasUserSelectedSeason = true
                    }
                    state.pendingEpisodeReveal = nil

                    var resolvedStreamURL = matchingEpisode?.streamURL ?? history.streamURL.flatMap { URL(string: $0) }
                    if resolvedStreamURL == nil,
                       let serverURL = state.config.serverURL,
                       let username = state.config.username,
                       let password = state.config.password
                    {
                        resolvedStreamURL = serverURL.appendingPathComponent("series/\(username)/\(password)/\(history.id).mp4")
                    }

                    if let streamURL = resolvedStreamURL {
                        let playable = PlayerFeature.PlayableItem(
                            id: history.id,
                            title: matchingEpisode?.title ?? history.title,
                            seriesTitle: state.series.title,
                            streamURL: streamURL,
                            coverURL: history.coverURL.flatMap { URL(string: $0) } ?? matchingEpisode?.coverURL ?? state.series.coverURL,
                            seriesID: state.series.id,
                            seasonNumber: matchingEpisode?.season,
                            episodeNumber: matchingEpisode?.episodeNum,
                            startPosition: 0.0,
                            config: state.config
                        )
                        let restartEpisodes = state.sequentialPlaylistEpisodes
                        let playlist = restartEpisodes.isEmpty ? nil : restartEpisodes.map { ep in
                            PlayerFeature.PlayableItem(
                                id: ep.id,
                                title: "\(state.series.title) - S\(String(format: "%02d", ep.season))E\(String(format: "%02d", ep.episodeNum))",
                                seriesTitle: state.series.title,
                                streamURL: ep.streamURL,
                                coverURL: ep.coverURL ?? state.series.coverURL,
                                seriesID: state.series.id,
                                seasonNumber: ep.season,
                                episodeNumber: ep.episodeNum,
                                config: state.config
                            )
                        }
                        return .send(.delegate(.didSelectEpisode(playable, playlist: playlist)))
                    }
                }

                if let firstEp = state.currentEpisodes.first ?? state.allEpisodes.values.first?.first {
                    return .send(.episodeSelected(firstEp))
                }
                return .none

            case .trailerTapped:
                #if os(tvOS)
                    return .none
                #else
                    guard state.trailerPresentationRequestID == nil else { return .none }
                    guard let key = state.resolvedTrailerKey else { return .none }
                    let requestID = UUID()
                    state.trailerPresentationRequestID = requestID
                    state.trailerVideoKey = key
                    state.isTrailerPresented = true
                    return .send(.delegate(.presentTrailer(requestID: requestID)))
                #endif

            case let .coordinatorDismissTrailer(requestID):
                guard state.trailerPresentationRequestID == requestID else { return .none }
                state.isTrailerPresented = false
                state.trailerVideoKey = nil
                state.trailerPresentationRequestID = nil
                return .none

            case let .historyStatusLoaded(history, scope):
                guard profileContextClient.snapshot() == scope else { return .none }
                state.historyItem = history
                if !state.hasUserSelectedSeason,
                   let history,
                   let episode = state.allEpisodes.values.flatMap(\.self).first(where: { $0.id == history.id })
                {
                    state.selectedSeasonNumber = episode.season
                }
                state.updateNextUpEpisode()
                return .none

            case let .favoriteStatusLoaded(isFav, scope):
                guard profileContextClient.snapshot() == scope else { return .none }
                state.isFavorite = isFav
                return .none

            case let .downloadedEpisodesLoaded(revision, dict):
                var currentDownloadedEpisodes = dict
                for (episodeID, deletionRevision) in state.deletedEpisodeRevisions where revision < deletionRevision {
                    currentDownloadedEpisodes[episodeID] = nil
                }
                state.downloadedEpisodes = currentDownloadedEpisodes
                if let pendingID = state.pendingDeleteEpisodeID, currentDownloadedEpisodes[pendingID] != true {
                    state.pendingDeleteEpisodeID = nil
                    state.pendingDeleteEpisodeTitle = nil
                    state.isConfirmingEpisodeDeletion = false
                }
                return .none

            case let .downloadEpisode(episode):
                guard !state.deletingEpisodeIDs.contains(episode.id) else { return .none }
                state.pendingDeleteEpisodeID = nil
                state.pendingDeleteEpisodeTitle = nil
                state.isConfirmingEpisodeDeletion = false
                state.downloadErrorMessage = nil
                if state.downloadedEpisodes[episode.id] == true {
                    state.pendingDeleteEpisodeID = episode.id
                    state.pendingDeleteEpisodeTitle = "\(state.series.title) - S\(episode.season)E\(episode.episodeNum): \(episode.title)"
                    state.isConfirmingEpisodeDeletion = true
                    return .none
                } else {
                    let streamURL = episode.streamURL

                    let id = episode.id
                    let title = "\(state.series.title) - S\(episode.season)E\(episode.episodeNum): \(episode.title)"
                    let userAgentOverride = state.config.userAgentOverride
                    let episodeMetadata = OfflineEpisodeMetadata(
                        seriesID: state.series.id,
                        seriesTitle: state.series.title,
                        seasonNumber: episode.season,
                        episodeNumber: episode.episodeNum,
                        episodeOrdinal: state.sequentialPlaylistEpisodes.firstIndex(where: { $0.id == episode.id }),
                        playlistID: state.config.playlistID
                    )

                    let finalCoverURL: URL? = {
                        if let url = episode.coverURL {
                            return url
                        } else if let poster = state.tmdbTV?.posterPath {
                            return URL(string: "https://image.tmdb.org/t/p/w342\(poster)")
                        } else if let url = state.series.coverURL {
                            return url
                        }
                        return nil
                    }()

                    let revision = state.downloadedEpisodesRevision
                    return .run { send in
                        try? await downloadClient.startDownload(id, title, streamURL, finalCoverURL, userAgentOverride, episodeMetadata)
                        let downloaded = await (try? downloadClient.getDownloadedMedia()) ?? []
                        let dict = Dictionary(downloaded.filter(\.isAvailable).map { ($0.id, true) }, uniquingKeysWith: { current, _ in current })
                        await send(.downloadedEpisodesLoaded(revision: revision, episodes: dict))
                    }
                }

            case .cancelDownloadedEpisodeDeletion:
                state.pendingDeleteEpisodeID = nil
                state.pendingDeleteEpisodeTitle = nil
                state.isConfirmingEpisodeDeletion = false
                return .none

            case .downloadedEpisodeDeletionDialogDismissed:
                // Preserve the pending ID until the dialog action is delivered.
                // SwiftUI may update the presentation binding before the button action.
                state.isConfirmingEpisodeDeletion = false
                return .none

            case .confirmDownloadedEpisodeDeletion:
                guard let id = state.pendingDeleteEpisodeID,
                      state.downloadedEpisodes[id] == true,
                      state.deletingEpisodeIDs.insert(id).inserted
                else {
                    state.pendingDeleteEpisodeID = nil
                    state.pendingDeleteEpisodeTitle = nil
                    state.isConfirmingEpisodeDeletion = false
                    return .none
                }
                state.pendingDeleteEpisodeID = nil
                state.pendingDeleteEpisodeTitle = nil
                state.isConfirmingEpisodeDeletion = false
                return .run { send in
                    do {
                        try await downloadClient.deleteDownloadedMedia(id)
                        await send(.downloadedEpisodeDeletionResponse(id: id, succeeded: true))
                    } catch {
                        await send(.downloadedEpisodeDeletionResponse(id: id, succeeded: false))
                    }
                }

            case let .downloadedEpisodeDeletionResponse(id, succeeded):
                state.deletingEpisodeIDs.remove(id)
                if succeeded {
                    state.downloadedEpisodesRevision &+= 1
                    state.deletedEpisodeRevisions[id] = state.downloadedEpisodesRevision
                    state.downloadedEpisodes[id] = nil
                } else {
                    state.downloadErrorMessage = AppStrings.Downloads.deleteDownloadFailure
                }
                return .none

            case .dismissDownloadError:
                state.downloadErrorMessage = nil
                return .none

            case .toggleFavorite:
                let profileScope = profileContextClient.snapshot()
                let item = FavoriteItem(
                    id: state.series.id,
                    type: "series",
                    title: state.series.title,
                    coverURL: state.tmdbTV?.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" } ?? state.series.coverURL?.absoluteString,
                    streamURL: nil,
                    playlistID: state.config.playlistID
                )
                return .run { send in
                    let isNowFav = await (try? databaseClient.toggleFavorite(item, profileScope)) ?? false
                    await send(.favoriteStatusLoaded(isNowFav, profileScope))
                }

            case .closeTapped:
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                return .merge(
                    .cancel(id: CancelID.awardRecognitions),
                    .cancel(id: CancelID.watchAvailability),
                    .send(.delegate(.close))
                )

            case .viewDidDisappear:
                state.pendingEpisodeReveal = nil
                state.pendingDeleteEpisodeID = nil
                state.pendingDeleteEpisodeTitle = nil
                state.isConfirmingEpisodeDeletion = false
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                return .merge(.cancel(id: CancelID.awardRecognitions), .cancel(id: CancelID.watchAvailability))

            case .delegate:
                return .none
            }
        }
    }

    private static func makeWatchAvailabilityRequest(
        requestID: UUID,
        mediaID: Int,
        fetch: @escaping @Sendable (Int) async throws -> TMDBWatchProvidersResponseDTO
    ) -> Effect<Action> {
        .run { send in
            await send(.watchAvailabilityResponse(
                requestID: requestID,
                mediaID: mediaID,
                result: Result { try await fetch(mediaID) }
            ))
        }
        .cancellable(id: CancelID.watchAvailability, cancelInFlight: true)
    }

    private func playEpisode(
        _ episode: DetailModels.Episode,
        playbackOrder: [DetailModels.Episode]?,
        state: inout State
    ) -> Effect<Action> {
        if state.selectedSeasonNumber != episode.season {
            state.selectedSeasonNumber = episode.season
        }
        state.hasUserSelectedSeason = true
        state.pendingEpisodeReveal = nil

        let history = state.episodeProgressMap[episode.id]
        let startPosition: Double? = if let history, history.duration > 0 {
            (history.progress / history.duration) < 0.92 ? (history.progress / history.duration) : 0.0
        } else {
            nil
        }
        let initialProgress: Double? = if let history, history.duration > 0, (history.progress / history.duration) < 0.92 {
            history.progress
        } else {
            nil
        }
        let episodeOrdinal = state.sequentialPlaylistEpisodes.firstIndex(where: { $0.id == episode.id })

        let playable = PlayerFeature.PlayableItem(
            id: episode.id,
            title: "\(state.series.title) - S\(String(format: "%02d", episode.season))E\(String(format: "%02d", episode.episodeNum))",
            seriesTitle: state.series.title,
            streamURL: episode.streamURL,
            coverURL: episode.coverURL ?? state.series.coverURL,
            seriesID: state.series.id,
            episodeOrdinal: episodeOrdinal,
            seasonNumber: episode.season,
            episodeNumber: episode.episodeNum,
            startPosition: startPosition,
            initialDuration: history?.duration,
            initialProgress: initialProgress,
            config: state.config
        )
        let playlistEpisodes = playbackOrder ?? state.sequentialPlaylistEpisodes
        let playlist = playlistEpisodes.isEmpty ? nil : Array(playlistEpisodes.enumerated().map { index, item in
            PlayerFeature.PlayableItem(
                id: item.id,
                title: "\(state.series.title) - S\(String(format: "%02d", item.season))E\(String(format: "%02d", item.episodeNum))",
                seriesTitle: state.series.title,
                streamURL: item.streamURL,
                coverURL: item.coverURL ?? state.series.coverURL,
                seriesID: state.series.id,
                episodeOrdinal: index,
                seasonNumber: item.season,
                episodeNumber: item.episodeNum,
                config: state.config
            )
        })
        return .send(.delegate(.didSelectEpisode(playable, playlist: playlist)))
    }
}
