import Foundation
import Combine
import UIKit
import Security
import EdizCore

@MainActor final class NativeStore: ObservableObject {
    private(set) var originalManuscript:[EdizCore.Record]=[]
    @Published var records: [EdizCore.Record] = []
    @Published var activity: [Activity] = []
    @Published var preferences = Preferences()
    @Published var error: String?
    @Published var captureRequest: EdizCore.Record?
    @Published var focusRequest: EdizCore.Record?
    @Published var undoRecord: EdizCore.Record?
    @Published var lastCreatedRecordID:String?
    @Published var lastRefresh:Date?
    @Published var ready = false
    private(set) var database: Database?
    private let root: URL
    let isPractice:Bool
    weak var walkthrough:WalkthroughSession?
    init(practice:Bool=false) {
        isPractice=practice
        let base=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("EdizOS",isDirectory:true)
        if practice { root=FileManager.default.temporaryDirectory.appendingPathComponent("EdizPractice-"+UUID().uuidString,isDirectory:true) }
        else if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            let id=(ProcessInfo.processInfo.environment["EDIZ_UI_TEST_ID"] ?? "default").filter{$0.isLetter || $0.isNumber || $0 == "-"}
            root=base.appendingPathComponent("UITests",isDirectory:true).appendingPathComponent(id.isEmpty ? "default":id,isDirectory:true)
            if ProcessInfo.processInfo.arguments.contains("-reset-test-data"){try? FileManager.default.removeItem(at:root)}
        } else { root=base }
        open()
    }
    @Published var assistantConnected=false
    var assistantToken:String? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") && ProcessInfo.processInfo.arguments.contains("-test-voice-fallback"){NativeVoicePreferences.defaults.set(true,forKey:"assistant-offline-voice");return String(repeating:"0",count:64)}
        #endif
        if isPractice || ProcessInfo.processInfo.arguments.contains("-ui-testing"){return nil};let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"EdizOSAssistant",kSecAttrAccount as String:"device",kSecReturnData as String:true];var value:CFTypeRef?;guard SecItemCopyMatching(query as CFDictionary,&value)==errSecSuccess,let data=value as? Data else{return nil};return String(data:data,encoding:.utf8)}
    func connectAssistant(_ url:URL){guard !isPractice,url.scheme == "edizos",url.host == "assistant",let token=URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first(where:{$0.name == "token"})?.value,token.count == 64,token.allSatisfy({$0.isHexDigit}) else{return};let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"EdizOSAssistant",kSecAttrAccount as String:"device"];SecItemDelete(query as CFDictionary);var item=query;item[kSecValueData as String]=Data(token.utf8);item[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly;if SecItemAdd(item as CFDictionary,nil)==errSecSuccess{assistantConnected=true;loadContext()}else{error="This device could not connect to the assistant."}}
    func loadContext() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing"){return}
        guard let token = assistantToken else { return }
        Task { @MainActor in _ = await fetchContext(token) }
    }
    @discardableResult func refresh() async -> Bool {
        do { try reload() } catch { self.error=error.localizedDescription;return false }
        if let token=assistantToken,!(await fetchContext(token)){return false}
        lastRefresh=Date();return true
    }
    private func fetchContext(_ token:String) async -> Bool {
            do {
                var request = URLRequest(url: URL(string: "https://ediz-os.vercel.app/api/assistant?context=1")!);request.timeoutInterval=12
                request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { self.error="Your workspace context could not be refreshed. Your saved work is still here.";return false }
                let context = try JSONDecoder().decode(WorkspaceContextBundle.self, from: data)
                let changes = WorkspaceContext.changes(incoming:context.items,existing:records)
                if !changes.isEmpty,let database {
                    for item in changes { try database.save(item,action:"Context imported") }
                    try reload()
                }
                return true
            } catch {
                self.error = "Your workspace context could not be downloaded. Try connecting again when online."
                return false
            }
    }
    func open() {
        do {
            let database = try Database(url:root.appendingPathComponent("ediz.sqlite"))
            self.database = database
            try reload()
            if !isPractice,!ProcessInfo.processInfo.arguments.contains("-ui-testing"),let url=Bundle.main.url(forResource:"moshia-manuscript",withExtension:"json",subdirectory:"GuideAudio/PrivateContext"),let bytes=try? Data(contentsOf:url),let envelope=(try? JSONSerialization.jsonObject(with:bytes)) as? [String:Any],let items=envelope["items"] as? [[String:Any]]{
                originalManuscript=items.compactMap{item in guard let id=item["id"] as? String,let title=item["title"] as? String,let body=item["body"] as? String else{return nil};var record=EdizCore.Record(space:"moshia",kind:"note",title:title);record.id=id;record.body=body;record.data=item["data"] as? [String:String] ?? [:];return record}
            }
            if !isPractice,!ProcessInfo.processInfo.arguments.contains("-ui-testing"),!records.contains(where:{$0.id == "ediz-context-websites-20261003"}){
                var websites=EdizCore.Record(space:"ejj",kind:"note",title:"Websites project · verified links")
                websites.id="ediz-context-websites-20261003";websites.data["contextType"]="workspace-brief"
                websites.body="The local Websites project contains RELAX CUT, an independent EJJ Digital barbershop demo for Reutlingen, and HSS, an automotive hail-damage concept. RELAX CUT public demo: https://relax-cut-demo.pages.dev . Its booking is simulated, not a live business booking service. HSS is a local project with no verified public URL. Do not invent a live link. Other demos and repositories may exist in separate projects; confirm their current links before sharing them. EJJ Digital’s normal complete website offer is €299."
                try database.save(websites,action:"Context imported");try reload()
            }
            for scope in ["all"]+Catalog.spaces.map(\.id) where chatShelf(scope).threads.isEmpty && !conversation(scope).isEmpty{_=openThread(scope:scope)}
            try database.snapshot(directory:root.appendingPathComponent("Snapshots"))
            try? FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:root.path)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-testing") && ProcessInfo.processInfo.arguments.contains("-test-call-results"){
                let id=openThread(scope:"band");let card=AssistantCard(type:"songs",title:"Friday practice ideas",subtitle:"Suggestions to try together",items:[AssistantCardItem(title:"Everlong",detail:"Foo Fighters · Work on steady dynamics"),AssistantCardItem(title:"Seven Nation Army",detail:"The White Stripes · Keep the riff locked in"),AssistantCardItem(title:"Come As You Are",detail:"Nirvana · Listen to the guitar phrasing")]);saveThread([ConversationEntry(role:"user",text:"Suggest rock songs for Friday"),ConversationEntry(role:"assistant",text:"Here are three ideas to try together.",provider:"CLEARANCE 19 Bot",cards:[card],spokenText:"I’ve put three ideas on your screen. Which would you like to start with?")],id:id,scope:"band");nameThread(id,scope:"band",title:"Friday practice ideas")
            }
            if ProcessInfo.processInfo.arguments.contains("-ui-testing") && ProcessInfo.processInfo.arguments.contains("-test-call-saved-results"){
                let record=EdizCore.Record(space:"band",kind:"note",title:"Saved Friday rehearsal");_ = save(record)
                let proposal=GeminiProposal(type:"create",title:"Prepare Saturday rehearsal",fields:GeminiFields(space:"band",kind:"rehearsal",title:"Prepared Saturday rehearsal"))
                let id=openThread(scope:"band");saveThread([ConversationEntry(role:"user",text:"Find my rehearsal and prepare a new one"),ConversationEntry(role:"assistant",text:"Here is your saved Friday rehearsal and a Saturday plan to review.",records:[record],actions:[proposal],provider:"CLEARANCE 19 Bot")],id:id,scope:"band")
            }
            if ProcessInfo.processInfo.arguments.contains("-ui-testing") && ProcessInfo.processInfo.arguments.contains("-test-long-chat-result"){
                let id=openThread(scope:"band");let items=(1...24).map{number in AssistantCardItem(title:"Practice idea \(number) · A longer title that should wrap without losing its meaning.",detail:"A complete explanation with enough detail to verify that a large result remains readable from its first item through its last item.")}
                let card=AssistantCard(type:"practice",title:"Complete rehearsal plan",items:items)
                saveThread([ConversationEntry(role:"user",text:"Show the whole practice plan"),ConversationEntry(role:"assistant",text:"Here is the complete plan.",provider:"CLEARANCE 19 Bot",cards:[card])],id:id,scope:"band")
            }
            #endif
            ready = true
            assistantConnected = assistantToken != nil
            loadContext()
        } catch { self.error = error.localizedDescription }
    }
    func reload() throws {
        guard let database else { throw CoreError.database("unavailable") }
        records = try database.records(); activity = try database.history(); preferences = try database.preferences()
    }
    @discardableResult func save(_ record: EdizCore.Record, action: String = "Updated") -> Bool {
        do { guard let database else{throw CoreError.database("unavailable")};var copy=record;copy.updated=Time.string(Date());try database.save(copy,action:action);try reload();if action == "Created"{lastCreatedRecordID=copy.id};UISelectionFeedbackGenerator().selectionChanged();walkthrough?.event("saved-"+copy.kind);return true }
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
    func conversation(_ scope:String)->[ConversationEntry] {
        guard let json=preferences.assistantChats[scope],let data=json.data(using:.utf8) else{return []}
        return (try? JSONDecoder().decode([ConversationEntry].self,from:data)) ?? []
    }
    func keepMemo(_ file:AssistantAttachment) throws -> AssistantAttachmentInfo {
        var info=AssistantAttachmentInfo(name:file.name,mimeType:file.mimeType)
        guard file.mimeType.hasPrefix("audio/") else{return info}
        let directory=root.appendingPathComponent("ChatMemos",isDirectory:true);try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let name=file.id.uuidString+".wav";try file.bytes.write(to:directory.appendingPathComponent(name),options:[.atomic,.completeFileProtection]);info.localFile=name;return info
    }
    func memoURL(_ file:AssistantAttachmentInfo) throws -> URL {
        guard let name=file.localFile,name.hasSuffix(".wav"),UUID(uuidString:String(name.dropLast(4))) != nil else{throw CoreError.database("Recording unavailable")}
        let url=root.appendingPathComponent("ChatMemos",isDirectory:true).appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath:url.path) else{throw CoreError.database("Recording unavailable")};return url
    }
    func saveConversation(_ entries:[ConversationEntry],scope:String) {
        do {
            let data=try JSONEncoder().encode(Array(entries.suffix(40)))
            var next=preferences;next.assistantChats[scope]=String(decoding:data,as:UTF8.self)
            setPreferences(next)
        }catch{self.error="This conversation could not be saved. Your records are unchanged."}
    }
    func setPreferences(_ next: Preferences) { do{try database?.setPreferences(next);preferences=next;walkthrough?.event("density-"+next.density);walkthrough?.event("focus-"+next.focus)}catch{self.error=error.localizedDescription} }
    func discardPractice(){guard isPractice else{return};database=nil;try? FileManager.default.removeItem(at:root)}
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
        var profile=preferences;profile.assistantChats=[:]
        let settings=try JSONSerialization.jsonObject(with:JSONEncoder().encode(profile))
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
