#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS Dashboard Quick Categories Shelf

    /// Category and collection showcase shelf with pinned category management on Apple TV.
    public struct DashboardQuickCategoriesShelf_tvOS: View {
        public let collection: DashboardFeature.ExploreCollection
        public let store: StoreOf<DashboardFeature>

        public init(
            collection: DashboardFeature.ExploreCollection,
            store: StoreOf<DashboardFeature>
        ) {
            self.collection = collection
            self.store = store
        }

        public var body: some View {
            let isPinned = store.pinnedHomeCategoryIDs.contains(collection.id)
            let canPin = collection.id.hasPrefix("live-category:") || collection.id.hasPrefix("movie-category:") || collection.id.hasPrefix("series-category:")

            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 18) {
                    Text(collection.title)
                        .font(AppFonts.displayMedium)
                        .foregroundStyle(AppColors.textPrimary)

                    if canPin {
                        Button {
                            store.send(.toggleHomeCategoryPin(collection.id))
                        } label: {
                            Label(
                                isPinned ? AppStrings.Dashboard.unpinHomeCategory : AppStrings.Dashboard.pinHomeCategory,
                                systemImage: isPinned ? "pin.slash.fill" : "pin.fill"
                            )
                        }
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                        .accessibilityHint(AppStrings.Dashboard.pinnedCategoryHint)
                        .contextMenu {
                            if isPinned, let index = store.pinnedHomeCategoryIDs.firstIndex(of: collection.id) {
                                if index > 0 {
                                    Button {
                                        store.send(.moveHomeCategoryPin(collection.id, -1))
                                    } label: {
                                        Label(AppStrings.Dashboard.movePinnedCategoryUp, systemImage: "arrow.up")
                                    }
                                }
                                if index + 1 < store.pinnedHomeCategoryIDs.count {
                                    Button {
                                        store.send(.moveHomeCategoryPin(collection.id, 1))
                                    } label: {
                                        Label(AppStrings.Dashboard.movePinnedCategoryDown, systemImage: "arrow.down")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 40) {
                        ForEach(collection.items) { item in
                            if item.type == .live {
                                TVChannelCard(channel: item, isSelected: false) { store.send(.channelSelected(item)) }
                                    .frame(width: 340)
                            } else if item.type == .series {
                                TVSeriesCard(series: item, isSelected: false) { store.send(.seriesSelected(item)) }
                                    .frame(width: 220)
                            } else {
                                TVVODCard(vod: item, isSelected: false) { store.send(.vodSelected(item)) }
                                    .frame(width: 220)
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 40)
                }
                .focusSection()
            }
        }
    }
#endif
