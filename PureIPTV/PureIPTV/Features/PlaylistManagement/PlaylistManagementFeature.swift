import ComposableArchitecture
import FactoryKit
import Foundation

@Reducer
public struct PlaylistManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public var playlists: [SavedPlaylist] = []
        public var activePlaylistID: UUID?
        @Presents public var addPlaylist: AddPlaylistFeature.State?

        public init() {}
    }

    public enum Action: BindableAction {
        case onAppear
        case viewDidDisappear
        case binding(BindingAction<State>)
        case setActivePlaylist(UUID)
        case deletePlaylist(UUID)
        case addPlaylist(PresentationAction<AddPlaylistFeature.Action>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didChangeActivePlaylist
            case addPlaylistTapped
            case dismissed
        }
    }

    @Injected(\.playlistRepository) var playlistRepository

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
                return .send(.delegate(.dismissed))

            case .binding:
                return .none

            case let .setActivePlaylist(id):
                playlistRepository.setActivePlaylistID(id)
                state.activePlaylistID = id
                return .send(.delegate(.didChangeActivePlaylist))

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

            case .addPlaylist(.presented(.connectResponse(.success))):
                state.playlists = playlistRepository.getPlaylists()
                state.activePlaylistID = playlistRepository.getActivePlaylistID()
                state.addPlaylist = nil
                return .none

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
