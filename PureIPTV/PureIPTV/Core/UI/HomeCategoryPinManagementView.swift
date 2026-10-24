import ComposableArchitecture
import SwiftUI

/// Lists every eligible catalog category, including categories that are not
/// part of the automatically selected Home shelves.
public struct HomeCategoryPinManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var store: StoreOf<DashboardFeature>

    public init(store: StoreOf<DashboardFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.availableHomeCategoryCollections) { collection in
                        let pinnedIndex = store.pinnedHomeCategoryIDs.firstIndex(of: collection.id)
                        let isPinned = pinnedIndex != nil
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.title)
                                    .lineLimit(2)
                                Text("\(collection.items.count) · \(collection.items.first?.title ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Button {
                                store.send(.toggleHomeCategoryPin(collection.id))
                            } label: {
                                Label(
                                    isPinned ? AppStrings.Dashboard.unpinHomeCategory : AppStrings.Dashboard.pinHomeCategory,
                                    systemImage: isPinned ? "pin.slash" : "pin"
                                )
                            }
                            .accessibilityHint(AppStrings.Dashboard.pinnedCategoryHint)
                            .contextMenu {
                                if let pinnedIndex {
                                    if pinnedIndex > 0 {
                                        Button(AppStrings.Dashboard.movePinnedCategoryUp, systemImage: "arrow.up") {
                                            store.send(.moveHomeCategoryPin(collection.id, -1))
                                        }
                                    }
                                    if pinnedIndex < store.pinnedHomeCategoryIDs.count - 1 {
                                        Button(AppStrings.Dashboard.movePinnedCategoryDown, systemImage: "arrow.down") {
                                            store.send(.moveHomeCategoryPin(collection.id, 1))
                                        }
                                    }
                                }
                            }
                        }
                        .accessibilityElement(children: .contain)
                    }
                } header: {
                    Text(AppStrings.Dashboard.manageHomeCategories)
                } footer: {
                    Text(AppStrings.Dashboard.pinnedCategoryHint)
                }
            }
            .overlay {
                if store.availableHomeCategoryCollections.isEmpty {
                    ContentUnavailableView(
                        AppStrings.Dashboard.noHomeCategories,
                        systemImage: "square.grid.2x2",
                        description: Text(AppStrings.Dashboard.homeCategoriesLoadHint)
                    )
                }
            }
            .navigationTitle(AppStrings.Dashboard.manageHomeCategories)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.Common.done) { dismiss() }
                }
            }
        }
    }
}
