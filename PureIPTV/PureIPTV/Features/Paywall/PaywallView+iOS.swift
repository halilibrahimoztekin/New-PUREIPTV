#if os(iOS)
    import ComposableArchitecture
    import RevenueCatUI
    import SwiftUI

    public struct PaywallView: View {
        let store: StoreOf<PaywallFeature>

        public init(store: StoreOf<PaywallFeature>) {
            self.store = store
        }

        public var body: some View {
            // We can just present the native RevenueCatUI PaywallView here.
            // Or we could wrap RevenueCatUI.PaywallView
            RevenueCatUI.PaywallView(displayCloseButton: true)
                .onPurchaseCompleted { customerInfo in
                    store.send(.purchaseResponse(.success(customerInfo)))
                }
                .onRestoreCompleted { customerInfo in
                    store.send(.restoreResponse(.success(customerInfo)))
                }
        }
    }
#endif
