import SwiftUI
import EdizCore

struct NativeRoot:View {
    @StateObject private var store: NativeStore
    init(store: NativeStore) { _store = StateObject(wrappedValue: store) }
    #if DEBUG
    var gymChangeFixture:GeminiProposal {let gym=GymStore();gym.load(store);let day=gym.state.days[0];return GeminiProposal(type:"gym",title:"Make chest press four sets",fields:GeminiFields(data:["operation":"edit","dayID":day.id.uuidString,"entryID":day.exercises[0].id.uuidString,"sets":"4","rest":"120"]))}
    static var readerFixture:[EdizCore.Record]{(1...2).map{number in var chapter=EdizCore.Record(space:"moshia",kind:"chapter",title:"Practice chapter \(number)");chapter.data["binderOrder"]=String(number);chapter.body=(1...35).map{"Sample paragraph \($0). A quiet reading page gives the words enough room. This is demonstration text for checking page navigation, not the private manuscript."}.joined(separator:"\n\n");return chapter}}
    static var readerJoinedFixture:[EdizCore.Record]{readerAudioFixture.map{var chapter=$0;chapter.title="Joined "+chapter.title;return chapter}}
    static var readerAudioFixture:[EdizCore.Record]{(1...2).map{number in var chapter=EdizCore.Record(space:"moshia",kind:"chapter",title:"Practice chapter \(number)");chapter.data["binderOrder"]=String(number);chapter.body=(1...4).map{_ in "A quiet reading page gives the words enough room. This short demonstration chapter checks natural audiobook playback, chapter selection, and saved recordings."}.joined(separator:"\n\n");return chapter}}
    #endif
    @State private var selected=0
    @State private var previous=0
    @State private var capturedRecord:EdizCore.Record?
    @State private var captureFeedbackJob:Task<Void,Never>?
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var body:some View {
        VStack(spacing:0) {
            if let session=store.walkthrough,!store.practiceOverlay {WalkthroughCoach(session:session)}
        Group {
            if store.ready {
                TabView(selection:$selected) {
                    OSNavigation{NativeToday()}.tabItem{Label("Today",systemImage:"house.fill")}.tag(0)
                    OSNavigation{NativeAssistant()}.tabItem{Label("Assistant",systemImage:"text.bubble.fill")}.tag(1)
                    NativeCaptureTab { selected=previous }.tabItem{Label("Capture",systemImage:"plus.circle.fill")}.tag(2)
                    OSNavigation{NativeSearch()}.tabItem{Label("Search",systemImage:"magnifyingglass")}.tag(3)
                    OSNavigation{NativeSpaces()}.tabItem{Label("Spaces",systemImage:"square.stack.3d.up.fill")}.tag(4)
                }.tint(Design.accent)
                    .background{if !store.isPractice{NativeTabScrubber(selection:$selected)}}
                    .onChange(of:selected){_,next in if next != 2 {previous=next};store.walkthrough?.event("tab-\(next)") }
                    .sheet(item:$store.captureRequest){seed in Group { if seed.data["_creation"] == "1" { NativeCreation(seed:seed) } else { NativeCapture(seed:seed) } }.presentationDetents([.large]).presentationDragIndicator(.visible)}
                    .fullScreenCover(item:$store.focusRequest){NativeFocus(record:$0)}
                    .overlay(alignment:.bottom){if let completed=store.undoRecord{CompletionToast(undo:{store.undo()},dismiss:{store.undoRecord=nil}).id(completed.id).padding(.horizontal,20).padding(.bottom,80).transition(.move(edge:.bottom).combined(with:.opacity))}}
                    .animation(reducedMotion ? nil:.spring(duration:0.35,bounce:0.18),value:store.undoRecord?.id)
                    .overlay(alignment:.bottom){if let record=capturedRecord,store.undoRecord == nil{HStack(spacing:12){Image(systemName:"checkmark.circle.fill").foregroundStyle(WorkspaceTheme.accent(record.space));VStack(alignment:.leading,spacing:3){Text("Saved to "+Catalog.space(record.space).name).font(.subheadline.weight(.semibold));Text(record.title).font(.caption).lineLimit(1).foregroundStyle(Design.muted)};Spacer()}.padding(16).background(.regularMaterial,in:RoundedRectangle(cornerRadius:18)).padding(.horizontal,20).padding(.bottom,76).transition(.move(edge:.bottom).combined(with:.opacity)).allowsHitTesting(false)}}
                    .animation(reducedMotion ? nil:.spring(duration:0.25,bounce:0.12),value:capturedRecord?.id)
                    .onChange(of:store.lastCreatedRecordID){_,id in guard let record=store.records.first(where:{$0.id == id}) else{return};captureFeedbackJob?.cancel();capturedRecord=record;captureFeedbackJob=Task{@MainActor in try? await Task.sleep(for:.seconds(3));guard !Task.isCancelled else{return};capturedRecord=nil}}
            } else {
                VStack(spacing:20){Text("Ediz OS").font(.title2.weight(.medium));Text("Your local data couldn’t be opened.").foregroundStyle(Design.muted);Button("Try again"){store.open()}.buttonStyle(ActionStyle())}.padding(24)
            }
        }
        }.onOpenURL{url in store.connectAssistant(url);if url.host == "assistant"{selected=1}}.environmentObject(store).preferredColorScheme(.dark).background(AppBackdrop())
            .environment(\.edizCompact,store.preferences.density == "compact")
            .environment(\.edizWorkspaceFocus,store.preferences.focus)
            .animation(reducedMotion ? nil:.easeInOut(duration:0.3),value:store.preferences.focus)
            .environment(\.defaultMinListRowHeight,store.preferences.density == "compact" ? 44:60)
            .listSectionSpacing(.custom(store.preferences.density == "compact" ? 12:28))
            .font(store.preferences.density == "compact" ? .callout:.body)
            .animation(reducedMotion ? nil:.easeInOut(duration:0.18),value:store.preferences.density)
            #if DEBUG
            .onAppear{if ProcessInfo.processInfo.arguments.contains("-ui-testing"){UIApplication.shared.isIdleTimerDisabled=true}}
            .sheet(isPresented:.constant(!store.isPractice && ProcessInfo.processInfo.arguments.contains("-test-settings"))){NavigationStack{NativeSettings()}.environmentObject(store)}
            .sheet(isPresented:.constant(!store.isPractice && ProcessInfo.processInfo.arguments.contains("-test-gym-video"))){if let video=GymVideo.clips.first{GymVideoPlayer(video:video)}}
            .sheet(isPresented:.constant(!store.isPractice && ProcessInfo.processInfo.arguments.contains("-test-gym-change"))){GymChangeReview(action:gymChangeFixture).environmentObject(store)}
            .sheet(isPresented:.constant(!store.isPractice && ProcessInfo.processInfo.arguments.contains("-test-rich-reply"))){ScrollView{NativeRichText(text:"### Rhythm and timing\n\n**Deftones** practice notes: start slowly.\n\n- Keep eighth notes even.\n- Use ×, ♭ and ♯ when useful.\n\n```tab\ne|----------------|\nB|----------------|\nG|----------------|\nD|-----2-----2----|\nA|-----2-----2----|\nE|-0-0---0-0------|\n```\n\n| Tempo | Goal |\n|---|---|\n| 80 BPM | Even timing |").padding(24)}.background(AppBackdrop(scope:"band"))}
            .sheet(isPresented:.constant(!store.isPractice && ProcessInfo.processInfo.arguments.contains("-test-complete-recording"))){NativeRecordingDiagnostics()}
            .sheet(isPresented:.constant(!store.isPractice && ProcessInfo.processInfo.arguments.contains("-test-reader-display"))){NavigationStack{NativeFullBook(chaptersOverride:Self.readerFixture)}.environmentObject(store)}
            .sheet(isPresented:.constant(!store.isPractice && ProcessInfo.processInfo.arguments.contains("-test-reader-joined"))){NavigationStack{NativeFullBook(chaptersOverride:Self.readerJoinedFixture)}.environmentObject(store)}
            .sheet(isPresented:.constant(!store.isPractice && ProcessInfo.processInfo.arguments.contains("-test-reader-audio"))){NavigationStack{NativeFullBook(chaptersOverride:Self.readerAudioFixture)}.environmentObject(store)}
            .sheet(isPresented:.constant(!store.isPractice && ProcessInfo.processInfo.arguments.contains("-test-manuscript-clean"))){Text("Original sections: \(store.originalManuscript.count); Clean: \( (store.originalManuscript+store.records.filter{$0.data["contextType"] == "original-manuscript"}).allSatisfy{ManuscriptText.clean($0.title)==$0.title && ManuscriptText.clean($0.body)==$0.body} )").accessibilityIdentifier("manuscript-clean-status")}
            #endif
            .onChange(of:store.assistantConnected){_,connected in if connected { selected=1 } }
            .alert("Ediz OS",isPresented:Binding(get:{store.error != nil},set:{if !$0{store.error=nil}})){Button("OK"){store.error=nil}}message:{Text(store.error ?? "")}
    }
}
struct NativeCaptureTab:View {
    @EnvironmentObject var store:NativeStore
    var finish:()->Void
    @State private var seed:EdizCore.Record?=nil
    func prepare(){
        do { if let draft=try store.database?.draft(){seed=draft;return} }
        catch{store.error="Your capture draft could not be opened."}
        var fresh=EdizCore.Record(title:"");fresh.data["_captureAuto"]="1";seed=fresh
    }
    var body:some View {
        Group { if let seed { NativeCapture(seed:seed,onFinish:{self.seed=nil;finish()}).id(seed.id) } else { Color.clear } }.onAppear{prepare()}
    }
}
struct NativeToday:View {
    @EnvironmentObject var store:NativeStore
    @State private var review=false
    @State private var weekly=false
    @State private var choosingFocus=false
    var greeting:String {let hour=Calendar.current.component(.hour,from:Date());return hour<12 ? "Good morning":hour<18 ? "Good afternoon":"Good evening"}
    var upcoming:[EdizCore.Record]{store.records.filter{store.preferences.focus == "all" || $0.space == store.preferences.focus}.filter{$0.kind == "event" || $0.kind == "rehearsal" || $0.kind == "exam"}.filter{$0.status != "done" && (Time.date($0.due).map{$0>=Date()} ?? false)}.sorted{($0.due ?? "")<($1.due ?? "")}}
    var focusedPriorities:[Recommendation]{store.priorities.filter{store.preferences.focus == "all" || $0.record.space == store.preferences.focus}}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:store.preferences.density == "compact" ? 13:20) {
                welcomeHero
                if !store.isPractice,let validity=NativeInstallation.validity,validity.needsRenewal(){NavigationLink{NativeSettings()}label:{Label("Refresh your iPhone build before "+validity.expires.formatted(date:.abbreviated,time:.omitted),systemImage:"clock.badge.exclamationmark").font(.subheadline).padding(16).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:18))}.buttonStyle(.plain)}

                if store.preferences.focus != "all" { focusedWorkspace }
                Surface {VStack(alignment:.leading,spacing:12) {
                    HStack{Text("What matters").font(Design.font(19,weight:"Medium",relativeTo:.headline));Spacer();GlassAction{Button{choosingFocus=true}label:{Image(systemName:"slider.horizontal.3").frame(width:44,height:44)}.accessibilityLabel("Change focus").walkthroughTarget("focus",session:store.walkthrough)}}
                    if focusedPriorities.isEmpty {
                        VStack(alignment:.leading,spacing:10){Text("Room for what matters.").font(Design.font(23,weight:"DemiBold",relativeTo:.title2));Text("A thought, a plan, or a little time for yourself.").font(Design.font(15,weight:"Regular")).foregroundStyle(Design.muted)}.padding(.vertical,12)
                    } else {
                        VStack(alignment:.leading,spacing:14){ForEach(Array(focusedPriorities.prefix(4))){recommendation in RecordRow(record:recommendation.record);Divider().opacity(0.4)};Text(Priority.briefing(store.records,focus:store.preferences.focus)).font(Design.font(14,weight:"Regular")).foregroundStyle(Design.muted)}
                    }
                    HStack(spacing:12){if store.preferences.focus != "all"{GlassAction{Button{store.capture()}label:{Label("Capture",systemImage:"plus").padding(.horizontal,8).frame(minHeight:44)}.accessibilityIdentifier("capture-from-today")}};NavigationLink{NativeImport()}label:{Label("Bring in existing work",systemImage:"square.and.arrow.down").font(.subheadline).foregroundStyle(Design.muted).frame(minHeight:44)};Spacer()}
                }}
                if let recent=store.recent,store.preferences.focus == "all" || recent.space == store.preferences.focus { Surface { VStack(alignment:.leading,spacing:10){Text("Continue where you left off").font(Design.font(19,weight:"DemiBold"));RecordRow(record:recent).padding(.vertical,8)} } }
                if !upcoming.isEmpty { VStack(alignment:.leading,spacing:10){Text("Coming up").font(Design.font(19,weight:"DemiBold"));VStack(spacing:12){ForEach(Array(upcoming.prefix(3))){RecordRow(record:$0);Divider().opacity(0.4)}}} }
                VStack(alignment:.leading,spacing:12){Text(store.preferences.focus == "all" ? "Your spaces":"Your workspace").font(Design.font(19,weight:"DemiBold",relativeTo:.headline));ForEach(Catalog.spaces.filter{store.preferences.focus == "all" || $0.id == store.preferences.focus}){space in NativeSpaceShortcut(space:space);Divider().opacity(0.35)};if store.preferences.focus != "all"{GlassAction{Button("All spaces"){store.setFocus("all")}.frame(minHeight:44)}}}

                HStack(spacing:12){GlassAction{Button{weekly=false;review=true}label:{Label("Review today",systemImage:"checkmark.circle").frame(maxWidth:.infinity,minHeight:48)}};GlassAction{Button{weekly=true;review=true}label:{Image(systemName:"calendar").frame(minWidth:44,minHeight:48)}.accessibilityLabel("Review this week")}}.font(Design.font(15))
            }.padding(.horizontal,20).padding(.top,8).padding(.bottom,26)
        }.modifier(BrandedRefresh()).background(AppBackdrop()).navigationTitle("Ediz OS").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented:$choosingFocus){NativeFocusChoice().presentationDragIndicator(.visible)}
            .sheet(isPresented:$review){NativeReview(weekly:weekly).presentationDragIndicator(.visible)}
    }
    var welcomeHero:some View {
        VStack(alignment:.leading,spacing:18){
            HStack(spacing:12){FocusLogo(scope:store.preferences.focus).frame(width:46,height:46).clipShape(RoundedRectangle(cornerRadius:10));Text("YOUR DAY").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(Design.muted);Spacer();Text(Date.now,format:.dateTime.weekday(.abbreviated).day().month(.abbreviated)).font(.caption).foregroundStyle(Design.muted)}
            if let date=store.lastRefresh {Label("Updated "+date.formatted(date:.omitted,time:.shortened),systemImage:"checkmark.circle").font(.caption).foregroundStyle(Design.muted).accessibilityIdentifier("workspace-refreshed")}
            if store.preferences.focus == "all" {
                Text(greeting+", Ediz.").font(.system(.largeTitle,design:.rounded).weight(.medium)).fixedSize(horizontal:false,vertical:true)
                Text("Your ideas, your music, your next chapter. Make yourself at home.").font(.subheadline).foregroundStyle(Design.muted).fixedSize(horizontal:false,vertical:true)
                Button{store.capture()}label:{HStack{Text("Capture a thought").font(.subheadline.weight(.semibold));Image(systemName:"plus").font(.subheadline.weight(.semibold))}.padding(.horizontal,18).frame(minHeight:46).foregroundStyle(Design.background).background(Design.ink,in:Capsule())}.buttonStyle(.plain).accessibilityIdentifier("capture-from-today")
                NavigationLink{NativeConversationHost(scope:"all")}label:{Label("Talk it through",systemImage:"bubble.left.and.bubble.right").font(.subheadline).foregroundStyle(Design.muted).frame(minHeight:44)}.buttonStyle(.plain)
            } else {Text("A little room to focus.").font(.title2.weight(.medium))}
        }.padding(.vertical,store.preferences.density == "compact" ? 12:22).frame(maxWidth:.infinity,alignment:.leading)
    }
    var focusedWorkspace:some View {
        let space=Catalog.space(store.preferences.focus)
        let count=store.records.filter{$0.space == space.id}.count
        return VStack(alignment:.leading,spacing:store.preferences.density == "compact" ? 16:24) {
            HStack { Label("YOUR FOCUS",systemImage:"scope").font(.caption.weight(.semibold));Spacer();Button("Change"){choosingFocus=true}.font(.subheadline) }
                .foregroundStyle(WorkspaceTheme.accent(space.id))
            Text(space.name).font(.largeTitle.weight(.semibold)).foregroundStyle(Design.ink)
            Text(space.summary+" · \(count) saved items").font(.subheadline).foregroundStyle(Design.muted)
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12) {
                ForEach(Array(space.modules.prefix(4))) { module in
                    NavigationLink(value:SpaceRoute(id:space.id,kind:module.kind)) {
                        Text(module.label).font(.body.weight(.medium)).frame(maxWidth:.infinity,minHeight:50)
                            .background(WorkspaceTheme.accent(space.id).opacity(0.15),in:RoundedRectangle(cornerRadius:16))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(store.preferences.density == "compact" ? 18:26)
            .frame(maxWidth:.infinity,minHeight:store.preferences.density == "compact" ? 240:300,alignment:.topLeading)
            .background{WorkspacePanel(scope:space.id).clipShape(RoundedRectangle(cornerRadius:26))}
            .accessibilityElement(children:.contain).accessibilityIdentifier("focused-workspace")
    }
}

struct NativeSpaceShortcut:View {
    @EnvironmentObject var store:NativeStore
    let space:SpaceDefinition
    var shortcut:String {space.id == "band" ? "Setlist":space.id == "school" ? "Homework":space.id == "personal" ? "Capture":space.modules[0].label}
    var body:some View {
        HStack(spacing:10){NavigationLink(value:SpaceRoute(id:space.id)){HStack(spacing:11){SpaceMark(space:space);VStack(alignment:.leading,spacing:4){Text(space.name).font(Design.font(16,weight:"DemiBold")).foregroundStyle(Design.ink);Text(space.summary).font(Design.font(12,weight:"Regular")).foregroundStyle(Design.muted)}}.frame(maxWidth:.infinity,alignment:.leading)}.buttonStyle(.plain)
            GlassAction{if space.id == "personal" {Button(shortcut){store.capture(space:"personal")}.frame(minHeight:44)}else{NavigationLink(value:SpaceRoute(id:space.id)){Text(shortcut).frame(minHeight:44)}}}.font(Design.font(13))
        }.padding(.vertical,store.preferences.density == "compact" ? 2:6)
    }
}
struct NativeSpaces:View {
    @EnvironmentObject var store:NativeStore
    var body:some View {
        ScrollViewReader{proxy in ScrollView { VStack(alignment:.leading,spacing:store.preferences.density == "compact" ? 10:24) {
            Text("Your spaces. A place for everything.").font(Design.font(15,weight:"Regular")).foregroundStyle(Design.muted).padding(.bottom,4)
            NavigationLink{NativeGym()}label:{GymSpaceCard()}.buttonStyle(.plain).accessibilityIdentifier("space-gym").id("gym")
            ForEach(Catalog.spaces){space in
                VStack(alignment:.leading,spacing:store.preferences.density == "compact" ? 10:22){NavigationLink{NativeSpace(route:SpaceRoute(id:space.id))}label:{HStack(spacing:12){SpaceMark(space:space);VStack(alignment:.leading,spacing:4){Text(space.name).font(Design.font(19,weight:"DemiBold"));if store.preferences.density != "compact" {Text(space.summary).font(Design.font(13,weight:"Regular")).foregroundStyle(Design.muted)}};Spacer()}}.buttonStyle(.plain).accessibilityIdentifier("space-"+space.id)
                    HStack(spacing:8){ForEach(Catalog.quickModules(for:space.id)){module in GlassAction{NavigationLink{NativeSpace(route:SpaceRoute(id:space.id,kind:module.kind))}label:{Text(module.label).font(Design.font(13)).frame(maxWidth:.infinity,minHeight:44).walkthroughTarget(module.kind == "chapter" ? "chapters":"",session:store.walkthrough)}}}}
                }.padding(store.preferences.density == "compact" ? 12:24).background{WorkspacePanel(scope:space.id).clipShape(RoundedRectangle(cornerRadius:24))}.overlay{RoundedRectangle(cornerRadius:24).strokeBorder(WorkspaceTheme.accent(space.id).opacity(0.18),lineWidth:1)}.id(space.id)
            }
        }.padding(20) }.modifier(BrandedRefresh()).background(AppBackdrop(scope:"spaces")).navigationTitle("Spaces").onAppear{if let kind=store.walkthrough?.kind{let target=kind == .gym ? "gym":kind == .rehearsal ? "band":"moshia";DispatchQueue.main.asyncAfter(deadline:.now()+0.35){proxy.scrollTo(target,anchor:.center)}}}}
    }
}
struct GymSpaceCard:View {
    @EnvironmentObject var store:NativeStore
    @StateObject private var gym=GymStore()
    var day:GymDay?{gym.state.days.indices.contains((Calendar.current.component(.weekday,from:Date())+5)%7) ? gym.state.days[(Calendar.current.component(.weekday,from:Date())+5)%7]:nil}
    var body:some View {
        VStack(alignment:.leading,spacing:20){
            HStack(alignment:.top){VStack(alignment:.leading,spacing:7){Text("TRAINING CLUB").font(.caption2.weight(.bold)).tracking(2).foregroundStyle(WorkspaceTheme.accent("gym"));Text("Gym").font(.system(.largeTitle,design:.rounded).weight(.bold))};Spacer();Image(systemName:"dumbbell.fill").font(.system(size:32,weight:.semibold)).rotationEffect(.degrees(-20)).foregroundStyle(WorkspaceTheme.accent("gym")).padding(8)}
            HStack(alignment:.bottom){VStack(alignment:.leading,spacing:6){Text(gym.state.active != nil ? "WORKOUT IN PROGRESS":"TODAY").font(.caption2.weight(.semibold)).foregroundStyle(Design.muted);Text(gym.state.active?.title ?? day?.title ?? "Your training plan").font(.headline);Text(day?.exercises.isEmpty == false ? "\(day!.exercises.count) exercises · Your pace":"Recovery is part of the plan").font(.caption).foregroundStyle(Design.muted)};Spacer();Image(systemName:"arrow.up.right").font(.headline).frame(width:44,height:44).background(WorkspaceTheme.accent("gym").opacity(0.18),in:Circle())}
            HStack(spacing:6){ForEach(0..<7){index in Capsule().fill((gym.state.days.indices.contains(index) && gym.state.days[index].exercises.isEmpty) ? Design.muted.opacity(0.18):WorkspaceTheme.accent("gym").opacity(0.65)).frame(height:4)}}.accessibilityHidden(true)
        }.foregroundStyle(Design.ink).padding(24).background(Color(red:0.10,green:0.12,blue:0.085),in:RoundedRectangle(cornerRadius:24)).overlay{RoundedRectangle(cornerRadius:24).strokeBorder(WorkspaceTheme.accent("gym").opacity(0.22),lineWidth:1)}.onAppear{gym.load(store);if let text=store.preferences.assistantChats["gym-state"],let saved=try? JSONDecoder().decode(GymState.self,from:Data(text.utf8)){gym.state=saved}}
    }
}
struct NativeSearch:View {
    @EnvironmentObject var store:NativeStore
    @State private var query=""
    @StateObject private var searchSpeech=NativeSpeech()
    @State private var finishingSpeech=false
    @State private var voiceSearchJob:Task<Void,Never>?
    @State private var space="all"
    @State private var ranked:[String]?
    @State private var reasoning:String?
    @State private var finding=false
    @State private var searchError:String?
    @State private var searchJob:Task<Void,Never>?
    @FocusState private var searching:Bool
    var corpus:[EdizCore.Record]{(store.searchableMemories()+(query.isEmpty ? []:store.originalManuscript)).filter{space == "all" || $0.space == space}}
    var results:[EdizCore.Record]{if let ranked{return ranked.compactMap{id in corpus.first{$0.id == id}}};return SearchIndex.find(corpus,query:query)}
    var body:some View {
        List {
            Section {
                VStack(alignment:.leading,spacing:6){Text("Find the thought, not just the words.").font(.title3.weight(.semibold));Text("Describe what you remember. Search can look through notes, chapters and past chats by meaning.").font(.subheadline).foregroundStyle(Design.muted)}.padding(.vertical,10)
                HStack(spacing:10){Image(systemName:"magnifyingglass").foregroundStyle(Design.muted);TextField("A name, a phrase, or what you remember…",text:$query).focused($searching).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search).onSubmit{searching=false;findByMeaning()}.accessibilityIdentifier("search-query");Button{toggleSearchSpeech()}label:{Image(systemName:searchSpeech.listening ? "stop.fill":"mic.fill").frame(width:44,height:44).foregroundStyle(searchSpeech.listening ? WorkspaceTheme.accent("school"):Design.ink).background(Design.raised,in:Circle())}.disabled(finishingSpeech || searchSpeech.requesting).accessibilityLabel(searchSpeech.listening ? "Finish voice search":"Speak your search").accessibilityIdentifier("search-microphone");if !query.isEmpty{Button{query=""}label:{Image(systemName:"xmark.circle.fill").foregroundStyle(Design.muted)}.accessibilityLabel("Clear search")}}.padding(.vertical,8).walkthroughTarget("search-query",session:store.walkthrough)
                if !query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,store.assistantConnected {
                    Button{searching=false;findByMeaning()}label:{HStack{if finding{ProgressView()}else{Image(systemName:"sparkle.magnifyingglass")};Text(finding ? "Looking through your memories…":"Find by meaning");Spacer()}}.disabled(finding).accessibilityIdentifier("search-by-meaning")
                }
            }
            if searchSpeech.listening || finishingSpeech{Section{HStack(spacing:4){ForEach(0..<20){index in Capsule().fill(WorkspaceTheme.accent("school")).frame(width:4,height:CGFloat(8)+searchSpeech.level*CGFloat(12+(index%5)*7))};Spacer();Text(finishingSpeech ? "Finishing…":"Listening…").font(.subheadline)}.frame(height:40).animation(.easeOut(duration:0.12),value:searchSpeech.level)}}
            if let message=searchSpeech.message{Section{Text(message).font(.footnote).foregroundStyle(Design.muted)}}
            Section {Picker("Space",selection:$space){Text("Everything").tag("all");ForEach(Catalog.spaces){Text($0.name).tag($0.id)}}}
            if let reasoning{Section{Text(reasoning).font(.subheadline).foregroundStyle(Design.muted)}}
            if let searchError{Section{Text(searchError).font(.footnote).foregroundStyle(Design.muted)}}
            Section(query.isEmpty ? "Recent":ranked == nil ? "Your memories":"Do you mean…") {
                if results.isEmpty{QuietEmpty(title:query.isEmpty ? "Your work will appear here.":"No matches yet.",message:query.isEmpty ? "Capture something or start a conversation.":"Try describing another detail you remember.")}
                ForEach(Array(results.prefix(100))){record in
                    if let scope=record.data["_chatScope"],let text=record.data["_chatID"],let id=UUID(uuidString:text){
                        NavigationLink{NativeConversationHost(scope:scope,initialID:id)}label:{HStack(alignment:.top,spacing:12){Image(systemName:"bubble.left.and.bubble.right").foregroundStyle(WorkspaceTheme.accent(scope));VStack(alignment:.leading,spacing:6){Text(record.title).font(.headline);Text(record.body).font(.caption).foregroundStyle(Design.muted).lineLimit(2);Text((scope == "all" ? "Everyday":Catalog.space(scope).name)+" · Chat").font(.caption2).foregroundStyle(Design.muted)}}.padding(.vertical,5)}
                    }else if record.data["readOnly"] == "true"{NavigationLink{ScrollView{Text(record.body).textSelection(.enabled).padding(20)}.background(AppBackdrop(scope:"moshia")).navigationTitle(record.title)}label:{Label(record.title,systemImage:"book.closed")}
                    }else{RecordRow(record:record).walkthroughTarget(record.title == "Practice guitar" ? "search-result":"",session:store.walkthrough)}
                }
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(AppBackdrop()).listRowSpacing(store.preferences.density == "compact" ? 4:12).modifier(BrandedRefresh()).navigationTitle("Search")
            .onChange(of:query){_,value in resetSearch();scheduleMeaningSearch();if value.localizedCaseInsensitiveContains("guitar"){store.walkthrough?.event("searched")}}
            .onChange(of:space){_,_ in resetSearch();scheduleMeaningSearch()}.onDisappear{searchJob?.cancel();voiceSearchJob?.cancel();searchSpeech.stop();finishingSpeech=false;finding=false}
    }
    func toggleSearchSpeech(){
        searching=false
        if searchSpeech.listening{finishingSpeech=true;voiceSearchJob=Task{@MainActor in let text=await searchSpeech.finish();guard !Task.isCancelled else{return};finishingSpeech=false;if !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{query=text}}}else{searchJob?.cancel();finding=false;searchSpeech.toggle()}
    }
    func resetSearch(){searchJob?.cancel();finding=false;ranked=nil;reasoning=nil;searchError=nil}
    func scheduleMeaningSearch(){
        guard !searchSpeech.listening,!finishingSpeech,query.trimmingCharacters(in:.whitespacesAndNewlines).count>=3,store.assistantConnected else{return}
        searchJob=Task{@MainActor in
            try? await Task.sleep(for:.milliseconds(650));guard !Task.isCancelled else{return};findByMeaning()
        }
    }
    func findByMeaning(){
        let q=query.trimmingCharacters(in:.whitespacesAndNewlines);guard !q.isEmpty,let token=store.assistantToken else{return}
        searchJob?.cancel();finding=true;searchError=nil;let items=Array(corpus.prefix(500)).map{item in var trimmed=item;trimmed.body=String(item.body.suffix(6000));return trimmed}
        searchJob=Task{@MainActor in
            do{let reply=try await GeminiAssistant.answer(question:q,records:items,conversation:[],token:token,scope:space,requestMode:"semantic-search");guard !Task.isCancelled else{return};ranked=reply.recordIds;reasoning=reply.text;finding=false}
            catch{guard !Task.isCancelled else{return};finding=false;searchError="The AI connection couldn’t finish this search. Your saved results are still available."}
        }
    }
}
