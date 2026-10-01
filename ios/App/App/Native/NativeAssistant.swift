import SwiftUI
import EdizCore

struct ConversationEntry:Identifiable {
    let id=UUID()
    let role:String
    let text:String
    var records:[EdizCore.Record]=[]
    var draft:EdizCore.Record?
}
enum LocalAssistant {
    static func answer(endpoint:String,question:String,context:[EdizCore.Record],conversation:[ConversationEntry]) async throws -> String {
        guard var url=URL(string:endpoint),let host=url.host?.lowercased(),url.scheme == "http" || url.scheme == "https" else{throw URLError(.badURL)}
        let parts=host.split(separator:".").compactMap{Int($0)}
        let privateHost=host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".local") || (parts.count == 4 && (parts[0] == 10 || (parts[0] == 192 && parts[1] == 168) || (parts[0] == 172 && (16...31).contains(parts[1]))))
        guard privateHost else{throw URLError(.unsupportedURL)}
        url.appendPathComponent("chat/completions")
        let json=String(decoding:try JSONEncoder().encode(context),as:UTF8.self)
        var messages:[[String:String]]=[["role":"system","content":"You are Ediz’s personal assistant inside Ediz OS. Be calm, useful and concise. Use only the supplied records for facts. POSSIBLE and PLANNED fiction records are not canon. Explain next steps and uncertainty. Never claim to edit, delete, schedule or save anything. Changes must be reviewed in the app. Do not write novel prose unless explicitly asked. Local records: "+json]]
        messages += conversation.suffix(8).map{["role":$0.role,"content":$0.text]}
        messages.append(["role":"user","content":question])
        var request=URLRequest(url:url);request.httpMethod="POST";request.timeoutInterval=35
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.httpBody=try JSONSerialization.data(withJSONObject:["model":"local-model","messages":messages,"temperature":0.4,"max_tokens":500])
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let response=response as? HTTPURLResponse,(200...299).contains(response.statusCode),let root=try JSONSerialization.jsonObject(with:data) as? [String:Any],let choices=root["choices"] as? [[String:Any]],let message=choices.first?["message"] as? [String:Any],let text=message["content"] as? String,!text.isEmpty else{throw URLError(.cannotParseResponse)}
        return text
    }
}
struct NativeAssistant:View {
    @EnvironmentObject var store:NativeStore
    @State private var entries:[ConversationEntry]=[]
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
        }.background(Design.background).navigationTitle("Assistant").navigationBarTitleDisplayMode(.inline)
    }
    var conversation:some View {
        VStack(alignment:.leading,spacing:22){
            if entries.isEmpty {
                Text("Let’s make room for what matters, Ediz.").font(.title3.weight(.medium)).padding(.top,12)
                Text(Priority.briefing(store.records,focus:store.preferences.focus)).font(.body).foregroundStyle(Design.muted)
                VStack(spacing:9){forPrompt("What should I focus on?");forPrompt("Plan tomorrow");forPrompt("Any loose ends?")}
            }
            ForEach(entries){entry in entryView(entry).id(entry.id)}
            if busy{HStack(spacing:9){ProgressView();Text("Thinking through your context…").font(.subheadline).foregroundStyle(Design.muted)}}
            if let message{Text(message).font(.footnote).foregroundStyle(Design.muted)}
        }.padding(20)
    }
    @ViewBuilder func entryView(_ entry:ConversationEntry)->some View {
        VStack(alignment:.leading,spacing:10){
            if entry.role == "user"{Text(entry.text).font(.body).padding(14).background(Design.raised,in:RoundedRectangle(cornerRadius:14)).frame(maxWidth:.infinity,alignment:.trailing)}else{
                Text(entry.text).font(.body).lineSpacing(4).textSelection(.enabled)
                ForEach(entry.records.compactMap{linked in store.records.first{$0.id == linked.id}}){RecordRow(record:$0)}
                if let draft=entry.draft{Button("Review reminder"){store.captureRequest=draft}.buttonStyle(ActionStyle())}
            }
        }
    }
    var composer:some View {
        VStack(spacing:8){
            if store.preferences.labs && !(store.preferences.localEndpoint ?? "").isEmpty{Toggle("Use my local model",isOn:$model).font(.subheadline)}
            HStack(alignment:.bottom,spacing:10){
                TextField("Ask about your work…",text:$question,axis:.vertical).lineLimit(1...5).font(.body).focused($typing).accessibilityIdentifier("assistant-question")
                Button{send()}label:{Image(systemName:"arrow.up").font(.body.weight(.medium)).frame(width:44,height:44).foregroundStyle(Design.background).background(Design.ink,in:Circle())}.disabled(busy || question.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty).accessibilityLabel("Send question")
            }
        }.padding(14).background(.regularMaterial,in:RoundedRectangle(cornerRadius:20)).padding(.horizontal,16).padding(.bottom,8)
    }
    func forPrompt(_ prompt:String)->some View{Button{question=prompt;send()}label:{HStack{Text(prompt);Spacer();Image(systemName:"arrow.up.right")}.font(.subheadline).padding(14).background(Design.surface,in:RoundedRectangle(cornerRadius:12))}.buttonStyle(.plain)}
    func send(){
        let q=question.trimmingCharacters(in:.whitespacesAndNewlines);guard !q.isEmpty,!busy else{return}
        let prior=(entries.last(where:{$0.role == "assistant"})?.records ?? []).compactMap{linked in store.records.first{$0.id == linked.id}}
        let reply=AssistantRules.reply(to:q,records:store.records,history:store.activity,focus:store.preferences.focus,previous:prior)
        let conversation=entries;entries.append(ConversationEntry(role:"user",text:q));question="";typing=false;message=nil
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
