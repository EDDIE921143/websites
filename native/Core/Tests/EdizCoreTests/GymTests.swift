import XCTest
@testable import EdizCore
final class GymTests:XCTestCase {
    func testFiveDayPlanMatchesRequestedOrder(){
        var state=GymState();state.adoptEdizFiveDayPlan()
        XCTAssertEqual(state.days.map(\.title),["Day 1 · Chest","Day 2 · Back","Recovery","Day 3 · Legs","Day 4 · Back & chest","Day 5 · Arms","Recovery"])
        XCTAssertEqual(state.days.map{$0.exercises.count},[6,6,0,5,5,8,0])
        XCTAssertEqual(state.days[0].exercises.map(\.exerciseID),["lever-chest-press","lever-seated-fly","lever-shoulder-press","lever-lateral-raise","lever-seated-dip","extra-decline-situp"])
        XCTAssertEqual(state.days[1].exercises.map(\.exerciseID),["lever-seated-row","bar-lat-pulldown","lever-reverse-fly","extra-decline-situp","shrugs","lever-preacher-curl"])
        XCTAssertEqual(state.days[3].exercises.map(\.exerciseID),["lever-seated-leg-curl","seated-leg-press","seated-hip-adduction","leg-extension","seated-calf-raise"])
        XCTAssertEqual(state.days[4].exercises.map(\.exerciseID),["lever-chest-press","lever-seated-fly","lever-seated-row","bar-lat-pulldown","extra-decline-situp"])
        XCTAssertEqual(state.days[5].exercises.map(\.exerciseID),["tricep-dips","preacher-curl","overhead-tricep-extension","hammer-curl","cable-pushdown","dumbbell-incline","one-arm-wrist-curl","one-arm-reverse-wrist-curl"])
    }
    func testFiveDayMigrationPreservesLogsCustomExercisesAndTargets() throws {
        var state=GymState()
        var curl=GymPlanExercise("preacher-curl");curl.sets=4;curl.rest=120;curl.target="10 reps";curl.superset="Arms"
        state.days[3]=GymDay("Day 4 · Arms",exercises:[curl,GymPlanExercise("tricep-extend")])
        state.days[2]=GymDay("Day 3 · Legs",exercises:[GymPlanExercise("hyperextensions")])
        state.days[0].scheduledDate="2026-10-12"
        state.custom=[GymExercise(id:"custom-machine",name:"My machine")];state.alerts=true
        state.active=GymWorkout(state.days[3]);state.active?.exercises[0].sets[0].kg=25
        state.history=[GymWorkout(state.days[3])]
        let encoder=JSONEncoder();encoder.outputFormatting = .sortedKeys
        let active=try encoder.encode(state.active),history=try encoder.encode(state.history)
        let dayID=state.days[0].id
        state.adoptEdizFiveDayPlan()
        XCTAssertEqual(state.days[0].id,dayID);XCTAssertEqual(state.days[0].scheduledDate,"2026-10-12")
        XCTAssertEqual(state.custom.first?.id,"custom-machine");XCTAssertTrue(state.alerts)
        XCTAssertEqual(try encoder.encode(state.active),active);XCTAssertEqual(try encoder.encode(state.history),history)
        let retained=try XCTUnwrap(state.days[5].exercises.first{$0.exerciseID=="preacher-curl"})
        XCTAssertEqual(retained.sets,4);XCTAssertEqual(retained.rest,120);XCTAssertEqual(retained.target,"10 reps");XCTAssertEqual(retained.superset,"Arms")
        XCTAssertFalse(state.days.flatMap(\.exercises).contains{$0.exerciseID=="hyperextensions" || $0.exerciseID=="tricep-extend"})
        XCTAssertNotEqual(retained.id,curl.id)
    }
    func testElapsedAndRestUseDeadlinesAcrossLockAndRestart() throws {
        let start=Date(timeIntervalSince1970:1000)
        var workout=GymWorkout(GymDay("Chest"),now:start)
        workout.restEnds=start.addingTimeInterval(90)
        let restored=try JSONDecoder().decode(GymWorkout.self,from:JSONEncoder().encode(workout))
        XCTAssertEqual(restored.elapsed(at:start.addingTimeInterval(600)),600)
        XCTAssertEqual(restored.restRemaining(at:start.addingTimeInterval(35)),55)
        XCTAssertEqual(restored.restRemaining(at:start.addingTimeInterval(200)),0)
    }
    func testOnlyCompletedSetsCountAndFinishIsIdempotent() throws {
        var state=GymState();state.active=GymWorkout(GymDay("Chest",exercises:[GymPlanExercise("press")]),now:Date(timeIntervalSince1970:1000))
        state.active?.exercises[0].sets[0].kg=40;state.active?.exercises[0].sets[0].reps=12
        XCTAssertEqual(state.active?.volume,0)
        state.active?.exercises[0].sets[0].done=true
        XCTAssertEqual(state.active?.volume,480)
        state.finish(at:Date(timeIntervalSince1970:1600));state.finish()
        XCTAssertNil(state.active);XCTAssertEqual(state.history.count,1);XCTAssertEqual(state.history[0].elapsed(at:Date()),600)
        let restored=try JSONDecoder().decode(GymState.self,from:JSONEncoder().encode(state))
        XCTAssertEqual(restored.previousSets(for:"press").first?.kg,40)
        XCTAssertEqual(restored.previousSets(for:"press").count,1)
        XCTAssertTrue(restored.previousSets(for:"different").isEmpty)
    }
    func testPlanChangesUseStableIDsAndPersistDates() throws {
        var state=GymState();state.days[0].exercises=[GymPlanExercise("press"),GymPlanExercise("fly")]
        let day=state.days[0].id.uuidString,entry=state.days[0].exercises[0].id.uuidString,other=state.days[1].id.uuidString
        try state.applyPlanChange(["operation":"remove","dayID":day,"entryID":entry],allowedExerciseIDs:["press","fly"])
        XCTAssertEqual(state.days[0].exercises.map(\.exerciseID),["fly"])
        XCTAssertThrowsError(try state.applyPlanChange(["operation":"edit","dayID":day,"entryID":entry,"sets":"5"],allowedExerciseIDs:["press","fly"]))
        XCTAssertEqual(state.days[0].exercises[0].sets,3)
        try state.applyPlanChange(["operation":"swap","dayID":day,"otherDayID":other],allowedExerciseIDs:["press","fly"])
        XCTAssertEqual(state.days[1].exercises[0].exerciseID,"fly");XCTAssertTrue(state.days[0].exercises.isEmpty)
        try state.applyPlanChange(["operation":"date","dayID":other,"date":"2026-10-09"],allowedExerciseIDs:["fly"])
        let restored=try JSONDecoder().decode(GymState.self,from:JSONEncoder().encode(state));XCTAssertEqual(restored.days[1].scheduledDate,"2026-10-09")
        XCTAssertThrowsError(try state.applyPlanChange(["operation":"add","dayID":day,"exerciseID":"invented"],allowedExerciseIDs:["fly"]))
    }
    func testInvalidPlanChangeIsAtomicAndKeepsWorkoutHistory() throws {
        var state=GymState();state.days[0].exercises=[GymPlanExercise("press")];state.active=GymWorkout(state.days[0])
        let day=state.days[0].id.uuidString,entry=state.days[0].exercises[0].id.uuidString
        XCTAssertThrowsError(try state.applyPlanChange(["operation":"edit","dayID":day,"entryID":entry,"sets":"4","rest":"-1"],allowedExerciseIDs:["press"]))
        XCTAssertEqual(state.days[0].exercises[0].sets,3)
        try state.applyPlanChange(["operation":"edit","dayID":day,"entryID":entry,"sets":"4","rest":"120"],allowedExerciseIDs:["press"])
        XCTAssertEqual(state.days[0].exercises[0].sets,4);XCTAssertEqual(state.active?.exercises[0].sets.count,3)
    }
    func testCardioDoesNotInventStrengthVolume(){var set=GymSet();set.minutes=30;set.distance=5;set.done=true;XCTAssertEqual(set.volume,0)}
}
