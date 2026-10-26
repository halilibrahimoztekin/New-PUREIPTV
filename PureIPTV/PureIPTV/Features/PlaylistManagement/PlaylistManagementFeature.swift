import ComposableArchitecture
import FactoryKit
import Foundation

@Reducer
public struct PlaylistManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public enum PlaylistStoreStatus: Equatable {
            case available
            case empty
            case unavailable
        }

        public enum PINFlow: Equatable {
            case configure(UUID)
            case activate(UUID)
            case remove(UUID)
            case startup(UUID)
        }

        public var playlists: [SavedPlaylist] = []
        public var playlistStoreStatus: PlaylistStoreStatus = .empty
        public var activePlaylistID: UUID?
        public var lockedPlaylistIDs: Set<UUID> = []
        public var unlockedPlaylistIDs: Set<UUID> = []
        public var startupUnlockPlaylistID: UUID?
        public var pinFlow: PINFlow?
        public var playlistPIN = ""
        public var playlistPINConfirmation = ""
        public var playlistPINError: String?
        public var playlistToDelete: SavedPlaylist?
        public var playlistBeingEdited: SavedPlaylist?
        public var userAgentDraft = ""
        public var channelZappingDelayDraft = 0
        public var serverURLDraft = ""
        public var usernameDraft = ""
        public var passwordDraft = ""
        public var m3uURLDraft = ""
        public var playlistValidationMessage: String?
        public var isRefreshingPlaylist = false
        @Presents public var addPlaylist: AddPlaylistFeature.State?

        public init(startupUnlockPlaylistID: UUID? = nil) {
            self.startupUnlockPlaylistID = startupUnlockPlaylistID
        }
    }

    public enum Action: BindableAction {
        case onAppear
        case refreshPlaylistStore
        case viewDidDisappear
        case binding(BindingAction<State>)
        case setActivePlaylist(UUID)
        case playlistLockTapped(UUID)
        case playlistPINChanged(String)
        case playlistPINConfirmationChanged(String)
        case submitPlaylistPIN
        case cancelPlaylistPIN
        case editPlaylistSettings(SavedPlaylist)
        case savePlaylistSettings
        case m3uPlaylistRefreshSucceeded(SavedPlaylist)
        case m3uPlaylistRefreshFailed(String)
        case cancelPlaylistSettings
        case deletePlaylist(UUID)
        case confirmDeletePlaylist(SavedPlaylist)
        case cancelDeletePlaylist
        case deletePlaylistConfirmed
        case addPlaylistButtonTapped
        case closeAddPlaylistTapped
        case addPlaylist(PresentationAction<AddPlaylistFeature.Action>)
        case closeTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case didChangeActivePlaylist
            case didUpdateActivePlaylistSettings(PlaylistConfig)
            case didChangePlaylistLock(UUID, isLocked: Bool)
            case didUnlockPlaylist(UUID)
            case didUnlockStartupPlaylist(UUID)
            case addPlaylistTapped
            case addPlaylistDidConnect
            case dismissed
        }
    }

    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.dismiss) var dismiss
    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.parentalControlClient) var parentalControlClient

    public init() {}

    private static func isValidHTTPURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty
        else { return false }
        return true
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                Self.refreshPlaylistStore(state: &state, repository: playlistRepository)
                state.activePlaylistID = playlistRepository.getActivePlaylistID()
                state.lockedPlaylistIDs = Set(state.playlists.filter { parentalControlClient.isPlaylistLocked($0.id) }.map(\.id))
                if let startupID = state.startupUnlockPlaylistID,
                   state.lockedPlaylistIDs.contains(startupID)
                {
                    state.pinFlow = .startup(startupID)
                    state.playlistPIN = ""
                    state.playlistPINError = nil
                }
                return .none

            case .refreshPlaylistStore:
                Self.refreshPlaylistStore(state: &state, repository: playlistRepository)
                return .none

            case .viewDidDisappear:
                state.isRefreshingPlaylist = false
                return .cancel(id: "PlaylistManagementFeature.m3uRefresh")

            case .closeTapped:
                guard state.startupUnlockPlaylistID == nil else { return .none }
                return .send(.delegate(.dismissed))

            case .binding:
                return .none

            case let .setActivePlaylist(id):
                guard state.activePlaylistID != id else { return .none }
                if state.lockedPlaylistIDs.contains(id), !state.unlockedPlaylistIDs.contains(id) {
                    state.pinFlow = .activate(id)
                    state.playlistPIN = ""
                    state.playlistPINConfirmation = ""
                    state.playlistPINError = nil
                    return .none
                }
                playlistRepository.setActivePlaylistID(id)
                state.activePlaylistID = id
                return .send(.delegate(.didChangeActivePlaylist))

            case let .playlistLockTapped(id):
                guard state.playlists.contains(where: { $0.id == id }) else { return .none }
                state.pinFlow = state.lockedPlaylistIDs.contains(id) ? .remove(id) : .configure(id)
                state.playlistPIN = ""
                state.playlistPINConfirmation = ""
                state.playlistPINError = nil
                return .none

            case let .playlistPINChanged(input):
                state.playlistPIN = String(input.filter { $0 >= "0" && $0 <= "9" }.prefix(4))
                state.playlistPINError = nil
                return .none

            case let .playlistPINConfirmationChanged(input):
                state.playlistPINConfirmation = String(input.filter { $0 >= "0" && $0 <= "9" }.prefix(4))
                state.playlistPINError = nil
                return .none

            case .submitPlaylistPIN:
                guard let flow = state.pinFlow else { return .none }
                let pin = state.playlistPIN
                switch flow {
                case let .configure(id):
                    guard pin.count == 4 else {
                        state.playlistPINError = "PIN 4 rakamdan oluşmalı."
                        return .none
                    }
                    guard pin == state.playlistPINConfirmation else {
                        state.playlistPINError = "PIN değerleri eşleşmiyor."
                        return .none
                    }
                    guard parentalControlClient.setPlaylistPIN(id, pin) else {
                        state.playlistPINError = "PIN güvenli olarak kaydedilemedi."
                        return .none
                    }
                    parentalControlClient.clearPlaylistPINFailures(id)
                    state.lockedPlaylistIDs.insert(id)
                    state.pinFlow = nil
                    state.playlistPIN = ""
                    state.playlistPINConfirmation = ""
                    return .send(.delegate(.didChangePlaylistLock(id, isLocked: true)))

                case let .activate(id), let .startup(id), let .remove(id):
                    let remainingSeconds = parentalControlClient.playlistPINLockoutRemainingSeconds(id)
                    guard remainingSeconds == 0 else {
                        state.playlistPINError = "Çok fazla hatalı deneme. \(remainingSeconds) saniye sonra tekrar deneyin."
                        state.playlistPIN = ""
                        return .none
                    }
                    guard pin.count == 4, parentalControlClient.verifyPlaylistPIN(id, pin) else {
                        let lockoutSeconds = parentalControlClient.recordPlaylistPINFailure(id)
                        state.playlistPINError = "PIN yanlış. Tekrar deneyin."
                        if lockoutSeconds > 0 {
                            state.playlistPINError = "Çok fazla hatalı deneme. \(lockoutSeconds) saniye sonra tekrar deneyin."
                        }
                        state.playlistPIN = ""
                        return .none
                    }
                    parentalControlClient.clearPlaylistPINFailures(id)
                    state.playlistPIN = ""
                    switch flow {
                    case .activate:
                        state.unlockedPlaylistIDs.insert(id)
                        playlistRepository.setActivePlaylistID(id)
                        state.activePlaylistID = id
                        state.pinFlow = nil
                        return .send(.delegate(.didUnlockPlaylist(id)))
                    case .startup:
                        state.unlockedPlaylistIDs.insert(id)
                        state.pinFlow = nil
                        state.startupUnlockPlaylistID = nil
                        return .send(.delegate(.didUnlockStartupPlaylist(id)))
                    case .remove:
                        guard parentalControlClient.setPlaylistPIN(id, nil) else {
                            state.playlistPINError = "PIN kilidi kaldırılamadı."
                            return .none
                        }
                        state.lockedPlaylistIDs.remove(id)
                        state.unlockedPlaylistIDs.remove(id)
                        state.pinFlow = nil
                        return .send(.delegate(.didChangePlaylistLock(id, isLocked: false)))
                    case .configure:
                        return .none
                    }
                }

            case .cancelPlaylistPIN:
                if case .startup = state.pinFlow {
                    return .none
                }
                state.pinFlow = nil
                state.playlistPIN = ""
                state.playlistPINConfirmation = ""
                state.playlistPINError = nil
                return .none

            case let .editPlaylistSettings(playlist):
                state.playlistBeingEdited = playlist
                state.userAgentDraft = playlist.userAgentOverride ?? ""
                state.channelZappingDelayDraft = playlist.channelZappingDelayMilliseconds ?? 0
                state.serverURLDraft = playlist.serverURL ?? ""
                state.usernameDraft = playlist.username ?? ""
                state.passwordDraft = playlist.password ?? ""
                state.m3uURLDraft = playlist.m3uURL ?? ""
                state.playlistValidationMessage = nil
                return .none

            case .savePlaylistSettings:
                guard !state.isRefreshingPlaylist, let playlist = state.playlistBeingEdited else { return .none }
                let value = state.userAgentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard
                    value.utf8.count <= 512,
                    value.rangeOfCharacter(from: .controlCharacters) == nil
                else {
                    state.playlistValidationMessage = "User-Agent 512 baytı aşamaz ve kontrol karakteri içeremez."
                    return .none
                }
                let serverURL = state.serverURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                let username = state.usernameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                let m3uURL = state.m3uURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if playlist.type == .xtream {
                    guard Self.isValidHTTPURL(serverURL), !username.isEmpty, !state.passwordDraft.isEmpty else {
                        state.playlistValidationMessage = "Xtream adresi, kullanıcı adı ve parola geçerli olmalı."
                        return .none
                    }
                } else if !Self.isValidHTTPURL(m3uURL) {
                    state.playlistValidationMessage = "M3U adresi geçerli bir HTTP veya HTTPS URL olmalı."
                    return .none
                }
                let updatedPlaylist = playlist
                    .replacingConnection(
                        serverURL: playlist.type == .xtream ? serverURL : nil,
                        username: playlist.type == .xtream ? username : nil,
                        password: playlist.type == .xtream ? state.passwordDraft : nil,
                        m3uURL: playlist.type == .m3u ? m3uURL : nil
                    )
                    .replacingUserAgentOverride(value.isEmpty ? nil : value)
                    .replacingChannelZappingDelayMilliseconds(state.channelZappingDelayDraft)
                if updatedPlaylist.type == .m3u, let config = updatedPlaylist.toPlaylistConfig() {
                    state.isRefreshingPlaylist = true
                    state.playlistValidationMessage = nil
                    return .run { [iptvClient] send in
                        do {
                            try await iptvClient.authenticate(config)
                            await send(.m3uPlaylistRefreshSucceeded(updatedPlaylist))
                        } catch is CancellationError {
                            return
                        } catch {
                            await send(.m3uPlaylistRefreshFailed(error.localizedDescription))
                        }
                    }.cancellable(id: "PlaylistManagementFeature.m3uRefresh", cancelInFlight: true)
                }
                return .send(.m3uPlaylistRefreshSucceeded(updatedPlaylist))

            case let .m3uPlaylistRefreshSucceeded(updatedPlaylist):
                state.isRefreshingPlaylist = false
                guard playlistRepository.updatePlaylist(updatedPlaylist) else {
                    state.playlistValidationMessage = "Ayarlar güvenli olarak kaydedilemedi. iCloud Keychain erişimini kontrol edip tekrar deneyin."
                    return .none
                }
                Self.refreshPlaylistStore(state: &state, repository: playlistRepository)
                state.playlistBeingEdited = nil
                state.userAgentDraft = ""
                state.channelZappingDelayDraft = 0
                state.serverURLDraft = ""
                state.usernameDraft = ""
                state.passwordDraft = ""
                state.m3uURLDraft = ""
                state.playlistValidationMessage = nil
                guard
                    state.activePlaylistID == updatedPlaylist.id,
                    let config = updatedPlaylist.toPlaylistConfig()
                else { return .none }
                return .send(.delegate(.didUpdateActivePlaylistSettings(config)))

            case let .m3uPlaylistRefreshFailed(message):
                state.isRefreshingPlaylist = false
                state.playlistValidationMessage = "Playlist yenilenemedi; mevcut ayarlar ve katalog korundu. Ayrıntı: \(message)"
                return .none

            case .cancelPlaylistSettings:
                state.isRefreshingPlaylist = false
                state.playlistBeingEdited = nil
                state.userAgentDraft = ""
                state.channelZappingDelayDraft = 0
                state.serverURLDraft = ""
                state.usernameDraft = ""
                state.passwordDraft = ""
                state.m3uURLDraft = ""
                state.playlistValidationMessage = nil
                return .cancel(id: "PlaylistManagementFeature.m3uRefresh")

            case let .confirmDeletePlaylist(playlist):
                state.playlistToDelete = playlist
                return .none

            case .cancelDeletePlaylist:
                state.playlistToDelete = nil
                return .none

            case .deletePlaylistConfirmed:
                guard let playlist = state.playlistToDelete else { return .none }
                state.playlistToDelete = nil
                return .send(.deletePlaylist(playlist.id))

            case let .deletePlaylist(id):
                guard playlistRepository.deletePlaylist(id: id) else {
                    state.playlistValidationMessage = "Playlist silinemedi; kayıt korunuyor. iCloud Keychain erişimini kontrol edin."
                    return .none
                }
                _ = parentalControlClient.setPlaylistPIN(id, nil)
                parentalControlClient.clearPlaylistPINFailures(id)
                Self.refreshPlaylistStore(state: &state, repository: playlistRepository)
                if state.activePlaylistID == id {
                    let newActive = state.playlists.first?.id
                    playlistRepository.setActivePlaylistID(newActive)
                    state.activePlaylistID = newActive
                    return .send(.delegate(.didChangeActivePlaylist))
                }
                return .none

            case .addPlaylistButtonTapped:
                state.addPlaylist = AddPlaylistFeature.State()
                return .none

            case .closeAddPlaylistTapped:
                guard state.startupUnlockPlaylistID == nil else { return .none }
                state.addPlaylist = nil
                return .none

            case .addPlaylist(.presented(.delegate(.didConnect))),
                 .addPlaylist(.presented(.delegate(.didReceiveTransferredPlaylist))):
                Self.refreshPlaylistStore(state: &state, repository: playlistRepository)
                state.activePlaylistID = playlistRepository.getActivePlaylistID()
                state.addPlaylist = nil
                return .send(.delegate(.addPlaylistDidConnect))

            case .addPlaylist:
                return .none

            case .delegate(.addPlaylistTapped):
                state.addPlaylist = AddPlaylistFeature.State()
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$addPlaylist, action: \.addPlaylist) {
            AddPlaylistFeature()
        }
    }

    private static func refreshPlaylistStore(state: inout State, repository: PlaylistRepository) {
        switch repository.readPlaylists() {
        case let .loaded(playlists):
            state.playlists = playlists
            state.playlistStoreStatus = .available
        case .notFound:
            state.playlists = []
            state.playlistStoreStatus = .empty
        case .failed:
            state.playlistStoreStatus = .unavailable
        }
    }
}
