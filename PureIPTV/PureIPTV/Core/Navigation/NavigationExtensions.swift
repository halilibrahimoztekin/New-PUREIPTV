#if os(iOS)
    import UIKit

    // MARK: - Interactive Pop Gesture Support

    /// Enables swipe-to-back even when .navigationBarBackButtonHidden(true) is used
    extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
        override open func viewDidLoad() {
            super.viewDidLoad()
            interactivePopGestureRecognizer?.delegate = self
        }

        public func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
            viewControllers.count > 1
        }
    }
#endif
