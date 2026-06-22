import XCTest

final class TodayFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
    }

    func testTodayTabShowsEmptyStateGuidance() throws {
        app.launch()

        let todayTab = app.tabBars.buttons["今日"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        todayTab.tap()

        let emptyGuidance = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '添加'")
        ).firstMatch
        XCTAssertTrue(emptyGuidance.waitForExistence(timeout: 5))
    }

    func testManualAddTaskAppearsInTodayList() throws {
        app.launch()

        app.tabBars.buttons["今日"].tap()

        let addButton = app.buttons["today-add-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let contentField = app.textFields["task-content-field"]
        XCTAssertTrue(contentField.waitForExistence(timeout: 5))
        contentField.tap()
        contentField.typeText("背诵古诗")

        let subjectPicker = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '科目'")
        ).firstMatch
        if subjectPicker.waitForExistence(timeout: 2) {
            subjectPicker.tap()
            let chineseOption = app.buttons.matching(
                NSPredicate(format: "label CONTAINS '语文'")
            ).firstMatch
            if chineseOption.waitForExistence(timeout: 2) {
                chineseOption.tap()
            }
        }

        app.buttons["task-create-save"].tap()

        let taskLabel = app.staticTexts["背诵古诗"]
        XCTAssertTrue(taskLabel.waitForExistence(timeout: 5))
    }
}
