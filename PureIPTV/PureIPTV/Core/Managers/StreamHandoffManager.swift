import Foundation

/// A URL-free description of the item to resolve on the receiving device.
public struct StreamHandoffRequest: Equatable, Sendable {
    public enum MediaKind: String, Equatable, Sendable {
        case live
        case vod
        case episode
    }

    public let playlistID: UUID
    public let itemID: String
    public let mediaKind: MediaKind
    public let seriesID: String?
    public let seriesTitle: String?
    public let categoryID: String?
    /// Normalized media position in the range 0...1. Live streams never seek.
    public let playbackPosition: Double
    public let title: String

    public init(
        playlistID: UUID,
        itemID: String,
        mediaKind: MediaKind,
        seriesID: String? = nil,
        seriesTitle: String? = nil,
        categoryID: String? = nil,
        playbackPosition: Double = 0,
        title: String
    ) {
        self.playlistID = playlistID
        self.itemID = itemID
        self.mediaKind = mediaKind
        self.seriesID = seriesID
        self.seriesTitle = seriesTitle
        self.categoryID = categoryID
        self.playbackPosition = min(max(playbackPosition.isFinite ? playbackPosition : 0, 0), 1)
        self.title = title
    }
}

public final class StreamHandoffManager: @unchecked Sendable {
    public static let shared = StreamHandoffManager()
    public static let activityType = "com.pureiptv.stream-handoff"
    private static let payloadVersion = 1

    private var currentActivity: NSUserActivity?

    private init() {}

    public func updatePlaybackActivity(_ request: StreamHandoffRequest) {
        invalidateActivity()
        guard Self.hasValidPayloadStrings(request) else { return }
        let activity = NSUserActivity(activityType: Self.activityType)
        activity.title = "PureIPTV: \(request.title)"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.userInfo = [
            "version": Self.payloadVersion,
            "playlistID": request.playlistID.uuidString,
            "itemID": request.itemID,
            "mediaKind": request.mediaKind.rawValue,
            "playbackPosition": request.playbackPosition,
            "title": request.title,
        ] as [String: Any]
        if let seriesID = request.seriesID,
           let seriesTitle = request.seriesTitle,
           request.mediaKind == .episode
        {
            activity.userInfo?["seriesID"] = seriesID
            activity.userInfo?["seriesTitle"] = seriesTitle
        }
        if let categoryID = request.categoryID, categoryID.count <= 512 {
            activity.userInfo?["categoryID"] = categoryID
        }
        activity.becomeCurrent()
        currentActivity = activity
    }

    public func invalidateActivity() {
        currentActivity?.invalidate()
        currentActivity = nil
    }

    public func parseHandoff(from activity: NSUserActivity) -> StreamHandoffRequest? {
        guard activity.activityType == Self.activityType,
              let info = activity.userInfo,
              info["version"] as? Int == Self.payloadVersion,
              let playlistString = info["playlistID"] as? String,
              let playlistID = UUID(uuidString: playlistString),
              let itemID = info["itemID"] as? String,
              !itemID.isEmpty, itemID.count <= 512,
              let kindString = info["mediaKind"] as? String,
              let kind = StreamHandoffRequest.MediaKind(rawValue: kindString),
              let title = info["title"] as? String,
              !title.isEmpty, title.count <= 300
        else { return nil }

        let seriesID = info["seriesID"] as? String
        guard kind != .episode || (seriesID?.isEmpty == false) else { return nil }
        guard seriesID == nil || (seriesID?.count ?? 0) <= 512 else { return nil }
        let seriesTitle = info["seriesTitle"] as? String
        guard kind != .episode || (seriesTitle?.isEmpty == false && (seriesTitle?.count ?? 0) <= 300) else { return nil }
        let categoryID = info["categoryID"] as? String
        guard categoryID == nil || (categoryID?.count ?? 0) <= 512 else { return nil }
        let position = info["playbackPosition"] as? Double ?? 0
        guard position.isFinite else { return nil }
        return StreamHandoffRequest(
            playlistID: playlistID,
            itemID: itemID,
            mediaKind: kind,
            seriesID: seriesID,
            seriesTitle: seriesTitle,
            categoryID: categoryID,
            playbackPosition: position,
            title: title
        )
    }

    private static func hasValidPayloadStrings(_ request: StreamHandoffRequest) -> Bool {
        guard !request.itemID.isEmpty, request.itemID.count <= 512,
              !request.title.isEmpty, request.title.count <= 300 else { return false }
        if request.mediaKind == .episode {
            guard let seriesID = request.seriesID, !seriesID.isEmpty, seriesID.count <= 512,
                  let seriesTitle = request.seriesTitle, !seriesTitle.isEmpty, seriesTitle.count <= 300
            else {
                return false
            }
        }
        guard request.categoryID == nil || (request.categoryID?.count ?? 0) <= 512 else { return false }
        return true
    }
}
