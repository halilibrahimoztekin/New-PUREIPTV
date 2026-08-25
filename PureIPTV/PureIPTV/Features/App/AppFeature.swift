import ComposableArchitecture
import Factory
import Foundation
import XCoordinator

@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public var splash = SplashFeature.State()
        public var addPlaylist = AddPlaylistFeature.State()
        public var home: HomeFeature.State?
        @Presents public var player: PlayerFeature.State?
        @Presents public var seriesDetail: SeriesDetailFeature.State?
        @Presents public var vodDetail: VODDetailFeature.State?

        public var splashIsActive = true
        public var isOnboarded = false

        public init() {}
    }

    public enum Action {
        case splash(SplashFeature.Action)
        case addPlaylist(AddPlaylistFeature.Action)
        case home(HomeFeature.Action)
        case player(PresentationAction<PlayerFeature.Action>)
        case seriesDetail(PresentationAction<SeriesDetailFeature.Action>)
        case vodDetail(PresentationAction<VODDetailFeature.Action>)
    }

    @Injected(\.playlistRepository) var playlistRepository
    @Injected(\.appCoordinator) var appCoordinator

    public init() {}

    public var body: some Reducer<State, Action> {
        let playlistRepository = self.playlistRepository
        let appCoordinator = self.appCoordinator

        Scope(state: \.splash, action: \.splash) {
            SplashFeature()
        }

        Scope(state: \.addPlaylist, action: \.addPlaylist) {
            AddPlaylistFeature()
        }

        .ifLet(\.home, action: \.home) {
            HomeFeature()
        }

        .ifLet(\.$player, action: \.player) {
            PlayerFeature()
        }

        Reduce { state, action in
            switch action {
            // ── Splash ───────────────────────────────────────────────
            case .splash(.splashDidFinish):
                state.splashIsActive = false

                let savedPlaylists = playlistRepository.getPlaylists()
                if let playlist = savedPlaylists.first, playlist.type == .xtream,
                   let serverURL = playlist.serverURL,
                   let username = playlist.username,
                   let password = playlist.password
                {
                    state.home = HomeFeature.State(
                        serverURL: serverURL,
                        username: username,
                        password: password
                    )
                    state.isOnboarded = true
                    return .run { _ in
                        await MainActor.run { appCoordinator.trigger(.home) }
                    }
                } else {
                    return .run { _ in
                        await MainActor.run { appCoordinator.trigger(.login) }
                    }
                }

            case .splash:
                return .none

            // ── AddPlaylist ──────────────────────────────────────────
            case let .addPlaylist(.delegate(.didConnect(serverURL, username, password))):
                state.home = HomeFeature.State(
                    serverURL: serverURL,
                    username: username,
                    password: password
                )
                state.isOnboarded = true
                return .run { _ in
                    await MainActor.run { appCoordinator.trigger(.home) }
                }

            case .addPlaylist:
                return .none

            // ── Home ─────────────────────────────────────────────────
            case let .home(.delegate(.didSelectChannel(channel))):
                guard let streamURL = channel.streamURL else { return .none }
                state.player = PlayerFeature.State(item: .init(
                    id: channel.id,
                    title: channel.title,
                    streamURL: streamURL
                ))
                return .run { _ in
                    await MainActor.run { appCoordinator.trigger(.player) }
                }

            case let .home(.delegate(.didSelectVOD(vod))):
                if let homeState = state.home {
                    state.vodDetail = VODDetailFeature.State(
                        vod: vod,
                        serverURL: homeState.serverURL,
                        username: homeState.username,
                        password: homeState.password
                    )
                    return .run { _ in
                        await MainActor.run { appCoordinator.trigger(.vodDetail) }
                    }
                }
                return .none

            case let .home(.delegate(.didSelectSeries(series))):
                if let homeState = state.home {
                    state.seriesDetail = SeriesDetailFeature.State(
                        series: series,
                        serverURL: homeState.serverURL,
                        username: homeState.username,
                        password: homeState.password
                    )
                    return .run { _ in
                        await MainActor.run { appCoordinator.trigger(.seriesDetail) }
                    }
                }
                return .none

            case .home:
                return .none

            // ── Series Detail ─────────────────────────────────────────
            case let .seriesDetail(.presented(.delegate(.didSelectEpisode(playable)))):
                state.player = PlayerFeature.State(item: playable)
                return .run { _ in
                    await MainActor.run { appCoordinator.trigger(.player) }
                }

            case .seriesDetail(.presented(.delegate(.close))):
                state.seriesDetail = nil
                return .none

            case .seriesDetail:
                return .none

            // ── Player ───────────────────────────────────────────────
            case .player(.presented(.delegate(.didClose))):
                state.player = nil
                return .none

            case .player:
                return .none

            // ── VOD Detail ───────────────────────────────────────────
            case let .vodDetail(.presented(.delegate(.didSelectPlay(playable)))):
                state.player = PlayerFeature.State(item: playable)
                return .run { _ in
                    await MainActor.run { appCoordinator.trigger(.player) }
                }

            case .vodDetail(.presented(.delegate(.close))):
                state.vodDetail = nil
                return .none

            case .vodDetail:
                return .none
            }
        }
        .ifLet(\.$seriesDetail, action: \.seriesDetail) {
            SeriesDetailFeature()
        }
        .ifLet(\.$vodDetail, action: \.vodDetail) {
            VODDetailFeature()
        }
    }
}
