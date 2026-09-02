import Combine
import SwiftUI

public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    @AppStorage("appThemeColorHex") public var themeColorHex: String = "#FF2D55" // Default is sort of a pink/red (Netflix/Apple TV red)
    @AppStorage("appIconName") public var currentAppIconName: String = "AppIcon"

    public var accentColor: Color {
        Color(hex: themeColorHex)
    }

    public let availableColors: [(name: String, hex: String)] = [
        ("Pure Kırmızı", "#FF2D55"),
        ("Apple Mavi", "#007AFF"),
        ("Neon Mor", "#AF52DE"),
        ("Doğa Yeşili", "#34C759"),
        ("Turuncu", "#FF9500"),
    ]

    public let availableIcons: [(name: String, iconName: String?)] = [
        ("Varsayılan (Dark)", nil),
        ("Aydınlık (Light)", "AppIconLight"),
        ("Neon (Mor)", "AppIconNeon"),
    ]

    private init() {}

    public func setThemeColor(hex: String) {
        themeColorHex = hex
        objectWillChange.send()
    }

    public func setAppIcon(iconName: String?) {
        #if os(iOS)
            if UIApplication.shared.supportsAlternateIcons {
                UIApplication.shared.setAlternateIconName(iconName) { error in
                    if let error {
                        print("Error changing app icon: \(error.localizedDescription)")
                    } else {
                        self.currentAppIconName = iconName ?? "AppIcon"
                        self.objectWillChange.send()
                    }
                }
            }
        #endif
    }
}
