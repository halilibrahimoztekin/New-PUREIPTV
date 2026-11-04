//
//  PureIPTVUITests.swift
//  PureIPTVUITests
//
//  Created by ibrahim öztekin on 19.08.2026.
//

import XCTest

final class PureIPTVUITests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testDashboardPersonalizationSectionScroll() {
        let app = XCUIApplication()
        app.launchArguments += ["-isOnboardingCompleted", "YES"]
        app.launch()

        let m3uOption = app.buttons["M3U URL"]
        let isAddingPlaylist = m3uOption.waitForExistence(timeout: 10)
        if isAddingPlaylist {
            #if os(tvOS)
                let xtreamOption = app.buttons["Xtream Codes"]
                XCTAssertTrue(xtreamOption.waitForExistence(timeout: 5))
                for _ in 0 ..< 20 where !xtreamOption.hasFocus {
                    Thread.sleep(forTimeInterval: 0.15)
                }
                XCTAssertTrue(xtreamOption.hasFocus)
                XCUIRemote.shared.press(.right)
                Thread.sleep(forTimeInterval: 0.3)
                XCTAssertTrue(m3uOption.hasFocus)
                XCUIRemote.shared.press(.select)
            #else
                m3uOption.tap()
            #endif

            let playlistURLField = app.textFields.matching(
                NSPredicate(format: "placeholderValue CONTAINS %@", "M3U URL")
            ).firstMatch
            XCTAssertTrue(playlistURLField.waitForExistence(timeout: 10))
            #if os(tvOS)
                for _ in 0 ..< 6 where !playlistURLField.hasFocus {
                    XCUIRemote.shared.press(.down)
                    Thread.sleep(forTimeInterval: 0.15)
                }
                XCTAssertTrue(playlistURLField.hasFocus)
                XCUIRemote.shared.press(.select)
            #else
                playlistURLField.tap()
            #endif
            playlistURLField.typeText("http://127.0.0.1:8766/synthetic.m3u")

            let connectButton = app.buttons["Bağlan"]
            XCTAssertTrue(connectButton.waitForExistence(timeout: 10))
            #if os(tvOS)
                for _ in 0 ..< 4 {
                    XCUIRemote.shared.press(.down)
                    Thread.sleep(forTimeInterval: 0.15)
                }
                XCUIRemote.shared.press(.select)
                Thread.sleep(forTimeInterval: 0.3)
                for _ in 0 ..< 2 {
                    XCUIRemote.shared.press(.down)
                    Thread.sleep(forTimeInterval: 0.2)
                }
                XCUIRemote.shared.press(.select)
            #else
                connectButton.tap()
            #endif
        }

        let adultProfile = app.staticTexts["Yetişkin"]
        if adultProfile.waitForExistence(timeout: isAddingPlaylist ? 60 : 3) {
            #if os(tvOS)
                XCUIRemote.shared.press(.select)
            #else
                app.buttons.matching(
                    NSPredicate(format: "label CONTAINS %@", "Yetişkin")
                ).firstMatch.tap()
            #endif
        }

        #if os(tvOS)
            let premiumCloseButton = app.buttons["Kapat"]
            if premiumCloseButton.waitForExistence(timeout: 5) {
                for _ in 0 ..< 8 where !premiumCloseButton.hasFocus {
                    XCUIRemote.shared.press(.right)
                    Thread.sleep(forTimeInterval: 0.15)
                }
                if premiumCloseButton.hasFocus {
                    XCUIRemote.shared.press(.select)
                }
            }
        #endif

        let recommendationsTitle = app.staticTexts["Sana Özel Öneriler"].firstMatch
        #if os(tvOS)
            for _ in 0 ..< 40 where !recommendationsTitle.waitForExistence(timeout: 1) {
                XCUIRemote.shared.press(.down)
                Thread.sleep(forTimeInterval: 0.1)
            }
            XCTAssertTrue(recommendationsTitle.waitForExistence(timeout: 30))

            for _ in 0 ..< 3 {
                XCUIRemote.shared.press(.up)
                Thread.sleep(forTimeInterval: 0.15)
                XCUIRemote.shared.press(.down)
                Thread.sleep(forTimeInterval: 0.15)
                XCTAssertTrue(recommendationsTitle.waitForExistence(timeout: 10))
            }
        #else
            for _ in 0 ..< 12 where !recommendationsTitle.waitForExistence(timeout: 2) {
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(recommendationsTitle.waitForExistence(timeout: 30))

            for _ in 0 ..< 3 {
                app.scrollViews.firstMatch.swipeDown()
                app.scrollViews.firstMatch.swipeUp()
                XCTAssertTrue(recommendationsTitle.waitForExistence(timeout: 10))
            }
        #endif
    }

    @MainActor
    func testLaunchPerformance() {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
