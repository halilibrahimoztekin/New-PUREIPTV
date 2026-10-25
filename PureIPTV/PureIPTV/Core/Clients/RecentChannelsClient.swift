import ComposableArchitecture
import Foundation

private actor PinnedRecentChannelStore {
    static let shared = PinnedRecentChannelStore()
    private let defaults = UserDefaults.standard

    func fetch(profileID: UUID?, playlistID: UUID) -> [String] {
        defaults.stringArray(forKey: storageKey(profileID: profileID, playlistID: playlistID)) ?? []
    }

    func toggle(id: String, profileID: UUID?, playlistID: UUID) -> [String] {
        let key = storageKey(profileID: profileID, playlistID: playlistID)
        var ids = defaults.stringArray(forKey: key) ?? []
        if let index = ids.firstIndex(of: id) {
            ids.remove(at: index)
        } else {
            ids.append(id)
        }
        defaults.set(ids, forKey: key)
        return ids
    }

    private func storageKey(profileID: UUID?, playlistID: UUID) -> String {
        "PureIPTV.PinnedRecentChannels.v1.\(profileID?.uuidString ?? "default").\(playlistID.uuidString)"
    }
}

private actor ScopedRecentChannelStore {
    static let shared = ScopedRecentChannelStore()
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let maxRecentChannels = 20
    private let watchCountsKey = "PureIPTV.RecentChannelsList.watchCounts.v1"
    private var revisions: [String: UInt64] = [:]

    func fetch(profileID: UUID?, playlistID: UUID) -> ScopedRecentChannelSnapshot {
        let key = storageKey(profileID: profileID, playlistID: playlistID)
        return ScopedRecentChannelSnapshot(records: records(for: key), revision: revisions[key, default: 0])
    }

    func record(_ item: RecentChannelDTO, profileID: UUID?, playlistID: UUID) {
        let key = storageKey(profileID: profileID, playlistID: playlistID)
        var list = records(for: key)
        list.removeAll { $0.id == item.id }
        list.insert(item, at: 0)
        if list.count > maxRecentChannels {
            list = Array(list.prefix(maxRecentChannels))
        }
        if let data = try? encoder.encode(list) {
            defaults.set(data, forKey: key)
            revisions[key, default: 0] &+= 1
        }
        var counts = (defaults.dictionary(forKey: watchCountsKey) as? [String: Int]) ?? [:]
        counts[item.id] = (counts[item.id] ?? 0) + 1
        defaults.set(counts, forKey: watchCountsKey)
    }

    func remove(id: String, profileID: UUID?, playlistID: UUID) -> ScopedRecentChannelSnapshot {
        let key = storageKey(profileID: profileID, playlistID: playlistID)
        var list = records(for: key)
        let originalCount = list.count
        list.removeAll { $0.id == id }
        if list.count != originalCount, let data = try? encoder.encode(list) {
            defaults.set(data, forKey: key)
            revisions[key, default: 0] &+= 1
        }
        return ScopedRecentChannelSnapshot(records: list, revision: revisions[key, default: 0])
    }

    private func records(for key: String) -> [RecentChannelDTO] {
        guard let data = defaults.data(forKey: key),
              let list = try? decoder.decode([RecentChannelDTO].self, from: data)
        else { return [] }
        return list.sorted { $0.lastWatchedAt > $1.lastWatchedAt }
    }

    private func storageKey(profileID: UUID?, playlistID: UUID) -> String {
        "PureIPTV.RecentChannelsList.v2.\(profileID?.uuidString.lowercased() ?? "no-profile").\(playlistID.uuidString.lowercased())"
    }
}

public struct ScopedRecentChannelSnapshot: Equatable, Sendable {
    public let records: [RecentChannelDTO]
    public let revision: UInt64

    public nonisolated init(records: [RecentChannelDTO], revision: UInt64) {
        self.records = records
        self.revision = revision
    }
}

@DependencyClient
public struct RecentChannelsClient: Sendable {
    public var fetchRecentChannels: @Sendable () async -> [RecentChannelDTO] = { [] }
    public var recordChannel: @Sendable (_ item: RecentChannelDTO) async -> Void
    public var fetchScopedRecentChannels: @Sendable (_ profileID: UUID?, _ playlistID: UUID) async -> ScopedRecentChannelSnapshot = { _, _ in ScopedRecentChannelSnapshot(records: [], revision: 0) }
    public var recordScopedChannel: @Sendable (_ item: RecentChannelDTO, _ profileID: UUID?, _ playlistID: UUID) async -> Void = { _, _, _ in }
    public var removeScopedRecentChannel: @Sendable (_ id: String, _ profileID: UUID?, _ playlistID: UUID) async -> ScopedRecentChannelSnapshot = { _, _, _ in ScopedRecentChannelSnapshot(records: [], revision: 0) }
    public var clearRecentChannels: @Sendable () async -> Void
    public var fetchWatchCounts: @Sendable () async -> [String: Int] = { [:] }
    public var fetchPinnedChannelIDs: @Sendable (_ profileID: UUID?, _ playlistID: UUID) async -> [String] = { _, _ in [] }
    public var togglePinnedChannel: @Sendable (_ id: String, _ profileID: UUID?, _ playlistID: UUID) async -> [String] = { _, _, _ in [] }
}

extension RecentChannelsClient: DependencyKey {
    private static let storageKey = "PureIPTV.RecentChannelsList.v1"
    private static let watchCountsKey = "PureIPTV.RecentChannelsList.watchCounts.v1"
    private static let maxRecentChannels = 20

    public static let liveValue: RecentChannelsClient = {
        let defaults = UserDefaults.standard
        let jsonEncoder = JSONEncoder()
        let jsonDecoder = JSONDecoder()

        return RecentChannelsClient(
            fetchRecentChannels: {
                guard let data = defaults.data(forKey: storageKey),
                      let list = try? jsonDecoder.decode([RecentChannelDTO].self, from: data)
                else {
                    return []
                }
                return list.sorted(by: { $0.lastWatchedAt > $1.lastWatchedAt })
            },
            recordChannel: { item in
                var list: [RecentChannelDTO] = []
                if let data = defaults.data(forKey: storageKey),
                   let saved = try? jsonDecoder.decode([RecentChannelDTO].self, from: data)
                {
                    list = saved
                }
                list.removeAll(where: { $0.id == item.id })
                list.insert(item, at: 0)
                if list.count > maxRecentChannels {
                    list = Array(list.prefix(maxRecentChannels))
                }
                if let encoded = try? jsonEncoder.encode(list) {
                    defaults.set(encoded, forKey: storageKey)
                }

                // Update Watch Frequency Count
                var counts = (defaults.dictionary(forKey: watchCountsKey) as? [String: Int]) ?? [:]
                counts[item.id] = (counts[item.id] ?? 0) + 1
                defaults.set(counts, forKey: watchCountsKey)
            },
            fetchScopedRecentChannels: { profileID, playlistID in
                await ScopedRecentChannelStore.shared.fetch(profileID: profileID, playlistID: playlistID)
            },
            recordScopedChannel: { item, profileID, playlistID in
                await ScopedRecentChannelStore.shared.record(item, profileID: profileID, playlistID: playlistID)
            },
            removeScopedRecentChannel: { id, profileID, playlistID in
                await ScopedRecentChannelStore.shared.remove(id: id, profileID: profileID, playlistID: playlistID)
            },
            clearRecentChannels: {
                defaults.removeObject(forKey: storageKey)
                defaults.removeObject(forKey: watchCountsKey)
            },
            fetchWatchCounts: {
                (defaults.dictionary(forKey: watchCountsKey) as? [String: Int]) ?? [:]
            },
            fetchPinnedChannelIDs: { profileID, playlistID in
                await PinnedRecentChannelStore.shared.fetch(profileID: profileID, playlistID: playlistID)
            },
            togglePinnedChannel: { id, profileID, playlistID in
                await PinnedRecentChannelStore.shared.toggle(id: id, profileID: profileID, playlistID: playlistID)
            }
        )
    }()

    public static let testValue: RecentChannelsClient = .init()
}

public extension DependencyValues {
    var recentChannelsClient: RecentChannelsClient {
        get { self[RecentChannelsClient.self] }
        set { self[RecentChannelsClient.self] = newValue }
    }
}
