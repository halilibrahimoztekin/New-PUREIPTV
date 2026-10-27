import ComposableArchitecture
import CryptoKit
import Foundation
import SwiftData

private actor WatchProgressSyncWriter {
    private let store: NSUbiquitousKeyValueStore
    private let deviceID: String
    private let itemPrefix = "pureiptv_watch_item_"
    private let deletionPrefix = "pureiptv_watch_del_"
    private let fencePrefix = "pureiptv_watch_del_fence_"
    private let retentionFloorPrefix = "pureiptv_watch_retention_floor_"
    private let maxRecordsPerDevice = 200
    private let maxManagedKeys = 700
    private let maxKVSKeys = 900
    private let maxKVSBytes = 700 * 1024

    init(store: NSUbiquitousKeyValueStore, deviceID: String) {
        self.store = store
        self.deviceID = deviceID
    }

    func write(_ record: WatchProgressSyncRecord) throws {
        store.synchronize()
        guard let data = try? JSONEncoder().encode(record), data.count <= 16 * 1024 else { return }
        let scopedIdentity = syncIdentity(record)
        let itemKey = itemPrefix + encoded(deviceID) + "_" + keyDigest(scopedIdentity)
        let deletionKey = deletionPrefix + encoded(deviceID) + "_" + keyDigest(scopedIdentity)
        let targetKey = record.isDeleted == true ? deletionKey : itemKey
        guard pruneGlobalStorage(reservingBytes: data.count, reservingKey: store.object(forKey: targetKey) == nil) else {
            return
        }

        if record.isDeleted == true {
            let existingDate = store.data(forKey: deletionKey)
                .flatMap { try? JSONDecoder().decode(WatchProgressSyncRecord.self, from: $0) }
                .map(\.lastWatchedAt) ?? .distantPast
            guard record.lastWatchedAt >= existingDate else { return }
            store.set(data, forKey: deletionKey)
            pruneTombstones()
        } else {
            let currentDate = store.data(forKey: itemKey)
                .flatMap { try? JSONDecoder().decode(WatchProgressSyncRecord.self, from: $0) }
                .map(\.lastWatchedAt) ?? .distantPast
            guard record.lastWatchedAt >= currentDate else { return }
            store.set(data, forKey: itemKey)
            pruneItems()
        }
        _ = pruneGlobalStorage()
        store.synchronize()
    }

    private func pruneItems() {
        let records = records(withPrefix: itemPrefix).filter { $0.value.deviceId == deviceID }
            .sorted { $0.value.lastWatchedAt < $1.value.lastWatchedAt }
        if records.count > maxRecordsPerDevice {
            for (key, _) in records.prefix(records.count - maxRecordsPerDevice) {
                store.removeObject(forKey: key)
            }
        }
    }

    private func pruneTombstones() {
        let records = records(withPrefix: deletionPrefix).filter { $0.value.deviceId == deviceID }
            .sorted { $0.value.lastWatchedAt < $1.value.lastWatchedAt }
        guard records.count > maxRecordsPerDevice else { return }
        let expired = records.prefix(records.count - maxRecordsPerDevice)
        for (key, record) in expired {
            let fenceKey = fencePrefix + encoded(deviceID) + ":" + keyDigest(syncIdentity(record))
            let existingDate = store.data(forKey: fenceKey)
                .flatMap { try? JSONDecoder().decode(WatchProgressSyncRecord.self, from: $0) }
                .map(\.lastWatchedAt) ?? .distantPast
            let latest = record.lastWatchedAt >= existingDate ? record : WatchProgressSyncRecord(
                id: record.id, type: record.type, title: record.title,
                seriesTitle: record.seriesTitle, coverURL: record.coverURL, streamURL: record.streamURL,
                progress: record.progress, duration: record.duration,
                lastWatchedAt: existingDate, playlistID: record.playlistID, seriesID: record.seriesID,
                profileID: record.profileID, deviceId: deviceID, isDeleted: true
            )
            if let fenceData = try? JSONEncoder().encode(latest) {
                store.set(fenceData, forKey: fenceKey)
            }
            store.removeObject(forKey: key)
        }
        let fencePrefixForDevice = fencePrefix + encoded(deviceID) + ":"
        let fences = store.dictionaryRepresentation.compactMap { key, value -> (String, Date)? in
            guard key.hasPrefix(fencePrefixForDevice), let data = value as? Data,
                  let record = try? JSONDecoder().decode(WatchProgressSyncRecord.self, from: data)
            else { return nil }
            return (key, record.lastWatchedAt)
        }.sorted { $0.1 < $1.1 }
        if fences.count > maxRecordsPerDevice {
            let expiredFences = fences.prefix(fences.count - maxRecordsPerDevice)
            let floorKey = retentionFloorPrefix + encoded(deviceID)
            let existingFloor = store.object(forKey: floorKey) as? Date ?? .distantPast
            let newFloor = expiredFences.map(\.1).max() ?? existingFloor
            store.set(max(existingFloor, newFloor), forKey: floorKey)
            // This is the bounded KVS retention policy: remote history older
            // than this floor is no longer synchronized, while local history
            // remains available on each device.
            for (key, _) in expiredFences {
                store.removeObject(forKey: key)
            }
        }
    }

    private func records(withPrefix prefix: String) -> [(key: String, value: WatchProgressSyncRecord)] {
        store.dictionaryRepresentation.compactMap { key, value in
            guard
                key.hasPrefix(prefix),
                let data = value as? Data,
                let record = try? JSONDecoder().decode(WatchProgressSyncRecord.self, from: data)
            else { return nil }
            return (key, record)
        }
    }

    private func pruneGlobalStorage(reservingBytes: Int = 0, reservingKey: Bool = false) -> Bool {
        while true {
            let values = store.dictionaryRepresentation
            var managed: [(key: String, date: Date, size: Int, kind: Int, deviceID: String)] = []
            for (key, value) in values {
                if key.hasPrefix(itemPrefix) || key.hasPrefix(deletionPrefix),
                   let data = value as? Data,
                   let record = try? JSONDecoder().decode(WatchProgressSyncRecord.self, from: data),
                   let sourceDeviceID = record.deviceId
                {
                    managed.append((key, record.lastWatchedAt, data.count, record.isDeleted == true ? 1 : 0, sourceDeviceID))
                } else if key.hasPrefix(fencePrefix), let data = value as? Data,
                          let record = try? JSONDecoder().decode(WatchProgressSyncRecord.self, from: data),
                          let sourceDeviceID = record.deviceId
                {
                    managed.append((key, record.lastWatchedAt, data.count, 2, sourceDeviceID))
                }
            }
            let totalBytes = (try? PropertyListSerialization.data(
                fromPropertyList: values,
                format: .binary,
                options: 0
            ).count) ?? values.values.reduce(0) { partial, value in
                partial + ((value as? Data)?.count ?? (value as? String)?.utf8.count ?? MemoryLayout<Int>.size)
            }
            let overBudget = managed.count + (reservingKey ? 1 : 0) > maxManagedKeys
                || values.count + (reservingKey ? 1 : 0) > maxKVSKeys
                || totalBytes + reservingBytes > maxKVSBytes
            guard overBudget else { return true }
            guard let oldest = managed.min(by: {
                $0.kind == $1.kind ? $0.date < $1.date : $0.kind < $1.kind
            }) else { return false }
            if oldest.kind > 0 {
                advanceRetentionFloor(for: oldest.deviceID, through: oldest.date)
            }
            store.removeObject(forKey: oldest.key)
        }
    }

    private func advanceRetentionFloor(for sourceDeviceID: String, through date: Date) {
        let key = retentionFloorPrefix + encoded(sourceDeviceID)
        let current = store.object(forKey: key) as? Date ?? .distantPast
        store.set(max(current, date), forKey: key)
    }

    private func encoded(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    private func syncIdentity(_ record: WatchProgressSyncRecord) -> String {
        "\(record.profileID?.uuidString ?? "legacy")|\(record.type)|\(record.playlistID?.uuidString ?? "")|\(record.id)"
    }

    private func keyDigest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).prefix(16)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func decoded(_ value: String) -> String? {
        let padded = value
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "-", with: "+")
        let base64 = padded + String(repeating: "=", count: (4 - padded.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// Client responsible for cross-device watch progress synchronization via iCloud Key-Value Store (Madde #43).
public struct WatchProgressSyncClient: Sendable {
    public var isSyncEnabled: @Sendable () -> Bool
    public var setSyncEnabled: @Sendable (Bool) -> Void
    public var syncItem: @Sendable (_ item: WatchHistoryItem) async throws -> Void
    public var markUnwatched: @Sendable (_ id: String) async throws -> Void
    public var pullAndMergeRemoteChanges: @Sendable () async throws -> Int
    public var observeRemoteChanges: @Sendable () -> AsyncStream<[WatchProgressSyncRecord]>

    public init(
        isSyncEnabled: @escaping @Sendable () -> Bool,
        setSyncEnabled: @escaping @Sendable (Bool) -> Void,
        syncItem: @escaping @Sendable (WatchHistoryItem) async throws -> Void,
        markUnwatched: @escaping @Sendable (String) async throws -> Void,
        pullAndMergeRemoteChanges: @escaping @Sendable () async throws -> Int,
        observeRemoteChanges: @escaping @Sendable () -> AsyncStream<[WatchProgressSyncRecord]>
    ) {
        self.isSyncEnabled = isSyncEnabled
        self.setSyncEnabled = setSyncEnabled
        self.syncItem = syncItem
        self.markUnwatched = markUnwatched
        self.pullAndMergeRemoteChanges = pullAndMergeRemoteChanges
        self.observeRemoteChanges = observeRemoteChanges
    }
}

extension WatchProgressSyncClient: DependencyKey {
    private nonisolated static let keyPrefix = "pureiptv_watch_prog_"
    private nonisolated static let indexKey = "pureiptv_watch_prog_index"
    private nonisolated static let enabledKey = "com.pureiptv.isICloudSyncEnabled"
    private nonisolated static let deviceIDKey = "com.pureiptv.iCloudSyncDeviceUUID"

    private static var deviceUUID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: deviceIDKey) {
            return existing
        }
        let newID = UUID().uuidString
        defaults.set(newID, forKey: deviceIDKey)
        return newID
    }

    public static let liveValue: WatchProgressSyncClient = {
        let store = NSUbiquitousKeyValueStore.default
        let localDeviceID = deviceUUID
        let writer = WatchProgressSyncWriter(store: store, deviceID: localDeviceID)

        // Default to enabled if not explicitly set
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            UserDefaults.standard.set(true, forKey: enabledKey)
        }

        @Sendable func isEnabled() -> Bool {
            UserDefaults.standard.bool(forKey: enabledKey)
        }

        let client = WatchProgressSyncClient(
            isSyncEnabled: {
                isEnabled()
            },
            setSyncEnabled: { enabled in
                UserDefaults.standard.set(enabled, forKey: enabledKey)
            },
            syncItem: { item in
                guard isEnabled() else { return }
                _ = try SharedDatabaseConfig.shared

                let record = WatchProgressSyncRecord(from: item, deviceId: localDeviceID)
                try await writer.write(record)
            },
            markUnwatched: { id in
                guard isEnabled() else { return }
                _ = try SharedDatabaseConfig.shared
                let record = WatchProgressSyncRecord(
                    id: id,
                    type: "deleted",
                    title: "",
                    progress: 0,
                    duration: 0,
                    lastWatchedAt: Date(),
                    deviceId: localDeviceID,
                    isDeleted: true
                )
                try await writer.write(record)
            },
            pullAndMergeRemoteChanges: {
                guard isEnabled() else { return 0 }
                let modelContainer = try SharedDatabaseConfig.shared

                store.synchronize()
                let values = store.dictionaryRepresentation
                var remoteRecords: [WatchProgressSyncRecord] = values.compactMap { key, value in
                    guard
                        key.hasPrefix("pureiptv_watch_item_") || key.hasPrefix("pureiptv_watch_del_"),
                        let data = value as? Data,
                        let record = try? JSONDecoder().decode(WatchProgressSyncRecord.self, from: data)
                    else { return nil }
                    return record
                }
                // Migrate records written by earlier app versions.
                let legacyIDs = (store.array(forKey: indexKey) as? [String]) ?? []
                for id in legacyIDs {
                    guard
                        let data = store.data(forKey: "\(keyPrefix)\(id)"),
                        let record = try? JSONDecoder().decode(WatchProgressSyncRecord.self, from: data)
                    else { continue }
                    remoteRecords.append(record)
                }

                func scopedIdentity(_ record: WatchProgressSyncRecord) -> String {
                    "\(record.profileID?.uuidString ?? "legacy")|\(record.type)|\(record.playlistID?.uuidString ?? "")|\(record.id)"
                }
                var newestLive: [String: WatchProgressSyncRecord] = [:]
                var newestDeletion: [String: WatchProgressSyncRecord] = [:]
                var legacyWildcardDeletions: [String: Date] = [:]
                for record in remoteRecords {
                    if record.isDeleted == true {
                        if record.type == "deleted", record.profileID == nil {
                            legacyWildcardDeletions[record.id] = max(legacyWildcardDeletions[record.id] ?? .distantPast, record.lastWatchedAt)
                            continue
                        }
                        let key = scopedIdentity(record)
                        if record.lastWatchedAt > (newestDeletion[key]?.lastWatchedAt ?? .distantPast) {
                            newestDeletion[key] = record
                        }
                    } else {
                        let key = scopedIdentity(record)
                        if record.lastWatchedAt > (newestLive[key]?.lastWatchedAt ?? .distantPast) {
                            newestLive[key] = record
                        }
                    }
                }
                var deletionFences: [String: Date] = [:]
                var legacyDeletionFences: [String: Date] = [:]
                var retentionFloors: [String: Date] = [:]
                for (key, value) in values {
                    if key.hasPrefix("pureiptv_watch_retention_floor_"), let floor = value as? Date {
                        let encodedDeviceID = String(key.dropFirst("pureiptv_watch_retention_floor_".count))
                        let paddedDeviceID = encodedDeviceID
                            .replacingOccurrences(of: "_", with: "/")
                            .replacingOccurrences(of: "-", with: "+")
                        let base64DeviceID = paddedDeviceID
                            + String(repeating: "=", count: (4 - paddedDeviceID.count % 4) % 4)
                        if let deviceData = Data(base64Encoded: base64DeviceID),
                           let sourceDeviceID = String(data: deviceData, encoding: .utf8)
                        {
                            retentionFloors[sourceDeviceID] = max(retentionFloors[sourceDeviceID] ?? .distantPast, floor)
                        }
                        continue
                    }
                    guard
                        key.hasPrefix("pureiptv_watch_del_fence_"),
                        let data = value as? Data,
                        let record = try? JSONDecoder().decode(WatchProgressSyncRecord.self, from: data)
                    else { continue }
                    if record.type == "deleted", record.profileID == nil {
                        legacyDeletionFences[record.id] = max(
                            legacyDeletionFences[record.id] ?? .distantPast,
                            record.lastWatchedAt
                        )
                    } else if record.isDeleted == true {
                        let identity = scopedIdentity(record)
                        deletionFences[identity] = max(
                            deletionFences[identity] ?? .distantPast,
                            record.lastWatchedAt
                        )
                    }
                }
                // Apply each source device's retention floor before conflict
                // resolution so a suppressed row cannot hide another device's
                // newer eligible progress for the same content.
                newestLive.removeAll(keepingCapacity: true)
                for record in remoteRecords where record.isDeleted != true {
                    let sourceFloor = retentionFloors[record.deviceId ?? ""] ?? .distantPast
                    guard record.lastWatchedAt > sourceFloor else { continue }
                    let key = scopedIdentity(record)
                    if record.lastWatchedAt > (newestLive[key]?.lastWatchedAt ?? .distantPast) {
                        newestLive[key] = record
                    }
                }
                let allIDs = Set(newestLive.keys).union(newestDeletion.keys)

                var mergedCount = 0
                let context = ModelContext(modelContainer)

                for identity in allIDs {
                    guard let remoteRecord = newestLive[identity] ?? newestDeletion[identity] else { continue }
                    let id = remoteRecord.id
                    let type = remoteRecord.type
                    let profileID = remoteRecord.profileID
                    let playlistID = remoteRecord.playlistID
                    if let remoteRecord = newestLive[identity],
                       remoteRecord.lastWatchedAt <= (retentionFloors[remoteRecord.deviceId ?? ""] ?? .distantPast)
                    {
                        // Never delete local history when the bounded remote
                        // synchronization horizon suppresses an older record.
                        continue
                    }
                    let descriptor = FetchDescriptor<WatchHistoryItem>(predicate: #Predicate {
                        $0.id == id && $0.type == type && $0.profileID == profileID
                    })
                    let localItem = try context.fetch(descriptor).first(where: { $0.playlistID == playlistID })
                    let legacyWildcard = profileID == nil ? (legacyWildcardDeletions[id] ?? .distantPast) : .distantPast
                    let tombstoneDate = max(
                        newestDeletion[identity]?.lastWatchedAt ?? .distantPast,
                        max(
                            deletionFences[identity] ?? .distantPast,
                            profileID == nil ? max(legacyDeletionFences[id] ?? .distantPast, legacyWildcard) : .distantPast
                        )
                    )
                    guard let remoteRecord = newestLive[identity] else {
                        if let localItem {
                            if tombstoneDate >= localItem.lastWatchedAt {
                                localItem.lastWatchedAt = tombstoneDate
                                localItem.removedAt = tombstoneDate
                                mergedCount += 1
                            }
                        } else {
                            context.insert(remoteRecord.toWatchHistoryItem())
                            mergedCount += 1
                        }
                        continue
                    }

                    guard remoteRecord.lastWatchedAt > tombstoneDate else {
                        let deletionDate = tombstoneDate
                        if let localItem, localItem.lastWatchedAt <= deletionDate {
                            localItem.lastWatchedAt = deletionDate
                            localItem.removedAt = deletionDate
                            mergedCount += 1
                        }
                        continue
                    }

                    if let localItem {
                        if remoteRecord.lastWatchedAt > localItem.lastWatchedAt {
                            remoteRecord.apply(to: localItem)
                            mergedCount += 1
                        }
                    } else {
                        context.insert(remoteRecord.toWatchHistoryItem())
                        mergedCount += 1
                    }
                }

                // Old id-only tombstones are retained as legacy-profile wildcard
                // markers. They never remove records belonging to a named profile.
                let legacyMarkers = Dictionary(uniqueKeysWithValues: legacyWildcardDeletions.map { ($0.key, $0.value) })
                for (id, date) in legacyMarkers {
                    let descriptor = FetchDescriptor<WatchHistoryItem>(predicate: #Predicate {
                        $0.id == id && $0.profileID == nil
                    })
                    for item in try context.fetch(descriptor) where item.lastWatchedAt <= date {
                        item.lastWatchedAt = max(item.lastWatchedAt, date)
                        item.removedAt = max(item.removedAt ?? .distantPast, date)
                        mergedCount += 1
                    }
                }

                if mergedCount > 0 {
                    try context.save()
                    NotificationCenter.default.post(name: .watchHistoryDidChange, object: nil)
                }

                return mergedCount
            },
            observeRemoteChanges: {
                AsyncStream { continuation in
                    let observer = NotificationCenter.default.addObserver(
                        forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                        object: store,
                        queue: .main
                    ) { notification in
                        guard isEnabled() else { return }

                        let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
                        // Process on server change or initial sync
                        if reason == NSUbiquitousKeyValueStoreServerChange || reason == NSUbiquitousKeyValueStoreInitialSyncChange {
                            guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
                                continuation.yield([])
                                return
                            }

                            var records: [WatchProgressSyncRecord] = []
                            for key in changedKeys where key.hasPrefix(keyPrefix)
                                || key.hasPrefix("pureiptv_watch_item_")
                                || key.hasPrefix("pureiptv_watch_del_")
                            {
                                if let data = store.data(forKey: key),
                                   let record = try? JSONDecoder().decode(WatchProgressSyncRecord.self, from: data)
                                {
                                    records.append(record)
                                }
                            }
                            continuation.yield(records)
                        }
                    }

                    continuation.onTermination = { _ in
                        NotificationCenter.default.removeObserver(observer)
                    }
                }
            }
        )

        // Automatically merge external iCloud updates when received
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: nil
        ) { _ in
            Task.detached(priority: .utility) {
                _ = try? await client.pullAndMergeRemoteChanges()
            }
        }

        return client
    }()

    public static let testValue: WatchProgressSyncClient = .init(
        isSyncEnabled: { true },
        setSyncEnabled: { _ in },
        syncItem: { _ in },
        markUnwatched: { _ in },
        pullAndMergeRemoteChanges: { 0 },
        observeRemoteChanges: { .finished }
    )
}

public extension DependencyValues {
    var watchProgressSyncClient: WatchProgressSyncClient {
        get { self[WatchProgressSyncClient.self] }
        set { self[WatchProgressSyncClient.self] = newValue }
    }
}
