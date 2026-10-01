import Foundation
import Combine
import UIKit
import EdizCore

@MainActor final class NativeStore: ObservableObject {
    @Published var records: [EdizCore.Record] = []
    @Published var activity: [Activity] = []
    @Published var preferences = Preferences()
    @Published var error: String?
    @Published var captureRequest: EdizCore.Record?
    @Published var focusRequest: EdizCore.Record?
    @Published var undoRecord: EdizCore.Record?
    @Published var ready = false
    private(set) var database: Database?
    private let root: URL
    init() {
        let base=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("EdizOS",isDirectory:true)
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            let id=(ProcessInfo.processInfo.environment["EDIZ_UI_TEST_ID"] ?? "default").filter{$0.isLetter || $0.isNumber || $0 == "-"}
            root=base.appendingPathComponent("UITests",isDirectory:true).appendingPathComponent(id.isEmpty ? "default":id,isDirectory:true)
            if ProcessInfo.processInfo.arguments.contains("-reset-test-data"){try? FileManager.default.removeItem(at:root)}
        } else { root=base }
        open()
    }
    func open() {
        do {
            let database = try Database(url:root.appendingPathComponent("ediz.sqlite"))
            self.database = database
            try reload()
            try database.snapshot(directory:root.appendingPathComponent("Snapshots"))
            try? FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:root.path)
            ready = true
        } catch { self.error = error.localizedDescription }
    }
    func reload() throws {
        guard let database else { throw CoreError.database("unavailable") }
        records = try database.records(); activity = try database.history(); preferences = try database.preferences()
    }
    @discardableResult func save(_ record: EdizCore.Record, action: String = "Updated") -> Bool {
        do { guard let database else{throw CoreError.database("unavailable")};var copy=record;copy.updated=Time.string(Date());try database.save(copy,action:action);try reload();UISelectionFeedbackGenerator().selectionChanged();return true }
        catch { self.error=error.localizedDescription;return false }
    }
    func complete(_ record: EdizCore.Record) { var copy=record;copy.status="done";if save(copy,action:"Completed"){undoRecord=record;UINotificationFeedbackGenerator().notificationOccurred(.success)} }
    func undo() { guard let record=undoRecord else{return};if save(record,action:"Reopened"){undoRecord=nil} }
    @discardableResult func remove(_ record: EdizCore.Record) -> Bool { do { guard let database else{throw CoreError.database("unavailable")};try database.delete(record);try reload();return true }catch{self.error=error.localizedDescription;return false} }
    func capture(space: String? = nil, kind: String? = nil) {
        do {
            if space == nil && kind == nil, let draft=try database?.draft() { captureRequest=draft;return }
            var record=EdizCore.Record(space:space ?? "personal",kind:kind ?? "task",title:"")
            if space == nil { record.data["_captureAuto"]="1" }
            captureRequest=record
        } catch { self.error=error.localizedDescription }
    }
    func draft(_ record: EdizCore.Record?) { do{try database?.setDraft(record)}catch{self.error="Your draft could not be saved. Keep the capture open."} }
    func editDraft(_ record:EdizCore.Record) { do{try database?.setEditDraft(record)}catch{self.error="Your edits could not be kept. Keep this screen open and try saving."} }
    func configureModel(enabled:Bool?=nil,endpoint:String?=nil){
        var next=preferences;if let enabled{next.labs=enabled};if let endpoint{next.localEndpoint=endpoint}
        do{guard let database else{throw CoreError.database("unavailable")};try database.setPreferences(next);preferences=next}catch{self.error=error.localizedDescription}
    }
    func setFocus(_ space: String) { var next=preferences;next.focus=space;setPreferences(next) }
    func setPreferences(_ next: Preferences) { do{try database?.setPreferences(next);preferences=next}catch{self.error=error.localizedDescription} }
    func export() throws -> URL {
        guard let database else{throw CoreError.database("unavailable")}
        let data=try database.backupData()
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("EdizExports",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let url=folder.appendingPathComponent("ediz-os-\(Time.string(Date()).prefix(10)).json")
        try data.write(to:url,options:[.atomic,.completeFileProtection])
        return url
    }
    func markBackupShared() { var next=preferences;next.lastBackup=Time.string(Date());setPreferences(next) }
    func exportProfile() throws -> URL {
        let settings=try JSONSerialization.jsonObject(with:JSONEncoder().encode(preferences))
        let spaces=Catalog.spaces.map{space in ["id":space.id,"name":space.name,"modules":space.modules.map{["kind":$0.kind,"label":$0.label]}] as [String:Any]}
        let data=try JSONSerialization.data(withJSONObject:["format":"ediz-profile","version":1,"spaces":spaces,"settings":settings],options:[.prettyPrinted,.sortedKeys])
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("ediz-profile.json")
        try data.write(to:url,options:[.atomic,.completeFileProtection]);return url
    }
    func restore(_ data: Data) -> Bool {
        do { guard let database else{throw CoreError.database("unavailable")};try database.snapshot(directory:root.appendingPathComponent("BeforeRestore-\(UUID().uuidString)"));try database.restore(data);try reload();return true }catch{self.error=error.localizedDescription;return false}
    }
    func merge(_ items: [EdizCore.Record]) -> Bool { do{guard let database else{throw CoreError.database("unavailable")};_ = try database.merge(items);try reload();return true}catch{self.error=error.localizedDescription;return false} }
    func remember(_ record: EdizCore.Record) { var next=preferences;next.recentId=record.id;setPreferences(next) }
    var priorities: [Recommendation] { Priority.rank(records,focus:preferences.focus) }
    var recent: EdizCore.Record? { records.first{$0.id == preferences.recentId} }
    func fileURL(_ attachment: Attachment) throws -> URL {
        guard let bytes=attachment.bytes else{throw CoreError.invalidBackup}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("EdizFiles",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let name=URL(fileURLWithPath:attachment.name).lastPathComponent
        let url=folder.appendingPathComponent("\(UUID().uuidString)-\(name)")
        try bytes.write(to:url,options:[.atomic,.completeFileProtection]);return url
    }
}
