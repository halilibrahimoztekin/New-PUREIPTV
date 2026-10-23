import ComposableArchitecture
import Foundation

@Reducer
public struct OnboardingFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var currentPage: Int = 0
        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case nextPage
        case skipTapped
        case startTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didCompleteOnboarding
        }
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .nextPage:
                state.currentPage += 1
                return .none
            case .skipTapped, .startTapped:
                UserDefaults.standard.set(true, forKey: "isOnboardingCompleted")
                return .send(.delegate(.didCompleteOnboarding))
            case .delegate:
                return .none
            case .binding:
                return .none
            }
        }
    }
}
