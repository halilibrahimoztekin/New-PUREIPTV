import Foundation
import SwiftUI

public enum HomeSectionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case continueWatching
    case favorites
    case sportsHub
    case recentlyAddedVOD
    case trendingSeries

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .continueWatching: "İzlemeye Devam Et"
        case .favorites: "Favorilerim"
        case .sportsHub: "Günün Maçları (Sports Hub)"
        case .recentlyAddedVOD: "Yeni Eklenen Filmler"
        case .trendingSeries: "Popüler Diziler"
        }
    }

    public var icon: String {
        switch self {
        case .continueWatching: "play.circle.fill"
        case .favorites: "star.fill"
        case .sportsHub: "sportscourt.fill"
        case .recentlyAddedVOD: "film.stack.fill"
        case .trendingSeries: "tv.fill"
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
        HomeSectionConfig(type: .continueWatching, isVisible: true),
        HomeSectionConfig(type: .favorites, isVisible: true),
        HomeSectionConfig(type: .sportsHub, isVisible: true),
        HomeSectionConfig(type: .recentlyAddedVOD, isVisible: true),
        HomeSectionConfig(type: .trendingSeries, isVisible: true),
    ]

    public func loadSections() {
        if let data = userDefaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([HomeSectionConfig].self, from: data)
        {
            sections = saved
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
