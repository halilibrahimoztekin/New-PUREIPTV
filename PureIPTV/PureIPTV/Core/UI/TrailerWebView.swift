#if os(iOS)
    import SafariServices
    import SwiftUI
    import UIKit

    /// Presents Safari as a modal view controller after the coordinator route appears.
    struct SafariModalPresenter: UIViewControllerRepresentable {
        let url: URL
        let onDismiss: () -> Void

        func makeUIViewController(context: Context) -> SafariPresentationHostController {
            SafariPresentationHostController(url: url, onDismiss: onDismiss)
        }

        func updateUIViewController(_ controller: SafariPresentationHostController, context: Context) {
            controller.onDismiss = onDismiss
            controller.presentSafariIfNeeded()
        }
    }

    @MainActor
    final class SafariPresentationHostController: UIViewController, SFSafariViewControllerDelegate {
        private let url: URL
        var onDismiss: () -> Void
        private var didPresentSafari = false

        init(url: URL, onDismiss: @escaping () -> Void) {
            self.url = url
            self.onDismiss = onDismiss
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func loadView() {
            let presenterView = UIView()
            presenterView.backgroundColor = .clear
            view = presenterView
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            presentSafariIfNeeded()
        }

        func presentSafariIfNeeded() {
            guard !didPresentSafari,
                  isViewLoaded,
                  view.window != nil,
                  presentedViewController == nil
            else { return }

            didPresentSafari = true
            let safariViewController = SFSafariViewController(url: url)
            safariViewController.delegate = self
            present(safariViewController, animated: true)
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDismiss()
        }
    }
#endif
