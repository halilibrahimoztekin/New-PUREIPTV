import Foundation

public struct XtreamAuthResponseDTO: Codable {
    public let userInfo: UserInfo
    public let serverInfo: ServerInfo

    enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case serverInfo = "server_info"
    }

    public struct UserInfo: Codable {
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

        enum CodingKeys: String, CodingKey {
            case username, password, message, auth, status
            case expDate = "exp_date"
            case isTrial = "is_trial"
            case activeCons = "active_cons"
            case createdAt = "created_at"
            case maxConnections = "max_connections"
        }
    }

    public struct ServerInfo: Codable {
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
