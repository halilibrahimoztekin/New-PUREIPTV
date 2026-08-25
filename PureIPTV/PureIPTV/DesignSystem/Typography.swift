import SwiftUI

public enum Typography {
    // Note: Since this is an Apple-native app, we are defaulting to Apple's system font (SF Pro)
    // to benefit from native tracking, optical sizing, and accessibility text scaling.

    #if os(tvOS) || targetEnvironment(macCatalyst)
        private static let scaleFactor: CGFloat = 1.5
    #else
        private static let scaleFactor: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 1.2 : 1.0
    #endif

    public static func displayLarge() -> Font {
        .system(size: 34 * scaleFactor, weight: .heavy, design: .default)
    }

    public static func headline() -> Font {
        .system(size: 24 * scaleFactor, weight: .bold, design: .default)
    }

    public static func title() -> Font {
        .system(size: 20 * scaleFactor, weight: .semibold, design: .default)
    }

    public static func bodyLarge() -> Font {
        .system(size: 17 * scaleFactor, weight: .regular, design: .default)
    }

    public static func bodySmall() -> Font {
        .system(size: 15 * scaleFactor, weight: .regular, design: .default)
    }

    public static func label() -> Font {
        .system(size: 12 * scaleFactor, weight: .bold, design: .default)
    }
}

/// View modifier for the label caps style which needs additional letter spacing
public struct LabelCapsModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(Typography.label())
            .textCase(.uppercase)
            // SF Pro is automatically tracked, but for small caps we add a bit of tracking (kerning).
            .tracking(1.5)
    }
}

public extension View {
    func labelCapsStyle() -> some View {
        modifier(LabelCapsModifier())
    }
}
