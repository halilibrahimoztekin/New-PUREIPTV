import ComposableArchitecture
import SwiftUI

struct FavoriteChannelListSwitcher: View {
    @Bindable var store: StoreOf<LiveTVFeature>
    @State private var isManagementPresented = false

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

                Button {
                    isManagementPresented = true
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
        .sheet(isPresented: $isManagementPresented) {
            FavoriteChannelListManagementView(store: store)
        }
    }

    private var isDefaultSelected: Bool {
        store.isFavoriteListMode && store.selectedFavoriteListID == nil
    }
}

struct FavoriteChannelListManagementView: View {
    @Bindable var store: StoreOf<LiveTVFeature>
    @Environment(\.dismiss) private var dismiss
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
                        dismiss()
                    } label: {
                        Label(AppStrings.Common.favorites, systemImage: store.isFavoriteListMode && store.selectedFavoriteListID == nil ? "checkmark.circle.fill" : "heart")
                    }
                    ForEach(store.favoriteLists) { list in
                        HStack {
                            Button {
                                store.send(.favoriteListSelected(list.id))
                                dismiss()
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
                        }
                    }
                } header: {
                    Text(AppStrings.LiveTV.favoriteListsSection)
                }
            }
            .navigationTitle(AppStrings.LiveTV.favoriteLists)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.Common.done) { dismiss() }
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
