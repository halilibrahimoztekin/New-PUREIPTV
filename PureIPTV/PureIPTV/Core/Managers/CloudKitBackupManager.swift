import Foundation

public final class CloudKitBackupManager: @unchecked Sendable {
    public static let shared = CloudKitBackupManager()

    private let store = NSUbiquitousKeyValueStore.default
    private let cloudSyncKey = "pureiptv_icloud_backup_payload"

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
    }

    @objc private func iCloudStoreDidChange(notification _: Notification) {
        NotificationCenter.default.post(name: .iCloudBackupRestored, object: nil)
    }

    /// Pushes full application state backup to iCloud
    public func backupToCloud(playlistsData: Data?, favorites: [String], customGroupsData: Data?) {
        var payload: [String: Any] = [
            "favorites": favorites,
            "timestamp": Date().timeIntervalSince1970,
        ]
        if let playlistsData {
            payload["playlists"] = playlistsData.base64EncodedString()
        }
        if let customGroupsData {
            payload["customGroups"] = customGroupsData.base64EncodedString()
        }

        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            store.set(data, forKey: cloudSyncKey)
            store.synchronize()
        }
    }

    /// Restores full application state backup from iCloud
    public func restoreFromCloud() -> (playlistsData: Data?, favorites: [String], customGroupsData: Data?)? {
        guard let data = store.data(forKey: cloudSyncKey),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let favorites = json["favorites"] as? [String] ?? []
        var playlistsData: Data?
        if let b64 = json["playlists"] as? String {
            playlistsData = Data(base64Encoded: b64)
        }
        var customGroupsData: Data?
        if let b64 = json["customGroups"] as? String {
            customGroupsData = Data(base64Encoded: b64)
        }

        return (playlistsData, favorites, customGroupsData)
    }

    public func syncNow() {
        store.synchronize()
    }
}

public extension Notification.Name {
    static let iCloudBackupRestored = Notification.Name("pureiptv_iCloudBackupRestored")
}
