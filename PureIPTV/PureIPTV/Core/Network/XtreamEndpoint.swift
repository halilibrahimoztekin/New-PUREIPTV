import Foundation

public enum XtreamEndpoint {
    case authenticate
    case getLiveCategories
    case getLiveStreams(categoryID: String?)
    case getVODCategories
    case getVODStreams(categoryID: String?)
    case getVODInfo(vodID: String)
    case getSeriesCategories
    case getSeries(categoryID: String?)
    case getSeriesInfo(seriesID: String)
    case getShortEPG(streamID: String, limit: Int?)

    public func url(with config: ServerConfig) throws -> URL {
        var components = URLComponents(url: config.baseURL.appendingPathComponent("player_api.php"), resolvingAgainstBaseURL: false)

        var queryItems = [
            URLQueryItem(name: "username", value: config.username),
            URLQueryItem(name: "password", value: config.password),
        ]

        switch self {
        case .authenticate:
            break // Just username and password
        case .getLiveCategories:
            queryItems.append(URLQueryItem(name: "action", value: "get_live_categories"))
        case let .getLiveStreams(categoryID):
            queryItems.append(URLQueryItem(name: "action", value: "get_live_streams"))
            if let categoryID = categoryID {
                queryItems.append(URLQueryItem(name: "category_id", value: categoryID))
            }
        case .getVODCategories:
            queryItems.append(URLQueryItem(name: "action", value: "get_vod_categories"))
        case let .getVODStreams(categoryID):
            queryItems.append(URLQueryItem(name: "action", value: "get_vod_streams"))
            if let categoryID = categoryID {
                queryItems.append(URLQueryItem(name: "category_id", value: categoryID))
            }
        case let .getVODInfo(vodID):
            queryItems.append(URLQueryItem(name: "action", value: "get_vod_info"))
            queryItems.append(URLQueryItem(name: "vod_id", value: vodID))
        case .getSeriesCategories:
            queryItems.append(URLQueryItem(name: "action", value: "get_series_categories"))
        case let .getSeries(categoryID):
            queryItems.append(URLQueryItem(name: "action", value: "get_series"))
            if let categoryID = categoryID {
                queryItems.append(URLQueryItem(name: "category_id", value: categoryID))
            }
        case let .getSeriesInfo(seriesID):
            queryItems.append(URLQueryItem(name: "action", value: "get_series_info"))
            queryItems.append(URLQueryItem(name: "series_id", value: seriesID))
        case let .getShortEPG(streamID, limit):
            queryItems.append(URLQueryItem(name: "action", value: "get_short_epg"))
            queryItems.append(URLQueryItem(name: "stream_id", value: streamID))
            if let limit = limit {
                queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
            }
        }

        components?.queryItems = queryItems

        guard let finalURL = components?.url else {
            throw NetworkError.invalidURL
        }

        return finalURL
    }
}
