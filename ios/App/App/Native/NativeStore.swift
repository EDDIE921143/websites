import Foundation
import Combine
import UIKit
import Security
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
    @Published var assistantConnected=false
    var assistantToken:String? {let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"EdizOSAssistant",kSecAttrAccount as String:"device",kSecReturnData as String:true];var value:CFTypeRef?;guard SecItemCopyMatching(query as CFDictionary,&value)==errSecSuccess,let data=value as? Data else{return nil};return String(data:data,encoding:.utf8)}
    func connectAssistant(_ url:URL){guard url.scheme == "edizos",url.host == "assistant",let token=URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first(where:{$0.name == "token"})?.value,token.count == 64,token.allSatisfy({$0.isHexDigit}) else{return};let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"EdizOSAssistant",kSecAttrAccount as String:"device"];SecItemDelete(query as CFDictionary);var item=query;item[kSecValueData as String]=Data(token.utf8);item[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly;if SecItemAdd(item as CFDictionary,nil)==errSecSuccess{assistantConnected=true;loadContext()}else{error="This device could not connect to the assistant."}}
    func loadContext(){guard let token=assistantToken else{return};Task{@MainActor in do{var request=URLRequest(url:URL(string:"https://ediz-os.vercel.app/api/assistant?context=1")!);request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization");let (data,response)=try await URLSession.shared.data(for:request);guard (response as? HTTPURLResponse)?.statusCode == 200 else{return};let context=try JSONDecoder().decode(WorkspaceContextBundle.self,from:data);let additions=context.items.filter{item in item.valid && item.kind == "note" && item.id.hasPrefix("ediz-context-") && !records.contains(where:{$0.id == item.id})};if !additions.isEmpty{_ = merge(additions)}}catch{error="Your workspace context could not be downloaded. Try connecting again when online."}}}
    func open() {
        do {
            let database = try Database(url:root.appendingPathComponent("ediz.sqlite"))
            self.database = database
            try reload()
            try database.snapshot(directory:root.appendingPathComponent("Snapshots"))
            try? FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:root.path)
            ready = true
            loadContext()
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
            if let space,let kind,let draft=try database?.creationDraft(space:space,kind:kind) { captureRequest=draft;return }
            var record=EdizCore.Record(space:space ?? "personal",kind:kind ?? "task",title:"")
            if kind != nil { record.data["_creation"]="1" }
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
    var recent: EdizCore.Record? {
        let open=records.filter{!["done","archived","REJECTED","Lost"].contains($0.status)}
        let saved=open.first{$0.id == preferences.recentId}
        if preferences.focus == "all" || saved?.space == preferences.focus{return saved}
        for entry in activity.sorted(by:{$0.at>$1.at}){if let record=open.first(where:{$0.id == entry.entityId && $0.space == preferences.focus}){return record}}
        return saved
    }
    func fileURL(_ attachment: Attachment) throws -> URL {
        guard let bytes=attachment.bytes else{throw CoreError.invalidBackup}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("EdizFiles",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let name=URL(fileURLWithPath:attachment.name).lastPathComponent
        let url=folder.appendingPathComponent("\(UUID().uuidString)-\(name)")
        try bytes.write(to:url,options:[.atomic,.completeFileProtection]);return url
    }
}

private struct WorkspaceContextBundle:Decodable{let items:[EdizCore.Record]}
