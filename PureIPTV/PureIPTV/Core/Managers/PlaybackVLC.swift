import AVFoundation
import Foundation
import SwiftVLC

/// All players must use the same ownership policy: AVAudioSession is process-wide.
@MainActor
enum PlaybackVLC {
    nonisolated static let instance: VLCInstance = {
        do {
            return try VLCInstance(appleAudioSessionPolicy: .applicationManaged)
        } catch {
            // Falling back to VLCInstance.shared would silently restore library-owned
            // audio-session calls on the main thread.
            fatalError("Failed to initialize application-managed VLC: \(error)")
        }
    }()

    private static let players = NSHashTable<Player>.weakObjects()
    private static var interruptionObserver: NSObjectProtocol?

    static func makePlayer() -> Player {
        let player = Player(instance: instance)
        players.add(player)
        observeInterruptionsIfNeeded()
        return player
    }

    nonisolated static func prewarm() {
        Task.detached(priority: .utility) {
            _ = instance
        }
    }

    private static func observeInterruptionsIfNeeded() {
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            guard
                let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                AVAudioSession.InterruptionType(rawValue: rawType) == .ended
            else { return }

            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
            Task { @MainActor in
                let activePlayers = players.allObjects.filter(\.isPlaybackRequestedActive)
                guard !activePlayers.isEmpty else { return }
                guard shouldResume else {
                    activePlayers.forEach { $0.pause() }
                    return
                }
                // VLC retains transport intent and handles its render graph. The app
                // only restores audio focus; it must not restart a user-paused player.
                do {
                    try await PlaybackAudioSession.setActive(true)
                } catch {
                    print("Failed to reactivate audio session after interruption: \(error)")
                }
            }
        }
    }
}
