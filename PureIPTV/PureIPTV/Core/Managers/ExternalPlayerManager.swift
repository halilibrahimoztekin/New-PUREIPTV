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

        public var checkURL: URL? {
            switch self {
            case .vlc:
                URL(string: "vlc://")
            case .infuse:
                URL(string: "infuse://")
            case .outplayer:
                URL(string: "outplayer://")
            }
        }

        public var appStoreURL: URL? {
            switch self {
            case .vlc:
                URL(string: "https://apps.apple.com/app/vlc-for-mobile/id650377962")
            case .infuse:
                URL(string: "https://apps.apple.com/app/infuse-video-player/id1136220934")
            case .outplayer:
                URL(string: "https://apps.apple.com/app/outplayer/id1449923287")
            }
        }

        public func openURLs(for streamURL: URL) -> [URL] {
            let raw = streamURL.absoluteString
            let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw

            switch self {
            case .vlc:
                var urls: [URL] = []
                // VLC iOS supports both direct vlc:// and x-callback-url formats
                if let direct = URL(string: "vlc://\(raw)") {
                    urls.append(direct)
                }
                if let callback = URL(string: "vlc-x-callback://x-callback-url/stream?url=\(encoded)") {
                    urls.append(callback)
                }
                return urls

            case .infuse:
                var urls: [URL] = []
                if let callback = URL(string: "infuse://x-callback-url/play?url=\(encoded)") {
                    urls.append(callback)
                }
                if let direct = URL(string: "infuse://play?url=\(encoded)") {
                    urls.append(direct)
                }
                return urls

            case .outplayer:
                var urls: [URL] = []
                if let direct = URL(string: "outplayer://\(encoded)") {
                    urls.append(direct)
                }
                return urls
            }
        }
    }

    public enum ExternalPlayerResult: Sendable {
        case opened
        case appNotInstalled(appStoreURL: URL?)
        case failed
    }

    @MainActor
    public final class ExternalPlayerManager: Sendable {
        public static let shared = ExternalPlayerManager()

        private init() {}

        public func isInstalled(_ player: ExternalPlayer) -> Bool {
            guard let checkURL = player.checkURL else { return false }
            return UIApplication.shared.canOpenURL(checkURL)
        }

        @discardableResult
        public func openStream(_ streamURL: URL, in player: ExternalPlayer) -> ExternalPlayerResult {
            // Always copy the stream URL to clipboard so user can paste it anywhere
            UIPasteboard.general.string = streamURL.absoluteString
            HapticManager.shared.trigger(.light)

            let candidateURLs = player.openURLs(for: streamURL)

            for url in candidateURLs {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    return .opened
                }
            }

            // If not directly openable via custom schemes, try first candidate URL anyway
            if let first = candidateURLs.first {
                UIApplication.shared.open(first, options: [:]) { success in
                    if !success, let storeURL = player.appStoreURL {
                        UIApplication.shared.open(storeURL, options: [:], completionHandler: nil)
                    }
                }
                return .opened
            }

            // Fallback: Player not installed, open App Store link
            if let storeURL = player.appStoreURL {
                UIApplication.shared.open(storeURL, options: [:], completionHandler: nil)
                return .appNotInstalled(appStoreURL: storeURL)
            }

            return .failed
        }
    }
#endif
