import SwiftUI
import EdizCore

struct AssistantCard:Codable,Identifiable {
    var id:String{type+title}
    let type:String
    let title:String
    var subtitle:String?
    var items:[AssistantCardItem]
    var purpose:String?
}
struct AssistantCardItem:Codable,Identifiable {
    var id:String{title+(detail ?? "")}
    let title:String
    var detail:String?
    var meta:String?
    var recordId:String?
}
struct ChatThread:Codable,Identifiable {
    var id=UUID()
    var title="New conversation"
    var titled=false
    var created=Date()
    var updated=Date()
    var entries:[ConversationEntry]=[]
}
struct ChatShelf:Codable {
    var active:UUID?
    var threads:[ChatThread]=[]
}
extension NativeStore {
    func chatShelf(_ scope:String)->ChatShelf {
        guard let text=preferences.assistantChats["history:"+scope],let data=text.data(using:.utf8),let shelf=try? JSONDecoder().decode(ChatShelf.self,from:data) else{return ChatShelf()}
        return shelf
    }
    func saveShelf(_ shelf:ChatShelf,scope:String){
        do{let data=try JSONEncoder().encode(shelf);var next=preferences;next.assistantChats["history:"+scope]=String(decoding:data,as:UTF8.self);if let active=shelf.threads.first(where:{$0.id == shelf.active}){next.assistantChats[scope]=String(decoding:try JSONEncoder().encode(active.entries),as:UTF8.self)}else{next.assistantChats.removeValue(forKey:scope)};setPreferences(next)}catch{self.error="Your conversation couldn’t be saved. Please keep the chat open."}
    }
    func openThread(scope:String,new:Bool=false)->UUID {
        var shelf=chatShelf(scope)
        if shelf.threads.isEmpty,!conversation(scope).isEmpty{var old=ChatThread();old.entries=conversation(scope);old.title="Earlier conversation";shelf.threads=[old];shelf.active=old.id}
        if !new,let active=shelf.active,shelf.threads.contains(where:{$0.id == active}){saveShelf(shelf,scope:scope);return active}
        let thread=ChatThread();shelf.threads.append(thread);shelf.active=thread.id;saveShelf(shelf,scope:scope);return thread.id
    }
    func selectThread(_ id:UUID,scope:String){var shelf=chatShelf(scope);guard shelf.threads.contains(where:{$0.id == id}) else{return};shelf.active=id;saveShelf(shelf,scope:scope)}
    func saveThread(_ entries:[ConversationEntry],id:UUID,scope:String){var shelf=chatShelf(scope);guard let index=shelf.threads.firstIndex(where:{$0.id == id}) else{return};shelf.threads[index].entries=Array(entries.suffix(60));shelf.threads[index].updated=Date();shelf.active=id;saveShelf(shelf,scope:scope)}
    func nameThread(_ id:UUID,scope:String,title:String){var shelf=chatShelf(scope);guard let index=shelf.threads.firstIndex(where:{$0.id == id}) else{return};let clean=title.trimmingCharacters(in:.whitespacesAndNewlines);guard !clean.isEmpty else{return};shelf.threads[index].title=String(clean.prefix(80));shelf.threads[index].titled=true;saveShelf(shelf,scope:scope)}
    func deleteThread(_ id:UUID,scope:String){var shelf=chatShelf(scope);shelf.threads.removeAll{$0.id == id};if shelf.active == id{shelf.active=shelf.threads.sorted{$0.updated>$1.updated}.first?.id};saveShelf(shelf,scope:scope)}
    func searchableMemories()->[EdizCore.Record] {
        var corpus=records
        for scope in ["all"]+Catalog.spaces.map(\.id) {
            for thread in chatShelf(scope).threads where !thread.entries.isEmpty {
                var item=EdizCore.Record(space:scope == "all" ? "personal":scope,kind:"note",title:thread.title)
                item.id="chat:"+scope+":"+thread.id.uuidString;item.created=Time.string(thread.created);item.updated=Time.string(thread.updated)
                item.body=String(thread.entries.map{($0.role == "user" ? "Ediz: ":"Assistant: ")+$0.contextText}.joined(separator:"\n").suffix(12000));item.data["_chatScope"]=scope;item.data["_chatID"]=thread.id.uuidString;corpus.append(item)
            }
        }
        return corpus.sorted{$0.updated>$1.updated}
    }
}
struct NativeConversationHost:View {
    @EnvironmentObject var store:NativeStore
    let scope:String
    var initialID:UUID?=nil
    var new=false
    @State private var threadID:UUID?
    @State private var question=""
    @State private var titleJob:Task<Void,Never>?
    @State private var naming=Set<UUID>()
    var thread:ChatThread?{store.chatShelf(scope).threads.first{$0.id == threadID}}
    var body:some View {
        Group {
            if let id=threadID {
                NativeAssistantChat(entries:Binding(get:{thread?.entries ?? []},set:{store.saveThread($0,id:id,scope:scope)}),question:$question,scope:scope,threadID:id,selectThread:{id in question="";store.selectThread(id,scope:scope);threadID=id}).id(id)
                    .onChange(of:thread?.entries.count){_,_ in nameIfReady()}
            } else {ProgressView().frame(maxWidth:.infinity,maxHeight:.infinity)}
        }.onAppear{if threadID == nil{if let initialID{store.selectThread(initialID,scope:scope);threadID=initialID}else{threadID=store.openThread(scope:scope,new:new)}};nameIfReady()}.onDisappear{titleJob?.cancel()}
    }
    func nameIfReady(){
        guard let thread,!thread.titled,!naming.contains(thread.id),thread.entries.last?.role == "assistant",let token=store.assistantToken else{return}
        let meaningful=thread.entries.filter{$0.role == "user" && $0.text.count>12 && !["hello","hi","hey","hallo","hi again","hello again","testing"].contains($0.text.lowercased().trimmingCharacters(in:.whitespacesAndNewlines))}
        guard meaningful.count>=2 || (meaningful.first?.text.split(separator:" ").count ?? 0)>=14 else{return}
        naming.insert(thread.id)
        titleJob=Task{@MainActor in do{let reply=try await GeminiAssistant.answer(question:"Give this conversation a specific title.",records:[],conversation:thread.entries,token:token,scope:scope,requestMode:"chat-title");guard !Task.isCancelled else{naming.remove(thread.id);return};store.nameThread(thread.id,scope:scope,title:reply.text)}catch{naming.remove(thread.id)}}
    }
}
struct NativeChatHistory:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) private var dismiss
    let scope:String
    var current:UUID?=nil
    var select:((UUID)->Void)?=nil
    @State private var query=""
    @State private var deleting:ChatThread?
    var threads:[ChatThread]{store.chatShelf(scope).threads.filter{!$0.entries.isEmpty && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.entries.contains{$0.text.localizedCaseInsensitiveContains(query)})}.sorted{$0.updated>$1.updated}}
    var body:some View {
        List {
            Section {VStack(alignment:.leading,spacing:8){Text("Conversations worth coming back to.").font(.title2.weight(.medium));Text(scope == "all" ? "Everyday":Catalog.space(scope).name).font(.subheadline).foregroundStyle(WorkspaceTheme.accent(scope))}.padding(.vertical,10).listRowBackground(Color.clear)}
            Section {
                if let select{Button{let id=store.openThread(scope:scope,new:true);select(id)}label:{Label("New chat",systemImage:"square.and.pencil")}.accessibilityIdentifier("chat-new")}
                else{NavigationLink{NativeConversationHost(scope:scope,new:true)}label:{Label("New chat",systemImage:"square.and.pencil")}.accessibilityIdentifier("chat-new")}
            }
            Section {
                if threads.isEmpty{QuietEmpty(title:"Room for a conversation.",message:"Your chats will appear here once you start talking.")}
                ForEach(threads){thread in
                    Group {if let select{Button{select(thread.id)}label:{row(thread)}}else{NavigationLink{NativeConversationHost(scope:scope,initialID:thread.id)}label:{row(thread)}}}
                        .accessibilityIdentifier("chat-thread-"+thread.id.uuidString)
                        .swipeActions{Button(role:.destructive){deleting=thread}label:{Label("Delete",systemImage:"trash")}}
                }
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(AppBackdrop(scope:scope)).navigationTitle("Chats").navigationBarTitleDisplayMode(.inline).searchable(text:$query,prompt:"Find a conversation")
            .alert("Delete this conversation?",isPresented:Binding(get:{deleting != nil},set:{if !$0{deleting=nil}})){Button("Keep chat",role:.cancel){deleting=nil};Button("Delete chat",role:.destructive){if let deleting{store.deleteThread(deleting.id,scope:scope);if deleting.id == current,let select{select(store.chatShelf(scope).active ?? store.openThread(scope:scope,new:true))}};deleting=nil}}message:{Text("Your workspace records are kept. This removes only this conversation.")}
            .onAppear{if store.chatShelf(scope).threads.isEmpty && !store.conversation(scope).isEmpty{_=store.openThread(scope:scope)}}
            .toolbar{if select != nil{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}}
    }
    func row(_ thread:ChatThread)->some View {HStack(alignment:.top,spacing:12){Image(systemName:current == thread.id ? "bubble.left.and.bubble.right.fill":"bubble.left").foregroundStyle(WorkspaceTheme.accent(scope)).padding(.top,3);VStack(alignment:.leading,spacing:7){Text(thread.title).font(.headline).foregroundStyle(Design.ink);Text(thread.entries.last?.text ?? "").font(.subheadline).foregroundStyle(Design.muted).lineLimit(2);Text(thread.updated,format:.dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(Design.muted)}.padding(.vertical,7);Spacer(minLength:0)}}
}
struct AssistantResultCard:View {
    @EnvironmentObject var store:NativeStore
    let card:AssistantCard
    let scope:String
    var onOpen:()->Void = {}
    @State private var selected:EdizCore.Record?
    var saved:Bool{!card.items.isEmpty && card.items.allSatisfy{$0.recordId != nil}}
    var category:String{saved ? "From your saved work":card.type == "songs" ? "Song suggestions":card.type == "practice" ? "Generated practice plan":card.type == "outline" ? "Draft outline":"Generated list"}
    var body:some View {
        VStack(alignment:.leading,spacing:14){
            HStack(spacing:12){Image(systemName:card.type == "songs" ? "music.note.list":card.type == "practice" ? "metronome":card.type == "outline" ? "book.pages":"list.bullet.rectangle").font(.title3).foregroundStyle(WorkspaceTheme.accent(scope));VStack(alignment:.leading,spacing:5){Text(category).font(.caption).foregroundStyle(Design.muted);Text(card.title).font(.headline.weight(.medium));if let subtitle=card.subtitle{Text(subtitle).font(.caption).foregroundStyle(Design.muted)}};Spacer(minLength:0)}
            ForEach(Array(card.items.enumerated()),id:\.offset){index,item in
                HStack(alignment:.top,spacing:12){Text(String(format:"%02d",index+1)).font(.caption.monospacedDigit().weight(.medium)).foregroundStyle(WorkspaceTheme.accent(scope)).frame(width:25,alignment:.leading).padding(.top,3);VStack(alignment:.leading,spacing:5){Text(item.title).font(.body.weight(.medium)).fixedSize(horizontal:false,vertical:true);if let detail=item.detail{Text(detail).font(.subheadline).foregroundStyle(Design.muted).fixedSize(horizontal:false,vertical:true)};if let meta=item.meta{Text(meta).font(.caption.weight(.medium)).foregroundStyle(WorkspaceTheme.accent(scope))}};Spacer(minLength:0)}
                if let id=item.recordId{if let record=store.records.first(where:{$0.id == id}){Button{onOpen();selected=record}label:{Label("Open saved item",systemImage:"arrow.up.right.square").font(.subheadline)}.accessibilityIdentifier("assistant-card-record-"+id)}else{Text("This saved item is no longer available.").font(.caption).foregroundStyle(Design.muted)}}
                if index<card.items.count-1{Divider().opacity(0.35)}
            }
        }.padding(18).frame(maxWidth:.infinity,alignment:.leading).foregroundStyle(Design.ink).background{if card.items.count<=6{RoundedRectangle(cornerRadius:18).fill(Design.surface)}}.overlay{if card.items.count<=6{RoundedRectangle(cornerRadius:18).strokeBorder(WorkspaceTheme.accent(scope).opacity(0.12),lineWidth:1)}}.sheet(item:$selected){record in NavigationStack{NativeEditor(record:record)}}
    }
}
