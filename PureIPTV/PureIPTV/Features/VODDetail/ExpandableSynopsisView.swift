import SwiftUI

struct ExpandableSynopsisView: View {
    let text: String
    let font: Font
    let lineLimit: Int
    let onPresent: () -> Void

    var body: some View {
        Button {
            onPresent()
        } label: {
            Text(text)
                .font(font)
                .foregroundStyle(AppColors.onSurface)
                .lineSpacing(6)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        #if os(tvOS)
            .tvFocusEffect(shape: .roundedRectangle(cornerRadius: 8))
        #endif
            .accessibilityLabel(AppStrings.VODDetail.overview)
            .accessibilityHint(AppStrings.Common.more)
    }
}
