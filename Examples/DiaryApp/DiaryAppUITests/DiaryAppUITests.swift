//
//  DiaryAppUITests.swift
//  DiaryAppUITests
//
//  Created by Den Ree on 20/05/2025.
//

import XCTest

final class DiaryAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testCreateEntryAndVerifyInList() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 2))

        let addButton = app.navigationBars["Diary"].buttons.element(boundBy: 0)
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        addButton.tap()

        let titleField = app.textFields["Enter title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("UI Test Entry")

        let saveButton = app.navigationBars.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["UI Test Entry"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
