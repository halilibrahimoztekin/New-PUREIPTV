import Foundation

enum PlaylistArtworkRequest {
    static func cacheKey(for url: URL, userAgentOverride: String?, playlistID: UUID? = nil) -> String {
        let override = userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userAgent = override.flatMap { $0.isEmpty ? nil : $0 } ?? UserAgentManager.resolveUserAgent()
        let playlistScope = playlistID.map { "|playlist:\($0.uuidString.lowercased())" } ?? ""
        return "\(url.absoluteString)|user-agent:\(userAgent)\(playlistScope)"
    }

    static func applyHeaders(to request: inout URLRequest, userAgentOverride: String?, playlistID: UUID?) {
        UserAgentManager.applyHeaders(to: &request, override: userAgentOverride)
        MediaServerRequestContextFactory.cachedContext(for: playlistID, requestURL: request.url)?.apply(to: &request)
    }
}
