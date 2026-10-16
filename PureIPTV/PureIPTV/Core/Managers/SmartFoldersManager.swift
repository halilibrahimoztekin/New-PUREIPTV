import Foundation

public struct SmartFolderRule: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var icon: String
    public var keywords: [String]
    public var isEnabled: Bool

    public init(id: String = UUID().uuidString, name: String, icon: String, keywords: [String], isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.icon = icon
        self.keywords = keywords
        self.isEnabled = isEnabled
    }

    public func matches(title: String) -> Bool {
        guard isEnabled, !keywords.isEmpty else { return false }
        let lowerTitle = title.lowercased()
        return keywords.contains { keyword in
            lowerTitle.contains(keyword.lowercased())
        }
    }
}

public final class SmartFoldersManager: @unchecked Sendable {
    public static let shared = SmartFoldersManager()

    private let storageKey = "pureiptv_smart_folders"
    private let userDefaults: UserDefaults

    public private(set) var folders: [SmartFolderRule] = []

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadFolders()
    }

    public static let defaultFolders: [SmartFolderRule] = [
        SmartFolderRule(id: "smart_4k", name: "4K / Ultra HD", icon: "4k.tv.fill", keywords: ["4k", "uhd"]),
        SmartFolderRule(id: "smart_fhd", name: "Full HD (1080p)", icon: "tv.fill", keywords: ["fhd", "1080p"]),
        SmartFolderRule(id: "smart_sports", name: "Spor Kanalları", icon: "sportscourt.fill", keywords: ["spor", "sport", "bein", "ssport", "tivibu"]),
        SmartFolderRule(id: "smart_news", name: "Haber Kanalları", icon: "newspaper.fill", keywords: ["haber", "news", "cnn", "ntv", "trthaber"]),
        SmartFolderRule(id: "smart_cinema", name: "Sinema & Film", icon: "film.fill", keywords: ["sinema", "cinema", "movie", "film"]),
    ]

    public func loadFolders() {
        if let data = userDefaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([SmartFolderRule].self, from: data)
        {
            folders = saved
        } else {
            folders = Self.defaultFolders
            saveFolders()
        }
    }

    public func saveFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    public func addFolder(name: String, icon: String, keywords: [String]) {
        let newFolder = SmartFolderRule(name: name, icon: icon, keywords: keywords)
        folders.append(newFolder)
        saveFolders()
    }

    public func removeFolder(id: String) {
        folders.removeAll { $0.id == id }
        saveFolders()
    }

    public func toggleFolder(id: String) {
        if let index = folders.firstIndex(where: { $0.id == id }) {
            folders[index].isEnabled.toggle()
            saveFolders()
        }
    }

    /// Evaluates which items match a given smart folder rule
    public func filter(items: [MediaModels.Item], for folder: SmartFolderRule) -> [MediaModels.Item] {
        items.filter { folder.matches(title: $0.title) }
    }
}
