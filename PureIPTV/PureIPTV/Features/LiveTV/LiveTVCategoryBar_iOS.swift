#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Live TV Category Bar (iOS)

    /// Horizontal category scroll bar with search filtering and Liquid Glass pills.
    struct LiveTVCategoryBar_iOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        @Binding var categorySearchQuery: String

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var scrollPositionID: String?

        private var filteredCategories: [MediaModels.Category] {
            let query = categorySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return store.categories }
            return store.categories.filter { $0.name.localizedStandardContains(query) }
        }

        var body: some View {
            let categories = filteredCategories

            VStack(spacing: 8) {
                if !store.categories.isEmpty {
                    CategorySearchField(text: $categorySearchQuery) {
                        if let firstMatch = categories.first {
                            store.send(.categorySelected(firstMatch))
                        }
                    }
                    .padding(.horizontal, 16)

                    Group {
                        if categories.isEmpty {
                            Text(AppStrings.Common.categoryNotFound)
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                        } else {
                            LiquidGlassContainer(spacing: 8) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 8) {
                                        ForEach(categories) { category in
                                            LiquidGlassPill(
                                                title: category.name,
                                                isSelected: store.selectedCategoryID == category.id,
                                                tint: AppColors.primary
                                            ) {
                                                HapticManager.shared.trigger(.light)
                                                store.send(.categorySelected(category))
                                            }
                                            .id(category.id)
                                            .accessibilityIdentifier("liveTV.category.\(category.id)")
                                        }
                                    }
                                    .scrollTargetLayout()
                                    .padding(.horizontal, 16)
                                }
                                .scrollPosition(id: $scrollPositionID, anchor: .center)
                                .frame(height: 44)
                                .accessibilityIdentifier("liveTV.categoryFilterScroll")
                            }
                            .frame(height: 44)
                        }
                    }
                    .onChange(of: categorySearchQuery) { _, _ in
                        scrollTo(categories.first?.id)
                    }
                    .onChange(of: store.selectedCategoryID) { _, selectedID in
                        guard let selectedID,
                              categories.contains(where: { $0.id == selectedID })
                        else { return }
                        scrollTo(selectedID)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }

        private func scrollTo(_ id: String?) {
            guard let id else { return }
            if reduceMotion {
                scrollPositionID = id
            } else {
                withAnimation(.snappy(duration: 0.25)) {
                    scrollPositionID = id
                }
            }
        }
    }
#endif
