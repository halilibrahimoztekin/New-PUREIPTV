import CryptoKit
import Foundation

enum SpecificPlaybackEnginePreferenceStore {
    private static let keyPrefix = "com.pureiptv.playbackEnginePreference.v1"

    static func load(
        item: PlayerFeature.PlayableItem,
        profileID: UUID?
    ) -> PlaybackEngine? {
        guard let key = scopeKey(item: item, profileID: profileID),
              let rawValue = UserDefaults.standard.string(forKey: key)
        else { return nil }
        return PlaybackEngine(rawValue: rawValue)
    }

    static func save(
        _ engine: PlaybackEngine,
        item: PlayerFeature.PlayableItem,
        profileID: UUID?
    ) {
        guard let key = scopeKey(item: item, profileID: profileID) else { return }
        UserDefaults.standard.set(engine.rawValue, forKey: key)
    }

    static func clear(item: PlayerFeature.PlayableItem, profileID: UUID?) {
        guard let key = scopeKey(item: item, profileID: profileID) else { return }
        UserDefaults.standard.removeObject(forKey: key)
    }

    static func scopeKey(
        item: PlayerFeature.PlayableItem,
        profileID: UUID?
    ) -> String? {
        guard !item.isLive,
              let playlistID = item.config?.playlistID,
              let safeItemID = validatedIdentifier(item.id)
        else { return nil }

        let safeSeriesID: String?
        if let seriesID = item.seriesID {
            guard let validatedSeriesID = validatedIdentifier(seriesID) else { return nil }
            safeSeriesID = validatedSeriesID
        } else {
            safeSeriesID = nil
        }
        let identity = safeItemID + "\u{0}" + (safeSeriesID ?? "")
        let digest = SHA256.hash(data: Data(identity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let profileKey = profileID?.uuidString.lowercased() ?? "default"
        return "\(keyPrefix).\(profileKey).\(playlistID.uuidString.lowercased()).\(digest)"
    }

    private static func validatedIdentifier(_ value: String) -> String? {
        guard (1 ... 256).contains(value.utf8.count),
              value.utf8.allSatisfy({ byte in
                  (65 ... 90).contains(byte) || (97 ... 122).contains(byte)
                      || (48 ... 57).contains(byte) || byte == 45 || byte == 46 || byte == 95
              })
        else { return nil }
        return value
    }
}
