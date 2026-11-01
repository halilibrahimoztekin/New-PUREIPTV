import ComposableArchitecture
import SwiftUI

struct AwardRecognitionMetadataView: View {
    let recognitions: [WikidataAwardClient.Recognition]

    private var winnerCount: Int {
        recognitions.filter { $0.kind == .winner }.reduce(0) { $0 + $1.recognitionCount }
    }

    private var nominationCount: Int {
        recognitions.filter { $0.kind == .nominee }.reduce(0) { $0 + $1.recognitionCount }
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                if winnerCount > 0 {
                    Label(
                        String(format: AppStrings.Dashboard.awardRecognitionCount, winnerCount),
                        systemImage: "trophy.fill"
                    )
                }
                if nominationCount > 0 {
                    Label(
                        String(format: AppStrings.Dashboard.awardNominationCount, nominationCount),
                        systemImage: "checkmark.seal.fill"
                    )
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.86))

            Spacer(minLength: 12)

            Text("Wikidata")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct SeriesEpisodeCatalogDiagnosticsView: View {
    let diagnostics: DetailModels.SeriesCatalogDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(AppStrings.SeriesDetail.catalogDiagnosticsTitle, systemImage: "exclamationmark.magnifyingglass")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Text(AppStrings.SeriesDetail.catalogDiagnosticsDescription)
                .font(.body)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            if !diagnostics.missingEpisodeRanges.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppStrings.SeriesDetail.possibleMissingEpisodeNumbers)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                    ForEach(diagnostics.missingEpisodeRanges) { range in
                        Text("S\(String(format: "%02d", range.seasonNumber))E\(range.firstMissingEpisode)–E\(range.lastMissingEpisode)")
                            .font(.body.monospaced())
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
            }

            if !diagnostics.duplicateEpisodePositions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppStrings.SeriesDetail.duplicateEpisodePositions)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                    ForEach(diagnostics.duplicateEpisodePositions) { position in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("S\(String(format: "%02d", position.seasonNumber))E\(position.episodeNumber)")
                                .font(.body.monospaced())
                                .foregroundStyle(.white.opacity(0.78))
                            Text("\(AppStrings.SeriesDetail.sourceIDs): \(position.sourceIDs.joined(separator: ", "))")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.65))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

public struct SeriesDetailView: View {
    let store: StoreOf<SeriesDetailFeature>
    let onPresentSynopsis: (String) -> Void
    @State private var hasDisappeared = false

    public init(
        store: StoreOf<SeriesDetailFeature>,
        onPresentSynopsis: @escaping (String) -> Void = { _ in }
    ) {
        self.store = store
        self.onPresentSynopsis = onPresentSynopsis
    }

    public var body: some View {
        Group {
            #if os(tvOS)
                SeriesDetailView_tvOS(store: store, onPresentSynopsis: onPresentSynopsis)
                    .onAppear { hasDisappeared = false }
                    .onDisappear {
                        guard !hasDisappeared else { return }
                        hasDisappeared = true
                        store.send(.viewDidDisappear)
                    }
            #else
                SeriesDetailView_iOS(store: store, onPresentSynopsis: onPresentSynopsis)
                    .onAppear { hasDisappeared = false }
                    .onDisappear {
                        guard !hasDisappeared else { return }
                        hasDisappeared = true
                        store.send(.viewDidDisappear)
                    }
            #endif
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
                mediaTitle: store.series.displayTitle,
                override: store.series.presentationOverride,
                onSave: { store.send(.savePresentationOverride($0)) },
                onClose: { store.send(.dismissPresentationEditor) }
            )
        }
        .confirmationDialog(
            AppStrings.Downloads.deleteDownloadTitle,
            isPresented: Binding(
                get: { store.isConfirmingEpisodeDeletion },
                set: { isPresented in
                    if !isPresented {
                        store.send(.downloadedEpisodeDeletionDialogDismissed)
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(AppStrings.Common.delete, role: .destructive) {
                store.send(.confirmDownloadedEpisodeDeletion)
            }
            Button(AppStrings.Common.cancel, role: .cancel) {
                store.send(.cancelDownloadedEpisodeDeletion)
            }
        } message: {
            Text(AppStrings.Downloads.deleteDownloadMessage(store.pendingDeleteEpisodeTitle ?? store.series.displayTitle))
        }
        .alert(
            AppStrings.Downloads.deleteDownloadTitle,
            isPresented: Binding(
                get: { store.downloadErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.send(.dismissDownloadError)
                    }
                }
            )
        ) {
            Button(AppStrings.Common.close, role: .cancel) {
                store.send(.dismissDownloadError)
            }
        } message: {
            Text(store.downloadErrorMessage ?? AppStrings.Downloads.deleteDownloadFailure)
        }
    }
}
