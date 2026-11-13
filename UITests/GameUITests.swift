//
//  GameUITests.swift
//  2048 — smoke test of the real app: a seeded fresh game (`-uiTestFreshGame`, nothing persisted).
//

import XCTest

final class GameUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshGame", "-interfaceLanguage", "en"]
        app.launch()
    }

    func testSwipesMoveAndUndoComesBack() {
        let board = app.otherElements["game.board"]
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        let undo = app.buttons["game.undo"]
        XCTAssertFalse(undo.isEnabled)

        let start = board.value as? String
        let swipes: [(XCUIElement) -> Void] = [{ $0.swipeLeft() }, { $0.swipeUp() },
                                                { $0.swipeRight() }, { $0.swipeDown() }]
        for swipe in swipes {
            swipe(board)
            if board.value as? String != start { break }
        }
        XCTAssertNotEqual(board.value as? String, start)
        XCTAssertTrue(undo.isEnabled)

        undo.tap()
        XCTAssertEqual(board.value as? String, start)
    }

    func testStatisticsAndSettingsOpen() {
        app.buttons["toolbar.statistics"].tap()
        XCTAssertTrue(app.otherElements["stats.bestScore"].waitForExistence(timeout: 3)
                      || app.staticTexts["BEST SCORE"].exists)
        app.buttons["Done"].tap()

        app.buttons["toolbar.settings"].tap()
        XCTAssertTrue(app.switches["settings.sound"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
    }
}
