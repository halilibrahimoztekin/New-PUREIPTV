import SwiftUI

struct CategorySearchField: View {
    @Binding var text: String
    var onSubmit: () -> Void = {}

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.55))
                .accessibilityHidden(true)

            TextField(AppStrings.CategoryMgmt.searchPlaceholder, text: $text)
                .font(.body)
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFocused)
                .accessibilityLabel(AppStrings.CategoryMgmt.searchPlaceholder)
                .onSubmit {
                    isSearchFocused = false
                    onSubmit()
                }

            if !text.isEmpty {
                Button {
                    text = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AppStrings.Search.clear)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(minHeight: 48)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .accessibilityHidden(true)
        }
    }
}
