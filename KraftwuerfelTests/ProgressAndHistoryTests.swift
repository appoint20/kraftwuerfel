import XCTest
@testable import Kraftwuerfel

final class ProgressAndHistoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutHistoryStore.shared.wipe()
    }

    override func tearDown() {
        WorkoutHistoryStore.shared.wipe()
        super.tearDown()
    }

    func testLogSessionAndProgression() {
        let store = WorkoutHistoryStore.shared
        XCTAssertEqual(store.totalWorkoutsCount, 0)

        let sets1 = [
            LoggedSet(setIndex: 0, weight: 80.0, reps: 8, done: true),
            LoggedSet(setIndex: 1, weight: 82.5, reps: 8, done: true)
        ]
        let ex1 = LoggedExercise(
            exerciseId: "bench_press",
            exerciseName: "Bankdrücken",
            category: .chest,
            sets: sets1
        )

        let quote = MotivationalQuotes.randomQuote(language: "de")
        XCTAssertFalse(quote.isEmpty)

        let log1 = store.logSession(
            planTitle: "Push Day",
            durationSeconds: 2400,
            peakHeartRate: 155,
            estimatedCalories: 320,
            exercises: [ex1],
            motivationalQuote: quote
        )

        XCTAssertEqual(store.totalWorkoutsCount, 1)
        XCTAssertEqual(log1.totalVolume, 80.0 * 8 + 82.5 * 8)
        XCTAssertEqual(log1.completedSetsCount, 2)

        // Query most recent log
        let recent = store.mostRecentLog(for: "Bankdrücken")
        XCTAssertNotNil(recent)
        XCTAssertEqual(recent?.weight, 82.5)
        XCTAssertEqual(recent?.reps, 8)

        // Add second session with progress
        let sets2 = [
            LoggedSet(setIndex: 0, weight: 85.0, reps: 8, done: true),
            LoggedSet(setIndex: 1, weight: 87.5, reps: 6, done: true)
        ]
        let ex2 = LoggedExercise(
            exerciseId: "bench_press",
            exerciseName: "Bankdrücken",
            category: .chest,
            sets: sets2
        )
        store.logSession(
            planTitle: "Push Day 2",
            durationSeconds: 2500,
            peakHeartRate: 160,
            estimatedCalories: 340,
            exercises: [ex2],
            motivationalQuote: "Starkes Training! 🔥"
        )

        XCTAssertEqual(store.totalWorkoutsCount, 2)

        // Test progression points
        let progression = store.exerciseProgression(for: "Bankdrücken")
        XCTAssertEqual(progression.count, 2)
        XCTAssertEqual(progression[0].maxWeight, 82.5)
        XCTAssertEqual(progression[1].maxWeight, 87.5)

        // Test all logged exercise names
        let names = store.allLoggedExerciseNames
        XCTAssertTrue(names.contains("Bankdrücken"))
    }

    func testMotivationalQuotesBothLanguages() {
        let de = MotivationalQuotes.randomQuote(language: "de")
        let en = MotivationalQuotes.randomQuote(language: "en")

        XCTAssertFalse(de.isEmpty)
        XCTAssertFalse(en.isEmpty)
        XCTAssertTrue(MotivationalQuotes.quotesDE.contains(de))
        XCTAssertTrue(MotivationalQuotes.quotesEN.contains(en))
    }

    func testBodyWeightTrackingAndProgress() {
        let session = AICoachSession.shared
        session.weightKg = 82.0
        session.startWeightKg = 86.0
        session.goalWeightKg = 78.0

        XCTAssertEqual(session.weightKg, 82.0)
        XCTAssertEqual(session.startWeightKg, 86.0)
        XCTAssertEqual(session.goalWeightKg, 78.0)

        // Delta to goal: 78 - 82 = -4.0 kg to lose
        let delta = session.goalWeightKg! - session.weightKg
        XCTAssertEqual(delta, -4.0)

        // Total journey: 86 - 78 = 8.0 kg
        // Progress made: 86 - 82 = 4.0 kg (50%)
        let totalJourney = abs(session.goalWeightKg! - session.startWeightKg!)
        let progressMade = session.startWeightKg! - session.weightKg
        let ratio = progressMade / totalJourney
        XCTAssertEqual(ratio, 0.5)
        XCTAssertEqual(ratio * 100.0, 50.0)
    }
}
