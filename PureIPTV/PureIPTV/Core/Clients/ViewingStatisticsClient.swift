import ComposableArchitecture
import Foundation

public nonisolated enum ViewingStatisticsContentKind: String, Codable, CaseIterable, Equatable, Sendable {
    case live
    case movie
    case series
}

public nonisolated struct ViewingStatisticsMedia: Equatable, Sendable {
    public let kind: ViewingStatisticsContentKind
    public let id: String
    public let playlistID: UUID?
    public let title: String

    public init(kind: ViewingStatisticsContentKind, id: String, playlistID: UUID?, title: String) {
        self.kind = kind
        self.id = id
        self.playlistID = playlistID
        self.title = title
    }
}

public nonisolated struct ViewingStatisticsEntry: Codable, Equatable, Sendable {
    public let day: Date
    public let kind: ViewingStatisticsContentKind
    public let id: String
    public let playlistID: UUID?
    public var title: String
    public var seconds: Double

    public var identity: String {
        [kind.rawValue, playlistID?.uuidString ?? "", id]
            .map { "\($0.utf8.count):\($0)" }
            .joined()
    }

    public init(day: Date, media: ViewingStatisticsMedia, seconds: Double) {
        self.day = day
        kind = media.kind
        id = media.id
        playlistID = media.playlistID
        title = media.title
        self.seconds = seconds
    }
}

private actor ViewingStatisticsStore {
    static let shared = ViewingStatisticsStore()
    private let defaults = UserDefaults.standard

    func load(profileID: UUID?) -> [ViewingStatisticsEntry] {
        guard let data = defaults.data(forKey: storageKey(profileID: profileID)) else { return [] }
        guard let entries = try? JSONDecoder().decode([ViewingStatisticsEntry].self, from: data) else { return [] }
        let retainedEntries = prune(entries)
        if retainedEntries.count != entries.count,
           let prunedData = try? JSONEncoder().encode(retainedEntries)
        {
            defaults.set(prunedData, forKey: storageKey(profileID: profileID))
        }
        return retainedEntries
    }

    func record(profileID: UUID?, media: ViewingStatisticsMedia, seconds: Double, at date: Date) {
        guard seconds.isFinite, seconds > 0, !media.id.isEmpty else { return }
        let key = storageKey(profileID: profileID)
        var entries = load(profileID: profileID)
        let day = Calendar.current.startOfDay(for: date)
        if let index = entries.firstIndex(where: {
            $0.day == day && $0.kind == media.kind && $0.id == media.id && $0.playlistID == media.playlistID
        }) {
            entries[index].seconds += seconds
            entries[index].title = media.title
        } else {
            entries.append(ViewingStatisticsEntry(day: day, media: media, seconds: seconds))
        }
        entries = prune(entries)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }

    func clear(profileID: UUID?) {
        defaults.removeObject(forKey: storageKey(profileID: profileID))
    }

    private func storageKey(profileID: UUID?) -> String {
        "com.pureiptv.viewingStatistics.v1.\(profileID?.uuidString.lowercased() ?? "legacy")"
    }

    private func prune(_ entries: [ViewingStatisticsEntry]) -> [ViewingStatisticsEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let oldestDay = calendar.date(byAdding: .day, value: -179, to: today) ?? today
        return entries.filter { $0.day >= oldestDay }
    }
}

@DependencyClient
public struct ViewingStatisticsClient: Sendable {
    public var load: @Sendable (_ profileID: UUID?) async -> [ViewingStatisticsEntry] = { _ in [] }
    public var record: @Sendable (
        _ profileID: UUID?,
        _ media: ViewingStatisticsMedia,
        _ seconds: Double,
        _ date: Date
    ) async -> Void = { _, _, _, _ in }
    public var clear: @Sendable (_ profileID: UUID?) async -> Void = { _ in }
}

extension ViewingStatisticsClient: DependencyKey {
    public static let liveValue: ViewingStatisticsClient = {
        let store = ViewingStatisticsStore.shared
        return ViewingStatisticsClient(
            load: { await store.load(profileID: $0) },
            record: { await store.record(profileID: $0, media: $1, seconds: $2, at: $3) },
            clear: { await store.clear(profileID: $0) }
        )
    }()

    public static let testValue = ViewingStatisticsClient()
}

public extension DependencyValues {
    var viewingStatisticsClient: ViewingStatisticsClient {
        get { self[ViewingStatisticsClient.self] }
        set { self[ViewingStatisticsClient.self] = newValue }
    }
}
