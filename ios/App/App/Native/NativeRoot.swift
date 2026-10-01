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
                    OSNavigation{NativeToday()}.tabItem{Label("Today",systemImage:"house.fill")}.tag(0)
                    NativeCaptureTab { selected=previous }.tabItem{Label("Capture",systemImage:"plus.circle.fill")}.tag(1)
                    OSNavigation{NativeSpaces()}.tabItem{Label("Spaces",systemImage:"square.stack.3d.up.fill")}.tag(2)
                    OSNavigation{NativeSearch()}.tabItem{Label("Search",systemImage:"magnifyingglass")}.tag(3)
                    OSNavigation{NativeAssistant()}.tabItem{Label("Assistant",systemImage:"text.bubble.fill")}.tag(4)
                }.tint(Design.accent)
                    .background(NativeTabScrubber(selection:$selected))
                    .onChange(of:selected){_,next in if next != 1 {previous=next} }
                    .sheet(item:$store.captureRequest){seed in Group { if seed.data["_creation"] == "1" { NativeCreation(seed:seed) } else { NativeCapture(seed:seed) } }.presentationDetents([.large]).presentationDragIndicator(.visible)}
                    .fullScreenCover(item:$store.focusRequest){NativeFocus(record:$0)}
                    .overlay(alignment:.bottom){if store.undoRecord != nil{HStack{Text("Completed").font(.subheadline);Spacer();Button("Undo"){store.undo()}.font(.subheadline.weight(.medium));Button{store.undoRecord=nil}label:{Image(systemName:"xmark").frame(width:30,height:36)}.accessibilityLabel("Dismiss completion")}.padding(.horizontal,16).background(.regularMaterial,in:RoundedRectangle(cornerRadius:12)).padding(.horizontal,20).padding(.bottom,80)}}
            } else {
                VStack(spacing:20){Text("Ediz OS").font(.title2.weight(.medium));Text("Your local data couldn’t be opened.").foregroundStyle(Design.muted);Button("Try again"){store.open()}.buttonStyle(ActionStyle())}.padding(24)
            }
        }.environmentObject(store).preferredColorScheme(.dark).background(Design.background)
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
    var upcoming:[EdizCore.Record]{store.records.filter{$0.kind == "event" || $0.kind == "rehearsal" || $0.kind == "exam"}.filter{$0.status != "done" && (Time.date($0.due).map{$0>=Date()} ?? false)}.sorted{($0.due ?? "")<($1.due ?? "")}}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:store.preferences.density == "compact" ? 13:20) {
                HStack(alignment:.center,spacing:18){VStack(alignment:.leading,spacing:6){Text(greeting+", Ediz.").font(Design.font(14,weight:"Regular")).foregroundStyle(Design.muted);Text("Today.").font(Design.font(34,weight:"Medium",relativeTo:.largeTitle)).foregroundStyle(Design.glassLettering);if store.preferences.focus != "all"{Button("Focused on "+Catalog.space(store.preferences.focus).name){choosingFocus=true}.font(.caption).foregroundStyle(Design.muted)}};Spacer();VStack(spacing:3){Text(Date.now,format:.dateTime.weekday(.abbreviated)).font(.caption2);Text(Date.now,format:.dateTime.day()).font(Design.font(29,weight:"Regular"));Text(Date.now,format:.dateTime.month(.abbreviated)).font(.caption2)}.foregroundStyle(Design.muted).frame(width:64,height:80).background(Design.surface,in:RoundedRectangle(cornerRadius:22))}

                VStack(alignment:.leading,spacing:12) {
                    HStack{Text("What matters").font(Design.font(19,weight:"Medium",relativeTo:.headline));Spacer();GlassAction{Button{choosingFocus=true}label:{Image(systemName:"slider.horizontal.3").frame(width:44,height:44)}.accessibilityLabel("Change focus")}}
                    if store.priorities.isEmpty {
                        VStack(alignment:.leading,spacing:8){Text("Nothing pressing.").font(Design.font(23,relativeTo:.title2));Text("Capture a thought or bring in your existing work.").font(Design.font(15,weight:"Regular")).foregroundStyle(Design.muted)}.padding(.vertical,3)
                    } else {
                        Surface{VStack(alignment:.leading,spacing:8){ForEach(Array(store.priorities.prefix(4))){recommendation in RecordRow(record:recommendation.record)};Text(Priority.briefing(store.records,focus:store.preferences.focus)).font(Design.font(14,weight:"Regular")).foregroundStyle(Design.muted)}}
                    }
                    HStack(spacing:12){GlassAction{Button{store.capture()}label:{Label("Capture",systemImage:"plus").padding(.horizontal,8).frame(minHeight:44)}.accessibilityIdentifier("capture-from-today")};GlassAction{NavigationLink{NativeImport()}label:{Label("Import",systemImage:"square.and.arrow.down").padding(.horizontal,8).frame(minHeight:44)}}}.font(Design.font(15))
                }
                if let recent=store.recent { VStack(alignment:.leading,spacing:10){Text("Continue where you left off").font(Design.font(19,weight:"DemiBold"));Surface{RecordRow(record:recent)}} }
                if !upcoming.isEmpty { VStack(alignment:.leading,spacing:10){Text("Coming up").font(Design.font(19,weight:"DemiBold"));Surface{VStack{ForEach(Array(upcoming.prefix(3))){RecordRow(record:$0)}}}} }
                VStack(alignment:.leading,spacing:12){Text("Your spaces").font(Design.font(19,weight:"DemiBold",relativeTo:.headline));Surface{VStack(spacing:store.preferences.density == "compact" ? 2:8){ForEach(Catalog.spaces.sorted{($0.id == store.preferences.focus ? 0:1)<($1.id == store.preferences.focus ? 0:1)}){space in NativeSpaceShortcut(space:space)}}}}
                HStack(spacing:12){GlassAction{Button{weekly=false;review=true}label:{Label("Review today",systemImage:"checkmark.circle").frame(maxWidth:.infinity,minHeight:48)}};GlassAction{Button{weekly=true;review=true}label:{Image(systemName:"calendar").frame(minWidth:44,minHeight:48)}.accessibilityLabel("Review this week")}}.font(Design.font(15))
            }.padding(.horizontal,20).padding(.top,8).padding(.bottom,26)
        }.background(Design.background).navigationTitle("Ediz OS").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented:$choosingFocus){NativeFocusChoice().presentationDragIndicator(.visible)}
            .sheet(isPresented:$review){NativeReview(weekly:weekly).presentationDragIndicator(.visible)}
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
    var body:some View {
        ScrollView { VStack(alignment:.leading,spacing:14) {
            Text("Five spaces. A place for everything.").font(Design.font(15,weight:"Regular")).foregroundStyle(Design.muted).padding(.bottom,4)
            ForEach(Catalog.spaces){space in
                VStack(alignment:.leading,spacing:16){NavigationLink(value:SpaceRoute(id:space.id)){HStack(spacing:12){SpaceMark(space:space);VStack(alignment:.leading,spacing:4){Text(space.name).font(Design.font(19,weight:"DemiBold"));Text(space.summary).font(Design.font(13,weight:"Regular")).foregroundStyle(Design.muted)};Spacer()}}.buttonStyle(.plain)
                    HStack(spacing:8){ForEach(Catalog.quickModules(for:space.id)){module in GlassAction{NavigationLink(value:SpaceRoute(id:space.id,kind:module.kind)){Text(module.label).font(Design.font(13)).frame(maxWidth:.infinity,minHeight:44)}}}}
                }.padding(17).background(Design.surface,in:RoundedRectangle(cornerRadius:24))
            }
        }.padding(20) }.background(Design.background).navigationTitle("Spaces")
    }
}
struct NativeSearch:View {
    @EnvironmentObject var store:NativeStore
    @State private var query=""
    @State private var space="all"
    var results:[EdizCore.Record]{SearchIndex.find(store.records,query:query).filter{space == "all" || $0.space == space}}
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
