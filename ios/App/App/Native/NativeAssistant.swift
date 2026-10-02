import SwiftUI
import WebKit
import EdizCore

struct ConversationEntry:Identifiable {
    let id=UUID()
    let role:String
    let text:String
    var records:[EdizCore.Record]=[]
    var draft:EdizCore.Record?
    var actions:[GeminiProposal]=[]
    var sources:[AssistantSource]=[]
    var searchSuggestions:String?
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
    @Environment(\.edizCompact) private var compact
    @State private var chats:[String:[ConversationEntry]]=[:]
    @State private var drafts:[String:String]=[:]
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                VStack(alignment:.leading,spacing:10) {
                    Text("Here with you, Ediz.").font(Design.font(28,relativeTo:.title))
                    Text("Choose a space. Each conversation starts with your saved context.")
                        .font(Design.font(16,weight:"Regular")).foregroundStyle(Design.muted)
                }.padding(.top,12)
                LazyVGrid(columns:compact ? [GridItem(.flexible())]:[GridItem(.flexible()),GridItem(.flexible())],spacing:compact ? 10:14) {
                    workspace("all","Everyday","bubble.left.and.bubble.right.fill")
                    ForEach(Catalog.spaces) { space in
                        workspace(space.id,space.name,SpaceMark(space:space).symbol)
                    }
                }
            }.padding(20)
        }.refreshable{await store.refresh()}.background(Design.background).navigationTitle("Assistant").navigationBarTitleDisplayMode(.inline)
    }
    func workspace(_ id:String,_ title:String,_ symbol:String)->some View {
        NavigationLink {
            NativeAssistantChat(entries:Binding(get:{chats[id] ?? []},set:{chats[id]=$0}),
                                question:Binding(get:{drafts[id] ?? ""},set:{drafts[id]=$0}),scope:id)
        } label: {
            (compact ? AnyLayout(HStackLayout(spacing:14)):AnyLayout(VStackLayout(spacing:12))) {
                Image(systemName:symbol).font(.system(size:24,weight:.medium)).accessibilityHidden(true)
                Text(title).font(Design.font(15)).multilineTextAlignment(.center).lineLimit(2)
            }.padding(.horizontal,10).frame(maxWidth:.infinity).frame(height:compact ? 64:124)
                .foregroundStyle(Design.ink).background(.regularMaterial,in:RoundedRectangle(cornerRadius:28))
                .contentShape(RoundedRectangle(cornerRadius:28))
        }.buttonStyle(.plain).accessibilityIdentifier("assistant-workspace-"+id)
    }
}
struct NativeAssistantChat:View {
    @EnvironmentObject var store:NativeStore
    @Binding var entries:[ConversationEntry]
    @Binding var question:String
    let scope:String
    @Environment(\.edizCompact) private var compact
    @State private var proposal:GeminiProposal?
    @State private var cloud=true
    var scopedRecords:[EdizCore.Record]{store.records.filter{scope == "all" || $0.space == scope}}
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
        }.sheet(item:$proposal){action in NativeAssistantReview(action:action)}.background(Design.background).navigationTitle(scope == "all" ? "Everyday":Catalog.space(scope).name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.topBarTrailing) { Menu {
                if store.assistantToken != nil { Toggle("Use Gemini",isOn:$cloud) }
                if store.preferences.labs { Toggle("Use my local model",isOn:$model) }
                Text("Context: \(scopedRecords.count) saved records")
            } label: { Image(systemName:"info.circle") }.accessibilityLabel("Chat context") } }
    }
    var conversation:some View {
        VStack(alignment:.leading,spacing:compact ? 12:22){
            HStack(spacing:10){
                Image(systemName:scope == "all" ? "bubble.left.and.bubble.right.fill":SpaceMark(space:Catalog.space(scope)).symbol).font(.title2)
                Text(scope == "all" ? "Your whole day":Catalog.space(scope).summary).font(.subheadline)
            }.foregroundStyle(scope == "all" ? Design.ink:Design.color(Catalog.space(scope).color)).padding(.vertical,8)
            if entries.isEmpty {
                Text(scope == "all" ? "What’s on your mind, Ediz?":"Let’s talk about "+Catalog.space(scope).name+".").font(Design.font(21,relativeTo:.title3)).padding(.top,12)
                Text(Priority.briefing(scopedRecords,focus:scope)).font(Design.font(16,weight:"Regular")).foregroundStyle(Design.muted)
                VStack(spacing:9){ForEach(prompts,id:\.self){forPrompt($0)}}
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
                    ForEach(entry.sources,id:\.url) { source in
                        if let url=URL(string:source.url),url.scheme == "https" { Link(source.title,destination:url).font(.footnote) }
                    }
                    if let html=entry.searchSuggestions,!html.isEmpty { NativeSearchSuggestions(html:html).frame(height:110) }
                    if let draft=entry.draft{Button("Review reminder"){store.captureRequest=draft}.buttonStyle(ActionStyle())}
                }.padding(15).frame(maxWidth:.infinity,alignment:.leading).background(.regularMaterial,in:RoundedRectangle(cornerRadius:23))
            }
        }
    }
    var prompts:[String] {
        switch scope {
        case "ejj": return ["Which leads need attention?", "Help me plan my next website", "What should I focus on?"]
        case "band": return ["Plan my next practice session", "Help me build a setlist", "Any loose ends?"]
        case "moshia": return ["Help me outline a chapter", "What have I saved about Moshia?", "Any loose ends?"]
        case "school": return ["What homework should I start?", "Plan tomorrow", "What should I focus on?"]
        default: return ["What should I focus on?", "Plan tomorrow", "Any loose ends?"]
        }
    }
    var composer:some View {
        HStack(alignment:.bottom,spacing:10) {
            TextField("Message…",text:$question,axis:.vertical)
                .lineLimit(1...4).font(Design.font(16,weight:"Regular"))
                .focused($typing).accessibilityIdentifier("assistant-question")
                .padding(.vertical,11).padding(.leading,6)
                .frame(maxWidth:.infinity,minHeight:44,alignment:.leading)
                .contentShape(Rectangle()).onTapGesture { typing=true }
            Button { send() } label: {
                Image(systemName:"arrow.up").font(.body.weight(.medium))
                    .frame(width:44,height:44).foregroundStyle(Design.background)
                    .background(Design.ink,in:Circle())
            }.disabled(busy || question.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send question")
        }.padding(8).background(.regularMaterial,in:RoundedRectangle(cornerRadius:28))
            .padding(.horizontal,16).padding(.bottom,8)
    }
    func forPrompt(_ prompt:String)->some View{GlassAction{Button{question=prompt;send()}label:{Text(prompt).font(Design.font(14)).frame(maxWidth:.infinity,minHeight:46)}}}
    func send(){
        let q=question.trimmingCharacters(in:.whitespacesAndNewlines);guard !q.isEmpty,!busy else{return}
        let prior=(entries.last(where:{$0.role == "assistant"})?.records ?? []).compactMap{linked in store.records.first{$0.id == linked.id}}
        let reply=AssistantRules.reply(to:q,records:scopedRecords,history:store.activity.filter{scope == "all" || Set(scopedRecords.map(\.id)).contains($0.entityId)},focus:scope,previous:prior)
        let conversation=entries;entries.append(ConversationEntry(role:"user",text:q));question="";typing=false;message=nil
        if cloud,let token=store.assistantToken{busy=true;let context=scopedRecords;Task{@MainActor in defer{busy=false};do{let answer=try await GeminiAssistant.answer(question:q,records:context,conversation:conversation,token:token,scope:scope);entries.append(ConversationEntry(role:"assistant",text:answer.text,records:answer.recordIds.compactMap{id in context.first{$0.id == id}},actions:answer.actions,sources:answer.sources ?? [],searchSuggestions:answer.searchSuggestions))}catch{message=error.localizedDescription;entries.append(ConversationEntry(role:"assistant",text:reply.text,records:reply.records,draft:reply.draft))}};return}
        guard model,store.preferences.labs,let endpoint=store.preferences.localEndpoint,!endpoint.isEmpty,reply.draft == nil else{entries.append(ConversationEntry(role:"assistant",text:reply.text,records:reply.records,draft:reply.draft));return}
        busy=true
        let context=reply.records.isEmpty ? Array(scopedRecords.prefix(50)):reply.records
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
struct AssistantSource:Codable {let url:String;let title:String}
struct GeminiResponse:Codable {let text:String;let recordIds:[String];let actions:[GeminiProposal];var sources:[AssistantSource]?;var searchSuggestions:String?}
struct NativeSearchSuggestions:UIViewRepresentable {
    let html:String
    func makeUIView(context:Context)->WKWebView {
        let config=WKWebViewConfiguration();config.defaultWebpagePreferences.allowsContentJavaScript=false
        let view=WKWebView(frame:.zero,configuration:config);view.isOpaque=false;view.backgroundColor = .clear
        view.scrollView.isScrollEnabled=false;view.navigationDelegate=context.coordinator
        view.loadHTMLString(html,baseURL:URL(string:"https://www.google.com"));return view
    }
    func updateUIView(_ view:WKWebView,context:Context){}
    func makeCoordinator()->Coordinator{Coordinator()}
    final class Coordinator:NSObject,WKNavigationDelegate {
        func webView(_ view:WKWebView,decidePolicyFor action:WKNavigationAction,decisionHandler:@escaping (WKNavigationActionPolicy)->Void) {
            if action.navigationType == .linkActivated,let url=action.request.url,url.scheme == "https" {UIApplication.shared.open(url);decisionHandler(.cancel)}else{decisionHandler(.allow)}
        }
    }
}
enum GeminiAssistant {
    static func answer(question:String,records:[EdizCore.Record],conversation:[ConversationEntry],token:String,scope:String) async throws -> GeminiResponse {
        var request=URLRequest(url:URL(string:"https://ediz-os.vercel.app/api/assistant")!);request.httpMethod="POST";request.timeoutInterval=55;request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")
        let encoded=try JSONSerialization.jsonObject(with:JSONEncoder().encode(Array(records.prefix(500))))
        request.httpBody=try JSONSerialization.data(withJSONObject:["question":question,"scope":scope,"records":encoded,"conversation":conversation.suffix(8).map{["role":$0.role,"text":$0.text]},"localDate":ISO8601DateFormatter().string(from:Date()),"timeZone":TimeZone.current.identifier])
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
