import ComposableArchitecture
import Foundation

@DependencyClient
public struct IPTVClient {
    public var authenticate: @Sendable (_ config: PlaylistConfig) async throws -> Void
    public var fetchLiveCategories: @Sendable (_ config: PlaylistConfig) async throws -> [MediaModels.Category]
    public var fetchLiveChannels: @Sendable (_ config: PlaylistConfig, _ categoryID: String?) async throws -> [MediaModels.Item]
    public var fetchVODCategories: @Sendable (_ config: PlaylistConfig) async throws -> [MediaModels.Category]
    public var fetchVODs: @Sendable (_ config: PlaylistConfig, _ categoryID: String?) async throws -> [MediaModels.Item]
    public var fetchSeriesCategories: @Sendable (_ config: PlaylistConfig) async throws -> [MediaModels.Category]
    public var fetchSeries: @Sendable (_ config: PlaylistConfig, _ categoryID: String?) async throws -> [MediaModels.Item]
    public var fetchSeriesInfo: @Sendable (_ config: PlaylistConfig, _ seriesID: String) async throws -> (info: DetailModels.Info, seasons: [DetailModels.Season], episodes: [DetailModels.Episode])
    public var fetchVODInfo: @Sendable (_ config: PlaylistConfig, _ vodID: String) async throws -> DetailModels.Info
}

extension IPTVClient: DependencyKey {
    public static let liveValue: IPTVClient = {
        let networkClient = NetworkClient()

        return IPTVClient(
            authenticate: { config in
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.authenticate.url(with: xtreamConfig)
                let _: XtreamAuthResponseDTO = try await networkClient.fetch(url: url)
            },
            fetchLiveCategories: { config in
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getLiveCategories.url(with: xtreamConfig)
                let dtos: [XtreamCategoryDTO] = try await networkClient.fetch(url: url)
                return dtos.map { MediaModels.Category(id: $0.categoryId, name: $0.categoryName) }
            },
            fetchLiveChannels: { config, categoryID in
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getLiveStreams(categoryID: categoryID).url(with: xtreamConfig)
                let dtos: [XtreamLiveStreamDTO] = try await networkClient.fetch(url: url)
                return dtos.map { dto in
                    let streamURL = xtreamConfig.baseURL.appendingPathComponent("live/\(xtreamConfig.username)/\(xtreamConfig.password)/\(dto.streamId).ts")
                    return MediaModels.Item(
                        id: String(dto.streamId),
                        title: dto.name,
                        streamURL: streamURL,
                        coverURL: dto.streamIcon.flatMap { URL(string: $0) },
                        categoryID: dto.categoryId,
                        type: .live
                    )
                }
            },
            fetchVODCategories: { config in
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getVODCategories.url(with: xtreamConfig)
                let dtos: [XtreamCategoryDTO] = try await networkClient.fetch(url: url)
                return dtos.map { MediaModels.Category(id: $0.categoryId, name: $0.categoryName) }
            },
            fetchVODs: { config, categoryID in
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getVODStreams(categoryID: categoryID).url(with: xtreamConfig)
                let dtos: [XtreamVODStreamDTO] = try await networkClient.fetch(url: url)
                return dtos.map { dto in
                    let ext = dto.containerExtension ?? "mp4"
                    let streamURL = xtreamConfig.baseURL.appendingPathComponent("movie/\(xtreamConfig.username)/\(xtreamConfig.password)/\(dto.streamId).\(ext)")
                    return MediaModels.Item(
                        id: String(dto.streamId),
                        title: dto.name,
                        streamURL: streamURL,
                        coverURL: dto.streamIcon.flatMap { URL(string: $0) },
                        categoryID: dto.categoryId,
                        type: .vod,
                        rating: dto.rating5based ?? dto.rating
                    )
                }
            },
            fetchSeriesCategories: { config in
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getSeriesCategories.url(with: xtreamConfig)
                let dtos: [XtreamCategoryDTO] = try await networkClient.fetch(url: url)
                return dtos.map { MediaModels.Category(id: $0.categoryId, name: $0.categoryName) }
            },
            fetchSeries: { config, categoryID in
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getSeries(categoryID: categoryID).url(with: xtreamConfig)
                let dtos: [XtreamSeriesDTO] = try await networkClient.fetch(url: url)
                return dtos.map { dto in
                    MediaModels.Item(
                        id: String(dto.seriesId),
                        title: dto.name,
                        streamURL: nil,
                        coverURL: dto.cover.flatMap { URL(string: $0) },
                        categoryID: dto.categoryId,
                        type: .series,
                        rating: dto.rating5based ?? Double(dto.rating ?? "0"),
                        releaseDate: dto.releaseDate
                    )
                }
            },
            fetchSeriesInfo: { config, seriesID in
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else {
                    throw NSError(domain: "IPTVClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Xtream configuration"])
                }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getSeriesInfo(seriesID: seriesID).url(with: xtreamConfig)
                let dto: XtreamSeriesInfoDTO = try await networkClient.fetch(url: url)

                let info = DetailModels.Info(
                    plot: dto.info?.plot,
                    cast: dto.info?.cast,
                    director: dto.info?.director,
                    genre: dto.info?.genre,
                    tmdbId: nil,
                    rating: dto.info?.rating5based,
                    releaseDate: dto.info?.releaseDate
                )

                var seasons: [DetailModels.Season] = []
                var episodes: [DetailModels.Episode] = []

                if let dtoSeasons = dto.episodes {
                    for (seasonNumStr, seasonEpisodes) in dtoSeasons {
                        guard let seasonNum = Int(seasonNumStr) else { continue }
                        seasons.append(DetailModels.Season(id: seasonNumStr, seasonNumber: seasonNum, name: "Sezon \(seasonNum)", episodeCount: seasonEpisodes.count))

                        for ep in seasonEpisodes {
                            let ext = ep.containerExtension
                            let streamURL = xtreamConfig.baseURL.appendingPathComponent("series/\(xtreamConfig.username)/\(xtreamConfig.password)/\(ep.id).\(ext)")
                            episodes.append(DetailModels.Episode(
                                id: ep.id,

                                episodeNum: ep.episodeNum ?? 0,
                                title: ep.title,
                                streamURL: streamURL,
                                coverURL: ep.info?.movieImage.flatMap { URL(string: $0) } ?? nil,
                                season: seasonNum,
                                duration: ep.info?.duration,
                                plot: ep.info?.plot
                            ))
                        }
                    }
                }

                return (info: info, seasons: seasons.sorted(by: { $0.seasonNumber < $1.seasonNumber }), episodes: episodes)
            },
            fetchVODInfo: { config, vodID in
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else {
                    throw NSError(domain: "IPTVClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Xtream configuration"])
                }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getVODInfo(vodID: vodID).url(with: xtreamConfig)
                let dto: XtreamVODInfoDTO = try await networkClient.fetch(url: url)

                return DetailModels.Info(
                    plot: dto.info?.plot ?? dto.info?.description,
                    cast: dto.info?.cast,
                    director: dto.info?.director,
                    genre: dto.info?.genre,
                    duration: dto.info?.duration,
                    tmdbId: dto.info?.tmdbId.flatMap(Int.init),
                    rating: dto.info?.rating5based,
                    releaseDate: dto.info?.releaseDate
                )
            }
        )
    }()

    public static let testValue = IPTVClient()
}

public extension DependencyValues {
    var iptvClient: IPTVClient {
        get { self[IPTVClient.self] }
        set { self[IPTVClient.self] = newValue }
    }
}
