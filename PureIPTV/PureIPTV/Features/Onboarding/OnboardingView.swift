import ComposableArchitecture
import OnboardingKit
import SwiftUI

public struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    public init(store: StoreOf<OnboardingFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [AppColors.background, AppColors.surfaceElevated, AppColors.surfaceSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        store.send(.skipTapped)
                    } label: {
                        Text(AppStrings.Onboarding.skip)
                            .font(AppFonts.bodyMedium.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding()
                    }
                    #if os(tvOS)
                    .buttonStyle(TVCapsuleButtonStyle())
                    #endif
                }

                OnboardingPageView(
                    pages: [0, 1, 2, 3],
                    pageIndex: $store.currentPage
                ) { info in
                    let tag = info.page
                    if tag == 0 {
                        onboardingPage(
                            icon: "tv.circle.fill",
                            title: AppStrings.Onboarding.page1Title,
                            description: AppStrings.Onboarding.page1Desc,
                            tag: 0
                        )
                    } else if tag == 1 {
                        onboardingPage(
                            icon: "magnifyingglass.circle.fill",
                            title: AppStrings.Onboarding.page2Title,
                            description: AppStrings.Onboarding.page2Desc,
                            tag: 1
                        )
                    } else if tag == 2 {
                        onboardingPage(
                            icon: "pip.enter",
                            title: AppStrings.Onboarding.page3Title,
                            description: AppStrings.Onboarding.page3Desc,
                            tag: 2
                        )
                    } else {
                        VStack(spacing: 24) {
                            Image(systemName: "list.bullet.rectangle.fill")
                                .font(AppFonts.custom(size: 80))
                                .foregroundColor(AppColors.primary)
                                .padding(.bottom, 16)
                                .symbolEffect(.bounce, options: .repeating)

                            Text(AppStrings.Onboarding.howToUse)
                                .font(AppFonts.headline)
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)

                            Text(AppStrings.Onboarding.description)
                                .font(AppFonts.bodyLarge)
                                .foregroundColor(AppColors.textPrimary.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 32)

                            Button {
                                store.send(.startTapped)
                            } label: {
                                Text(AppStrings.Onboarding.startNow)
                                    .font(AppFonts.titleSmall)
                                    .foregroundColor(AppColors.textPrimary)
                                #if os(iOS)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(AppColors.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                #else
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                #endif
                            }
                            #if os(iOS)
                            .buttonStyle(FluidScaleButtonStyle())
                            .padding(.horizontal, 40)
                            #else
                            .buttonStyle(TVCapsuleButtonStyle(isPrimary: true, isSelected: false))
                            .frame(width: 400)
                            #endif
                        }
                        .tag(3)
                    }
                }
                .animation(.easeInOut, value: store.currentPage)
            }
        }
    }

    private func onboardingPage(icon: String, title: String, description: String, tag: Int) -> some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(AppFonts.custom(size: 100))
                .foregroundColor(AppColors.primary)
                .padding(.bottom, 16)
                .symbolEffect(.pulse)

            Text(title)
                .font(AppFonts.headline)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(description)
                .font(AppFonts.bodyLarge)
                .foregroundColor(AppColors.textPrimary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if tag < 3 {
                Button {
                    store.send(.nextPage, animation: .spring())
                } label: {
                    Text(AppStrings.Onboarding.next)
                        .font(AppFonts.bodyLarge.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                    #if os(iOS)
                        .background(AppColors.borderStrong)
                        .clipShape(Capsule())
                    #endif
                }
                #if os(tvOS)
                .tvFocusEffect()
                #endif
                .padding(.top, 32)
            }
        }
        .tag(tag)
    }
}

#Preview {
    OnboardingView(store: Store(initialState: OnboardingFeature.State()) {
        OnboardingFeature()
    })
}
