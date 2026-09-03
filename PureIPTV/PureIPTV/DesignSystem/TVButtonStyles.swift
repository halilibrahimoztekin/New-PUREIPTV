#if os(tvOS)
    import SwiftUI

    // MARK: - TV Grid Card Button Style (For Media Posters, Channels, VODs, Series)

    public struct TVGridCardButtonStyle: ButtonStyle {
        public init() {}

        public func makeBody(configuration: Configuration) -> some View {
            TVGridCardButtonBody(configuration: configuration)
        }

        private struct TVGridCardButtonBody: View {
            let configuration: Configuration
            @Environment(\.isFocused) private var isFocused

            private var scale: CGFloat {
                if isFocused {
                    1.08
                } else if configuration.isPressed {
                    0.96
                } else {
                    1.0
                }
            }

            private var strokeColor: Color {
                isFocused ? Color.white.opacity(0.9) : Color.clear
            }

            private var shadowColor: Color {
                isFocused ? Color(hex: "#0A84FF").opacity(0.6) : Color.black.opacity(0.4)
            }

            private var shadowRadius: CGFloat {
                isFocused ? 16.0 : 8.0
            }

            private var shadowY: CGFloat {
                isFocused ? 6.0 : 2.0
            }

            var body: some View {
                configuration.label
                    .scaleEffect(scale)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(strokeColor, lineWidth: 3)
                    )
                    .shadow(
                        color: shadowColor,
                        radius: shadowRadius,
                        x: 0,
                        y: shadowY
                    )
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
                    .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            }
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
                if isFocused {
                    accentColor.opacity(0.24)
                } else if isSelected {
                    accentColor.opacity(0.12)
                } else {
                    Color.clear
                }
            }

            private var strokeColor: Color {
                isFocused ? accentColor.opacity(0.75) : Color.clear
            }

            private var shadowColor: Color {
                isFocused ? accentColor.opacity(0.4) : Color.clear
            }

            private var scale: CGFloat {
                if isFocused {
                    1.04
                } else if configuration.isPressed {
                    0.97
                } else {
                    1.0
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
                            .stroke(strokeColor, lineWidth: 1.5)
                    )
                    .shadow(color: shadowColor, radius: 10, x: 0, y: 0)
                    .scaleEffect(scale)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
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

            private var scale: CGFloat {
                if isFocused {
                    1.03
                } else if configuration.isPressed {
                    0.97
                } else {
                    1.0
                }
            }

            private var fillColor: Color {
                isFocused ? Color.white.opacity(0.18) : Color(hex: "#1A1A24")
            }

            private var strokeColor: Color {
                isFocused ? Color.white.opacity(0.85) : Color.white.opacity(0.06)
            }

            private var strokeWidth: CGFloat {
                isFocused ? 2.5 : 1.0
            }

            private var shadowColor: Color {
                isFocused ? Color(hex: "#0A84FF").opacity(0.4) : Color.black.opacity(0.3)
            }

            var body: some View {
                configuration.label
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(fillColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
                    .shadow(color: shadowColor, radius: isFocused ? 16 : 8, x: 0, y: isFocused ? 4 : 2)
                    .scaleEffect(scale)
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
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
                if isFocused {
                    Color.white
                } else if isSelected || isPrimary {
                    Color.red
                } else {
                    Color(hex: "#1A1A24")
                }
            }

            private var foregroundColor: Color {
                isFocused ? Color.black : Color.white
            }

            private var strokeColor: Color {
                if isFocused {
                    Color.clear
                } else if isSelected {
                    Color.red.opacity(0.8)
                } else {
                    Color.white.opacity(0.15)
                }
            }

            private var scale: CGFloat {
                if isFocused {
                    1.08
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
                    .shadow(color: isFocused ? Color.white.opacity(0.35) : Color.clear, radius: 12, x: 0, y: 0)
                    .scaleEffect(scale)
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
                if isFocused {
                    Color.white.opacity(0.3)
                } else if isFavorite {
                    Color.red.opacity(0.25)
                } else {
                    Color.white.opacity(0.08)
                }
            }

            private var strokeColor: Color {
                isFocused ? Color.white.opacity(0.9) : (isFavorite ? Color.red.opacity(0.6) : Color.white.opacity(0.2))
            }

            private var strokeWidth: CGFloat {
                isFocused ? 2.5 : 1.5
            }

            private var scale: CGFloat {
                if isFocused {
                    1.12
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
                    .shadow(color: isFocused ? Color.white.opacity(0.3) : Color.clear, radius: 10, x: 0, y: 0)
                    .scaleEffect(scale)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
            }
        }
    }

    public extension ButtonStyle where Self == TVGridCardButtonStyle {
        static var tvGridCard: TVGridCardButtonStyle {
            TVGridCardButtonStyle()
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
