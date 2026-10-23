import Foundation

public struct XtreamLiveStreamDTO: Codable, Sendable {
    public let num: Int?
    public let name: String
    public let streamType: String?
    public let streamId: Int
    public let streamIcon: String?
    public let epgChannelId: String?
    public let added: String?
    public let categoryId: String
    public let customSid: String?
    public let tvArchive: Int?
    public let directSource: String?
    public let tvArchiveDuration: Int?

    enum CodingKeys: String, CodingKey {
        case num
        case name
        case streamType = "stream_type"
        case streamId = "stream_id"
        case streamIcon = "stream_icon"
        case epgChannelId = "epg_channel_id"
        case added
        case categoryId = "category_id"
        case customSid = "custom_sid"
        case tvArchive = "tv_archive"
        case directSource = "direct_source"
        case tvArchiveDuration = "tv_archive_duration"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        num = try container.decodeIfPresent(Int.self, forKey: .num)
        name = try container.decode(String.self, forKey: .name)
        streamType = try container.decodeIfPresent(String.self, forKey: .streamType)
        streamId = try container.decode(Int.self, forKey: .streamId)
        streamIcon = try container.decodeIfPresent(String.self, forKey: .streamIcon)
        epgChannelId = try container.decodeIfPresent(String.self, forKey: .epgChannelId)
        added = try container.decodeIfPresent(String.self, forKey: .added)
        categoryId = try XtreamDTOValueDecoder.categoryID(from: container, forKey: .categoryId)
        customSid = try container.decodeIfPresent(String.self, forKey: .customSid)
        tvArchive = try container.decodeIfPresent(Int.self, forKey: .tvArchive)
        directSource = try container.decodeIfPresent(String.self, forKey: .directSource)
        tvArchiveDuration = try container.decodeIfPresent(Int.self, forKey: .tvArchiveDuration)
    }
}
