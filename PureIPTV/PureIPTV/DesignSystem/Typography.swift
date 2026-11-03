import SwiftUI

public enum Typography {
    public static func displayLarge() -> Font {
        AppFonts.displayLarge
    }

    public static func headline() -> Font {
        AppFonts.headline
    }

    public static func title() -> Font {
        AppFonts.title
    }

    public static func bodyLarge() -> Font {
        AppFonts.bodyLarge
    }

    public static func bodySmall() -> Font {
        AppFonts.bodySmall
    }

    public static func label() -> Font {
        AppFonts.captionBold
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
