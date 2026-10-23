import Foundation

public final class ChannelNumberManager: @unchecked Sendable {
    public static let shared = ChannelNumberManager()

    private let storageKey = "pureiptv_channel_numbers"
    private var customNumbers: [String: Int] = [:] // channelID -> number

    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Int] {
            customNumbers = saved
        }
    }

    /// Returns the resolved channel number. If no custom number assigned, falls back to 1-based index
    public func number(for channel: MediaModels.Item, defaultIndex: Int) -> Int {
        if let custom = customNumbers[channel.id] {
            return custom
        }
        return defaultIndex + 1
    }

    public func assign(number: Int, toChannelID channelID: String) {
        customNumbers[channelID] = number
        UserDefaults.standard.set(customNumbers, forKey: storageKey)
    }

    /// Finds a channel matching a dialed number
    public func channel(forNumber number: Int, in channels: [MediaModels.Item]) -> MediaModels.Item? {
        if let customMatch = channels.first(where: { customNumbers[$0.id] == number }) {
            return customMatch
        }
        let fallbackIndex = number - 1
        if fallbackIndex >= 0, fallbackIndex < channels.count {
            return channels[fallbackIndex]
        }
        return nil
    }
}
