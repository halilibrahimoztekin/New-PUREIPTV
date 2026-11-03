import SwiftUI

struct CategoryContentSortMenu: View {
    let selection: SortMethod
    let categoryName: String
    let hasCategoryOverride: Bool
    let onSelect: (SortMethod) -> Void
    let onReset: () -> Void

    var body: some View {
        Menu {
            Section(AppStrings.Settings.contentSorting) {
                ForEach(SortMethod.allCases) { method in
                    Button {
                        onSelect(method)
                    } label: {
                        if selection == method {
                            Label(method.title, systemImage: "checkmark")
                        } else {
                            Text(method.title)
                        }
                    }
                }
            }

            if hasCategoryOverride {
                Button(action: onReset) {
                    Label(AppStrings.Settings.useLibrarySortDefault, systemImage: "arrow.uturn.backward")
                }
            }
        } label: {
            Label(selection.title, systemImage: "arrow.up.arrow.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(AppColors.surfaceSecondary, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        #if os(tvOS)
        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: hasCategoryOverride))
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel("\(AppStrings.Settings.contentSorting): \(categoryName)")
        .accessibilityValue(selection.title)
    }
}
