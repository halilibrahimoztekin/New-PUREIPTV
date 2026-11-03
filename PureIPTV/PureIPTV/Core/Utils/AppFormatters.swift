import Foundation

/// Centralized, high-performance, thread-safe cached formatters for PureIPTV.
/// CoreFoundation / ICU formatters (`DateFormatter`, `ByteCountFormatter`, `ISO8601DateFormatter`, `RelativeDateTimeFormatter`)
/// are expensive to initialize (0.1ms - 0.5ms each). Reusing cached instances eliminates main-thread hitches
/// during scrolling and bulk catalog synchronization.
public nonisolated enum AppFormatters: Sendable {
    // MARK: - Locks & Storage

    private final class Storage: @unchecked Sendable {
        static let shared = Storage()

        let lock = NSLock()

        /// Time & Day Formatters
        lazy var shortTimeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.timeStyle = .short
            return f
        }()

        lazy var shortDayFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEE d"
            return f
        }()

        lazy var shortDateTimeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .short
            return f
        }()

        lazy var mediumDateShortTimeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            f.locale = Locale(identifier: "tr_TR")
            return f
        }()

        lazy var catchupTimestampFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd:HH-mm"
            return f
        }()

        lazy var httpDateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
            return f
        }()

        /// ISO8601
        lazy var iso8601Formatter = ISO8601DateFormatter()

        /// Relative Date Time
        lazy var relativeDateTimeFormatter: RelativeDateTimeFormatter = {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .short
            f.locale = Locale(identifier: "tr_TR")
            return f
        }()

        /// Byte Count Formatters
        lazy var fileSizeFormatter: ByteCountFormatter = {
            let f = ByteCountFormatter()
            f.allowedUnits = [.useMB, .useGB]
            f.countStyle = .file
            return f
        }()

        lazy var downloadSpeedFormatter: ByteCountFormatter = {
            let f = ByteCountFormatter()
            f.allowedUnits = [.useKB, .useMB]
            f.countStyle = .file
            return f
        }()

        lazy var generalByteCountFormatter: ByteCountFormatter = {
            let f = ByteCountFormatter()
            f.allowedUnits = [.useGB, .useMB]
            f.countStyle = .file
            return f
        }()

        /// Xtream Release Date Formatters
        lazy var xtreamReleaseDateFormatters: [DateFormatter] = ["yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "dd/MM/yyyy"].map { format in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = format
            return f
        }

        /// EPG Fallback Formatters
        lazy var epgFallbackFormatters: [DateFormatter] = [
            "yyyyMMddHHmmss Z",
            "yyyyMMddHHmmss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyyMMddHHmm",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        ].map { fmt in
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
            return f
        }
    }

    // MARK: - Public Formatting APIs

    /// Formats time in short format (e.g. "14:30")
    public static func timeShort(_ date: Date) -> String {
        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.shortTimeFormatter.string(from: date)
    }

    /// Formats day in "EEE d" format (e.g. "Pzt 3")
    public static func dayShort(_ date: Date) -> String {
        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.shortDayFormatter.string(from: date)
    }

    /// Formats short date and time (e.g. "03.11.2026 14:30")
    public static func dateTimeShort(_ date: Date) -> String {
        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.shortDateTimeFormatter.string(from: date)
    }

    /// Formats date and time in Turkish medium format (e.g. "3 Kas 2026 14:30")
    public static func mediumDateShortTime(_ date: Date) -> String {
        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.mediumDateShortTimeFormatter.string(from: date)
    }

    /// Catchup start time format ("yyyy-MM-dd:HH-mm")
    public static func catchupTimeString(_ date: Date) -> String {
        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.catchupTimestampFormatter.string(from: date)
    }

    /// Parses HTTP retry-after date format ("EEE, dd MMM yyyy HH:mm:ss 'GMT'")
    public static func parseHTTPDate(_ value: String) -> Date? {
        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.httpDateFormatter.date(from: value)
    }

    /// ISO8601 string from Date
    public static func iso8601String(from date: Date) -> String {
        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.iso8601Formatter.string(from: date)
    }

    /// Parses ISO8601 string to Date
    public static func parseISO8601(_ value: String) -> Date? {
        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.iso8601Formatter.date(from: value)
    }

    /// Relative date string formatted in Turkish (e.g. "2 sa önce", "3 gün önce")
    public static func relativeDate(for date: Date, relativeTo: Date = Date()) -> String {
        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.relativeDateTimeFormatter.localizedString(for: date, relativeTo: relativeTo)
    }

    /// Formats file sizes using MB and GB units
    public static func formatFileSize(_ bytes: Int64) -> String {
        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.fileSizeFormatter.string(fromByteCount: max(0, bytes))
    }

    /// Formats download speeds in KB/s or MB/s
    public static func formatDownloadSpeed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond > 0 else { return "" }
        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }
        let clamped = Int64(min(bytesPerSecond, Double(Int64.max / 2)))
        return "\(storage.downloadSpeedFormatter.string(fromByteCount: clamped))/s"
    }

    /// Formats byte count with GB/MB preference
    public static func formatByteCountGeneral(_ bytes: Int64) -> String {
        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.generalByteCountFormatter.string(fromByteCount: max(0, bytes))
    }

    /// High-performance Xtream catalog release date parser
    public static func parseXtreamReleaseDate(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }

        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }

        if let date = storage.iso8601Formatter.date(from: value) {
            return date
        }

        for formatter in storage.xtreamReleaseDateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    /// High-performance EPG fallback date parser
    public static func parseEPGFallbackDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let ts = Double(trimmed), ts > 1_000_000_000, ts < 2_500_000_000 {
            return Date(timeIntervalSince1970: ts)
        }

        let storage = Storage.shared
        storage.lock.lock()
        defer { storage.lock.unlock() }

        for formatter in storage.epgFallbackFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }
}
