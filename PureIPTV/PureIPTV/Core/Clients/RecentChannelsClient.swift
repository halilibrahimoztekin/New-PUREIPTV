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

@DependencyClient
public struct RecentChannelsClient: Sendable {
    public var fetchRecentChannels: @Sendable () async -> [RecentChannelDTO] = { [] }
    public var recordChannel: @Sendable (_ item: RecentChannelDTO) async -> Void
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
