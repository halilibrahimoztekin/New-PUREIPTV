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
            accentColor: Color = Color(hex: "#0A84FF")
        ) {
            self.isFocused = isFocused
            self.isSelected = isSelected
            self.cornerRadius = cornerRadius
            self.accentColor = accentColor
        }

        public func body(content: Content) -> some View {
            content
                .scaleEffect(reduceMotion ? 1.0 : (isFocused ? 1.06 : 1.0))
                .offset(y: reduceMotion ? 0 : (isFocused ? -3 : 0))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            isFocused
                                ? accentColor
                                : isSelected ? accentColor.opacity(0.5) : Color.white.opacity(0.08),
                            lineWidth: isFocused ? 3.5 : (isSelected ? 2 : 1)
                        )
                )
                // Çift Katmanlı Gölge: 1. Zemin derinlik gölgesi + 2. Neon ambiyans parlaması
                .shadow(
                    color: Color.black.opacity(isFocused ? 0.60 : 0.35),
                    radius: isFocused ? 28 : 8,
                    x: 0,
                    y: isFocused ? 14 : 4
                )
                .shadow(
                    color: isFocused ? accentColor.opacity(0.48) : Color.clear,
                    radius: 36,
                    x: 0,
                    y: 16
                )
                .animation(.spring(response: 0.30, dampingFraction: 0.74), value: isFocused)
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
                        .init(color: .white.opacity(isFocused ? 0.24 : 0.0), location: 0.0),
                        .init(color: .white.opacity(isFocused ? 0.08 : 0.0), location: 0.35),
                        .init(color: .clear, location: 0.85),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)

                // Üst Kenar Işık Yansıması (Top Bevel Reflection)
                if isFocused {
                    VStack {
                        LinearGradient(
                            colors: [.white.opacity(0.40), .white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 2)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }

                // Katman 3: Öne fırlayan Parallax içerik (Logo / Başlık / Rozet)
                floatingContent()
                    .scaleEffect(reduceMotion ? 1.0 : (isFocused ? 1.07 : 1.0))
                    .offset(y: reduceMotion ? 0 : (isFocused ? -2 : 0))
                    .shadow(color: Color.black.opacity(isFocused ? 0.50 : 0.0), radius: 6, y: 3)
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
            .scaleEffect(reduceMotion ? 1.0 : (isFocused ? 1.06 : 1.0))
            .offset(y: reduceMotion ? 0 : (isFocused ? -3 : 0))
            // Çift Katmanlı Gölge: 1. Zemin derinlik gölgesi + 2. Neon ambiyans parlaması
            .shadow(
                color: Color.black.opacity(isFocused ? 0.60 : 0.35),
                radius: isFocused ? 28 : 8,
                x: 0,
                y: isFocused ? 14 : 4
            )
            .shadow(
                color: isFocused ? accentColor.opacity(0.48) : Color.clear,
                radius: 36,
                x: 0,
                y: 16
            )
            .animation(.spring(response: 0.30, dampingFraction: 0.74), value: isFocused)
        }
    }
#endif
