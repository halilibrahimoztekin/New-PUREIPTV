#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    public struct DownloadsView_iOS: View {
        @Bindable var store: StoreOf<DownloadsFeature>

        public init(store: StoreOf<DownloadsFeature>) {
            self.store = store
        }

        private var hasDownloads: Bool {
            !store.downloadedItems.isEmpty
                || !store.activeDownloads.isEmpty
                || !store.failedDownloads.isEmpty
        }

        private var isDeletionInProgress: Bool {
            store.isClearingCompleted || !store.deletingDownloadIDs.isEmpty
        }

        private var isPlaybackLookupInProgress: Bool {
            store.playbackRequestID != nil
        }

        private func isPreparingPlayback(_ item: OfflineMediaSnapshot) -> Bool {
            isPlaybackLookupInProgress && store.pendingPlaybackItemID == item.id
        }

        public var body: some View {
            List {
                storageSummarySection

                if let loadFailureMessage = store.loadFailureMessage {
                    loadFailureSection(loadFailureMessage)
                }

                if store.isLoading, !hasDownloads {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(AppStrings.Common.loading)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 48)
                    }
                } else if !hasDownloads, store.loadFailureMessage == nil {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(.blue)
                                .accessibilityHidden(true)
                            Text(AppStrings.Downloads.empty)
                                .font(.headline)
                            Text(AppStrings.Downloads.emptyDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }

                if !store.activeDownloads.isEmpty {
                    Section(header: Text(AppStrings.Downloads.activeDownloads)) {
                        ForEach(store.activeDownloads) { item in
                            activeDownloadRow(item)
                        }
                    }
                }

                if !store.failedDownloads.isEmpty {
                    Section(header: Text(AppStrings.Downloads.failedDownloads)) {
                        ForEach(store.failedDownloads) { item in
                            failedDownloadRow(item)
                        }
                    }
                }

                if !store.downloadedItems.isEmpty {
                    Section(header: Text(AppStrings.Downloads.completedDownloads)) {
                        ForEach(store.downloadedItems) { item in
                            completedDownloadRow(item)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(AppStrings.Downloads.title)
            .alert(
                AppStrings.Downloads.title,
                isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { if !$0 { store.send(.dismissError) } }
                )
            ) {
                Button(AppStrings.Common.ok, role: .cancel) {
                    store.send(.dismissError)
                }
            } message: {
                Text(store.errorMessage ?? "")
            }
            .confirmationDialog(
                AppStrings.Downloads.clearCompletedTitle,
                isPresented: Binding(
                    get: { store.isConfirmingClearCompleted },
                    set: { if !$0 { store.send(.clearCompletedCancelled) } }
                ),
                titleVisibility: .visible
            ) {
                Button(AppStrings.Downloads.clearCompleted, role: .destructive) {
                    guard !isDeletionInProgress else { return }
                    store.send(.clearCompletedConfirmed)
                }
                .disabled(isDeletionInProgress)
                .accessibilityValue(isDeletionInProgress ? AppStrings.Common.loading : "")
                Button(AppStrings.Common.cancel, role: .cancel) {
                    store.send(.clearCompletedCancelled)
                }
            } message: {
                Text(AppStrings.Downloads.clearCompletedMessage)
            }
            .confirmationDialog(
                AppStrings.Downloads.deleteDownloadTitle,
                isPresented: Binding(
                    get: { store.pendingDeleteItem != nil },
                    set: { if !$0 { store.send(.deleteDownloadCancelled) } }
                ),
                titleVisibility: .visible
            ) {
                Button(AppStrings.Common.delete, role: .destructive) {
                    guard !isDeletionInProgress else { return }
                    store.send(.deleteDownloadConfirmed)
                }
                .disabled(isDeletionInProgress)
                .accessibilityValue(isDeletionInProgress ? AppStrings.Common.loading : "")
                Button(AppStrings.Common.cancel, role: .cancel) {
                    store.send(.deleteDownloadCancelled)
                }
            } message: {
                Text(AppStrings.Downloads.deleteDownloadMessage(store.pendingDeleteItem?.title ?? ""))
            }
        }

        private var storageSummarySection: some View {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 20) {
                            storageMetric(
                                title: AppStrings.Downloads.totalStorage,
                                value: downloadedStorageText
                            )
                            Spacer(minLength: 8)
                            storageMetric(
                                title: AppStrings.Downloads.availableStorage,
                                value: availableStorageText
                            )
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            storageMetric(
                                title: AppStrings.Downloads.totalStorage,
                                value: downloadedStorageText
                            )
                            storageMetric(
                                title: AppStrings.Downloads.availableStorage,
                                value: availableStorageText
                            )
                        }
                    }

                    HStack {
                        if store.hasLoadedDownloads {
                            completedCount
                        }
                        Spacer()
                        refreshButton
                    }

                    if !store.downloadedItems.isEmpty {
                        Button(role: .destructive) {
                            guard !isDeletionInProgress else { return }
                            store.send(.clearCompletedTapped)
                        } label: {
                            if isDeletionInProgress {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text(AppStrings.Downloads.clearCompleted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Label(AppStrings.Downloads.clearCompleted, systemImage: "trash")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                        .disabled(isDeletionInProgress)
                        .accessibilityValue(isDeletionInProgress ? AppStrings.Common.loading : "")
                    }

                    if let clearFailureMessage = store.clearFailureMessage {
                        Label(clearFailureMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }
        }

        private var completedCount: some View {
            Text("\(store.downloadedItems.count) \(AppStrings.Downloads.completedDownloads.lowercased())")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        private func loadFailureSection(_ message: String) -> some View {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        guard !store.isLoading else { return }
                        store.send(.loadDownloads)
                    } label: {
                        HStack(spacing: 8) {
                            if store.isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(AppStrings.Downloads.refreshDownloads)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isLoading)
                    .accessibilityLabel(AppStrings.Downloads.refreshDownloads)
                    .accessibilityValue(store.isLoading ? AppStrings.Common.loading : "")
                }
                .padding(.vertical, 4)
            }
        }

        private var refreshButton: some View {
            Button {
                guard !store.isLoading else { return }
                store.send(.loadDownloads)
            } label: {
                HStack(spacing: 8) {
                    if store.isLoading {
                        ProgressView()
                    } else {
                        Label(AppStrings.Downloads.refreshDownloads, systemImage: "arrow.clockwise")
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(store.isLoading)
            .accessibilityLabel(AppStrings.Downloads.refreshDownloads)
            .accessibilityValue(store.isLoading ? AppStrings.Common.loading : "")
        }

        private var availableStorageText: String {
            guard store.hasLoadedDownloads, let bytes = store.storageSummary.availableBytes else {
                return AppStrings.Downloads.storageUnavailable
            }
            return formattedByteCount(bytes)
        }

        private var downloadedStorageText: String {
            store.hasLoadedDownloads
                ? formattedByteCount(store.storageSummary.downloadedBytes)
                : AppStrings.Common.loading
        }

        private func storageMetric(title: String, value: String) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private func activeDownloadRow(_ item: DownloadProgressItem) -> some View {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    activeArtwork(item)
                    activeDetails(item)
                    Spacer(minLength: 4)
                    activeDownloadControls(item)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        activeArtwork(item)
                        activeDetails(item)
                    }
                    HStack {
                        Spacer()
                        activeDownloadControls(item)
                    }
                }
            }
            .padding(.vertical, 6)
        }

        @ViewBuilder
        private func activeArtwork(_ item: DownloadProgressItem) -> some View {
            if let coverString = item.coverURL, let coverURL = URL(string: coverString) {
                PlaylistAsyncImage(url: coverURL, userAgentOverride: item.userAgentOverride) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()
                    default:
                        artworkPlaceholder
                    }
                }
                .frame(width: 54, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            } else {
                artworkPlaceholder
                    .frame(width: 54, height: 80)
                    .accessibilityHidden(true)
            }
        }

        private var artworkPlaceholder: some View {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .overlay(Image(systemName: "film").foregroundColor(.white))
        }

        private func activeDetails(_ item: DownloadProgressItem) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if item.isPaused {
                    Text(AppStrings.Downloads.paused)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if item.isQueued {
                    Text(AppStrings.Downloads.queued)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView(value: max(0.01, item.progress))
                        .tint(.blue)
                        .accessibilityLabel(item.title)
                        .accessibilityValue(item.formattedProgress)
                }

                HStack(spacing: 6) {
                    Text(item.isPaused
                        ? AppStrings.Downloads.paused
                        : (item.isQueued ? AppStrings.Downloads.queued : item.formattedProgress))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                    if !item.formattedSize.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(item.formattedSize)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private func activeDownloadControls(_ item: DownloadProgressItem) -> some View {
            HStack(spacing: 8) {
                Button {
                    guard !store.pendingDownloadCommandIDs.contains(item.id) else { return }
                    store.send(.togglePauseActiveDownload(item.id))
                } label: {
                    Group {
                        if store.pendingDownloadCommandIDs.contains(item.id) {
                            ProgressView()
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: item.isPaused ? "play.fill" : "pause.fill")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .foregroundStyle(.blue)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isPaused ? AppStrings.Downloads.resumeDownload : AppStrings.Downloads.pauseDownload)

                Button {
                    guard !store.pendingDownloadCommandIDs.contains(item.id) else { return }
                    store.send(.cancelActiveDownload(item.id))
                } label: {
                    Group {
                        if store.pendingDownloadCommandIDs.contains(item.id) {
                            ProgressView()
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppStrings.Downloads.cancelDownload)
            }
        }

        private func failedDownloadRow(_ item: DownloadProgressItem) -> some View {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    failedDownloadDetails(item)
                    Spacer(minLength: 8)
                    dismissFailedDownloadButton(item)
                }

                VStack(alignment: .leading, spacing: 8) {
                    failedDownloadDetails(item)
                    HStack {
                        Spacer()
                        dismissFailedDownloadButton(item)
                    }
                }
            }
            .padding(.vertical, 6)
        }

        private func failedDownloadDetails(_ item: DownloadProgressItem) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Label(AppStrings.Downloads.failedDownload, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                Text(AppStrings.Downloads.failedDownloadHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }

        private func dismissFailedDownloadButton(_ item: DownloadProgressItem) -> some View {
            let isDismissing = store.pendingDownloadCommandIDs.contains(item.id)
            return Button {
                guard !isDismissing else { return }
                store.send(.dismissFailedDownload(item.id))
            } label: {
                Group {
                    if isDismissing {
                        ProgressView()
                    } else {
                        Label(AppStrings.Downloads.dismissFailedDownload, systemImage: "xmark.circle")
                    }
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(isDismissing)
            .accessibilityLabel(AppStrings.Downloads.dismissFailedDownload)
            .accessibilityValue(isDismissing ? AppStrings.Common.loading : "")
        }

        private func completedDownloadRow(_ item: OfflineMediaSnapshot) -> some View {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    completedDownloadContent(item)
                    Spacer(minLength: 8)
                    deleteDownloadButton(item)
                }

                VStack(alignment: .leading, spacing: 8) {
                    completedDownloadContent(item)
                    HStack {
                        Spacer()
                        deleteDownloadButton(item)
                    }
                }
            }
            .padding(.vertical, 6)
        }

        @ViewBuilder
        private func completedDownloadContent(_ item: OfflineMediaSnapshot) -> some View {
            if item.isAvailable {
                Button {
                    guard item.isAvailable,
                          !isDeletionInProgress,
                          !isPlaybackLookupInProgress
                    else { return }
                    store.send(.playDownload(item))
                } label: {
                    completedDownloadDetails(item)
                }
                .buttonStyle(.plain)
                .disabled(isDeletionInProgress || isPlaybackLookupInProgress)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item.title)
                .accessibilityValue(
                    isPreparingPlayback(item) || isDeletionInProgress || isPlaybackLookupInProgress
                        ? AppStrings.Common.loading
                        : ""
                )
            } else {
                completedDownloadDetails(item)
                    .accessibilityElement(children: .combine)
            }
        }

        private func completedDownloadDetails(_ item: OfflineMediaSnapshot) -> some View {
            HStack(spacing: 12) {
                completedArtwork(item)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if item.fileSize > 0 {
                        Text(formattedByteCount(item.fileSize))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !item.isAvailable {
                        Label(AppStrings.Downloads.missingDownload, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if item.isAvailable && (isPreparingPlayback(item) || isDeletionInProgress) {
                    VStack(spacing: 4) {
                        ProgressView()
                        Text(AppStrings.Common.loading)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                } else if item.isAvailable {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }

        @ViewBuilder
        private func completedArtwork(_ item: OfflineMediaSnapshot) -> some View {
            if let coverString = item.coverURL, let coverURL = URL(string: coverString) {
                PlaylistAsyncImage(url: coverURL, userAgentOverride: item.userAgentOverride) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()
                    default:
                        artworkPlaceholder
                    }
                }
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            } else {
                artworkPlaceholder
                    .frame(width: 60, height: 90)
                    .accessibilityHidden(true)
            }
        }

        private func deleteDownloadButton(_ item: OfflineMediaSnapshot) -> some View {
            Button(role: .destructive) {
                guard !isDeletionInProgress else { return }
                store.send(.deleteDownload(item.id))
            } label: {
                Group {
                    if isDeletionInProgress {
                        ProgressView()
                    } else {
                        Image(systemName: "trash")
                            .font(.body.weight(.semibold))
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(isDeletionInProgress)
            .accessibilityLabel("\(AppStrings.Common.delete) \(item.title)")
            .accessibilityValue(isDeletionInProgress ? AppStrings.Common.loading : "")
        }

        private func formattedByteCount(_ bytes: Int64) -> String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: max(0, bytes))
        }
    }
#endif
