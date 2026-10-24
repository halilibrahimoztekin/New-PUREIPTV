import ComposableArchitecture
import SwiftUI

#if os(tvOS)

    public struct DownloadsView_tvOS: View {
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
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                        Text(AppStrings.Downloads.empty)
                            .font(.title)
                        Text(AppStrings.Downloads.tvOSNotice)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 80)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 40) {
                            if !store.downloadedItems.isEmpty {
                                HStack(spacing: 20) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(AppStrings.Downloads.totalStorage)
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                        Text(totalStorageUsedString)
                                            .font(.title2.bold())
                                        Text("\(store.downloadedItems.count) \(AppStrings.Downloads.completedDownloads.lowercased())")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        store.send(.clearCompletedTapped)
                                    } label: {
                                        if store.isClearingCompleted {
                                            ProgressView()
                                        } else {
                                            Label(AppStrings.Downloads.clearCompleted, systemImage: "trash")
                                        }
                                    }
                                    .disabled(store.isClearingCompleted)
                                }
                            }

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 40)], spacing: 40) {
                                ForEach(store.downloadedItems) { item in
                                    Button {
                                        store.send(.playDownload(item))
                                    } label: {
                                        VStack {
                                            if let coverString = item.coverURL, let coverURL = URL(string: coverString) {
                                                PlaylistAsyncImage(url: coverURL, userAgentOverride: item.userAgentOverride) { phase in
                                                    switch phase {
                                                    case let .success(image):
                                                        image.resizable().scaledToFill()
                                                    default:
                                                        Rectangle().fill(Color.gray.opacity(0.3)).overlay(Image(systemName: "film").font(.largeTitle))
                                                    }
                                                }
                                                .frame(width: 250, height: 375)
                                                .clipped()
                                            } else {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 250, height: 375)
                                                    .overlay(Image(systemName: "film").font(.largeTitle))
                                            }

                                            Text(item.title)
                                                .lineLimit(1)
                                                .font(.headline)
                                                .padding(.top, 8)
                                        }
                                    }
                                    .buttonStyle(.card)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.send(.deleteDownload(item.id))
                                        } label: {
                                            Label(AppStrings.Common.delete, systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(40)
                    }
                }
            }
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
