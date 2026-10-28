import SwiftUI

/// Lists every eligible catalog category, including categories that are not
/// part of the automatically selected Home shelves.
public struct HomeCategoryPinManagementView: View {
    let state: DashboardFeature.State
    let send: (DashboardFeature.Action) -> Void
    let onClose: () -> Void

    public init(
        state: DashboardFeature.State,
        send: @escaping (DashboardFeature.Action) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.state = state
        self.send = send
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(state.availableHomeCategoryCollections) { collection in
                        let pinnedIndex = state.pinnedHomeCategoryIDs.firstIndex(of: collection.id)
                        let isPinned = pinnedIndex != nil
                        let firstItemTitle = collection.items.first?.title ?? ""
                        let itemSummary = "\(collection.items.count) · \(firstItemTitle)"
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.title)
                                    .lineLimit(2)
                                Text(itemSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Button {
                                send(.toggleHomeCategoryPin(collection.id))
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
                                            send(.moveHomeCategoryPin(collection.id, -1))
                                        }
                                    }
                                    if pinnedIndex < state.pinnedHomeCategoryIDs.count - 1 {
                                        Button(AppStrings.Dashboard.movePinnedCategoryDown, systemImage: "arrow.down") {
                                            send(.moveHomeCategoryPin(collection.id, 1))
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
                if state.availableHomeCategoryCollections.isEmpty {
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
                    Button(AppStrings.Common.done, action: onClose)
                }
            }
        }
    }
}
