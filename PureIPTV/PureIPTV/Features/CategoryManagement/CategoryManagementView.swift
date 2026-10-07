import ComposableArchitecture
import SwiftUI

public struct CategoryManagementView: View {
    @Bindable var store: StoreOf<CategoryManagementFeature>

    public init(store: StoreOf<CategoryManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView()
                } else if store.categories.isEmpty {
                    Text(AppStrings.CategoryMgmt.noCategoriesFound)
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(store.categories) { category in
                            HStack {
                                Text(category.name)
                                Spacer()

                                let isHidden = store.categoryPreferences[category.id]?.isHidden ?? false

                                Button(action: {
                                    store.send(.toggleVisibility(categoryID: category.id))
                                }) {
                                    Image(systemName: isHidden ? "eye.slash" : "eye")
                                        .foregroundColor(isHidden ? .red : .green)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onMove { source, destination in
                            store.send(.moveCategory(from: source, to: destination))
                        }
                    }
                    #if os(iOS)
                    .environment(\.editMode, .constant(.active))
                    #endif
                }
            }
            .navigationTitle(String(localized: "\(store.type.title) Kategorilerini Yönet"))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.cancel) {
                            store.send(.closeTapped)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppStrings.Common.save) {
                            store.send(.saveTapped)
                        }
                        .disabled(!store.hasUnsavedChanges)
                    }
                }
                .onAppear {
                    store.send(.onAppear)
                }
        }
    }
}
