#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - iOS & iPad Splash View

    public struct SplashView_iOS: View {
        @Bindable var store: StoreOf<SplashFeature>

        public init(store: StoreOf<SplashFeature>) {
            self.store = store
        }

        public var body: some View {
            ZStack {
                // ── OLED Black base ──────────────────────────────────────────
                Color.black
                    .ignoresSafeArea()

                // ── Ambient gradient glow behind logo ────────────────────────
                RadialGradient(
                    colors: [
                        Color(hex: "#0A84FF").opacity(0.15),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 280
                )
                .ignoresSafeArea()
                .opacity(store.logoOpacity)

                // ── Content stack ─────────────────────────────────────────────
                VStack(spacing: 0) {
                    Spacer()

                    // Logo
                    LogoBadge()
                        .scaleEffect(store.logoScale)
                        .opacity(store.logoOpacity)
                        .animation(
                            .spring(response: 0.7, dampingFraction: 0.65),
                            value: store.logoScale
                        )
                        .animation(
                            .easeOut(duration: 0.5),
                            value: store.logoOpacity
                        )

                    Spacer().frame(height: 20)

                    // Wordmark
                    Text(AppStrings.Splash.appName)
                        .font(.system(size: 34, weight: .heavy, design: .default))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#E4E1E7"), Color(hex: "#C0C6D6")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .tracking(-0.5)
                        .opacity(store.logoOpacity)
                        .animation(.easeOut(duration: 0.6).delay(0.15), value: store.logoOpacity)

                    Spacer().frame(height: 8)

                    // Tagline
                    Text(AppStrings.Splash.tagline)
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.7))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .opacity(store.taglineOpacity)
                        .animation(.easeOut(duration: 0.5), value: store.taglineOpacity)

                    Spacer()

                    // Loading indicator
                    PulsingIndicator()
                        .opacity(store.indicatorOpacity)
                        .animation(.easeIn(duration: 0.4), value: store.indicatorOpacity)
                        .padding(.bottom, 56)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
        }
    }

    // MARK: - Logo Badge

    private struct LogoBadge: View {
        var body: some View {
            PureMaterialLogo(size: 96, showGlow: true)
        }
    }

    // MARK: - Pulsing Indicator

    private struct PulsingIndicator: View {
        @State private var isPulsing = false

        var body: some View {
            HStack(spacing: 8) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Circle()
                        .fill(Color(hex: "#0A84FF"))
                        .frame(width: 6, height: 6)
                        .scaleEffect(isPulsing ? 1.0 : 0.5)
                        .opacity(isPulsing ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: isPulsing
                        )
                }
            }
            .onAppear {
                isPulsing = true
            }
        }
    }

    // MARK: - Preview

    #Preview {
        SplashView_iOS(
            store: Store(initialState: SplashFeature.State()) {
                SplashFeature()
            }
        )
    }
#endif
