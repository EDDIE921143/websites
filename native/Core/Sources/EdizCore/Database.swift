import Foundation
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

public final class Database {
    private var handle: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    public init(url: URL) throws {
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        guard sqlite3_open(url.path,&handle) == SQLITE_OK else { sqlite3_close(handle); handle=nil; throw CoreError.database("open") }
        do {
            try execute("PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA synchronous=FULL; PRAGMA busy_timeout=3000;")
            try execute("CREATE TABLE IF NOT EXISTS entities(id TEXT PRIMARY KEY,space TEXT NOT NULL,kind TEXT NOT NULL,status TEXT NOT NULL,json TEXT NOT NULL); CREATE INDEX IF NOT EXISTS entity_space_kind ON entities(space,kind); CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,json TEXT NOT NULL); CREATE TABLE IF NOT EXISTS activity(id TEXT PRIMARY KEY,json TEXT NOT NULL); CREATE TABLE IF NOT EXISTS attachments(id TEXT PRIMARY KEY,entity_id TEXT NOT NULL REFERENCES entities(id) ON DELETE CASCADE,json TEXT NOT NULL); PRAGMA user_version=1;")
        } catch { sqlite3_close(handle); handle=nil; throw error }
    }
    deinit { sqlite3_close(handle) }
    private func execute(_ sql: String) throws { var error: UnsafeMutablePointer<CChar>?; let result=sqlite3_exec(handle,sql,nil,nil,&error); if let error { sqlite3_free(error) }; guard result == SQLITE_OK else { throw CoreError.database("execute") } }
    private func statement(_ sql: String, _ bindings: [String]) throws -> OpaquePointer {
        var result: OpaquePointer?
        guard sqlite3_prepare_v2(handle,sql,-1,&result,nil) == SQLITE_OK, let statement=result else { throw CoreError.database("prepare") }
        let transient=unsafeBitCast(-1,to:sqlite3_destructor_type.self)
        for (index,value) in bindings.enumerated() {
            let code=value.withCString { sqlite3_bind_text(statement,Int32(index+1),$0,-1,transient) }
            if code != SQLITE_OK { sqlite3_finalize(statement); throw CoreError.database("bind") }
        }
        return statement
    }
    private func write(_ sql: String, _ bindings: [String] = []) throws { let s=try statement(sql,bindings);defer{sqlite3_finalize(s)};guard sqlite3_step(s) == SQLITE_DONE else { throw CoreError.database("write") } }
    private func read<T: Decodable>(_ sql: String, _ bindings: [String] = []) throws -> [T] {
        let s=try statement(sql,bindings);defer{sqlite3_finalize(s)};var output:[T]=[]
        while true { let code=sqlite3_step(s); if code == SQLITE_DONE { return output }; guard code == SQLITE_ROW, let text=sqlite3_column_text(s,0) else { throw CoreError.database("read") }; let json=String(cString:text);output.append(try decoder.decode(T.self,from:Data(json.utf8))) }
    }
    private func json<T: Encodable>(_ value: T) throws -> String { String(decoding:try encoder.encode(value),as:UTF8.self) }
    private func transaction(_ action: () throws -> Void) throws { try execute("BEGIN IMMEDIATE");do{try action();try execute("COMMIT")}catch{try? execute("ROLLBACK");throw error} }
    public func records() throws -> [Record] { try read("SELECT json FROM entities") }
    public func history() throws -> [Activity] { try read("SELECT json FROM activity ORDER BY rowid DESC") }
    public func preferences() throws -> Preferences { try read("SELECT json FROM settings WHERE key='profile'").first ?? Preferences() }
    public func setPreferences(_ preferences: Preferences) throws { try write("INSERT OR REPLACE INTO settings(key,json) VALUES('profile',?)",[json(preferences)]) }
    private func put(_ record: Record) throws { try write("INSERT OR REPLACE INTO entities(id,space,kind,status,json) VALUES(?,?,?,?,?)",[record.id,record.space,record.kind,record.status,json(record)]) }
    public func save(_ record: Record, action: String = "Updated") throws {
        guard record.valid else { throw CoreError.invalidRecord }
        try transaction { /* UPSERT preserves attachment foreign keys. */
            try write("INSERT INTO entities(id,space,kind,status,json) VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET space=excluded.space,kind=excluded.kind,status=excluded.status,json=excluded.json",[record.id,record.space,record.kind,record.status,json(record)])
            let activity=Activity(record:record,action:action)
            try write("INSERT INTO activity(id,json) VALUES(?,?)",[activity.id,json(activity)])
            try write("DELETE FROM settings WHERE key=?",["edit:"+record.id])
        }
    }
    public func delete(_ record: Record) throws { try transaction { try write("DELETE FROM entities WHERE id=?",[record.id]);try write("DELETE FROM settings WHERE key=?",["edit:"+record.id]);let event=Activity(record:record,action:"Deleted");try write("INSERT INTO activity(id,json) VALUES(?,?)",[event.id,json(event)]) } }
    public func draft() throws -> Record? { try read("SELECT json FROM settings WHERE key='draft'").first }
    public func setDraft(_ record: Record?) throws { if let record { try write("INSERT OR REPLACE INTO settings(key,json) VALUES('draft',?)",[json(record)]) } else { try write("DELETE FROM settings WHERE key='draft'") } }
    public func editDraft(recordID:String) throws -> Record? { try read("SELECT json FROM settings WHERE key=?",["edit:"+recordID]).first }
    public func setEditDraft(_ record:Record) throws { try write("INSERT OR REPLACE INTO settings(key,json) VALUES(?,?)",["edit:"+record.id,json(record)]) }
    public func attachments(recordID: String? = nil) throws -> [Attachment] { if let id=recordID { return try read("SELECT json FROM attachments WHERE entity_id=?",[id]) };return try read("SELECT json FROM attachments") }
    public func attach(_ attachment: Attachment) throws { guard attachment.bytes != nil else{throw CoreError.invalidBackup};try write("INSERT INTO attachments(id,entity_id,json) VALUES(?,?,?)",[attachment.id,attachment.entityId,json(attachment)]) }
    public func backup() throws -> Backup { Backup(items:try records(),settings:try preferences(),activity:try history(),attachments:try attachments()) }
    public func backupData() throws -> Data { let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];return try e.encode(backup()) }
    public func restore(_ data: Data) throws {
        let backup=try decoder.decode(Backup.self,from:data);try backup.validate()
        try transaction {
            try write("DELETE FROM attachments");try write("DELETE FROM entities");try write("DELETE FROM activity");try write("DELETE FROM settings")
            for item in backup.items { try put(item) }
            for activity in backup.activity { try write("INSERT INTO activity(id,json) VALUES(?,?)",[activity.id,json(activity)]) }
            try setPreferences(backup.settings)
            for file in backup.attachments { try attach(file) }
        }
    }
    public func merge(_ incoming: [Record]) throws -> Int {
        guard incoming.allSatisfy(\.valid) else{throw CoreError.invalidRecord}
        func key(_ r:Record)->String { "\(r.space):\(r.kind):\(r.title.trimmingCharacters(in:.whitespacesAndNewlines).lowercased())" }
        var keys=Set(try records().map(key));var ids=Set(try records().map(\.id));var count=0
        try transaction { for var r in incoming where !keys.contains(key(r)) { if ids.contains(r.id) { r.id=UUID().uuidString };try put(r);keys.insert(key(r));ids.insert(r.id);let event=Activity(record:r,action:"Imported");try write("INSERT INTO activity(id,json) VALUES(?,?)",[event.id,json(event)]);count += 1 } }
        return count
    }
    public func snapshot(directory: URL, now: Date = Date()) throws {
        let files=FileManager.default;try files.createDirectory(at:directory,withIntermediateDirectories:true)
        let name="ediz-\(Time.string(now).prefix(10)).json";let url=directory.appendingPathComponent(name)
        if !files.fileExists(atPath:url.path) { try backupData().write(to:url,options:.atomic) }
        let snapshots=try files.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil).filter{$0.lastPathComponent.hasPrefix("ediz-") && $0.pathExtension == "json"}.sorted{$0.lastPathComponent<$1.lastPathComponent}
        for stale in snapshots.dropLast(7) { try files.removeItem(at:stale) }
    }
}
