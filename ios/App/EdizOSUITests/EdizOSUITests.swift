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
        snapshot(name)
    }
    func snapshot(_ label:String){
        let attachment=XCTAttachment(screenshot:app.screenshot())
        attachment.name=label;attachment.lifetime = .keepAlways
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
        snapshot("Today with a real captured task")
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
        app.buttons["capture-from-today"].tap()
        let input=app.descendants(matching:.any).matching(identifier:"capture-text").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText("A pending thought")
        app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.08)).press(forDuration:0.1,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.9)))
        XCTAssertTrue(app.tabBars.buttons["Capture"].waitForExistence(timeout:5))
        app.buttons["capture-from-today"].tap()
        XCTAssertTrue(input.waitForExistence(timeout:5));XCTAssertEqual(input.value as? String,"A pending thought")
    }
    func testTabBarCanBeScrubbedAcrossCapture() {
        let today=app.tabBars.buttons["Today"],spaces=app.tabBars.buttons["Spaces"]
        today.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).press(forDuration:0.1,thenDragTo:spaces.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)))
        XCTAssertTrue(app.navigationBars["Spaces"].waitForExistence(timeout:5))
        snapshot("Native glass dock after sliding to Spaces")
    }
    func testAllSpacesHaveRealModuleDestinations() {
        app.tabBars.buttons["Spaces"].tap()
        snapshot("Spaces native index")
        for title in ["EJJ Digital","CLEARANCE 19","Moshia","School"] { XCTAssertTrue(app.staticTexts[title].exists) }
        app.buttons["Characters"].tap()
        let add=app.buttons["Add character"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout:5));add.tap()
        let input=app.descendants(matching:.any).matching(identifier:"creation-title").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText("Character for test")
        XCTAssertTrue(app.staticTexts["POSSIBLE — canon only when you choose it."].exists)
        app.buttons["creation-save"].tap()
        XCTAssertTrue(app.staticTexts["Character for test"].waitForExistence(timeout:5))
    }
    func ask(_ question:String){
        let input=app.descendants(matching:.any).matching(identifier:"assistant-question").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText(question)
        app.buttons["Send question"].tap()
    }
    func testAssistantKeepsContextAndPreviewsReminders(){
        capture("French homework tomorrow")
        app.tabBars.buttons["Assistant"].tap()
        ask("What should I focus on?")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@","Start with French homework")).firstMatch.waitForExistence(timeout:5))
        ask("Why that?")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@","French homework tomorrow:")).firstMatch.waitForExistence(timeout:5))
        snapshot("Assistant with a contextual follow-up")
        ask("Remind me call Studio 41 tomorrow at 16")
        let review=app.buttons["Review reminder"];XCTAssertTrue(review.waitForExistence(timeout:5));review.tap()
        XCTAssertTrue(app.buttons["capture-save"].waitForExistence(timeout:5))
        app.buttons["Close"].tap()
    }
    func testFocusCanPauseResumeAndFinish(){
        capture("A comfortable focus session")
        app.staticTexts["A comfortable focus session"].tap()
        app.buttons["Start focus"].tap()
        XCTAssertTrue(app.buttons["Begin"].waitForExistence(timeout:5));snapshot("Focus before starting");XCTAssertFalse(app.buttons["Finish"].exists);app.buttons["Begin"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout:5));app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout:5));app.buttons["Continue"].tap()
        app.buttons["Finish"].tap()
        XCTAssertTrue(app.buttons["record-save"].waitForExistence(timeout:5))
    }
}
