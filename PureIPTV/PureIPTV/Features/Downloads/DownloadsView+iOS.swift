#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    public struct DownloadsView_iOS: View {
        @Bindable var store: StoreOf<DownloadsFeature>

        public init(store: StoreOf<DownloadsFeature>) {
            self.store = store
        }

        public var body: some View {
            NavigationStack {
                Group {
                    if store.isLoading, store.downloadedItems.isEmpty, store.activeDownloads.isEmpty {
                        ProgressView(AppStrings.Common.loading)
                    } else if store.downloadedItems.isEmpty, store.activeDownloads.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
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
                            // Active In-Progress Downloads
                            if !store.activeDownloads.isEmpty {
                                Section(header: Text(AppStrings.VODDetail.downloading)) {
                                    ForEach(store.activeDownloads) { item in
                                        HStack(spacing: 14) {
                                            if let coverString = item.coverURL, let coverURL = URL(string: coverString) {
                                                AsyncImage(url: coverURL) { phase in
                                                    switch phase {
                                                    case let .success(image):
                                                        image.resizable().scaledToFill()
                                                    default:
                                                        Rectangle().fill(Color.gray.opacity(0.3)).overlay(Image(systemName: "film").foregroundColor(.white))
                                                    }
                                                }
                                                .frame(width: 50, height: 75)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                            } else {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 50, height: 75)
                                                    .overlay(Image(systemName: "film").foregroundColor(.white))
                                            }

                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(item.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .lineLimit(1)

                                                ProgressView(value: item.progress)
                                                    .tint(.blue)

                                                HStack {
                                                    Text(String(format: "%%%.0f", item.progress * 100))
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                    Spacer()
                                                }
                                            }

                                            Button(action: {
                                                store.send(.cancelActiveDownload(item.id))
                                            }) {
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
                                Section(header: Text(AppStrings.Downloads.title)) {
                                    ForEach(store.downloadedItems) { item in
                                        Button {
                                            store.send(.playDownload(item))
                                        } label: {
                                            HStack(spacing: 14) {
                                                if let coverString = item.coverURL, let coverURL = URL(string: coverString) {
                                                    AsyncImage(url: coverURL) { phase in
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
                                                    .foregroundStyle(.primary)
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
                .onAppear {
                    store.send(.onAppear)
                }
            }
        }
    }
#endif
