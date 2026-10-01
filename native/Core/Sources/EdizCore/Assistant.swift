import Foundation

public struct AssistantReply:Sendable {
    public var text:String
    public var records:[Record]
    public var draft:Record?
    public init(_ text:String,records:[Record]=[],draft:Record?=nil){self.text=text;self.records=records;self.draft=draft}
}
public enum AssistantRules {
    public static func reply(to question:String,records:[Record],history:[Activity],focus:String="all",previous:[Record]=[],now:Date=Date(),calendar:Calendar = .current)->AssistantReply {
        let q=question.trimmingCharacters(in:.whitespacesAndNewlines)
        let lower=q.lowercased()
        if lower.hasPrefix("capture ") || lower.hasPrefix("remind me ") || lower.hasPrefix("add task ") {
            let prefix=lower.hasPrefix("capture ") ? 8:lower.hasPrefix("add task ") ? 9:10
            let draft=CaptureParser.parse(String(q.dropFirst(prefix)),now:now,calendar:calendar)
            return AssistantReply("I’ve prepared this for \(Catalog.space(draft.space).name). Check the details before saving.",draft:draft)
        }
        if lower.contains("why"),let record=previous.first {
            let reasons=Priority.rank([record],now:now,focus:focus).first?.reasons ?? []
            return AssistantReply("\(record.title): "+(reasons.isEmpty ? "It came from your saved context.":reasons.joined(separator:" ")),records:[record])
        }
        if lower.contains("waiting") || lower.contains("blocked") || lower.contains("loose end") || lower.contains("forget") {
            let waiting=records.filter{["waiting","blocked"].contains($0.status) || $0.blocked == true}
            let stale=records.filter{$0.actionable && Time.date($0.updated).map{now.timeIntervalSince($0)>7*86400} == true}
            let found=Array((waiting+stale).prefix(5))
            return AssistantReply(found.isEmpty ? "There are no waiting or neglected actions in your saved work.":"\(waiting.count) items are waiting or blocked, and \(stale.count) active items have been quiet for over a week. These are worth a quick look; they don’t all need doing today.",records:found)
        }
        if lower.contains("progress") || lower.contains("completed") || lower.contains("review") {
            let period=lower.contains("week") ? 7*86400:86400
            let recent=history.filter{Time.date($0.at).map{now.timeIntervalSince($0)<Double(period)} == true}
            let completed=recent.filter{$0.action == "Completed"}
            let ids=Set(completed.map(\.entityId))
            return AssistantReply(completed.isEmpty ? "No completions are recorded for this period yet. Your saved changes still count as progress.":"You completed \(completed.count) items \(period>86400 ? "this week":"in the last day"). There were \(recent.count) saved changes in total.",records:Array(records.filter{ids.contains($0.id)}.prefix(5)))
        }
        if lower.hasPrefix("find ") || lower.hasPrefix("search ") || lower.hasPrefix("show me ") {
            let prefix=lower.hasPrefix("find ") ? 5:lower.hasPrefix("search ") ? 7:8
            let matches=SearchIndex.find(records,query:String(q.dropFirst(prefix)))
            return AssistantReply(matches.isEmpty ? "I couldn’t find that in your saved work. Try a name, a space, or a shorter phrase.":"I found \(matches.count) related \(matches.count == 1 ? "item":"items").",records:Array(matches.prefix(8)))
        }
        if lower.contains("tomorrow") || lower.contains("schedule") || lower.contains("calendar") || lower.contains("coming up") {
            let start=lower.contains("tomorrow") ? calendar.startOfDay(for:calendar.date(byAdding:.day,value:1,to:now) ?? now):calendar.startOfDay(for:now)
            let end=calendar.date(byAdding:.day,value:lower.contains("tomorrow") ? 1:7,to:start) ?? start
            let upcoming=records.filter{![$0.status].contains("done") && Time.date($0.due).map{$0>=start && $0<end} == true}.sorted{($0.due ?? "")<($1.due ?? "")}
            let minutes=upcoming.compactMap(\.duration).reduce(0,+)
            return AssistantReply(upcoming.isEmpty ? "There’s nothing dated \(lower.contains("tomorrow") ? "tomorrow":"in the next week") in your saved work.":"\(upcoming.count) items are scheduled \(lower.contains("tomorrow") ? "tomorrow":"over the next week").\(minutes>0 ? " The durations you’ve entered add up to \(minutes) minutes; undated estimates aren’t included.":"")",records:Array(upcoming.prefix(6)))
        }
        if lower.contains("focus") || lower.contains("next") || lower.contains("today") || lower.contains("matter") || lower.contains("plan") {
            let ranked=Priority.rank(records,now:now,focus:focus)
            guard let first=ranked.first else{return AssistantReply("There are no active next steps yet, Ediz. Capture what’s on your mind, or import the work you already have.")}
            return AssistantReply("Start with \(first.record.title). \(first.reasons.first ?? "") "+Priority.briefing(records,focus:focus),records:Array(ranked.prefix(3).map(\.record)))
        }
        let matches=SearchIndex.find(records,query:q)
        if !matches.isEmpty{return AssistantReply("Here’s the saved context I found for that.",records:Array(matches.prefix(6)))}
        return AssistantReply("I can help you choose a next step, plan tomorrow, review progress, find saved context, or prepare a reminder. For an open-ended conversation, you can optionally connect a local model in Settings; it needs no paid API.")
    }
}
