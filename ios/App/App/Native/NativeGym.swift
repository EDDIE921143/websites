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
    var gymContext:[EdizCore.Record]{let gym=GymStore();gym.load(self);var records=[gym.context]
        for (index,day) in gym.state.days.enumerated(){var record=EdizCore.Record(space:"gym",kind:"note",title:["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"][index]+" · "+day.title);record.id=day.id.uuidString;record.data["gymKind"]="day";record.body="Scheduled: "+(day.scheduledDate ?? "weekly")+"\n"+day.exercises.map{"entryID=\($0.id.uuidString), exerciseID=\($0.exerciseID): \(gym.exercise($0.exerciseID).name); sets=\($0.sets), rest=\($0.rest), target=\($0.target), superset=\($0.superset)"}.joined(separator:"\n");records.append(record)}
        for exercise in gym.exercises.prefix(79){var record=EdizCore.Record(space:"gym",kind:"note",title:exercise.name);record.id=exercise.id;record.data["gymKind"]="exercise";record.body=(exercise.equipment ?? "")+" · "+exercise.primaryMuscles.joined(separator:", ");records.append(record)}
        var catalogue=EdizCore.Record(space:"gym",kind:"note",title:"Complete exercise ID catalogue");catalogue.data["gymKind"]="catalogue";let names=Dictionary(gym.exercises.map{($0.id,$0.name)},uniquingKeysWith:{first,_ in first});if let bytes=try? JSONEncoder().encode(names){catalogue.body=String(decoding:bytes,as:UTF8.self)};records.append(catalogue)
        return records
    }
}
struct GymLibraryRequest:Identifiable {let id=UUID();var dayID:UUID?=nil}
struct NativeGym:View {
    @EnvironmentObject var store:NativeStore
    @StateObject private var gym=GymStore()
    @State private var section="week"
    @State private var weekday=0
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
            .toolbar{ToolbarItemGroup(placement:.topBarTrailing){if gym.state.active != nil{Button("Finish"){summary=gym.finish()}.fontWeight(.semibold).accessibilityIdentifier("gym-finish")}else{Button{library=GymLibraryRequest()}label:{Image(systemName:"books.vertical")}.accessibilityLabel("Exercise library");Button{settings=true}label:{Image(systemName:"gearshape")}.accessibilityLabel("Gym settings").accessibilityIdentifier("gym-settings")}}}
            .toolbar(gym.state.active == nil ? .visible:.hidden,for:.tabBar)
            .sheet(item:$editing){day in GymDayEditor(gym:gym,dayID:day.id)}
            .sheet(item:$library){request in GymLibrary(gym:gym,dayID:request.dayID)}
            .sheet(isPresented:$settings){GymGuide(gym:gym)}
            .sheet(item:$summary){workout in GymSummary(workout:workout,gym:gym)}
            .onAppear{gym.owner=nil;gym.load(store)}.onReceive(timer){_ in gym.tick()}
    }
    var week:some View {VStack(spacing:18){
        ScrollView(.horizontal,showsIndicators:false){HStack(spacing:9){ForEach(0..<min(7,gym.state.days.count),id:\.self){day in Button{withAnimation(reduceMotion ? nil:.easeOut(duration:0.2)){weekday=day}}label:{VStack(spacing:9){Text(["MON","TUE","WED","THU","FRI","SAT","SUN"][day]).font(.caption.weight(.semibold));Image(systemName:gym.state.days[day].exercises.isEmpty ? "leaf":"dumbbell.fill").font(.body)}.frame(width:58,height:72).foregroundStyle(weekday == day ? WorkspaceTheme.base("gym"):Design.muted).background(weekday == day ? accent:Design.surface,in:RoundedRectangle(cornerRadius:18))}.buttonStyle(.plain).accessibilityLabel(["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"][day]).accessibilityIdentifier("gym-weekday-\(day)")}}}
        ForEach(Array(gym.state.days.enumerated()).filter{$0.offset == weekday},id:\.element.id){index,day in
        VStack(alignment:.leading,spacing:14){HStack(alignment:.top){Text(["MON","TUE","WED","THU","FRI","SAT","SUN"][index]).font(.caption.weight(.semibold)).foregroundStyle(accent).frame(width:42,alignment:.leading).padding(.top,3);VStack(alignment:.leading,spacing:5){Text(day.title).font(.headline);if let date=day.scheduledDate{Label(date,systemImage:"calendar").font(.caption).foregroundStyle(accent)};Text(day.exercises.isEmpty ? "Recovery day · or add your own exercises":"\(day.exercises.count) exercises · "+day.exercises.reduce(into:[String]()){groups,item in for muscle in gym.exercise(item.exerciseID).primaryMuscles where !groups.contains(muscle){groups.append(muscle)}}.prefix(3).joined(separator:" / ")).font(.caption).foregroundStyle(Design.muted)};Spacer();Button{editing=day}label:{Image(systemName:"slider.horizontal.3").frame(width:44,height:44)}.accessibilityLabel("Edit "+day.title).accessibilityIdentifier("gym-edit-day-\(index)")}
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
    @State private var removing:GymPlanExercise?
    @State private var confirmRemoval=false
    var index:Int?{gym.state.days.firstIndex{$0.id == dayID}}
    func binding<T>(_ id:UUID,_ key:WritableKeyPath<GymPlanExercise,T>,_ fallback:T)->Binding<T>{Binding(get:{guard let index,let item=gym.state.days[index].exercises.first(where:{$0.id == id}) else{return fallback};return item[keyPath:key]},set:{value in guard let index,let row=gym.state.days[index].exercises.firstIndex(where:{$0.id == id}) else{return};gym.state.days[index].exercises[row][keyPath:key]=value;gym.save()})}
    var body:some View {
        NavigationStack {
            List {
                if let index {
                    Section("Your training day") {
                        TextField("Day name",text:Binding(get:{gym.state.days[index].title},set:{gym.state.days[index].title=$0;gym.save()}))
                        Menu("Move workout to another weekday") {
                            ForEach(Array(gym.state.days.enumerated()),id:\.element.id) { offset,day in
                                if day.id != dayID {
                                    Button(["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"][offset]+" · "+day.title){swapDay(offset)}
                                }
                            }
                        }
                        Text("Moving swaps the two days, keeping both workouts.").font(.caption).foregroundStyle(Design.muted)
                    }
                    ForEach(gym.state.days[index].exercises) { item in
                        Section {
                            VStack(alignment:.leading,spacing:14) {
                                HStack{Image(systemName:"dumbbell.fill").foregroundStyle(WorkspaceTheme.accent("gym"));Text(gym.exercise(item.exerciseID).name).font(.headline)}
                                Stepper("\(item.sets) sets",value:binding(item.id,\.sets,item.sets),in:1...20)
                                TextField("Target, e.g. 8–12 reps",text:binding(item.id,\.target,item.target))
                                TextField("Superset group (optional)",text:binding(item.id,\.superset,item.superset))
                                Stepper("Rest \(item.rest) seconds",value:binding(item.id,\.rest,item.rest),in:15...600,step:15)
                                Button(role:.destructive){removing=item;confirmRemoval=true}label:{Label("Remove exercise",systemImage:"trash")}.accessibilityIdentifier("gym-remove-"+item.id.uuidString)
                            }.padding(.vertical,8)
                        }
                    }
                    Section{Button{library=true}label:{Label("Choose another exercise",systemImage:"plus.circle.fill")}.frame(minHeight:44)}
                }
            }
            .scrollContentBackground(.hidden).background(AppBackdrop(scope:"gym"))
            .navigationTitle("Shape your workout").navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}
            .sheet(isPresented:$library){GymLibrary(gym:gym,dayID:dayID)}
            .confirmationDialog("Remove this exercise from the day?",isPresented:$confirmRemoval,titleVisibility:.visible){
                Button("Remove from this day",role:.destructive){
                    if let index,let removing{gym.state.days[index].exercises.removeAll{$0.id == removing.id};gym.save()}
                    removing=nil
                }
            }
        }
    }
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
    var body:some View {NavigationStack{List{Section{if !query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{Button{findByMeaning()}label:{Label(finding ? "Finding the movement…":"Find by description with AI",systemImage:"sparkle.magnifyingglass")}.disabled(finding).accessibilityIdentifier("gym-ai-search")};if let explanation{Text(explanation).font(.subheadline).foregroundStyle(Design.muted)};VStack(alignment:.leading,spacing:12){Picker("Muscle",selection:$muscle){Text("All muscles").tag("All");Text("Cardio").tag("Cardio");ForEach(Set(gym.exercises.flatMap(\.primaryMuscles)).sorted(),id:\.self){Text($0.capitalized).tag($0)}};Picker("Equipment",selection:$equipment){Text("All equipment").tag("All");ForEach(Set(gym.exercises.compactMap(\.equipment)).sorted(),id:\.self){Text($0.capitalized).tag($0)}}};Text(query.isEmpty && muscle == "All" && equipment == "All" ? "Machine favourites · search all \(gym.exercises.count) exercises":"\(results.count) exercises · reference photos load online").font(.caption).foregroundStyle(Design.muted)};ForEach(results){exercise in Button{selected=exercise}label:{HStack(spacing:14){GymExerciseImage(exercise:exercise,height:64).frame(width:76);VStack(alignment:.leading,spacing:5){Text(exercise.name).foregroundStyle(Design.ink);Text((exercise.equipment ?? "Custom")+" · "+exercise.primaryMuscles.joined(separator:", ")).font(.caption).foregroundStyle(Design.muted)};Spacer();Image(systemName:dayID != nil ? "plus.circle.fill":"chevron.right").font(.title3).foregroundStyle(WorkspaceTheme.accent("gym"))}.padding(.vertical,7)}}}.scrollContentBackground(.hidden).background(AppBackdrop(scope:"gym")).searchable(text:$query,prompt:"Exercise, machine or what it does").onChange(of:query){_,_ in job?.cancel();finding=false;ranked=nil;explanation=nil}.onChange(of:muscle){_,_ in job?.cancel();finding=false;ranked=nil}.onChange(of:equipment){_,_ in job?.cancel();finding=false;ranked=nil}.onDisappear{job?.cancel();finding=false}.navigationTitle("Exercise library").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}};ToolbarItem(placement:.topBarLeading){Button{custom=true}label:{Image(systemName:"plus")}.accessibilityLabel("Create custom exercise")}}.sheet(item:$selected){exercise in NavigationStack{ScrollView{VStack(alignment:.leading,spacing:18){GymExerciseImage(exercise:exercise,height:230);Text(exercise.name).font(.title2.weight(.semibold));Text(exercise.primaryMuscles.joined(separator:", ").capitalized).foregroundStyle(Design.muted);ForEach(Array(exercise.instructions.enumerated()),id:\.offset){offset,text in Text("\(offset+1). "+text).font(.body)};if exercise.images.count>1{Text("Tap the image to see the next movement position.").font(.caption).foregroundStyle(Design.muted)};if dayID != nil || gym.state.active != nil{Button("Add to "+(dayID != nil ? "day":"workout")){let plan=GymPlanExercise(exercise.id);if let dayID,let index=gym.state.days.firstIndex(where:{$0.id == dayID}){gym.state.days[index].exercises.append(plan)}else{gym.state.active?.exercises.append(GymWorkoutExercise(plan))};gym.save();selected=nil;dismiss()}.buttonStyle(ActionStyle()).accessibilityIdentifier("gym-add-exercise")}}.padding(20)}.navigationTitle("Technique").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){selected=nil}}}}}.sheet(isPresented:$custom){GymCustomExercise(gym:gym)}}}
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
    var body:some View {NavigationStack{List{Section("Rest alerts"){Toggle("Notify me when rest ends",isOn:Binding(get:{gym.state.alerts},set:{enabled in if enabled{Task{await gym.enableAlerts()}}else{gym.state.alerts=false;gym.save();UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:["ediz-gym-rest"])}}));Text("Notifications and a sound can arrive while the phone is locked. iPhone Focus and sound settings still apply.").font(.footnote).foregroundStyle(Design.muted)};Section{NavigationLink{GymTutorial(token:gym.owner?.assistantToken)}label:{Label("Take the spoken Gym walkthrough",systemImage:"play.rectangle.fill").font(.headline)}.accessibilityIdentifier("gym-tutorial-start");Text("Practise changing a day and logging a set without changing your workouts.").font(.caption).foregroundStyle(Design.muted)};Section("Make the plan yours"){guide("1. Choose your training day","Use the sliders next to a day to rename it, change exercises, reorder them, and set your targets. Empty days are recovery days.");guide("2. Find your movement","Search the exercise library by name, muscle or equipment. Technique screens include reference images. Add your own exercise when your machine is missing.");guide("3. Log your sets","Start a day, then expand an exercise. Enter kg and reps, or cardio minutes and kilometres. Tap the circle after each set. Only completed sets count toward volume.");guide("4. Supersets & rest","Use the same superset group name on two exercises. Alternate those exercises yourself; group labels keep them connected. Choose rest time per exercise and adjust the active rest timer.");guide("5. Keep your progress","Previous shows your latest completed sets for the same exercise. The timer uses the starting time, so locking the phone doesn’t lose elapsed time. Finish saves the session to History.")};Section("Understand the numbers"){Text("Volume is weight × repetitions across completed strength sets. It is not body weight moved or a calorie measurement. Calories are not estimated here because sets alone cannot give a reliable figure.");Text("Your four-day plan is placed across an editable week. The initial three sets and rest times are editable placeholders. Begin with manageable loads and check unfamiliar technique with a trainer.")};Section("Exercise resource"){Link("Free Exercise DB · public-domain catalogue",destination:URL(string:"https://github.com/yuhonas/free-exercise-db")!);Text("Reference images need an internet connection. Instructions and the exercise library are stored on the phone.").font(.footnote)}}.navigationTitle("Gym guide & settings").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}}}
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

struct GymChangeReview:View {
    @EnvironmentObject var store:NativeStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gym=GymStore()
    let action:GeminiProposal
    @State private var error:String?
    @State private var applied=false
    var body:some View {NavigationStack{ScrollView{VStack(alignment:.leading,spacing:20){Label("Your plan, adjusted",systemImage:"sparkles").font(.title2.weight(.semibold));Text(action.title).font(.headline)
        if let data=action.fields?.data,let day=gym.state.days.first(where:{$0.id.uuidString == data["dayID"]}){Text(day.title).foregroundStyle(Design.muted);ForEach(data.keys.filter{!["dayID","entryID","exerciseID","otherDayID","operation"].contains($0)}.sorted(),id:\.self){key in HStack{Text(key.capitalized);Spacer();Text(data[key] ?? "")}};if let id=data["exerciseID"]{Text(gym.exercise(id).name)};if let other=gym.state.days.first(where:{$0.id.uuidString == data["otherDayID"]}){Label("Swap with "+other.title,systemImage:"arrow.left.arrow.right")}}
        Text("This updates the weekly plan. A workout already in progress keeps its logged sets.").font(.footnote).foregroundStyle(Design.muted)
        if let error{Text(error).foregroundStyle(.red)}
        Button(applied ? "Changes saved":"Apply to my plan"){guard !applied else{dismiss();return};do{try gym.state.applyPlanChange(action.fields?.data ?? [:],allowedExerciseIDs:Set(gym.exercises.map(\.id)));gym.save();if let message=gym.message{error=message}else{applied=true;UINotificationFeedbackGenerator().notificationOccurred(.success)}}catch{self.error=error.localizedDescription}}.buttonStyle(ActionStyle()).accessibilityIdentifier("gym-apply-change")
    }.padding(24)}.background(AppBackdrop(scope:"gym")).navigationTitle("Review workout change").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}.onAppear{gym.load(store)}}}
}

/// A hands-on sandbox; the real weekly plan and history are never written here.
struct GymTutorial:View {
    let token:String?
    @StateObject private var narrator=NativeAssistantSpeaker()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step=0
    @State private var sets=3
    @State private var weight:Double=0
    @State private var reps:Double=0
    @State private var rest=90
    @State private var completed=false
    @State private var selected="Monday"
    @State private var spoken=true
    private let titles=["Welcome to your training space","Make the week work for you","Choose the movement","Build your working sets","Log the work you did","Give yourself time to recover","Let Gym Bot help","Keep the progress"]
    private let scripts=[
        "Welcome, Ediz. This is your training space. Your own four-day plan is here, alongside a library of exercises and the progress you build over time. Let's try the useful controls together. Everything in this walkthrough is practice, so your real workouts stay safe.",
        "Training doesn't always fit the same week. Open a day's sliders to move the workout, change its name or adjust the exercises. Moving a workout swaps the two days so you keep both. Choose a different day here to try it.",
        "You can find an exercise by its name, muscle or equipment. If you only remember what a machine does, describe it to the AI search. Open an exercise to see technique and reference photos, then add it to your day. A custom exercise is useful for a machine that's missing from the library.",
        "Your plan is a starting point, not a fixed prescription. Choose how many sets you want, a repetition target and a rest time. If two movements belong in a superset, give them the same group name. Try changing the number of sets here.",
        "During a workout, expand a movement and enter the weight and repetitions. Previous shows your latest completed sets for the same exercise, so you have a useful comparison. Enter a practice set below and mark it complete. Only completed sets contribute to volume.",
        "Rest starts when you finish a set. Every exercise can have its own timer, and you can add time or skip it while training. With notifications enabled, a rest alert can reach you while your phone is locked. Pick a rest time here that feels right for your practice set.",
        "Gym Bot can help adjust the actual plan. You might say, move legs to Friday, replace this exercise, or make the chest press four sets. It will prepare a specific change for you to review. Apply the suggestion to save it. The bot uses your plan and completed workouts, rather than guessing what you lifted.",
        "Nice work, Ediz. Finish saves the session to History. The elapsed timer keeps its starting time even when you lock your phone. Your volume is weight times completed repetitions; it isn't a calorie estimate. You're ready to make this space your own. Thanks for exploring it with me, and enjoy your next workout. Goodbye!"
    ]
    var ready:Bool{switch step{case 1:return selected != "Monday";case 3:return sets != 3;case 4:return completed;default:return true}}
    var body:some View {ScrollViewReader{proxy in ScrollView{VStack(alignment:.leading,spacing:24){
        HStack(spacing:12){GuideVoiceMark(accent:WorkspaceTheme.accent("gym"),level:narrator.level,speaking:narrator.speaking);VStack(alignment:.leading,spacing:4){Text("YOUR GYM WALKTHROUGH").font(.caption.weight(.semibold)).tracking(1);Text("Step \(step+1) of \(titles.count) · Practice space").font(.caption).foregroundStyle(Design.muted)};Spacer();Button{spoken.toggle();if spoken{read()}else{narrator.stop()}}label:{Image(systemName:spoken ? "speaker.wave.2.fill":"speaker.slash.fill").frame(width:44,height:44)}.accessibilityLabel("Toggle natural narration")}
        Color.clear.frame(height:1).id("gym-guide-top")
        ProgressView(value:Double(step+1),total:Double(titles.count)).tint(WorkspaceTheme.accent("gym"))
        Text(titles[step]).font(.largeTitle.weight(.semibold));Text(scripts[step]).font(.body).foregroundStyle(Design.muted).fixedSize(horizontal:false,vertical:true)
        if step>0{VStack(alignment:.leading,spacing:18){
            if step == 1{Text("Try moving a practice workout").font(.headline);Picker("Practice weekday",selection:$selected){ForEach(["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"],id:\.self){Text($0).tag($0)}}.pickerStyle(.menu)}
            if step == 2{Label("Seated chest press",systemImage:"dumbbell.fill").font(.headline);Label("Chest · machine",systemImage:"figure.strengthtraining.traditional");Text("Library → exercise → technique → Add to day").font(.subheadline).foregroundStyle(Design.muted)}
            if step == 3{Stepper("\(sets) working sets",value:$sets,in:1...20)}
            if step == 4{Text("Your practice set").font(.headline);HStack{GymNumberField(label:"Practice weight",placeholder:"kg",value:$weight);GymNumberField(label:"Practice reps",placeholder:"reps",value:$reps,integer:true);Button{completed=true;UINotificationFeedbackGenerator().notificationOccurred(.success)}label:{Image(systemName:completed ? "checkmark.circle.fill":"circle").font(.title).frame(width:44,height:44)}.disabled(weight<=0 || reps<=0)}.textFieldStyle(.roundedBorder);if completed{Label("Set logged. One step stronger!",systemImage:"sparkles").foregroundStyle(WorkspaceTheme.accent("gym"))}}
            if step == 5{Stepper("Rest · \(rest) seconds",value:$rest,in:15...600,step:15)}
            if step == 6{Label("“Move my leg day to Friday.”",systemImage:"bubble.left");Label("Review change → Apply to my plan",systemImage:"checkmark.circle")}
            if step == 7{Image(systemName:"checkmark.seal.fill").font(.system(size:56)).foregroundStyle(WorkspaceTheme.accent("gym")).symbolEffect(.bounce,value:step);Text("Ready for your next session.").font(.title2.weight(.semibold))}
        }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(Design.surface,in:RoundedRectangle(cornerRadius:22))}
        if let note=narrator.voiceNote,!note.hasPrefix("Natural voice"),!note.hasPrefix("Recorded natural voice"){Text(note).font(.caption).foregroundStyle(Design.muted);Button("Try narration again"){read()}}
        Button{read()}label:{Label("Replay narration",systemImage:"arrow.counterclockwise").font(.subheadline).frame(minHeight:44)}
        HStack{if step>0{Button("Back"){advance(-1)}.frame(minHeight:44)};Spacer();Button(step == titles.count-1 ? "Finish walkthrough":"Continue"){if step == titles.count-1{narrator.stop();dismiss()}else{advance(1)}}.foregroundStyle(WorkspaceTheme.base("gym")).buttonStyle(.borderedProminent).tint(WorkspaceTheme.accent("gym")).disabled(!ready)}
    }.padding(24)}.scrollDismissesKeyboard(.interactively).background(AppBackdrop(scope:"gym")).navigationTitle("Learn your Gym").navigationBarTitleDisplayMode(.inline).onAppear{read()}.onDisappear{narrator.stop()}.onChange(of:step){_,_ in withAnimation(reduceMotion ? nil:.easeOut(duration:0.2)){proxy.scrollTo("gym-guide-top",anchor:.top)}}}
    }
    func advance(_ direction:Int){withAnimation(reduceMotion ? nil:.spring(response:0.28,dampingFraction:0.88)){step+=direction};read()}
    func read(){guard spoken else{return};let voice=NativeVoicePreferences.defaults.string(forKey:"tutorial-natural-voice-name") ?? "Aoede";if let clip=Bundle.main.url(forResource:"gym-step-"+String(step),withExtension:"m4a",subdirectory:"GuideAudio/"+voice){narrator.playRecorded([clip],voice:voice)}else if let clip=Bundle.main.url(forResource:"gym-step-"+String(step),withExtension:"m4a",subdirectory:"GuideAudio/Aoede"){narrator.playRecorded([clip],voice:"Aoede")}else{narrator.say(scripts[step],token:token,natural:true,voice:voice)}}
}
