import Foundation

public struct XtreamVODModel: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let streamURL: URL
    public let posterURL: URL?
    public let categoryID: String
    public let rating: Double?
    public let description: String?

    public init(id: String, title: String, streamURL: URL, posterURL: URL?, categoryID: String, rating: Double? = nil, description: String? = nil) {
        self.id = id
        self.title = title
        self.streamURL = streamURL
        self.posterURL = posterURL
        self.categoryID = categoryID
        self.rating = rating
        self.description = description
    }
}
