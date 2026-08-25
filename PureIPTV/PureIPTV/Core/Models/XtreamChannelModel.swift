import Foundation

public struct XtreamChannelModel: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let streamURL: URL
    public let logoURL: URL?
    public let categoryID: String

    public init(id: String, name: String, streamURL: URL, logoURL: URL?, categoryID: String) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.logoURL = logoURL
        self.categoryID = categoryID
    }
}
