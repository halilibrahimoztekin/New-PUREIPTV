import SwiftUI

public struct MediaPresentationEditorView: View {
    private let mediaTitle: String
    private let onSave: (MediaPresentationOverride?) -> Void
    private let onClose: () -> Void

    @State private var title: String
    @State private var posterURL: String
    @State private var year: String

    public init(
        mediaTitle: String,
        override: MediaPresentationOverride?,
        onSave: @escaping (MediaPresentationOverride?) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.mediaTitle = mediaTitle
        self.onSave = onSave
        self.onClose = onClose
        _title = State(initialValue: override?.title ?? "")
        _posterURL = State(initialValue: override?.posterURLString ?? "")
        _year = State(initialValue: override?.year.map(String.init) ?? "")
    }

    private var parsedYear: Int? {
        guard !year.isEmpty else { return nil }
        return Int(year)
    }

    private var yearIsValid: Bool {
        year.isEmpty || parsedYear.map { (1888 ... 2100).contains($0) } == true
    }

    private var posterURLIsValid: Bool {
        posterURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || MediaPresentationOverride(title: nil, posterURLString: posterURL, year: nil).posterURLString != nil
    }

    private var canSave: Bool {
        yearIsValid && posterURLIsValid
    }

    private var normalizedOverride: MediaPresentationOverride? {
        let value = MediaPresentationOverride(title: title, posterURLString: posterURL, year: parsedYear)
        return value.isEmpty ? nil : value
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(mediaTitle) {
                    TextField(AppStrings.MediaPresentation.title, text: Binding(
                        get: { title },
                        set: { title = String($0.prefix(120)) }
                    ))
                    .textInputAutocapitalization(.words)

                    TextField(AppStrings.MediaPresentation.posterURL, text: $posterURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    #if os(iOS)
                        .keyboardType(.URL)
                    #endif
                    Text(AppStrings.MediaPresentation.posterURLDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if !posterURLIsValid {
                        Text(AppStrings.MediaPresentation.posterURLDescription)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    TextField(AppStrings.MediaPresentation.year, text: $year)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                    if !yearIsValid {
                        Text(AppStrings.MediaPresentation.invalidYear)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Text(AppStrings.MediaPresentation.localOnlyDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(AppStrings.MediaPresentation.reset, role: .destructive) {
                        onSave(nil)
                    }
                }
            }
            .navigationTitle(AppStrings.MediaPresentation.edit)
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.cancel, action: onClose)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppStrings.Common.save) {
                            onSave(normalizedOverride)
                        }
                        .disabled(!canSave)
                    }
                }
        }
    }
}
