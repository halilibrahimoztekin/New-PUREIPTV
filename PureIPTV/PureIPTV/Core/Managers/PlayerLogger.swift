import Foundation
import OSLog

public enum PlayerLogLevel: String, CaseIterable, Sendable, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    public var emoji: String {
        switch self {
        case .debug: "⚪️"
        case .info: "🔵"
        case .warning: "🟡"
        case .error: "🔴"
        }
    }
}

public struct PlayerLogEntry: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let level: PlayerLogLevel
    public let category: String
    public let message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: PlayerLogLevel,
        category: String,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
    }

    public var formattedTimestamp: String {
        Self.dateFormatter.string(from: timestamp)
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        return df
    }()

    public var filterableConsoleLine: String {
        "\(formattedTimestamp) [PureIPTV:Player] \(level.emoji) [\(level.rawValue)] [\(category)] \(message)"
    }
}

public final class PlayerLogger: @unchecked Sendable {
    public static let shared = PlayerLogger()

    private let osLogger = Logger(subsystem: "com.pureiptv.app", category: "VideoPlayer")
    private let lock = NSLock()
    private var entries: [PlayerLogEntry] = []
    private let maxEntries: Int = 400

    private init() {}

    /// Sanitizes sensitive information such as credentials, Xtream tokens, and passwords from log strings.
    public static func sanitize(message: String) -> String {
        var sanitized = message

        // 1. Redact credentials embedded in standard IPTV / Xtream URLs:
        // Pattern: /live/user/pass/id.ext or /movie/user/pass/id.ext or /series/user/pass/id.ext
        let urlRegex = try? NSRegularExpression(
            pattern: #"(https?://[^/\s]+/(?:live|movie|series)/)([^/\s]+)/([^/\s]+)(/[^/\s]+)"#,
            options: .caseInsensitive
        )
        if let regex = urlRegex {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: "$1***/$4")
        }

        // 2. Redact query-parameter secrets: username, password, token, key, secret, auth
        let queryRegex = try? NSRegularExpression(
            pattern: #"(?i)(password|passwd|pass|token|secret|auth|api_key|apikey)=([^&\s]+)"#,
            options: []
        )
        if let regex = queryRegex {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            sanitized = regex.stringByReplacingMatches(in: sanitized, options: [], range: range, withTemplate: "$1=***")
        }

        return sanitized
    }

    public func log(level: PlayerLogLevel, category: String, message: String) {
        let cleanMessage = Self.sanitize(message: message)
        let entry = PlayerLogEntry(level: level, category: category, message: cleanMessage)

        // 1. Apple Unified Logging (for Console.app, log stream, Instruments)
        switch level {
        case .debug:
            osLogger.debug("[\(category, privacy: .public)] \(cleanMessage, privacy: .public)")
        case .info:
            osLogger.info("[\(category, privacy: .public)] \(cleanMessage, privacy: .public)")
        case .warning:
            osLogger.warning("[\(category, privacy: .public)] \(cleanMessage, privacy: .public)")
        case .error:
            osLogger.error("[\(category, privacy: .public)] \(cleanMessage, privacy: .public)")
        }

        // 2. Standard Output Print for instant Xcode / Terminal filtering:
        // Filter by typing "[PureIPTV:Player]" or "[ERROR]" or category name in Xcode Console filter bar
        print(entry.filterableConsoleLine)

        lock.lock()
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()
    }

    public func debug(category: String, message: String) {
        log(level: .debug, category: category, message: message)
    }

    public func info(category: String, message: String) {
        log(level: .info, category: category, message: message)
    }

    public func warning(category: String, message: String) {
        log(level: .warning, category: category, message: message)
    }

    public func error(category: String, message: String) {
        log(level: .error, category: category, message: message)
    }

    public func getEntries() -> [PlayerLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    public func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    public func exportFormattedText() -> String {
        let snapshot = getEntries()
        var text = "=== PureIPTV Player Diagnostics Log ===\n"
        text += "Exported At: \(Date())\n"
        #if os(tvOS)
            text += "Platform: tvOS\n"
        #else
            text += "Platform: iOS\n"
        #endif
        text += "Total Log Entries: \(snapshot.count)\n"
        text += "========================================\n\n"
        for entry in snapshot {
            text += entry.filterableConsoleLine + "\n"
        }
        return text
    }
}
