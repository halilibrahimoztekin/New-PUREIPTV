import ComposableArchitecture
import Foundation

@DependencyClient
public struct RecentChannelsClient: Sendable {
    public var fetchRecentChannels: @Sendable () async -> [RecentChannelDTO] = { [] }
    public var recordChannel: @Sendable (_ item: RecentChannelDTO) async -> Void
    public var clearRecentChannels: @Sendable () async -> Void
}

extension RecentChannelsClient: DependencyKey {
    private static let storageKey = "PureIPTV.RecentChannelsList.v1"
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
            },
            clearRecentChannels: {
                defaults.removeObject(forKey: storageKey)
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
