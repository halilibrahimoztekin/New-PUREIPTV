#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Live TV Category Bar (iOS)

    /// Horizontal category scroll bar with search filtering and Liquid Glass pills.
    struct LiveTVCategoryBar_iOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        @Binding var categorySearchQuery: String

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

                    ScrollViewReader { proxy in
                        Group {
                            if categories.isEmpty {
                                Text(AppStrings.Common.categoryNotFound)
                                    .font(AppFonts.caption)
                                    .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                                    .padding(.horizontal, 16)
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
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                        .onChange(of: categorySearchQuery) { _, _ in
                            guard let firstMatchID = categories.first?.id else { return }
                            if reduceMotion {
                                proxy.scrollTo(firstMatchID, anchor: .center)
                            } else {
                                withAnimation { proxy.scrollTo(firstMatchID, anchor: .center) }
                            }
                        }
                        .onChange(of: store.selectedCategoryID) { _, selectedID in
                            guard let selectedID,
                                  categories.contains(where: { $0.id == selectedID })
                            else { return }
                            if reduceMotion {
                                proxy.scrollTo(selectedID, anchor: .center)
                            } else {
                                withAnimation { proxy.scrollTo(selectedID, anchor: .center) }
                            }
                        }
                    }
                    // Constrain the reader itself. Constraining only the content inside
                    // ScrollViewReader can still let the reader claim the remaining
                    // vertical space in the parent VStack on iPhone layouts.
                    .frame(height: 40)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
#endif
