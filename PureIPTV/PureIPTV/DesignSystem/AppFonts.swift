import SwiftUI

// MARK: - App Fonts (Cinematic Obsidian Typography System)

/// Centralized font token system for PureIPTV across iOS, iPadOS, macOS, and tvOS.
/// All UI views must reference typography from this class rather than using ad-hoc .system(size:) calls.
public final class AppFonts: Sendable {
    private init() {}

    #if os(tvOS)
        public static let scaleFactor: CGFloat = 1.5
    #elseif targetEnvironment(macCatalyst)
        public static let scaleFactor: CGFloat = 1.2
    #else
        public static let scaleFactor: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 1.2 : 1.0
    #endif

    // MARK: - Display Titles (Hero & Headers)

    /// Large display title (48pt on tvOS, 34pt on iOS, Heavy weight).
    public static var displayLarge: Font {
        #if os(tvOS)
            .system(size: 48, weight: .heavy, design: .default)
        #else
            .system(size: 34, weight: .heavy, design: .default)
        #endif
    }

    /// Medium display title (38pt on tvOS, 28pt on iOS, Bold weight).
    public static var displayMedium: Font {
        #if os(tvOS)
            .system(size: 38, weight: .bold, design: .default)
        #else
            .system(size: 28, weight: .bold, design: .default)
        #endif
    }

    /// Small display title alias (32pt on tvOS, 24pt on iOS, Bold weight).
    public static var displaySmall: Font {
        headline
    }

    // MARK: - Headlines & Section Titles

    /// Section headline (32pt on tvOS, 24pt on iOS, Bold weight).
    public static var headline: Font {
        #if os(tvOS)
            .system(size: 32, weight: .bold, design: .default)
        #else
            .system(size: 24, weight: .bold, design: .default)
        #endif
    }

    /// Secondary headline alias.
    public static var headlineMedium: Font {
        title
    }

    /// Primary content title (26pt on tvOS, 20pt on iOS, Semibold weight).
    public static var title: Font {
        #if os(tvOS)
            .system(size: 26, weight: .semibold, design: .default)
        #else
            .system(size: 20, weight: .semibold, design: .default)
        #endif
    }

    /// Large title alias.
    public static var titleLarge: Font {
        headline
    }

    /// Medium title alias.
    public static var titleMedium: Font {
        title
    }

    /// Secondary small title (22pt on tvOS, 18pt on iOS, Semibold weight).
    public static var titleSmall: Font {
        #if os(tvOS)
            .system(size: 22, weight: .semibold, design: .default)
        #else
            .system(size: 18, weight: .semibold, design: .default)
        #endif
    }

    // MARK: - Body Text

    /// Standard large reading body (24pt on tvOS, 17pt on iOS, Regular weight).
    public static var bodyLarge: Font {
        #if os(tvOS)
            .system(size: 24, weight: .regular, design: .default)
        #else
            .system(size: 17, weight: .regular, design: .default)
        #endif
    }

    /// Standard medium body text (20pt on tvOS, 15pt on iOS, Regular weight).
    public static var bodyMedium: Font {
        #if os(tvOS)
            .system(size: 20, weight: .regular, design: .default)
        #else
            .system(size: 15, weight: .regular, design: .default)
        #endif
    }

    /// Standard body alias.
    public static var body: Font {
        bodyMedium
    }

    /// Emphasized bold body text (20pt on tvOS, 15pt on iOS, Bold weight).
    public static var bodyBold: Font {
        #if os(tvOS)
            .system(size: 20, weight: .bold, design: .default)
        #else
            .system(size: 15, weight: .bold, design: .default)
        #endif
    }

    /// Small body text (18pt on tvOS, 13pt on iOS, Regular weight).
    public static var bodySmall: Font {
        #if os(tvOS)
            .system(size: 18, weight: .regular, design: .default)
        #else
            .system(size: 13, weight: .regular, design: .default)
        #endif
    }

    /// Footnote alias.
    public static var footnote: Font {
        bodySmall
    }

    // MARK: - Captions & Metadata

    /// Standard caption for metadata and secondary descriptions (16pt on tvOS, 12pt on iOS, Regular weight).
    public static var caption: Font {
        #if os(tvOS)
            .system(size: 16, weight: .regular, design: .default)
        #else
            .system(size: 12, weight: .regular, design: .default)
        #endif
    }

    /// Medium weight caption.
    public static var captionMedium: Font {
        captionSemibold
    }

    /// Emphasized bold caption (16pt on tvOS, 12pt on iOS, Bold weight).
    public static var captionBold: Font {
        #if os(tvOS)
            .system(size: 16, weight: .bold, design: .default)
        #else
            .system(size: 12, weight: .bold, design: .default)
        #endif
    }

    /// Semibold caption (16pt on tvOS, 12pt on iOS, Semibold weight).
    public static var captionSemibold: Font {
        #if os(tvOS)
            .system(size: 16, weight: .semibold, design: .default)
        #else
            .system(size: 12, weight: .semibold, design: .default)
        #endif
    }

    /// Compact small caption for timestamps, badges, and counters (14pt on tvOS, 10pt on iOS, Medium weight).
    public static var captionSmall: Font {
        #if os(tvOS)
            .system(size: 14, weight: .medium, design: .default)
        #else
            .system(size: 10, weight: .medium, design: .default)
        #endif
    }

    // MARK: - Labels & Badges

    /// All-caps label style for badges like "4K", "HDR", "CANLI" (16pt on tvOS, 12pt on iOS, Bold weight).
    public static var labelCaps: Font {
        #if os(tvOS)
            .system(size: 16, weight: .bold, design: .default)
        #else
            .system(size: 12, weight: .bold, design: .default)
        #endif
    }

    /// Button text font (20pt on tvOS, 15pt on iOS, Semibold weight).
    public static var button: Font {
        #if os(tvOS)
            .system(size: 20, weight: .semibold, design: .default)
        #else
            .system(size: 15, weight: .semibold, design: .default)
        #endif
    }

    // MARK: - Dynamic Sizing

    /// Custom size generator that automatically adapts to platform scaling factor.
    public static func custom(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: size * scaleFactor, weight: weight, design: design)
    }
}

// MARK: - Font Convenient Extensions

public extension Font {
    static var appDisplayLarge: Font {
        AppFonts.displayLarge
    }

    static var appDisplayMedium: Font {
        AppFonts.displayMedium
    }

    static var appDisplaySmall: Font {
        AppFonts.displaySmall
    }

    static var appHeadline: Font {
        AppFonts.headline
    }

    static var appTitle: Font {
        AppFonts.title
    }

    static var appTitleLarge: Font {
        AppFonts.titleLarge
    }

    static var appTitleMedium: Font {
        AppFonts.titleMedium
    }

    static var appTitleSmall: Font {
        AppFonts.titleSmall
    }

    static var appBodyLarge: Font {
        AppFonts.bodyLarge
    }

    static var appBodyMedium: Font {
        AppFonts.bodyMedium
    }

    static var appBodySmall: Font {
        AppFonts.bodySmall
    }

    static var appFootnote: Font {
        AppFonts.footnote
    }

    static var appCaption: Font {
        AppFonts.caption
    }

    static var appCaptionMedium: Font {
        AppFonts.captionMedium
    }

    static var appCaptionBold: Font {
        AppFonts.captionBold
    }

    static var appCaptionSemibold: Font {
        AppFonts.captionSemibold
    }

    static var appCaptionSmall: Font {
        AppFonts.captionSmall
    }

    static var appLabelCaps: Font {
        AppFonts.labelCaps
    }

    static var appButton: Font {
        AppFonts.button
    }
}
