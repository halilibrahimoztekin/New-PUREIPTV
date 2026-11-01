import Foundation

public struct M3UParsedResult: Sendable {
    public let items: [M3UItemDTO]
    public let epgURL: URL?
}

public enum M3UParserError: LocalizedError, Equatable, Sendable {
    case playlistTooLarge
    case lineTooLarge
    case tooManyItems
    case invalidEncoding
    case missingHeader
    case emptyPlaylist

    public var errorDescription: String? {
        switch self {
        case .playlistTooLarge:
            "Playlist 128 MiB boyut sınırını aşıyor; mevcut katalog korundu."
        case .lineTooLarge:
            "Playlist içinde 1 MiB sınırını aşan tek bir satır var; mevcut katalog korundu."
        case .tooManyItems:
            "Playlist 200.000 kayıt sınırını aşıyor; mevcut katalog korundu."
        case .invalidEncoding:
            "Playlist geçerli UTF-8 metni değil; mevcut katalog korundu."
        case .missingHeader:
            "Playlist M3U başlığı içermiyor; mevcut katalog korundu."
        case .emptyPlaylist:
            "Playlist boş veya okunamıyor; mevcut katalog korundu."
        }
    }
}

private struct M3UParsedState {
    private(set) var items: [M3UItemDTO] = []
    private(set) var epgURL: URL?

    private var currentTvgID: String?
    private var currentTvgName: String?
    private var currentOriginalLanguageCode: String?
    private var currentTvgLogo: String?
    private var currentTvgType: String?
    private var currentCatchup: String?
    private var currentCatchupDays: Int?
    private var currentGroupTitle: String?
    private var currentTitle = "Unknown"

    private let attrRegex = try? NSRegularExpression(pattern: "([a-zA-Z0-9\\-]+)=\"([^\"]+)\"", options: [])
    private let epgRegex = try? NSRegularExpression(
        pattern: #"(?:x-tvg-url|url-tvg)\s*=\s*"([^"]+)""#,
        options: [.caseInsensitive]
    )

    mutating func consume(_ line: String, maximumItemCount: Int? = nil) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }

        if trimmed.hasPrefix("#EXTM3U") {
            if let regex = epgRegex {
                let nsString = trimmed as NSString
                if let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length)) {
                    let urlString = nsString.substring(with: match.range(at: 1))
                    epgURL = URL(string: urlString)
                }
            }
        } else if trimmed.hasPrefix("#EXTINF:") {
            currentTvgID = nil
            currentTvgName = nil
            currentOriginalLanguageCode = nil
            currentTvgLogo = nil
            currentTvgType = nil
            currentCatchup = nil
            currentCatchupDays = nil
            currentGroupTitle = nil

            if let regex = attrRegex {
                let nsString = trimmed as NSString
                let results = regex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length))
                for match in results {
                    let key = nsString.substring(with: match.range(at: 1)).lowercased()
                    let value = nsString.substring(with: match.range(at: 2))
                    switch key {
                    case "tvg-id": currentTvgID = value
                    case "tvg-name": currentTvgName = value
                    case "tvg-language": currentOriginalLanguageCode = value
                    case "tvg-logo": currentTvgLogo = value
                    case "tvg-type": currentTvgType = value
                    case "group-title": currentGroupTitle = value
                    case "catchup": currentCatchup = value
                    case "catchup-days": currentCatchupDays = Int(value)
                    default: break
                    }
                }
            }

            if let commaIndex = trimmed.lastIndex(of: ",") {
                currentTitle = trimmed[trimmed.index(after: commaIndex)...].trimmingCharacters(in: .whitespaces)
            }
        } else if trimmed.hasPrefix("#EXTGRP:") {
            currentGroupTitle = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
        } else if trimmed.hasPrefix("#EXTVLCOPT:") {
            // Ignore for now.
        } else if !trimmed.hasPrefix("#"), let url = URL(string: trimmed) {
            guard maximumItemCount.map({ items.count < $0 }) ?? true else { return false }
            let processed = SmartChannelProcessingEngine.process(
                rawTitle: currentTitle,
                groupTitle: currentGroupTitle
            )
            let item = M3UItemDTO(
                title: processed.cleanTitle,
                streamURL: url,
                coverURL: currentTvgLogo.flatMap { URL(string: $0) },
                groupTitle: processed.inferredCategory,
                sourceGroupTitle: currentGroupTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                tvgID: currentTvgID,
                tvgName: currentTvgName,
                originalLanguageSourceValue: currentOriginalLanguageCode,
                tvgLogo: currentTvgLogo,
                tvgType: currentTvgType,
                catchup: currentCatchup,
                catchupDays: currentCatchupDays
            )
            items.append(item)
            currentTitle = "Unknown"
        }

        return true
    }

    var result: M3UParsedResult {
        M3UParsedResult(items: items, epgURL: epgURL)
    }
}

public struct M3UParser: Sendable {
    public init() {}

    /// Parses an M3U string without materializing a second array containing every line.
    public func parse(m3uString: String) -> M3UParsedResult {
        let normalizedString = m3uString.first == "\u{FEFF}" ? String(m3uString.dropFirst()) : m3uString
        var state = M3UParsedState()
        normalizedString.enumerateLines { line, _ in
            _ = state.consume(line)
        }
        return state.result
    }
}

public enum M3UStreamingProgress: Equatable, Sendable {
    case indeterminate
    case percentage(Int)
}

/// Incrementally parses UTF-8 M3U bytes while retaining only the current line and parsed catalog.
public actor M3UIncrementalParser {
    public static let maximumPlaylistBytes = 128 * 1024 * 1024
    private static let maximumLineBytes = 1 * 1024 * 1024
    private static let maximumItemCount = 200_000

    private var state = M3UParsedState()
    private var pendingLine: [UInt8] = []
    private var receivedBytes = 0
    private var expectedHeaderFound = false
    private var isFirstLine = true
    private var isFinished = false
    private var lastProgressBucket = -1
    private var reportedIndeterminateProgress = false

    public init() {
        pendingLine.reserveCapacity(1024)
    }

    public func append(_ chunk: Data, expectedByteCount: Int64?) throws -> M3UStreamingProgress? {
        guard !isFinished else { throw M3UParserError.missingHeader }
        guard chunk.count <= Self.maximumPlaylistBytes - receivedBytes else {
            throw M3UParserError.playlistTooLarge
        }
        receivedBytes += chunk.count

        for byte in chunk {
            if byte == 0x0A || byte == 0x0D {
                try processPendingLine()
                pendingLine.removeAll(keepingCapacity: true)
            } else {
                guard pendingLine.count < Self.maximumLineBytes else {
                    throw M3UParserError.lineTooLarge
                }
                pendingLine.append(byte)
            }
        }
        try Task.checkCancellation()

        if let expectedByteCount, expectedByteCount > 0 {
            let fraction = min(Double(receivedBytes) / Double(expectedByteCount), 0.99)
            let bucket = Int(fraction * 100) / 5 * 5
            guard bucket > lastProgressBucket else { return nil }
            lastProgressBucket = bucket
            return .percentage(bucket)
        }

        guard !reportedIndeterminateProgress else { return nil }
        reportedIndeterminateProgress = true
        return .indeterminate
    }

    public func finish() throws -> M3UParsedResult {
        guard !isFinished else { throw M3UParserError.missingHeader }
        if !pendingLine.isEmpty {
            try processPendingLine()
            pendingLine.removeAll(keepingCapacity: false)
        }
        isFinished = true
        try Task.checkCancellation()
        guard expectedHeaderFound else { throw M3UParserError.missingHeader }
        guard !state.items.isEmpty else { throw M3UParserError.emptyPlaylist }
        return state.result
    }

    private func processPendingLine() throws {
        var bytes = pendingLine
        if isFirstLine {
            isFirstLine = false
            if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
                bytes.removeFirst(3)
            }
        }
        guard let line = String(bytes: bytes, encoding: .utf8) else {
            throw M3UParserError.invalidEncoding
        }

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#EXTM3U") {
            let suffix = trimmed.dropFirst("#EXTM3U".count)
            if suffix.isEmpty || suffix.first?.isWhitespace == true {
                expectedHeaderFound = true
            }
        }
        guard state.consume(line, maximumItemCount: Self.maximumItemCount) else {
            throw M3UParserError.tooManyItems
        }
    }
}
