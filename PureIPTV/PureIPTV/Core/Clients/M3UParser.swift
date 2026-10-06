import Foundation

public struct M3UParsedResult: Sendable {
    public let items: [M3UItemDTO]
    public let epgURL: URL?
}

public struct M3UParser: Sendable {
    public init() {}

    /// Parses an M3U string into an array of `M3UItemDTO`s and optional EPG URL.
    public func parse(m3uString: String) -> M3UParsedResult {
        var items: [M3UItemDTO] = []
        var epgURL: URL? = nil

        let lines = m3uString.components(separatedBy: .newlines)

        var currentTvgID: String?
        var currentTvgName: String?
        var currentTvgLogo: String?
        var currentTvgType: String?
        var currentCatchup: String?
        var currentCatchupDays: Int?
        var currentGroupTitle: String?
        var currentTitle = "Unknown"

        // Compile regexes once for performance
        let attrRegex = try? NSRegularExpression(pattern: "([a-zA-Z0-9\\-]+)=\"([^\"]+)\"", options: [])
        let epgRegex = try? NSRegularExpression(pattern: "x-tvg-url=\"([^\"]+)\"", options: [])

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("#EXTM3U") {
                if let regex = epgRegex {
                    let nsString = trimmed as NSString
                    if let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length)) {
                        let urlString = nsString.substring(with: match.range(at: 1))
                        epgURL = URL(string: urlString)
                    }
                }
            } else if trimmed.hasPrefix("#EXTINF:") {
                // Reset metadata for the next item
                currentTvgID = nil
                currentTvgName = nil
                currentTvgLogo = nil
                currentTvgType = nil
                currentCatchup = nil
                currentCatchupDays = nil
                currentGroupTitle = nil

                // Parse attributes
                if let regex = attrRegex {
                    let nsString = trimmed as NSString
                    let results = regex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length))
                    for match in results {
                        let key = nsString.substring(with: match.range(at: 1)).lowercased()
                        let value = nsString.substring(with: match.range(at: 2))
                        switch key {
                        case "tvg-id": currentTvgID = value
                        case "tvg-name": currentTvgName = value
                        case "tvg-logo": currentTvgLogo = value
                        case "tvg-type": currentTvgType = value
                        case "group-title": currentGroupTitle = value
                        case "catchup": currentCatchup = value
                        case "catchup-days": currentCatchupDays = Int(value)
                        default: break
                        }
                    }
                }

                // Parse title (everything after the last comma)
                if let commaIndex = trimmed.lastIndex(of: ",") {
                    let titleSubstring = trimmed[trimmed.index(after: commaIndex)...]
                    currentTitle = titleSubstring.trimmingCharacters(in: .whitespaces)
                }
            } else if trimmed.hasPrefix("#EXTGRP:") {
                let group = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                currentGroupTitle = group
            } else if trimmed.hasPrefix("#EXTVLCOPT:") {
                // Ignore for now
            } else if !trimmed.hasPrefix("#") {
                // This should be the URL
                if let url = URL(string: trimmed) {
                    let item = M3UItemDTO(
                        title: currentTitle,
                        streamURL: url,
                        coverURL: currentTvgLogo.flatMap { URL(string: $0) },
                        groupTitle: currentGroupTitle ?? "Uncategorized",
                        tvgID: currentTvgID,
                        tvgName: currentTvgName,
                        tvgLogo: currentTvgLogo,
                        tvgType: currentTvgType,
                        catchup: currentCatchup,
                        catchupDays: currentCatchupDays
                    )
                    items.append(item)
                }

                // Title is reset, others are reset on next #EXTINF
                currentTitle = "Unknown"
            }
        }

        return M3UParsedResult(items: items, epgURL: epgURL)
    }
}
