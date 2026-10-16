import Foundation

@MainActor
public final class DeadLinkChecker: Sendable {
    public static let shared = DeadLinkChecker()

    private var deadChannelIDs: Set<String> = []
    private var verifiedChannelIDs: Set<String> = []

    private init() {}

    public func isDead(channelID: String) -> Bool {
        deadChannelIDs.contains(channelID)
    }

    public func getDeadChannels() -> Set<String> {
        deadChannelIDs
    }

    /// Performs a fast HEAD request to check if a stream link is reachable
    public func checkChannel(id: String, url: URL) async -> Bool {
        if verifiedChannelIDs.contains(id) {
            return true
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 3.5
        UserAgentManager.shared.applyHeaders(to: &request)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                let reachable = (200 ... 399).contains(httpResponse.statusCode)
                if reachable {
                    verifiedChannelIDs.insert(id)
                    deadChannelIDs.remove(id)
                } else {
                    deadChannelIDs.insert(id)
                }
                return reachable
            }
        } catch {
            deadChannelIDs.insert(id)
            return false
        }
        return true
    }

    /// Scans a batch of favorite channels in the background with controlled concurrency
    public func scanChannels(_ channels: [MediaModels.Item]) async -> Set<String> {
        for channel in channels.prefix(50) {
            guard let url = channel.streamURL else { continue }
            let reachable = await checkChannel(id: channel.id, url: url)
            if !reachable {
                deadChannelIDs.insert(channel.id)
            }
        }
        return deadChannelIDs
    }

    public func reset() {
        deadChannelIDs.removeAll()
        verifiedChannelIDs.removeAll()
    }
}
