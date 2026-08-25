import ComposableArchitecture
import Factory
import Foundation
import OSLog
import XCoordinator

// MARK: - SeriesDetailFeature

@Reducer
public struct SeriesDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public let series: MediaModels.Item
        public let serverURL: String
        public let username: String
        public let password: String

        // API Data
        public var info: DetailModels.Info?
        public var seasons: [DetailModels.Season] = []
        public var allEpisodes: [String: [DetailModels.Episode]] = [:] // Keyed by season number string
        public var tmdbTV: TMDBTVDetailsDTO?

        // UI State
        public var selectedSeasonNumber: Int?
        public var isLoading = false
        public var isTMDBLoading = false
        public var errorMessage: String?

        /// Computed
        public var currentEpisodes: [DetailModels.Episode] {
            guard let seasonNum = selectedSeasonNumber else { return [] }
            return allEpisodes[String(seasonNum)] ?? []
        }

        public init(series: MediaModels.Item, serverURL: String, username: String, password: String) {
            self.series = series
            self.serverURL = serverURL
            self.username = username
            self.password = password
        }
    }

    public enum Action {
        case onAppear
        case infoResponse(Result<(info: DetailModels.Info, seasons: [DetailModels.Season], episodes: [DetailModels.Episode]), Error>)
        case tmdbSearchResponse(Result<TMDBSearchResponseDTO, Error>)
        case tmdbDetailsResponse(Result<TMDBTVDetailsDTO, Error>)
        case seasonSelected(Int)
        case episodeSelected(DetailModels.Episode)
        case tmdbTimeout
        case delegate(Delegate)
        case closeTapped

        public enum Delegate: Equatable {
            case didSelectEpisode(PlayerFeature.PlayableItem)
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
                guard !state.isLoading, state.seasons.isEmpty else { return .none }
                state.isLoading = true
                state.isTMDBLoading = true
                state.errorMessage = nil

                guard let url = URL(string: state.serverURL) else { return .none }
                let config = PlaylistConfig(type: .xtream, serverURL: url, username: state.username, password: state.password)
                let seriesID = state.series.id

                return .run { send in
                    await send(.infoResponse(
                        Result { try await iptvClient.fetchSeriesInfo(config, seriesID) }
                    ))
                }

            case let .infoResponse(.success(result)):
                state.info = result.info
                state.seasons = result.seasons

                var parsedEpisodes: [String: [DetailModels.Episode]] = [:]
                for ep in result.episodes {
                    let seasonStr = String(ep.season)
                    parsedEpisodes[seasonStr, default: []].append(ep)
                }

                // Sort episodes
                for (key, eps) in parsedEpisodes {
                    parsedEpisodes[key] = eps.sorted { $0.episodeNum < $1.episodeNum }
                }
                state.allEpisodes = parsedEpisodes

                state.isLoading = false // Show episodes immediately

                // Fetch TMDB Info
                let searchTitle = state.series.title.cleanedForTMDBSearch()
                print("TMDB search fallback for Series: \(state.series.title) -> cleaned: \(searchTitle)")

                let tmdbEffect: Effect<Action> = .run { send in
                    await send(.tmdbSearchResponse(
                        Result { try await tmdbClient.searchTV(searchTitle) }
                    ))
                }

                let timeoutEffect: Effect<Action> = .run { send in
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    await send(.tmdbTimeout)
                }

                // Auto-select first season
                if let firstSeason = state.seasons.first {
                    state.selectedSeasonNumber = firstSeason.seasonNumber
                } else if let firstKey = state.allEpisodes.keys.sorted(by: { Int($0) ?? 0 < Int($1) ?? 0 }).first {
                    state.selectedSeasonNumber = Int(firstKey)
                }

                return .merge(tmdbEffect, timeoutEffect)

            case let .tmdbSearchResponse(.success(response)):
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
                    return .none
                }

            case let .tmdbDetailsResponse(.success(tvDetails)):
                print("TMDB details fetched for TV: \(tvDetails.name ?? "")")
                state.isTMDBLoading = false
                state.tmdbTV = tvDetails
                return .none

            case let .tmdbSearchResponse(.failure(error)):
                print("TMDB search failed for TV: \(error.localizedDescription)")
                state.isTMDBLoading = false
                return .none

            case let .tmdbDetailsResponse(.failure(error)):
                print("TMDB fetch details failed for TV: \(error.localizedDescription)")
                state.isTMDBLoading = false
                return .none

            case .tmdbTimeout:
                print("TMDB loading timed out after 4 seconds")
                state.isTMDBLoading = false
                return .none

            case let .infoResponse(.failure(error)):
                state.isLoading = false
                state.isTMDBLoading = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .seasonSelected(seasonNum):
                state.selectedSeasonNumber = seasonNum
                return .none

            case let .episodeSelected(episode):
                let streamURL = episode.streamURL
                let playable = PlayerFeature.PlayableItem(
                    id: episode.id,
                    title: "\(state.series.title) - S\(String(format: "%02d", episode.season))E\(String(format: "%02d", episode.episodeNum))",
                    streamURL: streamURL
                )
                return .send(.delegate(.didSelectEpisode(playable)))

            case .closeTapped:
                return .run { send in
                    await MainActor.run {
                        appCoordinator.trigger(.dismissSeriesDetail)
                    }
                    await send(.delegate(.close))
                }

            case .delegate:
                return .none
            }
        }
    }
}
