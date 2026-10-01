import Foundation
public struct Recommendation: Identifiable, Sendable {
    public var record: Record
    public var score: Double
    public var reasons: [String]
    public var id: String { record.id }
}
public enum Priority {
    public static func rank(_ records: [Record], now: Date = Date(), focus: String = "all") -> [Recommendation] {
        records.filter(\.actionable).map { record in
            var score = Double((record.importance ?? 2) * 8)
            var reasons: [String] = []
            if let due = Time.date(record.due) {
                let days = due.timeIntervalSince(now) / 86400
                if days < 0 { score += 65; reasons.append("Its planned date has passed; choose a realistic next step.") }
                else if days < 1 { score += 60; reasons.append("It is due within the next 24 hours.") }
                else if days < 3 { score += 40; reasons.append("Its deadline is approaching.") }
                else if days < 7 { score += 20; reasons.append("It is coming up this week.") }
            }
            if (record.importance ?? 2) >= 4 { reasons.append("You marked this as important.") }
            if record.space == focus { score += 20; reasons.append("It matches your current focus.") }
            let age = now.timeIntervalSince(Time.date(record.updated) ?? now) / 86400
            score += min(15, max(0, age))
            if age > 7 { reasons.append("It has been quiet for more than a week.") }
            if record.kind == "lead", let contact = Time.date(record.data["lastContact"]), now.timeIntervalSince(contact) >= 4 * 86400 { score += 15; reasons.append("This relationship is ready for a follow-up.") }
            if let duration = record.duration, duration > 0, duration <= 25 { score += 4; reasons.append("It fits into a short session.") }
            if reasons.isEmpty { reasons.append("An active next step in your system.") }
            return Recommendation(record: record, score: score, reasons: reasons)
        }.sorted { a,b in
            func urgent(_ r:Record)->Bool { ["assignment","exam"].contains(r.kind) && (Time.date(r.due).map{$0.timeIntervalSince(now)<=86400} ?? false) }
            if urgent(a.record) != urgent(b.record){return urgent(a.record)}
            return a.score == b.score ? a.record.created < b.record.created : a.score > b.score
        }
    }
    public static func briefing(_ records: [Record], now: Date = Date(), focus: String = "all") -> String {
        let top = rank(records, now:now, focus:focus).prefix(4)
        guard !top.isEmpty else { return "Nothing needs to be ranked yet. Capture a task when you’re ready." }
        let grouped = Dictionary(grouping: top, by: { $0.record.space })
        return Catalog.spaces.compactMap { s in grouped[s.id].map { "\($0.count) \($0.count == 1 ? "next step" : "next steps") in \(s.name)" } }.joined(separator:". ") + ". Start with one."
    }
}
public enum CaptureParser {
    public static func parse(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> Record {
        let lower = text.lowercased()
        let space = lower.range(of:"ejj|studio|client|lead|website|domain",options:.regularExpression) != nil ? "ejj" : lower.range(of:"moshia|mushiya|nathaniel|chapter|character|plot",options:.regularExpression) != nil ? "moshia" : lower.range(of:"clearance|guitar|rehearsal|band|song",options:.regularExpression) != nil ? "band" : lower.range(of:"school|french|english|math|homework|exam|test",options:.regularExpression) != nil ? "school" : "personal"
        let kind = lower.contains("idea") ? "idea" : lower.contains("note") ? "note" : lower.contains("homework") || (space == "school" && lower.contains(" p")) ? "assignment" : "task"
        var date: Date?
        if lower.contains("tomorrow") { date = calendar.date(byAdding:.day,value:1,to:now) }
        else if lower.contains("today") { date = now }
        else {
            let weekdays = ["sunday","monday","tuesday","wednesday","thursday","friday","saturday"]
            if let index = weekdays.firstIndex(where:{ lower.contains($0) }) { let current = calendar.component(.weekday,from:now); let delta = (index + 1 - current + 7) % 7; date = calendar.date(byAdding:.day,value:delta == 0 ? 7 : delta,to:now) }
        }
        if let d = date {
            var hour = 12, minute = 0
            if let regex = try? NSRegularExpression(pattern:"(?:at|um)\\s+(\\d{1,2})(?::(\\d{2}))?"), let match = regex.firstMatch(in:lower,range:NSRange(lower.startIndex...,in:lower)), let h = Range(match.range(at:1),in:lower) {
                hour = Int(lower[h]) ?? 12
                if let m = Range(match.range(at:2),in:lower) { minute = Int(lower[m]) ?? 0 }
            }
            date = hour <= 23 && minute <= 59 ? calendar.date(bySettingHour:hour,minute:minute,second:0,of:d) : nil
        }
        return Record(space:space,kind:kind,title:text.trimmingCharacters(in:.whitespacesAndNewlines),due:date,now:now)
    }
}
public enum SearchIndex {
    public static func find(_ records: [Record], query: String) -> [Record] {
        let words = query.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if words.isEmpty { return records.sorted { $0.updated > $1.updated } }
        func distance(_ a: String, _ b: String) -> Int { let aa=Array(a),bb=Array(b); var row=Array(0...bb.count); for (i,c) in aa.enumerated() { var next=[i+1]; for (j,d) in bb.enumerated() { next.append(min(next[j]+1,row[j+1]+1,row[j]+(c == d ? 0 : 1))) }; row=next }; return row.last ?? aa.count }
        return records.compactMap { r -> (Record,Int)? in
            let text=([r.title,r.body,r.kind,r.status,Catalog.space(r.space).name]+Array(r.data.values)+[Time.date(r.due).map{ $0.formatted(.dateTime.weekday(.wide)) } ?? ""]).joined(separator:" ").lowercased()
            let tokens=text.split(whereSeparator:{ !$0.isLetter && !$0.isNumber }).map(String.init)
            var score=0
            for word in words { if text.contains(word) { score += r.title.lowercased().contains(word) ? 5 : 2 } else if word.count >= 4 && tokens.contains(where:{ abs($0.count-word.count) <= 1 && distance($0,word) <= 1 }) { score += 1 } else { return nil } }
            return (r,score)
        }.sorted { $0.1 > $1.1 }.map(\.0)
    }
}
public enum Grades {
    public static func project(_ records: [Record], subject: String, next: Double, weight: Double) -> Double? {
        let grades=records.filter { $0.kind == "grade" && $0.data["subject"]?.lowercased() == subject.lowercased() }
        let values=grades.compactMap { r -> (Double,Double)? in guard let value=Double(r.data["grade"] ?? "") else{return nil};return (value,max(0,Double(r.data["weight"] ?? "1") ?? 1)) }
        let total=values.reduce(0) { $0+$1.1 }+max(0,weight)
        guard total > 0 else { return nil }
        return (values.reduce(0) { $0+$1.0*$1.1 }+next*max(0,weight))/total
    }
}
