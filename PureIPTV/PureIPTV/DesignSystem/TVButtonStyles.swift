#if os(tvOS)
    import SwiftUI

    enum TVFocusShape {
        case roundedRectangle(cornerRadius: CGFloat)
        case capsule
        case circle
    }

    private struct TVFocusShapePath: Shape {
        let shape: TVFocusShape

        func path(in rect: CGRect) -> Path {
            switch shape {
            case let .roundedRectangle(cornerRadius):
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
            case .capsule:
                Capsule().path(in: rect)
            case .circle:
                Circle().path(in: rect)
            }
        }
    }

    private struct TVHighContrastFocusOutlineModifier: ViewModifier {
        let shape: TVFocusShape
        let isFocused: Bool

        @AppStorage("com.pureiptv.tvOSHighContrastFocusFrame") private var isEnabled = false

        func body(content: Content) -> some View {
            content.overlay {
                if isFocused, isEnabled {
                    TVFocusShapePath(shape: shape)
                        .stroke(Color.black.opacity(0.96), lineWidth: 8)
                        .overlay {
                            TVFocusShapePath(shape: shape)
                                .stroke(Color.white, lineWidth: 4)
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    extension View {
        func tvHighContrastFocusOutline(isFocused: Bool, shape: TVFocusShape) -> some View {
            modifier(TVHighContrastFocusOutlineModifier(shape: shape, isFocused: isFocused))
        }
    }

    extension View {
        func tvFocusEffect(
            shape: TVFocusShape = .roundedRectangle(cornerRadius: 14),
            accentColor: Color = AppColors.primary
        ) -> some View {
            buttonStyle(.plain)
                .focusEffectDisabled()
                .modifier(TVFocusEffectModifier(shape: shape, accentColor: accentColor))
        }
    }

    private struct TVFocusEffectModifier: ViewModifier {
        let shape: TVFocusShape
        let accentColor: Color

        @Environment(\.isFocused) private var isFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        func body(content: Content) -> some View {
            content
                .scaleEffect(isFocused ? 1.035 : 1)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82),
                    value: isFocused
                )
        }
    }

    // MARK: - TV Grid Card Button Style (For Media Posters, Channels, VODs, Series)

    public struct TVGridCardButtonStyle: ButtonStyle {
        public let cornerRadius: CGFloat

        public init(cornerRadius: CGFloat = 16) {
            self.cornerRadius = cornerRadius
        }

        public func makeBody(configuration: Configuration) -> some View {
            TVGridCardButtonBody(configuration: configuration)
        }

        private struct TVGridCardButtonBody: View {
            let configuration: Configuration
            @Environment(\.isFocused) private var isFocused
            @Environment(\.accessibilityReduceMotion) private var reduceMotion

            var body: some View {
                configuration.label
                    .scaleEffect(
                        reduceMotion ? 1 : (isFocused ? 1.045 : (configuration.isPressed ? 0.98 : 1))
                    )
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.82),
                        value: isFocused
                    )
                    .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            }
        }
    }

    public extension ButtonStyle where Self == TVGridCardButtonStyle {
        static var tvGridCard: TVGridCardButtonStyle {
            TVGridCardButtonStyle()
        }

        static func tvGridCard(cornerRadius: CGFloat) -> TVGridCardButtonStyle {
            TVGridCardButtonStyle(cornerRadius: cornerRadius)
        }
    }

    // MARK: - TV Category Row Button Style (For Sidebar Category Menus)

    public struct TVCategoryRowButtonStyle: ButtonStyle {
        let accentColor: Color
        let isSelected: Bool

        public init(accentColor: Color, isSelected: Bool = false) {
            self.accentColor = accentColor
            self.isSelected = isSelected
        }

        public func makeBody(configuration: Configuration) -> some View {
            TVCategoryRowButtonBody(
                configuration: configuration,
                accentColor: accentColor,
                isSelected: isSelected
            )
        }

        private struct TVCategoryRowButtonBody: View {
            let configuration: Configuration
            let accentColor: Color
            let isSelected: Bool
            @Environment(\.isFocused) private var isFocused
            private var fillColor: Color {
                if isSelected {
                    accentColor.opacity(0.12)
                } else {
                    Color.clear
                }
            }

            var body: some View {
                configuration.label
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(fillColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.clear, lineWidth: 1.5)
                    )
                    .scaleEffect(isFocused ? 1.04 : (configuration.isPressed ? 0.97 : 1))
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
                    .focusEffectDisabled()
            }
        }
    }

    // MARK: - TV Episode Card Button Style (For Series Detail Episode List)

    public struct TVEpisodeCardButtonStyle: ButtonStyle {
        public init() {}

        public func makeBody(configuration: Configuration) -> some View {
            TVEpisodeCardButtonBody(configuration: configuration)
        }

        private struct TVEpisodeCardButtonBody: View {
            let configuration: Configuration
            @Environment(\.isFocused) private var isFocused
            @Environment(\.accessibilityReduceMotion) private var reduceMotion

            private var scale: CGFloat {
                if isFocused {
                    1.03
                } else if configuration.isPressed {
                    0.97
                } else {
                    1.0
                }
            }

            var body: some View {
                configuration.label
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.surfaceTertiary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 2)
                    .scaleEffect(reduceMotion ? 1 : scale)
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
                    .focusEffectDisabled()
            }
        }
    }

    // MARK: - TV Capsule Button Style (For Action Buttons, Season Buttons, Pills)

    public struct TVCapsuleButtonStyle: ButtonStyle {
        let isPrimary: Bool
        let isSelected: Bool

        public init(isPrimary: Bool = false, isSelected: Bool = false) {
            self.isPrimary = isPrimary
            self.isSelected = isSelected
        }

        public func makeBody(configuration: Configuration) -> some View {
            TVCapsuleButtonBody(
                configuration: configuration,
                isPrimary: isPrimary,
                isSelected: isSelected
            )
        }

        private struct TVCapsuleButtonBody: View {
            let configuration: Configuration
            let isPrimary: Bool
            let isSelected: Bool
            @Environment(\.isFocused) private var isFocused

            private var fillColor: Color {
                if isSelected || isPrimary {
                    Color.red
                } else {
                    AppColors.surfaceTertiary
                }
            }

            private var foregroundColor: Color {
                Color.white
            }

            private var strokeColor: Color {
                if isSelected {
                    Color.red.opacity(0.8)
                } else {
                    Color.white.opacity(0.15)
                }
            }

            private var scale: CGFloat {
                if isFocused {
                    1.035
                } else if configuration.isPressed {
                    0.96
                } else {
                    1.0
                }
            }

            var body: some View {
                configuration.label
                    .foregroundStyle(foregroundColor)
                    .background(
                        Capsule()
                            .fill(fillColor)
                    )
                    .overlay(
                        Capsule()
                            .stroke(strokeColor, lineWidth: 1.5)
                    )
                    .scaleEffect(scale)
                    .focusEffectDisabled()
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
            }
        }
    }

    // MARK: - TV Circle Button Style (For Favorite, Close, and Icon Buttons)

    public struct TVCircleButtonStyle: ButtonStyle {
        let isFavorite: Bool

        public init(isFavorite: Bool = false) {
            self.isFavorite = isFavorite
        }

        public func makeBody(configuration: Configuration) -> some View {
            TVCircleButtonBody(configuration: configuration, isFavorite: isFavorite)
        }

        private struct TVCircleButtonBody: View {
            let configuration: Configuration
            let isFavorite: Bool
            @Environment(\.isFocused) private var isFocused

            private var fillColor: Color {
                if isFavorite {
                    Color.red.opacity(0.25)
                } else {
                    Color.white.opacity(0.08)
                }
            }

            private var strokeColor: Color {
                isFavorite ? Color.red.opacity(0.6) : Color.white.opacity(0.2)
            }

            private var strokeWidth: CGFloat {
                1.5
            }

            private var scale: CGFloat {
                if isFocused {
                    1.035
                } else if configuration.isPressed {
                    0.95
                } else {
                    1.0
                }
            }

            var body: some View {
                configuration.label
                    .background(
                        Circle()
                            .fill(fillColor)
                    )
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
                    .scaleEffect(scale)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
                    .focusEffectDisabled()
            }
        }
    }

    public extension ButtonStyle where Self == TVEpisodeCardButtonStyle {
        static var tvEpisodeCard: TVEpisodeCardButtonStyle {
            TVEpisodeCardButtonStyle()
        }
    }

    public extension ButtonStyle where Self == TVCapsuleButtonStyle {
        static var tvCapsule: TVCapsuleButtonStyle {
            TVCapsuleButtonStyle()
        }
    }

    public extension ButtonStyle where Self == TVCircleButtonStyle {
        static var tvCircle: TVCircleButtonStyle {
            TVCircleButtonStyle()
        }
    }
#endif
