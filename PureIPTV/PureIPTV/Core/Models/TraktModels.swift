import Foundation

// MARK: - Trakt Device Code (OAuth 2.0 Device Flow)

public struct TraktDeviceCode: Codable, Equatable, Sendable {
    public let deviceCode: String
    public let userCode: String
    public let verificationURL: String
    public let expiresIn: Int
    public let interval: Int
    public let requestedAt: Date

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURL = "verification_url"
        case expiresIn = "expires_in"
        case interval
    }

    public nonisolated init(
        deviceCode: String,
        userCode: String,
        verificationURL: String,
        expiresIn: Int,
        interval: Int,
        requestedAt: Date = Date()
    ) {
        self.deviceCode = deviceCode
        self.userCode = userCode
        self.verificationURL = verificationURL
        self.expiresIn = expiresIn
        self.interval = interval
        self.requestedAt = requestedAt
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceCode = try container.decode(String.self, forKey: .deviceCode)
        userCode = try container.decode(String.self, forKey: .userCode)
        verificationURL = try container.decode(String.self, forKey: .verificationURL)
        expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        interval = try container.decode(Int.self, forKey: .interval)
        requestedAt = Date()
    }
}

// MARK: - Trakt Token Response

public struct TraktTokenResponse: Codable, Equatable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let refreshToken: String
    public let scope: String?
    public let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case createdAt = "created_at"
    }

    public nonisolated init(
        accessToken: String,
        tokenType: String,
        expiresIn: Int,
        refreshToken: String,
        scope: String? = nil,
        createdAt: Int = Int(Date().timeIntervalSince1970)
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.scope = scope
        self.createdAt = createdAt
    }
}

// MARK: - Trakt User Profile

public struct TraktUser: Codable, Equatable, Sendable {
    public let username: String
    public let name: String?
    public let isVIP: Bool
    public let avatarURL: String?

    public nonisolated init(username: String, name: String? = nil, isVIP: Bool = false, avatarURL: String? = nil) {
        self.username = username
        self.name = name
        self.isVIP = isVIP
        self.avatarURL = avatarURL
    }
}

// MARK: - Trakt Scrobble Payload

public struct TraktScrobblePayload: Codable, Equatable, Sendable {
    public let title: String
    public let year: Int?
    public let season: Int?
    public let episode: Int?
    public let progress: Double // 0.0 to 100.0
    public let isEpisode: Bool
    public let tmdbID: Int?

    public nonisolated init(
        title: String,
        year: Int? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        progress: Double,
        isEpisode: Bool = false,
        tmdbID: Int? = nil
    ) {
        self.title = title
        self.year = year
        self.season = season
        self.episode = episode
        self.progress = progress
        self.isEpisode = isEpisode
        self.tmdbID = tmdbID
    }
}

// MARK: - Trakt Scrobble Response

public struct TraktScrobbleResponse: Codable, Equatable, Sendable {
    public let action: String // "start", "pause", "scrobble"
    public let progress: Double

    public nonisolated init(action: String, progress: Double) {
        self.action = action
        self.progress = progress
    }
}

// MARK: - Trakt Watchlist Item

public struct TraktWatchlistItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String {
        "\(type)_\(traktID)"
    }

    public let traktID: Int
    public let title: String
    public let year: Int?
    public let type: String // "movie" or "show"
    public let overview: String?
    public let tmdbID: Int?
    public let imdbID: String?
    public let listedAt: Date?

    public nonisolated init(
        traktID: Int,
        title: String,
        year: Int? = nil,
        type: String,
        overview: String? = nil,
        tmdbID: Int? = nil,
        imdbID: String? = nil,
        listedAt: Date? = nil
    ) {
        self.traktID = traktID
        self.title = title
        self.year = year
        self.type = type
        self.overview = overview
        self.tmdbID = tmdbID
        self.imdbID = imdbID
        self.listedAt = listedAt
    }
}

// MARK: - Trakt Playback Progress Item

public struct TraktPlaybackProgressItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String {
        "\(type)_\(traktID)_\(season ?? 0)_\(episode ?? 0)"
    }

    public let traktID: Int
    public let title: String
    public let progress: Double // 0 to 100
    public let pausedAt: Date?
    public let type: String // "movie" or "episode"
    public let season: Int?
    public let episode: Int?
    public let year: Int?

    public nonisolated init(
        traktID: Int,
        title: String,
        progress: Double,
        pausedAt: Date? = nil,
        type: String,
        season: Int? = nil,
        episode: Int? = nil,
        year: Int? = nil
    ) {
        self.traktID = traktID
        self.title = title
        self.progress = progress
        self.pausedAt = pausedAt
        self.type = type
        self.season = season
        self.episode = episode
        self.year = year
    }
}
