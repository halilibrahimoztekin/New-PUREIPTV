import AVFoundation
import Foundation

enum PlaybackAudioSession {
    /// Serialize session changes and keep the blocking API off the main thread,
    /// including on iOS/tvOS versions without asynchronous activation APIs.
    private nonisolated static let queue = DispatchQueue(
        label: "com.pureiptv.audio-session",
        qos: .userInitiated
    )

    nonisolated static func setActive(_ active: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    if active {
                        #if os(iOS)
                            let desiredRouteSharingPolicy: AVAudioSession.RouteSharingPolicy = .longFormVideo
                        #else
                            let desiredRouteSharingPolicy: AVAudioSession.RouteSharingPolicy = .default
                        #endif
                        // Avoid reapplying an identical configuration. A
                        // category change can trigger a route update and may
                        // block on system audio work.
                        if session.category != .playback
                            || session.mode != .moviePlayback
                            || session.routeSharingPolicy != desiredRouteSharingPolicy
                        {
                            try session.setCategory(.playback, mode: .moviePlayback, policy: desiredRouteSharingPolicy)
                        }
                    }
                    try session.setActive(active)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
