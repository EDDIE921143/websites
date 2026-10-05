import Foundation

public struct GymExercise: Codable, Identifiable, Sendable {
    public var id:String
    public var name:String
    public var equipment:String?
    public var category:String
    public var primaryMuscles:[String]
    public var instructions:[String]
    public var images:[String]
    public var isCardio:Bool { category == "cardio" }
    public init(id:String=UUID().uuidString,name:String,equipment:String?=nil,category:String="strength",primaryMuscles:[String]=[],instructions:[String]=[],images:[String]=[]) {self.id=id;self.name=name;self.equipment=equipment;self.category=category;self.primaryMuscles=primaryMuscles;self.instructions=instructions;self.images=images}
}
public struct GymPlanExercise: Codable, Identifiable, Sendable {
    public var id=UUID()
    public var exerciseID:String
    public var sets:Int=3
    public var rest:Int=90
    public var superset:String=""
    public var target:String="8–12 reps"
    public init(_ exerciseID:String){self.exerciseID=exerciseID}
}
public struct GymDay: Codable, Identifiable, Sendable {
    public var id=UUID()
    public var title:String
    public var scheduledDate:String?
    public var exercises:[GymPlanExercise]
    public init(_ title:String,exercises:[GymPlanExercise]=[]){self.title=title;self.exercises=exercises}
}
public struct GymSet: Codable, Identifiable, Sendable {
    public var id=UUID()
    public var kg:Double=0
    public var reps:Int=0
    public var minutes:Double=0
    public var distance:Double=0
    public var done:Bool=false
    public init(){}
    public var volume:Double{done ? max(0,kg)*Double(max(0,reps)):0}
}
public struct GymWorkoutExercise: Codable, Identifiable, Sendable {
    public var id=UUID()
    public var exerciseID:String
    public var rest:Int
    public var superset:String
    public var sets:[GymSet]
    public init(_ plan:GymPlanExercise){exerciseID=plan.exerciseID;rest=plan.rest;superset=plan.superset;sets=(0..<max(1,min(20,plan.sets))).map{_ in GymSet()}}
}
public struct GymWorkout: Codable, Identifiable, Sendable {
    public var id=UUID()
    public var title:String
    public var started=Date()
    public var ended:Date?
    public var exercises:[GymWorkoutExercise]
    public var restEnds:Date?
    public init(_ day:GymDay,now:Date=Date()){title=day.title;started=now;exercises=day.exercises.map{GymWorkoutExercise($0)}}
    public var volume:Double{exercises.flatMap(\.sets).reduce(0){$0+$1.volume}}
    public var completedSets:Int{exercises.flatMap(\.sets).filter(\.done).count}
    public func elapsed(at now:Date)->TimeInterval{max(0,(ended ?? now).timeIntervalSince(started))}
    public func restRemaining(at now:Date)->Int{max(0,Int(ceil((restEnds ?? now).timeIntervalSince(now))))}
}
public struct GymState: Codable, Sendable {
    public var days:[GymDay]=[GymDay("Chest & triceps"),GymDay("Back & biceps"),GymDay("Rest / easy cardio"),GymDay("Legs"),GymDay("Shoulders & core"),GymDay("Cardio"),GymDay("Rest")]
    public var custom:[GymExercise]=[]
    public var active:GymWorkout?
    public var history:[GymWorkout]=[]
    public var alerts=false
    public init(){}
    public func previousSets(for exerciseID:String)->[GymSet]{history.sorted{($0.ended ?? $0.started)>($1.ended ?? $1.started)}.first{$0.exercises.contains{$0.exerciseID == exerciseID && $0.sets.contains(where:\.done)}}?.exercises.first{$0.exerciseID == exerciseID}?.sets.filter(\.done) ?? []}
    public mutating func finish(at now:Date=Date()){guard var workout=active else{return};workout.ended=now;workout.restEnds=nil;history.insert(workout,at:0);active=nil}
}

/// Apply one reviewed change atomically; stale IDs never target a different exercise.
extension GymState {
    public mutating func applyPlanChange(_ data:[String:String],allowedExerciseIDs:Set<String>) throws {
        guard let dayID=data["dayID"],let day=days.firstIndex(where:{$0.id.uuidString == dayID}) else{throw GymChangeError.stale}
        var updated=self
        switch data["operation"] {
        case "swap":
            guard let otherID=data["otherDayID"],let other=days.firstIndex(where:{$0.id.uuidString == otherID}),other != day else{throw GymChangeError.stale}
            updated.days[day].title=days[other].title;updated.days[day].exercises=days[other].exercises
            updated.days[other].title=days[day].title;updated.days[other].exercises=days[day].exercises
        case "rename":
            guard let title=data["name"],!title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{throw GymChangeError.invalid}
            updated.days[day].title=String(title.prefix(100))
        case "date":
            guard let date=data["date"],date.range(of:#"^\d{4}-\d{2}-\d{2}$"#,options:.regularExpression) != nil,ISO8601DateFormatter().date(from:date+"T12:00:00Z") != nil else{throw GymChangeError.invalid}
            updated.days[day].scheduledDate=date
        case "add":
            guard let exercise=data["exerciseID"],allowedExerciseIDs.contains(exercise) else{throw GymChangeError.invalid}
            updated.days[day].exercises.append(GymPlanExercise(exercise))
        case "remove","edit","replace":
            guard let entryID=data["entryID"],let entry=days[day].exercises.firstIndex(where:{$0.id.uuidString == entryID}) else{throw GymChangeError.stale}
            if data["operation"] == "remove"{updated.days[day].exercises.remove(at:entry)}
            else if data["operation"] == "replace"{guard let exercise=data["exerciseID"],allowedExerciseIDs.contains(exercise) else{throw GymChangeError.invalid};updated.days[day].exercises[entry].exerciseID=exercise}
            else {
                if let value=data["sets"]{guard let count=Int(value),(1...20).contains(count) else{throw GymChangeError.invalid};updated.days[day].exercises[entry].sets=count}
                if let value=data["rest"]{guard let seconds=Int(value),(15...600).contains(seconds) else{throw GymChangeError.invalid};updated.days[day].exercises[entry].rest=seconds}
                if let value=data["target"]{updated.days[day].exercises[entry].target=String(value.prefix(100))}
                if let value=data["superset"]{updated.days[day].exercises[entry].superset=String(value.prefix(100))}
            }
        default:throw GymChangeError.invalid
        }
        self=updated
    }
}
public enum GymChangeError:LocalizedError {
    case stale,invalid
    public var errorDescription:String?{self == .stale ? "This plan has changed. Ask Gym Bot for an updated suggestion.":"This change has an unavailable exercise or invalid setting. Ask Gym Bot to revise it."}
}
