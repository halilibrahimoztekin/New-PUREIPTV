import Foundation

public extension XtreamVODModel {
    static var placeholder: XtreamVODModel {
        XtreamVODModel(
            id: UUID().uuidString,
            title: "Loading Movie...",
            streamURL: URL(string: "http://example.com")!,
            posterURL: nil,
            categoryID: "0",
            rating: 5.0,
            description: "Loading description..."
        )
    }
}
