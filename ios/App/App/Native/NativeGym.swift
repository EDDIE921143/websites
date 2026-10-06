import SwiftUI
import Combine
import EdizCore
import UserNotifications
import AudioToolbox
import AVKit

final class GymNotificationDelegate:NSObject,UNUserNotificationCenterDelegate {
    static let shared=GymNotificationDelegate()
    func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping (UNNotificationPresentationOptions)->Void){completionHandler([.banner,.sound])}
}
@MainActor final class GymStore:ObservableObject {
    @Published var state=GymState()
    @Published var catalog:[GymExercise]=[]
    @Published var message:String?
    @Published var storageReadable=true
    weak var owner:NativeStore?
    var exercises:[GymExercise]{catalog+state.custom}
    func load(_ store:NativeStore){guard owner == nil else{return};owner=store;UNUserNotificationCenter.current().delegate=GymNotificationDelegate.shared
        if let text=store.preferences.assistantChats["gym-state"]{do{state=try JSONDecoder().decode(GymState.self,from:Data(text.utf8));storageReadable=true}catch{storageReadable=false;message="Your saved Gym data couldn’t be opened. Restore a backup in Settings → Import & restore. The existing data has been kept.";return}}
        if let url=Bundle.main.url(forResource:"exercises",withExtension:"json",subdirectory:"GymResources"),let data=try? Data(contentsOf:url){catalog=(try? JSONDecoder().decode([GymExercise].self,from:data)) ?? []}
        if store.preferences.assistantChats["gym-plan-revision"] != EdizGymPlan.revision {
            var preferences=store.preferences
            if let previous=preferences.assistantChats["gym-state"],preferences.assistantChats["gym-plan-before-five-day"] == nil{preferences.assistantChats["gym-plan-before-five-day"]=previous}
            state.adoptEdizFiveDayPlan()
            do{preferences.assistantChats["gym-state"]=String(decoding:try JSONEncoder().encode(state),as:UTF8.self);preferences.assistantChats["gym-plan-revision"]=EdizGymPlan.revision;store.setPreferences(preferences)}catch{message="Your five-day plan couldn’t be saved. Your previous data is kept."}
        }
    }
    func exercise(_ id:String)->GymExercise{exercises.first{$0.id == id} ?? GymExercise(id:id,name:"Unavailable exercise",instructions:["Replace this exercise from the library."])}
    func save(){guard storageReadable,let owner else{return};do{let data=try JSONEncoder().encode(state);var prefs=owner.preferences;prefs.assistantChats["gym-state"]=String(decoding:data,as:UTF8.self);owner.setPreferences(prefs)}catch{message="The workout couldn’t be saved. Please keep this screen open."}}
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
            if !gym.storageReadable{QuietEmpty(title:"Your saved plan needs attention",message:gym.message ?? "Restore a backup to continue.")}else if let workout=gym.state.active{workoutHeader(workout);workoutCards(workout)}else{
                VStack(alignment:.leading,spacing:9){Text("Build a little stronger.").font(.largeTitle.weight(.semibold));Text("Your week, your pace. Adjust the plan to fit you.").foregroundStyle(Design.muted)}.padding(.top,8)
                NavigationLink{NativeConversationHost(scope:"gym")}label:{HStack{Image(systemName:"sparkles");VStack(alignment:.leading,spacing:3){Text("Gym assistant").font(.headline);Text("Talk through your plan and progress").font(.caption).foregroundStyle(Design.muted)};Spacer();Image(systemName:"chevron.right")}.padding(16).background(accent.opacity(0.12),in:RoundedRectangle(cornerRadius:18))}.buttonStyle(.plain).accessibilityIdentifier("gym-assistant")
                Picker("Gym view",selection:$section){Text("Week").tag("week");Text("History").tag("history")}.pickerStyle(.segmented)
                if section == "week"{week}else{history}
            }
            if let message=gym.message{Text(message).font(.footnote).foregroundStyle(Design.muted)}
        }.padding(20)}.scrollDismissesKeyboard(.interactively).background(AppBackdrop(scope:"gym")).navigationTitle("Gym").navigationBarTitleDisplayMode(.inline).tint(accent)
            .toolbar{ToolbarItemGroup(placement:.topBarTrailing){if gym.state.active != nil{Button("Finish"){summary=gym.finish();store.walkthrough?.event("gym-finish",narrate:false)}.fontWeight(.semibold).accessibilityIdentifier("gym-finish").walkthroughTarget("gym-finish",session:store.walkthrough)}else{Button{library=GymLibraryRequest()}label:{Image(systemName:"books.vertical")}.accessibilityLabel("Exercise library");Button{settings=true}label:{Image(systemName:"gearshape")}.accessibilityLabel("Gym settings").accessibilityIdentifier("gym-settings")}}}
            .toolbar(gym.state.active == nil ? .visible:.hidden,for:.tabBar)
            .sheet(item:$editing){day in GymDayEditor(gym:gym,dayID:day.id)}
            .sheet(item:$library){request in GymLibrary(gym:gym,dayID:request.dayID)}
            .sheet(isPresented:$settings){GymGuide(gym:gym)}
            .sheet(item:$summary){workout in GymSummary(workout:workout,gym:gym)}
            .onAppear{gym.owner=nil;gym.load(store);store.walkthrough?.event("gym-open")}.onReceive(timer){_ in gym.tick()}
    }
    var week:some View {VStack(spacing:18){
        ScrollView(.horizontal,showsIndicators:false){HStack(spacing:9){ForEach(0..<min(7,gym.state.days.count),id:\.self){day in Button{withAnimation(reduceMotion ? nil:.easeOut(duration:0.2)){weekday=day};if day==1{store.walkthrough?.event("gym-day")}}label:{VStack(spacing:9){Text(["MON","TUE","WED","THU","FRI","SAT","SUN"][day]).font(.caption.weight(.semibold));Image(systemName:gym.state.days[day].exercises.isEmpty ? "leaf":"dumbbell.fill").font(.body)}.frame(width:58,height:72).foregroundStyle(weekday == day ? WorkspaceTheme.base("gym"):Design.muted).background(weekday == day ? accent:Design.surface,in:RoundedRectangle(cornerRadius:18))}.buttonStyle(.plain).accessibilityLabel(["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"][day]).accessibilityIdentifier("gym-weekday-\(day)").walkthroughTarget(day==1 ? "gym-day":"",session:store.walkthrough)}}}
        ForEach(Array(gym.state.days.enumerated()).filter{$0.offset == weekday},id:\.element.id){index,day in
        VStack(alignment:.leading,spacing:14){HStack(alignment:.top){Text(["MON","TUE","WED","THU","FRI","SAT","SUN"][index]).font(.caption.weight(.semibold)).foregroundStyle(accent).frame(width:42,alignment:.leading).padding(.top,3);VStack(alignment:.leading,spacing:5){Text(day.title).font(.headline);if let date=day.scheduledDate{Label(date,systemImage:"calendar").font(.caption).foregroundStyle(accent)};Text(day.exercises.isEmpty ? "Recovery day · or add your own exercises":"\(day.exercises.count) exercises · "+day.exercises.reduce(into:[String]()){groups,item in for muscle in gym.exercise(item.exerciseID).primaryMuscles where !groups.contains(muscle){groups.append(muscle)}}.prefix(3).joined(separator:" / ")).font(.caption).foregroundStyle(Design.muted)};Spacer();Button{editing=day}label:{Image(systemName:"slider.horizontal.3").frame(width:44,height:44)}.accessibilityLabel("Edit "+day.title).accessibilityIdentifier("gym-edit-day-\(index)")}
            if !day.exercises.isEmpty{Text(day.exercises.map{gym.exercise($0.exerciseID).name}.joined(separator:" · ")).font(.subheadline).foregroundStyle(Design.muted).lineLimit(3);Button{gym.start(day);store.walkthrough?.event("gym-start");expanded=Set(gym.state.active?.exercises.prefix(1).map(\.id) ?? [])}label:{Label("Start workout",systemImage:"play.fill").foregroundStyle(WorkspaceTheme.base("gym")).frame(maxWidth:.infinity,minHeight:44)}.buttonStyle(.borderedProminent).accessibilityIdentifier("gym-start-\(index)").walkthroughTarget("gym-start",session:store.walkthrough)}
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
        if expanded{GymMovementGuide(exercise:exercise,height:130);Button{instructions.toggle()}label:{Label(instructions ? "Hide technique":"Technique & instructions",systemImage:"info.circle")}.font(.subheadline);if instructions{ForEach(Array(exercise.instructions.enumerated()),id:\.offset){offset,text in Text("\(offset+1). "+text).font(.subheadline).foregroundStyle(Design.muted)}}
            HStack{Text("PREVIOUS").frame(width:78,alignment:.leading);Text(exercise.isCardio ? "MIN / KM":"KG / REPS").frame(maxWidth:.infinity);Text("DONE").frame(width:44)}.font(.caption2.weight(.semibold)).foregroundStyle(Design.muted)
            ForEach(Array(item.sets.enumerated()),id:\.element.id){setIndex,set in setRow(exercise,item,setIndex,set)}
            HStack{Button{gym.state.active?.exercises[index].sets.append(GymSet());gym.save()}label:{Label("Add set",systemImage:"plus")};Spacer();Menu{ForEach([30,45,60,90,120,180],id:\.self){seconds in Button("\(seconds)s"){gym.state.active?.exercises[index].rest=seconds;gym.save()}}}label:{Label("Rest \(item.rest)s",systemImage:"timer")}}.font(.subheadline).frame(minHeight:44)
        }
    }.padding(16).background(Design.surface,in:RoundedRectangle(cornerRadius:20))}}
    func binding<T>(_ set:Int,_ key:WritableKeyPath<GymSet,T>,_ fallback:T)->Binding<T>{Binding(get:{guard let item,self.item != nil,item.sets.indices.contains(set) else{return fallback};return item.sets[set][keyPath:key]},set:{value in guard let item,self.item != nil,item.sets.indices.contains(set) else{return};gym.state.active?.exercises[index].sets[set][keyPath:key]=value;gym.save()})}
    func setRow(_ exercise:GymExercise,_ item:GymWorkoutExercise,_ setIndex:Int,_ set:GymSet)->some View {let previous=gym.state.previousSets(for:item.exerciseID);return HStack(spacing:8){VStack(alignment:.leading,spacing:4){Text("SET \(setIndex+1)").font(.caption2);Text(previous.indices.contains(setIndex) ? (exercise.isCardio ? "\(Int(previous[setIndex].minutes))m / \(previous[setIndex].distance.formatted())k":"\(previous[setIndex].kg.formatted()) × \(previous[setIndex].reps)"):"—").font(.caption).foregroundStyle(Design.muted)}.frame(width:78,alignment:.leading)
        if exercise.isCardio{GymNumberField(label:"Set \(setIndex+1) minutes",placeholder:"min",value:binding(setIndex,\.minutes,0));GymNumberField(label:"Set \(setIndex+1) distance",placeholder:"km",value:binding(setIndex,\.distance,0))}else{GymNumberField(label:"Set \(setIndex+1) weight",placeholder:"kg",value:binding(setIndex,\.kg,0));GymNumberField(label:"Set \(setIndex+1) reps",placeholder:"reps",value:Binding(get:{Double(gym.state.active?.exercises[index].sets[setIndex].reps ?? 0)},set:{gym.state.active?.exercises[index].sets[setIndex].reps=Int($0);gym.save()}),integer:true)}
        Button{UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),to:nil,from:nil,for:nil);gym.state.active?.exercises[index].sets[setIndex].kg=max(0,set.kg);gym.state.active?.exercises[index].sets[setIndex].reps=max(0,set.reps);gym.state.active?.exercises[index].sets[setIndex].minutes=max(0,set.minutes);gym.state.active?.exercises[index].sets[setIndex].distance=max(0,set.distance);gym.state.active?.exercises[index].sets[setIndex].done.toggle();gym.save();if !set.done{gym.startRest(item.rest);if set.kg>0 && set.reps>0 || exercise.isCardio && set.minutes>0{gym.owner?.walkthrough?.event("gym-set")};UIImpactFeedbackGenerator(style:.light).impactOccurred()}}label:{Image(systemName:set.done ? "checkmark.circle.fill":"circle").font(.title2).foregroundStyle(set.done ? WorkspaceTheme.accent("gym"):Design.muted).frame(width:44,height:44)}.accessibilityLabel(set.done ? "Unmark set \(setIndex+1)":"Complete set \(setIndex+1)")
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
                        Text("Moving swaps the two days, keeping both workouts. Below, use Up and Down to reorder exercises or the calendar button to move one to another day.").font(.caption).foregroundStyle(Design.muted)
                    }
                    ForEach(gym.state.days[index].exercises) { item in
                        Section {
                            VStack(alignment:.leading,spacing:14) {
                                HStack{Image(systemName:"dumbbell.fill").foregroundStyle(WorkspaceTheme.accent("gym"));Text(gym.exercise(item.exerciseID).name).font(.headline)}
                                Stepper("\(item.sets) sets",value:binding(item.id,\.sets,item.sets),in:1...20)
                                TextField("Target, e.g. 8–12 reps",text:binding(item.id,\.target,item.target))
                                TextField("Superset group (optional)",text:binding(item.id,\.superset,item.superset))
                                Stepper("Rest \(item.rest) seconds",value:binding(item.id,\.rest,item.rest),in:15...600,step:15)
                                HStack(spacing:16){
                                    Button{move(item.id,by:-1)}label:{Label("Up",systemImage:"arrow.up")}.buttonStyle(.bordered).disabled(gym.state.days[index].exercises.first?.id == item.id).accessibilityLabel("Move "+gym.exercise(item.exerciseID).name+" up").accessibilityIdentifier("gym-move-up-"+item.id.uuidString)
                                    Button{move(item.id,by:1)}label:{Label("Down",systemImage:"arrow.down")}.buttonStyle(.bordered).disabled(gym.state.days[index].exercises.last?.id == item.id).accessibilityLabel("Move "+gym.exercise(item.exerciseID).name+" down").accessibilityIdentifier("gym-move-down-"+item.id.uuidString)
                                    Spacer()
                                    Menu{ForEach(Array(gym.state.days.enumerated()).filter{$0.offset != index},id:\.element.id){offset,day in Button(["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][offset]+" · "+day.title){moveToDay(item.id,target:offset)}}}label:{Image(systemName:"calendar.badge.arrow.left").frame(width:44,height:44)}.accessibilityLabel("Move "+gym.exercise(item.exerciseID).name+" to another day")
                                }
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
    func move(_ entry:UUID,by direction:Int){guard let index,let position=gym.state.days[index].exercises.firstIndex(where:{$0.id==entry}) else{return};let target=position+direction;guard gym.state.days[index].exercises.indices.contains(target) else{return};withAnimation(.easeInOut(duration:0.2)){gym.state.days[index].exercises.swapAt(position,target)};gym.save()}
    func moveToDay(_ entry:UUID,target:Int){guard let index,index != target,gym.state.days.indices.contains(target),let position=gym.state.days[index].exercises.firstIndex(where:{$0.id==entry}) else{return};let item=gym.state.days[index].exercises.remove(at:position);gym.state.days[target].exercises.append(item);gym.save()}
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
    var body:some View {NavigationStack{List{Section{if !query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{Button{findByMeaning()}label:{Label(finding ? "Finding the movement…":"Find by description with AI",systemImage:"sparkle.magnifyingglass")}.disabled(finding).accessibilityIdentifier("gym-ai-search")};if let explanation{Text(explanation).font(.subheadline).foregroundStyle(Design.muted)};VStack(alignment:.leading,spacing:12){Picker("Muscle",selection:$muscle){Text("All muscles").tag("All");Text("Cardio").tag("Cardio");ForEach(Set(gym.exercises.flatMap(\.primaryMuscles)).sorted(),id:\.self){Text($0.capitalized).tag($0)}};Picker("Equipment",selection:$equipment){Text("All equipment").tag("All");ForEach(Set(gym.exercises.compactMap(\.equipment)).sorted(),id:\.self){Text($0.capitalized).tag($0)}}};Text(query.isEmpty && muscle == "All" && equipment == "All" ? "Machine favourites · search all \(gym.exercises.count) exercises":"\(results.count) exercises · reference photos load online").font(.caption).foregroundStyle(Design.muted)};ForEach(results){exercise in Button{selected=exercise}label:{HStack(spacing:14){GymExerciseImage(exercise:exercise,height:64).frame(width:76);VStack(alignment:.leading,spacing:5){Text(exercise.name).foregroundStyle(Design.ink);Text((exercise.equipment ?? "Custom")+" · "+exercise.primaryMuscles.joined(separator:", ")).font(.caption).foregroundStyle(Design.muted)};Spacer();Image(systemName:dayID != nil ? "plus.circle.fill":"chevron.right").font(.title3).foregroundStyle(WorkspaceTheme.accent("gym"))}.padding(.vertical,7)}}}.scrollContentBackground(.hidden).background(AppBackdrop(scope:"gym")).searchable(text:$query,prompt:"Exercise, machine or what it does").onChange(of:query){_,_ in job?.cancel();finding=false;ranked=nil;explanation=nil}.onChange(of:muscle){_,_ in job?.cancel();finding=false;ranked=nil}.onChange(of:equipment){_,_ in job?.cancel();finding=false;ranked=nil}.onDisappear{job?.cancel();finding=false}.navigationTitle("Exercise library").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}};ToolbarItem(placement:.topBarLeading){Button{custom=true}label:{Image(systemName:"plus")}.accessibilityLabel("Create custom exercise")}}.sheet(item:$selected){exercise in NavigationStack{ScrollView{VStack(alignment:.leading,spacing:18){GymMovementGuide(exercise:exercise,height:230);Text(exercise.name).font(.title2.weight(.semibold));Text(exercise.primaryMuscles.joined(separator:", ").capitalized).foregroundStyle(Design.muted);ForEach(Array(exercise.instructions.enumerated()),id:\.offset){offset,text in Text("\(offset+1). "+text).font(.body)};if exercise.images.count>1{Text("Tap the image to see the next movement position.").font(.caption).foregroundStyle(Design.muted)};if dayID != nil || gym.state.active != nil{Button("Add to "+(dayID != nil ? "day":"workout")){let plan=GymPlanExercise(exercise.id);if let dayID,let index=gym.state.days.firstIndex(where:{$0.id == dayID}){gym.state.days[index].exercises.append(plan)}else{gym.state.active?.exercises.append(GymWorkoutExercise(plan))};gym.save();selected=nil;dismiss()}.buttonStyle(ActionStyle()).accessibilityIdentifier("gym-add-exercise")}}.padding(20)}.navigationTitle("Technique").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){selected=nil}}}}}.sheet(isPresented:$custom){GymCustomExercise(gym:gym)}}}
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
    var body:some View {NavigationStack{List{Section("Rest alerts"){Toggle("Notify me when rest ends",isOn:Binding(get:{gym.state.alerts},set:{enabled in if enabled{Task{await gym.enableAlerts()}}else{gym.state.alerts=false;gym.save();UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:["ediz-gym-rest"])}}));Text("Notifications and a sound can arrive while the phone is locked. iPhone Focus and sound settings still apply.").font(.footnote).foregroundStyle(Design.muted)};Section{NavigationLink{GymTutorial(token:gym.owner?.assistantToken)}label:{Label("Take the spoken Gym walkthrough",systemImage:"play.rectangle.fill").font(.headline)}.accessibilityIdentifier("gym-tutorial-start");Text("Practise changing a day and logging a set without changing your workouts.").font(.caption).foregroundStyle(Design.muted)};Section("Make the plan yours"){guide("1. Choose your training day","Use the sliders next to a day to rename it, change exercises, reorder them, and set your targets. Empty days are recovery days.");guide("2. Find your movement","Search the exercise library by name, muscle or equipment. Technique screens include reference images. Add your own exercise when your machine is missing.");guide("3. Log your sets","Start a day, then expand an exercise. Enter kg and reps, or cardio minutes and kilometres. Tap the circle after each set. Only completed sets count toward volume.");guide("4. Supersets & rest","Use the same superset group name on two exercises. Alternate those exercises yourself; group labels keep them connected. Choose rest time per exercise and adjust the active rest timer.");guide("5. Keep your progress","Previous shows your latest completed sets for the same exercise. The timer uses the starting time, so locking the phone doesn’t lose elapsed time. Finish saves the session to History.")};Section("Understand the numbers"){Text("Volume is weight × repetitions across completed strength sets. It is not body weight moved or a calorie measurement. Calories are not estimated here because sets alone cannot give a reliable figure.");Text("Your five-day plan is placed across an editable week. The initial three sets and rest times are editable placeholders. Begin with manageable loads and check unfamiliar technique with a trainer.")};Section("Exercise resource"){Button("Clear downloaded demonstrations"){let folder=FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("GymDemonstrations");try? FileManager.default.removeItem(at:folder)};Text("Matching videos download when opened and can replay offline. Clearing them leaves your workouts untouched.").font(.footnote);Link("Free Exercise DB · public-domain catalogue",destination:URL(string:"https://github.com/yuhonas/free-exercise-db")!);Text("Reference images need an internet connection. Instructions and the exercise library are stored on the phone.").font(.footnote)}}.navigationTitle("Gym guide & settings").toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}}}
    func guide(_ title:String,_ body:String)->some View {VStack(alignment:.leading,spacing:8){Text(title).font(.headline);Text(body).foregroundStyle(Design.muted)}.padding(.vertical,5)}
}
struct GymSummary:View {
    let workout:GymWorkout
    @ObservedObject var gym:GymStore
    @Environment(\.dismiss) private var dismiss
    var body:some View {NavigationStack{ScrollView{VStack(alignment:.leading,spacing:24){Image(systemName:"checkmark.seal.fill").font(.system(size:48)).foregroundStyle(WorkspaceTheme.accent("gym"));Text("One session stronger.").font(.largeTitle.weight(.semibold));Text(workout.title).font(.title3);HStack{stat("Completed",String(workout.completedSets)+" sets");Spacer();stat("Volume",String(Int(workout.volume))+" kg");Spacer();stat("Time",String(Int(workout.elapsed(at:Date())/60))+" min")};ForEach(workout.exercises){item in VStack(alignment:.leading,spacing:5){Text(gym.exercise(item.exerciseID).name).font(.headline);Text("\(item.sets.filter(\.done).count) completed sets").font(.caption);Text(item.sets.filter(\.done).map{$0.minutes>0 ? "\($0.minutes.formatted()) min · \($0.distance.formatted()) km":"\($0.kg.formatted()) kg × \($0.reps)"}.joined(separator:" · ")).font(.subheadline).foregroundStyle(Design.muted)}};Button("Done"){dismiss()}.buttonStyle(ActionStyle())}.padding(24)}.safeAreaInset(edge:.top){if let session=gym.owner?.walkthrough{WalkthroughCoach(session:session)}}.navigationTitle("Workout saved").navigationBarTitleDisplayMode(.inline)}}
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
    @Environment(\.dismiss) private var dismiss
    @State private var session:WalkthroughSession?
    var body:some View{ProgressView("Opening Gym practice…").navigationBarBackButtonHidden().onAppear{if session == nil{session=WalkthroughSession(kind:.gym,narration:true,token:token)}}.fullScreenCover(item:$session){active in NativeRoot(store:active.practice).onAppear{active.onExit={active.practice.discardPractice();session=nil;dismiss()};active.startGuidance()}.onDisappear{active.narrator.stop()}}}

}

struct GymVideo:Codable,Identifiable {
    let exerciseID:String
    let title:String
    let url:String
    var id:String{exerciseID}
    static let clips:[GymVideo]={guard let url=Bundle.main.url(forResource:"videos",withExtension:"json",subdirectory:"GymResources"),let bytes=try? Data(contentsOf:url) else{return []};return (try? JSONDecoder().decode([GymVideo].self,from:bytes)) ?? []}()
}
struct GymMovementGuide:View {
    let exercise:GymExercise
    var height:CGFloat=160
    @State private var video:GymVideo?
    var matching:GymVideo?{GymVideo.clips.first{$0.exerciseID == exercise.id || $0.title.caseInsensitiveCompare(exercise.name) == .orderedSame}}
    var body:some View {VStack(alignment:.leading,spacing:10){GymExerciseImage(exercise:exercise,height:height)
        if let matching{Button{video=matching}label:{Label("Watch demonstration",systemImage:"play.rectangle.fill").frame(minHeight:44)}.accessibilityIdentifier("gym-watch-demonstration");Text(matching.title+" · Your Move").font(.caption).foregroundStyle(Design.muted)}else{Text(exercise.images.isEmpty ? "Technique instructions below. No matching demonstration yet.":"Still reference positions · tap the image to change position").font(.caption).foregroundStyle(Design.muted)}
    }.sheet(item:$video){GymVideoPlayer(video:$0)}}
}
struct GymVideoPlayer:View {
    let video:GymVideo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var player:AVPlayer?
    @State private var failure:String?
    @State private var playbackStarted=false
    let playbackTick=Timer.publish(every:0.5,on:.main,in:.common).autoconnect()
    var body:some View {NavigationStack{VStack(spacing:18){if let player{VideoPlayer(player:player).accessibilityIdentifier("gym-video-player")}else if let failure{Text(failure).padding();Button("Try again"){Task{await load()}}}else{ProgressView("Opening demonstration…")};if playbackStarted{Text("Playing demonstration").font(.caption).accessibilityIdentifier("gym-video-playing")};Text("\(video.title) · Your Move").font(.subheadline).foregroundStyle(Design.muted);Link("Video source",destination:URL(string:"https://ymove.app/free-exercise-videos")!)}.padding(20).background(AppBackdrop(scope:"gym")).navigationTitle("Movement demonstration").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.confirmationAction){Button("Done"){player?.pause();dismiss()}}}.task{await load()}.onReceive(playbackTick){_ in if let player{playbackStarted=player.currentTime().seconds>0.5;if player.currentItem?.status == .failed{failure="The demonstration couldn’t play. Try again or use the reference photos.";player.pause();self.player=nil}}}.onDisappear{player?.pause();player=nil}.onChange(of:scenePhase){_,phase in if phase != .active{player?.pause()}}}}
    func load() async {failure=nil;guard let url=URL(string:video.url) else{return};do{let folder=FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("GymDemonstrations",isDirectory:true);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);let cached=folder.appendingPathComponent(video.exerciseID+".mp4")
        if !FileManager.default.fileExists(atPath:cached.path){var request=URLRequest(url:url);request.timeoutInterval=35;let (temporary,response)=try await URLSession.shared.download(for:request);defer{try? FileManager.default.removeItem(at:temporary)};guard let response=response as? HTTPURLResponse,response.statusCode == 200,response.mimeType == "video/mp4",let size=try temporary.resourceValues(forKeys:[.fileSizeKey]).fileSize,size>1000,size<25000000 else{throw URLError(.cannotDecodeContentData)};try Task.checkCancellation();try FileManager.default.moveItem(at:temporary,to:cached)}
        let asset=AVURLAsset(url:cached);let playable=try await asset.load(.isPlayable);try Task.checkCancellation();guard playable else{throw URLError(.cannotDecodeContentData)};let next=AVPlayer(playerItem:AVPlayerItem(asset:asset));next.isMuted=true;player=next;next.play()}catch{if !Task.isCancelled{failure="This demonstration couldn’t open. Your reference photos and technique notes are still available."}}}
}
