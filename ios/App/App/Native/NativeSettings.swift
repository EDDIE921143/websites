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
            Section("Look & feel"){Picker("Density",selection:Binding(get:{store.preferences.density},set:{var next=store.preferences;next.density=$0;store.setPreferences(next)})){Text("Comfortable").tag("comfortable");Text("Compact").tag("compact")}.pickerStyle(.segmented);Text("Comfortable gives cards room to breathe. Compact uses shorter rows and smaller panels. Touch targets stay easy to reach.").font(.footnote).foregroundStyle(Design.muted)}
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
            Section("Advanced"){NavigationLink("System health"){NativeHealth()};Text("Native edition 0.3.10 · On-device storage, optional cloud AI.").font(.footnote).foregroundStyle(Design.muted)}
            Section {
                NavigationLink { NativeTutorial() } label: {
                    HStack(spacing:14) {
                        Image(systemName:"book.pages.fill").font(.title2).foregroundStyle(Design.ink)
                            .frame(width:48,height:48).background(Design.raised,in:RoundedRectangle(cornerRadius:14))
                        VStack(alignment:.leading,spacing:5){Text("Your guide to Ediz OS").font(.headline);Text("A step-by-step walkthrough").font(.subheadline).foregroundStyle(Design.muted)}
                    }.padding(.vertical,8)
                }.accessibilityIdentifier("settings-tutorial")
            } header:{Text("Getting started")}
        }.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("Settings")
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
    var body:some View { Form{Section("Local system"){LabeledContent("Database",value:"SQLite · WAL");LabeledContent("Records",value:String(store.records.count));LabeledContent("History",value:String(store.activity.count));LabeledContent("Storage",value:"App sandbox");LabeledContent("Offline",value:"Core always available");LabeledContent("Search",value:"Local lexical & fuzzy");LabeledContent("AI",value:store.assistantConnected ? "Gemini connected":"Saved context");LabeledContent("Version",value:"0.3.10");Text("Records are stored on this device. AI requests share the selected context with that provider. Speech requires on-device recognition. No analytics are collected.").font(.footnote).foregroundStyle(Design.muted)}}.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("System health") }
}

struct NativeFocusChoice:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) private var dismiss
    var body:some View {NavigationStack {List {Section {Text("Choose where you want more attention. Important deadlines stay visible.").font(.subheadline).foregroundStyle(Design.muted).listRowSeparator(.hidden);choice("all","Balanced");ForEach(Catalog.spaces){choice($0.id,$0.name)}}}.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("Focus on a space").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}}}
    func choice(_ id:String,_ label:String)->some View {Button{store.setFocus(id);if store.preferences.focus == id{dismiss()}}label:{HStack{Text(label).foregroundStyle(Design.ink);Spacer();if store.preferences.focus == id{Image(systemName:"checkmark").foregroundStyle(Design.ink)}}.frame(minHeight:44)}.listRowSeparator(.hidden)}
}

private struct TutorialStep {
    let title:String
    let summary:String
    let symbol:String
    let space:String
    let previewTitle:String
    let previewDetail:String
    let instructions:[String]
    let tip:String
}
struct NativeTutorial:View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var index=0
    private let steps:[TutorialStep]=[
        .init(title:"Make room for your day",summary:"One home for your work, ideas, and the things you want to keep.",symbol:"square.stack.3d.up.fill",space:"all",previewTitle:"Ediz OS",previewDetail:"Today · Spaces · Capture · Search · Assistant",instructions:["Today brings your next steps together.","Spaces keeps each part of your life organized.","Use the center Capture button whenever something comes to mind."],tip:"You can return to this guide from the bottom of Settings at any time."),
        .init(title:"Choose what matters",summary:"Give one workspace your attention without losing your other work.",symbol:"scope",space:"moshia",previewTitle:"Focused on Moshia",previewDetail:"A dedicated workspace at the top of Today",instructions:["Open Today and tap Change focus beside What matters.","Choose a space to see its work and a larger focus panel.","Choose Balanced to bring every space back into view."],tip:"Workspace focus changes Today. It is separate from the timer you start on an individual task."),
        .init(title:"Everything has a place",summary:"Keep business, music, fiction, school, and everyday life distinct.",symbol:"square.grid.2x2.fill",space:"ejj",previewTitle:"Your five spaces",previewDetail:"EJJ Digital · CLEARANCE 19 · Moshia · School · Personal",instructions:["Open Spaces, then choose a workspace.","Tap a module such as Leads, Songs, Chapters, or Homework.","Use Add to create the right kind of item, or tap an existing item to edit it."],tip:"Use the Area picker inside a workspace to move between its modules."),
        .init(title:"Catch the thought",summary:"Get an idea out of your head before worrying about its details.",symbol:"mic.fill",space:"personal",previewTitle:"Capture",previewDetail:"Type a thought or speak it",instructions:["Tap the center Capture button and type your thought.","Tap the microphone to dictate. Allow iOS speech and microphone access when prompted.","Review the space, type, and details, then tap Save."],tip:"For structured work, use Add inside a module. A new chapter then opens the dedicated chapter form."),
        .init(title:"Keep the details clear",summary:"Give each item enough context to make sense when you return.",symbol:"book.closed.fill",space:"moshia",previewTitle:"A chapter, clearly organized",previewDetail:"Title · Context · POV · Purpose · Location",instructions:["Open a chapter to edit its title and context in separate sections.","Keep POV, purpose, and location in their own fields.","Choose the story state deliberately: POSSIBLE, PLANNED, CANON, or REJECTED."],tip:"Planning a possibility does not make it canon. Review the state before saving important story changes."),
        .init(title:"Talk with your context",summary:"Open a conversation for the part of your life you want to work on.",symbol:"bubble.left.and.bubble.right.fill",space:"ejj",previewTitle:"Your own workspace chat",previewDetail:"Saved context · Conversation · Reviewable changes",instructions:["Open Assistant and choose Everyday or a workspace.","Ask a question, plan something, or request a change. Review a proposed change before confirming it.","Use the context menu at the top to choose Gemini, a configured local model, or Saved context."],tip:"Recent chats are kept per workspace. Saved context is an on-device helper; Gemini and a local model provide AI conversation. Provider errors show a retry option."),
        .init(title:"Find it again",summary:"Search the work you have saved without remembering where it lives.",symbol:"magnifyingglass",space:"school",previewTitle:"Search your saved work",previewDetail:"Titles · Notes · Details",instructions:["Open Search and enter a word or phrase.","Use the available filters to narrow the results.","Tap a result to open its full record and make changes."],tip:"Search in this tab works with your local records. Internet research belongs in Assistant and depends on the provider’s availability."),
        .init(title:"Work at your own pace",summary:"Use a timer for a task, or practice music with the tools in your band space.",symbol:"timer",space:"band",previewTitle:"A little focused time",previewDetail:"Start · Pause · Resume · Finish",instructions:["Open a task and choose Focus to start a session.","Pause or resume when you need to. Finish the session when you are done.","For music practice, open CLEARANCE 19 → Songs → Rehearsal mode."],tip:"Rehearsal mode includes the metronome. Keep your device volume at a comfortable level."),
        .init(title:"Make the app yours",summary:"Choose a layout that fits how you like to see your work.",symbol:"slider.horizontal.3",space:"personal",previewTitle:"Comfortable or Compact",previewDetail:"Roomier cards or shorter rows",instructions:["Open Settings from the sliders button at the top of a main screen.","Choose Comfortable for larger panels and more breathing room.","Choose Compact for shorter cards and a denser list. Your choice is saved."],tip:"Text follows your iPhone’s preferred text size. The app also respects Reduce Motion for its transitions."),
        .init(title:"Keep your work safe",summary:"Know what is saved, what the assistant sees, and how to take your work with you.",symbol:"externaldrive.fill",space:"all",previewTitle:"Your data, in your hands",previewDetail:"Context · Full backup · Import & restore",instructions:["In Settings → Assistant context, review and edit your workspace briefs and refresh imported context.","Use Export full backup and save the file somewhere safe. A profile export contains settings, not your records or chats.","Use Import & restore to bring in supported files. Read the preview before merging or restoring."],tip:"Records are stored on your device. AI requests share the selected context with the chosen provider. Imported ChatGPT context is a snapshot; future ChatGPT messages do not sync automatically.")
    ]
    private var step:TutorialStep {steps[index]}
    private var accent:Color {step.space == "all" ? Design.ink:Design.color(Catalog.space(step.space).color)}
    var body:some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    VStack(alignment:.leading,spacing:12) {
                        HStack{Text("Step \(index+1) of \(steps.count)").font(.subheadline.weight(.medium));Spacer();Text("EDIZ OS GUIDE").font(.caption).tracking(1.5).foregroundStyle(Design.muted)}
                        ProgressView(value:Double(index+1),total:Double(steps.count)).tint(accent)
                    }.id("tutorial-top")
                    VStack(alignment:.leading,spacing:12) {
                        Text(step.title).font(.largeTitle.weight(.semibold)).fixedSize(horizontal:false,vertical:true).accessibilityAddTraits(.isHeader)
                        Text(step.summary).font(.body).foregroundStyle(Design.muted).fixedSize(horizontal:false,vertical:true)
                    }
                    HStack(alignment:.center,spacing:18) {
                        if index == 0 {
                            Image("EdizLogo").resizable().scaledToFit().frame(width:60,height:60).clipShape(RoundedRectangle(cornerRadius:16)).accessibilityHidden(true)
                        } else {
                            Image(systemName:step.symbol).font(.system(size:28,weight:.medium)).foregroundStyle(accent)
                                .frame(width:60,height:60).background(accent.opacity(0.15),in:RoundedRectangle(cornerRadius:18)).accessibilityHidden(true)
                        }
                        VStack(alignment:.leading,spacing:8) {
                            Text(step.previewTitle).font(.headline).foregroundStyle(Design.ink)
                            Text(step.previewDetail).font(.subheadline).foregroundStyle(Design.muted).fixedSize(horizontal:false,vertical:true)
                        }.frame(maxWidth:.infinity,alignment:.leading)
                    }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:22))
                    VStack(alignment:.leading,spacing:20) {
                        ForEach(Array(step.instructions.enumerated()),id:\.offset) { number,instruction in
                            HStack(alignment:.top,spacing:14) {
                                Text("\(number+1)").font(.caption.weight(.semibold)).foregroundStyle(accent).frame(width:28,height:28).background(accent.opacity(0.12),in:Circle())
                                Text(instruction).font(.body).fixedSize(horizontal:false,vertical:true).padding(.top,2)
                            }
                        }
                    }
                    HStack(alignment:.top,spacing:12){Image(systemName:"lightbulb").foregroundStyle(accent);Text(step.tip).font(.footnote).foregroundStyle(Design.muted).fixedSize(horizontal:false,vertical:true)}.padding(18).background(Design.surface,in:RoundedRectangle(cornerRadius:18))
                }.padding(24)
            }.onChange(of:index){_,_ in reader.scrollTo("tutorial-top",anchor:.top)}
                .safeAreaInset(edge:.bottom,spacing:0) {
                    HStack(spacing:14) {
                        Button("Previous"){move(-1)}.font(.subheadline.weight(.medium)).frame(minWidth:84,minHeight:50).disabled(index == 0).accessibilityIdentifier("tutorial-previous")
                        Button(index == steps.count-1 ? "Finish":"Continue") {
                            if index == steps.count-1{dismiss()}else{move(1)}
                        }.font(.body.weight(.semibold)).foregroundStyle(Design.background).frame(maxWidth:.infinity,minHeight:50).background(accent,in:RoundedRectangle(cornerRadius:16)).accessibilityIdentifier("tutorial-next")
                    }.padding(.horizontal,24).padding(.vertical,12).background(Design.background)
                }
        }.background(AppBackdrop(scope:step.space)).navigationTitle("Your guide").navigationBarTitleDisplayMode(.inline).toolbar(.hidden,for:.tabBar)
            .toolbar{ToolbarItem(placement:.topBarTrailing){Menu{ForEach(steps.indices,id:\.self){number in Button("\(number+1). "+steps[number].title){index=number}}}label:{Image(systemName:"list.bullet")}.accessibilityLabel("Tutorial contents")}}
    }
    private func move(_ delta:Int){withAnimation(reducedMotion ? nil:.easeOut(duration:0.18)){index=min(steps.count-1,max(0,index+delta))}}
}
