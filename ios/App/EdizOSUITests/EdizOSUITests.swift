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
        snapshot("Refined Capture writing card and destination preview")
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
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout:5));XCTAssertTrue(app.otherElements["completion-feedback"].exists);snapshot("Completion ring and Undo");app.buttons["Undo"].tap()
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
    func testEveryWorkspaceModuleCreatesAndReopensItsRecord(){
        let spaces:[(String,[String])]=[("ejj",["Leads","Websites","Tasks","Notes","Ideas"]),("band",["Songs","Rehearsals","Practice","Notes","Ideas"]),("moshia",["Chapters","Characters","Plot threads","Locations","Organizations","Timeline","Research","Ideas"]),("school",["Homework","Tests","Subjects","Grades","Timetable","Materials"]),("personal",["Tasks","Appointments","Notes","Ideas"])]
        app.tabBars.buttons["Spaces"].tap()
        for (scope,modules) in spaces {
            let space=app.buttons["space-"+scope]
            for _ in 0..<6{if space.isHittable{break};app.swipeUp()}
            XCTAssertTrue(space.isHittable);space.tap()
            for module in modules {
                app.buttons["module-picker"].tap();app.buttons[module].firstMatch.tap()
                app.buttons["module-add"].tap()
                let title=app.descendants(matching:.any).matching(identifier:"creation-title").firstMatch
                XCTAssertTrue(title.waitForExistence(timeout:5));title.tap();title.typeText(scope+" "+module+" sweep")
                app.buttons["creation-save"].tap()
                let record=app.staticTexts[scope+" "+module+" sweep"].firstMatch
                XCTAssertTrue(record.waitForExistence(timeout:5));record.tap()
                XCTAssertTrue(app.buttons["record-save"].waitForExistence(timeout:5))
                let edit=app.descendants(matching:.any).matching(identifier:"record-title").firstMatch
                XCTAssertEqual(edit.value as? String,scope+" "+module+" sweep")
                app.buttons["record-save"].tap()
                XCTAssertTrue(record.waitForExistence(timeout:5))
            }
            app.navigationBars.buttons.firstMatch.tap()
        }
        snapshot("Every workspace module created and reopened its typed record")
    }
    func testContinuityDeskOpensSavedChapter(){
        app.tabBars.buttons["Spaces"].tap();app.buttons["Chapters"].tap();app.buttons["module-add"].tap()
        let title=app.descendants(matching:.any).matching(identifier:"creation-title").firstMatch;title.tap();title.typeText("Chapter 1: A saved beginning");app.buttons["creation-save"].tap()
        app.buttons["story-desk-open"].tap();XCTAssertTrue(app.navigationBars["Continuity desk"].waitForExistence(timeout:5));XCTAssertTrue(app.staticTexts["Canon ledger"].exists)
        snapshot("Moshia continuity desk with saved chapter and separate canon")
        app.buttons["story-desk-continue"].tap();XCTAssertTrue(app.buttons["record-save"].waitForExistence(timeout:5));XCTAssertEqual(app.descendants(matching:.any).matching(identifier:"record-title").firstMatch.value as? String,"Chapter 1: A saved beginning")
    }
    func testStoryCanonRequiresConfirmationAndDeletionCanBeCancelled(){
        app.tabBars.buttons["Spaces"].tap();app.buttons["Chapters"].tap();app.buttons["module-add"].tap()
        let title=app.descendants(matching:.any).matching(identifier:"creation-title").firstMatch
        title.tap();title.typeText("Canon confirmation check");app.buttons["creation-save"].tap()
        app.staticTexts["Canon confirmation check"].tap();app.buttons["record-state"].tap();app.buttons["CANON"].firstMatch.tap();app.buttons["record-save"].tap()
        XCTAssertTrue(app.buttons["Confirm canon"].waitForExistence(timeout:5));app.buttons["Keep editing"].tap()
        XCTAssertTrue(app.buttons["record-save"].exists);app.buttons["record-save"].tap();app.buttons["Confirm canon"].tap()
        XCTAssertTrue(app.staticTexts["CANON"].waitForExistence(timeout:5))
        app.staticTexts["Canon confirmation check"].tap()
        for _ in 0..<6{if app.buttons["Delete item"].isHittable{break};app.swipeUp()}
        app.buttons["Delete item"].tap();XCTAssertTrue(app.buttons["Keep it"].waitForExistence(timeout:5));app.buttons["Keep it"].tap()
        XCTAssertTrue(app.buttons["record-save"].exists)
        app.buttons["Delete item"].tap();app.alerts.buttons["Delete item"].tap()
        XCTAssertTrue(app.buttons["module-add"].waitForExistence(timeout:5));XCTAssertFalse(app.staticTexts["Canon confirmation check"].exists)
    }
    func testSettingsHistoryHealthAndTextImport(){
        app.buttons["Settings and backup"].tap();app.buttons["Import & restore"].tap()
        let text=app.textFields["Paste tasks, notes or lead information"]
        XCTAssertTrue(text.waitForExistence(timeout:5));text.tap();text.typeText("A sweep import note")
        app.buttons["Review text"].tap();app.buttons["Import records"].tap()
        XCTAssertTrue(app.staticTexts["Records imported. Title duplicates were skipped."].waitForExistence(timeout:5))
        app.navigationBars.buttons.firstMatch.tap();app.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["A sweep import note"].waitForExistence(timeout:5))
        app.navigationBars.buttons.firstMatch.tap()
        for _ in 0..<6{if app.buttons["System health"].isHittable{break};app.swipeUp()}
        app.buttons["System health"].tap();XCTAssertTrue(app.staticTexts["Database, SQLite · WAL"].waitForExistence(timeout:5));XCTAssertTrue(app.staticTexts["Version, 0.3.15"].exists)
        snapshot("System health after a real text import")
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
        app.buttons["Select Second audio song"].tap();XCTAssertTrue(app.textFields["metronome-bpm"].waitForExistence(timeout:5));XCTAssertEqual(app.textFields["metronome-bpm"].value as? String,"144")
        app.buttons["Select Audio test song"].tap();XCTAssertEqual(app.textFields["metronome-bpm"].value as? String,"120")
        let tempo=app.textFields["metronome-bpm"];tempo.tap();tempo.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:3)+"132");app.buttons["Apply tempo"].tap()
        XCTAssertEqual(tempo.value as? String,"132");app.buttons["Increase tempo"].tap();XCTAssertEqual(tempo.value as? String,"133");app.buttons["Decrease tempo"].tap();XCTAssertEqual(tempo.value as? String,"132")
        app.buttons["Tap tempo"].tap();app.buttons["Tap tempo"].tap();XCTAssertTrue(Int(tempo.value as? String ?? "0").map{(30...240).contains($0)} == true)
        snapshot("Direct BPM entry and tempo adjustment controls")
        app.buttons["Start metronome"].tap()
        XCTAssertTrue(app.buttons["Stop metronome"].waitForExistence(timeout:5));snapshot("Rehearsal with running native audio")
        app.buttons["Stop metronome"].tap();XCTAssertTrue(app.buttons["Start metronome"].waitForExistence(timeout:5))
    }
    func testNativeWorkspaceFocusActuallyChangesToday(){
        app.buttons["Change focus"].tap();app.buttons["Moshia"].tap()
        XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"focused-workspace").firstMatch.waitForExistence(timeout:5));XCTAssertTrue(app.staticTexts["YOUR FOCUS"].exists);XCTAssertEqual(app.descendants(matching:.any).matching(identifier:"focus-logo").firstMatch.value as? String,"Moshia")
        let hero=app.descendants(matching:.any).matching(identifier:"focused-workspace").firstMatch
        XCTAssertTrue(hero.exists);XCTAssertGreaterThan(hero.frame.height,250)
        snapshot("Moshia is the dominant Today workspace")
        app.terminate();app.launchArguments=["-ui-testing"];app.launch()
        XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"focused-workspace").firstMatch.waitForExistence(timeout:5));XCTAssertTrue(app.staticTexts["YOUR FOCUS"].exists)
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
    func testConnectedTutorialUsesNaturalVoiceReadOnly() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Natural tutorial voice uses the paired phone credential.")
        #endif
        app.terminate();app.launchArguments=[];app.launchEnvironment=[:];app.launch()
        app.buttons["Settings and backup"].tap()
        let guide=app.buttons["settings-tutorial"]
        for _ in 0..<6{if guide.isHittable{break};app.swipeUp()}
        guide.tap()
        let spoken=app.switches["tutorial-spoken-guide"]
        XCTAssertTrue(spoken.waitForExistence(timeout:5));if spoken.value as? String == "0"{spoken.tap()}
        app.buttons["tutorial-start-chapters"].tap()
        XCTAssertTrue(app.staticTexts["Natural voice"].waitForExistence(timeout:20))
        let audible=NSPredicate(format:"value MATCHES %@","Audio level [1-9][0-9]*")
        expectation(for:audible,evaluatedWith:app.otherElements["tutorial-voice-activity"]);waitForExpectations(timeout:8)
        snapshot("Natural spoken chapter walkthrough in a safe practice workspace")
        app.buttons["walkthrough-voice-toggle"].tap();app.buttons["walkthrough-exit"].tap()
        XCTAssertTrue(app.navigationBars["Your guide"].waitForExistence(timeout:5))
    }
    func testSpokenTutorialCanReadMuteReplayAndAdvance(){
        app.buttons["Settings and backup"].tap()
        let guide=app.buttons["settings-tutorial"]
        for _ in 0..<6{if guide.isHittable{break};app.swipeUp()}
        guide.tap()
        let spoken=app.switches["tutorial-spoken-guide"]
        XCTAssertTrue(spoken.waitForExistence(timeout:5));if spoken.value as? String == "0"{spoken.tap()}
        app.buttons["tutorial-start-capture"].tap()
        XCTAssertTrue(app.buttons["walkthrough-voice-replay"].waitForExistence(timeout:5))
        let activity=app.otherElements["tutorial-voice-activity"]
        let audible=NSPredicate(format:"value MATCHES %@","Audio level [1-9][0-9]*")
        expectation(for:audible,evaluatedWith:activity);waitForExpectations(timeout:8)
        snapshot("Spoken tutorial with measured audio and mute replay controls")
        app.buttons["walkthrough-voice-toggle"].tap()
        XCTAssertFalse(app.buttons["walkthrough-voice-replay"].exists)
        app.tabBars.buttons["Capture"].tap()
        XCTAssertTrue(app.staticTexts["Try typing"].waitForExistence(timeout:5))
        app.buttons["walkthrough-voice-toggle"].tap()
        XCTAssertTrue(app.buttons["walkthrough-voice-replay"].exists)
        app.buttons["walkthrough-voice-replay"].tap()
        expectation(for:audible,evaluatedWith:activity);waitForExpectations(timeout:8)
        #if !targetEnvironment(simulator)
        app.buttons["Speak"].tap()
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout:8))
        XCTAssertTrue(app.buttons["walkthrough-voice-toggle"].label.contains("Read aloud"))
        XCTAssertFalse(app.buttons["walkthrough-voice-replay"].exists)
        app.buttons["Stop"].tap()
        app.buttons["walkthrough-voice-toggle"].tap()
        XCTAssertTrue(app.buttons["walkthrough-voice-replay"].waitForExistence(timeout:5))
        #endif
        app.buttons["walkthrough-exit"].tap()
        XCTAssertTrue(app.navigationBars["Your guide"].waitForExistence(timeout:5))
        XCTAssertFalse(app.otherElements["tutorial-voice-activity"].exists)
    }
    func testPullToRefreshReloadsTheWorkspace(){
        XCTAssertFalse(app.staticTexts["workspace-refreshed"].exists)
        let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.25))
        let end=app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.78))
        start.press(forDuration:0.1,thenDragTo:end)
        XCTAssertTrue(app.staticTexts["workspace-refreshed"].waitForExistence(timeout:5))
        snapshot("Today confirms a real completed refresh")
    }
    func testWorkspaceHeadersMatchTheirDestinations(){
        app.tabBars.buttons["Spaces"].tap();app.buttons["Chapters"].tap()
        XCTAssertTrue(app.otherElements["workspace-header-moshia"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Your story, taking shape."].exists)
        snapshot("Moshia workspace header and continuity entry")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["space-ejj"].tap()
        XCTAssertTrue(app.otherElements["workspace-header-ejj"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Keep good work moving."].exists)
        app.buttons["module-picker"].tap();app.buttons["Websites"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Add website"].exists)
        snapshot("EJJ workspace identity and module selector")
    }
    func testHandsOnTutorialsAdvanceWithRealActionsAndKeepYourData(){
        snapshot("Warm welcoming Today screen")
        app.buttons["Settings and backup"].tap()
        let guide=app.buttons["settings-tutorial"]
        for _ in 0..<6 {if guide.isHittable{break};app.swipeUp()}
        XCTAssertTrue(guide.isHittable);guide.tap()
        XCTAssertTrue(app.staticTexts["Learn by doing."].waitForExistence(timeout:5))
        let spoken=app.switches["tutorial-spoken-guide"];if spoken.value as? String == "1"{spoken.tap()}
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
    func testInstalledContextAndWorkspaceBackgroundsReadOnly() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Private installed context is verified on the paired phone; no device credential is copied into CI.")
        #endif
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
    func testMemoRecorderAndComposerModes() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Live on-device speech recognition is verified on the paired iPhone; simulator speech assets and microphone support vary.")
        #endif
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-all"].tap()
        XCTAssertTrue(app.buttons["assistant-voice"].exists);XCTAssertFalse(app.buttons["assistant-send"].exists)
        let input=app.descendants(matching:.any).matching(identifier:"assistant-question").firstMatch
        input.tap();input.typeText("Keep my draft")
        XCTAssertTrue(app.buttons["assistant-send"].exists)
        app.buttons["assistant-memo"].tap()
        XCTAssertTrue(app.buttons["dictation-stop"].waitForExistence(timeout:8))
        XCTAssertTrue(app.buttons["dictation-send"].exists)
        XCTAssertFalse(app.navigationBars["Voice memo"].exists)
        Thread.sleep(forTimeInterval:1.5);snapshot("Inline recording bar with stop and transcribe-send controls")
        app.buttons["dictation-stop"].tap()
        XCTAssertTrue(app.buttons["assistant-memo"].waitForExistence(timeout:6))
        XCTAssertTrue((input.value as? String)?.contains("Keep my draft") == true)
        XCTAssertFalse(app.staticTexts["Everyday Bot"].exists)
        app.buttons["assistant-memo"].tap()
        XCTAssertTrue(app.buttons["dictation-cancel"].waitForExistence(timeout:8));app.buttons["dictation-cancel"].tap()
        XCTAssertTrue(app.buttons["assistant-memo"].waitForExistence(timeout:5))
        XCTAssertTrue((input.value as? String)?.contains("Keep my draft") == true)
    }
    func testImmersiveVoiceSettings(){
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-ejj"].tap()
        snapshot("EJJ Digital with a quiet steel accent")
        app.buttons["assistant-voice"].tap()
        XCTAssertTrue(app.staticTexts["EJJ Digital Bot"].waitForExistence(timeout:5))
        XCTAssertTrue(app.otherElements["voice-activity"].exists)
        snapshot("Immersive audio-reactive voice conversation")
        app.buttons["voice-settings"].tap()
        XCTAssertTrue(app.navigationBars["Voice settings"].waitForExistence(timeout:5))
        app.buttons["voice-choice"].tap()
        app.buttons["Puck · Upbeat"].tap()
        snapshot("Natural voice choices and output settings")
        app.buttons["voice-settings-done"].tap()
        XCTAssertTrue(app.staticTexts["Puck · Natural voice"].exists)
        app.buttons["voice-settings"].tap();app.buttons["voice-choice"].tap();app.buttons["Aoede · Relaxed"].tap();app.buttons["voice-settings-done"].tap()
        app.buttons["voice-done"].tap()
    }
    func testConnectedNaturalVoiceReadOnly() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Connected cloud voice uses the paired device credential.")
        #endif
        app.terminate();app.launchArguments=[];app.launchEnvironment=[:];app.launch()
        snapshot("Installed home with visible contour background")
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-all"].tap()
        app.buttons["assistant-voice"].tap()
        XCTAssertTrue(app.buttons["voice-read-reply"].waitForExistence(timeout:5))
        app.buttons["voice-read-reply"].tap()
        let voice=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Natural voice · ")).firstMatch
        XCTAssertTrue(voice.waitForExistence(timeout:18))
        XCTAssertTrue(app.staticTexts["Your assistant is speaking"].exists)
        let activity=app.otherElements["voice-activity"]
        let audible=NSPredicate(format:"value MATCHES %@","Audio level [1-9][0-9]*")
        expectation(for:audible,evaluatedWith:activity);waitForExpectations(timeout:5)
        snapshot("Natural speech with a measured audio signal and output route")
        app.buttons["voice-done"].tap()
    }
    func testRejectedCloudVoiceFallsBackToAudibleDeviceSpeech(){
        app.terminate();app.launchArguments.append("-test-voice-fallback");app.launch()
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-all"].tap()
        app.buttons["assistant-voice"].tap();app.buttons["voice-read-reply"].tap()
        XCTAssertTrue(app.staticTexts["Device voice · keeping the conversation going"].waitForExistence(timeout:10))
        let audible=NSPredicate(format:"value MATCHES %@","Audio level [1-9][0-9]*")
        expectation(for:audible,evaluatedWith:app.otherElements["voice-activity"]);waitForExpectations(timeout:8)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format:"label CONTAINS[c] %@","unavailable")).firstMatch.exists)
        snapshot("Cloud voice rejection continues with measured device audio")
        app.buttons["voice-done"].tap()
    }
    func testAssistantAttachmentPickersAndSpokenReply(){
        snapshot("Refined iOS home with contour background")
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-all"].tap()
        app.buttons["assistant-attach"].tap();app.buttons["Choose a file"].tap()
        let dismissPicker=app.descendants(matching:.any).matching(NSPredicate(format:"label IN %@",["Cancel","Close"])).firstMatch;XCTAssertTrue(dismissPicker.waitForExistence(timeout:10));dismissPicker.tap()
        app.buttons["assistant-attach"].tap();app.buttons["Photo or video"].tap()
        XCTAssertTrue(dismissPicker.waitForExistence(timeout:10));dismissPicker.tap()
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
        XCTAssertGreaterThanOrEqual(cards.count,2)
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
