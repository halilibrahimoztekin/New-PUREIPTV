import Foundation

public struct M3UStreamingParserResult: Sendable {
    public let items: [MediaModels.Item]
    public let epgURL: URL?

    public init(items: [MediaModels.Item], epgURL: URL?) {
        self.items = items
        self.epgURL = epgURL
    }
}

public actor M3UStreamingParser {
    public static let shared = M3UStreamingParser()

    private init() {}

    /// Parses large M3U files (100,000+ lines) via AsyncSequence line-by-line without loading the entire file into RAM.
    public func parseStreaming(
        fileURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> M3UStreamingParserResult {
        var items: [MediaModels.Item] = []
        var detectedEPGURL: URL?

        // Estimate line count for progress calculation if file size is accessible
        let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 10_000_000
        var bytesProcessed = 0

        var currentTitle = ""
        var currentLogo: String?
        var currentGroup = "Genel"
        var currentTvgID: String?
        var currentTvgArchive = 0

        var lineIndex = 0

        for try await line in fileURL.lines {
            lineIndex += 1
            bytesProcessed += line.utf8.count + 1

            if lineIndex % 1000 == 0, fileSize > 0 {
                let fraction = min(1.0, max(0.0, Double(bytesProcessed) / Double(fileSize)))
                onProgress?(fraction)
            }

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("#EXTM3U") {
                if let urlRange = trimmed.range(of: "url-tvg=\""),
                   let endQuote = trimmed[urlRange.upperBound...].firstIndex(of: "\"")
                {
                    let epgStr = String(trimmed[urlRange.upperBound ..< endQuote])
                    detectedEPGURL = URL(string: epgStr)
                }
                continue
            }

            if trimmed.hasPrefix("#EXTINF:") {
                // Parse attributes
                currentTitle = extractTag(from: trimmed, key: ",") ?? "Kanal \(items.count + 1)"
                currentLogo = extractAttribute(from: trimmed, key: "tvg-logo")
                currentGroup = extractAttribute(from: trimmed, key: "group-title") ?? "Genel"
                currentTvgID = extractAttribute(from: trimmed, key: "tvg-id")
                if let archStr = extractAttribute(from: trimmed, key: "tvg-archive"), let arch = Int(archStr) {
                    currentTvgArchive = arch
                } else {
                    currentTvgArchive = 0
                }
            } else if !trimmed.hasPrefix("#") {
                // Stream URL
                if let url = URL(string: trimmed) {
                    let item = MediaModels.Item(
                        id: "\(items.count)_\(currentTvgID ?? UUID().uuidString)",
                        title: currentTitle,
                        streamURL: url,
                        coverURL: currentLogo.flatMap { URL(string: $0) },
                        categoryID: currentGroup,
                        type: .live,
                        epgChannelID: currentTvgID,
                        tvArchive: currentTvgArchive
                    )
                    items.append(item)
                }
                // Reset temporary fields
                currentTitle = ""
                currentLogo = nil
                currentGroup = "Genel"
                currentTvgID = nil
                currentTvgArchive = 0
            }
        }

        onProgress?(1.0)
        return M3UStreamingParserResult(items: items, epgURL: detectedEPGURL)
    }

    private func extractAttribute(from line: String, key: String) -> String? {
        guard let range = line.range(of: "\(key)=\"") else { return nil }
        let sub = line[range.upperBound...]
        guard let quoteIndex = sub.firstIndex(of: "\"") else { return nil }
        return String(sub[..<quoteIndex])
    }

    private func extractTag(from line: String, key _: String) -> String? {
        guard let commaIndex = line.lastIndex(of: ",") else { return nil }
        let title = String(line[line.index(after: commaIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }
}
