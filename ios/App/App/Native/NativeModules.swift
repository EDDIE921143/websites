import SwiftUI
import EdizCore

struct NativeSpace:View {
    @EnvironmentObject var store:NativeStore
    let route:SpaceRoute
    @State private var kind=""
    @State private var filter="all"
    @State private var rehearsal=false
    var space:SpaceDefinition{Catalog.space(route.id)}
    var creationNoun:String {kind == "thread" ? "plot thread":kind == "assignment" ? "homework":kind == "note" && route.id == "moshia" ? "research":kind}
    var records:[EdizCore.Record]{store.records.filter{$0.space == route.id && $0.kind == kind && (filter == "all" || $0.status == filter)}.sorted{$0.updated>$1.updated}}
    var songs:[EdizCore.Record]{store.records.filter{$0.space == "band" && $0.kind == "song" && $0.status != "archived"}.sorted{$0.created<$1.created}}
    var body:some View {
        List {
            Section {
                Picker("Area",selection:$kind){ForEach(space.modules){Text($0.label).tag($0.kind)}}
                if kind == "lead"{Picker("Pipeline",selection:$filter){Text("All leads").tag("all");ForEach(Catalog.states(kind:"lead",space:"ejj"),id:\.self){Text($0).tag($0)}}}
                if route.id == "moshia"{Picker("Story state",selection:$filter){Text("All states").tag("all");ForEach(Catalog.states(kind:kind,space:"moshia"),id:\.self){Text($0).tag($0)}}}
            }
            if kind == "lead" {
                Section("Pipeline"){
                    let leads=store.records.filter{$0.space == "ejj" && $0.kind == "lead"}
                    HStack{metric("Leads",leads.filter{$0.status != "Client" && $0.status != "Lost"}.count);Spacer();metric("Interested",leads.filter{$0.status == "Interested"}.count);Spacer();metric("Clients",leads.filter{$0.status == "Client"}.count)}
                }
            }
            if route.id == "band" && kind == "song"{Section{Button("Rehearsal mode"){rehearsal=true};if let next=store.records.filter({$0.kind == "rehearsal" && Time.date($0.due).map{$0>Date()} == true}).sorted(by:{($0.due ?? "")<($1.due ?? "")}).first{RecordRow(record:next)}}}
            if route.id == "school" && kind == "grade"{NativeGradeProjection()}
            if route.id == "school" && ["assignment","exam"].contains(kind){NativeWorkload()}
            Section(space.modules.first{$0.kind == kind}?.label ?? "Records") {
                if records.isEmpty{QuietEmpty(title:"Ready for your \(kind == "assignment" ? "homework":kind == "lead" ? "leads":kind == "chapter" ? "chapters":"work").",message:"Add your own material or bring in an existing file.");Button("Add \(creationNoun)"){store.capture(space:route.id,kind:kind)}}
                ForEach(records){record in
                    VStack(alignment:.leading,spacing:7){RecordRow(record:record)
                        if route.id == "moshia"{Text(record.status).font(.caption.weight(.medium)).foregroundStyle(Design.color(space.color))}
                        if record.kind == "song"{Text([record.data["artist"],record.data["BPM"].map{"\($0) BPM"},record.data["tuning"],record.status].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:" · ")).font(.subheadline).foregroundStyle(Design.muted)}
                        if record.kind == "chapter"{Text([record.data["POV"],record.data["wordCount"].map{"\($0) words"},record.data["location"]].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:" · ")).font(.subheadline).foregroundStyle(Design.muted)}
                    }.listRowSeparator(.hidden).swipeActions(edge:.trailing,allowsFullSwipe:true){if record.actionable{Button{store.complete(record)}label:{Label("Done",systemImage:"checkmark")}.tint(.green)}}
                }
            }
            if route.id == "moshia" && kind == "event"{NativeTimeline()}
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Design.background).navigationTitle(space.name).navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.topBarLeading){Button{store.capture(space:route.id,kind:kind)}label:{Label("Add \(creationNoun)",systemImage:"plus")}.disabled(kind.isEmpty).accessibilityIdentifier("module-add")}}
            .onAppear{if kind.isEmpty{kind=route.kind ?? space.modules[0].kind}}
            .onChange(of:kind){_,_ in filter="all"}
            .fullScreenCover(isPresented:$rehearsal){NativeRehearsal(songs:songs)}
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
        }.onAppear{if subject.isEmpty{subject=subjects.first ?? ""}}
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
            }.background(Design.background).navigationTitle("Focus").navigationBarTitleDisplayMode(.inline)
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
        }.scrollContentBackground(.hidden).background(Design.background).navigationTitle(weekly ? "This week":"Today’s review").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}}
    }
}
