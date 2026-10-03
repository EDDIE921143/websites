import XCTest
@testable import EdizCore
final class AssistantTests:XCTestCase {
    let now=Time.date("2026-10-01T10:00:00Z")!
    func testGreetingStartsAConversationInsteadOfSearchingRecords(){let r=Record(title:"Hello draft",now:now);let reply=AssistantRules.reply(to:"Hello",records:[r],history:[]);XCTAssertTrue(reply.text.contains("What’s on your mind?"));XCTAssertTrue(reply.records.isEmpty)}
    func testAssistantReasonsUseThePreviousRecommendation(){let r=Record(title:"Real task",due:now.addingTimeInterval(3600),now:now);let reply=AssistantRules.reply(to:"Why that?",records:[r],history:[],previous:[r],now:now);XCTAssertTrue(reply.text.contains("24 hours"));XCTAssertEqual(reply.records.first?.id,r.id)}
    func testReminderIsOnlyADraft(){let reply=AssistantRules.reply(to:"Remind me French homework tomorrow",records:[],history:[],now:now);XCTAssertEqual(reply.draft?.space,"school");XCTAssertNotNil(reply.draft?.due);XCTAssertTrue(reply.records.isEmpty)}
    func testCreativeQuestionsNeverPresentPossibilitiesAsCanon(){let r=Record(space:"moshia",kind:"character",title:"Nathaniel",body:"A possible secret",now:now);let reply=AssistantRules.reply(to:"Tell me about Nathaniel",records:[r],history:[],now:now);XCTAssertTrue(reply.text.contains("POSSIBLE"));XCTAssertTrue(reply.text.contains("A possible secret"))}
    func testTomorrowUsesSavedDurations(){var cal=Calendar(identifier:.gregorian);cal.timeZone=TimeZone(secondsFromGMT:0)!;var r=Record(title:"Tomorrow",due:now.addingTimeInterval(86400),now:now);r.duration=25;let reply=AssistantRules.reply(to:"Plan tomorrow",records:[r],history:[],now:now,calendar:cal);XCTAssertEqual(reply.records.count,1);XCTAssertTrue(reply.text.contains("25 minutes"))}
}

final class DictationTranscriptTests: XCTestCase {
    func testTimestampCorrectionDoesNotDuplicateGrowingHypothesis() {
        var text=DictationTranscript()
        text.update("Make a plan",segmentStart:0)
        text.update("Make a plan for Friday",segmentStart:1.2)
        text.update("Make a plan for Friday",segmentStart:2.5)
        XCTAssertEqual(text.text,"Make a plan for Friday")
    }

    func testPreservesEarlierSpeechWhenRecognitionMovesToANewSegment() {
        var text=DictationTranscript()
        text.update("We need to practice the chorus",segmentStart:0)
        text.update("and make a plan for Friday",segmentStart:12)
        XCTAssertEqual(text.text,"We need to practice the chorus and make a plan for Friday")
        text.commit()
        text.update("if everyone can come",segmentStart:0)
        XCTAssertEqual(text.text,"We need to practice the chorus and make a plan for Friday if everyone can come")
    }
    func testAllowsPartialCorrectionsWithoutDuplicatingThem() {
        var text=DictationTranscript()
        text.update("Go to the ware",segmentStart:0)
        text.update("Go to the warehouse",segmentStart:0)
        XCTAssertEqual(text.text,"Go to the warehouse")
    }
}
