import Foundation
import GroupActivities

public struct PureIPTVSharePlayActivity: GroupActivity {
    public static let activityIdentifier = "com.pureiptv.SharePlayActivity"

    public let itemID: String
    public let title: String
    public let streamURLString: String
    public let type: String

    public init(itemID: String, title: String, streamURLString: String, type: String) {
        self.itemID = itemID
        self.title = title
        self.streamURLString = streamURLString
        self.type = type
    }

    public var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = title
        meta.type = .watchTogether
        return meta
    }
}
