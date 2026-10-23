import ComposableArchitecture
import Foundation

// MARK: - Splash Phase

public enum SplashPhase: Equatable {
    case loading // Initial state: animating logo
    case ready // App is initialized, animation can complete
    case done // Transition to main app
}

// MARK: - SplashFeature

@Reducer
public struct SplashFeature {
    @ObservableState
    public struct State: Equatable {
        public var phase: SplashPhase = .loading
        public var logoScale: CGFloat = 0.7
        public var logoOpacity: Double = 0.0
        public var taglineOpacity: Double = 0.0
        public var indicatorOpacity: Double = 0.0

        public init() {}
    }

    public enum Action {
        case onAppear
        case logoAnimationDidStart
        case taglineAnimationDidStart
        case indicatorAnimationDidStart
        case appInitDidFinish
        case splashDidFinish
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.logoScale = 0.7
                state.logoOpacity = 0.0
                state.taglineOpacity = 0.0
                state.indicatorOpacity = 0.0
                // Kick off the animation sequence
                return .run { send in
                    await send(.logoAnimationDidStart)
                }

            case .logoAnimationDidStart:
                state.logoScale = 1.0
                state.logoOpacity = 1.0
                return .run { send in
                    // Stagger: tagline appears 0.4s after logo
                    try await Task.sleep(for: .milliseconds(400))
                    await send(.taglineAnimationDidStart)
                }

            case .taglineAnimationDidStart:
                state.taglineOpacity = 1.0
                return .run { send in
                    // Stagger: indicator appears 0.3s after tagline
                    try await Task.sleep(for: .milliseconds(300))
                    await send(.indicatorAnimationDidStart)
                    // Start app initialization in parallel (min 2s total splash)
                    try await Task.sleep(for: .milliseconds(1500))
                    await send(.appInitDidFinish)
                }

            case .indicatorAnimationDidStart:
                state.indicatorOpacity = 1.0
                return .none

            case .appInitDidFinish:
                state.phase = .ready
                return .run { send in
                    // Small grace period before transitioning
                    try await Task.sleep(for: .milliseconds(300))
                    await send(.splashDidFinish)
                }

            case .splashDidFinish:
                state.phase = .done
                return .none
            }
        }
    }
}
