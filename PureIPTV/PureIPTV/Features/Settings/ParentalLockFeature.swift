import ComposableArchitecture
import Foundation

@Reducer
public struct ParentalLockFeature {
    @ObservableState
    public struct State: Equatable {
        public enum Parent: Equatable {
            case vod(routeIndex: Int, config: PlaylistConfig)
            case series(routeIndex: Int, config: PlaylistConfig)
        }

        public let presentationID: UUID
        public let isCoordinatorRoute: Bool
        public var parent: Parent?
        public var pinInput: String = ""
        public var errorMessage: String?
        public var pendingItem: MediaModels.Item?
        public var pendingCategory: MediaModels.Category?

        public init(
            category: MediaModels.Category? = nil,
            item: MediaModels.Item? = nil,
            presentationID: UUID = UUID(),
            isCoordinatorRoute: Bool = false,
            parent: Parent? = nil
        ) {
            self.presentationID = presentationID
            self.isCoordinatorRoute = isCoordinatorRoute
            self.parent = parent
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
            case didUnlockFromRoute(presentationID: UUID, category: MediaModels.Category?, item: MediaModels.Item?)
            case didCancel
            case didCancelFromRoute(presentationID: UUID)
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
                    let success = try await settingsClient.authenticateWithBiometrics(AppStrings.ParentalLock.biometricReason)
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
                            state.errorMessage = AppStrings.Errors.incorrectPIN
                            state.pinInput = ""
                        }
                    }
                }
                return .none

            case .cancelTapped:
                if state.isCoordinatorRoute {
                    return .send(.delegate(.didCancelFromRoute(presentationID: state.presentationID)))
                }
                return .send(.delegate(.didCancel))

            case let .authenticateWithBiometricsResult(success):
                if success {
                    return .send(.unlockSuccess)
                }
                return .none

            case .unlockSuccess:
                if state.isCoordinatorRoute {
                    return .send(.delegate(.didUnlockFromRoute(
                        presentationID: state.presentationID,
                        category: state.pendingCategory,
                        item: state.pendingItem
                    )))
                }
                return .send(.delegate(.didUnlock(
                    category: state.pendingCategory,
                    item: state.pendingItem
                )))

            case .delegate:
                return .none
            }
        }
    }
}
