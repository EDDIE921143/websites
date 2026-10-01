import XCTest

final class EdizOSUITests:XCTestCase {
    var app:XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure=false
        app=XCUIApplication()
        app.launchArguments=["-ui-testing","-reset-test-data"]
        app.launchEnvironment["EDIZ_UI_TEST_ID"]=UUID().uuidString
        app.launch()
    }
    override func tearDownWithError() throws {
        let attachment=XCTAttachment(screenshot:app.screenshot())
        attachment.name=name;attachment.lifetime = .keepAlways
        add(attachment)
    }
    func capture(_ title:String) {
        app.tabBars.buttons["Capture"].tap()
        let input=app.descendants(matching:.any).matching(identifier:"capture-text").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText(title)
        let save=app.buttons["capture-save"];XCTAssertTrue(save.waitForExistence(timeout:5));save.tap()
    }
    func testCapturePersistenceCompletionAndUndo() {
        capture("French homework tomorrow")
        let task=app.staticTexts["French homework tomorrow"]
        XCTAssertTrue(task.waitForExistence(timeout:5))
        app.terminate();app.launchArguments=["-ui-testing"];app.launch()
        XCTAssertTrue(task.waitForExistence(timeout:5))
        app.buttons["Complete French homework tomorrow"].tap()
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout:5));app.buttons["Undo"].tap()
        XCTAssertTrue(task.waitForExistence(timeout:5))
    }
    func testNativeEdgeSwipeBackFromEditor() {
        capture("Phone navigation check")
        app.staticTexts["Phone navigation check"].tap()
        XCTAssertTrue(app.buttons["record-save"].waitForExistence(timeout:5))
        app.coordinate(withNormalizedOffset:CGVector(dx:0.01,dy:0.5)).press(forDuration:0.05,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.85,dy:0.5)))
        XCTAssertTrue(app.navigationBars["Ediz OS"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["record-save"].exists)
    }
    func testNativeCaptureCanDismissWithSwipeAndRecoverDraft() {
        app.tabBars.buttons["Capture"].tap()
        let input=app.descendants(matching:.any).matching(identifier:"capture-text").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText("A pending thought")
        app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.08)).press(forDuration:0.1,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.9)))
        XCTAssertTrue(app.tabBars.buttons["Capture"].waitForExistence(timeout:5))
        app.tabBars.buttons["Capture"].tap()
        XCTAssertTrue(input.waitForExistence(timeout:5));XCTAssertEqual(input.value as? String,"A pending thought")
    }
    func testAllSpacesHaveRealModuleDestinations() {
        app.tabBars.buttons["Spaces"].tap()
        for title in ["EJJ Digital","CLEARANCE 19","Moshia","School"] { XCTAssertTrue(app.staticTexts[title].exists) }
        app.buttons["Characters"].tap()
        let add=app.buttons["Add character"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout:5));add.tap()
        let input=app.descendants(matching:.any).matching(identifier:"capture-text").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText("Character for test")
        XCTAssertTrue(app.staticTexts["POSSIBLE — canon only when you choose it."].exists)
        app.buttons["capture-save"].tap()
        XCTAssertTrue(app.staticTexts["Character for test"].waitForExistence(timeout:5))
    }
}
