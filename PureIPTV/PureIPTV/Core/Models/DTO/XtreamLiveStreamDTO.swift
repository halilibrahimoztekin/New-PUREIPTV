import Foundation

public struct XtreamLiveStreamDTO: Codable {
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
}
