import SwiftUI

/// A container that applies the design system's margins and background color consistently across platforms.
public struct ResponsiveContainer<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack {
            // Base OLED Background
            Theme.Colors.background
                .ignoresSafeArea()

            // Content with platform-specific margins
            content
                .padding(.horizontal, Theme.Layout.margin)
            #if os(tvOS)
                .padding(.vertical, Theme.Layout.margin) // Apply full safe area for tvOS
            #endif
        }
        // Force dark mode for Cinematic Obsidian theme
        .preferredColorScheme(.dark)
    }
}

/// Preview
struct ResponsiveContainer_Previews: PreviewProvider {
    static var previews: some View {
        ResponsiveContainer {
            VStack(spacing: Theme.Layout.stackMedium) {
                Text("Cinematic Obsidian")
                    .font(Typography.displayLarge())
                    .foregroundColor(Theme.Colors.primary)

                Text("PREMIUM CONTENT")
                    .labelCapsStyle()
                    .foregroundColor(Theme.Colors.premium)

                RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius, style: .continuous)
                    .fill(Theme.Colors.surface)
                    .frame(height: 200)
                    .overlay(
                        Text("Content Card")
                            .font(Typography.bodyLarge())
                            .foregroundColor(Theme.Colors.onSurface)
                    )
            }
        }
    }
}
