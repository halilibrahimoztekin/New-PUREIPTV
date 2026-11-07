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
    func testEpisodeForwardSeekAdvancesPlaybackTime() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-isOnboardingCompleted", "YES",
        ]
        app.launch()

        let adultProfileButton = app.buttons["Yetişkin"]
        XCTAssertTrue(adultProfileButton.waitForExistence(timeout: 10))
        adultProfileButton.tap()

        let seriesTab = app.tabBars.buttons["Diziler"]
        XCTAssertTrue(seriesTab.waitForExistence(timeout: 20))
        seriesTab.tap()

        let seriesCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Mahsun J EXXEN")
        ).firstMatch
        XCTAssertTrue(seriesCard.waitForExistence(timeout: 30))
        seriesCard.tap()

        let resumeButton = app.buttons["seriesDetail.resumeButton"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 20))
        resumeButton.tap()

        // A tap in the video toggles the hidden transport controls.
        let forwardButton = app.buttons["player.skipForward"]
        if !forwardButton.waitForExistence(timeout: 2) {
            // Controls start visible, but a slow opening/buffering transition can
            // leave the player surface needing a tap to reveal them.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        guard forwardButton.waitForExistence(timeout: 10) else {
            XCTContext.runActivity(named: "Player screen when skip control is missing") { activity in
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "player-skip-control-missing"
                screenshot.lifetime = .keepAlways
                activity.add(screenshot)

                let hierarchy = XCTAttachment(string: app.debugDescription)
                hierarchy.name = "player-accessibility-hierarchy"
                hierarchy.lifetime = .keepAlways
                activity.add(hierarchy)
            }
            XCTFail("The player forward-skip control did not appear. Current UI hierarchy:\n\(app.debugDescription)")
            return
        }
        let currentTime = app.staticTexts["player.currentTime"]
        XCTAssertTrue(currentTime.waitForExistence(timeout: 10))

        // The player hides its controls after a short idle period. Waiting for
        // the accessibility label above can outlast that timer, so make sure
        // the button is still visible and interactive immediately before the
        // tap. A center tap reveals the controls when they have auto-hidden.
        let actionableForwardButton = app.buttons["player.skipForward"]
        if !actionableForwardButton.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let forwardButtonHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: actionableForwardButton
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [forwardButtonHittable], timeout: 5),
            .completed,
            "The forward-skip button must be visible and hittable before the seek test taps it."
        )

        guard let startingSeconds = Self.seconds(from: currentTime.label) else {
            XCTFail("Player current-time label was not parseable: \(currentTime.label)")
            return
        }
        actionableForwardButton.tap()

        let didAdvance = expectation(for: NSPredicate { _, _ in
            guard let observedSeconds = Self.seconds(from: currentTime.label) else { return false }
            return observedSeconds >= startingSeconds + 8
        }, evaluatedWith: currentTime)
        wait(for: [didAdvance], timeout: 4)

        guard let finalSeconds = Self.seconds(from: currentTime.label) else {
            XCTFail("Player current-time label was not parseable after seek: \(currentTime.label)")
            return
        }
        XCTAssertGreaterThanOrEqual(finalSeconds, startingSeconds + 8)
    }

    @MainActor
    func testEpisodeResumesFromSavedPositionAfterClosingPlayer() {
        let app = XCUIApplication()
        app.launchArguments += ["-isOnboardingCompleted", "YES"]
        app.launch()

        let adultProfileButton = app.buttons["Yetişkin"]
        XCTAssertTrue(adultProfileButton.waitForExistence(timeout: 10))
        adultProfileButton.tap()

        let seriesTab = app.tabBars.buttons["Diziler"]
        XCTAssertTrue(seriesTab.waitForExistence(timeout: 20))
        seriesTab.tap()

        let seriesCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Mahsun J EXXEN")
        ).firstMatch
        XCTAssertTrue(seriesCard.waitForExistence(timeout: 30))
        seriesCard.tap()

        let resumeButton = app.buttons["seriesDetail.resumeButton"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 20))
        resumeButton.tap()

        let forwardButton = app.buttons["player.skipForward"]
        if !forwardButton.waitForExistence(timeout: 2) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(forwardButton.waitForExistence(timeout: 10))
        let currentTime = app.staticTexts["player.currentTime"]
        XCTAssertTrue(currentTime.waitForExistence(timeout: 10))

        let actionableForwardButton = app.buttons["player.skipForward"]
        if !actionableForwardButton.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let forwardButtonHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: actionableForwardButton
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [forwardButtonHittable], timeout: 5),
            .completed,
            "The forward-skip button must be visible and hittable before the seek test taps it."
        )

        guard let startingSeconds = Self.seconds(from: currentTime.label) else {
            XCTFail("Player current-time label was not parseable: \(currentTime.label)")
            return
        }
        actionableForwardButton.tap()

        let didAdvance = expectation(for: NSPredicate { _, _ in
            guard let observedSeconds = Self.seconds(from: currentTime.label) else { return false }
            return observedSeconds >= startingSeconds + 8
        }, evaluatedWith: currentTime)
        // Seek can trigger a short rebuffer on remote VOD streams. Keep the
        // assertion on the actual playback clock, but allow that rebuffer to
        // complete before closing the player and checking resume persistence.
        wait(for: [didAdvance], timeout: 20)

        guard let savedTimeSeconds = Self.seconds(from: currentTime.label) else {
            XCTFail("Player current-time label was not parseable before closing: \(currentTime.label)")
            return
        }

        let closeButton = app.buttons["Kapat"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 10))
        closeButton.tap()
        let resumeAgainButton = app.buttons["seriesDetail.resumeButton"]
        XCTAssertTrue(resumeAgainButton.waitForExistence(timeout: 20), "The episode should be saved before returning to its series detail page")
        resumeAgainButton.tap()

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let resumedTime = app.staticTexts["player.currentTime"]
        XCTAssertTrue(resumedTime.waitForExistence(timeout: 20))

        let resumedFromSavedPosition = expectation(for: NSPredicate { _, _ in
            guard let observedSeconds = Self.seconds(from: resumedTime.label) else { return false }
            return observedSeconds >= savedTimeSeconds - 5
        }, evaluatedWith: resumedTime)
        let resumeWaitResult = XCTWaiter.wait(for: [resumedFromSavedPosition], timeout: 20)
        XCTAssertEqual(
            resumeWaitResult,
            .completed,
            "Resume should reach the saved position. Saved label was \(savedTimeSeconds)s; latest resumed label is \(resumedTime.label)."
        )
        guard let resumedSeconds = Self.seconds(from: resumedTime.label) else {
            XCTFail("Player current-time label was not parseable after resume: \(resumedTime.label)")
            return
        }
        XCTAssertGreaterThanOrEqual(
            resumedSeconds,
            savedTimeSeconds - 5,
            "Resume regressed: saved at \(savedTimeSeconds)s, reopened at \(resumedSeconds)s."
        )
    }

    private static func seconds(from timestamp: String) -> Int? {
        let components = timestamp.split(separator: ":").compactMap { Int($0) }
        guard (2 ... 3).contains(components.count) else { return nil }
        return components.reduce(0) { $0 * 60 + $1 }
    }

    @MainActor
    func testSettingsRendersFromMoreTab() {
        let app = XCUIApplication()
        app.launchArguments += ["-isOnboardingCompleted", "YES"]
        app.launch()

        let adultProfileButton = app.buttons["Yetişkin"]
        XCTAssertTrue(adultProfileButton.waitForExistence(timeout: 10))
        adultProfileButton.tap()

        let moreTab = app.tabBars.buttons["Daha Fazla"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 15))
        moreTab.tap()

        let settingsRow = app.tables.cells
            .containing(.staticText, identifier: "Ayarlar")
            .firstMatch
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 10))
        XCTAssertTrue(settingsRow.isHittable)
        settingsRow.tap()

        let accountRow = app.staticTexts["Hesap Yönetimi (Playlists)"]
        let backupRestoreRow = app.staticTexts["Yedekten Geri Yükle (.iptvbackup)"]
        let switchProfileRow = app.staticTexts["Profil Değiştir"]
        XCTAssertTrue(accountRow.waitForExistence(timeout: 15))
        XCTAssertTrue(accountRow.isHittable)
        XCTAssertTrue(backupRestoreRow.isHittable)
        XCTAssertTrue(switchProfileRow.isHittable)
    }

    @MainActor
    func testAdultProfileSelectionLeavesProfilePicker() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-isOnboardingCompleted", "YES"]
        app.launch()

        let adultProfileButton = app.buttons["Yetişkin"]
        guard adultProfileButton.waitForExistence(timeout: 10) else {
            throw XCTSkip("Profile picker is not shown for this simulator state.")
        }

        adultProfileButton.tap()
        XCTAssertFalse(adultProfileButton.waitForExistence(timeout: 3))
    }

    @MainActor
    func testLiveTVGridRemainsAttachedToCategoriesWhileScrolling() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-isOnboardingCompleted", "YES"]
        app.launch()

        let adultProfileButton = app.buttons["Yetişkin"]
        XCTAssertTrue(adultProfileButton.waitForExistence(timeout: 10))
        adultProfileButton.tap()

        let liveTVTab = app.tabBars.buttons["Canlı TV"]
        XCTAssertTrue(liveTVTab.waitForExistence(timeout: 20))
        liveTVTab.tap()

        let categoryScroll = app.scrollViews["liveTV.categoryFilterScroll"]
        XCTAssertTrue(categoryScroll.waitForExistence(timeout: 20))
        let channelGrid = app.scrollViews["liveTV.channelGrid"]
        XCTAssertTrue(channelGrid.waitForExistence(timeout: 20))

        let channelPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "liveTV.channel.")
        let firstChannel = app.descendants(matching: .any).matching(channelPredicate).firstMatch
        guard firstChannel.waitForExistence(timeout: 20) else {
            throw XCTSkip("This simulator profile does not have any visible live channels.")
        }

        XCTAssertLessThanOrEqual(
            firstChannel.frame.minY - categoryScroll.frame.maxY,
            72,
            "The first channel row should stay close to the category filters."
        )

        let channels = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "liveTV.channel.")
        )
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)
        for swipeIndex in 0 ..< 3 {
            channelGrid.swipeUp()
            XCTAssertTrue(
                channels.allElementsBoundByIndex.contains(where: \.isHittable),
                "Channel cards should remain available after scroll \(swipeIndex + 1)."
            )
        }
    }

    @MainActor
    func testDashboardPersonalizationSectionScroll() throws {
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
            // The dashboard contains horizontal shelf scroll views. Select the
            // full-height vertical dashboard scroller explicitly so this test
            // cannot accidentally exercise a poster shelf instead.
            let dashboardScrollView = app.scrollViews["dashboard.mainScroll"]
            XCTAssertTrue(
                dashboardScrollView.waitForExistence(timeout: 10),
                "Expected the dashboard's main vertical scroll view."
            )

            for _ in 0 ..< 16 where !recommendationsTitle.isHittable {
                dashboardScrollView.swipeUp()
            }
            XCTAssertTrue(recommendationsTitle.waitForExistence(timeout: 30))

            let discoveryShelfPredicate = NSPredicate(
                format: "label IN %@ OR label BEGINSWITH %@",
                [
                    "Yeni Bölümler",
                    "En Çok Oy Alan Filmler",
                    "En Yüksek Puanlı Filmler",
                    "Ödül Kazanan Filmler",
                    "Ödüle Aday Filmler",
                    "En Çok İzlediğin Oyuncular",
                ],
                "Ortak oyuncu:"
            )
            let discoveryShelf = app.staticTexts.matching(discoveryShelfPredicate).firstMatch
            let downstreamAnchor = app.staticTexts["Yeni Eklenen Filmler"].firstMatch

            // The async discovery shelf is inserted above this stable home
            // section. Capture its visible frame while discovery is still
            // absent, then wait for the actual async insertion.
            for _ in 0 ..< 16 where !downstreamAnchor.isHittable {
                dashboardScrollView.swipeUp()
            }
            XCTAssertTrue(downstreamAnchor.waitForExistence(timeout: 20), "Expected a downstream dashboard section to anchor.")
            XCTAssertTrue(downstreamAnchor.isHittable, "The downstream anchor must be visible before measuring its frame.")
            if discoveryShelf.exists {
                throw XCTSkip("The simulator profile resolved its recommendation shelf before the baseline frame could be captured.")
            }

            let anchorFrameBeforeInsertion = downstreamAnchor.frame
            let discoveryShelfAppeared = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true"),
                object: discoveryShelf
            )
            guard XCTWaiter.wait(for: [discoveryShelfAppeared], timeout: 15) == .completed else {
                throw XCTSkip("No secondary recommendation shelf was eligible for this simulator playlist/profile.")
            }

            XCTAssertTrue(downstreamAnchor.isHittable, "The downstream anchor should remain visible after async shelf insertion.")
            let anchorFrameAfterInsertion = downstreamAnchor.frame
            XCTAssertEqual(
                anchorFrameAfterInsertion.minY,
                anchorFrameBeforeInsertion.minY,
                accuracy: 12,
                "Async recommendation shelf insertion shifted the visible downstream anchor. Before: \(anchorFrameBeforeInsertion), after: \(anchorFrameAfterInsertion)."
            )
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
