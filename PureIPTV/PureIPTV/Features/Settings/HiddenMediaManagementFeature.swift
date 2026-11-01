import ComposableArchitecture
import FactoryKit
import Foundation

@Reducer
public struct HiddenMediaManagementFeature {
    @ObservableState
    public struct State: Equatable {
        public var items: [HiddenMediaEntry] = []
        public var playlistNames: [UUID: String] = [:]
        public var pendingRestoreIDs: Set<String> = []
        public var activeLoadRequestID: UUID?
        public var profileScope: ProfileContextSnapshot?
        public var isLoading = false
        public var errorMessage: String?

        public init() {}

        public func playlistName(for entry: HiddenMediaEntry) -> String {
            guard let playlistID = entry.identity.playlistID else {
                return AppStrings.Settings.defaultMediaSource
            }
            return playlistNames[playlistID] ?? String(playlistID.uuidString.prefix(8))
        }
    }

    public enum Action {
        case onAppear
        case itemsLoaded(requestID: UUID, profileScope: ProfileContextSnapshot, Result<[HiddenMediaEntry], Error>)
        case restoreTapped(HiddenMediaEntry)
        case restoreCompleted(entry: HiddenMediaEntry, profileScope: ProfileContextSnapshot, Result<Bool, Error>)
    }

    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let playlistRepository = playlistRepository
        let databaseClient = databaseClient
        let profileContextClient = profileContextClient

        Reduce { state, action in
            switch action {
            case .onAppear:
                let profileScope = profileContextClient.snapshot()
                let requestID = UUID()
                state.profileScope = profileScope
                state.activeLoadRequestID = requestID
                state.isLoading = true
                state.errorMessage = nil
                state.playlistNames = Dictionary(
                    playlistRepository.getPlaylists().map { ($0.id, $0.name) },
                    uniquingKeysWith: { _, latest in latest }
                )
                return .run { send in
                    do {
                        let items = try await databaseClient.fetchHiddenMediaItems(nil, profileScope)
                        await send(.itemsLoaded(requestID: requestID, profileScope: profileScope, .success(items)))
                    } catch {
                        await send(.itemsLoaded(requestID: requestID, profileScope: profileScope, .failure(error)))
                    }
                }

            case let .itemsLoaded(requestID, scope, result):
                guard state.activeLoadRequestID == requestID,
                      profileContextClient.snapshot() == scope
                else { return .none }
                state.activeLoadRequestID = nil
                state.isLoading = false
                switch result {
                case let .success(items):
                    state.items = items.sorted { $0.hiddenAt > $1.hiddenAt }
                case let .failure(error):
                    state.errorMessage = String(format: AppStrings.Common.error, locale: Locale.current, arguments: [error.localizedDescription])
                }
                return .none

            case let .restoreTapped(entry):
                guard !state.pendingRestoreIDs.contains(entry.id),
                      let profileScope = state.profileScope,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                state.pendingRestoreIDs.insert(entry.id)
                return .run { send in
                    do {
                        let succeeded = try await databaseClient.setHiddenMediaItem(entry, false, profileScope)
                        await send(.restoreCompleted(entry: entry, profileScope: profileScope, .success(succeeded)))
                    } catch {
                        await send(.restoreCompleted(entry: entry, profileScope: profileScope, .failure(error)))
                    }
                }

            case let .restoreCompleted(entry, scope, result):
                state.pendingRestoreIDs.remove(entry.id)
                guard profileContextClient.snapshot() == scope else { return .none }
                switch result {
                case .success(true):
                    state.items.removeAll { $0.identity == entry.identity }
                    state.errorMessage = nil
                case .success(false):
                    state.errorMessage = AppStrings.Errors.hiddenMediaSaveFailed
                case let .failure(error):
                    state.errorMessage = String(format: AppStrings.Common.error, locale: Locale.current, arguments: [error.localizedDescription])
                }
                return .none
            }
        }
    }
}
