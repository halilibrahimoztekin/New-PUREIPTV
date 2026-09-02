import ComposableArchitecture
@preconcurrency import Foundation

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
    public var fetchShortEPG: @Sendable (_ config: PlaylistConfig, _ streamID: String, _ limit: Int?) async throws -> [EPGProgram]
}

extension IPTVClient: DependencyKey {
    public nonisolated static let liveValue: IPTVClient = {
        let networkClient = NetworkClient()

        return IPTVClient(
            authenticate: { config in
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.authenticate.url(with: xtreamConfig)
                let data = try await networkClient.fetchData(url: url)
                let _: XtreamAuthResponseDTO = try await MainActor.run {
                    try JSONDecoder().decode(XtreamAuthResponseDTO.self, from: data)
                }
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
                        type: .live,
                        epgChannelID: dto.epgChannelId,
                        tvArchive: dto.tvArchive,
                        tvArchiveDuration: dto.tvArchiveDuration
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
                    let addedDate = dto.added.flatMap { TimeInterval($0) }.map { Date(timeIntervalSince1970: $0) }
                    return MediaModels.Item(
                        id: String(dto.streamId),
                        title: dto.name,
                        streamURL: streamURL,
                        coverURL: dto.streamIcon.flatMap { URL(string: $0) },
                        categoryID: dto.categoryId,
                        type: .vod,
                        rating: dto.rating5based ?? dto.rating,
                        addedDate: addedDate
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
                    let addedDate = dto.lastModified.flatMap { TimeInterval($0) }.map { Date(timeIntervalSince1970: $0) }
                    return MediaModels.Item(
                        id: String(dto.seriesId),
                        title: dto.name,
                        streamURL: nil,
                        coverURL: dto.cover.flatMap { URL(string: $0) },
                        categoryID: dto.categoryId,
                        type: .series,
                        rating: dto.rating5based ?? Double(dto.rating ?? "0"),
                        releaseDate: dto.releaseDate,
                        addedDate: addedDate
                    )
                }
            },
            fetchSeriesInfo: { config, seriesID in
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else {
                    throw NSError(domain: "IPTVClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Xtream configuration"])
                }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getSeriesInfo(seriesID: seriesID).url(with: xtreamConfig)
                let data = try await networkClient.fetchData(url: url)
                let dto = try await MainActor.run { try JSONDecoder().decode(XtreamSeriesInfoDTO.self, from: data) }

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
                let data = try await networkClient.fetchData(url: url)
                let dto = try await MainActor.run { try JSONDecoder().decode(XtreamVODInfoDTO.self, from: data) }

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
            },
            fetchShortEPG: { config, streamID, limit in
                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getShortEPG(streamID: streamID, limit: limit).url(with: xtreamConfig)
                let data = try await networkClient.fetchData(url: url)

                let response: [EPGItemDTO]
                var debugError: String? = nil

                do {
                    let dto = try JSONDecoder().decode(EPGResponseDTO.self, from: data)
                    response = dto.epgListings
                } catch {
                    if let array = try? JSONDecoder().decode([EPGItemDTO].self, from: data) {
                        response = array
                    } else {
                        // If data is empty or malformed
                        let str = String(data: data, encoding: .utf8) ?? "unknown"
                        debugError = "Dec Err: \(error.localizedDescription) DataPrefix: \(str.prefix(100))"
                        response = []
                    }
                }

                if let err = debugError {
                    return [
                        EPGProgram(id: "debug_1", title: err, description: "", startTime: Date().addingTimeInterval(-3600), endTime: Date().addingTimeInterval(3600), isPlayingNow: true),
                    ]
                }

                if response.isEmpty {
                    return [
                        EPGProgram(id: "debug_2", title: "API returned empty list", description: "", startTime: Date().addingTimeInterval(-3600), endTime: Date().addingTimeInterval(3600), isPlayingNow: true),
                    ]
                }

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = TimeZone(identifier: "UTC")

                let result: [EPGProgram] = response.compactMap { (item: EPGItemDTO) -> EPGProgram? in
                    var start: Date?
                    var end: Date?

                    if let startTS = item.startTimestamp, let endTS = item.stopTimestamp {
                        start = Date(timeIntervalSince1970: TimeInterval(startTS))
                        end = Date(timeIntervalSince1970: TimeInterval(endTS))
                    } else {
                        start = formatter.date(from: item.start)
                        end = formatter.date(from: item.end)
                    }

                    guard let finalStart = start, let finalEnd = end else { return nil }

                    return EPGProgram(
                        id: item.id,
                        title: item.title,
                        description: item.description,
                        startTime: finalStart,
                        endTime: finalEnd,
                        isPlayingNow: item.nowPlaying == 1
                    )
                }

                if result.isEmpty {
                    let firstItem = response.first
                    return [
                        EPGProgram(id: "debug_3", title: "Parsed 0 items. API count: \(response.count). First start: \(firstItem?.start ?? "nil"), startTS: \(firstItem?.startTimestamp.map(String.init) ?? "nil")", description: "", startTime: Date().addingTimeInterval(-3600), endTime: Date().addingTimeInterval(3600), isPlayingNow: true),
                    ]
                }

                return result
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
