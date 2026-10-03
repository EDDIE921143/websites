import SwiftUI
import EdizCore

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
            if kind == "lead" {
                Section("Pipeline"){
                    let leads=store.records.filter{$0.space == "ejj" && $0.kind == "lead"}
                    HStack{metric("Leads",leads.filter{$0.status != "Client" && $0.status != "Lost"}.count);Spacer();metric("Interested",leads.filter{$0.status == "Interested"}.count);Spacer();metric("Clients",leads.filter{$0.status == "Client"}.count)}
                }
            }
            if route.id == "band" && kind == "song"{Section("Rehearsal desk"){HStack{metric("Setlist",songs.count);Spacer();metric("Ready",songs.filter{$0.status == "Ready"}.count);Spacer();metric("Learning",songs.filter{$0.status == "Learning"}.count)};Button{rehearsal=true}label:{Label("Rehearsal mode",systemImage:"play.circle.fill").font(.headline).frame(minHeight:44)};if let next=store.records.filter({$0.kind == "rehearsal" && Time.date($0.due).map{$0>Date()} == true}).sorted(by:{($0.due ?? "")<($1.due ?? "")}).first{RecordRow(record:next)}}}
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
            .toolbar{ToolbarItem(placement:.topBarTrailing){NavigationLink{NativeChatHistory(scope:route.id)}label:{Image(systemName:"bubble.left.and.bubble.right")}.accessibilityLabel("Chats").accessibilityIdentifier("space-chats")};ToolbarItem(placement:.topBarLeading){Button{store.capture(space:route.id,kind:kind)}label:{Label("Add \(creationNoun)",systemImage:"plus")}.disabled(kind.isEmpty).accessibilityIdentifier("module-add").walkthroughTarget("add-chapter",session:store.walkthrough)}}
            .onAppear{if kind.isEmpty{kind=route.kind ?? space.modules[0].kind};if route.id == "moshia" && kind == "chapter"{store.walkthrough?.event("chapters-open")}}
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
                        VStack(spacing:10){Text("\(elapsed/60):\(String(format:"%02d",elapsed%60))").font(Design.font(38,weight:"Regular",relativeTo:.largeTitle)).monospacedDigit();Text("Time with your work").font(Design.font(12,weight:"Regular")).foregroundStyle(Design.muted)}
                            .frame(width:208,height:208).background(Design.surface,in:Circle()).shadow(color:.black.opacity(0.2),radius:25,y:12).padding(.vertical,10)
                    }
                    if let minutes=record.duration{Text("You allowed about \(minutes) minutes. There’s no countdown.").font(Design.font(14,weight:"Regular")).foregroundStyle(Design.muted).multilineTextAlignment(.center)}
                    if !record.body.isEmpty{Surface{VStack(alignment:.leading,spacing:10){Text("Keep in mind").font(Design.font(16));Text(record.body).font(Design.font(15,weight:"Regular")).lineSpacing(4).textSelection(.enabled)}}}
                    Group{
                    HStack(spacing:12){
                        GlassAction{Button(started == nil ? (begun ? "Continue":"Begin"):"Pause"){toggle()}.font(Design.font(16)).frame(maxWidth:.infinity,minHeight:48)}
                        GlassAction{Button("Finish"){store.complete(record);dismiss()}.font(Design.font(14)).foregroundStyle(Design.muted).frame(maxWidth:.infinity,minHeight:48)}.opacity(begun ? 1:0).disabled(!begun).accessibilityHidden(!begun)
                    }.padding(.top,4)
                }
                }.frame(maxWidth:.infinity).padding(24)
            }.background(AppBackdrop()).navigationTitle("Focus").navigationBarTitleDisplayMode(.inline)
                .toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}
        }.preferredColorScheme(.dark).tint(Design.accent)
    }
    func toggle(){if let start=started{accumulated += Date().timeIntervalSince(start);started=nil}else{started=Date()}}
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
