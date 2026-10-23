import ComposableArchitecture
@testable import PureIPTV
import SwiftVLC
import XCTest

@MainActor
final class ParentalControlEngineTests: XCTestCase {
    func testParentalControlClientBasicOperations() {
        let hiddenChannels = LockIsolated<[HiddenItemDTO]>([])
        let blacklistedCats = LockIsolated<[HiddenItemDTO]>([])
        let parentalPIN = LockIsolated("1234")
        let isEnabled = LockIsolated(true)

        let client = ParentalControlClient(
            isParentalControlEnabled: { isEnabled.value },
            verifyPIN: { input in input == parentalPIN.value },
            setParentalPIN: { pin, enabled in
                if let pin {
                    parentalPIN.setValue(pin)
                }
                isEnabled.setValue(enabled)
            },
            hasPIN: { !parentalPIN.value.isEmpty },
            isAdultContent: { text in
                text.lowercased().contains("adult") || text.lowercased().contains("xxx")
            },
            authenticateWithBiometrics: { _ in true },
            hiddenChannelIDs: { Set(hiddenChannels.value.map(\.id)) },
            hideChannel: { id, title in
                hiddenChannels.withValue { items in
                    if !items.contains(where: { $0.id == id }) {
                        items.append(HiddenItemDTO(id: id, title: title, type: .channel))
                    }
                }
            },
            unhideChannel: { id in
                hiddenChannels.withValue { items in
                    items.removeAll { $0.id == id }
                }
            },
            unhideAllChannels: {
                hiddenChannels.setValue([])
            },
            isChannelHidden: { id in
                hiddenChannels.value.contains(where: { $0.id == id })
            },
            blacklistedCategoryIDs: { Set(blacklistedCats.value.map(\.id)) },
            blacklistCategory: { id, title in
                blacklistedCats.withValue { items in
                    if !items.contains(where: { $0.id == id }) {
                        items.append(HiddenItemDTO(id: id, title: title, type: .category))
                    }
                }
            },
            unblacklistCategory: { id in
                blacklistedCats.withValue { items in
                    items.removeAll { $0.id == id }
                }
            },
            unblacklistAllCategories: {
                blacklistedCats.setValue([])
            },
            isCategoryBlacklisted: { id in
                blacklistedCats.value.contains(where: { $0.id == id })
            },
            fetchHiddenChannels: { hiddenChannels.value },
            fetchBlacklistedCategories: { blacklistedCats.value }
        )

        // 1. Initial State
        XCTAssertTrue(client.isParentalControlEnabled())
        XCTAssertTrue(client.hasPIN())
        XCTAssertTrue(client.verifyPIN("1234"))
        XCTAssertFalse(client.verifyPIN("0000"))
        XCTAssertTrue(client.isAdultContent("Adult Channel 18+"))
        XCTAssertFalse(client.isAdultContent("TRT Spor HD"))

        // 2. Hide & Unhide Channels
        XCTAssertFalse(client.isChannelHidden("ch_1"))
        client.hideChannel("ch_1", "Secret Channel")
        XCTAssertTrue(client.isChannelHidden("ch_1"))
        XCTAssertEqual(client.hiddenChannelIDs(), ["ch_1"])
        XCTAssertEqual(client.fetchHiddenChannels().count, 1)
        XCTAssertEqual(client.fetchHiddenChannels().first?.title, "Secret Channel")

        client.unhideChannel("ch_1")
        XCTAssertFalse(client.isChannelHidden("ch_1"))
        XCTAssertEqual(client.hiddenChannelIDs().count, 0)

        // 3. Blacklist Categories
        XCTAssertFalse(client.isCategoryBlacklisted("cat_xxx"))
        client.blacklistCategory("cat_xxx", "Adult VOD")
        XCTAssertTrue(client.isCategoryBlacklisted("cat_xxx"))
        XCTAssertEqual(client.blacklistedCategoryIDs(), ["cat_xxx"])

        client.unblacklistAllCategories()
        XCTAssertFalse(client.isCategoryBlacklisted("cat_xxx"))
        XCTAssertEqual(client.blacklistedCategoryIDs().count, 0)
    }

    func testPlayerFeatureHiddenChannelHandling() async throws {
        let streamURL = try XCTUnwrap(URL(string: "http://example.com/stream.m3u8"))
        let channel1 = PlayerFeature.PlayableItem(id: "1", title: "Kanal 1", streamURL: streamURL, isLive: true)
        let channel2 = PlayerFeature.PlayableItem(id: "2", title: "Kanal 2", streamURL: streamURL, isLive: true)
        let channel3 = PlayerFeature.PlayableItem(id: "3", title: "Kanal 3", streamURL: streamURL, isLive: true)

        let hiddenState = LockIsolated<Set<String>>(["2"])

        var state = PlayerFeature.State(item: channel1)
        state.playlist = [channel1, channel2, channel3]

        let store = TestStore(initialState: state) {
            PlayerFeature()
        } withDependencies: {
            $0.parentalControlClient.hiddenChannelIDs = { hiddenState.value }
            $0.parentalControlClient.blacklistedCategoryIDs = { [] }
            $0.parentalControlClient.hideChannel = { id, _ in
                hiddenState.withValue { _ = $0.insert(id) }
            }
            $0.parentalControlClient.unhideChannel = { id in
                hiddenState.withValue { _ = $0.remove(id) }
            }
        }

        // Test load preferences
        await store.send(.loadHiddenContentPreferences) {
            $0.hiddenChannelIDs = ["2"]
            $0.blacklistedCategoryIDs = []
        }

        // Hide Channel 3
        await store.send(.hideChannel(id: "3", title: "Kanal 3")) {
            $0.hiddenChannelIDs = ["2", "3"]
        }
        XCTAssertTrue(hiddenState.value.contains("3"))

        // Unhide Channel 2
        await store.send(.unhideChannel(id: "2")) {
            $0.hiddenChannelIDs = ["3"]
        }
        XCTAssertFalse(hiddenState.value.contains("2"))
    }

    func testSettingsFeatureHiddenContentUnlockAndUnhide() async {
        let hiddenList = LockIsolated<[HiddenItemDTO]>([
            HiddenItemDTO(id: "ch_99", title: "Özel Kanal", type: .channel),
        ])
        let blacklistedList = LockIsolated<[HiddenItemDTO]>([
            HiddenItemDTO(id: "cat_99", title: "Özel Kategori", type: .category),
        ])

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.parentalControlClient.isParentalControlEnabled = { true }
            $0.parentalControlClient.verifyPIN = { input in input == "9876" }
            $0.parentalControlClient.hiddenChannelIDs = { Set(hiddenList.value.map(\.id)) }
            $0.parentalControlClient.blacklistedCategoryIDs = { Set(blacklistedList.value.map(\.id)) }
            $0.parentalControlClient.fetchHiddenChannels = { hiddenList.value }
            $0.parentalControlClient.fetchBlacklistedCategories = { blacklistedList.value }
            $0.parentalControlClient.unhideChannel = { id in
                hiddenList.withValue { $0.removeAll(where: { item in item.id == id }) }
            }
            $0.parentalControlClient.unblacklistCategory = { id in
                blacklistedList.withValue { $0.removeAll(where: { item in item.id == id }) }
            }
            $0.parentalControlClient.authenticateWithBiometrics = { _ in false }
        }

        // 1. Trigger open hidden content -> shows PIN unlock modal because parental control is enabled
        #if os(tvOS)
            await store.send(.openHiddenContentManagement) {
                $0.isUnlockingHiddenContent = true
                $0.hiddenContentUnlockPIN = ""
                $0.hiddenContentUnlockError = nil
            }
        #else
            await store.send(.openHiddenContentManagement)
            await store.receive(\.biometricUnlockResult) {
                $0.isUnlockingHiddenContent = true
                $0.hiddenContentUnlockPIN = ""
                $0.hiddenContentUnlockError = nil
            }
        #endif

        // 2. Enter incorrect PIN: "1111"
        await store.send(.hiddenContentUnlockPINChanged("1111")) {
            $0.hiddenContentUnlockPIN = "1111"
        }
        await store.receive(\.submitHiddenContentUnlock) {
            $0.hiddenContentUnlockError = AppStrings.Errors.incorrectPIN
            $0.hiddenContentUnlockPIN = ""
        }

        // 3. Enter correct PIN: "9876"
        await store.send(.hiddenContentUnlockPINChanged("9876")) {
            $0.hiddenContentUnlockPIN = "9876"
        }
        await store.receive(\.submitHiddenContentUnlock) {
            $0.isUnlockingHiddenContent = false
            $0.hiddenContentUnlockPIN = ""
            $0.hiddenContentUnlockError = nil
        }
        await store.receive(\.loadHiddenContentData) {
            $0.hiddenChannelsList = hiddenList.value
            $0.blacklistedCategoriesList = blacklistedList.value
            $0.hiddenChannelsCount = 1
            $0.blacklistedCategoriesCount = 1
            $0.isShowingHiddenContentSheet = true
        }

        // 4. Unhide channel from settings
        await store.send(.unhideChannelFromSettings("ch_99")) {
            $0.hiddenChannelsList = []
            $0.hiddenChannelsCount = 0
        }
        XCTAssertEqual(hiddenList.value.count, 0)

        // 5. Unblacklist category from settings
        await store.send(.unblacklistCategoryFromSettings("cat_99")) {
            $0.blacklistedCategoriesList = []
            $0.blacklistedCategoriesCount = 0
        }
        XCTAssertEqual(blacklistedList.value.count, 0)

        // 6. Close sheet
        await store.send(.closeHiddenContentManagement) {
            $0.isShowingHiddenContentSheet = false
        }
    }
}
