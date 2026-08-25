import Factory
import Foundation

public final class PlaylistRepository {
    private let keychainKey = "com.pureiptv.savedPlaylists"
    private let keychainManager = KeychainManager.shared

    public init() {}

    /// Retrieves all saved playlists from iCloud Keychain
    public func getPlaylists() -> [SavedPlaylist] {
        do {
            return try keychainManager.retrieve(for: keychainKey, as: [SavedPlaylist].self)
        } catch {
            return []
        }
    }

    /// Adds a new playlist and saves it to iCloud Keychain
    public func addPlaylist(_ playlist: SavedPlaylist) {
        var current = getPlaylists()
        // Prevent exact duplicates
        if !current.contains(where: { $0.id == playlist.id }) {
            current.append(playlist)
            try? keychainManager.save(current, for: keychainKey)
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
