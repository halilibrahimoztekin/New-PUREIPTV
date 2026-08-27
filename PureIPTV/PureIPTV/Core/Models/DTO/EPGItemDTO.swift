import Foundation

public struct EPGResponseDTO: Codable {
    public let epgListings: [EPGItemDTO]

    enum CodingKeys: String, CodingKey {
        case epgListings = "epg_listings"
    }
}

public struct EPGItemDTO: Codable {
    public let id: String
    public let epgId: String
    public let title: String
    public let lang: String
    public let start: String
    public let end: String
    public let description: String
    public let channelId: String
    public let startTimestamp: Int?
    public let stopTimestamp: Int?
    public let stopV: String?
    public let nowPlaying: Int?
    public let hasArchive: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case epgId = "epg_id"
        case title
        case lang
        case start
        case end
        case description
        case channelId = "channel_id"
        case startTimestamp = "start_timestamp"
        case stopTimestamp = "stop_timestamp"
        case stopV = "stop_v"
        case nowPlaying = "now_playing"
        case hasArchive = "has_archive"
    }
}
