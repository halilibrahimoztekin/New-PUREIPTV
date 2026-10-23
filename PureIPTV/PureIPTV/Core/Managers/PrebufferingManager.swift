import Foundation

@MainActor
public final class PrebufferingManager: Sendable {
    public static let shared = PrebufferingManager()

    private var prebufferTask: Task<Void, Never>?

    private init() {}

    public func prepareChannel(url: URL?, userAgentOverride: String? = nil) {
        guard let url else { return }
        // If low power mode is enabled, respect battery efficiency (Madde #98)
        if PowerEfficiencyManager.shared.shouldThrottlePrebuffering {
            return
        }

        cancelPrebuffer()

        prebufferTask = Task(priority: .utility) {
            var request = URLRequest(url: url)
            request.setValue("bytes=0-524288", forHTTPHeaderField: "Range") // 512 KB pre-buffer
            request.timeoutInterval = 3.0
            UserAgentManager.shared.applyHeaders(to: &request, override: userAgentOverride)

            do {
                _ = try await URLSession.shared.data(for: request)
            } catch {
                // Silently ignore prebuffer failure
            }
        }
    }

    public func cancelPrebuffer() {
        prebufferTask?.cancel()
        prebufferTask = nil
    }
}
