import Foundation
import SwiftData

@Model
public final class UserProfile {
    public var id: UUID = UUID()
    public var name: String = ""
    public var avatarIcon: String = "person.circle.fill"
    public var isKidsMode: Bool = false
    public var createdAt: Date = Date()

    public init(id: UUID = UUID(), name: String, avatarIcon: String = "person.circle.fill", isKidsMode: Bool = false) {
        self.id = id
        self.name = name
        self.avatarIcon = avatarIcon
        self.isKidsMode = isKidsMode
        createdAt = Date()
    }
}
