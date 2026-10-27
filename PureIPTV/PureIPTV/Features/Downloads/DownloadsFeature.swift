import ComposableArchitecture
import Foundation

private nonisolated enum DownloadsCancelID: Hashable, Sendable {
    case observation
    case load
    case playback
}

private func mergeDownloadSnapshot(_ snapshot: [DownloadProgressItem], live: [DownloadProgressItem], changedIDs: Set<String>) -> [DownloadProgressItem] {
    let snapshotByID = Dictionary(snapshot.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    let liveByID = Dictionary(live.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    var seen = Set<String>()
    return (snapshot + live).compactMap { item in
        guard seen.insert(item.id).inserted else { return nil }
        return changedIDs.contains(item.id) ? liveByID[item.id] : snapshotByID[item.id]
    }
}

@Reducer
public struct DownloadsFeature {
    @ObservableState
    public struct State: Equatable {
        public var downloadedItems: [OfflineMediaSnapshot] = []
        public var activeDownloads: [DownloadProgressItem] = []
        public var failedDownloads: [DownloadProgressItem] = []
        public var storageSummary = DownloadStorageSummary()
        public var isLoading = false
        public var hasLoadedDownloads = false
        public var isVisible = false
        public var isClearingCompleted = false
        public var isConfirmingClearCompleted = false
        public var pendingDeleteItem: OfflineMediaSnapshot?
        public var deletingDownloadIDs: Set<String> = []
        public var pendingDownloadCommandIDs: Set<String> = []
        public var clearFailureMessage: String?
        public var errorMessage: String?
        public var loadFailureMessage: String?
        public var playbackRequestID: UUID?
        public var pendingPlaybackItemID: String?
        public var loadRequestID: UUID?
        public var queueGeneration: UInt64 = 0
        public var queueChanges: [String: UInt64] = [:]

        public init() {}

        mutating func recordQueueChange(_ id: String) {
            queueGeneration &+= 1
            queueChanges[id] = queueGeneration
        }
    }

    public enum Action {
        case onAppear
        case onDisappear
        case loadDownloads
        case downloadsResponse(requestID: UUID, generation: UInt64, Result<DownloadLibrarySnapshot, Error>)
        case downloadProgressUpdated(DownloadProgressItem)
        case togglePauseActiveDownload(String)
        case cancelActiveDownload(String)
        case dismissFailedDownload(String)
        case downloadCommandResponse(id: String, succeeded: Bool)
        case deleteDownload(String)
        case deleteDownloadCancelled
        case deleteDownloadConfirmed
        case deleteDownloadResponse(id: String, succeeded: Bool)
        case clearCompletedTapped
        case clearCompletedCancelled
        case clearCompletedConfirmed
        case clearCompletedResponse(DownloadBulkDeleteResult)
        case dismissClearFailure
        case dismissError
        case playDownload(OfflineMediaSnapshot)
        case playbackResponse(requestID: UUID, OfflineMediaSnapshot?)
        case playbackUnavailable
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case playOfflineMedia(OfflineMediaSnapshot)
        }
    }

    @Dependency(\.downloadClient) var downloadClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isVisible else { return .none }
                state.isVisible = true
                state.isLoading = true
                return .run { [downloadClient] send in
                    let updates = await downloadClient.observeDownloads()
                    guard !Task.isCancelled else { return }
                    await send(.loadDownloads)
                    for await update in updates {
                        guard !Task.isCancelled else { return }
                        await send(.downloadProgressUpdated(update))
                    }
                }
                .cancellable(id: DownloadsCancelID.observation, cancelInFlight: true)

            case .onDisappear:
                state.isVisible = false
                state.isLoading = false
                state.loadRequestID = nil
                state.playbackRequestID = nil
                state.pendingPlaybackItemID = nil
                state.pendingDeleteItem = nil
                state.isConfirmingClearCompleted = false
                return .merge(.cancel(id: DownloadsCancelID.observation), .cancel(id: DownloadsCancelID.load), .cancel(id: DownloadsCancelID.playback))

            case .loadDownloads:
                guard state.isVisible else { return .none }
                state.isLoading = true
                state.loadFailureMessage = nil
                let requestID = UUID()
                let generation = state.queueGeneration
                state.loadRequestID = requestID
                return .run { [downloadClient] send in
                    let result = await Result { try await downloadClient.getDownloadsSnapshot() }
                    guard !Task.isCancelled else { return }
                    await send(.downloadsResponse(requestID: requestID, generation: generation, result))
                }
                .cancellable(id: DownloadsCancelID.load, cancelInFlight: true)

            case let .downloadsResponse(requestID, generation, .success(snapshot)):
                guard state.loadRequestID == requestID else { return .none }
                state.loadRequestID = nil
                state.isLoading = false
                state.downloadedItems = snapshot.downloadedItems
                state.hasLoadedDownloads = true
                state.storageSummary = snapshot.storageSummary
                state.loadFailureMessage = nil
                if state.errorMessage == AppStrings.Downloads.downloadLoadFailure { state.errorMessage = nil }
                let changedIDs = Set(state.queueChanges.filter { $0.value > generation }.map(\.key))
                state.activeDownloads = mergeDownloadSnapshot(snapshot.activeDownloads, live: state.activeDownloads, changedIDs: changedIDs)
                state.failedDownloads = mergeDownloadSnapshot(snapshot.failedDownloads, live: state.failedDownloads, changedIDs: changedIDs)
                state.queueChanges = state.queueChanges.filter { $0.value > generation }
                return .none

            case let .downloadsResponse(requestID, _, .failure):
                guard state.loadRequestID == requestID else { return .none }
                state.loadRequestID = nil
                state.isLoading = false
                state.loadFailureMessage = AppStrings.Downloads.downloadLoadFailure
                return .none

            case let .downloadProgressUpdated(update):
                if !update.isCompleted, !update.isFailed, !update.isCancelled,
                   state.activeDownloads.first(where: { $0.id == update.id }) == update {
                    return .none
                }
                state.recordQueueChange(update.id)
                if update.isCompleted || update.isCancelled {
                    state.activeDownloads.removeAll { $0.id == update.id }
                    state.failedDownloads.removeAll { $0.id == update.id }
                    return state.isVisible ? .send(.loadDownloads) : .none
                }
                if update.isFailed {
                    state.activeDownloads.removeAll { $0.id == update.id }
                    state.failedDownloads.removeAll { $0.id == update.id }
                    state.failedDownloads.insert(update, at: 0)
                    return state.isVisible ? .send(.loadDownloads) : .none
                }
                state.failedDownloads.removeAll { $0.id == update.id }
                if let index = state.activeDownloads.firstIndex(where: { $0.id == update.id }) {
                    state.activeDownloads[index] = update
                } else {
                    state.activeDownloads.append(update)
                }
                return .none

            case let .cancelActiveDownload(id):
                guard state.activeDownloads.contains(where: { $0.id == id }),
                      state.pendingDownloadCommandIDs.insert(id).inserted else { return .none }
                return .run { [downloadClient] send in
                    do {
                        try await downloadClient.cancelDownload(id)
                        await send(.downloadCommandResponse(id: id, succeeded: true))
                    } catch {
                        await send(.downloadCommandResponse(id: id, succeeded: false))
                    }
                }

            case let .togglePauseActiveDownload(id):
                guard let item = state.activeDownloads.first(where: { $0.id == id }),
                      state.pendingDownloadCommandIDs.insert(id).inserted else { return .none }
                return .run { [downloadClient] send in
                    if item.isPaused {
                        await downloadClient.resumeDownload(id)
                    } else {
                        await downloadClient.pauseDownload(id)
                    }
                    await send(.downloadCommandResponse(id: id, succeeded: true))
                }

            case let .dismissFailedDownload(id):
                guard state.failedDownloads.contains(where: { $0.id == id }),
                      state.pendingDownloadCommandIDs.insert(id).inserted else { return .none }
                return .run { [downloadClient] send in
                    do {
                        try await downloadClient.dismissFailedDownload(id)
                        await send(.downloadCommandResponse(id: id, succeeded: true))
                    } catch {
                        await send(.downloadCommandResponse(id: id, succeeded: false))
                    }
                }

            case let .downloadCommandResponse(id, succeeded):
                state.pendingDownloadCommandIDs.remove(id)
                state.loadRequestID = nil
                if !succeeded { state.errorMessage = AppStrings.Downloads.downloadCommandFailure }
                return state.isVisible ? .send(.loadDownloads) : .none

            case let .deleteDownload(id):
                guard !state.isClearingCompleted, state.deletingDownloadIDs.isEmpty,
                      let item = state.downloadedItems.first(where: { $0.id == id }) else { return .none }
                state.pendingDeleteItem = item
                return .none

            case .deleteDownloadCancelled:
                state.pendingDeleteItem = nil
                return .none

            case .deleteDownloadConfirmed:
                guard let item = state.pendingDeleteItem, !state.isClearingCompleted,
                      state.deletingDownloadIDs.insert(item.id).inserted else { return .none }
                state.pendingDeleteItem = nil
                state.playbackRequestID = nil
                state.pendingPlaybackItemID = nil
                return .merge(.cancel(id: DownloadsCancelID.playback), .run { [downloadClient] send in
                    do {
                        try await downloadClient.deleteDownloadedMedia(item.id)
                        await send(.deleteDownloadResponse(id: item.id, succeeded: true))
                    } catch {
                        await send(.deleteDownloadResponse(id: item.id, succeeded: false))
                    }
                })

            case let .deleteDownloadResponse(id, succeeded):
                state.deletingDownloadIDs.remove(id)
                state.loadRequestID = nil
                if succeeded { state.downloadedItems.removeAll { $0.id == id } }
                if !succeeded { state.errorMessage = AppStrings.Downloads.deleteDownloadFailure }
                return state.isVisible ? .send(.loadDownloads) : .none

            case .clearCompletedTapped:
                guard !state.downloadedItems.isEmpty, !state.isClearingCompleted,
                      state.deletingDownloadIDs.isEmpty else { return .none }
                state.isConfirmingClearCompleted = true
                return .none

            case .clearCompletedCancelled:
                state.isConfirmingClearCompleted = false
                return .none

            case .clearCompletedConfirmed:
                guard state.isConfirmingClearCompleted, !state.isClearingCompleted,
                      state.deletingDownloadIDs.isEmpty else { return .none }
                state.isConfirmingClearCompleted = false
                state.isClearingCompleted = true
                state.clearFailureMessage = nil
                state.playbackRequestID = nil
                state.pendingPlaybackItemID = nil
                return .merge(.cancel(id: DownloadsCancelID.playback), .run { [downloadClient] send in
                    let result: DownloadBulkDeleteResult
                    do {
                        result = try await downloadClient.deleteAllCompletedDownloads()
                    } catch {
                        result = DownloadBulkDeleteResult(removedCount: 0, bytesFreed: 0, failureCount: 1)
                    }
                    await send(.clearCompletedResponse(result))
                })

            case let .clearCompletedResponse(result):
                state.isClearingCompleted = false
                state.loadRequestID = nil
                if result.failureCount > 0 { state.clearFailureMessage = AppStrings.Downloads.clearCompletedFailure }
                return state.isVisible ? .send(.loadDownloads) : .none

            case .dismissClearFailure:
                state.clearFailureMessage = nil
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case let .playDownload(item):
                guard state.isVisible, state.playbackRequestID == nil,
                      item.isAvailable, !state.deletingDownloadIDs.contains(item.id), !state.isClearingCompleted else { return .none }
                let requestID = UUID()
                state.playbackRequestID = requestID
                state.pendingPlaybackItemID = item.id
                return .run { [downloadClient] send in
                    let current = try? await downloadClient.getDownloadedMedia().first(where: { $0.id == item.id && $0.isAvailable })
                    guard !Task.isCancelled else { return }
                    await send(.playbackResponse(requestID: requestID, current))
                }
                .cancellable(id: DownloadsCancelID.playback, cancelInFlight: true)

            case let .playbackResponse(requestID, current):
                guard state.isVisible, state.playbackRequestID == requestID else { return .none }
                state.playbackRequestID = nil
                state.pendingPlaybackItemID = nil
                guard let current, state.downloadedItems.contains(where: { $0.id == current.id && $0.isAvailable }),
                      !state.deletingDownloadIDs.contains(current.id), !state.isClearingCompleted else {
                    return .send(.playbackUnavailable)
                }
                return .send(.delegate(.playOfflineMedia(current)))

            case .playbackUnavailable:
                state.errorMessage = AppStrings.Downloads.missingDownload
                return state.isVisible ? .send(.loadDownloads) : .none

            case .delegate:
                return .none
            }
        }
    }
}
