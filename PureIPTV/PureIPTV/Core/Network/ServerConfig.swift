import Foundation

public struct ServerConfig: Equatable {
    public let baseURL: URL
    public let username: String
    public let password: String

    public init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
    }
}
