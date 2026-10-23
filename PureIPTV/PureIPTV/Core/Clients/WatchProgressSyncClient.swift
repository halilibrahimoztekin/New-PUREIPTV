import ComposableArchitecture
import Foundation
import SwiftData

/// Client responsible for cross-device watch progress synchronization via iCloud Key-Value Store (Madde #43).
public struct WatchProgressSyncClient: Sendable {
    public var isSyncEnabled: @Sendable () -> Bool
    public var setSyncEnabled: @Sendable (Bool) -> Void
    public var syncItem: @Sendable (_ item: WatchHistoryItem) async throws -> Void
    public var pullAndMergeRemoteChanges: @Sendable () async throws -> Int
    public var observeRemoteChanges: @Sendable () -> AsyncStream<[WatchProgressSyncRecord]>

    public init(
        isSyncEnabled: @escaping @Sendable () -> Bool,
        setSyncEnabled: @escaping @Sendable (Bool) -> Void,
        syncItem: @escaping @Sendable (WatchHistoryItem) async throws -> Void,
        pullAndMergeRemoteChanges: @escaping @Sendable () async throws -> Int,
        observeRemoteChanges: @escaping @Sendable () -> AsyncStream<[WatchProgressSyncRecord]>
    ) {
        self.isSyncEnabled = isSyncEnabled
        self.setSyncEnabled = setSyncEnabled
        self.syncItem = syncItem
        self.pullAndMergeRemoteChanges = pullAndMergeRemoteChanges
        self.observeRemoteChanges = observeRemoteChanges
    }
}

extension WatchProgressSyncClient: DependencyKey {
    private nonisolated static let keyPrefix = "pureiptv_watch_prog_"
    private nonisolated static let indexKey = "pureiptv_watch_prog_index"
    private nonisolated static let enabledKey = "com.pureiptv.isICloudSyncEnabled"
    private nonisolated static let deviceIDKey = "com.pureiptv.iCloudSyncDeviceUUID"
    private nonisolated static let maxIndexCount = 200

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
        let modelContainer = SharedDatabaseConfig.shared

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

                let record = WatchProgressSyncRecord(from: item, deviceId: deviceUUID)
                guard let data = try? JSONEncoder().encode(record) else { return }

                let itemKey = "\(keyPrefix)\(record.id)"
                store.set(data, forKey: itemKey)

                // Update index
                var index = (store.array(forKey: indexKey) as? [String]) ?? []
                if let existingPos = index.firstIndex(of: record.id) {
                    index.remove(at: existingPos)
                }
                index.insert(record.id, at: 0)

                // Prune old entries past max limit to respect iCloud KVS 1MB storage quota
                if index.count > maxIndexCount {
                    let toRemove = index.suffix(from: maxIndexCount)
                    for oldId in toRemove {
                        store.removeObject(forKey: "\(keyPrefix)\(oldId)")
                    }
                    index = Array(index.prefix(maxIndexCount))
                }

                store.set(index, forKey: indexKey)
                store.synchronize()
            },
            pullAndMergeRemoteChanges: {
                guard isEnabled() else { return 0 }

                store.synchronize()
                let index = (store.array(forKey: indexKey) as? [String]) ?? []
                guard !index.isEmpty else { return 0 }

                var mergedCount = 0
                let context = ModelContext(modelContainer)

                for id in index {
                    let itemKey = "\(keyPrefix)\(id)"
                    guard let data = store.data(forKey: itemKey),
                          let remoteRecord = try? JSONDecoder().decode(WatchProgressSyncRecord.self, from: data)
                    else {
                        continue
                    }

                    // Skip self-echoed records from the exact same device UUID
                    if remoteRecord.deviceId == deviceUUID {
                        continue
                    }

                    // Check local record in SwiftData
                    let descriptor = FetchDescriptor<WatchHistoryItem>(
                        predicate: #Predicate { $0.id == id }
                    )

                    if let localItem = try? context.fetch(descriptor).first {
                        // Conflict resolution: only update if remote timestamp is strictly newer
                        if remoteRecord.lastWatchedAt > localItem.lastWatchedAt {
                            remoteRecord.apply(to: localItem)
                            mergedCount += 1
                        }
                    } else {
                        // New remote entry, insert locally
                        let newItem = remoteRecord.toWatchHistoryItem()
                        context.insert(newItem)
                        mergedCount += 1
                    }
                }

                if mergedCount > 0 {
                    try? context.save()
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
                            for key in changedKeys where key.hasPrefix(keyPrefix) {
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
