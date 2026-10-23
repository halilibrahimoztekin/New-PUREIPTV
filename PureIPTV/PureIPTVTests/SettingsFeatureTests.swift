import ComposableArchitecture
@testable import PureIPTV
import XCTest

@MainActor
final class SettingsFeatureTests: XCTestCase {
    func testPINSetupSuccess() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient.isParentalControlEnabled = { false }
            $0.settingsClient.setParentalControl = { _, _ in }
        }

        await store.send(.onAppear) {
            $0.isParentalControlEnabled = false
        }

        // Enable toggle
        await store.send(.toggleParentalControl(true)) {
            $0.isShowingPINSetup = true
            $0.step = .enterNew
            $0.pinInput = ""
            $0.pinConfirm = ""
        }

        // Enter PIN 1234
        await store.send(.pinInputChanged("123")) {
            $0.pinInput = "123"
        }
        await store.send(.pinInputChanged("1234")) {
            $0.pinInput = "1234"
            $0.step = .confirm
        }

        // Confirm PIN 1234
        await store.send(.pinInputChanged("123")) {
            $0.pinConfirm = "123"
        }
        await store.send(.pinInputChanged("1234")) {
            $0.pinConfirm = "1234"
        }
        await store.receive(\.savePIN) {
            $0.isParentalControlEnabled = true
            $0.isShowingPINSetup = false
        }
    }

    func testPINSetupMismatch() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient.isParentalControlEnabled = { false }
        }

        await store.send(.toggleParentalControl(true)) {
            $0.isShowingPINSetup = true
            $0.step = .enterNew
        }

        await store.send(.pinInputChanged("1234")) {
            $0.pinInput = "1234"
            $0.step = .confirm
        }

        await store.send(.pinInputChanged("1235")) {
            $0.pinConfirm = "1235"
        }
        await store.receive(\.savePIN) {
            $0.errorMessage = AppStrings.Errors.pinMismatch
            $0.pinConfirm = ""
            $0.step = .confirm
        }
    }
}
