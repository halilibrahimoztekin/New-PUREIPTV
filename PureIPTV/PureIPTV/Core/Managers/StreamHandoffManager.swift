import Foundation
#if canImport(UIKit)
    import UIKit
#endif

public final class StreamHandoffManager: @unchecked Sendable {
    public static let shared = StreamHandoffManager()

    public static let activityType = "com.pureiptv.stream-handoff"

    private var currentActivity: NSUserActivity?

    private init() {}

    public func updatePlaybackActivity(
        channelTitle: String,
        streamURL: URL,
        playbackPosition: Double,
        isLive: Bool
    ) {
        let activity = NSUserActivity(activityType: Self.activityType)
        activity.title = "PureIPTV: \(channelTitle)"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false

        activity.userInfo = [
            "channelTitle": channelTitle,
            "streamURL": streamURL.absoluteString,
            "playbackPosition": playbackPosition,
            "isLive": isLive,
        ]

        activity.becomeCurrent()
        currentActivity = activity
    }

    public func invalidateActivity() {
        currentActivity?.invalidate()
        currentActivity = nil
    }

    public func parseHandoff(from activity: NSUserActivity) -> (title: String, url: URL, position: Double, isLive: Bool)? {
        guard activity.activityType == Self.activityType,
              let info = activity.userInfo,
              let title = info["channelTitle"] as? String,
              let urlString = info["streamURL"] as? String,
              let url = URL(string: urlString)
        else {
            return nil
        }
        let position = info["playbackPosition"] as? Double ?? 0.0
        let isLive = info["isLive"] as? Bool ?? true
        return (title, url, position, isLive)
    }
}
