import Foundation

public struct CustomFavoriteGroup: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var icon: String
    public var channelIDs: Set<String>

    public init(id: String = UUID().uuidString, name: String, icon: String = "star.fill", channelIDs: Set<String> = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.channelIDs = channelIDs
    }
}

public final class CustomFavoriteGroupsManager: @unchecked Sendable {
    public static let shared = CustomFavoriteGroupsManager()

    private let storageKey = "pureiptv_custom_favorite_groups"
    private let userDefaults: UserDefaults

    public private(set) var groups: [CustomFavoriteGroup] = []

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadGroups()
    }

    public static let defaultGroups: [CustomFavoriteGroup] = [
        CustomFavoriteGroup(id: "group_sports", name: "Spor Favorilerim", icon: "sportscourt.fill"),
        CustomFavoriteGroup(id: "group_docs", name: "Belgesel & Doğa", icon: "globe.europe.africa.fill"),
        CustomFavoriteGroup(id: "group_family", name: "Aile & Çocuk", icon: "heart.fill"),
    ]

    public func loadGroups() {
        if let data = userDefaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([CustomFavoriteGroup].self, from: data)
        {
            groups = saved
        } else {
            groups = Self.defaultGroups
            saveGroups()
        }
    }

    public func saveGroups() {
        if let data = try? JSONEncoder().encode(groups) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    public func createGroup(name: String, icon: String = "folder.fill") {
        let group = CustomFavoriteGroup(name: name, icon: icon)
        groups.append(group)
        saveGroups()
    }

    public func deleteGroup(id: String) {
        groups.removeAll { $0.id == id }
        saveGroups()
    }

    public func toggleChannel(channelID: String, inGroupID groupID: String) {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        if groups[idx].channelIDs.contains(channelID) {
            groups[idx].channelIDs.remove(channelID)
        } else {
            groups[idx].channelIDs.insert(channelID)
        }
        saveGroups()
    }

    public func isChannel(channelID: String, inGroupID groupID: String) -> Bool {
        guard let group = groups.first(where: { $0.id == groupID }) else { return false }
        return group.channelIDs.contains(channelID)
    }

    public func groupsContaining(channelID: String) -> [CustomFavoriteGroup] {
        groups.filter { $0.channelIDs.contains(channelID) }
    }
}
