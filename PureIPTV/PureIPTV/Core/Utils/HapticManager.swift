import Foundation
import SwiftUI

#if os(iOS)
    import UIKit
#endif

public enum HapticStyle {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
}

public struct HapticManager {
    public static let shared = HapticManager()

    private init() {}

    public func trigger(_ style: HapticStyle) {
        #if os(iOS)
            switch style {
            case .light:
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            case .medium:
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            case .heavy:
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
            case .success:
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            case .warning:
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            case .error:
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        #endif
    }
}
