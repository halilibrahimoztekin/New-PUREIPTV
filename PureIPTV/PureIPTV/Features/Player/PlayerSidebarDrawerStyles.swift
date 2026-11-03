import SwiftUI

#if os(tvOS)

    // MARK: - tvOS Sidebar Drawer Button Styles

    struct TVCategoryFilterChipButtonStyle: ButtonStyle {
        let isSelected: Bool
        let accentColor: Color

        func makeBody(configuration: Configuration) -> some View {
            TVCategoryFilterChipBody(configuration: configuration, isSelected: isSelected, accentColor: accentColor)
        }

        private struct TVCategoryFilterChipBody: View {
            let configuration: Configuration
            let isSelected: Bool
            let accentColor: Color
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .scaleEffect(isFocused ? 1.08 : 1.0)
                    .brightness(isFocused ? 0.15 : 0.0)
                    .shadow(
                        color: isFocused ? accentColor.opacity(0.65) : .clear,
                        radius: isFocused ? 10 : 0,
                        x: 0,
                        y: 0
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
                    .tvHighContrastFocusOutline(isFocused: isFocused, shape: .capsule)
            }
        }
    }

    struct TVSortOptionButtonStyle: ButtonStyle {
        let accentColor: Color

        func makeBody(configuration: Configuration) -> some View {
            TVSortOptionBody(configuration: configuration, accentColor: accentColor)
        }

        private struct TVSortOptionBody: View {
            let configuration: Configuration
            let accentColor: Color
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .scaleEffect(isFocused ? 1.08 : 1.0)
                    .brightness(isFocused ? 0.2 : 0.0)
                    .shadow(
                        color: isFocused ? accentColor.opacity(0.8) : .clear,
                        radius: isFocused ? 10 : 0,
                        x: 0,
                        y: 0
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
                    .tvHighContrastFocusOutline(isFocused: isFocused, shape: .roundedRectangle(cornerRadius: 12))
            }
        }
    }

    struct TVCleanerButtonStyle: ButtonStyle {
        let isActive: Bool

        func makeBody(configuration: Configuration) -> some View {
            TVCleanerBody(configuration: configuration, isActive: isActive)
        }

        private struct TVCleanerBody: View {
            let configuration: Configuration
            let isActive: Bool
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .scaleEffect(isFocused ? 1.08 : 1.0)
                    .brightness(isFocused ? 0.25 : 0.0)
                    .shadow(
                        color: isFocused ? (isActive ? AppColors.warningGold.opacity(0.8) : AppColors.borderStrong) : .clear,
                        radius: isFocused ? 10 : 0,
                        x: 0,
                        y: 0
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
                    .tvHighContrastFocusOutline(isFocused: isFocused, shape: .roundedRectangle(cornerRadius: 12))
            }
        }
    }
#endif
