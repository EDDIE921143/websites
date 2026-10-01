import XCTest
@testable import EdizCore
final class CoreTests: XCTestCase {
    let now=Time.date("2026-10-01T10:00:00Z")!
    func database() throws -> Database { let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("test.sqlite");return try Database(url:url) }
    func testCreationDraftsKeepTheirOwnFieldsAndLeaveQuickCaptureAlone() throws {
        let db=try database();let quick=Record(title:"Quick thought");try db.setDraft(quick)
        var chapter=Record(space:"moshia",kind:"chapter",title:"Chapter draft");chapter.data["POV"]="Narrator";try db.setCreationDraft(chapter)
        try db.setCreationDraft(Record(space:"moshia",kind:"thread",title:"Loose thread"))
        XCTAssertEqual(try db.creationDraft(space:"moshia",kind:"chapter")?.data["POV"],"Narrator")
        XCTAssertEqual(try db.draft()?.title,"Quick thought")
        try db.clearCreationDraft(space:"moshia",kind:"chapter")
        XCTAssertNil(try db.creationDraft(space:"moshia",kind:"chapter"))
        XCTAssertEqual(try db.creationDraft(space:"moshia",kind:"thread")?.title,"Loose thread")
    }
    func testPriorityExcludesWaitingAndExplainsDeadline() {
        let soon=Record(space:"school",kind:"assignment",title:"Due",due:now.addingTimeInterval(3600),now:now)
        let waiting=Record(title:"Waiting",status:"waiting",now:now)
        let ordinary=Record(title:"Ordinary",now:now)
        let ranked=Priority.rank([ordinary,waiting,soon],now:now)
        XCTAssertEqual(ranked.first?.id,soon.id);XCTAssertEqual(ranked.count,2);XCTAssertTrue(ranked[0].reasons.contains{$0.contains("24 hours")})
    }
    func testCreativePossibilitiesStayPossible() { let r=CaptureParser.parse("Moshia idea: Nathaniel",now:now);XCTAssertEqual(r.space,"moshia");XCTAssertEqual(r.kind,"idea");XCTAssertEqual(r.status,"POSSIBLE");XCTAssertFalse(r.actionable) }
    func testCaptureUnderstandsTomorrowAndTime() { var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!;let r=CaptureParser.parse("Call Studio 41 tomorrow at 16",now:now,calendar:calendar);XCTAssertEqual(r.space,"ejj");XCTAssertEqual(r.due,"2026-10-02T16:00:00Z") }
    func testFuzzySearchAndLinkedInformation() { var r=Record(space:"moshia",kind:"chapter",title:"Chapter 10");r.data["characters"]="Nathaniel";XCTAssertEqual(SearchIndex.find([r],query:"Nathanil").count,1) }
    func testPersistenceAndHistory() throws { let db=try database();let r=Record(title:"Local task");try db.save(r,action:"Created");XCTAssertEqual(try db.records().first?.title,r.title);XCTAssertEqual(try db.history().first?.action,"Created") }
    func testDraftRoundTrip() throws { let db=try database();let draft=Record(title:"");try db.setDraft(draft);XCTAssertEqual(try db.draft()?.id,draft.id);try db.setDraft(nil);XCTAssertNil(try db.draft()) }
    func testEditsStayDraftsUntilExplicitSave() throws {
        let db=try database();var record=Record(space:"moshia",kind:"character",title:"Character");try db.save(record)
        record.status="CANON";record.body="Unsaved context";try db.setEditDraft(record)
        XCTAssertEqual(try db.records().first?.status,"POSSIBLE")
        XCTAssertEqual(try db.editDraft(recordID:record.id)?.body,"Unsaved context")
        try db.save(record);XCTAssertNil(try db.editDraft(recordID:record.id))
        XCTAssertEqual(try db.records().first?.status,"CANON")
    }
    func testBackupRoundTripWithAttachmentAndUpdate() throws { let db=try database();var r=Record(title:"With file");try db.save(r);let attachment=Attachment(recordID:r.id,name:"note.txt",type:"text/plain",bytes:Data("private".utf8));try db.attach(attachment);r.title="Updated";try db.save(r);XCTAssertEqual(try db.attachments().count,1);let backup=try db.backupData();let restored=try database();try restored.restore(backup);XCTAssertEqual(try restored.records().first?.title,"Updated");XCTAssertEqual(try restored.attachments().first?.bytes,Data("private".utf8)) }
    func testWebBackupWithoutAttachmentTimestampOrOptionalSettings() throws {
        let source=try database();let r=Record(title:"Existing web record");try source.save(r)
        try source.attach(Attachment(recordID:r.id,name:"web.txt",type:"text/plain",bytes:Data("original file".utf8)))
        var json=try JSONSerialization.jsonObject(with:source.backupData()) as! [String:Any]
        var files=json["attachments"] as! [[String:Any]];files[0].removeValue(forKey:"at");json["attachments"]=files
        json["settings"]=["focus":"school"]
        let destination=try database();try destination.restore(JSONSerialization.data(withJSONObject:json))
        XCTAssertEqual(try destination.attachments().first?.bytes,Data("original file".utf8))
        XCTAssertEqual(try destination.preferences().focus,"school")
    }
    func testInvalidBackupCannotErasePreviousRecords() throws { let db=try database();let r=Record(title:"Safe");try db.save(r);var backup=try db.backup();backup.items[0].space="invalid";XCTAssertThrowsError(try db.restore(JSONEncoder().encode(backup)));XCTAssertEqual(try db.records().first?.title,"Safe") }
    func testMergeDuplicatesAndIDCollisionAreSafe() throws { let db=try database();let r=Record(title:"Original");try db.save(r);var other=r;other.title="Other";XCTAssertEqual(try db.merge([r,other]),1);XCTAssertEqual(try db.records().count,2);XCTAssertEqual(Set(try db.records().map(\.id)).count,2) }
    func testCSVQuotedFieldsAndCalendar() throws { let records=try ImportParser.records(data:Data("business,notes\nStudio 41,\"A, B\"".utf8),filename:"leads.csv",space:"ejj");XCTAssertEqual(records.first?.data["notes"],"A, B");XCTAssertEqual(records.first?.status,"Lead");let calendar=try ImportParser.records(data:Data("BEGIN:VCALENDAR\nBEGIN:VEVENT\nSUMMARY:Rehearsal\nDTSTART:20261002T160000Z\nEND:VEVENT\nEND:VCALENDAR".utf8),filename:"calendar.ics",space:"band");XCTAssertEqual(calendar.first?.due,"2026-10-02T16:00:00Z") }
    func testWeightedGradeProjection() { var r=Record(space:"school",kind:"grade",title:"English");r.data=["subject":"English","grade":"1","weight":"2"];XCTAssertEqual(Grades.project([r],subject:"English",next:2,weight:1)!,4.0/3.0,accuracy:0.001) }
    func testSQLiteReopenAndSevenDailySnapshots() throws { let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);let url=folder.appendingPathComponent("store.sqlite");do{let db=try Database(url:url);try db.save(Record(title:"Durable"));for day in 0..<10{try db.snapshot(directory:folder.appendingPathComponent("snapshots"),now:now.addingTimeInterval(Double(day)*86400))}};let reopened=try Database(url:url);XCTAssertEqual(try reopened.records().first?.title,"Durable");XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath:folder.appendingPathComponent("snapshots").path).count,7) }
}
