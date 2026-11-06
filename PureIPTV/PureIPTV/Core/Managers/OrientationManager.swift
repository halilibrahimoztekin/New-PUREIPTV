import Foundation
import SwiftUI
#if os(iOS)
    import OSLog
    import UIKit

    @MainActor
    public final class OrientationManager {
        public static let shared = OrientationManager()

        /// Mask of currently supported orientations for the app window
        public var supportedOrientations: UIInterfaceOrientationMask = .allButUpsideDown

        private static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "PureIPTV",
            category: "OrientationManager"
        )

        private init() {}

        /// Automatically switches the screen to landscape for full-screen video playback (iPhone).
        public func lockLandscape() {
            guard UIDevice.current.userInterfaceIdiom == .phone else {
                updateSupportedOrientations(.all)
                return
            }

            let windowScene = updateSupportedOrientations(.landscape)

            if #available(iOS 16.0, *) {
                guard let windowScene else { return }
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { error in
                    Self.logger.error("Landscape-right geometry request failed: \(error.localizedDescription, privacy: .public)")
                    // If landscape-right is unavailable, retry with either landscape direction.
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
                        Self.logger.error("Landscape geometry fallback failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
        }

        /// Restores vertical portrait orientation when player is minimized to Mini-Player or closed (iPhone).
        public func unlockPortrait() {
            guard UIDevice.current.userInterfaceIdiom == .phone else {
                updateSupportedOrientations(.all)
                return
            }

            let windowScene = updateSupportedOrientations(.portrait)

            if #available(iOS 16.0, *) {
                guard let windowScene else { return }
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                    Self.logger.error("Portrait geometry request failed: \(error.localizedDescription, privacy: .public)")
                }
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
        }

        /// Releases strict orientation lock back to general defaults.
        public func resetToDefault() {
            if UIDevice.current.userInterfaceIdiom == .pad {
                updateSupportedOrientations(.all)
            } else {
                updateSupportedOrientations(.allButUpsideDown)
            }
        }

        /// Updates the app's advertised mask and tells UIKit to re-query the active controller.
        /// The scene geometry request must follow this notification or it can be rejected against
        /// a stale supported-orientation mask.
        @discardableResult
        private func updateSupportedOrientations(_ orientations: UIInterfaceOrientationMask) -> UIWindowScene? {
            supportedOrientations = orientations

            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else {
                Self.logger.warning("Cannot refresh orientation support: no foreground-active window scene")
                return nil
            }

            let rootViewController = windowScene.windows
                .first(where: \.isKeyWindow)?
                .rootViewController
            let visibleViewController = Self.visibleViewController(from: rootViewController)

            if #available(iOS 16.0, *) {
                rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                if let visibleViewController, visibleViewController !== rootViewController {
                    visibleViewController.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            }

            return windowScene
        }

        private static func visibleViewController(from viewController: UIViewController?) -> UIViewController? {
            guard let viewController else { return nil }

            if let presented = viewController.presentedViewController {
                return visibleViewController(from: presented)
            }
            if let navigationController = viewController as? UINavigationController {
                return visibleViewController(from: navigationController.visibleViewController)
            }
            if let tabBarController = viewController as? UITabBarController {
                return visibleViewController(from: tabBarController.selectedViewController)
            }

            return viewController
        }
    }
#else
    public final class OrientationManager {
        public static let shared = OrientationManager()
        private init() {}
        public func lockLandscape() {}
        public func unlockPortrait() {}
        public func resetToDefault() {}
    }
#endif
