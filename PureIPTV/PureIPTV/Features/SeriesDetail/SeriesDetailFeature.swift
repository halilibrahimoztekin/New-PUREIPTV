import ComposableArchitecture
import FactoryKit
import Foundation
import OSLog
import XCoordinator

// MARK: - SeriesDetailFeature

@Reducer
public struct SeriesDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public let series: MediaModels.Item
        public let config: PlaylistConfig

        // API Data
        public var info: DetailModels.Info?
        public var seasons: [DetailModels.Season] = []
        public var allEpisodes: [String: [DetailModels.Episode]] = [:] // Keyed by season number string
        public var tmdbTV: TMDBTVDetailsDTO?

        public var selectedSeasonNumber: Int?
        public var isLoading = false
        public var isTMDBLoading = false
        public var isFavorite = false
        public var downloadedEpisodes: [String: Bool] = [:]
        public var historyItem: WatchHistoryItem?
        public var errorMessage: String?

        public var autoPlayOnLoad: Bool = false

        /// Computed
        public var currentEpisodes: [DetailModels.Episode] {
            guard let seasonNum = selectedSeasonNumber else { return [] }
            return allEpisodes[String(seasonNum)] ?? []
        }

        public init(series: MediaModels.Item, config: PlaylistConfig, historyItem: WatchHistoryItem? = nil, autoPlayOnLoad: Bool = false) {
            self.series = series
            self.config = config
            self.historyItem = historyItem
            self.autoPlayOnLoad = autoPlayOnLoad
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
        case toggleFavorite
        case favoriteStatusLoaded(Bool)
        case downloadedEpisodesLoaded([String: Bool])
        case downloadEpisode(DetailModels.Episode)
        case historyStatusLoaded(WatchHistoryItem?)
        case resumeTapped
        case delegate(Delegate)
        case closeTapped
        case viewDidDisappear

        public enum Delegate: Equatable {
            case didSelectEpisode(PlayerFeature.PlayableItem)
            case close
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Injected(\.tmdbClient) var tmdbClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.downloadClient) var downloadClient
    @Injected(\.appCoordinator) var appCoordinator
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let tmdbClient = tmdbClient
        let appCoordinator = appCoordinator

        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading, state.seasons.isEmpty else { return .none }
                state.isLoading = true
                state.isTMDBLoading = true
                state.errorMessage = nil

                let config = state.config
                let seriesID = state.series.id
                let searchTitle = state.series.title.cleanedForTMDBSearch()

                print("Fetching Series Info and TMDB details for: \(searchTitle)")

                let infoEffect: Effect<Action> = .run { send in
                    await send(.infoResponse(
                        Result { try await iptvClient.fetchSeriesInfo(config, seriesID) }
                    ))
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
                    let isFav = await (try? databaseClient.isFavorite(id)) ?? false
                    await send(.favoriteStatusLoaded(isFav))
                }

                let historyEffect: Effect<Action> = .run { [id = state.series.id] send in
                    let history = try? await databaseClient.getSeriesWatchProgress(id)
                    await send(.historyStatusLoaded(history))
                }

                let downloadEffect: Effect<Action> = .run { send in
                    let downloaded = await (try? downloadClient.getDownloadedMedia()) ?? []
                    let dict = Dictionary(uniqueKeysWithValues: downloaded.map { ($0.id, true) })
                    await send(.downloadedEpisodesLoaded(dict))
                }

                return .merge(infoEffect, tmdbEffect, timeoutEffect, favoriteEffect, historyEffect, downloadEffect)

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

                // Auto-select first season
                if let firstSeason = state.seasons.first {
                    state.selectedSeasonNumber = firstSeason.seasonNumber
                } else if let firstKey = state.allEpisodes.keys.sorted(by: { Int($0) ?? 0 < Int($1) ?? 0 }).first {
                    state.selectedSeasonNumber = Int(firstKey)
                }

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
                print("TMDB details fetched for TV: \(tvDetails.name ?? "")")
                state.isTMDBLoading = false
                state.tmdbTV = tvDetails
                if !state.seasons.isEmpty {
                    state.isLoading = false
                }
                return .none

            case let .tmdbSearchResponse(.failure(error)):
                print("TMDB search failed for TV: \(error.localizedDescription)")
                state.isTMDBLoading = false
                if !state.seasons.isEmpty {
                    state.isLoading = false
                }
                return .none

            case let .tmdbDetailsResponse(.failure(error)):
                print("TMDB fetch details failed for TV: \(error.localizedDescription)")
                state.isTMDBLoading = false
                if !state.seasons.isEmpty {
                    state.isLoading = false
                }
                return .none

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
                return .none

            case let .episodeSelected(episode):
                let streamURL = episode.streamURL
                let playable = PlayerFeature.PlayableItem(
                    id: episode.id,
                    title: "\(state.series.title) - S\(String(format: "%02d", episode.season))E\(String(format: "%02d", episode.episodeNum))",
                    streamURL: streamURL,
                    coverURL: episode.coverURL ?? state.series.coverURL,
                    seriesID: state.series.id
                )
                return .send(.delegate(.didSelectEpisode(playable)))

            case .resumeTapped:
                guard let history = state.historyItem, let streamString = history.streamURL, let streamURL = URL(string: streamString), history.duration > 0 else { return .none }
                let startPosition = history.progress / history.duration
                let playable = PlayerFeature.PlayableItem(
                    id: history.id,
                    title: history.title,
                    streamURL: streamURL,
                    coverURL: history.coverURL.flatMap { URL(string: $0) } ?? state.series.coverURL,
                    seriesID: state.series.id,
                    startPosition: startPosition
                )
                return .send(.delegate(.didSelectEpisode(playable)))

            case let .historyStatusLoaded(history):
                state.historyItem = history
                return .none

            case let .favoriteStatusLoaded(isFav):
                state.isFavorite = isFav
                return .none

            case let .downloadedEpisodesLoaded(dict):
                state.downloadedEpisodes = dict
                return .none

            case let .downloadEpisode(episode):
                if state.downloadedEpisodes[episode.id] == true {
                    return .run { send in
                        try? await downloadClient.deleteDownloadedMedia(episode.id)
                        let downloaded = await (try? downloadClient.getDownloadedMedia()) ?? []
                        let dict = Dictionary(uniqueKeysWithValues: downloaded.map { ($0.id, true) })
                        await send(.downloadedEpisodesLoaded(dict))
                    }
                } else {
                    let streamURL = episode.streamURL

                    let id = episode.id
                    let title = "\(state.series.title) - S\(episode.season)E\(episode.episodeNum): \(episode.title)"

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

                    return .run { send in
                        try? await downloadClient.startDownload(id, title, streamURL, finalCoverURL)
                        let downloaded = await (try? downloadClient.getDownloadedMedia()) ?? []
                        let dict = Dictionary(uniqueKeysWithValues: downloaded.map { ($0.id, true) })
                        await send(.downloadedEpisodesLoaded(dict))
                    }
                }

            case .toggleFavorite:
                let item = FavoriteItem(
                    id: state.series.id,
                    type: "series",
                    title: state.series.title,
                    coverURL: state.tmdbTV?.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" } ?? state.series.coverURL?.absoluteString,
                    streamURL: nil
                )
                return .run { send in
                    let isNowFav = await (try? databaseClient.toggleFavorite(item)) ?? false
                    await send(.favoriteStatusLoaded(isNowFav))
                }

            case .closeTapped:
                return .send(.delegate(.close))

            case .viewDidDisappear:
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
