import ComposableArchitecture
import Foundation

private actor CategoryNameOverrideStore {
    static let shared = CategoryNameOverrideStore()
    private let defaults = UserDefaults.standard

    func load(playlistID: UUID, mediaType: String) -> [String: String] {
        guard Self.supportedMediaTypes.contains(mediaType),
              let data = defaults.data(forKey: key(playlistID, mediaType)),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return Self.normalized(decoded)
    }

    func save(_ overrides: [String: String], playlistID: UUID, mediaType: String) {
        guard Self.supportedMediaTypes.contains(mediaType) else { return }
        let storageKey = key(playlistID, mediaType)
        let normalized = Self.normalized(overrides)
        guard !normalized.isEmpty else {
            defaults.removeObject(forKey: storageKey)
            return
        }
        guard normalized.count <= 4096,
              let data = try? JSONEncoder().encode(normalized),
              data.count <= 1_048_576 else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func key(_ playlistID: UUID, _ mediaType: String) -> String {
        "com.pureiptv.categoryNames.v1.\(playlistID.uuidString).\(mediaType)"
    }

    private static let supportedMediaTypes: Set<String> = ["live", "vod", "series"]

    private static func normalized(_ overrides: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (categoryID, value) in overrides.prefix(4096) {
            let key = String(categoryID.trimmingCharacters(in: .whitespacesAndNewlines).prefix(512))
            let name = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
            guard !key.isEmpty, !name.isEmpty else { continue }
            result[key] = name
        }
        return result
    }
}

@DependencyClient
public struct CategoryNameOverrideClient: Sendable {
    public var load: @Sendable (_ playlistID: UUID, _ mediaType: String) async -> [String: String] = { _, _ in [:] }
    public var save: @Sendable (_ overrides: [String: String], _ playlistID: UUID, _ mediaType: String) async -> Void
}

extension CategoryNameOverrideClient: DependencyKey {
    public static let liveValue = Self(
        load: { playlistID, mediaType in
            await CategoryNameOverrideStore.shared.load(playlistID: playlistID, mediaType: mediaType)
        },
        save: { overrides, playlistID, mediaType in
            await CategoryNameOverrideStore.shared.save(overrides, playlistID: playlistID, mediaType: mediaType)
        }
    )

    public static let testValue = Self()
}

public extension DependencyValues {
    var categoryNameOverrideClient: CategoryNameOverrideClient {
        get { self[CategoryNameOverrideClient.self] }
        set { self[CategoryNameOverrideClient.self] = newValue }
    }
}
