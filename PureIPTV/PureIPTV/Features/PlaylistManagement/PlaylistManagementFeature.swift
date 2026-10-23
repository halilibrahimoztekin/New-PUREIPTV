import ComposableArchitecture
import FactoryKit
import Foundation

@Reducer
public struct PlaylistManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public var playlists: [SavedPlaylist] = []
        public var activePlaylistID: UUID?
        public var playlistToDelete: SavedPlaylist?
        public var playlistBeingEdited: SavedPlaylist?
        public var userAgentDraft = ""
        public var channelZappingDelayDraft = 0
        public var userAgentValidationMessage: String?
        @Presents public var addPlaylist: AddPlaylistFeature.State?

        public init() {}
    }

    public enum Action: BindableAction {
        case onAppear
        case viewDidDisappear
        case binding(BindingAction<State>)
        case setActivePlaylist(UUID)
        case editPlaylistSettings(SavedPlaylist)
        case savePlaylistSettings
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
            case addPlaylistTapped
            case addPlaylistDidConnect
            case dismissed
        }
    }

    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.playlists = playlistRepository.getPlaylists()
                state.activePlaylistID = playlistRepository.getActivePlaylistID()
                return .none

            case .viewDidDisappear:
                return .none

            case .closeTapped:
                return .send(.delegate(.dismissed))

            case .binding:
                return .none

            case let .setActivePlaylist(id):
                guard state.activePlaylistID != id else { return .none }
                playlistRepository.setActivePlaylistID(id)
                state.activePlaylistID = id
                return .send(.delegate(.didChangeActivePlaylist))

            case let .editPlaylistSettings(playlist):
                state.playlistBeingEdited = playlist
                state.userAgentDraft = playlist.userAgentOverride ?? ""
                state.channelZappingDelayDraft = playlist.channelZappingDelayMilliseconds ?? 0
                state.userAgentValidationMessage = nil
                return .none

            case .savePlaylistSettings:
                guard let playlist = state.playlistBeingEdited else { return .none }
                let value = state.userAgentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard
                    value.utf8.count <= 512,
                    value.rangeOfCharacter(from: .controlCharacters) == nil
                else {
                    state.userAgentValidationMessage = "User-Agent 512 baytı aşamaz ve kontrol karakteri içeremez."
                    return .none
                }
                let updatedPlaylist = playlist
                    .replacingUserAgentOverride(value.isEmpty ? nil : value)
                    .replacingChannelZappingDelayMilliseconds(state.channelZappingDelayDraft)
                playlistRepository.updatePlaylist(updatedPlaylist)
                state.playlists = playlistRepository.getPlaylists()
                state.playlistBeingEdited = nil
                state.userAgentDraft = ""
                state.channelZappingDelayDraft = 0
                state.userAgentValidationMessage = nil
                guard
                    state.activePlaylistID == updatedPlaylist.id,
                    let config = updatedPlaylist.toPlaylistConfig()
                else { return .none }
                return .send(.delegate(.didUpdateActivePlaylistSettings(config)))

            case .cancelPlaylistSettings:
                state.playlistBeingEdited = nil
                state.userAgentDraft = ""
                state.channelZappingDelayDraft = 0
                state.userAgentValidationMessage = nil
                return .none

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
                playlistRepository.deletePlaylist(id: id)
                state.playlists = playlistRepository.getPlaylists()
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
                state.addPlaylist = nil
                return .none

            case .addPlaylist(.presented(.delegate(.didConnect))):
                state.playlists = playlistRepository.getPlaylists()
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
}
