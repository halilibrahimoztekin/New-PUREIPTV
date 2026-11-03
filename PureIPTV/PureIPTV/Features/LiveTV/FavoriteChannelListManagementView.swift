import ComposableArchitecture
import SwiftUI
#if os(iOS)
    import UniformTypeIdentifiers
#endif

private struct FavoriteListExportWarningTarget: Identifiable {
    let id = UUID()
    let listID: UUID?
}

struct FavoriteChannelListSwitcher: View {
    @Bindable var store: StoreOf<LiveTVFeature>

    var body: some View {
        LiquidGlassContainer(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    #if os(tvOS)
                        Button {
                            store.send(.favoriteListSelected(nil))
                        } label: {
                            Text(AppStrings.Common.favorites)
                                .lineLimit(1)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .frame(minHeight: 44)
                                .background(isDefaultSelected ? AppColors.primary : AppColors.surfaceSecondary, in: Capsule())
                        }
                        .accessibilityLabel(AppStrings.Common.favorites)
                        .accessibilityAddTraits(isDefaultSelected ? .isSelected : [])
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: isDefaultSelected))
                    #else
                        LiquidGlassPill(
                            title: AppStrings.Common.favorites,
                            icon: "heart.fill",
                            isSelected: isDefaultSelected,
                            tint: AppColors.primary
                        ) {
                            HapticManager.shared.trigger(.light)
                            store.send(.favoriteListSelected(nil))
                        }
                        .accessibilityLabel(AppStrings.Common.favorites)
                        .accessibilityAddTraits(isDefaultSelected ? .isSelected : [])
                    #endif

                    ForEach(store.favoriteLists) { list in
                        let isSelected = store.selectedFavoriteListID == list.id && store.isFavoriteListMode
                        #if os(tvOS)
                            Button {
                                store.send(.favoriteListSelected(list.id))
                            } label: {
                                Text(list.name)
                                    .lineLimit(1)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .frame(minHeight: 44)
                                    .background(isSelected ? AppColors.primary : AppColors.surfaceSecondary, in: Capsule())
                            }
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                            .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: isSelected))
                        #else
                            LiquidGlassPill(
                                title: list.name,
                                isSelected: isSelected,
                                tint: AppColors.primary
                            ) {
                                HapticManager.shared.trigger(.light)
                                store.send(.favoriteListSelected(list.id))
                            }
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        #endif
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
                        #if os(tvOS)
                            .frame(minHeight: 44)
                            .background(AppColors.surfaceSecondary, in: Capsule())
                            .tvFocusEffect(shape: .capsule)
                        #else
                            .liquidGlass(shape: .capsule, isInteractive: true)
                        #endif
                    }

                    #if os(tvOS)
                        Button {
                            store.send(.favoriteListManagementTapped)
                        } label: {
                            Label(AppStrings.LiveTV.manageFavoriteLists, systemImage: "slider.horizontal.3")
                                .font(AppFonts.captionSemibold)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .frame(minHeight: 44)
                                .background(AppColors.surfaceSecondary, in: Capsule())
                        }
                        .accessibilityHint(AppStrings.LiveTV.manageFavoriteListsHint)
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                    #else
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.favoriteListManagementTapped)
                        } label: {
                            Label(AppStrings.LiveTV.manageFavoriteLists, systemImage: "slider.horizontal.3")
                                .font(AppFonts.captionSemibold)
                                .foregroundStyle(AppColors.textSecondary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                        }
                        .liquidGlass(shape: .capsule, isInteractive: true)
                        .buttonStyle(.plain)
                        .accessibilityHint(AppStrings.LiveTV.manageFavoriteListsHint)
                    #endif
                }
                .padding(.horizontal, 16)
            }
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
    @State private var exportWarningTarget: FavoriteListExportWarningTarget?
    @State private var isExporterPresented = false
    @State private var skippedExportMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage = store.favoriteListExportErrorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
                if let skippedExportMessage {
                    Section {
                        Text(skippedExportMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    TextField(AppStrings.LiveTV.favoriteListName, text: $name)
                        .onSubmit(save)
                    Button(editingID == nil ? AppStrings.LiveTV.createFavoriteList : AppStrings.LiveTV.saveFavoriteListName, action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text(AppStrings.LiveTV.newFavoriteList)
                }

                Section {
                    #if os(iOS)
                        HStack {
                            Button {
                                store.send(.favoriteListSelected(nil))
                                onDismiss()
                            } label: {
                                Label(AppStrings.Common.favorites, systemImage: store.isFavoriteListMode && store.selectedFavoriteListID == nil ? "checkmark.circle.fill" : "heart")
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            exportButton(for: nil)
                        }
                    #else
                        Button {
                            store.send(.favoriteListSelected(nil))
                            onDismiss()
                        } label: {
                            Label(AppStrings.Common.favorites, systemImage: store.isFavoriteListMode && store.selectedFavoriteListID == nil ? "checkmark.circle.fill" : "heart")
                        }
                    #endif
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
                            #if os(iOS)
                                exportButton(for: list.id)
                            #endif
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
        #if os(iOS)
        .fileExporter(
            isPresented: $isExporterPresented,
            document: FavoriteChannelListM3UDocument(data: store.favoriteListExport?.data ?? Data()),
            contentType: FavoriteChannelListM3UDocument.contentType,
            defaultFilename: store.favoriteListExport?.filename ?? "Favorites.m3u8"
        ) { result in
            if case .success = result,
               let export = store.favoriteListExport,
               export.skippedChannelCount > 0
            {
                skippedExportMessage = AppStrings.LiveTV.favoriteListExportSkipped(
                    export.exportedChannelCount,
                    export.skippedChannelCount
                )
            }
            store.send(.clearFavoriteListExport)
        }
        .onChange(of: store.favoriteListExport) { _, export in
            if export != nil {
                isExporterPresented = true
            }
        }
        .alert(
            AppStrings.LiveTV.favoriteListExportWarningTitle,
            isPresented: Binding(
                get: { exportWarningTarget != nil },
                set: {
                    if !$0 {
                        exportWarningTarget = nil
                    }
                }
            ),
            presenting: exportWarningTarget
        ) { target in
            Button(AppStrings.LiveTV.favoriteListExportContinue, role: .destructive) {
                skippedExportMessage = nil
                store.send(.exportFavoriteListTapped(target.listID))
                exportWarningTarget = nil
            }
            Button(AppStrings.Common.cancel, role: .cancel) {
                exportWarningTarget = nil
            }
        } message: { _ in
            Text(AppStrings.LiveTV.favoriteListExportWarningMessage)
        }
        .onDisappear {
            isExporterPresented = false
            store.send(.clearFavoriteListExport)
        }
        #endif
    }

    #if os(iOS)
        private func exportButton(for listID: UUID?) -> some View {
            Button {
                exportWarningTarget = FavoriteListExportWarningTarget(listID: listID)
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel(AppStrings.LiveTV.favoriteListExport)
        }
    #endif

    private func save() {
        store.send(.saveNamedFavoriteList(id: editingID, name: name))
        editingID = nil
        name = ""
    }
}

#if os(iOS)
    private struct FavoriteChannelListM3UDocument: FileDocument {
        static let contentType = UTType(filenameExtension: "m3u8", conformingTo: .plainText) ?? .plainText
        static var readableContentTypes: [UTType] {
            [contentType]
        }

        let data: Data

        init(data: Data) {
            self.data = data
        }

        init(configuration: ReadConfiguration) throws {
            data = configuration.file.regularFileContents ?? Data()
        }

        func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
            FileWrapper(regularFileWithContents: data)
        }
    }
#endif
