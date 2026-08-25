import SwiftUI

extension UIScreen {
    /// A modern replacement for `UIScreen.main.bounds.width`
    static var currentWidth: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) as? UIWindowScene else {
            return 0
        }
        return windowScene.screen.bounds.width
    }

    /// A modern replacement for `UIScreen.main.bounds.height`
    static var currentHeight: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) as? UIWindowScene else {
            return 0
        }
        return windowScene.screen.bounds.height
    }
}
