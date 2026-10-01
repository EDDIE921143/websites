import XCTest
@testable import EdizCore
final class AssistantTests:XCTestCase {
    let now=Time.date("2026-10-01T10:00:00Z")!
    func testAssistantReasonsUseThePreviousRecommendation(){let r=Record(title:"Real task",due:now.addingTimeInterval(3600),now:now);let reply=AssistantRules.reply(to:"Why that?",records:[r],history:[],previous:[r],now:now);XCTAssertTrue(reply.text.contains("24 hours"));XCTAssertEqual(reply.records.first?.id,r.id)}
    func testReminderIsOnlyADraft(){let reply=AssistantRules.reply(to:"Remind me French homework tomorrow",records:[],history:[],now:now);XCTAssertEqual(reply.draft?.space,"school");XCTAssertNotNil(reply.draft?.due);XCTAssertTrue(reply.records.isEmpty)}
    func testTomorrowUsesSavedDurations(){var cal=Calendar(identifier:.gregorian);cal.timeZone=TimeZone(secondsFromGMT:0)!;var r=Record(title:"Tomorrow",due:now.addingTimeInterval(86400),now:now);r.duration=25;let reply=AssistantRules.reply(to:"Plan tomorrow",records:[r],history:[],now:now,calendar:cal);XCTAssertEqual(reply.records.count,1);XCTAssertTrue(reply.text.contains("25 minutes"))}
}
