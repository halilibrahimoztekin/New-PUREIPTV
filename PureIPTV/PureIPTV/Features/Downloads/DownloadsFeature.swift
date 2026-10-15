import ComposableArchitecture
import Foundation

@Reducer
public struct DownloadsFeature {
    @ObservableState
    public struct State: Equatable {
        public var downloadedItems: [OfflineMedia] = []
        public var activeDownloads: [DownloadProgressItem] = []
        public var isLoading = false
        public var errorMessage: String?

        public init() {}
    }

    public enum Action {
        case onAppear
        case loadDownloads
        case downloadsLoaded([OfflineMedia])
        case activeDownloadsLoaded([DownloadProgressItem])
        case downloadProgressUpdated(DownloadProgressItem)
        case cancelActiveDownload(String)
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
                return .merge(
                    .send(.loadDownloads),
                    .run { send in
                        for await update in downloadClient.observeDownloads() {
                            await send(.downloadProgressUpdated(update))
                        }
                    }
                )

            case .loadDownloads:
                state.isLoading = true
                return .run { send in
                    let items = await (try? downloadClient.getDownloadedMedia()) ?? []
                    let active = await downloadClient.getActiveDownloads()
                    await send(.downloadsLoaded(items))
                    await send(.activeDownloadsLoaded(active))
                }

            case let .downloadsLoaded(items):
                state.isLoading = false
                state.downloadedItems = items
                return .none

            case let .activeDownloadsLoaded(active):
                state.activeDownloads = active
                return .none

            case let .downloadProgressUpdated(update):
                if update.isCompleted {
                    state.activeDownloads.removeAll { $0.id == update.id }
                    return .send(.loadDownloads)
                } else {
                    if let index = state.activeDownloads.firstIndex(where: { $0.id == update.id }) {
                        state.activeDownloads[index] = update
                    } else {
                        state.activeDownloads.append(update)
                    }
                    return .none
                }

            case let .cancelActiveDownload(id):
                state.activeDownloads.removeAll { $0.id == id }
                return .run { _ in
                    try? await downloadClient.cancelDownload(id)
                }

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
