import Foundation

public struct Module: Identifiable, Hashable, Sendable {
    public let kind: String
    public let label: String
    public var id: String { kind }
    public init(_ kind: String, _ label: String) { self.kind = kind; self.label = label }
}
public struct SpaceDefinition: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let summary: String
    public let mark: String
    public let color: UInt32
    public let modules: [Module]
}
public enum Catalog {
    public static let spaces: [SpaceDefinition] = [
        .init(id:"ejj", name:"EJJ Digital", summary:"Leads · Websites", mark:"EJJ", color:0x7199BF, modules:[.init("lead","Leads"),.init("website","Websites"),.init("task","Tasks"),.init("note","Notes"),.init("idea","Ideas")]),
        .init(id:"band", name:"CLEARANCE 19", summary:"Songs · Rehearsals", mark:"19", color:0xBF7777, modules:[.init("song","Songs"),.init("rehearsal","Rehearsals"),.init("task","Practice"),.init("note","Notes"),.init("idea","Ideas")]),
        .init(id:"moshia", name:"Moshia", summary:"Chapters · Story world", mark:"M", color:0xC5B89B, modules:[.init("chapter","Chapters"),.init("character","Characters"),.init("thread","Plot threads"),.init("location","Locations"),.init("organization","Organizations"),.init("event","Timeline"),.init("note","Research"),.init("idea","Ideas")]),
        .init(id:"school", name:"School", summary:"Homework · Tests", mark:"S", color:0xC3A46B, modules:[.init("assignment","Homework"),.init("exam","Tests"),.init("subject","Subjects"),.init("grade","Grades"),.init("event","Timetable"),.init("note","Materials")]),
        .init(id:"personal", name:"Personal", summary:"Tasks · Notes", mark:"P", color:0x93936F, modules:[.init("task","Tasks"),.init("event","Appointments"),.init("note","Notes"),.init("idea","Ideas")])
    ]
    public static func space(_ id: String) -> SpaceDefinition { spaces.first { $0.id == id } ?? spaces[4] }
    public static func quickModules(for id:String)->[Module] {
        let kinds=id == "school" ? ["assignment","exam","grade"]:id == "personal" ? ["task","note","idea"]:Array(space(id).modules.prefix(3)).map(\.kind)
        return kinds.compactMap{kind in space(id).modules.first{$0.kind == kind}}
    }
    public static let kinds = Set(spaces.flatMap { $0.modules.map(\.kind) })
    public static func states(kind: String, space: String) -> [String] {
        if space == "moshia" { return ["POSSIBLE","PLANNED","CANON","REJECTED"] }
        if kind == "lead" { return ["Lead","Contacted","Interested","Demo","Follow-up","Client","Lost"] }
        if kind == "song" { return ["Learning","Rehearsing","Ready"] }
        if kind == "idea" { return ["new","developing","promoted","archived"] }
        return ["active","waiting","blocked","done","archived"]
    }
    public static func fields(_ kind: String) -> [String] {
        switch kind {
        case "lead": return ["business","contact","phone","email","website","city","lastContact","nextAction","package","value","source"]
        case "website": return ["productionURL","repository","domain","lastDeployment","deploymentStatus","client"]
        case "song": return ["artist","BPM","tuning","structure","readiness","chords","lyrics"]
        case "rehearsal": return ["location","setlist","targets"]
        case "character": return ["aliases","age","relationships","affiliations","knowledge","secrets","chapterAppearances"]
        case "chapter": return ["wordCount","POV","location","storyDate","characters","plotThreads","purpose","continuity"]
        case "thread": return ["setup","development","payoff","threadStatus"]
        case "location": return ["region","description"]
        case "event": return ["location","storyDate","chapter","characters","sequence"]
        case "assignment", "exam": return ["subject","instructions"]
        case "subject": return ["teacher","room","weightingRules"]
        case "grade": return ["subject","grade","weight"]
        default: return []
        }
    }
}
public enum Time {
    public static func string(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    public static func date(_ string: String?) -> Date? {
        guard let string else { return nil }
        let f = ISO8601DateFormatter()
        if let d = f.date(from: string) { return d }
        f.formatOptions.insert(.withFractionalSeconds)
        return f.date(from: string)
    }
}
public struct Record: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var space: String
    public var kind: String
    public var title: String
    public var body: String
    public var status: String
    public var created: String
    public var updated: String
    public var due: String?
    public var duration: Int?
    public var importance: Int?
    public var blocked: Bool?
    public var data: [String:String]
    public init(space: String = "personal", kind: String = "task", title: String, body: String = "", status: String? = nil, due: Date? = nil, now: Date = Date()) {
        self.id = UUID().uuidString; self.space = space; self.kind = kind; self.title = title; self.body = body
        self.status = status ?? Catalog.states(kind: kind, space: space)[0]
        self.created = Time.string(now); self.updated = Time.string(now); self.due = due.map(Time.string)
        self.duration = nil; self.importance = 2; self.blocked = false; self.data = [:]
    }
    public var actionable: Bool {
        ["task","assignment","exam","lead"].contains(kind) && !["done","Lost","Client","archived","waiting","blocked"].contains(status) && blocked != true
    }
    public var valid: Bool {
        Catalog.spaces.contains { $0.id == space } && Catalog.kinds.contains(kind) && !id.isEmpty && !title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && Time.date(created) != nil && Time.date(updated) != nil && (due == nil || Time.date(due) != nil)
    }
}
public struct Activity: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var entityId: String
    public var title: String
    public var action: String
    public var at: String
    public init(record: Record, action: String, now: Date = Date()) { self.id = UUID().uuidString; self.entityId = record.id; self.title = record.title; self.action = action; self.at = Time.string(now) }
}
public struct Preferences: Codable, Sendable {
    public var theme: String = "dark"
    public var density: String = "comfortable"
    public var focus: String = "all"
    public var lastVisit: String = Time.string(Date())
    public var lastBackup: String?
    public var recentId: String?
    public var labs: Bool = false
    public var localEndpoint: String?
    public init() {}
    enum CodingKeys:String,CodingKey { case theme,density,focus,lastVisit,lastBackup,recentId,labs,localEndpoint }
    public init(from decoder:Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        theme=try c.decodeIfPresent(String.self,forKey:.theme) ?? "dark"
        density=try c.decodeIfPresent(String.self,forKey:.density) ?? "comfortable"
        focus=try c.decodeIfPresent(String.self,forKey:.focus) ?? "all"
        lastVisit=try c.decodeIfPresent(String.self,forKey:.lastVisit) ?? Time.string(Date())
        lastBackup=try c.decodeIfPresent(String.self,forKey:.lastBackup)
        recentId=try c.decodeIfPresent(String.self,forKey:.recentId)
        labs=try c.decodeIfPresent(Bool.self,forKey:.labs) ?? false
        localEndpoint=try c.decodeIfPresent(String.self,forKey:.localEndpoint)
    }
}
public struct Attachment: Codable, Identifiable, Sendable {
    public var id: String
    public var entityId: String
    public var name: String
    public var type: String
    public var base64: String
    public var at: String?
    public init(recordID: String, name: String, type: String, bytes: Data) { id = UUID().uuidString; entityId = recordID; self.name = name; self.type = type; base64 = "data:\(type);base64,\(bytes.base64EncodedString())"; at = Time.string(Date()) }
    public var bytes: Data? { guard let comma = base64.firstIndex(of:",") else { return nil }; return Data(base64Encoded: String(base64[base64.index(after:comma)...])) }
}
public struct Backup: Codable, Sendable {
    public var format: String = "ediz-os"
    public var version: Int = 1
    public var exported: String = Time.string(Date())
    public var items: [Record]
    public var settings: Preferences
    public var activity: [Activity]
    public var attachments: [Attachment]
    public init(items:[Record],settings:Preferences,activity:[Activity],attachments:[Attachment] = []) { self.items = items; self.settings = settings; self.activity = activity; self.attachments = attachments }
    public func validate() throws {
        guard format == "ediz-os", version == 1, items.allSatisfy(\.valid), Set(items.map(\.id)).count == items.count else { throw CoreError.invalidBackup }
        let ids = Set(items.map(\.id))
        guard attachments.allSatisfy({ ids.contains($0.entityId) && $0.bytes != nil }), Set(attachments.map(\.id)).count == attachments.count else { throw CoreError.invalidBackup }
    }
}
public enum CoreError: Error, LocalizedError {
    case invalidBackup, database(String), invalidRecord
    public var errorDescription: String? { switch self { case .invalidBackup:return "This backup could not be validated. Your current records are unchanged.";case .database:return "Ediz OS couldn’t save that change. Your previous version is safe.";case .invalidRecord:return "Add a title and check the date before saving." } }
}
