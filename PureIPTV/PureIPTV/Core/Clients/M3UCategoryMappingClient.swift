import ComposableArchitecture
import Foundation

private actor M3UCategoryMappingStore {
    static let shared = M3UCategoryMappingStore()
    private let defaults = UserDefaults.standard

    func load(playlistID: UUID) -> [String: String] {
        guard let data = defaults.data(forKey: key(playlistID)) else { return [:] }
        let decoded = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        return Self.normalized(decoded)
    }

    func save(_ mappings: [String: String], playlistID: UUID) {
        guard let data = try? JSONEncoder().encode(Self.normalized(mappings)) else { return }
        defaults.set(data, forKey: key(playlistID))
    }

    private func key(_ playlistID: UUID) -> String {
        "com.pureiptv.m3uCategoryMappings.live.v1.\(playlistID.uuidString)"
    }

    private static func normalized(_ mappings: [String: String]) -> [String: String] {
        var values: [String: String] = [:]
        for (source, target) in mappings {
            let sourceTag = String(source.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
            let targetName = String(target.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            guard !sourceTag.isEmpty, !targetName.isEmpty else { continue }
            values[sourceTag] = targetName
        }
        return values
    }
}

@DependencyClient
public struct M3UCategoryMappingClient: Sendable {
    public var load: @Sendable (_ playlistID: UUID) async -> [String: String] = { _ in [:] }
    public var save: @Sendable (_ mappings: [String: String], _ playlistID: UUID) async -> Void
}

extension M3UCategoryMappingClient: DependencyKey {
    public static let liveValue = Self(
        load: { playlistID in await M3UCategoryMappingStore.shared.load(playlistID: playlistID) },
        save: { mappings, playlistID in await M3UCategoryMappingStore.shared.save(mappings, playlistID: playlistID) }
    )

    public static let testValue = Self()
}

public extension DependencyValues {
    var m3uCategoryMappingClient: M3UCategoryMappingClient {
        get { self[M3UCategoryMappingClient.self] }
        set { self[M3UCategoryMappingClient.self] = newValue }
    }
}
