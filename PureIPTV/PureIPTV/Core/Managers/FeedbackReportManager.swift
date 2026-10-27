import Foundation
#if os(iOS) || os(tvOS)
    import UIKit
#endif

private struct ConnectionFailureContext: Sendable {
    let playlistFormat: String
    let stage: String
    let errorCode: String
}

/// Creates a deliberately small support report from an explicit allowlist.
/// No app logs, playback state, account data, URLs, or error text are read.
public actor FeedbackReportManager {
    public static let shared = FeedbackReportManager()
    private var latestConnectionFailure: ConnectionFailureContext?

    private init() {}

    public func recordConnectionFailure(playlistType: PlaylistType, error: Error) {
        let errorCode = if let networkError = error as? NetworkError {
            switch networkError {
            case .invalidURL: "invalid_url"
            case .invalidResponse: "invalid_response"
            case .unauthorized: "unauthorized"
            case let .serverError(statusCode): "http_\(min(max(statusCode, 100), 599))"
            case .rateLimited: "rate_limited"
            case .decodingFailed: "decoding_failed"
            case .underlying: "network_error"
            }
        } else if error is CancellationError {
            "cancelled"
        } else {
            "connection_failed"
        }
        latestConnectionFailure = ConnectionFailureContext(
            playlistFormat: playlistType == .xtream ? "Xtream" : "M3U",
            stage: "playlist_authentication",
            errorCode: errorCode
        )
    }

    public func clearConnectionFailure() {
        latestConnectionFailure = nil
    }

    public func generateDiagnosticReport() async -> URL? {
        let bundle = Bundle.main
        let appVersion = bounded(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, limit: 32) ?? "Unknown"
        let build = bounded(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String, limit: 32) ?? "Unknown"
        let osVersion = bounded(ProcessInfo.processInfo.operatingSystemVersionString, limit: 64) ?? "Unknown"
        #if os(tvOS)
            let platform = "tvOS"
        #elseif os(iOS)
            let platform = "iOS"
        #else
            let platform = "Apple platform"
        #endif
        #if os(iOS) || os(tvOS)
            let deviceType = await MainActor.run { UIDevice.current.model }
        #else
            let deviceType = platform
        #endif
        let generatedAt = ISO8601DateFormatter().string(from: Date())

        let connectionDetails = latestConnectionFailure.map {
            """
            Son bağlantı denemesi:
            Playlist biçimi: \($0.playlistFormat)
            Uygulama aşaması: \($0.stage)
            Sansürlenmiş hata kodu: \($0.errorCode)
            """
        } ?? "Son başarısız playlist bağlantısı yok."

        let report = """
        PureIPTV Gizlilik Korumalı Tanılama Raporu
        Oluşturulma: \(generatedAt)
        Uygulama sürümü: \(appVersion) (\(build))
        Platform: \(platform)
        Cihaz türü: \(bounded(deviceType, limit: 32) ?? "Unknown")
        İşletim sistemi: \(osVersion)

        \(connectionDetails)

        Gizlilik: Bu rapor yalnızca yukarıdaki bilgileri içerir. Günlükler, etkin kanal,
        oynatma adresleri, hesap veya kullanıcı kimlikleri, ağ bilgileri ve hata metinleri eklenmemiştir.
        """
        // Constant-sized allowlisted fields and strict per-field bounds keep report generation bounded.
        guard report.utf8.count <= 2048 else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PureIPTV-Diagnostic-\(UUID().uuidString).txt", isDirectory: false)
        do {
            try Data(report.utf8).write(to: url, options: .atomic)
            #if os(iOS) || os(tvOS)
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: url.path
                )
            #endif
            return url
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    private func bounded(_ value: String?, limit: Int) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return String(value.prefix(limit)).filter { !$0.isNewline && !$0.isWhitespace || $0 == " " }
    }
}
