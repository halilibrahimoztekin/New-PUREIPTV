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
                if store.isLoading {
                    ProgressView("İndirilenler yükleniyor...")
                } else if store.downloadedItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Henüz indirilmiş içerik yok")
                            .font(.headline)
                        Text("Filmleri veya dizileri indirerek internet bağlantınız olmadan da izleyebilirsiniz.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        ForEach(store.downloadedItems) { item in
                            Button {
                                store.send(.playDownload(item))
                            } label: {
                                HStack(spacing: 16) {
                                    if let coverString = item.coverURL, let coverURL = URL(string: coverString) {
                                        AsyncImage(url: coverURL) { phase in
                                            switch phase {
                                            case let .success(image):
                                                image.resizable().scaledToFill()
                                            default:
                                                Rectangle().fill(Color.gray.opacity(0.3)).overlay(Image(systemName: "film").foregroundColor(.white))
                                            }
                                        }
                                        .frame(width: 80, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 120)
                                            .overlay(Image(systemName: "film").foregroundColor(.white))
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(item.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
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
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("İndirilenler")
            .onAppear {
                store.send(.onAppear)
            }
        }
    }
}
