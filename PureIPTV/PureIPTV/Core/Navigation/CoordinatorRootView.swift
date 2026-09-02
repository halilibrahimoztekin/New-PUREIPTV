import SwiftUI
import UIKit
import XCoordinator

/// A simple SwiftUI wrapper that hosts the AppCoordinator's rootViewController.
/// All routing logic is now handled in AppCoordinator and triggered by TCA Reducers via side-effects.
public struct CoordinatorRootView: UIViewControllerRepresentable {
    let coordinator: AppCoordinator

    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    public func makeUIViewController(context _: Context) -> UINavigationController {
        coordinator.rootViewController
    }

    public func updateUIViewController(_: UINavigationController, context _: Context) {
        // No manual state observation needed here!
        // XCoordinator handles all the routing internally.
    }
}
