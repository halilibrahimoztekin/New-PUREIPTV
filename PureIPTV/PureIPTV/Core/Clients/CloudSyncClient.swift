import ComposableArchitecture
import CryptoKit
import Foundation
import SwiftData

// MARK: - FavoriteSyncDTO

/// Lightweight, Codable transfer model for syncing favorite channels/movies across iCloud devices (Madde #24).
public struct FavoriteSyncDTO: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let type: String // "live", "vod", "series"
    public let title: String
    public let coverURL: String?
    public let streamURL: String?
    public let addedAt: Date
    public let playlistID: UUID?
    public let profileID: UUID?
    public let removedAt: Date?

    public init(
        id: String,
        type: String,
        title: String,
        coverURL: String? = nil,
        streamURL: String? = nil,
        addedAt: Date = Date(),
        playlistID: UUID? = nil,
        profileID: UUID? = nil,
        removedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.coverURL = coverURL
        self.streamURL = streamURL
        self.addedAt = addedAt
        self.playlistID = playlistID
        self.profileID = profileID
        self.removedAt = removedAt
    }

    public init(from favorite: FavoriteItem) {
        id = favorite.id
        type = favorite.type
        title = favorite.title
        coverURL = favorite.coverURL
        streamURL = favorite.streamURL
        addedAt = favorite.addedAt
        playlistID = favorite.playlistID
        profileID = favorite.profileID
        removedAt = favorite.removedAt
    }

    public func toFavoriteItem() -> FavoriteItem {
        FavoriteItem(
            id: id,
            type: type,
            title: title,
            coverURL: coverURL,
            streamURL: streamURL,
            addedAt: addedAt,
            playlistID: playlistID,
            profileID: profileID,
            removedAt: removedAt
        )
    }
}

private func sportsFollowRecordWins(
    _ candidate: SportsFollowSyncRecord,
    over current: SportsFollowSyncRecord
) -> Bool {
    candidate.wins(over: current)
}

private func favoriteSyncVersion(_ dto: FavoriteSyncDTO) -> Date {
    dto.removedAt ?? dto.addedAt
}

private func favoriteSyncWins(_ candidate: FavoriteSyncDTO, over current: FavoriteSyncDTO) -> Bool {
    let candidateVersion = favoriteSyncVersion(candidate)
    let currentVersion = favoriteSyncVersion(current)
    if candidateVersion != currentVersion {
        return candidateVersion > currentVersion
    }
    if (candidate.removedAt != nil) != (current.removedAt != nil) {
        return candidate.removedAt != nil
    }
    let candidateStable = "\(candidate.title)|\(candidate.coverURL ?? "")|\(candidate.streamURL ?? "")"
    let currentStable = "\(current.title)|\(current.coverURL ?? "")|\(current.streamURL ?? "")"
    return candidateStable > currentStable
}

// MARK: - CloudSync Models

public struct CloudSyncSummary: Codable, Equatable, Sendable {
    public var favoritesCount: Int
    public var hiddenChannelsCount: Int
    public var blacklistedCategoriesCount: Int
    public var watchProgressCount: Int
    public var lastSyncDate: Date
    public var deviceID: String

    public init(
        favoritesCount: Int = 0,
        hiddenChannelsCount: Int = 0,
        blacklistedCategoriesCount: Int = 0,
        watchProgressCount: Int = 0,
        lastSyncDate: Date = Date(),
        deviceID: String = ""
    ) {
        self.favoritesCount = favoritesCount
        self.hiddenChannelsCount = hiddenChannelsCount
        self.blacklistedCategoriesCount = blacklistedCategoriesCount
        self.watchProgressCount = watchProgressCount
        self.lastSyncDate = lastSyncDate
        self.deviceID = deviceID
    }
}

private struct HomeSectionPreferenceEntry: Codable {
    let id: String
    let isVisible: Bool
}

private struct HomeSectionPreferenceSyncDTO: Codable {
    let schemaVersion: Int
    let sections: [HomeSectionPreferenceEntry]
    let modifiedAt: Date
    let deviceID: String

    var isSupported: Bool {
        schemaVersion == 1 && sections.allSatisfy { HomeSectionType(rawValue: $0.id) != nil }
    }

    var knownSections: [HomeSectionConfig] {
        sections.compactMap { entry in
            guard let type = HomeSectionType(rawValue: entry.id) else { return nil }
            return HomeSectionConfig(type: type, isVisible: entry.isVisible)
        }
    }
}

private struct TopShelfSelectionSyncDTO: Codable {
    let schemaVersion: Int
    let selection: TopShelfContentSelection
    let modifiedAt: Date
    let deviceID: String

    var isSupported: Bool {
        schemaVersion == 1
    }
}

private final class PresentationPreferenceSyncGate: @unchecked Sendable {
    private let lock = NSRecursiveLock()

    func withLock<Value>(_ operation: () throws -> Value) rethrows -> Value {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private func preferenceSyncRecordWins(
    candidateDate: Date,
    candidateDeviceID: String,
    over currentDate: Date,
    currentDeviceID: String
) -> Bool {
    if candidateDate != currentDate {
        return candidateDate > currentDate
    }
    return candidateDeviceID > currentDeviceID
}

public enum CloudSyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case success(Date)
    case error(String)
}

// MARK: - CloudSyncClient

@DependencyClient
public struct CloudSyncClient: Sendable {
    public var isSyncEnabled: @Sendable () -> Bool = { true }
    public var setSyncEnabled: @Sendable (_ enabled: Bool) -> Void
    public var isPlaylistSyncEnabled: @Sendable (_ playlistID: UUID) -> Bool = {
        PlaylistCloudSyncPreference.isEnabled(for: $0)
    }

    public var setPlaylistSyncEnabled: @Sendable (_ playlistID: UUID, _ enabled: Bool) async -> Void = { _, _ in }
    public var syncFavorites: @Sendable (_ favorites: [FavoriteSyncDTO]) async throws -> Void
    public var pullFavorites: @Sendable () async throws -> [FavoriteSyncDTO] = { [] }
    public var syncHiddenItems: @Sendable (_ items: [HiddenItemDTO]) async throws -> Void
    public var pullHiddenItems: @Sendable () async throws -> [HiddenItemDTO] = { [] }
    public var syncPresentationPreferences: @Sendable () async throws -> [HomeSectionConfig] = {
        HomeSectionManager.shared.sections
    }

    public var loadSportsFollows: @Sendable (_ profileID: UUID?) async throws -> [SportsFollowSyncRecord] = { _ in [] }
    public var setSportsFollow: @Sendable (
        _ profileID: UUID?,
        _ kind: SportsFollowKind,
        _ displayName: String,
        _ isFollowing: Bool
    ) async throws -> [SportsFollowSyncRecord] = { _, _, _, _ in [] }
    public var observeSportsFollows: @Sendable (_ profileID: UUID?) -> AsyncStream<[SportsFollowSyncRecord]> = { _ in
        AsyncStream { $0.finish() }
    }

    public var observePresentationPreferenceChanges: @Sendable () -> AsyncStream<[HomeSectionConfig]> = {
        AsyncStream { $0.finish() }
    }

    public var performFullSync: @Sendable () async throws -> CloudSyncSummary
    public var observeRemoteChanges: @Sendable () -> AsyncStream<CloudSyncSummary> = { AsyncStream { $0.finish() } }
    public var lastSyncDate: @Sendable () -> Date? = { nil }
    public var getSyncStatus: @Sendable () -> CloudSyncStatus = { .idle }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let cloudSyncDidComplete = Notification.Name("com.pureiptv.cloudSyncDidComplete")
    static let favoritesDidChange = Notification.Name("com.pureiptv.favoritesDidChange")
    static let hiddenContentDidChange = Notification.Name("com.pureiptv.hiddenContentDidChange")
}

// MARK: - DependencyKey & Live Value

extension CloudSyncClient: DependencyKey {
    private nonisolated static let favoritesKey = "com.pureiptv.icloud.favorites"
    private nonisolated static let hiddenChannelsKey = "com.pureiptv.icloud.hiddenChannels"
    private nonisolated static let blacklistedCategoriesKey = "com.pureiptv.icloud.blacklistedCategories"
    private nonisolated static let lastSyncKey = "com.pureiptv.icloud.lastSyncTimestamp"
    private nonisolated static let homeSectionsKeyPrefix = "com.pureiptv.icloud.homeSections.v1"
    private nonisolated static let topShelfSelectionKey = "com.pureiptv.icloud.topShelfSelection.v1"
    private nonisolated static let localSportsFollowsKeyPrefix = "com.pureiptv.sportsFollows.v1"
    private nonisolated static let remoteSportsFollowsKeyPrefix = "pure.sports.v1"
    private nonisolated static let presentationPreferenceSyncGate = PresentationPreferenceSyncGate()
    private nonisolated static let sportsFollowSyncGate = PresentationPreferenceSyncGate()
    private nonisolated static let enabledKey = "com.pureiptv.isICloudSyncEnabled"
    private nonisolated static let maxFavoritesCount = 500
    private nonisolated static let maxHiddenCount = 300
    private nonisolated static let maxSportsFollowDocumentBytes = 256 * 1024
    private nonisolated static let maxSportsFollowStoreBytes = 900 * 1024
    private nonisolated static let maxICloudKeyValueStoreKeys = 1024

    private nonisolated static var presentationPlatformKey: String {
        #if os(tvOS)
            "tvos"
        #elseif os(iOS)
            "ios"
        #else
            "other"
        #endif
    }

    private static var deviceUUID: String {
        TopShelfService.syncDeviceID
    }

    public static let liveValue: CloudSyncClient = {
        let store = NSUbiquitousKeyValueStore.default
        let defaults = UserDefaults.standard

        let localHiddenChannelsKey = "com.pureiptv.hiddenChannelsMetadata"
        let localCategoriesKey = "com.pureiptv.blacklistedCategoriesMetadata"

        @Sendable func isEnabled() -> Bool {
            if defaults.object(forKey: enabledKey) == nil {
                defaults.set(true, forKey: enabledKey)
                return true
            }
            return defaults.bool(forKey: enabledKey)
        }

        @Sendable func pullRemoteFavorites() -> [FavoriteSyncDTO] {
            let keys = store.dictionaryRepresentation.keys.filter { $0 == favoritesKey || $0.hasPrefix(favoritesKey + ".profile.") }
            return keys.flatMap { key in
                guard let data = store.data(forKey: key) else { return [FavoriteSyncDTO]() }
                return (try? JSONDecoder().decode([FavoriteSyncDTO].self, from: data)) ?? [FavoriteSyncDTO]()
            }.filter { PlaylistCloudSyncPreference.isEnabled(for: $0.playlistID) }
        }

        @Sendable func pushLocalFavorites(_ favorites: [FavoriteSyncDTO]) {
            let eligibleFavorites = favorites.filter { PlaylistCloudSyncPreference.isEnabled(for: $0.playlistID) }
            let grouped = Dictionary(grouping: eligibleFavorites.prefix(maxFavoritesCount)) { $0.profileID?.uuidString ?? "legacy" }
            for (scope, records) in grouped {
                let key = scope == "legacy" ? favoritesKey : favoritesKey + ".profile." + scope
                if let data = try? JSONEncoder().encode(Array(records)) {
                    store.set(data, forKey: key)
                }
            }
            store.synchronize()
        }

        @Sendable func removeRemoteFavorites(for playlistID: UUID) {
            guard !PlaylistCloudSyncPreference.isEnabled(for: playlistID) else { return }
            store.synchronize()
            guard !PlaylistCloudSyncPreference.isEnabled(for: playlistID) else { return }
            let keys = store.dictionaryRepresentation.keys.filter {
                $0 == favoritesKey || $0.hasPrefix(favoritesKey + ".profile.")
            }
            for key in keys {
                guard let data = store.data(forKey: key),
                      let existing = try? JSONDecoder().decode([FavoriteSyncDTO].self, from: data)
                else { continue }
                let retained = existing.filter { $0.playlistID != playlistID }
                guard retained.count != existing.count else { continue }
                if retained.isEmpty {
                    store.removeObject(forKey: key)
                } else if let data = try? JSONEncoder().encode(retained) {
                    store.set(data, forKey: key)
                }
            }
            store.synchronize()
        }

        @Sendable func purgeDisabledPlaylistRecords() async {
            store.synchronize()
            for playlistID in PlaylistCloudSyncPreference.disabledPlaylistIDs() {
                guard !PlaylistCloudSyncPreference.isEnabled(for: playlistID) else { continue }
                removeRemoteFavorites(for: playlistID)
                await WatchProgressSyncClient.liveValue.removePlaylistFromSync(playlistID)
            }
        }

        @Sendable func pullRemoteHiddenItems() -> [HiddenItemDTO] {
            var items: [HiddenItemDTO] = []
            if let chanData = store.data(forKey: hiddenChannelsKey),
               let chans = try? JSONDecoder().decode([HiddenItemDTO].self, from: chanData)
            {
                items.append(contentsOf: chans)
            }
            if let catData = store.data(forKey: blacklistedCategoriesKey),
               let cats = try? JSONDecoder().decode([HiddenItemDTO].self, from: catData)
            {
                items.append(contentsOf: cats)
            }
            return items
        }

        @Sendable func pushLocalHiddenItems(_ items: [HiddenItemDTO]) {
            let channels = items.filter { $0.type == .channel }
            let categories = items.filter { $0.type == .category }

            if let cData = try? JSONEncoder().encode(Array(channels.prefix(maxHiddenCount))) {
                store.set(cData, forKey: hiddenChannelsKey)
            }
            if let catData = try? JSONEncoder().encode(Array(categories.prefix(maxHiddenCount))) {
                store.set(catData, forKey: blacklistedCategoriesKey)
            }
            store.synchronize()
        }

        @Sendable func sportsProfileScope(_ profileID: UUID?) -> String {
            profileID?.uuidString.lowercased() ?? "legacy"
        }

        @Sendable func localSportsFollowsKey(_ profileID: UUID?) -> String {
            Self.localSportsFollowsKeyPrefix + ".profile." + sportsProfileScope(profileID)
        }

        @Sendable func remoteSportsFollowsKey(profileID: UUID?, deviceID: String) -> String {
            let scope = sportsProfileScope(profileID) + "|" + deviceID
            let suffix = SHA256.hash(data: Data(scope.utf8))
                .prefix(16)
                .map { String(format: "%02x", $0) }
                .joined()
            return Self.remoteSportsFollowsKeyPrefix + "." + suffix
        }

        @Sendable func localSportsFollowRecords(profileID: UUID?) -> [SportsFollowSyncRecord] {
            guard let data = defaults.data(forKey: localSportsFollowsKey(profileID)),
                  let records = try? JSONDecoder().decode([SportsFollowSyncRecord].self, from: data)
            else { return [] }
            return records.filter { $0.isValid && $0.profileID == profileID }
        }

        @Sendable func remoteSportsFollowRecords(profileID: UUID?) -> [SportsFollowSyncRecord] {
            store.dictionaryRepresentation.keys
                .filter { $0.hasPrefix(Self.remoteSportsFollowsKeyPrefix + ".") }
                .flatMap { key -> [SportsFollowSyncRecord] in
                    guard let data = store.data(forKey: key),
                          let records = try? JSONDecoder().decode([SportsFollowSyncRecord].self, from: data)
                    else { return [] }
                    return records.filter { $0.isValid && $0.profileID == profileID }
                }
        }

        @Sendable func mergeSportsFollowRecords(
            _ records: [SportsFollowSyncRecord],
            profileID: UUID?
        ) -> [SportsFollowSyncRecord] {
            var recordsByID: [String: SportsFollowSyncRecord] = [:]
            for record in records where record.isValid && record.profileID == profileID {
                if let current = recordsByID[record.id] {
                    if sportsFollowRecordWins(record, over: current) {
                        recordsByID[record.id] = record
                    }
                } else {
                    recordsByID[record.id] = record
                }
            }
            return recordsByID.values.sorted { $0.id < $1.id }
        }

        @Sendable func persistLocalSportsFollowRecords(
            _ records: [SportsFollowSyncRecord],
            profileID: UUID?
        ) {
            guard let data = try? JSONEncoder().encode(records) else { return }
            let key = localSportsFollowsKey(profileID)
            guard defaults.data(forKey: key) != data else { return }
            defaults.set(data, forKey: key)
        }

        @Sendable func pushRemoteSportsFollowRecords(
            _ records: [SportsFollowSyncRecord],
            profileID: UUID?
        ) throws {
            let scopedRecords = records.filter { $0.isValid && $0.profileID == profileID }
            guard let data = try? JSONEncoder().encode(scopedRecords) else {
                throw SportsFollowSyncError.invalidRecord
            }
            let key = remoteSportsFollowsKey(profileID: profileID, deviceID: deviceUUID)
            guard data.count <= Self.maxSportsFollowDocumentBytes else {
                throw SportsFollowSyncError.remoteStorageLimitExceeded
            }
            let existingValues = store.dictionaryRepresentation
            let previousData = store.data(forKey: key)
            guard previousData != data else { return }
            guard previousData != nil || existingValues.count < Self.maxICloudKeyValueStoreKeys else {
                throw SportsFollowSyncError.remoteStorageLimitExceeded
            }
            var projectedValues = existingValues
            projectedValues[key] = data
            guard let projectedData = try? PropertyListSerialization.data(
                fromPropertyList: projectedValues,
                format: .binary,
                options: 0
            ),
                projectedData.count <= Self.maxSportsFollowStoreBytes
            else {
                throw SportsFollowSyncError.remoteStorageLimitExceeded
            }
            store.set(data, forKey: key)
            guard store.synchronize() else {
                if let previousData {
                    store.set(previousData, forKey: key)
                } else {
                    store.removeObject(forKey: key)
                }
                _ = store.synchronize()
                throw SportsFollowSyncError.remoteStoreUnavailable
            }
        }

        @Sendable func synchronizeSportsFollows(
            profileID: UUID?,
            requireRemoteWrite: Bool = false
        ) throws -> [SportsFollowSyncRecord] {
            try Self.sportsFollowSyncGate.withLock {
                let syncEnabled = isEnabled()
                if syncEnabled {
                    store.synchronize()
                }
                let localRecords = localSportsFollowRecords(profileID: profileID)
                let remoteRecords = syncEnabled ? remoteSportsFollowRecords(profileID: profileID) : []
                let merged = mergeSportsFollowRecords(localRecords + remoteRecords, profileID: profileID)
                persistLocalSportsFollowRecords(merged, profileID: profileID)
                if syncEnabled {
                    if requireRemoteWrite {
                        try pushRemoteSportsFollowRecords(merged, profileID: profileID)
                    } else {
                        try? pushRemoteSportsFollowRecords(merged, profileID: profileID)
                    }
                }
                return merged
            }
        }

        @Sendable func updateSportsFollow(
            profileID: UUID?,
            kind: SportsFollowKind,
            displayName: String,
            isFollowing: Bool
        ) throws -> [SportsFollowSyncRecord] {
            try Self.sportsFollowSyncGate.withLock {
                let syncEnabled = isEnabled()
                if syncEnabled {
                    store.synchronize()
                }
                let localRecords = localSportsFollowRecords(profileID: profileID)
                let remoteRecords = syncEnabled ? remoteSportsFollowRecords(profileID: profileID) : []
                let record = SportsFollowSyncRecord(
                    kind: kind,
                    displayName: displayName,
                    profileID: profileID,
                    isFollowing: isFollowing,
                    modifiedAt: .now,
                    deviceID: deviceUUID
                )
                guard record.isValid else { throw SportsFollowSyncError.invalidRecord }
                var mergedByID = Dictionary(
                    uniqueKeysWithValues: mergeSportsFollowRecords(localRecords + remoteRecords, profileID: profileID)
                        .map { ($0.id, $0) }
                )
                if let current = mergedByID[record.id] {
                    if sportsFollowRecordWins(record, over: current) {
                        mergedByID[record.id] = record
                    }
                } else {
                    mergedByID[record.id] = record
                }
                let merged = mergedByID.values.sorted { $0.id < $1.id }
                if syncEnabled {
                    try pushRemoteSportsFollowRecords(merged, profileID: profileID)
                }
                persistLocalSportsFollowRecords(merged, profileID: profileID)
                return merged
            }
        }

        @Sendable func synchronizeAllSportsFollowScopes() throws {
            let localKeys = defaults.dictionaryRepresentation().keys.filter {
                $0.hasPrefix(Self.localSportsFollowsKeyPrefix + ".profile.")
            }
            var profileIDs = Set<UUID>()
            var includesLegacyProfile = false
            for key in localKeys {
                let scope = String(key.dropFirst((Self.localSportsFollowsKeyPrefix + ".profile.").count))
                if scope == "legacy" {
                    includesLegacyProfile = true
                } else if let profileID = UUID(uuidString: scope) {
                    profileIDs.insert(profileID)
                }
            }
            let remoteKeys = store.dictionaryRepresentation.keys.filter {
                $0.hasPrefix(Self.remoteSportsFollowsKeyPrefix + ".")
            }
            for key in remoteKeys {
                guard let data = store.data(forKey: key),
                      let records = try? JSONDecoder().decode([SportsFollowSyncRecord].self, from: data)
                else { continue }
                for record in records where record.isValid {
                    if let profileID = record.profileID {
                        profileIDs.insert(profileID)
                    } else {
                        includesLegacyProfile = true
                    }
                }
            }
            if includesLegacyProfile {
                _ = try synchronizeSportsFollows(profileID: nil, requireRemoteWrite: true)
            }
            for profileID in profileIDs {
                _ = try synchronizeSportsFollows(profileID: profileID, requireRemoteWrite: true)
            }
        }

        @Sendable func syncPresentationPreferences() async throws -> [HomeSectionConfig] {
            try Self.presentationPreferenceSyncGate.withLock {
                let sectionManager = HomeSectionManager.shared
                return sectionManager.withSyncLock {
                    guard isEnabled() else { return sectionManager.sections }

                    store.synchronize()
                    let sectionsKey = Self.homeSectionsKeyPrefix + "." + Self.presentationPlatformKey
                    let localDeviceID = deviceUUID
                    let localSections = sectionManager.sections
                    let localModifiedAt = sectionManager.syncModifiedAt
                    let localSourceDeviceID = sectionManager.syncDeviceID ?? localDeviceID
                    let remoteSectionsData = store.data(forKey: sectionsKey)
                    let remoteSections = remoteSectionsData.flatMap {
                        try? JSONDecoder().decode(HomeSectionPreferenceSyncDTO.self, from: $0)
                    }

                    if remoteSectionsData == nil || remoteSections?.isSupported == true {
                        let remoteSectionsWin = remoteSections.map { remote in
                            guard let localModifiedAt else { return true }
                            return preferenceSyncRecordWins(
                                candidateDate: remote.modifiedAt,
                                candidateDeviceID: remote.deviceID,
                                over: localModifiedAt,
                                currentDeviceID: localSourceDeviceID
                            )
                        } ?? false
                        if let remoteSections, remoteSectionsWin {
                            sectionManager.applySyncedSections(
                                remoteSections.knownSections,
                                modifiedAt: remoteSections.modifiedAt,
                                deviceID: remoteSections.deviceID
                            )
                        } else {
                            let modifiedAt = localModifiedAt ?? Date()
                            let entries = localSections.map {
                                HomeSectionPreferenceEntry(id: $0.type.rawValue, isVisible: $0.isVisible)
                            }
                            let record = HomeSectionPreferenceSyncDTO(
                                schemaVersion: 1,
                                sections: entries,
                                modifiedAt: modifiedAt,
                                deviceID: localSourceDeviceID
                            )
                            if let data = try? JSONEncoder().encode(record), data.count <= 8192 {
                                store.set(data, forKey: sectionsKey)
                                sectionManager.applySyncedSections(
                                    localSections,
                                    modifiedAt: modifiedAt,
                                    deviceID: localSourceDeviceID
                                )
                            }
                        }
                    }

                    #if os(tvOS)
                        TopShelfService.shared.withContentSelectionSyncLock {
                            let localTopShelf = TopShelfService.shared.contentSelection
                            let localTopShelfModifiedAt = TopShelfService.shared.contentSelectionSyncModifiedAt
                            let localTopShelfSourceDeviceID = TopShelfService.shared.contentSelectionSyncDeviceID ?? localDeviceID
                            let remoteTopShelfData = store.data(forKey: Self.topShelfSelectionKey)
                            let remoteTopShelf = remoteTopShelfData.flatMap {
                                try? JSONDecoder().decode(TopShelfSelectionSyncDTO.self, from: $0)
                            }
                            if remoteTopShelfData == nil || remoteTopShelf?.isSupported == true {
                                let remoteTopShelfWins = remoteTopShelf.map { remote in
                                    guard let localTopShelfModifiedAt else { return true }
                                    return preferenceSyncRecordWins(
                                        candidateDate: remote.modifiedAt,
                                        candidateDeviceID: remote.deviceID,
                                        over: localTopShelfModifiedAt,
                                        currentDeviceID: localTopShelfSourceDeviceID
                                    )
                                } ?? false
                                if let remoteTopShelf, remoteTopShelfWins {
                                    TopShelfService.shared.applySyncedContentSelection(
                                        remoteTopShelf.selection,
                                        modifiedAt: remoteTopShelf.modifiedAt,
                                        deviceID: remoteTopShelf.deviceID
                                    )
                                } else {
                                    let modifiedAt = localTopShelfModifiedAt ?? Date()
                                    let record = TopShelfSelectionSyncDTO(
                                        schemaVersion: 1,
                                        selection: localTopShelf,
                                        modifiedAt: modifiedAt,
                                        deviceID: localTopShelfSourceDeviceID
                                    )
                                    if let data = try? JSONEncoder().encode(record), data.count <= 8192 {
                                        store.set(data, forKey: Self.topShelfSelectionKey)
                                        TopShelfService.shared.applySyncedContentSelection(
                                            localTopShelf,
                                            modifiedAt: modifiedAt,
                                            deviceID: localTopShelfSourceDeviceID
                                        )
                                    }
                                }
                            }
                        }
                    #endif

                    store.synchronize()
                    return sectionManager.sections
                }
            }
        }

        @Sendable func mergeRemoteFavoritesIntoDatabase(remote: [FavoriteSyncDTO], modelContainer: ModelContainer) async throws -> Int {
            guard !remote.isEmpty else { return 0 }
            let context = ModelContext(modelContainer)
            var merged = 0

            for dto in remote where PlaylistCloudSyncPreference.isEnabled(for: dto.playlistID) {
                let id = dto.id
                let type = dto.type
                let profileID = dto.profileID
                let descriptor = FetchDescriptor<FavoriteItem>(
                    predicate: #Predicate { $0.id == id && $0.type == type && $0.profileID == profileID }
                )
                if let local = try context.fetch(descriptor).first(where: { $0.playlistID == dto.playlistID }) {
                    // Preserve timestamped soft-deletes even when addedAt is unchanged.
                    if favoriteSyncWins(dto, over: FavoriteSyncDTO(from: local)) {
                        local.title = dto.title
                        local.coverURL = dto.coverURL
                        local.streamURL = dto.streamURL
                        local.addedAt = dto.addedAt
                        local.playlistID = dto.playlistID
                        local.profileID = dto.profileID
                        local.removedAt = dto.removedAt
                        merged += 1
                    }
                } else {
                    let newItem = dto.toFavoriteItem()
                    context.insert(newItem)
                    merged += 1
                }
            }

            if merged > 0 {
                try context.save()
                await MainActor.run {
                    NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
                }
            }
            return merged
        }

        @Sendable func mergeRemoteHiddenItemsIntoDefaults(remote: [HiddenItemDTO]) async -> Int {
            guard !remote.isEmpty else { return 0 }

            let decoder = JSONDecoder()
            let encoder = JSONEncoder()

            var localChannels: [HiddenItemDTO] = []
            if let data = defaults.data(forKey: localHiddenChannelsKey) {
                localChannels = (try? decoder.decode([HiddenItemDTO].self, from: data)) ?? []
            }

            var localCats: [HiddenItemDTO] = []
            if let data = defaults.data(forKey: localCategoriesKey) {
                localCats = (try? decoder.decode([HiddenItemDTO].self, from: data)) ?? []
            }

            var mergedCount = 0

            // Merge channels
            var channelMap = Dictionary(uniqueKeysWithValues: localChannels.map { ($0.id, $0) })
            for r in remote where r.type == .channel {
                if let existing = channelMap[r.id] {
                    if r.hiddenAt > existing.hiddenAt {
                        channelMap[r.id] = r
                        mergedCount += 1
                    }
                } else {
                    channelMap[r.id] = r
                    mergedCount += 1
                }
            }

            // Merge categories
            var catMap = Dictionary(uniqueKeysWithValues: localCats.map { ($0.id, $0) })
            for r in remote where r.type == .category {
                if let existing = catMap[r.id] {
                    if r.hiddenAt > existing.hiddenAt {
                        catMap[r.id] = r
                        mergedCount += 1
                    }
                } else {
                    catMap[r.id] = r
                    mergedCount += 1
                }
            }

            if mergedCount > 0 {
                let newChannels = Array(channelMap.values)
                let newCats = Array(catMap.values)

                if let cData = try? encoder.encode(newChannels) {
                    defaults.set(cData, forKey: localHiddenChannelsKey)
                }
                if let catData = try? encoder.encode(newCats) {
                    defaults.set(catData, forKey: localCategoriesKey)
                }

                await MainActor.run {
                    NotificationCenter.default.post(name: .hiddenContentDidChange, object: nil)
                }
            }

            return mergedCount
        }

        @Sendable func fullSync() async throws -> CloudSyncSummary {
            await purgeDisabledPlaylistRecords()
            guard isEnabled() else {
                return CloudSyncSummary(
                    favoritesCount: 0,
                    hiddenChannelsCount: 0,
                    blacklistedCategoriesCount: 0,
                    watchProgressCount: 0,
                    lastSyncDate: Date(),
                    deviceID: deviceUUID
                )
            }

            // Open persistence before touching either cloud or local sync state.
            let modelContainer = try SharedDatabaseConfig.shared

            store.synchronize()

            // 1. Pull & Merge Remote Favorites
            let remoteFavorites = pullRemoteFavorites()
            _ = try await mergeRemoteFavoritesIntoDatabase(remote: remoteFavorites, modelContainer: modelContainer)

            // 2. Read all local favorites and push union to cloud
            let context = ModelContext(modelContainer)
            let localFavorites = try context.fetch(FetchDescriptor<FavoriteItem>())
                .filter { PlaylistCloudSyncPreference.isEnabled(for: $0.playlistID) }
            func identity(_ dto: FavoriteSyncDTO) -> String {
                "\(dto.profileID?.uuidString ?? "legacy")|\(dto.type)|\(dto.playlistID?.uuidString ?? "")|\(dto.id)"
            }
            var favoriteMap: [String: FavoriteSyncDTO] = [:]
            for remote in remoteFavorites {
                let key = identity(remote)
                if let current = favoriteMap[key] {
                    if favoriteSyncWins(remote, over: current) {
                        favoriteMap[key] = remote
                    }
                } else {
                    favoriteMap[key] = remote
                }
            }
            for local in localFavorites {
                let dto = FavoriteSyncDTO(from: local)
                let key = identity(dto)
                if let existing = favoriteMap[key] {
                    if favoriteSyncWins(dto, over: existing) {
                        favoriteMap[key] = dto
                    }
                } else {
                    favoriteMap[key] = dto
                }
            }
            let mergedFavorites = Array(favoriteMap.values)
            pushLocalFavorites(mergedFavorites)

            // 3. Pull & Merge Remote Hidden Items
            let remoteHidden = pullRemoteHiddenItems()
            _ = await mergeRemoteHiddenItemsIntoDefaults(remote: remoteHidden)

            // 4. Read local hidden items and push union to cloud
            var allLocalHidden: [HiddenItemDTO] = []
            if let cData = defaults.data(forKey: localHiddenChannelsKey),
               let chans = try? JSONDecoder().decode([HiddenItemDTO].self, from: cData)
            {
                allLocalHidden.append(contentsOf: chans)
            }
            if let catData = defaults.data(forKey: localCategoriesKey),
               let cats = try? JSONDecoder().decode([HiddenItemDTO].self, from: catData)
            {
                allLocalHidden.append(contentsOf: cats)
            }

            var hiddenMap = Dictionary(uniqueKeysWithValues: remoteHidden.map { ($0.id, $0) })
            for l in allLocalHidden {
                if let existing = hiddenMap[l.id] {
                    if l.hiddenAt >= existing.hiddenAt {
                        hiddenMap[l.id] = l
                    }
                } else {
                    hiddenMap[l.id] = l
                }
            }
            let mergedHidden = Array(hiddenMap.values)
            pushLocalHiddenItems(mergedHidden)

            // 5. Watch Progress Sync
            let watchMerged = try await WatchProgressSyncClient.liveValue.pullAndMergeRemoteChanges()

            // Sports follows contain normalized identities only, with no playlist or provider data.
            try synchronizeAllSportsFollowScopes()

            _ = try await syncPresentationPreferences()

            let now = Date()
            defaults.set(now.timeIntervalSince1970, forKey: lastSyncKey)
            store.set(now.timeIntervalSince1970, forKey: lastSyncKey)
            store.synchronize()

            let summary = CloudSyncSummary(
                favoritesCount: mergedFavorites.count,
                hiddenChannelsCount: mergedHidden.filter { $0.type == .channel }.count,
                blacklistedCategoriesCount: mergedHidden.filter { $0.type == .category }.count,
                watchProgressCount: watchMerged,
                lastSyncDate: now,
                deviceID: deviceUUID
            )

            await MainActor.run {
                NotificationCenter.default.post(name: .cloudSyncDidComplete, object: nil, userInfo: ["summary": summary])
            }

            return summary
        }

        let client = CloudSyncClient(
            isSyncEnabled: {
                isEnabled()
            },
            setSyncEnabled: { enabled in
                defaults.set(enabled, forKey: enabledKey)
            },
            isPlaylistSyncEnabled: { playlistID in
                PlaylistCloudSyncPreference.isEnabled(for: playlistID)
            },
            setPlaylistSyncEnabled: { playlistID, enabled in
                guard PlaylistCloudSyncPreference.isEnabled(for: playlistID) == enabled,
                      !enabled
                else { return }
                await purgeDisabledPlaylistRecords()
            },
            syncFavorites: { favorites in
                guard isEnabled() else { return }
                pushLocalFavorites(favorites)
            },
            pullFavorites: {
                await purgeDisabledPlaylistRecords()
                guard isEnabled() else { return [] }
                return pullRemoteFavorites()
            },
            syncHiddenItems: { items in
                guard isEnabled() else { return }
                pushLocalHiddenItems(items)
            },
            pullHiddenItems: {
                guard isEnabled() else { return [] }
                return pullRemoteHiddenItems()
            },
            syncPresentationPreferences: {
                try await syncPresentationPreferences()
            },
            loadSportsFollows: { profileID in
                try synchronizeSportsFollows(profileID: profileID)
            },
            setSportsFollow: { profileID, kind, displayName, isFollowing in
                try updateSportsFollow(
                    profileID: profileID,
                    kind: kind,
                    displayName: displayName,
                    isFollowing: isFollowing
                )
            },
            observeSportsFollows: { profileID in
                AsyncStream { continuation in
                    let observer = NotificationCenter.default.addObserver(
                        forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                        object: store,
                        queue: .main
                    ) { notification in
                        if let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
                           !changedKeys.contains(where: { $0.hasPrefix(Self.remoteSportsFollowsKeyPrefix + ".") })
                        {
                            return
                        }
                        Task {
                            guard isEnabled() else { return }
                            let records = (try? synchronizeSportsFollows(profileID: profileID))
                                ?? localSportsFollowRecords(profileID: profileID)
                            continuation.yield(records)
                        }
                    }
                    continuation.onTermination = { @Sendable _ in
                        NotificationCenter.default.removeObserver(observer)
                    }
                }
            },
            observePresentationPreferenceChanges: {
                AsyncStream { continuation in
                    let observer = NotificationCenter.default.addObserver(
                        forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                        object: store,
                        queue: .main
                    ) { _ in
                        Task {
                            if let sections = try? await syncPresentationPreferences() {
                                continuation.yield(sections)
                            }
                        }
                    }

                    continuation.onTermination = { @Sendable _ in
                        NotificationCenter.default.removeObserver(observer)
                    }
                }
            },
            performFullSync: {
                try await fullSync()
            },
            observeRemoteChanges: {
                AsyncStream { continuation in
                    let observer = NotificationCenter.default.addObserver(
                        forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                        object: store,
                        queue: .main
                    ) { _ in
                        Task {
                            await purgeDisabledPlaylistRecords()
                            guard isEnabled() else { return }
                            if let summary = try? await fullSync() {
                                continuation.yield(summary)
                            }
                        }
                    }

                    continuation.onTermination = { @Sendable _ in
                        NotificationCenter.default.removeObserver(observer)
                    }
                }
            },
            lastSyncDate: {
                let timestamp = defaults.double(forKey: lastSyncKey)
                guard timestamp > 0 else { return nil }
                return Date(timeIntervalSince1970: timestamp)
            },
            getSyncStatus: {
                let timestamp = defaults.double(forKey: lastSyncKey)
                if timestamp > 0 {
                    return .success(Date(timeIntervalSince1970: timestamp))
                }
                return .idle
            }
        )

        // Purge records on every device when an iCloud playlist opt-out arrives,
        // including when global sync is disabled or Settings is not observing.
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: nil
        ) { notification in
            if let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
               !changedKeys.contains(where: PlaylistCloudSyncPreference.isPreferenceKey)
            {
                return
            }
            Task.detached(priority: .utility) {
                await purgeDisabledPlaylistRecords()
            }
        }

        return client
    }()

    public static let testValue: CloudSyncClient = .init()
}

// MARK: - DependencyValues Registration

public extension DependencyValues {
    var cloudSyncClient: CloudSyncClient {
        get { self[CloudSyncClient.self] }
        set { self[CloudSyncClient.self] = newValue }
    }
}
