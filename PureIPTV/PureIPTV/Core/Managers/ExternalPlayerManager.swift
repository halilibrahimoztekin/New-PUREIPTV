#if canImport(UIKit)
    import UIKit

    public enum ExternalPlayer: String, CaseIterable, Identifiable, Sendable {
        case vlc = "VLC Media Player"
        case infuse = "Infuse"
        case outplayer = "Outplayer"

        public var id: String {
            rawValue
        }

        public var iconName: String {
            switch self {
            case .vlc: "cone.fill"
            case .infuse: "play.circle.fill"
            case .outplayer: "arrow.up.right.video.fill"
            }
        }

        public func openURL(for streamURL: URL) -> URL? {
            let raw = streamURL.absoluteString
            guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return nil
            }

            switch self {
            case .vlc:
                return URL(string: "vlc-x-callback://x-callback-url/stream?url=\(encoded)") ?? URL(string: "vlc://\(encoded)")
            case .infuse:
                return URL(string: "infuse://x-callback-url/play?url=\(encoded)")
            case .outplayer:
                return URL(string: "outplayer://\(encoded)")
            }
        }
    }

    @MainActor
    public final class ExternalPlayerManager: Sendable {
        public static let shared = ExternalPlayerManager()

        private init() {}

        public func openStream(_ streamURL: URL, in player: ExternalPlayer) -> Bool {
            guard let url = player.openURL(for: streamURL) else { return false }

            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return true
            } else {
                // If custom scheme cannot be opened directly, try fallback URL
                if player == .vlc, let fallback = URL(string: "vlc://\(streamURL.absoluteString)") {
                    UIApplication.shared.open(fallback, options: [:], completionHandler: nil)
                    return true
                }
                return false
            }
        }
    }
#endif
