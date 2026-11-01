import Foundation

/// Local, playlist-scoped opt-out for syncing records that can contain stream URLs.
/// Missing keys default to enabled to preserve existing users' sync behavior.
public nonisolated enum PlaylistCloudSyncPreference {
    private nonisolated static let defaultsKeyPrefix = "com.pureiptv.icloud.playlistSyncEnabled.v1."
    private nonisolated static let ubiquitousKeyPrefix = "com.pureiptv.icloud.playlistSyncEnabled.v1."

    public static func isEnabled(for playlistID: UUID?) -> Bool {
        guard let playlistID else { return true }
        let suffix = playlistID.uuidString.lowercased()
        let ubiquitousKey = ubiquitousKeyPrefix + suffix
        if let value = NSUbiquitousKeyValueStore.default.object(forKey: ubiquitousKey) as? Bool {
            return value
        }
        let defaultsKey = defaultsKeyPrefix + suffix
        return UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    public static func setEnabled(_ enabled: Bool, for playlistID: UUID) {
        let suffix = playlistID.uuidString.lowercased()
        UserDefaults.standard.set(enabled, forKey: defaultsKeyPrefix + suffix)
        let store = NSUbiquitousKeyValueStore.default
        store.set(enabled, forKey: ubiquitousKeyPrefix + suffix)
        store.synchronize()
    }

    public static func isPreferenceKey(_ key: String) -> Bool {
        key.hasPrefix(ubiquitousKeyPrefix)
    }

    public static func disabledPlaylistIDs() -> Set<UUID> {
        let stores: [([String: Any], String)] = [
            (NSUbiquitousKeyValueStore.default.dictionaryRepresentation, ubiquitousKeyPrefix),
            (UserDefaults.standard.dictionaryRepresentation(), defaultsKeyPrefix),
        ]
        return Set(stores.flatMap { store in
            let (values, prefix) = store
            return values.compactMap { key, value -> UUID? in
                guard key.hasPrefix(prefix),
                      (value as? Bool) == false
                else { return nil }
                return UUID(uuidString: String(key.dropFirst(prefix.count)))
            }
        })
    }
}
