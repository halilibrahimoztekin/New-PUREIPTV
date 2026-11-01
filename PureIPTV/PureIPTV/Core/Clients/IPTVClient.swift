import ComposableArchitecture
import CryptoKit
@preconcurrency import Foundation

private actor M3UResponseBodyCollector {
    private let maximumBytes: Int
    private var body = Data()
    private var canRetainBody = true

    init(maximumBytes: Int) {
        self.maximumBytes = maximumBytes
    }

    func append(_ chunk: Data) {
        guard canRetainBody else { return }
        guard chunk.count <= maximumBytes - body.count else {
            canRetainBody = false
            body.removeAll(keepingCapacity: false)
            return
        }
        body.append(chunk)
    }

    func retainedBody() -> Data? {
        canRetainBody ? body : nil
    }
}

private actor EPGSourceIdentityKeyStore {
    private let keychainAccount = "com.pureiptv.epgSourceIdentityHMACKey.v1"
    private var cachedKeyData: Data?

    func keyData() -> Data? {
        if let cachedKeyData {
            return cachedKeyData
        }
        do {
            let encodedKey = try KeychainManager.shared.retrieve(for: keychainAccount, as: String.self)
            guard let keyData = Data(base64Encoded: encodedKey), keyData.count == 32 else { return nil }
            cachedKeyData = keyData
            return keyData
        } catch KeychainError.itemNotFound {
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            do {
                try KeychainManager.shared.save(keyData.base64EncodedString(), for: keychainAccount)
                cachedKeyData = keyData
                return keyData
            } catch {
                return nil
            }
        } catch {
            return nil
        }
    }
}

actor M3UCache {
    struct Entry {
        var items: [M3UItemDTO] = []
        var epgURL: URL?
        var xmltvData: XMLTVData?
        var xmltvFetchedAt: Date?
    }

    private var entries: [String: Entry] = [:]

    func replaceCatalog(items: [M3UItemDTO], epgURL: URL?, for key: String) throws {
        try Task.checkCancellation()
        var entry = entries[key] ?? Entry()
        if entry.epgURL != epgURL {
            entry.xmltvData = nil
            entry.xmltvFetchedAt = nil
        }
        entry.items = items
        entry.epgURL = epgURL
        entries[key] = entry
    }

    func getItems(for key: String) -> [M3UItemDTO] {
        entries[key]?.items ?? []
    }

    func hasCatalog(for key: String) -> Bool {
        !(entries[key]?.items.isEmpty ?? true)
    }

    func removeCatalog(for key: String) {
        entries.removeValue(forKey: key)
    }

    func replaceContent(items: [M3UItemDTO], epgURL: URL?, contentType: PlaylistContentType, for key: String) throws {
        try replaceContents(items: items, epgURL: epgURL, contentTypes: [contentType], for: key)
    }

    func replaceContents(
        items: [M3UItemDTO],
        epgURL: URL?,
        contentTypes: Set<PlaylistContentType>,
        for key: String
    ) throws {
        try Task.checkCancellation()
        guard !contentTypes.isEmpty else { return }
        var entry = entries[key] ?? Entry()
        if entry.epgURL != epgURL {
            entry.xmltvData = nil
            entry.xmltvFetchedAt = nil
        }
        let mediaTypes = contentTypes.map(\.mediaType)
        entry.items.removeAll { mediaTypes.contains($0.resolvedMediaType) }
        entry.items.append(contentsOf: items.filter { mediaTypes.contains($0.resolvedMediaType) })
        entry.epgURL = epgURL
        entries[key] = entry
    }

    func getEpgURL(for key: String) -> URL? {
        entries[key]?.epgURL
    }

    func getXmltvData(for key: String) -> XMLTVData? {
        entries[key]?.xmltvData
    }

    func getXmltvSnapshot(for key: String) -> (data: XMLTVData, fetchedAt: Date)? {
        guard let entry = entries[key],
              let xmltvData = entry.xmltvData,
              let fetchedAt = entry.xmltvFetchedAt else { return nil }
        return (xmltvData, fetchedAt)
    }

    func setXmltvData(_ data: XMLTVData, for key: String) {
        var entry = entries[key] ?? Entry()
        entry.xmltvData = data
        entry.xmltvFetchedAt = Date()
        entries[key] = entry
    }

    func replaceXmltvData(_ data: XMLTVData, for key: String) throws {
        try Task.checkCancellation()
        var entry = entries[key] ?? Entry()
        entry.xmltvData = data
        entry.xmltvFetchedAt = Date()
        entries[key] = entry
    }
}

public struct CachedEPGProgramSnapshot: Equatable, Sendable {
    public let programs: [EPGProgram]
    public let sourceFingerprint: String
    public let fetchedAt: Date
    public let age: TimeInterval

    fileprivate init(programs: [EPGProgram], sourceFingerprint: String, fetchedAt: Date, age: TimeInterval) {
        self.programs = programs
        self.sourceFingerprint = sourceFingerprint
        self.fetchedAt = fetchedAt
        self.age = age
    }
}

private actor EPGProgramSnapshotCache {
    private struct Key: Hashable {
        let sourceFingerprint: String
        let playlistID: UUID
        let epgChannelID: String
    }

    private struct Entry: Sendable {
        let programs: [EPGProgram]
        let fetchedAt: Date
        let cachedAt: Date
        let requestedProgramLimit: Int?
    }

    private let snapshotLifetime: TimeInterval = 5 * 60
    private let maximumEntries = 512
    private var entries: [Key: Entry] = [:]

    func store(
        _ programs: [EPGProgram],
        sourceFingerprint: String,
        playlistID: UUID,
        epgChannelID: String,
        fetchedAt: Date,
        requestedProgramLimit: Int?,
        now: Date = Date()
    ) {
        let normalizedID = epgChannelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty, normalizedID.count <= 512 else { return }
        let sourceAge = now.timeIntervalSince(fetchedAt)
        guard sourceAge >= 0 else { return }

        entries[Key(
            sourceFingerprint: sourceFingerprint,
            playlistID: playlistID,
            epgChannelID: normalizedID
        )] = Entry(
            programs: programs,
            fetchedAt: fetchedAt,
            cachedAt: now,
            requestedProgramLimit: requestedProgramLimit
        )
        pruneExpiredSnapshots(now: now)
        if entries.count > maximumEntries {
            let oldestKeys = entries.sorted { $0.value.cachedAt < $1.value.cachedAt }
                .prefix(entries.count - maximumEntries)
                .map(\.key)
            oldestKeys.forEach { entries.removeValue(forKey: $0) }
        }
    }

    func read(
        sourceFingerprint: String,
        playlistID: UUID,
        epgChannelIDs: [String],
        requiredProgramCount: Int?,
        maximumSourceAge: TimeInterval,
        expectedSourceFetchedAt: Date? = nil,
        now: Date = Date()
    ) -> [String: CachedEPGProgramSnapshot] {
        pruneExpiredSnapshots(now: now)
        var snapshots: [String: CachedEPGProgramSnapshot] = [:]
        for value in epgChannelIDs {
            let channelID = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !channelID.isEmpty, channelID.count <= 512 else { continue }
            let key = Key(
                sourceFingerprint: sourceFingerprint,
                playlistID: playlistID,
                epgChannelID: channelID
            )
            guard let entry = entries[key] else { continue }
            let satisfiesLimit: Bool = if let requiredProgramCount {
                entry.requestedProgramLimit.map { $0 >= requiredProgramCount } ?? true
            } else {
                entry.requestedProgramLimit == nil
            }
            guard satisfiesLimit else { continue }
            if let expectedSourceFetchedAt,
               abs(entry.fetchedAt.timeIntervalSince(expectedSourceFetchedAt)) > 0.001
            {
                continue
            }
            let age = now.timeIntervalSince(entry.fetchedAt)
            guard age >= 0, age <= maximumSourceAge else { continue }
            snapshots[channelID] = CachedEPGProgramSnapshot(
                programs: entry.programs,
                sourceFingerprint: sourceFingerprint,
                fetchedAt: entry.fetchedAt,
                age: age
            )
        }
        return snapshots
    }

    private func pruneExpiredSnapshots(now: Date) {
        entries = entries.filter { _, entry in
            let age = now.timeIntervalSince(entry.cachedAt)
            return age >= 0 && age <= snapshotLifetime
        }
    }
}

public nonisolated enum PlaylistContentType: CaseIterable, Hashable, Sendable {
    case live
    case movies
    case series

    fileprivate var mediaType: MediaModels.ItemType {
        switch self {
        case .live: .live
        case .movies: .vod
        case .series: .series
        }
    }
}

public enum M3URefreshStage: Equatable, Sendable {
    case downloading
    case validating
    case parsing(progress: Int?)
    case replacingCatalog
    case loadingCategories

    public var title: String {
        switch self {
        case .downloading: return "Playlist indiriliyor…".localized
        case .validating: return "Playlist doğrulanıyor…".localized
        case let .parsing(progress):
            let title = "Playlist doğrulanıyor…".localized
            return progress.map { "\(title) \($0)%" } ?? title
        case .replacingCatalog: return "Katalog güncelleniyor…".localized
        case .loadingCategories: return "Kategoriler yenileniyor…".localized
        }
    }

    public var canCancel: Bool {
        switch self {
        case .downloading, .validating, .parsing:
            true
        case .replacingCatalog, .loadingCategories:
            false
        }
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

private func applyingCategoryNameOverrides(
    _ categories: [MediaModels.Category],
    config: PlaylistConfig,
    mediaType: String,
    client: CategoryNameOverrideClient
) async -> [MediaModels.Category] {
    guard let playlistID = config.playlistID else { return categories }
    let overrides = await client.load(playlistID, mediaType)
    return categories.map { category in
        let sourceName = category.sourceName
        return MediaModels.Category(
            id: category.id,
            name: overrides[category.id] ?? sourceName,
            sourceName: sourceName
        )
    }
}

@DependencyClient
public struct IPTVClient {
    public var authenticate: @Sendable (_ config: PlaylistConfig) async throws -> Void
    public var refreshCatalog: @Sendable (
        _ config: PlaylistConfig,
        _ reportStage: @escaping @Sendable (M3URefreshStage) async -> Void
    ) async throws -> Bool = { _, _ in false }
    public var refreshContent: @Sendable (
        _ config: PlaylistConfig,
        _ contentType: PlaylistContentType,
        _ reportStage: @escaping @Sendable (M3URefreshStage) async -> Void
    ) async throws -> Void = { _, _, _ in }
    public var refreshContents: @Sendable (
        _ config: PlaylistConfig,
        _ contentTypes: Set<PlaylistContentType>,
        _ reportStage: @escaping @Sendable (M3URefreshStage) async -> Void
    ) async throws -> Void = { _, _, _ in }
    public var fetchLiveCategories: @Sendable (_ config: PlaylistConfig) async throws -> [MediaModels.Category]
    public var fetchM3UCategoryTags: @Sendable (_ config: PlaylistConfig) async -> [String] = { _ in [] }
    public var fetchSupportedXtreamLiveOutputFormats: @Sendable (_ config: PlaylistConfig) async throws -> [XtreamLiveOutputFormat] = { _ in [] }
    public var fetchLiveChannels: @Sendable (_ config: PlaylistConfig, _ categoryID: String?) async throws -> [MediaModels.Item]
    public var resolveLiveItem: @Sendable (_ config: PlaylistConfig, _ itemID: String, _ categoryID: String?) async throws -> MediaModels.Item?
    public var fetchVODCategories: @Sendable (_ config: PlaylistConfig) async throws -> [MediaModels.Category]
    public var fetchVODs: @Sendable (_ config: PlaylistConfig, _ categoryID: String?) async throws -> [MediaModels.Item]
    public var fetchSeriesCategories: @Sendable (_ config: PlaylistConfig) async throws -> [MediaModels.Category]
    public var fetchSeries: @Sendable (_ config: PlaylistConfig, _ categoryID: String?) async throws -> [MediaModels.Item]
    public var searchMediaServer: @Sendable (_ config: PlaylistConfig, _ query: String) async throws -> (vods: [MediaModels.Item], series: [MediaModels.Item]) = { _, _ in ([], []) }
    public var fetchSeriesInfo: @Sendable (_ config: PlaylistConfig, _ seriesID: String) async throws -> (info: DetailModels.Info, seasons: [DetailModels.Season], episodes: [DetailModels.Episode])
    public var fetchVODInfo: @Sendable (_ config: PlaylistConfig, _ vodID: String) async throws -> DetailModels.Info
    public var fetchMediaServerPlaybackOptions: @Sendable (_ config: PlaylistConfig, _ vodID: String) async throws -> [MediaModels.MediaServerPlaybackOption] = { _, _ in [] }
    public var resolveVODItem: @Sendable (_ config: PlaylistConfig, _ vodID: String, _ categoryID: String?, _ mediaSourceID: String?) async throws -> MediaModels.Item?
    public var fetchShortEPG: @Sendable (
        _ config: PlaylistConfig,
        _ channelID: String,
        _ epgChannelID: String?,
        _ limit: Int?
    ) async throws -> [EPGProgram]
    public var refreshEPGCache: @Sendable (_ config: PlaylistConfig) async throws -> Void
    public var refreshEPGCacheIfAvailable: @Sendable (_ config: PlaylistConfig) async throws -> Bool = { _ in false }
    public var resolveEPGSourceIdentity: @Sendable (_ config: PlaylistConfig) async -> EPGSourceIdentity? = { _ in nil }
    public var cachedEPGPrograms: @Sendable (
        _ config: PlaylistConfig,
        _ epgChannelIDs: [String],
        _ requiredProgramCount: Int?
    ) async -> [String: CachedEPGProgramSnapshot] = { _, _, _ in [:] }
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

private nonisolated struct EPGTimeSpan: Sendable {
    let start: Date
    let end: Date
}

private nonisolated func mergedEPGTimeSpans(_ spans: [EPGTimeSpan]) -> [EPGTimeSpan] {
    let sorted = spans.filter { $0.start < $0.end }.sorted {
        if $0.start != $1.start {
            return $0.start < $1.start
        }
        return $0.end < $1.end
    }
    var merged: [EPGTimeSpan] = []
    for span in sorted {
        guard let last = merged.last, span.start <= last.end else {
            merged.append(span)
            continue
        }
        merged[merged.count - 1] = EPGTimeSpan(start: last.start, end: max(last.end, span.end))
    }
    return merged
}

private nonisolated func mergeEPGPrograms(
    primary: [EPGProgram],
    secondary: [EPGProgram],
    secondaryLimit: Int?
) -> [EPGProgram] {
    guard !secondary.isEmpty else {
        return primary.sorted { $0.startTime < $1.startTime }
    }

    var occupied = mergedEPGTimeSpans(primary.map {
        EPGTimeSpan(start: $0.startTime, end: $0.endTime)
    })
    var additions: [EPGProgram] = []
    let maximumAdditions = secondaryLimit.map { max(0, $0) } ?? secondary.count
    let now = Date()
    let orderedSecondary = secondary.filter { $0.startTime < $0.endTime }.sorted {
        if $0.startTime != $1.startTime {
            return $0.startTime < $1.startTime
        }
        if $0.endTime != $1.endTime {
            return $0.endTime > $1.endTime
        }
        return $0.id.localizedStandardCompare($1.id) == .orderedAscending
    }

    for program in orderedSecondary {
        guard additions.count < maximumAdditions else { break }
        var cursor = program.startTime
        var gaps: [EPGTimeSpan] = []

        for span in occupied {
            if span.end <= cursor {
                continue
            }
            if span.start >= program.endTime {
                break
            }
            if span.start > cursor {
                gaps.append(EPGTimeSpan(start: cursor, end: min(span.start, program.endTime)))
            }
            cursor = max(cursor, span.end)
            if cursor >= program.endTime {
                break
            }
        }
        if cursor < program.endTime {
            gaps.append(EPGTimeSpan(start: cursor, end: program.endTime))
        }

        for gap in gaps where gap.start < gap.end {
            guard additions.count < maximumAdditions else { break }
            additions.append(EPGProgram(
                id: "secondary-\(program.id)-\(Int(gap.start.timeIntervalSince1970))-\(Int(gap.end.timeIntervalSince1970))",
                title: program.title,
                description: program.description,
                startTime: gap.start,
                endTime: gap.end,
                isPlayingNow: gap.start <= now && now <= gap.end,
                categories: program.categories,
                artworkURL: program.artworkURL
            ))
            occupied = mergedEPGTimeSpans(occupied + [gap])
        }
    }

    return (primary + additions).sorted { $0.startTime < $1.startTime }
}

private func isEPGRateLimit(_ error: Error) -> Bool {
    guard let networkError = error as? NetworkError else { return false }
    if case .rateLimited = networkError {
        return true
    }
    return false
}

private func checkEPGProviderCooldown(for config: PlaylistConfig, settingsClient: SettingsClient) throws {
    guard let playlistID = config.playlistID,
          let retryAfter = settingsClient.getEPGProviderCooldownUntil(playlistID) else { return }
    guard retryAfter > .now else {
        settingsClient.setEPGProviderCooldownUntil(playlistID, nil)
        return
    }
    throw NetworkError.rateLimited(retryAfter: retryAfter)
}

private func recordEPGProviderCooldown(from error: Error, for config: PlaylistConfig, settingsClient: SettingsClient) {
    guard let playlistID = config.playlistID,
          let networkError = error as? NetworkError,
          case let .rateLimited(retryAfter) = networkError,
          let retryAfter else { return }
    let existingRetryAfter = settingsClient.getEPGProviderCooldownUntil(playlistID)
    settingsClient.setEPGProviderCooldownUntil(playlistID, max(existingRetryAfter ?? .distantPast, retryAfter))
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

func makeXtreamLiveStreamURL(config: PlaylistConfig, streamID: String) -> URL? {
    guard !streamID.isEmpty,
          streamID.count <= 32,
          streamID.allSatisfy({ $0 >= "0" && $0 <= "9" }),
          Int(streamID) != nil,
          let serverURL = config.serverURL,
          let username = config.username,
          let password = config.password else { return nil }
    return makeXtreamStreamURL(
        baseURL: serverURL,
        username: username,
        password: password,
        path: ["live", username, password, "\(streamID).\(config.xtreamLiveOutputFormat.rawValue)"]
    )
}

extension IPTVClient: DependencyKey {
    public nonisolated static let liveValue: IPTVClient = {
        let networkClient = NetworkClient()
        let m3uCache = M3UCache()
        let encryptedM3UCache = EncryptedM3UCache()
        let epgSourceIdentityKeyStore = EPGSourceIdentityKeyStore()
        let epgProgramSnapshotCache = EPGProgramSnapshotCache()
        let mediaServerCatalogClient = MediaServerCatalogClient.liveValue
        let logoOverrideClient = ChannelLogoOverrideClient.liveValue
        let m3uCategoryMappingClient = M3UCategoryMappingClient.liveValue
        let categoryNameOverrideClient = CategoryNameOverrideClient.liveValue
        let m3uMemoryScopeKey = SymmetricKey(size: .bits256)

        let resolvedM3URequestConfig: @Sendable (PlaylistConfig) -> PlaylistConfig = { config in
            let configuredUserAgent = config.userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
            let effectiveUserAgent = configuredUserAgent.flatMap { $0.isEmpty ? nil : $0 }
                ?? UserAgentManager.resolveUserAgent()
            return config.replacingUserAgentOverride(effectiveUserAgent)
        }

        let m3uCacheKey: @Sendable (PlaylistConfig) -> String = { config in
            let requestConfig = resolvedM3URequestConfig(config)
            let components = [
                requestConfig.playlistID?.uuidString ?? "",
                requestConfig.type.rawValue,
                requestConfig.m3uURL?.absoluteString ?? "",
                requestConfig.username ?? "",
                requestConfig.password ?? "",
                requestConfig.userAgentOverride ?? "",
            ]
            var identity = Data("PureIPTV.M3U.memory.scope.v1".utf8)
            for component in components {
                let bytes = Data(component.utf8)
                var length = UInt64(bytes.count).bigEndian
                withUnsafeBytes(of: &length) { identity.append(contentsOf: $0) }
                identity.append(bytes)
            }
            let code = HMAC<SHA256>.authenticationCode(for: identity, using: m3uMemoryScopeKey)
            return code.map { String(format: "%02x", $0) }.joined()
        }

        let fetchAndParseM3U: @Sendable (
            PlaylistConfig,
            (@Sendable (M3URefreshStage) async -> Void)?
        ) async throws -> M3UParsedResult = { config, reportStage in
            guard config.type == .m3u, let url = config.m3uURL else { throw NetworkError.invalidURL }
            let scopedConfig = resolvedM3URequestConfig(config)
            let effectiveUserAgent = scopedConfig.userAgentOverride ?? UserAgentManager.resolveUserAgent()
            let context = await encryptedM3UCache.prepare(for: scopedConfig)

            let parseCachedBody: @Sendable (Data) async throws -> M3UParsedResult = { body in
                let parser = M3UIncrementalParser()
                var offset = 0
                while offset < body.count {
                    let end = min(offset + 32 * 1024, body.count)
                    let chunk = body.subdata(in: offset ..< end)
                    if let progress = try await parser.append(chunk, expectedByteCount: Int64(body.count)),
                       let reportStage
                    {
                        switch progress {
                        case .indeterminate:
                            await reportStage(.parsing(progress: nil))
                        case let .percentage(value):
                            await reportStage(.parsing(progress: value))
                        }
                    }
                    offset = end
                }
                try Task.checkCancellation()
                let parsed = try await parser.finish()
                await reportStage?(.parsing(progress: 100))
                return parsed
            }

            let download: @Sendable (Bool) async throws -> (M3UHTTPResponseMetadata, M3UParsedResult?, Data?) = { useValidators in
                let parser = M3UIncrementalParser()
                let bodyCollector = M3UResponseBodyCollector(
                    maximumBytes: EncryptedM3UCache.maximumPersistedBodyBytes
                )
                let snapshot = useValidators ? context?.snapshot : nil
                let response = try await networkClient.fetchDataInChunks(
                    url: url,
                    userAgentOverride: effectiveUserAgent,
                    ifNoneMatch: snapshot?.etag,
                    ifModifiedSince: snapshot?.lastModified,
                    maximumBytes: M3UIncrementalParser.maximumPlaylistBytes
                ) { chunk, expectedByteCount in
                    await bodyCollector.append(chunk)
                    guard let progress = try await parser.append(chunk, expectedByteCount: expectedByteCount) else { return }
                    guard let reportStage else { return }
                    switch progress {
                    case .indeterminate:
                        await reportStage(.parsing(progress: nil))
                    case let .percentage(value):
                        await reportStage(.parsing(progress: value))
                    }
                }
                guard response.statusCode == 200 else { return (response, nil, nil) }
                try Task.checkCancellation()
                let parsed = try await parser.finish()
                await reportStage?(.parsing(progress: 100))
                return await (response, parsed, bodyCollector.retainedBody())
            }

            do {
                let hasValidator = context?.snapshot?.etag != nil || context?.snapshot?.lastModified != nil
                var outcome = try await download(hasValidator)
                if outcome.0.statusCode == 304 {
                    if let snapshot = context?.snapshot,
                       EncryptedM3UCache.responseValidatorsMatch(outcome.0, snapshot: snapshot)
                    {
                        do {
                            let parsed = try await parseCachedBody(snapshot.body)
                            if EncryptedM3UCache.responseAllowsPersistence(
                                outcome.0,
                                fallbackVary: snapshot.vary
                            ) {
                                await encryptedM3UCache.store(
                                    body: snapshot.body,
                                    etag: outcome.0.etag ?? snapshot.etag,
                                    lastModified: outcome.0.lastModified ?? snapshot.lastModified,
                                    vary: outcome.0.vary ?? snapshot.vary,
                                    for: scopedConfig
                                )
                            } else {
                                await encryptedM3UCache.invalidate(for: scopedConfig)
                            }
                            return parsed
                        } catch is CancellationError {
                            throw CancellationError()
                        } catch {
                            await encryptedM3UCache.invalidate(for: scopedConfig)
                        }
                    } else if context?.snapshot != nil {
                        await encryptedM3UCache.invalidate(for: scopedConfig)
                    }
                    try Task.checkCancellation()
                    outcome = try await download(false)
                }

                guard outcome.0.statusCode == 200, let parsed = outcome.1 else {
                    throw NetworkError.invalidResponse
                }
                if let body = outcome.2,
                   EncryptedM3UCache.responseAllowsPersistence(outcome.0),
                   EncryptedM3UCache.responseHasUsableValidator(outcome.0)
                {
                    await encryptedM3UCache.store(
                        body: body,
                        etag: outcome.0.etag,
                        lastModified: outcome.0.lastModified,
                        vary: outcome.0.vary,
                        for: scopedConfig
                    )
                } else {
                    await encryptedM3UCache.invalidate(for: scopedConfig)
                }
                return parsed
            } catch {
                if let networkError = error as? NetworkError, networkError == .unauthorized {
                    await encryptedM3UCache.invalidate(for: scopedConfig)
                    await m3uCache.removeCatalog(for: m3uCacheKey(scopedConfig))
                }
                throw error
            }
        }

        let ensureM3UCache: @Sendable (PlaylistConfig) async -> [M3UItemDTO] = { config in
            let requestConfig = resolvedM3URequestConfig(config)
            let key = m3uCacheKey(requestConfig)
            let existing = await m3uCache.getItems(for: key)
            if !existing.isEmpty {
                return existing
            }
            guard requestConfig.m3uURL != nil else { return [] }
            do {
                let parsedResult = try await fetchAndParseM3U(requestConfig, nil)
                try await m3uCache.replaceCatalog(items: parsedResult.items, epgURL: parsedResult.epgURL, for: key)
                return parsedResult.items
            } catch {
                return await m3uCache.getItems(for: key)
            }
        }

        let ensureM3UCacheForEPG: @Sendable (PlaylistConfig, SettingsClient) async throws -> [M3UItemDTO] = { config, settingsClient in
            let requestConfig = resolvedM3URequestConfig(config)
            let key = m3uCacheKey(requestConfig)
            let existing = await m3uCache.getItems(for: key)
            if !existing.isEmpty {
                return existing
            }
            try checkEPGProviderCooldown(for: config, settingsClient: settingsClient)
            guard requestConfig.m3uURL != nil else { return [] }
            let parsedResult: M3UParsedResult
            do {
                parsedResult = try await fetchAndParseM3U(requestConfig, nil)
            } catch {
                recordEPGProviderCooldown(from: error, for: config, settingsClient: settingsClient)
                if isEPGRateLimit(error) {
                    throw error
                }
                return []
            }
            do {
                try await m3uCache.replaceCatalog(items: parsedResult.items, epgURL: parsedResult.epgURL, for: key)
                return parsedResult.items
            } catch {
                return await m3uCache.getItems(for: key)
            }
        }

        let refreshProviderEPGIfAvailable: @Sendable (PlaylistConfig) async throws -> Bool = { config in
            guard config.type == .m3u else { return false }
            let requestConfig = resolvedM3URequestConfig(config)
            @Dependency(\.xmltvParser) var xmltvParser
            @Dependency(\.settingsClient) var settingsClient
            let cacheKey = m3uCacheKey(requestConfig)
            if await m3uCache.getItems(for: cacheKey).isEmpty {
                guard requestConfig.m3uURL != nil else { throw NetworkError.invalidURL }
                let parsedPlaylist = try await fetchAndParseM3U(requestConfig, nil)
                try Task.checkCancellation()
                try await m3uCache.replaceCatalog(
                    items: parsedPlaylist.items,
                    epgURL: parsedPlaylist.epgURL,
                    for: cacheKey
                )
            }
            guard let epgURL = await m3uCache.getEpgURL(for: cacheKey) else { return false }
            try checkEPGProviderCooldown(for: config, settingsClient: settingsClient)
            let data: Data
            do {
                data = try await networkClient.fetchXMLTVData(url: epgURL, userAgentOverride: requestConfig.userAgentOverride)
            } catch {
                recordEPGProviderCooldown(from: error, for: config, settingsClient: settingsClient)
                throw error
            }
            // Replace the guide only after a full parse succeeds so failed
            // updates keep the last-known-good XMLTV data available.
            let parsedXMLTV = try await xmltvParser.parse(data)
            try Task.checkCancellation()
            try await m3uCache.replaceXmltvData(parsedXMLTV, for: cacheKey)
            return true
        }

        let resolveEPGSourceIdentity: @Sendable (PlaylistConfig) async -> EPGSourceIdentity? = { config in
            let sourceURL: URL?
            let identityMaterial: String
            switch config.type {
            case .m3u:
                sourceURL = await m3uCache.getEpgURL(for: m3uCacheKey(config))
                identityMaterial = [
                    PlaylistType.m3u.rawValue,
                    config.m3uURL?.absoluteString ?? "",
                    sourceURL?.absoluteString ?? "",
                    config.userAgentOverride ?? "",
                ].joined(separator: "\u{0}")
            case .xtream:
                sourceURL = config.serverURL
                identityMaterial = [
                    PlaylistType.xtream.rawValue,
                    config.serverURL?.absoluteString ?? "",
                    config.username ?? "",
                    config.password ?? "",
                    config.userAgentOverride ?? "",
                ].joined(separator: "\u{0}")
            case .plex, .emby:
                sourceURL = nil
                identityMaterial = ""
            }
            guard let sourceURL,
                  let keyData = await epgSourceIdentityKeyStore.keyData() else { return nil }
            return EPGSourceIdentity(
                playlistType: config.type,
                url: sourceURL,
                identityMaterial: identityMaterial,
                hmacKey: SymmetricKey(data: keyData)
            )
        }

        let readCachedEPGPrograms: @Sendable (
            PlaylistConfig,
            [String],
            Int?
        ) async -> [String: CachedEPGProgramSnapshot] = { config, epgChannelIDs, requiredProgramCount in
            @Dependency(\.settingsClient) var settingsClient
            guard let playlistID = config.playlistID,
                  let sourceIdentity = await resolveEPGSourceIdentity(config) else { return [:] }
            let maximumSourceAge: TimeInterval = if config.type == .m3u, settingsClient.autoUpdateEPG() {
                settingsClient.epgAutoRefreshInterval().duration
            } else {
                5 * 60
            }
            let expectedSourceFetchedAt: Date?
            if config.type == .m3u {
                expectedSourceFetchedAt = await m3uCache
                    .getXmltvSnapshot(for: m3uCacheKey(config))?.fetchedAt
                guard expectedSourceFetchedAt != nil else { return [:] }
            } else {
                expectedSourceFetchedAt = nil
            }
            return await epgProgramSnapshotCache.read(
                sourceFingerprint: sourceIdentity.fingerprint,
                playlistID: playlistID,
                epgChannelIDs: Array(epgChannelIDs.prefix(500)),
                requiredProgramCount: requiredProgramCount,
                maximumSourceAge: maximumSourceAge,
                expectedSourceFetchedAt: expectedSourceFetchedAt
            )
        }

        return IPTVClient(
            authenticate: { config in
                if config.type == .plex || config.type == .emby {
                    try await mediaServerCatalogClient.validate(config)
                    return
                }
                if config.type == .m3u {
                    let requestConfig = resolvedM3URequestConfig(config)
                    guard requestConfig.m3uURL != nil else {
                        throw NSError(domain: "IPTVClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid M3U configuration"])
                    }
                    let key = m3uCacheKey(requestConfig)
                    do {
                        let parsedResult = try await fetchAndParseM3U(requestConfig, nil)
                        try await m3uCache.replaceCatalog(items: parsedResult.items, epgURL: parsedResult.epgURL, for: key)
                    } catch {
                        if error is CancellationError {
                            throw error
                        }
                        if await m3uCache.hasCatalog(for: key) {
                            throw NSError(domain: "IPTVClient.M3U", code: 503, userInfo: [NSLocalizedDescriptionKey: "Playlist yenilenemedi; son başarılı katalog korunuyor. Ayrıntı: \(error.localizedDescription)"])
                        }
                        throw error
                    }
                    return
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return }

                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.authenticate.url(with: xtreamConfig)
                if let authDTO: XtreamAuthResponseDTO = try? await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride) {
                    await AccountInfoManager.shared.update(from: authDTO)
                }
            },
            refreshCatalog: { config, reportStage in
                switch config.type {
                case .m3u:
                    let requestConfig = resolvedM3URequestConfig(config)
                    guard requestConfig.m3uURL != nil else { throw NetworkError.invalidURL }
                    await reportStage(.downloading)
                    let parsedResult = try await fetchAndParseM3U(requestConfig, reportStage)
                    try Task.checkCancellation()
                    await reportStage(.replacingCatalog)
                    try await m3uCache.replaceCatalog(
                        items: parsedResult.items,
                        epgURL: parsedResult.epgURL,
                        for: m3uCacheKey(requestConfig)
                    )
                    return parsedResult.epgURL != nil
                case .xtream:
                    guard let serverURL = config.serverURL,
                          let username = config.username,
                          let password = config.password else { throw NetworkError.invalidURL }
                    let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                    await reportStage(.loadingCategories)
                    let authURL = try XtreamEndpoint.authenticate.url(with: xtreamConfig)
                    let auth: XtreamAuthResponseDTO = try await networkClient.fetch(
                        url: authURL,
                        userAgentOverride: config.userAgentOverride
                    )
                    guard auth.userInfo.auth == 1 else {
                        throw auth.userInfo.auth == 0 ? NetworkError.unauthorized : NetworkError.invalidResponse
                    }
                    let liveURL = try XtreamEndpoint.getLiveCategories.url(with: xtreamConfig)
                    let vodURL = try XtreamEndpoint.getVODCategories.url(with: xtreamConfig)
                    let seriesURL = try XtreamEndpoint.getSeriesCategories.url(with: xtreamConfig)
                    let _: [XtreamCategoryDTO] = try await networkClient.fetch(url: liveURL, userAgentOverride: config.userAgentOverride)
                    try Task.checkCancellation()
                    let _: [XtreamCategoryDTO] = try await networkClient.fetch(url: vodURL, userAgentOverride: config.userAgentOverride)
                    try Task.checkCancellation()
                    let _: [XtreamCategoryDTO] = try await networkClient.fetch(url: seriesURL, userAgentOverride: config.userAgentOverride)
                    try Task.checkCancellation()
                    return false
                case .plex, .emby:
                    await reportStage(.loadingCategories)
                    try await mediaServerCatalogClient.refreshCatalog(config)
                    return false
                }
            },
            refreshContent: { config, contentType, reportStage in
                if config.type == .plex || config.type == .emby {
                    await mediaServerCatalogClient.invalidate(config, contentType == .live ? nil : contentType == .movies ? .vod : .series)
                    return
                }
                guard config.type == .m3u else { return }
                let requestConfig = resolvedM3URequestConfig(config)
                guard requestConfig.m3uURL != nil else { return }
                await reportStage(.downloading)
                let parsedResult = try await fetchAndParseM3U(requestConfig, reportStage)
                try Task.checkCancellation()
                await reportStage(.replacingCatalog)
                try await m3uCache.replaceContent(
                    items: parsedResult.items,
                    epgURL: parsedResult.epgURL,
                    contentType: contentType,
                    for: m3uCacheKey(requestConfig)
                )
            },
            refreshContents: { config, contentTypes, reportStage in
                guard !contentTypes.isEmpty else { return }
                if config.type == .plex || config.type == .emby {
                    if contentTypes.contains(.live) {
                        await mediaServerCatalogClient.invalidate(config, nil)
                    } else {
                        for contentType in PlaylistContentType.allCases where contentTypes.contains(contentType) {
                            await mediaServerCatalogClient.invalidate(
                                config,
                                contentType == .movies ? .vod : .series
                            )
                        }
                    }
                    return
                }
                guard config.type == .m3u else { return }
                let requestConfig = resolvedM3URequestConfig(config)
                guard requestConfig.m3uURL != nil else { return }
                await reportStage(.downloading)
                let parsedResult = try await fetchAndParseM3U(requestConfig, reportStage)
                try Task.checkCancellation()
                await reportStage(.replacingCatalog)
                let cacheKey = m3uCacheKey(requestConfig)
                try await m3uCache.replaceContents(
                    items: parsedResult.items,
                    epgURL: parsedResult.epgURL,
                    contentTypes: contentTypes,
                    for: cacheKey
                )
            },
            fetchLiveCategories: { config in
                if config.type == .plex || config.type == .emby {
                    return []
                }
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
                    let categories = categoriesByID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    return await applyingCategoryNameOverrides(categories, config: config, mediaType: "live", client: categoryNameOverrideClient)
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getLiveCategories.url(with: xtreamConfig)
                let dtos: [XtreamCategoryDTO] = try await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride)
                let categories = dtos.map { MediaModels.Category(id: $0.categoryId, name: $0.categoryName) }
                return await applyingCategoryNameOverrides(categories, config: config, mediaType: "live", client: categoryNameOverrideClient)
            },
            fetchM3UCategoryTags: { config in
                guard config.type == .m3u else { return [] }
                let items = await ensureM3UCache(config).filter { $0.resolvedMediaType == .live }
                return Array(Set(items.compactMap { item in
                    let tag = item.sourceGroupTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return tag.isEmpty || tag.count > 160 ? nil : tag
                })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            },
            fetchSupportedXtreamLiveOutputFormats: { config in
                guard config.type == .xtream,
                      let serverURL = config.serverURL,
                      let username = config.username,
                      let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.authenticate.url(with: xtreamConfig)
                let dto: XtreamAuthResponseDTO = try await networkClient.fetch(
                    url: url,
                    userAgentOverride: config.userAgentOverride
                )
                var seenFormats = Set<XtreamLiveOutputFormat>()
                return (dto.userInfo.allowedOutputFormats ?? []).compactMap { value in
                    guard let format = XtreamLiveOutputFormat(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()),
                          seenFormats.insert(format).inserted else { return nil }
                    return format
                }
            },
            fetchLiveChannels: { config, categoryID in
                if config.type == .plex || config.type == .emby {
                    return []
                }
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
                            logoOverrideStorageKey: ChannelLogoOverrideIdentity.m3uKey(tvgID: item.tvgID, streamURL: item.streamURL),
                            categoryID: category.id,
                            type: .live,
                            epgChannelID: item.tvgID,
                            userAgentOverride: config.userAgentOverride
                        )
                    }
                    guard let playlistID = config.playlistID else { return channels }
                    let overrideKeys = channels.map { $0.logoOverrideStorageKey ?? $0.id }
                    let overrides = await logoOverrideClient.fetchOverrides(playlistID, overrideKeys)
                    return channels.map { channel in
                        channel.replacingLogoURLOverride(overrides[channel.logoOverrideStorageKey ?? channel.id])
                    }
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getLiveStreams(categoryID: categoryID).url(with: xtreamConfig)
                let dtos: [XtreamLiveStreamDTO] = try await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride)
                let channels = dtos.compactMap { dto -> MediaModels.Item? in
                    guard let streamURL = makeXtreamLiveStreamURL(config: config, streamID: String(dto.streamId)) else {
                        return nil
                    }
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
                if config.type == .plex || config.type == .emby {
                    return nil
                }
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
                        logoOverrideStorageKey: ChannelLogoOverrideIdentity.m3uKey(tvgID: item.tvgID, streamURL: item.streamURL),
                        categoryID: category.id,
                        type: .live,
                        epgChannelID: item.tvgID,
                        userAgentOverride: config.userAgentOverride
                    )
                    guard let playlistID = config.playlistID else { return resolved }
                    let storageKey = resolved.logoOverrideStorageKey ?? itemID
                    let overrides = await logoOverrideClient.fetchOverrides(playlistID, [storageKey])
                    return resolved.replacingLogoURLOverride(overrides[storageKey])
                }
                guard config.type == .xtream,
                      let streamURL = makeXtreamLiveStreamURL(config: config, streamID: itemID) else { return nil }
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
                if config.type == .plex || config.type == .emby {
                    let categories = try await mediaServerCatalogClient.fetchCategories(config, .vod)
                    return await applyingCategoryNameOverrides(categories, config: config, mediaType: "vod", client: categoryNameOverrideClient)
                }
                if config.type == .m3u {
                    let items = await ensureM3UCache(config).filter { $0.resolvedMediaType == .vod }
                    let groups = Array(Set(items.map(\.groupTitle))).sorted()
                    let categories = groups.map { MediaModels.Category(id: $0, name: $0) }
                    return await applyingCategoryNameOverrides(categories, config: config, mediaType: "vod", client: categoryNameOverrideClient)
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getVODCategories.url(with: xtreamConfig)
                let dtos: [XtreamCategoryDTO] = try await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride)
                let categories = dtos.map { MediaModels.Category(id: $0.categoryId, name: $0.categoryName) }
                return await applyingCategoryNameOverrides(categories, config: config, mediaType: "vod", client: categoryNameOverrideClient)
            },
            fetchVODs: { config, categoryID in
                if config.type == .plex || config.type == .emby {
                    return try await mediaServerCatalogClient.fetchItems(config, .vod, categoryID)
                }
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
                            originalLanguageCode: item.originalLanguageCode,
                            originalLanguageSourceValue: item.originalLanguageSourceValue,
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
                        originalLanguageCode: dto.originalLanguageCode,
                        originalLanguageSourceValue: dto.originalLanguageSourceValue,
                        rating: dto.rating5based ?? dto.rating,
                        addedDate: addedDate,
                        userAgentOverride: config.userAgentOverride
                    )
                }
            },
            fetchSeriesCategories: { config in
                if config.type == .plex || config.type == .emby {
                    let categories = try await mediaServerCatalogClient.fetchCategories(config, .series)
                    return await applyingCategoryNameOverrides(categories, config: config, mediaType: "series", client: categoryNameOverrideClient)
                }
                if config.type == .m3u {
                    let items = await ensureM3UCache(config).filter { $0.resolvedMediaType == .series }
                    let groups = Array(Set(items.map(\.groupTitle))).sorted()
                    let categories = groups.map { MediaModels.Category(id: $0, name: $0) }
                    return await applyingCategoryNameOverrides(categories, config: config, mediaType: "series", client: categoryNameOverrideClient)
                }

                guard config.type == .xtream, let serverURL = config.serverURL, let username = config.username, let password = config.password else { return [] }
                let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)
                let url = try XtreamEndpoint.getSeriesCategories.url(with: xtreamConfig)
                let dtos: [XtreamCategoryDTO] = try await networkClient.fetch(url: url, userAgentOverride: config.userAgentOverride)
                let categories = dtos.map { MediaModels.Category(id: $0.categoryId, name: $0.categoryName) }
                return await applyingCategoryNameOverrides(categories, config: config, mediaType: "series", client: categoryNameOverrideClient)
            },
            fetchSeries: { config, categoryID in
                if config.type == .plex || config.type == .emby {
                    return try await mediaServerCatalogClient.fetchItems(config, .series, categoryID)
                }
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
                            originalLanguageCode: item.originalLanguageCode,
                            originalLanguageSourceValue: item.originalLanguageSourceValue,
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
                    MediaModels.Item(
                        id: String(dto.seriesId),
                        title: dto.name,
                        streamURL: nil,
                        coverURL: dto.cover.flatMap { URL(string: $0) },
                        categoryID: dto.categoryId,
                        type: .series,
                        originalLanguageCode: dto.originalLanguageCode,
                        originalLanguageSourceValue: dto.originalLanguageSourceValue,
                        rating: dto.rating5based ?? Double(dto.rating ?? "0"),
                        releaseDate: dto.releaseDate,
                        userAgentOverride: config.userAgentOverride
                    )
                }
            },
            searchMediaServer: { config, query in
                guard config.type == .plex || config.type == .emby else { return ([], []) }
                return try await mediaServerCatalogClient.search(config, query)
            },
            fetchSeriesInfo: { config, seriesID in
                if config.type == .plex || config.type == .emby {
                    let result = try await mediaServerCatalogClient.fetchSeriesInfo(config, seriesID)
                    var info = result.info
                    let diagnostics = SeriesEpisodeCatalogNormalizer.diagnostics(for: result.episodes)
                    info.seriesCatalogDiagnostics = diagnostics.isEmpty ? nil : diagnostics
                    return (
                        info: info,
                        seasons: result.seasons,
                        episodes: SeriesEpisodeCatalogNormalizer.canonicalized(result.episodes)
                    )
                }
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

                var info = DetailModels.Info(
                    plot: dto.info?.plot,
                    cast: dto.info?.cast,
                    director: dto.info?.director,
                    genre: dto.info?.genre,
                    tmdbId: nil,
                    rating: dto.info?.rating5based,
                    releaseDate: dto.info?.releaseDate
                )

                var episodes: [DetailModels.Episode] = []

                if let dtoSeasons = dto.episodes {
                    for (seasonNumStr, seasonEpisodes) in dtoSeasons {
                        let groupSeasonNumber = Int(seasonNumStr)
                        for ep in seasonEpisodes {
                            guard let seasonNum = ep.season.flatMap({ $0 >= 0 ? $0 : nil }) ?? groupSeasonNumber,
                                  seasonNum >= 0
                            else { continue }

                            let episodeID = ep.id.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !episodeID.isEmpty else { continue }
                            let fileExtension = ep.containerExtension.trimmingCharacters(in: .whitespacesAndNewlines)
                            let extensionSuffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"
                            let streamURL = xtreamConfig.baseURL.appendingPathComponent(
                                "series/\(xtreamConfig.username)/\(xtreamConfig.password)/\(episodeID)\(extensionSuffix)"
                            )
                            episodes.append(DetailModels.Episode(
                                id: episodeID,
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

                let diagnostics = SeriesEpisodeCatalogNormalizer.diagnostics(for: episodes)
                info.seriesCatalogDiagnostics = diagnostics.isEmpty ? nil : diagnostics

                let canonicalEpisodes = SeriesEpisodeCatalogNormalizer.canonicalized(episodes)
                let episodeCountsBySeason = Dictionary(grouping: canonicalEpisodes, by: \.season).mapValues(\.count)
                var seasonNumbers = Set(canonicalEpisodes.map(\.season))
                for season in dto.seasons ?? [] {
                    if let seasonNumber = season.seasonNumber, seasonNumber >= 0 {
                        seasonNumbers.insert(seasonNumber)
                    }
                }

                let seasons = seasonNumbers.sorted().map { seasonNumber in
                    let providerSeason = dto.seasons?.first(where: { $0.seasonNumber == seasonNumber })
                    let providerName = providerSeason?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let name = providerName.flatMap { $0.isEmpty ? nil : $0 } ?? "Sezon \(seasonNumber)"
                    return DetailModels.Season(
                        id: String(seasonNumber),
                        seasonNumber: seasonNumber,
                        name: name,
                        episodeCount: episodeCountsBySeason[seasonNumber] ?? 0
                    )
                }

                return (info: info, seasons: seasons, episodes: canonicalEpisodes)
            },
            fetchVODInfo: { config, vodID in
                if config.type == .plex || config.type == .emby {
                    return try await mediaServerCatalogClient.fetchVODInfo(config, vodID)
                }
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
            fetchMediaServerPlaybackOptions: { config, vodID in
                guard config.type == .plex || config.type == .emby,
                      !vodID.isEmpty,
                      vodID.count <= 512 else { return [] }
                return try await mediaServerCatalogClient.fetchPlaybackOptions(config, vodID)
            },
            resolveVODItem: { config, vodID, categoryID, mediaSourceID in
                guard !vodID.isEmpty, vodID.count <= 512 else { return nil }
                if config.type == .plex || config.type == .emby {
                    return try await mediaServerCatalogClient.resolvePlaybackItem(config, vodID, mediaSourceID)
                }

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
            fetchShortEPG: { config, channelID, requestedEPGChannelID, limit in
                @Dependency(\.xmltvParser) var xmltvParser
                @Dependency(\.settingsClient) var settingsClient
                @Dependency(\.customEPGMappingClient) var customEPGMappingClient

                let requestedEPGID = requestedEPGChannelID?.trimmingCharacters(in: .whitespacesAndNewlines)
                let epgChannelID: String = if config.type == .m3u,
                                              let requestedEPGID,
                                              !requestedEPGID.isEmpty
                {
                    requestedEPGID
                } else {
                    channelID
                }

                let fetchSecondaryPrograms: @Sendable () async -> [EPGProgram] = {
                    await customEPGMappingClient.fetchProgramsForChannel(
                        channelID,
                        "",
                        nil,
                        config.playlistID
                    )
                }
                let finishPrograms: @Sendable ([EPGProgram], [EPGProgram]) -> [EPGProgram] = { primary, secondary in
                    let merged = mergeEPGPrograms(primary: primary, secondary: secondary, secondaryLimit: limit)
                    return customEPGMappingClient.applyTimeShift(merged, channelID, config.playlistID)
                }

                let cachedPrograms = await readCachedEPGPrograms(config, [epgChannelID], limit)
                if let snapshot = cachedPrograms[epgChannelID] {
                    return snapshot.programs
                }

                if config.type == .m3u {
                    let requestConfig = resolvedM3URequestConfig(config)
                    do {
                        _ = try await ensureM3UCacheForEPG(requestConfig, settingsClient)
                        let cacheKey = m3uCacheKey(requestConfig)
                        guard let epgURL = await m3uCache.getEpgURL(for: cacheKey) else {
                            throw NetworkError.underlying(description: "This M3U playlist has no EPG source.")
                        }
                        var xmltvSnapshot = await m3uCache.getXmltvSnapshot(for: cacheKey)
                        if xmltvSnapshot == nil {
                            try checkEPGProviderCooldown(for: requestConfig, settingsClient: settingsClient)
                            let data: Data
                            do {
                                data = try await networkClient.fetchXMLTVData(url: epgURL, userAgentOverride: requestConfig.userAgentOverride)
                            } catch {
                                recordEPGProviderCooldown(from: error, for: requestConfig, settingsClient: settingsClient)
                                throw error
                            }
                            let parsed = try await xmltvParser.parse(data)
                            await m3uCache.setXmltvData(parsed, for: cacheKey)
                            xmltvSnapshot = await m3uCache.getXmltvSnapshot(for: cacheKey)
                        }
                        guard let xmltvSnapshot else {
                            throw NetworkError.decodingFailed(description: "The XMLTV source could not be parsed.")
                        }

                        let now = Date()
                        let programmes = xmltvSnapshot.data.programmes[epgChannelID] ?? []
                        let requestedCount = limit.map { min(max(0, $0), programmes.count) } ?? programmes.count
                        let primary = programmes.prefix(requestedCount).map { p in
                            EPGProgram(
                                id: "m3u-\(epgChannelID)-\(Int(p.start.timeIntervalSince1970))-\(Int(p.end.timeIntervalSince1970))",
                                title: p.title,
                                description: p.description,
                                startTime: p.start,
                                endTime: p.end,
                                isPlayingNow: p.start <= now && p.end >= now,
                                categories: p.categories,
                                artworkURL: p.artworkURL
                            )
                        }
                        try Task.checkCancellation()
                        let secondary = await fetchSecondaryPrograms()
                        try Task.checkCancellation()
                        let result = finishPrograms(primary, secondary)
                        if let playlistID = config.playlistID,
                           let sourceIdentity = await resolveEPGSourceIdentity(config)
                        {
                            await epgProgramSnapshotCache.store(
                                result,
                                sourceFingerprint: sourceIdentity.fingerprint,
                                playlistID: playlistID,
                                epgChannelID: epgChannelID,
                                fetchedAt: xmltvSnapshot.fetchedAt,
                                requestedProgramLimit: limit
                            )
                        }
                        return result
                    } catch {
                        guard !Task.isCancelled, !(error is CancellationError) else { throw error }
                        let secondary = await fetchSecondaryPrograms()
                        try Task.checkCancellation()
                        guard !secondary.isEmpty else { throw error }
                        return finishPrograms([], secondary)
                    }
                }

                var response: [EPGItemDTO] = []
                var receivedValidResponse = false
                var lastRequestError: Error = NetworkError.invalidResponse

                if config.type == .xtream,
                   let serverURL = config.serverURL,
                   let username = config.username,
                   let password = config.password
                {
                    let xtreamConfig = ServerConfig(baseURL: serverURL, username: username, password: password)

                    // Strategy 1: Attempt action=get_short_epg
                    do {
                        try checkEPGProviderCooldown(for: config, settingsClient: settingsClient)
                        let url = try XtreamEndpoint.getShortEPG(streamID: epgChannelID, limit: limit).url(with: xtreamConfig)
                        let data = try await networkClient.fetchData(url: url, userAgentOverride: config.userAgentOverride)
                        response = try decodeEPGItems(data)
                        receivedValidResponse = true
                    } catch {
                        guard !Task.isCancelled, !(error is CancellationError) else { throw error }
                        recordEPGProviderCooldown(from: error, for: config, settingsClient: settingsClient)
                        lastRequestError = error
                    }

                    // Strategy 2: If empty, attempt action=get_simple_data_table
                    if response.isEmpty, !isEPGRateLimit(lastRequestError) {
                        do {
                            try checkEPGProviderCooldown(for: config, settingsClient: settingsClient)
                            let url = try XtreamEndpoint.getEPGDataTable(streamID: epgChannelID).url(with: xtreamConfig)
                            let data = try await networkClient.fetchData(url: url, userAgentOverride: config.userAgentOverride)
                            response = try decodeEPGItems(data)
                            receivedValidResponse = true
                        } catch {
                            guard !Task.isCancelled, !(error is CancellationError) else { throw error }
                            recordEPGProviderCooldown(from: error, for: config, settingsClient: settingsClient)
                            lastRequestError = error
                        }
                    }
                }

                try Task.checkCancellation()
                let secondary = await fetchSecondaryPrograms()
                try Task.checkCancellation()

                if response.isEmpty, !receivedValidResponse, secondary.isEmpty {
                    throw lastRequestError
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
                // Xtream normally includes epoch timestamps. Avoid creating ten
                // DateFormatter instances for every channel response in that case.
                let needsDateFormatterFallback = response.contains {
                    $0.startTimestamp == nil || $0.stopTimestamp == nil
                }
                let formatters: [DateFormatter] = needsDateFormatterFallback ? formatStrings.map { fmt in
                    let f = DateFormatter()
                    f.dateFormat = fmt
                    f.locale = Locale(identifier: "en_US_POSIX")
                    f.timeZone = TimeZone(identifier: "UTC")
                    return f
                } : []

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

                let result: [EPGProgram] = response.compactMap { (item: EPGItemDTO) -> EPGProgram? in
                    var start: Date?
                    var end: Date?

                    if let startTS = item.startTimestamp, let endTS = item.stopTimestamp {
                        start = Date(timeIntervalSince1970: TimeInterval(startTS))
                        end = Date(timeIntervalSince1970: TimeInterval(endTS))
                    } else {
                        if let s = parseEPGDate(item.start), let e = parseEPGDate(item.end) {
                            start = s
                            end = e
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
                        isPlayingNow: item.nowPlaying == 1 || (finalStart <= Date() && Date() <= finalEnd),
                        artworkURL: EPGArtworkURL.parse(item.icon)
                    )
                }

                let finishedPrograms = finishPrograms(result, secondary)
                if receivedValidResponse,
                   let playlistID = config.playlistID,
                   let sourceIdentity = await resolveEPGSourceIdentity(config)
                {
                    await epgProgramSnapshotCache.store(
                        finishedPrograms,
                        sourceFingerprint: sourceIdentity.fingerprint,
                        playlistID: playlistID,
                        epgChannelID: epgChannelID,
                        fetchedAt: Date(),
                        requestedProgramLimit: limit
                    )
                }
                return finishedPrograms
            },
            refreshEPGCache: { config in
                guard config.type == .m3u else { return }
                guard try await refreshProviderEPGIfAvailable(config) else {
                    throw NetworkError.underlying(description: "This M3U playlist has no EPG source.")
                }
            },
            refreshEPGCacheIfAvailable: refreshProviderEPGIfAvailable,
            resolveEPGSourceIdentity: resolveEPGSourceIdentity,
            cachedEPGPrograms: readCachedEPGPrograms,
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
                                categories: programme.categories,
                                artworkURL: programme.artworkURL
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
        refreshCatalog: { _, _ in false },
        refreshContent: { _, _, _ in },
        refreshContents: { _, _, _ in },
        fetchLiveCategories: { _ in [] },
        fetchM3UCategoryTags: { _ in [] },
        fetchSupportedXtreamLiveOutputFormats: { _ in [] },
        fetchLiveChannels: { _, _ in [] },
        resolveLiveItem: { _, _, _ in nil },
        fetchVODCategories: { _ in [] },
        fetchVODs: { _, _ in [] },
        fetchSeriesCategories: { _ in [] },
        fetchSeries: { _, _ in [] },
        searchMediaServer: { _, _ in ([], []) },
        fetchSeriesInfo: { _, _ in (DetailModels.Info(), [], []) },
        fetchVODInfo: { _, _ in DetailModels.Info() },
        fetchMediaServerPlaybackOptions: { _, _ in [] },
        resolveVODItem: { _, _, _, _ in nil },
        fetchShortEPG: { _, _, _, _ in [] },
        refreshEPGCache: { _ in },
        refreshEPGCacheIfAvailable: { _ in false },
        resolveEPGSourceIdentity: { _ in nil },
        cachedEPGPrograms: { _, _, _ in [:] },
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
