#if os(tvOS)
    import SwiftUI

    // MARK: - tvOS Player Focusable Fields

    public enum TVPlayerFocusableField: Hashable, Sendable {
        case play
        case restart
        case backward
        case replayWithSubtitles
        case playPause
        case forward
        case skipMarkers
        case liveChannelsMenu
        case audioSubtitleMenu
        case displayModeMenu
        case scrubber
    }

    // MARK: - Custom Glass Focus Button Styles for tvOS

    @available(tvOS 16.0, *)
    public struct TVPlayerCircleButtonStyle: ButtonStyle {
        public var size: CGFloat

        public init(size: CGFloat = 56) {
            self.size = size
        }

        public func makeBody(configuration: Configuration) -> some View {
            TVPlayerCircleButtonBody(configuration: configuration, size: size)
        }

        private struct TVPlayerCircleButtonBody: View {
            let configuration: Configuration
            let size: CGFloat
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .foregroundStyle(isFocused ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.85))
                    .frame(width: size, height: size)
                    .background(
                        Circle()
                            .fill(isFocused ? AppColors.textPrimary.opacity(0.35) : AppColors.textPrimary.opacity(0.12))
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                isFocused ? AppColors.textPrimary.opacity(0.9) : AppColors.textPrimary.opacity(0.15),
                                lineWidth: isFocused ? 2.5 : 1
                            )
                    )
                    .shadow(
                        color: isFocused ? AppColors.primary.opacity(0.55) : Color.clear,
                        radius: 12,
                        x: 0,
                        y: 0
                    )
                    .scaleEffect(isFocused ? 1.15 : (configuration.isPressed ? 0.94 : 1.0))
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
                    .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
                    .tvHighContrastFocusOutline(isFocused: isFocused, shape: .circle)
            }
        }
    }

    @available(tvOS 16.0, *)
    public struct TVPlayerCapsuleButtonStyle: ButtonStyle {
        public init() {}

        public func makeBody(configuration: Configuration) -> some View {
            TVPlayerCapsuleButtonBody(configuration: configuration)
        }

        private struct TVPlayerCapsuleButtonBody: View {
            let configuration: Configuration
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .foregroundStyle(isFocused ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.85))
                    .background(
                        Capsule()
                            .fill(isFocused ? AppColors.textPrimary.opacity(0.35) : AppColors.textPrimary.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isFocused ? AppColors.textPrimary.opacity(0.9) : AppColors.textPrimary.opacity(0.15),
                                lineWidth: isFocused ? 2.5 : 1
                            )
                    )
                    .shadow(
                        color: isFocused ? AppColors.primary.opacity(0.55) : Color.clear,
                        radius: 12,
                        x: 0,
                        y: 0
                    )
                    .scaleEffect(isFocused ? 1.08 : (configuration.isPressed ? 0.95 : 1.0))
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isFocused)
                    .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
                    .tvHighContrastFocusOutline(isFocused: isFocused, shape: .capsule)
            }
        }
    }
#endif
