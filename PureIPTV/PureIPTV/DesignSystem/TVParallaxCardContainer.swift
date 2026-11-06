#if os(tvOS)
    import SwiftUI

    /// tvOS için Apple HIG standartlarında 3D derinlikli Parallax, ambient glow ve specular sheen sağlayan kart stili.
    public struct TVParallaxCardModifier: ViewModifier {
        let isFocused: Bool
        let isSelected: Bool
        let cornerRadius: CGFloat
        let accentColor: Color

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        public init(
            isFocused: Bool,
            isSelected: Bool = false,
            cornerRadius: CGFloat = 16,
            accentColor: Color = AppColors.primary
        ) {
            self.isFocused = isFocused
            self.isSelected = isSelected
            self.cornerRadius = cornerRadius
            self.accentColor = accentColor
        }

        public func body(content: Content) -> some View {
            content
                .scaleEffect(reduceMotion ? 1.0 : (isFocused ? 1.045 : 1.0))
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(accentColor.opacity(0.5), lineWidth: 2)
                    }
                }
                .shadow(
                    color: AppColors.oledBlack.opacity(0.35),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isFocused)
        }
    }

    /// tvOS kartları için tam donanımlı Parallax Card Container
    public struct TVParallaxCardContainer<Content: View, FloatingContent: View>: View {
        let isFocused: Bool
        let isSelected: Bool
        let cornerRadius: CGFloat
        let accentColor: Color
        @ViewBuilder let backgroundContent: () -> Content
        @ViewBuilder let floatingContent: () -> FloatingContent

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        public init(
            isFocused: Bool,
            isSelected: Bool = false,
            cornerRadius: CGFloat = 16,
            accentColor: Color = AppColors.primary,
            @ViewBuilder backgroundContent: @escaping () -> Content,
            @ViewBuilder floatingContent: @escaping () -> FloatingContent
        ) {
            self.isFocused = isFocused
            self.isSelected = isSelected
            self.cornerRadius = cornerRadius
            self.accentColor = accentColor
            self.backgroundContent = backgroundContent
            self.floatingContent = floatingContent
        }

        public var body: some View {
            ZStack {
                // Katman 1: Arka Plan & Poster
                backgroundContent()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                // Kart içeriği odak değişiminde sabit kalır; yalnızca kartın tamamı ölçeklenir.
                floatingContent()
            }
            .shadow(
                color: Color.black.opacity(0.35),
                radius: 8,
                x: 0,
                y: 4
            )
            .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isFocused)
        }
    }
#endif
