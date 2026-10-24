import ComposableArchitecture
import Foundation

public struct FavoriteChannelOrderSnapshot: Equatable, Sendable {
    public var mode: FavoriteChannelSortMode
    public var orderedIDs: [String]
    public var revision: UInt64

    public init(mode: FavoriteChannelSortMode = .defaultOrder, orderedIDs: [String] = [], revision: UInt64 = 0) {
        self.mode = mode
        self.orderedIDs = orderedIDs
        self.revision = revision
    }
}

public struct FavoriteChannelOrderClient: Sendable {
    public var load: @Sendable (_ profileID: UUID?, _ playlistID: UUID?, _ listID: UUID?) async -> FavoriteChannelOrderSnapshot
    public var save: @Sendable (_ snapshot: FavoriteChannelOrderSnapshot, _ profileID: UUID?, _ playlistID: UUID?, _ listID: UUID?) async -> Void

    public init(
        load: @escaping @Sendable (UUID?, UUID?, UUID?) async -> FavoriteChannelOrderSnapshot,
        save: @escaping @Sendable (FavoriteChannelOrderSnapshot, UUID?, UUID?, UUID?) async -> Void
    ) {
        self.load = load
        self.save = save
    }
}

private actor FavoriteChannelOrderStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private func key(_ profileID: UUID, _ playlistID: UUID, _ listID: UUID?, _ field: String) -> String {
        let listScope = listID.map { ".list.\($0.uuidString)" } ?? ""
        return "com.pureiptv.favoriteChannelOrder.\(profileID.uuidString).\(playlistID.uuidString)\(listScope).\(field)"
    }

    func load(_ profileID: UUID, _ playlistID: UUID, _ listID: UUID?) -> FavoriteChannelOrderSnapshot {
        let mode = defaults.string(forKey: key(profileID, playlistID, listID, "mode"))
            .flatMap(FavoriteChannelSortMode.init(rawValue:)) ?? .defaultOrder
        let orderedIDs = defaults.stringArray(forKey: key(profileID, playlistID, listID, "ids")) ?? []
        let revision = UInt64(max(0, defaults.integer(forKey: key(profileID, playlistID, listID, "revision"))))
        return FavoriteChannelOrderSnapshot(mode: mode, orderedIDs: orderedIDs, revision: revision)
    }

    func save(_ snapshot: FavoriteChannelOrderSnapshot, _ profileID: UUID, _ playlistID: UUID, _ listID: UUID?) {
        let revisionKey = key(profileID, playlistID, listID, "revision")
        let currentRevision = UInt64(max(0, defaults.integer(forKey: revisionKey)))
        guard snapshot.revision > currentRevision else { return }
        defaults.set(snapshot.mode.rawValue, forKey: key(profileID, playlistID, listID, "mode"))
        defaults.set(snapshot.orderedIDs, forKey: key(profileID, playlistID, listID, "ids"))
        defaults.set(Int(snapshot.revision), forKey: revisionKey)
    }
}

extension FavoriteChannelOrderClient: DependencyKey {
    public static let liveValue: FavoriteChannelOrderClient = {
        let store = FavoriteChannelOrderStore(defaults: .standard)
        return FavoriteChannelOrderClient(
            load: { profileID, playlistID, listID in
                guard let profileID, let playlistID else { return FavoriteChannelOrderSnapshot() }
                return await store.load(profileID, playlistID, listID)
            },
            save: { snapshot, profileID, playlistID, listID in
                guard let profileID, let playlistID else { return }
                await store.save(snapshot, profileID, playlistID, listID)
            }
        )
    }()

    public static let testValue = FavoriteChannelOrderClient(
        load: { _, _, _ in FavoriteChannelOrderSnapshot() },
        save: { _, _, _, _ in }
    )
}

public extension DependencyValues {
    var favoriteChannelOrderClient: FavoriteChannelOrderClient {
        get { self[FavoriteChannelOrderClient.self] }
        set { self[FavoriteChannelOrderClient.self] = newValue }
    }
}
