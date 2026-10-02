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
    func testChapterCreationKeepsItsOwnDraftAndFields(){
        app.tabBars.buttons["Spaces"].tap();app.buttons["Chapters"].tap()
        app.buttons["Add chapter"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Add chapter"].waitForExistence(timeout:5))
        let title=app.descendants(matching:.any).matching(identifier:"creation-title").firstMatch
        title.tap();title.typeText("Chapter: native draft")
        let pov=app.descendants(matching:.any).matching(identifier:"creation-POV").firstMatch
        pov.tap();pov.typeText("Narrator")
        snapshot("Chapter creation uses its own native editor")
        app.buttons["Close"].firstMatch.tap();app.buttons["Add chapter"].firstMatch.tap()
        XCTAssertEqual(title.value as? String,"Chapter: native draft")
        XCTAssertEqual(pov.value as? String,"Narrator")
        app.buttons["creation-save"].tap()
        XCTAssertTrue(app.staticTexts["Chapter: native draft"].waitForExistence(timeout:5))
    }
    func testNativeMetronomeProducesRunningAudioAndStops(){
        app.tabBars.buttons["Spaces"].tap();app.buttons["Songs"].tap()
        for (name,tempo) in [("Audio test song","120"),("Second audio song","144")] {
            XCTAssertTrue(app.buttons["module-add"].waitForExistence(timeout:5));app.buttons["module-add"].tap()
            let title=app.descendants(matching:.any).matching(identifier:"creation-title").firstMatch;title.tap();title.typeText(name)
            let bpm=app.descendants(matching:.any).matching(identifier:"creation-BPM").firstMatch;bpm.tap();bpm.typeText(tempo)
            app.buttons["creation-save"].tap();XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout:5))
        }
        app.buttons["Rehearsal mode"].tap()
        app.buttons["Select Second audio song"].tap();XCTAssertTrue(app.staticTexts["144"].waitForExistence(timeout:5))
        app.buttons["Select Audio test song"].tap();XCTAssertTrue(app.staticTexts["120"].waitForExistence(timeout:5))
        app.buttons["Start metronome"].tap()
        XCTAssertTrue(app.buttons["Stop metronome"].waitForExistence(timeout:5));snapshot("Rehearsal with running native audio")
        app.buttons["Stop metronome"].tap();XCTAssertTrue(app.buttons["Start metronome"].waitForExistence(timeout:5))
    }
    func testNativeWorkspaceFocusActuallyChangesToday(){
        app.buttons["Change focus"].tap();app.buttons["Moshia"].tap()
        XCTAssertTrue(app.buttons["Focused on Moshia"].waitForExistence(timeout:5))
        let hero=app.descendants(matching:.any).matching(identifier:"focused-workspace").firstMatch
        XCTAssertTrue(hero.exists);XCTAssertGreaterThan(hero.frame.height,250)
        snapshot("Moshia is the dominant Today workspace")
        app.terminate();app.launchArguments=["-ui-testing"];app.launch()
        XCTAssertTrue(app.buttons["Focused on Moshia"].waitForExistence(timeout:5))
    }
    func ask(_ question:String){
        let input=app.descendants(matching:.any).matching(identifier:"assistant-question").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText(question)
        app.buttons["Send question"].tap()
    }
    func testAssistantKeepsContextAndPreviewsReminders(){
        capture("French homework tomorrow")
        app.tabBars.buttons["Assistant"].tap()
        app.buttons["assistant-workspace-all"].tap()
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
    func testAssistantChooserHasEqualCardsAndSeparateChatsWithOneTapTyping(){
        app.tabBars.buttons["Assistant"].tap()
        XCTAssertFalse(app.descendants(matching:.any).matching(identifier:"assistant-question").firstMatch.exists)
        let everyday=app.buttons["assistant-workspace-all"]
        let ejj=app.buttons["assistant-workspace-ejj"]
        XCTAssertTrue(everyday.waitForExistence(timeout:5))
        XCTAssertEqual(everyday.frame.height,ejj.frame.height,accuracy:1)
        XCTAssertEqual(everyday.frame.width,ejj.frame.width,accuracy:1)
        snapshot("Assistant workspace chooser")
        everyday.tap()
        let input=app.descendants(matching:.any).matching(identifier:"assistant-question").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout:5));input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:3))
        input.typeText("Hello");app.buttons["Send question"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@","What’s on your mind?")).firstMatch.waitForExistence(timeout:5))
        snapshot("Everyday conversation and compact composer")
        app.navigationBars.buttons.firstMatch.tap()
        ejj.tap()
        XCTAssertTrue(app.navigationBars["EJJ Digital"].waitForExistence(timeout:5))
        XCTAssertFalse(app.staticTexts["Hello"].exists)
        snapshot("Dedicated EJJ Digital chat")
        app.terminate();app.launchArguments.removeAll{$0 == "-reset-test-data"};app.launch()
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-all"].tap()
        XCTAssertTrue(app.staticTexts["Hello"].waitForExistence(timeout:5))
        snapshot("Conversation restored after app restart")
    }
    func testHandsOnTutorialsAdvanceWithRealActionsAndKeepYourData(){
        snapshot("Warm welcoming Today screen")
        app.buttons["Settings and backup"].tap()
        let guide=app.buttons["settings-tutorial"]
        for _ in 0..<6 {if guide.isHittable{break};app.swipeUp()}
        XCTAssertTrue(guide.isHittable);guide.tap()
        XCTAssertTrue(app.staticTexts["Learn by doing."].waitForExistence(timeout:5))
        snapshot("Hands-on tutorial chooser")
        func start(_ id:String){
            let button=app.buttons["tutorial-start-"+id]
            for _ in 0..<5 {if button.isHittable{break};app.swipeUp()}
            XCTAssertTrue(button.isHittable);button.tap()
            XCTAssertTrue(app.buttons["walkthrough-exit"].waitForExistence(timeout:5))
        }
        func finish(){
            XCTAssertTrue(app.buttons["walkthrough-done"].waitForExistence(timeout:5))
            snapshot("Interactive tutorial completed")
            app.buttons["walkthrough-done"].tap()
            XCTAssertTrue(app.navigationBars["Your guide"].waitForExistence(timeout:5))
        }
        start("capture")
        XCTAssertTrue(app.staticTexts["Open Capture"].exists)
        app.tabBars.buttons["Capture"].tap()
        XCTAssertTrue(app.staticTexts["Try typing"].waitForExistence(timeout:5))
        snapshot("Capture tutorial highlights the actual input")
        let input=app.descendants(matching:.any).matching(identifier:"capture-text").firstMatch
        input.tap();input.typeText("Practice guitar tomorrow")
        XCTAssertTrue(app.staticTexts["Save the thought"].exists)
        app.buttons["capture-save"].tap();finish()
        start("chapters");app.tabBars.buttons["Spaces"].tap()
        let chapters=app.buttons["Chapters"]
        for _ in 0..<5 {if chapters.isHittable{break};app.swipeUp()}
        chapters.tap();app.buttons["module-add"].tap()
        let title=app.descendants(matching:.any).matching(identifier:"creation-title").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout:5));title.tap();title.typeText("My practice chapter")
        let context=app.descendants(matching:.any).matching(identifier:"creation-context").firstMatch
        context.tap();context.typeText("A character finds a letter.")
        snapshot("Chapter tutorial highlights the real Add control")
        app.buttons["creation-save"].tap();finish()
        start("assistant");app.tabBars.buttons["Assistant"].tap()
        app.buttons["assistant-workspace-moshia"].tap()
        let message=app.descendants(matching:.any).matching(identifier:"assistant-question").firstMatch
        message.tap();message.typeText("What have I saved about Moshia?")
        snapshot("Assistant tutorial highlights the actual send button")
        app.buttons["Send question"].tap();finish()
        start("search");app.tabBars.buttons["Search"].tap()
        let search=app.textFields["search-query"]
        XCTAssertTrue(search.waitForExistence(timeout:5));search.tap();search.typeText("guitar")
        app.staticTexts["Practice guitar"].tap();finish()
        start("appearance");app.buttons["Settings and backup"].tap()
        app.buttons["Compact"].tap()
        XCTAssertTrue(app.staticTexts["Try Comfortable"].waitForExistence(timeout:5))
        app.buttons["Comfortable"].tap();finish()
        start("focus");app.buttons["Change focus"].tap()
        app.buttons["Moshia"].tap();finish()
        app.navigationBars.buttons.firstMatch.tap()
        for _ in 0..<6 {if app.buttons["Comfortable"].isHittable{break};app.swipeDown()}
        XCTAssertTrue(app.buttons["Comfortable"].isSelected)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertFalse(app.staticTexts["My practice chapter"].exists)
        app.tabBars.buttons["Search"].tap()
        XCTAssertFalse(app.staticTexts["Practice guitar"].exists)
        XCTAssertFalse(app.staticTexts["Practice guitar tomorrow"].exists)
    }
    func testInstalledContextAndWorkspaceBackgroundsReadOnly(){
        app.terminate()
        app.launchArguments=[];app.launchEnvironment=[:];app.launch()
        app.buttons["Settings and backup"].tap()
        let contextLink=app.buttons["Review saved context"]
        for _ in 0..<4 {if contextLink.isHittable{break};app.swipeUp()}
        XCTAssertTrue(contextLink.isHittable);contextLink.tap()
        XCTAssertTrue(app.buttons["refresh-assistant-context"].waitForExistence(timeout:5))
        snapshot("Imported assistant context in Settings")
        app.navigationBars.buttons.firstMatch.tap();app.navigationBars.buttons.firstMatch.tap()
        app.tabBars.buttons["Spaces"].tap();app.buttons["Chapters"].tap()
        let chapter=app.staticTexts["Chapter 3"]
        for _ in 0..<5 {if chapter.exists{break};app.swipeUp()}
        XCTAssertTrue(chapter.exists)
        snapshot("Real imported Moshia chapter summaries")
        app.navigationBars.buttons.firstMatch.tap()
        app.tabBars.buttons["Assistant"].tap()
        let ejj=app.buttons["assistant-workspace-ejj"]
        XCTAssertTrue(ejj.waitForExistence(timeout:5));ejj.tap()
        snapshot("EJJ Digital business workspace chat")
        app.navigationBars.buttons.firstMatch.tap()
        if !app.buttons["assistant-workspace-ejj"].waitForExistence(timeout:3) {app.navigationBars.buttons.firstMatch.tap()}
        let story=app.buttons["assistant-workspace-moshia"]
        for _ in 0..<3 {if story.isHittable{break};app.swipeUp()}
        XCTAssertTrue(story.isHittable);story.tap()
        snapshot("Moshia story workspace chat")
        for (scope,name) in [("band","CLEARANCE 19 rehearsal room chat"),("school","School study desk chat"),("personal","Personal notebook chat")] {
            app.navigationBars.buttons.firstMatch.tap()
            let card=app.buttons["assistant-workspace-"+scope]
            if !card.isHittable {app.swipeUp()}
            card.tap();snapshot(name)
        }
    }
    func testConnectedNaturalVoiceReadOnly(){
        app.terminate();app.launchArguments=[];app.launchEnvironment=[:];app.launch()
        snapshot("Installed home with visible contour background")
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-all"].tap()
        app.buttons["assistant-voice"].tap()
        app.segmentedControls.buttons["Natural"].tap()
        XCTAssertTrue(app.buttons["voice-read-reply"].waitForExistence(timeout:5))
        app.buttons["voice-read-reply"].tap()
        XCTAssertTrue(app.staticTexts["Natural voice · Gemini"].waitForExistence(timeout:18))
        XCTAssertTrue(app.staticTexts["Your assistant is speaking"].exists)
        snapshot("Verified natural Gemini voice on the iPhone")
        app.buttons["voice-done"].tap()
    }
    func testAssistantAttachmentPickersAndSpokenReply(){
        snapshot("Refined iOS home with contour background")
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-all"].tap()
        app.buttons["assistant-attach"].tap();app.buttons["Choose a file"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout:5));app.buttons["Cancel"].tap()
        app.buttons["assistant-attach"].tap();app.buttons["Photo or video"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout:5));app.buttons["Cancel"].tap()
        let input=app.descendants(matching:.any).matching(identifier:"assistant-question").firstMatch
        input.tap();input.typeText("Hello");app.buttons["Send question"].tap()
        app.buttons["assistant-voice"].tap()
        XCTAssertTrue(app.staticTexts["Ready when you are"].waitForExistence(timeout:5))
        snapshot("Voice conversation with explicit microphone control")
        app.buttons["voice-read-reply"].tap()
        XCTAssertTrue(app.staticTexts["Your assistant is speaking"].waitForExistence(timeout:5))
        snapshot("Assistant speaking the reply aloud")
        app.buttons["voice-done"].tap()
        XCTAssertTrue(app.buttons["assistant-question"].exists || app.textFields["assistant-question"].exists || app.textViews["assistant-question"].exists)
    }
    func testDistinctWorkspaceChatLayouts(){
        app.tabBars.buttons["Assistant"].tap()
        for (scope,heading) in [("ejj","BUSINESS WORKSPACE"),("band","Your rehearsal room"),("moshia","The story workspace"),("school","Study desk"),("personal","Your notebook"),("all","Your day, together.")] {
            let card=app.buttons["assistant-workspace-"+scope]
            for _ in 0..<3 {if card.isHittable{break};app.swipeUp()}
            if !card.isHittable {app.swipeDown()}
            XCTAssertTrue(card.isHittable);card.tap()
            XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout:5))
            snapshot("Distinct chat design "+scope)
            app.navigationBars.buttons.firstMatch.tap()
        }
    }
    func testDensityChangesAllAssistantCardsImmediately(){
        app.tabBars.buttons["Assistant"].tap()
        let card=app.buttons["assistant-workspace-all"]
        XCTAssertTrue(card.waitForExistence(timeout:5));let comfortable=card.frame.height
        app.buttons["Settings and backup"].tap();app.buttons["Compact"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout:5));XCTAssertLessThan(card.frame.height,comfortable-20)
        snapshot("Compact spaces and assistant layout")
        app.buttons["Settings and backup"].tap();app.buttons["Comfortable"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout:5));XCTAssertEqual(card.frame.height,comfortable,accuracy:1)
        snapshot("Comfortable spaces and assistant layout")
    }
    func testChaptersUseSeparateCardsAndWritingSections(){
        app.tabBars.buttons["Spaces"].tap();app.buttons["Chapters"].tap()
        for title in ["First test chapter","Second test chapter","Third test chapter"] {
            app.buttons["module-add"].tap()
            let input=app.descendants(matching:.any).matching(identifier:"creation-title").firstMatch
            let context=app.descendants(matching:.any).matching(identifier:"creation-context").firstMatch
            XCTAssertTrue(input.waitForExistence(timeout:5));XCTAssertGreaterThan(context.frame.minY-input.frame.maxY,20)
            input.tap();XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:3));input.typeText(title)
            if title == "First test chapter" { snapshot("Separate chapter title and context fields") }
            app.buttons["creation-save"].tap()
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout:5))
        }
        app.swipeDown()
        let cards=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","chapter-card-"))
        XCTAssertEqual(cards.count,3)
        XCTAssertGreaterThan(cards.element(boundBy:1).frame.minY-cards.element(boundBy:0).frame.maxY,12)
        snapshot("Three individually separated chapter cards")
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
