import ComposableArchitecture
import Foundation

public enum TMDBMatchMediaKind: String, Codable, Equatable, Sendable {
    case movie
    case series
}

private struct TMDBMatchOverrideRecord: Codable, Equatable, Sendable {
    let tmdbID: Int?
    let updatedAt: Date
}

private actor TMDBMatchOverrideStore {
    static let shared = TMDBMatchOverrideStore()

    private let defaults = UserDefaults.standard
    private let localKey = "com.pureiptv.tmdbMatchOverrides.v1"
    private let cloudKey = "com.pureiptv.icloud.tmdbMatchOverrides.v1"
    private let maximumRecords = 512

    func load(playlistID: UUID, kind: TMDBMatchMediaKind, itemID: String, cloudSyncEnabled: Bool) -> Int? {
        guard Self.isValid(itemID: itemID) else { return nil }
        var records = localRecords()
        if cloudSyncEnabled {
            records = Self.merged(records, Self.decode(NSUbiquitousKeyValueStore.default.data(forKey: cloudKey)))
            persist(records, cloudSyncEnabled: true)
        }
        return records[Self.recordKey(playlistID: playlistID, kind: kind, itemID: itemID)]?.tmdbID
    }

    func save(
        tmdbID: Int?,
        playlistID: UUID,
        kind: TMDBMatchMediaKind,
        itemID: String,
        cloudSyncEnabled: Bool,
        updatedAt: Date
    ) {
        guard Self.isValid(itemID: itemID), tmdbID.map({ $0 > 0 }) ?? true else { return }
        var records = localRecords()
        if cloudSyncEnabled {
            records = Self.merged(records, Self.decode(NSUbiquitousKeyValueStore.default.data(forKey: cloudKey)))
        }

        let recordKey = Self.recordKey(playlistID: playlistID, kind: kind, itemID: itemID)
        let candidate = TMDBMatchOverrideRecord(tmdbID: tmdbID, updatedAt: updatedAt)
        if let current = records[recordKey] {
            if candidate.updatedAt > current.updatedAt
                || (candidate.updatedAt == current.updatedAt && Self.tieBreak(candidate) > Self.tieBreak(current))
            {
                records[recordKey] = candidate
            }
        } else {
            records[recordKey] = candidate
        }
        persist(records, cloudSyncEnabled: cloudSyncEnabled)
    }

    private func localRecords() -> [String: TMDBMatchOverrideRecord] {
        Self.decode(defaults.data(forKey: localKey))
    }

    private func persist(_ values: [String: TMDBMatchOverrideRecord], cloudSyncEnabled: Bool) {
        let bounded = Self.bounded(values, limit: maximumRecords)
        guard let data = try? JSONEncoder().encode(bounded) else { return }
        defaults.set(data, forKey: localKey)
        guard cloudSyncEnabled else { return }
        let store = NSUbiquitousKeyValueStore.default
        store.set(data, forKey: cloudKey)
        store.synchronize()
    }

    private static func decode(_ data: Data?) -> [String: TMDBMatchOverrideRecord] {
        guard let data else { return [:] }
        return (try? JSONDecoder().decode([String: TMDBMatchOverrideRecord].self, from: data)) ?? [:]
    }

    private static func merged(
        _ lhs: [String: TMDBMatchOverrideRecord],
        _ rhs: [String: TMDBMatchOverrideRecord]
    ) -> [String: TMDBMatchOverrideRecord] {
        var result = lhs
        for (key, candidate) in rhs {
            guard let current = result[key] else {
                result[key] = candidate
                continue
            }
            if candidate.updatedAt > current.updatedAt
                || (candidate.updatedAt == current.updatedAt && tieBreak(candidate) > tieBreak(current))
            {
                result[key] = candidate
            }
        }
        return bounded(result, limit: 512)
    }

    private static func bounded(
        _ values: [String: TMDBMatchOverrideRecord],
        limit: Int
    ) -> [String: TMDBMatchOverrideRecord] {
        guard values.count > limit else { return values }
        return Dictionary(uniqueKeysWithValues: values
            .sorted { lhs, rhs in
                if lhs.value.updatedAt != rhs.value.updatedAt {
                    return lhs.value.updatedAt > rhs.value.updatedAt
                }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map { ($0.key, $0.value) })
    }

    private static func tieBreak(_ record: TMDBMatchOverrideRecord) -> String {
        record.tmdbID.map(String.init) ?? "~cleared"
    }

    private static func isValid(itemID: String) -> Bool {
        !itemID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && itemID.utf8.count <= 512
    }

    private static func recordKey(playlistID: UUID, kind: TMDBMatchMediaKind, itemID: String) -> String {
        "\(playlistID.uuidString):\(kind.rawValue):\(itemID.utf8.count):\(itemID)"
    }
}

@DependencyClient
public struct TMDBMatchOverrideClient: Sendable {
    public var load: @Sendable (_ playlistID: UUID, _ kind: TMDBMatchMediaKind, _ itemID: String, _ cloudSyncEnabled: Bool) async -> Int? = { _, _, _, _ in nil }
    public var save: @Sendable (_ tmdbID: Int?, _ playlistID: UUID, _ kind: TMDBMatchMediaKind, _ itemID: String, _ cloudSyncEnabled: Bool, _ updatedAt: Date) async -> Void
}

extension TMDBMatchOverrideClient: DependencyKey {
    public static let liveValue = Self(
        load: { playlistID, kind, itemID, cloudSyncEnabled in
            await TMDBMatchOverrideStore.shared.load(
                playlistID: playlistID,
                kind: kind,
                itemID: itemID,
                cloudSyncEnabled: cloudSyncEnabled
            )
        },
        save: { tmdbID, playlistID, kind, itemID, cloudSyncEnabled, updatedAt in
            await TMDBMatchOverrideStore.shared.save(
                tmdbID: tmdbID,
                playlistID: playlistID,
                kind: kind,
                itemID: itemID,
                cloudSyncEnabled: cloudSyncEnabled,
                updatedAt: updatedAt
            )
        }
    )

    public static let testValue = Self()
}

public extension DependencyValues {
    var tmdbMatchOverrideClient: TMDBMatchOverrideClient {
        get { self[TMDBMatchOverrideClient.self] }
        set { self[TMDBMatchOverrideClient.self] = newValue }
    }
}
