import ComposableArchitecture
import FactoryKit
import Foundation
import OSLog

@Reducer
public struct VODDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public var vod: MediaModels.Item
        public let config: PlaylistConfig

        // API Data
        public var info: DetailModels.Info?
        public var tmdbMovie: TMDBMovieDetailsDTO?
        public var watchAvailabilityCountryCode: String?
        public var watchAvailability: TMDBWatchProviderRegionDTO?
        public var watchAvailabilityResponse: TMDBWatchProvidersResponseDTO?
        public var watchAvailabilityLoadedAt: Date?
        public var watchAvailabilityLoadedMediaID: Int?
        public var watchAvailabilityRequestID: UUID?
        public var isWatchAvailabilityLoading = false
        public var watchAvailabilityFailed = false
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
        public var presentationOverrides: [String: MediaPresentationOverride] = [:]

        // UI State
        public var isLoading = false
        public var isTMDBLoading = false
        public var isFavorite = false
        public var isDownloaded = false
        public var isStartingDownload = false
        public var downloadErrorMessage: String?
        public var isConfirmingDownloadDeletion = false
        public var isDeletingDownload = false
        public var downloadStatusRequestID: UUID?
        public var downloadDeletionRequestID: UUID?
        public var historyItem: WatchHistoryItem?
        public var errorMessage: String?

        public var autoPlayOnLoad: Bool = false
        public var canManageTMDBMatch: Bool {
            config.playlistID != nil
        }

        public var canManagePresentation: Bool {
            config.playlistID != nil
        }

        public var selectedActor: TMDBCastMemberDTO?
        public var selectedActorDetails: TMDBPersonDetailsDTO?
        public var isLoadingActorDetails: Bool = false
        public var actorBiographyPresentationRequestID: UUID?
        public var isTrailerPresented: Bool = false
        public var trailerVideoKey: String?
        public var trailerPresentationRequestID: UUID?

        // Multi-Version & Quality Grouping (Madde #47)
        public var availableVersions: [MovieVersionEdition] = []
        public var selectedVersionId: String?
        public var matchingRequestID: UUID?

        // Similar Movies Intelligent Matching
        public var catalogVODs: [MediaModels.Item] = []
        public var matchedVODsByTMDBId: [Int: MediaModels.Item] = [:]
        public var selectedUnmatchedMovie: TMDBSimilarItemDTO?
        public var unmatchedMoviePresentationRequestID: UUID?

        public var resolvedTrailerKey: String? {
            if let videos = tmdbMovie?.videos?.results {
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

        public init(
            vod: MediaModels.Item,
            config: PlaylistConfig,
            historyItem: WatchHistoryItem? = nil,
            autoPlayOnLoad: Bool = false,
            catalogVODs: [MediaModels.Item] = []
        ) {
            self.vod = vod
            self.config = config
            self.historyItem = historyItem
            self.autoPlayOnLoad = autoPlayOnLoad
            self.catalogVODs = catalogVODs
        }
    }

    public indirect enum Action {
        case onAppear
        case presentationOverridesLoaded(requestID: UUID, profileScope: ProfileContextSnapshot, overrides: [String: MediaPresentationOverride])
        case editPresentationTapped
        case dismissPresentationEditor
        case savePresentationOverride(MediaPresentationOverride?)
        case presentationOverrideSaved(requestID: UUID, profileScope: ProfileContextSnapshot)
        case infoResponse(Result<DetailModels.Info, Error>)
        case tmdbSearchResponse(Result<TMDBSearchResponseDTO, Error>)
        case tmdbDetailsResponse(Result<TMDBMovieDetailsDTO, Error>)
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
        case manualTMDBDetailsResponse(Int, Result<TMDBMovieDetailsDTO, Error>)
        case clearTMDBMatchOverride
        case catalogVODsResponse(Result<[MediaModels.Item], Error>)
        case playTapped
        case resumeTapped
        case restartTapped
        case tmdbTimeout
        case toggleFavorite
        case favoriteStatusLoaded(Bool, ProfileContextSnapshot)
        case downloadStatusLoaded(requestID: UUID, id: String, isDownloaded: Bool)
        case downloadStartFinished(requestID: UUID, id: String, isDownloaded: Bool, errorMessage: String?)
        case downloadTapped
        case cancelDownloadDeletion
        case downloadDeletionDialogDismissed
        case confirmDownloadDeletion
        case downloadDeletionFinished(requestID: UUID, id: String, succeeded: Bool)
        case historyStatusLoaded(id: String, item: WatchHistoryItem?, scope: ProfileContextSnapshot)
        case markUnwatched
        case actorTapped(TMDBCastMemberDTO)
        case actorDetailsResponse(requestID: UUID, result: Result<TMDBPersonDetailsDTO, Error>)
        case coordinatorDismissActorBiography(requestID: UUID)
        case trailerTapped
        case coordinatorDismissTrailer(requestID: UUID)
        case selectVersion(MovieVersionEdition)
        case similarMovieTapped(TMDBSimilarItemDTO)
        case coordinatorDismissUnmatchedMovie(requestID: UUID)
        case backgroundMatchingCompleted(requestID: UUID, versions: [MovieVersionEdition], matched: [Int: MediaModels.Item])
        case delegate(Delegate)
        case closeTapped
        case viewDidDisappear

        public enum Delegate: Equatable {
            case didSelectPlay(PlayerFeature.PlayableItem)
            case didSelectVOD(MediaModels.Item)
            case presentTMDBMatchPicker(requestID: UUID)
            case presentActorBiography(requestID: UUID)
            case presentTrailer(requestID: UUID)
            case presentUnmatchedMovie(requestID: UUID)
            case close
        }
    }

    private nonisolated enum CancelID: Hashable, Sendable {
        case versionHistory
        case awardRecognitions
        case watchAvailability
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

    public init() {}

    private static func computeMatchingInBackground(
        vod: MediaModels.Item,
        catalog: [MediaModels.Item],
        similar: [TMDBSimilarItemDTO]?,
        selectedVersionId: String?
    ) async -> (versions: [MovieVersionEdition], matched: [Int: MediaModels.Item]) {
        await Task.detached(priority: .utility) {
            func fastNorm(_ raw: String) -> String {
                var s = raw.lowercased()
                let replacements: [(String, String)] = [
                    ("ı", "i"), ("ğ", "g"), ("ü", "u"), ("ş", "s"), ("ö", "o"), ("ç", "c"),
                    ("İ", "i"), ("Ğ", "g"), ("Ü", "u"), ("Ş", "s"), ("Ö", "o"), ("Ç", "c"),
                ]
                for (t, r) in replacements {
                    s = s.replacingOccurrences(of: t, with: r)
                }
                let noiseWords: Set = [
                    "1080p", "720p", "2160p", "4k", "uhd", "hdr", "bluray", "blu-ray",
                    "web-dl", "webdl", "webrip", "dual", "dublaj", "altyazili", "altyazılı",
                    "turkce", "türkçe", "tr", "eng", "ita", "ger", "fra", "es", "multi",
                ]
                let tokens = s.components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !noiseWords.contains($0) && !$0.isEmpty }
                return tokens.joined(separator: " ")
            }

            // 1. Versions Discovery
            var versions: [MovieVersionEdition] = []
            let targetNorm = fastNorm(vod.title)
            if catalog.isEmpty || targetNorm.isEmpty {
                versions = [MovieVersionEdition(item: vod, isCurrent: true)]
            } else {
                var matchingItems = catalog.filter { item in
                    let itemNorm = fastNorm(item.title)
                    return !itemNorm.isEmpty && itemNorm == targetNorm
                }
                if !matchingItems.contains(where: { $0.id == vod.id }) {
                    matchingItems.insert(vod, at: 0)
                }
                let currentId = selectedVersionId ?? vod.id
                func qualityPriority(for title: String) -> Int {
                    let lower = title.lowercased()
                    if lower.contains("4k") || lower.contains("uhd") || lower.contains("2160p") {
                        return 4
                    }
                    if lower.contains("1080p") || lower.contains("fhd") || lower.contains("bluray") || lower.contains("blu-ray") {
                        return 3
                    }
                    if lower.contains("720p") || lower.contains("hd") {
                        return 2
                    }
                    if lower.contains("480p") || lower.contains("sd") || lower.contains("dvdrip") {
                        return 0
                    }
                    return 1
                }
                matchingItems.sort { lhs, rhs in
                    let lhsPriority = qualityPriority(for: lhs.title)
                    let rhsPriority = qualityPriority(for: rhs.title)
                    if lhsPriority != rhsPriority {
                        return lhsPriority > rhsPriority
                    }
                    let lhsTitle = fastNorm(lhs.title)
                    let rhsTitle = fastNorm(rhs.title)
                    if lhsTitle != rhsTitle {
                        return lhsTitle < rhsTitle
                    }
                    return lhs.id < rhs.id
                }
                versions = matchingItems.map { MovieVersionEdition(item: $0, isCurrent: $0.id == currentId) }
            }

            // 2. Similar Movies Matching
            var matched: [Int: MediaModels.Item] = [:]
            if let similarList = similar, !similarList.isEmpty, !catalog.isEmpty {
                let catalogNormMap: [(norm: String, item: MediaModels.Item)] = catalog.compactMap { item in
                    let norm = fastNorm(item.title)
                    return norm.isEmpty ? nil : (norm: norm, item: item)
                }
                for movie in similarList {
                    let primaryNorm = fastNorm(movie.title ?? movie.name ?? "")
                    let origNorm = fastNorm(movie.originalTitle ?? movie.originalName ?? "")
                    if let exact = catalogNormMap.first(where: {
                        (!primaryNorm.isEmpty && $0.norm == primaryNorm) || (!origNorm.isEmpty && $0.norm == origNorm)
                    }) {
                        matched[movie.id] = exact.item
                        continue
                    }
                    if primaryNorm.count >= 4, let m = catalogNormMap.first(where: { $0.norm.contains(primaryNorm) || primaryNorm.contains($0.norm) }) {
                        matched[movie.id] = m.item
                        continue
                    }
                    if origNorm.count >= 4, let m = catalogNormMap.first(where: { $0.norm.contains(origNorm) || origNorm.contains($0.norm) }) {
                        matched[movie.id] = m.item
                        continue
                    }
                }
            }

            return (versions: versions, matched: matched)
        }.value
    }

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let tmdbClient = tmdbClient
        let profileContextClient = profileContextClient
        let tmdbMatchOverrideClient = tmdbMatchOverrideClient
        let cloudSyncClient = cloudSyncClient
        let wikidataAwardClient = wikidataAwardClient
        let mediaPresentationOverrideClient = mediaPresentationOverrideClient
        let settingsClient = settingsClient

        Reduce { state, action in
            switch action {
            case .onAppear:
                let savedWatchAvailabilityCountry = settingsClient.getWatchAvailabilityRegionCode()
                if state.watchAvailabilityCountryCode != savedWatchAvailabilityCountry {
                    state.watchAvailabilityFailed = false
                    if let mediaID = state.tmdbMovie?.id,
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
                                                                    let mediaID = state.tmdbMovie?.id
                {
                    .send(.loadWatchAvailability(mediaID: mediaID))
                } else {
                    .none
                }
                if state.availableVersions.isEmpty {
                    state.availableVersions = [MovieVersionEdition(item: state.vod, isCurrent: true)]
                    state.selectedVersionId = state.vod.id
                }
                let config = state.config
                let vodID = state.vod.id
                let profileScope = profileContextClient.snapshot()
                let playlistID = config.playlistID
                if state.presentationProfileScope != profileScope {
                    state.vod = state.vod.replacingPresentationOverride(nil)
                    state.presentationOverrides = [:]
                    state.isPresentationOverrideLoaded = false
                    state.matchingRequestID = nil
                    let selectedVersionID = state.selectedVersionId
                    state.availableVersions = state.availableVersions.map { version in
                        MovieVersionEdition(item: version.item.replacingPresentationOverride(nil), isCurrent: version.id == selectedVersionID)
                    }
                    state.catalogVODs = state.catalogVODs.map { $0.replacingPresentationOverride(nil) }
                    state.matchedVODsByTMDBId = state.matchedVODsByTMDBId.mapValues { $0.replacingPresentationOverride(nil) }
                }
                let presentationRequestID = UUID()
                state.presentationProfileScope = profileScope
                state.presentationOverrideRequestID = presentationRequestID
                let presentationOverrideEffect: Effect<Action> = if let playlistID {
                    .run { send in
                        let overrides = await mediaPresentationOverrideClient.load(profileScope.profileID, playlistID, .movie)
                        guard profileContextClient.snapshot() == profileScope else { return }
                        await send(.presentationOverridesLoaded(
                            requestID: presentationRequestID,
                            profileScope: profileScope,
                            overrides: overrides
                        ))
                    }
                } else {
                    .none
                }
                guard !state.isLoading, state.info == nil else {
                    return .merge(presentationOverrideEffect, existingAvailabilityEffect)
                }
                state.isLoading = true
                state.isTMDBLoading = true
                state.errorMessage = nil

                let searchTitle = state.vod.title.cleanedForTMDBSearch()

                print("Fetching VOD Info and TMDB details for: \(searchTitle)")

                let infoEffect: Effect<Action> = .run { send in
                    await send(.infoResponse(
                        Result { try await iptvClient.fetchVODInfo(config, vodID) }
                    ))
                }

                let tmdbEffect: Effect<Action> = .run { send in
                    await send(.tmdbSearchResponse(
                        Result { try await tmdbClient.searchMovie(searchTitle) }
                    ))
                }

                let timeoutEffect: Effect<Action> = .run { send in
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    await send(.tmdbTimeout)
                }

                let favoriteEffect: Effect<Action> = .run { [id = state.vod.id] send in
                    let isFav = await (try? databaseClient.isFavorite(id, "vod", playlistID, profileScope)) ?? false
                    await send(.favoriteStatusLoaded(isFav, profileScope))
                }

                let historyEffect: Effect<Action> = .run { [id = state.vod.id] send in
                    let history = try? await databaseClient.getWatchProgress(id, "vod", playlistID, profileScope)
                    await send(.historyStatusLoaded(id: id, item: history, scope: profileScope))
                }
                .cancellable(id: CancelID.versionHistory, cancelInFlight: true)

                let downloadStatusRequestID = UUID()
                state.downloadStatusRequestID = downloadStatusRequestID
                let downloadEffect: Effect<Action> = .run { [id = state.vod.id] send in
                    let isDown = await (try? downloadClient.isDownloaded(id)) ?? false
                    await send(.downloadStatusLoaded(requestID: downloadStatusRequestID, id: id, isDownloaded: isDown))
                }

                let catalogEffect: Effect<Action> = state.catalogVODs.isEmpty ? .run { [config = state.config] send in
                    await send(.catalogVODsResponse(
                        Result { try await iptvClient.fetchVODs(config, nil) }
                    ))
                } : .none

                let overrideEffect: Effect<Action> = if let playlistID {
                    .run { [itemID = state.vod.id] send in
                        let override = await tmdbMatchOverrideClient.load(
                            playlistID,
                            .movie,
                            itemID,
                            cloudSyncClient.isSyncEnabled()
                        )
                        await send(.tmdbOverrideLoaded(override))
                    }
                } else {
                    .none
                }

                let matchingEffect: Effect<Action>
                if state.catalogVODs.isEmpty {
                    matchingEffect = .none
                } else {
                    let matchingRequestID = UUID()
                    state.matchingRequestID = matchingRequestID
                    matchingEffect = .run { [vod = state.vod, catalog = state.catalogVODs, similar = state.tmdbMovie?.similar?.results, versionId = state.selectedVersionId] send in
                        let res = await Self.computeMatchingInBackground(vod: vod, catalog: catalog, similar: similar, selectedVersionId: versionId)
                        await send(.backgroundMatchingCompleted(requestID: matchingRequestID, versions: res.versions, matched: res.matched))
                    }
                }

                return .merge(infoEffect, tmdbEffect, timeoutEffect, favoriteEffect, historyEffect, downloadEffect, catalogEffect, matchingEffect, overrideEffect, presentationOverrideEffect, existingAvailabilityEffect)

            case let .watchAvailabilityCountrySelected(countryCode):
                guard countryCode == nil || TMDBWatchAvailabilityRegionCode.normalized(countryCode) != nil else { return .none }
                let normalizedCode = TMDBWatchAvailabilityRegionCode.normalized(countryCode)
                guard state.watchAvailabilityCountryCode != normalizedCode else { return .none }
                settingsClient.setWatchAvailabilityRegionCode(normalizedCode)
                state.watchAvailabilityCountryCode = normalizedCode
                state.watchAvailabilityFailed = false
                if let normalizedCode,
                   let mediaID = state.tmdbMovie?.id,
                   state.watchAvailabilityLoadedMediaID == mediaID,
                   state.watchAvailabilityLoadedAt != nil,
                   let response = state.watchAvailabilityResponse
                {
                    state.watchAvailability = response.results?[normalizedCode]
                    state.isWatchAvailabilityLoading = false
                    return .none
                }
                state.watchAvailability = nil
                guard normalizedCode != nil, let mediaID = state.tmdbMovie?.id else { return .none }
                return .send(.loadWatchAvailability(mediaID: mediaID))

            case let .loadWatchAvailability(mediaID):
                guard state.watchAvailabilityCountryCode != nil, state.tmdbMovie?.id == mediaID else { return .none }
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
                    fetch: tmdbClient.fetchMovieWatchProviders
                )

            case let .watchAvailabilityResponse(requestID, mediaID, .success(response)):
                guard state.watchAvailabilityRequestID == requestID,
                      state.tmdbMovie?.id == mediaID else { return .none }
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
                      state.tmdbMovie?.id == mediaID else { return .none }
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
                      let mediaID = state.tmdbMovie?.id else { return .none }
                state.watchAvailabilityRequestID = nil
                state.watchAvailabilityResponse = nil
                state.watchAvailabilityLoadedAt = nil
                state.watchAvailabilityLoadedMediaID = nil
                state.isWatchAvailabilityLoading = false
                state.watchAvailabilityFailed = false
                return .send(.loadWatchAvailability(mediaID: mediaID))

            case let .presentationOverridesLoaded(requestID, profileScope, overrides):
                guard state.presentationOverrideRequestID == requestID,
                      state.presentationProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                state.presentationOverrides = overrides
                state.vod = state.vod.replacingPresentationOverride(overrides[state.vod.id])
                state.catalogVODs = state.catalogVODs.map { item in
                    item.replacingPresentationOverride(overrides[item.id])
                }
                let selectedVersionId = state.selectedVersionId
                state.availableVersions = state.availableVersions.map { version in
                    MovieVersionEdition(
                        item: version.item.replacingPresentationOverride(overrides[version.id]),
                        isCurrent: version.id == selectedVersionId
                    )
                }
                state.matchedVODsByTMDBId = state.matchedVODsByTMDBId.mapValues { item in
                    item.replacingPresentationOverride(overrides[item.id])
                }
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
                state.vod = state.vod.replacingPresentationOverride(override)
                if let override, !override.isEmpty {
                    state.presentationOverrides[state.vod.id] = override
                } else {
                    state.presentationOverrides.removeValue(forKey: state.vod.id)
                }
                let presentationOverrides = state.presentationOverrides
                state.catalogVODs = state.catalogVODs.map { item in
                    item.replacingPresentationOverride(presentationOverrides[item.id])
                }
                let selectedVersionId = state.selectedVersionId
                state.availableVersions = state.availableVersions.map { version in
                    MovieVersionEdition(
                        item: version.item.replacingPresentationOverride(presentationOverrides[version.id]),
                        isCurrent: version.id == selectedVersionId
                    )
                }
                state.matchedVODsByTMDBId = state.matchedVODsByTMDBId.mapValues { item in
                    item.replacingPresentationOverride(presentationOverrides[item.id])
                }
                state.isPresentationOverrideLoaded = true
                state.isPresentationEditorPresented = false
                let mediaID = state.vod.id
                return .run { send in
                    await mediaPresentationOverrideClient.save(override, mediaID, profileScope.profileID, playlistID, .movie)
                    guard profileContextClient.snapshot() == profileScope else { return }
                    await send(.presentationOverrideSaved(requestID: requestID, profileScope: profileScope))
                }

            case let .presentationOverrideSaved(requestID, profileScope):
                guard state.presentationOverrideRequestID == requestID,
                      state.presentationProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                return .none

            case let .catalogVODsResponse(.success(items)):
                let resolvedItems = items.map { item in
                    let override = state.isPresentationOverrideLoaded
                        ? state.presentationOverrides[item.id]
                        : item.presentationOverride
                    return item.replacingPresentationOverride(override)
                }
                state.catalogVODs = resolvedItems
                let matchingRequestID = UUID()
                state.matchingRequestID = matchingRequestID
                return .run { [vod = state.vod, catalog = resolvedItems, similar = state.tmdbMovie?.similar?.results, versionId = state.selectedVersionId] send in
                    let res = await Self.computeMatchingInBackground(vod: vod, catalog: catalog, similar: similar, selectedVersionId: versionId)
                    await send(.backgroundMatchingCompleted(requestID: matchingRequestID, versions: res.versions, matched: res.matched))
                }

            case .catalogVODsResponse(.failure):
                return .none

            case let .backgroundMatchingCompleted(requestID, versions, matched):
                guard state.matchingRequestID == requestID else { return .none }
                state.matchingRequestID = nil
                let overrides = state.presentationOverrides
                let isPresentationOverrideLoaded = state.isPresentationOverrideLoaded
                let selectedVersionId = state.selectedVersionId
                state.availableVersions = versions.map {
                    let override = isPresentationOverrideLoaded
                        ? overrides[$0.id]
                        : $0.item.presentationOverride
                    return MovieVersionEdition(
                        item: $0.item.replacingPresentationOverride(override),
                        isCurrent: $0.id == selectedVersionId
                    )
                }
                state.matchedVODsByTMDBId = matched.mapValues { item in
                    let override = isPresentationOverrideLoaded
                        ? overrides[item.id]
                        : item.presentationOverride
                    return item.replacingPresentationOverride(override)
                }
                return .none

            case let .infoResponse(.success(dto)):
                state.info = dto
                if !state.isTMDBLoading {
                    state.isLoading = false
                }

                if state.autoPlayOnLoad {
                    state.autoPlayOnLoad = false
                    return .send(.resumeTapped)
                }
                return .none

            case let .tmdbSearchResponse(.success(response)):
                state.tmdbSearchResults = response.results ?? []
                guard !state.hasManualTMDBOverride else { return .none }
                if let firstResult = response.results?.first {
                    print("TMDB search found result: \(firstResult.title ?? "") (ID: \(firstResult.id))")
                    return .run { send in
                        await send(.tmdbDetailsResponse(
                            Result { try await tmdbClient.fetchMovieDetails(firstResult.id) }
                        ))
                    }
                } else {
                    print("TMDB search returned 0 results for VOD")
                    state.isTMDBLoading = false
                    if state.info != nil {
                        state.isLoading = false
                    }
                    return .none
                }

            case let .tmdbDetailsResponse(.success(movieDetails)):
                guard !state.hasManualTMDBOverride else { return .none }
                print("TMDB details fetched for VOD: \(movieDetails.title ?? "")")
                state.isTMDBLoading = false
                state.tmdbMovie = movieDetails
                state.awardRecognitions = []
                if state.info != nil {
                    state.isLoading = false
                }
                let awardEffect: Effect<Action> = .run { send in
                    await send(.awardRecognitionsResponse(
                        tmdbID: movieDetails.id,
                        result: Result { try await wikidataAwardClient.fetchRecognitions([movieDetails.id], .movie) }
                    ))
                }
                .cancellable(id: CancelID.awardRecognitions, cancelInFlight: true)
                let matchingEffect: Effect<Action>
                if state.catalogVODs.isEmpty {
                    matchingEffect = .none
                } else {
                    let matchingRequestID = UUID()
                    state.matchingRequestID = matchingRequestID
                    matchingEffect = .run { [vod = state.vod, catalog = state.catalogVODs, similar = movieDetails.similar?.results, versionId = state.selectedVersionId] send in
                        let res = await Self.computeMatchingInBackground(vod: vod, catalog: catalog, similar: similar, selectedVersionId: versionId)
                        await send(.backgroundMatchingCompleted(requestID: matchingRequestID, versions: res.versions, matched: res.matched))
                    }
                }
                let availabilityEffect: Effect<Action> = if state.watchAvailabilityCountryCode != nil {
                    .send(.loadWatchAvailability(mediaID: movieDetails.id))
                } else {
                    .none
                }
                return .merge(matchingEffect, awardEffect, availabilityEffect)

            case let .tmdbSearchResponse(.failure(error)):
                guard !state.hasManualTMDBOverride else { return .none }
                print("TMDB search failed: \(error.localizedDescription)")
                state.isTMDBLoading = false
                if state.info != nil {
                    state.isLoading = false
                }
                return .none // Fail silently for tmdb search

            case let .tmdbDetailsResponse(.failure(error)):
                guard !state.hasManualTMDBOverride else { return .none }
                print("TMDB fetch details failed: \(error.localizedDescription)")
                state.isTMDBLoading = false
                state.tmdbMovie = nil
                state.awardRecognitions = []
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                state.watchAvailabilityFailed = false
                state.watchAvailability = nil
                state.watchAvailabilityResponse = nil
                state.watchAvailabilityLoadedAt = nil
                state.watchAvailabilityLoadedMediaID = nil
                if state.info != nil {
                    state.isLoading = false
                }
                return .merge(
                    .cancel(id: CancelID.awardRecognitions),
                    .cancel(id: CancelID.watchAvailability)
                ) // Fail silently for tmdb details

            case let .awardRecognitionsResponse(tmdbID, .success(recognitions)):
                guard state.tmdbMovie?.id == tmdbID else { return .none }
                state.awardRecognitions = recognitions.filter { $0.tmdbID == tmdbID }
                return .none

            case let .awardRecognitionsResponse(tmdbID, .failure):
                guard state.tmdbMovie?.id == tmdbID else { return .none }
                state.awardRecognitions = []
                return .none

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
                    await send(.manualTMDBDetailsResponse(tmdbID, Result { try await tmdbClient.fetchMovieDetails(tmdbID) }))
                })

            case let .manualTMDBSearch(query):
                state.isTMDBMatchPickerPresented = true
                state.isTMDBLoading = true
                let requestID = UUID()
                state.manualTMDBSearchRequestID = requestID
                return .run { send in
                    await send(.manualTMDBSearchResponse(requestID, Result { try await tmdbClient.searchMovie(query) }))
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
                state.tmdbMovie = nil
                state.awardRecognitions = []
                state.isTMDBLoading = true
                state.watchAvailability = nil
                state.watchAvailabilityResponse = nil
                state.watchAvailabilityLoadedAt = nil
                state.watchAvailabilityLoadedMediaID = nil
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                state.watchAvailabilityFailed = false
                let itemID = state.vod.id
                let cloudSyncEnabled = cloudSyncClient.isSyncEnabled()
                let revision = max(Date(), (state.lastTMDBMatchWriteRevision ?? .distantPast).addingTimeInterval(0.001))
                state.lastTMDBMatchWriteRevision = revision
                return .merge(
                    .cancel(id: CancelID.awardRecognitions),
                    .cancel(id: CancelID.watchAvailability),
                    .run { _ in await tmdbMatchOverrideClient.save(tmdbID, playlistID, .movie, itemID, cloudSyncEnabled, revision) },
                    .run { send in
                        await send(.manualTMDBDetailsResponse(tmdbID, Result { try await tmdbClient.fetchMovieDetails(tmdbID) }))
                    }
                )

            case let .manualTMDBDetailsResponse(tmdbID, .success(details)):
                guard state.selectedTMDBMatchID == tmdbID else { return .none }
                state.tmdbMovie = details
                state.awardRecognitions = []
                state.isTMDBLoading = false
                state.isLoading = false
                state.isTMDBMatchPickerPresented = false
                let awardEffect: Effect<Action> = .run { send in
                    await send(.awardRecognitionsResponse(
                        tmdbID: details.id,
                        result: Result { try await wikidataAwardClient.fetchRecognitions([details.id], .movie) }
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
                state.tmdbMovie = nil
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
                let itemID = state.vod.id
                let cloudSyncEnabled = cloudSyncClient.isSyncEnabled()
                let revision = max(Date(), (state.lastTMDBMatchWriteRevision ?? .distantPast).addingTimeInterval(0.001))
                state.lastTMDBMatchWriteRevision = revision
                state.hasManualTMDBOverride = false
                state.didUserChangeTMDBMatch = true
                state.selectedTMDBMatchID = nil
                state.tmdbMovie = nil
                state.awardRecognitions = []
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                state.watchAvailabilityFailed = false
                state.watchAvailability = nil
                state.watchAvailabilityResponse = nil
                state.watchAvailabilityLoadedAt = nil
                state.watchAvailabilityLoadedMediaID = nil
                state.isTMDBMatchPickerPresented = false
                let query = state.vod.title.cleanedForTMDBSearch()
                return .merge(
                    .cancel(id: CancelID.awardRecognitions),
                    .cancel(id: CancelID.watchAvailability),
                    .run { _ in await tmdbMatchOverrideClient.save(nil, playlistID, .movie, itemID, cloudSyncEnabled, revision) },
                    .run { send in await send(.tmdbSearchResponse(Result { try await tmdbClient.searchMovie(query) })) }
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

            case let .actorTapped(actor):
                guard state.actorBiographyPresentationRequestID == nil else { return .none }
                let requestID = UUID()
                state.actorBiographyPresentationRequestID = requestID
                state.selectedActor = actor
                state.selectedActorDetails = nil
                state.isLoadingActorDetails = true
                return .merge(
                    .run { send in
                        await send(.actorDetailsResponse(
                            requestID: requestID,
                            result: Result {
                                try await tmdbClient.fetchPersonDetails(actor.id)
                            }
                        ))
                    },
                    .send(.delegate(.presentActorBiography(requestID: requestID)))
                )

            case let .actorDetailsResponse(requestID, .success(details)):
                guard state.actorBiographyPresentationRequestID == requestID else { return .none }
                state.isLoadingActorDetails = false
                state.selectedActorDetails = details
                return .none

            case let .actorDetailsResponse(requestID, .failure):
                guard state.actorBiographyPresentationRequestID == requestID else { return .none }
                state.isLoadingActorDetails = false
                return .none

            case let .coordinatorDismissActorBiography(requestID):
                guard state.actorBiographyPresentationRequestID == requestID else { return .none }
                state.actorBiographyPresentationRequestID = nil
                state.selectedActor = nil
                state.selectedActorDetails = nil
                state.isLoadingActorDetails = false
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

            case let .selectVersion(version):
                guard !state.isConfirmingDownloadDeletion, !state.isStartingDownload, !state.isDeletingDownload else { return .none }
                state.selectedVersionId = version.id
                let profileScope = profileContextClient.snapshot()
                if state.presentationProfileScope != profileScope {
                    state.presentationOverrides = [:]
                    state.matchingRequestID = nil
                    state.catalogVODs = state.catalogVODs.map { $0.replacingPresentationOverride(nil) }
                    state.matchedVODsByTMDBId = state.matchedVODsByTMDBId.mapValues { $0.replacingPresentationOverride(nil) }
                    let selectedVersionID = version.id
                    state.availableVersions = state.availableVersions.map { existingVersion in
                        MovieVersionEdition(
                            item: existingVersion.item.replacingPresentationOverride(nil),
                            isCurrent: existingVersion.id == selectedVersionID
                        )
                    }
                }
                state.presentationProfileScope = profileScope
                state.vod = version.item.replacingPresentationOverride(
                    state.isPresentationOverrideLoaded ? state.presentationOverrides[version.id] : nil
                )
                state.isPresentationOverrideLoaded = false
                let presentationRequestID = UUID()
                state.presentationOverrideRequestID = presentationRequestID
                state.historyItem = nil
                state.isDownloaded = false
                let downloadStatusRequestID = UUID()
                state.downloadStatusRequestID = downloadStatusRequestID
                state.availableVersions = state.availableVersions.map {
                    MovieVersionEdition(item: $0.item, isCurrent: $0.id == version.id)
                }
                let playlistID = state.config.playlistID
                let historyEffect: Effect<Action> = .run { [id = version.id] send in
                    let history = try? await databaseClient.getWatchProgress(id, "vod", playlistID, profileScope)
                    await send(.historyStatusLoaded(id: id, item: history, scope: profileScope))
                }
                .cancellable(id: CancelID.versionHistory, cancelInFlight: true)
                let downloadID = version.item.id
                let downloadStatusEffect: Effect<Action> = .run { send in
                    let isDownloaded = await (try? downloadClient.isDownloaded(downloadID)) ?? false
                    await send(.downloadStatusLoaded(
                        requestID: downloadStatusRequestID,
                        id: downloadID,
                        isDownloaded: isDownloaded
                    ))
                }
                let presentationOverrideEffect: Effect<Action> = if let playlistID {
                    .run { send in
                        let overrides = await mediaPresentationOverrideClient.load(profileScope.profileID, playlistID, .movie)
                        guard profileContextClient.snapshot() == profileScope else { return }
                        await send(.presentationOverridesLoaded(
                            requestID: presentationRequestID,
                            profileScope: profileScope,
                            overrides: overrides
                        ))
                    }
                } else {
                    .none
                }
                return .merge(historyEffect, downloadStatusEffect, presentationOverrideEffect)

            case let .similarMovieTapped(movie):
                if let matched = state.matchedVODsByTMDBId[movie.id] {
                    return .send(.delegate(.didSelectVOD(matched)))
                } else {
                    guard state.unmatchedMoviePresentationRequestID == nil else { return .none }
                    let requestID = UUID()
                    state.unmatchedMoviePresentationRequestID = requestID
                    state.selectedUnmatchedMovie = movie
                    return .send(.delegate(.presentUnmatchedMovie(requestID: requestID)))
                }

            case let .coordinatorDismissUnmatchedMovie(requestID):
                guard state.unmatchedMoviePresentationRequestID == requestID else { return .none }
                state.unmatchedMoviePresentationRequestID = nil
                state.selectedUnmatchedMovie = nil
                return .none

            case .playTapped:
                let streamURL: URL? = {
                    if let url = state.vod.streamURL {
                        return url
                    }
                    if let serverURL = state.config.serverURL, let username = state.config.username, let password = state.config.password {
                        return serverURL.appendingPathComponent("movie/\(username)/\(password)/\(state.vod.id).mp4")
                    }
                    return nil
                }()
                guard let finalStreamURL = streamURL else { return .none }
                let playable = PlayerFeature.PlayableItem(
                    id: state.vod.id,
                    title: state.vod.title,
                    streamURL: finalStreamURL,
                    coverURL: state.tmdbMovie?.posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w342\($0)") } ?? state.vod.coverURL,
                    startPosition: 0.0,
                    config: state.config
                )
                return .send(.delegate(.didSelectPlay(playable)))

            case .restartTapped:
                return .send(.playTapped)

            case .resumeTapped:
                let streamURL: URL? = {
                    if let url = state.vod.streamURL {
                        return url
                    }
                    if let history = state.historyItem, let s = history.streamURL, let u = URL(string: s) {
                        return u
                    }
                    if let serverURL = state.config.serverURL, let username = state.config.username, let password = state.config.password {
                        return serverURL.appendingPathComponent("movie/\(username)/\(password)/\(state.vod.id).mp4")
                    }
                    return nil
                }()
                guard let finalStreamURL = streamURL, let history = state.historyItem, history.duration > 0 else {
                    return .send(.playTapped)
                }
                let startPosition = history.progress / history.duration
                let playable = PlayerFeature.PlayableItem(
                    id: state.vod.id,
                    title: state.vod.title,
                    streamURL: finalStreamURL,
                    coverURL: state.tmdbMovie?.posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w342\($0)") } ?? state.vod.coverURL,
                    startPosition: startPosition,
                    initialDuration: history.duration,
                    initialProgress: history.progress,
                    config: state.config
                )
                return .send(.delegate(.didSelectPlay(playable)))

            case let .historyStatusLoaded(id, history, scope):
                guard state.vod.id == id, profileContextClient.snapshot() == scope else { return .none }
                state.historyItem = history
                return .none

            case .markUnwatched:
                guard
                    let history = state.historyItem,
                    history.duration > 0,
                    history.progress / history.duration >= 0.90
                else { return .none }
                state.historyItem = nil
                let profileScope = profileContextClient.snapshot()
                let playlistID = state.config.playlistID
                return .run { [id = history.id] _ in
                    try? await databaseClient.deleteWatchProgress(id, "vod", playlistID, profileScope)
                }

            case let .favoriteStatusLoaded(isFav, scope):
                guard profileContextClient.snapshot() == scope else { return .none }
                state.isFavorite = isFav
                return .none

            case let .downloadStatusLoaded(requestID, id, isDown):
                guard state.downloadStatusRequestID == requestID, state.vod.id == id else { return .none }
                state.isDownloaded = isDown
                return .none

            case let .downloadStartFinished(requestID, id, isDownloaded, errorMessage):
                guard state.downloadStatusRequestID == requestID, state.vod.id == id else { return .none }
                state.isStartingDownload = false
                if let errorMessage {
                    state.downloadErrorMessage = errorMessage
                } else {
                    state.isDownloaded = isDownloaded
                }
                return .none

            case .downloadTapped:
                guard state.config.type != .plex, state.config.type != .emby,
                      !state.isStartingDownload, !state.isDeletingDownload
                else { return .none }
                state.downloadErrorMessage = nil
                if state.isDownloaded {
                    state.isConfirmingDownloadDeletion = true
                    return .none
                } else {
                    guard let streamURL = state.vod.streamURL else { return .none }
                    let id = state.vod.id
                    let title = state.vod.title
                    let userAgentOverride = state.config.userAgentOverride
                    let downloadStatusRequestID = UUID()
                    state.downloadStatusRequestID = downloadStatusRequestID
                    state.isStartingDownload = true

                    let finalCoverURL: URL? = {
                        if let posterPath = state.tmdbMovie?.posterPath {
                            return URL(string: "https://image.tmdb.org/t/p/w342\(posterPath)")
                        } else if let url = state.vod.coverURL {
                            return url
                        }
                        return nil
                    }()

                    return .run { send in
                        do {
                            try await downloadClient.startDownload(id, title, streamURL, finalCoverURL, userAgentOverride, nil)
                            let isDownloaded = await (try? downloadClient.isDownloaded(id)) ?? false
                            await send(.downloadStartFinished(
                                requestID: downloadStatusRequestID,
                                id: id,
                                isDownloaded: isDownloaded,
                                errorMessage: nil
                            ))
                        } catch {
                            await send(.downloadStartFinished(
                                requestID: downloadStatusRequestID,
                                id: id,
                                isDownloaded: false,
                                errorMessage: error.localizedDescription
                            ))
                        }
                    }
                }

            case .cancelDownloadDeletion, .downloadDeletionDialogDismissed:
                state.isConfirmingDownloadDeletion = false
                return .none

            case .confirmDownloadDeletion:
                guard state.isDownloaded, !state.isStartingDownload, !state.isDeletingDownload else { return .none }
                state.isConfirmingDownloadDeletion = false
                state.isDeletingDownload = true
                state.downloadStatusRequestID = nil
                let requestID = UUID()
                let id = state.vod.id
                state.downloadDeletionRequestID = requestID
                return .run { send in
                    do {
                        try await downloadClient.deleteDownloadedMedia(id)
                        await send(.downloadDeletionFinished(requestID: requestID, id: id, succeeded: true))
                    } catch {
                        await send(.downloadDeletionFinished(requestID: requestID, id: id, succeeded: false))
                    }
                }

            case let .downloadDeletionFinished(requestID, id, succeeded):
                guard state.downloadDeletionRequestID == requestID, state.vod.id == id else { return .none }
                state.downloadDeletionRequestID = nil
                state.isDeletingDownload = false
                if succeeded {
                    state.isDownloaded = false
                } else {
                    state.downloadErrorMessage = AppStrings.Downloads.deleteDownloadFailure
                }
                return .none

            case .toggleFavorite:
                let profileScope = profileContextClient.snapshot()
                let item = FavoriteItem(
                    id: state.vod.id,
                    type: "vod",
                    title: state.vod.title,
                    coverURL: state.tmdbMovie?.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" } ?? state.vod.coverURL?.absoluteString,
                    streamURL: state.vod.streamURL?.absoluteString,
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
                    .cancel(id: CancelID.versionHistory),
                    .cancel(id: CancelID.awardRecognitions),
                    .cancel(id: CancelID.watchAvailability),
                    .send(.delegate(.close))
                )

            case .viewDidDisappear:
                state.isConfirmingDownloadDeletion = false
                state.watchAvailabilityRequestID = nil
                state.isWatchAvailabilityLoading = false
                return .merge(
                    .cancel(id: CancelID.versionHistory),
                    .cancel(id: CancelID.awardRecognitions),
                    .cancel(id: CancelID.watchAvailability)
                )

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
}
