import Foundation
import SwiftUI

public enum HomeSectionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case hero
    case continueWatching
    case favorites
    case featuredLiveTV
    case sportsHub
    case recommendations
    case recentlyAddedVOD
    case trendingSeries
    case discoverCollections

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .hero: "Öne Çıkan İçerik"
        case .continueWatching: "İzlemeye Devam Et"
        case .favorites: "Favorilerim"
        case .featuredLiveTV: "Öne Çıkan Canlı TV"
        case .sportsHub: "Günün Maçları (Sports Hub)"
        case .recommendations: "Sana Özel Öneriler"
        case .recentlyAddedVOD: "Yeni Eklenen Filmler"
        case .trendingSeries: "Popüler Diziler"
        case .discoverCollections: "Keşfet".localized
        }
    }

    public var icon: String {
        switch self {
        case .hero: "sparkles.rectangle.stack.fill"
        case .continueWatching: "play.circle.fill"
        case .favorites: "star.fill"
        case .featuredLiveTV: "tv.fill"
        case .sportsHub: "sportscourt.fill"
        case .recommendations: "wand.and.stars"
        case .recentlyAddedVOD: "film.stack.fill"
        case .trendingSeries: "tv.fill"
        case .discoverCollections: "square.grid.2x2.fill"
        }
    }
}

public struct HomeSectionConfig: Identifiable, Codable, Equatable, Sendable {
    public let type: HomeSectionType
    public var isVisible: Bool

    public var id: String {
        type.rawValue
    }

    public init(type: HomeSectionType, isVisible: Bool = true) {
        self.type = type
        self.isVisible = isVisible
    }
}

public final class HomeSectionManager: @unchecked Sendable {
    public static let shared = HomeSectionManager()

    private let storageKey = "pureiptv_home_sections_v1"
    private let userDefaults: UserDefaults

    public private(set) var sections: [HomeSectionConfig] = []

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadSections()
    }

    public static let defaultSections: [HomeSectionConfig] = [
        HomeSectionConfig(type: .hero, isVisible: true),
        HomeSectionConfig(type: .continueWatching, isVisible: true),
        HomeSectionConfig(type: .favorites, isVisible: true),
        HomeSectionConfig(type: .featuredLiveTV, isVisible: true),
        HomeSectionConfig(type: .sportsHub, isVisible: true),
        HomeSectionConfig(type: .recommendations, isVisible: true),
        HomeSectionConfig(type: .recentlyAddedVOD, isVisible: true),
        HomeSectionConfig(type: .trendingSeries, isVisible: true),
        HomeSectionConfig(type: .discoverCollections, isVisible: true),
    ]

    public func loadSections() {
        if let data = userDefaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([HomeSectionConfig].self, from: data)
        {
            var migrated = saved.reduce(into: [HomeSectionConfig]()) { result, section in
                guard !result.contains(where: { $0.type == section.type }) else { return }
                result.append(section)
            }
            for (defaultIndex, section) in Self.defaultSections.enumerated()
                where !migrated.contains(where: { $0.type == section.type })
            {
                let nextDefaultTypes = Self.defaultSections.dropFirst(defaultIndex + 1).map(\.type)
                let insertionIndex = migrated.firstIndex { nextDefaultTypes.contains($0.type) } ?? migrated.endIndex
                migrated.insert(section, at: insertionIndex)
            }
            sections = migrated
            if migrated != saved {
                saveSections()
            }
        } else {
            sections = Self.defaultSections
            saveSections()
        }
    }

    public func saveSections() {
        if let data = try? JSONEncoder().encode(sections) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    public func toggleSection(type: HomeSectionType) {
        if let idx = sections.firstIndex(where: { $0.type == type }) {
            sections[idx].isVisible.toggle()
            saveSections()
        }
    }

    public func move(from source: IndexSet, to destination: Int) {
        sections.move(fromOffsets: source, toOffset: destination)
        saveSections()
    }

    public func resetToDefault() {
        sections = Self.defaultSections
        saveSections()
    }
}
