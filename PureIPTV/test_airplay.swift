import AVFoundation

do {
    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .defaultToSpeaker])
    try AVAudioSession.sharedInstance().setActive(true)
} catch {
    print("Error setting audio session: \(error)")
}
