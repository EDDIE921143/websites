import SwiftUI
import EdizCore

struct NativeSettings:View {
    @EnvironmentObject var store:NativeStore
    @State private var file:FilePreview?
    @State private var testing=false
    @State private var modelStatus="Not tested. No records are sent by a connection test."
    @State private var checkedEndpoint=""
    var body:some View {
        Form {
            Section("Look & feel"){Picker("Density",selection:Binding(get:{store.preferences.density},set:{var next=store.preferences;next.density=$0;store.setPreferences(next)})){Text("Comfortable").tag("comfortable");Text("Compact").tag("compact")}.pickerStyle(.segmented).walkthroughTarget("density",session:store.walkthrough);Text("Comfortable gives cards room to breathe. Compact uses shorter rows and smaller panels. Touch targets stay easy to reach.").font(.footnote).foregroundStyle(Design.muted)}
            Section("Your attention"){Picker("Current focus",selection:Binding(get:{store.preferences.focus},set:{store.setFocus($0)})){Text("Balanced").tag("all");ForEach(Catalog.spaces){Text($0.name).tag($0.id)}};Text("This gives the chosen space more weight. Deadlines still matter.").font(.footnote).foregroundStyle(Design.muted)}
            Section("Your data"){
                Button("Export full backup"){do{file=FilePreview(url:try store.export())}catch{store.error=error.localizedDescription}}
                Button("Export Ediz OS profile"){do{file=FilePreview(url:try store.exportProfile())}catch{store.error=error.localizedDescription}}
                if let last=Time.date(store.preferences.lastBackup){LabeledContent("Last shared backup",value:last.formatted(date:.abbreviated,time:.omitted))}
                NavigationLink("Import & restore"){NativeImport()}
                NavigationLink("History"){NativeHistory()}
                Text("Seven daily snapshots stay on this device. Export a backup to protect against device loss.").font(.footnote).foregroundStyle(Design.muted)
            }
            Section("Assistant context"){
                LabeledContent("Cloud assistant",value:store.assistantConnected ? "Connected":"Not connected")
                NavigationLink("Review saved context"){NativeAssistantContext()}
                Text("Your workspace briefs and chapter summaries are available to the assistant. You can read and edit them here.").font(.footnote).foregroundStyle(Design.muted)
            }
            Section("Local assistant"){
                Toggle("Enable local model connection",isOn:Binding(get:{store.preferences.labs},set:{store.configureModel(enabled:$0)}))
                if store.preferences.labs{
                    TextField("http://your-computer.local:1234/v1",text:Binding(get:{store.preferences.localEndpoint ?? ""},set:{store.configureModel(endpoint:$0)})).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button(testing ? "Testing connection…":"Test connection") {
                        let endpoint=store.preferences.localEndpoint ?? ""
                        testing=true;checkedEndpoint=endpoint;modelStatus="Testing…"
                        Task { @MainActor in
                            defer{testing=false}
                            do {let names=try await LocalAssistant.models(endpoint:endpoint);if store.preferences.localEndpoint == endpoint{modelStatus="Connected · "+names.joined(separator:", ")}}
                            catch {if store.preferences.localEndpoint == endpoint{modelStatus="Not available. Check that a model is loaded, the LAN address is correct, and local-network access is allowed."}}
                        }
                    }.disabled(testing)
                    Text(checkedEndpoint == (store.preferences.localEndpoint ?? "") ? modelStatus:"Not tested for this address.").font(.footnote).foregroundStyle(Design.muted).accessibilityIdentifier("local-model-status")
                    Text("On iPhone, localhost means this phone. For a model on your Mac, use the Mac’s LAN address on the same Wi-Fi.").font(.footnote).foregroundStyle(Design.muted)
                    Text("Connect a model you run on your local network. Records are sent only when you switch on ‘Use my local model’ in Assistant and ask a question. No paid key is required.").font(.footnote).foregroundStyle(Design.muted)
                }
            }
            Section("Advanced"){NavigationLink("System health"){NativeHealth()};Text("Native edition 0.3.15 · On-device storage, optional cloud AI.").font(.footnote).foregroundStyle(Design.muted)}
            Section {
                NavigationLink { NativeTutorial() } label: {
                    HStack(spacing:14) {
                        Image(systemName:"book.pages.fill").font(.title2).foregroundStyle(Design.ink)
                            .frame(width:48,height:48).background(Design.raised,in:RoundedRectangle(cornerRadius:14))
                        VStack(alignment:.leading,spacing:5){Text("Your guide to Ediz OS").font(.headline);Text("Learn by using the app").font(.subheadline).foregroundStyle(Design.muted)}
                    }.padding(.vertical,8)
                }.accessibilityIdentifier("settings-tutorial").disabled(store.isPractice)
            } header:{Text("Getting started")}
        }.onAppear{store.walkthrough?.event("settings-open")}.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("Settings")
            .sheet(item:$file){shared in NativeShare(url:shared.url){completed in if completed && shared.url.lastPathComponent.hasPrefix("ediz-os-"){store.markBackupShared()}}}
    }
}
struct NativeShare:UIViewControllerRepresentable {
    let url:URL
    let completion:(Bool)->Void
    func makeUIViewController(context:Context)->UIActivityViewController{let controller=UIActivityViewController(activityItems:[url],applicationActivities:nil);controller.completionWithItemsHandler={_,completed,_,_ in Task{@MainActor in completion(completed)}};return controller}
    func updateUIViewController(_ controller:UIActivityViewController,context:Context){}
}
struct NativeAssistantContext:View {
    @EnvironmentObject var store:NativeStore
    @State private var syncing=false
    var body:some View {
        List {
            Section {
                Text("Saved context belongs to you. Each chat uses its workspace records; Everyday can use every space.").font(.subheadline).foregroundStyle(Design.muted)
                Button(syncing ? "Refreshing…":"Refresh context") {
                    syncing=true
                    Task{@MainActor in await store.refresh();syncing=false}
                }.disabled(syncing).accessibilityIdentifier("refresh-assistant-context")
            }
            ForEach(Catalog.spaces) { space in
                Section(space.name) {
                    let briefs=store.records.filter{$0.space == space.id && $0.data["contextType"] == "workspace-brief"}
                    ForEach(briefs) { brief in
                        NavigationLink(value:brief) {
                            VStack(alignment:.leading,spacing:8) {
                                Text(brief.title).foregroundStyle(Design.ink)
                                Text(brief.body).font(.subheadline).foregroundStyle(Design.muted).lineLimit(4)
                                if let sources=brief.data["source"] {Text(sources).font(.caption).foregroundStyle(Design.color(space.color))}
                            }.padding(.vertical,6)
                        }
                    }
                    if briefs.isEmpty{Text("No workspace brief saved yet.").foregroundStyle(Design.muted)}
                    if space.id == "moshia" {
                        NavigationLink(value:SpaceRoute(id:"moshia",kind:"chapter")) {
                            LabeledContent("Chapter summaries",value:String(store.records.filter{$0.space == "moshia" && $0.kind == "chapter"}.count))
                        }
                    }
                }
            }
        }.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("Assistant context")
    }
}
struct NativeHistory:View {
    @EnvironmentObject var store:NativeStore
    var months:[String]{Array(Set(store.activity.map{String($0.at.prefix(7))})).sorted(by:>)}
    var body:some View{List{if months.isEmpty{QuietEmpty(title:"Your history starts here.",message:"Saved work and decisions will be available to look back on.")};ForEach(months,id:\.self){month in Section(month){ForEach(store.activity.filter{$0.at.hasPrefix(month)}){event in VStack(alignment:.leading,spacing:5){Text(event.title).font(.body);Text("\(event.action) · \(Time.date(event.at)?.formatted(date:.abbreviated,time:.shortened) ?? event.at)").font(.caption).foregroundStyle(Design.muted)}}}}}.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("History")}
}
struct NativeHealth:View {
    @EnvironmentObject var store:NativeStore
    var body:some View { Form{Section("Local system"){LabeledContent("Database",value:"SQLite · WAL");LabeledContent("Records",value:String(store.records.count));LabeledContent("History",value:String(store.activity.count));LabeledContent("Storage",value:"App sandbox");LabeledContent("Offline",value:"Core always available");LabeledContent("Search",value:"Local lexical & fuzzy");LabeledContent("AI",value:store.assistantConnected ? "Gemini connected":"Saved context");LabeledContent("Version",value:"0.3.15");Text("Records are stored on this device. AI requests share the selected context with that provider. Speech requires on-device recognition. No analytics are collected.").font(.footnote).foregroundStyle(Design.muted)}}.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("System health") }
}

struct NativeFocusChoice:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) private var dismiss
    var body:some View {VStack(spacing:0){if let session=store.walkthrough{WalkthroughCoach(session:session)};NavigationStack {List {Section {Text("Choose where you want more attention. Important deadlines stay visible.").font(.subheadline).foregroundStyle(Design.muted).listRowSeparator(.hidden);choice("all","Balanced");ForEach(Catalog.spaces){choice($0.id,$0.name)}}}.scrollContentBackground(.hidden).background(AppBackdrop()).onAppear{store.walkthrough?.event("focus-open")}.navigationTitle("Focus on a space").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}}}}
    func choice(_ id:String,_ label:String)->some View {Button{store.setFocus(id);if store.preferences.focus == id{dismiss()}}label:{HStack{Text(label).foregroundStyle(Design.ink);Spacer();if store.preferences.focus == id{Image(systemName:"checkmark").foregroundStyle(Design.ink)}}.frame(minHeight:44)}.listRowSeparator(.hidden).walkthroughTarget(id == "moshia" ? "focus-moshia":"",session:store.walkthrough)}
}

struct WalkthroughStep {
    let title:String
    let instruction:String
    let event:String
    let target:String
    var spoken:String {
        switch event {
        case "tab-2":return "When an idea comes to you, Capture gives you somewhere to put it straight away. You'll find the plus in the bottom bar. Let's open it together."
        case "capture-typed":return "Here's room for your thought. Try writing Practice guitar tomorrow, or use an idea of your own. The preview underneath helps you see where it will go."
        case "captured":return "There it is. Have a look at the preview, and when you're happy with it, Save is waiting in the top corner. This is practice, so your own work stays safe."
        case "tab-4":return "If you want to save chapters, your story has its own home in Moshia. We'll find it through Spaces, at the right of the bottom bar."
        case "chapters-open":return "Each space is a different part of your life. Moshia is where your chapters and story world live. Look for its Chapters shortcut, and we'll start something new."
        case "creation-open":return "This is your chapter collection. The plus at the top opens a fresh chapter. You can come back here whenever you're ready to write the next one."
        case "chapter-titled":return "Give this chapter a name that means something to you. It can be a working title; you'll always be able to change it later."
        case "chapter-context":return "Now let's keep the part you don't want to forget. Who's here? What changes? A sentence in Context worth keeping gives you somewhere to pick up next time."
        case "saved-chapter":return "You have a title and a little context. When it feels ready, the Add button in the corner brings them together as a chapter. This example stays in your practice workspace."
        case "tab-1":return "Your assistant is there when you want to think something through. Let's open Assistant beside Today and try a conversation about your story."
        case "chat-open":return "Each conversation has its own focus. Moshia helps with your story; EJJ Digital is for your business; Clearance 19 is for the band. Let's try the Moshia conversation."
        case "assistant-typed":return "You can talk to it in your own words. Try asking what you've saved about Moshia. The message field is right below the conversation."
        case "assistant-replied":return "When you're ready, the arrow sends your message. This practice conversation uses example context. Your usual chats use your connected assistant and the context you've saved."
        case "tab-3":return "You don't have to remember where every little thing went. Search brings your saved work together. Let's open it and find something."
        case "searched":return "Try looking for guitar. There's a practice task waiting here, and even part of a name can help you find the right thing."
        case "result-open":return "There's your practice task. Open it to see the details. Search can take you straight back into your work, wherever you originally saved it."
        case "settings-open":return "You can make this place feel more like yours. The sliders in the top corner open Settings, where we'll try the two layouts."
        case "density-compact":return "Compact brings things a little closer together. Give it a try and notice how more of your work fits on the screen."
        case "density-comfortable":return "Comfortable gives your cards more breathing room. Try it too, and see which layout feels better to you. Your own choice won't change in this practice."
        case "focus-open":return "Some days, one thing deserves more room. The focus control beside What matters lets you choose which space gets the main part of Today."
        case "focus-moshia":return "Let's make room for your story. Choose Moshia and watch Today take on its colors, with your writing workspace right at the center."
        default:return "Take your time. I'll be here when you're ready for the next part."
        }
    }
}
enum WalkthroughKind:String,CaseIterable,Identifiable {
    case capture,chapters,assistant,search,appearance,focus
    var id:String{rawValue}
    var title:String{switch self{case .capture:return "Capture a thought";case .chapters:return "Create a chapter";case .assistant:return "Explore a chat";case .search:return "Find your work";case .appearance:return "Change the look";case .focus:return "Focus on a space"}}
    var symbol:String{switch self{case .capture:return "plus.circle.fill";case .chapters:return "book.closed.fill";case .assistant:return "text.bubble.fill";case .search:return "magnifyingglass";case .appearance:return "slider.horizontal.3";case .focus:return "scope"}}
    var summary:String{switch self{case .capture:return "Type, preview, and save a thought.";case .chapters:return "Try the chapter title and context fields.";case .assistant:return "Open a workspace and send a practice message.";case .search:return "Search and open a real practice result.";case .appearance:return "Switch layouts and see the change immediately.";case .focus:return "Give Moshia the main space on Today."}}
    var welcome:String {"Hey Ediz, thanks for using Ediz OS. "+(self == .chapters ? "I'll show you how to save a chapter and keep the context that matters. ":"I'll show you around this part of your app. ")+"We can try it together in a practice workspace, so your own work stays safe. "}
    var steps:[WalkthroughStep]{switch self{
    case .capture:return [
        .init(title:"Open Capture",instruction:"Tap Capture, the + in the bottom bar.",event:"tab-2",target:""),
        .init(title:"Try typing",instruction:"Tap the highlighted field. Type ‘Practice guitar tomorrow’ or a thought of your own.",event:"capture-typed",target:"capture-text"),
        .init(title:"Save the thought",instruction:"Look at the preview, then tap the highlighted Save button at the top right.",event:"captured",target:"capture-save")]
    case .chapters:return [
        .init(title:"Open your spaces",instruction:"Tap Spaces in the bottom bar.",event:"tab-4",target:""),
        .init(title:"Find Moshia",instruction:"Tap the highlighted Chapters button in the Moshia card. Scroll a little if needed.",event:"chapters-open",target:"chapters"),
        .init(title:"Add a chapter",instruction:"Tap the highlighted Add chapter button at the top left.",event:"creation-open",target:"add-chapter"),
        .init(title:"Give it a title",instruction:"Tap the highlighted Chapter title field and type a title.",event:"chapter-titled",target:"chapter-title"),
        .init(title:"Keep the context",instruction:"Tap the highlighted Context worth keeping field. Write one sentence about what happens.",event:"chapter-context",target:"chapter-context"),
        .init(title:"Create your chapter",instruction:"Tap the highlighted Add button at the top right. This chapter stays in the practice workspace.",event:"saved-chapter",target:"chapter-save")]
    case .assistant:return [
        .init(title:"Open Assistant",instruction:"Tap Assistant in the bottom bar.",event:"tab-1",target:""),
        .init(title:"Choose a conversation",instruction:"Tap the highlighted Moshia card to open its own conversation.",event:"chat-open",target:"assistant-moshia"),
        .init(title:"Write a message",instruction:"Tap the highlighted Message field and ask ‘What have I saved about Moshia?’.",event:"assistant-typed",target:"assistant-message"),
        .init(title:"Send it",instruction:"Tap the highlighted arrow. Practice uses Saved context; your connected AI chats work outside this tutorial.",event:"assistant-replied",target:"assistant-send")]
    case .search:return [
        .init(title:"Open Search",instruction:"Tap Search in the bottom bar.",event:"tab-3",target:""),
        .init(title:"Search for a thought",instruction:"Tap the search field and type ‘guitar’. You’ll see the practice task below.",event:"searched",target:"search-query"),
        .init(title:"Open the result",instruction:"Tap ‘Practice guitar’. The item opens so you can examine its details.",event:"result-open",target:"search-result")]
    case .appearance:return [
        .init(title:"Open Settings",instruction:"Tap the highlighted sliders button at the top right.",event:"settings-open",target:"settings"),
        .init(title:"Try Compact",instruction:"Tap Compact in the highlighted Look & feel control. Watch the rows become shorter.",event:"density-compact",target:"density"),
        .init(title:"Try Comfortable",instruction:"Tap Comfortable. The cards and rows have room to breathe again.",event:"density-comfortable",target:"density")]
    case .focus:return [
        .init(title:"Choose your attention",instruction:"Tap the highlighted Change focus sliders beside What matters.",event:"focus-open",target:"focus"),
        .init(title:"Choose Moshia",instruction:"Tap the highlighted Moshia row. Then examine the larger story workspace on Today.",event:"focus-moshia",target:"focus-moshia")]
    }}
}
@MainActor final class WalkthroughSession:ObservableObject,Identifiable {
    let id=UUID()
    let kind:WalkthroughKind
    let practice:NativeStore
    @Published var index=0
    @Published var narrationEnabled:Bool
    let narrator=NativeAssistantSpeaker()
    private let narrationToken:String?
    private var guidanceStarted=false
    var onExit:(()->Void)?
    var steps:[WalkthroughStep]{kind.steps}
    var finished:Bool{index >= steps.count}
    var step:WalkthroughStep?{finished ? nil:steps[index]}
    init(kind:WalkthroughKind,narration:Bool=false,token:String?=nil){
        self.narrationEnabled=narration;self.narrationToken=token
        self.kind=kind;practice=NativeStore(practice:true)
        var task=EdizCore.Record(space:"personal",kind:"task",title:"Practice guitar");task.body="A practice item. Open it, inspect its details, and try the controls."
        _=practice.save(task,action:"Practice example")
        var brief=EdizCore.Record(space:"moshia",kind:"note",title:"Moshia practice context");brief.body="Moshia is your story workspace. Chapters, characters and plot threads belong here. This example is only for learning the app.";brief.data["contextType"]="workspace-brief"
        _=practice.save(brief,action:"Practice example")
        practice.walkthrough=self
    }
    func event(_ value:String){guard step?.event == value else{return};index+=1;UISelectionFeedbackGenerator().selectionChanged();readStep()}
    func startGuidance(){guard !guidanceStarted else{return};guidanceStarted=true;readStep(welcome:true)}
    func toggleNarration(){narrationEnabled.toggle();if narrationEnabled{readStep()}else{narrator.stop()}}
    func readStep(welcome:Bool=false){
        narrator.stop();guard narrationEnabled,guidanceStarted else{return}
        let text=(welcome ? kind.welcome:"")+(step?.spoken ?? "Nice, you’ve tried it yourself. That is yours to use whenever you need it. You can explore a little more here, or head back to your app when you’re ready.")
        let defaults=NativeVoicePreferences.defaults
        let voice=defaults.string(forKey:"assistant-natural-voice-name") ?? "Aoede"
        narrator.say(text,token:narrationToken,natural:true,voice:voice)
    }
    func close(){narrator.stop();onExit?()}
}
struct WalkthroughCoach:View {
    @ObservedObject var session:WalkthroughSession
    @ObservedObject private var narrator:NativeAssistantSpeaker
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    init(session:WalkthroughSession){self.session=session;self.narrator=session.narrator}
    var body:some View {
        VStack(alignment:.leading,spacing:10){
            HStack{Label("PRACTICE WORKSPACE",systemImage:"hand.tap.fill").font(.caption2.weight(.semibold)).tracking(1);Spacer();Button{session.close()}label:{Image(systemName:"xmark.circle.fill").font(.title2)}.accessibilityLabel("Exit tutorial").accessibilityIdentifier("walkthrough-exit")}
            if let step=session.step {
                HStack(alignment:.firstTextBaseline){Text(step.title).font(.headline);Spacer();Text("\(session.index+1) / \(session.steps.count)").font(.caption).foregroundStyle(Design.muted)}
                Text(step.instruction).font(.subheadline).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("walkthrough-instruction")
                ProgressView(value:Double(session.index),total:Double(session.steps.count)).tint(Design.ink)
                    .animation(reducedMotion ? nil:.easeInOut(duration:0.25),value:session.index)
            } else {
                Label("You’ve tried it yourself",systemImage:"checkmark.circle.fill").font(.headline).accessibilityIdentifier("walkthrough-complete")
                Text("Look around this practice screen, or return to your app. Your own records and settings haven’t changed.").font(.subheadline)
                Button("Done — back to tutorials"){session.close()}.buttonStyle(ActionStyle()).accessibilityIdentifier("walkthrough-done")
            }
            HStack(spacing:12){
                Button{session.toggleNarration()}label:{Label(session.narrationEnabled ? "Mute guide":"Read aloud",systemImage:session.narrationEnabled ? "speaker.wave.2.fill":"speaker.slash.fill").font(.caption.weight(.medium)).frame(minHeight:44)}.buttonStyle(.plain).accessibilityIdentifier("walkthrough-voice-toggle")
                Spacer()
                if session.narrationEnabled {
                    Text(narrator.preparing ? "Getting ready…":narrator.voiceNote?.hasPrefix("Natural voice") == true ? "Natural voice":narrator.speaking ? "Offline voice":"Guide on").font(.caption).foregroundStyle(Design.muted).accessibilityIdentifier("tutorial-voice-source")
                    Button{session.readStep()}label:{Image(systemName:"arrow.counterclockwise").frame(width:44,height:44)}.buttonStyle(.plain).accessibilityLabel("Replay instruction").accessibilityIdentifier("walkthrough-voice-replay")
                }
            }.accessibilityElement(children:.contain).accessibilityIdentifier("tutorial-voice-activity").accessibilityValue("Audio level \(Int(narrator.level*100))")
        }.foregroundStyle(Design.ink).padding(16).background(Design.raised,in:RoundedRectangle(cornerRadius:18)).padding(.horizontal,12).padding(.vertical,8).background(Design.background)
    }
}
struct WalkthroughTarget:ViewModifier {
    @ObservedObject var session:WalkthroughSession
    let id:String
    func body(content:Content)->some View {
        content.overlay{if !id.isEmpty && session.step?.target == id {RoundedRectangle(cornerRadius:12).strokeBorder(Design.ink,lineWidth:2).padding(-4).allowsHitTesting(false).accessibilityHidden(true)}}
    }
}
extension View {
    @ViewBuilder func walkthroughTarget(_ id:String,session:WalkthroughSession?)->some View {if let session{modifier(WalkthroughTarget(session:session,id:id))}else{self}}
}
struct NativeTutorial:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("tutorial-spoken-guide",store:NativeVoicePreferences.defaults) private var spokenGuide=true
    @State private var session:WalkthroughSession?
    @State private var practiceStore:NativeStore?
    var body:some View {
        ScrollView{VStack(alignment:.leading,spacing:22){
            Image(systemName:"hand.tap.fill").font(.system(size:38)).foregroundStyle(Design.ink)
            Text("Learn by doing.").font(.largeTitle.weight(.semibold))
            Text("Choose something to try. We’ll take you through the real screens, highlight the next control, and move on when you use it.").font(.body).foregroundStyle(Design.muted)
            Label("A separate practice workspace keeps your own records and settings safe.",systemImage:"checkmark.shield.fill").font(.subheadline).foregroundStyle(Design.muted)
            Surface {VStack(alignment:.leading,spacing:8){
                Toggle(isOn:$spokenGuide){Label("Spoken guidance",systemImage:"speaker.wave.2.fill").font(.headline)}.accessibilityIdentifier("tutorial-spoken-guide")
                Text("A friendly walkthrough in your natural voice. Mute or replay anytime. An offline voice keeps the guide available without a connection.").font(.subheadline).foregroundStyle(Design.muted)
            }}
            ForEach(WalkthroughKind.allCases){kind in
                Button{let next=WalkthroughSession(kind:kind,narration:spokenGuide,token:store.assistantToken);practiceStore=next.practice;session=next}label:{HStack(alignment:.top,spacing:16){Image(systemName:kind.symbol).font(.title2).frame(width:34);VStack(alignment:.leading,spacing:7){Text(kind.title).font(.headline);Text(kind.summary).font(.subheadline).foregroundStyle(Design.muted);Text("\(kind.steps.count) hands-on steps").font(.caption).foregroundStyle(Design.muted)};Spacer();Image(systemName:"arrow.right").font(.subheadline)}.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:20))}.buttonStyle(.plain).accessibilityIdentifier("tutorial-start-"+kind.id)
            }
        }.padding(22)}.background(AppBackdrop()).navigationTitle("Your guide").navigationBarTitleDisplayMode(.inline).toolbar(.hidden,for:.tabBar)
            .fullScreenCover(item:$session,onDismiss:{practiceStore?.discardPractice();practiceStore=nil}){active in NativeRoot(store:active.practice).onAppear{active.onExit={session=nil};active.startGuidance()}.onDisappear{active.narrator.stop()}}
            .onChange(of:scenePhase){_,phase in if phase != .active{session?.narrator.stop()}}
    }
}
