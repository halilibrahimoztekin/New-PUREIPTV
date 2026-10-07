import ComposableArchitecture
import SwiftUI

public struct PlaylistManagementView: View {
    @Bindable var store: StoreOf<PlaylistManagementFeature>

    public init(store: StoreOf<PlaylistManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.playlists) { playlist in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(playlist.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(playlist.serverURL ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.activePlaylistID == playlist.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.send(.setActivePlaylist(playlist.id))
                        }
                        #if os(iOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.send(.deletePlaylist(playlist.id))
                            } label: {
                                Label(AppStrings.Common.delete, systemImage: "trash")
                            }
                        }
                        #else
                        .contextMenu {
                                    Button(role: .destructive) {
                                        store.send(.deletePlaylist(playlist.id))
                                    } label: {
                                        Label(AppStrings.Common.delete, systemImage: "trash")
                                    }
                                }
                        #endif
                    }
                } header: {
                    Text(AppStrings.PlaylistMgmt.savedAccounts)
                } footer: {
                    Text(AppStrings.PlaylistMgmt.switchNote)
                }
            }
            .navigationTitle(AppStrings.PlaylistMgmt.accountManagement)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            store.send(.closeTapped)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            store.send(.delegate(.addPlaylistTapped))
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .onAppear {
                    store.send(.onAppear)
                }
                .onDisappear {
                    store.send(.viewDidDisappear)
                }
                .sheet(
                    item: $store.scope(state: \.addPlaylist, action: \.addPlaylist)
                ) { addPlaylistStore in
                    NavigationStack {
                        AddPlaylistView(store: addPlaylistStore)
                    }
                }
        }
    }
}
