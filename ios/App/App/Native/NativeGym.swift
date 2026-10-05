import SwiftUI
import Combine
import EdizCore
import UserNotifications
import AudioToolbox

final class GymNotificationDelegate:NSObject,UNUserNotificationCenterDelegate {
    static let shared=GymNotificationDelegate()
    func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping (UNNotificationPresentationOptions)->Void){completionHandler([.banner,.sound])}
}
@MainActor final class GymStore:ObservableObject {
    @Published var state=GymState()
    @Published var catalog:[GymExercise]=[]
    @Published var message:String?
    weak var owner:NativeStore?
    var exercises:[GymExercise]{catalog+state.custom}
    func load(_ store:NativeStore){guard owner == nil else{return};owner=store;UNUserNotificationCenter.current().delegate=GymNotificationDelegate.shared
        if let text=store.preferences.assistantChats["gym-state"],let data=text.data(using:.utf8),let saved=try? JSONDecoder().decode(GymState.self,from:data){state=saved}
        if let url=Bundle.main.url(forResource:"exercises",withExtension:"json",subdirectory:"GymResources"),let data=try? Data(contentsOf:url){catalog=(try? JSONDecoder().decode([GymExercise].self,from:data)) ?? []}
        if store.preferences.assistantChats["gym-state"] == nil {
            let plan=[["lever-chest-press","lever-seated-fly","lever-shoulder-press","lever-lateral-raise","lever-seated-dip","extra-decline-situp"],["lever-seated-row","bar-lat-pulldown","lever-reverse-fly","extra-decline-situp","shrugs","lever-preacher-curl"],[],["lever-seated-leg-curl","seated-leg-press","seated-hip-adduction","leg-extension","seated-calf-raise","hyperextensions"],["tricep-dips","preacher-curl","tricep-extend","overhead-tricep-extension","hammer-curl","cable-pushdown","dumbbell-incline","one-arm-wrist-curl","one-arm-reverse-wrist-curl"],[],[]]
            let titles=["Day 1 · Chest & shoulders","Day 2 · Back & biceps","Recovery","Day 3 · Legs","Day 4 · Arms & forearms","Optional cardio","Recovery"]
            for index in plan.indices{state.days[index].title=titles[index];state.days[index].exercises=plan[index].map{GymPlanExercise($0)}}
            save()
        }
    }
    func exercise(_ id:String)->GymExercise{exercises.first{$0.id == id} ?? GymExercise(id:id,name:"Unavailable exercise",instructions:["Replace this exercise from the library."])}
    func save(){guard let owner else{return};do{let data=try JSONEncoder().encode(state);var prefs=owner.preferences;prefs.assistantChats["gym-state"]=String(decoding:data,as:UTF8.self);owner.setPreferences(prefs)}catch{message="The workout couldn’t be saved. Please keep this screen open."}}
    func start(_ day:GymDay){guard state.active == nil else{return};state.active=GymWorkout(day);save()}
    func startRest(_ seconds:Int){state.active?.restEnds=Date().addingTimeInterval(Double(seconds));save();UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:["ediz-gym-rest"])
        if state.alerts{let content=UNMutableNotificationContent();content.title="Ready for your next set";content.body="Your rest timer has finished.";content.sound = .default;let request=UNNotificationRequest(identifier:"ediz-gym-rest",content:content,trigger:UNTimeIntervalNotificationTrigger(timeInterval:Double(max(1,seconds)),repeats:false));UNUserNotificationCenter.current().add(request){_ in}}
    }
    func finish()->GymWorkout?{let completed=state.active;state.finish();save();UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:["ediz-gym-rest"]);return completed.map{var item=$0;item.ended=Date();return item}}
    func tick(){if let ends=state.active?.restEnds,ends<=Date(){state.active?.restEnds=nil;save();if Date().timeIntervalSince(ends)<5 && !state.alerts{AudioServicesPlaySystemSound(1007);UINotificationFeedbackGenerator().notificationOccurred(.success)}}}
    func enableAlerts() async {do{state.alerts=try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound]);if !state.alerts{message="Rest alerts are off. You can allow notifications in iPhone Settings."};save()}catch{message="Rest alerts couldn’t be enabled."}}
    var context:EdizCore.Record{var r=EdizCore.Record(space:"gym",kind:"note",title:"Ediz’s gym plan and training history");r.body=state.days.enumerated().map{index,day in "Day \(index+1): \(day.title): "+day.exercises.map{exercise($0.exerciseID).name+" — \($0.sets) sets; \($0.target); rest \($0.rest)s"}.joined(separator:", ")}.joined(separator:"\n");r.body += "\nRecent completed workouts:\n"+state.history.prefix(8).map{workout in "\(workout.title): \(workout.completedSets) completed sets, \(Int(workout.volume)) kg volume. "+workout.exercises.map{item in exercise(item.exerciseID).name+": "+item.sets.filter(\.done).map{set in set.minutes>0 ? "\(set.minutes) min, \(set.distance) km":"\(set.kg) kg × \(set.reps)"}.joined(separator:"; ")}.joined(separator:". ")}.joined(separator:"\n");return r}
}
extension NativeStore {
    var gymContext:[EdizCore.Record]{let gym=GymStore();gym.load(self);return [gym.context]}
}
struct GymLibraryRequest:Identifiable {let id=UUID();var dayID:UUID?=nil}
struct NativeGym:View {
    @EnvironmentObject var store:NativeStore
    @StateObject private var gym=GymStore()
    @State private var section="week"
    @State private var editing:GymDay?
    @State private var library:GymLibraryRequest?
    @State private var settings=false
    @State private var summary:GymWorkout?
    @State private var expanded:Set<UUID>=[]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let timer=Timer.publish(every:1,on:.main,in:.common).autoconnect()
    var accent:Color{WorkspaceTheme.accent("gym")}
    var body:some View {
        ScrollView{VStack(alignment:.leading,spacing:22){
            if let workout=gym.state.active{workoutHeader(workout);workoutCards(workout)}else{
                VStack(alignment:.leading,spacing:9){Text("Build a little stronger.").font(.largeTitle.weight(.semibold));Text("Your week, your pace. Adjust the plan to fit you.").foregroundStyle(Design.muted)}.padding(.top,8)
                NavigationLink{NativeConversationHost(scope:"gym")}label:{HStack{Image(systemName:"sparkles");VStack(alignment:.leading,spacing:3){Text("Gym assistant").font(.headline);Text("Talk through your plan and progress").font(.caption).foregroundStyle(Design.muted)};Spacer();Image(systemName:"chevron.right")}.padding(16).background(accent.opacity(0.12),in:RoundedRectangle(cornerRadius:18))}.buttonStyle(.plain).accessibilityIdentifier("gym-assistant")
                Picker("Gym view",selection:$section){Text("Week").tag("week");Text("History").tag("history")}.pickerStyle(.segmented)
                if section == "week"{week}else{history}
            }
            if let message=gym.message{Text(message).font(.footnote).foregroundStyle(Design.muted)}
        }.padding(20)}.scrollDismissesKeyboard(.interactively).background(AppBackdrop(scope:"gym")).navigationTitle("Gym").navigationBarTitleDisplayMode(.inline).tint(accent)
            .toolbar{ToolbarItemGroup(placement:.topBarTrailing){if gym.state.active != nil{Button("Finish"){summary=gym.finish()}.fontWeight(.semibold).accessibilityIdentifier("gym-finish")}else{Button{library=GymLibraryRequest()}label:{Image(systemName:"books.vertical")}.accessibilityLabel("Exercise library");Button{settings=true}label:{Image(systemName:"gearshape")}.accessibilityLabel("Gym settings")}}}
            .toolbar(gym.state.active == nil ? .visible:.hidden,for:.tabBar)
            .sheet(item:$editing){day in GymDayEditor(gym:gym,dayID:day.id)}
            .sheet(item:$library){request in GymLibrary(gym:gym,dayID:request.dayID)}
            .sheet(isPresented:$settings){GymGuide(gym:gym)}
            .sheet(item:$summary){workout in GymSummary(workout:workout,gym:gym)}
            .onAppear{gym.load(store)}.onReceive(timer){_ in gym.tick()}
    }
    var week:some View {VStack(spacing:12){ForEach(Array(gym.state.days.enumerated()),id:\.element.id){index,day in
        VStack(alignment:.leading,spacing:14){HStack(alignment:.top){Text(["MON","TUE","WED","THU","FRI","SAT","SUN"][index]).font(.caption.weight(.semibold)).foregroundStyle(accent).frame(width:42,alignment:.leading).padding(.top,3);VStack(alignment:.leading,spacing:5){Text(day.title).font(.headline);Text(day.exercises.isEmpty ? "Recovery day · or add your own exercises":"\(day.exercises.count) exercises · "+day.exercises.reduce(into:[String]()){groups,item in for muscle in gym.exercise(item.exerciseID).primaryMuscles where !groups.contains(muscle){groups.append(muscle)}}.prefix(3).joined(separator:" / ")).font(.caption).foregroundStyle(Design.muted)};Spacer();Button{editing=day}label:{Image(systemName:"slider.horizontal.3").frame(width:44,height:44)}.accessibilityLabel("Edit "+day.title)}
            if !day.exercises.isEmpty{Text(day.exercises.map{gym.exercise($0.exerciseID).name}.joined(separator:" · ")).font(.subheadline).foregroundStyle(Design.muted).lineLimit(3);Button{gym.start(day);expanded=Set(gym.state.active?.exercises.prefix(1).map(\.id) ?? [])}label:{Label("Start workout",systemImage:"play.fill").foregroundStyle(WorkspaceTheme.base("gym")).frame(maxWidth:.infinity,minHeight:44)}.buttonStyle(.borderedProminent).accessibilityIdentifier("gym-start-\(index)")}
            Button{library=GymLibraryRequest(dayID:day.id)}label:{Label("Add exercise",systemImage:"plus").font(.subheadline).frame(maxWidth:.infinity,minHeight:44)}.buttonStyle(.bordered).accessibilityIdentifier("gym-add-day-\(index)")
        }.padding(17).background(Design.surface,in:RoundedRectangle(cornerRadius:20))
    };Button{library=GymLibraryRequest()}label:{Label("Explore \(gym.exercises.count) exercises",systemImage:"magnifyingglass").frame(maxWidth:.infinity,minHeight:48)}.buttonStyle(.bordered)}}
    var history:some View {VStack(alignment:.leading,spacing:14){if gym.state.history.isEmpty{QuietEmpty(title:"Your progress starts here.",message:"Finish a workout to see your sets, volume and time.")};ForEach(gym.state.history){workout in Button{summary=workout}label:{HStack{VStack(alignment:.leading,spacing:6){Text(workout.title).font(.headline);Text(workout.started.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(Design.muted)};Spacer();VStack(alignment:.trailing,spacing:6){Text("\(Int(workout.volume)) kg").font(.headline);Text("\(workout.completedSets) sets").font(.caption)}}.padding(18).background(Design.surface,in:RoundedRectangle(cornerRadius:18))}.buttonStyle(.plain)}}}
    func workoutHeader(_ workout:GymWorkout)->some View {VStack(alignment:.leading,spacing:16){HStack(alignment:.top){Text(workout.title).font(.title.weight(.semibold));Spacer();NavigationLink{NativeConversationHost(scope:"gym")}label:{Image(systemName:"sparkles").frame(width:44,height:44).background(WorkspaceTheme.accent("gym").opacity(0.12),in:Circle())}.accessibilityLabel("Ask Gym assistant")};TimelineView(.periodic(from:.now,by:1)){context in HStack(spacing:26){metric("TIME",duration(workout.elapsed(at:context.date)));metric("VOLUME","\(Int(workout.volume)) kg");metric("SETS","\(workout.completedSets)")}};if workout.restEnds != nil{HStack{Image(systemName:"timer");TimelineView(.periodic(from:.now,by:1)){context in Text("Rest · \(workout.restRemaining(at:context.date))s").monospacedDigit()};Spacer();Button("+15s"){gym.startRest(workout.restRemaining(at:Date())+15)};Button("Skip"){gym.state.active?.restEnds=nil;gym.save();UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:["ediz-gym-rest"])}}.font(.subheadline).padding(14).background(accent.opacity(0.16),in:RoundedRectangle(cornerRadius:16))}}}
    func metric(_ label:String,_ value:String)->some View {VStack(alignment:.leading,spacing:5){Text(label).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(Design.muted);Text(value).font(.title3.weight(.semibold)).monospacedDigit()}}
    func duration(_ seconds:Double)->String{String(format:"%02d:%02d",Int(seconds)/60,Int(seconds)%60)}
    func workoutCards(_ workout:GymWorkout)->some View {VStack(spacing:14){ForEach(Array(workout.exercises.enumerated()),id:\.element.id){index,item in GymWorkoutCard(gym:gym,index:index,expanded:Binding(get:{expanded.contains(item.id)},set:{value in withAnimation(reduceMotion ? nil:.spring(response:0.28,dampingFraction:0.88)){if value{expanded.insert(item.id)}else{expanded.remove(item.id)}}}))};Button{library=GymLibraryRequest()}label:{Label("Add an exercise",systemImage:"plus").frame(maxWidth:.infinity,minHeight:48)}.buttonStyle(.bordered)}}
}
struct GymExerciseImage:View {
    let exercise:GymExercise
    var height:CGFloat=120
    @State private var frame=0
    var body:some View {
        Group{if !exercise.images.isEmpty,let url=URL(string:"https://raw.githubusercontent.com/yuhonas/free-exercise-db/f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5/exercises/"+exercise.images[min(frame,exercise.images.count-1)]){AsyncImage(url:url){image in image.resizable().scaledToFit()}placeholder:{placeholder}}else{placeholder}}
            .frame(maxWidth:.infinity).frame(height:height).background(Color.white.opacity(0.06),in:RoundedRectangle(cornerRadius:14)).clipShape(RoundedRectangle(cornerRadius:14))
            .onTapGesture{if exercise.images.count>1{frame=(frame+1)%exercise.images.count}}.accessibilityLabel(exercise.name+" reference image. Tap to change demonstration frame.")
    }
    var placeholder:some View {VStack(spacing:8){Image(systemName:exercise.isCardio ? "figure.run":"dumbbell").font(.largeTitle);Text(exercise.primaryMuscles.joined(separator:", ")).font(.caption).foregroundStyle(Design.muted)}}
}
struct GymWorkoutCard:View {
    @ObservedObject var gym:GymStore
    let index:Int
    @Binding var expanded:Bool
    @State private var instructions=false
    var item:GymWorkoutExercise?{guard let active=gym.state.active,active.exercises.indices.contains(index) else{return nil};return active.exercises[index]}
    var body:some View {if let item{let exercise=gym.exercise(item.exerciseID);VStack(alignment:.leading,spacing:16){
        Button{expanded.toggle()}label:{HStack(spacing:12){Image(systemName:exercise.isCardio ? "figure.run":"dumbbell.fill").foregroundStyle(WorkspaceTheme.accent("gym")).frame(width:38,height:38).background(WorkspaceTheme.accent("gym").opacity(0.12),in:RoundedRectangle(cornerRadius:10));VStack(alignment:.leading,spacing:5){Text(exercise.name).font(.headline).multilineTextAlignment(.leading);Text("\(item.sets.filter(\.done).count)/\(item.sets.count) sets"+(item.superset.isEmpty ? "":" · Superset "+item.superset)).font(.caption).foregroundStyle(Design.muted)};Spacer();Image(systemName:expanded ? "chevron.up":"chevron.down").font(.caption)}}.buttonStyle(.plain).accessibilityIdentifier("gym-exercise-\(index)")
        if expanded{GymExerciseImage(exercise:exercise,height:130);Button{instructions.toggle()}label:{Label(instructions ? "Hide technique":"Technique & instructions",systemImage:"info.circle")}.font(.subheadline);if instructions{ForEach(Array(exercise.instructions.enumerated()),id:\.offset){offset,text in Text("\(offset+1). "+text).font(.subheadline).foregroundStyle(Design.muted)}}
            HStack{Text("PREVIOUS").frame(width:78,alignment:.leading);Text(exercise.isCardio ? "MIN / KM":"KG / REPS").frame(maxWidth:.infinity);Text("DONE").frame(width:44)}.font(.caption2.weight(.semibold)).foregroundStyle(Design.muted)
            ForEach(Array(item.sets.enumerated()),id:\.element.id){setIndex,set in setRow(exercise,item,setIndex,set)}
            HStack{Button{gym.state.active?.exercises[index].sets.append(GymSet());gym.save()}label:{Label("Add set",systemImage:"plus")};Spacer();Menu{ForEach([30,45,60,90,120,180],id:\.self){seconds in Button("\(seconds)s"){gym.state.active?.exercises[index].rest=seconds;gym.save()}}}label:{Label("Rest \(item.rest)s",systemImage:"timer")}}.font(.subheadline).frame(minHeight:44)
        }
    }.padding(16).background(Design.surface,in:RoundedRectangle(cornerRadius:20))}}
    func binding<T>(_ set:Int,_ key:WritableKeyPath<GymSet,T>,_ fallback:T)->Binding<T>{Binding(get:{guard let item,self.item != nil,item.sets.indices.contains(set) else{return fallback};return item.sets[set][keyPath:key]},set:{value in guard let item,self.item != nil,item.sets.indices.contains(set) else{return};gym.state.active?.exercises[index].sets[set][keyPath:key]=value;gym.save()})}
    func setRow(_ exercise:GymExercise,_ item:GymWorkoutExercise,_ setIndex:Int,_ set:GymSet)->some View {let previous=gym.state.previousSets(for:item.exerciseID);return HStack(spacing:8){VStack(alignment:.leading,spacing:4){Text("SET \(setIndex+1)").font(.caption2);Text(previous.indices.contains(setIndex) ? (exercise.isCardio ? "\(Int(previous[setIndex].minutes))m / \(previous[setIndex].distance.formatted())k":"\(previous[setIndex].kg.formatted()) × \(previous[setIndex].reps)"):"—").font(.caption).foregroundStyle(Design.muted)}.frame(width:78,alignment:.leading)
        if exercise.isCardio{GymNumberField(label:"Set \(setIndex+1) minutes",placeholder:"min",value:binding(setIndex,\.minutes,0));GymNumberField(label:"Set \(setIndex+1) distance",placeholder:"km",value:binding(setIndex,\.distance,0))}else{GymNumberField(label:"Set \(setIndex+1) weight",placeholder:"kg",value:binding(setIndex,\.kg,0));GymNumberField(label:"Set \(setIndex+1) reps",placeholder:"reps",value:Binding(get:{Double(gym.state.active?.exercises[index].sets[setIndex].reps ?? 0)},set:{gym.state.active?.exercises[index].sets[setIndex].reps=Int($0);gym.save()}),integer:true)}
        Button{UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),to:nil,from:nil,for:nil);gym.state.active?.exercises[index].sets[setIndex].kg=max(0,set.kg);gym.state.active?.exercises[index].sets[setIndex].reps=max(0,set.reps);gym.state.active?.exercises[index].sets[setIndex].minutes=max(0,set.minutes);gym.state.active?.exercises[index].sets[setIndex].distance=max(0,set.distance);gym.state.active?.exercises[index].sets[setIndex].done.toggle();gym.save();if !set.done{gym.startRest(item.rest);UIImpactFeedbackGenerator(style:.light).impactOccurred()}}label:{Image(systemName:set.done ? "checkmark.circle.fill":"circle").font(.title2).foregroundStyle(set.done ? WorkspaceTheme.accent("gym"):Design.muted).frame(width:44,height:44)}.accessibilityLabel(set.done ? "Unmark set \(setIndex+1)":"Complete set \(setIndex+1)")
    }.textFieldStyle(.roundedBorder).padding(.vertical,3)}
}
struct GymDayEditor:View {
    @ObservedObject var gym:GymStore
    let dayID:UUID
    @Environment(\.dismiss) private var dismiss
    @State private var library=false
    var index:Int?{gym.state.days.firstIndex{$0.id == dayID}}
    var body:some View {NavigationStack{Form{if let index{Section("Your training day"){TextField("Day name",text:Binding(get:{gym.state.days[index].title},set:{gym.state.days[index].title=$0;gym.save()}));Menu("Swap this workout with another day"){ForEach(Array(gym.state.days.enumerated()),id:\.element.id){offset,day in if day.id != dayID{Button(["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"][offset]+" · "+day.title){swapDay(offset)}}}}};Section("Exercises"){ForEach(Array(gym.state.days[index].exercises.enumerated()),id:\.element.id){offset,item in VStack(alignment:.leading,spacing:12){Text(gym.exercise(item.exerciseID).name).font(.headline);Stepper("\(item.sets) sets",value:Binding(get:{gym.state.days[index].exercises[offset].sets},set:{gym.state.days[index].exercises[offset].sets=$0;gym.save()}),in:1...20);TextField("Target, e.g. 8–12 reps",text:Binding(get:{gym.state.days[index].exercises[offset].target},set:{gym.state.days[index].exercises[offset].target=$0;gym.save()}));TextField("Superset group (optional)",text:Binding(get:{gym.state.days[index].exercises[offset].superset},set:{gym.state.days[index].exercises[offset].superset=$0;gym.save()}));Stepper("Rest \(item.rest) seconds",value:Binding(get:{gym.state.days[index].exercises[offset].rest},set:{gym.state.days[index].exercises[offset].rest=$0;gym.save()}),in:15...600,step:15)}}.onDelete{gym.state.days[index].exercises.remove(atOffsets:$0);gym.save()}.onMove{gym.state.days[index].exercises.move(fromOffsets:$0,toOffset:$1);gym.save()};Button{library=true}label:{Label("Add exercise",systemImage:"plus")}}}}.navigationTitle("Edit day").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}};ToolbarItem(placement:.topBarLeading){EditButton()}}.sheet(isPresented:$library){GymLibrary(gym:gym,dayID:dayID)}}}
    func swapDay(_ target:Int){guard let index,index != target else{return};let name=gym.state.days[index].title;let items=gym.state.days[index].exercises;gym.state.days[index].title=gym.state.days[target].title;gym.state.days[index].exercises=gym.state.days[target].exercises;gym.state.days[target].title=name;gym.state.days[target].exercises=items;gym.save();dismiss()}
}
struct GymLibrary:View {
    @ObservedObject var gym:GymStore
    var dayID:UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var query=""
    @State private var muscle="All"
    @State private var equipment="All"
    @State private var selected:GymExercise?
    @State private var custom=false
    @State private var ranked:[String]?
    @State private var finding=false
    @State private var explanation:String?
    @State private var job:Task<Void,Never>?
    var results:[GymExercise]{if let ranked{return ranked.compactMap{id in gym.exercises.first{$0.id == id}}};if query.isEmpty,muscle == "All",equipment == "All"{return Array(gym.exercises.prefix(79))};return gym.exercises.filter{(query.isEmpty || ($0.name+" "+($0.equipment ?? "")+" "+$0.primaryMuscles.joined(separator:" ")).localizedCaseInsensitiveContains(query)) && (muscle == "All" || (muscle == "Cardio" ? $0.isCardio:$0.primaryMuscles.contains(muscle))) && (equipment == "All" || $0.equipment == equipment)}}
    var body:some View {NavigationStack{List{Section{if !query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{Button{findByMeaning()}label:{Label(finding ? "Finding the movement…":"Find by description with AI",systemImage:"sparkle.magnifyingglass")}.disabled(finding).accessibilityIdentifier("gym-ai-search")};if let explanation{Text(explanation).font(.subheadline).foregroundStyle(Design.muted)};HStack{Picker("Muscle",selection:$muscle){Text("All muscles").tag("All");Text("Cardio").tag("Cardio");ForEach(Set(gym.exercises.flatMap(\.primaryMuscles)).sorted(),id:\.self){Text($0.capitalized).tag($0)}};Picker("Equipment",selection:$equipment){Text("All equipment").tag("All");ForEach(Set(gym.exercises.compactMap(\.equipment)).sorted(),id:\.self){Text($0.capitalized).tag($0)}}};Text(query.isEmpty && muscle == "All" && equipment == "All" ? "Machine favourites · search all \(gym.exercises.count) exercises":"\(results.count) exercises · reference photos load online").font(.caption).foregroundStyle(Design.muted)};ForEach(results){exercise in Button{selected=exercise}label:{HStack{Image(systemName:exercise.isCardio ? "figure.run":"dumbbell").frame(width:30);VStack(alignment:.leading,spacing:5){Text(exercise.name).foregroundStyle(Design.ink);Text((exercise.equipment ?? "Custom")+" · "+exercise.primaryMuscles.joined(separator:", ")).font(.caption).foregroundStyle(Design.muted)};Spacer();Image(systemName:"chevron.right").font(.caption)}}}}.searchable(text:$query,prompt:"Exercise, machine or what it does").onChange(of:query){_,_ in job?.cancel();finding=false;ranked=nil;explanation=nil}.onChange(of:muscle){_,_ in job?.cancel();finding=false;ranked=nil}.onChange(of:equipment){_,_ in job?.cancel();finding=false;ranked=nil}.onDisappear{job?.cancel();finding=false}.navigationTitle("Exercise library").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}};ToolbarItem(placement:.topBarLeading){Button{custom=true}label:{Image(systemName:"plus")}.accessibilityLabel("Create custom exercise")}}.sheet(item:$selected){exercise in NavigationStack{ScrollView{VStack(alignment:.leading,spacing:18){GymExerciseImage(exercise:exercise,height:230);Text(exercise.name).font(.title2.weight(.semibold));Text(exercise.primaryMuscles.joined(separator:", ").capitalized).foregroundStyle(Design.muted);ForEach(Array(exercise.instructions.enumerated()),id:\.offset){offset,text in Text("\(offset+1). "+text).font(.body)};if exercise.images.count>1{Text("Tap the image to see the next movement position.").font(.caption).foregroundStyle(Design.muted)};if dayID != nil || gym.state.active != nil{Button("Add to "+(dayID != nil ? "day":"workout")){let plan=GymPlanExercise(exercise.id);if let dayID,let index=gym.state.days.firstIndex(where:{$0.id == dayID}){gym.state.days[index].exercises.append(plan)}else{gym.state.active?.exercises.append(GymWorkoutExercise(plan))};gym.save();selected=nil;dismiss()}.buttonStyle(ActionStyle()).accessibilityIdentifier("gym-add-exercise")}}.padding(20)}.navigationTitle("Technique").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){selected=nil}}}}}.sheet(isPresented:$custom){GymCustomExercise(gym:gym)}}}
    func findByMeaning(){
        guard let token=gym.owner?.assistantToken else{explanation="Connect your assistant in Settings to search by description.";return}
        job?.cancel();finding=true;explanation=nil;let question=query
        let records=gym.exercises.map{exercise in var item=EdizCore.Record(space:"gym",kind:"note",title:exercise.name);item.id=exercise.id;item.body=(exercise.equipment ?? "")+"; "+exercise.primaryMuscles.joined(separator:", ")+"; "+String(exercise.instructions.prefix(2).joined(separator:" ").prefix(500));return item}
        job=Task{@MainActor in defer{if !Task.isCancelled{finding=false}};do{let answer:GeminiResponse
            do{answer=try await GeminiAssistant.answer(question:question,records:records,conversation:[],token:token,scope:"gym",requestMode:"exercise-search")}
            catch{guard !Task.isCancelled,error.localizedDescription.contains("500 records") else{throw error};var ids:[String]=[];var note="";for start in stride(from:0,to:records.count,by:500){try Task.checkCancellation();let batch=Array(records[start..<min(start+500,records.count)]);let reply=try await GeminiAssistant.answer(question:"Find the exercise matching this movement or machine description: "+question,records:batch,conversation:[],token:token,scope:"gym",requestMode:"semantic-search");ids += reply.recordIds;if note.isEmpty,!reply.recordIds.isEmpty{note=reply.text}};answer=GeminiResponse(text:note.isEmpty ? "No close match yet. Try describing the movement or muscle.":note,recordIds:Array(Set(ids)).sorted{left,right in (ids.firstIndex(of:left) ?? 0)<(ids.firstIndex(of:right) ?? 0)},actions:[])}
            try Task.checkCancellation();ranked=answer.recordIds;explanation=answer.text}catch{if !Task.isCancelled{explanation=error.localizedDescription}}}
    }
}
struct GymCustomExercise:View {
    @ObservedObject var gym:GymStore
    @Environment(\.dismiss) private var dismiss
    @State private var name=""
    @State private var equipment=""
    @State private var muscle=""
    @State private var instructions=""
    @State private var cardio=false
    var body:some View {NavigationStack{Form{TextField("Exercise name",text:$name);TextField("Machine / equipment",text:$equipment);TextField("Muscle group",text:$muscle);Toggle("Cardio exercise",isOn:$cardio);TextField("Technique notes",text:$instructions,axis:.vertical)}.navigationTitle("Your own exercise").toolbar{ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Save"){gym.state.custom.append(GymExercise(name:name.trimmingCharacters(in:.whitespacesAndNewlines),equipment:equipment,category:cardio ? "cardio":"strength",primaryMuscles:muscle.isEmpty ? []:[muscle.lowercased()],instructions:instructions.isEmpty ? []:[instructions]));gym.save();dismiss()}.disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}}}}
}
struct GymGuide:View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var gym:GymStore
    var body:some View {NavigationStack{List{Section("Rest alerts"){Toggle("Notify me when rest ends",isOn:Binding(get:{gym.state.alerts},set:{enabled in if enabled{Task{await gym.enableAlerts()}}else{gym.state.alerts=false;gym.save();UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:["ediz-gym-rest"])}}));Text("Notifications and a sound can arrive while the phone is locked. iPhone Focus and sound settings still apply.").font(.footnote).foregroundStyle(Design.muted)};Section("Make the plan yours"){guide("1. Choose your training day","Use the sliders next to a day to rename it, change exercises, reorder them, and set your targets. Empty days are recovery days.");guide("2. Find your movement","Search the exercise library by name, muscle or equipment. Technique screens include reference images. Add your own exercise when your machine is missing.");guide("3. Log your sets","Start a day, then expand an exercise. Enter kg and reps, or cardio minutes and kilometres. Tap the circle after each set. Only completed sets count toward volume.");guide("4. Supersets & rest","Use the same superset group name on two exercises. Alternate those exercises yourself; group labels keep them connected. Choose rest time per exercise and adjust the active rest timer.");guide("5. Keep your progress","Previous shows your latest completed sets for the same exercise. The timer uses the starting time, so locking the phone doesn’t lose elapsed time. Finish saves the session to History.")};Section("Understand the numbers"){Text("Volume is weight × repetitions across completed strength sets. It is not body weight moved or a calorie measurement. Calories are not estimated here because sets alone cannot give a reliable figure.");Text("Your four-day plan is placed across an editable week. The initial three sets and rest times are editable placeholders. Begin with manageable loads and check unfamiliar technique with a trainer.")};Section("Exercise resource"){Link("Free Exercise DB · public-domain catalogue",destination:URL(string:"https://github.com/yuhonas/free-exercise-db")!);Text("Reference images need an internet connection. Instructions and the exercise library are stored on the phone.").font(.footnote)}}.navigationTitle("Gym guide & settings").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}}}
    func guide(_ title:String,_ body:String)->some View {VStack(alignment:.leading,spacing:8){Text(title).font(.headline);Text(body).foregroundStyle(Design.muted)}.padding(.vertical,5)}
}
struct GymSummary:View {
    let workout:GymWorkout
    @ObservedObject var gym:GymStore
    @Environment(\.dismiss) private var dismiss
    var body:some View {NavigationStack{ScrollView{VStack(alignment:.leading,spacing:24){Image(systemName:"checkmark.seal.fill").font(.system(size:48)).foregroundStyle(WorkspaceTheme.accent("gym"));Text("One session stronger.").font(.largeTitle.weight(.semibold));Text(workout.title).font(.title3);HStack{stat("Completed",String(workout.completedSets)+" sets");Spacer();stat("Volume",String(Int(workout.volume))+" kg");Spacer();stat("Time",String(Int(workout.elapsed(at:Date())/60))+" min")};ForEach(workout.exercises){item in VStack(alignment:.leading,spacing:5){Text(gym.exercise(item.exerciseID).name).font(.headline);Text("\(item.sets.filter(\.done).count) completed sets").font(.caption);Text(item.sets.filter(\.done).map{$0.minutes>0 ? "\($0.minutes.formatted()) min · \($0.distance.formatted()) km":"\($0.kg.formatted()) kg × \($0.reps)"}.joined(separator:" · ")).font(.subheadline).foregroundStyle(Design.muted)}};Button("Done"){dismiss()}.buttonStyle(ActionStyle())}.padding(24)}.navigationTitle("Workout saved").navigationBarTitleDisplayMode(.inline)}}
    func stat(_ label:String,_ value:String)->some View{VStack(alignment:.leading,spacing:6){Text(label).font(.caption).foregroundStyle(Design.muted);Text(value).font(.headline)}}
}

/// String editing preserves an unfinished decimal and commits each keystroke before Done.
struct GymNumberField:View {
    let label:String
    let placeholder:String
    @Binding var value:Double
    var integer=false
    @State private var text=""
    var body:some View {TextField(placeholder,text:$text).keyboardType(integer ? .numberPad:.decimalPad).accessibilityLabel(label).onAppear{if value != 0{text=value.formatted(.number.grouping(.never))}}.onChange(of:text){_,input in let normalized=input.replacingOccurrences(of:",",with:".");if input.isEmpty{value=0}else if let number=Double(normalized),number.isFinite{value=max(0,min(number,integer ? 10000:100000))}}}
}
