import Foundation

public struct XtreamCategoryDTO: Codable, Sendable {
    public let categoryId: String
    public let categoryName: String
    public let parentId: Int?

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
        case parentId = "parent_id"
    }
}
