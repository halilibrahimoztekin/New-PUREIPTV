import AVFoundation
import ComposableArchitecture
import FactoryKit
import SwiftData
import SwiftUI
import SwiftVLC

@main
struct PureIPTVApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var themeManager = ThemeManager.shared
    @Injected(\.appCoordinator) var coordinator

    init() {
        VLCInstance.prewarmShared()
        coordinator.setup(store: store)

        do {
            #if os(tvOS)
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            #else
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .defaultToSpeaker])
            #endif
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }

    /// The single store that drives the entire app logic
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var sharedModelContainer: ModelContainer = SharedDatabaseConfig.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                CoordinatorRootView(coordinator: coordinator)
                    .preferredColorScheme(.dark)
                    .tint(themeManager.accentColor)
                    .ignoresSafeArea()
                    .modelContainer(sharedModelContainer)
                    .onChange(of: scenePhase) { newPhase in
                        if newPhase == .background {
                            appDelegate.scheduleAppRefresh()
                        }
                    }

                if let playerStore = store.scope(state: \.player, action: \.player) {
                    if store.isPlayerMini {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                #if os(iOS)
                                    // Mini player — küçük pencere olarak gösterilir, PiP full PlayerView'dan yönetilir
                                    PlayerView(store: playerStore)
                                        .frame(width: 200, height: 112) // 16:9 ratio
                                        .cornerRadius(12)
                                        .shadow(radius: 10)
                                        .padding()
                                        .onTapGesture {
                                            store.send(.toggleMiniPlayer)
                                        }
                                #endif
                            }
                        }
                    }
                }
            }
        }
    }
}
