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
