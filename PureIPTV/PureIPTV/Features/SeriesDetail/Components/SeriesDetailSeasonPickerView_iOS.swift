#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SeriesDetailSeasonPickerView_iOS: View {
        let store: StoreOf<SeriesDetailFeature>

        public init(store: StoreOf<SeriesDetailFeature>) {
            self.store = store
        }

        public var body: some View {
            if !store.seasons.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text(AppStrings.SeriesDetail.seasons)
                        .font(AppFonts.titleLarge)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 24)

                    SeasonPickerPillsView(
                        seasons: store.seasons,
                        selectedSeasonNumber: store.selectedSeasonNumber,
                        allEpisodes: store.allEpisodes,
                        onSelectSeason: { seasonNum in
                            store.send(.seasonSelected(seasonNum))
                        }
                    )
                    .padding(.horizontal, 24)
                }
            } else if store.isLoading {
                VStack(alignment: .leading, spacing: 14) {
                    Text(AppStrings.SeriesDetail.seasons)
                        .font(AppFonts.titleLarge)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 24)

                    HStack(spacing: 10) {
                        ForEach(0 ..< 4, id: \.self) { _ in
                            Capsule()
                                .fill(AppColors.borderMedium)
                                .frame(width: 90, height: 36)
                                .shimmeringPlaceholder(isLoading: true)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
#endif
