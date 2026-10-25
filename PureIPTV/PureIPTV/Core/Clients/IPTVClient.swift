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

    func replaceXmltvData(_ data: XMLTVData, for key: String) throws {
        try Task.checkCancellation()
        entries[key, default: Entry()].xmltvData = data
    }
}

private func parseXtreamReleaseDate(_ value: String?) -> Date? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    if let date = ISO8601DateFormatter().date(from: value) {
        return date
    }
    for format in ["yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "dd/MM/yyyy"] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        if let date = formatter.date(from: value) {
            return date
        }
    }
    return nil
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

private func m3uCategory(for item: M3UItemDTO, config: PlaylistConfig, mappings: [String: String]) -> MediaModels.Category {
    let sourceTag = item.sourceGroupTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !sourceTag.isEmpty, sourceTag.count <= 160,
          let targetName = mappings[sourceTag]?.trimmingCharacters(in: .whitespacesAndNewlines),
          !targetName.isEmpty,
          let playlistID = config.playlistID
    else {
        return MediaModels.Category(id: item.groupTitle, name: item.groupTitle)
    }
    let normalizedTarget = targetName.lowercased(with: Locale(identifier: "en_US_POSIX"))
    return MediaModels.Category(
        id: "m3u-map.\(playlistID.uuidString.lowercased()).\(normalizedTarget)",
        name: targetName
    )
}

@DependencyClient
public struct IPTVClient {
    public var authenticate: @Sendable (_ config: PlaylistConfig) async throws -> Void
    public var fetchLiveCategories: @Sendable (_ config: PlaylistConfig) async throws -> [MediaModels.Category]
    public var fetchM3UCategoryTags: @Sendable (_ config: PlaylistConfig) async -> [String] = { _ in [] }
    public var fetchLiveChannels: @Sendable (_ config: PlaylistConfig, _ categoryID: String?) async throws -> [MediaModels.Item]
    public var resolveLiveItem: @Sendable (_ config: PlaylistConfig, _ itemID: String, _ categoryID: String?) async throws -> MediaModels.Item?
    public var fetchVODCategories: @Sendable (_ config: PlaylistConfig) async throws -> [MediaModels.Category]
    public var fetchVODs: @Sendable (_ config: PlaylistConfig, _ categoryID: String?) async throws -> [MediaModels.Item]
    public var fetchSeriesCategories: @Sendable (_ config: PlaylistConfig) async throws -> [MediaModels.Category]
    public var fetchSeries: @Sendable (_ config: PlaylistConfig, _ categoryID: String?) async throws -> [MediaModels.Item]
    public var fetchSeriesInfo: @Sendable (_ config: PlaylistConfig, _ seriesID: String) async throws -> (info: DetailModels.Info, seasons: [DetailModels.Season], episodes: [DetailModels.Episode])
    public var fetchVODInfo: @Sendable (_ config: PlaylistConfig, _ vodID: String) async throws -> DetailModels.Info
    public var resolveVODItem: @Sendable (_ config: PlaylistConfig, _ vodID: String, _ categoryID: String?) async throws -> MediaModels.Item?
    public var fetchShortEPG: @Sendable (_ config: PlaylistConfig, _ streamID: String, _ limit: Int?) async throws -> [EPGProgram]
    public var refreshEPGCache: @Sendable (_ config: PlaylistConfig) async throws -> Void
    public var searchCachedEPGPrograms: @Sendable (_ config: PlaylistConfig, _ query: String, _ channels: [MediaModels.Item], _ limit: Int) async -> [CachedEPGProgramMatch] = { _, _, _, _ in [] }
}

private func decodeEPGItems(_ data: Data) throws -> [EPGItemDTO] {
    let decoder = JSONDecoder()
    do {
        return try decoder.decode(EPGResponseDTO.self, from: data).epgListings
    } catch {
        do {
            return try decoder.decode([EPGItemDTO].self, from: data)
        } catch {
            throw NetworkError.decodingFailed(description: error.localizedDescription)
        }
    }
}

private func makeXtreamStreamURL(
    baseURL: URL,
    username _: String,
    password _: String,
    path: [String]
) -> URL? {
    guard let baseHost = baseURL.host, let scheme = baseURL.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
    var allowed = CharacterSet.alphanumerics
    allowed.formUnion(CharacterSet(charactersIn: "-._~"))
    let encodedSegments = path.compactMap { $0.addingPercentEncoding(withAllowedCharacters: allowed) }
    guard encodedSegments.count == path.count else { return nil }
    var basePath = components.percentEncodedPath
    if !basePath.hasSuffix("/") {
        basePath += "/"
    }
    components.percentEncodedPath = basePath + encodedSegments.joined(separator: "/")
    components.query = nil
    components.fragment = nil
    guard let result = components.url,
          result.host?.caseInsensitiveCompare(baseHost) == .orderedSame,
          result.scheme?.lowercased() == scheme,
          result.user == nil, result.password == nil else { return nil }
    return result
}

extension IPTVClient: DependencyKey {
    public nonisolated static let liveValue: IPTVClient = {
        let networkClient = NetworkClient()
        let m3uCache = M3UCache()
        let logoOverrideClient = ChannelLogoOverrideClient.liveValue
        let m3uCategoryMappingClient = M3UCategoryMappingClient.liveValue

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
                    let mappings: [String: String] = if let playlistID = config.playlistID {
                        await m3uCategoryMappingClient.load(playlistID)
                    } else {
                        [:]
                    }
                    var categoriesByID: [String: MediaModels.Category] = [:]
                    for item in items {
                        let category = m3uCategory(for: item, config: config, mappings: mappings)
                        if categoriesByID[category.id] == nil {
                            categoriesByID[category.id] = category
                        }
                    }
                    return categoriesByID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getLiveCategories.url(with: xtreamConfig)
                let dtos: [XtreamCategoryDTO] = try await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride)
                return dtos.map { MediaModels.Category(id: $0.categoryId, name: $0.categoryName) }
            },
            fetchM3UCategoryTags: { config in
                guard config.type == .m3u else { return [] }
                let items = await ensureM3UCache(config).filter { $0.resolvedMediaType == .live }
                return Array(Set(items.compactMap { item in
                    let tag = item.sourceGroupTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return tag.isEmpty || tag.count > 160 ? nil : tag
                })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            },
            fetchLiveChannels: { config, categoryID in
                if config.type == .m3u {
                    let items = await ensureM3UCache(config).filter { $0.resolvedMediaType == .live }
                    let mappings: [String: String] = if let playlistID = config.playlistID {
                        await m3uCategoryMappingClient.load(playlistID)
                    } else {
                        [:]
                    }
                    let filtered = items.filter { item in
                        guard let categoryID else { return true }
                        return m3uCategory(for: item, config: config, mappings: mappings).id == categoryID
                    }
                    let channels = filtered.map { item in
                        let category = m3uCategory(for: item, config: config, mappings: mappings)
                        return MediaModels.Item(
                            id: item.id,
                            title: item.title,
                            streamURL: item.streamURL,
                            coverURL: item.coverURL,
                            categoryID: category.id,
                            type: .live,
                            epgChannelID: item.tvgID,
                            userAgentOverride: config.userAgentOverride
                        )
                    }
                    guard let playlistID = config.playlistID else { return channels }
                    let overrides = await logoOverrideClient.fetchOverrides(playlistID, channels.map(\.id))
                    return channels.map { $0.replacingLogoURLOverride(overrides[$0.id]) }
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getLiveStreams(categoryID: categoryID).url(with: xtreamConfig)
                let dtos: [XtreamLiveStreamDTO] = try await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride)
                let channels = dtos.map { dto in
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
                guard let playlistID = config.playlistID else { return channels }
                let overrides = await logoOverrideClient.fetchOverrides(playlistID, channels.map(\.id))
                return channels.map { $0.replacingLogoURLOverride(overrides[$0.id]) }
            },
            resolveLiveItem: { config, itemID, categoryID in
                guard !itemID.isEmpty, itemID.count <= 512 else { return nil }
                if config.type == .m3u {
                    let cachedItems = await ensureM3UCache(config)
                    let mappings: [String: String] = if let playlistID = config.playlistID {
                        await m3uCategoryMappingClient.load(playlistID)
                    } else {
                        [:]
                    }
                    var matchingItem: M3UItemDTO?
                    for candidate in cachedItems {
                        guard candidate.id == itemID else { continue }
                        guard candidate.resolvedMediaType == .live else { continue }
                        if let categoryID, m3uCategory(for: candidate, config: config, mappings: mappings).id != categoryID {
                            continue
                        }
                        matchingItem = candidate
                        break
                    }
                    guard let item = matchingItem else { return nil }
                    let category = m3uCategory(for: item, config: config, mappings: mappings)
                    let resolved = MediaModels.Item(
                        id: item.id,
                        title: item.title,
                        streamURL: item.streamURL,
                        coverURL: item.coverURL,
                        categoryID: category.id,
                        type: .live,
                        epgChannelID: item.tvgID,
                        userAgentOverride: config.userAgentOverride
                    )
                    guard let playlistID = config.playlistID else { return resolved }
                    let overrides = await logoOverrideClient.fetchOverrides(playlistID, [itemID])
                    return resolved.replacingLogoURLOverride(overrides[itemID])
                }
                guard itemID.count <= 32,
                      itemID.allSatisfy({ $0 >= "0" && $0 <= "9" }),
                      Int(itemID) != nil else { return nil }
                guard config.type == .xtream,
                      let serverURL = config.serverURL,
                      let username = config.username,
                      let password = config.password,
                      let streamURL = makeXtreamStreamURL(
                          baseURL: serverURL,
                          username: username,
                          password: password,
                          path: ["live", username, password, "\(itemID).ts"]
                      ) else { return nil }
                let resolved = MediaModels.Item(
                    id: itemID,
                    title: itemID,
                    streamURL: streamURL,
                    categoryID: categoryID ?? "",
                    type: .live,
                    userAgentOverride: config.userAgentOverride
                )
                guard let playlistID = config.playlistID else { return resolved }
                let overrides = await logoOverrideClient.fetchOverrides(playlistID, [itemID])
                return resolved.replacingLogoURLOverride(overrides[itemID])
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
                                plot: ep.info?.plot,
                                addedDate: ep.added.flatMap { TimeInterval($0) }.map {
                                    Date(timeIntervalSince1970: $0)
                                },
                                releaseDate: parseXtreamReleaseDate(ep.info?.releasedate)
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
            resolveVODItem: { config, vodID, categoryID in
                guard !vodID.isEmpty, vodID.count <= 512 else { return nil }

                if config.type == .m3u {
                    let cachedItems = await ensureM3UCache(config)
                    var item: M3UItemDTO?
                    for candidate in cachedItems {
                        guard candidate.id == vodID else { continue }
                        guard candidate.resolvedMediaType == .vod else { continue }
                        if let categoryID, candidate.groupTitle != categoryID {
                            continue
                        }
                        item = candidate
                        break
                    }
                    guard let item else { return nil }
                    return MediaModels.Item(
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

                guard vodID.count <= 32,
                      vodID.allSatisfy({ $0 >= "0" && $0 <= "9" }),
                      Int(vodID) != nil else { return nil }
                guard config.type == .xtream,
                      let serverURL = config.serverURL,
                      let username = config.username,
                      let password = config.password else { return nil }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let endpoint = try XtreamEndpoint.getVODInfo(vodID: vodID).url(with: xtreamConfig)
                let data = try await networkClient.fetchData(url: endpoint, userAgentOverride: config.userAgentOverride)
                let dto = try await MainActor.run { try JSONDecoder().decode(XtreamVODInfoDTO.self, from: data) }
                guard let movieData = dto.movieData,
                      movieData.streamId > 0,
                      String(movieData.streamId) == vodID else { return nil }
                let ext = movieData.containerExtension.flatMap { value -> String? in
                    guard (1 ... 10).contains(value.count),
                          value.utf8.allSatisfy({
                              (48 ... 57).contains($0) || (65 ... 90).contains($0) || (97 ... 122).contains($0)
                          }) else { return nil }
                    return value
                } ?? "mp4"
                guard let streamURL = makeXtreamStreamURL(
                    baseURL: serverURL,
                    username: username,
                    password: password,
                    path: ["movie", username, password, "\(vodID).\(ext)"]
                ) else { return nil }
                return MediaModels.Item(
                    id: vodID,
                    title: movieData.name ?? dto.info?.name ?? vodID,
                    streamURL: streamURL,
                    coverURL: dto.info?.movieImage.flatMap(URL.init(string:)),
                    categoryID: "",
                    type: .vod,
                    userAgentOverride: config.userAgentOverride
                )
            },
            fetchShortEPG: { config, streamID, limit in
                @Dependency(\.xmltvParser) var xmltvParser
                if config.type == .m3u {
                    _ = await ensureM3UCache(config)
                    let cacheKey = m3uCacheKey(config)
                    guard let epgURL = await m3uCache.getEpgURL(for: cacheKey) else {
                        throw NetworkError.underlying(description: "This M3U playlist has no EPG source.")
                    }
                    var currentXMLTV = await m3uCache.getXmltvData(for: cacheKey)
                    if currentXMLTV == nil {
                        let data = try await networkClient.fetchData(url: epgURL, userAgentOverride: config.userAgentOverride)
                        currentXMLTV = try await xmltvParser.parse(data)
                        if let parsed = currentXMLTV {
                            await m3uCache.setXmltvData(parsed, for: cacheKey)
                        }
                    }
                    guard let xmlData = currentXMLTV else {
                        throw NetworkError.decodingFailed(description: "The XMLTV source could not be parsed.")
                    }

                    let now = Date()
                    let programmes = xmlData.programmes[streamID] ?? []
                    return programmes.map { p in
                        EPGProgram(
                            id: "m3u-\(streamID)-\(Int(p.start.timeIntervalSince1970))-\(Int(p.end.timeIntervalSince1970))",
                            title: p.title,
                            description: p.description,
                            startTime: p.start,
                            endTime: p.end,
                            isPlayingNow: p.start <= now && p.end >= now,
                            categories: p.categories
                        )
                    }
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else {
                    throw NetworkError.invalidResponse
                }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)

                var response: [EPGItemDTO] = []
                var receivedValidResponse = false
                var lastRequestError: Error = NetworkError.invalidResponse

                // Strategy 1: Attempt action=get_short_epg
                do {
                    let url = try XtreamEndpoint.getShortEPG(streamID: streamID, limit: limit).url(with: xtreamConfig)
                    let data = try await networkClient.fetchData(url: url, userAgentOverride: config.userAgentOverride)
                    response = try decodeEPGItems(data)
                    receivedValidResponse = true
                } catch {
                    lastRequestError = error
                }

                // Strategy 2: If empty, attempt action=get_simple_data_table
                if response.isEmpty {
                    do {
                        let url = try XtreamEndpoint.getEPGDataTable(streamID: streamID).url(with: xtreamConfig)
                        let data = try await networkClient.fetchData(url: url, userAgentOverride: config.userAgentOverride)
                        response = try decodeEPGItems(data)
                        receivedValidResponse = true
                    } catch {
                        lastRequestError = error
                    }
                }

                // Strategy 3: If still empty, check mapped XMLTV sources via CustomEPGMappingClient
                if response.isEmpty {
                    @Dependency(\.customEPGMappingClient) var customEPGMappingClient
                    let customPrograms = await customEPGMappingClient.fetchProgramsForChannel(streamID, "", nil)
                    if !customPrograms.isEmpty {
                        return customPrograms
                    }
                    guard receivedValidResponse else { throw lastRequestError }
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
            refreshEPGCache: { config in
                guard config.type == .m3u else { return }
                @Dependency(\.xmltvParser) var xmltvParser
                _ = await ensureM3UCache(config)
                let cacheKey = m3uCacheKey(config)
                guard let epgURL = await m3uCache.getEpgURL(for: cacheKey) else {
                    throw NetworkError.underlying(description: "This M3U playlist has no EPG source.")
                }
                let data = try await networkClient.fetchData(
                    url: epgURL,
                    userAgentOverride: config.userAgentOverride
                )
                // Keep the current parsed XMLTV value intact until parsing has
                // completed successfully; malformed responses never evict the
                // last-good cache.
                let parsedXMLTV = try await xmltvParser.parse(data)
                try Task.checkCancellation()
                try await m3uCache.replaceXmltvData(parsedXMLTV, for: cacheKey)
            },
            searchCachedEPGPrograms: { config, query, channels, limit in
                guard config.type == .m3u, limit > 0 else { return [] }
                let cacheKey = m3uCacheKey(config)
                guard let xmlData = await m3uCache.getXmltvData(for: cacheKey) else { return [] }
                let terms = query
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
                    .split(whereSeparator: \.isWhitespace)
                    .map(String.init)
                guard !terms.isEmpty else { return [] }

                var channelByEPGID: [String: MediaModels.Item] = [:]
                var channelByNormalizedName: [String: MediaModels.Item] = [:]
                for channel in channels where channel.type == .live {
                    if let epgID = channel.epgChannelID, !epgID.isEmpty {
                        channelByEPGID[epgID] = channel
                    }
                    channelByEPGID[channel.id] = channel
                    let name = channel.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
                    channelByNormalizedName[name] = channel
                }

                var results: [CachedEPGProgramMatch] = []
                let now = Date()
                var scannedProgrammes = 0
                for epgID in xmlData.programmes.keys.sorted() {
                    guard !Task.isCancelled, scannedProgrammes < 50000 else { break }
                    let programmes = xmlData.programmes[epgID] ?? []
                    let channel = channelByEPGID[epgID] ?? xmlData.channels[epgID].flatMap { epgChannel in
                        channelByNormalizedName[epgChannel.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))]
                    }
                    guard let channel else { continue }
                    for programme in programmes {
                        scannedProgrammes += 1
                        if scannedProgrammes.isMultiple(of: 64), Task.isCancelled {
                            return []
                        }
                        if scannedProgrammes > 50000 {
                            break
                        }
                        let searchable = (programme.title + " " + programme.description)
                            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
                        guard terms.allSatisfy({ searchable.localizedStandardContains($0) }) else { continue }
                        results.append(CachedEPGProgramMatch(
                            program: EPGProgram(
                                id: "m3u-\(epgID)-\(Int(programme.start.timeIntervalSince1970))-\(Int(programme.end.timeIntervalSince1970))",
                                title: programme.title,
                                description: programme.description,
                                startTime: programme.start,
                                endTime: programme.end,
                                isPlayingNow: programme.start <= now && programme.end >= now,
                                categories: programme.categories
                            ),
                            channel: channel
                        ))
                        if results.count >= max(limit * 4, limit) {
                            break
                        }
                    }
                    if results.count >= max(limit * 4, limit) {
                        break
                    }
                }
                return Array(results.sorted { lhs, rhs in
                    let lhsLive = lhs.program.startTime <= now && lhs.program.endTime >= now
                    let rhsLive = rhs.program.startTime <= now && rhs.program.endTime >= now
                    if lhsLive != rhsLive {
                        return lhsLive
                    }
                    if lhs.program.startTime != rhs.program.startTime {
                        return lhs.program.startTime < rhs.program.startTime
                    }
                    return lhs.program.title.localizedStandardCompare(rhs.program.title) == .orderedAscending
                }.prefix(limit))
            }
        )
    }()

    public static let testValue = IPTVClient(
        authenticate: { _ in },
        fetchLiveCategories: { _ in [] },
        fetchM3UCategoryTags: { _ in [] },
        fetchLiveChannels: { _, _ in [] },
        resolveLiveItem: { _, _, _ in nil },
        fetchVODCategories: { _ in [] },
        fetchVODs: { _, _ in [] },
        fetchSeriesCategories: { _ in [] },
        fetchSeries: { _, _ in [] },
        fetchSeriesInfo: { _, _ in (DetailModels.Info(), [], []) },
        fetchVODInfo: { _, _ in DetailModels.Info() },
        resolveVODItem: { _, _, _ in nil },
        fetchShortEPG: { _, _, _ in [] },
        refreshEPGCache: { _ in },
        searchCachedEPGPrograms: { _, _, _, _ in [] }
    )
}

public struct CachedEPGProgramMatch: Equatable, Sendable, Identifiable {
    public let program: EPGProgram
    public let channel: MediaModels.Item
    public var id: String {
        program.id + "|" + channel.id
    }

    public init(program: EPGProgram, channel: MediaModels.Item) {
        self.program = program
        self.channel = channel
    }
}

public extension DependencyValues {
    var iptvClient: IPTVClient {
        get { self[IPTVClient.self] }
        set { self[IPTVClient.self] = newValue }
    }
}
