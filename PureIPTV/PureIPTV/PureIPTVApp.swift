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
        #if os(iOS)
            EPGReminderNotificationDelegate.install()
        #endif
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
                            store.send(.appEnteredBackground)
                        } else if newPhase == .active {
                            store.send(.appEnteredForeground)
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
            #if os(iOS)
            .sheet(
                isPresented: Binding(
                    get: { store.playlistTransferPairing != nil },
                    set: {
                        if !$0 {
                            store.send(.cancelPlaylistTransfer)
                        }
                    }
                )
            ) {
                PlaylistQRTransferConfirmationView(
                    playlists: store.playlistTransferPlaylists,
                    selectedID: store.playlistTransferSelectedID,
                    isLoading: store.isLoadingPlaylistTransfer,
                    isSubmitting: store.isSubmittingPlaylistTransfer,
                    error: store.playlistTransferError,
                    onSelect: { store.send(.selectPlaylistForTransfer($0)) },
                    onConfirm: { store.send(.confirmPlaylistTransfer) },
                    onCancel: { store.send(.cancelPlaylistTransfer) }
                )
            }
            #endif
            #if os(tvOS)
            .onContinueUserActivity(StreamHandoffManager.activityType) { activity in
                guard let request = StreamHandoffManager.shared.parseHandoff(from: activity) else { return }
                store.send(.receiveStreamHandoff(request))
            }
            #endif
        }
    }
}

#if os(iOS)
    private struct PlaylistQRTransferConfirmationView: View {
        let playlists: [SavedPlaylist]
        let selectedID: UUID?
        let isLoading: Bool
        let isSubmitting: Bool
        let error: String?
        let onSelect: (UUID) -> Void
        let onConfirm: () -> Void
        let onCancel: () -> Void

        var body: some View {
            NavigationStack {
                List(playlists) { playlist in
                    Button {
                        onSelect(playlist.id)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.name).font(.body.weight(.semibold))
                                Text(playlist.type.displayName).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedID == playlist.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedID == playlist.id ? .isSelected : [])
                }
                .overlay {
                    if isLoading {
                        ProgressView("iCloud Keychain bekleniyor…")
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    } else if playlists.isEmpty {
                        ContentUnavailableView("Playlist bulunamadı", systemImage: "qrcode", description: Text("Aktarılabilecek kayıtlı playlist görünmüyor."))
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 12) {
                        Text("Seçilen playlist Apple TV’de etkinleştirilecek. Adres ve giriş bilgileri QR kodla paylaşılmaz; cihazlar aynı Apple ID ve iCloud Keychain’i kullanmalıdır.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let error {
                            Text(error).font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button(action: onConfirm) {
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("Apple TV’ye Aktar").frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedID == nil || isSubmitting || isLoading)
                    }
                    .padding()
                    .background(.bar)
                }
                .navigationTitle("Playlist Seç")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("İptal", action: onCancel)
                    }
                }
            }
        }
    }
#endif
