import ComposableArchitecture
import SwiftUI

public struct SmartChannelGroupManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var store: StoreOf<LiveTVFeature>
    @State private var editingID: String?
    @State private var name = ""
    @State private var selectedCategoryIDs: [String] = []

    public init(store: StoreOf<LiveTVFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            List {
                Section(AppStrings.LiveTV.smartGroups) {
                    ForEach(store.smartChannelGroups) { group in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                Text(AppStrings.LiveTV.smartGroupCategoryCount(group.categoryIDs.count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(AppStrings.Common.edit) {
                                editingID = group.id
                                name = group.name
                                selectedCategoryIDs = group.categoryIDs
                            }
                            .accessibilityLabel("\(AppStrings.Common.edit): \(group.name)")
                            Button(role: .destructive) {
                                store.send(.deleteSmartChannelGroup(group.id))
                                if editingID == group.id {
                                    resetEditor()
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("\(AppStrings.Common.delete): \(group.name)")
                        }
                    }
                    Button {
                        resetEditor()
                    } label: {
                        Label(AppStrings.LiveTV.newSmartGroup, systemImage: "plus")
                    }
                }

                Section {
                    TextField(AppStrings.LiveTV.smartGroupName, text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel(AppStrings.LiveTV.smartGroupName)
                    ForEach(store.smartGroupSelectableCategories) { category in
                        categoryChoice(id: category.id, title: category.name, isUnavailable: false)
                    }
                    ForEach(selectedCategoryIDs.filter { id in !store.smartGroupSelectableCategories.contains(where: { $0.id == id }) }, id: \.self) { categoryID in
                        categoryChoice(id: categoryID, title: "\(AppStrings.LiveTV.unavailableSmartGroupCategory): \(categoryID)", isUnavailable: true)
                    }
                    Button {
                        let groupID = editingID ?? UUID().uuidString
                        editingID = groupID
                        store.send(.saveSmartChannelGroup(
                            id: groupID,
                            name: name,
                            categoryIDs: selectedCategoryIDs
                        ))
                    } label: {
                        Label(AppStrings.Common.save, systemImage: "checkmark")
                    }
                    .disabled(store.isLoadingSmartGroups || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategoryIDs.isEmpty)
                    .accessibilityHint(AppStrings.LiveTV.smartGroupPrivacyHint)
                } header: {
                    Text(editingID == nil ? AppStrings.LiveTV.newSmartGroup : AppStrings.LiveTV.editSmartGroup)
                } footer: {
                    Text(AppStrings.LiveTV.smartGroupPrivacyHint)
                }
            }
            .navigationTitle(AppStrings.LiveTV.smartGroups)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.Common.done) { dismiss() }
                }
            }
        }
    }

    private func categoryChoice(id: String, title: String, isUnavailable: Bool) -> some View {
        let isSelected = selectedCategoryIDs.contains(id)
        let hasReachedLimit = !isSelected && selectedCategoryIDs.count >= SmartChannelGroup.maximumCategoryCount
        return Button {
            if isSelected {
                selectedCategoryIDs.removeAll { $0 == id }
            } else if !isUnavailable, selectedCategoryIDs.count < SmartChannelGroup.maximumCategoryCount {
                selectedCategoryIDs.append(id)
            }
        } label: {
            HStack {
                Text(title)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled((isUnavailable && !isSelected) || hasReachedLimit)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? AppStrings.LiveTV.selected : AppStrings.LiveTV.notSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func resetEditor() {
        editingID = nil
        name = ""
        selectedCategoryIDs = []
    }
}
