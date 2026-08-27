import ComposableArchitecture
import Foundation
import LocalAuthentication

@DependencyClient
public struct SettingsClient: Sendable {
    public var isParentalControlEnabled: @Sendable () -> Bool = { false }
    public var getParentalPIN: @Sendable () -> String? = { nil }
    public var setParentalControl: @Sendable (_ enabled: Bool, _ pin: String?) async throws -> Void
    public var verifyPIN: @Sendable (_ pin: String) -> Bool = { _ in false }
    public var isAdultContent: @Sendable (_ text: String) -> Bool = { _ in false }
    public var authenticateWithBiometrics: @Sendable (_ reason: String) async throws -> Bool
}

extension SettingsClient: DependencyKey {
    public static let liveValue: SettingsClient = {
        let defaults = UserDefaults.standard
        let pinKey = "com.pureiptv.parentalPIN"
        let enabledKey = "com.pureiptv.parentalControlEnabled"

        return SettingsClient(
            isParentalControlEnabled: {
                defaults.bool(forKey: enabledKey)
            },
            getParentalPIN: {
                defaults.string(forKey: pinKey)
            },
            setParentalControl: { enabled, pin in
                defaults.set(enabled, forKey: enabledKey)
                if let pin = pin, enabled {
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
            }
        )
    }()
}

public extension DependencyValues {
    var settingsClient: SettingsClient {
        get { self[SettingsClient.self] }
        set { self[SettingsClient.self] = newValue }
    }
}
