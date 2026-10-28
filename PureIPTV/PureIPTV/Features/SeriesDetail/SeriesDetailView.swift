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
        #if os(tvOS)
            SeriesDetailView_tvOS(store: store, onPresentSynopsis: onPresentSynopsis)
                .onAppear { hasDisappeared = false }
                .onDisappear {
                    guard !hasDisappeared else { return }
                    hasDisappeared = true
                    store.send(.viewDidDisappear)
                }
        #else
            SeriesDetailView_iOS(store: store)
                .onAppear { hasDisappeared = false }
                .onDisappear {
                    guard !hasDisappeared else { return }
                    hasDisappeared = true
                    store.send(.viewDidDisappear)
                }
        #endif
    }
}
