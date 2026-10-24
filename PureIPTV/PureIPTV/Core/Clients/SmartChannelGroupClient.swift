import ComposableArchitecture
import Foundation

public struct SmartChannelGroup: Equatable, Identifiable, Codable, Sendable {
    public static let maximumCategoryCount = 20
    public var id: String
    public var name: String
    public var categoryIDs: [String]

    public nonisolated init(id: String = UUID().uuidString, name: String, categoryIDs: [String]) {
        self.id = id
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(48))
        var unique: [String] = []
        for categoryID in categoryIDs where unique.count < Self.maximumCategoryCount && !unique.contains(categoryID) {
            unique.append(categoryID)
        }
        self.categoryIDs = unique
    }
}

public struct SmartChannelGroupSnapshot: Equatable, Sendable {
    public var groups: [SmartChannelGroup]
    public var revision: UInt64

    public nonisolated init(groups: [SmartChannelGroup], revision: UInt64) {
        self.groups = groups
        self.revision = revision
    }
}

private actor SmartChannelGroupStore {
    static let shared = SmartChannelGroupStore()
    private let defaults = UserDefaults.standard

    func load(profileID: UUID, playlistID: UUID) -> SmartChannelGroupSnapshot {
        let storageKey = key(profileID, playlistID)
        let groups: [SmartChannelGroup]
        if let data = defaults.data(forKey: storageKey) {
            let decoded = (try? JSONDecoder().decode([SmartChannelGroup].self, from: data)) ?? []
            groups = decoded.map { SmartChannelGroup(id: $0.id, name: $0.name, categoryIDs: $0.categoryIDs) }
        } else {
            groups = []
        }
        let storedRevision = UInt64(max(0, defaults.integer(forKey: storageKey + ".revision")))
        return SmartChannelGroupSnapshot(groups: groups, revision: storedRevision)
    }

    func save(_ groups: [SmartChannelGroup], profileID: UUID, playlistID: UUID, revision: UInt64) {
        let storageKey = key(profileID, playlistID)
        let revisionKey = storageKey + ".revision"
        guard revision >= UInt64(max(0, defaults.integer(forKey: revisionKey))) else { return }
        guard let data = try? JSONEncoder().encode(groups) else { return }
        defaults.set(data, forKey: storageKey)
        defaults.set(Int(min(revision, UInt64(Int.max))), forKey: revisionKey)
    }

    private func key(_ profileID: UUID, _ playlistID: UUID) -> String {
        "com.pureiptv.smartChannelGroups.\(profileID.uuidString).\(playlistID.uuidString)"
    }
}

@DependencyClient
public struct SmartChannelGroupClient: Sendable {
    public var load: @Sendable (_ profileID: UUID, _ playlistID: UUID) async -> SmartChannelGroupSnapshot = { _, _ in
        SmartChannelGroupSnapshot(groups: [], revision: 0)
    }

    public var save: @Sendable (_ groups: [SmartChannelGroup], _ profileID: UUID, _ playlistID: UUID, _ revision: UInt64) async -> Void
}

extension SmartChannelGroupClient: DependencyKey {
    public static let liveValue = Self(
        load: { profileID, playlistID in
            await SmartChannelGroupStore.shared.load(profileID: profileID, playlistID: playlistID)
        },
        save: { groups, profileID, playlistID, revision in
            await SmartChannelGroupStore.shared.save(groups, profileID: profileID, playlistID: playlistID, revision: revision)
        }
    )

    public static let testValue = Self()
}

public extension DependencyValues {
    var smartChannelGroupClient: SmartChannelGroupClient {
        get { self[SmartChannelGroupClient.self] }
        set { self[SmartChannelGroupClient.self] = newValue }
    }
}
