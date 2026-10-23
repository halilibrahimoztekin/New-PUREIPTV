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
                        try session.setCategory(.playback, mode: .moviePlayback, policy: .longFormAudio)
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
