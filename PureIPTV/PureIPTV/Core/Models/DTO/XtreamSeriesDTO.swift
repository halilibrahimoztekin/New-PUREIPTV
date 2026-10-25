import Foundation

public struct XtreamSeriesDTO: Codable, Sendable {
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
    public let originalLanguageCode: String?
    public let originalLanguageSourceValue: String?

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
        case originalLanguageCode = "original_language"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        num = try container.decodeIfPresent(Int.self, forKey: .num)
        name = try container.decode(String.self, forKey: .name)
        seriesId = try container.decode(Int.self, forKey: .seriesId)
        cover = try container.decodeIfPresent(String.self, forKey: .cover)
        plot = try container.decodeIfPresent(String.self, forKey: .plot)
        cast = try container.decodeIfPresent(String.self, forKey: .cast)
        director = try container.decodeIfPresent(String.self, forKey: .director)
        genre = try container.decodeIfPresent(String.self, forKey: .genre)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        lastModified = try container.decodeIfPresent(String.self, forKey: .lastModified)
        rating = try container.decodeIfPresent(String.self, forKey: .rating)
        rating5based = try container.decodeIfPresent(Double.self, forKey: .rating5based)
        categoryId = try XtreamDTOValueDecoder.categoryID(from: container, forKey: .categoryId)
        originalLanguageSourceValue = try? container.decode(String.self, forKey: .originalLanguageCode)
        originalLanguageCode = ISO639LanguageCode.normalize(originalLanguageSourceValue)
    }
}
