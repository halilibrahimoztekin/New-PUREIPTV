import Foundation
import SwiftUI

// MARK: - Channel Category Filter Model

public enum ChannelCategoryFilter: Hashable, Sendable, Identifiable {
    case all
    case sports
    case news
    case cinema
    case documentaries
    case kids
    case ultraHD4K
    case music
    case history
    case custom(String)

    public var id: String {
        switch self {
        case .all: "all"
        case .sports: "sports"
        case .news: "news"
        case .cinema: "cinema"
        case .documentaries: "docs"
        case .kids: "kids"
        case .ultraHD4K: "4k"
        case .music: "music"
        case .history: "history"
        case let .custom(cat): "cat_\(cat)"
        }
    }

    public var title: String {
        switch self {
        case .all: AppStrings.LiveTV.allChannels
        case .sports: AppStrings.LiveTV.categorySports
        case .news: AppStrings.LiveTV.categoryNews
        case .cinema: AppStrings.LiveTV.categoryCinema
        case .documentaries: AppStrings.LiveTV.categoryDocs
        case .kids: AppStrings.LiveTV.categoryKids
        case .ultraHD4K: AppStrings.LiveTV.category4K
        case .music: AppStrings.LiveTV.categoryMusic
        case .history: AppStrings.LiveTV.recentChannels
        case let .custom(cat): cat
        }
    }

    public var icon: String {
        switch self {
        case .all: "tv"
        case .sports: "sportscourt.fill"
        case .news: "newspaper.fill"
        case .cinema: "popcorn.fill"
        case .documentaries: "globe.europe.africa.fill"
        case .kids: "teddybear.fill"
        case .ultraHD4K: "sparkles.tv.fill"
        case .music: "music.note"
        case .history: "clock.arrow.circlepath"
        case .custom: "folder.fill"
        }
    }

    public var accentColorHex: String {
        switch self {
        case .all: "#0A84FF" // System Blue
        case .sports: "#30D158" // Stadium Green
        case .news: "#FF453A" // Urgent Red
        case .cinema: "#BF5AF2" // Cinema Purple
        case .documentaries: "#FFD60A" // Geographic Gold
        case .kids: "#FF9F0A" // Playful Orange
        case .ultraHD4K: "#64D2FF" // Electric Cyan
        case .music: "#FF375F" // Music Pink
        case .history: "#5E5CE6" // Indigo
        case .custom: "#0A84FF" // Default Blue
        }
    }

    public var accentColor: Color {
        Color(hex: accentColorHex)
    }

    public func matches(title: String, categoryID: String?) -> Bool {
        let t = title.lowercased()
        let c = (categoryID ?? "").lowercased()

        switch self {
        case .all:
            return true

        case .history:
            return false // Handled directly via history array
        case .sports:
            let keywords = [
                "spor", "sport", "bein", "ssport", "s sport", "espn", "futbol", "football",
                "nba", "f1", "formula", "eurosport", "tivibu spor", "sky sport", "arena sport",
                "dazn", "match", "tennis", "ufc", "lig tv", "exxen", "trt spor", "aspor",
                "a spor", "sports",
            ]
            return keywords.contains { t.contains($0) || c.contains($0) }

        case .news:
            let keywords = [
                "haber", "news", "cnn", "bbc", "ntv", "a haber", "trt haber", "al jazeera",
                "bloomberg", "fox news", "sky news", "haberturk", "tgrt", "tv100", "tele1",
                "halk tv", "sozcu", "euronews", "dw", "cnnturk",
            ]
            return keywords.contains { t.contains($0) || c.contains($0) }

        case .cinema:
            let keywords = [
                "sinema", "cinema", "movie", "film", "dizi", "action", "drama", "comedy",
                "hbo", "showtime", "star cinema", "movies", "tivibu sinema", "tv+", "filmbox",
                "paramount", "beın movies", "cine",
            ]
            return keywords.contains { t.contains($0) || c.contains($0) }

        case .documentaries:
            let keywords = [
                "belgesel", "doc", "documentary", "discovery", "nat geo", "national geographic",
                "history", "animal planet", "tlc", "dmax", "viasat", "yaban", "habitat",
                "science", "investigation", "trt belgesel", "wild",
            ]
            return keywords.contains { t.contains($0) || c.contains($0) }

        case .kids:
            let keywords = [
                "çocuk", "cocuk", "kids", "cartoon", "disney", "nickelodeon", "minika",
                "baby", "animation", "boomerang", "cartoon network", "trt cocuk", "junior",
            ]
            return keywords.contains { t.contains($0) || c.contains($0) }

        case .ultraHD4K:
            let keywords = ["4k", "uhd", "ultra hd", "2160p", "4k hdr"]
            return keywords.contains { t.contains($0) || c.contains($0) }

        case .music:
            let keywords = [
                "müzik", "muzik", "music", "mtv", "kral", "power", "nrj", "trace",
                "vh1", "dream", "radio", "tvy", "number 1", "number1",
            ]
            return keywords.contains { t.contains($0) || c.contains($0) }

        case let .custom(cat):
            return categoryID == cat
        }
    }
}
