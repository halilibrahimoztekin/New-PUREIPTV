import ComposableArchitecture
import Factory
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
        case tmdbTimeout
        case delegate(Delegate)
        case closeTapped

        public enum Delegate: Equatable {
            case didSelectPlay(PlayerFeature.PlayableItem)
            case close
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Injected(\.tmdbClient) var tmdbClient
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

                return .run { send in
                    await send(.infoResponse(
                        Result { try await iptvClient.fetchVODInfo(config, vodID) }
                    ))
                }

            case let .infoResponse(.success(dto)):
                state.info = dto
                state.isLoading = false // Main UI ready

                let timeoutEffect: Effect<Action> = .run { send in
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    await send(.tmdbTimeout)
                }

                // Fetch TMDB Info by searching title
                let searchTitle = state.vod.title.cleanedForTMDBSearch()
                print("TMDB search fallback for VOD: \(state.vod.title) -> cleaned: \(searchTitle)")

                let tmdbEffect: Effect<Action> = .run { send in
                    await send(.tmdbSearchResponse(
                        Result { try await tmdbClient.searchMovie(searchTitle) }
                    ))
                }

                return .merge(tmdbEffect, timeoutEffect)

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
                    state.isTMDBLoading = false // No TMDB result, we stop loading
                    return .none
                }

            case let .tmdbDetailsResponse(.success(movieDetails)):
                print("TMDB details fetched for VOD: \(movieDetails.title ?? "")")
                state.isTMDBLoading = false
                state.tmdbMovie = movieDetails
                return .none

            case let .tmdbSearchResponse(.failure(error)):
                print("TMDB search failed: \(error.localizedDescription)")
                state.isTMDBLoading = false
                return .none // Fail silently for tmdb search

            case let .tmdbDetailsResponse(.failure(error)):
                print("TMDB fetch details failed: \(error.localizedDescription)")
                state.isTMDBLoading = false
                return .none // Fail silently for tmdb details

            case .tmdbTimeout:
                print("TMDB loading timed out after 4 seconds")
                state.isTMDBLoading = false
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
                    streamURL: streamURL
                )
                return .send(.delegate(.didSelectPlay(playable)))

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
