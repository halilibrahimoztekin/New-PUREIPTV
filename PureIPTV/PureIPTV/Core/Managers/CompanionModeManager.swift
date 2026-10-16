import Foundation

public struct CompanionPlaybackInfo: Codable, Equatable, Sendable {
    public let channelID: String
    public let channelTitle: String
    public let programTitle: String?
    public let isPlaying: Bool
    public let deviceName: String

    public init(
        channelID: String,
        channelTitle: String,
        programTitle: String? = nil,
        isPlaying: Bool = true,
        deviceName: String = "Apple TV"
    ) {
        self.channelID = channelID
        self.channelTitle = channelTitle
        self.programTitle = programTitle
        self.isPlaying = isPlaying
        self.deviceName = deviceName
    }
}

public final class CompanionModeManager: @unchecked Sendable {
    public static let shared = CompanionModeManager()

    private let storageKey = "pureiptv_companion_state"
    public private(set) var activePlayback: CompanionPlaybackInfo?

    private init() {}

    /// Called by tvOS when playback state updates
    public func broadcastPlayback(info: CompanionPlaybackInfo) {
        activePlayback = info
        if let data = try? JSONEncoder().encode(info) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        NotificationCenter.default.post(name: .companionPlaybackChanged, object: nil)
    }

    /// Called by iOS to check if an Apple TV on the same iCloud/Local network is playing
    public func fetchActivePlayback() -> CompanionPlaybackInfo? {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(CompanionPlaybackInfo.self, from: data)
        {
            activePlayback = saved
            return saved
        }
        return activePlayback
    }

    public func clearPlayback() {
        activePlayback = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
        NotificationCenter.default.post(name: .companionPlaybackChanged, object: nil)
    }
}

public extension Notification.Name {
    static let companionPlaybackChanged = Notification.Name("pureiptv_companionPlaybackChanged")
}
