import Foundation

/// Represents a distinct quality and audio edition of a movie in the catalog (Madde #47).
public struct MovieVersionEdition: Equatable, Identifiable, Sendable {
    public let item: MediaModels.Item
    public let qualityLabel: String
    public let editionLabel: String
    public let fullBadge: String
    public let isCurrent: Bool

    public var id: String {
        item.id
    }

    public init(item: MediaModels.Item, isCurrent: Bool = false) {
        self.item = item
        self.isCurrent = isCurrent

        let parsedQuality = Self.detectQuality(from: item.title)
        let parsedEdition = Self.detectEdition(from: item.title)

        qualityLabel = parsedQuality
        editionLabel = parsedEdition

        if !parsedEdition.isEmpty, parsedEdition != "Standart" {
            fullBadge = "\(parsedQuality) • \(parsedEdition)"
        } else {
            fullBadge = parsedQuality
        }
    }

    // MARK: - Parser Helpers

    public static func detectQuality(from title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("4k") || lower.contains("uhd") || lower.contains("2160p") {
            return "4K UHD"
        } else if lower.contains("1080p") || lower.contains("fhd") || lower.contains("bluray") || lower.contains("blu-ray") {
            return "1080p FHD"
        } else if lower.contains("720p") || lower.contains("hd") {
            return "720p HD"
        } else if lower.contains("480p") || lower.contains("sd") || lower.contains("dvdrip") {
            return "SD"
        }
        return "HD"
    }

    public static func detectEdition(from title: String) -> String {
        let lower = title.lowercased()
        var editions: [String] = []

        if lower.contains("imax") {
            editions.append("IMAX")
        }
        if lower.contains("extended") || lower.contains("director") {
            editions.append("Extended")
        }
        if lower.contains("dual") || lower.contains("tr-en") || lower.contains("tr/en") {
            editions.append("Dual Audio")
        } else if lower.contains("dublaj") || lower.contains("turkce dublaj") || lower.contains("türkçe dublaj") {
            editions.append("Türkçe Dublaj")
        } else if lower.contains("altyazi") || lower.contains("altyazılı") || lower.contains("sub") {
            editions.append("Altyazılı")
        } else if lower.contains("orijinal") || lower.contains("original") {
            editions.append("Orijinal Dil")
        }

        return editions.isEmpty ? "Standart" : editions.joined(separator: " • ")
    }
}
