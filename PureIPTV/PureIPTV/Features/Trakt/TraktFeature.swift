import ComposableArchitecture
import Foundation

private let pollTimerCancelID = "TraktFeature.pollTimer"

@Reducer
public struct TraktFeature {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var isAuthenticated: Bool = false
        public var user: TraktUser?
        public var isAutoScrobbleEnabled: Bool = true
        public var deviceCodeInfo: TraktDeviceCode?
        public var isAuthorizing: Bool = false
        public var authError: String?
        public var watchlist: IdentifiedArrayOf<TraktWatchlistItem> = []
        public var playbackItems: IdentifiedArrayOf<TraktPlaybackProgressItem> = []
        public var isLoading: Bool = false

        public init() {}
    }

    public enum Action: Sendable, Equatable {
        case onAppear
        case startDeviceAuth
        case deviceCodeResponse(TaskResult<TraktDeviceCode>)
        case pollDeviceToken
        case pollTokenResponse(TaskResult<TraktTokenResponse?>)
        case cancelAuth
        case fetchWatchlist
        case watchlistResponse(TaskResult<[TraktWatchlistItem]>)
        case fetchPlaybackProgress
        case playbackProgressResponse(TaskResult<[TraktPlaybackProgressItem]>)
        case toggleAutoScrobble(Bool)
        case logout
    }

    @Dependency(\.traktClient) var traktClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isAuthenticated = traktClient.isAuthenticated()
                state.user = traktClient.currentUser()
                state.isAutoScrobbleEnabled = traktClient.isAutoScrobbleEnabled()

                guard state.isAuthenticated else { return .none }
                return .merge(
                    .send(.fetchWatchlist),
                    .send(.fetchPlaybackProgress)
                )

            case .startDeviceAuth:
                state.isAuthorizing = true
                state.authError = nil
                state.deviceCodeInfo = nil

                return .run { send in
                    await send(.deviceCodeResponse(TaskResult {
                        try await traktClient.generateDeviceCode()
                    }))
                }

            case let .deviceCodeResponse(.success(code)):
                state.deviceCodeInfo = code
                let pollInterval = max(code.interval, 5)

                return .run { send in
                    try await clock.sleep(for: .seconds(pollInterval))
                    await send(.pollDeviceToken)
                }
                .cancellable(id: pollTimerCancelID, cancelInFlight: true)

            case let .deviceCodeResponse(.failure(error)):
                state.isAuthorizing = false
                state.authError = error.localizedDescription
                return .none

            case .pollDeviceToken:
                guard state.isAuthorizing, let code = state.deviceCodeInfo else {
                    return .cancel(id: pollTimerCancelID)
                }

                return .run { send in
                    await send(.pollTokenResponse(TaskResult {
                        try await traktClient.pollDeviceToken(code.deviceCode)
                    }))
                }

            case let .pollTokenResponse(.success(maybeToken)):
                if maybeToken != nil {
                    // Success! Authenticated
                    state.isAuthorizing = false
                    state.isAuthenticated = true
                    state.user = traktClient.currentUser()
                    state.deviceCodeInfo = nil
                    state.authError = nil

                    return .merge(
                        .cancel(id: pollTimerCancelID),
                        .send(.fetchWatchlist),
                        .send(.fetchPlaybackProgress)
                    )
                } else {
                    // Still pending, continue polling
                    guard state.isAuthorizing, let code = state.deviceCodeInfo else {
                        return .cancel(id: pollTimerCancelID)
                    }
                    let pollInterval = max(code.interval, 5)

                    return .run { send in
                        try await clock.sleep(for: .seconds(pollInterval))
                        await send(.pollDeviceToken)
                    }
                    .cancellable(id: pollTimerCancelID, cancelInFlight: true)
                }

            case let .pollTokenResponse(.failure(error)):
                state.isAuthorizing = false
                state.authError = error.localizedDescription
                return .cancel(id: pollTimerCancelID)

            case .cancelAuth:
                state.isAuthorizing = false
                state.deviceCodeInfo = nil
                state.authError = nil
                return .cancel(id: pollTimerCancelID)

            case .fetchWatchlist:
                state.isLoading = true
                return .run { send in
                    await send(.watchlistResponse(TaskResult {
                        try await traktClient.fetchWatchlist()
                    }))
                }

            case let .watchlistResponse(.success(items)):
                state.isLoading = false
                state.watchlist = IdentifiedArray(uniqueElements: items)
                return .none

            case .watchlistResponse(.failure):
                state.isLoading = false
                return .none

            case .fetchPlaybackProgress:
                return .run { send in
                    await send(.playbackProgressResponse(TaskResult {
                        try await traktClient.fetchPlaybackProgress()
                    }))
                }

            case let .playbackProgressResponse(.success(items)):
                state.playbackItems = IdentifiedArray(uniqueElements: items)
                return .none

            case .playbackProgressResponse(.failure):
                return .none

            case let .toggleAutoScrobble(enabled):
                state.isAutoScrobbleEnabled = enabled
                traktClient.setAutoScrobbleEnabled(enabled)
                return .none

            case .logout:
                traktClient.logout()
                state.isAuthenticated = false
                state.user = nil
                state.watchlist.removeAll()
                state.playbackItems.removeAll()
                return .cancel(id: pollTimerCancelID)
            }
        }
    }
}
