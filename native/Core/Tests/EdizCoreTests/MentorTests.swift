import XCTest
@testable import EdizCore
final class MentorTests:XCTestCase {
    func testStudentsAndContextNeverCrossStudentOrSpace(){
        let a=MentorDesk.student(first:"Alex",last:"Example",subjects:"Math",year:"8")
        let b=MentorDesk.student(first:"Sam",last:"Example",subjects:"English",year:"7")
        let lesson=MentorDesk.item(student:a,type:"session",title:"Fractions",subject:"Math",body:"Practised")
        var foreign=lesson;foreign.id="other";foreign.space="school"
        XCTAssertTrue(a.valid);XCTAssertTrue(lesson.valid)
        XCTAssertEqual(Set(MentorDesk.context(for:a.id,in:[a,b,lesson,foreign]).map(\.id)),Set([a.id,lesson.id]))
        XCTAssertEqual(MentorDesk.students(in:[lesson,b,a]).count,2)
    }
    func testReminderKeepsNearAppointmentsAndExcludesCompleted(){
        let now=Date(timeIntervalSince1970:100000)
        let student=MentorDesk.student(first:"A",last:"B",subjects:"Math",year:"")
        var event=MentorDesk.item(student:student,type:"appointment",title:"Lesson",subject:"Math",body:"",due:now.addingTimeInterval(300))
        XCTAssertEqual(MentorDesk.reminderDate(event,now:now),Time.date(event.due))
        event.status="done";XCTAssertNil(MentorDesk.reminderDate(event,now:now))
        event.status="active";event.due=Time.string(now.addingTimeInterval(-1));XCTAssertNil(MentorDesk.reminderDate(event,now:now))
    }
}
