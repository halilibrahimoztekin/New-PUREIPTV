import FactoryKit
import Foundation

public final class PlaylistRepository: @unchecked Sendable {
    public enum PlaylistReadResult {
        case loaded([SavedPlaylist])
        case notFound
        case failed
    }

    public enum ActivePlaylistReadResult {
        case loaded(SavedPlaylist?)
        case failed
    }

    private let keychainKey = "com.pureiptv.savedPlaylists"
    private let localKeychainKey = "com.pureiptv.savedPlaylists.local.v1"
    private let keychainManager = KeychainManager.shared

    public nonisolated init() {}

    private let activePlaylistKey = "com.pureiptv.activePlaylistID"
    private let defaultStartupPlaylistKey = "com.pureiptv.defaultStartupPlaylistID"

    /// Gets the currently active playlist ID, if any.
    public nonisolated func getActivePlaylistID() -> UUID? {
        if let idString = UserDefaults.standard.string(forKey: activePlaylistKey), let uuid = UUID(uuidString: idString) {
            return uuid
        }
        return nil
    }

    /// Sets the currently active playlist ID.
    public nonisolated func setActivePlaylistID(_ id: UUID?) {
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: activePlaylistKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activePlaylistKey)
        }
    }

    /// Gets the separately pinned playlist to open when the app starts.
    public nonisolated func getDefaultStartupPlaylistID() -> UUID? {
        guard let idString = UserDefaults.standard.string(forKey: defaultStartupPlaylistKey) else { return nil }
        return UUID(uuidString: idString)
    }

    /// Sets or clears the separately pinned startup playlist.
    public nonisolated func setDefaultStartupPlaylistID(_ id: UUID?) {
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: defaultStartupPlaylistKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultStartupPlaylistKey)
        }
    }

    /// Retrieves the currently active playlist
    public nonisolated func getActivePlaylist() -> SavedPlaylist? {
        switch readActivePlaylist() {
        case let .loaded(playlist): playlist
        case .failed: nil
        }
    }

    /// A protected/unreadable Keychain must not look like an empty library at startup.
    public nonisolated func readActivePlaylist() -> ActivePlaylistReadResult {
        let playlists: [SavedPlaylist]
        switch readPlaylists() {
        case let .loaded(saved): playlists = saved
        case .notFound: return .loaded(nil)
        case .failed: return .failed
        }
        if let activeID = getActivePlaylistID(), let playlist = playlists.first(where: { $0.id == activeID }) {
            return .loaded(playlist)
        }
        if let first = playlists.first {
            setActivePlaylistID(first.id)
            return .loaded(first)
        }
        return .loaded(nil)
    }

    /// Resolves startup preference without changing it when the Keychain cannot be read.
    public nonisolated func readStartupPlaylist() -> ActivePlaylistReadResult {
        let playlists: [SavedPlaylist]
        switch readPlaylists() {
        case let .loaded(saved): playlists = saved
        case .notFound: playlists = []
        case .failed: return .failed
        }

        if let startupID = getDefaultStartupPlaylistID() {
            if let playlist = playlists.first(where: { $0.id == startupID }) {
                setActivePlaylistID(playlist.id)
                return .loaded(playlist)
            }
            setDefaultStartupPlaylistID(nil)
        }

        if let activeID = getActivePlaylistID(), let playlist = playlists.first(where: { $0.id == activeID }) {
            return .loaded(playlist)
        }
        if let first = playlists.first {
            setActivePlaylistID(first.id)
            return .loaded(first)
        }
        return .loaded(nil)
    }

    /// Retrieves playlists from iCloud Keychain and this device's local Keychain.
    public nonisolated func getPlaylists() -> [SavedPlaylist] {
        switch readPlaylists() {
        case let .loaded(playlists): playlists
        case .notFound, .failed: []
        }
    }

    private nonisolated func storedPlaylists(synchronizable: Bool) throws -> [SavedPlaylist]? {
        let key = synchronizable ? keychainKey : localKeychainKey
        do {
            return try keychainManager.retrieve(for: key, as: [SavedPlaylist].self, synchronizable: synchronizable)
        } catch KeychainError.itemNotFound {
            return nil
        }
    }

    public nonisolated func readPlaylists() -> PlaylistReadResult {
        do {
            var synchronized = try storedPlaylists(synchronizable: true)
            var local = try storedPlaylists(synchronizable: false)
            guard synchronized != nil || local != nil else { return .notFound }

            let excludedCloudPlaylists = (synchronized ?? []).filter {
                !PlaylistCloudSyncPreference.isEnabled(for: $0.id)
            }
            if !excludedCloudPlaylists.isEmpty {
                var localByID = Dictionary(uniqueKeysWithValues: (local ?? []).map { ($0.id, $0) })
                for playlist in excludedCloudPlaylists where localByID[playlist.id] == nil {
                    localByID[playlist.id] = playlist
                }
                let enabledCloudPlaylists = (synchronized ?? []).filter {
                    PlaylistCloudSyncPreference.isEnabled(for: $0.id)
                }
                let combined = enabledCloudPlaylists + Array(localByID.values)
                guard savePlaylists(combined) else { return .failed }
                synchronized = enabledCloudPlaylists
                local = Array(localByID.values)
            }

            var playlistsByID: [UUID: SavedPlaylist] = [:]
            for playlist in local ?? [] {
                playlistsByID[playlist.id] = playlist
            }
            for playlist in synchronized ?? [] where PlaylistCloudSyncPreference.isEnabled(for: playlist.id) {
                playlistsByID[playlist.id] = playlist
            }
            return .loaded(Array(playlistsByID.values))
        } catch {
            return .failed
        }
    }

    private nonisolated func savePlaylists(_ playlists: [SavedPlaylist]) -> Bool {
        let synchronized = playlists.filter { PlaylistCloudSyncPreference.isEnabled(for: $0.id) }
        let local = playlists.filter { !PlaylistCloudSyncPreference.isEnabled(for: $0.id) }

        do {
            // Write both replacement arrays before deleting an empty partition so a failure never loses the only copy.
            if !local.isEmpty {
                try keychainManager.save(local, for: localKeychainKey, synchronizable: false)
            }
            if !synchronized.isEmpty {
                try keychainManager.save(synchronized, for: keychainKey, synchronizable: true)
            }
            if local.isEmpty {
                try keychainManager.delete(for: localKeychainKey, synchronizable: false)
            }
            if synchronized.isEmpty {
                try keychainManager.delete(for: keychainKey, synchronizable: true)
            }
            return true
        } catch {
            return false
        }
    }

    /// Keeps a playlist on this device while moving its credentials out of the shared iCloud Keychain record.
    public nonisolated func setPlaylistCloudSyncEnabled(_ id: UUID, enabled: Bool) -> Bool {
        let current: [SavedPlaylist]
        switch readPlaylists() {
        case let .loaded(playlists): current = playlists
        case .notFound, .failed: return false
        }
        guard current.contains(where: { $0.id == id }) else { return false }
        let previousValue = PlaylistCloudSyncPreference.isEnabled(for: id)
        guard previousValue != enabled else { return true }

        PlaylistCloudSyncPreference.setEnabled(enabled, for: id)
        guard savePlaylists(current) else {
            PlaylistCloudSyncPreference.setEnabled(previousValue, for: id)
            return false
        }
        return true
    }

    /// Adds a new playlist and saves it to iCloud Keychain
    public nonisolated func addPlaylist(_ playlist: SavedPlaylist) -> Bool {
        var current: [SavedPlaylist]
        switch readPlaylists() {
        case let .loaded(playlists): current = playlists
        case .notFound: current = []
        case .failed: return false
        }
        // Prevent exact duplicates
        if !current.contains(where: { $0.id == playlist.id }) {
            current.append(playlist)
            guard savePlaylists(current) else { return false }
            setActivePlaylistID(playlist.id)
        }
        return true
    }

    /// Deletes a playlist by ID
    public func deletePlaylist(id: UUID) -> Bool {
        var current: [SavedPlaylist]
        switch readPlaylists() {
        case let .loaded(playlists): current = playlists
        case .notFound:
            if getDefaultStartupPlaylistID() == id {
                setDefaultStartupPlaylistID(nil)
            }
            return true
        case .failed: return false
        }
        current.removeAll { $0.id == id }
        if savePlaylists(current) {
            if getDefaultStartupPlaylistID() == id {
                setDefaultStartupPlaylistID(nil)
            }
            MediaServerRequestContextFactory.removeCachedContext(for: id)
            return true
        }
        return false
    }

    /// Updates an existing playlist
    public func updatePlaylist(_ playlist: SavedPlaylist) -> Bool {
        var current: [SavedPlaylist]
        switch readPlaylists() {
        case let .loaded(playlists): current = playlists
        case .notFound: return false
        case .failed: return false
        }
        if let index = current.firstIndex(where: { $0.id == playlist.id }) {
            current[index] = playlist
            return savePlaylists(current)
        }
        return false
    }
}

// MARK: - Factory Registration

public extension Container {
    var playlistRepository: Factory<PlaylistRepository> {
        self { PlaylistRepository() }.singleton
    }
}
