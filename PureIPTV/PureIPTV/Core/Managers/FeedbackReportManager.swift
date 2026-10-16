import Foundation
import OSLog

public struct FeedbackDiagnosticReport: Sendable {
    public let timestamp: Date
    public let osVersion: String
    public let appVersion: String
    public let vpnActive: Bool
    public let sanitizedLogs: String
}

@MainActor
public final class FeedbackReportManager: Sendable {
    public static let shared = FeedbackReportManager()

    private init() {}

    public func generateDiagnosticReport(activeChannelName: String? = nil, lastErrorMessage: String? = nil) async -> URL? {
        var logLines: [String] = []

        if #available(iOS 15.0, tvOS 15.0, *) {
            do {
                let store = try OSLogStore(scope: .currentProcessIdentifier)
                let oneMinuteAgo = store.position(date: Date().addingTimeInterval(-60))
                let entries = try store.getEntries(at: oneMinuteAgo)

                for entry in entries {
                    if let logEntry = entry as? OSLogEntryLog {
                        logLines.append("[\(logEntry.date.formatted(date: .omitted, time: .standard))] [\(logEntry.category)] \(logEntry.composedMessage)")
                    }
                }
            } catch {
                logLines.append("OSLog okuma hatası: \(error.localizedDescription)")
            }
        }

        // Sanitize sensitive credentials
        let joinedLogs = logLines.joined(separator: "\n")
        let sanitized = sanitizeCredentials(in: joinedLogs)

        let isVPN = VPNMonitor.shared.isConnected
        let osInfo = ProcessInfo.processInfo.operatingSystemVersionString

        let report = """
        # PureIPTV Hata Teşhis Raporu
        Tarih: \(Date().formatted(date: .abbreviated, time: .standard))
        İşletim Sistemi: \(osInfo)
        VPN Durumu: \(isVPN ? "Aktif" : "Pasif")
        Aktif Kanal: \(activeChannelName ?? "Yok")
        Son Hata: \(lastErrorMessage ?? "Yok")

        ## Son 1 Dakikalık Sistem Günlükleri (Maskelenmiş):
        ```
        \(sanitized.isEmpty ? "Kritik log kaydı bulunamadı." : sanitized)
        ```
        """

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("PureIPTV_Report_\(Int(Date().timeIntervalSince1970)).txt")
        do {
            try report.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }

    private func sanitizeCredentials(in raw: String) -> String {
        var sanitized = raw
        // Mask passwords in query params or json
        let passwordRegex = try? NSRegularExpression(pattern: #"(password=)[^& \n]+"#, options: .caseInsensitive)
        sanitized = passwordRegex?.stringByReplacingMatches(in: sanitized, range: NSRange(location: 0, length: sanitized.utf16.count), withTemplate: "$1***") ?? sanitized

        let tokenRegex = try? NSRegularExpression(pattern: #"(token=)[^& \n]+"#, options: .caseInsensitive)
        sanitized = tokenRegex?.stringByReplacingMatches(in: sanitized, range: NSRange(location: 0, length: sanitized.utf16.count), withTemplate: "$1***") ?? sanitized

        let userRegex = try? NSRegularExpression(pattern: #"(username=)[^& \n]+"#, options: .caseInsensitive)
        sanitized = userRegex?.stringByReplacingMatches(in: sanitized, range: NSRange(location: 0, length: sanitized.utf16.count), withTemplate: "$1***") ?? sanitized

        return sanitized
    }
}
