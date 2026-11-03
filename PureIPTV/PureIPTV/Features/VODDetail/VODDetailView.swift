import ComposableArchitecture
import SwiftUI

public struct VODDetailView: View {
    let store: StoreOf<VODDetailFeature>
    let onPresentSynopsis: (String) -> Void
    @State private var hasDisappeared = false

    public init(
        store: StoreOf<VODDetailFeature>,
        onPresentSynopsis: @escaping (String) -> Void = { _ in }
    ) {
        self.store = store
        self.onPresentSynopsis = onPresentSynopsis
    }

    public var body: some View {
        Group {
            #if os(tvOS)
                VODDetailView_tvOS(store: store, onPresentSynopsis: onPresentSynopsis)
                    .onAppear { hasDisappeared = false }
                    .onDisappear {
                        guard !hasDisappeared else { return }
                        hasDisappeared = true
                        store.send(.viewDidDisappear)
                    }
            #else
                VODDetailView_iOS(store: store, onPresentSynopsis: onPresentSynopsis)
                    .onAppear { hasDisappeared = false }
                    .onDisappear {
                        guard !hasDisappeared else { return }
                        hasDisappeared = true
                        store.send(.viewDidDisappear)
                    }
            #endif
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 8) {
                if store.canManageTMDBMatch {
                    Button {
                        store.send(.showTMDBMatchPicker)
                    } label: {
                        Label(AppStrings.TMDBMatchPicker.title, systemImage: "film")
                            .font(AppFonts.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .liquidGlass(shape: .capsule, isInteractive: true)
                    }
                    .accessibilityHint(AppStrings.TMDBMatchPicker.searchAccessibilityLabel)
                }

                if store.canManagePresentation {
                    Button {
                        store.send(.editPresentationTapped)
                    } label: {
                        Label(AppStrings.MediaPresentation.edit, systemImage: "pencil")
                            .font(AppFonts.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .liquidGlass(shape: .capsule, isInteractive: true)
                    }
                    .disabled(!store.isPresentationOverrideLoaded)
                    .accessibilityHint(AppStrings.MediaPresentation.localOnlyDescription)
                }
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .sheet(
            isPresented: Binding(
                get: { store.isPresentationEditorPresented },
                set: { isPresented in
                    if !isPresented {
                        store.send(.dismissPresentationEditor)
                    }
                }
            )
        ) {
            MediaPresentationEditorView(
                mediaTitle: store.vod.displayTitle,
                override: store.vod.presentationOverride,
                onSave: { store.send(.savePresentationOverride($0)) },
                onClose: { store.send(.dismissPresentationEditor) }
            )
        }
        .confirmationDialog(
            AppStrings.Downloads.deleteDownloadTitle,
            isPresented: Binding(
                get: { store.isConfirmingDownloadDeletion },
                set: { isPresented in
                    if !isPresented {
                        store.send(.downloadDeletionDialogDismissed)
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(AppStrings.Common.delete, role: .destructive) {
                store.send(.confirmDownloadDeletion)
            }
            Button(AppStrings.Common.cancel, role: .cancel) {
                store.send(.cancelDownloadDeletion)
            }
        } message: {
            Text(AppStrings.Downloads.deleteDownloadMessage(store.vod.displayTitle))
        }
    }
}
