import SwiftUI
import EdizCore

struct NativeRoot:View {
    @StateObject private var store=NativeStore()
    @State private var selected=0
    @State private var previous=0
    var body:some View {
        Group {
            if store.ready {
                TabView(selection:$selected) {
                    OSNavigation{NativeToday()}.tabItem{Label("Today",systemImage:"house")}.tag(0)
                    OSNavigation{NativeSpaces()}.tabItem{Label("Spaces",systemImage:"square.grid.2x2")}.tag(1)
                    Color.clear.tabItem{Label("Capture",systemImage:"plus.app")}.tag(2)
                    OSNavigation{NativeSearch()}.tabItem{Label("Search",systemImage:"magnifyingglass")}.tag(3)
                    OSNavigation{NativeAssistant()}.tabItem{Label("Assistant",systemImage:"text.bubble")}.tag(4)
                }.tint(Design.accent)
                    .onChange(of:selected){_,next in if next == 2 { selected=previous;store.capture() }else{previous=next} }
                    .sheet(item:$store.captureRequest){NativeCapture(seed:$0).presentationDetents([.large]).presentationDragIndicator(.visible)}
                    .fullScreenCover(item:$store.focusRequest){NativeFocus(record:$0)}
                    .overlay(alignment:.bottom){if store.undoRecord != nil{HStack{Text("Completed").font(.subheadline);Spacer();Button("Undo"){store.undo()}.font(.subheadline.weight(.medium));Button{store.undoRecord=nil}label:{Image(systemName:"xmark").frame(width:30,height:36)}.accessibilityLabel("Dismiss completion")}.padding(.horizontal,16).background(.regularMaterial,in:RoundedRectangle(cornerRadius:12)).padding(.horizontal,20).padding(.bottom,80)}}
            } else {
                VStack(spacing:20){Text("Ediz OS").font(.title2.weight(.medium));Text("Your local data couldn’t be opened.").foregroundStyle(Design.muted);Button("Try again"){store.open()}.buttonStyle(ActionStyle())}.padding(24)
            }
        }.environmentObject(store).preferredColorScheme(.dark).background(Design.background)
            .alert("Ediz OS",isPresented:Binding(get:{store.error != nil},set:{if !$0{store.error=nil}})){Button("OK"){store.error=nil}}message:{Text(store.error ?? "")}
    }
}
struct NativeToday:View {
    @EnvironmentObject var store:NativeStore
    @State private var review=false
    @State private var weekly=false
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                HStack(alignment:.firstTextBaseline){Text("Today").font(.largeTitle.weight(.medium));Spacer();Text(Date.now,format:.dateTime.weekday(.abbreviated).day().month(.abbreviated)).font(.subheadline).foregroundStyle(Design.muted)}
                Surface {
                    VStack(alignment:.leading,spacing:15) {
                        HStack{Text("Next up").font(.title3.weight(.medium));Spacer();NavigationLink { NativeSettings() }label:{Image(systemName:"line.3.horizontal.decrease").foregroundStyle(Design.muted).frame(width:44,height:32)}.accessibilityLabel("Change focus")}
                        if store.priorities.isEmpty {
                            Text("Nothing scheduled yet.").font(.body).foregroundStyle(Design.muted)
                            Text("Capture a task or import your existing work.").font(.subheadline).foregroundStyle(Design.muted)
                            HStack(spacing:10){Button{store.capture()}label:{Label("Capture",systemImage:"plus")}.buttonStyle(ActionStyle(primary:true));NavigationLink { NativeImport() }label:{Label("Import",systemImage:"square.and.arrow.down")}.buttonStyle(ActionStyle())}
                        } else {
                            ForEach(Array(store.priorities.prefix(4))){recommendation in RecordRow(record:recommendation.record)}
                            Text(Priority.briefing(store.records,focus:store.preferences.focus)).font(.subheadline).foregroundStyle(Design.muted)
                        }
                    }
                }
                VStack(alignment:.leading,spacing:12) {
                    HStack{Text("Spaces").font(.title3.weight(.medium));Spacer();NavigationLink("All spaces",destination:NativeSpaces()).font(.subheadline)}
                    LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10){ForEach([Catalog.spaces[0],Catalog.spaces[3],Catalog.spaces[1],Catalog.spaces[4]]){space in destination(space)}}
                    destination(Catalog.spaces[2])
                }
                if let recent=store.recent {
                    Surface{VStack(alignment:.leading,spacing:8){Text("Continue").font(.subheadline).foregroundStyle(Design.muted);RecordRow(record:recent)}}
                }
                let upcoming=store.records.filter{$0.kind == "event" || $0.kind == "rehearsal"}.filter{Time.date($0.due).map{$0>=Date()} ?? false}.sorted{($0.due ?? "")<($1.due ?? "")}
                if !upcoming.isEmpty { Surface{VStack(alignment:.leading,spacing:8){Text("Coming up").font(.title3.weight(.medium));ForEach(Array(upcoming.prefix(3))){RecordRow(record:$0)}}} }
                VStack(alignment:.leading,spacing:12){Text("Review").font(.title3.weight(.medium));HStack(spacing:10){Button{weekly=false;review=true}label:{Label("Today",systemImage:"checkmark.circle")}.buttonStyle(ActionStyle());Button{weekly=true;review=true}label:{Label("This week",systemImage:"calendar")}.buttonStyle(ActionStyle())}}
            }.padding(20)
        }.background(Design.background).navigationTitle("Ediz OS").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented:$review){NativeReview(weekly:weekly).presentationDragIndicator(.visible)}
    }
    func destination(_ space:SpaceDefinition)->some View {
        NavigationLink(value:SpaceRoute(id:space.id)){
            VStack(alignment:.leading,spacing:11){HStack{SpaceMark(space:space);Spacer();Image(systemName:"arrow.up.right").font(.caption).foregroundStyle(Design.color(space.color))};Text(space.name).font(.subheadline.weight(.medium)).foregroundStyle(Design.ink);Text(space.summary).font(.caption).foregroundStyle(Design.muted)}.frame(maxWidth:.infinity,alignment:.leading).padding(15).background(Design.color(space.color).opacity(0.11),in:RoundedRectangle(cornerRadius:12))
        }.buttonStyle(.plain)
    }
}
struct NativeSpaces:View {
    var body:some View {
        ScrollView { VStack(alignment:.leading,spacing:12) {
            Text("Your work, in context.").font(.subheadline).foregroundStyle(Design.muted).padding(.bottom,8)
            ForEach(Catalog.spaces){space in
                VStack(alignment:.leading,spacing:13){NavigationLink(value:SpaceRoute(id:space.id)){HStack{SpaceMark(space:space);Text(space.name).font(.headline.weight(.medium));Spacer();Image(systemName:"arrow.right").font(.subheadline).foregroundStyle(Design.muted)}}.buttonStyle(.plain)
                    HStack(spacing:7){ForEach(Catalog.quickModules(for:space.id)){module in NavigationLink(value:SpaceRoute(id:space.id,kind:module.kind)){Text(module.label).font(.caption.weight(.medium)).frame(maxWidth:.infinity).frame(minHeight:44).background(Design.raised.opacity(0.7),in:RoundedRectangle(cornerRadius:9))}.buttonStyle(.plain)}}
                }.padding(15).background(Design.color(space.color).opacity(0.10),in:RoundedRectangle(cornerRadius:13))
            }
        }.padding(20) }.background(Design.background).navigationTitle("Spaces")
    }
}
struct NativeSearch:View {
    @EnvironmentObject var store:NativeStore
    @State private var query=""
    @State private var space="all"
    var results:[Record]{SearchIndex.find(store.records,query:query).filter{space == "all" || $0.space == space}}
    var body:some View {
        List {
            Section { Picker("Space",selection:$space){Text("Everything").tag("all");ForEach(Catalog.spaces){Text($0.name).tag($0.id)}} }
            Section(query.isEmpty ? "Recent":"Results") {
                if results.isEmpty{QuietEmpty(title:query.isEmpty ? "Your work will appear here.":"No matches yet.",message:query.isEmpty ? "Capture or import something to make it searchable.":"Try a shorter name or a different space.")}
                ForEach(Array(results.prefix(100))){RecordRow(record:$0)}
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Design.background).navigationTitle("Search").searchable(text:$query,prompt:"A person, a project, Friday…")
    }
}
