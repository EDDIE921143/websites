import SwiftUI
import EdizCore
import CryptoKit
import AVFoundation

struct NativeSpace:View {
    @EnvironmentObject var store:NativeStore
    let route:SpaceRoute
    @State private var kind=""
    @State private var filter="all"
    @State private var rehearsal=false
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var space:SpaceDefinition{Catalog.space(route.id)}
    var creationNoun:String {kind == "thread" ? "plot thread":kind == "assignment" ? "homework":kind == "note" && route.id == "moshia" ? "research":kind}
    var orderedRecords:[EdizCore.Record]{store.records.filter{$0.space == route.id && $0.kind == kind}.sorted{kind == "chapter" ? chapterBefore($0,$1):$0.updated>$1.updated}}
    var records:[EdizCore.Record]{orderedRecords.filter{filter == "all" || $0.status == filter}}
    var songs:[EdizCore.Record]{store.records.filter{$0.space == "band" && $0.kind == "song" && $0.status != "archived"}.sorted{$0.created<$1.created}}
    var body:some View {
        ScrollViewReader { proxy in
        List {
            Section { workspaceHeader.listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden) }

            if route.id == "moshia" {
                Section {NavigationLink{NativeStoryDesk()}label:{HStack(spacing:14){Image(systemName:"book.pages.fill").font(.title2).foregroundStyle(WorkspaceTheme.accent("moshia"));VStack(alignment:.leading,spacing:5){Text("Continuity desk").font(.headline);Text("Chapters, open threads and established canon").font(.subheadline).foregroundStyle(Design.muted)}}.padding(.vertical,8)}.accessibilityIdentifier("story-desk-open")}
            }
            if route.id == "band" && kind == "song"{Section{Button("Add your own song"){store.capture(space:"band",kind:"song")};NavigationLink{NativeKnownSongs()}label:{Label("Add known songs",systemImage:"sparkles")}.accessibilityIdentifier("known-songs-open")}}
            if kind == "lead" {
                Section("Pipeline"){
                    let leads=store.records.filter{$0.space == "ejj" && $0.kind == "lead"}
                    HStack{metric("Leads",leads.filter{$0.status != "Client" && $0.status != "Lost"}.count);Spacer();metric("Interested",leads.filter{$0.status == "Interested"}.count);Spacer();metric("Clients",leads.filter{$0.status == "Client"}.count)}
                }
            }
            if route.id == "band" && kind == "song"{Section("Rehearsal desk"){HStack{metric("Setlist",songs.count);Spacer();metric("Ready",songs.filter{$0.status == "Ready"}.count);Spacer();metric("Learning",songs.filter{$0.status == "Learning"}.count)};Button{rehearsal=true}label:{Label("Rehearsal mode",systemImage:"play.circle.fill").font(.headline).frame(minHeight:44)}.walkthroughTarget("rehearsal",session:store.walkthrough);if let next=store.records.filter({$0.kind == "rehearsal" && Time.date($0.due).map{$0>Date()} == true}).sorted(by:{($0.due ?? "")<($1.due ?? "")}).first{RecordRow(record:next)}}}
            if route.id == "school" && kind == "grade"{NativeGradeProjection()}
            if route.id == "school" && ["assignment","exam"].contains(kind){NativeWorkload()}
            if kind == "chapter" && !records.isEmpty {
                ForEach(records) { record in
                    Section(chapterLabel(record)) {
                        NavigationLink(value: record) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(record.title).font(Design.font(21)).foregroundStyle(Design.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !record.body.isEmpty {
                                    Text(record.body).font(Design.font(15, weight: "Regular"))
                                        .foregroundStyle(Design.muted).lineLimit(2)
                                }
                                let details = [record.data["POV"], record.data["purpose"], record.data["location"], record.data["wordCount"].map { "\($0) words" }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                                if !details.isEmpty { Text(details).font(.subheadline).foregroundStyle(Design.muted) }
                                Text(record.status).font(.caption.weight(.medium))
                                    .foregroundStyle(WorkspaceTheme.accent(space.id))
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Design.raised, in: Capsule())
                            }.padding(.vertical, store.preferences.density == "compact" ? 8 : 14)
                        }.accessibilityIdentifier("chapter-card-" + record.id)
                            .listRowBackground(Design.surface).listRowSeparator(.hidden).id(record.id)
                    }
                }
            } else {
            Section(space.modules.first{$0.kind == kind}?.label ?? "Records") {
                if records.isEmpty{QuietEmpty(title:"Ready for your \(kind == "assignment" ? "homework":kind == "lead" ? "leads":kind == "chapter" ? "chapters":"work").",message:"Add your own material or bring in an existing file.");Button("Add \(creationNoun)"){store.capture(space:route.id,kind:kind)}}
                ForEach(records){record in
                    VStack(alignment:.leading,spacing:10){if record.kind == "chapter"{Text("Chapter \((records.firstIndex(where:{$0.id == record.id}) ?? 0)+1)").font(Design.font(13)).foregroundStyle(Design.muted)};RecordRow(record:record)
                        if route.id == "moshia"{Text(record.status).font(.caption.weight(.medium)).foregroundStyle(WorkspaceTheme.accent(space.id))}
                        if record.kind == "song"{Text([record.data["artist"],record.data["BPM"].map{"\($0) BPM"},record.data["tuning"],record.status].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:" · ")).font(.subheadline).foregroundStyle(Design.muted)}
                        if record.kind == "chapter"{Text([record.data["POV"],record.data["wordCount"].map{"\($0) words"},record.data["location"]].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:" · ")).font(.subheadline).foregroundStyle(Design.muted)}
                    }.id(record.id).listRowSeparator(.hidden).swipeActions(edge:.trailing,allowsFullSwipe:true){if record.actionable{Button{store.complete(record)}label:{Label("Done",systemImage:"checkmark")}.tint(.green)}}
                }
            }
            }
            if route.id == "moshia" && kind == "event"{NativeTimeline()}
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).modifier(WorkspaceEntrance()).modifier(BrandedRefresh()).background(AppBackdrop(scope:route.id)).navigationTitle(space.name).navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.topBarTrailing){HStack(spacing:0){if route.id == "moshia"{NavigationLink{NativeFullBook()}label:{Image(systemName:"book.closed").frame(width:44,height:44)}.accessibilityLabel("Full Book").accessibilityIdentifier("full-book-open").walkthroughTarget("full-book",session:store.walkthrough)};NavigationLink{NativeChatHistory(scope:route.id)}label:{Image(systemName:"bubble.left.and.bubble.right").frame(width:44,height:44)}.accessibilityLabel("Chats").accessibilityIdentifier("space-chats")}.padding(.trailing,4)};ToolbarItem(placement:.topBarLeading){Button{store.capture(space:route.id,kind:kind)}label:{Label("Add \(creationNoun)",systemImage:"plus")}.disabled(kind.isEmpty).accessibilityIdentifier("module-add").walkthroughTarget("add-chapter",session:store.walkthrough)}}
            .onAppear{if kind.isEmpty{kind=route.kind ?? space.modules[0].kind};if route.id == "moshia" && kind == "chapter"{store.walkthrough?.event("chapters-open")};if route.id == "band" && kind == "song"{store.walkthrough?.event("songs-open")}}
            .onChange(of:kind){_,_ in filter="all"}
            .fullScreenCover(isPresented:$rehearsal){NativeRehearsal(songs:songs)}
            .safeAreaInset(edge:.top){moduleControls.padding(.horizontal,20).padding(.vertical,8).background(WorkspaceTheme.base(route.id))}
            .onChange(of:store.lastCreatedRecordID){_,id in
                guard let id,records.contains(where:{$0.id == id}) else{return}
                DispatchQueue.main.asyncAfter(deadline:.now()+0.2){withAnimation(reducedMotion ? nil:.easeOut(duration:0.25)){proxy.scrollTo(id,anchor:.center)}}
            }
        }
    }
    var moduleControls:some View {
                HStack(spacing:12){
                    Picker("Area",selection:$kind){ForEach(space.modules){Text($0.label).tag($0.kind)}}.labelsHidden().pickerStyle(.menu).font(.headline).tint(WorkspaceTheme.accent(route.id)).accessibilityIdentifier("module-picker")
                    Spacer(minLength:0)
                    if kind == "lead"{Picker("Pipeline",selection:$filter){Text("All leads").tag("all");ForEach(Catalog.states(kind:"lead",space:"ejj"),id:\.self){Text($0).tag($0)}}.labelsHidden().pickerStyle(.menu).font(.caption)}
                    if route.id == "moshia"{Picker("Story state",selection:$filter){Text("All states").tag("all");ForEach(Catalog.states(kind:kind,space:"moshia"),id:\.self){Text($0).tag($0)}}.labelsHidden().pickerStyle(.menu).font(.caption)}
                }.frame(minHeight:48).padding(.horizontal,16).background(Design.surface,in:Capsule())

    }
    var workspaceHeader:some View {
        let count=store.records.filter{$0.space == route.id && $0.status != "archived"}.count
        return VStack(alignment:.leading,spacing:16){
            HStack{Text("YOUR WORKSPACE").font(.caption2.weight(.semibold)).tracking(1.4);Spacer();SpaceMark(space:space).scaleEffect(1.2)}.foregroundStyle(WorkspaceTheme.accent(route.id))
            Text(workspaceHeading).font(.system(.title,design:route.id == "moshia" ? .serif:.rounded).weight(.semibold)).fixedSize(horizontal:false,vertical:true)
            Text(space.summary).font(.subheadline).foregroundStyle(Design.muted)
            HStack(spacing:8){Circle().fill(WorkspaceTheme.accent(route.id)).frame(width:6,height:6);Text("\(count) saved items · \(space.modules.count) areas").font(.caption).foregroundStyle(Design.muted)}
        }.padding(24).frame(maxWidth:.infinity,alignment:.leading).background{WorkspacePanel(scope:route.id).clipShape(RoundedRectangle(cornerRadius:24))}.overlay{RoundedRectangle(cornerRadius:24).strokeBorder(WorkspaceTheme.accent(route.id).opacity(0.22),lineWidth:1)}.accessibilityElement(children:.contain).accessibilityIdentifier("workspace-header-"+route.id)
    }
    var workspaceHeading:String {
        switch route.id{case "moshia":return "Your story, taking shape.";case "band":return "Make room for the music.";case "ejj":return "Keep good work moving.";case "school":return "One step ahead.";default:return "A little room for you."}
    }
    func chapterBefore(_ a:EdizCore.Record,_ b:EdizCore.Record)->Bool {
        let first=WorkspaceContext.chapterNumber(a),second=WorkspaceContext.chapterNumber(b)
        if first != second {return (first ?? Int.max)<(second ?? Int.max)}
        return a.created == b.created ? a.id<b.id:a.created<b.created
    }
    func chapterLabel(_ record:EdizCore.Record)->String {
        if let number=WorkspaceContext.chapterNumber(record){return number == 0 ? "Prologue":"Chapter \(number)"}
        let offset=orderedRecords.contains{WorkspaceContext.chapterNumber($0) == 0} ? 0:1
        return "Chapter \((orderedRecords.firstIndex(where:{$0.id == record.id}) ?? 0)+offset)"
    }
    func metric(_ title:String,_ count:Int)->some View{VStack(alignment:.leading,spacing:5){Text(count,format:.number).font(.title2.weight(.medium));Text(title).font(.caption).foregroundStyle(Design.muted)}}
}
struct NativeWorkload:View {
    @EnvironmentObject var store:NativeStore
    var body:some View {
        Section("This week"){
            ForEach(0..<7){offset in
                let day=Calendar.current.date(byAdding:.day,value:offset,to:Date()) ?? Date()
                let items=store.records.filter{$0.space == "school" && $0.actionable && Time.date($0.due).map{Calendar.current.isDate($0,inSameDayAs:day)} == true}
                HStack{Text(day,format:.dateTime.weekday(.wide));Spacer();Text("\(items.count) \(items.count == 1 ? "item":"items")").foregroundStyle(Design.muted);if items.contains(where:{$0.duration != nil}){Text("\(items.compactMap(\.duration).reduce(0,+)) min").foregroundStyle(Design.muted)}}.font(.subheadline)
            }
            Text("Time is based on durations you’ve added; unsized items aren’t estimated.").font(.footnote).foregroundStyle(Design.muted)
        }
    }
}
struct NativeStoryDesk:View {
    @EnvironmentObject var store:NativeStore
    var material:[EdizCore.Record]{store.records.filter{$0.space == "moshia" && $0.status != "REJECTED"}}
    var chapters:[EdizCore.Record]{material.filter{$0.kind == "chapter"}.sorted{a,b in let first=WorkspaceContext.chapterNumber(a) ?? Int.max,second=WorkspaceContext.chapterNumber(b) ?? Int.max;return first == second ? a.created<b.created:first<second}}
    var threads:[EdizCore.Record]{material.filter{$0.kind == "thread"}.sorted{$0.updated>$1.updated}}
    var canon:[EdizCore.Record]{material.filter{$0.status == "CANON"}.sorted{$0.title.localizedStandardCompare($1.title) == .orderedAscending}}
    var latest:EdizCore.Record?{chapters.max{$0.updated<$1.updated}}
    var body:some View {
        List {
            Section {VStack(alignment:.leading,spacing:12){Text("A clear view of your story.").font(.title2.weight(.medium));Text("Work from your saved material. Possibilities stay separate from established canon.").font(.subheadline).foregroundStyle(Design.muted);HStack{deskCount("Chapters",chapters.count);Spacer();deskCount("Threads",threads.count);Spacer();deskCount("Canon",canon.count)}}.padding(.vertical,12)}
            if let latest{Section("Continue writing"){NavigationLink{NativeEditor(record:latest)}label:{VStack(alignment:.leading,spacing:8){Text(latest.title).font(.headline);if !latest.body.isEmpty{Text(latest.body).font(.subheadline).foregroundStyle(Design.muted).lineLimit(3)};Text(latest.status).font(.caption).foregroundStyle(WorkspaceTheme.accent("moshia"))}}.accessibilityIdentifier("story-desk-continue")}}
            Section("Open plot threads"){if threads.isEmpty{Text("Keep a question or unresolved thread in Plot threads.").foregroundStyle(Design.muted)};ForEach(threads){record in NavigationLink{NativeEditor(record:record)}label:{VStack(alignment:.leading,spacing:6){Text(record.title);Text(record.status).font(.caption).foregroundStyle(Design.muted)}}}}
            Section("Canon ledger"){if canon.isEmpty{Text("Your confirmed story facts will appear here. Mark material CANON after reviewing it.").foregroundStyle(Design.muted)};ForEach(canon){record in NavigationLink{NativeEditor(record:record)}label:{VStack(alignment:.leading,spacing:5){Text(record.title);Text(record.kind.capitalized).font(.caption).foregroundStyle(Design.muted)}}}}
            Section("Chapter outline"){if chapters.isEmpty{Text("Add a chapter to begin your outline.").foregroundStyle(Design.muted)};ForEach(chapters){record in NavigationLink{NativeEditor(record:record)}label:{HStack(alignment:.top,spacing:14){Text(WorkspaceContext.chapterNumber(record).map{String($0)} ?? "—").font(.title3.monospacedDigit()).foregroundStyle(WorkspaceTheme.accent("moshia")).frame(width:28);VStack(alignment:.leading,spacing:6){Text(record.title);Text([record.data["POV"],record.data["purpose"]].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:" · ")).font(.caption).foregroundStyle(Design.muted)}}}}}
            Section {NavigationLink("Browse characters"){NativeSpace(route:SpaceRoute(id:"moshia",kind:"character"))};NavigationLink("Browse locations"){NativeSpace(route:SpaceRoute(id:"moshia",kind:"location"))};NavigationLink("Story chronology"){NativeSpace(route:SpaceRoute(id:"moshia",kind:"event"))}}
        }.scrollContentBackground(.hidden).background(AppBackdrop(scope:"moshia")).navigationTitle("Continuity desk").navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for:EdizCore.Record.self){NativeEditor(record:$0)}
        .navigationDestination(for:SpaceRoute.self){NativeSpace(route:$0)}
    }
    func deskCount(_ title:String,_ count:Int)->some View{VStack(alignment:.leading,spacing:5){Text(String(count)).font(.title2.monospacedDigit());Text(title).font(.caption).foregroundStyle(Design.muted)}}
}

struct NativeGradeProjection:View {
    @EnvironmentObject var store:NativeStore
    @State private var subject=""
    @State private var next=2.0
    @State private var weight=1.0
    var subjects:[String]{Array(Set(store.records.filter{$0.kind == "grade"}.compactMap{$0.data["subject"]})).sorted()}
    var body:some View {
        Section("Grade projection"){
            if subjects.isEmpty{Text("Add a grade and subject to explore possible results.").font(.subheadline).foregroundStyle(Design.muted)}else{
                Picker("Subject",selection:$subject){ForEach(subjects,id:\.self){Text($0).tag($0)}}
                Stepper("Next grade: \(next.formatted(.number.precision(.fractionLength(1))))",value:$next,in:1...6,step:0.1)
                Stepper("Weight: \(weight.formatted(.number.precision(.fractionLength(1))))",value:$weight,in:0.1...10,step:0.1)
                if let value=Grades.project(store.records,subject:subject,next:next,weight:weight){Text(value,format:.number.precision(.fractionLength(2))).font(.title2.weight(.medium))}
                Text("A weighted estimate from your records, not an official grade.").font(.footnote).foregroundStyle(Design.muted)
            }
        }.onAppear{if !subjects.contains(subject){subject=subjects.first ?? ""}}.onChange(of:subjects){_,values in if !values.contains(subject){subject=values.first ?? ""}}
    }
}
struct NativeTimeline:View {
    @EnvironmentObject var store:NativeStore
    @State private var query=""
    var events:[EdizCore.Record]{store.records.filter{$0.space == "moshia" && $0.kind == "event" && (query.isEmpty || [$0.data["characters"],$0.data["location"],$0.data["chapter"]].compactMap{$0}.joined(separator:" ").localizedCaseInsensitiveContains(query))}.sorted{($0.data["storyDate"] ?? $0.due ?? $0.created)<($1.data["storyDate"] ?? $1.due ?? $1.created)}}
    var body:some View{Section("Story chronology"){TextField("Filter character, chapter or location",text:$query);ForEach(events){event in NavigationLink(value:event){VStack(alignment:.leading,spacing:7){Text(event.data["storyDate"] ?? event.due ?? "Story date not set").font(.caption).foregroundStyle(Design.muted);Text(event.title).font(.body.weight(.medium));Text([event.status,event.data["location"] ?? "",event.data["characters"] ?? ""].filter{!$0.isEmpty}.joined(separator:" · ")).font(.subheadline).foregroundStyle(Design.muted)}}}}}
}
struct NativeFocus:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) private var dismiss
    let record:EdizCore.Record
    @State private var started:Date?
    @State private var accumulated=0.0
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var begun:Bool {started != nil || accumulated>0}
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:24){
                    HStack(spacing:8){SpaceMark(space:Catalog.space(record.space));Text(Catalog.space(record.space).name).font(Design.font(14,weight:"Regular")).foregroundStyle(Design.muted)}.padding(.top,24)
                    Text(record.title).font(Design.font(24,relativeTo:.title2)).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
                    Text(!begun ? "A little space to begin.":started == nil ? "Take your time. Your session is here.":"Stay with this one thing.").font(Design.font(15,weight:"Regular")).foregroundStyle(Design.muted).multilineTextAlignment(.center)
                    TimelineView(.periodic(from:.now,by:1)){context in
                        let elapsed=max(0,Int(accumulated+(started.map{context.date.timeIntervalSince($0)} ?? 0)))
                        ZStack{
                            Circle().fill(WorkspaceTheme.accent(record.space).opacity(0.07)).frame(width:270,height:270)
                            Circle().stroke(Design.muted.opacity(0.12),style:StrokeStyle(lineWidth:1,dash:[1,12])).frame(width:250,height:250)
                            Circle().fill(LinearGradient(colors:[Design.raised,Design.surface],startPoint:.topLeading,endPoint:.bottomTrailing)).frame(width:224,height:224).shadow(color:.black.opacity(0.16),radius:22,y:12)
                            if let minutes=record.duration,minutes>0{Circle().trim(from:0,to:min(1,Double(elapsed)/Double(minutes*60))).stroke(WorkspaceTheme.accent(record.space).opacity(0.6),style:StrokeStyle(lineWidth:3,lineCap:.round)).frame(width:236,height:236).rotationEffect(.degrees(-90)).animation(reducedMotion ? nil:.easeInOut(duration:0.8),value:elapsed)}
                            VStack(spacing:14){Text("TIME WITH YOUR WORK").font(.caption2).tracking(2).foregroundStyle(Design.muted);Text("\(elapsed/60):\(String(format:"%02d",elapsed%60))").font(.system(size:54,weight:.light,design:.rounded)).monospacedDigit().contentTransition(.numericText());HStack(spacing:6){Circle().fill(started != nil ? WorkspaceTheme.accent(record.space):Design.muted).frame(width:5,height:5);Text(started != nil ? "Here, with one thing":begun ? "A quiet pause":"Whenever you’re ready").font(.caption).foregroundStyle(Design.muted)}}
                        }.frame(height:280).padding(.vertical,4)
                    }
                    if let minutes=record.duration{Text("You allowed about \(minutes) minutes. There’s no countdown.").font(Design.font(14,weight:"Regular")).foregroundStyle(Design.muted).multilineTextAlignment(.center)}
                    if !record.body.isEmpty{Surface{VStack(alignment:.leading,spacing:10){Text("Keep in mind").font(Design.font(16));Text(record.body).font(Design.font(15,weight:"Regular")).lineSpacing(4).textSelection(.enabled)}}}
                    Group{
                    HStack(spacing:12){
                        GlassAction{Button(started == nil ? (begun ? "Continue":"Begin"):"Pause"){toggle()}.font(Design.font(16)).frame(maxWidth:.infinity,minHeight:48)}
                        if begun{GlassAction{Button("Finish"){store.complete(record);dismiss()}.font(Design.font(14)).foregroundStyle(Design.muted).frame(maxWidth:.infinity,minHeight:48)}}
                    }.padding(.top,4)
                }
                }.frame(maxWidth:.infinity).padding(24)
            }.background(AppBackdrop().environment(\.edizWorkspaceFocus,record.space)).navigationTitle("Focus").navigationBarTitleDisplayMode(.inline)
                .toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}
        }.preferredColorScheme(.dark).tint(Design.accent)
    }
    func toggle(){UIImpactFeedbackGenerator(style:.soft).impactOccurred();withAnimation(reducedMotion ? nil:.easeInOut(duration:0.25)){if let start=started{accumulated += Date().timeIntervalSince(start);started=nil}else{started=Date()}}}
}
struct NativeReview:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) private var dismiss
    let weekly:Bool
    var events:[Activity]{store.activity.filter{Time.date($0.at).map{$0>Date().addingTimeInterval(weekly ? -7*86400 : -86400)} ?? false}}
    var body:some View {
        NavigationStack{List{Section("Progress"){Text("\(events.filter{$0.action == "Completed"}.count) completed \(weekly ? "this week":"today")").font(.body.weight(.medium))}
            Section("Next steps"){ForEach(Array(store.priorities.prefix(5))){p in VStack(alignment:.leading,spacing:8){Text(p.record.title);Text(p.reasons.first ?? "").font(.subheadline).foregroundStyle(Design.muted);if let due=Time.date(p.record.due),due<Date(){Button("Move to tomorrow"){var record=p.record;record.due=Time.string(Calendar.current.date(byAdding:.day,value:1,to:Date()) ?? Date());_ = store.save(record,action:"Rescheduled")}}}}}
            Section("What changed"){if events.isEmpty{Text("Your history starts with your first saved item.").foregroundStyle(Design.muted)};ForEach(events){event in VStack(alignment:.leading,spacing:5){Text(event.title);Text(event.action).font(.caption).foregroundStyle(Design.muted)}}}
        }.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle(weekly ? "This week":"Today’s review").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}}
    }
}

struct NativeKnownSongs:View {
    @EnvironmentObject var store:NativeStore
    @State private var songs:[KnownSong]=[]
    @State private var loading=false
    @State private var error:String?
    @State private var job:Task<Void,Never>?
    @State private var activeRequest=UUID()
    var body:some View {
        List {
            Section{Text("Ideas for your next rehearsal, informed by your band notes. Listen first, then choose what to add.").font(.subheadline).foregroundStyle(Design.muted)}
            if loading{Section{HStack{ProgressView();Text("Finding your next songs…");Spacer();Button("Stop"){activeRequest=UUID();job?.cancel();loading=false}}}}
            if let error{Section{Text(error);Button("Try again"){load()}}}
            ForEach(songs){song in Section{KnownSongRow(song:song)}}
        }.scrollContentBackground(.hidden).background(AppBackdrop(scope:"band")).navigationTitle("Add known songs").navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.topBarTrailing){Button{load()}label:{Image(systemName:"arrow.clockwise")}.accessibilityLabel("New suggestions").disabled(loading)}}
            .onAppear{if songs.isEmpty,!loading{load()}}.onDisappear{activeRequest=UUID();job?.cancel();loading=false}
    }
    func load(){
        job?.cancel();let id=UUID();activeRequest=id;error=nil;loading=true
        job=Task{@MainActor in defer{if activeRequest==id{loading=false}}
            guard let token=store.assistantToken else{error="Connect your assistant in Settings to get suggestions based on your band context.";return}
            do{let reply=try await GeminiAssistant.answer(question:"Suggest 20 songs we could learn next. Use our band context and avoid our saved repertoire.",records:store.records.filter{$0.space == "band"},conversation:[],token:token,scope:"band",requestMode:"song-recommendations",memories:store.searchableMemories().filter{$0.space == "band"});try Task.checkCancellation();songs=reply.songSuggestions ?? [];if songs.isEmpty{error="The assistant returned no song suggestions. Please try again."}}
            catch{if !Task.isCancelled{self.error=error.localizedDescription}}
        }
    }
}
struct KnownSongRow:View {
    @EnvironmentObject var store:NativeStore
    let song:KnownSong
    @State private var preview:SongPreview?
    @State private var loading=false
    @State private var error:String?
    @State private var previewJob:Task<Void,Never>?
    @Environment(\.scenePhase) private var phase
    var saved:Bool{store.records.contains{$0.space == "band" && $0.kind == "song" && $0.title.localizedCaseInsensitiveCompare(song.title) == .orderedSame && ($0.data["artist"] ?? "").localizedCaseInsensitiveCompare(song.artist) == .orderedSame}}
    var body:some View {
        VStack(alignment:.leading,spacing:12){Text(song.title).font(.headline);Text(song.artist).font(.subheadline).foregroundStyle(Design.muted);Text(song.reason).font(.subheadline).fixedSize(horizontal:false,vertical:true)
            if let preview{NativeSongPreview(preview:preview)}else{Button{findPreview()}label:{Label(loading ? "Finding preview…":"Listen to a preview",systemImage:"play.circle")}.disabled(loading)}
            if let error{Text(error).font(.caption).foregroundStyle(Design.muted)}
            HStack{Button(saved ? "Added":"Add to songs"){var record=EdizCore.Record(space:"band",kind:"song",title:song.title);record.data["artist"]=song.artist;record.body=song.reason;record.status="Learning";if store.save(record){UINotificationFeedbackGenerator().notificationOccurred(.success)}}.disabled(saved)}
        }.padding(.vertical,8).onDisappear{previewJob?.cancel();loading=false}.onChange(of:phase){_,value in if value == .background{previewJob?.cancel();loading=false}}
    }
    func findPreview(){previewJob?.cancel();loading=true;error=nil;previewJob=Task{@MainActor in defer{loading=false};guard let token=store.assistantToken else{error="Connect your assistant first.";return};do{let reply=try await GeminiAssistant.answer(question:"Play "+song.title+" by "+song.artist,records:[],conversation:[],token:token,scope:"band");try Task.checkCancellation();preview=reply.musicPreview;if preview==nil{error="No catalog preview is available for this song."}}catch{if !Task.isCancelled{self.error=error.localizedDescription}}}}
}

@MainActor final class BookAudioController:ObservableObject {
    @Published var active=false
    @Published var completed=false
    @Published var preparingBook=false
    @Published var preparedCount=0
    @Published var preparationError:String?
    @Published var downloadDetail=""
    @Published var downloadPaused=false
    @Published var segmentCounts:[String:Int]=[:]
    @Published var segmentTotals:[String:Int]=[:]
    private var downloadGeneration=UUID()
    var downloadProgress:Double{Double(segmentCounts.values.reduce(0,+))/Double(max(1,segmentTotals.values.reduce(0,+)))}
    var completedParts:Int{segmentCounts.values.reduce(0,+)}
    var totalParts:Int{segmentTotals.values.reduce(0,+)}
    func offlineSummary(_ source:[EdizCore.Record],voice:String)->String{
        let urls=source.map{cacheURL(for:$0,voice:voice)}.filter{BookAudioDownload.isReady($0)}
        let bytes=urls.reduce(0){$0+((try? $1.resourceValues(forKeys:[.fileSizeKey]).fileSize) ?? 0)}
        let duration=urls.reduce(0.0){$0+((try? AVAudioPlayer(contentsOf:$1).duration) ?? 0)}
        return ByteCountFormatter.string(fromByteCount:Int64(bytes),countStyle:.file)+" on this iPhone"+(duration>0 ? " · "+Self.time(duration):"")
    }
    func pauseDownload(){downloadGeneration=UUID();downloadJob?.cancel();downloadJob=nil;preparingBook=false;downloadPaused=true;downloadDetail="Paused · completed audio is kept";preparedCount=prepared(chapters,voice:voiceName);refreshDurations()}
    private func segmentURL(_ chapter:EdizCore.Record,text:String,voice:String)->URL{
        let hash=SHA256.hash(data:Data((voice+"\u{0}"+text).utf8)).map{String(format:"%02x",$0)}.joined()
        return cacheDirectory.appendingPathComponent("Segments",isDirectory:true).appendingPathComponent(cacheURL(for:chapter,voice:voice).deletingPathExtension().lastPathComponent+"-"+hash+".m4a")
    }
    @Published var durations:[Double]=[]
    private var downloadJob:Task<Void,Never>?
    @Published var playbackError:String?
    @Published var chapterTitle=""
    @Published var chapterNumber=0
    @Published var chapterCount=0
    @Published var speed:Float=1
    @Published var voiceName="Aoede"
    let speaker=NativeAssistantSpeaker()
    private var chapters:[EdizCore.Record]=[]
    private var index=0
    private var token:String?
    var practiceAudio:URL?
    var practiceCache:URL?
    private var cacheDirectory:URL {
        if let practiceCache{return practiceCache}
        let testing=ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let base=testing ? FileManager.default.temporaryDirectory:FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("EdizOS",isDirectory:true)
        return base.appendingPathComponent(testing ? "BookAudioTests":"BookAudio",isDirectory:true)
    }
    func cacheURL(for chapter:EdizCore.Record,voice:String)->URL {
        let input=Data(("v2-live-chunks\u{0}"+voice+"\u{0}"+chapter.title+"\u{0}"+chapter.body).utf8)
        let hash=SHA256.hash(data:input).map{String(format:"%02x",$0)}.joined()
        return cacheDirectory.appendingPathComponent(hash+".m4a")
    }
    func prepared(_ source:[EdizCore.Record],voice:String)->Int {source.filter{BookAudioDownload.isReady(cacheURL(for:$0,voice:voice))}.count}
    var chapterChoices:[String]{chapters.map(\.title)}
    var totalDuration:Double{!durations.isEmpty && durations.allSatisfy{$0>0} ? durations.reduce(0,+):0}
    var position:Double{completed ? totalDuration:durations.prefix(index).reduce(0,+)+speaker.recordedSeconds}
    func refreshDurations(){durations=chapters.map{(try? AVAudioPlayer(contentsOf:cacheURL(for:$0,voice:voiceName)).duration) ?? 0}}
    func seek(_ seconds:Double){
        guard totalDuration>0 else{return};var remaining=max(0,min(seconds,totalDuration-0.05));var selected=0
        while selected+1<durations.count,remaining>=durations[selected]{remaining-=durations[selected];selected+=1}
        let wasPaused=speaker.paused;if selected != index || completed{index=selected;playCurrent();if wasPaused{speaker.pausePlayback()}};speaker.seekRecording(remaining)
    }
    static func time(_ seconds:Double)->String{let n=max(0,Int(seconds));return n>=3600 ? String(format:"%d:%02d:%02d",n/3600,(n%3600)/60,n%60):String(format:"%d:%02d",n/60,n%60)}
    func selectChapter(_ selected:Int){guard chapters.indices.contains(selected) else{return};index=selected;playCurrent()}
    func start(_ source:[EdizCore.Record],at startIndex:Int,token:String?,voice:String){
        stop();guard !source.isEmpty else{return}
        chapters=source;index=min(max(0,startIndex),source.count-1);self.token=token;voiceName=voice;chapterCount=source.count;refreshDurations();active=true;playCurrent()
    }
    func playCurrent(){
        guard active,chapters.indices.contains(index) else{stop();return}
        completed=false;chapterNumber=index+1;chapterTitle=chapters[index].title;playbackError=nil
        speaker.failed={[weak self] message in self?.playbackError=message}
        speaker.finished={[weak self] in self?.next()}
        speaker.setPlaybackRate(speed)
        let chapter=chapters[index],url=cacheURL(for:chapter,voice:voiceName)
        if FileManager.default.fileExists(atPath:url.path){speaker.playRecorded([url],voice:voiceName);return}
        guard let token else{playbackError="Connect your assistant to prepare this chapter. Already prepared chapters play offline.";return}
        speaker.say(chapter.title+". "+chapter.body,token:token,natural:true,voice:voiceName,recordingURL:url,preferredSpeechModel:"live")
    }
    func prepareAll(_ source:[EdizCore.Record],token:String?,voice:String){
        stop();guard !source.isEmpty else{return}
        chapters=source;self.token=token;voiceName=voice;chapterCount=source.count;preparedCount=prepared(source,voice:voice);refreshDurations();preparationError=nil
        let missing=source.filter{!BookAudioDownload.isReady(cacheURL(for:$0,voice:voice))}
        guard !missing.isEmpty else{downloadDetail="Downloaded · ready offline";return}
        guard token != nil || practiceAudio != nil else{preparationError="Connect your assistant to download the missing audio.";return}
        segmentTotals=Dictionary(source.map{($0.id,SpeechText.chunks($0.title+". "+$0.body,limit:700).count)},uniquingKeysWith:{first,_ in first})
        segmentCounts=Dictionary(source.map{chapter in let texts=SpeechText.chunks(chapter.title+". "+chapter.body,limit:700);return (chapter.id,BookAudioDownload.isReady(cacheURL(for:chapter,voice:voice)) ? texts.count:texts.filter{BookAudioDownload.isReady(segmentURL(chapter,text:$0,voice:voice))}.count)},uniquingKeysWith:{first,_ in first})
        downloadPaused=false;preparingBook=true;let generation=downloadGeneration
        downloadJob=Task{@MainActor in
            do{
                try await withThrowingTaskGroup(of:Void.self){group in
                    var remaining=missing.makeIterator()
                    for _ in 0..<min(2,missing.count){if let chapter=remaining.next(){group.addTask{try await self.downloadChapter(chapter,token:token ?? "",voice:voice,generation:generation)}}}
                    while try await group.next() != nil {
                        try Task.checkCancellation();guard self.downloadGeneration==generation else{throw CancellationError()};self.preparedCount+=1;self.refreshDurations()
                        if let chapter=remaining.next(){group.addTask{try await self.downloadChapter(chapter,token:token ?? "",voice:voice,generation:generation)}}
                    }
                }
                guard !Task.isCancelled,downloadGeneration==generation else{return};preparingBook=false;downloadDetail="Downloaded · ready offline";refreshDurations()
            }catch{guard !Task.isCancelled,downloadGeneration==generation else{return};preparingBook=false;downloadPaused=true;preparationError="Download paused. Finished audio is kept; tap Resume download to continue.";downloadDetail="";refreshDurations()}
        }
    }
    private func downloadChapter(_ chapter:EdizCore.Record,token:String,voice:String,generation:UUID) async throws {
        let destination=cacheURL(for:chapter,voice:voice)
        let folder=cacheDirectory.appendingPathComponent("Segments",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        var pieces:[URL]=[]
        let segments=SpeechText.chunks(chapter.title+". "+chapter.body,limit:700)
        for (number,text) in segments.enumerated(){
            try Task.checkCancellation();guard downloadGeneration==generation else{throw CancellationError()};downloadDetail="\(chapter.title) · part \(number+1) of \(segments.count)"
            let url=segmentURL(chapter,text:text,voice:voice)
            if !BookAudioDownload.isReady(url){
                if let practiceAudio{try await Task.sleep(for:.seconds(8));try Task.checkCancellation();try FileManager.default.copyItem(at:practiceAudio,to:url)}
                else{try await BookAudioDownload.segment(text,token:token,voice:voice,to:url)}
            }
            try Task.checkCancellation();guard downloadGeneration==generation else{throw CancellationError()};segmentCounts[chapter.id]=max(segmentCounts[chapter.id] ?? 0,number+1)
            pieces.append(url)
        }
        try Task.checkCancellation();guard downloadGeneration==generation else{throw CancellationError()};downloadDetail="Finishing "+chapter.title
        try await BookAudioDownload.join(pieces,to:destination)
        for piece in Set(pieces){try? FileManager.default.removeItem(at:piece)}
    }
    func next(){if index+1<chapters.count{index+=1;playCurrent()}else{speaker.stop();completed=true}}
    func previous(){guard !chapters.isEmpty else{return};index=max(0,index-1);playCurrent()}
    func retry(){playCurrent()}
    func setSpeed(_ value:Float){speed=value;speaker.setPlaybackRate(value)}
    func changeVoice(_ value:String){guard voiceName != value else{return};guard prepared(chapters,voice:value)==chapters.count else{playbackError="Download \(value) from Book contents before switching narrators.";return};voiceName=value;UserDefaults.standard.set(value,forKey:"moshia-audiobook-voice");refreshDurations();playCurrent()}
    func cycleVoice(){let voices=["Aoede","Puck","Kore"];let next=(voices.firstIndex(of:voiceName) ?? 0)+1;changeVoice(voices[next % voices.count])}
    #if DEBUG
    func seedJoinedTestAudio(_ source:[EdizCore.Record]) async throws {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing"),let clip=Bundle.main.url(forResource:"new-additions",withExtension:"m4a",subdirectory:"GuideAudio/Aoede") else{return}
        try FileManager.default.createDirectory(at:cacheDirectory,withIntermediateDirectories:true)
        for chapter in source{try await BookAudioDownload.join([clip,clip],to:cacheURL(for:chapter,voice:"Aoede"))}
        chapters=source;voiceName="Aoede";refreshDurations();preparedCount=source.count
    }
    func resetTestAudio(){guard ProcessInfo.processInfo.arguments.contains("-ui-testing") else{return};try? FileManager.default.removeItem(at:cacheDirectory)}
    #endif
    func stop(){downloadGeneration=UUID();downloadJob?.cancel();downloadJob=nil;downloadPaused=false;downloadDetail="";speaker.finished=nil;speaker.failed=nil;speaker.stop();active=false;completed=false;preparingBook=false;chapterTitle="";chapterNumber=0;chapterCount=0;chapters=[];durations=[];token=nil}
}

struct BookAudioBar:View {
    @ObservedObject var audio:BookAudioController
    @ObservedObject var speaker:NativeAssistantSpeaker
    var body:some View {
        VStack(spacing:8){
            HStack(spacing:12){
                Image(systemName:"headphones").font(.title3).frame(width:40,height:40).background(WorkspaceTheme.accent("moshia").opacity(0.14),in:RoundedRectangle(cornerRadius:12))
                VStack(alignment:.leading,spacing:3){Text(audio.chapterTitle).font(.subheadline.weight(.semibold)).lineLimit(1);Text(speaker.paused ? "Paused · \(audio.voiceName)":speaker.voiceNote ?? (speaker.preparing ? "Preparing natural voice…":"Chapter \(audio.chapterNumber) of \(audio.chapterCount) · \(audio.voiceName)")).font(.caption).foregroundStyle(Design.muted).lineLimit(2)}
                Spacer(minLength:0)
                Button{audio.stop()}label:{Image(systemName:"stop.fill").font(.subheadline.weight(.semibold)).foregroundStyle(Design.background).frame(width:40,height:40).background(WorkspaceTheme.accent("moshia"),in:Circle())}.buttonStyle(.plain).accessibilityLabel("Stop audiobook")
            }
            HStack(spacing:10){
                Button{if audio.completed{audio.selectChapter(0)}else if speaker.paused{speaker.resumePlayback()}else{speaker.pausePlayback()}}label:{Label(audio.completed ? "Replay":speaker.paused ? "Play":"Pause",systemImage:audio.completed ? "arrow.counterclockwise":speaker.paused ? "play.fill":"pause.fill").frame(minHeight:40)}.buttonStyle(.plain).accessibilityIdentifier("book-audiobook-pause")
                Button{audio.setSpeed(max(0.75,audio.speed-0.25))}label:{Image(systemName:"minus").frame(width:32,height:40)}.buttonStyle(.plain).disabled(audio.speed<=0.75).accessibilityLabel("Slower audiobook").accessibilityIdentifier("book-audiobook-slower")
                Text(String(format:"%g×",Double(audio.speed))).monospacedDigit().frame(minWidth:32).accessibilityIdentifier("book-audiobook-speed")
                Button{audio.setSpeed(min(1.5,audio.speed+0.25))}label:{Image(systemName:"plus").frame(width:32,height:40)}.buttonStyle(.plain).disabled(audio.speed>=1.5).accessibilityLabel("Faster audiobook").accessibilityIdentifier("book-audiobook-faster")
                Button{audio.cycleVoice()}label:{Label(audio.voiceName,systemImage:"waveform").lineLimit(1).frame(minHeight:40)}.buttonStyle(.plain).accessibilityLabel("Change audiobook voice").accessibilityValue(audio.voiceName).accessibilityIdentifier("book-audiobook-voice")
                Spacer(minLength:0)
            }.font(.caption.weight(.semibold)).foregroundStyle(WorkspaceTheme.accent("moshia"))
        }.padding(.horizontal,16).padding(.vertical,8).background(Design.raised).accessibilityElement(children:.contain).accessibilityIdentifier("book-audiobook-controls").accessibilityValue("Audio level \(Int(speaker.level*100))")
    }
}
struct BookListeningView:View {
    @ObservedObject var audio:BookAudioController
    @ObservedObject var speaker:NativeAssistantSpeaker
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var chapterPicker=false
    @State private var chapterQuery=""
    private let accent=WorkspaceTheme.accent("moshia")
    var body:some View {
        GeometryReader{geometry in
            VStack(spacing:0){
                HStack{Button{dismiss()}label:{Label("Back to book",systemImage:"chevron.down").frame(minHeight:44)}.accessibilityIdentifier("audiobook-back");Spacer();Text("MOSHIA AUDIOBOOK").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Design.muted)}.padding(.horizontal,24).padding(.top,12)
                Spacer(minLength:20)
                ZStack{
                    RoundedRectangle(cornerRadius:36).fill(LinearGradient(colors:[Color(red:0.35,green:0.29,blue:0.23),Color(red:0.13,green:0.12,blue:0.11)],startPoint:.topLeading,endPoint:.bottomTrailing))
                    RoundedRectangle(cornerRadius:36).strokeBorder(accent.opacity(0.35),lineWidth:1)
                    VStack(spacing:25){Image(systemName:"book.closed.fill").font(.system(size:64,weight:.ultraLight)).foregroundStyle(accent);HStack(alignment:.center,spacing:5){ForEach(0..<17,id:\.self){index in Capsule().fill(accent.opacity(speaker.speaking ? 0.9:0.35)).frame(width:4,height:speaker.speaking ? 8+CGFloat((index*7)%19)+speaker.level*34:6+CGFloat(index%3)*3)}}.frame(height:64).animation(reducedMotion ? nil:.easeOut(duration:0.16),value:speaker.level)}
                }.frame(width:max(160,min(geometry.size.width-72,geometry.size.height*0.30)),height:max(160,min(geometry.size.width-72,geometry.size.height*0.30))).shadow(color:.black.opacity(0.25),radius:22,y:15).accessibilityElement(children:.ignore).accessibilityLabel("Audiobook artwork").accessibilityValue("Audio level \(Int(speaker.level*100))").accessibilityIdentifier("book-listening-level")
                Spacer(minLength:20)
                VStack(alignment:.leading,spacing:12){Text(audio.chapterTitle).font(.system(.title,design:.serif).weight(.medium)).lineLimit(2).minimumScaleFactor(0.8);Text("Chapter \(audio.chapterNumber) of \(audio.chapterCount) · \(audio.voiceName)").font(.subheadline).foregroundStyle(Design.muted);if audio.totalDuration>0{Slider(value:Binding(get:{min(audio.position,audio.totalDuration)},set:{audio.seek($0)}),in:0...max(1,audio.totalDuration)).tint(accent).accessibilityLabel("Audiobook position").accessibilityIdentifier("book-listening-seek");HStack{Text(BookAudioController.time(audio.position));Spacer();Text(BookAudioController.time(audio.totalDuration))}.font(.caption.monospacedDigit()).foregroundStyle(Design.muted).accessibilityIdentifier("book-listening-duration")}else{Text("Full length appears after download.").font(.caption).foregroundStyle(Design.muted)};Text(audio.completed ? "Book complete · replay or choose a chapter":speaker.paused ? "Paused":speaker.voiceNote ?? (speaker.preparing ? "Preparing natural voice…":"Listening")).font(.caption).foregroundStyle(Design.muted).lineLimit(2)}.frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,32)
                HStack(spacing:24){Button{audio.previous()}label:{Image(systemName:"backward.end.fill").frame(width:44,height:56)}.accessibilityLabel("Previous chapter");Button{if audio.completed{audio.selectChapter(0)}else if speaker.paused{speaker.resumePlayback()}else{speaker.pausePlayback()}}label:{Image(systemName:audio.completed ? "arrow.counterclockwise":speaker.paused ? "play.fill":"pause.fill").font(.title2).foregroundStyle(Design.background).frame(width:74,height:74).background(accent,in:Circle())}.accessibilityLabel(audio.completed ? "Replay audiobook":speaker.paused ? "Play audiobook":"Pause audiobook").accessibilityIdentifier("book-listening-pause");Button{audio.next()}label:{Image(systemName:"forward.end.fill").frame(width:44,height:56)}.accessibilityLabel("Next chapter")}.font(.title3).foregroundStyle(Design.ink).padding(.top,27)
                HStack(spacing:20){Button{audio.setSpeed(audio.speed>=1.5 ? 0.75:audio.speed+0.25)}label:{Text(String(format:"%g×",Double(audio.speed))).font(.subheadline.monospacedDigit()).frame(minWidth:58,minHeight:44)}.accessibilityLabel("Audiobook speed").accessibilityValue(String(format:"%g×",Double(audio.speed))).accessibilityIdentifier("book-listening-speed");Button{audio.cycleVoice()}label:{Label(audio.voiceName,systemImage:"waveform").font(.subheadline).frame(minHeight:44)}.accessibilityLabel("Narrator voice").accessibilityValue(audio.voiceName).accessibilityIdentifier("book-listening-voice");Button{audio.stop();dismiss()}label:{Label("Stop",systemImage:"stop.fill").font(.subheadline).frame(minHeight:44)}.accessibilityIdentifier("book-listening-stop")}.foregroundStyle(Design.ink).padding(.top,10)
                if let error=audio.playbackError{VStack(spacing:8){Text(error).font(.footnote).multilineTextAlignment(.center);Button("Retry this chapter"){audio.retry()}.buttonStyle(ActionStyle()).accessibilityIdentifier("book-listening-retry")}.foregroundStyle(Design.muted).padding(.horizontal,30).padding(.top,10)}
                Button{chapterPicker=true}label:{Label("Chapters",systemImage:"list.bullet").frame(minHeight:44)}.font(.subheadline).foregroundStyle(Design.ink).padding(.top,8).accessibilityIdentifier("book-listening-chapters")
                Text("Voice changes restart this chapter.").font(.caption2).foregroundStyle(Design.muted).padding(.top,16)
                Spacer(minLength:20)
            }.frame(maxWidth:.infinity,maxHeight:.infinity).background(AppBackdrop(scope:"moshia"))
        }.preferredColorScheme(.dark)
            .sheet(isPresented:$chapterPicker){NavigationStack{List{ForEach(Array(audio.chapterChoices.enumerated()),id:\.offset){number,title in if chapterQuery.isEmpty || title.localizedCaseInsensitiveContains(chapterQuery){Button{audio.selectChapter(number);chapterPicker=false}label:{HStack{Text("\(number+1)").monospacedDigit().foregroundStyle(Design.muted);Text(title).font(.system(.body,design:.serif));Spacer();if number+1 == audio.chapterNumber{Image(systemName:"waveform").foregroundStyle(accent)}}}}}}.searchable(text:$chapterQuery,prompt:"Find a chapter").navigationTitle("Chapters").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){chapterPicker=false}}}}}
            .onChange(of:audio.active){_,active in if !active{dismiss()}}
    }
}
struct NativeFullBook:View {
    var chaptersOverride:[EdizCore.Record]?=nil
    @EnvironmentObject var store:NativeStore
    @State private var page=0
    @State private var pages:[ReaderPage]=[]
    @State private var textSize:Double=20
    @State private var paper="linen"
    @State private var contents=false
    @State private var bookVoice="Aoede"
    @State private var listening=false
    @State private var controls=true
    @StateObject private var audiobook=BookAudioController()
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var chapters:[EdizCore.Record]{(chaptersOverride ?? store.originalManuscript).sorted{(Int($0.data["binderOrder"] ?? "") ?? 0)<(Int($1.data["binderOrder"] ?? "") ?? 0)}}
    var pageColor:Color{paper == "paper" ? Color(red:0.94,green:0.90,blue:0.82):paper == "night" ? Color(red:0.10,green:0.10,blue:0.10):Color(red:0.18,green:0.16,blue:0.14)}
    var ink:Color{paper == "paper" ? Color(red:0.20,green:0.17,blue:0.14):Color(red:0.88,green:0.83,blue:0.75)}
    var body:some View {
        GeometryReader{geometry in
            VStack(spacing:0){
                if pages.isEmpty{QuietEmpty(title:"Your original book",message:"The private manuscript will appear here when it has been imported on this device.").padding(24)}else{
                    TabView(selection:$page){ForEach(Array(pages.enumerated()),id:\.offset){index,item in
                        VStack(alignment:.leading,spacing:20){
                            VStack(alignment:.leading,spacing:10){
                                if item.offset == 0{Text("MOSHIA").font(.caption2.weight(.medium)).tracking(3).opacity(0.55);Text(item.chapter).font(.system(size:25,weight:.medium,design:.serif)).lineLimit(2).minimumScaleFactor(0.8)}else{HStack{Text(item.chapter).lineLimit(1);Spacer();Text("MOSHIA").tracking(2)}.font(.caption2).opacity(0.5)}
                                Rectangle().fill(ink.opacity(0.14)).frame(height:1)
                            }.frame(height:76,alignment:.bottom)
                            Text(item.text).font(.system(size:textSize,design:.serif)).lineSpacing(5).frame(maxWidth:.infinity,alignment:.leading).fixedSize(horizontal:false,vertical:true)
                            Spacer(minLength:0)
                        }.foregroundStyle(ink).padding(.horizontal,30).padding(.top,24).padding(.bottom,12).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).contentShape(Rectangle()).onTapGesture{location in
                            if location.x<geometry.size.width*0.25{turn(-1)}else if location.x>geometry.size.width*0.75{turn(1)}else{withAnimation(reducedMotion ? nil:.easeInOut(duration:0.2)){controls.toggle()}}
                        }.tag(index).accessibilityIdentifier("book-page-"+String(index)).accessibilityAction(named:"Next page"){turn(1)}.accessibilityAction(named:"Previous page"){turn(-1)}
                    }}.tabViewStyle(.page(indexDisplayMode:.never))
                    VStack(spacing:0){
                        HStack{Button{turn(-1)}label:{Image(systemName:"chevron.left").frame(width:44,height:44)}.accessibilityLabel("Previous page").disabled(page==0);Spacer();VStack(spacing:3){Text("\(page+1) of \(pages.count)").font(.caption.monospacedDigit());Text("Tap the edges or swipe to turn").font(.caption2).opacity(0.55)};Spacer();Button{turn(1)}label:{Image(systemName:"chevron.right").frame(width:44,height:44)}.accessibilityLabel("Next page").disabled(page>=pages.count-1)}
                        Slider(value:Binding(get:{Double(page)},set:{page=Int($0.rounded())}),in:0...Double(max(1,pages.count-1)),step:1).accessibilityLabel("Book position").tint(ink.opacity(0.6)).disabled(pages.count<2)
                    }.foregroundStyle(ink).padding(.horizontal,24).frame(height:74).opacity(controls ? 1:0.12).allowsHitTesting(controls)
                }
            }.background(pageColor).task(id:"\(geometry.size.width)-\(geometry.size.height)-\(textSize)"){paginate(size:geometry.size)}
        }.navigationTitle("Moshia · Full Book").navigationBarTitleDisplayMode(.inline).toolbar(.hidden,for:.tabBar).tint(WorkspaceTheme.accent("moshia"))
            .safeAreaInset(edge:.bottom,spacing:0){if audiobook.active && !listening{BookAudioBar(audio:audiobook,speaker:audiobook.speaker)}}
            .fullScreenCover(isPresented:$listening){BookListeningView(audio:audiobook,speaker:audiobook.speaker)}
            .toolbar{ToolbarItem(placement:.topBarTrailing){HStack(spacing:0){Button{contents=true;store.walkthrough?.event("reader-contents");store.walkthrough?.event("reader-audio-open")}label:{Image(systemName:"list.bullet").frame(width:44,height:44)}.accessibilityLabel("Book contents");Menu{Button("Larger text"){textSize=min(28,textSize+2)};Button("Smaller text"){textSize=max(16,textSize-2)};Picker("Page appearance",selection:$paper){Text("Warm linen").tag("linen");Text("Paper").tag("paper");Text("Night").tag("night")}}label:{Image(systemName:"textformat.size").frame(width:44,height:44)}.accessibilityLabel("Reader options")}.padding(.trailing,4)}}
            .sheet(isPresented:$contents){NavigationStack{List{ForEach(chapters){chapter in Button{if let index=pages.firstIndex(where:{$0.chapterID==chapter.id}){page=index};contents=false;store.walkthrough?.event("reader-chapter")}label:{VStack(alignment:.leading,spacing:6){Text(chapter.title).font(.system(.headline,design:.serif));if let index=pages.firstIndex(where:{$0.chapterID==chapter.id}){Text("Page \(index+1)").font(.caption).foregroundStyle(.secondary)};if BookAudioDownload.isReady(audiobook.cacheURL(for:chapter,voice:bookVoice)){Label("Audio ready offline",systemImage:"checkmark.circle").font(.caption).foregroundStyle(.secondary)}}.padding(.vertical,8)}}
                Section("Audiobook"){
                    if audiobook.practiceAudio != nil{Text("Practice uses a bundled guide voice sample, not book narration.").font(.caption)}
                    let voice=bookVoice
                    let ready=audiobook.prepared(chapters,voice:voice)
                    Picker("Narrator",selection:$bookVoice){Text("Aoede").tag("Aoede");Text("Puck").tag("Puck");Text("Kore").tag("Kore")}.disabled(audiobook.preparingBook || audiobook.practiceAudio != nil).onChange(of:bookVoice){_,voice in if !store.isPractice{UserDefaults.standard.set(voice,forKey:"moshia-audiobook-voice")}}
                    Button{let resumed=audiobook.downloadPaused;audiobook.prepareAll(chapters,token:store.assistantToken,voice:voice);store.walkthrough?.event(resumed ? "download-resumed":"download-started")}label:{Label(audiobook.preparingBook ? "Downloading \(audiobook.preparedCount) of \(chapters.count) chapters…":ready==chapters.count && !chapters.isEmpty ? "Downloaded · available offline":(audiobook.downloadPaused && audiobook.voiceName==voice) || ready>0 ? "Resume download":"Download audiobook",systemImage:ready==chapters.count ? "checkmark.circle.fill":"arrow.down.circle")}.disabled(chapters.isEmpty || audiobook.preparingBook || (ready<chapters.count && store.assistantToken == nil && audiobook.practiceAudio == nil)).accessibilityIdentifier("book-audiobook-prepare")
                    if audiobook.preparingBook{VStack(alignment:.leading,spacing:10){ProgressView(value:audiobook.downloadProgress).accessibilityIdentifier("book-download-progress");HStack{Text("\(Int(audiobook.downloadProgress*100))% · \(audiobook.completedParts) of \(audiobook.totalParts) audio parts").font(.caption.monospacedDigit());Spacer();Button("Pause"){audiobook.pauseDownload();store.walkthrough?.event("download-paused")}.accessibilityIdentifier("book-download-pause")};Text(audiobook.downloadDetail).font(.caption).foregroundStyle(Design.muted)}.padding(.vertical,8)}else if audiobook.downloadPaused && audiobook.voiceName==voice{Label("Paused · your completed audio is kept",systemImage:"pause.circle").font(.caption).foregroundStyle(Design.muted)}
                    if ready>0{Label(audiobook.offlineSummary(chapters,voice:voice),systemImage:"iphone").font(.caption).foregroundStyle(Design.muted).accessibilityIdentifier("book-download-storage")}
                    Button{startAudiobook(fromCurrent:false)}label:{Label("Play full book",systemImage:"play.circle.fill")}.disabled(chapters.isEmpty || ready != chapters.count || audiobook.preparingBook).accessibilityIdentifier("book-audiobook-start")
                    Button{startAudiobook(fromCurrent:true)}label:{Label("Play from this chapter",systemImage:"bookmark")}.disabled(chapters.isEmpty || (store.assistantToken == nil && !currentAudioReady(voice:voice)) || audiobook.preparingBook).accessibilityIdentifier("book-audiobook-current")
                    if let error=audiobook.preparationError,audiobook.voiceName==voice{Text(error).font(.caption).foregroundStyle(Design.muted)}
                    Text(ready==chapters.count && !chapters.isEmpty ? "Ready offline. Playback starts from the downloaded audio, without asking the AI again.":"\(ready) of \(chapters.count) chapters downloaded. Keep the book open while downloading. Progress updates within each chapter. Pause anytime; finished audio parts are reused when you resume.").font(.caption).foregroundStyle(Design.muted)
                    Text("Narrator: \(voice). Changing the voice or chapter text requires new audio for that selection.").font(.caption).foregroundStyle(Design.muted)
                }

            }.safeAreaInset(edge:.top){if let session=store.walkthrough{WalkthroughCoach(session:session)}}.navigationTitle("Contents").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){contents=false}}}}}
            .onAppear{
                if store.walkthrough?.kind == .downloads,audiobook.practiceCache == nil{audiobook.practiceCache=FileManager.default.temporaryDirectory.appendingPathComponent("GuideAudio-"+UUID().uuidString,isDirectory:true);audiobook.practiceAudio=Bundle.main.url(forResource:"new-additions-v2",withExtension:"m4a",subdirectory:"GuideAudio/Aoede")}
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-reset-test-audio"){audiobook.resetTestAudio()}
                if ProcessInfo.processInfo.arguments.contains("-test-reader-joined"){Task{try? await audiobook.seedJoinedTestAudio(chapters)}}
                #endif
                if !store.isPractice{bookVoice=UserDefaults.standard.string(forKey:"moshia-audiobook-voice") ?? "Aoede";textSize=UserDefaults.standard.object(forKey:"moshia-reader-size") as? Double ?? 20;paper=UserDefaults.standard.string(forKey:"moshia-reader-paper") ?? "linen"};store.walkthrough?.event("reader-open")}
            .onChange(of:textSize){_,value in if !store.isPractice{UserDefaults.standard.set(value,forKey:"moshia-reader-size")}}
            .onChange(of:paper){_,value in if !store.isPractice{UserDefaults.standard.set(value,forKey:"moshia-reader-paper")}}
            .onChange(of:page){old,new in if old != new{store.walkthrough?.event("reader-turned")};if !store.isPractice,pages.indices.contains(new){UserDefaults.standard.set(pages[new].chapterID+"|"+String(pages[new].offset),forKey:"moshia-reader-bookmark")}}
            .onDisappear{if !listening{audiobook.stop()}}
    }
    func currentAudioReady(voice:String)->Bool{guard pages.indices.contains(page),let chapter=chapters.first(where:{$0.id == pages[page].chapterID}) else{return false};return BookAudioDownload.isReady(audiobook.cacheURL(for:chapter,voice:voice))}
    func startAudiobook(fromCurrent:Bool){
        let selected=fromCurrent && pages.indices.contains(page) ? chapters.firstIndex(where:{$0.id == pages[page].chapterID}) ?? 0:0
        let voice=bookVoice
        store.walkthrough?.narrator.stop();store.walkthrough?.event("download-play",narrate:false);audiobook.start(chapters,at:selected,token:store.assistantToken,voice:voice);contents=false;listening=true
    }
    func turn(_ amount:Int){guard !pages.isEmpty else{return};withAnimation(reducedMotion ? nil:.easeInOut(duration:0.28)){page=min(max(0,page+amount),pages.count-1)}}
    func paginate(size:CGSize){
        let bookmark=pages.indices.contains(page) ? pages[page].chapterID+"|"+String(pages[page].offset):(store.isPractice ? nil:UserDefaults.standard.string(forKey:"moshia-reader-bookmark"))
        pages=chapters.flatMap{BookPagination.pages(chapter:$0,width:max(100,size.width-60),height:max(100,size.height-218),fontSize:textSize)}
        if let bookmark{let parts=bookmark.components(separatedBy:"|");let offset=Int(parts.last ?? "") ?? 0;page=pages.lastIndex(where:{$0.chapterID==parts.first && $0.offset<=offset}) ?? 0}else{page=0}
    }
}
struct ReaderPage {let chapterID:String;let chapter:String;let offset:Int;let text:String}
enum BookPagination {
    static func pages(chapter:EdizCore.Record,width:CGFloat,height:CGFloat,fontSize:CGFloat)->[ReaderPage]{
        let paragraph=NSMutableParagraphStyle();paragraph.lineSpacing=5
        let storage=NSTextStorage(string:chapter.body,attributes:[.font:UIFont.systemFont(ofSize:fontSize,weight:.regular).withDesign(.serif),.paragraphStyle:paragraph])
        let layout=NSLayoutManager();storage.addLayoutManager(layout)
        var result:[ReaderPage]=[];var last=0
        while last<storage.length{
            let container=NSTextContainer(size:CGSize(width:width,height:height));container.lineFragmentPadding=0;layout.addTextContainer(container)
            let range=layout.characterRange(forGlyphRange:layout.glyphRange(for:container),actualGlyphRange:nil)
            guard range.length>0 else{break}
            result.append(ReaderPage(chapterID:chapter.id,chapter:chapter.title,offset:range.location,text:(chapter.body as NSString).substring(with:range)));last=NSMaxRange(range)
        }
        return result
    }
}
private extension UIFont {func withDesign(_ design:UIFontDescriptor.SystemDesign)->UIFont{UIFont(descriptor:fontDescriptor.withDesign(design) ?? fontDescriptor,size:pointSize)}}

@MainActor enum BookAudioDownload {
    static func isReady(_ url:URL)->Bool{(try? AVAudioPlayer(contentsOf:url).duration).map{$0>0} ?? false}
    static func segment(_ text:String,token:String,voice:String,to destination:URL) async throws {
        let temporary=destination.deletingPathExtension().appendingPathExtension(UUID().uuidString+".partial.m4a")
        for attempt in 0...1 {
            try Task.checkCancellation();try? FileManager.default.removeItem(at:temporary)
            do{
                var file:AVAudioFile?=try AVAudioFile(forWriting:temporary,settings:[AVFormatIDKey:Int(kAudioFormatMPEG4AAC),AVSampleRateKey:24000,AVNumberOfChannelsKey:1,AVEncoderBitRateKey:48000],commonFormat:.pcmFormatFloat32,interleaved:false)
                var request=URLRequest(url:URL(string:"https://ediz-os.vercel.app/api/assistant")!);request.httpMethod="POST";request.timeoutInterval=110
                request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")
                request.httpBody=try JSONSerialization.data(withJSONObject:["mode":"speech-stream","text":text,"voice":voice,"speechModel":"live"])
                let (bytes,response)=try await URLSession.shared.bytes(for:request)
                guard let http=response as? HTTPURLResponse else{throw URLError(.badServerResponse)}
                guard http.statusCode==200 else{throw NSError(domain:"BookDownload",code:http.statusCode)}
                var done=false,total=0
                let format=AVAudioFormat(standardFormatWithSampleRate:24000,channels:1)!
                for try await line in bytes.lines {
                    try Task.checkCancellation();guard let data=line.data(using:.utf8),let packet=try JSONSerialization.jsonObject(with:data) as? [String:Any] else{continue}
                    if packet["error"] != nil{throw URLError(.networkConnectionLost)}
                    if let encoded=packet["audio"] as? String,let audio=Data(base64Encoded:encoded){
                        guard packet["rate"] as? Int==24000,!audio.isEmpty,audio.count%2==0,total+audio.count<=4000000,let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(audio.count/2)),let samples=buffer.floatChannelData?[0] else{throw URLError(.cannotDecodeContentData)}
                        total+=audio.count;buffer.frameLength=buffer.frameCapacity
                        audio.withUnsafeBytes{raw in for i in 0..<Int(buffer.frameLength){samples[i]=Float(Int16(littleEndian:raw.loadUnaligned(fromByteOffset:i*2,as:Int16.self)))/32768}}
                        try file?.write(from:buffer)
                    }
                    if packet["done"] as? Bool==true{done=true}
                }
                file=nil
                guard done,total>0,isReady(temporary) else{throw URLError(.networkConnectionLost)}
                try? FileManager.default.removeItem(at:destination);try FileManager.default.moveItem(at:temporary,to:destination)
                try? FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:destination.path);return
            }catch{
                try? FileManager.default.removeItem(at:temporary);try Task.checkCancellation()
                let issue=error as NSError
                if attempt==0,![400,401,403,422].contains(issue.code){try await Task.sleep(for:.seconds(1));continue}
                throw error
            }
        }
    }
    static func join(_ urls:[URL],to destination:URL) async throws {
        let composition=AVMutableComposition();guard let track=composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid) else{throw URLError(.cannotDecodeContentData)}
        var position=CMTime.zero
        for url in urls{
            try Task.checkCancellation();let asset=AVURLAsset(url:url)
            guard let source=try await asset.loadTracks(withMediaType:.audio).first else{throw URLError(.cannotDecodeContentData)}
            let duration=try await asset.load(.duration);try track.insertTimeRange(CMTimeRange(start:.zero,duration:duration),of:source,at:position);position=CMTimeAdd(position,duration)
        }
        let temporary=destination.deletingPathExtension().appendingPathExtension(UUID().uuidString+".joined.m4a");try? FileManager.default.removeItem(at:temporary)
        guard let export=AVAssetExportSession(asset:composition,presetName:AVAssetExportPresetAppleM4A) else{throw URLError(.cannotDecodeContentData)}
        export.outputURL=temporary;export.outputFileType = .m4a
        try await withTaskCancellationHandler(operation:{
            try await withCheckedThrowingContinuation{(continuation:CheckedContinuation<Void,Error>) in export.exportAsynchronously{if export.status == .completed{continuation.resume()}else{continuation.resume(throwing:export.error ?? URLError(.cannotDecodeContentData))}}}
        },onCancel:{export.cancelExport()})
        try Task.checkCancellation();guard isReady(temporary) else{throw URLError(.cannotDecodeContentData)}
        try? FileManager.default.removeItem(at:destination);try FileManager.default.moveItem(at:temporary,to:destination)
        try? FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:destination.path)
    }
}
