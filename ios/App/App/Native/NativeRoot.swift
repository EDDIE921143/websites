import SwiftUI
import EdizCore

struct NativeRoot:View {
    @StateObject private var store: NativeStore
    init(store: NativeStore) { _store = StateObject(wrappedValue: store) }
    @State private var selected=0
    @State private var previous=0
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var body:some View {
        VStack(spacing:0) {
            if let session=store.walkthrough {WalkthroughCoach(session:session)}
        Group {
            if store.ready {
                TabView(selection:$selected) {
                    OSNavigation{NativeToday()}.tabItem{Label("Today",systemImage:"house.fill")}.tag(0)
                    OSNavigation{NativeAssistant()}.tabItem{Label("Assistant",systemImage:"text.bubble.fill")}.tag(1)
                    NativeCaptureTab { selected=previous }.tabItem{Label("Capture",systemImage:"plus.circle.fill")}.tag(2)
                    OSNavigation{NativeSearch()}.tabItem{Label("Search",systemImage:"magnifyingglass")}.tag(3)
                    OSNavigation{NativeSpaces()}.tabItem{Label("Spaces",systemImage:"square.stack.3d.up.fill")}.tag(4)
                }.tint(Design.accent)
                    .background(NativeTabScrubber(selection:$selected))
                    .onChange(of:selected){_,next in if next != 2 {previous=next};store.walkthrough?.event("tab-\(next)") }
                    .sheet(item:$store.captureRequest){seed in Group { if seed.data["_creation"] == "1" { NativeCreation(seed:seed) } else { NativeCapture(seed:seed) } }.presentationDetents([.large]).presentationDragIndicator(.visible)}
                    .fullScreenCover(item:$store.focusRequest){NativeFocus(record:$0)}
                    .overlay(alignment:.bottom){if let completed=store.undoRecord{CompletionToast(undo:{store.undo()},dismiss:{store.undoRecord=nil}).id(completed.id).padding(.horizontal,20).padding(.bottom,80).transition(.move(edge:.bottom).combined(with:.opacity))}}
                    .animation(reducedMotion ? nil:.spring(duration:0.35,bounce:0.18),value:store.undoRecord?.id)
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

                if store.preferences.focus != "all" { focusedWorkspace }
                VStack(alignment:.leading,spacing:12) {
                    HStack{Text("What matters").font(Design.font(19,weight:"Medium",relativeTo:.headline));Spacer();GlassAction{Button{choosingFocus=true}label:{Image(systemName:"slider.horizontal.3").frame(width:44,height:44)}.accessibilityLabel("Change focus").walkthroughTarget("focus",session:store.walkthrough)}}
                    if focusedPriorities.isEmpty {
                        VStack(alignment:.leading,spacing:10){Text("Room for what matters.").font(Design.font(23,weight:"DemiBold",relativeTo:.title2));Text("A thought, a plan, or a little time for yourself.").font(Design.font(15,weight:"Regular")).foregroundStyle(Design.muted)}.padding(.vertical,12)
                    } else {
                        VStack(alignment:.leading,spacing:14){ForEach(Array(focusedPriorities.prefix(4))){recommendation in RecordRow(record:recommendation.record);Divider().opacity(0.4)};Text(Priority.briefing(store.records,focus:store.preferences.focus)).font(Design.font(14,weight:"Regular")).foregroundStyle(Design.muted)}
                    }
                    HStack(spacing:12){if store.preferences.focus != "all"{GlassAction{Button{store.capture()}label:{Label("Capture",systemImage:"plus").padding(.horizontal,8).frame(minHeight:44)}.accessibilityIdentifier("capture-from-today")}};NavigationLink{NativeImport()}label:{Label("Bring in existing work",systemImage:"square.and.arrow.down").font(.subheadline).foregroundStyle(Design.muted).frame(minHeight:44)};Spacer()}
                }
                if let recent=store.recent,store.preferences.focus == "all" || recent.space == store.preferences.focus { VStack(alignment:.leading,spacing:10){Text("Continue where you left off").font(Design.font(19,weight:"DemiBold"));RecordRow(record:recent).padding(.vertical,8)} }
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
                Text(greeting+",\nEdiz.").font(.system(.largeTitle,design:.rounded).weight(.semibold)).fixedSize(horizontal:false,vertical:true)
                Text("A little space for your plans, stories, and ideas.").font(.subheadline).foregroundStyle(Design.muted).fixedSize(horizontal:false,vertical:true)
                Button{store.capture()}label:{HStack{Text("Capture a thought").font(.subheadline.weight(.semibold));Image(systemName:"plus").font(.subheadline.weight(.semibold))}.padding(.horizontal,18).frame(minHeight:46).foregroundStyle(Design.background).background(Design.ink,in:Capsule())}.buttonStyle(.plain).accessibilityIdentifier("capture-from-today")
            } else {Text("A little room to focus.").font(.title2.weight(.medium))}
        }.padding(.vertical,store.preferences.density == "compact" ? 12:22).frame(maxWidth:.infinity,alignment:.leading)
    }
    var focusedWorkspace:some View {
        let space=Catalog.space(store.preferences.focus)
        let count=store.records.filter{$0.space == space.id}.count
        return VStack(alignment:.leading,spacing:store.preferences.density == "compact" ? 16:24) {
            HStack { Label("YOUR FOCUS",systemImage:"scope").font(.caption.weight(.semibold));Spacer();Button("Change"){choosingFocus=true}.font(.subheadline) }
                .foregroundStyle(Design.color(space.color))
            Text(space.name).font(.largeTitle.weight(.semibold)).foregroundStyle(Design.ink)
            Text(space.summary+" · \(count) saved items").font(.subheadline).foregroundStyle(Design.muted)
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12) {
                ForEach(Array(space.modules.prefix(4))) { module in
                    NavigationLink(value:SpaceRoute(id:space.id,kind:module.kind)) {
                        Text(module.label).font(.body.weight(.medium)).frame(maxWidth:.infinity,minHeight:50)
                            .background(Design.color(space.color).opacity(0.15),in:RoundedRectangle(cornerRadius:16))
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
        ScrollView { VStack(alignment:.leading,spacing:store.preferences.density == "compact" ? 10:24) {
            Text("Five spaces. A place for everything.").font(Design.font(15,weight:"Regular")).foregroundStyle(Design.muted).padding(.bottom,4)
            ForEach(Catalog.spaces){space in
                VStack(alignment:.leading,spacing:store.preferences.density == "compact" ? 10:22){NavigationLink(value:SpaceRoute(id:space.id)){HStack(spacing:12){SpaceMark(space:space);VStack(alignment:.leading,spacing:4){Text(space.name).font(Design.font(19,weight:"DemiBold"));if store.preferences.density != "compact" {Text(space.summary).font(Design.font(13,weight:"Regular")).foregroundStyle(Design.muted)}};Spacer()}}.buttonStyle(.plain).accessibilityIdentifier("space-"+space.id)
                    HStack(spacing:8){ForEach(Catalog.quickModules(for:space.id)){module in GlassAction{NavigationLink(value:SpaceRoute(id:space.id,kind:module.kind)){Text(module.label).font(Design.font(13)).frame(maxWidth:.infinity,minHeight:44).walkthroughTarget(module.kind == "chapter" ? "chapters":"",session:store.walkthrough)}}}}
                }.padding(store.preferences.density == "compact" ? 12:24).background{WorkspacePanel(scope:space.id).clipShape(RoundedRectangle(cornerRadius:24))}.overlay{RoundedRectangle(cornerRadius:24).strokeBorder(WorkspaceTheme.accent(space.id).opacity(0.18),lineWidth:1)}
            }
        }.padding(20) }.modifier(BrandedRefresh()).background(AppBackdrop(scope:"spaces")).navigationTitle("Spaces")
    }
}
struct NativeSearch:View {
    @EnvironmentObject var store:NativeStore
    @State private var query=""
    @State private var space="all"
    @State private var ranked:[String]?
    @State private var reasoning:String?
    @State private var finding=false
    @State private var searchError:String?
    @State private var searchJob:Task<Void,Never>?
    @FocusState private var searching:Bool
    var corpus:[EdizCore.Record]{store.searchableMemories().filter{space == "all" || $0.space == space}}
    var results:[EdizCore.Record]{if let ranked{return ranked.compactMap{id in corpus.first{$0.id == id}}};return SearchIndex.find(corpus,query:query)}
    var body:some View {
        List {
            Section {
                HStack(spacing:10){Image(systemName:"magnifyingglass").foregroundStyle(Design.muted);TextField("A name, a phrase, or what you remember…",text:$query).focused($searching).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search).onSubmit{searching=false;findByMeaning()}.accessibilityIdentifier("search-query");if !query.isEmpty{Button{query=""}label:{Image(systemName:"xmark.circle.fill").foregroundStyle(Design.muted)}.accessibilityLabel("Clear search")}}.padding(.vertical,8).walkthroughTarget("search-query",session:store.walkthrough)
                if !query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,store.assistantConnected {
                    Button{searching=false;findByMeaning()}label:{HStack{if finding{ProgressView()}else{Image(systemName:"sparkle.magnifyingglass")};Text(finding ? "Looking through your memories…":"Find by meaning");Spacer()}}.disabled(finding).accessibilityIdentifier("search-by-meaning")
                }
            }
            Section {Picker("Space",selection:$space){Text("Everything").tag("all");ForEach(Catalog.spaces){Text($0.name).tag($0.id)}}}
            if let reasoning{Section{Text(reasoning).font(.subheadline).foregroundStyle(Design.muted)}}
            if let searchError{Section{Text(searchError).font(.footnote).foregroundStyle(Design.muted)}}
            Section(query.isEmpty ? "Recent":ranked == nil ? "Matching words":"Closest memories") {
                if results.isEmpty{QuietEmpty(title:query.isEmpty ? "Your work will appear here.":"No matches yet.",message:query.isEmpty ? "Capture something or start a conversation.":"Try describing another detail you remember.")}
                ForEach(Array(results.prefix(100))){record in
                    if let scope=record.data["_chatScope"],let text=record.data["_chatID"],let id=UUID(uuidString:text){
                        NavigationLink{NativeConversationHost(scope:scope,initialID:id)}label:{HStack(alignment:.top,spacing:12){Image(systemName:"bubble.left.and.bubble.right").foregroundStyle(WorkspaceTheme.accent(scope));VStack(alignment:.leading,spacing:6){Text(record.title).font(.headline);Text(record.body).font(.caption).foregroundStyle(Design.muted).lineLimit(2);Text((scope == "all" ? "Everyday":Catalog.space(scope).name)+" · Chat").font(.caption2).foregroundStyle(Design.muted)}}.padding(.vertical,5)}
                    }else{RecordRow(record:record).walkthroughTarget(record.title == "Practice guitar" ? "search-result":"",session:store.walkthrough)}
                }
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(AppBackdrop()).listRowSpacing(store.preferences.density == "compact" ? 4:12).modifier(BrandedRefresh()).navigationTitle("Search")
            .onChange(of:query){_,value in resetSearch();if value.localizedCaseInsensitiveContains("guitar"){store.walkthrough?.event("searched")}}
            .onChange(of:space){_,_ in resetSearch()}.onDisappear{searchJob?.cancel();finding=false}
    }
    func resetSearch(){searchJob?.cancel();finding=false;ranked=nil;reasoning=nil;searchError=nil}
    func findByMeaning(){
        let q=query.trimmingCharacters(in:.whitespacesAndNewlines);guard !q.isEmpty,let token=store.assistantToken else{return}
        searchJob?.cancel();finding=true;searchError=nil;let items=Array(corpus.prefix(500)).map{item in var trimmed=item;trimmed.body=String(item.body.suffix(6000));return trimmed}
        searchJob=Task{@MainActor in
            do{let reply=try await GeminiAssistant.answer(question:q,records:items,conversation:[],token:token,scope:space,requestMode:"semantic-search");guard !Task.isCancelled else{return};ranked=reply.recordIds;reasoning=reply.text;finding=false}
            catch{guard !Task.isCancelled else{return};finding=false;searchError="Meaning search couldn’t finish. Matches by words are still shown."}
        }
    }
}
