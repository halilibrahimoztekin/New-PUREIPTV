import SwiftUI

public enum Theme {
    public enum Colors {
        // Core Backgrounds
        public static let background = Color(hex: "#000000") // True Black
        public static let surface = Color(hex: "#0C0C10") // Anthracite

        // Accents
        public static let primary = Color(hex: "#0A84FF") // Electric Blue
        public static let premium = Color(hex: "#BF5AF2") // Neon Purple

        /// Status
        public static let liveIndicator = Color(hex: "#FF453A") // Live Red

        // Text & Icons
        public static let onSurface = Color(hex: "#E4E1E7")
        public static let onSurfaceVariant = Color(hex: "#C0C6D6")
    }

    public enum Layout {
        // Platform specific margins
        #if os(tvOS)
            public static let margin: CGFloat = 80
        #elseif os(iOS)
            public static let margin: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 32 : 16
        #else
            public static let margin: CGFloat = 32
        #endif

        // Stacking base units
        public static let stackSmall: CGFloat = 8
        public static let stackMedium: CGFloat = 16
        public static let stackLarge: CGFloat = 32

        /// Card properties
        public static let cardCornerRadius: CGFloat = 16
    }
}

/// Helper extension for Hex colors
public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
