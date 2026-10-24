import ComposableArchitecture
import Foundation

public enum ChannelLogoOverrideURL {
    public static let maximumLength = 2048

    public static func validatedURL(from rawValue: String) -> URL? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.utf8.count <= maximumLength,
              let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              let url = components.url,
              url.absoluteString.utf8.count <= maximumLength else { return nil }
        return url
    }
}

private actor ChannelLogoOverrideStore {
    static let shared = ChannelLogoOverrideStore()
    private let defaults = UserDefaults.standard
    private let keyPrefix = "PureIPTV.ChannelLogoOverrides.v1."

    func fetch(playlistID: UUID, channelIDs: [String]) -> [String: URL] {
        let values = defaults.dictionary(forKey: key(for: playlistID)) as? [String: String] ?? [:]
        var result: [String: URL] = [:]
        for channelID in channelIDs where isValidChannelID(channelID) {
            guard let rawValue = values[channelID],
                  let url = ChannelLogoOverrideURL.validatedURL(from: rawValue) else { continue }
            result[channelID] = url
        }
        return result
    }

    func set(playlistID: UUID, channelID: String, rawValue: String?) -> URL? {
        guard isValidChannelID(channelID) else { return nil }
        let key = key(for: playlistID)
        var values = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        if let rawValue {
            guard let url = ChannelLogoOverrideURL.validatedURL(from: rawValue) else { return nil }
            values[channelID] = url.absoluteString
            defaults.set(values, forKey: key)
            return url
        }
        values.removeValue(forKey: channelID)
        if values.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(values, forKey: key)
        }
        return nil
    }

    private func key(for playlistID: UUID) -> String {
        keyPrefix + playlistID.uuidString
    }

    private func isValidChannelID(_ channelID: String) -> Bool {
        !channelID.isEmpty && channelID.utf8.count <= 512
    }
}

@DependencyClient
public struct ChannelLogoOverrideClient: Sendable {
    public var fetchOverrides: @Sendable (_ playlistID: UUID, _ channelIDs: [String]) async -> [String: URL] = { _, _ in [:] }
    public var setOverride: @Sendable (_ playlistID: UUID, _ channelID: String, _ rawValue: String?) async -> URL?
}

extension ChannelLogoOverrideClient: DependencyKey {
    public static let liveValue = ChannelLogoOverrideClient(
        fetchOverrides: { playlistID, channelIDs in
            await ChannelLogoOverrideStore.shared.fetch(playlistID: playlistID, channelIDs: channelIDs)
        },
        setOverride: { playlistID, channelID, rawValue in
            await ChannelLogoOverrideStore.shared.set(playlistID: playlistID, channelID: channelID, rawValue: rawValue)
        }
    )
    public static let testValue = ChannelLogoOverrideClient()
}

public extension DependencyValues {
    var channelLogoOverrideClient: ChannelLogoOverrideClient {
        get { self[ChannelLogoOverrideClient.self] }
        set { self[ChannelLogoOverrideClient.self] = newValue }
    }
}
