import FactoryKit
import Foundation

public final class PlaylistRepository: @unchecked Sendable {
    private let keychainKey = "com.pureiptv.savedPlaylists"
    private let keychainManager = KeychainManager.shared

    public nonisolated init() {}

    private let activePlaylistKey = "com.pureiptv.activePlaylistID"

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

    /// Retrieves the currently active playlist
    public nonisolated func getActivePlaylist() -> SavedPlaylist? {
        let playlists = getPlaylists()
        if let activeID = getActivePlaylistID(), let playlist = playlists.first(where: { $0.id == activeID }) {
            return playlist
        }
        // Fallback to first if active is not set
        if let first = playlists.first {
            setActivePlaylistID(first.id)
            return first
        }
        return nil
    }

    /// Retrieves all saved playlists from iCloud Keychain
    public nonisolated func getPlaylists() -> [SavedPlaylist] {
        do {
            return try keychainManager.retrieve(for: keychainKey, as: [SavedPlaylist].self)
        } catch {
            return []
        }
    }

    /// Adds a new playlist and saves it to iCloud Keychain
    public nonisolated func addPlaylist(_ playlist: SavedPlaylist) {
        var current = getPlaylists()
        // Prevent exact duplicates
        if !current.contains(where: { $0.id == playlist.id }) {
            current.append(playlist)
            try? keychainManager.save(current, for: keychainKey)
            setActivePlaylistID(playlist.id)
        }
    }

    /// Deletes a playlist by ID
    public func deletePlaylist(id: UUID) {
        var current = getPlaylists()
        current.removeAll { $0.id == id }
        try? keychainManager.save(current, for: keychainKey)
    }

    /// Updates an existing playlist
    public func updatePlaylist(_ playlist: SavedPlaylist) {
        var current = getPlaylists()
        if let index = current.firstIndex(where: { $0.id == playlist.id }) {
            current[index] = playlist
            try? keychainManager.save(current, for: keychainKey)
        }
    }
}

// MARK: - Factory Registration

public extension Container {
    var playlistRepository: Factory<PlaylistRepository> {
        self { PlaylistRepository() }.singleton
    }
}
