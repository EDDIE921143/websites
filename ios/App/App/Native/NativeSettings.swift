import SwiftUI
import EdizCore

enum RecordedGuide {
    static var voices:[String]{["Aoede","Puck","Kore"].filter{voice in
        let clips=Set(["intro-ai-lab","welcome","complete","lab-complete"]+RecordAssistTool.allCases.map{"lab-tool-"+$0.id}+WalkthroughKind.allCases.flatMap{kind in kind.recordingKeys})
        return clips.allSatisfy{Bundle.main.url(forResource:$0,withExtension:"m4a",subdirectory:"GuideAudio/"+voice) != nil}
    }}
}
struct NativeSettings:View {
    @EnvironmentObject var store:NativeStore
    @State private var file:FilePreview?
    @State private var testing=false
    @State private var modelStatus="Not tested. No records are sent by a connection test."
    @State private var checkedEndpoint=""
    @AppStorage("ediz-reminders-enabled") private var remindersEnabled=false
    @AppStorage("ediz-writing-nudge") private var writingNudge=false
    @AppStorage("guide-playback-speed",store:NativeVoicePreferences.defaults) private var guideSpeed=1.15
    @AppStorage("tutorial-natural-voice-name",store:NativeVoicePreferences.defaults) private var tutorialVoice="Aoede"
    var body:some View {
        Form {
            Section {
                NavigationLink { NativeTutorial() } label: {
                    HStack(spacing:14) {
                        Image(systemName:"book.pages.fill").font(.title2).foregroundStyle(Design.ink)
                            .frame(width:48,height:48).background(Design.raised,in:RoundedRectangle(cornerRadius:14))
                        VStack(alignment:.leading,spacing:5){Text("Your guide to Ediz OS").font(.headline);Text("Spoken walkthroughs · practise on the real screens").font(.subheadline).foregroundStyle(Design.muted)}
                    }.padding(.vertical,8)
                }.accessibilityIdentifier("settings-tutorial").disabled(store.isPractice)
            } header:{Text("Getting started")}
            Section("Look & feel"){Picker("Density",selection:Binding(get:{store.preferences.density},set:{var next=store.preferences;next.density=$0;store.setPreferences(next)})){Text("Comfortable").tag("comfortable");Text("Compact").tag("compact")}.pickerStyle(.segmented).walkthroughTarget("density",session:store.walkthrough);Text("Comfortable gives cards room to breathe. Compact uses shorter rows and smaller panels. Touch targets stay easy to reach.").font(.footnote).foregroundStyle(Design.muted)}
            Section("Your attention"){Picker("Current focus",selection:Binding(get:{store.preferences.focus},set:{store.setFocus($0)})){Text("Balanced").tag("all");ForEach(Catalog.spaces){Text($0.name).tag($0.id)}};Text("This gives the chosen space more weight. Deadlines still matter.").font(.footnote).foregroundStyle(Design.muted)}
            Section("Reminders"){
                Toggle("Notify me about saved dates",isOn:Binding(get:{remindersEnabled},set:{wanted in Task{@MainActor in let enabled=await NativeReminderScheduler.setEnabled(wanted,records:store.records);remindersEnabled=enabled;if wanted && !enabled{store.error="Notifications are off for Ediz OS. Enable them in iPhone Settings to receive reminders."}}})).accessibilityIdentifier("settings-reminders")
                if remindersEnabled{Toggle("A daily Moshia writing nudge",isOn:$writingNudge).onChange(of:writingNudge){_,_ in Task{await NativeReminderScheduler.refresh(records:store.records)}}.accessibilityIdentifier("settings-writing-nudge")}
                Text("Saved dates can remind you an hour ahead; school tests can remind you the day before. The optional writing nudge uses your latest saved Moshia chapter at 18:00. These are on-device reminders, available even when the assistant connection is offline.").font(.footnote).foregroundStyle(Design.muted)
            }
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
            Section("Guide voice"){
                Picker("Guide speed",selection:$guideSpeed){Text("Normal · 1×").tag(1.0);Text("Brisk · 1.15×").tag(1.15);Text("Faster · 1.3×").tag(1.3)}
                Picker("Recorded natural voice",selection:$tutorialVoice){ForEach(RecordedGuide.voices,id:\.self){Text($0).tag($0)}}.disabled(RecordedGuide.voices.count<2).accessibilityIdentifier("tutorial-voice-choice")
                Text("Aoede’s complete guide plays directly from your app, including offline. More recorded narrators need provider capacity; your call offers three natural voices.").font(.footnote).foregroundStyle(Design.muted)
            }
            Section("Advanced"){NavigationLink("System health"){NativeHealth()};Text("Native edition "+(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")+" · On-device storage, optional cloud AI.").font(.footnote).foregroundStyle(Design.muted)}

        }.onAppear{if !RecordedGuide.voices.contains(tutorialVoice){tutorialVoice="Aoede"};store.walkthrough?.event("settings-open")}.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("Settings")
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
    var scope="all"
    @EnvironmentObject var store:NativeStore
    @State private var syncing=false
    var body:some View {
        List {
            Section {
                Text("Saved context belongs to you. Each bot retrieves relevant records only from its own workspace. Everyday retrieves context for the subject you ask about.").font(.subheadline).foregroundStyle(Design.muted)
                Button(syncing ? "Refreshing…":"Refresh context") {
                    syncing=true
                    Task{@MainActor in await store.refresh();syncing=false}
                }.disabled(syncing).accessibilityIdentifier("refresh-assistant-context")
            }
            ForEach(Catalog.spaces.filter{scope == "all" || $0.id == scope}) { space in
                Section(space.name) {
                    let briefs=store.records.filter{$0.space == space.id && $0.data["contextType"] == "workspace-brief"}
                    ForEach(briefs) { brief in
                        NavigationLink(value:brief) {
                            VStack(alignment:.leading,spacing:8) {
                                Text(brief.title).foregroundStyle(Design.ink)
                                Text(brief.body).font(.subheadline).foregroundStyle(Design.muted).lineLimit(4)
                                if let sources=brief.data["source"] {Text(sources).font(.caption).foregroundStyle(WorkspaceTheme.accent(space.id))}
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
    var body:some View { Form{Section("Local system"){LabeledContent("Database",value:"SQLite · WAL");LabeledContent("Records",value:String(store.records.count));LabeledContent("History",value:String(store.activity.count));LabeledContent("Storage",value:"App sandbox");LabeledContent("Offline",value:"Core always available");LabeledContent("Search",value:"Local lexical & fuzzy");LabeledContent("AI",value:store.assistantConnected ? "Gemini connected":"Saved context");LabeledContent("Version",value:Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—");Text("Records are stored on this device. AI requests share the selected context with that provider. Speech requires on-device recognition. No analytics are collected.").font(.footnote).foregroundStyle(Design.muted)}}.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("System health") }
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
    case capture,chapters,assistant,search,appearance,focus,reader,rehearsal,gym,notes,downloads
    var id:String{rawValue}
    var title:String{switch self{case .gym:return "Train with your plan";case .downloads:return "Keep audio offline";case .notes:return "Organize AI Notes";case .capture:return "Capture a thought";case .chapters:return "Create a chapter";case .assistant:return "Explore a chat";case .search:return "Find your work";case .appearance:return "Change the look";case .reader:return "Read your book";case .rehearsal:return "Set up a rehearsal";case .focus:return "Focus on a space"}}
    var symbol:String{switch self{case .gym:return "dumbbell.fill";case .downloads:return "arrow.down.circle";case .notes:return "note.text";case .capture:return "plus.circle.fill";case .chapters:return "book.closed.fill";case .assistant:return "text.bubble.fill";case .search:return "magnifyingglass";case .appearance:return "slider.horizontal.3";case .reader:return "book.pages.fill";case .rehearsal:return "metronome.fill";case .focus:return "scope"}}
    var summary:String{switch self{case .gym:return "Open Gym, choose a day, start a workout and log a real practice set.";case .downloads:return "Start, pause and resume a sample download, then open its player.";case .notes:return "Find a captured idea, filter its space, and open its AI tools.";case .capture:return "Type, preview, and save a thought.";case .chapters:return "Try the chapter title and context fields.";case .assistant:return "Open a workspace and send a practice message.";case .search:return "Search and open a real practice result.";case .appearance:return "Switch layouts and see the change immediately.";case .reader:return "Turn pages, explore contents and make the reader yours.";case .rehearsal:return "Try the setlist, tempo controls and metronome.";case .focus:return "Give Moshia the main space on Today."}}
    var steps:[WalkthroughStep]{[.init(title:self == .capture ? "Welcome to Ediz OS":title,instruction:opening+"\n\n"+lesson,event:"learn-"+id,target:"")]+actionSteps}
    var lesson:String{baseLesson+"\n\n"+extendedLesson}
    var extendedLesson:String{switch self{case .gym:return "Your week is Monday chest, Tuesday back, Thursday legs, Friday back and chest, and Saturday arms. Wednesday and Sunday are rest. Edit day changes order and targets. Add exercise sits below each workout. History keeps finished sessions. The separate practice plan is discarded when you leave.";case .downloads:return "Practice copies a bundled recording on this phone and uses no cloud requests. Your own book generates its narration through your connected assistant, so its first download takes longer. Completed chapters play offline.";case .notes:return "The count reflects the current filter. Clear the search or choose All spaces to see more. Opening a note keeps you in charge of what the AI changes.";case .reader:return "Try changing the type size after this lesson. The pages are measured again so the writing still fits. Warm linen, paper and night give you different reading conditions. Turning pages only changes your position, never the manuscript. This lesson uses invented sample chapters. Your original writing and reading preferences stay separate.";case .rehearsal:return "Song suggestions in Assistant can become a rehearsal setlist. Choose Add to rehearsal, select the songs you want and review before saving. A preview helps you recognize a track; Apple previews play up to thirty seconds inside the app. Nothing is added just because a bot suggested it. Use your ears and the band’s preferences to choose. Start slowly and leave room to experiment.";case .capture:return "There are a few more details worth knowing before you try. When you use Speak, the waveform reacts to your actual voice, while the screen stays clear of unfinished words. The full recording is kept until you finish, so you can explain a longer idea without watching the beginning disappear. After transcription, read through the result. If you said you might do something, it should still be a possibility, not suddenly a promise. If transcription cannot finish, the app keeps the recording so you can try again or save the audio. In a chat, the microphone works inside the message bar. Stop brings your words back as editable text. Send transcribes and then sends them. For a project idea, give one sentence about what you want and another about what would make it useful. You can add the details later. The important part is getting the thought safely out of your head."
case .chapters:return "Your story also has a quieter place to read. In Moshia, Full Book opens the original copied manuscript as an e-reader. A new chapter begins on a new page. Swipe across the page, or touch its right edge to move forward and its left edge to go back. The middle lets the lower controls fade into the background. Contents takes you straight to a chapter. Reader options change the text size and let you choose warm linen, paper or night. Your reading position is remembered. This reader is separate from editing: turning a page cannot rewrite the manuscript. Back in the chapter workspace, keep scene context short enough to scan, then put fuller writing in its proper entry. Characters, the timeline and open story threads help you ask the Moshia bot a more useful continuity question. Possible ideas remain possible until you decide they belong in your story."
case .assistant:return "Here are a few ways to make a conversation useful. Start with the outcome you want, and tell the bot what should stay unchanged. In a call, you can simply talk. It should not replace the voice screen with a prepared list after a greeting. When you want something visible, ask it to show a plan, make a list, or play a preview. The result then has a reason to appear. You can return to the voice view without ending the conversation. The plus beside a message adds a picture, video or file. Explain what you want it to examine, especially with a musical clip: the instrument, the section and the question you are trying to answer. Media understanding can still make mistakes, so compare important details yourself. Copy and Read aloud are under replies. Stop response lets you cancel a request that is no longer useful. Chats keeps different topics apart, and a meaningful title helps you find them again."
case .search:return "Think of meaning search as describing a memory to someone who can look through your saved work. You might say, the scene where the character came back at dusk, or the chat where we decided what to rehearse on Friday. Add the detail you remember, even if you are unsure of the title. The app should show the closest saved match and explain why it might fit, rather than inventing a missing conversation. Open a result to check it. If it is the wrong one, change the description or choose a space to narrow the search. Chat history is searchable too. You do not have to move everything into a note just to find it later. For a decision that matters, saving a short summary still makes returning easier. Your work remains on this device, so Settings also offers a full backup. Share that backup somewhere you control before relying on it for device loss."
case .appearance:return "Different parts of your day can feel different without becoming confusing. A workspace accent helps you recognize where you are, while listening, thinking and playback feedback tell you what the app is doing. Reader appearance is independent, so you can choose a light paper page while the rest of the app stays warm and dark. Comfortable gives longer writing and controls room to breathe. Compact helps you scan a busy collection. Neither choice should change your saved content. In the band workspace, Add your own song keeps your original music separate from Add known songs. Known-song suggestions include a reason to try each track and a real preview when the catalog has one. Add only the songs you want to keep. Apple previews stay inside the app; a full recording may not be available. Notice how a useful label explains what will actually happen."
case .focus:return "A working session should feel like an invitation, not a test. Open a task or chapter and choose Start focus when you want to stay with it. Begin starts an elapsed timer. Pause holds the time, Continue resumes it, and Finish completes the saved item only when you choose. If you are simply leaving for a break, Close is enough. A planned duration is a guide, not a deadline, and the app does not need to rush you. You can keep a short reminder beside the timer, then put the phone down and work. For music, rehearsal mode keeps the song and tempo together. You can enter a BPM directly, use the plus and minus buttons, or tap a beat to find a comfortable tempo. Start slower when learning a part, and raise it when you are ready. The metronome and music preview share audio carefully with voice, so start the activity you actually want to hear."
}}
    var baseLesson:String{switch self{case .gym:return "Gym lives in Spaces, below the other workspaces. We will use that actual screen, choose Tuesday, start its workout, and mark a sample set. The coach stays above the controls. Finish saves this practice session, so you can inspect its summary without changing your own history.";case .downloads:return "We will use the real audiobook controls with a bundled guide-voice sample. It is practice audio, not your book. Start the transfer, pause it, then resume. Finished parts are kept. When the recording is ready, open the player and try pause or seeking.";case .notes:return "AI Notes brings your saved thoughts together. An idea can appear even before you add more context. We will open AI Notes, filter to the band, search for guitar and open a sample thought. Your real notes stay separate.";case .reader:return "Let us give the story room to breathe. Full Book is a quiet reading space, separate from chapter editing. Touch the right side to move forward or swipe across the page. Every chapter has its own opening. Contents helps you jump straight to a chapter instead of hunting for it. We will try a page turn, then visit the second sample chapter. There is no need to rush. Notice how the words sit on the page.";case .rehearsal:return "A rehearsal starts with a song and a comfortable pace. The rehearsal desk keeps the current song, its notes and the setlist together. You can type a tempo, use the plus and minus buttons, or tap your beat. The metronome is optional: it is a tool for listening and practicing, not a test. We will open a sample setlist, adjust the tempo, start a few beats and stop them. The sample songs will not enter your real band records.";case .capture:return "An idea usually arrives before you know how to organize it. Capture is where you can keep that first version without interrupting your train of thought. You can write, or use Speak and explain it in your own words. You do not need to make it sound polished while you are talking. The app records your entire thought and transcribes it after you finish. Stop and keep brings the whole thought back to the editor. With the assistant connected, polishing removes filler and turns the idea into clearer written paragraphs or steps. It should preserve your meaning, your uncertainty and any conditions you mentioned. You can compare the original with the polished version before you decide what to save. Check the destination in the preview too: a school task belongs in School, while a story idea belongs in Moshia. Saving is your decision. In this lesson we will start with typing, inspect the preview and save a practice thought. When you understand that little journey, voice capture follows the same pattern: explain, review, then save."
case .chapters:return "A chapter has more than one job here. Its title helps you find it later, its number keeps the sequence understandable, and its context helps you remember what changes in the scene. Context worth keeping is a place for the important situation, the people involved and the reason the scene matters. It is separate from the title. Your copied Scrivener manuscript is background reference for the assistant; creating a practice chapter here does not rewrite or replace that original script. When you discuss Moshia, the bot should use that reference for continuity and distinguish confirmed story material from possible new ideas. New creative suggestions stay possible unless you choose otherwise. In this lesson, we will open the chapter collection, name a new chapter, add a sentence of context and review it before saving. Think of the chapter entry as an organized place to continue working, not a demand to finish all the prose in one sitting. A working title is enough to begin. You can return to the entry and refine it later."
case .assistant:return "Each workspace gives the assistant a different conversation and purpose. EJJ Digital is for your business, Clearance 19 is for the band, Moshia is for your story, and Everyday is for thinking across your day. Chats keeps separate conversations so you can return to one topic without mixing it with another. A title develops from the real subject after you have said enough; a greeting should not become the whole topic. You can type, dictate a message or start a voice conversation. Under a reply, Copy keeps its text and Read aloud uses your selected natural voice. A voice call should stay conversational. A list, a plan or a music preview should appear because you asked for it, not just because the bot knows your band exists. Proposed changes still need your review before they are saved. Your usual connected bot can use your saved context and attached media; this practice lesson uses sample context so it will not send your own material or change your real work. We will open Moshia, ask a question and inspect the reply together."
case .search:return "Search is useful when you remember the meaning of something but not its exact name. You might remember a chapter where someone returns to a building, a rehearsal decision from a chat, or a task you captured while thinking about tomorrow. Describe what you remember in ordinary words. When the assistant is connected, it looks through the supplied saved work and chat history by meaning after you pause typing. Do you mean introduces the closest memories, with a short explanation of why they may be relevant. You can narrow the search to one space when a description is too broad. Results should take you back to the actual saved item or conversation, not an invented answer. If the connection fails, local search stays available and tells you that the meaning search did not finish. In our practice workspace there is a guitar task waiting to be found. We will search for it and open its details. In your real workspace you can use a fuller description instead of guessing the right keyword."
case .appearance:return "Comfortable and Compact are two ways to give your work room. Comfortable makes reading and pressing controls easier by using larger rows and more breathing space. Compact makes it easier to scan a longer collection on one screen. Changing the layout does not change your records; it changes how they are presented. The workspace colors help you recognize where you are, and active feedback should explain what is happening: listening, thinking, playing or completing an action. Motion has a purpose too. A new reply settles into the conversation, thinking dots show that a request is running, and finishing a step gives you a small celebration. If your device uses Reduce Motion, the app keeps the feedback quieter. We will try both layouts in practice so you can compare them without changing your own preference. Notice the actual rows and controls, not only the selected button. Choose the one that feels comfortable for the way you use your phone, and change it again whenever your needs change."
case .focus:return "Focus gives one part of your life the main place on Today. If you choose Moshia, your story workspace becomes the larger section and the background takes on its identity. Choosing a focus does not hide or delete the other spaces; you can still reach them through Spaces or switch focus again. Today is a place to return to the work that matters now, with Continue where you left off helping you reopen something familiar. Focus is different from a timer: one changes the emphasis of the screen, while the other helps you keep track of a working session. Start small. You might give your story attention for a little while, then return to the band or your schoolwork. In this lesson we will open the focus control and choose Moshia. Have a look at how much room the story receives and how the colors help you recognize that choice. The practice workspace is separate, so your real focus stays as you left it. You are choosing where to put your attention, not making a permanent commitment."
}}
    var accent:Color{WorkspaceTheme.accent(self == .gym ? "gym":self == .rehearsal || self == .notes ? "band":self == .appearance ? "ejj":self == .search ? "school":self == .capture ? "personal":"moshia")}
    var opening:String{switch self{case .capture:return "Welcome, Ediz, to Ediz OS. This is your place for ideas, your story, the band, school and everyday plans. We will start with one thought, then follow it into the parts of the app that help you work with it. Everything you try here stays in a separate practice space. Let us capture your first idea.";case .chapters:return "A captured thought gives an idea somewhere to live. For Moshia, a chapter gives that idea a place in the story. We will separate its title from the context you want to keep, then save a sample chapter.";case .assistant:return "Your writing has a place now. When you want to think it through with someone, open its workspace bot. Let us find Moshia and try a conversation, keeping each topic in its own chat.";case .search:return "As your thoughts and conversations grow, you need a way back to them. We will look for a saved idea and open the actual result. You can describe what you remember rather than guessing its title.";case .appearance:return "Finding your work is easier when the screen feels right. Let us compare Comfortable and Compact in the practice app, and see how the rows and controls change.";case .focus:return "With the layout feeling comfortable, choose what deserves your attention. We will give Moshia the main place on Today. You can change that focus whenever your day changes.";case .reader:return "Moshia has a place to write and a quieter place to read. We will open Full Book, turn its pages and use Contents to choose a chapter. This is sample writing, separate from your manuscript.";case .rehearsal:return "From the story, let us turn to the band. Your rehearsal desk puts songs and tempo together. We will choose a sample song, adjust the beat and try the metronome.";case .gym:return "The same Spaces screen also holds Gym. This time we will walk through the real workout controls, so you know where to go: choose a day, begin, record a set, then finish. Your own training history stays untouched.";case .notes:return "Ideas do not need to stay scattered. AI Notes brings captured thoughts into one view. We will filter by workspace, find a guitar idea and open its tools. This is a new practice lesson for organizing notes.";case .downloads:return "Reading can become listening when the recording is saved. This lesson is specifically about downloading: start, pause, resume and open the audio player. We will copy a bundled voice sample so you can try every control without waiting for cloud narration.";}}
    var farewell:String{switch self{case .capture:return "Your first thought is safe in practice. You have tried the journey from an idea to a saved item. Next, Create a chapter gives a story idea its own place in Moshia.";case .chapters:return "You have kept the title and scene context separate and saved a chapter. Explore a chat is next, where Moshia helps you think through your writing.";case .assistant:return "You have opened a workspace conversation and inspected a reply. When you need to find that work later, the next lesson takes you through Search.";case .search:return "You have found and opened a saved thought. Next we will make the screen feel comfortable for the way you use it.";case .appearance:return "You have compared both layouts. The next lesson gives one workspace the main place on Today, so the app follows what matters to you.";case .focus:return "Moshia now has room on Today. When you are ready to read, Full Book offers a quieter view. That is the next part of the guide.";case .reader:return "You have turned pages and found a chapter through Contents. Your original manuscript is unchanged. The next lesson takes us to the band and its rehearsal desk.";case .rehearsal:return "You have adjusted the tempo and tried a few beats. That is the essentials and the reading and music tour. You can continue with Gym and the newer tools, or return to your own app.";case .gym:return "You have found Gym, chosen a day and finished a practice session. The same controls are ready for your own workouts in Spaces. Your real history is unchanged.";case .notes:return "You have filtered your notes and opened a guitar idea. In your app, the same view helps you find thoughts without searching each workspace. Your practice is separate.";case .downloads:return "You have paused, resumed and opened saved audio. Your own book uses these controls too, with its narration downloaded once and kept offline. Thanks for exploring Ediz OS with me, Ediz. Come back whenever you want another try. Goodbye.";}}
    func spoken(_ step:WalkthroughStep)->String {
        if self == .reader || self == .rehearsal || self == .notes || self == .downloads || self == .gym{return step.instruction+" Take a moment to try it. I will move on when you use the control."}
        return step.spoken+" "+(step.event == "density-compact" ? "Look at the size of the rows and the way the cards change, not just the selected label.":step.event == "chapter-context" ? "Keep this separate from the chapter title. It is a reminder of the scene, not a replacement for the manuscript.":step.event == "assistant-replied" ? "After a real reply, Copy and Read aloud live below it. A proposed change still needs your review before saving.":step.event == "searched" ? "Outside practice, you can describe what you remember in a whole sentence and use meaning search.":"There is no hurry. You can replay this explanation or explore the screen before continuing.")
    }
    var recordingKeys:[String]{["course-"+id+"-flow-intro","course-"+id+"-flow-complete"]+GuideNarration.parts(lesson).indices.map{"course-"+id+"-lesson-"+String($0)}+actionSteps.map{"course-"+id+"-"+$0.event}}
    var actionSteps:[WalkthroughStep]{switch self{
    case .gym:return [.init(title:"Find Gym",instruction:"Open Spaces at the far right, then Gym below the workspace cards.",event:"gym-open",target:""),.init(title:"Choose Tuesday",instruction:"Choose TUE in the weekday strip. This is your back workout.",event:"gym-day",target:"gym-day"),.init(title:"Begin a session",instruction:"Choose Start workout below the day description.",event:"gym-start",target:"gym-start"),.init(title:"Log a sample set",instruction:"The first exercise is expanded. Enter kilograms and repetitions, then mark the circle beside set 1.",event:"gym-set",target:""),.init(title:"Save the session",instruction:"Choose Finish at the top right. The summary shows completed sets, volume and elapsed time.",event:"gym-finish",target:"gym-finish")]
    case .downloads:return [.init(title:"Open your story",instruction:"Open Spaces, then Chapters in Moshia.",event:"chapters-open",target:"chapters"),.init(title:"Enter the reader",instruction:"Choose Full Book at the top right.",event:"reader-open",target:"full-book"),.init(title:"Find the audio",instruction:"Open Book contents. The audio controls are below the chapters.",event:"reader-contents",target:""),.init(title:"Start the sample",instruction:"Choose Download audiobook. Practice uses a bundled guide recording.",event:"download-started",target:""),.init(title:"Pause the transfer",instruction:"Choose Pause while the audio parts are being prepared.",event:"download-paused",target:""),.init(title:"Keep your progress",instruction:"Choose Resume download. Completed parts are reused.",event:"download-resumed",target:""),.init(title:"Open the recording",instruction:"Wait for Ready offline, then choose Play full book. Close the player when you have tried it.",event:"download-play",target:"")]

    case .notes:return [.init(title:"Find your assistant",instruction:"Open Assistant next to Today.",event:"tab-1",target:""),.init(title:"See your notes",instruction:"Choose AI notes above the workspace cards.",event:"ai-notes-open",target:""),.init(title:"Choose a space",instruction:"Open All spaces and choose CLEARANCE 19.",event:"ai-notes-filter",target:""),.init(title:"Find the thought",instruction:"Type guitar in Find notes.",event:"ai-notes-searched",target:""),.init(title:"Work with the idea",instruction:"Open A guitar idea. Its AI tools let you clarify or ask questions.",event:"result-open",target:"")]

    case .reader:return [.init(title:"Find your story",instruction:"Open Spaces. This lesson has two sample chapters ready for you.",event:"tab-4",target:""),.init(title:"Open the chapter shelf",instruction:"Choose Chapters in Moshia. Your story has a reading view as well as an editing view.",event:"chapters-open",target:"chapters"),.init(title:"Settle into the book",instruction:"Open Full Book at the top right. We will read sample writing here.",event:"reader-open",target:"full-book"),.init(title:"Turn a page",instruction:"Swipe left or touch the right edge. Notice how the words have room instead of running into the controls.",event:"reader-turned",target:""),.init(title:"Choose where to read",instruction:"Open Book contents at the top right. You can jump to a chapter without scrolling through the whole book.",event:"reader-contents",target:""),.init(title:"Visit the next chapter",instruction:"Choose The rehearsal room in Contents. A chapter opening deserves its own page.",event:"reader-chapter",target:""),.init(title:"Find offline listening",instruction:"Open Book contents again. Audiobook is below the chapters: choose a narrator, download once, then play the completed audio offline.",event:"reader-audio-open",target:"")]
    case .rehearsal:return [.init(title:"Visit the band",instruction:"Open Spaces, then Songs in CLEARANCE 19. Two sample songs are waiting.",event:"tab-4",target:""),.init(title:"Open your songs",instruction:"Choose Songs in CLEARANCE 19. The rehearsal desk lives above the song collection.",event:"songs-open",target:"songs"),.init(title:"Enter rehearsal",instruction:"Choose Rehearsal mode. The setlist, notes and tempo belong together here.",event:"rehearsal-open",target:"rehearsal"),.init(title:"Find a comfortable pace",instruction:"Try the plus or minus beside BPM. You can also type a number or tap a beat.",event:"rehearsal-tempo",target:"tempo"),.init(title:"Hear the beat",instruction:"Start the metronome. Follow the four beat lights for a moment; the first beat is your anchor.",event:"rehearsal-start",target:"metronome"),.init(title:"Leave room for the music",instruction:"Stop the metronome when you have found your pace. You are in control of what plays.",event:"rehearsal-stop",target:"metronome")]
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
enum GuideNarration {
    static func parts(_ text:String)->[String]{var result:[String]=[];var current="";for word in text.split(whereSeparator:{ $0.isWhitespace }){if current.count+word.count+1>1600{result.append(current);current=""};current += (current.isEmpty ? "":" ")+word};if !current.isEmpty{result.append(current)};return result}
}
@MainActor final class WalkthroughSession:ObservableObject,Identifiable {
    let id=UUID()
    let kind:WalkthroughKind
    let practice:NativeStore
    @Published var index=0
    @Published var celebrating=false
    @Published var narrationEnabled:Bool
    let narrator=NativeAssistantSpeaker()
    private let narrationToken:String?
    private var guidanceStarted=false
    private var celebrationJob:Task<Void,Never>?
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
        if kind == .reader || kind == .downloads{practice.setPracticeManuscript((1...2).map{number in var chapter=EdizCore.Record(space:"moshia",kind:"chapter",title:number == 1 ? "A quiet beginning":"The rehearsal room");chapter.data["binderOrder"]=String(number);chapter.body=(1...18).map{"Sample paragraph \($0). Ediz paused at the doorway and listened. A little light reached the room, and the next idea could wait a moment. This is invented writing for the reading lesson."}.joined(separator:"\n\n");return chapter})}
        if kind == .rehearsal{for title in ["A steady beginning","Room for the chorus"]{var song=EdizCore.Record(space:"band",kind:"song",title:title);song.body="Practice example: listen together, start slowly and leave space for the chorus.";song.data["BPM"]="100";_=practice.save(song)}}
        if kind == .notes{var note=EdizCore.Record(space:"band",kind:"idea",title:"A guitar idea");_=practice.save(note,action:"Practice thought")}
        if kind == .downloads{practice.setPracticeManuscript((1...2).map{number in var chapter=EdizCore.Record(space:"moshia",kind:"chapter",title:"Guide voice sample \(number)");chapter.body="Bundled narration sample for practising local audio controls, not manuscript narration.";chapter.data["binderOrder"]=String(number);return chapter})}
        practice.walkthrough=self
    }
    func event(_ value:String,narrate:Bool=true){guard step?.event == value else{return};index+=1;celebrating=true;celebrationJob?.cancel();celebrationJob=Task{@MainActor in try? await Task.sleep(for:.milliseconds(1800));guard !Task.isCancelled else{return};self.celebrating=false};if finished{NativeVoicePreferences.defaults.set(true,forKey:"guide-completed-"+kind.id)};UINotificationFeedbackGenerator().notificationOccurred(.success);if narrate{readStep()}}
    func startGuidance(){guard !guidanceStarted else{return};guidanceStarted=true;readStep(welcome:true)}
    func toggleNarration(){narrationEnabled.toggle();if narrationEnabled{readStep()}else{narrator.stop()}}
    func muteForRecording(){narrator.stop()}
    func readStep(welcome:Bool=false){
        narrator.stop();guard narrationEnabled,guidanceStarted else{return}
        let defaults=NativeVoicePreferences.defaults
        let selected=defaults.string(forKey:"tutorial-natural-voice-name") ?? "Aoede"
        let voice=RecordedGuide.voices.contains(selected) ? selected:"Aoede"
        var clips:[String]=[]
        if welcome{
            clips.append("course-"+kind.id+"-flow-intro")
        }
        if let step{if step.event.hasPrefix("learn-"){clips += GuideNarration.parts(kind.lesson).indices.map{"course-"+kind.id+"-lesson-"+String($0)}}else{clips.append("course-"+kind.id+"-"+step.event)}}else{clips.append("course-"+kind.id+"-flow-complete")}
        let urls=clips.compactMap{Bundle.main.url(forResource:$0,withExtension:"m4a",subdirectory:"GuideAudio/"+voice)}
        guard urls.count==clips.count else{narrator.voiceNote="This recorded guide isn’t available yet. Your interactive steps are ready.";return}
        narrator.setPlaybackRate(Float(defaults.object(forKey:"guide-playback-speed") as? Double ?? 1.15));narrator.playRecorded(urls,voice:voice)
    }
    func close(){celebrationJob?.cancel();narrator.stop();onExit?()}
}
struct GuideVoiceMark:View {
    let accent:Color
    let level:CGFloat
    let speaking:Bool
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var body:some View {
        ZStack {
            RoundedRectangle(cornerRadius:12).fill(accent.opacity(speaking ? 0.22:0.12))
            RoundedRectangle(cornerRadius:12).strokeBorder(accent.opacity(speaking ? 0.8:0.35),lineWidth:1)
            HStack(alignment:.center,spacing:3){
                ForEach(0..<3,id:\.self){index in
                    Capsule().fill(accent).frame(width:3,height:speaking ? 6+min(17,level*CGFloat(11+index*5)):CGFloat(4+index*2))
                }
            }
        }.frame(width:36,height:36)
            .animation(reducedMotion ? nil:.easeOut(duration:0.12),value:level)
            .accessibilityHidden(true)
    }
}
struct WalkthroughCoach:View {
    @ObservedObject var session:WalkthroughSession
    @ObservedObject private var narrator:NativeAssistantSpeaker
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var expanded=false
    init(session:WalkthroughSession){self.session=session;self.narrator=session.narrator}
    var body:some View {Group{if expanded{detailed}else{compactCoach}}.animation(reducedMotion ? nil:.easeOut(duration:0.22),value:expanded)}
    var compactCoach:some View {
        VStack(alignment:.leading,spacing:4){
            HStack(spacing:10){GuideVoiceMark(accent:session.kind.accent,level:CGFloat(narrator.level),speaking:session.narrationEnabled && narrator.speaking)
                VStack(alignment:.leading,spacing:3){Text(session.step?.title ?? "You made it your own.").font(.subheadline.weight(.semibold));if let step=session.step,!step.event.hasPrefix("learn-"){Text(step.instruction).font(.caption).foregroundStyle(Design.muted).lineLimit(2)}}
                Spacer(minLength:0);Button{session.close()}label:{Image(systemName:"xmark").frame(width:44,height:44)}.accessibilityLabel("Exit tutorial").accessibilityIdentifier("walkthrough-exit")
            }
            HStack(spacing:12){
                Button{expanded=true}label:{VStack(alignment:.leading,spacing:2){Text("Show guidance").font(.caption);if session.narrationEnabled{HStack(spacing:3){ForEach(0..<4,id:\.self){index in Capsule().fill(session.kind.accent).frame(width:3,height:3+CGFloat(narrator.level)*CGFloat(6+index*3))};Text(narrator.preparing ? "Getting ready…":narrator.speaking ? "Your guide is speaking":"Natural voice")}.animation(reducedMotion ? nil:.easeOut(duration:0.1),value:narrator.level).font(.caption2).foregroundStyle(Design.muted).accessibilityIdentifier("tutorial-voice-source")}}.frame(minHeight:44)}
                Button{session.toggleNarration()}label:{Image(systemName:session.narrationEnabled ? "speaker.wave.2.fill":"speaker.slash.fill").frame(width:44,height:44)}.accessibilityLabel(session.narrationEnabled ? "Mute guide":"Read aloud").accessibilityIdentifier("walkthrough-voice-toggle")
                if session.narrationEnabled{Button{session.readStep()}label:{Image(systemName:"arrow.counterclockwise").frame(width:44,height:44)}.accessibilityLabel("Replay instruction").accessibilityIdentifier("walkthrough-voice-replay")}
                Spacer(minLength:0)
                if let step=session.step{if step.event.hasPrefix("learn-"){Button("Let’s try it"){session.event(step.event)}.font(.caption.weight(.semibold)).frame(minHeight:44).accessibilityIdentifier("walkthrough-lesson-continue")}else{Text("\(session.index+1) / \(session.steps.count)").font(.caption.monospacedDigit()).foregroundStyle(Design.muted)}}else{Button("Done"){session.close()}.font(.caption.weight(.semibold)).frame(minHeight:44).accessibilityLabel("Done — back to tutorials").accessibilityIdentifier("walkthrough-done")}
            }.accessibilityElement(children:.contain).accessibilityIdentifier("tutorial-voice-activity").accessibilityValue("Audio level \(Int(narrator.level*100))")
            GeometryReader{size in Capsule().fill(session.kind.accent.opacity(0.16)).overlay(alignment:.leading){Capsule().fill(session.kind.accent).frame(width:size.size.width*CGFloat(session.index)/CGFloat(max(1,session.steps.count)))}}.frame(height:3).accessibilityLabel("Lesson progress").accessibilityValue("Step \(min(session.index+1,session.steps.count)) of \(session.steps.count)")
            if session.celebrating{HStack(spacing:6){Image(systemName:"sparkle").foregroundStyle(session.kind.accent).symbolEffect(.bounce,value:reducedMotion ? 0:session.index);Text(session.finished ? "Ready for your own workspace":"One step closer").font(.caption2.weight(.medium)).foregroundStyle(Design.muted)}.frame(maxWidth:.infinity).transition(.opacity)}
        if session.finished{HStack(spacing:12){Image(systemName:"star.circle.fill").font(.system(size:30)).foregroundStyle(session.kind.accent).symbolEffect(.bounce,value:reducedMotion ? 0:session.index);VStack(alignment:.leading,spacing:2){Text("Course complete").font(.subheadline.weight(.semibold));Text(session.kind.title+" · Explored").font(.caption).foregroundStyle(Design.muted)}}.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:14)).transition(.opacity.combined(with:.scale(scale:0.95)))}
        }.animation(reducedMotion ? nil:.spring(duration:0.45,bounce:0.2),value:session.finished).animation(reducedMotion ? nil:.easeOut(duration:0.25),value:session.celebrating).animation(reducedMotion ? nil:.easeOut(duration:0.25),value:session.index).padding(.horizontal,14).padding(.top,8).background(Design.raised,in:RoundedRectangle(cornerRadius:16)).padding(.horizontal,20).padding(.vertical,8).background(Design.background)
    }
    var detailed:some View {
        VStack(alignment:.leading,spacing:10){
            HStack(spacing:8){GuideVoiceMark(accent:session.kind.accent,level:CGFloat(narrator.level),speaking:session.narrationEnabled && narrator.speaking);Button{withAnimation{expanded.toggle()}}label:{Text(expanded ? "LESS GUIDANCE":"SHOW GUIDANCE")}.font(.caption2.weight(.semibold)).tracking(1);Spacer();Button{session.close()}label:{Image(systemName:"xmark.circle.fill").font(.title2)}.accessibilityLabel("Exit tutorial").accessibilityIdentifier("walkthrough-exit")}
            if session.celebrating {Label(session.finished ? "Woohoo! You did it!":"Nice — you’ve got it!",systemImage:"checkmark.seal.fill").font(.subheadline.weight(.semibold)).foregroundStyle(session.kind.accent).symbolEffect(.bounce,value:reducedMotion ? 0:session.index).transition(reducedMotion ? .opacity:.move(edge:.top).combined(with:.opacity))}
            if session.celebrating && expanded{HStack(spacing:8){ForEach(0..<7,id:\.self){index in Image(systemName:index%2==0 ? "sparkle":"circle.fill").font(.system(size:index%2==0 ? 16:5)).foregroundStyle(session.kind.accent.opacity(0.4+Double(index%3)*0.2)).offset(y:reducedMotion ? 0:CGFloat(index%2==0 ? -3:3))}}.frame(maxWidth:.infinity).transition(.opacity)}
            if let step=session.step {
                HStack(alignment:.firstTextBaseline){Text(step.title).font(.headline);Spacer();Text("\(session.index+1) / \(session.steps.count)").font(.caption).foregroundStyle(Design.muted)}
                if step.event.hasPrefix("learn-"){if expanded{ScrollView{Text(step.instruction).font(.subheadline).lineSpacing(4).fixedSize(horizontal:false,vertical:true).padding(.vertical,4)}.frame(maxHeight:160)};Button("Let’s try it"){session.event(step.event)}.buttonStyle(ActionStyle()).accessibilityIdentifier("walkthrough-lesson-continue")}
                else{Text(step.instruction).font(.subheadline).lineLimit(expanded ? nil:2).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("walkthrough-instruction")}
                HStack(spacing:5){ForEach(0..<session.steps.count,id:\.self){number in Capsule().fill(number<session.index ? session.kind.accent:number==session.index ? Design.ink:Design.muted.opacity(0.2)).frame(height:number==session.index ? 7:4)}}.accessibilityLabel("Step \(session.index+1) of \(session.steps.count)")
                    .animation(reducedMotion ? nil:.easeInOut(duration:0.25),value:session.index)
            } else {
                Label("You’ve tried it yourself",systemImage:"checkmark.circle.fill").symbolEffect(.bounce,value:reducedMotion ? 0:session.index).font(.headline).accessibilityIdentifier("walkthrough-complete")
                Text("Look around this practice screen, or return to your app. Your own records and settings haven’t changed.").font(.subheadline)
                Button("Done — back to tutorials"){session.close()}.buttonStyle(ActionStyle()).accessibilityIdentifier("walkthrough-done")
            }
            if let note=narrator.voiceNote,!note.hasPrefix("Recorded natural voice"){Text(note).font(.footnote).foregroundStyle(Design.muted)}
            HStack(spacing:12){
                Button{session.toggleNarration()}label:{Label(session.narrationEnabled ? "Mute guide":"Read aloud",systemImage:session.narrationEnabled ? "speaker.wave.2.fill":"speaker.slash.fill").font(.caption.weight(.medium)).frame(minHeight:44)}.buttonStyle(.plain).accessibilityIdentifier("walkthrough-voice-toggle")
                Spacer()
                if session.narrationEnabled {
                    Text(narrator.preparing ? "Getting ready…":narrator.voiceNote?.hasPrefix("Recorded natural voice") == true ? "Natural voice":"Guide on").font(.caption).foregroundStyle(Design.muted).accessibilityIdentifier("tutorial-voice-source")
                    Button{session.readStep()}label:{Image(systemName:"arrow.counterclockwise").frame(width:44,height:44)}.buttonStyle(.plain).accessibilityLabel("Replay instruction").accessibilityIdentifier("walkthrough-voice-replay")
                }
            }.accessibilityElement(children:.contain).accessibilityIdentifier("tutorial-voice-activity").accessibilityValue("Audio level \(Int(narrator.level*100))")
        }.animation(reducedMotion ? nil:.spring(response:0.35,dampingFraction:0.8),value:session.celebrating).animation(reducedMotion ? nil:.easeInOut(duration:0.25),value:session.index).foregroundStyle(Design.ink).padding(16).background(Design.raised,in:RoundedRectangle(cornerRadius:18)).padding(.horizontal,20).padding(.vertical,8).background(Design.background)
    }
}
struct WalkthroughTarget:ViewModifier {
    @ObservedObject var session:WalkthroughSession
    let id:String
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    func body(content:Content)->some View {
        content.overlay{if !id.isEmpty && session.step?.target == id {RoundedRectangle(cornerRadius:12).strokeBorder(session.kind.accent,lineWidth:2).padding(-3).phaseAnimator([false,true],trigger:session.index){view,phase in view.opacity(phase && !reducedMotion ? 0.5:1).scaleEffect(phase && !reducedMotion ? 1.015:1)}animation:{_ in .easeOut(duration:0.45)}.allowsHitTesting(false).accessibilityHidden(true)}}
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
    @State private var aiLab=false
    var body:some View {
        ScrollView{VStack(alignment:.leading,spacing:22){
            HStack{Image(systemName:"hand.tap.fill").font(.system(size:38)).foregroundStyle(Design.ink);Spacer();Text("YOUR APP, TOGETHER").font(.caption2.weight(.semibold)).tracking(1.5).foregroundStyle(Design.muted)}
            Text("Learn by doing.").font(.largeTitle.weight(.semibold))
            Text("Start with Capture, then create a chapter and try a chat. These same lessons always stay here. Each uses the real controls in a separate practice workspace.").font(.body).foregroundStyle(Design.muted)
            Label("A separate practice workspace keeps your own records and settings safe.",systemImage:"checkmark.shield.fill").font(.subheadline).foregroundStyle(Design.muted)
            Surface {VStack(alignment:.leading,spacing:8){
                Toggle(isOn:$spokenGuide){Label("Spoken guidance",systemImage:"speaker.wave.2.fill").font(.headline)}.accessibilityIdentifier("tutorial-spoken-guide")
                Text("A recorded natural voice guides you through each step. Choose your narrator in Settings. Mute or replay anytime, even offline.").font(.subheadline).foregroundStyle(Design.muted)
            }}
            ForEach(Array(WalkthroughKind.allCases.enumerated()),id:\.element.id){position,kind in
                if position == 0{Text("Start with the essentials").font(.title3.weight(.medium))};if position == 6{Text("Go a little further").font(.title3.weight(.medium))}
                Button{let next=WalkthroughSession(kind:kind,narration:spokenGuide,token:store.assistantToken);practiceStore=next.practice;session=next}label:{HStack(alignment:.top,spacing:16){Image(systemName:kind.symbol).font(.title2).foregroundStyle(kind.accent).frame(width:48,height:48).background(kind.accent.opacity(0.12),in:RoundedRectangle(cornerRadius:14));VStack(alignment:.leading,spacing:7){Text(kind.title).font(.headline);Text(kind.summary).font(.subheadline).foregroundStyle(Design.muted);Label(NativeVoicePreferences.defaults.bool(forKey:"guide-completed-"+kind.id) ? "Explored · Try again":"\(kind.steps.count) steps · About \(max(3,kind.steps.count)) min",systemImage:NativeVoicePreferences.defaults.bool(forKey:"guide-completed-"+kind.id) ? "checkmark.circle.fill":"hand.point.up.left").font(.caption).foregroundStyle(Design.muted)};Spacer();Image(systemName:"arrow.right").font(.subheadline)}.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:20))}.buttonStyle(.plain).accessibilityIdentifier("tutorial-start-"+kind.id)
            }
            Text("Practice with AI and your Gym").font(.title3.weight(.medium))
            Button{aiLab=true}label:{HStack(alignment:.top,spacing:16){Image(systemName:"sparkles").font(.title2);VStack(alignment:.leading,spacing:7){Text("AI notes lab").font(.headline);Text("Try clarity, summaries, next steps and questions. Review the result, then apply it to a sample draft.").font(.subheadline).foregroundStyle(Design.muted);Label("4 tools · Hands-on practice",systemImage:"hand.tap").font(.caption).foregroundStyle(Design.muted)};Spacer();Image(systemName:"arrow.right")}.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:20))}.buttonStyle(.plain).accessibilityIdentifier("tutorial-ai-lab")

            NavigationLink{NativeNewFeatures()}label:{HStack(spacing:16){Image(systemName:"sparkles.rectangle.stack").font(.title2);VStack(alignment:.leading,spacing:7){Text("New additions").font(.headline);Text("Try the new features in guided practice").font(.subheadline).foregroundStyle(Design.muted)};Spacer();Image(systemName:"arrow.right")}.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:20))}.buttonStyle(.plain).accessibilityIdentifier("tutorial-new-additions")
        }.padding(22)}.background(AppBackdrop()).navigationTitle("Your guide").sheet(isPresented:$aiLab){NativeAIWorkshop(narrationEnabled:spokenGuide).presentationDetents([.large])}.navigationBarTitleDisplayMode(.inline).toolbar(.hidden,for:.tabBar)
            .fullScreenCover(item:$session,onDismiss:{practiceStore?.discardPractice();practiceStore=nil}){active in NativeRoot(store:active.practice).onAppear{active.onExit={session=nil};active.startGuidance()}.onDisappear{active.narrator.stop()}}
            .onChange(of:scenePhase){_,phase in if phase != .active{session?.narrator.stop()}}
    }
}

struct NativeNewFeatures:View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var store:NativeStore
    @StateObject private var narrator=NativeAssistantSpeaker()
    @AppStorage("tutorial-spoken-guide",store:NativeVoicePreferences.defaults) private var spoken=true
    @State private var session:WalkthroughSession?
    @StateObject private var musicPractice=NativeStore(practice:true)
    @State private var aiLab=false
    var body:some View {ScrollView{VStack(alignment:.leading,spacing:18){
        HStack(spacing:12){GuideVoiceMark(accent:Design.ink,level:narrator.level,speaking:narrator.speaking);VStack(alignment:.leading,spacing:4){Text("Try the new features.").font(.title2.weight(.semibold));Text("The same guide · more things to practise").font(.caption).foregroundStyle(Design.muted)};Spacer();Button{if narrator.speaking{narrator.stop()}else{read()}}label:{Image(systemName:narrator.speaking ? "stop.fill":"speaker.wave.2.fill").frame(width:44,height:44)}.accessibilityLabel("Read the introduction")}
        Text("Start a lesson below. The practice stays separate from your own work, and you can replay or return to the essentials anytime.").font(.subheadline).foregroundStyle(Design.muted)
        course("Organize AI Notes","Filter, find and open a thought using the real AI Notes controls.","note.text",kind:.notes,id:"new-organize-notes")
        course("Keep audio offline","Start, pause, resume and play a bundled practice recording.","arrow.down.circle",kind:.downloads,id:"new-offline-audio")
        Text("Earlier additions").font(.title3.weight(.medium)).padding(.top,8)
        NavigationLink{NativeMusicPracticeRoom().environmentObject(musicPractice)}label:{feature("Music practice cards","Try the original tab grid, visual timing and chord shapes.","guitars","Hands-on music tools")}.buttonStyle(.plain).accessibilityIdentifier("new-music-tools")
        course("Your week in the gym","Find Gym in Spaces, start a sample workout, log a set and finish.","dumbbell.fill",kind:.gym,id:"new-gym-guide")
        Button{narrator.stop();aiLab=true}label:{feature("Clearer thoughts","Try clarity, questions, summaries and next steps on a sample note.","note.text","4 tools · safe practice draft")}.buttonStyle(.plain).accessibilityIdentifier("new-notes-lab")
        if let note=narrator.voiceNote,!note.hasPrefix("Recorded natural voice"){Text(note).font(.caption).foregroundStyle(Design.muted)}
    }.padding(22)}.background(AppBackdrop()).navigationTitle("New additions").navigationBarTitleDisplayMode(.inline).onAppear{if spoken{read()}}.onDisappear{narrator.stop()}.onChange(of:scenePhase){_,phase in if phase != .active{narrator.stop()}}
        .sheet(isPresented:$aiLab){NativeAIWorkshop(narrationEnabled:spoken)}
        .fullScreenCover(item:$session,onDismiss:{session?.practice.discardPractice()}){active in NativeRoot(store:active.practice).onAppear{active.onExit={active.practice.discardPractice();session=nil};active.startGuidance()}.onDisappear{active.narrator.stop()}}
    }
    func course(_ title:String,_ detail:String,_ symbol:String,kind:WalkthroughKind,id:String)->some View{Button{narrator.stop();session=WalkthroughSession(kind:kind,narration:spoken,token:store.assistantToken)}label:{feature(title,detail,symbol,"\(kind.steps.count) guided steps · real practice screens")}.buttonStyle(.plain).accessibilityIdentifier(id)}
    func feature(_ title:String,_ detail:String,_ symbol:String,_ caption:String)->some View{HStack(alignment:.top,spacing:14){Image(systemName:symbol).font(.title2).frame(width:42,height:42).background(Design.raised,in:RoundedRectangle(cornerRadius:12));VStack(alignment:.leading,spacing:8){Text(title).font(.headline);Text(detail).font(.subheadline).foregroundStyle(Design.muted);Label(caption,systemImage:"hand.tap").font(.caption).foregroundStyle(Design.muted)};Spacer(minLength:0);Image(systemName:"arrow.right").font(.subheadline).padding(.top,12)}.foregroundStyle(Design.ink).padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:20))}
    func read(){narrator.setPlaybackRate(Float(NativeVoicePreferences.defaults.object(forKey:"guide-playback-speed") as? Double ?? 1.15));if let url=Bundle.main.url(forResource:"new-additions-v2",withExtension:"m4a",subdirectory:"GuideAudio/Aoede"){narrator.playRecorded([url],voice:"Aoede")}else{narrator.voiceNote="This guide recording isn't available on this build."}}
}
struct NativeMusicPracticeRoom:View {
    let tab=AssistantCard(type:"tablature",title:"An original warm-up",subtitle:"Guitar · standard tuning · one quarter-note per step",items:[AssistantCardItem(title:"e",detail:"-,-,-,-,-,-,-,-"),AssistantCardItem(title:"B",detail:"-,-,-,-,-,-,-,-"),AssistantCardItem(title:"G",detail:"-,-,-,-,-,-,-,-"),AssistantCardItem(title:"D",detail:"-,-,-,-,-,-,-,-"),AssistantCardItem(title:"A",detail:"-,-,-,-,-,-,-,-"),AssistantCardItem(title:"E",detail:"0,1,2,3,3,2,1,0")])
    let chords=AssistantCard(type:"chords",title:"Two starting shapes",subtitle:"Guitar · standard tuning · low E to high e",items:[AssistantCardItem(title:"Em",detail:"0,2,2,0,0,0"),AssistantCardItem(title:"Am",detail:"x,0,2,2,1,0")])
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:22){Text("Music you can see.").font(.largeTitle.weight(.semibold));Text("Try these original examples. In CLEARANCE 19, ask for a pattern, chord shapes or a verified song-tab source.").foregroundStyle(Design.muted);NativeMusicNotation(card:tab,scope:"band");NativeMusicNotation(card:chords,scope:"band");NavigationLink{NativeConversationHost(scope:"band")}label:{Label("Ask CLEARANCE 19",systemImage:"sparkles")}.buttonStyle(ActionStyle())}.padding(20)}.background(AppBackdrop(scope:"band")).navigationTitle("Music tools").navigationBarTitleDisplayMode(.inline)}
}
