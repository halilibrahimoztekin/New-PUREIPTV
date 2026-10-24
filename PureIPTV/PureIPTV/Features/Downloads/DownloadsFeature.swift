import ComposableArchitecture
import Foundation

@Reducer
public struct DownloadsFeature {
    @ObservableState
    public struct State: Equatable {
        public var downloadedItems: [OfflineMedia] = []
        public var activeDownloads: [DownloadProgressItem] = []
        public var isLoading = false
        public var isClearingCompleted = false
        public var isConfirmingClearCompleted = false
        public var clearFailureMessage: String?
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
        case clearCompletedTapped
        case clearCompletedCancelled
        case clearCompletedConfirmed
        case clearCompletedResponse(DownloadBulkDeleteResult)
        case dismissClearFailure
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
                let updates = downloadClient.observeDownloads()
                return .merge(
                    .send(.loadDownloads),
                    .run { send in
                        for await update in updates {
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
                if update.isCompleted || update.isFailed {
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

            case .clearCompletedTapped:
                guard !state.downloadedItems.isEmpty, !state.isClearingCompleted else { return .none }
                state.isConfirmingClearCompleted = true
                return .none

            case .clearCompletedCancelled:
                state.isConfirmingClearCompleted = false
                return .none

            case .clearCompletedConfirmed:
                guard !state.isClearingCompleted else { return .none }
                state.isConfirmingClearCompleted = false
                state.isClearingCompleted = true
                state.clearFailureMessage = nil
                return .run { send in
                    let result: DownloadBulkDeleteResult
                    do {
                        result = try await downloadClient.deleteAllCompletedDownloads()
                    } catch {
                        result = DownloadBulkDeleteResult(removedCount: 0, bytesFreed: 0, failureCount: 1)
                    }
                    await send(.clearCompletedResponse(result))
                }

            case let .clearCompletedResponse(result):
                state.isClearingCompleted = false
                if result.failureCount > 0 {
                    state.clearFailureMessage = AppStrings.Downloads.clearCompletedFailure
                }
                return .send(.loadDownloads)

            case .dismissClearFailure:
                state.clearFailureMessage = nil
                return .none

            case let .playDownload(item):
                return .send(.delegate(.playOfflineMedia(item)))

            case .delegate:
                return .none
            }
        }
    }
}
