import ComposableArchitecture
import Foundation

public nonisolated struct CategoryNameRule: Codable, Equatable, Identifiable, Sendable {
    public nonisolated enum MatchMode: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
        case literal
        case regularExpression
    }

    public let id: UUID
    public var pattern: String
    public var mode: MatchMode
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        pattern: String = "",
        mode: MatchMode = .literal,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.pattern = pattern
        self.mode = mode
        self.isEnabled = isEnabled
    }
}

private actor CategoryNameRuleStore {
    static let shared = CategoryNameRuleStore()
    private let defaults = UserDefaults.standard

    func load(profileID: UUID?, playlistID: UUID, mediaType: String) -> [CategoryNameRule] {
        guard Self.supportedMediaTypes.contains(mediaType),
              let data = defaults.data(forKey: key(profileID, playlistID, mediaType)),
              data.count <= Self.maximumPayloadSize,
              let rules = try? JSONDecoder().decode([CategoryNameRule].self, from: data) else { return [] }
        return Array(rules.prefix(Self.maximumRuleCount))
    }

    func save(
        _ rules: [CategoryNameRule],
        profileID: UUID?,
        playlistID: UUID,
        mediaType: String
    ) -> Bool {
        guard Self.supportedMediaTypes.contains(mediaType),
              rules.count <= Self.maximumRuleCount,
              rules.allSatisfy({ $0.pattern.count <= Self.maximumStoredPatternLength }),
              Set(rules.map(\.id)).count == rules.count else { return false }

        let storageKey = key(profileID, playlistID, mediaType)
        guard !rules.isEmpty else {
            defaults.removeObject(forKey: storageKey)
            return true
        }

        guard let data = try? JSONEncoder().encode(rules),
              data.count <= Self.maximumPayloadSize else { return false }
        defaults.set(data, forKey: storageKey)
        return true
    }

    private func key(_ profileID: UUID?, _ playlistID: UUID, _ mediaType: String) -> String {
        "com.pureiptv.categoryNameRules.v1.\(profileID?.uuidString ?? "default").\(playlistID.uuidString).\(mediaType)"
    }

    private static let supportedMediaTypes: Set<String> = ["live", "vod", "series"]
    private static let maximumRuleCount = 100
    private static let maximumStoredPatternLength = 256
    private static let maximumPayloadSize = 1_048_576
}

@DependencyClient
public struct CategoryNameRuleClient: Sendable {
    public var load: @Sendable (_ profileID: UUID?, _ playlistID: UUID, _ mediaType: String) async -> [CategoryNameRule] = { _, _, _ in [] }
    public var save: @Sendable (_ rules: [CategoryNameRule], _ profileID: UUID?, _ playlistID: UUID, _ mediaType: String) async -> Bool = { _, _, _, _ in false }
}

extension CategoryNameRuleClient: DependencyKey {
    public static let liveValue = Self(
        load: { profileID, playlistID, mediaType in
            await CategoryNameRuleStore.shared.load(profileID: profileID, playlistID: playlistID, mediaType: mediaType)
        },
        save: { rules, profileID, playlistID, mediaType in
            await CategoryNameRuleStore.shared.save(
                rules,
                profileID: profileID,
                playlistID: playlistID,
                mediaType: mediaType
            )
        }
    )

    public static let testValue = Self()
}

public extension DependencyValues {
    var categoryNameRuleClient: CategoryNameRuleClient {
        get { self[CategoryNameRuleClient.self] }
        set { self[CategoryNameRuleClient.self] = newValue }
    }
}
