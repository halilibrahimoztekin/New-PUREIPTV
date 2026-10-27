@preconcurrency import Foundation

public struct XtreamAuthResponseDTO: Codable, Sendable {
    public let userInfo: UserInfo
    public let serverInfo: ServerInfo

    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case serverInfo = "server_info"
    }

    public struct UserInfo: Codable, Sendable {
        public let username: String?
        public let password: String?
        public let message: String?
        public let auth: Int?
        public let status: String?
        public let expDate: String?
        public let isTrial: String?
        public let activeCons: String?
        public let createdAt: String?
        public let maxConnections: String?
        public let allowedOutputFormats: [String]?

        enum CodingKeys: String, CodingKey {
            case username, password, message, auth, status
            case expDate = "exp_date"
            case isTrial = "is_trial"
            case activeCons = "active_cons"
            case createdAt = "created_at"
            case maxConnections = "max_connections"
            case allowedOutputFormats = "allowed_output_formats"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            username = try container.decodeIfPresent(String.self, forKey: .username)
            password = try container.decodeIfPresent(String.self, forKey: .password)
            message = try container.decodeIfPresent(String.self, forKey: .message)
            auth = try container.decodeIfPresent(Int.self, forKey: .auth)
            status = try container.decodeIfPresent(String.self, forKey: .status)
            expDate = try container.decodeIfPresent(String.self, forKey: .expDate)
            isTrial = try container.decodeIfPresent(String.self, forKey: .isTrial)
            activeCons = try container.decodeIfPresent(String.self, forKey: .activeCons)
            createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            maxConnections = try container.decodeIfPresent(String.self, forKey: .maxConnections)
            allowedOutputFormats = try? container.decode([String].self, forKey: .allowedOutputFormats)
        }
    }

    public struct ServerInfo: Codable, Sendable {
        public let url: String?
        public let port: String?
        public let httpsPort: String?
        public let serverProtocol: String?
        public let rtmpPort: String?
        public let timezone: String?
        public let timestampNow: Int?
        public let timeNow: String?
        public let process: Bool?

        enum CodingKeys: String, CodingKey {
            case url, port
            case httpsPort = "https_port"
            case serverProtocol = "server_protocol"
            case rtmpPort = "rtmp_port"
            case timezone
            case timestampNow = "timestamp_now"
            case timeNow = "time_now"
            case process
        }
    }
}
