//
//  DiaryAppUITests.swift
//  DiaryAppUITests
//
//  Created by Den Ree on 20/05/2025.
//

import XCTest

final class DiaryAppUITests: XCTestCase {

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
    func testCreateEntryAndVerifyInList() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Diary"].waitForExistence(timeout: 2))

        // Open add-entry flow from the trailing navigation bar button.
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

        XCTAssertTrue(app.buttons["UI Test Entry"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
