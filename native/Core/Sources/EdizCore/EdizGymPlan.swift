import Foundation

public enum EdizGymPlan {
    public static let revision="five-day-wed-sun-rest-20261005"
    public static let titles:[String]=["Day 1 · Chest", "Day 2 · Back", "Recovery", "Day 3 · Legs", "Day 4 · Back & chest", "Day 5 · Arms", "Recovery"]
    public static let exercises:[[String]]=[["lever-chest-press", "lever-seated-fly", "lever-shoulder-press", "lever-lateral-raise", "lever-seated-dip", "extra-decline-situp"], ["lever-seated-row", "bar-lat-pulldown", "lever-reverse-fly", "extra-decline-situp", "shrugs", "lever-preacher-curl"], [], ["lever-seated-leg-curl", "seated-leg-press", "seated-hip-adduction", "leg-extension", "seated-calf-raise"], ["lever-chest-press", "lever-seated-fly", "lever-seated-row", "bar-lat-pulldown", "extra-decline-situp"], ["tricep-dips", "preacher-curl", "overhead-tricep-extension", "hammer-curl", "cable-pushdown", "dumbbell-incline", "one-arm-wrist-curl", "one-arm-reverse-wrist-curl"], []]
}
extension GymState {
    public mutating func adoptEdizFiveDayPlan(){
        let previous=days
        while days.count<7{days.append(GymDay("Recovery"))}
        for index in 0..<7 {
            days[index].title=EdizGymPlan.titles[index]
            days[index].exercises=EdizGymPlan.exercises[index].map{exercise in
                var entry=GymPlanExercise(exercise)
                let prefix=EdizGymPlan.titles[index].components(separatedBy:" ·").first ?? ""
                let preferred=index==5 ? previous.first{$0.title.localizedCaseInsensitiveContains("arms")}:previous.first{$0.title.hasPrefix(prefix+" ·")}
                if let old=preferred?.exercises.first(where:{$0.exerciseID==exercise}) ?? previous.flatMap(\.exercises).first(where:{$0.exerciseID==exercise}){entry.sets=old.sets;entry.rest=old.rest;entry.target=old.target;entry.superset=old.superset}
                return entry
            }
        }
    }
}
