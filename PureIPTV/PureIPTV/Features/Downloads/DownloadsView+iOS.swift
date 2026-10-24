#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    public struct DownloadsView_iOS: View {
        @Bindable var store: StoreOf<DownloadsFeature>

        public init(store: StoreOf<DownloadsFeature>) {
            self.store = store
        }

        private var totalStorageUsedString: String {
            let totalBytes = store.downloadedItems.reduce(0) { $0 + $1.fileSize }
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useGB, .useMB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalBytes)
        }

        public var body: some View {
            Group {
                if store.isLoading, store.downloadedItems.isEmpty, store.activeDownloads.isEmpty {
                    PureLoadingView(size: .large, text: AppStrings.Common.loading)
                } else if store.downloadedItems.isEmpty, store.activeDownloads.isEmpty {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 100, height: 100)
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 54, weight: .light))
                                .foregroundStyle(.blue)
                        }
                        Text(AppStrings.Downloads.empty)
                            .font(.headline)
                        Text(AppStrings.Downloads.emptyDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        // Storage Summary Header
                        if !store.downloadedItems.isEmpty {
                            Section {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: "internaldrive")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(.blue)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(AppStrings.Downloads.totalStorage)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(totalStorageUsedString)
                                                .font(.headline)
                                                .fontWeight(.bold)
                                        }

                                        Spacer()

                                        Text("\(store.downloadedItems.count) \(AppStrings.Downloads.completedDownloads.lowercased())")
                                            .font(.caption2)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                                            .foregroundStyle(.secondary)
                                    }

                                    Button(role: .destructive) {
                                        store.send(.clearCompletedTapped)
                                    } label: {
                                        if store.isClearingCompleted {
                                            ProgressView()
                                                .controlSize(.small)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else {
                                            Label(AppStrings.Downloads.clearCompleted, systemImage: "trash")
                                        }
                                    }
                                    .disabled(store.isClearingCompleted)
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        // Active In-Progress Downloads
                        if !store.activeDownloads.isEmpty {
                            Section(header: Text(AppStrings.Downloads.activeDownloads)) {
                                ForEach(store.activeDownloads) { item in
                                    HStack(spacing: 14) {
                                        // Thumbnail
                                        if let coverString = item.coverURL, let coverURL = URL(string: coverString) {
                                            PlaylistAsyncImage(url: coverURL, userAgentOverride: item.userAgentOverride) { phase in
                                                switch phase {
                                                case let .success(image):
                                                    image.resizable().scaledToFill()
                                                default:
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .overlay(Image(systemName: "film").foregroundColor(.white))
                                                }
                                            }
                                            .frame(width: 54, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 54, height: 80)
                                                .overlay(Image(systemName: "film").foregroundColor(.white))
                                        }

                                        // Details & Live Progress
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(item.title)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .lineLimit(1)

                                            if item.isQueued {
                                                Text(AppStrings.Downloads.queued)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            } else {
                                                ProgressView(value: max(0.01, item.progress))
                                                    .tint(.blue)
                                            }

                                            HStack(spacing: 8) {
                                                Text(item.isQueued ? AppStrings.Downloads.queued : item.formattedProgress)
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(.blue)

                                                if !item.formattedSize.isEmpty {
                                                    Text("•")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                    Text(item.formattedSize)
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }

                                                Spacer()

                                                if !item.formattedSpeed.isEmpty {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "arrow.down")
                                                            .font(.system(size: 9, weight: .bold))
                                                        Text(item.formattedSpeed)
                                                            .font(.caption2)
                                                    }
                                                    .foregroundStyle(.secondary)
                                                }
                                            }
                                        }

                                        // Cancel Button
                                        Button {
                                            HapticManager.shared.trigger(.medium)
                                            store.send(.cancelActiveDownload(item.id))
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        // Completed Downloads
                        if !store.downloadedItems.isEmpty {
                            Section(header: Text(AppStrings.Downloads.completedDownloads)) {
                                ForEach(store.downloadedItems) { item in
                                    Button {
                                        store.send(.playDownload(item))
                                    } label: {
                                        HStack(spacing: 14) {
                                            if let coverString = item.coverURL, let coverURL = URL(string: coverString) {
                                                PlaylistAsyncImage(url: coverURL, userAgentOverride: item.userAgentOverride) { phase in
                                                    switch phase {
                                                    case let .success(image):
                                                        image.resizable().scaledToFill()
                                                    default:
                                                        Rectangle().fill(Color.gray.opacity(0.3)).overlay(Image(systemName: "film").foregroundColor(.white))
                                                    }
                                                }
                                                .frame(width: 60, height: 90)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 60, height: 90)
                                                    .overlay(Image(systemName: "film").foregroundColor(.white))
                                            }

                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(item.title)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(2)

                                                if item.fileSize > 0 {
                                                    let formatter = ByteCountFormatter()
                                                    Text(formatter.string(fromByteCount: item.fileSize))
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            Spacer()

                                            Image(systemName: "play.circle.fill")
                                                .font(.title)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            store.send(.deleteDownload(item.id))
                                        } label: {
                                            Label(AppStrings.Common.delete, systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(AppStrings.Downloads.title)
            .confirmationDialog(
                AppStrings.Downloads.clearCompletedTitle,
                isPresented: Binding(
                    get: { store.isConfirmingClearCompleted },
                    set: {
                        if !$0 {
                            store.send(.clearCompletedCancelled)
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button(AppStrings.Downloads.clearCompleted, role: .destructive) {
                    store.send(.clearCompletedConfirmed)
                }
                Button(AppStrings.Common.cancel, role: .cancel) {
                    store.send(.clearCompletedCancelled)
                }
            } message: {
                Text(AppStrings.Downloads.clearCompletedMessage)
            }
            .alert(
                AppStrings.Downloads.clearCompletedTitle,
                isPresented: Binding(
                    get: { store.clearFailureMessage != nil },
                    set: {
                        if !$0 {
                            store.send(.dismissClearFailure)
                        }
                    }
                )
            ) {
                Button(AppStrings.Common.ok) { store.send(.dismissClearFailure) }
            } message: {
                Text(store.clearFailureMessage ?? AppStrings.Downloads.clearCompletedFailure)
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }
#endif
