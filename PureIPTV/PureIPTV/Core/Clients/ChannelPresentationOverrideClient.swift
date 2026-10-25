import ComposableArchitecture
import Foundation

public struct ChannelPresentationOverride: Codable, Equatable, Sendable {
    public var name: String?
    public var number: Int?

    public init(name: String? = nil, number: Int? = nil) {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedName, !trimmedName.isEmpty {
            self.name = String(trimmedName.prefix(80))
        } else {
            self.name = nil
        }
        self.number = number.flatMap { (1 ... 999_999).contains($0) ? $0 : nil }
    }
}

public struct ChannelPresentationEditorTarget: Identifiable {
    public let channel: MediaModels.Item
    public let playlistID: UUID
    public let profileScope: ProfileContextSnapshot

    public var id: String {
        "\(playlistID.uuidString):\(profileScope.profileID?.uuidString ?? "default"): \(profileScope.generation.uuidString):\(channel.id)"
    }

    public init(channel: MediaModels.Item, playlistID: UUID, profileScope: ProfileContextSnapshot) {
        self.channel = channel
        self.playlistID = playlistID
        self.profileScope = profileScope
    }
}

private actor ChannelPresentationOverrideStore {
    static let shared = ChannelPresentationOverrideStore()
    private let defaults = UserDefaults.standard

    func load(profileID: UUID?, playlistID: UUID) -> [String: ChannelPresentationOverride] {
        guard let data = defaults.data(forKey: key(profileID, playlistID)) else { return [:] }
        return (try? JSONDecoder().decode([String: ChannelPresentationOverride].self, from: data)) ?? [:]
    }

    func save(_ override: ChannelPresentationOverride?, channelID: String, profileID: UUID?, playlistID: UUID) {
        let storageKey = key(profileID, playlistID)
        var values = load(profileID: profileID, playlistID: playlistID)
        if let override, override.name != nil || override.number != nil {
            values[channelID] = override
        } else {
            values.removeValue(forKey: channelID)
        }
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func key(_ profileID: UUID?, _ playlistID: UUID) -> String {
        "com.pureiptv.channelPresentation.v1.\(profileID?.uuidString ?? "default").\(playlistID.uuidString)"
    }
}

@DependencyClient
public struct ChannelPresentationOverrideClient: Sendable {
    public var load: @Sendable (_ profileID: UUID?, _ playlistID: UUID) async -> [String: ChannelPresentationOverride] = { _, _ in [:] }
    public var save: @Sendable (_ override: ChannelPresentationOverride?, _ channelID: String, _ profileID: UUID?, _ playlistID: UUID) async -> Void
}

extension ChannelPresentationOverrideClient: DependencyKey {
    public static let liveValue = Self(
        load: { profileID, playlistID in
            await ChannelPresentationOverrideStore.shared.load(profileID: profileID, playlistID: playlistID)
        },
        save: { override, channelID, profileID, playlistID in
            await ChannelPresentationOverrideStore.shared.save(override, channelID: channelID, profileID: profileID, playlistID: playlistID)
        }
    )

    public static let testValue = Self()
}

public extension DependencyValues {
    var channelPresentationOverrideClient: ChannelPresentationOverrideClient {
        get { self[ChannelPresentationOverrideClient.self] }
        set { self[ChannelPresentationOverrideClient.self] = newValue }
    }
}
