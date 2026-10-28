import ComposableArchitecture
import SwiftUI

struct FavoriteChannelListSwitcher: View {
    @Bindable var store: StoreOf<LiveTVFeature>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    store.send(.favoriteListSelected(nil))
                } label: {
                    Text(AppStrings.Common.favorites)
                        .lineLimit(1)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(isDefaultSelected ? Color.accentColor : Color.white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppStrings.Common.favorites)
                .accessibilityAddTraits(isDefaultSelected ? .isSelected : [])

                ForEach(store.favoriteLists) { list in
                    Button {
                        store.send(.favoriteListSelected(list.id))
                    } label: {
                        Text(list.name)
                            .lineLimit(1)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(store.selectedFavoriteListID == list.id && store.isFavoriteListMode ? Color.accentColor : Color.white.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(store.selectedFavoriteListID == list.id && store.isFavoriteListMode ? .isSelected : [])
                }

                if store.isFavoriteListMode, !store.isChannelSelectionMode {
                    Picker(AppStrings.LiveTV.sortTitle, selection: Binding(
                        get: { store.favoriteSortMode },
                        set: { store.send(.setFavoriteSortMode($0)) }
                    )) {
                        ForEach(FavoriteChannelSortMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityHint(AppStrings.Favorites.orderingDescription)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.1), in: Capsule())
                }

                Button {
                    store.send(.favoriteListManagementTapped)
                } label: {
                    Label(AppStrings.LiveTV.manageFavoriteLists, systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint(AppStrings.LiveTV.manageFavoriteListsHint)
            }
            .padding(.horizontal, 16)
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }

    private var isDefaultSelected: Bool {
        store.isFavoriteListMode && store.selectedFavoriteListID == nil
    }
}

struct FavoriteChannelManualOrderActions: View {
    let store: StoreOf<LiveTVFeature>
    let channelID: String

    var body: some View {
        if store.isFavoriteListMode,
           store.favoriteSortMode == .manual,
           !store.isChannelSelectionMode,
           let index = store.currentChannels.firstIndex(where: { $0.id == channelID })
        {
            if index > 0 {
                Button {
                    store.send(.moveFavoriteChannel(channelID: channelID, offset: -1))
                } label: {
                    Label(AppStrings.Favorites.moveUp, systemImage: "arrow.up")
                }
            }
            if index + 1 < store.currentChannels.count {
                Button {
                    store.send(.moveFavoriteChannel(channelID: channelID, offset: 1))
                } label: {
                    Label(AppStrings.Favorites.moveDown, systemImage: "arrow.down")
                }
            }
        }
    }
}

struct FavoriteChannelListManagementView: View {
    @Bindable var store: StoreOf<LiveTVFeature>
    let onDismiss: () -> Void
    @State private var name = ""
    @State private var editingID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(AppStrings.LiveTV.favoriteListName, text: $name)
                        .onSubmit(save)
                    Button(editingID == nil ? AppStrings.LiveTV.createFavoriteList : AppStrings.LiveTV.saveFavoriteListName, action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text(AppStrings.LiveTV.newFavoriteList)
                }

                Section {
                    Button {
                        store.send(.favoriteListSelected(nil))
                        onDismiss()
                    } label: {
                        Label(AppStrings.Common.favorites, systemImage: store.isFavoriteListMode && store.selectedFavoriteListID == nil ? "checkmark.circle.fill" : "heart")
                    }
                    ForEach(store.favoriteLists) { list in
                        let listIndex = store.favoriteLists.firstIndex(where: { $0.id == list.id }) ?? 0
                        HStack {
                            Button {
                                store.send(.favoriteListSelected(list.id))
                                onDismiss()
                            } label: {
                                HStack {
                                    Text(list.name)
                                    Spacer()
                                    if store.isFavoriteListMode, store.selectedFavoriteListID == list.id {
                                        Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            Button {
                                editingID = list.id
                                name = list.name
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .accessibilityLabel(AppStrings.LiveTV.editFavoriteList)
                            Button(role: .destructive) {
                                store.send(.deleteNamedFavoriteList(list.id))
                                if editingID == list.id {
                                    editingID = nil; name = ""
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel(AppStrings.LiveTV.deleteFavoriteList)
                            Button {
                                store.send(.moveNamedFavoriteList(id: list.id, offset: -1))
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .disabled(listIndex == 0)
                            .accessibilityLabel(AppStrings.Favorites.moveUp)
                            Button {
                                store.send(.moveNamedFavoriteList(id: list.id, offset: 1))
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .disabled(listIndex == store.favoriteLists.count - 1)
                            .accessibilityLabel(AppStrings.Favorites.moveDown)
                        }
                    }
                } header: {
                    Text(AppStrings.LiveTV.favoriteListsSection)
                }
            }
            .navigationTitle(AppStrings.LiveTV.favoriteLists)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.Common.done, action: onDismiss)
                }
            }
        }
    }

    private func save() {
        store.send(.saveNamedFavoriteList(id: editingID, name: name))
        editingID = nil
        name = ""
    }
}
