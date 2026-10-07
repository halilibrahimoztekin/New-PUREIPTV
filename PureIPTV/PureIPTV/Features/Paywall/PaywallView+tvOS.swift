#if os(tvOS)
    import ComposableArchitecture
    import RevenueCat
    import SwiftUI

    public struct PaywallView: View {
        let store: StoreOf<PaywallFeature>

        public init(store: StoreOf<PaywallFeature>) {
            self.store = store
        }

        public var body: some View {
            WithPerceptionTracking {
                ZStack {
                    // Background
                    Color.black.edgesIgnoringSafeArea(.all)

                    // Content
                    VStack(spacing: 40) {
                        Text(AppStrings.Paywall.unlockPremium)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(AppStrings.Paywall.fullAccessDescription)
                            .font(.headline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 100)

                        if store.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(2)
                        } else if let error = store.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                        } else {
                            HStack(spacing: 40) {
                                ForEach(store.packages, id: \.identifier) { package in
                                    Button(action: {
                                        store.send(.purchasePackage(package))
                                    }) {
                                        VStack(spacing: 20) {
                                            Text(package.storeProduct.localizedTitle)
                                                .font(.headline)
                                                .foregroundColor(.white)

                                            Text(package.localizedPriceString)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)

                                            Text(package.storeProduct.localizedDescription)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.center)
                                        }
                                        .frame(width: 300, height: 250)
                                        .padding()
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(16)
                                    }
                                    .buttonStyle(CardButtonStyle())
                                }
                            }
                            .padding(.top, 40)
                        }

                        Spacer()

                        Button(AppStrings.Paywall.restorePurchases) {
                            store.send(.restorePurchases)
                        }
                        .foregroundColor(.gray)
                        .padding()
                    }
                    .padding(60)
                }
                .onAppear {
                    store.send(.onAppear)
                }
            }
        }
    }
#endif
