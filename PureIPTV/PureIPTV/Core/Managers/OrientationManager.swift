import Foundation
import SwiftUI
#if os(iOS)
    import UIKit

    @MainActor
    public final class OrientationManager {
        public static let shared = OrientationManager()

        /// Mask of currently supported orientations for the app window
        public var supportedOrientations: UIInterfaceOrientationMask = .allButUpsideDown

        private init() {}

        /// Automatically switches the screen to landscape for full-screen video playback (iPhone).
        public func lockLandscape() {
            guard UIDevice.current.userInterfaceIdiom == .phone else {
                supportedOrientations = .all
                return
            }

            supportedOrientations = .landscape

            if #available(iOS 16.0, *) {
                guard let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive })
                else {
                    return
                }

                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in
                    // If landscapeRight fails or orientation is reversed, try any landscape
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { _ in }
                }
                UIViewController.attemptRotationToDeviceOrientation()
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
        }

        /// Restores vertical portrait orientation when player is minimized to Mini-Player or closed (iPhone).
        public func unlockPortrait() {
            guard UIDevice.current.userInterfaceIdiom == .phone else {
                supportedOrientations = .all
                return
            }

            supportedOrientations = .portrait

            if #available(iOS 16.0, *) {
                guard let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive })
                else {
                    return
                }

                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
                UIViewController.attemptRotationToDeviceOrientation()
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
        }

        /// Releases strict orientation lock back to general defaults.
        public func resetToDefault() {
            if UIDevice.current.userInterfaceIdiom == .pad {
                supportedOrientations = .all
            } else {
                supportedOrientations = .allButUpsideDown
            }
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
