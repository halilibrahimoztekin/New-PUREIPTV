import ComposableArchitecture
import FactoryKit
import Foundation

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

        // UI state
        public var isLoading: Bool = false
        public var errorMessage: String?
        public var isPasswordVisible: Bool = false

        /// Validation
        public var canConnect: Bool {
            switch playlistType {
            case .xtream:
                !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !password.isEmpty
            case .m3u:
                !m3uURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case playlistTypeChanged(PlaylistType)
        case connectTapped
        case connectResponse(Result<String, Error>)
        case dismissError
        case togglePasswordVisibility
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didConnect(serverURL: String, username: String, password: String)
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.hapticClient) var hapticClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let playlistRepository = playlistRepository

        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                // Clear error on any field change
                state.errorMessage = nil
                return .none

            case let .playlistTypeChanged(type):
                state.playlistType = type
                state.errorMessage = nil
                return .none

            case .togglePasswordVisibility:
                state.isPasswordVisible.toggle()
                return .none

            case .connectTapped:
                guard state.canConnect else { return .none }
                state.isLoading = true
                state.errorMessage = nil

                switch state.playlistType {
                case .xtream:
                    let rawURL = state.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    let username = state.username.trimmingCharacters(in: .whitespacesAndNewlines)
                    let password = state.password

                    return .run { send in
                        do {
                            guard let url = URL(string: rawURL) else {
                                throw NetworkError.invalidURL
                            }
                            let config = PlaylistConfig(type: .xtream, serverURL: url, username: username, password: password)
                            try await iptvClient.authenticate(config)
                            await send(.connectResponse(.success("Xtream Playlist")))
                        } catch {
                            await send(.connectResponse(.failure(error)))
                        }
                    }

                case .m3u:
                    let m3uURLString = state.m3uURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    return .run { send in
                        do {
                            guard let url = URL(string: m3uURLString) else {
                                throw NetworkError.invalidURL
                            }
                            let config = PlaylistConfig(type: .m3u, m3uURL: url)
                            try await iptvClient.authenticate(config)
                            await send(.connectResponse(.success("M3U Playlist")))
                        } catch {
                            await send(.connectResponse(.failure(error)))
                        }
                    }
                }

            case let .connectResponse(.success(message)):
                state.isLoading = false
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
                    playlistRepository.addPlaylist(playlist)
                    await send(.delegate(.didConnect(serverURL: rawURL, username: username, password: password)))
                }

            case let .connectResponse(.failure(error)):
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
