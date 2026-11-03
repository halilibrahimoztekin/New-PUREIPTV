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
            ZStack {
                // Background: OLED Black + Ambient Glow
                Color.black.ignoresSafeArea()

                RadialGradient(
                    colors: [
                        AppColors.premium.opacity(0.12),
                        AppColors.primary.opacity(0.08),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: 700
                )
                .ignoresSafeArea()

                // Content
                VStack(spacing: 36) {
                    Spacer().frame(height: 10)

                    VStack(spacing: 12) {
                        Text(AppStrings.Paywall.unlockPremium)
                            .font(AppFonts.displayLarge)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.textPrimary, AppColors.onSurface],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: AppColors.premium.opacity(0.4), radius: 12, y: 4)

                        Text(AppStrings.Paywall.fullAccessDescription)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textSecondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 100)
                    }

                    if store.isLoading {
                        PureLoadingView(size: .large, text: AppStrings.Common.loading)
                            .frame(maxHeight: 280)
                    } else if let error = store.errorMessage {
                        Text(error)
                            .font(AppFonts.title)
                            .foregroundColor(AppColors.destructive)
                            .frame(maxHeight: 280)
                    } else {
                        HStack(spacing: 40) {
                            ForEach(store.packages, id: \.identifier) { package in
                                Button(action: {
                                    store.send(.purchasePackage(package))
                                }) {
                                    VStack(spacing: 16) {
                                        Text(package.storeProduct.localizedTitle)
                                            .font(AppFonts.title)
                                            .foregroundColor(AppColors.textPrimary)

                                        Text(package.localizedPriceString)
                                            .font(AppFonts.displayMedium)
                                            .foregroundColor(AppColors.premium)
                                            .shadow(color: AppColors.premium.opacity(0.4), radius: 8)

                                        Text(package.storeProduct.localizedDescription)
                                            .font(AppFonts.bodyMedium)
                                            .foregroundColor(AppColors.textSecondary.opacity(0.75))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(3)
                                    }
                                    .frame(width: 340, height: 260)
                                    .padding(24)
                                    .background(.ultraThinMaterial)
                                    .background(AppColors.surfaceSecondary.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [AppColors.premium.opacity(0.6), AppColors.primary.opacity(0.3)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                }
                                .buttonStyle(TVGridCardButtonStyle(cornerRadius: 20))
                            }
                        }
                        .padding(.top, 20)
                        .focusSection()
                    }

                    Spacer()

                    HStack(spacing: 32) {
                        Button {
                            store.send(.restorePurchases)
                        } label: {
                            Label(AppStrings.Paywall.restorePurchases, systemImage: "arrow.clockwise")
                                .font(.system(size: 20, weight: .semibold))
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))

                        Button {
                            store.send(.closeButtonTapped)
                        } label: {
                            Text(AppStrings.Common.cancel)
                                .font(.system(size: 20, weight: .semibold))
                                .padding(.horizontal, 28)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 40)

                // Top-Right Close Button
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            store.send(.closeButtonTapped)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.8))
                                .frame(width: 52, height: 52)
                        }
                        .buttonStyle(TVCircleButtonStyle())
                        .padding(50)
                    }
                    Spacer()
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onExitCommand {
                store.send(.closeButtonTapped)
            }
        }
    }
#endif
