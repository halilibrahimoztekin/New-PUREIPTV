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

        // UI State
        public var isLoading = false
        public var isTMDBLoading = false
        public var isFavorite = false
        public var isDownloaded = false
        public var historyItem: WatchHistoryItem?
        public var errorMessage: String?

        public var autoPlayOnLoad: Bool = false
        public var selectedActor: TMDBCastMemberDTO?
        public var selectedActorDetails: TMDBPersonDetailsDTO?
        public var isLoadingActorDetails: Bool = false
        public var isTrailerPresented: Bool = false
        public var trailerVideoKey: String?
        public var trailerTitle: String?
        public var isAutoPlayTrailerActive: Bool = false
        public var isTrailerMuted: Bool = true
        public var isAutoPlayTrailerEnabled: Bool = false

        // Multi-Version & Quality Grouping (Madde #47)
        public var availableVersions: [MovieVersionEdition] = []
        public var selectedVersionId: String?

        // Similar Movies Intelligent Matching
        public var catalogVODs: [MediaModels.Item] = []
        public var matchedVODsByTMDBId: [Int: MediaModels.Item] = [:]
        public var selectedUnmatchedMovie: TMDBSimilarItemDTO?

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

    public enum Action {
        case onAppear
        case infoResponse(Result<DetailModels.Info, Error>)
        case tmdbSearchResponse(Result<TMDBSearchResponseDTO, Error>)
        case tmdbDetailsResponse(Result<TMDBMovieDetailsDTO, Error>)
        case catalogVODsResponse(Result<[MediaModels.Item], Error>)
        case playTapped
        case resumeTapped
        case restartTapped
        case tmdbTimeout
        case toggleFavorite
        case favoriteStatusLoaded(Bool)
        case downloadStatusLoaded(Bool)
        case downloadTapped
        case historyStatusLoaded(WatchHistoryItem?)
        case markUnwatched
        case actorTapped(TMDBCastMemberDTO)
        case actorDetailsResponse(Result<TMDBPersonDetailsDTO, Error>)
        case dismissActorDetails
        case trailerTapped
        case dismissTrailer
        case startInlineTrailer
        case toggleTrailerMute
        case stopInlineTrailer
        case expandTrailer
        case selectVersion(MovieVersionEdition)
        case similarMovieTapped(TMDBSimilarItemDTO)
        case dismissUnmatchedMovie
        case backgroundMatchingCompleted(versions: [MovieVersionEdition], matched: [Int: MediaModels.Item])
        case delegate(Delegate)
        case closeTapped
        case viewDidDisappear

        public enum Delegate: Equatable {
            case didSelectPlay(PlayerFeature.PlayableItem)
            case didSelectVOD(MediaModels.Item)
            case close
        }
    }

    private nonisolated enum CancelID: Hashable, Sendable {
        case autoPlayTrailer
    }

    @Injected(\.iptvClient) var iptvClient
    @Injected(\.tmdbClient) var tmdbClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.downloadClient) var downloadClient
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
                    return itemNorm == targetNorm || (targetNorm.count >= 5 && (itemNorm.contains(targetNorm) || targetNorm.contains(itemNorm)))
                }
                if !matchingItems.contains(where: { $0.id == vod.id }) {
                    matchingItems.insert(vod, at: 0)
                }
                let currentId = selectedVersionId ?? vod.id
                let editions = matchingItems.map { MovieVersionEdition(item: $0, isCurrent: $0.id == currentId) }
                let qualityPriority: [String: Int] = [
                    "4K UHD": 4, "1080p FHD": 3, "720p HD": 2, "HD": 1, "SD": 0,
                ]
                versions = editions.sorted {
                    (qualityPriority[$0.qualityLabel] ?? 1) > (qualityPriority[$1.qualityLabel] ?? 1)
                }
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

        Reduce { state, action in
            switch action {
            case .onAppear:
                if state.availableVersions.isEmpty {
                    state.availableVersions = [MovieVersionEdition(item: state.vod, isCurrent: true)]
                    state.selectedVersionId = state.vod.id
                }
                guard !state.isLoading, state.info == nil else { return .none }
                state.isLoading = true
                state.isTMDBLoading = true
                state.errorMessage = nil

                let config = state.config
                let vodID = state.vod.id
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
                    let isFav = await (try? databaseClient.isFavorite(id)) ?? false
                    await send(.favoriteStatusLoaded(isFav))
                }

                let historyEffect: Effect<Action> = .run { [id = state.vod.id] send in
                    let history = try? await databaseClient.getWatchProgress(id)
                    await send(.historyStatusLoaded(history))
                }

                let downloadEffect: Effect<Action> = .run { [id = state.vod.id] send in
                    let isDown = await (try? downloadClient.isDownloaded(id)) ?? false
                    await send(.downloadStatusLoaded(isDown))
                }

                let catalogEffect: Effect<Action> = state.catalogVODs.isEmpty ? .run { [config = state.config] send in
                    await send(.catalogVODsResponse(
                        Result { try await iptvClient.fetchVODs(config, nil) }
                    ))
                } : .none

                let matchingEffect: Effect<Action> = state.catalogVODs.isEmpty ? .none : .run { [vod = state.vod, catalog = state.catalogVODs, similar = state.tmdbMovie?.similar?.results, versionId = state.selectedVersionId] send in
                    let res = await Self.computeMatchingInBackground(vod: vod, catalog: catalog, similar: similar, selectedVersionId: versionId)
                    await send(.backgroundMatchingCompleted(versions: res.versions, matched: res.matched))
                }

                return .merge(infoEffect, tmdbEffect, timeoutEffect, favoriteEffect, historyEffect, downloadEffect, catalogEffect, matchingEffect)

            case let .catalogVODsResponse(.success(items)):
                state.catalogVODs = items
                return .run { [vod = state.vod, catalog = items, similar = state.tmdbMovie?.similar?.results, versionId = state.selectedVersionId] send in
                    let res = await Self.computeMatchingInBackground(vod: vod, catalog: catalog, similar: similar, selectedVersionId: versionId)
                    await send(.backgroundMatchingCompleted(versions: res.versions, matched: res.matched))
                }

            case .catalogVODsResponse(.failure):
                return .none

            case let .backgroundMatchingCompleted(versions, matched):
                state.availableVersions = versions
                state.matchedVODsByTMDBId = matched
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
                print("TMDB details fetched for VOD: \(movieDetails.title ?? "")")
                state.isTMDBLoading = false
                state.tmdbMovie = movieDetails
                if state.info != nil {
                    state.isLoading = false
                }
                let matchingEffect: Effect<Action> = state.catalogVODs.isEmpty ? .none : .run { [vod = state.vod, catalog = state.catalogVODs, similar = movieDetails.similar?.results, versionId = state.selectedVersionId] send in
                    let res = await Self.computeMatchingInBackground(vod: vod, catalog: catalog, similar: similar, selectedVersionId: versionId)
                    await send(.backgroundMatchingCompleted(versions: res.versions, matched: res.matched))
                }
                var effects: [Effect<Action>] = [matchingEffect]
                if state.resolvedTrailerKey != nil, state.isAutoPlayTrailerEnabled {
                    effects.append(.run { send in
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        if !Task.isCancelled {
                            await send(.startInlineTrailer)
                        }
                    }
                    .cancellable(id: CancelID.autoPlayTrailer, cancelInFlight: true))
                }
                return .merge(effects)

            case let .tmdbSearchResponse(.failure(error)):
                print("TMDB search failed: \(error.localizedDescription)")
                state.isTMDBLoading = false
                if state.info != nil {
                    state.isLoading = false
                }
                return .none // Fail silently for tmdb search

            case let .tmdbDetailsResponse(.failure(error)):
                print("TMDB fetch details failed: \(error.localizedDescription)")
                state.isTMDBLoading = false
                if state.info != nil {
                    state.isLoading = false
                }
                return .none // Fail silently for tmdb details

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
                state.selectedActor = actor
                state.selectedActorDetails = nil
                state.isLoadingActorDetails = true
                return .run { send in
                    await send(.actorDetailsResponse(Result {
                        try await tmdbClient.fetchPersonDetails(actor.id)
                    }))
                }

            case let .actorDetailsResponse(.success(details)):
                state.isLoadingActorDetails = false
                state.selectedActorDetails = details
                return .none

            case .actorDetailsResponse(.failure):
                state.isLoadingActorDetails = false
                return .none

            case .dismissActorDetails:
                state.selectedActor = nil
                state.selectedActorDetails = nil
                state.isLoadingActorDetails = false
                return .none

            case .trailerTapped:
                state.isAutoPlayTrailerActive = false
                guard let key = state.resolvedTrailerKey else { return .none }
                state.trailerVideoKey = key
                state.trailerTitle = "\(state.tmdbMovie?.title ?? state.vod.title) - \(AppStrings.VODDetail.trailer)"
                state.isTrailerPresented = true
                return .cancel(id: CancelID.autoPlayTrailer)

            case .dismissTrailer:
                state.isTrailerPresented = false
                state.trailerVideoKey = nil
                state.trailerTitle = nil
                return .none

            case .startInlineTrailer:
                guard state.resolvedTrailerKey != nil, state.isAutoPlayTrailerEnabled else { return .none }
                state.isAutoPlayTrailerActive = true
                return .none

            case .toggleTrailerMute:
                state.isTrailerMuted.toggle()
                return .none

            case .stopInlineTrailer:
                state.isAutoPlayTrailerActive = false
                return .cancel(id: CancelID.autoPlayTrailer)

            case .expandTrailer:
                state.isAutoPlayTrailerActive = false
                return .merge(
                    .cancel(id: CancelID.autoPlayTrailer),
                    .send(.trailerTapped)
                )

            case let .selectVersion(version):
                state.selectedVersionId = version.id
                state.vod = version.item
                state.availableVersions = state.availableVersions.map {
                    MovieVersionEdition(item: $0.item, isCurrent: $0.id == version.id)
                }
                return .run { [id = version.id] send in
                    let history = try? await databaseClient.getWatchProgress(id)
                    await send(.historyStatusLoaded(history))
                }

            case let .similarMovieTapped(movie):
                if let matched = state.matchedVODsByTMDBId[movie.id] {
                    return .send(.delegate(.didSelectVOD(matched)))
                } else {
                    state.selectedUnmatchedMovie = movie
                    return .none
                }

            case .dismissUnmatchedMovie:
                state.selectedUnmatchedMovie = nil
                return .none

            case .playTapped:
                state.isAutoPlayTrailerActive = false
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
                return .merge(
                    .cancel(id: CancelID.autoPlayTrailer),
                    .send(.delegate(.didSelectPlay(playable)))
                )

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

            case let .historyStatusLoaded(history):
                state.historyItem = history
                return .none

            case .markUnwatched:
                guard
                    let history = state.historyItem,
                    history.duration > 0,
                    history.progress / history.duration >= 0.90
                else { return .none }
                state.historyItem = nil
                return .run { [id = history.id] _ in
                    try? await databaseClient.deleteWatchProgress(id)
                }

            case let .favoriteStatusLoaded(isFav):
                state.isFavorite = isFav
                return .none

            case let .downloadStatusLoaded(isDown):
                state.isDownloaded = isDown
                return .none

            case .downloadTapped:
                if state.isDownloaded {
                    return .run { [id = state.vod.id] send in
                        try? await downloadClient.deleteDownloadedMedia(id)
                        await send(.downloadStatusLoaded(false))
                    }
                } else {
                    guard let streamURL = state.vod.streamURL else { return .none }
                    let id = state.vod.id
                    let title = state.vod.title
                    let userAgentOverride = state.config.userAgentOverride

                    let finalCoverURL: URL? = {
                        if let posterPath = state.tmdbMovie?.posterPath {
                            return URL(string: "https://image.tmdb.org/t/p/w342\(posterPath)")
                        } else if let url = state.vod.coverURL {
                            return url
                        }
                        return nil
                    }()

                    return .run { send in
                        try? await downloadClient.startDownload(id, title, streamURL, finalCoverURL, userAgentOverride)
                        await send(.downloadStatusLoaded(true))
                    }
                }

            case .toggleFavorite:
                let item = FavoriteItem(
                    id: state.vod.id,
                    type: "vod",
                    title: state.vod.title,
                    coverURL: state.tmdbMovie?.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" } ?? state.vod.coverURL?.absoluteString,
                    streamURL: state.vod.streamURL?.absoluteString
                )
                return .run { send in
                    let isNowFav = await (try? databaseClient.toggleFavorite(item)) ?? false
                    await send(.favoriteStatusLoaded(isNowFav))
                }

            case .closeTapped:
                state.isAutoPlayTrailerActive = false
                return .merge(
                    .cancel(id: CancelID.autoPlayTrailer),
                    .send(.delegate(.close))
                )

            case .viewDidDisappear:
                state.isAutoPlayTrailerActive = false
                return .cancel(id: CancelID.autoPlayTrailer)

            case .delegate:
                return .none
            }
        }
    }
}
