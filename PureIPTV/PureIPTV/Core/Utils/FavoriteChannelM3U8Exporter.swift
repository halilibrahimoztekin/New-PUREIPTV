import Foundation

public nonisolated struct FavoriteChannelM3U8Export: Equatable, Sendable {
    public let data: Data
    public let filename: String
    public let exportedChannelCount: Int
    public let skippedChannelCount: Int

    public init(
        data: Data,
        filename: String,
        exportedChannelCount: Int,
        skippedChannelCount: Int
    ) {
        self.data = data
        self.filename = filename
        self.exportedChannelCount = exportedChannelCount
        self.skippedChannelCount = skippedChannelCount
    }
}

public nonisolated enum FavoriteChannelM3U8Exporter {
    public static func makeExport(
        channels: [MediaModels.Item],
        categoryNames: [String: String],
        listName: String
    ) -> FavoriteChannelM3U8Export? {
        var lines = ["#EXTM3U"]
        var exportedCount = 0
        var skippedCount = 0

        for channel in channels {
            guard let streamURL = channel.streamURL,
                  !streamURL.absoluteString.isEmpty,
                  !streamURL.absoluteString.contains("\n"),
                  !streamURL.absoluteString.contains("\r")
            else {
                skippedCount += 1
                continue
            }

            var attributes: [String] = []
            appendAttribute("tvg-id", value: channel.epgChannelID, to: &attributes)
            appendAttribute("tvg-name", value: channel.title, to: &attributes)
            appendAttribute("tvg-logo", value: channel.displayLogoURL?.absoluteString, to: &attributes)
            appendAttribute("group-title", value: categoryNames[channel.categoryID], to: &attributes)

            let attributeText = attributes.isEmpty ? "" : " \(attributes.joined(separator: " "))"
            lines.append("#EXTINF:-1\(attributeText),\(cleanLine(channel.title))")
            lines.append(streamURL.absoluteString)
            exportedCount += 1
        }

        guard exportedCount > 0,
              let data = (lines.joined(separator: "\n") + "\n").data(using: .utf8)
        else { return nil }

        return FavoriteChannelM3U8Export(
            data: data,
            filename: filename(for: listName),
            exportedChannelCount: exportedCount,
            skippedChannelCount: skippedCount
        )
    }

    private static func appendAttribute(_ name: String, value: String?, to attributes: inout [String]) {
        guard let value else { return }
        let sanitizedValue = value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\"", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedValue.isEmpty else { return }
        attributes.append("\(name)=\"\(sanitizedValue)\"")
    }

    private static func cleanLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func filename(for listName: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let pieces = listName.unicodeScalars.split { !allowedCharacters.contains($0) }
        let baseName = pieces
            .map(String.init)
            .joined(separator: "-")
            .split(whereSeparator: { $0 == " " || $0 == "_" })
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        let boundedName = String((baseName.isEmpty ? "Favorites" : baseName).prefix(48))
        return "\(boundedName).m3u8"
    }
}
