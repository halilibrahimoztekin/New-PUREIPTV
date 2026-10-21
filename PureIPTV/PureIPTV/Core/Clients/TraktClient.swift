import ComposableArchitecture
import Foundation

// MARK: - Trakt Error

public enum TraktError: LocalizedError, Sendable, Equatable {
    case unauthenticated
    case invalidResponse
    case networkError(String)
    case expiredCode
    case accessDenied
    case rateLimited

    public var errorDescription: String? {
        switch self {
        case .unauthenticated:
            "Trakt.tv hesabı bağlı değil."
        case .invalidResponse:
            "Trakt.tv sunucusundan geçersiz yanıt alındı."
        case let .networkError(msg):
            "Bağlantı hatası: \(msg)"
        case .expiredCode:
            "Eşleştirme kodunun süresi doldu. Lütfen yeniden deneyin."
        case .accessDenied:
            "Kullanıcı tarafından erişim reddedildi."
        case .rateLimited:
            "Çok sık istek yapıldı, lütfen birkaç saniye bekleyin."
        }
    }
}

// MARK: - Trakt Client Interface

@DependencyClient
public struct TraktClient: Sendable {
    public var isAuthenticated: @Sendable () -> Bool = { false }
    public var currentUser: @Sendable () -> TraktUser? = { nil }
    public var getAccessToken: @Sendable () -> String? = { nil }

    public var generateDeviceCode: @Sendable () async throws -> TraktDeviceCode
    public var pollDeviceToken: @Sendable (_ deviceCode: String) async throws -> TraktTokenResponse?
    public var fetchUserProfile: @Sendable () async throws -> TraktUser
    public var scrobbleStart: @Sendable (_ payload: TraktScrobblePayload) async throws -> TraktScrobbleResponse
    public var scrobblePause: @Sendable (_ payload: TraktScrobblePayload) async throws -> TraktScrobbleResponse
    public var scrobbleStop: @Sendable (_ payload: TraktScrobblePayload) async throws -> TraktScrobbleResponse
    public var fetchWatchlist: @Sendable () async throws -> [TraktWatchlistItem]
    public var fetchPlaybackProgress: @Sendable () async throws -> [TraktPlaybackProgressItem]

    public var isAutoScrobbleEnabled: @Sendable () -> Bool = { true }
    public var setAutoScrobbleEnabled: @Sendable (Bool) -> Void = { _ in }
    public var logout: @Sendable () -> Void = {}
}

// MARK: - DependencyKey & Live Implementation

extension TraktClient: DependencyKey {
    private nonisolated static let tokenKey = "com.pureiptv.trakt.token"
    private nonisolated static let userKey = "com.pureiptv.trakt.user"
    private nonisolated static let autoScrobbleKey = "com.pureiptv.isTraktAutoScrobbleEnabled"

    // Default registered Trakt application credentials for PureIPTV
    private nonisolated static let clientID = "a16c738e4a7a8d0f19c299c836cb1690076b9148d88e63ef93bf9bcf3c95971a"
    private nonisolated static let clientSecret = "467d58a5620ce9b7754b2fc5ba21379e9a11f26f63f53835c24e6ca6fbf193c7"
    private nonisolated static let baseURL = "https://api.trakt.tv"

    public nonisolated static let liveValue: TraktClient = {
        let session = URLSession.shared

        @Sendable func savedToken() -> TraktTokenResponse? {
            try? KeychainManager.shared.retrieve(for: tokenKey, as: TraktTokenResponse.self)
        }

        @Sendable func savedUser() -> TraktUser? {
            try? KeychainManager.shared.retrieve(for: userKey, as: TraktUser.self)
        }

        @Sendable func isAutoScrobble() -> Bool {
            if UserDefaults.standard.object(forKey: autoScrobbleKey) == nil {
                UserDefaults.standard.set(true, forKey: autoScrobbleKey)
            }
            return UserDefaults.standard.bool(forKey: autoScrobbleKey)
        }

        @Sendable func makeRequest(
            path: String,
            method: String = "GET",
            body: Data? = nil,
            requiresAuth: Bool = true
        ) throws -> URLRequest {
            guard let url = URL(string: "\(baseURL)\(path)") else {
                throw TraktError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("2", forHTTPHeaderField: "trakt-api-version")
            request.setValue(clientID, forHTTPHeaderField: "trakt-api-key")

            if requiresAuth {
                guard let token = savedToken()?.accessToken else {
                    throw TraktError.unauthenticated
                }
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            if let body {
                request.httpBody = body
            }
            return request
        }

        return TraktClient(
            isAuthenticated: {
                savedToken() != nil
            },
            currentUser: {
                savedUser()
            },
            getAccessToken: {
                savedToken()?.accessToken
            },
            generateDeviceCode: {
                let reqBody = ["client_id": clientID]
                let bodyData = try JSONSerialization.data(withJSONObject: reqBody)
                let request = try makeRequest(path: "/oauth/device/code", method: "POST", body: bodyData, requiresAuth: false)

                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                    throw TraktError.invalidResponse
                }

                return try JSONDecoder().decode(TraktDeviceCode.self, from: data)
            },
            pollDeviceToken: { deviceCode in
                let reqBody = [
                    "code": deviceCode,
                    "client_id": clientID,
                    "client_secret": clientSecret,
                ]
                let bodyData = try JSONSerialization.data(withJSONObject: reqBody)
                let request = try makeRequest(path: "/oauth/device/token", method: "POST", body: bodyData, requiresAuth: false)

                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw TraktError.invalidResponse
                }

                if http.statusCode == 200 {
                    let token = try JSONDecoder().decode(TraktTokenResponse.self, from: data)
                    try? KeychainManager.shared.save(token, for: tokenKey)

                    // Fetch user profile immediately
                    if let userReq = try? makeRequest(path: "/users/me?extended=full", method: "GET", requiresAuth: true) {
                        if let (userData, userResp) = try? await session.data(for: userReq),
                           let userHttp = userResp as? HTTPURLResponse, (200 ... 299).contains(userHttp.statusCode)
                        {
                            if let json = try? JSONSerialization.jsonObject(with: userData) as? [String: Any],
                               let username = json["username"] as? String
                            {
                                let name = json["name"] as? String
                                let isVip = (json["is_vip"] as? Bool) ?? (json["vip"] as? Bool) ?? false
                                let images = json["images"] as? [String: Any]
                                let avatar = (images?["avatar"] as? [String: Any])?["full"] as? String
                                let user = TraktUser(username: username, name: name, isVIP: isVip, avatarURL: avatar)
                                try? KeychainManager.shared.save(user, for: userKey)
                            }
                        }
                    }
                    return token
                } else if http.statusCode == 400 {
                    // Pending approval
                    return nil
                } else if http.statusCode == 404 || http.statusCode == 410 {
                    throw TraktError.expiredCode
                } else if http.statusCode == 418 {
                    throw TraktError.accessDenied
                } else if http.statusCode == 429 {
                    throw TraktError.rateLimited
                } else {
                    return nil
                }
            },
            fetchUserProfile: {
                guard savedToken() != nil else { throw TraktError.unauthenticated }
                let request = try makeRequest(path: "/users/me?extended=full", method: "GET", requiresAuth: true)
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                    throw TraktError.invalidResponse
                }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let username = json["username"] as? String
                else {
                    throw TraktError.invalidResponse
                }
                let name = json["name"] as? String
                let isVip = (json["is_vip"] as? Bool) ?? (json["vip"] as? Bool) ?? false
                let images = json["images"] as? [String: Any]
                let avatar = (images?["avatar"] as? [String: Any])?["full"] as? String
                let user = TraktUser(username: username, name: name, isVIP: isVip, avatarURL: avatar)
                try? KeychainManager.shared.save(user, for: userKey)
                return user
            },
            scrobbleStart: { payload in
                guard isAutoScrobble() else {
                    return TraktScrobbleResponse(action: "start", progress: payload.progress)
                }
                guard savedToken() != nil else { throw TraktError.unauthenticated }

                var root: [String: Any] = ["progress": payload.progress]
                if payload.isEpisode {
                    root["show"] = ["title": payload.title]
                    root["episode"] = [
                        "season": payload.season ?? 1,
                        "number": payload.episode ?? 1,
                    ]
                } else {
                    var movie: [String: Any] = ["title": payload.title]
                    if let year = payload.year {
                        movie["year"] = year
                    }
                    root["movie"] = movie
                }

                let bodyData = try JSONSerialization.data(withJSONObject: root)
                let request = try makeRequest(path: "/scrobble/start", method: "POST", body: bodyData, requiresAuth: true)
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                    throw TraktError.invalidResponse
                }
                let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let action = (json["action"] as? String) ?? "start"
                let progress = (json["progress"] as? Double) ?? payload.progress
                return TraktScrobbleResponse(action: action, progress: progress)
            },
            scrobblePause: { payload in
                guard isAutoScrobble() else {
                    return TraktScrobbleResponse(action: "pause", progress: payload.progress)
                }
                guard savedToken() != nil else { throw TraktError.unauthenticated }

                var root: [String: Any] = ["progress": payload.progress]
                if payload.isEpisode {
                    root["show"] = ["title": payload.title]
                    root["episode"] = [
                        "season": payload.season ?? 1,
                        "number": payload.episode ?? 1,
                    ]
                } else {
                    var movie: [String: Any] = ["title": payload.title]
                    if let year = payload.year {
                        movie["year"] = year
                    }
                    root["movie"] = movie
                }

                let bodyData = try JSONSerialization.data(withJSONObject: root)
                let request = try makeRequest(path: "/scrobble/pause", method: "POST", body: bodyData, requiresAuth: true)
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                    throw TraktError.invalidResponse
                }
                let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let action = (json["action"] as? String) ?? "pause"
                let progress = (json["progress"] as? Double) ?? payload.progress
                return TraktScrobbleResponse(action: action, progress: progress)
            },
            scrobbleStop: { payload in
                guard isAutoScrobble() else {
                    return TraktScrobbleResponse(action: "scrobble", progress: payload.progress)
                }
                guard savedToken() != nil else { throw TraktError.unauthenticated }

                var root: [String: Any] = ["progress": payload.progress]
                if payload.isEpisode {
                    root["show"] = ["title": payload.title]
                    root["episode"] = [
                        "season": payload.season ?? 1,
                        "number": payload.episode ?? 1,
                    ]
                } else {
                    var movie: [String: Any] = ["title": payload.title]
                    if let year = payload.year {
                        movie["year"] = year
                    }
                    root["movie"] = movie
                }

                let bodyData = try JSONSerialization.data(withJSONObject: root)
                let request = try makeRequest(path: "/scrobble/stop", method: "POST", body: bodyData, requiresAuth: true)
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                    throw TraktError.invalidResponse
                }
                let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let action = (json["action"] as? String) ?? (payload.progress >= 80 ? "scrobble" : "stop")
                let progress = (json["progress"] as? Double) ?? payload.progress
                return TraktScrobbleResponse(action: action, progress: progress)
            },
            fetchWatchlist: {
                guard savedToken() != nil else { throw TraktError.unauthenticated }
                var items: [TraktWatchlistItem] = []

                // Fetch Movies Watchlist
                if let req = try? makeRequest(path: "/sync/watchlist/movies?extended=full", method: "GET", requiresAuth: true),
                   let (data, resp) = try? await session.data(for: req),
                   let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode),
                   let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                {
                    for entry in jsonArray {
                        if let movie = entry["movie"] as? [String: Any],
                           let title = movie["title"] as? String,
                           let ids = movie["ids"] as? [String: Any],
                           let traktID = ids["trakt"] as? Int
                        {
                            let year = movie["year"] as? Int
                            let overview = movie["overview"] as? String
                            let tmdbID = ids["tmdb"] as? Int
                            let imdbID = ids["imdb"] as? String
                            items.append(TraktWatchlistItem(
                                traktID: traktID,
                                title: title,
                                year: year,
                                type: "movie",
                                overview: overview,
                                tmdbID: tmdbID,
                                imdbID: imdbID
                            ))
                        }
                    }
                }

                // Fetch Shows Watchlist
                if let req = try? makeRequest(path: "/sync/watchlist/shows?extended=full", method: "GET", requiresAuth: true),
                   let (data, resp) = try? await session.data(for: req),
                   let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode),
                   let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                {
                    for entry in jsonArray {
                        if let show = entry["show"] as? [String: Any],
                           let title = show["title"] as? String,
                           let ids = show["ids"] as? [String: Any],
                           let traktID = ids["trakt"] as? Int
                        {
                            let year = show["year"] as? Int
                            let overview = show["overview"] as? String
                            let tmdbID = ids["tmdb"] as? Int
                            let imdbID = ids["imdb"] as? String
                            items.append(TraktWatchlistItem(
                                traktID: traktID,
                                title: title,
                                year: year,
                                type: "show",
                                overview: overview,
                                tmdbID: tmdbID,
                                imdbID: imdbID
                            ))
                        }
                    }
                }

                return items
            },
            fetchPlaybackProgress: {
                guard savedToken() != nil else { throw TraktError.unauthenticated }
                let request = try makeRequest(path: "/sync/playback", method: "GET", requiresAuth: true)
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                    throw TraktError.invalidResponse
                }
                guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    return []
                }

                var results: [TraktPlaybackProgressItem] = []
                for entry in jsonArray {
                    let progress = (entry["progress"] as? Double) ?? 0.0
                    let type = (entry["type"] as? String) ?? "movie"

                    if type == "episode", let ep = entry["episode"] as? [String: Any],
                       let ids = ep["ids"] as? [String: Any],
                       let traktID = ids["trakt"] as? Int
                    {
                        let season = ep["season"] as? Int
                        let epNum = ep["number"] as? Int
                        let show = entry["show"] as? [String: Any]
                        let showTitle = (show?["title"] as? String) ?? (ep["title"] as? String) ?? "Dizi"

                        results.append(TraktPlaybackProgressItem(
                            traktID: traktID,
                            title: showTitle,
                            progress: progress,
                            type: "episode",
                            season: season,
                            episode: epNum
                        ))
                    } else if let movie = entry["movie"] as? [String: Any],
                              let ids = movie["ids"] as? [String: Any],
                              let traktID = ids["trakt"] as? Int
                    {
                        let title = (movie["title"] as? String) ?? "Film"
                        let year = movie["year"] as? Int
                        results.append(TraktPlaybackProgressItem(
                            traktID: traktID,
                            title: title,
                            progress: progress,
                            type: "movie",
                            year: year
                        ))
                    }
                }
                return results
            },
            isAutoScrobbleEnabled: {
                isAutoScrobble()
            },
            setAutoScrobbleEnabled: { val in
                UserDefaults.standard.set(val, forKey: autoScrobbleKey)
            },
            logout: {
                try? KeychainManager.shared.delete(for: tokenKey)
                try? KeychainManager.shared.delete(for: userKey)
            }
        )
    }()

    public nonisolated static let testValue: TraktClient = .liveValue
}

public extension DependencyValues {
    var traktClient: TraktClient {
        get { self[TraktClient.self] }
        set { self[TraktClient.self] = newValue }
    }
}
