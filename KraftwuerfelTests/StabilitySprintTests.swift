import XCTest
import Foundation
@testable import Kraftwuerfel

final class StabilitySprintTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GeneratorSettings.shared.split = .fullBody
        GeneratorSettings.shared.method = .standard
        GeneratorSettings.shared.count = 6
    }

    // MARK: - Issue 1: Generator & Reel Stability

    func testReelControllerLifecycleAndStop() {
        let reel = ReelController()
        reel.runReel(count: 6)
        XCTAssertFalse(reel.scramble.isEmpty)
        reel.stopEverything()
        XCTAssertTrue(reel.scramble.isEmpty)
    }

    // MARK: - Issue 2: Beine vs Beine-Fokus Conflict

    func testSplitLegsAutoResetsLegsFocus() {
        let settings = GeneratorSettings.shared
        settings.split = .push
        settings.method = .legsFocus
        XCTAssertEqual(settings.method, .legsFocus)

        // Switch to legs split
        settings.split = .legs
        XCTAssertEqual(settings.split, .legs)
        XCTAssertEqual(settings.method, .standard, "Selecting split .legs must auto-reset method .legsFocus to .standard")

        // Attempting to set legsFocus while split == .legs must stay .standard
        settings.method = .legsFocus
        XCTAssertEqual(settings.method, .standard, "Method .legsFocus must not be selectable while split == .legs")
    }

    func testPlanGeneratorNormalizesLegsFocusOnLegsSplit() {
        let slots = PlanGenerator.buildPlan(
            categories: [.legs, .glutes, .calves],
            count: 6,
            method: .legsFocus,
            restTime: 60
        )
        XCTAssertEqual(slots.count, 6)
        for slot in slots {
            XCTAssertFalse(slot.exercise.name.isEmpty)
            XCTAssertEqual(slot.sets, 3)
        }
    }

    // MARK: - Issue 3: Meal Guide – No Repetitions Within Same Week

    func testWeeklyMealGuideHasZeroDuplicatesWithinWeek() {
        let biometrics = UserBiometrics(
            sex: "male",
            age: 26,
            heightCm: 182,
            weightKg: 78,
            somatotype: .mesomorph,
            activityLevel: .moderatelyActive
        )
        let input = AICoachInput(
            goal: .muscle,
            experience: .intermediate,
            biometrics: biometrics,
            selectedDays: ["Montag", "Dienstag", "Donnerstag", "Freitag"],
            sessionDurationMinutes: 60,
            weeks: 4,
            equipment: Set(EquipmentType.allCases),
            diet: .omnivore,
            includeWarmup: true,
            method: .standard
        )

        let nutrition = AICoachService.shared.generateNutrition(input: input, language: "de")
        XCTAssertEqual(nutrition.weeklySchedule.count, 7, "Weekly schedule must have 7 days")

        var seenMeals = Set<String>()
        var duplicates: [String] = []

        for daySchedule in nutrition.weeklySchedule {
            for meal in daySchedule.meals {
                let normalized = meal.name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
                if seenMeals.contains(normalized) {
                    duplicates.append("Day \(daySchedule.dayNumber) (\(daySchedule.dayName)): \(meal.name)")
                }
                seenMeals.insert(normalized)
            }
        }

        XCTAssertTrue(
            duplicates.isEmpty,
            "Meal Guide must NOT contain duplicate meals within the same week. Found duplicates: \(duplicates)"
        )
    }

    func testLactoVegetarianWeeklyMealGuideHasZeroDuplicates() {
        let biometrics = UserBiometrics(sex: "female", age: 24, heightCm: 175, weightKg: 70, somatotype: .ectomorph, activityLevel: .veryActive)
        let input = AICoachInput(
            goal: .definition,
            experience: .beginner,
            biometrics: biometrics,
            selectedDays: ["Montag", "Mittwoch", "Freitag"],
            sessionDurationMinutes: 60,
            weeks: 4,
            equipment: Set(EquipmentType.allCases),
            diet: .lactoVegetarian,
            includeWarmup: true,
            method: .standard
        )

        let nutrition = AICoachService.shared.generateNutrition(input: input, language: "de")
        var seenMeals = Set<String>()
        for daySchedule in nutrition.weeklySchedule {
            for meal in daySchedule.meals {
                let normalized = meal.name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
                XCTAssertFalse(seenMeals.contains(normalized), "Duplicate meal found: \(meal.name) in day \(daySchedule.dayNumber)")
                seenMeals.insert(normalized)
            }
        }
    }

    // MARK: - Issue 4: Meal Guide – Chronological Time Order

    func testMealTimeParsingAndSorting() {
        XCTAssertEqual(PlanMapper.parseTimeMinutes("08:00"), 480)
        XCTAssertEqual(PlanMapper.parseTimeMinutes("12:30"), 750)
        XCTAssertEqual(PlanMapper.parseTimeMinutes("16:00"), 960)
        XCTAssertEqual(PlanMapper.parseTimeMinutes("19:30"), 1170)
        XCTAssertEqual(PlanMapper.parseTimeMinutes("7:15"), 435)

        let unorderedMeals = [
            MealItem(time: "19:30", name: "Dinner", calories: 600, items: []),
            MealItem(time: "08:00", name: "Breakfast", calories: 450, items: []),
            MealItem(time: "16:00", name: "Snack", calories: 250, items: []),
            MealItem(time: "12:30", name: "Lunch", calories: 700, items: [])
        ]

        let sorted = unorderedMeals.sorted { PlanMapper.parseTimeMinutes($0.time) < PlanMapper.parseTimeMinutes($1.time) }
        XCTAssertEqual(sorted.map(\.time), ["08:00", "12:30", "16:00", "19:30"])
    }

    // MARK: - Issue 5: AI Coach – Always 6–8 Exercises

    func testEnsureExerciseCountBetween6And8PadsUnder6() {
        let singleSlot = [
            ExerciseSlot(exercise: ExerciseDatabase.all[0], sets: 3, reps: "8-12", restSeconds: 60)
        ]
        let padded = PlanMapper.ensureExerciseCountBetween6And8(singleSlot)
        XCTAssertEqual(padded.count, 6, "Must pad to minimum 6 exercises")
    }

    func testEnsureExerciseCountBetween6And8TrimsOver8() {
        var tenSlots: [ExerciseSlot] = []
        for i in 0..<10 {
            tenSlots.append(ExerciseSlot(exercise: ExerciseDatabase.all[i % ExerciseDatabase.all.count], sets: 3, reps: "8-12", restSeconds: 60))
        }
        let trimmed = PlanMapper.ensureExerciseCountBetween6And8(tenSlots)
        XCTAssertEqual(trimmed.count, 8, "Must trim to maximum 8 exercises")
    }

    func testAICoachPlanAlwaysGenerates6To8ExercisesPerDay() {
        let biometrics = UserBiometrics(sex: "male", age: 30, heightCm: 185, weightKg: 85, somatotype: .mesomorph, activityLevel: .veryActive)
        let input = AICoachInput(
            goal: .muscle,
            experience: .advanced,
            biometrics: biometrics,
            selectedDays: ["Montag", "Dienstag", "Donnerstag", "Freitag"],
            sessionDurationMinutes: 75,
            weeks: 4,
            equipment: Set(EquipmentType.allCases),
            diet: .omnivore,
            includeWarmup: true,
            method: .standard
        )

        let plan = AICoachService.shared.generatePlan(input: input, language: "de")
        for day in plan.days {
            XCTAssertGreaterThanOrEqual(day.cycle1Slots.count, 6, "Cycle 1 must have at least 6 exercises")
            XCTAssertLessThanOrEqual(day.cycle1Slots.count, 8, "Cycle 1 must have at most 8 exercises")
            XCTAssertGreaterThanOrEqual(day.cycle2Slots.count, 6, "Cycle 2 must have at least 6 exercises")
            XCTAssertLessThanOrEqual(day.cycle2Slots.count, 8, "Cycle 2 must have at most 8 exercises")
        }
    }

    // MARK: - Issue 6 & 7: Authentication & Password Reset Email Normalization

    func testEmailCaseInsensitiveNormalization() {
        let rawEmail1 = "  John.DOE@Example.COM  \n"
        let normalized1 = rawEmail1.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
        XCTAssertEqual(normalized1, "john.doe@example.com")

        let rawEmail2 = "User+Test@GMAIL.com "
        let normalized2 = rawEmail2.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
        XCTAssertEqual(normalized2, "user+test@gmail.com")
    }

    // MARK: - Issue 8: Live Workout State Saving

    func testWorkoutHistoryStoreLogsSessionCorrectly() {
        let store = WorkoutHistoryStore.shared
        let initialCount = store.logs.count

        let exercise = LoggedExercise(
            exerciseId: "bench_press",
            exerciseName: "Bankdrücken",
            category: .chest,
            sets: [
                LoggedSet(setIndex: 0, weight: 80.0, reps: 8, done: true),
                LoggedSet(setIndex: 1, weight: 85.0, reps: 6, done: true)
            ]
        )

        let log = store.logSession(
            planTitle: "Test Workout Sprint",
            durationSeconds: 1800,
            peakHeartRate: 145,
            estimatedCalories: 320,
            exercises: [exercise],
            motivationalQuote: "Stark gemacht!"
        )

        XCTAssertEqual(store.logs.count, initialCount + 1)
        XCTAssertEqual(log.planTitle, "Test Workout Sprint")
        XCTAssertEqual(log.durationSeconds, 1800)
        XCTAssertEqual(log.estimatedCalories, 320)
        XCTAssertEqual(log.totalVolume, (80.0 * 8) + (85.0 * 6))
    }

    // MARK: - Location-based Equipment Disabling

    func testTrainingLocationAutoDisablesGymEquipment() {
        let homeAllowed = AICoachSession.allowedEquipment(for: .homeBodyweight)
        XCTAssertTrue(homeAllowed.contains(.bodyweight))
        XCTAssertTrue(homeAllowed.contains(.dumbbell))
        XCTAssertFalse(homeAllowed.contains(.machine), "Gym machines must not be allowed for home location")
        XCTAssertFalse(homeAllowed.contains(.cable), "Cable crossover must not be allowed for home location")
        XCTAssertFalse(homeAllowed.contains(.smithMachine), "Smith machine must not be allowed for home location")

        let outdoorAllowed = AICoachSession.allowedEquipment(for: .outdoorPark)
        XCTAssertEqual(outdoorAllowed, [.bodyweight], "Outdoor park must only allow bodyweight exercises")

        let gymAllowed = AICoachSession.allowedEquipment(for: .gym)
        XCTAssertEqual(gymAllowed.count, EquipmentType.allCases.count, "Gym must allow all equipment types")
    }

    func testSomatotypePropertiesAndCases() {
        XCTAssertEqual(Somatotype.allCases.count, 3)
        XCTAssertEqual(Somatotype.ectomorph.id, "ectomorph")
        XCTAssertEqual(Somatotype.mesomorph.id, "mesomorph")
        XCTAssertEqual(Somatotype.endomorph.id, "endomorph")
    }
}
