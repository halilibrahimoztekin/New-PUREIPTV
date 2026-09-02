import Foundation

public struct EPGResponseDTO: Codable, Sendable {
    public let epgListings: [EPGItemDTO]

    enum CodingKeys: String, CodingKey {
        case epgListings = "epg_listings"
    }

    public init(epgListings: [EPGItemDTO]) {
        self.epgListings = epgListings
    }
}

public struct EPGItemDTO: Codable, Sendable {
    public var id: String
    public var epgId: String
    public var title: String
    public var lang: String
    public var start: String
    public var end: String
    public var description: String
    public var channelId: String
    public var startTimestamp: Int?
    public var stopTimestamp: Int?
    public var stopV: String?
    public var nowPlaying: Int?
    public var hasArchive: Int?

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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        func decodeString(forKey key: CodingKeys) -> String {
            if let str = try? container.decode(String.self, forKey: key) {
                return str
            }
            if let intVal = try? container.decode(Int.self, forKey: key) {
                return String(intVal)
            }
            return ""
        }

        func decodeInt(forKey key: CodingKeys) -> Int? {
            if let intVal = try? container.decodeIfPresent(Int.self, forKey: key) {
                return intVal
            }
            if let strVal = try? container.decodeIfPresent(String.self, forKey: key), let intVal = Int(strVal) {
                return intVal
            }
            return nil
        }

        id = decodeString(forKey: .id)
        epgId = decodeString(forKey: .epgId)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        lang = decodeString(forKey: .lang)
        start = try container.decodeIfPresent(String.self, forKey: .start) ?? ""
        end = try container.decodeIfPresent(String.self, forKey: .end) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        channelId = decodeString(forKey: .channelId)
        stopV = try? container.decodeIfPresent(String.self, forKey: .stopV)

        startTimestamp = decodeInt(forKey: .startTimestamp)
        stopTimestamp = decodeInt(forKey: .stopTimestamp)
        nowPlaying = decodeInt(forKey: .nowPlaying)
        hasArchive = decodeInt(forKey: .hasArchive)
    }
}
