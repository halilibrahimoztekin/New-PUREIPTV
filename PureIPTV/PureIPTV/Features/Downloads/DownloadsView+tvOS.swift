import ComposableArchitecture
import SwiftUI

#if os(tvOS)

    public struct DownloadsView_tvOS: View {
        @Bindable var store: StoreOf<DownloadsFeature>

        public init(store: StoreOf<DownloadsFeature>) {
            self.store = store
        }

        public var body: some View {
            Group {
                if store.isLoading {
                    ProgressView(AppStrings.Common.loading)
                } else if store.downloadedItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                        Text(AppStrings.Downloads.empty)
                            .font(.title)
                        Text(AppStrings.Downloads.emptyDescription)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 40)], spacing: 40) {
                            ForEach(store.downloadedItems) { item in
                                Button {
                                    store.send(.playDownload(item))
                                } label: {
                                    VStack {
                                        if let coverString = item.coverURL, let coverURL = URL(string: coverString) {
                                            AsyncImage(url: coverURL) { phase in
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
                        .padding(40)
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }
#endif
