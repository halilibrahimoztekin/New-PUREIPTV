import Foundation

enum RememberedPlaybackChoice: String, Equatable, Sendable {
    case inAppVLC = "in-app:vlc"
    case inAppAVPlayer = "in-app:avplayer"
    case externalVLC = "external:vlc"
    case externalInfuse = "external:infuse"
    case externalOutplayer = "external:outplayer"

    var title: String {
        switch self {
        case .inAppVLC: "VLC"
        case .inAppAVPlayer: "AVPlayer"
        case .externalVLC: "VLC Media Player"
        case .externalInfuse: "Infuse"
        case .externalOutplayer: "Outplayer"
        }
    }

    var playbackEngine: PlaybackEngine? {
        switch self {
        case .inAppVLC: .vlc
        case .inAppAVPlayer: .avPlayer
        case .externalVLC, .externalInfuse, .externalOutplayer: nil
        }
    }

    static func inApp(_ engine: PlaybackEngine) -> Self {
        switch engine {
        case .vlc: .inAppVLC
        case .avPlayer: .inAppAVPlayer
        }
    }

    #if canImport(UIKit)
        var externalPlayer: ExternalPlayer? {
            switch self {
            case .externalVLC: .vlc
            case .externalInfuse: .infuse
            case .externalOutplayer: .outplayer
            case .inAppVLC, .inAppAVPlayer: nil
            }
        }

        static func external(_ player: ExternalPlayer) -> Self {
            switch player {
            case .vlc: .externalVLC
            case .infuse: .externalInfuse
            case .outplayer: .externalOutplayer
            }
        }
    #endif
}

struct PlaybackChoiceReminder: Equatable, Sendable {
    let choice: RememberedPlaybackChoice
    let scopeKey: String
}

enum PlaybackChoicePreferenceStore {
    private static let keyPrefix = "com.pureiptv.playbackChoice.v1"

    static func load(
        item: PlayerFeature.PlayableItem,
        playbackURL: URL,
        profileID: UUID?
    ) -> PlaybackChoiceReminder? {
        guard let scopeKey = scopeKey(
            item: item,
            playbackURL: playbackURL,
            profileID: profileID
        ),
            let rawValue = UserDefaults.standard.string(forKey: scopeKey),
            let choice = RememberedPlaybackChoice(rawValue: rawValue)
        else {
            return nil
        }

        return PlaybackChoiceReminder(choice: choice, scopeKey: scopeKey)
    }

    static func save(
        _ choice: RememberedPlaybackChoice,
        item: PlayerFeature.PlayableItem,
        playbackURL: URL,
        profileID: UUID?
    ) {
        guard let scopeKey = scopeKey(
            item: item,
            playbackURL: playbackURL,
            profileID: profileID
        ) else { return }

        UserDefaults.standard.set(choice.rawValue, forKey: scopeKey)
    }

    static func clear(scopeKey: String) {
        UserDefaults.standard.removeObject(forKey: scopeKey)
    }

    static func scopeKey(
        item: PlayerFeature.PlayableItem,
        playbackURL: URL,
        profileID: UUID?
    ) -> String? {
        guard let playlistID = item.config?.playlistID,
              let scheme = playbackURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else { return nil }

        let streamFormat = playbackURL.pathExtension.lowercased()
        guard !streamFormat.isEmpty else { return nil }

        let mediaKind = item.isLive ? "live" : "vod"
        let profileKey = profileID?.uuidString.lowercased() ?? "default"
        return "\(keyPrefix).\(profileKey).\(playlistID.uuidString.lowercased()).\(mediaKind).\(scheme).\(streamFormat)"
    }
}
