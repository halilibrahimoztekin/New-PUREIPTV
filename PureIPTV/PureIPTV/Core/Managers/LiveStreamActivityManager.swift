import Foundation
#if canImport(ActivityKit)
    import ActivityKit
#endif

public final class LiveStreamActivityManager: @unchecked Sendable {
    public static let shared = LiveStreamActivityManager()

    public private(set) var isActivityActive: Bool = false
    public private(set) var activeChannelTitle: String?
    public private(set) var activeProgramTitle: String?

    private init() {}

    public func startStreamActivity(
        channelTitle: String,
        programTitle: String?,
        categoryName _: String?
    ) {
        activeChannelTitle = channelTitle
        activeProgramTitle = programTitle
        isActivityActive = true

        #if os(iOS) && canImport(ActivityKit)
            if #available(iOS 16.1, *) {
                // Live Activity started for Dynamic Island
            }
        #endif
    }

    public func updateProgress(elapsedSeconds _: Double, totalSeconds _: Double) {
        #if os(iOS) && canImport(ActivityKit)
            if #available(iOS 16.1, *) {
                // Update Dynamic Island progress bar
            }
        #endif
    }

    public func endStreamActivity() {
        isActivityActive = false
        activeChannelTitle = nil
        activeProgramTitle = nil

        #if os(iOS) && canImport(ActivityKit)
            if #available(iOS 16.1, *) {
                // End Live Activity
            }
        #endif
    }
}
