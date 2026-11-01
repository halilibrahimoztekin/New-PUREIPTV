import SwiftUI

public struct CategoryNameEditorView: View {
    let sourceName: String
    let onSave: (String) -> Void
    let onClose: () -> Void

    @State private var name: String

    public init(
        sourceName: String,
        currentName: String,
        onSave: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.sourceName = sourceName
        self.onSave = onSave
        self.onClose = onClose
        _name = State(initialValue: currentName)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(sourceName) {
                    TextField(AppStrings.CategoryMgmt.categoryName, text: $name)
                        .accessibilityLabel(AppStrings.CategoryMgmt.categoryName)
                        .textInputAutocapitalization(.words)
                }
                Section {
                    Button(AppStrings.CategoryMgmt.resetCategoryName, role: .destructive) {
                        onSave("")
                        onClose()
                    }
                }
            }
            .navigationTitle(AppStrings.CategoryMgmt.editCategoryName)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.cancel, action: onClose)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppStrings.Common.save) {
                            onSave(name)
                            onClose()
                        }
                    }
                }
        }
    }
}
