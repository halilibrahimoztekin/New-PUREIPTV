import Foundation

public struct XtreamSeriesDTO: Codable {
    public let num: Int?
    public let name: String
    public let seriesId: Int
    public let cover: String?
    public let plot: String?
    public let cast: String?
    public let director: String?
    public let genre: String?
    public let releaseDate: String?
    public let lastModified: String?
    public let rating: String?
    public let rating5based: Double?
    public let categoryId: String

    private enum CodingKeys: String, CodingKey {
        case num
        case name
        case seriesId = "series_id"
        case cover
        case plot
        case cast
        case director
        case genre
        case releaseDate
        case lastModified = "last_modified"
        case rating
        case rating5based = "rating_5based"
        case categoryId = "category_id"
    }
}
