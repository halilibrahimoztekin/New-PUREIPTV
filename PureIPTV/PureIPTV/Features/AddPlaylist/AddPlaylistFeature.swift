import ComposableArchitecture
import FactoryKit
import Foundation
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

// PlaylistType is defined in Core/Models/Playlist.swift

@Reducer
public struct AddPlaylistFeature {
    @ObservableState
    public struct State: Equatable {
        /// Playlist type selector
        public var playlistType: PlaylistType = .xtream

        // Xtream Codes fields
        public var serverURL: String = ""
        public var username: String = ""
        public var password: String = ""

        /// M3U field
        public var m3uURL: String = ""
        public var plexPIN: PlexSignInPIN?
        public var plexAccountToken: String?
        public var discoveredPlexServers: [PlexDiscoveredServer] = []
        public var selectedPlexServerID: String?

        // Smart Paste (Madde #77)
        public var detectedClipboardURL: String?
        public var isShowingClipboardBanner: Bool = false

        // UI state
        public var isLoading: Bool = false
        public var errorMessage: String?
        public var isPasswordVisible: Bool = false
        public var qrTransferFocusRequestID: UUID?

        /// Validation
        public var canConnect: Bool {
            switch playlistType {
            case .xtream:
                !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !password.isEmpty
            case .m3u:
                !m3uURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .plex:
                true
            case .emby:
                !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !password.isEmpty
            }
        }

        public init() {}
    }

    public enum Action: BindableAction {
        case onAppear
        case checkClipboard
        case clipboardURLDetected(String)
        case applyClipboardURL
        case dismissClipboardBanner

        case binding(BindingAction<State>)
        case playlistTypeChanged(PlaylistType)
        case connectTapped
        case qrTransferTapped
        case qrTransferRouteDidDismiss(UUID)
        case connectResponse(PlaylistType, Result<String, Error>)
        case plexPINCreated(PlexSignInPIN)
        case plexAccountTokenReceived(String)
        case plexServersLoaded(Result<[PlexDiscoveredServer], Error>)
        case selectPlexServer(String)
        case plexPlaylistSaveResult(serverURL: String, succeeded: Bool)
        case embyAuthenticationResponse(serverURL: String, result: Result<EmbyAuthenticatedSession, Error>)
        case embyPlaylistSaveResult(serverURL: String, succeeded: Bool)
        case playlistSaveFailed(PlaylistType)
        case playlistSaveSucceeded(type: PlaylistType, serverURL: String, username: String, password: String)
        case dismissError
        case togglePasswordVisibility

        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didConnect(serverURL: String, username: String, password: String)
            case didReceiveTransferredPlaylist
            case presentQRTransfer
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.mediaServerClient) var mediaServerClient
    @Dependency(\.hapticClient) var hapticClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let playlistRepository = playlistRepository
        let mediaServerClient = mediaServerClient
        let clock = clock

        BindingReducer()

        Reduce { state, action in
            switch action {
            case .onAppear, .checkClipboard:
                #if os(iOS)
                    return .run { send in
                        await MainActor.run {
                            if UIPasteboard.general.hasStrings, let string = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) {
                                if string.lowercased().hasPrefix("http"),
                                   string.lowercased().contains(".m3u") ||
                                   string.lowercased().contains(".m3u8") ||
                                   string.lowercased().contains("get.php") ||
                                   string.lowercased().contains("player_api.php")
                                {
                                    Task { @MainActor in
                                        send(.clipboardURLDetected(string))
                                    }
                                }
                            }
                        }
                    }
                #else
                    return .none
                #endif

            case let .clipboardURLDetected(url):
                state.detectedClipboardURL = url
                state.isShowingClipboardBanner = true
                return .none

            case .applyClipboardURL:
                if let url = state.detectedClipboardURL {
                    state.m3uURL = url
                    state.playlistType = .m3u
                    state.isShowingClipboardBanner = false
                    state.detectedClipboardURL = nil
                }
                return .none

            case .dismissClipboardBanner:
                state.isShowingClipboardBanner = false
                state.detectedClipboardURL = nil
                return .none

            case .binding:
                // Clear error on any field change
                state.errorMessage = nil
                return .none

            case let .playlistTypeChanged(type):
                state.playlistType = type
                state.errorMessage = nil
                state.isLoading = false
                state.plexPIN = nil
                state.plexAccountToken = nil
                state.discoveredPlexServers = []
                state.selectedPlexServerID = nil
                return .merge(
                    .cancel(id: "AddPlaylistFeature.plexPinPolling"),
                    .cancel(id: "AddPlaylistFeature.authentication")
                )

            case .togglePasswordVisibility:
                state.isPasswordVisible.toggle()
                return .none

            case .qrTransferTapped:
                return .send(.delegate(.presentQRTransfer))

            case let .qrTransferRouteDidDismiss(presentationID):
                state.qrTransferFocusRequestID = presentationID
                return .none

            case .connectTapped:
                guard !state.isLoading, state.canConnect else { return .none }
                state.isLoading = true
                state.errorMessage = nil

                switch state.playlistType {
                case .plex:
                    if let selectedPlexServerID = state.selectedPlexServerID,
                       let server = state.discoveredPlexServers.first(where: { $0.id == selectedPlexServerID }),
                       let accountToken = state.plexAccountToken
                    {
                        let playlist = SavedPlaylist(
                            name: server.name,
                            type: .plex,
                            serverURL: server.baseURL.absoluteString,
                            mediaServerCredentials: MediaServerCredentials(
                                serverID: server.id,
                                accessToken: server.accessToken,
                                accountToken: accountToken
                            )
                        )
                        let serverURL = server.baseURL.absoluteString
                        return .run { send in
                            guard !Task.isCancelled else { return }
                            await send(.plexPlaylistSaveResult(
                                serverURL: serverURL,
                                succeeded: playlistRepository.addPlaylist(playlist)
                            ))
                        }
                        .cancellable(id: "AddPlaylistFeature.authentication", cancelInFlight: true)
                    }
                    state.isLoading = true
                    state.errorMessage = nil
                    state.plexPIN = nil
                    return .run { send in
                        do {
                            let pin = try await mediaServerClient.createPlexPIN()
                            await send(.plexPINCreated(pin))
                            for _ in 0 ..< 120 {
                                try await clock.sleep(for: .seconds(3))
                                try Task.checkCancellation()
                                if let token = try? await mediaServerClient.pollPlexPIN(pin.id, pin.code),
                                   !token.isEmpty
                                {
                                    await send(.plexAccountTokenReceived(token))
                                    return
                                }
                            }
                            await send(.connectResponse(.plex, .failure(NetworkError.underlying(description: "Plex oturum açma kodunun süresi doldu."))))
                        } catch is CancellationError {
                            return
                        } catch {
                            await send(.connectResponse(.plex, .failure(error)))
                        }
                    }
                    .cancellable(id: "AddPlaylistFeature.plexPinPolling", cancelInFlight: true)
                    .cancellable(id: "AddPlaylistFeature.authentication", cancelInFlight: true)

                case .xtream:
                    let rawURL = state.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    let username = state.username.trimmingCharacters(in: .whitespacesAndNewlines)
                    let password = state.password

                    return .run { send in
                        await FeedbackReportManager.shared.clearConnectionFailure()
                        do {
                            guard let url = URL(string: rawURL) else {
                                throw NetworkError.invalidURL
                            }
                            let config = PlaylistConfig(type: .xtream, serverURL: url, username: username, password: password)
                            try await iptvClient.authenticate(config)
                            await send(.connectResponse(.xtream, .success("Xtream Playlist")))
                        } catch {
                            guard !Task.isCancelled else { return }
                            await FeedbackReportManager.shared.recordConnectionFailure(playlistType: .xtream, error: error)
                            await send(.connectResponse(.xtream, .failure(error)))
                        }
                    }.cancellable(id: "AddPlaylistFeature.authentication", cancelInFlight: true)

                case .m3u:
                    let m3uURLString = state.m3uURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    return .run { send in
                        await FeedbackReportManager.shared.clearConnectionFailure()
                        do {
                            guard let url = URL(string: m3uURLString) else {
                                throw NetworkError.invalidURL
                            }
                            let config = PlaylistConfig(type: .m3u, m3uURL: url)
                            try await iptvClient.authenticate(config)
                            await send(.connectResponse(.m3u, .success("M3U Playlist")))
                        } catch {
                            guard !Task.isCancelled else { return }
                            await FeedbackReportManager.shared.recordConnectionFailure(playlistType: .m3u, error: error)
                            await send(.connectResponse(.m3u, .failure(error)))
                        }
                    }.cancellable(id: "AddPlaylistFeature.authentication", cancelInFlight: true)

                case .emby:
                    state.isLoading = true
                    state.errorMessage = nil
                    let rawURL = state.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    let username = state.username.trimmingCharacters(in: .whitespacesAndNewlines)
                    let password = state.password
                    guard let url = URL(string: rawURL), url.scheme?.lowercased() == "https" else {
                        state.isLoading = false
                        state.errorMessage = "Emby bağlantısı için HTTPS gereklidir; parolanız HTTP üzerinden gönderilemez."
                        return .none
                    }
                    return .run { send in
                        await FeedbackReportManager.shared.clearConnectionFailure()
                        do {
                            let session = try await mediaServerClient.authenticateEmby(url, username, password)
                            await send(.embyAuthenticationResponse(serverURL: rawURL, result: .success(session)))
                        } catch {
                            guard !Task.isCancelled else { return }
                            await FeedbackReportManager.shared.recordConnectionFailure(playlistType: .emby, error: error)
                            await send(.embyAuthenticationResponse(serverURL: rawURL, result: .failure(error)))
                        }
                    }.cancellable(id: "AddPlaylistFeature.authentication", cancelInFlight: true)
                }

            case let .plexPINCreated(pin):
                guard state.playlistType == .plex else { return .none }
                state.plexPIN = pin
                return .none

            case let .plexAccountTokenReceived(token):
                guard state.playlistType == .plex else { return .none }
                state.plexAccountToken = token
                return .run { send in
                    await send(.plexServersLoaded(Result { try await mediaServerClient.discoverPlexServers(token) }))
                }.cancellable(id: "AddPlaylistFeature.authentication", cancelInFlight: true)

            case let .plexServersLoaded(.success(servers)):
                guard state.playlistType == .plex else { return .none }
                state.isLoading = false
                state.discoveredPlexServers = servers
                state.selectedPlexServerID = servers.first?.id
                state.plexPIN = nil
                if servers.isEmpty {
                    state.errorMessage = "Plex hesabında erişilebilir medya sunucusu bulunamadı."
                }
                return .cancel(id: "AddPlaylistFeature.plexPinPolling")

            case let .plexServersLoaded(.failure(error)):
                guard state.playlistType == .plex else { return .none }
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case let .selectPlexServer(serverID):
                guard state.playlistType == .plex else { return .none }
                guard state.discoveredPlexServers.contains(where: { $0.id == serverID }) else { return .none }
                state.selectedPlexServerID = serverID
                return .none

            case let .plexPlaylistSaveResult(serverURL, succeeded):
                guard state.playlistType == .plex else { return .none }
                state.isLoading = false
                guard succeeded else {
                    state.errorMessage = "Plex sunucusu güvenli olarak kaydedilemedi."
                    return .none
                }
                return .send(.delegate(.didConnect(serverURL: serverURL, username: "", password: "")))

            case let .embyAuthenticationResponse(serverURL, .success(session)):
                guard state.playlistType == .emby else { return .none }
                let rawURL = serverURL
                let playlist = SavedPlaylist(
                    name: session.userName,
                    type: .emby,
                    serverURL: rawURL,
                    mediaServerCredentials: MediaServerCredentials(
                        serverID: session.serverID,
                        userID: session.userID,
                        accessToken: session.accessToken
                    )
                )
                return .run { send in
                    guard !Task.isCancelled else { return }
                    let succeeded = playlistRepository.addPlaylist(playlist)
                    guard !Task.isCancelled else { return }
                    await send(.embyPlaylistSaveResult(serverURL: rawURL, succeeded: succeeded))
                }
                .cancellable(id: "AddPlaylistFeature.authentication", cancelInFlight: true)

            case let .embyPlaylistSaveResult(serverURL, succeeded):
                guard state.playlistType == .emby else { return .none }
                state.isLoading = false
                guard succeeded else {
                    state.errorMessage = "Emby sunucusu güvenli olarak kaydedilemedi."
                    return .none
                }
                return .send(.delegate(.didConnect(serverURL: serverURL, username: "", password: "")))

            case let .embyAuthenticationResponse(_, .failure(error)):
                guard state.playlistType == .emby else { return .none }
                state.isLoading = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? "Emby sunucusuna bağlanılamadı."
                return .none

            case let .connectResponse(type, .success(message)):
                guard type == state.playlistType else { return .none }
                let rawURL = state.playlistType == .xtream ? state.serverURL.trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let username = state.playlistType == .xtream ? state.username.trimmingCharacters(in: .whitespacesAndNewlines) : ""
                let password = state.playlistType == .xtream ? state.password : ""
                let m3uURL = state.playlistType == .m3u ? state.m3uURL.trimmingCharacters(in: .whitespacesAndNewlines) : ""

                // Save to iCloud Keychain
                let playlist = SavedPlaylist(
                    name: message,
                    type: state.playlistType,
                    serverURL: rawURL.isEmpty ? nil : rawURL,
                    username: username.isEmpty ? nil : username,
                    password: password.isEmpty ? nil : password,
                    m3uURL: m3uURL.isEmpty ? nil : m3uURL
                )

                return .run { send in
                    guard !Task.isCancelled else { return }
                    guard playlistRepository.addPlaylist(playlist) else {
                        guard !Task.isCancelled else { return }
                        await send(.playlistSaveFailed(type))
                        return
                    }
                    guard !Task.isCancelled else { return }
                    await send(.playlistSaveSucceeded(
                        type: type,
                        serverURL: rawURL,
                        username: username,
                        password: password
                    ))
                }.cancellable(id: "AddPlaylistFeature.authentication", cancelInFlight: true)

            case let .playlistSaveFailed(type):
                guard type == state.playlistType else { return .none }
                state.isLoading = false
                state.errorMessage = "Playlist bu cihazda güvenli olarak kaydedilemedi. iCloud Keychain ayarlarını kontrol edip tekrar deneyin."
                return .none

            case let .playlistSaveSucceeded(type, serverURL, username, password):
                guard type == state.playlistType else { return .none }
                state.isLoading = false
                return .send(.delegate(.didConnect(serverURL: serverURL, username: username, password: password)))

            case let .connectResponse(type, .failure(error)):
                guard type == state.playlistType else { return .none }
                state.isLoading = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
