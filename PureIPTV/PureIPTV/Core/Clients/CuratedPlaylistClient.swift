import ComposableArchitecture
import Foundation

/// A source-scoped reference. It deliberately contains no stream URL, cover URL, or provider credentials.
public struct CuratedPlaylistEntry: Codable, Equatable, Identifiable, Sendable {
    public nonisolated static let maximumEntryCount = 1000
    public nonisolated static let maximumItemIDByteCount = 1024

    public let playlistID: UUID
    public let contentType: String
    public let itemID: String
    public let categoryID: String
    public let titleSnapshot: String
    public let playlistNameSnapshot: String

    public nonisolated var id: String {
        Self.identity(playlistID: playlistID, contentType: contentType, itemID: itemID)
    }

    public nonisolated static func identity(playlistID: UUID, contentType: String, itemID: String) -> String {
        let components = [playlistID.uuidString.lowercased(), contentType, itemID]
        return "curated-item-v1|" + components.map { "\($0.utf8.count):\($0)" }.joined()
    }

    public nonisolated init(
        playlistID: UUID,
        contentType: String,
        itemID: String,
        categoryID: String,
        titleSnapshot: String,
        playlistNameSnapshot: String
    ) {
        self.playlistID = playlistID
        self.contentType = contentType
        self.itemID = itemID.utf8.count <= Self.maximumItemIDByteCount ? itemID : ""
        self.categoryID = String(categoryID.prefix(128))
        self.titleSnapshot = String(titleSnapshot.prefix(240))
        self.playlistNameSnapshot = String(playlistNameSnapshot.prefix(120))
    }

    fileprivate nonisolated var isValid: Bool {
        MediaModels.ItemType(rawValue: contentType) != nil
            && !itemID.isEmpty
            && !titleSnapshot.isEmpty
    }
}

public struct CuratedPlaylistSnapshot: Equatable, Sendable {
    public let entries: [CuratedPlaylistEntry]
    public let revision: UInt64

    public nonisolated init(entries: [CuratedPlaylistEntry] = [], revision: UInt64 = 0) {
        self.entries = entries
        self.revision = revision
    }
}

private actor CuratedPlaylistStore {
    static let shared = CuratedPlaylistStore()

    private let defaults = UserDefaults.standard
    private let maximumSnapshotByteCount = 2 * 1024 * 1024

    func load(profileID: UUID?) -> CuratedPlaylistSnapshot {
        let key = storageKey(profileID: profileID)
        let decoded = defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([CuratedPlaylistEntry].self, from: $0) } ?? []
        var seen = Set<String>()
        let entries = decoded.prefix(CuratedPlaylistEntry.maximumEntryCount).compactMap { entry -> CuratedPlaylistEntry? in
            guard entry.isValid, seen.insert(entry.id).inserted else { return nil }
            return CuratedPlaylistEntry(
                playlistID: entry.playlistID,
                contentType: entry.contentType,
                itemID: entry.itemID,
                categoryID: entry.categoryID,
                titleSnapshot: entry.titleSnapshot,
                playlistNameSnapshot: entry.playlistNameSnapshot
            )
        }
        let revision = UInt64(max(0, defaults.integer(forKey: key + ".revision")))
        return CuratedPlaylistSnapshot(entries: entries, revision: revision)
    }

    func toggle(_ entry: CuratedPlaylistEntry, profileID: UUID?) -> CuratedPlaylistSnapshot {
        guard entry.isValid else { return load(profileID: profileID) }
        var current = load(profileID: profileID)
        if let index = current.entries.firstIndex(where: { $0.id == entry.id }) {
            var entries = current.entries
            entries.remove(at: index)
            current = save(entries, profileID: profileID, fallback: current)
        } else if current.entries.count < CuratedPlaylistEntry.maximumEntryCount {
            current = save(current.entries + [entry], profileID: profileID, fallback: current)
        }
        return current
    }

    func remove(id: String, profileID: UUID?) -> CuratedPlaylistSnapshot {
        let current = load(profileID: profileID)
        let entries = current.entries.filter { $0.id != id }
        guard entries.count != current.entries.count else { return current }
        return save(entries, profileID: profileID, fallback: current)
    }

    private func save(
        _ entries: [CuratedPlaylistEntry],
        profileID: UUID?,
        fallback: CuratedPlaylistSnapshot
    ) -> CuratedPlaylistSnapshot {
        let key = storageKey(profileID: profileID)
        guard let data = try? JSONEncoder().encode(entries), data.count <= maximumSnapshotByteCount else {
            return fallback
        }
        let revision = fallback.revision &+ 1
        defaults.set(data, forKey: key)
        defaults.set(Int(min(revision, UInt64(Int.max))), forKey: key + ".revision")
        return CuratedPlaylistSnapshot(entries: entries, revision: revision)
    }

    private func storageKey(profileID: UUID?) -> String {
        "com.pureiptv.curatedPlaylist.v1.\(profileID?.uuidString.lowercased() ?? "default")"
    }
}

@DependencyClient
public struct CuratedPlaylistClient: Sendable {
    public var load: @Sendable (_ profileID: UUID?) async -> CuratedPlaylistSnapshot = { _ in
        CuratedPlaylistSnapshot()
    }

    public var toggle: @Sendable (_ entry: CuratedPlaylistEntry, _ profileID: UUID?) async -> CuratedPlaylistSnapshot = { _, _ in
        CuratedPlaylistSnapshot()
    }

    public var remove: @Sendable (_ entryID: String, _ profileID: UUID?) async -> CuratedPlaylistSnapshot = { _, _ in
        CuratedPlaylistSnapshot()
    }
}

extension CuratedPlaylistClient: DependencyKey {
    public nonisolated static let liveValue = CuratedPlaylistClient(
        load: { profileID in await CuratedPlaylistStore.shared.load(profileID: profileID) },
        toggle: { entry, profileID in await CuratedPlaylistStore.shared.toggle(entry, profileID: profileID) },
        remove: { entryID, profileID in await CuratedPlaylistStore.shared.remove(id: entryID, profileID: profileID) }
    )

    public nonisolated static let testValue = CuratedPlaylistClient()
}

public extension DependencyValues {
    var curatedPlaylistClient: CuratedPlaylistClient {
        get { self[CuratedPlaylistClient.self] }
        set { self[CuratedPlaylistClient.self] = newValue }
    }
}
