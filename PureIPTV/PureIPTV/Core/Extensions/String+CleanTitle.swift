import Foundation

public extension String {
    /// Cleans IPTV VOD/Series titles from common tags, resolutions, and years.
    /// E.g. "TR | 180 (2026)" -> "180"
    /// E.g. "FHD - Inception 1080p" -> "Inception"
    func cleanedForTMDBSearch() -> String {
        var text = self

        // 1. Remove common prefixes like "TR |", "EN -", "FHD", "4K", etc.
        let prefixesToRemove = ["TR |", "TR|", "EN |", "EN|", "FHD -", "FHD", "4K -", "4K", "HD -", "HD", "SD -", "SD"]
        for prefix in prefixesToRemove {
            if text.uppercased().hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
            }
        }

        // 2. Remove resolutions, encodings and common tags
        let tagsToRemove = [
            "(1080p)", "1080p", "1080", "(720p)", "720p", "720", "(4K)", "4K", "2160p",
            "x264", "x265", "HEVC", "BluRay", "BDRip", "BRRip", "HDRip", "WEB-DL",
            "WEBRip", "HDTV", "PDTV", "VOD", "(VOD)",
        ]

        for tag in tagsToRemove {
            // Case insensitive replacement
            text = text.replacingOccurrences(of: tag, with: "", options: .caseInsensitive)
        }

        // 3. Remove Year in parentheses like "(2023)" or standalone year at the end " 2023"
        // Use regex for this
        if let regex = try? NSRegularExpression(pattern: "\\s*\\(?\\b(19|20)\\d{2}\\b\\)?\\s*", options: .caseInsensitive) {
            text = regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.count), withTemplate: " ")
        }

        // 4. Clean up remaining garbage characters
        let charsToRemove: [Character] = ["|", "-", "_", "[", "]", "(", ")", "{", "}"]
        text = String(text.filter { !charsToRemove.contains($0) })

        // 5. Trim whitespaces and multiple spaces
        text = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return text
    }
}
