import Foundation

enum PlaylistArtworkRequest {
    static func cacheKey(for url: URL, userAgentOverride: String?) -> String {
        let override = userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userAgent = override.flatMap { $0.isEmpty ? nil : $0 } ?? UserAgentManager.resolveUserAgent()
        return "\(url.absoluteString)|user-agent:\(userAgent)"
    }
}
