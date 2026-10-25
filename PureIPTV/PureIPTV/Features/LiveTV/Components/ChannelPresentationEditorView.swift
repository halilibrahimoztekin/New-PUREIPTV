import SwiftUI

public struct ChannelPresentationEditorView: View {
    let channelTitle: String
    let currentName: String?
    let currentNumber: Int?
    let onSave: (String, Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var numberText: String

    public init(
        channelTitle: String,
        currentName: String?,
        currentNumber: Int?,
        onSave: @escaping (String, Int?) -> Void
    ) {
        self.channelTitle = channelTitle
        self.currentName = currentName
        self.currentNumber = currentNumber
        self.onSave = onSave
        _name = State(initialValue: currentName ?? "")
        _numberText = State(initialValue: currentNumber.map(String.init) ?? "")
    }

    private var parsedNumber: Int? {
        guard !numberText.isEmpty, let number = Int(numberText), (1 ... 999_999).contains(number) else { return nil }
        return number
    }

    private var numberIsValid: Bool {
        numberText.isEmpty || parsedNumber != nil
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(channelTitle) {
                    TextField(AppStrings.LiveTV.channelName, text: $name)
                        .accessibilityLabel(AppStrings.LiveTV.channelName)
                        .textInputAutocapitalization(.words)
                    TextField(AppStrings.LiveTV.channelNumber, text: $numberText)
                        .accessibilityLabel(AppStrings.LiveTV.channelNumber)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                }
                Section {
                    Button(AppStrings.LiveTV.resetChannelPresentation, role: .destructive) {
                        name = ""
                        numberText = ""
                        onSave("", nil)
                        dismiss()
                    }
                }
            }
            .navigationTitle(AppStrings.LiveTV.editChannelPresentation)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppStrings.Common.save) {
                            onSave(name, parsedNumber)
                            dismiss()
                        }
                        .disabled(!numberIsValid)
                    }
                }
        }
    }
}
