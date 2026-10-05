import XCTest
@testable import EdizCore
final class GymTests:XCTestCase {
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
    func testCardioDoesNotInventStrengthVolume(){var set=GymSet();set.minutes=30;set.distance=5;set.done=true;XCTAssertEqual(set.volume,0)}
}
