import ComposableArchitecture
import Foundation

public nonisolated enum MediaPresentationKind: String, Codable, Equatable, Sendable {
    case movie
    case series
}

public nonisolated struct MediaPresentationOverride: Codable, Equatable, Sendable {
    public let title: String?
    public let posterURLString: String?
    public let year: Int?

    public var posterURL: URL? {
        posterURLString.flatMap { URL(string: $0) }
    }

    public var isEmpty: Bool {
        title == nil && posterURLString == nil && year == nil
    }

    public init(title: String?, posterURLString: String?, year: Int?) {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = trimmedTitle.flatMap { $0.isEmpty ? nil : String($0.prefix(120)) }

        if let rawURL = posterURLString?.trimmingCharacters(in: .whitespacesAndNewlines),
           let components = URLComponents(string: rawURL),
           components.scheme?.lowercased() == "https",
           let host = components.host,
           !host.isEmpty,
           components.user == nil,
           components.password == nil,
           let url = components.url
        {
            self.posterURLString = url.absoluteString
        } else {
            self.posterURLString = nil
        }

        self.year = year.flatMap { (1888 ... 2100).contains($0) ? $0 : nil }
    }
}

private actor MediaPresentationOverrideStore {
    static let shared = MediaPresentationOverrideStore()
    private let defaults = UserDefaults.standard

    func load(profileID: UUID?, playlistID: UUID, kind: MediaPresentationKind) -> [String: MediaPresentationOverride] {
        guard let data = defaults.data(forKey: key(profileID, playlistID, kind)),
              let decoded = try? JSONDecoder().decode([String: MediaPresentationOverride].self, from: data)
        else { return [:] }

        return decoded.compactMapValues { value in
            let validated = MediaPresentationOverride(
                title: value.title,
                posterURLString: value.posterURLString,
                year: value.year
            )
            return validated.isEmpty ? nil : validated
        }
    }

    func save(
        _ override: MediaPresentationOverride?,
        itemID: String,
        profileID: UUID?,
        playlistID: UUID,
        kind: MediaPresentationKind
    ) {
        let storageKey = key(profileID, playlistID, kind)
        var values = load(profileID: profileID, playlistID: playlistID, kind: kind)
        let itemKey = itemID

        if let override {
            let validated = MediaPresentationOverride(
                title: override.title,
                posterURLString: override.posterURLString,
                year: override.year
            )
            if validated.isEmpty {
                values.removeValue(forKey: itemKey)
            } else {
                values[itemKey] = validated
            }
        } else {
            values.removeValue(forKey: itemKey)
        }

        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func key(_ profileID: UUID?, _ playlistID: UUID, _ kind: MediaPresentationKind) -> String {
        "com.pureiptv.mediaPresentation.v1.\(profileID?.uuidString ?? "default").\(playlistID.uuidString).\(kind.rawValue)"
    }
}

@DependencyClient
public struct MediaPresentationOverrideClient: Sendable {
    public var load: @Sendable (_ profileID: UUID?, _ playlistID: UUID, _ kind: MediaPresentationKind) async -> [String: MediaPresentationOverride] = { _, _, _ in [:] }
    public var save: @Sendable (
        _ override: MediaPresentationOverride?,
        _ itemID: String,
        _ profileID: UUID?,
        _ playlistID: UUID,
        _ kind: MediaPresentationKind
    ) async -> Void
}

extension MediaPresentationOverrideClient: DependencyKey {
    public static let liveValue = Self(
        load: { profileID, playlistID, kind in
            await MediaPresentationOverrideStore.shared.load(
                profileID: profileID,
                playlistID: playlistID,
                kind: kind
            )
        },
        save: { override, itemID, profileID, playlistID, kind in
            await MediaPresentationOverrideStore.shared.save(
                override,
                itemID: itemID,
                profileID: profileID,
                playlistID: playlistID,
                kind: kind
            )
        }
    )

    public static let testValue = Self()
}

public extension DependencyValues {
    var mediaPresentationOverrideClient: MediaPresentationOverrideClient {
        get { self[MediaPresentationOverrideClient.self] }
        set { self[MediaPresentationOverrideClient.self] = newValue }
    }
}
