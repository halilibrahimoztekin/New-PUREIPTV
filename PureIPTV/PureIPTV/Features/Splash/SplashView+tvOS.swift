#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS Splash View

    // Design principles:
    // - 10-foot UI: everything at 1.5–2x scale vs iOS
    // - Focus Engine: all interactive elements conform to focusability
    // - tvOS remote "select" triggers splash completion if app is ready
    // - Logo animation: more dramatic, breathing pulse for OLED TVs

    public struct SplashView_tvOS: View {
        @Bindable var store: StoreOf<SplashFeature>
        @FocusState private var isFocused: Bool

        public init(store: StoreOf<SplashFeature>) {
            self.store = store
        }

        public var body: some View {
            ZStack {
                // ── OLED Black base ──────────────────────────────────────────
                Color.black
                    .ignoresSafeArea()

                // ── Wide ambient glow (TV screens are wide) ──────────────────
                EllipticalGradient(
                    colors: [
                        Color(hex: "#0A84FF").opacity(0.12),
                        Color(hex: "#BF5AF2").opacity(0.06),
                        Color.clear,
                    ],
                    center: .center,
                    startRadiusFraction: 0.1,
                    endRadiusFraction: 0.7
                )
                .ignoresSafeArea()
                .opacity(store.logoOpacity)

                // ── Main content ─────────────────────────────────────────────
                VStack(spacing: 0) {
                    Spacer()

                    // Logo badge — scaled up for 10-foot viewing
                    TVLogoBadge()
                        .scaleEffect(store.logoScale)
                        .opacity(store.logoOpacity)
                        .animation(
                            .spring(response: 0.9, dampingFraction: 0.6),
                            value: store.logoScale
                        )
                        .animation(
                            .easeOut(duration: 0.6),
                            value: store.logoOpacity
                        )

                    Spacer().frame(height: 36)

                    // Wordmark — Display Large for TV
                    Text(AppStrings.Splash.appName)
                        .font(.system(size: 72, weight: .heavy, design: .default))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#E4E1E7"), Color(hex: "#C0C6D6")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .tracking(-1.5)
                        .opacity(store.logoOpacity)
                        .animation(.easeOut(duration: 0.7).delay(0.2), value: store.logoOpacity)

                    Spacer().frame(height: 16)

                    // Tagline
                    Text(AppStrings.Splash.tagline)
                        .font(.system(size: 28, weight: .medium, design: .default))
                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.65))
                        .tracking(3)
                        .textCase(.uppercase)
                        .opacity(store.taglineOpacity)
                        .animation(.easeOut(duration: 0.6), value: store.taglineOpacity)

                    Spacer()

                    // Invisible focusable button — captures tvOS remote "Select"
                    // when splash is ready, allowing early dismissal
                    Button {
                        if store.phase == .ready {
                            store.send(.splashDidFinish)
                        }
                    } label: {
                        // TV loading indicator
                        TVLoadingIndicator()
                            .opacity(store.indicatorOpacity)
                            .animation(.easeIn(duration: 0.5), value: store.indicatorOpacity)
                    }
                    .buttonStyle(.tvCapsule) // Use custom style instead of plain
                    .focused($isFocused)
                    .padding(.bottom, 80) // tvOS safe area
                }
            }
            .onAppear {
                store.send(.onAppear)
                // tvOS auto-focuses the button so remote works immediately
                isFocused = true
            }
        }
    }

    // MARK: - TV Logo Badge

    private struct TVLogoBadge: View {
        var body: some View {
            PureMaterialLogo(size: 180, showGlow: true)
        }
    }

    // MARK: - TV Loading Indicator

    private struct TVLoadingIndicator: View {
        @State private var isPulsing = false

        var body: some View {
            HStack(spacing: 14) {
                ForEach(0 ..< 3, id: \.self) { index in
                    Circle()
                        .fill(Color(hex: "#0A84FF"))
                        .frame(width: 12, height: 12)
                        .scaleEffect(isPulsing ? 1.0 : 0.4)
                        .opacity(isPulsing ? 1.0 : 0.25)
                        .animation(
                            .easeInOut(duration: 0.7)
                                .repeatForever()
                                .delay(Double(index) * 0.18),
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

    #Preview("tvOS Splash") {
        SplashView_tvOS(
            store: Store(initialState: SplashFeature.State()) {
                SplashFeature()
            }
        )
    }
#endif
