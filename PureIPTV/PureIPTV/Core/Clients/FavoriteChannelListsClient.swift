import ComposableArchitecture
import Foundation

public struct NamedFavoriteChannelList: Codable, Equatable, Identifiable, Sendable {
    public static let maximumChannelIDByteCount = 128
    public var id: UUID
    public var name: String
    public var channelIDs: [String]

    public nonisolated init(id: UUID = UUID(), name: String, channelIDs: [String] = []) {
        self.id = id
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        var unique: [String] = []
        var seen = Set<String>()
        for channelID in channelIDs where unique.count < 2000 {
            guard channelID.utf8.count <= Self.maximumChannelIDByteCount,
                  seen.insert(channelID).inserted else { continue }
            unique.append(channelID)
        }
        self.channelIDs = unique
    }
}

public struct FavoriteChannelListsSnapshot: Equatable, Sendable {
    public var lists: [NamedFavoriteChannelList]
    public var revision: UInt64

    public nonisolated init(lists: [NamedFavoriteChannelList] = [], revision: UInt64 = 0) {
        self.lists = lists
        self.revision = revision
    }
}

public enum FavoriteChannelListPendingMutation: Equatable, Sendable {
    case save(id: UUID?, name: String)
    case delete(UUID)
    case move(id: UUID, offset: Int)
    case toggle(channel: MediaModels.Item, listID: UUID)
    case bulk(channelIDs: [String], listID: UUID, operation: BulkFavoriteOperation, generationID: UUID)
}

public enum BulkFavoriteOperation: Equatable, Sendable {
    case add
    case remove
}

private actor FavoriteChannelListsStore {
    static let shared = FavoriteChannelListsStore()
    private let defaults = UserDefaults.standard
    /// The 40 MiB ceiling covers 20 lists × 2,000 IDs at the model's 128-byte
    /// per-ID bound, including worst-case JSON escaping and list metadata.
    private let maximumSnapshotByteCount = 40 * 1024 * 1024

    func load(profileID: UUID, playlistID: UUID) -> FavoriteChannelListsSnapshot {
        let key = storageKey(profileID, playlistID)
        let decodedLists = defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([NamedFavoriteChannelList].self, from: $0) } ?? []
        let lists = decodedLists.prefix(20).map {
            NamedFavoriteChannelList(id: $0.id, name: $0.name, channelIDs: $0.channelIDs)
        }
        let revision = UInt64(max(0, defaults.integer(forKey: key + ".revision")))
        return FavoriteChannelListsSnapshot(lists: lists, revision: revision)
    }

    func save(_ snapshot: FavoriteChannelListsSnapshot, profileID: UUID, playlistID: UUID) -> Bool {
        let key = storageKey(profileID, playlistID)
        let revisionKey = key + ".revision"
        let currentRevision = UInt64(max(0, defaults.integer(forKey: revisionKey)))
        let lists = snapshot.lists.prefix(20).map {
            NamedFavoriteChannelList(id: $0.id, name: $0.name, channelIDs: $0.channelIDs)
        }
        guard snapshot.revision > currentRevision,
              let data = try? JSONEncoder().encode(lists),
              data.count <= maximumSnapshotByteCount else { return false }
        defaults.set(data, forKey: key)
        defaults.set(Int(min(snapshot.revision, UInt64(Int.max))), forKey: revisionKey)
        return true
    }

    private func storageKey(_ profileID: UUID, _ playlistID: UUID) -> String {
        "com.pureiptv.favoriteChannelLists.v1.\(profileID.uuidString).\(playlistID.uuidString)"
    }
}

public struct FavoriteChannelListsClient: Sendable {
    public var load: @Sendable (UUID, UUID) async -> FavoriteChannelListsSnapshot
    public var save: @Sendable (FavoriteChannelListsSnapshot, UUID, UUID) async -> Bool

    public init(
        load: @escaping @Sendable (UUID, UUID) async -> FavoriteChannelListsSnapshot,
        save: @escaping @Sendable (FavoriteChannelListsSnapshot, UUID, UUID) async -> Bool
    ) {
        self.load = load
        self.save = save
    }
}

extension FavoriteChannelListsClient: DependencyKey {
    public nonisolated static let liveValue = FavoriteChannelListsClient(
        load: { profileID, playlistID in
            await FavoriteChannelListsStore.shared.load(profileID: profileID, playlistID: playlistID)
        },
        save: { snapshot, profileID, playlistID in
            await FavoriteChannelListsStore.shared.save(snapshot, profileID: profileID, playlistID: playlistID)
        }
    )

    public nonisolated static let testValue = FavoriteChannelListsClient(
        load: { _, _ in FavoriteChannelListsSnapshot() },
        save: { _, _, _ in true }
    )
}

public extension DependencyValues {
    var favoriteChannelListsClient: FavoriteChannelListsClient {
        get { self[FavoriteChannelListsClient.self] }
        set { self[FavoriteChannelListsClient.self] = newValue }
    }
}
