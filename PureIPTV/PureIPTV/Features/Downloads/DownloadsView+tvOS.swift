import ComposableArchitecture
import SwiftUI

#if os(tvOS)

    public struct DownloadsView_tvOS: View {
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
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    storageSummarySection

                    if let loadFailureMessage = store.loadFailureMessage {
                        loadFailureSection(loadFailureMessage)
                    }

                    if store.isLoading, !hasDownloads {
                        HStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text(AppStrings.Common.loading)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else if !hasDownloads, store.loadFailureMessage == nil {
                        VStack(spacing: 20) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 80))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(AppStrings.Downloads.empty)
                                .font(.title)
                            Text(AppStrings.Downloads.tvOSNotice)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 80)
                        }
                        .frame(maxWidth: .infinity, minHeight: 320)
                    }

                    if !store.activeDownloads.isEmpty {
                        activeDownloadsSection
                    }

                    if !store.failedDownloads.isEmpty {
                        failedDownloadsSection
                    }

                    if !store.downloadedItems.isEmpty {
                        completedDownloadsSection
                    }
                }
                .padding(48)
                .focusSection()
            }
        }

        private var storageSummarySection: some View {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 40) {
                    storageMetric(
                        title: AppStrings.Downloads.totalStorage,
                        value: downloadedStorageText
                    )
                    storageMetric(
                        title: AppStrings.Downloads.availableStorage,
                        value: availableStorageText
                    )
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 16) {
                        if store.hasLoadedDownloads {
                            Text("\(store.downloadedItems.count) \(AppStrings.Downloads.completedDownloads.lowercased())")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            guard !store.isLoading else { return }
                            store.send(.loadDownloads)
                        } label: {
                            HStack(spacing: 12) {
                                if store.isLoading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(AppStrings.Downloads.refreshDownloads)
                            }
                            .font(.title3.weight(.semibold))
                            .frame(minWidth: 250, minHeight: 64)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(AppStrings.Downloads.refreshDownloads)
                        .accessibilityValue(store.isLoading ? AppStrings.Common.loading : "")
                    }
                }

                if !store.downloadedItems.isEmpty {
                    Button(role: .destructive) {
                        guard !isDeletionInProgress else { return }
                        store.send(.clearCompletedTapped)
                    } label: {
                        HStack(spacing: 12) {
                            if isDeletionInProgress {
                                ProgressView()
                            } else {
                                Image(systemName: "trash")
                            }
                            Text(AppStrings.Downloads.clearCompleted)
                        }
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 360, minHeight: 68)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityValue(isDeletionInProgress ? AppStrings.Common.loading : "")
                }

                if let clearFailureMessage = store.clearFailureMessage {
                    Label(clearFailureMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }

        private func loadFailureSection(_ message: String) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    guard !store.isLoading else { return }
                    store.send(.loadDownloads)
                } label: {
                    HStack(spacing: 12) {
                        if store.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(AppStrings.Downloads.refreshDownloads)
                    }
                    .font(.title3.weight(.semibold))
                    .frame(minWidth: 300, minHeight: 72)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(AppStrings.Downloads.refreshDownloads)
                .accessibilityValue(store.isLoading ? AppStrings.Common.loading : "")
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .focusSection()
        }

        private var activeDownloadsSection: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text(AppStrings.Downloads.activeDownloads)
                    .font(.title2.weight(.bold))

                ForEach(store.activeDownloads) { item in
                    activeDownloadCard(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusSection()
        }

        private func activeDownloadCard(_ item: DownloadProgressItem) -> some View {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 24) {
                    activeArtwork(item)
                    activeDetails(item)
                }

                HStack(spacing: 20) {
                    Button {
                        guard !store.pendingDownloadCommandIDs.contains(item.id) else { return }
                        store.send(.togglePauseActiveDownload(item.id))
                    } label: {
                        HStack(spacing: 12) {
                            if store.pendingDownloadCommandIDs.contains(item.id) {
                                ProgressView()
                            } else {
                                Image(systemName: item.isPaused ? "play.fill" : "pause.fill")
                            }
                            Text(item.isPaused ? AppStrings.Downloads.resumeDownload : AppStrings.Downloads.pauseDownload)
                        }
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 300, minHeight: 72)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(item.isPaused ? AppStrings.Downloads.resumeDownload : AppStrings.Downloads.pauseDownload)
                    .accessibilityValue(store.pendingDownloadCommandIDs.contains(item.id) ? AppStrings.Common.loading : "")

                    Button(role: .destructive) {
                        guard !store.pendingDownloadCommandIDs.contains(item.id) else { return }
                        store.send(.cancelActiveDownload(item.id))
                    } label: {
                        HStack(spacing: 12) {
                            if store.pendingDownloadCommandIDs.contains(item.id) {
                                ProgressView()
                            } else {
                                Image(systemName: "xmark.circle.fill")
                            }
                            Text(AppStrings.Downloads.cancelDownload)
                        }
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 260, minHeight: 72)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(AppStrings.Downloads.cancelDownload)
                    .accessibilityValue(store.pendingDownloadCommandIDs.contains(item.id) ? AppStrings.Common.loading : "")
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            } else {
                artworkPlaceholder
                    .frame(width: 120, height: 180)
                    .accessibilityHidden(true)
            }
        }

        private var artworkPlaceholder: some View {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .overlay(Image(systemName: "film").font(.largeTitle).foregroundColor(.white))
        }

        private func activeDetails(_ item: DownloadProgressItem) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)

                if item.isPaused {
                    Text(AppStrings.Downloads.paused)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else if item.isQueued {
                    Text(AppStrings.Downloads.queued)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView(value: max(0.01, item.progress))
                        .tint(.blue)
                        .scaleEffect(y: 1.5)
                        .accessibilityLabel(item.title)
                        .accessibilityValue(item.formattedProgress)
                }

                HStack(spacing: 12) {
                    Text(item.isPaused
                        ? AppStrings.Downloads.paused
                        : (item.isQueued ? AppStrings.Downloads.queued : item.formattedProgress))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.blue)
                    if !item.formattedSize.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(item.formattedSize)
                            .foregroundStyle(.secondary)
                    }
                    if !item.formattedSpeed.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(item.formattedSpeed)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var failedDownloadsSection: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text(AppStrings.Downloads.failedDownloads)
                    .font(.title2.weight(.bold))

                ForEach(store.failedDownloads) { item in
                    let isDismissing = store.pendingDownloadCommandIDs.contains(item.id)
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(item.title)
                                .font(.title3.weight(.semibold))
                                .lineLimit(2)
                            Label(AppStrings.Downloads.failedDownload, systemImage: "exclamationmark.triangle.fill")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.red)
                            Text(AppStrings.Downloads.failedDownloadHint)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)

                        Button {
                            guard !isDismissing else { return }
                            store.send(.dismissFailedDownload(item.id))
                        } label: {
                            HStack(spacing: 12) {
                                if isDismissing {
                                    ProgressView()
                                } else {
                                    Image(systemName: "xmark.circle")
                                }
                                Text(AppStrings.Downloads.dismissFailedDownload)
                            }
                            .font(.title3.weight(.semibold))
                            .frame(minWidth: 300, minHeight: 72)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(AppStrings.Downloads.dismissFailedDownload)
                        .accessibilityValue(isDismissing ? AppStrings.Common.loading : "")
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .focusSection()
        }

        private var completedDownloadsSection: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text(AppStrings.Downloads.completedDownloads)
                    .font(.title2.weight(.bold))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 32)], spacing: 32) {
                    ForEach(store.downloadedItems) { item in
                        completedDownloadCard(item)
                    }
                }
                .focusSection()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private func completedDownloadCard(_ item: OfflineMediaSnapshot) -> some View {
            VStack(spacing: 16) {
                if item.isAvailable {
                    Button {
                        guard item.isAvailable,
                              !isDeletionInProgress,
                              !isPlaybackLookupInProgress
                        else { return }
                        store.send(.playDownload(item))
                    } label: {
                        completedCardContent(item)
                    }
                    .tvFocusEffect()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.title)
                    .accessibilityValue(
                        isPreparingPlayback(item) || isDeletionInProgress || isPlaybackLookupInProgress
                            ? AppStrings.Common.loading
                            : ""
                    )
                } else {
                    completedCardContent(item)
                        .accessibilityElement(children: .combine)
                }

                Button(role: .destructive) {
                    guard !isDeletionInProgress else { return }
                    store.send(.deleteDownload(item.id))
                } label: {
                    HStack(spacing: 12) {
                        if isDeletionInProgress {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                        }
                        Text(AppStrings.Common.delete)
                    }
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("\(AppStrings.Common.delete) \(item.title)")
                .accessibilityValue(isDeletionInProgress ? AppStrings.Common.loading : "")
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }

        private func completedCardContent(_ item: OfflineMediaSnapshot) -> some View {
            VStack(spacing: 12) {
                completedArtwork(item)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(item.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if item.fileSize > 0 {
                    Text(formattedByteCount(item.fileSize))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if item.isAvailable && (isPreparingPlayback(item) || isDeletionInProgress) {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(AppStrings.Common.loading)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                }

                if !item.isAvailable {
                    Label(AppStrings.Downloads.missingDownload, systemImage: "exclamationmark.triangle.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .accessibilityHidden(true)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(Image(systemName: "film").font(.largeTitle).foregroundColor(.white))
                    .accessibilityHidden(true)
            }
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
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(minWidth: 300, alignment: .leading)
        }

        private func formattedByteCount(_ bytes: Int64) -> String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: max(0, bytes))
        }
    }
#endif
