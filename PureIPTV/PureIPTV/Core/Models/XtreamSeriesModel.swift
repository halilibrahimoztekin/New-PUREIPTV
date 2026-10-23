import Foundation

public struct XtreamSeriesModel: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let coverURL: URL?
    public let categoryID: String
    public let rating: Double?
    public let releaseDate: String?
    public let cast: String?
    public let director: String?
    public let plot: String?
    public let genre: String?

    public init(
        id: String,
        title: String,
        coverURL: URL?,
        categoryID: String,
        rating: Double? = nil,
        releaseDate: String? = nil,
        cast: String? = nil,
        director: String? = nil,
        plot: String? = nil,
        genre: String? = nil
    ) {
        self.id = id
        self.title = title
        self.coverURL = coverURL
        self.categoryID = categoryID
        self.rating = rating
        self.releaseDate = releaseDate
        self.cast = cast
        self.director = director
        self.plot = plot
        self.genre = genre
    }
}

public extension XtreamSeriesModel {
    static var placeholder: XtreamSeriesModel {
        XtreamSeriesModel(
            id: UUID().uuidString,
            title: "Loading Series...",
            coverURL: nil,
            categoryID: "0",
            rating: 5.0
        )
    }
}
