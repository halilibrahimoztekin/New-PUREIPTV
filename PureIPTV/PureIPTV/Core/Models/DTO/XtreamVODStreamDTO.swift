import Foundation

public struct XtreamVODStreamDTO: Codable, Sendable {
    public let num: Int?
    public let name: String
    public let streamType: String?
    public let streamId: Int
    public let streamIcon: String?
    public let rating: Double?
    public let rating5based: Double?
    public let added: String?
    public let categoryId: String
    public let containerExtension: String?
    public let customSid: String?
    public let directSource: String?

    enum CodingKeys: String, CodingKey {
        case num
        case name
        case streamType = "stream_type"
        case streamId = "stream_id"
        case streamIcon = "stream_icon"
        case rating
        case rating5based = "rating_5based"
        case added
        case categoryId = "category_id"
        case containerExtension = "container_extension"
        case customSid = "custom_sid"
        case directSource = "direct_source"
    }
}
