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
    func testSongSuggestionsCreateReviewedRehearsal(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-call-results"];app.launch()
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-band"].tap()
        let add=app.buttons["assistant-add-rehearsal"];for _ in 0..<8{if add.isHittable{break};app.swipeUp()};XCTAssertTrue(add.isHittable);add.tap()
        app.buttons["rehearsal-review"].tap();XCTAssertTrue(app.buttons["record-save"].waitForExistence(timeout:5));snapshot("Song suggestions reviewed in rehearsal draft");app.buttons["record-save"].tap()
        app.navigationBars.buttons["BackButton"].tap();app.tabBars.buttons["Search"].tap();app.textFields["search-query"].tap();app.textFields["search-query"].typeText("Next rehearsal\n");XCTAssertTrue(app.staticTexts["Next rehearsal"].waitForExistence(timeout:5));app.staticTexts["Next rehearsal"].tap();app.swipeUp();XCTAssertTrue(app.textFields.containing(NSPredicate(format:"value CONTAINS %@","Everlong")).firstMatch.exists)
    }
    func testCapturedIdeaWithoutBodyAppearsInAINotes(){
        app.tabBars.buttons["Capture"].tap()
        let input=app.descendants(matching:.any)["capture-text"];XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText("A quiet guitar idea")
        let save=app.buttons["capture-save-primary"];XCTAssertTrue(save.isHittable);save.tap()
        app.tabBars.buttons["Assistant"].tap();app.segmentedControls["assistant-section"].buttons["AI notes"].tap()
        XCTAssertTrue(app.staticTexts["A quiet guitar idea"].waitForExistence(timeout:5));XCTAssertTrue(app.buttons["ai-notes-capture"].exists)
        snapshot("Title-only captured ideas now appear in AI Notes with space filters")
        app.staticTexts["A quiet guitar idea"].tap();XCTAssertTrue(app.buttons["record-ai-run"].waitForExistence(timeout:5))
    }
    func testNotesFilterFitsWithCoach(){
        app.buttons["Settings and backup"].tap();let guide=app.buttons["settings-tutorial"];for _ in 0..<8{if guide.isHittable{break};app.swipeUp()};guide.tap();let spoken=app.switches["tutorial-spoken-guide"];if spoken.value as? String == "1"{spoken.tap()};let lesson=app.buttons["tutorial-start-notes"];for _ in 0..<15{if lesson.isHittable{break};app.swipeUp()};lesson.tap();app.buttons["walkthrough-lesson-continue"].tap();app.tabBars.buttons["Assistant"].tap();app.segmentedControls["assistant-section"].buttons["AI notes"].tap()
        let filter=app.buttons["ai-notes-space"];for _ in 0..<5{if filter.frame.maxY<app.frame.height-110{break};app.swipeUp()}
        snapshot("Notes controls with consistent margins above the tab bar")
        for position in [0.25,0.5,0.85]{filter.coordinate(withNormalizedOffset:CGVector(dx:position,dy:0.5)).tap();XCTAssertTrue(app.buttons["CLEARANCE 19"].waitForExistence(timeout:5));app.buttons["ai-notes-filter-all"].tap()}
        filter.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap();app.buttons["CLEARANCE 19"].tap();XCTAssertTrue(app.staticTexts["Find the thought"].waitForExistence(timeout:5));snapshot("Workspace filter opens across its full width")

    }
    func testDistinctNotesDownloadAndGymPractice(){
        func enter(_ kind:String){
            app.terminate();app.launchArguments=["-ui-testing","-reset-test-data"];app.launch();app.buttons["Settings and backup"].tap();let guide=app.buttons["settings-tutorial"];for _ in 0..<8{if guide.isHittable{break};app.swipeUp()};guide.tap()
            let spoken=app.switches["tutorial-spoken-guide"];if spoken.value as? String == "1"{spoken.tap()}
            let lesson=app.buttons["tutorial-start-"+kind];for _ in 0..<15{if lesson.isHittable{break};app.swipeUp()};XCTAssertTrue(lesson.isHittable);lesson.tap();XCTAssertTrue(app.buttons["walkthrough-lesson-continue"].waitForExistence(timeout:5));app.buttons["walkthrough-lesson-continue"].tap()
        }
        enter("notes");app.tabBars.buttons["Assistant"].tap();app.segmentedControls["assistant-section"].buttons["AI notes"].tap();let filter=app.buttons["ai-notes-space"];for _ in 0..<5{if filter.frame.maxY<app.frame.height-110{break};app.swipeUp()};snapshot("Notes filter positioned above the tab bar");filter.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap();app.buttons["CLEARANCE 19"].tap();app.textFields["ai-notes-search"].tap();app.textFields["ai-notes-search"].typeText("guitar\n");app.staticTexts["A guitar idea"].tap();XCTAssertTrue(app.buttons["record-ai-run"].waitForExistence(timeout:5));XCTAssertTrue(app.buttons["walkthrough-done"].exists);snapshot("Dedicated notes practice filters and opens a title-only thought")
        enter("downloads");app.tabBars.buttons["Spaces"].tap();let chapters=app.buttons["Chapters"];for _ in 0..<8{if chapters.isHittable{break};app.swipeUp()};chapters.tap();XCTAssertTrue(app.buttons["full-book-open"].waitForExistence(timeout:5));app.buttons["full-book-open"].tap();app.buttons["Book contents"].tap();let download=app.buttons["book-audiobook-prepare"];for _ in 0..<6{if download.isHittable{break};app.swipeUp()};XCTAssertTrue(download.isEnabled);download.tap();let pause=app.buttons["book-download-pause"];XCTAssertTrue(pause.waitForExistence(timeout:5));pause.tap();XCTAssertTrue(app.staticTexts["Keep your progress"].waitForExistence(timeout:5));download.tap();let play=app.buttons["book-audiobook-start"];expectation(for:NSPredicate(format:"enabled == true"),evaluatedWith:play);waitForExpectations(timeout:40);play.tap();XCTAssertTrue(app.sliders["book-listening-seek"].waitForExistence(timeout:5));snapshot("Dedicated download practice reaches the local audio player")
        enter("gym");app.tabBars.buttons["Spaces"].tap();let gym=app.buttons["space-gym"];for _ in 0..<12{if gym.isHittable{break};app.swipeUp()};gym.tap();XCTAssertTrue(app.buttons["gym-weekday-1"].waitForExistence(timeout:5));app.buttons["gym-weekday-1"].tap();let start=app.buttons["gym-start-1"];for _ in 0..<5{if start.isHittable{break};app.swipeUp()};start.tap();let mark=app.buttons["Complete set 1"].firstMatch;for _ in 0..<8{if mark.isHittable{break};app.swipeUp()};XCTAssertTrue(mark.isHittable);let weight=app.textFields["Set 1 weight"].firstMatch;weight.tap();weight.typeText("20");let reps=app.textFields["Set 1 reps"].firstMatch;reps.tap();reps.typeText("10");mark.tap();XCTAssertTrue(app.staticTexts["Save the session"].waitForExistence(timeout:5));app.buttons["gym-finish"].tap();XCTAssertTrue(app.staticTexts["One session stronger."].waitForExistence(timeout:5));snapshot("Gym guide uses actual workout and summary screens")
    }
    func testGuideKeepsEssentialsFirstAndAdditionsHavePractice(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-settings"];app.launch();app.buttons["settings-tutorial"].tap()
        let capture=app.buttons["tutorial-start-capture"];XCTAssertTrue(capture.waitForExistence(timeout:5));XCTAssertTrue(capture.isHittable);XCTAssertFalse(app.buttons["tutorial-ai-lab"].isHittable)
        snapshot("Stable guide starts with Capture and the essentials")
        let additions=app.buttons["tutorial-new-additions"];for _ in 0..<12{if additions.isHittable{break};app.swipeUp()};additions.tap()
        let notes=app.buttons["new-notes-lab"];for _ in 0..<5{if notes.isHittable{break};app.swipeUp()};XCTAssertTrue(notes.isHittable);notes.tap()
        XCTAssertTrue(app.buttons["record-ai-tool-polish"].waitForExistence(timeout:5));XCTAssertTrue(app.buttons["record-ai-tool-review"].exists)
        snapshot("New additions opens the existing hands-on notes practice")
    }
    func testAssistantNotesOpensSelectedRecordTools(){
        capture("Notes easy to find")
        app.tabBars.buttons["Search"].tap();app.textFields["search-query"].tap();app.textFields["search-query"].typeText("Notes easy to find\n");app.staticTexts["Notes easy to find"].tap();let context=app.descendants(matching:.any).matching(identifier:"record-context").firstMatch;context.tap();context.typeText("Try a quieter intro at rehearsal.");app.buttons["record-save"].tap()
        app.tabBars.buttons["Assistant"].tap();app.segmentedControls["assistant-section"].buttons["AI notes"].tap();XCTAssertTrue(app.staticTexts["Notes easy to find"].waitForExistence(timeout:5));app.staticTexts["Notes easy to find"].tap();XCTAssertTrue(app.buttons["record-ai-run"].waitForExistence(timeout:5));XCTAssertTrue(app.buttons["record-ai-tool-summary"].exists);snapshot("Assistant AI notes opens selected record tools")
    }
    func testReadingAndRehearsalTutorialsFinishWithRealControls(){
        app.buttons["Settings and backup"].tap();let guide=app.buttons["settings-tutorial"];for _ in 0..<7{if guide.isHittable{break};app.swipeUp()};guide.tap();let spoken=app.switches["tutorial-spoken-guide"];if spoken.value as? String == "1"{spoken.tap()}
        func start(_ id:String){let lesson=app.buttons["tutorial-start-"+id];for _ in 0..<10{if lesson.isHittable{break};app.swipeUp()};XCTAssertTrue(lesson.isHittable);lesson.tap();app.buttons["walkthrough-lesson-continue"].tap()}
        start("reader");app.tabBars.buttons["Spaces"].tap();let chapters=app.buttons["Chapters"];for _ in 0..<6{if chapters.isHittable{break};app.swipeUp()};chapters.tap();app.buttons["full-book-open"].tap();XCTAssertTrue(app.staticTexts["Turn a page"].waitForExistence(timeout:5));app.buttons["Next page"].tap();app.buttons["Book contents"].tap();app.buttons.containing(.staticText,identifier:"The rehearsal room").firstMatch.tap();app.buttons["Book contents"].tap();app.buttons["Done"].tap();XCTAssertTrue(app.buttons["walkthrough-done"].waitForExistence(timeout:5));snapshot("Reading lesson completed with sample chapters");app.buttons["walkthrough-done"].tap()
        start("rehearsal");app.tabBars.buttons["Spaces"].tap();let songs=app.buttons["Songs"];for _ in 0..<6{if songs.isHittable{break};app.swipeUp()};songs.tap();let rehearsal=app.buttons["Rehearsal mode"];for _ in 0..<8{if rehearsal.isHittable{break};app.swipeUp()};XCTAssertTrue(rehearsal.isHittable);rehearsal.tap();XCTAssertTrue(app.staticTexts["Find a comfortable pace"].waitForExistence(timeout:5));app.buttons["Increase tempo"].tap();app.buttons["Start metronome"].tap();XCTAssertTrue(app.staticTexts["Leave room for the music"].waitForExistence(timeout:5));app.buttons["Stop metronome"].tap();XCTAssertTrue(app.buttons["walkthrough-done"].waitForExistence(timeout:5));snapshot("Rehearsal lesson completed inside the real rehearsal view");app.buttons["walkthrough-done"].tap()
    }
    func testImportedManuscriptIsCleanWithoutExposingProse() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("The private manuscript is only bundled in the owner's signed device build.")
        #endif
        app.terminate();app.launchArguments=["-test-manuscript-clean"];app.launchEnvironment=[:];app.launch()
        let status=app.staticTexts["manuscript-clean-status"];XCTAssertTrue(status.waitForExistence(timeout:10));XCTAssertEqual(status.label,"Original sections: 15; Clean: true");snapshot("Private manuscript verification shows counts only")
    }
    func testAINotesWorkshopExploresToolsAndAppliesOnlyToPractice(){
        capture("Keep my actual note")
        app.tabBars.buttons["Today"].tap()
        app.buttons["Settings and backup"].tap();let guide=app.buttons["settings-tutorial"];for _ in 0..<8{if guide.isHittable{break};app.swipeUp()};guide.tap()
        let lab=app.buttons["tutorial-ai-lab"];for _ in 0..<5{if lab.isHittable{break};app.swipeUp()};lab.tap()
        for tool in ["polish","summary","plan","review"]{
            let choice=app.buttons["record-ai-tool-"+tool];XCTAssertTrue(choice.waitForExistence(timeout:5));choice.tap();app.buttons["record-ai-run"].tap();XCTAssertTrue(app.staticTexts["record-ai-result"].waitForExistence(timeout:5))
        }
        let answer=app.textFields["record-ai-answer"].firstMatch;for _ in 0..<5{if answer.isHittable{break};app.swipeUp()};XCTAssertTrue(answer.isHittable);answer.tap();answer.typeText("Math homework first");let clarify=app.buttons["record-ai-clarify-answers"];for _ in 0..<5{if clarify.isHittable{break};app.swipeUp()};clarify.tap();for _ in 0..<4{if app.buttons["record-ai-apply"].isHittable{break};app.swipeUp()};snapshot("AI notes lab clarifies practice answers before applying");app.buttons["record-ai-apply"].tap();XCTAssertTrue(app.buttons["ai-lab-done"].waitForExistence(timeout:5));snapshot("AI notes lab reward keeps real work separate");app.buttons["ai-lab-done"].tap();app.navigationBars.buttons["BackButton"].tap()
        app.tabBars.buttons["Search"].tap();app.textFields["search-query"].tap();app.textFields["search-query"].typeText("Keep my actual note\n");XCTAssertTrue(app.staticTexts["Keep my actual note"].waitForExistence(timeout:5))
    }
    func testConnectedRecordPolishCanBeReviewedAppliedAndRestored() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Connected polish needs the private iPhone credential, which is excluded from CI.")
        #endif
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-connected-assistant"];app.launch()
        capture("Reviewable AI note")
        app.tabBars.buttons["Search"].tap();app.textFields["search-query"].tap();app.textFields["search-query"].typeText("Reviewable AI note\n")
        app.staticTexts["Reviewable AI note"].tap();let context=app.descendants(matching:.any).matching(identifier:"record-context").firstMatch;let original="Uh, I might record a guitar idea only if homework is finished. Friday is not confirmed yet.";context.tap();context.typeText(original)
        app.swipeUp();let ai=app.buttons["record-ai-open"];XCTAssertTrue(ai.waitForExistence(timeout:5));ai.tap();app.buttons["record-ai-run"].tap();let result=app.staticTexts["record-ai-result"];XCTAssertTrue(result.waitForExistence(timeout:90));XCTAssertTrue(result.label.localizedCaseInsensitiveContains("homework"));XCTAssertTrue(result.label.localizedCaseInsensitiveContains("Friday"))
        for _ in 0..<4{if app.buttons["record-ai-apply"].isHittable{break};app.swipeUp()};app.buttons["record-ai-apply"].tap();let restore=app.buttons["record-ai-restore"];XCTAssertTrue(restore.waitForExistence(timeout:5));restore.tap();XCTAssertEqual(context.value as? String,original);app.buttons["record-save"].tap()
    }
    func testCallIgnoresUnrequestedCards(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-call-results","-test-no-results"];app.launch()
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-band"].tap();app.buttons["assistant-voice"].tap()
        XCTAssertTrue(app.buttons["voice-done"].waitForExistence(timeout:5));XCTAssertFalse(app.staticTexts["Friday practice ideas"].isHittable);XCTAssertFalse(app.scrollViews["voice-results"].exists)
        snapshot("Call remains in voice view when a result was not requested");app.buttons["voice-done"].tap()
    }
    func testReaderTurnsByTapAndSwipeAndKeepsChapterStarts(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-reader-display"];app.launch()
        let first=app.descendants(matching:.any).matching(identifier:"book-page-0").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout:10))
        snapshot("Warm e-reader chapter opening with demonstration text")
        app.coordinate(withNormalizedOffset:CGVector(dx:0.94,dy:0.5)).tap()
        XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"book-page-1").firstMatch.waitForExistence(timeout:5))
        app.swipeLeft();XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"book-page-2").firstMatch.waitForExistence(timeout:5))
        app.buttons["Book contents"].tap();app.buttons.containing(.staticText,identifier:"Practice chapter 2").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Practice chapter 2"].waitForExistence(timeout:5));snapshot("Reader contents starts a new chapter on its own page")
    }
    func testBookContentsIncludesAudiobook(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-reader-display"];app.launch()
        app.buttons["Book contents"].tap()
        let listen=app.buttons["book-audiobook-start"]
        for _ in 0..<6{if listen.isHittable{break};app.swipeUp()}
        XCTAssertTrue(listen.isHittable)
        XCTAssertTrue(app.buttons["book-audiobook-current"].exists)
        snapshot("Audiobook choices sit at the end of book contents")
    }
    func testGuideNewAdditionsAndNativeMusicTools(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-settings"];app.launch()
        let guide=app.buttons["settings-tutorial"];XCTAssertTrue(guide.waitForExistence(timeout:5));XCTAssertTrue(guide.isHittable);guide.tap()
        let additions=app.buttons["tutorial-new-additions"];for _ in 0..<12{if additions.isHittable{break};app.swipeUp()};XCTAssertTrue(additions.isHittable);additions.tap()
        let music=app.buttons["new-music-tools"];XCTAssertTrue(music.waitForExistence(timeout:5));for _ in 0..<5{if music.isHittable{break};app.swipeUp()};music.tap();XCTAssertTrue(app.descendants(matching:.any)["music-tab-grid"].waitForExistence(timeout:5));snapshot("Native original tab grid and visual follow-along controls")
        app.swipeUp();XCTAssertTrue(app.descendants(matching:.any)["music-chord-diagrams"].exists);snapshot("Drawn guitar chord shapes with open and muted strings")
    }
    func testFiveDayPlanAndTenStepGuide(){
        app.tabBars.buttons["Spaces"].firstMatch.tap();let gym=app.buttons["space-gym"]
        for _ in 0..<7{if gym.isHittable{break};app.swipeUp()};gym.tap()
        let titles=["Day 1 · Chest","Day 2 · Back","Day 3 · Legs","Day 4 · Back & chest","Day 5 · Arms"]
        let counts=[6,6,5,5,8]
        let weekdays=[0,1,3,4,5]
        for index in 0..<5 {
            let weekday=app.buttons["gym-weekday-\(weekdays[index])"]
            for _ in 0..<4{if weekday.isHittable{break};app.swipeDown()};weekday.tap()
            XCTAssertTrue(app.staticTexts[titles[index]].waitForExistence(timeout:5))
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label BEGINSWITH %@","\(counts[index]) exercises")).firstMatch.exists)
        }
        snapshot("Corrected fifth training day with eight arm exercises")
        for index in [2,6]{let button=app.buttons["gym-weekday-\(index)"];button.tap();XCTAssertTrue(app.staticTexts["Recovery day · or add your own exercises"].waitForExistence(timeout:5))}
        app.buttons["gym-weekday-0"].tap()
        app.buttons["gym-settings"].tap();XCTAssertTrue(app.buttons["gym-tutorial-start"].waitForExistence(timeout:5));app.buttons["gym-tutorial-start"].tap()
        XCTAssertTrue(app.buttons["walkthrough-lesson-continue"].waitForExistence(timeout:5));app.buttons["walkthrough-lesson-continue"].tap();app.tabBars.buttons["Spaces"].firstMatch.tap();let practiceGym=app.buttons["space-gym"].firstMatch;for _ in 0..<8{if practiceGym.isHittable{break};app.swipeUp()};practiceGym.tap();XCTAssertTrue(app.buttons["gym-weekday-1"].waitForExistence(timeout:5));snapshot("Gym tutorial locates real workout controls in a separate practice app");app.buttons["walkthrough-exit"].tap()
        XCTAssertTrue(app.buttons["gym-tutorial-start"].waitForExistence(timeout:5))
    }
    func testGymDemonstrationOpensRealVideo(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-gym-video"];app.launch()
        XCTAssertTrue(app.descendants(matching:.any)["gym-video-player"].waitForExistence(timeout:35));XCTAssertTrue(app.staticTexts["gym-video-playing"].waitForExistence(timeout:35));snapshot("Matching pec-deck movement opens in the native video player")
    }
    func testGymPlanWorkoutAndPersistence(){
        app.tabBars.buttons["Assistant"].tap();XCTAssertFalse(app.buttons["assistant-workspace-gym"].exists)
        app.tabBars.buttons["Spaces"].tap();let gym=app.buttons["space-gym"];for _ in 0..<7{if gym.isHittable{break};app.swipeUp()};XCTAssertTrue(gym.isHittable);gym.tap()
        XCTAssertTrue(app.staticTexts["Build a little stronger."].waitForExistence(timeout:5));snapshot("Gym weekly plan using Ediz's five training days")
        app.buttons["gym-start-0"].tap();let exercise=app.buttons["gym-exercise-0"];XCTAssertTrue(exercise.waitForExistence(timeout:5))
        let weight=app.textFields["Set 1 weight"];for _ in 0..<4{if weight.isHittable{break};app.swipeUp()};weight.tap();weight.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:4)+"40")
        let reps=app.textFields["Set 1 reps"];reps.tap();reps.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:4)+"10");app.swipeDown()
        let complete=app.buttons["Complete set 1"];for _ in 0..<4{if complete.isHittable{break};app.swipeUp()};complete.tap();snapshot("Expandable workout sets and rest timer")
        app.terminate();app.launchArguments=["-ui-testing"];app.launch();app.tabBars.buttons["Spaces"].tap();let restored=app.buttons["space-gym"];for _ in 0..<7{if restored.isHittable{break};app.swipeUp()};restored.tap()
        XCTAssertTrue(app.staticTexts["400 kg"].waitForExistence(timeout:5));app.buttons["gym-finish"].tap();XCTAssertTrue(app.staticTexts["One session stronger."].waitForExistence(timeout:5));snapshot("Finished workout saved with elapsed time and completed volume");app.buttons["Done"].tap();app.buttons["History"].tap();XCTAssertTrue(app.staticTexts["400 kg"].waitForExistence(timeout:5))
    }
    func testGymLibraryAddsExerciseBelowTheDay(){
        app.tabBars.buttons["Spaces"].tap();let gym=app.buttons["space-gym"];for _ in 0..<7{if gym.isHittable{break};app.swipeUp()};gym.tap()
        let add=app.buttons["gym-add-day-0"];for _ in 0..<4{if add.isHittable{break};app.swipeUp()};XCTAssertTrue(add.waitForExistence(timeout:5));add.tap()
        let search=app.searchFields.firstMatch;XCTAssertTrue(search.waitForExistence(timeout:5));search.tap();search.typeText("incline dumbbell curl");XCTAssertTrue(app.buttons["gym-ai-search"].waitForExistence(timeout:5));snapshot("Exercise library searches the full catalogue from a day's Add exercise button")
        let result=app.buttons.containing(NSPredicate(format:"label CONTAINS[c] %@","incline dumbbell curl")).firstMatch;XCTAssertTrue(result.waitForExistence(timeout:5));result.tap();let save=app.buttons["gym-add-exercise"];for _ in 0..<6{if save.isHittable{break};app.swipeUp()};XCTAssertTrue(save.isHittable);save.tap();XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label BEGINSWITH %@","7 exercises")).firstMatch.waitForExistence(timeout:5));snapshot("Exercise added to the selected day without starting a workout")
    }
    func testReviewedGymChangeSavesPlan(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-gym-change"];app.launch()
        let apply=app.buttons["gym-apply-change"];XCTAssertTrue(apply.waitForExistence(timeout:5));apply.tap();XCTAssertTrue(app.buttons["Changes saved"].waitForExistence(timeout:5));snapshot("Reviewed Gym Bot change saves four sets and two-minute rest")
        app.terminate();app.launchArguments=["-ui-testing"];app.launch();app.tabBars.buttons["Spaces"].tap();let gym=app.buttons["space-gym"];for _ in 0..<7{if gym.isHittable{break};app.swipeUp()};gym.tap();app.buttons["gym-edit-day-0"].tap();XCTAssertTrue(app.steppers["4 sets"].waitForExistence(timeout:5));XCTAssertTrue(app.steppers["Rest 120 seconds"].exists)
    }
    func testGymRemoveExercisePersistsAndTutorialOpens(){
        app.tabBars.buttons["Spaces"].tap();let gym=app.buttons["space-gym"];for _ in 0..<7{if gym.isHittable{break};app.swipeUp()};gym.tap();snapshot("Weekday selector focuses the plan on one workout")
        app.buttons["gym-edit-day-0"].tap()
        let down=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","gym-move-down-")).firstMatch
        for _ in 0..<5{if down.isHittable{break};app.swipeUp()};XCTAssertTrue(down.isHittable);down.tap()
        let headings=app.staticTexts["Lever chest press"]
        XCTAssertTrue(headings.exists);snapshot("Visible exercise reorder buttons and move-to-day menu")
        let remove=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","gym-remove-")).firstMatch
        for _ in 0..<5{if remove.isHittable{break};app.swipeUp()};XCTAssertTrue(remove.isHittable);snapshot("Workout editor with stable exercise sections and visible removal");remove.tap();app.buttons["Remove from this day"].tap();app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label BEGINSWITH %@","5 exercises")).firstMatch.waitForExistence(timeout:5))
        app.terminate();app.launchArguments=["-ui-testing"];app.launch();app.tabBars.buttons["Spaces"].tap();let restored=app.buttons["space-gym"];for _ in 0..<7{if restored.isHittable{break};app.swipeUp()};restored.tap();XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label BEGINSWITH %@","5 exercises")).firstMatch.waitForExistence(timeout:5))
        app.buttons["gym-settings"].tap();XCTAssertTrue(app.buttons["gym-tutorial-start"].waitForExistence(timeout:5));app.buttons["gym-tutorial-start"].tap();XCTAssertTrue(app.buttons["walkthrough-lesson-continue"].waitForExistence(timeout:5));snapshot("Actual Gym tutorial with voice-reactive coach and separate practice screens")
    }
    func testRichReplyDisplaysHeadingsAndAlignedGuitarTab(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-rich-reply"];app.launch()
        XCTAssertTrue(app.staticTexts["Rhythm and timing"].waitForExistence(timeout:5));XCTAssertFalse(app.staticTexts["### Rhythm and timing"].exists);XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@","e|----------------|")).firstMatch.exists);snapshot("Readable headings emphasis symbols and guitar tablature")
    }
    func testJoinedOfflineBookRecordingHasWorkingTimeline(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-reader-joined"];app.launch();app.buttons["Book contents"].tap()
        let play=app.buttons["book-audiobook-start"]
        for _ in 0..<7{if play.isHittable{break};app.swipeUp()}
        expectation(for:NSPredicate(format:"enabled == true"),evaluatedWith:play);waitForExpectations(timeout:30);play.tap()
        let timeline=app.sliders["book-listening-seek"];XCTAssertTrue(timeline.waitForExistence(timeout:10))
        app.buttons["Pause audiobook"].tap();timeline.adjust(toNormalizedSliderPosition:0.75)
        XCTAssertTrue(app.staticTexts["Joined Practice chapter 2"].exists);XCTAssertTrue(app.staticTexts["Paused"].exists)
        snapshot("Joined offline book preserves pause across chapter seeking")
    }
    func testDownloadedBookPlaysOfflineWithTotalLength() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("This test downloads natural audio using the paired device connection.")
        #endif
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-reader-audio","-test-connected-assistant","-reset-test-audio"];app.launch()
        app.buttons["Book contents"].tap()
        let download=app.buttons["book-audiobook-prepare"]
        for _ in 0..<7{if download.isHittable{break};app.swipeUp()}
        XCTAssertTrue(download.isEnabled);download.tap()
        let pause=app.buttons["book-download-pause"];XCTAssertTrue(pause.waitForExistence(timeout:10));pause.tap()
        XCTAssertTrue(app.staticTexts["Paused · your completed audio is kept"].waitForExistence(timeout:5));XCTAssertTrue(download.isEnabled);download.tap()
        let play=app.buttons["book-audiobook-start"]
        let ready=NSPredicate(format:"enabled == true")
        expectation(for:ready,evaluatedWith:play);waitForExpectations(timeout:240)
        snapshot("Downloaded audiobook ready for local playback")
        // Reopen without access to the assistant credential. Any cloud request would fail.
        app.terminate();app.launchArguments=["-ui-testing","-test-reader-audio"];app.launch();app.buttons["Book contents"].tap()
        for _ in 0..<7{if app.buttons["book-audiobook-start"].isHittable{break};app.swipeUp()}
        XCTAssertTrue(app.buttons["book-audiobook-start"].isEnabled);app.buttons["book-audiobook-start"].tap()
        XCTAssertTrue(app.sliders["book-listening-seek"].waitForExistence(timeout:10))
        XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"book-listening-duration").firstMatch.exists)
        app.buttons["Pause audiobook"].tap();XCTAssertTrue(app.staticTexts["Paused"].exists)
        app.sliders["book-listening-seek"].adjust(toNormalizedSliderPosition:0.7)
        XCTAssertTrue(app.staticTexts["Practice chapter 2"].exists)
        snapshot("Offline full-book player with duration and seek controls")
    }
    func testNaturalAudiobookPlaysSampleOnDevice() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Natural audiobook signal needs the connected iPhone credential.")
        #endif
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-reader-audio","-test-connected-assistant"];app.launch()
        app.buttons["Book contents"].tap()
        let listen=app.buttons["book-audiobook-start"]
        for _ in 0..<6{if listen.isHittable{break};app.swipeUp()}
        XCTAssertTrue(listen.isEnabled);listen.tap()
        XCTAssertTrue(app.staticTexts["MOSHIA AUDIOBOOK"].waitForExistence(timeout:5))
        snapshot("Listening screen immediately after starting a sample chapter")
        let pause=app.buttons["Pause audiobook"]
        if pause.exists {pause.tap();XCTAssertTrue(app.staticTexts["Paused"].waitForExistence(timeout:5));app.buttons["Play audiobook"].tap()}
        else {XCTAssertTrue(app.buttons["Replay audiobook"].waitForExistence(timeout:5))}
        let speed=app.buttons["Audiobook speed"];speed.tap();XCTAssertEqual(speed.value as? String,"1.25×")
        let voices=app.buttons.matching(NSPredicate(format:"label == %@","Narrator voice"));let voice=voices.element(boundBy:voices.count-1);voice.tap();XCTAssertEqual(voice.value as? String,"Puck")
        snapshot("Natural audiobook playing invented sample chapter")
        app.buttons["Stop"].tap()
        XCTAssertFalse(app.staticTexts["MOSHIA AUDIOBOOK"].exists)
    }
    func testCaptureQuestionsClarifyAnInventedIdeaOnDevice() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Connected clarification needs the paired iPhone credential.")
        #endif
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-connected-assistant"];app.launch()
        app.tabBars.buttons["Capture"].tap()
        let input=app.descendants(matching:.any).matching(identifier:"capture-text").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText("Maybe I can record a guitar idea after homework, but I have not decided which part yet.")
        let clarify=app.buttons["capture-ai-questions"];for _ in 0..<5{if clarify.isHittable{break};app.swipeUp()};XCTAssertTrue(clarify.isHittable);clarify.tap()
        let answer=app.textFields["record-ai-answer"].firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout:90));answer.tap();answer.typeText("The quiet opening riff")
        let useAnswers=app.buttons["record-ai-clarify-answers"];for _ in 0..<5{if useAnswers.isHittable{break};app.swipeUp()};useAnswers.tap()
        let result=app.staticTexts["record-ai-result"]
        let containsMeaning=NSPredicate(format:"label CONTAINS[c] %@ AND label CONTAINS[c] %@","guitar","homework")
        expectation(for:containsMeaning,evaluatedWith:result);waitForExpectations(timeout:90)
        snapshot("Capture questions produce a reviewable clarified idea")
        let apply=app.buttons["record-ai-apply"];for _ in 0..<5{if apply.isHittable{break};app.swipeUp()};apply.tap()
        XCTAssertTrue(input.waitForExistence(timeout:5));XCTAssertTrue((input.value as? String ?? "").localizedCaseInsensitiveContains("guitar"))
    }
    func testCompleteRecordingRetainsBeginningAndEndAndReaderRetainsEveryCharacter() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("SpeechAnalyzer verification needs the paired iPhone.")
        #endif
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-complete-recording"];app.launch()
        let status=app.staticTexts["recording-diagnostic-result"]
        XCTAssertTrue(status.waitForExistence(timeout:10))
        let completed=NSPredicate(format:"label BEGINSWITH %@","Reader exact: yes; First: true; Last: true; Words:")
        expectation(for:completed,evaluatedWith:status);waitForExpectations(timeout:240)
        let count=Int(status.label.components(separatedBy:"Words: ").last ?? "") ?? 0
        XCTAssertGreaterThan(count,120)
        snapshot("Complete recording retains the beginning and end; reader pagination retains every character")
    }
    func testBookAndSongDiscoveryEntriesAreReachable(){
        app.tabBars.buttons["Spaces"].tap();app.buttons["space-moshia"].tap()
        let book=app.buttons["full-book-open"];XCTAssertTrue(book.waitForExistence(timeout:5));book.tap();XCTAssertTrue(app.navigationBars["Moshia · Full Book"].exists)
        app.navigationBars.buttons["BackButton"].tap();XCTAssertTrue(app.navigationBars["Moshia"].waitForExistence(timeout:5));app.navigationBars.buttons["BackButton"].tap();XCTAssertTrue(app.navigationBars["Spaces"].waitForExistence(timeout:5))
        app.buttons["space-band"].tap();let songs=app.buttons["known-songs-open"];XCTAssertTrue(songs.waitForExistence(timeout:5));songs.tap();XCTAssertTrue(app.navigationBars["Add known songs"].exists)
    }
    func testConnectedPersonalReplyReadsAloudInChat() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Connected natural voice needs the paired device credential.")
        #endif
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-connected-assistant"];app.launch()
        app.tabBars.buttons["Assistant"].tap();let workspace=app.buttons["assistant-workspace-personal"];for _ in 0..<3{if workspace.isHittable{break};app.swipeUp()};workspace.tap()
        let input=app.descendants(matching:.any).matching(identifier:"assistant-question").firstMatch;XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText("Hello. Please answer in one friendly sentence.");app.buttons["assistant-send"].tap()
        let read=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","reply-read-")).firstMatch
        XCTAssertTrue(read.waitForExistence(timeout:90));read.tap()
        let activity=app.otherElements["reply-voice-activity"]
        let audible=NSPredicate(format:"value MATCHES %@","Audio level [1-9][0-9]*")
        expectation(for:audible,evaluatedWith:activity);waitForExpectations(timeout:110)
        snapshot("Personal assistant replies and reads aloud with a measured natural-voice signal")
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
        let caution=app.staticTexts["POSSIBLE — canon only when you choose it."];for _ in 0..<4{if caution.exists{break};app.swipeUp()};XCTAssertTrue(caution.exists)
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
        app.buttons["System health"].tap();XCTAssertTrue(app.staticTexts["Database, SQLite · WAL"].waitForExistence(timeout:5));XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Version, 0.3.")).firstMatch.exists)
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
        if app.buttons["walkthrough-lesson-continue"].waitForExistence(timeout:3){app.buttons["walkthrough-lesson-continue"].tap()}
        XCTAssertTrue(app.staticTexts["Natural voice"].waitForExistence(timeout:20))
        let audible=NSPredicate(format:"value MATCHES %@","Audio level [1-9][0-9]*")
        expectation(for:audible,evaluatedWith:app.otherElements["tutorial-voice-activity"]);waitForExpectations(timeout:8)
        snapshot("Natural spoken chapter walkthrough in a safe practice workspace")
        app.buttons["walkthrough-voice-toggle"].tap();app.buttons["walkthrough-exit"].tap()
        XCTAssertTrue(app.navigationBars["Your guide"].waitForExistence(timeout:5))
    }
    func testTutorialNarrationSurvivesVoiceCapture(){
        app.swipeDown();app.buttons["Settings and backup"].tap()
        let guide=app.buttons["settings-tutorial"];for _ in 0..<12{if guide.isHittable{break};app.swipeUp()};guide.tap()
        let spoken=app.switches["tutorial-spoken-guide"];XCTAssertTrue(spoken.waitForExistence(timeout:5));if spoken.value as? String == "0"{spoken.tap()}
        app.buttons["tutorial-start-capture"].tap()
        if app.buttons["walkthrough-lesson-continue"].waitForExistence(timeout:3){app.buttons["walkthrough-lesson-continue"].tap()}
        XCTAssertTrue(app.buttons["walkthrough-voice-replay"].waitForExistence(timeout:5))
        app.tabBars.buttons["Capture"].tap();app.buttons["Speak"].tap()
        let cancel=app.buttons["Cancel voice capture"];XCTAssertTrue(cancel.waitForExistence(timeout:5));cancel.tap()
        XCTAssertTrue(app.buttons["walkthrough-voice-replay"].waitForExistence(timeout:5))
        app.buttons["walkthrough-voice-replay"].tap()
        let audible=NSPredicate(format:"value MATCHES %@","Audio level [1-9][0-9]*")
        expectation(for:audible,evaluatedWith:app.otherElements["tutorial-voice-activity"]);waitForExpectations(timeout:8)
        snapshot("Natural guide resumes after pausing for voice capture")
        app.buttons["walkthrough-exit"].tap()
    }
    func testSpokenTutorialCanReadMuteReplayAndAdvance(){
        app.swipeDown();let settings=app.buttons["Settings and backup"];XCTAssertTrue(settings.waitForExistence(timeout:5));settings.tap()
        let guide=app.buttons["settings-tutorial"]
        for _ in 0..<12{if guide.isHittable{break};app.swipeUp()}
        XCTAssertTrue(guide.waitForExistence(timeout:5));guide.tap()
        let spoken=app.switches["tutorial-spoken-guide"]
        XCTAssertTrue(spoken.waitForExistence(timeout:5));if spoken.value as? String == "0"{spoken.tap()}
        app.buttons["tutorial-start-capture"].tap()
        if app.buttons["walkthrough-lesson-continue"].waitForExistence(timeout:3){app.buttons["walkthrough-lesson-continue"].tap()}
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
        XCTAssertTrue(app.buttons["capture-voice-stop"].waitForExistence(timeout:8))
        XCTAssertTrue(app.staticTexts["Listening to you"].waitForExistence(timeout:8))
        snapshot("Capture voice pane with real audio and live transcript")
        app.buttons["capture-voice-stop"].tap()
        XCTAssertTrue(app.buttons["walkthrough-voice-toggle"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["walkthrough-voice-toggle"].label.contains("Mute guide"))
        XCTAssertTrue(app.buttons["walkthrough-voice-replay"].exists)
        app.buttons["walkthrough-voice-replay"].tap()
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
            let lesson=app.buttons["walkthrough-lesson-continue"];if lesson.exists{lesson.tap()}
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
        let workspace=app.buttons["assistant-workspace-moshia"];for _ in 0..<3{if workspace.isHittable{break};app.swipeUp()};workspace.tap()
        let message=app.descendants(matching:.any).matching(identifier:"assistant-question").firstMatch
        XCTAssertTrue(message.waitForExistence(timeout:5));message.tap();message.typeText("What have I saved about Moshia?")
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
        let initialBar=app.buttons["dictation-stop"].frame;Thread.sleep(forTimeInterval:1.5);XCTAssertEqual(initialBar.minY,app.buttons["dictation-stop"].frame.minY,accuracy:1);snapshot("Inline recording bar with stop and transcribe-send controls")
        app.buttons["dictation-stop"].tap()
        XCTAssertTrue(app.buttons["assistant-memo"].waitForExistence(timeout:6))
        XCTAssertTrue((input.value as? String)?.contains("Keep my draft") == true)
        XCTAssertFalse(app.staticTexts["Everyday Bot"].exists)
        app.buttons["assistant-memo"].tap()
        XCTAssertTrue(app.buttons["dictation-cancel"].waitForExistence(timeout:8));app.buttons["dictation-cancel"].tap()
        XCTAssertTrue(app.buttons["assistant-memo"].waitForExistence(timeout:5))
        XCTAssertTrue((input.value as? String)?.contains("Keep my draft") == true)
    }
    func testCaptureVoiceHasLiveRecorderAndKeepsEditableText() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Live transcription is verified on the paired iPhone.")
        #endif
        app.tabBars.buttons["Capture"].tap();let input=app.descendants(matching:.any).matching(identifier:"capture-text").firstMatch;XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText("Keep this thought");app.buttons["Speak"].tap()
        XCTAssertTrue(app.buttons["capture-voice-stop"].waitForExistence(timeout:8));XCTAssertTrue(app.staticTexts["Listening to you"].waitForExistence(timeout:8));XCTAssertFalse(app.otherElements["capture-live-transcript"].exists);XCTAssertFalse(app.scrollViews["capture-live-transcript"].exists);XCTAssertTrue(app.staticTexts["Your words appear after you finish."].exists)
        snapshot("Voice-only Capture keeps transcript hidden until Stop");app.buttons["capture-voice-stop"].tap();XCTAssertTrue(input.waitForExistence(timeout:5));XCTAssertTrue((input.value as? String)?.contains("Keep this thought") == true)
        app.buttons["capture-save"].tap();XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Keep this thought")).firstMatch.waitForExistence(timeout:5))
    }
    func testSavedChatsReopenAndPersistWithoutMerging(){
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-all"].tap()
        ask("Find my saved music plans")
        app.buttons["workspace-chats"].tap()
        let rows=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","chat-thread-"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout:5));let original=rows.firstMatch.identifier
        app.buttons["chat-new"].tap()
        XCTAssertTrue(app.buttons["assistant-memo"].waitForExistence(timeout:5));XCTAssertFalse(app.staticTexts["Find my saved music plans"].exists)
        ask("Help with tomorrow’s homework")
        app.buttons["workspace-chats"].tap();XCTAssertEqual(rows.count,2);snapshot("Separate saved conversations for one workspace")
        app.buttons[original].tap();XCTAssertTrue(app.staticTexts["Find my saved music plans"].waitForExistence(timeout:5));XCTAssertFalse(app.staticTexts["Help with tomorrow’s homework"].exists)
        app.terminate();app.launchArguments=["-ui-testing"];app.launch()
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-all"].tap()
        XCTAssertTrue(app.staticTexts["Find my saved music plans"].waitForExistence(timeout:5));app.buttons["workspace-chats"].tap();XCTAssertEqual(rows.count,2)
    }
    func testDeletingOpenChatKeepsNewMessagesSaved(){
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-all"].tap();ask("Our old rehearsal discussion")
        app.buttons["workspace-chats"].tap()
        let rows=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","chat-thread-"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout:5));rows.firstMatch.swipeLeft();app.buttons["Delete"].firstMatch.tap()
        let confirmation=app.alerts["Delete this conversation?"];XCTAssertTrue(confirmation.waitForExistence(timeout:5));confirmation.buttons["Delete chat"].tap()
        XCTAssertTrue(app.buttons["assistant-memo"].waitForExistence(timeout:5));XCTAssertFalse(app.staticTexts["Our old rehearsal discussion"].exists)
        ask("Our fresh rehearsal discussion")
        app.terminate();app.launchArguments=["-ui-testing"];app.launch();app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-all"].tap()
        XCTAssertTrue(app.staticTexts["Our fresh rehearsal discussion"].waitForExistence(timeout:5));XCTAssertFalse(app.staticTexts["Our old rehearsal discussion"].exists)
        app.buttons["workspace-chats"].tap();XCTAssertEqual(rows.count,1)
    }
    func testSearchVoiceEntryAndGymIdentity(){
        snapshot("Warm Today with assistant entry")
        app.tabBars.buttons["Search"].coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap()
        XCTAssertTrue(app.buttons["search-microphone"].waitForExistence(timeout:5))
        XCTAssertTrue(app.textFields["search-query"].exists)
        snapshot("Search by meaning and voice entry")
        app.tabBars.buttons["Spaces"].coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap()
        let gym=app.buttons["space-gym"];XCTAssertTrue(gym.waitForExistence(timeout:5))
        if !gym.isHittable{app.swipeUp()};snapshot("Dedicated Gym training card")
        gym.tap();XCTAssertTrue(app.buttons["gym-assistant"].waitForExistence(timeout:5))
    }
    func testSavedChatsAppearInSearch(){
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-band"].tap();ask("Our acoustic bridge needs a slower run-through")
        app.tabBars.buttons["Search"].tap();let field=app.textFields["search-query"];XCTAssertTrue(field.waitForExistence(timeout:5));field.tap();field.typeText("acoustic bridge\n")
        let chat=app.staticTexts["New conversation"];XCTAssertTrue(chat.waitForExistence(timeout:5));chat.tap()
        XCTAssertTrue(app.staticTexts["Our acoustic bridge needs a slower run-through"].waitForExistence(timeout:5))
        snapshot("Search returns and reopens a remembered conversation")
    }
    func testCallSavedResultsOpenAndPreparedChangesRequireReview(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-call-saved-results"];app.launch()
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-band"].tap();app.buttons["assistant-voice"].tap()
        let saved=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","voice-record-")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout:5));XCTAssertTrue(app.staticTexts["Changes to review · nothing saved yet"].exists);saved.tap()
        XCTAssertTrue(app.buttons["record-save"].waitForExistence(timeout:5));XCTAssertEqual(app.descendants(matching:.any).matching(identifier:"record-title").firstMatch.value as? String,"Saved Friday rehearsal");app.buttons["record-save"].tap()
        XCTAssertTrue(app.buttons["voice-listen"].waitForExistence(timeout:5));app.buttons["voice-review-Prepare Saturday rehearsal"].tap()
        app.buttons["Review new item"].tap();XCTAssertTrue(app.buttons["creation-save"].waitForExistence(timeout:5));app.buttons["creation-save"].tap()
        XCTAssertTrue(app.buttons["voice-done"].waitForExistence(timeout:5));app.buttons["voice-done"].tap()
        app.tabBars.buttons["Search"].tap();let field=app.textFields["search-query"];field.tap();field.typeText("Prepared Saturday rehearsal\n")
        XCTAssertTrue(app.staticTexts["Prepared Saturday rehearsal"].waitForExistence(timeout:5));snapshot("Saved call results open actual records; proposals save only after review")
    }
    func testLongChatResultCanBeReadFromBeginningToEnd(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-long-chat-result"];app.launch()
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-band"].tap()
        let first=app.staticTexts["Practice idea 1 · A longer title that should wrap without losing its meaning."]
        XCTAssertTrue(first.waitForExistence(timeout:5));snapshot("Long chat result opens at the start with soft scroll edges")
        let last=app.staticTexts["Practice idea 24 · A longer title that should wrap without losing its meaning."]
        for _ in 0..<16{if last.isHittable{break};app.swipeUp()}
        XCTAssertTrue(last.isHittable);snapshot("Last item of a complete 24-item chat result remains readable")
    }
    func testCallShowsDesignedResultsAndEnds(){
        app.terminate();app.launchArguments=["-ui-testing","-reset-test-data","-test-call-results"];app.launch()
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-band"].tap();app.buttons["assistant-voice"].tap()
        XCTAssertTrue(app.staticTexts["CLEARANCE 19 Bot"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Friday practice ideas"].waitForExistence(timeout:5));XCTAssertTrue(app.staticTexts["Song suggestions"].exists);XCTAssertTrue(app.staticTexts["Everlong"].exists);XCTAssertTrue(app.buttons["voice-listen"].exists)
        snapshot("Structured song suggestions inside the voice conversation")
        app.buttons["voice-done"].tap();XCTAssertTrue(app.staticTexts["call-ended"].waitForExistence(timeout:5));XCTAssertTrue(app.buttons["assistant-voice"].exists)
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

        let activity=app.otherElements["voice-activity"]
        let audible=NSPredicate(format:"value MATCHES %@","Audio level [1-9][0-9]*")
        expectation(for:audible,evaluatedWith:activity);waitForExpectations(timeout:20)
        XCTAssertTrue(voice.exists)
        snapshot("Natural speech with a measured audio signal and output route")
        app.buttons["voice-done"].tap()
    }
    func testRejectedCloudVoiceFallsBackToAudibleDeviceSpeech(){
        app.terminate();app.launchArguments.append("-test-voice-fallback");app.launch()
        app.tabBars.buttons["Assistant"].tap();app.buttons["assistant-workspace-all"].tap()
        app.buttons["assistant-voice"].tap();app.buttons["voice-read-reply"].tap()
        let backupVoice=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Offline backup · ")).firstMatch
        XCTAssertTrue(backupVoice.waitForExistence(timeout:10))
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
        let dismissPicker=app.buttons.matching(NSPredicate(format:"label IN %@",["Cancel","Close","Done"])).firstMatch;XCTAssertTrue(dismissPicker.waitForExistence(timeout:10));dismissPicker.tap()
        XCTAssertTrue(app.buttons["assistant-attach"].waitForExistence(timeout:5));app.buttons["assistant-attach"].tap();XCTAssertTrue(app.buttons["Photo or video"].waitForExistence(timeout:5));app.buttons["Photo or video"].tap()
        XCTAssertTrue(dismissPicker.waitForExistence(timeout:10));dismissPicker.tap()
        let input=app.descendants(matching:.any).matching(identifier:"assistant-question").firstMatch
        input.tap();input.typeText("Hello");app.buttons["Send question"].tap()
        app.buttons["assistant-voice"].tap()
        #if targetEnvironment(simulator)
        XCTAssertTrue(app.staticTexts["Ready when you are"].waitForExistence(timeout:5))
        #else
        XCTAssertTrue(app.staticTexts["Listening to you"].waitForExistence(timeout:8))
        #endif
        snapshot("Voice conversation with explicit microphone control")
        app.buttons["voice-read-reply"].tap()
        XCTAssertTrue(app.staticTexts["Connect your assistant to hear your chosen natural voice."].waitForExistence(timeout:5))
        XCTAssertFalse(app.staticTexts["Your assistant is speaking"].exists)
        snapshot("Unconnected voice explains the connection requirement without claiming playback")
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
        for _ in 0..<4{if cards.count>=2{break};app.swipeUp()}
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
