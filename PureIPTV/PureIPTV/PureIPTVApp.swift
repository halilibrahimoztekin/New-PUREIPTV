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

        // Initialize RevenueCat
        PurchasesClient.liveValue.configure("appl_bSAnxGvXpdPeSquSYsatWQrNwOG")

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

        // Cross-device iCloud watch progress sync (Madde #43)
        Task.detached(priority: .utility) {
            _ = try? await WatchProgressSyncClient.liveValue.pullAndMergeRemoteChanges()
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
                    .onChange(of: scenePhase) { newPhase, _ in
                        if newPhase == .background {
                            appDelegate.scheduleAppRefresh()
                        }
                    }

                #if os(iOS)
                    if let playerStore = store.scope(state: \.player, action: \.player) {
                        if store.isPlayerMini {
                            VStack {
                                Spacer()
                                DockedMiniPlayerView(
                                    store: playerStore,
                                    onExpand: {
                                        store.send(.expandPlayer)
                                    },
                                    onClose: {
                                        store.send(.closeMiniPlayer)
                                    }
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 64)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.isPlayerMini)
                            .zIndex(999)
                        }
                    }
                #endif
            }
            .onOpenURL { url in
                store.send(.handleDeepLink(url))
            }
        }
    }
}
