import ComposableArchitecture
import Foundation
#if os(iOS)
    import LocalAuthentication
#endif

public enum SortMethod: String, CaseIterable, Equatable, Identifiable {
    case defaultOrder = "Varsayılan"
    case alphabetical = "A-Z (Alfabetik)"
    case rating = "IMDb Puanı"
    case dateAdded = "Eklenme Tarihi"

    public var id: String {
        rawValue
    }
}

public struct SettingsClient: Sendable {
    public var isParentalControlEnabled: @Sendable () -> Bool = { false }
    public var getParentalPIN: @Sendable () -> String? = { nil }
    public var setParentalControl: @Sendable (_ enabled: Bool, _ pin: String?) async throws -> Void = { _, _ in }
    public var verifyPIN: @Sendable (_ pin: String) -> Bool = { _ in false }
    public var isAdultContent: @Sendable (_ text: String) -> Bool = { _ in false }
    public var authenticateWithBiometrics: @Sendable (_ reason: String) async throws -> Bool = { _ in false }

    public var getVODSortMethod: @Sendable () -> SortMethod = { .defaultOrder }
    public var setVODSortMethod: @Sendable (SortMethod) -> Void = { _ in }

    public var getSeriesSortMethod: @Sendable () -> SortMethod = { .defaultOrder }
    public var setSeriesSortMethod: @Sendable (SortMethod) -> Void = { _ in }

    // MARK: - New Settings

    public var autoPlayNextEpisode: @Sendable () -> Bool = { true }
    public var setAutoPlayNextEpisode: @Sendable (Bool) -> Void = { _ in }

    public var startMuted: @Sendable () -> Bool = { false }
    public var setStartMuted: @Sendable (Bool) -> Void = { _ in }

    public var hardwareAcceleration: @Sendable () -> Bool = { true }
    public var setHardwareAcceleration: @Sendable (Bool) -> Void = { _ in }

    public var epgTimeShift: @Sendable () -> Int = { 0 }
    public var setEpgTimeShift: @Sendable (Int) -> Void = { _ in }

    public var autoUpdateEPG: @Sendable () -> Bool = { true }
    public var setAutoUpdateEPG: @Sendable (Bool) -> Void = { _ in }

    public var hideAdultContent: @Sendable () -> Bool = { false }
    public var setHideAdultContent: @Sendable (Bool) -> Void = { _ in }

    public var defaultStartupTab: @Sendable () -> String = { "Keşfet" }
    public var setDefaultStartupTab: @Sendable (String) -> Void = { _ in }
}

extension SettingsClient: DependencyKey {
    public static let liveValue: SettingsClient = {
        let defaults = UserDefaults.standard
        let pinKey = "com.pureiptv.parentalPIN"
        let enabledKey = "com.pureiptv.parentalControlEnabled"
        let vodSortKey = "com.pureiptv.vodSortMethod"
        let seriesSortKey = "com.pureiptv.seriesSortMethod"
        let autoPlayKey = "com.pureiptv.autoPlayNextEpisode"
        let startMutedKey = "com.pureiptv.startMuted"
        let hwAccelKey = "com.pureiptv.hardwareAcceleration"
        let epgShiftKey = "com.pureiptv.epgTimeShift"
        let autoUpdateEpgKey = "com.pureiptv.autoUpdateEPG"
        let hideAdultKey = "com.pureiptv.hideAdultContent"
        let startupTabKey = "com.pureiptv.defaultStartupTab"

        // Set defaults for some keys
        defaults.register(defaults: [
            autoPlayKey: true,
            hwAccelKey: true,
            autoUpdateEpgKey: true,
            startupTabKey: "Keşfet",
        ])

        return SettingsClient(
            isParentalControlEnabled: {
                defaults.bool(forKey: enabledKey)
            },
            getParentalPIN: {
                defaults.string(forKey: pinKey)
            },
            setParentalControl: { enabled, pin in
                defaults.set(enabled, forKey: enabledKey)
                if let pin, enabled {
                    defaults.set(pin, forKey: pinKey)
                } else {
                    defaults.removeObject(forKey: pinKey)
                }
            },
            verifyPIN: { inputPin in
                guard defaults.bool(forKey: enabledKey),
                      let savedPin = defaults.string(forKey: pinKey)
                else {
                    return true // If not enabled, always verify
                }
                return savedPin == inputPin
            },
            isAdultContent: { text in
                let lowercased = text.lowercased()
                let adultKeywords = ["adult", "xxx", "18+", "yetişkin", "porn", "erotic"]
                return adultKeywords.contains { lowercased.contains($0) }
            },
            authenticateWithBiometrics: { reason in
                #if os(tvOS)
                    // LocalAuthentication (Biometrics/FaceID) is not available on Apple TV
                    return false
                #else
                    let context = LAContext()
                    var error: NSError?

                    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                        do {
                            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                        } catch {
                            return false
                        }
                    } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                        // Fallback to passcode if biometrics are not available
                        do {
                            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                        } catch {
                            return false
                        }
                    }
                    return false
                #endif
            },
            getVODSortMethod: {
                if let raw = defaults.string(forKey: vodSortKey), let method = SortMethod(rawValue: raw) {
                    return method
                }
                return .defaultOrder
            },
            setVODSortMethod: { method in
                defaults.set(method.rawValue, forKey: vodSortKey)
            },
            getSeriesSortMethod: {
                if let raw = defaults.string(forKey: seriesSortKey), let method = SortMethod(rawValue: raw) {
                    return method
                }
                return .defaultOrder
            },
            setSeriesSortMethod: { method in
                defaults.set(method.rawValue, forKey: seriesSortKey)
            },
            autoPlayNextEpisode: { defaults.bool(forKey: autoPlayKey) },
            setAutoPlayNextEpisode: { defaults.set($0, forKey: autoPlayKey) },
            startMuted: { defaults.bool(forKey: startMutedKey) },
            setStartMuted: { defaults.set($0, forKey: startMutedKey) },
            hardwareAcceleration: { defaults.bool(forKey: hwAccelKey) },
            setHardwareAcceleration: { defaults.set($0, forKey: hwAccelKey) },
            epgTimeShift: { defaults.integer(forKey: epgShiftKey) },
            setEpgTimeShift: { defaults.set($0, forKey: epgShiftKey) },
            autoUpdateEPG: { defaults.bool(forKey: autoUpdateEpgKey) },
            setAutoUpdateEPG: { defaults.set($0, forKey: autoUpdateEpgKey) },
            hideAdultContent: { defaults.bool(forKey: hideAdultKey) },
            setHideAdultContent: { defaults.set($0, forKey: hideAdultKey) },
            defaultStartupTab: { defaults.string(forKey: startupTabKey) ?? "Keşfet" },
            setDefaultStartupTab: { defaults.set($0, forKey: startupTabKey) }
        )
    }()
}

public extension DependencyValues {
    var settingsClient: SettingsClient {
        get { self[SettingsClient.self] }
        set { self[SettingsClient.self] = newValue }
    }
}
