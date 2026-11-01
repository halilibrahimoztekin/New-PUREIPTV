import Combine
import CoreFoundation
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

private struct ImportedVisualThemePackage: Codable, Equatable {
    let id: String
    let name: String
    let accentHex: String
    let atmosphereHex: String

    var preset: VisualThemePreset {
        VisualThemePreset(
            id: id,
            name: name,
            accentHex: accentHex,
            atmosphereHex: atmosphereHex
        )
    }
}

private struct VisualThemePackageDocument: Decodable {
    let schemaVersion: Int
    let id: String
    let name: String
    let accentHex: String
    let atmosphereHex: String
}

private enum VisualThemePackageError: LocalizedError {
    case invalidFormat
    case fileTooLarge
    case tooManyPackages

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            AppStrings.Settings.visualThemePackageInvalid
        case .fileTooLarge:
            AppStrings.Settings.visualThemePackageTooLarge
        case .tooManyPackages:
            AppStrings.Settings.visualThemePackageLimit
        }
    }
}

public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    private static let packageFileSizeLimit = 16 * 1024
    private static let packageCountLimit = 20
    private static let packageDocumentKeys: Set<String> = [
        "schemaVersion", "id", "name", "accentHex", "atmosphereHex",
    ]

    @AppStorage("appThemeColorHex") public var themeColorHex: String = "#FF2D55"
    @AppStorage("appIconName") public var currentAppIconName: String = "AppIcon"
    @Published public private(set) var selectedPresetID: String
    @Published public private(set) var importedPackages: [VisualThemePreset] = []

    private var activeProfileID: UUID?

    public var availablePresets: [VisualThemePreset] {
        Self.presets + importedPackages
    }

    public var selectedPreset: VisualThemePreset {
        availablePresets.first(where: { $0.id == selectedPresetID }) ?? Self.presets[0]
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

        let storedProfileID = defaults.string(forKey: "currentProfileID").flatMap(UUID.init(uuidString:))
        activateProfileTheme(profileID: storedProfileID)
    }

    public func setThemePreset(id: String) {
        guard let preset = availablePresets.first(where: { $0.id == id }) else { return }
        selectedPresetID = preset.id
        if Self.presets.contains(where: { $0.id == preset.id }) {
            UserDefaults.standard.set(preset.id, forKey: "appThemePresetID")
            if let activeProfileID {
                UserDefaults.standard.removeObject(forKey: Self.activePackageKey(for: activeProfileID))
            }
        } else if let activeProfileID {
            UserDefaults.standard.set(preset.id, forKey: Self.activePackageKey(for: activeProfileID))
        } else {
            return
        }
        themeColorHex = preset.accentHex
    }

    public func activateProfileTheme(profileID: UUID?) {
        activeProfileID = profileID
        let defaults = UserDefaults.standard
        if let profileID {
            importedPackages = Self.loadPackages(for: profileID).map(\.preset)
        } else {
            importedPackages = []
        }

        let packageID = profileID.flatMap { defaults.string(forKey: Self.activePackageKey(for: $0)) }
        if let packageID, importedPackages.contains(where: { $0.id == packageID }) {
            selectedPresetID = packageID
        } else {
            if let profileID {
                defaults.removeObject(forKey: Self.activePackageKey(for: profileID))
            }
            selectedPresetID = defaults.string(forKey: "appThemePresetID")
                .flatMap { id in Self.presets.contains(where: { $0.id == id }) ? id : nil }
                ?? Self.presets[0].id
        }

        themeColorHex = selectedPreset.accentHex
    }

    @discardableResult
    public func importThemePackage(_ data: Data, for profileID: UUID) throws -> VisualThemePreset {
        guard data.count <= Self.packageFileSizeLimit else {
            throw VisualThemePackageError.fileTooLarge
        }

        let package = try Self.decodePackage(data)
        var packages = Self.loadPackages(for: profileID)
        let isNewPackage = !packages.contains(where: { $0.id == package.id })
        guard !isNewPackage || packages.count < Self.packageCountLimit else {
            throw VisualThemePackageError.tooManyPackages
        }

        packages.removeAll(where: { $0.id == package.id })
        packages.append(package)
        try Self.savePackages(packages, for: profileID)

        if activeProfileID == profileID {
            importedPackages = packages.map(\.preset)
            UserDefaults.standard.set(package.id, forKey: Self.activePackageKey(for: profileID))
            selectedPresetID = package.id
            themeColorHex = package.accentHex
        }

        return package.preset
    }

    public func removeImportedThemePackage(id: String) {
        guard let activeProfileID else { return }
        var packages = Self.loadPackages(for: activeProfileID)
        guard packages.contains(where: { $0.id == id }) else { return }
        packages.removeAll(where: { $0.id == id })
        try? Self.savePackages(packages, for: activeProfileID)
        importedPackages = packages.map(\.preset)

        guard selectedPresetID == id else { return }
        UserDefaults.standard.removeObject(forKey: Self.activePackageKey(for: activeProfileID))
        let fallbackID = UserDefaults.standard.string(forKey: "appThemePresetID")
            .flatMap { presetID in Self.presets.contains(where: { $0.id == presetID }) ? presetID : nil }
            ?? Self.presets[0].id
        selectedPresetID = fallbackID
        themeColorHex = selectedPreset.accentHex
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

    private static func activePackageKey(for profileID: UUID) -> String {
        "com.pureiptv.visualTheme.activePackage.\(profileID.uuidString.lowercased())"
    }

    private static func packagesKey(for profileID: UUID) -> String {
        "com.pureiptv.visualTheme.packages.\(profileID.uuidString.lowercased())"
    }

    private static func loadPackages(for profileID: UUID) -> [ImportedVisualThemePackage] {
        guard let data = UserDefaults.standard.data(forKey: packagesKey(for: profileID)),
              data.count <= packageFileSizeLimit * packageCountLimit,
              let packages = try? JSONDecoder().decode([ImportedVisualThemePackage].self, from: data)
        else {
            return []
        }

        var seenIDs = Set<String>()
        return packages.filter { package in
            guard isValidPackageID(package.id),
                  isValidPackageName(package.name),
                  isValidHexColor(package.accentHex),
                  isValidHexColor(package.atmosphereHex)
            else {
                return false
            }
            return seenIDs.insert(package.id).inserted
        }
        .prefix(packageCountLimit)
        .map(\.self)
    }

    private static func savePackages(_ packages: [ImportedVisualThemePackage], for profileID: UUID) throws {
        let data = try JSONEncoder().encode(packages)
        UserDefaults.standard.set(data, forKey: packagesKey(for: profileID))
    }

    private static func decodePackage(_ data: Data) throws -> ImportedVisualThemePackage {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any],
            Set(dictionary.keys) == packageDocumentKeys,
            let schemaVersion = dictionary["schemaVersion"] as? NSNumber,
            CFGetTypeID(schemaVersion) != CFBooleanGetTypeID(),
            schemaVersion.intValue == 1,
            schemaVersion.doubleValue == 1,
            let document = try? JSONDecoder().decode(VisualThemePackageDocument.self, from: data),
            document.schemaVersion == 1,
            isValidPackageID(document.id),
            isValidPackageName(document.name),
            isValidHexColor(document.accentHex),
            isValidHexColor(document.atmosphereHex)
        else {
            throw VisualThemePackageError.invalidFormat
        }

        return ImportedVisualThemePackage(
            id: document.id,
            name: document.name.trimmingCharacters(in: .whitespacesAndNewlines),
            accentHex: document.accentHex.uppercased(),
            atmosphereHex: document.atmosphereHex.uppercased()
        )
    }

    private static func isValidPackageID(_ value: String) -> Bool {
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_")
        return (1 ... 40).contains(value.unicodeScalars.count)
            && value.unicodeScalars.allSatisfy(allowedCharacters.contains)
            && !presets.contains(where: { $0.id == value })
    }

    private static func isValidPackageName(_ value: String) -> Bool {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return (1 ... 48).contains(trimmedValue.count)
            && !trimmedValue.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }

    private static func isValidHexColor(_ value: String) -> Bool {
        guard value.count == 7, value.first == "#" else { return false }
        let allowedDigits = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return value.dropFirst().unicodeScalars.allSatisfy(allowedDigits.contains)
    }
}
