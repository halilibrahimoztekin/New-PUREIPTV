import Foundation

/// Read-only catalog and playback resolution for authenticated Plex and Emby servers.
/// IDs and URLs returned here never contain access tokens; credentials are applied only
/// when a request is constructed.
public struct MediaServerCatalogClient: Sendable {
    public var validate: @Sendable (_ config: PlaylistConfig) async throws -> Void
    public var fetchCategories: @Sendable (_ config: PlaylistConfig, _ type: MediaModels.ItemType) async throws -> [MediaModels.Category]
    public var fetchItems: @Sendable (_ config: PlaylistConfig, _ type: MediaModels.ItemType, _ categoryID: String?) async throws -> [MediaModels.Item]
    public var search: @Sendable (_ config: PlaylistConfig, _ query: String) async throws -> (vods: [MediaModels.Item], series: [MediaModels.Item])
    public var fetchSeriesInfo: @Sendable (_ config: PlaylistConfig, _ seriesID: String) async throws -> (info: DetailModels.Info, seasons: [DetailModels.Season], episodes: [DetailModels.Episode])
    public var fetchVODInfo: @Sendable (_ config: PlaylistConfig, _ itemID: String) async throws -> DetailModels.Info
    public var resolvePlaybackItem: @Sendable (_ config: PlaylistConfig, _ itemID: String) async throws -> MediaModels.Item?
    public var invalidate: @Sendable (_ config: PlaylistConfig, _ type: MediaModels.ItemType?) async -> Void

    public init(
        validate: @escaping @Sendable (PlaylistConfig) async throws -> Void,
        fetchCategories: @escaping @Sendable (PlaylistConfig, MediaModels.ItemType) async throws -> [MediaModels.Category],
        fetchItems: @escaping @Sendable (PlaylistConfig, MediaModels.ItemType, String?) async throws -> [MediaModels.Item],
        search: @escaping @Sendable (PlaylistConfig, String) async throws -> (vods: [MediaModels.Item], series: [MediaModels.Item]),
        fetchSeriesInfo: @escaping @Sendable (PlaylistConfig, String) async throws -> (info: DetailModels.Info, seasons: [DetailModels.Season], episodes: [DetailModels.Episode]),
        fetchVODInfo: @escaping @Sendable (PlaylistConfig, String) async throws -> DetailModels.Info,
        resolvePlaybackItem: @escaping @Sendable (PlaylistConfig, String) async throws -> MediaModels.Item?,
        invalidate: @escaping @Sendable (PlaylistConfig, MediaModels.ItemType?) async -> Void
    ) {
        self.validate = validate
        self.fetchCategories = fetchCategories
        self.fetchItems = fetchItems
        self.search = search
        self.fetchSeriesInfo = fetchSeriesInfo
        self.fetchVODInfo = fetchVODInfo
        self.resolvePlaybackItem = resolvePlaybackItem
        self.invalidate = invalidate
    }

    public static let liveValue: Self = {
        let networkClient = NetworkClient()
        let cache = MediaServerCatalogCache()

        let connection: @Sendable (PlaylistConfig) throws -> MediaServerConnection = { config in
            guard config.type == .plex || config.type == .emby,
                  let baseURL = MediaServerRequestContextFactory.baseURL(for: config),
                  let context = MediaServerRequestContextFactory.context(for: config),
                  let credentials = config.mediaServerCredentials,
                  let serverID = MediaServerIdentifier.validated(credentials.serverID)
            else { throw NetworkError.invalidURL }
            MediaServerRequestContextFactory.register(config)
            let userID = credentials.userID.flatMap(MediaServerIdentifier.validated)
            if config.type == .emby, userID == nil {
                throw NetworkError.invalidURL
            }
            return MediaServerConnection(
                provider: config.type,
                baseURL: baseURL,
                serverID: serverID,
                userID: userID,
                context: context,
                playlistID: config.playlistID
            )
        }

        let validate: @Sendable (PlaylistConfig) async throws -> Void = { config in
            let server = try connection(config)
            switch server.provider {
            case .plex:
                _ = try await fetchPlexLibraries(server, networkClient: networkClient)
            case .emby:
                _ = try await fetchEmbyViews(server, networkClient: networkClient)
            case .xtream, .m3u:
                throw NetworkError.invalidURL
            }
        }

        let fetchCategories: @Sendable (PlaylistConfig, MediaModels.ItemType) async throws -> [MediaModels.Category] = { config, itemType in
            guard itemType == .vod || itemType == .series else { return [] }
            let server = try connection(config)
            let key = server.cacheKey(type: itemType, categoryID: nil)
            if let cached = await cache.categories(for: key) {
                return cached
            }
            let categories: [MediaModels.Category]
            switch server.provider {
            case .plex:
                let libraries = try await fetchPlexLibraries(server, networkClient: networkClient)
                let wantedType = itemType == .vod ? "movie" : "show"
                categories = libraries.compactMap { library in
                    guard library.type?.lowercased() == wantedType,
                          let rawID = MediaServerIdentifier.validated(library.key)
                    else { return nil }
                    return MediaModels.Category(
                        id: MediaServerIdentifier.stableID(provider: server.provider, serverID: server.serverID, itemID: rawID),
                        name: library.title
                    )
                }
            case .emby:
                let views = try await fetchEmbyViews(server, networkClient: networkClient)
                let wantedType = itemType == .vod ? "movies" : "tvshows"
                categories = views.compactMap { view in
                    guard view.collectionType?.lowercased() == wantedType,
                          let rawID = MediaServerIdentifier.validated(view.id)
                    else { return nil }
                    return MediaModels.Category(
                        id: MediaServerIdentifier.stableID(provider: server.provider, serverID: server.serverID, itemID: rawID),
                        name: view.name ?? "Library"
                    )
                }
            case .xtream, .m3u:
                categories = []
            }
            await cache.store(categories, for: key)
            return categories
        }

        let fetchItems: @Sendable (PlaylistConfig, MediaModels.ItemType, String?) async throws -> [MediaModels.Item] = { config, itemType, categoryID in
            guard itemType == .vod || itemType == .series else { return [] }
            let server = try connection(config)
            let key = server.cacheKey(type: itemType, categoryID: categoryID)
            if let cached = await cache.items(for: key) {
                return cached
            }
            let items: [MediaModels.Item] = switch server.provider {
            case .plex:
                try await fetchPlexItems(
                    server,
                    type: itemType,
                    categoryID: categoryID,
                    networkClient: networkClient
                )
            case .emby:
                try await fetchEmbyItems(
                    server,
                    type: itemType,
                    categoryID: categoryID,
                    networkClient: networkClient
                )
            case .xtream, .m3u:
                []
            }
            await cache.store(items, for: key)
            return items
        }

        let search: @Sendable (PlaylistConfig, String) async throws -> (vods: [MediaModels.Item], series: [MediaModels.Item]) = { config, query in
            let server = try connection(config)
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedQuery.isEmpty, trimmedQuery.count <= 120 else { return ([], []) }
            let normalizedQuery = FuzzySearchEngine.normalize(trimmedQuery)
            guard !normalizedQuery.isEmpty else { return ([], []) }
            let key = "\(server.playlistID?.uuidString ?? server.serverID)|\(server.provider.rawValue)|\(server.serverID)|search|\(normalizedQuery)"
            if let cached = await cache.search(for: key) {
                return cached
            }
            let results: (vods: [MediaModels.Item], series: [MediaModels.Item]) = switch server.provider {
            case .plex:
                try await fetchPlexSearch(server, query: trimmedQuery, networkClient: networkClient)
            case .emby:
                try await fetchEmbySearch(server, query: trimmedQuery, networkClient: networkClient)
            case .xtream, .m3u:
                ([], [])
            }
            try Task.checkCancellation()
            await cache.storeSearch(results, for: key)
            return results
        }

        let fetchSeriesInfo: @Sendable (PlaylistConfig, String) async throws -> (info: DetailModels.Info, seasons: [DetailModels.Season], episodes: [DetailModels.Episode]) = { config, seriesID in
            let server = try connection(config)
            guard let rawSeriesID = MediaServerIdentifier.rawItemID(seriesID, provider: server.provider, serverID: server.serverID) else {
                throw NetworkError.invalidURL
            }
            switch server.provider {
            case .plex:
                let show = try await fetchPlexMetadata(server, itemID: rawSeriesID, networkClient: networkClient)
                let seasonMetadata = try await fetchPlexChildren(server, itemID: rawSeriesID, networkClient: networkClient)
                    .filter { $0.type?.lowercased() == "season" }
                var seasons: [DetailModels.Season] = []
                var episodes: [DetailModels.Episode] = []
                for seasonMetadata in seasonMetadata {
                    guard let seasonID = seasonMetadata.ratingKey.flatMap(MediaServerIdentifier.validated) else { continue }
                    let number = seasonMetadata.index ?? seasonMetadata.parentIndex ?? 0
                    seasons.append(DetailModels.Season(
                        id: MediaServerIdentifier.stableID(provider: server.provider, serverID: server.serverID, itemID: seasonID),
                        seasonNumber: max(0, number),
                        name: seasonMetadata.title ?? "Season \(number)",
                        episodeCount: seasonMetadata.childCount
                    ))
                    let seasonEpisodes = try await fetchPlexChildren(server, itemID: seasonID, networkClient: networkClient)
                        .filter { $0.type?.lowercased() == "episode" }
                    episodes.append(contentsOf: seasonEpisodes.compactMap { episode -> DetailModels.Episode? in
                        guard let episodeID = episode.ratingKey.flatMap(MediaServerIdentifier.validated) else { return nil }
                        return DetailModels.Episode(
                            id: MediaServerIdentifier.stableID(provider: server.provider, serverID: server.serverID, itemID: episodeID),
                            episodeNum: max(0, episode.index ?? 0),
                            title: episode.title ?? "Episode",
                            streamURL: placeholderURL(server, path: ["library", "metadata", episodeID]),
                            coverURL: episode.thumb.flatMap { providerURL($0, server: server) },
                            season: max(0, number),
                            duration: episode.durationMilliseconds.flatMap(formatMilliseconds),
                            plot: episode.summary,
                            rating: episode.rating,
                            addedDate: episode.addedAt.map(Date.init(timeIntervalSince1970:)),
                            releaseDate: parseISODate(episode.originallyAvailableAt)
                        )
                    })
                }
                return (
                    info: plexInfo(show),
                    seasons: seasons.sorted { $0.seasonNumber < $1.seasonNumber },
                    episodes: episodes.sorted { ($0.season, $0.episodeNum) < ($1.season, $1.episodeNum) }
                )
            case .emby:
                let show = try await fetchEmbyItem(server, itemID: rawSeriesID, networkClient: networkClient)
                var seasonItems: [EmbyItem] = []
                var seasonStart = 0
                while seasonStart < 20000 {
                    try Task.checkCancellation()
                    let page = try await fetchEmbyPage(
                        server,
                        path: ["Shows", rawSeriesID, "Seasons"],
                        query: [URLQueryItem(name: "UserId", value: server.userID)],
                        startIndex: seasonStart,
                        networkClient: networkClient
                    )
                    guard !page.items.isEmpty else { break }
                    seasonItems.append(contentsOf: page.items)
                    seasonStart += page.items.count
                    if let total = page.totalRecordCount, seasonStart >= total {
                        break
                    }
                    if page.totalRecordCount == nil, page.items.count < 200 {
                        break
                    }
                }
                var seasons: [DetailModels.Season] = []
                var episodes: [DetailModels.Episode] = []
                for seasonItem in seasonItems {
                    guard let seasonID = seasonItem.id.flatMap(MediaServerIdentifier.validated) else { continue }
                    let seasonNumber = max(0, seasonItem.indexNumber ?? seasonItem.parentIndexNumber ?? 0)
                    seasons.append(DetailModels.Season(
                        id: MediaServerIdentifier.stableID(provider: server.provider, serverID: server.serverID, itemID: seasonID),
                        seasonNumber: seasonNumber,
                        name: seasonItem.name ?? "Season \(seasonNumber)",
                        episodeCount: seasonItem.childCount
                    ))
                    let seasonEpisodes = try await fetchEmbyItems(
                        server,
                        path: ["Shows", rawSeriesID, "Episodes"],
                        query: [URLQueryItem(name: "SeasonId", value: seasonID)],
                        itemType: .series,
                        networkClient: networkClient
                    )
                    episodes.append(contentsOf: seasonEpisodes.compactMap { episode -> DetailModels.Episode? in
                        guard let episodeID = episode.id.flatMap(MediaServerIdentifier.validated) else { return nil }
                        return DetailModels.Episode(
                            id: MediaServerIdentifier.stableID(provider: server.provider, serverID: server.serverID, itemID: episodeID),
                            episodeNum: max(0, episode.indexNumber ?? 0),
                            title: episode.name ?? "Episode",
                            streamURL: placeholderURL(server, path: ["Videos", episodeID, "stream.mp4"]),
                            coverURL: embyImageURL(server, itemID: episodeID),
                            season: seasonNumber,
                            duration: episode.runTimeTicks.flatMap(formatTicks),
                            plot: episode.overview,
                            rating: episode.communityRating,
                            addedDate: parseISODate(episode.dateCreated),
                            releaseDate: parseISODate(episode.premiereDate)
                        )
                    })
                }
                return (
                    info: embyInfo(show),
                    seasons: seasons.sorted { $0.seasonNumber < $1.seasonNumber },
                    episodes: episodes.sorted { ($0.season, $0.episodeNum) < ($1.season, $1.episodeNum) }
                )
            case .xtream, .m3u:
                throw NetworkError.invalidURL
            }
        }

        let fetchVODInfo: @Sendable (PlaylistConfig, String) async throws -> DetailModels.Info = { config, itemID in
            let server = try connection(config)
            guard let rawItemID = MediaServerIdentifier.rawItemID(itemID, provider: server.provider, serverID: server.serverID) else {
                throw NetworkError.invalidURL
            }
            switch server.provider {
            case .plex:
                return try await plexInfo(fetchPlexMetadata(server, itemID: rawItemID, networkClient: networkClient))
            case .emby:
                return try await embyInfo(fetchEmbyItem(server, itemID: rawItemID, networkClient: networkClient))
            case .xtream, .m3u: throw NetworkError.invalidURL
            }
        }

        let resolvePlaybackItem: @Sendable (PlaylistConfig, String) async throws -> MediaModels.Item? = { config, itemID in
            let server = try connection(config)
            guard let rawItemID = MediaServerIdentifier.rawItemID(itemID, provider: server.provider, serverID: server.serverID) else {
                return nil
            }
            switch server.provider {
            case .plex:
                let metadata = try await fetchPlexMetadata(server, itemID: rawItemID, networkClient: networkClient)
                guard let partKey = metadata.media?.lazy.flatMap(\.parts).compactMap(\.key).first,
                      let streamURL = providerURL(partKey, server: server)
                else { throw NetworkError.invalidResponse }
                return plexMediaItem(metadata, server: server, categoryID: metadata.librarySectionID, streamURL: streamURL, itemType: metadata.type?.lowercased() == "show" ? .series : .vod)
            case .emby:
                let metadata = try await fetchEmbyItem(server, itemID: rawItemID, networkClient: networkClient)
                let playback = try await fetchEmbyPlaybackURL(
                    server,
                    itemID: rawItemID,
                    preference: config.mediaServerPlaybackPreference,
                    networkClient: networkClient
                )
                let itemType: MediaModels.ItemType = metadata.type?.lowercased() == "series" ? .series : .vod
                return embyMediaItem(
                    metadata,
                    server: server,
                    categoryID: metadata.parentID,
                    streamURL: playback.url,
                    itemType: itemType,
                    playbackRequestHeaders: playback.headers,
                    serverPlaybackStatus: playback.status
                )
            case .xtream, .m3u:
                return nil
            }
        }

        return Self(
            validate: validate,
            fetchCategories: fetchCategories,
            fetchItems: fetchItems,
            search: search,
            fetchSeriesInfo: fetchSeriesInfo,
            fetchVODInfo: fetchVODInfo,
            resolvePlaybackItem: resolvePlaybackItem,
            invalidate: { config, itemType in await cache.invalidate(playlistID: config.playlistID, itemType: itemType) }
        )
    }()
}

private nonisolated struct MediaServerConnection: Sendable {
    let provider: PlaylistType
    let baseURL: URL
    let serverID: String
    let userID: String?
    let context: MediaServerRequestContext
    let playlistID: UUID?

    func cacheKey(type: MediaModels.ItemType, categoryID: String?) -> String {
        "\(playlistID?.uuidString ?? serverID)|\(provider.rawValue)|\(serverID)|\(type.rawValue)|\(categoryID ?? "all")"
    }
}

private actor MediaServerCatalogCache {
    private nonisolated struct CategoryEntry {
        let expiresAt: Date
        let value: [MediaModels.Category]
    }

    private nonisolated struct ItemEntry {
        let expiresAt: Date
        let value: [MediaModels.Item]
    }

    private nonisolated struct SearchEntry {
        let expiresAt: Date
        let value: MediaServerSearchResults
    }

    private var categories: [String: CategoryEntry] = [:]
    private var items: [String: ItemEntry] = [:]
    private var searches: [String: SearchEntry] = [:]
    private let lifetime: TimeInterval = 90
    private let categoryEntryLimit = 64
    private let itemEntryLimit = 8
    private let searchEntryLimit = 20

    func categories(for key: String) -> [MediaModels.Category]? {
        pruneExpiredEntries(at: Date())
        guard let entry = categories[key], entry.expiresAt > Date() else {
            categories[key] = nil
            return nil
        }
        return entry.value
    }

    func items(for key: String) -> [MediaModels.Item]? {
        pruneExpiredEntries(at: Date())
        guard let entry = items[key], entry.expiresAt > Date() else {
            items[key] = nil
            return nil
        }
        return entry.value
    }

    func search(for key: String) -> (vods: [MediaModels.Item], series: [MediaModels.Item])? {
        pruneExpiredEntries(at: Date())
        guard let entry = searches[key], entry.expiresAt > Date() else {
            searches[key] = nil
            return nil
        }
        return (entry.value.vods, entry.value.series)
    }

    func store(_ value: [MediaModels.Category], for key: String) {
        let now = Date()
        pruneExpiredEntries(at: now)
        if categories.count >= categoryEntryLimit, categories[key] == nil,
           let oldestKey = categories.min(by: { $0.value.expiresAt < $1.value.expiresAt })?.key
        {
            categories[oldestKey] = nil
        }
        categories[key] = CategoryEntry(expiresAt: now.addingTimeInterval(lifetime), value: value)
    }

    func store(_ value: [MediaModels.Item], for key: String) {
        let now = Date()
        pruneExpiredEntries(at: now)
        if items.count >= itemEntryLimit, items[key] == nil,
           let oldestKey = items.min(by: { $0.value.expiresAt < $1.value.expiresAt })?.key
        {
            items[oldestKey] = nil
        }
        items[key] = ItemEntry(expiresAt: now.addingTimeInterval(lifetime), value: value)
    }

    func storeSearch(_ value: (vods: [MediaModels.Item], series: [MediaModels.Item]), for key: String) {
        let now = Date()
        pruneExpiredEntries(at: now)
        if searches.count >= searchEntryLimit, searches[key] == nil,
           let oldestKey = searches.min(by: { $0.value.expiresAt < $1.value.expiresAt })?.key
        {
            searches[oldestKey] = nil
        }
        searches[key] = SearchEntry(
            expiresAt: now.addingTimeInterval(lifetime),
            value: MediaServerSearchResults(vods: value.vods, series: value.series)
        )
    }

    private func pruneExpiredEntries(at date: Date) {
        categories = categories.filter { $0.value.expiresAt > date }
        items = items.filter { $0.value.expiresAt > date }
        searches = searches.filter { $0.value.expiresAt > date }
    }

    func invalidate(playlistID: UUID?, itemType: MediaModels.ItemType?) {
        let playlistPrefix = playlistID?.uuidString
        if let playlistPrefix {
            categories = categories.filter { !$0.key.hasPrefix(playlistPrefix) }
            items = items.filter { !$0.key.hasPrefix(playlistPrefix) }
            searches = searches.filter { !$0.key.hasPrefix(playlistPrefix) }
        } else {
            categories.removeAll()
            items.removeAll()
            searches.removeAll()
        }
        _ = itemType
    }
}

private nonisolated struct MediaServerSearchResults: Sendable {
    let vods: [MediaModels.Item]
    let series: [MediaModels.Item]
}

private nonisolated enum MediaServerIdentifier {
    static func validated(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 256,
              value.utf8.allSatisfy({ byte in
                  (48 ... 57).contains(byte) || (65 ... 90).contains(byte) || (97 ... 122).contains(byte)
                      || byte == 45 || byte == 46 || byte == 95
              }) else { return nil }
        return value
    }

    static func stableID(provider: PlaylistType, serverID: String, itemID: String) -> String {
        "\(provider.rawValue)|\(serverID)|\(itemID)"
    }

    static func rawItemID(_ stableID: String, provider: PlaylistType, serverID: String) -> String? {
        let prefix = "\(provider.rawValue)|\(serverID)|"
        guard stableID.hasPrefix(prefix) else { return nil }
        return validated(String(stableID.dropFirst(prefix.count)))
    }

    static func rawCategoryID(_ stableID: String, provider: PlaylistType, serverID: String) -> String? {
        rawItemID(stableID, provider: provider, serverID: serverID)
    }
}

private nonisolated func fetchPlexLibraries(
    _ server: MediaServerConnection,
    networkClient: NetworkClient
) async throws -> [PlexLibrarySection] {
    guard let url = serverURL(server.baseURL, path: ["library", "sections"]) else { throw NetworkError.invalidURL }
    var request = server.context.makeRequest(for: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let response: PlexContainerResponse = try await networkClient.fetch(request: request)
    return response.mediaContainer.directories
}

private nonisolated func fetchPlexItems(
    _ server: MediaServerConnection,
    type: MediaModels.ItemType,
    categoryID: String?,
    networkClient: NetworkClient
) async throws -> [MediaModels.Item] {
    let libraries = try await fetchPlexLibraries(server, networkClient: networkClient)
        .filter { $0.type?.lowercased() == (type == .vod ? "movie" : "show") }
    let selectedLibraries: [PlexLibrarySection]
    if let categoryID {
        guard let rawID = MediaServerIdentifier.rawCategoryID(categoryID, provider: server.provider, serverID: server.serverID) else { return [] }
        selectedLibraries = libraries.filter { $0.key == rawID }
    } else {
        selectedLibraries = libraries
    }

    var result: [MediaModels.Item] = []
    var seenIDs = Set<String>()
    for library in selectedLibraries {
        guard let sectionID = MediaServerIdentifier.validated(library.key) else { continue }
        var start = 0
        var total = Int.max
        while start < total, start < 20000 {
            try Task.checkCancellation()
            guard let url = serverURL(server.baseURL, path: ["library", "sections", sectionID, "all"]) else { throw NetworkError.invalidURL }
            var request = server.context.makeRequest(for: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(String(start), forHTTPHeaderField: "X-Plex-Container-Start")
            request.setValue("200", forHTTPHeaderField: "X-Plex-Container-Size")
            let page: PlexContainerResponse = try await networkClient.fetch(request: request)
            let metadata = page.mediaContainer.metadata
            total = page.mediaContainer.totalSize ?? (metadata.isEmpty ? 0 : start + metadata.count)
            for item in metadata {
                guard let rawID = MediaServerIdentifier.validated(item.ratingKey ?? item.id) else { continue }
                let stableID = MediaServerIdentifier.stableID(provider: server.provider, serverID: server.serverID, itemID: rawID)
                guard seenIDs.insert(stableID).inserted else { continue }
                let itemType: MediaModels.ItemType = type == .vod ? .vod : .series
                result.append(plexMediaItem(
                    item,
                    server: server,
                    categoryID: sectionID,
                    streamURL: placeholderURL(server, path: ["library", "metadata", rawID]),
                    itemType: itemType
                ))
            }
            guard !metadata.isEmpty else { break }
            start += metadata.count
            if metadata.count < 200, start < total {
                break
            }
        }
    }
    return result
}

private nonisolated func fetchPlexSearch(
    _ server: MediaServerConnection,
    query: String,
    networkClient: NetworkClient
) async throws -> (vods: [MediaModels.Item], series: [MediaModels.Item]) {
    guard let url = serverURL(server.baseURL, path: ["hubs", "search"], query: [
        URLQueryItem(name: "query", value: query),
        URLQueryItem(name: "limit", value: "100"),
    ]) else { throw NetworkError.invalidURL }
    var request = server.context.makeRequest(for: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let response: PlexHubSearchResponse = try await networkClient.fetch(request: request)
    var vods: [MediaModels.Item] = []
    var series: [MediaModels.Item] = []
    var seen = Set<String>()
    for hub in response.mediaContainer.hubs {
        for metadata in hub.metadata {
            try Task.checkCancellation()
            guard let itemID = MediaServerIdentifier.validated(metadata.ratingKey ?? metadata.id),
                  let type = metadata.type?.lowercased() else { continue }
            let itemType: MediaModels.ItemType
            switch type {
            case "movie": itemType = .vod
            case "show": itemType = .series
            default: continue
            }
            let item = plexMediaItem(
                metadata,
                server: server,
                categoryID: metadata.librarySectionID,
                streamURL: placeholderURL(server, path: ["library", "metadata", itemID]),
                itemType: itemType
            )
            guard seen.insert(item.id).inserted else { continue }
            if itemType == .vod, vods.count < 100 {
                vods.append(item)
            } else if itemType == .series, series.count < 100 {
                series.append(item)
            }
            if vods.count >= 100, series.count >= 100 {
                break
            }
        }
        if vods.count >= 100, series.count >= 100 {
            break
        }
    }
    return (vods, series)
}

private nonisolated func fetchEmbyViews(_ server: MediaServerConnection, networkClient: NetworkClient) async throws -> [EmbyItem] {
    guard let userID = server.userID,
          let url = serverURL(server.baseURL, path: ["Users", userID, "Views"]) else { throw NetworkError.invalidURL }
    var request = server.context.makeRequest(for: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("false", forHTTPHeaderField: "X-Emby-External-Content")
    let response: EmbyItemsResponse = try await networkClient.fetch(request: request)
    return response.items
}

private nonisolated func fetchEmbyItems(
    _ server: MediaServerConnection,
    type: MediaModels.ItemType,
    categoryID: String?,
    networkClient: NetworkClient
) async throws -> [MediaModels.Item] {
    let views = try await fetchEmbyViews(server, networkClient: networkClient)
        .filter { $0.collectionType?.lowercased() == (type == .vod ? "movies" : "tvshows") }
    let selectedViews: [EmbyItem]
    if let categoryID {
        guard let rawID = MediaServerIdentifier.rawCategoryID(categoryID, provider: server.provider, serverID: server.serverID) else { return [] }
        selectedViews = views.filter { $0.id == rawID }
    } else {
        selectedViews = views
    }

    var result: [MediaModels.Item] = []
    var seenIDs = Set<String>()
    let itemTypeName = type == .vod ? "Movie" : "Series"
    for view in selectedViews {
        guard let parentID = MediaServerIdentifier.validated(view.id) else { continue }
        let items = try await fetchEmbyItems(
            server,
            path: ["Users", server.userID ?? "", "Items"],
            query: [URLQueryItem(name: "ParentId", value: parentID)],
            itemTypeName: itemTypeName,
            networkClient: networkClient
        )
        for item in items {
            guard let rawID = MediaServerIdentifier.validated(item.id) else { continue }
            let stableID = MediaServerIdentifier.stableID(provider: server.provider, serverID: server.serverID, itemID: rawID)
            guard seenIDs.insert(stableID).inserted else { continue }
            result.append(embyMediaItem(
                item,
                server: server,
                categoryID: parentID,
                streamURL: placeholderURL(server, path: ["Videos", rawID, "stream.mp4"]),
                itemType: type
            ))
        }
    }
    return result
}

private nonisolated func fetchEmbySearch(
    _ server: MediaServerConnection,
    query: String,
    networkClient: NetworkClient
) async throws -> (vods: [MediaModels.Item], series: [MediaModels.Item]) {
    let views = try await fetchEmbyViews(server, networkClient: networkClient)
    let movieViews = views.filter { $0.collectionType?.lowercased() == "movies" }
    let seriesViews = views.filter { $0.collectionType?.lowercased() == "tvshows" }
    let vods = try await fetchEmbySearchItems(
        server,
        query: query,
        views: movieViews,
        itemType: .vod,
        networkClient: networkClient
    )
    let series = try await fetchEmbySearchItems(
        server,
        query: query,
        views: seriesViews,
        itemType: .series,
        networkClient: networkClient
    )
    return (vods, series)
}

private nonisolated func fetchEmbySearchItems(
    _ server: MediaServerConnection,
    query: String,
    views: [EmbyItem],
    itemType: MediaModels.ItemType,
    networkClient: NetworkClient
) async throws -> [MediaModels.Item] {
    guard let userID = server.userID else { throw NetworkError.invalidURL }
    var result: [MediaModels.Item] = []
    var seen = Set<String>()
    for view in views {
        guard let viewID = MediaServerIdentifier.validated(view.id) else { continue }
        var start = 0
        var total = Int.max
        while start < total, start < 200, result.count < 100 {
            try Task.checkCancellation()
            guard let url = serverURL(server.baseURL, path: ["Users", userID, "Items"], query: [
                URLQueryItem(name: "ParentId", value: viewID),
                URLQueryItem(name: "SearchTerm", value: query),
                URLQueryItem(name: "Recursive", value: "true"),
                URLQueryItem(name: "IncludeItemTypes", value: itemType == .vod ? "Movie" : "Series"),
                URLQueryItem(name: "Fields", value: "Overview,DateCreated,Genres,MediaSources,ProviderIds,RunTimeTicks,People"),
                URLQueryItem(name: "StartIndex", value: String(start)),
                URLQueryItem(name: "Limit", value: "50"),
            ]) else { throw NetworkError.invalidURL }
            var request = server.context.makeRequest(for: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let page: EmbyItemsResponse = try await networkClient.fetch(request: request)
            total = page.totalRecordCount ?? (page.items.isEmpty ? 0 : start + page.items.count)
            for item in page.items {
                guard let rawID = MediaServerIdentifier.validated(item.id),
                      item.type?.caseInsensitiveCompare(itemType == .vod ? "Movie" : "Series") == .orderedSame else { continue }
                let mapped = embyMediaItem(
                    item,
                    server: server,
                    categoryID: viewID,
                    streamURL: placeholderURL(server, path: ["Videos", rawID, "stream.mp4"]),
                    itemType: itemType
                )
                if seen.insert(mapped.id).inserted {
                    result.append(mapped)
                    if result.count == 100 {
                        break
                    }
                }
            }
            guard !page.items.isEmpty else { break }
            start += page.items.count
            if page.items.count < 50, start < total {
                break
            }
        }
        if result.count >= 100 {
            break
        }
    }
    return result
}

private nonisolated func fetchEmbyItems(
    _ server: MediaServerConnection,
    path: [String],
    query: [URLQueryItem],
    itemType: MediaModels.ItemType,
    networkClient: NetworkClient
) async throws -> [EmbyItem] {
    try await fetchEmbyItems(
        server,
        path: path,
        query: query,
        itemTypeName: itemType == .vod ? "Movie" : "Episode",
        networkClient: networkClient
    )
}

private nonisolated func fetchEmbyItems(
    _ server: MediaServerConnection,
    path: [String],
    query: [URLQueryItem],
    itemTypeName: String,
    networkClient: NetworkClient
) async throws -> [EmbyItem] {
    var start = 0
    var total = Int.max
    var result: [EmbyItem] = []
    while start < total, start < 20000 {
        try Task.checkCancellation()
        var pageQuery = query
        pageQuery.append(contentsOf: [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "IncludeItemTypes", value: itemTypeName),
            URLQueryItem(name: "Fields", value: "Overview,DateCreated,Genres,MediaSources,ProviderIds,RunTimeTicks,People"),
            URLQueryItem(name: "StartIndex", value: String(start)),
            URLQueryItem(name: "Limit", value: "200"),
        ])
        guard let url = serverURL(server.baseURL, path: path, query: pageQuery) else { throw NetworkError.invalidURL }
        var request = server.context.makeRequest(for: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let page: EmbyItemsResponse = try await networkClient.fetch(request: request)
        result.append(contentsOf: page.items)
        total = page.totalRecordCount ?? (page.items.isEmpty ? 0 : start + page.items.count)
        guard !page.items.isEmpty else { break }
        start += page.items.count
        if page.items.count < 200, start < total {
            break
        }
    }
    return result
}

private nonisolated func fetchEmbyPage(
    _ server: MediaServerConnection,
    path: [String],
    query: [URLQueryItem],
    startIndex: Int,
    networkClient: NetworkClient
) async throws -> EmbyItemsResponse {
    var query = query
    query.append(contentsOf: [
        URLQueryItem(name: "StartIndex", value: String(startIndex)),
        URLQueryItem(name: "Limit", value: "200"),
        URLQueryItem(name: "Fields", value: "Overview,DateCreated,Genres,MediaSources,ProviderIds,RunTimeTicks,People"),
    ])
    guard let url = serverURL(server.baseURL, path: path, query: query) else { throw NetworkError.invalidURL }
    var request = server.context.makeRequest(for: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return try await networkClient.fetch(request: request)
}

private nonisolated func fetchPlexMetadata(
    _ server: MediaServerConnection,
    itemID: String,
    networkClient: NetworkClient
) async throws -> PlexMetadata {
    guard let itemID = MediaServerIdentifier.validated(itemID),
          let url = serverURL(server.baseURL, path: ["library", "metadata", itemID]) else { throw NetworkError.invalidURL }
    var request = server.context.makeRequest(for: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let response: PlexContainerResponse = try await networkClient.fetch(request: request)
    guard let item = response.mediaContainer.metadata.first else { throw NetworkError.invalidResponse }
    return item
}

private nonisolated func fetchPlexChildren(
    _ server: MediaServerConnection,
    itemID: String,
    networkClient: NetworkClient
) async throws -> [PlexMetadata] {
    guard let itemID = MediaServerIdentifier.validated(itemID),
          let url = serverURL(server.baseURL, path: ["library", "metadata", itemID, "children"]) else { throw NetworkError.invalidURL }
    var request = server.context.makeRequest(for: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("0", forHTTPHeaderField: "X-Plex-Container-Start")
    request.setValue("1000", forHTTPHeaderField: "X-Plex-Container-Size")
    let response: PlexContainerResponse = try await networkClient.fetch(request: request)
    return response.mediaContainer.metadata
}

private nonisolated func fetchEmbyItem(
    _ server: MediaServerConnection,
    itemID: String,
    networkClient: NetworkClient
) async throws -> EmbyItem {
    guard let userID = server.userID,
          let itemID = MediaServerIdentifier.validated(itemID),
          let url = serverURL(server.baseURL, path: ["Users", userID, "Items", itemID], query: [
              URLQueryItem(name: "Fields", value: "Overview,DateCreated,Genres,MediaSources,ProviderIds,RunTimeTicks,People"),
          ]) else { throw NetworkError.invalidURL }
    var request = server.context.makeRequest(for: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    return try await networkClient.fetch(request: request)
}

private nonisolated func fetchEmbyPlaybackURL(
    _ server: MediaServerConnection,
    itemID: String,
    preference: MediaServerPlaybackPreference,
    networkClient: NetworkClient
) async throws -> (url: URL, headers: [String: String]?, status: MediaModels.ServerPlaybackStatus) {
    guard let userID = server.userID,
          let itemID = MediaServerIdentifier.validated(itemID),
          let url = serverURL(server.baseURL, path: ["Items", itemID, "PlaybackInfo"], query: [
              URLQueryItem(name: "UserId", value: userID),
          ]) else { throw NetworkError.invalidURL }
    var request = server.context.makeRequest(for: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if preference == .directStreamOnly {
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(EmbyPlaybackInfoRequest(
            id: itemID,
            userID: userID,
            enableDirectPlay: false,
            enableDirectStream: true,
            enableTranscoding: false,
            isPlayback: true
        ))
    }
    let response: EmbyPlaybackInfoResponse = try await networkClient.fetch(request: request)
    let source: EmbyMediaSource?
    if preference == .directStreamOnly {
        source = response.mediaSources.first(where: { $0.supportsDirectStream == true || $0.directStreamURL != nil })
        guard source != nil else { throw EmbyPlaybackResolutionError.directStreamUnavailable }
    } else {
        source = response.mediaSources.first
    }
    guard let source,
          let sourceID = MediaServerIdentifier.validated(source.id) else { throw NetworkError.invalidResponse }
    let playSessionID = MediaServerIdentifier.validated(response.playSessionID)
    let directURL = source.directStreamURL.flatMap { providerURL($0, server: server) }
    let transcodingURL = source.transcodingURL.flatMap { providerURL($0, server: server) }
    let playbackStatus: MediaModels.ServerPlaybackStatus
    if let directURL {
        playbackStatus = MediaModels.ServerPlaybackStatus(mode: .directStream, evidence: .playbackResponse)
        return (directURL, safeEmbyPlaybackHeaders(source.requiredHTTPHeaders), playbackStatus)
    }
    if preference == .automatic, let transcodingURL {
        playbackStatus = MediaModels.ServerPlaybackStatus(mode: .transcoding, evidence: .playbackResponse)
        return (transcodingURL, safeEmbyPlaybackHeaders(source.requiredHTTPHeaders), playbackStatus)
    }
    guard preference == .automatic || source.supportsDirectStream == true else {
        throw EmbyPlaybackResolutionError.directStreamUnavailable
    }
    let container = MediaServerIdentifier.validated(source.container?.lowercased()) ?? "mp4"
    var query = [
        URLQueryItem(name: "static", value: "true"),
        URLQueryItem(name: "MediaSourceId", value: sourceID),
    ]
    if let playSessionID {
        query.append(URLQueryItem(name: "PlaySessionId", value: playSessionID))
    }
    guard let streamURL = serverURL(server.baseURL, path: ["Videos", itemID, "stream.\(container)"], query: query),
          let safeURL = server.context.makeRequest(for: streamURL).url else { throw NetworkError.invalidURL }
    playbackStatus = MediaModels.ServerPlaybackStatus(mode: .directStream, evidence: .playbackResponse)
    return (safeURL, safeEmbyPlaybackHeaders(source.requiredHTTPHeaders), playbackStatus)
}

private nonisolated enum EmbyPlaybackResolutionError: LocalizedError {
    case directStreamUnavailable

    var errorDescription: String? {
        switch self {
        case .directStreamUnavailable:
            AppStrings.Player.directStreamUnavailable
        }
    }
}

private nonisolated func plexMediaItem(
    _ item: PlexMetadata,
    server: MediaServerConnection,
    categoryID: String?,
    streamURL: URL,
    itemType: MediaModels.ItemType
) -> MediaModels.Item {
    let rawID = MediaServerIdentifier.validated(item.ratingKey ?? item.id) ?? "unknown"
    return MediaModels.Item(
        id: MediaServerIdentifier.stableID(provider: server.provider, serverID: server.serverID, itemID: rawID),
        title: item.title ?? "Untitled",
        streamURL: streamURL,
        coverURL: item.thumb.flatMap { providerURL($0, server: server) },
        categoryID: categoryID.map { MediaServerIdentifier.stableID(provider: server.provider, serverID: server.serverID, itemID: $0) } ?? "",
        type: itemType,
        rating: item.rating,
        releaseDate: item.originallyAvailableAt ?? item.year.map(String.init),
        duration: item.durationMilliseconds.flatMap(formatMilliseconds),
        addedDate: item.addedAt.map(Date.init(timeIntervalSince1970:)),
        userAgentOverride: nil,
        playlistID: server.playlistID
    )
}

private nonisolated func embyMediaItem(
    _ item: EmbyItem,
    server: MediaServerConnection,
    categoryID: String?,
    streamURL: URL,
    itemType: MediaModels.ItemType,
    playbackRequestHeaders: [String: String]? = nil,
    serverPlaybackStatus: MediaModels.ServerPlaybackStatus? = nil
) -> MediaModels.Item {
    let rawID = MediaServerIdentifier.validated(item.id) ?? "unknown"
    return MediaModels.Item(
        id: MediaServerIdentifier.stableID(provider: server.provider, serverID: server.serverID, itemID: rawID),
        title: item.name ?? "Untitled",
        streamURL: streamURL,
        coverURL: embyImageURL(server, itemID: rawID),
        categoryID: categoryID.map { MediaServerIdentifier.stableID(provider: server.provider, serverID: server.serverID, itemID: $0) } ?? "",
        type: itemType,
        rating: item.communityRating,
        releaseDate: item.premiereDate ?? item.productionYear.map(String.init),
        duration: item.runTimeTicks.flatMap(formatTicks),
        addedDate: parseISODate(item.dateCreated),
        userAgentOverride: nil,
        playlistID: server.playlistID,
        playbackRequestHeaders: playbackRequestHeaders,
        serverPlaybackStatus: serverPlaybackStatus
    )
}

private nonisolated func safeEmbyPlaybackHeaders(_ headers: [String: String]?) -> [String: String]? {
    let blockedNames: Set = [
        "accept-encoding", "authorization", "connection", "content-length", "host", "proxy-authorization",
        "range", "transfer-encoding", "user-agent", "x-emby-authorization", "x-emby-token", "x-plex-token",
    ]
    let safeHeaders = headers?.filter { name, value in
        let normalizedName = name.lowercased()
        let validName = !name.isEmpty && name.count <= 128 && name.utf8.allSatisfy { byte in
            (48 ... 57).contains(byte) || (65 ... 90).contains(byte) || (97 ... 122).contains(byte) || byte == 45
        }
        return validName
            && !blockedNames.contains(normalizedName)
            && value.utf8.count <= 4096
            && !value.contains("\r")
            && !value.contains("\n")
    }
    return safeHeaders?.isEmpty == false ? safeHeaders : nil
}

private nonisolated func plexInfo(_ item: PlexMetadata) -> DetailModels.Info {
    let genres = item.genres.compactMap(\.tag).filter { !$0.isEmpty }
    let cast = item.roles.compactMap(\.tag).filter { !$0.isEmpty }
    let directors = item.directors.compactMap(\.tag).filter { !$0.isEmpty }
    return DetailModels.Info(
        plot: item.summary,
        cast: cast.isEmpty ? nil : cast.joined(separator: ", "),
        director: directors.isEmpty ? nil : directors.joined(separator: ", "),
        genre: genres.isEmpty ? nil : genres.joined(separator: ", "),
        duration: item.durationMilliseconds.flatMap(formatMilliseconds),
        rating: item.rating,
        releaseDate: item.originallyAvailableAt ?? item.year.map(String.init),
        genresList: genres.isEmpty ? nil : genres
    )
}

private nonisolated func embyInfo(_ item: EmbyItem) -> DetailModels.Info {
    let genres = item.genres.filter { !$0.isEmpty }
    let cast = item.people.filter { $0.type?.caseInsensitiveCompare("Actor") == .orderedSame }.compactMap(\.name)
    let directors = item.people.filter { $0.type?.caseInsensitiveCompare("Director") == .orderedSame }.compactMap(\.name)
    return DetailModels.Info(
        plot: item.overview,
        cast: cast.isEmpty ? nil : cast.joined(separator: ", "),
        director: directors.isEmpty ? nil : directors.joined(separator: ", "),
        genre: genres.isEmpty ? nil : genres.joined(separator: ", "),
        duration: item.runTimeTicks.flatMap(formatTicks),
        rating: item.communityRating,
        releaseDate: item.premiereDate ?? item.productionYear.map(String.init),
        genresList: genres.isEmpty ? nil : genres,
        imdbId: item.providerIDs?["Imdb"]
    )
}

private nonisolated func embyImageURL(_ server: MediaServerConnection, itemID: String) -> URL? {
    guard let url = serverURL(server.baseURL, path: ["Items", itemID, "Images", "Primary"]) else { return nil }
    return server.context.makeRequest(for: url).url
}

private nonisolated func placeholderURL(_ server: MediaServerConnection, path: [String]) -> URL {
    serverURL(server.baseURL, path: path) ?? server.baseURL
}

private nonisolated func providerURL(_ path: String, server: MediaServerConnection) -> URL? {
    guard !path.isEmpty else { return nil }
    let resolved: URL
    if let components = URLComponents(string: path), components.scheme != nil {
        guard components.host?.caseInsensitiveCompare(server.baseURL.host ?? "") == .orderedSame,
              components.user == nil, components.password == nil,
              let url = components.url else { return nil }
        resolved = url
    } else {
        let relativePath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: relativePath, relativeTo: server.baseURL)?.absoluteURL else { return nil }
        resolved = url
    }
    guard resolved.host?.caseInsensitiveCompare(server.baseURL.host ?? "") == .orderedSame,
          resolved.port == server.baseURL.port,
          resolved.scheme?.lowercased() == server.baseURL.scheme?.lowercased(),
          resolved.user == nil, resolved.password == nil
    else { return nil }
    return server.context.makeRequest(for: resolved).url
}

private nonisolated func serverURL(_ baseURL: URL, path: [String], query: [URLQueryItem] = []) -> URL? {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
    let encodedSegments = path.compactMap { $0.addingPercentEncoding(withAllowedCharacters: allowed) }
    guard encodedSegments.count == path.count,
          var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
    var basePath = components.percentEncodedPath
    if !basePath.hasSuffix("/") {
        basePath += "/"
    }
    components.percentEncodedPath = basePath + encodedSegments.joined(separator: "/")
    components.queryItems = query.isEmpty ? nil : query
    components.fragment = nil
    return components.url
}

private nonisolated func formatMilliseconds(_ milliseconds: Int64) -> String? {
    guard milliseconds > 0 else { return nil }
    return formatDuration(TimeInterval(milliseconds) / 1000)
}

private nonisolated func formatTicks(_ ticks: Int64) -> String? {
    guard ticks > 0 else { return nil }
    return formatDuration(TimeInterval(ticks) / 10_000_000)
}

private nonisolated func formatDuration(_ seconds: TimeInterval) -> String {
    let totalMinutes = max(1, Int(seconds / 60))
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
}

private nonisolated func parseISODate(_ value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    let formatter = ISO8601DateFormatter()
    if let date = formatter.date(from: value) {
        return date
    }
    formatter.formatOptions = [.withFullDate]
    return formatter.date(from: value)
}

private nonisolated struct PlexHubSearchResponse: Decodable {
    let mediaContainer: PlexHubSearchContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

private nonisolated struct PlexHubSearchContainer: Decodable {
    let hubs: [PlexSearchHub]

    enum CodingKeys: String, CodingKey {
        case hubs = "Hub"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hubs = try container.decodeIfPresent([PlexSearchHub].self, forKey: .hubs) ?? []
    }
}

private nonisolated struct PlexSearchHub: Decodable {
    let type: String?
    let metadata: [PlexMetadata]

    enum CodingKeys: String, CodingKey {
        case type
        case metadata = "Metadata"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeFlexibleString(forKey: .type)
        metadata = try container.decodeIfPresent([PlexMetadata].self, forKey: .metadata) ?? []
    }
}

private nonisolated struct PlexContainerResponse: Decodable {
    let mediaContainer: PlexContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}

private nonisolated struct PlexContainer: Decodable {
    let directories: [PlexLibrarySection]
    let metadata: [PlexMetadata]
    let totalSize: Int?

    enum CodingKeys: String, CodingKey {
        case directories = "Directory"
        case metadata = "Metadata"
        case totalSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        directories = try container.decodeIfPresent([PlexLibrarySection].self, forKey: .directories) ?? []
        metadata = try container.decodeIfPresent([PlexMetadata].self, forKey: .metadata) ?? []
        totalSize = try container.decodeFlexibleIntIfPresent(forKey: .totalSize)
    }
}

private nonisolated struct PlexLibrarySection: Decodable {
    let key: String
    let title: String
    let type: String?

    enum CodingKeys: String, CodingKey {
        case key
        case title
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decodeFlexibleString(forKey: .key) ?? ""
        title = try container.decodeFlexibleString(forKey: .title) ?? ""
        type = try container.decodeFlexibleString(forKey: .type)
    }
}

private nonisolated struct PlexMetadata: Decodable {
    let id: String?
    let ratingKey: String?
    let key: String?
    let type: String?
    let title: String?
    let thumb: String?
    let summary: String?
    let year: Int?
    let rating: Double?
    let originallyAvailableAt: String?
    let durationMilliseconds: Int64?
    let addedAt: TimeInterval?
    let index: Int?
    let parentIndex: Int?
    let childCount: Int?
    let librarySectionID: String?
    let media: [PlexMedia]?
    let genres: [PlexTag]
    let roles: [PlexTag]
    let directors: [PlexTag]

    enum CodingKeys: String, CodingKey {
        case id
        case ratingKey
        case key
        case type
        case title
        case thumb
        case summary
        case year
        case rating
        case originallyAvailableAt
        case durationMilliseconds = "duration"
        case addedAt
        case index
        case parentIndex
        case childCount
        case librarySectionID
        case media = "Media"
        case genres = "Genre"
        case roles = "Role"
        case directors = "Director"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        ratingKey = try container.decodeFlexibleString(forKey: .ratingKey)
        key = try container.decodeFlexibleString(forKey: .key)
        type = try container.decodeFlexibleString(forKey: .type)
        title = try container.decodeFlexibleString(forKey: .title)
        thumb = try container.decodeFlexibleString(forKey: .thumb)
        summary = try container.decodeFlexibleString(forKey: .summary)
        year = try container.decodeFlexibleIntIfPresent(forKey: .year)
        rating = try container.decodeFlexibleDoubleIfPresent(forKey: .rating)
        originallyAvailableAt = try container.decodeFlexibleString(forKey: .originallyAvailableAt)
        durationMilliseconds = try container.decodeFlexibleInt64IfPresent(forKey: .durationMilliseconds)
        addedAt = try container.decodeFlexibleDoubleIfPresent(forKey: .addedAt)
        index = try container.decodeFlexibleIntIfPresent(forKey: .index)
        parentIndex = try container.decodeFlexibleIntIfPresent(forKey: .parentIndex)
        childCount = try container.decodeFlexibleIntIfPresent(forKey: .childCount)
        librarySectionID = try container.decodeFlexibleString(forKey: .librarySectionID)
        media = try container.decodeIfPresent([PlexMedia].self, forKey: .media)
        genres = try container.decodeIfPresent([PlexTag].self, forKey: .genres) ?? []
        roles = try container.decodeIfPresent([PlexTag].self, forKey: .roles) ?? []
        directors = try container.decodeIfPresent([PlexTag].self, forKey: .directors) ?? []
    }
}

private nonisolated struct PlexMedia: Decodable {
    let parts: [PlexPart]

    enum CodingKeys: String, CodingKey { case parts = "Part" }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        parts = try container.decodeIfPresent([PlexPart].self, forKey: .parts) ?? []
    }
}

private nonisolated struct PlexPart: Decodable {
    let key: String?

    enum CodingKeys: String, CodingKey { case key }
}

private nonisolated struct PlexTag: Decodable {
    let tag: String?

    enum CodingKeys: String, CodingKey { case tag }
}

private nonisolated struct EmbyItemsResponse: Decodable {
    let items: [EmbyItem]
    let totalRecordCount: Int?

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([EmbyItem].self, forKey: .items) ?? []
        totalRecordCount = try container.decodeFlexibleIntIfPresent(forKey: .totalRecordCount)
    }
}

private nonisolated struct EmbyItem: Decodable {
    let id: String?
    let name: String?
    let type: String?
    let collectionType: String?
    let overview: String?
    let productionYear: Int?
    let communityRating: Double?
    let premiereDate: String?
    let dateCreated: String?
    let runTimeTicks: Int64?
    let parentID: String?
    let indexNumber: Int?
    let parentIndexNumber: Int?
    let childCount: Int?
    let genres: [String]
    let providerIDs: [String: String]?
    let people: [EmbyPerson]
    let mediaSources: [EmbyMediaSource]

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case collectionType = "CollectionType"
        case overview = "Overview"
        case productionYear = "ProductionYear"
        case communityRating = "CommunityRating"
        case premiereDate = "PremiereDate"
        case dateCreated = "DateCreated"
        case runTimeTicks = "RunTimeTicks"
        case parentID = "ParentId"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case childCount = "ChildCount"
        case genres = "Genres"
        case providerIDs = "ProviderIds"
        case people = "People"
        case mediaSources = "MediaSources"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        name = try container.decodeFlexibleString(forKey: .name)
        type = try container.decodeFlexibleString(forKey: .type)
        collectionType = try container.decodeFlexibleString(forKey: .collectionType)
        overview = try container.decodeFlexibleString(forKey: .overview)
        productionYear = try container.decodeFlexibleIntIfPresent(forKey: .productionYear)
        communityRating = try container.decodeFlexibleDoubleIfPresent(forKey: .communityRating)
        premiereDate = try container.decodeFlexibleString(forKey: .premiereDate)
        dateCreated = try container.decodeFlexibleString(forKey: .dateCreated)
        runTimeTicks = try container.decodeFlexibleInt64IfPresent(forKey: .runTimeTicks)
        parentID = try container.decodeFlexibleString(forKey: .parentID)
        indexNumber = try container.decodeFlexibleIntIfPresent(forKey: .indexNumber)
        parentIndexNumber = try container.decodeFlexibleIntIfPresent(forKey: .parentIndexNumber)
        childCount = try container.decodeFlexibleIntIfPresent(forKey: .childCount)
        genres = try container.decodeIfPresent([String].self, forKey: .genres) ?? []
        providerIDs = try container.decodeIfPresent([String: String].self, forKey: .providerIDs)
        people = try container.decodeIfPresent([EmbyPerson].self, forKey: .people) ?? []
        mediaSources = try container.decodeIfPresent([EmbyMediaSource].self, forKey: .mediaSources) ?? []
    }
}

private nonisolated struct EmbyPerson: Decodable {
    let name: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case type = "Type"
    }
}

private nonisolated struct EmbyMediaSource: Decodable {
    let id: String?
    let container: String?
    let supportsDirectPlay: Bool?
    let supportsDirectStream: Bool?
    let supportsTranscoding: Bool?
    let directStreamURL: String?
    let transcodingURL: String?
    let requiredHTTPHeaders: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case container = "Container"
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case supportsTranscoding = "SupportsTranscoding"
        case directStreamURL = "DirectStreamUrl"
        case transcodingURL = "TranscodingUrl"
        case requiredHTTPHeaders = "RequiredHttpHeaders"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        self.container = try container.decodeFlexibleString(forKey: .container)
        supportsDirectPlay = try container.decodeIfPresent(Bool.self, forKey: .supportsDirectPlay)
        supportsDirectStream = try container.decodeIfPresent(Bool.self, forKey: .supportsDirectStream)
        supportsTranscoding = try container.decodeIfPresent(Bool.self, forKey: .supportsTranscoding)
        directStreamURL = try container.decodeFlexibleString(forKey: .directStreamURL)
        transcodingURL = try container.decodeFlexibleString(forKey: .transcodingURL)
        requiredHTTPHeaders = try? container.decode([String: String].self, forKey: .requiredHTTPHeaders)
    }
}

private nonisolated struct EmbyPlaybackInfoRequest: Encodable {
    let id: String
    let userID: String
    let enableDirectPlay: Bool
    let enableDirectStream: Bool
    let enableTranscoding: Bool
    let isPlayback: Bool

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case userID = "UserId"
        case enableDirectPlay = "EnableDirectPlay"
        case enableDirectStream = "EnableDirectStream"
        case enableTranscoding = "EnableTranscoding"
        case isPlayback = "IsPlayback"
    }
}

private nonisolated struct EmbyPlaybackInfoResponse: Decodable {
    let playSessionID: String?
    let mediaSources: [EmbyMediaSource]

    enum CodingKeys: String, CodingKey {
        case playSessionID = "PlaySessionId"
        case mediaSources = "MediaSources"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playSessionID = try container.decodeFlexibleString(forKey: .playSessionID)
        mediaSources = try container.decodeIfPresent([EmbyMediaSource].self, forKey: .mediaSources) ?? []
    }
}

private extension KeyedDecodingContainer {
    nonisolated func decodeFlexibleString(forKey key: Key) throws -> String? {
        if let string = try? decode(String.self, forKey: key) {
            return string
        }
        if let integer = try? decode(Int64.self, forKey: key) {
            return String(integer)
        }
        if let number = try? decode(Double.self, forKey: key), number.isFinite {
            return String(number)
        }
        return nil
    }

    nonisolated func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    nonisolated func decodeFlexibleInt64IfPresent(forKey key: Key) throws -> Int64? {
        if let value = try? decode(Int64.self, forKey: key) {
            return value
        }
        if let value = try? decode(String.self, forKey: key) {
            return Int64(value)
        }
        return nil
    }

    nonisolated func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let value = try? decode(Double.self, forKey: key), value.isFinite {
            return value
        }
        if let value = try? decode(String.self, forKey: key), let parsed = Double(value), parsed.isFinite {
            return parsed
        }
        return nil
    }
}
