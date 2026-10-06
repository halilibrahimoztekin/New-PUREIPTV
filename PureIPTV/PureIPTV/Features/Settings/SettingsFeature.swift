import ComposableArchitecture
import Foundation

@Reducer
public struct SettingsFeature {
    @ObservableState
    public struct State: Equatable {
        public var isParentalControlEnabled: Bool = false
        public var isShowingPINSetup: Bool = false
        public var pinInput: String = ""
        public var pinConfirm: String = ""
        public var step: PINStep = .enterNew
        public var errorMessage: String?

        public enum PINStep: Equatable {
            case enterNew
            case confirm
        }

        public init() {}
    }

    public enum Action: BindableAction {
        case managePlaylistsTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case openManagePlaylists
        }

        case onAppear
        case binding(BindingAction<State>)
        case toggleParentalControl(Bool)
        case pinInputChanged(String)
        case cancelPINSetup
        case savePIN
    }

    @Dependency(\.settingsClient) var settingsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isParentalControlEnabled = settingsClient.isParentalControlEnabled()
                return .none

            case .managePlaylistsTapped:
                return .send(.delegate(.openManagePlaylists))

            case .delegate:
                return .none

            case .binding:
                return .none

            case let .toggleParentalControl(enabled):
                if enabled {
                    // Kapatmaktan açmaya geçiyorsa PIN belirleme ekranını aç
                    state.isShowingPINSetup = true
                    state.step = .enterNew
                    state.pinInput = ""
                    state.pinConfirm = ""
                    state.errorMessage = nil
                    // Toggle'ı UI'da hemen true yapma, PIN belirlenince true yapacağız
                    return .none
                } else {
                    // Kapatılıyorsa direkt kapat
                    state.isParentalControlEnabled = false
                    return .run { _ in
                        try await settingsClient.setParentalControl(false, nil)
                    }
                }

            case let .pinInputChanged(input):
                let filtered = input.filter(\.isNumber)
                if filtered.count <= 4 {
                    if state.step == .enterNew {
                        state.pinInput = filtered
                        if filtered.count == 4 {
                            state.step = .confirm
                            state.errorMessage = nil
                        }
                    } else {
                        state.pinConfirm = filtered
                        if filtered.count == 4 {
                            return .send(.savePIN)
                        }
                    }
                }
                return .none

            case .cancelPINSetup:
                state.isShowingPINSetup = false
                state.isParentalControlEnabled = false
                return .none

            case .savePIN:
                if state.pinInput == state.pinConfirm {
                    state.isParentalControlEnabled = true
                    state.isShowingPINSetup = false
                    let finalPIN = state.pinInput
                    return .run { _ in
                        try await settingsClient.setParentalControl(true, finalPIN)
                    }
                } else {
                    state.errorMessage = AppStrings.Errors.pinMismatch
                    state.pinConfirm = ""
                    state.step = .confirm
                    return .none
                }
            }
        }
    }
}
