import ComposableArchitecture
import SwiftUI

public struct M3UCategoryMappingEditorView: View {
    let config: PlaylistConfig
    let onSave: () -> Void
    let onClose: () -> Void

    @Dependency(\.iptvClient) private var iptvClient
    @Dependency(\.m3uCategoryMappingClient) private var mappingClient
    @State private var tags: [String] = []
    @State private var mappings: [String: String] = [:]
    @State private var isLoading = true
    @State private var isSaving = false

    public init(config: PlaylistConfig, onSave: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.config = config
        self.onSave = onSave
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            Group {
                if config.playlistID == nil {
                    ContentUnavailableView(
                        AppStrings.M3UCategoryMapping.savedPlaylistRequired,
                        systemImage: "tag.slash",
                        description: Text(AppStrings.M3UCategoryMapping.savedPlaylistRequiredHint)
                    )
                } else if isLoading {
                    ProgressView(AppStrings.Common.loading)
                } else if tags.isEmpty {
                    ContentUnavailableView(
                        AppStrings.M3UCategoryMapping.noTags,
                        systemImage: "tag",
                        description: Text(AppStrings.M3UCategoryMapping.noTagsHint)
                    )
                } else {
                    List {
                        Section {
                            Text(AppStrings.M3UCategoryMapping.instructions)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(tags, id: \.self) { tag in
                            Section {
                                TextField(
                                    AppStrings.M3UCategoryMapping.destinationCategory,
                                    text: binding(for: tag)
                                )
                                .accessibilityLabel("\(AppStrings.M3UCategoryMapping.destinationCategory): \(tag)")
                            } header: {
                                Text(tag)
                                #if os(iOS)
                                    .textSelection(.enabled)
                                #endif
                            }
                        }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #else
                    .listStyle(.plain)
                    #endif
                }
            }
            .navigationTitle(AppStrings.M3UCategoryMapping.title)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.cancel, action: onClose)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppStrings.Common.save) { save() }
                            .disabled(isLoading || isSaving || config.playlistID == nil || tags.isEmpty)
                    }
                }
                .task(id: config.playlistID) { await load() }
        }
    }

    private func binding(for tag: String) -> Binding<String> {
        Binding(
            get: { mappings[tag] ?? "" },
            set: { mappings[tag] = $0 }
        )
    }

    @MainActor
    private func load() async {
        guard config.type == .m3u, let playlistID = config.playlistID else {
            tags = []
            isLoading = false
            return
        }
        async let loadedTags = iptvClient.fetchM3UCategoryTags(config)
        async let loadedMappings = mappingClient.load(playlistID)
        let (resolvedTags, resolvedMappings) = await (loadedTags, loadedMappings)
        guard !Task.isCancelled else { return }
        tags = resolvedTags
        mappings = resolvedMappings
        isLoading = false
    }

    @MainActor
    private func save() {
        guard let playlistID = config.playlistID else { return }
        isSaving = true
        let savedMappings = mappings
        Task {
            await mappingClient.save(savedMappings, playlistID)
            onSave()
        }
    }
}
