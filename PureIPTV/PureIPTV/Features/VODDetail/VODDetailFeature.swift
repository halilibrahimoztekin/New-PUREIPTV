import ComposableArchitecture
import FactoryKit
import Foundation
import OSLog
import XCoordinator

@Reducer
public struct VODDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public let vod: MediaModels.Item
        public let serverURL: String
        public let username: String
        public let password: String

        // API Data
        public var info: DetailModels.Info?
        public var tmdbMovie: TMDBMovieDetailsDTO?

        // UI State
        public var isLoading = false
        public var isTMDBLoading = false
        public var isFavorite = false
        public var historyItem: WatchHistoryItem?
        public var errorMessage: String?

        public init(vod: MediaModels.Item, serverURL: String, username: String, password: String) {
            self.vod = vod
            self.serverURL = serverURL
            self.username = username
            self.password = password
        }
    }

    public enum Action {
        case onAppear
        case infoResponse(Result<DetailModels.Info, Error>)
        case tmdbSearchResponse(Result<TMDBSearchResponseDTO, Error>)
        case tmdbDetailsResponse(Result<TMDBMovieDetailsDTO, Error>)
        case playTapped
        case resumeTapped
        case tmdbTimeout
        case toggleFavorite
        case favoriteStatusLoaded(Bool)
        case historyStatusLoaded(WatchHistoryItem?)
        case delegate(Delegate)
        case closeTapped

        public enum Delegate: Equatable {
            case didSelectPlay(PlayerFeature.PlayableItem)
            case close
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Injected(\.tmdbClient) var tmdbClient
    @Dependency(\.databaseClient) var databaseClient
    @Injected(\.appCoordinator) var appCoordinator

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = self.iptvClient
        let tmdbClient = self.tmdbClient
        let appCoordinator = self.appCoordinator

        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading, state.info == nil else { return .none }
                state.isLoading = true
                state.isTMDBLoading = true
                state.errorMessage = nil

                guard let url = URL(string: state.serverURL) else { return .none }
                let config = PlaylistConfig(type: .xtream, serverURL: url, username: state.username, password: state.password)
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
                    let isFav = (try? await databaseClient.isFavorite(id)) ?? false
                    await send(.favoriteStatusLoaded(isFav))
                }

                let historyEffect: Effect<Action> = .run { [id = state.vod.id] send in
                    let history = try? await databaseClient.getWatchProgress(id)
                    await send(.historyStatusLoaded(history))
                }

                return .merge(infoEffect, tmdbEffect, timeoutEffect, favoriteEffect, historyEffect)

            case let .infoResponse(.success(dto)):
                state.info = dto
                if !state.isTMDBLoading {
                    state.isLoading = false
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

            case .playTapped:
                guard let streamURL = state.vod.streamURL else { return .none }
                let playable = PlayerFeature.PlayableItem(
                    id: state.vod.id,
                    title: state.vod.title,
                    streamURL: streamURL,
                    coverURL: state.tmdbMovie?.posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w342\($0)") } ?? state.vod.coverURL
                )
                return .send(.delegate(.didSelectPlay(playable)))

            case .resumeTapped:
                guard let streamURL = state.vod.streamURL, let history = state.historyItem, history.duration > 0 else { return .none }
                let startPosition = history.progress / history.duration
                let playable = PlayerFeature.PlayableItem(
                    id: state.vod.id,
                    title: state.vod.title,
                    streamURL: streamURL,
                    coverURL: state.tmdbMovie?.posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w342\($0)") } ?? state.vod.coverURL,
                    startPosition: startPosition
                )
                return .send(.delegate(.didSelectPlay(playable)))

            case let .historyStatusLoaded(history):
                state.historyItem = history
                return .none

            case let .favoriteStatusLoaded(isFav):
                state.isFavorite = isFav
                return .none

            case .toggleFavorite:
                let item = FavoriteItem(
                    id: state.vod.id,
                    type: "vod",
                    title: state.vod.title,
                    coverURL: state.tmdbMovie?.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" } ?? state.vod.coverURL?.absoluteString,
                    streamURL: state.vod.streamURL?.absoluteString
                )
                return .run { send in
                    let isNowFav = (try? await databaseClient.toggleFavorite(item)) ?? false
                    await send(.favoriteStatusLoaded(isNowFav))
                }

            case .closeTapped:
                return .run { send in
                    await MainActor.run {
                        appCoordinator.trigger(.dismissVodDetail)
                    }
                    await send(.delegate(.close))
                }

            case .delegate:
                return .none
            }
        }
    }
}
