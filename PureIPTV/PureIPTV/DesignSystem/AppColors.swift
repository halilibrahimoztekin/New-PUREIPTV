import SwiftUI

// MARK: - App Colors (Cinematic Obsidian Design System)

/// Centralized color token system for PureIPTV across iOS, iPadOS, macOS, and tvOS.
/// All UI views must reference colors from this class rather than using hardcoded hex strings.
public final class AppColors: Sendable {
    private init() {}

    // MARK: - Core Backgrounds (OLED Black)

    /// Pure OLED Black (#000000). The foundation that blends into hardware bezels.
    public static let oledBlack = Color(hex: "#000000")
    /// Default screen background.
    public static let background = Color(hex: "#000000")
    /// Slightly elevated dark background (#131317) for contrast against true black.
    public static let backgroundSubtle = Color(hex: "#131317")

    // MARK: - Surfaces & Containers (Anthracite)

    /// Primary card and modal background surface (#0C0C10).
    public static let surface = Color(hex: "#0C0C10")
    /// Secondary container, search bar, button background, and filter pill surface (#1F1F23).
    public static let surfaceSecondary = Color(hex: "#1F1F23")
    /// Tertiary surface for elevated card rows and drawers (#1A1A24).
    public static let surfaceTertiary = Color(hex: "#1A1A24")
    /// Elevated interactive element background (#2A2A30).
    public static let surfaceElevated = Color(hex: "#2A2A30")
    /// Dark container background (#18181D).
    public static let surfaceContainer = Color(hex: "#18181D")
    /// Deep surface background (#0F0F13).
    public static let surfaceDark = Color(hex: "#0F0F13")

    // MARK: - Brand & Accents

    /// Electric Blue (#0A84FF) - Primary interactive color with maximum legibility.
    public static let primary = Color(hex: "#0A84FF")
    /// Dark Electric Blue (#0060CC) - Used for primary gradients and button pressed states.
    public static let primaryDark = Color(hex: "#0060CC")
    /// Primary interactive accent alias.
    public static let accent = Color(hex: "#0A84FF")
    /// Neon Purple (#BF5AF2) - Reserved for Premium, Paywall, and VIP highlights.
    public static let premium = Color(hex: "#BF5AF2")
    /// Purple accent alias.
    public static let purpleAccent = Color(hex: "#BF5AF2")
    /// Neon Teal / Mint (#00F5D4) - Used for Next Up badges, video scrubber, and stats.
    public static let neonTeal = Color(hex: "#00F5D4")
    /// Cyan (#00D2FF) - Used for media tags and technical indicators.
    public static let cyan = Color(hex: "#00D2FF")
    /// Sky Blue (#64D2FF) - Used for secondary info badges.
    public static let sky = Color(hex: "#64D2FF")
    /// Amber (#E5A00D) - Used for warnings, sync alerts, and attention chips.
    public static let amber = Color(hex: "#E5A00D")

    // MARK: - Brand Logo Tokens

    public static let logoGlowCyan = Color(hex: "#00D2FF")
    public static let logoGlowPurple = Color(hex: "#9333EA")
    public static let logoBaseDark = Color(hex: "#101626")
    public static let logoBaseDeep = Color(hex: "#070B14")
    public static let logoGlassTop = Color(hex: "#22314F")
    public static let logoGlassBottom = Color(hex: "#121A2D")
    public static let logoRibbonCyan = Color(hex: "#00E5FF")
    public static let logoRibbonMagenta = Color(hex: "#E11D48")
    public static let logoTriangleLight = Color(hex: "#38BDF8")
    public static let logoTriangleDark = Color(hex: "#2563EB")

    // MARK: - Status & Alerts

    /// Live Red (#FF453A) - Exclusively for Live indicators and critical alerts.
    public static let live = Color(hex: "#FF453A")
    /// Live indicator alias.
    public static let liveIndicator = Color(hex: "#FF453A")
    /// Live status alias.
    public static let statusLive = Color(hex: "#FF453A")
    /// Destructive actions and error messages (#FF453A).
    public static let destructive = Color(hex: "#FF453A")
    /// Error status alias.
    public static let error = Color(hex: "#FF453A")
    /// Warning / Favorite Orange (#FF9F0A).
    public static let warning = Color(hex: "#FF9F0A")
    /// Gold / Rating Star / UHD 4K badge (#FFD60A).
    public static let warningGold = Color(hex: "#FFD60A")
    /// Success / Connected / Online Green (#30D158).
    public static let success = Color(hex: "#30D158")

    // MARK: - Typography & Iconography

    /// Primary text color (pure white).
    public static let textPrimary = Color.white
    /// Standard on-surface text (#E4E1E7).
    public static let onSurface = Color(hex: "#E4E1E7")
    /// Secondary on-surface text for subtitles and metadata (#C0C6D6).
    public static let onSurfaceVariant = Color(hex: "#C0C6D6")
    /// Secondary text alias (#C0C6D6).
    public static let textSecondary = Color(hex: "#C0C6D6")
    /// Tertiary subtle text (white 45%).
    public static let textTertiary = Color.white.opacity(0.45)
    /// Muted text (#9B9BA5).
    public static let textMuted = Color(hex: "#9B9BA5")

    // MARK: - Borders & Glassmorphic Outlines

    /// Subtle 1px inner rim light (white 8%).
    public static let borderSubtle = Color.white.opacity(0.08)
    /// Medium card border (white 12%).
    public static let borderMedium = Color.white.opacity(0.12)
    /// Glassmorphic component outline border (white 12%).
    public static let glassBorder = Color.white.opacity(0.12)
    /// Strong focused border (white 20%).
    public static let borderStrong = Color.white.opacity(0.20)
    /// Standard divider (white 10%).
    public static let divider = Color.white.opacity(0.10)
    /// Glassmorphic material background plate (white 6%).
    public static let glassPlate = Color.white.opacity(0.06)
}

// MARK: - Color Convenient Extensions

public extension Color {
    static var appOledBlack: Color {
        AppColors.oledBlack
    }

    static var appBackground: Color {
        AppColors.background
    }

    static var appBackgroundSubtle: Color {
        AppColors.backgroundSubtle
    }

    static var appSurface: Color {
        AppColors.surface
    }

    static var appSurfaceSecondary: Color {
        AppColors.surfaceSecondary
    }

    static var appSurfaceTertiary: Color {
        AppColors.surfaceTertiary
    }

    static var appSurfaceElevated: Color {
        AppColors.surfaceElevated
    }

    static var appSurfaceContainer: Color {
        AppColors.surfaceContainer
    }

    static var appSurfaceDark: Color {
        AppColors.surfaceDark
    }

    static var appPrimary: Color {
        AppColors.primary
    }

    static var appPrimaryDark: Color {
        AppColors.primaryDark
    }

    static var appAmber: Color {
        AppColors.amber
    }

    static var appAccent: Color {
        AppColors.accent
    }

    static var appPremium: Color {
        AppColors.premium
    }

    static var appNeonTeal: Color {
        AppColors.neonTeal
    }

    static var appCyan: Color {
        AppColors.cyan
    }

    static var appSky: Color {
        AppColors.sky
    }

    static var appLive: Color {
        AppColors.live
    }

    static var appStatusLive: Color {
        AppColors.statusLive
    }

    static var appDestructive: Color {
        AppColors.destructive
    }

    static var appError: Color {
        AppColors.error
    }

    static var appPurpleAccent: Color {
        AppColors.purpleAccent
    }

    static var appGlassBorder: Color {
        AppColors.glassBorder
    }

    static var appWarning: Color {
        AppColors.warning
    }

    static var appWarningGold: Color {
        AppColors.warningGold
    }

    static var appSuccess: Color {
        AppColors.success
    }

    static var appTextPrimary: Color {
        AppColors.textPrimary
    }

    static var appOnSurface: Color {
        AppColors.onSurface
    }

    static var appOnSurfaceVariant: Color {
        AppColors.onSurfaceVariant
    }

    static var appTextSecondary: Color {
        AppColors.textSecondary
    }

    static var appTextTertiary: Color {
        AppColors.textTertiary
    }

    static var appTextMuted: Color {
        AppColors.textMuted
    }

    static var appBorderSubtle: Color {
        AppColors.borderSubtle
    }

    static var appBorderMedium: Color {
        AppColors.borderMedium
    }

    static var appBorderStrong: Color {
        AppColors.borderStrong
    }

    static var appDivider: Color {
        AppColors.divider
    }

    static var appGlassPlate: Color {
        AppColors.glassPlate
    }
}
