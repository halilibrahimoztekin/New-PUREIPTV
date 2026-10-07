import ComposableArchitecture
import Foundation

@Reducer
public struct DownloadsFeature {
    @ObservableState
    public struct State: Equatable {
        public var downloadedItems: [OfflineMedia] = []
        public var isLoading = false
        public var errorMessage: String?

        public init() {}
    }

    public enum Action {
        case onAppear
        case loadDownloads
        case downloadsLoaded([OfflineMedia])
        case deleteDownload(String)
        case playDownload(OfflineMedia)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case playOfflineMedia(OfflineMedia)
        }
    }

    @Dependency(\.downloadClient) var downloadClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.loadDownloads)

            case .loadDownloads:
                state.isLoading = true
                return .run { send in
                    let items = await (try? downloadClient.getDownloadedMedia()) ?? []
                    await send(.downloadsLoaded(items))
                }

            case let .downloadsLoaded(items):
                state.isLoading = false
                state.downloadedItems = items
                return .none

            case let .deleteDownload(id):
                return .run { send in
                    try? await downloadClient.deleteDownloadedMedia(id: id)
                    await send(.loadDownloads)
                }

            case let .playDownload(item):
                return .send(.delegate(.playOfflineMedia(item)))

            case .delegate:
                return .none
            }
        }
    }
}
