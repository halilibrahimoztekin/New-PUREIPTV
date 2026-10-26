import ComposableArchitecture
import SwiftUI

struct ChannelSelectionToolbar: View {
    let store: StoreOf<LiveTVFeature>
    @State private var isConfirmingHide = false

    private var isBusy: Bool {
        store.activeBulkFavoriteRequestID != nil
            || store.isDefaultFavoriteRequestInProgressForSelection
            || store.selectedCurrentChannelIDs.isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            if let notice = store.bulkFavoriteNotice {
                Text(notice)
                    .font(.footnote)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Text(AppStrings.LiveTV.selectedChannelCount(store.selectedCurrentChannelIDs.count))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .accessibilityAddTraits(.updatesFrequently)

                    Button(AppStrings.LiveTV.selectAllChannels) {
                        store.send(.selectAllCurrentChannels)
                    }
                    Button(AppStrings.LiveTV.clearChannelSelection) {
                        store.send(.clearChannelSelection)
                    }

                    Button(AppStrings.LiveTV.addSelectedToFavorites) {
                        store.send(.bulkFavoriteAction(targetListID: nil, operation: .add))
                    }
                    .disabled(isBusy)

                    Button(AppStrings.LiveTV.removeSelectedFromFavorites) {
                        store.send(.bulkFavoriteAction(targetListID: nil, operation: .remove))
                    }
                    .disabled(isBusy)

                    Button(role: .destructive) {
                        isConfirmingHide = true
                    } label: {
                        Label("Seçilenleri Gizle", systemImage: "eye.slash")
                    }
                    .disabled(isBusy)

                    if !store.favoriteLists.isEmpty {
                        Menu(AppStrings.LiveTV.addSelectedToList) {
                            ForEach(store.favoriteLists) { list in
                                Button(list.name) {
                                    store.send(.bulkFavoriteAction(targetListID: list.id, operation: .add))
                                }
                            }
                        }
                        .disabled(isBusy)

                        Menu(AppStrings.LiveTV.removeSelectedFromList) {
                            ForEach(store.favoriteLists) { list in
                                Button(list.name) {
                                    store.send(.bulkFavoriteAction(targetListID: list.id, operation: .remove))
                                }
                            }
                        }
                        .disabled(isBusy)
                    }

                    Button(AppStrings.LiveTV.cancelChannelSelection) {
                        store.send(.exitChannelSelectionMode)
                    }
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .confirmationDialog(
            "Seçili Kanalları Gizle",
            isPresented: $isConfirmingHide,
            titleVisibility: .visible
        ) {
            Button("\(store.selectedCurrentChannelIDs.count) Kanalı Gizle", role: .destructive) {
                store.send(.hideSelectedChannels)
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Seçili kanallar görünür listelerden kaldırılacak. Ayarlar > Gizlenen İçerikler bölümünden kanalları geri alabilirsiniz.")
        }
    }
}
