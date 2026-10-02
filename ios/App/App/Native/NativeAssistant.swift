import SwiftUI
import EdizCore

struct ConversationEntry:Identifiable {
    let id=UUID()
    let role:String
    let text:String
    var records:[EdizCore.Record]=[]
    var draft:EdizCore.Record?
    var actions:[GeminiProposal]=[]
}
enum LocalAssistant {
    static func baseURL(_ endpoint:String) throws -> URL {
        guard let url=URL(string:endpoint),let host=url.host?.lowercased(),url.scheme == "http" || url.scheme == "https" else{throw URLError(.badURL)}
        let parts=host.split(separator:".").compactMap{Int($0)}
        let privateHost=host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".local") || (parts.count == 4 && (parts[0] == 10 || (parts[0] == 192 && parts[1] == 168) || (parts[0] == 172 && (16...31).contains(parts[1]))))
        guard privateHost, url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else{throw URLError(.unsupportedURL)}
        return url.path.isEmpty || url.path == "/" ? url.appendingPathComponent("v1") : url
    }
    static func models(endpoint:String) async throws -> [String] {
        let url=try baseURL(endpoint).appendingPathComponent("models")
        var request=URLRequest(url:url);request.timeoutInterval=8
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let response=response as? HTTPURLResponse,(200...299).contains(response.statusCode),
              let root=try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let list=root["data"] as? [[String:Any]] else{throw URLError(.cannotParseResponse)}
        let names=list.compactMap{$0["id"] as? String}.filter{!$0.isEmpty}
        guard !names.isEmpty else{throw URLError(.resourceUnavailable)}
        return names
    }
    static func answer(endpoint:String,question:String,context:[EdizCore.Record],conversation:[ConversationEntry]) async throws -> String {
        var url=try baseURL(endpoint)
        let available=try await models(endpoint:endpoint)
        url.appendPathComponent("chat/completions")
        let json=String(decoding:try JSONEncoder().encode(context),as:UTF8.self)
        var messages:[[String:String]]=[["role":"system","content":"You are Ediz’s personal assistant inside Ediz OS. Be calm, useful and concise. Use only the supplied records for facts. POSSIBLE and PLANNED fiction records are not canon. Explain next steps and uncertainty. Never claim to edit, delete, schedule or save anything. Changes must be reviewed in the app. Do not write novel prose unless explicitly asked. Local records: "+json]]
        messages += conversation.suffix(8).map{["role":$0.role,"content":$0.text]}
        messages.append(["role":"user","content":question])
        var request=URLRequest(url:url);request.httpMethod="POST";request.timeoutInterval=35
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.httpBody=try JSONSerialization.data(withJSONObject:["model":available[0],"messages":messages,"temperature":0.4,"max_tokens":500])
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let response=response as? HTTPURLResponse,(200...299).contains(response.statusCode),let root=try JSONSerialization.jsonObject(with:data) as? [String:Any],let choices=root["choices"] as? [[String:Any]],let message=choices.first?["message"] as? [String:Any],let text=message["content"] as? String,!text.isEmpty else{throw URLError(.cannotParseResponse)}
        return text
    }
}
struct NativeAssistant:View {
    @EnvironmentObject var store:NativeStore
    @State private var entries:[ConversationEntry]=[]
    @State private var proposal:GeminiProposal?
    @State private var cloud=true
    @State private var scope="all"
    var scopedRecords:[EdizCore.Record]{store.records.filter{scope == "all" || $0.space == scope}}
    @State private var question=""
    @State private var busy=false
    @State private var model=false
    @State private var message:String?
    @FocusState private var typing:Bool
    var body:some View {
        ScrollViewReader{reader in
            ScrollView{conversation}
                .scrollDismissesKeyboard(.interactively)
                .onChange(of:entries.count){_,_ in if let id=entries.last?.id{reader.scrollTo(id,anchor:.bottom)}}
                .safeAreaInset(edge:.bottom){composer}
        }.sheet(item:$proposal){action in NativeAssistantReview(action:action)}.background(Design.background).navigationTitle("Assistant").navigationBarTitleDisplayMode(.inline)
    }
    var conversation:some View {
        VStack(alignment:.leading,spacing:14){
            Surface{VStack(alignment:.leading,spacing:14){Label("Here with you, Ediz.",systemImage:"bubble.left.and.bubble.right.fill").font(Design.font(22));Text("Choose a perspective for your work.").font(.subheadline).foregroundStyle(Design.muted);LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10){GlassAction{Button("Everyday"){scope="all";entries=[]}.frame(maxWidth:.infinity,minHeight:48)};ForEach(Catalog.spaces){space in GlassAction{Button{scope=space.id;entries=[]}label:{HStack{SpaceMark(space:space);Text(space.name).font(Design.font(12))}.frame(maxWidth:.infinity,minHeight:48)}}}};Text(scope == "all" ? "All spaces":Catalog.space(scope).name).font(.caption).foregroundStyle(Design.muted)}}
            if entries.isEmpty {
                Text("Let’s make room for what matters, Ediz.").font(Design.font(21,relativeTo:.title3)).padding(.top,12)
                Text(Priority.briefing(store.records,focus:store.preferences.focus)).font(Design.font(16,weight:"Regular")).foregroundStyle(Design.muted)
                VStack(spacing:9){forPrompt("What should I focus on?");forPrompt("Plan tomorrow");forPrompt("Any loose ends?")}
            }
            ForEach(entries){entry in entryView(entry).id(entry.id)}
            if busy{HStack(spacing:9){ProgressView();Text("Thinking through your context…").font(.subheadline).foregroundStyle(Design.muted)}}
            if let message{Text(message).font(.footnote).foregroundStyle(Design.muted)}
        }.padding(20)
    }
    @ViewBuilder func entryView(_ entry:ConversationEntry)->some View {
        VStack(alignment:entry.role == "user" ? .trailing:.leading,spacing:10){
            if entry.role == "user" {
                Text(entry.text).font(Design.font(16,weight:"Regular")).padding(14).background(.regularMaterial,in:RoundedRectangle(cornerRadius:23)).frame(maxWidth:.infinity,alignment:.trailing)
            } else {
                VStack(alignment:.leading,spacing:10){Text(entry.text).font(Design.font(16,weight:"Regular")).lineSpacing(3).textSelection(.enabled)
                    ForEach(entry.records.compactMap{linked in store.records.first{$0.id == linked.id}}){RecordRow(record:$0)}
                    ForEach(entry.actions){action in Button("Review: "+action.title){proposal=action}.buttonStyle(ActionStyle())}
                    if let draft=entry.draft{Button("Review reminder"){store.captureRequest=draft}.buttonStyle(ActionStyle())}
                }.padding(15).frame(maxWidth:.infinity,alignment:.leading).background(.regularMaterial,in:RoundedRectangle(cornerRadius:23))
            }
        }
    }
    var composer:some View {
        VStack(spacing:8){
            if store.assistantToken != nil{Toggle("Gemini · share this space’s records",isOn:$cloud).font(.caption)}
            if store.preferences.labs && !(store.preferences.localEndpoint ?? "").isEmpty{Toggle("Use my local model",isOn:$model).font(.subheadline)}
            HStack(alignment:.bottom,spacing:10){
                TextField("Ask about your work…",text:$question,axis:.vertical).lineLimit(1...5).font(Design.font(16,weight:"Regular")).focused($typing).accessibilityIdentifier("assistant-question")
                Button{send()}label:{Image(systemName:"arrow.up").font(.body.weight(.medium)).frame(width:44,height:44).foregroundStyle(Design.background).background(Design.ink,in:Circle())}.disabled(busy || question.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).accessibilityLabel("Send question")
            }
        }.padding(14).background(.regularMaterial,in:RoundedRectangle(cornerRadius:27)).padding(.horizontal,16).padding(.bottom,8)
    }
    func forPrompt(_ prompt:String)->some View{GlassAction{Button{question=prompt;send()}label:{Text(prompt).font(Design.font(14)).frame(maxWidth:.infinity,minHeight:46)}}}
    func send(){
        let q=question.trimmingCharacters(in:.whitespacesAndNewlines);guard !q.isEmpty,!busy else{return}
        let prior=(entries.last(where:{$0.role == "assistant"})?.records ?? []).compactMap{linked in store.records.first{$0.id == linked.id}}
        let reply=AssistantRules.reply(to:q,records:scopedRecords,history:store.activity,focus:scope,previous:prior)
        let conversation=entries;entries.append(ConversationEntry(role:"user",text:q));question="";typing=false;message=nil
        if cloud,let token=store.assistantToken{busy=true;let context=scopedRecords;Task{@MainActor in defer{busy=false};do{let answer=try await GeminiAssistant.answer(question:q,records:context,conversation:conversation,token:token);entries.append(ConversationEntry(role:"assistant",text:answer.text,records:answer.recordIds.compactMap{id in context.first{$0.id == id}},actions:answer.actions))}catch{message=error.localizedDescription;entries.append(ConversationEntry(role:"assistant",text:reply.text,records:reply.records,draft:reply.draft))}};return}
        guard model,store.preferences.labs,let endpoint=store.preferences.localEndpoint,!endpoint.isEmpty,reply.draft == nil else{entries.append(ConversationEntry(role:"assistant",text:reply.text,records:reply.records,draft:reply.draft));return}
        busy=true
        let context=reply.records.isEmpty ? Array(store.priorities.prefix(8).map(\.record)):reply.records
        Task{@MainActor in
            defer{busy=false}
            do{let answer=try await LocalAssistant.answer(endpoint:endpoint,question:q,context:context,conversation:conversation);entries.append(ConversationEntry(role:"assistant",text:answer,records:reply.records))}
            catch{message="Your local model couldn’t be reached. Here’s what your saved information tells me.";entries.append(ConversationEntry(role:"assistant",text:reply.text,records:reply.records))}
        }
    }
}

struct GeminiProposal:Codable,Identifiable {
    var id:String{title+(entityId ?? "")}
    let type:String
    let title:String
    var entityId:String?
    var fields:GeminiFields?
}
struct GeminiFields:Codable {var space:String?;var kind:String?;var title:String?;var body:String?;var status:String?;var due:String?;var duration:Int?;var importance:Int?;var data:[String:String]?}
struct GeminiResponse:Codable {let text:String;let recordIds:[String];let actions:[GeminiProposal]}
enum GeminiAssistant {
    static func answer(question:String,records:[EdizCore.Record],conversation:[ConversationEntry],token:String) async throws -> GeminiResponse {
        var request=URLRequest(url:URL(string:"https://ediz-os.vercel.app/api/assistant")!);request.httpMethod="POST";request.timeoutInterval=55;request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")
        let encoded=try JSONSerialization.jsonObject(with:JSONEncoder().encode(Array(records.prefix(500))))
        request.httpBody=try JSONSerialization.data(withJSONObject:["question":question,"records":encoded,"conversation":conversation.suffix(8).map{["role":$0.role,"text":$0.text]},"localDate":ISO8601DateFormatter().string(from:Date()),"timeZone":TimeZone.current.identifier])
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let response=response as? HTTPURLResponse,(200...299).contains(response.statusCode) else{let detail=(try? JSONSerialization.jsonObject(with:data)) as? [String:String];throw NSError(domain:"EdizAssistant",code:1,userInfo:[NSLocalizedDescriptionKey:detail?["error"] ?? "Gemini is unavailable. Your on-device result is below."])}
        return try JSONDecoder().decode(GeminiResponse.self,from:data)
    }
}
struct NativeAssistantReview:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) var dismiss
    let action:GeminiProposal
    var existing:EdizCore.Record?{store.records.first{$0.id == action.entityId}}
    var draft:EdizCore.Record {var record=existing ?? EdizCore.Record(space:action.fields?.space ?? "personal",kind:action.fields?.kind ?? "task",title:action.fields?.title ?? "");if let f=action.fields{if let value=f.title{record.title=value};if let value=f.body{record.body=value};if let value=f.space{record.space=value};if let value=f.kind{record.kind=value};if let value=f.status{record.status=value};if let value=f.due{record.due=value};if let value=f.duration{record.duration=value};if let value=f.importance{record.importance=value};if let value=f.data{record.data.merge(value){_,new in new}}};if !Catalog.states(kind:record.kind,space:record.space).contains(record.status){record.status=Catalog.states(kind:record.kind,space:record.space)[0]};return record}
    var body:some View {NavigationStack{ScrollView{VStack(alignment:.leading,spacing:18){Text(action.title).font(Design.font(23));Text(action.type == "delete" ? "This permanently deletes the item and attachments.":draft.status == "CANON" ? "Confirming this establishes canon in Moshia.":"Nothing changes until you confirm.").foregroundStyle(Design.muted);if action.type != "delete"{Surface{VStack(alignment:.leading,spacing:12){Text(draft.title);Text(draft.body);Text(draft.status);if let due=draft.due{Text(due)};ForEach(draft.data.keys.sorted(),id:\.self){key in Text(key+": "+(draft.data[key] ?? ""))}}}};Button(action.type == "create" ? "Review new item":action.type == "delete" ? "Confirm deletion":"Confirm changes"){if action.type == "create"{var record=draft;record.data["_creation"]="1";dismiss();DispatchQueue.main.asyncAfter(deadline:.now()+0.35){store.captureRequest=record}}else if let existing{if action.type == "delete"{if store.remove(existing){dismiss()}}else if store.save(draft){dismiss()}}}.buttonStyle(ActionStyle())}.padding(20)}}.background(Design.background).navigationTitle("Review suggestion").toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}}
}
