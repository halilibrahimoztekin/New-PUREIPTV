import ComposableArchitecture
@preconcurrency import Foundation

actor M3UCache {
    struct Entry {
        var items: [M3UItemDTO] = []
        var epgURL: URL?
        var xmltvData: XMLTVData?
    }

    private var entries: [String: Entry] = [:]

    func update(items: [M3UItemDTO], epgURL: URL?, for key: String) {
        entries[key] = Entry(items: items, epgURL: epgURL)
    }

    func getItems(for key: String) -> [M3UItemDTO] {
        entries[key]?.items ?? []
    }

    func getEpgURL(for key: String) -> URL? {
        entries[key]?.epgURL
    }

    func getXmltvData(for key: String) -> XMLTVData? {
        entries[key]?.xmltvData
    }

    func setXmltvData(_ data: XMLTVData, for key: String) {
        entries[key, default: Entry()].xmltvData = data
    }

    func clearXmltvData() {
        for key in Array(entries.keys) {
            entries[key]?.xmltvData = nil
        }
    }
}

private extension M3UItemDTO {
    var resolvedMediaType: MediaModels.ItemType {
        // 1. tvg-type
        if let type = tvgType?.lowercased() {
            if type.contains("movie") || type.contains("vod") {
                return .vod
            }
            if type.contains("series") || type.contains("tv show") || type.contains("tv-show") {
                return .series
            }
            if type.contains("live") || type.contains("tv") {
                return .live
            }
        }

        // 2. group-title
        let group = groupTitle.lowercased()
        if group.contains("movie") || group.contains("film") || group.contains("vod") {
            return .vod
        }
        if group.contains("series") || group.contains("dizi") || group.contains("season") {
            return .series
        }

        // 3. url extension
        let path = streamURL.path.lowercased()
        if path.hasSuffix(".mp4") || path.hasSuffix(".mkv") || path.hasSuffix(".avi") {
            return .vod
        }

        return .live
    }
}

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
    public var clearEPGCache: @Sendable () async -> Void = {}
}

extension IPTVClient: DependencyKey {
    public nonisolated static let liveValue: IPTVClient = {
        let networkClient = NetworkClient()
        let m3uCache = M3UCache()

        let m3uCacheKey: @Sendable (PlaylistConfig) -> String = { config in
            let identity = config.playlistID?.uuidString ?? config.m3uURL?.absoluteString ?? "unidentified"
            let sourceURL = config.m3uURL?.absoluteString ?? ""
            let userAgent = (config.userAgentOverride ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(identity)|\(sourceURL)|\(userAgent.isEmpty ? "default" : userAgent)"
        }

        let ensureM3UCache: @Sendable (PlaylistConfig) async -> [M3UItemDTO] = { config in
            let key = m3uCacheKey(config)
            let existing = await m3uCache.getItems(for: key)
            if !existing.isEmpty {
                return existing
            }
            guard let url = config.m3uURL else { return [] }
            guard let data = try? await networkClient.fetchData(url: url, userAgentOverride: config.userAgentOverride) else { return [] }
            guard let str = String(data: data, encoding: .utf8) else { return [] }
            let parser = M3UParser()
            let parsedResult = await Task.detached(priority: .userInitiated) {
                parser.parse(m3uString: str)
            }.value
            await m3uCache.update(items: parsedResult.items, epgURL: parsedResult.epgURL, for: key)
            return parsedResult.items
        }

        return IPTVClient(
            authenticate: { config in
                if config.type == .m3u {
                    guard let m3uURL = config.m3uURL else {
                        throw NSError(domain: "IPTVClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid M3U configuration"])
                    }
                    let data = try await networkClient.fetchData(url: m3uURL, userAgentOverride: config.userAgentOverride)
                    guard let m3uString = String(data: data, encoding: .utf8) else {
                        throw NSError(domain: "IPTVClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to parse M3U data"])
                    }
                    let parser = M3UParser()
                    let parsedResult = await Task.detached(priority: .userInitiated) {
                        parser.parse(m3uString: m3uString)
                    }.value
                    await m3uCache.update(items: parsedResult.items, epgURL: parsedResult.epgURL, for: m3uCacheKey(config))
                    return
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return }

                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.authenticate.url(with: xtreamConfig)
                if let authDTO: XtreamAuthResponseDTO = try? await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride) {
                    await AccountInfoManager.shared.update(from: authDTO)
                }
            },
            fetchLiveCategories: { config in
                if config.type == .m3u {
                    let items = await ensureM3UCache(config).filter { $0.resolvedMediaType == .live }
                    let groups = Array(Set(items.map(\.groupTitle))).sorted()
                    return groups.map { MediaModels.Category(id: $0, name: $0) }
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getLiveCategories.url(with: xtreamConfig)
                let dtos: [XtreamCategoryDTO] = try await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride)
                return dtos.map { MediaModels.Category(id: $0.categoryId, name: $0.categoryName) }
            },
            fetchLiveChannels: { config, categoryID in
                if config.type == .m3u {
                    let items = await ensureM3UCache(config).filter { $0.resolvedMediaType == .live }
                    let filtered = items.filter { categoryID == nil || $0.groupTitle == categoryID }
                    return filtered.map { item in
                        MediaModels.Item(
                            id: item.id,
                            title: item.title,
                            streamURL: item.streamURL,
                            coverURL: item.coverURL,
                            categoryID: item.groupTitle,
                            type: .live,
                            epgChannelID: item.tvgID,
                            userAgentOverride: config.userAgentOverride
                        )
                    }
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getLiveStreams(categoryID: categoryID).url(with: xtreamConfig)
                let dtos: [XtreamLiveStreamDTO] = try await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride)
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
                        tvArchiveDuration: dto.tvArchiveDuration,
                        userAgentOverride: config.userAgentOverride
                    )
                }
            },
            fetchVODCategories: { config in
                if config.type == .m3u {
                    let items = await ensureM3UCache(config).filter { $0.resolvedMediaType == .vod }
                    let groups = Array(Set(items.map(\.groupTitle))).sorted()
                    return groups.map { MediaModels.Category(id: $0, name: $0) }
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getVODCategories.url(with: xtreamConfig)
                let dtos: [XtreamCategoryDTO] = try await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride)
                return dtos.map { MediaModels.Category(id: $0.categoryId, name: $0.categoryName) }
            },
            fetchVODs: { config, categoryID in
                if config.type == .m3u {
                    let items = await ensureM3UCache(config).filter { $0.resolvedMediaType == .vod }
                    let filtered = items.filter { categoryID == nil || $0.groupTitle == categoryID }
                    return filtered.map { item in
                        MediaModels.Item(
                            id: item.id,
                            title: item.title,
                            streamURL: item.streamURL,
                            coverURL: item.coverURL,
                            categoryID: item.groupTitle,
                            type: .vod,
                            epgChannelID: item.tvgID,
                            userAgentOverride: config.userAgentOverride
                        )
                    }
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getVODStreams(categoryID: categoryID).url(with: xtreamConfig)
                let dtos: [XtreamVODStreamDTO] = try await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride)
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
                        addedDate: addedDate,
                        userAgentOverride: config.userAgentOverride
                    )
                }
            },
            fetchSeriesCategories: { config in
                if config.type == .m3u {
                    let items = await ensureM3UCache(config).filter { $0.resolvedMediaType == .series }
                    let groups = Array(Set(items.map(\.groupTitle))).sorted()
                    return groups.map { MediaModels.Category(id: $0, name: $0) }
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getSeriesCategories.url(with: xtreamConfig)
                let dtos: [XtreamCategoryDTO] = try await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride)
                return dtos.map { MediaModels.Category(id: $0.categoryId, name: $0.categoryName) }
            },
            fetchSeries: { config, categoryID in
                if config.type == .m3u {
                    let items = await ensureM3UCache(config).filter { $0.resolvedMediaType == .series }
                    let filtered = items.filter { categoryID == nil || $0.groupTitle == categoryID }
                    return filtered.map { item in
                        MediaModels.Item(
                            id: item.id,
                            title: item.title,
                            streamURL: item.streamURL, // In MediaModels for Series, streamURL can be nil until an episode is selected, but here we only have the M3U item URL
                            coverURL: item.coverURL,
                            categoryID: item.groupTitle,
                            type: .series,
                            epgChannelID: item.tvgID,
                            userAgentOverride: config.userAgentOverride
                        )
                    }
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getSeries(categoryID: categoryID).url(with: xtreamConfig)
                let dtos: [XtreamSeriesDTO] = try await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride)
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
                        addedDate: addedDate,
                        userAgentOverride: config.userAgentOverride
                    )
                }
            },
            fetchSeriesInfo: { config, seriesID in
                if config.type == .m3u {
                    // Since M3U series items are flat, we just return a single episode pseudo-info
                    // Find the item first
                    let items = await ensureM3UCache(config)
                    if let item = items.first(where: { $0.id == seriesID }) {
                        let info = DetailModels.Info(plot: nil, cast: nil, director: nil, genre: item.groupTitle)
                        let seasons = [DetailModels.Season(id: "1", seasonNumber: 1, name: "Season 1", episodeCount: 1)]
                        let episodes = [DetailModels.Episode(id: item.id, episodeNum: 1, title: item.title, streamURL: item.streamURL, coverURL: item.coverURL, season: 1)]
                        return (info: info, seasons: seasons, episodes: episodes)
                    }
                    throw NSError(domain: "IPTVClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "Series not found"])
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else {
                    throw NSError(domain: "IPTVClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Xtream configuration"])
                }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getSeriesInfo(seriesID: seriesID).url(with: xtreamConfig)
                let data = try await networkClient.fetchData(url: url, userAgentOverride: config.userAgentOverride)
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
                if config.type == .m3u {
                    // Find the item first
                    let items = await ensureM3UCache(config)
                    if let item = items.first(where: { $0.id == vodID }) {
                        return DetailModels.Info(plot: nil, cast: nil, director: nil, genre: item.groupTitle)
                    }
                    throw NSError(domain: "IPTVClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "VOD not found"])
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else {
                    throw NSError(domain: "IPTVClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Xtream configuration"])
                }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getVODInfo(vodID: vodID).url(with: xtreamConfig)
                let data = try await networkClient.fetchData(url: url, userAgentOverride: config.userAgentOverride)
                let dto = try await MainActor.run { try JSONDecoder().decode(XtreamVODInfoDTO.self, from: data) }

                return DetailModels.Info(
                    plot: dto.info?.plot ?? dto.info?.description,
                    cast: dto.info?.cast,
                    director: dto.info?.director,
                    genre: dto.info?.genre,
                    duration: dto.info?.duration,
                    tmdbId: dto.info?.tmdbId.flatMap(Int.init),
                    rating: dto.info?.rating5based,
                    releaseDate: dto.info?.releaseDate,
                    youtubeTrailer: dto.info?.youtubeTrailer
                )
            },
            fetchShortEPG: { config, streamID, limit in
                @Dependency(\.xmltvParser) var xmltvParser
                if config.type == .m3u {
                    _ = await ensureM3UCache(config)
                    let cacheKey = m3uCacheKey(config)
                    guard let epgURL = await m3uCache.getEpgURL(for: cacheKey) else { return [] }
                    var currentXMLTV = await m3uCache.getXmltvData(for: cacheKey)
                    if currentXMLTV == nil {
                        let data = try await networkClient.fetchData(url: epgURL, userAgentOverride: config.userAgentOverride)
                        currentXMLTV = try await xmltvParser.parse(data)
                        if let parsed = currentXMLTV {
                            await m3uCache.setXmltvData(parsed, for: cacheKey)
                        }
                    }
                    guard let xmlData = currentXMLTV else { return [] }

                    let now = Date()
                    let programmes = xmlData.programmes[streamID] ?? []
                    return programmes.map { p in
                        EPGProgram(
                            id: UUID().uuidString,
                            title: p.title,
                            description: p.description,
                            startTime: p.start,
                            endTime: p.end,
                            isPlayingNow: p.start <= now && p.end >= now
                        )
                    }
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)

                var response: [EPGItemDTO] = []

                // Strategy 1: Attempt action=get_short_epg
                if let url = try? XtreamEndpoint.getShortEPG(streamID: streamID, limit: limit).url(with: xtreamConfig),
                   let data = try? await networkClient.fetchData(url: url, userAgentOverride: config.userAgentOverride)
                {
                    if let dto = try? JSONDecoder().decode(EPGResponseDTO.self, from: data) {
                        response = dto.epgListings
                    } else if let array = try? JSONDecoder().decode([EPGItemDTO].self, from: data) {
                        response = array
                    }
                }

                // Strategy 2: If empty, attempt action=get_simple_data_table
                if response.isEmpty,
                   let url = try? XtreamEndpoint.getEPGDataTable(streamID: streamID).url(with: xtreamConfig),
                   let data = try? await networkClient.fetchData(url: url, userAgentOverride: config.userAgentOverride)
                {
                    if let dto = try? JSONDecoder().decode(EPGResponseDTO.self, from: data) {
                        response = dto.epgListings
                    } else if let array = try? JSONDecoder().decode([EPGItemDTO].self, from: data) {
                        response = array
                    }
                }

                // Strategy 3: If still empty, check mapped XMLTV sources via CustomEPGMappingClient
                if response.isEmpty {
                    @Dependency(\.customEPGMappingClient) var customEPGMappingClient
                    let customPrograms = await customEPGMappingClient.fetchProgramsForChannel(streamID, "", nil)
                    if !customPrograms.isEmpty {
                        return customPrograms
                    }
                    return []
                }

                let formatStrings = [
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy-MM-dd HH:mm",
                    "yyyyMMddHHmmss Z",
                    "yyyyMMddHHmmss zzz",
                    "yyyyMMddHHmmss",
                    "yyyyMMddHHmm Z",
                    "yyyyMMddHHmm",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                    "yyyy-MM-dd'T'HH:mm:ssXXXXX",
                ]
                let formatters: [DateFormatter] = formatStrings.map { fmt in
                    let f = DateFormatter()
                    f.dateFormat = fmt
                    f.locale = Locale(identifier: "en_US_POSIX")
                    f.timeZone = TimeZone(identifier: "UTC")
                    return f
                }

                let parseEPGDate: (String) -> Date? = { str in
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return nil }
                    if let ts = Double(trimmed), ts > 1_000_000_000, ts < 2_500_000_000 {
                        return Date(timeIntervalSince1970: ts)
                    }
                    for f in formatters {
                        if let d = f.date(from: trimmed) {
                            return d
                        }
                    }
                    return nil
                }

                let decodeBase64OrSelf: (String) -> String = { text in
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return text }
                    if let data = Data(base64Encoded: trimmed, options: [.ignoreUnknownCharacters]),
                       let decoded = String(data: data, encoding: .utf8),
                       !decoded.isEmpty,
                       decoded.rangeOfCharacter(from: CharacterSet.controlCharacters.subtracting(.newlines)) == nil
                    {
                        return decoded
                    }
                    return text
                }

                let epgShift = UserDefaults.standard.integer(forKey: "com.pureiptv.epgTimeShift")
                let shiftInterval = TimeInterval(epgShift * 3600)

                let result: [EPGProgram] = response.compactMap { (item: EPGItemDTO) -> EPGProgram? in
                    var start: Date?
                    var end: Date?

                    if let startTS = item.startTimestamp, let endTS = item.stopTimestamp {
                        start = Date(timeIntervalSince1970: TimeInterval(startTS)).addingTimeInterval(shiftInterval)
                        end = Date(timeIntervalSince1970: TimeInterval(endTS)).addingTimeInterval(shiftInterval)
                    } else {
                        if let s = parseEPGDate(item.start), let e = parseEPGDate(item.end) {
                            start = s.addingTimeInterval(shiftInterval)
                            end = e.addingTimeInterval(shiftInterval)
                        }
                    }

                    guard let finalStart = start, let finalEnd = end else { return nil }

                    let cleanTitle = decodeBase64OrSelf(item.title)
                    let cleanDesc = decodeBase64OrSelf(item.description)

                    return EPGProgram(
                        id: item.id.isEmpty ? UUID().uuidString : item.id,
                        title: cleanTitle.isEmpty ? AppStrings.Player.epgNotFound : cleanTitle,
                        description: cleanDesc,
                        startTime: finalStart,
                        endTime: finalEnd,
                        isPlayingNow: item.nowPlaying == 1 || (finalStart <= Date() && Date() <= finalEnd)
                    )
                }

                return result
            },
            clearEPGCache: {
                await m3uCache.clearXmltvData()
            }
        )
    }()

    public static let testValue = IPTVClient(
        authenticate: { _ in },
        fetchLiveCategories: { _ in [] },
        fetchLiveChannels: { _, _ in [] },
        fetchVODCategories: { _ in [] },
        fetchVODs: { _, _ in [] },
        fetchSeriesCategories: { _ in [] },
        fetchSeries: { _, _ in [] },
        fetchSeriesInfo: { _, _ in (DetailModels.Info(), [], []) },
        fetchVODInfo: { _, _ in DetailModels.Info() },
        fetchShortEPG: { _, _, _ in [] },
        clearEPGCache: {}
    )
}

public extension DependencyValues {
    var iptvClient: IPTVClient {
        get { self[IPTVClient.self] }
        set { self[IPTVClient.self] = newValue }
    }
}
