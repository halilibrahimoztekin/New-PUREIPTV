import ComposableArchitecture
import FactoryKit
import Foundation
import OSLog
import XCoordinator

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
        public var isAutoPlayTrailerEnabled: Bool = true

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
    @Injected(\.appCoordinator) var appCoordinator
    @Dependency(\.dismiss) var dismiss

    public init() {}

    private static func normalizeTitle(_ raw: String) -> String {
        var s = raw.lowercased()
        let replacements: [(String, String)] = [
            ("ı", "i"), ("ğ", "g"), ("ü", "u"), ("ş", "s"), ("ö", "o"), ("ç", "c"),
            ("İ", "i"), ("Ğ", "g"), ("Ü", "u"), ("Ş", "s"), ("Ö", "o"), ("Ç", "c"),
        ]
        for (target, replacement) in replacements {
            s = s.replacingOccurrences(of: target, with: replacement)
        }
        let noiseTags = [
            "1080p", "720p", "2160p", "4k", "uhd", "hdr", "bluray", "blu-ray",
            "web-dl", "webdl", "webrip", "dual", "dublaj", "altyazili", "altyazılı",
            "turkce", "türkçe", "tr", "eng", "ita", "ger", "fra", "es", "multi",
        ]
        for tag in noiseTags {
            s = s.replacingOccurrences(of: "\\b\(tag)\\b", with: "", options: .regularExpression)
        }
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        s = s.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
        return s.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func updateMatchedVODs(state: inout State) {
        guard let similar = state.tmdbMovie?.similar?.results, !similar.isEmpty, !state.catalogVODs.isEmpty else {
            return
        }
        var map: [Int: MediaModels.Item] = [:]
        let catalogNormMap: [(norm: String, item: MediaModels.Item)] = state.catalogVODs.compactMap { item in
            let norm = normalizeTitle(item.title)
            return norm.isEmpty ? nil : (norm: norm, item: item)
        }

        for movie in similar {
            let primaryNorm = normalizeTitle(movie.title ?? movie.name ?? "")
            let origNorm = normalizeTitle(movie.originalTitle ?? movie.originalName ?? "")

            // 1. Exact match with primary title or original title
            if let exact = catalogNormMap.first(where: {
                (!primaryNorm.isEmpty && $0.norm == primaryNorm) ||
                    (!origNorm.isEmpty && $0.norm == origNorm)
            }) {
                map[movie.id] = exact.item
                continue
            }

            // 2. Substring match if length is meaningful (>= 4 characters)
            if primaryNorm.count >= 4 {
                if let match = catalogNormMap.first(where: { $0.norm.contains(primaryNorm) || primaryNorm.contains($0.norm) }) {
                    map[movie.id] = match.item
                    continue
                }
            }

            if origNorm.count >= 4 {
                if let match = catalogNormMap.first(where: { $0.norm.contains(origNorm) || origNorm.contains($0.norm) }) {
                    map[movie.id] = match.item
                    continue
                }
            }
        }
        state.matchedVODsByTMDBId = map
    }

    private static func discoverAvailableVersions(state: inout State) {
        guard !state.catalogVODs.isEmpty else {
            state.availableVersions = [MovieVersionEdition(item: state.vod, isCurrent: true)]
            state.selectedVersionId = state.vod.id
            return
        }

        let targetNorm = normalizeTitle(state.vod.title)
        guard !targetNorm.isEmpty else {
            state.availableVersions = [MovieVersionEdition(item: state.vod, isCurrent: true)]
            state.selectedVersionId = state.vod.id
            return
        }

        var matchingItems = state.catalogVODs.filter { item in
            let itemNorm = normalizeTitle(item.title)
            return itemNorm == targetNorm || (targetNorm.count >= 5 && (itemNorm.contains(targetNorm) || targetNorm.contains(itemNorm)))
        }

        if !matchingItems.contains(where: { $0.id == state.vod.id }) {
            matchingItems.insert(state.vod, at: 0)
        }

        let currentId = state.selectedVersionId ?? state.vod.id
        let editions = matchingItems.map { MovieVersionEdition(item: $0, isCurrent: $0.id == currentId) }

        let qualityPriority: [String: Int] = [
            "4K UHD": 4,
            "1080p FHD": 3,
            "720p HD": 2,
            "HD": 1,
            "SD": 0,
        ]

        state.availableVersions = editions.sorted {
            let p1 = qualityPriority[$0.qualityLabel] ?? 1
            let p2 = qualityPriority[$1.qualityLabel] ?? 1
            return p1 > p2
        }

        if state.selectedVersionId == nil {
            state.selectedVersionId = state.vod.id
        }
    }

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let tmdbClient = tmdbClient

        Reduce { state, action in
            switch action {
            case .onAppear:
                Self.discoverAvailableVersions(state: &state)
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

                return .merge(infoEffect, tmdbEffect, timeoutEffect, favoriteEffect, historyEffect, downloadEffect, catalogEffect)

            case let .catalogVODsResponse(.success(items)):
                state.catalogVODs = items
                Self.updateMatchedVODs(state: &state)
                Self.discoverAvailableVersions(state: &state)
                return .none

            case .catalogVODsResponse(.failure):
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
                Self.updateMatchedVODs(state: &state)
                if state.info != nil {
                    state.isLoading = false
                }
                if state.resolvedTrailerKey != nil, state.isAutoPlayTrailerEnabled {
                    return .run { send in
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        if !Task.isCancelled {
                            await send(.startInlineTrailer)
                        }
                    }
                    .cancellable(id: CancelID.autoPlayTrailer, cancelInFlight: true)
                }
                return .none

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
                    let catalog = state.catalogVODs
                    state = State(
                        vod: matched,
                        config: state.config,
                        catalogVODs: catalog
                    )
                    return .merge(
                        .send(.onAppear),
                        .send(.delegate(.didSelectVOD(matched)))
                    )
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
                    startPosition: 0.0
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
                    initialProgress: history.progress
                )
                return .send(.delegate(.didSelectPlay(playable)))

            case let .historyStatusLoaded(history):
                state.historyItem = history
                return .none

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

                    let finalCoverURL: URL? = {
                        if let posterPath = state.tmdbMovie?.posterPath {
                            return URL(string: "https://image.tmdb.org/t/p/w342\(posterPath)")
                        } else if let url = state.vod.coverURL {
                            return url
                        }
                        return nil
                    }()

                    return .run { send in
                        try? await downloadClient.startDownload(id, title, streamURL, finalCoverURL)
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
