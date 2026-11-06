import Foundation

public nonisolated enum TMDBImageSize: String, Sendable {
    case w185
    case w342
    case w500
    case w780
    case w1280
    case original
}

public nonisolated enum TMDBImageURL {
    public static func make(path: String?, size: TMDBImageSize) -> URL? {
        guard let path,
              path.hasPrefix("/"),
              !path.hasPrefix("//"),
              !path.contains(".."),
              !path.contains("\\")
        else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "image.tmdb.org"
        components.path = "/t/p/\(size.rawValue)\(path)"
        return components.url
    }
}
