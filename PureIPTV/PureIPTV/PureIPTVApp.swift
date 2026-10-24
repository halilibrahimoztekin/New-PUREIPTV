import AVFoundation
import ComposableArchitecture
import FactoryKit
import Kingfisher
import SwiftData
import SwiftUI
import SwiftVLC

@main
struct PureIPTVApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var themeManager = ThemeManager.shared
    init() {
        PlaybackVLC.prewarm()

        // Initialize RevenueCat
        PurchasesClient.liveValue.configure("appl_bSAnxGvXpdPeSquSYsatWQrNwOG")

        // Memory & Cache Optimization: Cap Kingfisher and URLCache to prevent unbounded memory growth
        ImageCache.default.memoryStorage.config.totalCostLimit = 64 * 1024 * 1024 // 64MB max memory
        ImageCache.default.memoryStorage.config.countLimit = 150
        ImageCache.default.memoryStorage.config.expiration = .seconds(300)

        URLCache.shared = URLCache(
            memoryCapacity: 20 * 1024 * 1024, // 20MB in memory
            diskCapacity: 100 * 1024 * 1024, // 100MB on disk
            diskPath: "pureiptv_url_cache"
        )

        #if os(iOS)
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { _ in
                ImageCache.default.clearMemoryCache()
                URLCache.shared.removeAllCachedResponses()
            }
        #endif

        Task {
            do {
                try await PlaybackAudioSession.setActive(true)
            } catch {
                print("Failed to configure audio session: \(error)")
            }
        }

        // Cross-device iCloud watch progress sync (Madde #43)
        Task.detached(priority: .utility) {
            _ = try? await WatchProgressSyncClient.liveValue.pullAndMergeRemoteChanges()
        }
    }

    /// The single store that drives the entire app logic
    let store = Store(initialState: AppCoordinator.State.initialState) {
        AppCoordinator()
    }

    var sharedModelContainer: ModelContainer = SharedDatabaseConfig.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppCoordinatorView(store: store)
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
                    if let playerStore = store.scope(state: \.miniPlayer, action: \.miniPlayer) {
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
            #if os(tvOS)
            .onContinueUserActivity(StreamHandoffManager.activityType) { activity in
                guard let request = StreamHandoffManager.shared.parseHandoff(from: activity) else { return }
                store.send(.receiveStreamHandoff(request))
            }
            #endif
        }
    }
}
