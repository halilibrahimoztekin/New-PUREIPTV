import AVFoundation
import ComposableArchitecture
import FactoryKit
import SwiftData
import SwiftUI
import SwiftVLC

@main
struct PureIPTVApp: App {
    @Injected(\.appCoordinator) var coordinator

    init() {
        VLCInstance.prewarmShared()
        coordinator.setup(store: store)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }

    /// The single store that drives the entire app logic
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            CoordinatorRootView(coordinator: coordinator)
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
                .modelContainer(for: [FavoriteItem.self, WatchHistoryItem.self, CategoryPreference.self])
        }
    }
}
