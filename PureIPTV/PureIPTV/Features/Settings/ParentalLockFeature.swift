import ComposableArchitecture
import Foundation

@Reducer
public struct ParentalLockFeature {
    @ObservableState
    public struct State: Equatable {
        public var pinInput: String = ""
        public var errorMessage: String?
        public var pendingItem: MediaModels.Item?
        public var pendingCategory: MediaModels.Category?

        public init(category: MediaModels.Category? = nil, item: MediaModels.Item? = nil) {
            pendingCategory = category
            pendingItem = item
        }
    }

    public enum Action: BindableAction {
        case onAppear
        case binding(BindingAction<State>)
        case pinInputChanged(String)
        case cancelTapped
        case authenticateWithBiometricsResult(Bool)
        case unlockSuccess
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didUnlock(category: MediaModels.Category?, item: MediaModels.Item?)
            case didCancel
        }
    }

    @Dependency(\.settingsClient) var settingsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    // Try FaceID first
                    let success = try await settingsClient.authenticateWithBiometrics("Yetişkin içeriğine erişmek için doğrulama gerekiyor")
                    await send(.authenticateWithBiometricsResult(success))
                }

            case .binding:
                return .none

            case let .pinInputChanged(input):
                let filtered = input.filter(\.isNumber)
                if filtered.count <= 4 {
                    state.pinInput = filtered
                    if filtered.count == 4 {
                        if settingsClient.verifyPIN(filtered) {
                            return .send(.unlockSuccess)
                        } else {
                            state.errorMessage = "Hatalı PIN"
                            state.pinInput = ""
                        }
                    }
                }
                return .none

            case .cancelTapped:
                return .send(.delegate(.didCancel))

            case let .authenticateWithBiometricsResult(success):
                if success {
                    return .send(.unlockSuccess)
                }
                return .none

            case .unlockSuccess:
                return .send(.delegate(.didUnlock(category: state.pendingCategory, item: state.pendingItem)))

            case .delegate:
                return .none
            }
        }
    }
}
