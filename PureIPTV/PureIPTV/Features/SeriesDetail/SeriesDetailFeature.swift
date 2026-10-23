import ComposableArchitecture
import FactoryKit
import Foundation
import OSLog

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
        public var nextUpEpisode: DetailModels.Episode?
        public var tmdbTV: TMDBTVDetailsDTO?

        public var selectedSeasonNumber: Int?
        public var isLoading = false
        public var isTMDBLoading = false
        public var isFavorite = false
        public var downloadedEpisodes: [String: Bool] = [:]
        public var historyItem: WatchHistoryItem?
        public var episodeProgressMap: [String: WatchHistoryItem] = [:]
        public var episodeLayoutMode: EpisodeLayoutMode = .list
        public var errorMessage: String?

        public var autoPlayOnLoad: Bool = false
        public var isTrailerPresented: Bool = false
        public var trailerVideoKey: String?
        public var trailerTitle: String?

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

        public var sequentialPlaylistEpisodes: [DetailModels.Episode] {
            let all = allEpisodes.values.flatMap(\.self).sorted {
                if $0.season != $1.season {
                    return $0.season < $1.season
                }
                return $0.episodeNum < $1.episodeNum
            }
            return all.isEmpty ? currentEpisodes : all
        }

        public mutating func updateNextUpEpisode() {
            let allEps = allEpisodes.values.flatMap(\.self).sorted {
                if $0.season != $1.season {
                    return $0.season < $1.season
                }
                return $0.episodeNum < $1.episodeNum
            }
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

    public enum Action {
        case onAppear
        case infoResponse(Result<(info: DetailModels.Info, seasons: [DetailModels.Season], allEpisodes: [String: [DetailModels.Episode]]), Error>)
        case tmdbSearchResponse(Result<TMDBSearchResponseDTO, Error>)
        case tmdbDetailsResponse(Result<TMDBTVDetailsDTO, Error>)
        case seasonSelected(Int)
        case episodeSelected(DetailModels.Episode)
        case toggleLayoutMode
        case playNextEpisodeTapped
        case tmdbTimeout
        case toggleFavorite
        case favoriteStatusLoaded(Bool)
        case downloadedEpisodesLoaded([String: Bool])
        case episodeProgressLoaded([WatchHistoryItem])
        case markEpisodeUnwatched(String)
        case downloadEpisode(DetailModels.Episode)
        case historyStatusLoaded(WatchHistoryItem?)
        case resumeTapped
        case restartTapped
        case trailerTapped
        case dismissTrailer
        case delegate(Delegate)
        case closeTapped
        case viewDidDisappear

        public enum Delegate: Equatable {
            case didSelectEpisode(PlayerFeature.PlayableItem, playlist: [PlayerFeature.PlayableItem]?)
            case close
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Injected(\.tmdbClient) var tmdbClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.downloadClient) var downloadClient
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let tmdbClient = tmdbClient

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
                    do {
                        let result = try await iptvClient.fetchSeriesInfo(config, seriesID)
                        var parsed: [String: [DetailModels.Episode]] = [:]
                        for ep in result.episodes {
                            let seasonStr = String(ep.season)
                            parsed[seasonStr, default: []].append(ep)
                        }
                        for (key, eps) in parsed {
                            parsed[key] = eps.sorted { $0.episodeNum < $1.episodeNum }
                        }
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

                let episodesHistoryEffect: Effect<Action> = .run { [id = state.series.id] send in
                    let items = await (try? databaseClient.fetchSeriesEpisodesWatchHistory(id)) ?? []
                    await send(.episodeProgressLoaded(items))
                }

                return .merge(infoEffect, tmdbEffect, timeoutEffect, favoriteEffect, historyEffect, downloadEffect, episodesHistoryEffect)

            case let .infoResponse(.success(result)):
                state.info = result.info
                state.seasons = result.seasons
                state.allEpisodes = result.allEpisodes

                // Auto-select first season
                if let firstSeason = state.seasons.first {
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
                state.updateNextUpEpisode()
                return .none

            case .toggleLayoutMode:
                state.episodeLayoutMode = state.episodeLayoutMode == .list ? .grid : .list
                return .none

            case .playNextEpisodeTapped:
                if let nextEp = state.nextUpEpisode {
                    return .send(.episodeSelected(nextEp))
                }
                return .none

            case let .episodeProgressLoaded(items):
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
                return .run { _ in
                    try? await databaseClient.deleteWatchProgress(id)
                }

            case let .episodeSelected(episode):
                // Ensure selectedSeasonNumber matches the played episode's season
                if state.selectedSeasonNumber != episode.season {
                    state.selectedSeasonNumber = episode.season
                }

                let streamURL = episode.streamURL
                let history = state.episodeProgressMap[episode.id]
                let startPosition: Double? = if let h = history, h.duration > 0 {
                    (h.progress / h.duration) < 0.92 ? (h.progress / h.duration) : 0.0
                } else {
                    nil
                }
                let initialProgress: Double? = if let h = history, h.duration > 0, (h.progress / h.duration) < 0.92 {
                    h.progress
                } else {
                    nil
                }

                let playable = PlayerFeature.PlayableItem(
                    id: episode.id,
                    title: "\(state.series.title) - S\(String(format: "%02d", episode.season))E\(String(format: "%02d", episode.episodeNum))",
                    seriesTitle: state.series.title,
                    streamURL: streamURL,
                    coverURL: episode.coverURL ?? state.series.coverURL,
                    seriesID: state.series.id,
                    startPosition: startPosition,
                    initialDuration: history?.duration,
                    initialProgress: initialProgress
                )
                let playlistEpisodes = state.sequentialPlaylistEpisodes
                let playlist = playlistEpisodes.isEmpty ? nil : playlistEpisodes.map { ep in
                    PlayerFeature.PlayableItem(
                        id: ep.id,
                        title: "\(state.series.title) - S\(String(format: "%02d", ep.season))E\(String(format: "%02d", ep.episodeNum))",
                        seriesTitle: state.series.title,
                        streamURL: ep.streamURL,
                        coverURL: ep.coverURL ?? state.series.coverURL,
                        seriesID: state.series.id
                    )
                }
                return .send(.delegate(.didSelectEpisode(playable, playlist: playlist)))

            case .resumeTapped:
                guard let history = state.historyItem, let streamString = history.streamURL, let streamURL = URL(string: streamString) else {
                    return .send(.restartTapped)
                }

                // Locate episode in allEpisodes to resolve accurate season
                let allEpsList = state.allEpisodes.values.flatMap(\.self)
                let matchingEpisode = allEpsList.first(where: { $0.id == history.id })
                if let ep = matchingEpisode, state.selectedSeasonNumber != ep.season {
                    state.selectedSeasonNumber = ep.season
                }

                let startPosition = history.duration > 0 ? (history.progress / history.duration) : 0.0
                let playable = PlayerFeature.PlayableItem(
                    id: history.id,
                    title: history.title,
                    seriesTitle: state.series.title,
                    streamURL: streamURL,
                    coverURL: history.coverURL.flatMap { URL(string: $0) } ?? state.series.coverURL,
                    seriesID: state.series.id,
                    startPosition: startPosition,
                    initialDuration: history.duration > 0 ? history.duration : nil,
                    initialProgress: history.progress > 0 ? history.progress : nil
                )
                let resumeEpisodes = state.sequentialPlaylistEpisodes
                let playlist = resumeEpisodes.isEmpty ? nil : resumeEpisodes.map { ep in
                    PlayerFeature.PlayableItem(
                        id: ep.id,
                        title: "\(state.series.title) - S\(String(format: "%02d", ep.season))E\(String(format: "%02d", ep.episodeNum))",
                        seriesTitle: state.series.title,
                        streamURL: ep.streamURL,
                        coverURL: ep.coverURL ?? state.series.coverURL,
                        seriesID: state.series.id
                    )
                }
                return .send(.delegate(.didSelectEpisode(playable, playlist: playlist)))

            case .restartTapped:
                if let history = state.historyItem, let streamString = history.streamURL, let streamURL = URL(string: streamString) {
                    let allEpsList = state.allEpisodes.values.flatMap(\.self)
                    let matchingEpisode = allEpsList.first(where: { $0.id == history.id })
                    if let ep = matchingEpisode, state.selectedSeasonNumber != ep.season {
                        state.selectedSeasonNumber = ep.season
                    }

                    let playable = PlayerFeature.PlayableItem(
                        id: history.id,
                        title: history.title,
                        seriesTitle: state.series.title,
                        streamURL: streamURL,
                        coverURL: history.coverURL.flatMap { URL(string: $0) } ?? state.series.coverURL,
                        seriesID: state.series.id,
                        startPosition: 0.0
                    )
                    let restartEpisodes = state.sequentialPlaylistEpisodes
                    let playlist = restartEpisodes.isEmpty ? nil : restartEpisodes.map { ep in
                        PlayerFeature.PlayableItem(
                            id: ep.id,
                            title: "\(state.series.title) - S\(String(format: "%02d", ep.season))E\(String(format: "%02d", ep.episodeNum))",
                            seriesTitle: state.series.title,
                            streamURL: ep.streamURL,
                            coverURL: ep.coverURL ?? state.series.coverURL,
                            seriesID: state.series.id
                        )
                    }
                    return .send(.delegate(.didSelectEpisode(playable, playlist: playlist)))
                } else if let firstEp = state.currentEpisodes.first ?? state.allEpisodes.values.first?.first {
                    return .send(.episodeSelected(firstEp))
                }
                return .none

            case .trailerTapped:
                guard let key = state.resolvedTrailerKey else { return .none }
                state.trailerVideoKey = key
                state.trailerTitle = "\(state.tmdbTV?.name ?? state.series.title) - \(AppStrings.VODDetail.trailer)"
                state.isTrailerPresented = true
                return .none

            case .dismissTrailer:
                state.isTrailerPresented = false
                state.trailerVideoKey = nil
                state.trailerTitle = nil
                return .none

            case let .historyStatusLoaded(history):
                state.historyItem = history
                state.updateNextUpEpisode()
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
