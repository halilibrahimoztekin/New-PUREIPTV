import Combine
import SwiftUI

public struct VisualThemePreset: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let accentHex: String
    public let atmosphereHex: String

    public var accentColor: Color {
        Color(hex: accentHex)
    }

    public var atmosphereColor: Color {
        Color(hex: atmosphereHex)
    }
}

public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    @AppStorage("appThemeColorHex") public var themeColorHex: String = "#FF2D55"
    @AppStorage("appIconName") public var currentAppIconName: String = "AppIcon"
    @Published public private(set) var selectedPresetID: String

    public var availablePresets: [VisualThemePreset] {
        Self.presets
    }

    public var selectedPreset: VisualThemePreset {
        Self.presets.first(where: { $0.id == selectedPresetID }) ?? Self.presets[0]
    }

    public var accentColor: Color {
        selectedPreset.accentColor
    }

    public var atmosphereColor: Color {
        selectedPreset.atmosphereColor
    }

    public var availableIcons: [(name: String, iconName: String?)] {
        [
            ("Varsayılan (Dark)".localized, nil),
            ("Aydınlık (Light)".localized, "AppIconLight"),
            ("Neon (Mor)".localized, "AppIconNeon"),
        ]
    }

    private static let presets: [VisualThemePreset] = [
        VisualThemePreset(
            id: "classic",
            name: AppStrings.Settings.themePresetClassic,
            accentHex: "#FF2D55",
            atmosphereHex: "#681F3A"
        ),
        VisualThemePreset(
            id: "ocean",
            name: AppStrings.Settings.themePresetOcean,
            accentHex: "#007AFF",
            atmosphereHex: "#123B65"
        ),
        VisualThemePreset(
            id: "aurora",
            name: AppStrings.Settings.themePresetAurora,
            accentHex: "#AF52DE",
            atmosphereHex: "#35215E"
        ),
        VisualThemePreset(
            id: "forest",
            name: AppStrings.Settings.themePresetForest,
            accentHex: "#34C759",
            atmosphereHex: "#184C3A"
        ),
        VisualThemePreset(
            id: "ember",
            name: AppStrings.Settings.themePresetEmber,
            accentHex: "#FF9500",
            atmosphereHex: "#66330F"
        ),
    ]

    private init() {
        let defaults = UserDefaults.standard
        if let storedID = defaults.string(forKey: "appThemePresetID"),
           Self.presets.contains(where: { $0.id == storedID })
        {
            selectedPresetID = storedID
        } else {
            let savedColor = defaults.string(forKey: "appThemeColorHex") ?? "#FF2D55"
            let migratedPreset = Self.nearestPreset(to: savedColor)
            selectedPresetID = migratedPreset.id
            defaults.set(migratedPreset.id, forKey: "appThemePresetID")
            defaults.set(migratedPreset.accentHex, forKey: "appThemeColorHex")
        }

        if let selected = Self.presets.first(where: { $0.id == selectedPresetID }) {
            defaults.set(selected.accentHex, forKey: "appThemeColorHex")
        }
    }

    public func setThemePreset(id: String) {
        guard let preset = Self.presets.first(where: { $0.id == id }) else { return }
        selectedPresetID = preset.id
        UserDefaults.standard.set(preset.id, forKey: "appThemePresetID")
        themeColorHex = preset.accentHex
    }

    /// Compatibility for callers that still provide a legacy accent hex.
    public func setThemeColor(hex: String) {
        setThemePreset(id: Self.nearestPreset(to: hex).id)
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

    private static func nearestPreset(to hex: String) -> VisualThemePreset {
        let target = rgbComponents(hex)
        return presets.min { lhs, rhs in
            colorDistance(rgbComponents(lhs.accentHex), target)
                < colorDistance(rgbComponents(rhs.accentHex), target)
        } ?? presets[0]
    }

    private static func rgbComponents(_ hex: String) -> (Double, Double, Double) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else {
            return (1, 0.176, 0.333)
        }
        return (
            Double((rgb >> 16) & 0xFF) / 255,
            Double((rgb >> 8) & 0xFF) / 255,
            Double(rgb & 0xFF) / 255
        )
    }

    private static func colorDistance(
        _ lhs: (Double, Double, Double),
        _ rhs: (Double, Double, Double)
    ) -> Double {
        let red = lhs.0 - rhs.0
        let green = lhs.1 - rhs.1
        let blue = lhs.2 - rhs.2
        return red * red + green * green + blue * blue
    }
}
