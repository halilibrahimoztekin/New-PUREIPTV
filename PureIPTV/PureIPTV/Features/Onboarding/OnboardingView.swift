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
                colors: [Color(hex: "#0f0c29"), Color(hex: "#302b63"), Color(hex: "#24243e")],
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
                        Text("Atla")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding()
                    }
                    #if os(tvOS)
                    .buttonStyle(.plain)
                    .focusable(true)
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
                            title: "PureIPTV'ye Hoşgeldiniz",
                            description: "Apple ekosistemi için özenle tasarlanmış, akıcı ve reklamsız premium IPTV deneyimi.",
                            tag: 0
                        )
                    } else if tag == 1 {
                        onboardingPage(
                            icon: "magnifyingglass.circle.fill",
                            title: "Hızlı Arama & Geçmiş",
                            description: "Gelişmiş arama altyapısı sayesinde binlerce kanal ve film arasında saniyeler içinde geçiş yapın.",
                            tag: 1
                        )
                    } else if tag == 2 {
                        onboardingPage(
                            icon: "pip.enter",
                            title: "Zengin Oynatıcı & PiP",
                            description: "Picture in Picture desteği ve ses/altyazı kontrolüyle seyir zevkinizi üst seviyeye taşıyın.",
                            tag: 2
                        )
                    } else {
                        VStack(spacing: 24) {
                            Image(systemName: "list.bullet.rectangle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.accentColor)
                                .padding(.bottom, 16)
                                .symbolEffect(.bounce, options: .repeating)

                            Text("Nasıl Kullanılır?")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("Ana ekrandan '+' butonuna basarak Xtream Codes veya M3U bağlantılarınızı kolayca ekleyebilir ve izlemeye başlayabilirsiniz.")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 32)

                            Button {
                                store.send(.startTapped)
                            } label: {
                                Text("Hemen Başla")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                #if os(iOS)
                                    .background(Color.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                #endif
                            }
                            #if os(iOS)
                            .buttonStyle(FluidScaleButtonStyle())
                            .padding(.horizontal, 40)
                            #else
                            .buttonStyle(.card)
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
                .font(.system(size: 100))
                .foregroundColor(.accentColor)
                .padding(.bottom, 16)
                .symbolEffect(.pulse)

            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if tag < 3 {
                Button {
                    store.send(.nextPage, animation: .spring())
                } label: {
                    Text("İleri")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                    #if os(iOS)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    #endif
                }
                #if os(tvOS)
                .buttonStyle(.card)
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
