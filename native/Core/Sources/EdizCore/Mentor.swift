import Foundation

public enum MentorDesk {
    public static let space = "tutoring"
    public static func students(in records:[Record])->[Record] {
        records.filter{$0.space == space && $0.data["mentorType"] == "student" && $0.status != "archived"}.sorted{$0.title.localizedStandardCompare($1.title) == .orderedAscending}
    }
    public static func context(for studentID:String,in records:[Record])->[Record] {
        records.filter{$0.space == space && ($0.id == studentID || $0.data["studentID"] == studentID)}
    }
    public static func student(first:String,last:String,subjects:String,year:String)->Record {
        var r=Record(space:space,kind:"note",title:[first,last].map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}.filter{!$0.isEmpty}.joined(separator:" "))
        r.data=["mentorType":"student","firstName":first,"lastName":last,"subjects":subjects,"year":year];return r
    }
    public static func item(student:Record,type:String,title:String,subject:String,body:String,due:Date?=nil)->Record {
        var r=Record(space:space,kind:type == "exam" ? "exam":type == "appointment" ? "event":type == "goal" ? "task":"note",title:title,body:body,due:due)
        r.data=["mentorType":type,"studentID":student.id,"studentName":student.title,"subject":subject,"reminderMinutes":type == "exam" ? "1440":"30"]
        return r
    }
    public static func reminderDate(_ record:Record,now:Date=Date())->Date? {
        guard record.space == space,!["done","archived"].contains(record.status),["exam","appointment","goal"].contains(record.data["mentorType"]),let due=Time.date(record.due),due>now else{return nil}
        let minutes=max(0,min(10080,Int(record.data["reminderMinutes"] ?? "30") ?? 30))
        let preferred=due.addingTimeInterval(-Double(minutes)*60)
        return preferred>now ? preferred:due
    }
}
