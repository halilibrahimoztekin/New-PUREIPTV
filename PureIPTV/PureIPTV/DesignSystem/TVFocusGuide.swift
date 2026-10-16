#if os(tvOS)
    import SwiftUI
    import UIKit

    // MARK: - TV Focus Guide & Sınır Koruması (Apple HIG 10-Foot UI)

    /// tvOS Focus Engine için asimetrik, boşluklu veya çapraz grid geçişlerinde
    /// odağın çıkmaz sokağa girmesini (dead-end focus) veya alakasız öğelere zıplamasını
    /// önleyen görünmez kılavuz katmanı (UIFocusGuide Bridge).
    public struct TVFocusGuideBridge: UIViewRepresentable {
        public init() {}

        public func makeUIView(context _: Context) -> UIFocusGuideBridgeUIView {
            UIFocusGuideBridgeUIView()
        }

        public func updateUIView(_: UIFocusGuideBridgeUIView, context _: Context) {}
    }

    public final class UIFocusGuideBridgeUIView: UIView {
        private let focusGuide = UIFocusGuide()

        override public init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            backgroundColor = .clear

            addLayoutGuide(focusGuide)
            NSLayoutConstraint.activate([
                focusGuide.topAnchor.constraint(equalTo: topAnchor),
                focusGuide.bottomAnchor.constraint(equalTo: bottomAnchor),
                focusGuide.leadingAnchor.constraint(equalTo: leadingAnchor),
                focusGuide.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    // MARK: - Focus Guide Modifiers

    public extension View {
        /// Belirli bir alana Focus Sınır Koruması (Focus Guide) ekler.
        /// Boşluklu alanlarda odak ışın izleme (raycast) boşluğa düştüğünde odağı yakalar.
        func focusGuideBoundary() -> some View {
            background(TVFocusGuideBridge())
        }

        /// İki asimetrik sütun arasında (örn. Kategori -> Grid) güvenli odak köprüsü kurar.
        func focusBridge(in namespace: Namespace.ID, isPreferred: Bool = false) -> some View {
            focusScope(namespace)
                .modifier(DefaultFocusModifier(isPreferred: isPreferred, namespace: namespace))
        }
    }

    private struct DefaultFocusModifier: ViewModifier {
        let isPreferred: Bool
        let namespace: Namespace.ID

        func body(content: Content) -> some View {
            if isPreferred {
                content.prefersDefaultFocus(in: namespace)
            } else {
                content
            }
        }
    }
#else
    import SwiftUI

    public extension View {
        func focusGuideBoundary() -> some View {
            self
        }

        func focusBridge(in _: Namespace.ID, isPreferred _: Bool = false) -> some View {
            self
        }
    }
#endif
