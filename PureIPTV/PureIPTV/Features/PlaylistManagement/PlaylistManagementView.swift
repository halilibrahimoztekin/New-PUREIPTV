import ComposableArchitecture
import SwiftUI

public struct PlaylistManagementView: View {
    @Bindable var store: StoreOf<PlaylistManagementFeature>
    @State private var hasDisappeared = false

    public init(store: StoreOf<PlaylistManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            // Section: Saved Playlists
            Section {
                ForEach(store.playlists) { playlist in
                    playlistRow(playlist)
                    #if os(iOS)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                store.send(.editPlaylistSettings(playlist))
                            } label: {
                                Label(AppStrings.PlaylistMgmt.playbackSettings, systemImage: "slider.horizontal.3")
                            }
                            Button(role: .destructive) {
                                store.send(.confirmDeletePlaylist(playlist))
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

            // Section: Add Account Button
            Section {
                Button {
                    store.send(.addPlaylistButtonTapped)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(hex: "#0A84FF"))
                        Text(AppStrings.PlaylistMgmt.addAccount)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(hex: "#0A84FF"))
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                #if os(tvOS)
                .buttonStyle(TVCategoryRowButtonStyle(accentColor: Color(hex: "#0A84FF"), isSelected: false))
                #else
                .buttonStyle(.plain)
                #endif
            }
        }
        .navigationTitle(AppStrings.PlaylistMgmt.accountManagement)
        #if os(iOS)
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        store.send(.closeTapped)
                    } label: {
                        #if os(tvOS)
                            Text(AppStrings.Common.cancel)
                        #else
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                        #endif
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.addPlaylistButtonTapped)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                hasDisappeared = false
                store.send(.onAppear)
            }
            .onDisappear {
                guard !hasDisappeared else { return }
                hasDisappeared = true
                store.send(.viewDidDisappear)
            }
        #if os(tvOS)
            .onExitCommand {
                store.send(.closeTapped)
            }
        #endif
            .confirmationDialog(
                AppStrings.Common.delete,
                isPresented: Binding(
                    get: { store.playlistToDelete != nil },
                    set: {
                        if !$0 {
                            store.send(.cancelDeletePlaylist)
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button(AppStrings.Common.delete, role: .destructive) {
                    store.send(.deletePlaylistConfirmed)
                }
                Button(AppStrings.Common.cancel, role: .cancel) {
                    store.send(.cancelDeletePlaylist)
                }
            } message: {
                if let name = store.playlistToDelete?.name {
                    Text("\"\(name)\" çalma listesini silmek istediğinize emin misiniz?")
                }
            }
            .sheet(
                item: $store.scope(state: \.addPlaylist, action: \.addPlaylist)
            ) { addPlaylistStore in
                NavigationStack {
                    AddPlaylistView(store: addPlaylistStore)
                    #if os(tvOS)
                        .onExitCommand {
                            store.send(.closeAddPlaylistTapped)
                        }
                    #endif
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { store.playlistBeingEdited != nil },
                    set: { isPresented in
                        if !isPresented {
                            store.send(.cancelPlaylistSettings)
                        }
                    }
                )
            ) {
                if let playlist = store.playlistBeingEdited {
                    NavigationStack {
                        playlistSettingsForm(for: playlist)
                            .navigationTitle(AppStrings.PlaylistMgmt.playbackSettings)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button(AppStrings.Common.cancel) {
                                        store.send(.cancelPlaylistSettings)
                                    }
                                }
                                ToolbarItem(placement: .confirmationAction) {
                                    Button(AppStrings.Common.save) {
                                        store.send(.savePlaylistSettings)
                                    }
                                    .disabled(!canSaveUserAgentDraft)
                                }
                            }
                    }
                }
            }
    }

    // MARK: - Playlist Row

    @ViewBuilder
    private func playlistRow(_ playlist: SavedPlaylist) -> some View {
        let isActive = store.activePlaylistID == playlist.id

        Button {
            store.send(.setActivePlaylist(playlist.id))
        } label: {
            HStack(spacing: 16) {
                // Type Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? Color(hex: "#0A84FF").opacity(0.2) : Color.white.opacity(0.08))
                        .frame(width: 44, height: 44)

                    Image(systemName: playlist.type == .xtream ? "server.rack" : "doc.text")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isActive ? Color(hex: "#0A84FF") : Color.white.opacity(0.6))
                }

                // Title & Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(playlist.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.white)

                        if isActive {
                            Text("Aktif")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.green))
                        }
                    }

                    Text(playlist.serverURL ?? playlist.m3uURL ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                #if os(tvOS)
                    Button {
                        store.send(.editPlaylistSettings(playlist))
                    } label: {
                        Image(systemName: "text.badge.checkmark")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: "#0A84FF"))
                            .padding(8)
                    }
                    .buttonStyle(TVCircleButtonStyle())
                    .accessibilityLabel(AppStrings.PlaylistMgmt.playbackSettings)

                    // Delete button on tvOS
                    Button {
                        store.send(.confirmDeletePlaylist(playlist))
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.red.opacity(0.8))
                            .padding(8)
                    }
                    .buttonStyle(TVCircleButtonStyle())
                #endif

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.green)
                }
            }
            .padding(.vertical, 4)
        }
        #if os(tvOS)
        .buttonStyle(TVCategoryRowButtonStyle(accentColor: Color(hex: "#0A84FF"), isSelected: isActive))
        #else
        .buttonStyle(.plain)
        #endif
    }

    private var canSaveUserAgentDraft: Bool {
        let value = store.userAgentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.utf8.count <= 512
            && value.rangeOfCharacter(from: .controlCharacters) == nil
    }

    private var channelZappingDelayValue: String {
        guard store.channelZappingDelayDraft > 0 else { return AppStrings.Player.off }
        return AppStrings.PlaylistMgmt.channelZappingDelayValue(store.channelZappingDelayDraft)
    }

    private func playlistSettingsForm(for playlist: SavedPlaylist) -> some View {
        Form {
            Section(playlist.name) {
                TextField("User-Agent", text: $store.userAgentDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("\(playlist.name) için özel User-Agent")
                Text("Boş bırakılırsa uygulamanın genel User-Agent değeri kullanılır.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    #if os(tvOS)
                        Picker(AppStrings.PlaylistMgmt.channelZappingDelay, selection: $store.channelZappingDelayDraft) {
                            ForEach(Array(stride(from: 0, through: 3000, by: 250)), id: \.self) { delay in
                                Text(delay == 0 ? AppStrings.Player.off : AppStrings.PlaylistMgmt.channelZappingDelayValue(delay))
                                    .tag(delay)
                            }
                        }
                        .pickerStyle(.menu)
                    #else
                        Stepper(value: $store.channelZappingDelayDraft, in: 0 ... 3000, step: 250) {
                            HStack {
                                Text(AppStrings.PlaylistMgmt.channelZappingDelay)
                                Spacer()
                                Text(channelZappingDelayValue)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    #endif
                    Text(AppStrings.PlaylistMgmt.channelZappingDelayDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let message = store.userAgentValidationMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
