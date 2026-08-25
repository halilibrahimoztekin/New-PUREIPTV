import Foundation

public extension XtreamChannelModel {
    static var placeholder: XtreamChannelModel {
        XtreamChannelModel(
            id: UUID().uuidString,
            name: "Loading Channel Name...",
            streamURL: URL(string: "http://example.com")!,
            logoURL: nil,
            categoryID: "0"
        )
    }
}
