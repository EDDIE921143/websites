import SwiftUI
import WebKit
import EdizCore
import UniformTypeIdentifiers

struct ConversationEntry:Identifiable,Codable {
    var id=UUID()
    let role:String
    let text:String
    var records:[EdizCore.Record]=[]
    var draft:EdizCore.Record?
    var actions:[GeminiProposal]=[]
    var sources:[AssistantSource]=[]
    var searchSuggestions:String?
    var provider:String?
    var attachments:[AssistantAttachmentInfo]?
    var cards:[AssistantCard]?
    var spokenText:String?
    var musicPreview:SongPreview?
    var contextText:String{text+(cards ?? []).map{card in "\n"+card.title+"\n"+card.items.map{[$0.title,$0.detail,$0.meta].compactMap{$0}.joined(separator:" · ")}.joined(separator:"\n")}.joined()}
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
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo:.body) private var cardHeight:CGFloat=166
    @ScaledMetric(relativeTo:.body) private var rowHeight:CGFloat=88
    private var rows:Bool{compact || textSize >= .xxLarge}
    @State private var drafts:[String:String]=[:]
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                VStack(alignment:.leading,spacing:10) {
                    Text("Here with you, Ediz.").font(Design.font(28,relativeTo:.title))
                    Text("Choose a space. Each conversation starts with your saved context.")
                        .font(Design.font(16,weight:"Regular")).foregroundStyle(Design.muted)
                }.padding(.top,12)
                LazyVGrid(columns:rows ? [GridItem(.flexible())]:[GridItem(.flexible()),GridItem(.flexible())],spacing:compact ? 10:14) {
                    workspace("all","Everyday","bubble.left.and.bubble.right.fill")
                    ForEach(Catalog.spaces) { space in
                        workspace(space.id,space.name,SpaceMark(space:space).symbol)
                    }
                }
            }.padding(20)
        }.refreshable{await store.refresh()}.background(AppBackdrop()).navigationTitle("Assistant").navigationBarTitleDisplayMode(.inline)
    }
    func workspace(_ id:String,_ title:String,_ symbol:String)->some View {
        NavigationLink {
            NativeConversationHost(scope:id)
        } label: {
            let accent=id == "all" ? Design.ink:WorkspaceTheme.accent(id)
            (rows ? AnyLayout(HStackLayout(spacing:14)):AnyLayout(VStackLayout(alignment:.leading,spacing:12))) {
                Image(systemName:symbol).font(.system(size:22,weight:.medium))
                    .foregroundStyle(accent).frame(width:44,height:44)
                    .background(accent.opacity(0.16),in:RoundedRectangle(cornerRadius:14)).accessibilityHidden(true)
                VStack(alignment:.leading,spacing:5) {
                    Text(title).font(.headline).foregroundStyle(Design.ink).lineLimit(2)
                    let count=store.records.filter{id == "all" || $0.space == id}.count
                    Text(count == 0 ? "Start a conversation":"\(count) saved records")
                        .font(.caption).foregroundStyle(Design.muted).lineLimit(1)
                }.frame(maxWidth:.infinity,alignment:.leading)
            }.padding(16).frame(maxWidth:.infinity,alignment:.leading).frame(minHeight:rows ? rowHeight:cardHeight)
                .background(Design.surface,in:RoundedRectangle(cornerRadius:compact ? 16:22))
                .contentShape(RoundedRectangle(cornerRadius:22))
        }.buttonStyle(.plain).accessibilityIdentifier("assistant-workspace-"+id).walkthroughTarget(id == "moshia" ? "assistant-moshia":"",session:store.walkthrough)
    }
}
enum WorkspaceBot {
    static func name(_ scope:String)->String {switch scope{case "ejj":return "EJJ Digital Bot";case "band":return "CLEARANCE 19 Bot";case "moshia":return "Moshia Bot";case "school":return "School Bot";case "personal":return "Personal Bot";default:return "Everyday Bot"}}
}
struct NativeAssistantChat:View {
    @EnvironmentObject var store:NativeStore
    @Binding var entries:[ConversationEntry]
    @Binding var question:String
    let scope:String
    var threadID:UUID?=nil
    var selectThread:((UUID)->Void)?=nil
    @State private var historyOpen=false
    @Environment(\.edizCompact) private var compact
    @State private var proposal:GeminiProposal?
    @State private var attachments:[AssistantAttachment]=[]
    @State private var importingFiles=false
    @State private var attachmentOptions=false
    @State private var attachmentChoice:String?
    @State private var choosingMedia=false
    @State private var preparing=0
    @State private var mediaError:String?
    @StateObject private var dictation=NativeSpeech()
    @State private var dictating=false
    @State private var transcribing=false
    @State private var recordStarted=Date()
    @State private var dictationJob:Task<Void,Never>?
    @State private var memoPreview:FilePreview?
    @State private var voiceOpen=false
    @State private var voiceWanted=false
    @State private var voiceAuto=false
    @State private var interruptionPrefix=""
    @State private var voiceTurn:Task<Void,Never>?
    @State private var responseTask:Task<Void,Never>?
    @State private var callRequest=false
    @State private var activeRequest=UUID()
    @State private var callStarted=Date()
    @State private var callEntryStart=0
    @State private var callEnded:String?
    @StateObject private var speech=NativeSpeech()
    @StateObject private var speaker=NativeAssistantSpeaker()
    @Environment(\.scenePhase) private var scenePhase
    @State private var mode="cloud"
    var accent:Color {WorkspaceTheme.accent(scope)}
    var corners:CGFloat {scope == "moshia" ? 12:scope == "ejj" || scope == "school" ? 16:24}
    var contextTitle:String {switch scope{case "ejj":return "Business context";case "band":return "Band notes";case "moshia":return "Story context";case "school":return "Study notes";case "personal":return "Your saved notes";default:return "Across your spaces"}}
    var opening:String {switch scope{case "ejj":return "What are we building?";case "band":return "What are we rehearsing?";case "moshia":return "Where does the story go next?";case "school":return "What needs your attention?";case "personal":return "What would you like to keep?";default:return "What’s on your mind, Ediz?"}}
    var scopedRecords:[EdizCore.Record]{store.records.filter{scope == "all" || $0.space == scope}}
    @State private var readingEntry:UUID?
    @State private var copiedEntry:UUID?
    @State private var latestPreviewID:UUID?
    @State private var chatAppeared=false
    @State private var busy=false
    @State private var failedQuestion:String?
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var message:String?
    @FocusState private var typing:Bool
    var body:some View {
        ScrollViewReader{reader in
            ScrollView{conversation}.safeAreaPadding(.vertical,18)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of:entries.count){_,_ in scrollToBottom(reader)}
                .onChange(of:busy){_,_ in scrollToBottom(reader)}
                .safeAreaInset(edge:.bottom){composer}
        }.sheet(item:$proposal){action in NativeAssistantReview(action:action)}
            .sheet(isPresented:$historyOpen){NavigationStack{NativeChatHistory(scope:scope,current:threadID,select:{id in endVoice();historyOpen=false;selectThread?(id)})}}
            .sheet(isPresented:$attachmentOptions,onDismiss:{let choice=attachmentChoice;attachmentChoice=nil;mediaError=nil;if choice == "media"{choosingMedia=true}else if choice == "file"{importingFiles=true}}){
                VStack(alignment:.leading,spacing:18){
                    Text("Add to your message").font(.title3.weight(.semibold))
                    Text("Photos, videos, documents and recordings").font(.subheadline).foregroundStyle(Design.muted)
                    Button{attachmentChoice="media";attachmentOptions=false}label:{Label("Photo or video",systemImage:"photo.on.rectangle").frame(maxWidth:.infinity,minHeight:48,alignment:.leading)}
                    Button{attachmentChoice="file";attachmentOptions=false}label:{Label("Choose a file",systemImage:"folder").frame(maxWidth:.infinity,minHeight:48,alignment:.leading)}
                }.padding(24).presentationDetents([.height(270)]).presentationDragIndicator(.visible)
            }
            .sheet(isPresented:$choosingMedia){NativeAssistantMediaPicker(receive:{url in prepareAttachment(url,temporary:true)},close:{choosingMedia=false},failed:{mediaError=$0})}
            .sheet(item:$memoPreview,onDismiss:{memoPreview=nil}){clip in NativeAudioPractice(url:clip.url).presentationDragIndicator(.visible)}
            .fileImporter(isPresented:$importingFiles,allowedContentTypes:[.image,.movie,.audio,.pdf,.plainText,.text,.json,.commaSeparatedText],allowsMultipleSelection:true){result in switch result{case .success(let urls):for url in urls{prepareAttachment(url)};case .failure(let error):if (error as NSError).code != NSUserCancelledError{mediaError="That file couldn’t be opened. Try choosing it again."}}}
            .fullScreenCover(isPresented:$voiceOpen,onDismiss:{endVoice()}){NativeAssistantVoicePanel(speech:speech,speaker:speaker,busy:busy,entry:callReply,error:message,scope:scope,listen:{beginListening()},pause:{pauseVoice()},send:{sendVoice()},read:{voiceAuto=false;speech.stop();readCallReply()},end:{endVoice()})}
            .onChange(of:speech.transcript){_,value in scheduleVoice(value)}
            .onChange(of:entries.count){_,_ in if voiceWanted && voiceAuto,let last=entries.last,last.role == "assistant"{if last.musicPreview != nil{pauseVoice();return};speech.stop();speaker.say(last.spokenText ?? last.text,token:store.assistantToken,natural:true,voice:NativeVoicePreferences.defaults.string(forKey:"assistant-natural-voice-name") ?? "Aoede")}}
            .onDisappear{dictationJob?.cancel();dictation.stop();dictating=false;transcribing=false;if !voiceOpen{voiceAuto=false;voiceWanted=false;voiceTurn?.cancel();speech.stop();speaker.stop()}}
            .onChange(of:scenePhase){_,phase in if phase == .background{endVoice();dictationJob?.cancel();dictation.stop();dictating=false;transcribing=false}}.background(AppBackdrop(scope:scope)).tint(accent).navigationTitle(scope == "all" ? "Everyday":Catalog.space(scope).name).navigationBarTitleDisplayMode(.inline)
            .onAppear{withAnimation(reducedMotion ? nil:.spring(response:0.3,dampingFraction:0.85)){chatAppeared=true};if scope == "moshia"{store.walkthrough?.event("chat-open")};if store.assistantToken == nil && mode == "cloud"{mode="saved"}}
            .toolbar { ToolbarItem(placement:.topBarTrailing) { HStack(spacing:18){Button{historyOpen=true}label:{Image(systemName:"bubble.left.and.bubble.right")}.accessibilityLabel("Chats").accessibilityIdentifier("workspace-chats");Menu {
                Picker("Assistant",selection:$mode) {
                    if store.assistantToken != nil { Text(WorkspaceBot.name(scope)).tag("cloud") }
                    if store.preferences.labs { Text("Local model").tag("local") }
                    Text("Saved context").tag("saved")
                }
                NavigationLink("Review saved context"){NativeAssistantContext()}
                Text("Context: \(scopedRecords.count) saved records")
            } label: { Image(systemName:"info.circle") }.accessibilityLabel("Chat context") } } }
    }
    func scrollToBottom(_ reader:ScrollViewProxy) {
        Task{@MainActor in await Task.yield();withAnimation(reducedMotion ? nil:.easeOut(duration:0.18)){if let last=entries.last,last.role == "assistant"{reader.scrollTo(last.id,anchor:.top)}else{reader.scrollTo("conversation-bottom",anchor:.bottom)}}}
    }
    var conversation:some View {
        VStack(alignment:.leading,spacing:compact ? 12:22){
            NativeChatHeader(scope:scope).opacity(chatAppeared ? 1:0).offset(y:reducedMotion || chatAppeared ? 0:10)
            if entries.isEmpty {
                Text(opening).font(scope == "moshia" ? .system(.title2,design:.serif):.title3.weight(.medium)).padding(.top,4)
                Surface {
                    VStack(alignment:.leading,spacing:9) {
                        Label(contextTitle,systemImage:scope == "moshia" ? "book.closed":"tray.full.fill").font(.subheadline.weight(.medium)).foregroundStyle(accent)
                        if let brief=scopedRecords.first(where:{$0.data["contextType"] == "workspace-brief" && (scope != "all" || $0.space == "personal")}) {
                            Text(brief.body).font(.subheadline).foregroundStyle(Design.muted).lineLimit(3)
                        } else {Text("Ask a question or capture something you want to keep.").font(.subheadline).foregroundStyle(Design.muted)}
                        NavigationLink("Review context"){NativeAssistantContext()}.font(.subheadline)
                    }
                }
                if scope == "band" || scope == "school" {
                    HStack(alignment:.top,spacing:10){ForEach(Array(prompts.prefix(2)),id:\.self){prompt in
                        Button{question=prompt;send()}label:{VStack(alignment:.leading,spacing:12){Image(systemName:scope == "band" ? "music.note":"pencil").foregroundStyle(accent);Text(prompt).font(.subheadline.weight(.medium)).multilineTextAlignment(.leading).foregroundStyle(Design.ink)}.padding(16).frame(maxWidth:.infinity,minHeight:104,alignment:.topLeading).background{WorkspacePanel(scope:scope).clipShape(RoundedRectangle(cornerRadius:corners))}}.buttonStyle(.plain)
                    }}
                    if let last=prompts.last{forPrompt(last)}
                } else {VStack(spacing:8){ForEach(prompts,id:\.self){forPrompt($0)}}}
            }
            ForEach(entries){entry in entryView(entry).id(entry.id).transition(.opacity.combined(with:.offset(y:reducedMotion ? 0:8)))}
            if busy{ThinkingCompanion(color:accent,reducedMotion:reducedMotion)}
            if let message {
                Surface {VStack(alignment:.leading,spacing:10) {
                    Label("Couldn’t get a reply",systemImage:"exclamationmark.bubble").font(.subheadline.weight(.medium))
                    Text(message).font(.footnote).foregroundStyle(Design.muted)
                    if let failedQuestion {Button("Try again") {
                        question=failedQuestion
                        if entries.last?.role == "user",entries.last?.text == failedQuestion{entries.removeLast()}
                        send()
                    }.buttonStyle(ActionStyle()).accessibilityIdentifier("assistant-retry")}
                }}
            }
            Color.clear.frame(height:1).id("conversation-bottom")
        }.padding(20).animation(reducedMotion ? nil:.easeOut(duration:0.22),value:entries.count).animation(reducedMotion ? nil:.easeOut(duration:0.18),value:busy)
    }
    @ViewBuilder func entryView(_ entry:ConversationEntry)->some View {
        VStack(alignment:entry.role == "user" ? .trailing:.leading,spacing:10){
            if entry.role == "user" {
                VStack(alignment:.trailing,spacing:8){
                    ForEach(entry.attachments ?? []){file in
                        if file.mimeType.hasPrefix("audio/"),file.localFile != nil {Button{do{memoPreview=FilePreview(url:try store.memoURL(file))}catch{mediaError="This recording isn’t available on this device."}}label:{Label("Play voice memo",systemImage:"play.circle.fill")}.font(.subheadline)}
                        else{Label(file.name,systemImage:file.mimeType.hasPrefix("image/") ? "photo":file.mimeType.hasPrefix("video/") ? "video":file.mimeType.hasPrefix("audio/") ? "waveform":"doc.text").font(.caption).lineLimit(2)}
                    }
                    Text(entry.text).font(Design.font(16,weight:"Regular"))
                }.padding(14).background(accent.opacity(0.14),in:RoundedRectangle(cornerRadius:corners)).frame(maxWidth:.infinity,alignment:.trailing)
            } else {
                VStack(alignment:.leading,spacing:10){if let provider=entry.provider{Text(provider == "Gemini" ? WorkspaceBot.name(scope):provider).font(.caption.weight(.medium)).foregroundStyle(accent)};Text(entry.text).font(Design.font(16,weight:"Regular")).lineSpacing(5).fixedSize(horizontal:false,vertical:true).textSelection(.enabled)
                    if let preview=entry.musicPreview{NativeSongPreview(preview:preview,autoPlay:entry.id==latestPreviewID)}
                    ForEach(entry.cards ?? []){AssistantResultCard(card:$0,scope:scope)}
                    ForEach(entry.records.compactMap{linked in store.records.first{$0.id == linked.id}}){RecordRow(record:$0)}
                    ForEach(entry.actions){action in Button("Review: "+action.title){proposal=action}.buttonStyle(ActionStyle())}
                    ForEach(entry.sources,id:\.url) { source in
                        if let url=URL(string:source.url),url.scheme == "https" { Link(source.title,destination:url).font(.footnote) }
                    }
                    if let html=entry.searchSuggestions,!html.isEmpty { NativeSearchSuggestions(html:html).frame(height:110) }
                    HStack(spacing:18){
                        Button{if readingEntry==entry.id && (speaker.speaking || speaker.preparing){speaker.stop();readingEntry=nil}else{endVoice();readingEntry=entry.id;speaker.say(entry.spokenText ?? entry.contextText,token:store.assistantToken,natural:true,voice:NativeVoicePreferences.defaults.string(forKey:"assistant-natural-voice-name") ?? "Aoede")}}label:{Label(readingEntry==entry.id && (speaker.speaking || speaker.preparing) ? "Stop":"Read aloud",systemImage:readingEntry==entry.id && speaker.speaking ? "stop.fill":"speaker.wave.2")}.accessibilityIdentifier("reply-read-"+entry.id.uuidString)
                        Button{UIPasteboard.general.string=entry.contextText;copiedEntry=entry.id;UIImpactFeedbackGenerator(style:.light).impactOccurred();Task{@MainActor in try? await Task.sleep(for:.seconds(2));if copiedEntry==entry.id{copiedEntry=nil}}}label:{Label(copiedEntry==entry.id ? "Copied":"Copy",systemImage:copiedEntry==entry.id ? "checkmark":"doc.on.doc")}.accessibilityIdentifier("reply-copy-"+entry.id.uuidString)
                    }.font(.caption.weight(.medium)).foregroundStyle(Design.muted).buttonStyle(.plain).padding(.top,6)
                    if readingEntry==entry.id,let note=speaker.voiceNote,!note.hasPrefix("Natural voice"){Text(note).font(.footnote).foregroundStyle(Design.muted)}
                    if let draft=entry.draft{Button("Review reminder"){store.captureRequest=draft}.buttonStyle(ActionStyle())}
                }.padding((entry.cards ?? []).isEmpty ? 15:0).frame(maxWidth:.infinity,alignment:.leading).background{if(entry.cards ?? []).isEmpty{WorkspacePanel(scope:scope).clipShape(RoundedRectangle(cornerRadius:corners))}}
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
        VStack(alignment:.leading,spacing:8){
            if let callEnded{Label(callEnded,systemImage:"waveform.circle").font(.caption).foregroundStyle(Design.muted).accessibilityIdentifier("call-ended")}
            if preparing>0{HStack{ProgressView();Text("Preparing attachment…").font(.caption)}}
            if !attachments.isEmpty {
                ScrollView(.horizontal,showsIndicators:false){HStack(spacing:8){ForEach(attachments){file in
                    HStack(spacing:8){
                        if file.mimeType.hasPrefix("image/"),let picture=UIImage(data:file.bytes){Image(uiImage:picture).resizable().scaledToFill().frame(width:36,height:36).clipped().clipShape(RoundedRectangle(cornerRadius:6))}else{Image(systemName:file.symbol)}
                        if file.mimeType.hasPrefix("audio/"){Button{previewMemo(file)}label:{Label("Voice memo",systemImage:"play.circle.fill")}.font(.caption).accessibilityIdentifier("assistant-memo-preview")}else{Text(file.name).font(.caption).lineLimit(1).frame(maxWidth:140)}
                        Button{attachments.removeAll{$0.id == file.id}}label:{Image(systemName:"xmark.circle.fill").frame(width:32,height:36)}.accessibilityLabel("Remove "+file.name).disabled(busy)
                    }.padding(6).background{WorkspacePanel(scope:scope).clipShape(RoundedRectangle(cornerRadius:12))}
                }}}
                Text("Shared with Gemini when you send · 2.5 MB total").font(.caption2).foregroundStyle(Design.muted)
            }
            if let mediaError{Text(mediaError).font(.caption).foregroundStyle(Design.muted)}
            if dictating || transcribing { recordingBar } else {
            HStack(alignment:.bottom,spacing:6) {
                Button {typing=false;attachmentOptions=true} label:{Image(systemName:"plus").font(.body.weight(.medium)).frame(width:40,height:44)}.accessibilityLabel("Add attachment").accessibilityIdentifier("assistant-attach").disabled(busy || preparing>0)
                TextField("Message…",text:$question,axis:.vertical)
                    .lineLimit(1...4).font(Design.font(16,weight:"Regular"))
                    .focused($typing).accessibilityIdentifier("assistant-question").walkthroughTarget("assistant-message",session:store.walkthrough)
                    .padding(.vertical,11).frame(maxWidth:.infinity,minHeight:44,alignment:.leading)
                    .contentShape(Rectangle()).onTapGesture { typing=true }
                Button{typing=false;endVoice();store.walkthrough?.muteForRecording();mediaError=nil;recordStarted=Date();dictating=true;dictation.toggle()}label:{Image(systemName:"mic").font(.body).frame(width:40,height:44)}.accessibilityLabel("Record voice memo").accessibilityIdentifier("assistant-memo").disabled(busy || preparing>0)
                let hasMessage = !question.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || !attachments.isEmpty
                Button {
                    if hasMessage{send()}else{typing=false;callStarted=Date();callEntryStart=entries.count;
                        #if DEBUG
                        if ProcessInfo.processInfo.arguments.contains("-ui-testing") && (ProcessInfo.processInfo.arguments.contains("-test-call-results") || ProcessInfo.processInfo.arguments.contains("-test-call-saved-results")){callEntryStart=0}
                        #endif
                        callEnded=nil;voiceWanted=true;voiceAuto=true;voiceOpen=true;speaker.finished={if voiceWanted && voiceAuto{beginListening()}};speaker.interrupted={text in interruptionPrefix=text;message=nil;speaker.acknowledgeInterruption{if voiceWanted{beginListening()}}}}
                } label: {
                    Image(systemName:hasMessage ? "arrow.up":"waveform").font(.body.weight(.medium)).frame(width:44,height:44).foregroundStyle(Design.background).background(accent,in:Circle())
                }.disabled(busy || preparing>0).accessibilityLabel(hasMessage ? "Send question":"Talk to your assistant").accessibilityIdentifier(hasMessage ? "assistant-send":"assistant-voice").walkthroughTarget("assistant-send",session:store.walkthrough)

            }
            }
        }.animation(reducedMotion ? nil:.easeInOut(duration:0.2),value:dictating)
        .onChange(of:dictation.requesting){_,requesting in if !requesting && !dictation.listening && dictating{dictating=false;mediaError=dictation.message}}
        .onChange(of:dictation.message){_,error in if let error{mediaError=error}}
        .onChange(of:question){_,value in if !value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{store.walkthrough?.event("assistant-typed")}}
            .padding(8).background(Design.raised,in:RoundedRectangle(cornerRadius:corners))
            .padding(.horizontal,16).padding(.bottom,8)
    }
    var recordingBar:some View {
        HStack(spacing:10){
            Button{dictationJob?.cancel();dictation.stop();dictating=false;transcribing=false}label:{Image(systemName:"xmark").frame(width:40,height:44)}.accessibilityLabel("Cancel recording").accessibilityIdentifier("dictation-cancel")
            if transcribing || dictation.requesting{ProgressView();Text(transcribing ? "Transcribing…":"Starting microphone…").font(.subheadline).frame(maxWidth:.infinity,alignment:.leading)}else{
                HStack(spacing:8){AudioWaveform(levels:dictation.levels,color:accent,height:28);TimelineView(.periodic(from:recordStarted,by:1)){time in Text(String(format:"%d:%02d",Int(max(0,time.date.timeIntervalSince(recordStarted)))/60,Int(max(0,time.date.timeIntervalSince(recordStarted)))%60)).font(.caption.monospacedDigit()).foregroundStyle(Design.muted).frame(width:38)}}.frame(maxWidth:.infinity).accessibilityIdentifier("dictation-recording")
            }
            Button{finishDictation(sendAfter:false)}label:{Image(systemName:"stop.fill").frame(width:40,height:44)}.disabled(transcribing || dictation.requesting).accessibilityLabel("Stop and transcribe").accessibilityIdentifier("dictation-stop")
            Button{finishDictation(sendAfter:true)}label:{Image(systemName:"arrow.up").frame(width:44,height:44).foregroundStyle(Design.background).background(accent,in:Circle())}.disabled(transcribing || dictation.requesting).accessibilityLabel("Transcribe and send").accessibilityIdentifier("dictation-send")
        }.frame(height:44)
    }
    func finishDictation(sendAfter:Bool){
        guard dictating,!transcribing else{return};transcribing=true
        dictationJob=Task{@MainActor in
            let text=await dictation.finish().trimmingCharacters(in:.whitespacesAndNewlines)
            guard !Task.isCancelled else{return};dictating=false;transcribing=false
            guard !text.isEmpty else{mediaError="No speech was detected. Try again, or type your message.";return}
            question += (question.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "":" ")+text
            if sendAfter{send()}else{typing=true}
        }
    }
    func stage(_ file:AssistantAttachment){
        guard attachments.count<3,attachments.reduce(0,{$0+$1.bytes.count})+file.bytes.count<=AssistantMedia.limit else{mediaError="Attach up to three files and 2.5 MB total.";return}
        attachments.append(file);mediaError=nil
    }
    func previewMemo(_ file:AssistantAttachment){
        do{let url=FileManager.default.temporaryDirectory.appendingPathComponent(file.id.uuidString+".wav");try file.bytes.write(to:url,options:[.atomic,.completeFileProtection]);memoPreview=FilePreview(url:url)}catch{mediaError="This memo couldn’t be played. Try recording again."}
    }
    func prepareAttachment(_ url:URL,temporary:Bool=false){
        let access=url.startAccessingSecurityScopedResource();preparing+=1;mediaError=nil
        Task{@MainActor in
            defer{preparing-=1;if access{url.stopAccessingSecurityScopedResource()};if temporary{try? FileManager.default.removeItem(at:url)}}
            do{
                guard attachments.count<3 else{throw AssistantMedia.issue("Attach up to three files per message.")}
                let file=try await AssistantMedia.prepare(url)
                guard attachments.count<3,attachments.reduce(0,{$0+$1.bytes.count})+file.bytes.count<=AssistantMedia.limit else{throw AssistantMedia.issue("Choose smaller files or a shorter clip; attachments can total 2.5 MB.")}
                attachments.append(file)
            }catch{mediaError=error.localizedDescription}
        }
    }
    func beginListening(){guard voiceWanted,!busy else{return};voiceAuto=true;voiceTurn?.cancel();speaker.stop();speech.stop();speech.toggle()}
    func scheduleVoice(_ value:String){
        voiceTurn?.cancel();guard voiceWanted,speech.listening,!busy,!speaker.speaking,!value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return}
        voiceTurn=Task{@MainActor in do{try await Task.sleep(for:.seconds(1.6));guard !Task.isCancelled,voiceWanted else{return};sendVoice()}catch{}}
    }
    var callReply:ConversationEntry?{guard !busy,entries.last?.role == "assistant" else{return nil};return entries.dropFirst(min(callEntryStart,entries.count)).last{$0.role == "assistant"}}
    func readCallReply(){speaker.say(callReply?.spokenText ?? callReply?.text ?? "Hi Ediz. I’m listening. What would you like to work on?",token:store.assistantToken,natural:true,voice:NativeVoicePreferences.defaults.string(forKey:"assistant-natural-voice-name") ?? "Aoede")}
    func sendVoice(){
        guard voiceWanted,!busy,!speech.transcript.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return}
        voiceTurn?.cancel();voiceTurn=Task{@MainActor in
            let text=await speech.finish().trimmingCharacters(in:.whitespacesAndNewlines)
            guard !Task.isCancelled,voiceWanted,!text.isEmpty else{return};question=interruptionPrefix.isEmpty ? text:interruptionPrefix+" "+text;interruptionPrefix="";send()
        }
    }
    func pauseVoice(){
        voiceAuto=false;voiceTurn?.cancel();speech.stop();speaker.stop()
        if callRequest{activeRequest=UUID();responseTask?.cancel();responseTask=nil;callRequest=false;busy=false}
    }
    func endVoice(){
        if voiceWanted{let seconds=Int(Date().timeIntervalSince(callStarted));callEnded="Voice conversation ended · \(seconds/60):"+String(format:"%02d",seconds%60);UIImpactFeedbackGenerator(style:.soft).impactOccurred()}
        voiceAuto=false;voiceWanted=false;voiceOpen=false;voiceTurn?.cancel();voiceTurn=nil;interruptionPrefix="";speaker.finished=nil;speaker.interrupted=nil;speech.stop();speaker.stop()
        if callRequest{activeRequest=UUID();responseTask?.cancel();responseTask=nil;callRequest=false;busy=false;message=nil;failedQuestion=nil}
    }
    func forPrompt(_ prompt:String)->some View {
        Button{question=prompt;send()}label:{HStack(spacing:12){Text(prompt).font(.subheadline).multilineTextAlignment(.leading);Spacer();Image(systemName:"arrow.up.left").font(.caption).foregroundStyle(accent)}.padding(.horizontal,16).padding(.vertical,12).frame(minHeight:52).foregroundStyle(Design.ink).background(Design.surface,in:RoundedRectangle(cornerRadius:corners))}.buttonStyle(.plain)
    }
    func send(){
        var q=question.trimmingCharacters(in:.whitespacesAndNewlines);guard !busy,preparing==0 else{return}
        if q.isEmpty,!attachments.isEmpty{q=attachments.allSatisfy{$0.mimeType.hasPrefix("audio/")} ? "Please transcribe this voice memo and respond to it.":"What can you tell me about these attachments?"}
        guard !q.isEmpty else{return}
        if !attachments.isEmpty,(mode != "cloud" || store.assistantToken == nil){mediaError="Choose your connected bot from Chat context to ask about attached media. Saved context and local text models can’t read these files.";return}
        let outgoing=attachments
        let outgoingInfo:[AssistantAttachmentInfo]
        do{outgoingInfo=try outgoing.map{try store.keepMemo($0)}}catch{mediaError="Your voice memo couldn’t be saved. Try again before sending.";return}
        let prior=(entries.last(where:{$0.role == "assistant"})?.records ?? []).compactMap{linked in store.records.first{$0.id == linked.id}}
        let reply=AssistantRules.reply(to:q,records:scopedRecords,history:store.activity.filter{scope == "all" || Set(scopedRecords.map(\.id)).contains($0.entityId)},focus:scope,previous:prior)
        let conversation=entries;callEnded=nil;entries.append(ConversationEntry(role:"user",text:q,attachments:outgoing.isEmpty ? nil:outgoingInfo));question="";typing=false;message=nil;failedQuestion=nil
        if mode == "cloud",let token=store.assistantToken{
            busy=true;let context=scopedRecords+((scope == "moshia" || scope == "all") ? store.originalManuscript:[]);let inCall=voiceWanted;callRequest=inCall;let requestID=UUID();activeRequest=requestID
            responseTask=Task{@MainActor in
                defer{if activeRequest==requestID{busy=false;callRequest=false}}
                do{
                    let memories=store.searchableMemories().filter{$0.data["_chatID"] != nil && $0.data["_chatID"] != threadID?.uuidString && (scope == "all" || $0.space == scope)}
                    let answer=try await GeminiAssistant.answer(question:q,records:context,conversation:conversation,token:token,scope:scope,attachments:outgoing,voiceMode:inCall,memories:Array(memories.prefix(12)))
                    guard !Task.isCancelled,(!inCall || voiceWanted) else{return}
                    attachments.removeAll{file in outgoing.contains{$0.id == file.id}}
                    let newReply=ConversationEntry(role:"assistant",text:answer.text,records:answer.recordIds.compactMap{id in context.first{$0.id == id}},actions:answer.actions,sources:answer.sources ?? [],searchSuggestions:answer.searchSuggestions,provider:WorkspaceBot.name(scope),cards:answer.cards,spokenText:answer.spokenText,musicPreview:answer.musicPreview);latestPreviewID=newReply.id;entries.append(newReply)
                }catch{guard !Task.isCancelled else{return};message=error.localizedDescription;failedQuestion=q}
            };return
        }
        guard mode == "local" else{entries.append(ConversationEntry(role:"assistant",text:reply.text,records:reply.records,draft:reply.draft,provider:"Saved context"));store.walkthrough?.event("assistant-replied");return}
        guard store.preferences.labs,let endpoint=store.preferences.localEndpoint,!endpoint.isEmpty else{message="Add your local model’s network address and test the connection in Settings.";failedQuestion=q;return}
        busy=true
        let context=reply.records.isEmpty ? Array(scopedRecords.prefix(50)):reply.records
        Task{@MainActor in
            defer{busy=false}
            do{let answer=try await LocalAssistant.answer(endpoint:endpoint,question:q,context:context,conversation:conversation);entries.append(ConversationEntry(role:"assistant",text:answer,records:reply.records,provider:"Local model"))}
            catch{message="Your local model couldn’t be reached. Check the connection in Settings, or choose Saved context from the chat menu.";failedQuestion=q}
        }
    }
}

struct NativeChatHeader:View {
    @EnvironmentObject var store:NativeStore
    let scope:String
    @Environment(\.dynamicTypeSize) private var textSize
    var accent:Color{WorkspaceTheme.accent(scope)}
    func count(_ kind:String)->Int{store.records.filter{$0.space == scope && $0.kind == kind}.count}
    func badge(_ title:String,_ value:Int)->some View {
        Text("\(value) "+title).font(.caption.weight(.medium)).foregroundStyle(accent).padding(.horizontal,11).padding(.vertical,7).background(accent.opacity(0.10),in:Capsule())
    }
    @ViewBuilder func badges(_ first:String,_ firstCount:Int,_ second:String,_ secondCount:Int)->some View {
        if textSize >= .xxLarge {VStack(alignment:.leading,spacing:8){badge(first,firstCount);badge(second,secondCount)}}
        else {HStack(spacing:8){badge(first,firstCount);badge(second,secondCount)}}
    }
    var body:some View {
        Group {
            switch scope {
            case "ejj":
                VStack(alignment:.leading,spacing:16){
                    HStack{Text("BUSINESS WORKSPACE").font(.caption).tracking(1.5);Spacer();Image(systemName:"rectangle.3.group.fill").font(.title2)}.foregroundStyle(accent)
                    Text("EJJ Digital").font(.title.weight(.semibold))
                    badges("leads",count("lead"),"websites",count("website"))
                }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background{WorkspacePanel(scope:scope).clipShape(RoundedRectangle(cornerRadius:18))}
            case "band":
                VStack(alignment:.leading,spacing:16){
                    HStack(alignment:.center){VStack(alignment:.leading,spacing:8){Text("CLEARANCE 19").font(.title2.weight(.bold));Text("Your rehearsal room").font(.subheadline).foregroundStyle(Design.muted)};Spacer();Image(systemName:"waveform").font(.system(size:42,weight:.medium)).foregroundStyle(accent).accessibilityHidden(true)}
                    badges("songs",count("song"),"rehearsals",count("rehearsal"))
                }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(accent.opacity(0.10),in:RoundedRectangle(cornerRadius:28))
            case "moshia":
                HStack(alignment:.top,spacing:18){
                    RoundedRectangle(cornerRadius:3).fill(accent).frame(width:5,height:106)
                    VStack(alignment:.leading,spacing:12){Text("Moshia").font(.system(.largeTitle,design:.serif).weight(.medium));Text("The story workspace").font(.subheadline).foregroundStyle(Design.muted);badges("chapters",count("chapter"),"threads",count("thread"))}
                }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:12))
            case "school":
                VStack(alignment:.leading,spacing:16){
                    Label("Study desk",systemImage:"graduationcap.fill").font(.system(.title2,design:.rounded).weight(.semibold)).foregroundStyle(accent)
                    badges("homework",count("assignment"),"tests",count("exam"))
                    Text("One subject. One next step.").font(.subheadline).foregroundStyle(Design.muted)
                }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background{WorkspacePanel(scope:scope).clipShape(RoundedRectangle(cornerRadius:16))}
            case "personal":
                HStack(alignment:.top,spacing:16){Image(systemName:"text.book.closed.fill").font(.title).foregroundStyle(accent);VStack(alignment:.leading,spacing:12){Text("Your notebook").font(.system(.title2,design:.rounded).weight(.medium));Text("A place for the everyday things.").font(.subheadline).foregroundStyle(Design.muted);badges("tasks",count("task"),"notes",count("note"))}}.padding(.vertical,14)
            default:
                VStack(alignment:.leading,spacing:14){Text("Your day, together.").font(.title2.weight(.medium));HStack(spacing:12){ForEach(Catalog.spaces){space in SpaceMark(space:space)}}.accessibilityHidden(true);Text("A conversation across all your spaces.").font(.subheadline).foregroundStyle(Design.muted)}.padding(.vertical,10)
            }
        }.foregroundStyle(Design.ink)
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
struct GeminiResponse:Codable {let text:String;let recordIds:[String];let actions:[GeminiProposal];var sources:[AssistantSource]?;var searchSuggestions:String?;var cards:[AssistantCard]?;var spokenText:String?;var musicPreview:SongPreview?}
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
    static func answer(question:String,records:[EdizCore.Record],conversation:[ConversationEntry],token:String,scope:String,attachments:[AssistantAttachment]=[],voiceMode:Bool=false,requestMode:String="chat",memories:[EdizCore.Record]=[]) async throws -> GeminiResponse {
        var request=URLRequest(url:URL(string:"https://ediz-os.vercel.app/api/assistant")!);request.httpMethod="POST";request.timeoutInterval=55;request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")
        let encoded=try JSONSerialization.jsonObject(with:JSONEncoder().encode(Array(records.prefix(500))))
        request.httpBody=try JSONSerialization.data(withJSONObject:["mode":requestMode,"voiceMode":voiceMode,"question":question,"scope":scope,"records":encoded,"memories":memories.prefix(12).map{["title":$0.title,"space":$0.space,"body":String($0.body.suffix(6000))]},"conversation":conversation.suffix(8).map{["role":$0.role,"text":$0.contextText]},"localDate":ISO8601DateFormatter().string(from:Date()),"timeZone":TimeZone.current.identifier,"attachments":attachments.map{["name":$0.name,"mimeType":$0.mimeType,"data":$0.bytes.base64EncodedString()]}])
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let response=response as? HTTPURLResponse,(200...299).contains(response.statusCode) else{let detail=(try? JSONSerialization.jsonObject(with:data)) as? [String:String];throw NSError(domain:"EdizAssistant",code:1,userInfo:[NSLocalizedDescriptionKey:detail?["error"] ?? "Your assistant couldn’t answer. Please try again."])}
        return try JSONDecoder().decode(GeminiResponse.self,from:data)
    }
}
struct NativeAssistantReview:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) var dismiss
    let action:GeminiProposal
    var inCall=false
    @State private var creation:EdizCore.Record?
    @State private var createdID:String?
    var existing:EdizCore.Record?{store.records.first{$0.id == action.entityId}}
    var draft:EdizCore.Record {var record=existing ?? EdizCore.Record(space:action.fields?.space ?? "personal",kind:action.fields?.kind ?? "task",title:action.fields?.title ?? "");if let f=action.fields{if let value=f.title{record.title=value};if let value=f.body{record.body=value};if let value=f.space{record.space=value};if let value=f.kind{record.kind=value};if let value=f.status{record.status=value};if let value=f.due{record.due=value};if let value=f.duration{record.duration=value};if let value=f.importance{record.importance=value};if let value=f.data{record.data.merge(value){_,new in new}}};if !Catalog.states(kind:record.kind,space:record.space).contains(record.status){record.status=Catalog.states(kind:record.kind,space:record.space)[0]};return record}
    var body:some View {NavigationStack{ScrollView{VStack(alignment:.leading,spacing:18){Text(action.title).font(Design.font(23));Text(action.type == "delete" ? "This permanently deletes the item and attachments.":draft.status == "CANON" ? "Confirming this establishes canon in Moshia.":"Nothing changes until you confirm.").foregroundStyle(Design.muted);if action.type != "delete"{Surface{VStack(alignment:.leading,spacing:12){Text(draft.title);Text(draft.body);Text(draft.status);if let due=draft.due{Text(due)};ForEach(draft.data.keys.sorted(),id:\.self){key in Text(key+": "+(draft.data[key] ?? ""))}}}};Button(action.type == "create" ? "Review new item":action.type == "delete" ? "Confirm deletion":"Confirm changes"){if action.type == "create"{var record=draft;record.data["_creation"]="1";if inCall{createdID=record.id;creation=record}else{dismiss();DispatchQueue.main.asyncAfter(deadline:.now()+0.35){store.captureRequest=record}}}else if let existing{if action.type == "delete"{if store.remove(existing){dismiss()}}else if store.save(draft){dismiss()}}}.buttonStyle(ActionStyle())}.padding(20)}}.sheet(item:$creation,onDismiss:{if let createdID,store.records.contains(where:{$0.id == createdID}){dismiss()}}){NativeCreation(seed:$0)}.background(AppBackdrop()).navigationTitle("Review suggestion").toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}}
}

struct ThinkingCompanion:View {
    let color:Color
    let reducedMotion:Bool
    var body:some View {
        HStack(spacing:12){
            TimelineView(.animation(minimumInterval:1.0/20,paused:reducedMotion)){timeline in
                HStack(spacing:5){ForEach(0..<3){index in
                    let phase=sin(timeline.date.timeIntervalSinceReferenceDate*5-Double(index)*0.8)
                    Circle().fill(color).frame(width:6,height:6).opacity(reducedMotion ? 0.7:0.45+max(0,phase)*0.55).offset(y:reducedMotion ? 0:-max(0,phase)*5)
                }}.frame(width:38,height:28)
            }
            Text("Thinking through your context…").font(.subheadline).foregroundStyle(Design.muted)
        }.padding(.vertical,12).accessibilityElement(children:.combine).accessibilityIdentifier("assistant-thinking")
    }
}
