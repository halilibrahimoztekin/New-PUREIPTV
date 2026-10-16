#if os(tvOS)
    import SwiftUI

    /// tvOS için Apple HIG standartlarında 3D derinlikli Parallax, ambient glow ve specular sheen sağlayan kart stili.
    public struct TVParallaxCardModifier: ViewModifier {
        let isFocused: Bool
        let isSelected: Bool
        let cornerRadius: CGFloat
        let accentColor: Color

        public init(
            isFocused: Bool,
            isSelected: Bool = false,
            cornerRadius: CGFloat = 16,
            accentColor: Color = Color(hex: "#0A84FF")
        ) {
            self.isFocused = isFocused
            self.isSelected = isSelected
            self.cornerRadius = cornerRadius
            self.accentColor = accentColor
        }

        public func body(content: Content) -> some View {
            content
                .scaleEffect(isFocused ? 1.05 : 1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            isFocused
                                ? accentColor
                                : isSelected ? accentColor.opacity(0.5) : Color.white.opacity(0.08),
                            lineWidth: isFocused ? 3.5 : (isSelected ? 2 : 1)
                        )
                )
                .shadow(
                    color: isFocused ? accentColor.opacity(0.45) : Color.black.opacity(0.4),
                    radius: isFocused ? 28 : 8,
                    x: 0,
                    y: isFocused ? 14 : 4
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.72), value: isFocused)
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

        public init(
            isFocused: Bool,
            isSelected: Bool = false,
            cornerRadius: CGFloat = 16,
            accentColor: Color = Color(hex: "#0A84FF"),
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

                // Katman 2: Specular Sheen (Işık Yansıması)
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(isFocused ? 0.22 : 0.0), location: 0.0),
                        .init(color: .white.opacity(isFocused ? 0.06 : 0.0), location: 0.4),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)

                // Katman 3: Öne fırlayan Parallax içerik (Logo / Başlık / Rozet)
                floatingContent()
                    .scaleEffect(isFocused ? 1.08 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isFocused)

                // Katman 4: Neon Kenarlık
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isFocused
                            ? accentColor
                            : isSelected ? accentColor.opacity(0.5) : Color.white.opacity(0.08),
                        lineWidth: isFocused ? 3.5 : (isSelected ? 2 : 1)
                    )
            }
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(
                color: isFocused ? accentColor.opacity(0.45) : Color.black.opacity(0.4),
                radius: isFocused ? 28 : 8,
                x: 0,
                y: isFocused ? 14 : 4
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: isFocused)
        }
    }
#endif
